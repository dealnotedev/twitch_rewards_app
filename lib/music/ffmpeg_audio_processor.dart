import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'music_models.dart';

typedef AudioProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments,
);

class AudioProcessingException implements Exception {
  final String message;

  const AudioProcessingException(this.message);

  @override
  String toString() => message;
}

/// Normalizes the first audio stream while preserving its encoding format.
class FfmpegAudioProcessor {
  final String executable;
  final double targetLufs;
  final double truePeak;
  final double minimumLoudnessRange;
  final Duration passTimeout;
  final AudioProcessStarter _startProcess;
  Process? _activeProcess;
  Completer<void>? _completion;
  int _generation = 0;

  FfmpegAudioProcessor({
    required this.executable,
    this.targetLufs = -16,
    this.truePeak = -2,
    this.minimumLoudnessRange = 20,
    this.passTimeout = const Duration(minutes: 10),
    AudioProcessStarter? processStarter,
  }) : _startProcess = processStarter ?? _start {
    if (!targetLufs.isFinite ||
        targetLufs < -70 ||
        targetLufs > -5 ||
        !truePeak.isFinite ||
        truePeak < -9 ||
        truePeak > 0 ||
        !minimumLoudnessRange.isFinite ||
        minimumLoudnessRange < 1 ||
        minimumLoudnessRange > 50) {
      throw ArgumentError('Invalid loudness normalization targets');
    }
  }

  String get cacheProfile =>
      'youtube-loudnorm-v3-i$targetLufs-tp$truePeak-lra-floor$minimumLoudnessRange'
      '-source-format';

  String _targets(double range) => 'I=$targetLufs:TP=$truePeak:LRA=$range';

  Future<File> normalize({
    required File input,
    required Directory stagingDirectory,
    required Duration duration,
    required void Function(MusicPreparationProgress) onProgress,
  }) async {
    if (_completion != null) {
      throw const AudioProcessingException(
        'Audio processing is already running',
      );
    }
    final completion = _completion = Completer<void>();
    final generation = _generation;
    try {
      final analysis = await _run(
        [
          '-af',
          'loudnorm=${_targets(minimumLoudnessRange)}:print_format=json',
          '-f',
          'null',
          '-',
        ],
        input: input,
        generation: generation,
        duration: duration,
        phase: MusicQueueItemPhase.analyzing,
        onProgress: onProgress,
      );
      _checkCanceled(generation);
      final measured = _measurements(analysis.stderr);
      final extension = p.extension(input.path).toLowerCase();
      final format = _sourceFormat(analysis.header, extension);
      final output = File(
        p.join(stagingDirectory.path, 'normalized$extension'),
      );
      // Preserve the measured range whenever possible. Even a small excess
      // over a fixed LRA target forces dynamic mode and can miss integrated
      // loudness on tracks with large level changes. FFmpeg caps LRA at 50 LU.
      final range =
          measured['input_lra']!.clamp(minimumLoudnessRange, 50.0).toDouble();
      final filter = 'loudnorm=${_targets(range)}'
          ':measured_I=${measured['input_i']}'
          ':measured_TP=${measured['input_tp']}'
          ':measured_LRA=${measured['input_lra']}'
          ':measured_thresh=${measured['input_thresh']}'
          ':offset=${measured['target_offset']}:linear=true:print_format=json';
      await _run(
        [
          '-af',
          filter,
          '-ar',
          format.sampleRate,
          ...format.channelArguments,
          '-c:a',
          format.encoder,
          ...format.encoderArguments,
          '-map_metadata',
          '-1',
          '-f',
          format.muxer,
          output.path,
        ],
        input: input,
        generation: generation,
        duration: duration,
        phase: MusicQueueItemPhase.normalizing,
        onProgress: onProgress,
      );
      if (!await output.exists() || await output.length() == 0) {
        throw const AudioProcessingException('FFmpeg did not produce audio');
      }
      _checkCanceled(generation);
      return output;
    } finally {
      _completion = null;
      completion.complete();
    }
  }

  Future<({String header, String stderr})> _run(
    List<String> outputArguments, {
    required File input,
    required int generation,
    required Duration duration,
    required MusicQueueItemPhase phase,
    required void Function(MusicPreparationProgress) onProgress,
  }) async {
    _checkCanceled(generation);
    onProgress(MusicPreparationProgress(phase: phase, fraction: 0));
    _checkCanceled(generation);
    late Process process;
    try {
      process = await _startProcess(executable, [
        '-hide_banner',
        '-nostdin',
        '-nostats',
        '-y',
        '-progress',
        'pipe:1',
        '-i',
        input.path,
        '-map',
        '0:a:0',
        '-vn',
        '-sn',
        '-dn',
        ...outputArguments,
      ]);
    } on ProcessException catch (error) {
      throw AudioProcessingException(
        'FFmpeg is unavailable. Install ffmpeg.exe in the tools folder '
        'next to the app. ${error.message}',
      );
    }
    _activeProcess = process;
    const logLimit = 65536;
    var header = '';
    var stderr = '';
    var lastFraction = 0.0;
    final stdoutDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .forEach((line) {
      if (generation != _generation || !line.startsWith('out_time_us=')) return;
      final micros = int.tryParse(line.substring('out_time_us='.length));
      if (micros == null || duration.inMicroseconds <= 0) return;
      final fraction =
          (micros / duration.inMicroseconds).clamp(0.0, 1.0).toDouble();
      if (fraction > lastFraction) {
        lastFraction = fraction;
        onProgress(
          MusicPreparationProgress(phase: phase, fraction: fraction),
        );
      }
    });
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((chunk) {
      // The input stream details precede the final loudnorm statistics.
      if (header.length < logLimit) {
        final remaining = logLimit - header.length;
        header +=
            chunk.length > remaining ? chunk.substring(0, remaining) : chunk;
      }
      stderr += chunk;
      // Keep the final loudnorm JSON and useful diagnostics without retaining
      // an unbounded log for a corrupt input.
      if (stderr.length > logLimit) {
        stderr = stderr.substring(stderr.length - logLimit);
      }
    });
    final streamsDone = Future.wait([stdoutDone, stderrDone]);
    try {
      _checkCanceled(generation);
      final exitCode = await process.exitCode.timeout(passTimeout);
      await streamsDone;
      _checkCanceled(generation);
      if (exitCode != 0) {
        final detail = stderr.trim().replaceAll(RegExp(r'\s+'), ' ');
        throw AudioProcessingException(
          'FFmpeg ${phase.name} failed: '
          '${detail.length > 300 ? detail.substring(detail.length - 300) : detail}',
        );
      }
      return (header: header, stderr: stderr);
    } on TimeoutException {
      throw AudioProcessingException('Audio ${phase.name} timed out');
    } finally {
      // Wait for Windows to release the output before cache staging is removed.
      try {
        process.kill();
        await process.exitCode;
        await streamsDone;
      } finally {
        if (identical(_activeProcess, process)) _activeProcess = null;
      }
    }
  }

  // The analysis pass already identifies the input demuxer and the first audio
  // stream. The yt-dlp extension distinguishes muxers that share a demuxer.
  static _SourceAudioFormat _sourceFormat(String log, String extension) {
    final header = log.split('\nStream mapping:').first;
    final demuxers = _inputFormat.firstMatch(header)?.group(1)?.split(',');
    final audio = _inputAudio.firstMatch(header);
    if (demuxers == null || audio == null) {
      throw const AudioProcessingException(
        'FFmpeg did not report the source audio format',
      );
    }
    final (demuxer, muxer) = switch (extension) {
      '.aac' => ('aac', 'adts'),
      '.m4a' => ('m4a', 'ipod'),
      '.mp4' => ('mp4', 'mp4'),
      '.mov' => ('mov', 'mov'),
      '.webm' => ('webm', 'webm'),
      '.mka' || '.mkv' => ('matroska', 'matroska'),
      '.ogg' || '.oga' || '.opus' => ('ogg', 'ogg'),
      '.mp3' => ('mp3', 'mp3'),
      '.wav' => ('wav', 'wav'),
      _ => ('', ''),
    };
    if (!demuxers.contains(demuxer)) {
      throw AudioProcessingException(
        'Unsupported source container: $extension',
      );
    }
    final codec = audio.group(1)!;
    final (encoder, encoderArguments) = switch (codec) {
      'aac' => ('aac', const ['-q:a', '2']),
      'opus' => ('libopus', const <String>[]),
      'vorbis' => ('libvorbis', const ['-q:a', '4']),
      'mp3' => ('libmp3lame', const ['-q:a', '2']),
      'pcm_s16le' || 'pcm_f32le' => (codec, const <String>[]),
      _ => throw AudioProcessingException(
          'Unsupported source audio codec: $codec',
        ),
    };
    final layout = audio.group(3)!.trim();
    final count = _unspecifiedChannels.firstMatch(layout)?.group(1);
    return (
      muxer: muxer,
      encoder: encoder,
      encoderArguments: encoderArguments,
      sampleRate: audio.group(2)!,
      channelArguments: count == null ? ['-ch_layout', layout] : ['-ac', count],
    );
  }

  static final _inputFormat = RegExp(
    r'^Input #0, ([^\r\n]+?), from ',
    multiLine: true,
  );
  static final _inputAudio = RegExp(
    r'^  Stream #0:\d+[^\r\n]*?: Audio: (\w+)\b[^\r\n]*?, (\d+) Hz, ([^,\r\n]+)',
    multiLine: true,
  );
  static final _unspecifiedChannels = RegExp(r'^(\d+) channels$');

  static Map<String, double> _measurements(String stderr) {
    for (final match in RegExp(
      r'\{[^{}]*\}',
    ).allMatches(stderr).toList().reversed) {
      try {
        final json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        if (!json.containsKey('input_i')) continue;
        final result = <String, double>{};
        for (final key in [
          'input_i',
          'input_tp',
          'input_lra',
          'input_thresh',
          'target_offset',
        ]) {
          final value = double.tryParse('${json[key]}');
          if (value == null || !value.isFinite) {
            throw const AudioProcessingException(
              'Audio loudness cannot be measured (silent or invalid audio)',
            );
          }
          result[key] = value;
        }
        if (result['input_i']! < -99 ||
            result['input_i']! > 0 ||
            result['input_tp']! < -99 ||
            result['input_tp']! > 99 ||
            result['input_lra']! < 0 ||
            result['input_lra']! > 99 ||
            result['input_thresh']! < -99 ||
            result['input_thresh']! > 0 ||
            result['target_offset']!.abs() > 99) {
          throw const AudioProcessingException(
            'FFmpeg returned invalid loudness measurements',
          );
        }
        return result;
      } on FormatException {
        continue;
      }
    }
    throw const AudioProcessingException(
      'FFmpeg did not report loudness measurements',
    );
  }

  void _checkCanceled(int generation) {
    if (generation != _generation) {
      throw const AudioProcessingException('Audio processing canceled');
    }
  }

  Future<void> cancel() async {
    _generation++;
    _activeProcess?.kill();
    await _completion?.future;
  }

  static Future<Process> _start(String executable, List<String> arguments) =>
      Process.start(executable, arguments, runInShell: false);
}

typedef _SourceAudioFormat = ({
  String muxer,
  String encoder,
  List<String> encoderArguments,
  String sampleRate,
  List<String> channelArguments,
});
