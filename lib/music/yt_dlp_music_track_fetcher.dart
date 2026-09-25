import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:twitch_listener/music/ffmpeg_audio_processor.dart';
import 'package:twitch_listener/music/music_file_cache.dart';
import 'package:twitch_listener/music/music_models.dart';

typedef MusicProcessStarter = Future<Process> Function(
    String executable, List<String> arguments);

class YtDlpException implements Exception {
  final String message;
  final int? exitCode;

  const YtDlpException(this.message, {this.exitCode});

  @override
  String toString() => message;
}

class YtDlpMusicTrackFetcher implements MusicTrackFetcher {
  static const _filePrefix = 'YT_FILE:';
  static const _progressPrefix = 'YT_PROGRESS|';

  final String executable;
  final String? denoPath;
  final MusicFileCache cache;
  final FfmpegAudioProcessor audioProcessor;
  final Duration inspectTimeout;
  final Duration downloadTimeout;
  final MusicProcessStarter _processStarter;

  Process? _activeProcess;
  int _generation = 0;

  YtDlpMusicTrackFetcher({
    required this.executable,
    required this.denoPath,
    required this.cache,
    required this.audioProcessor,
    this.inspectTimeout = const Duration(seconds: 20),
    this.downloadTimeout = const Duration(minutes: 15),
    MusicProcessStarter? processStarter,
  }) : _processStarter = processStarter ?? _startProcess {
    if (cache.profileName != audioProcessor.cacheProfile) {
      throw ArgumentError('Music cache must use the audio processor profile');
    }
  }

  @override
  Future<MusicTrackMetadata> inspect(Uri sourceUrl) async {
    final result = await _runCollectingOutput([
      '--ignore-config',
      '--no-colors',
      '--encoding',
      'utf-8',
      '--no-playlist',
      '--skip-download',
      '--dump-single-json',
      ..._runtimeArguments,
      sourceUrl.toString(),
    ], timeout: inspectTimeout);

    if (result.exitCode != 0) {
      throw YtDlpException(
        _errorMessage('Unable to inspect YouTube URL', result.stderr),
        exitCode: result.exitCode,
      );
    }

    try {
      final json = jsonDecode(result.stdout);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }

      if (json['is_live'] == true || json['live_status'] == 'is_live') {
        throw const YtDlpException('Live streams are not supported');
      }

      final seconds = json['duration'];
      if (seconds is! num || seconds <= 0) {
        throw const YtDlpException('Video duration is unavailable');
      }

      final videoId = json['id'];
      final title = json['title'];
      if (videoId is! String || title is! String) {
        throw const YtDlpException('YouTube metadata is incomplete');
      }

      final thumbnail = json['thumbnail'];

      return MusicTrackMetadata(
        videoId: videoId,
        title: title,
        author: (json['uploader'] as String?) ?? 'YouTube',
        duration: Duration(seconds: seconds.round()),
        thumbnail: thumbnail is String && thumbnail.isNotEmpty
            ? Uri.tryParse(thumbnail)
            : null,
        sourceUrl: sourceUrl,
      );
    } on YtDlpException {
      rethrow;
    } catch (error) {
      throw YtDlpException('Invalid yt-dlp metadata: $error');
    }
  }

  @override
  Future<String> obtain({
    required MusicTrackMetadata metadata,
    required void Function(MusicPreparationProgress progress) onProgress,
  }) {
    final generation = _generation;
    void checkCanceled() {
      if (generation != _generation) {
        throw const YtDlpException('Music preparation canceled');
      }
    }

    return cache.obtain(
      videoId: metadata.videoId,
      checkCanceled: checkCanceled,
      produce: (stagingDirectory) async {
        checkCanceled();
        final downloaded = await _download(
          sourceUrl: metadata.sourceUrl,
          stagingDirectory: stagingDirectory,
          onProgress: onProgress,
        );
        checkCanceled();
        final normalized = await audioProcessor.normalize(
          input: downloaded,
          stagingDirectory: stagingDirectory,
          duration: metadata.duration,
          onProgress: onProgress,
        );
        checkCanceled();
        return normalized;
      },
    );
  }

  Future<File> _download({
    required Uri sourceUrl,
    required Directory stagingDirectory,
    required void Function(MusicPreparationProgress progress) onProgress,
  }) async {
    final args = <String>[
      '--ignore-config',
      '--no-colors',
      '--encoding',
      'utf-8',
      '--no-playlist',
      '--format',
      'bestaudio/best',
      // Keep the original stream for measurement and a single final encode.
      '--fixup',
      'never',
      '--paths',
      stagingDirectory.path,
      '--output',
      'audio.%(ext)s',
      '--newline',
      '--progress',
      '--progress-delta',
      '0.5',
      '--progress-template',
      'download:$_progressPrefix%(progress.downloaded_bytes)s|'
          '%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|'
          '%(progress.eta)s',
      '--print',
      'after_move:$_filePrefix%(filepath)s',
      ..._runtimeArguments,
      sourceUrl.toString(),
    ];

    final stderr = StringBuffer();
    String? finalPath;
    final process = await _start(args);

    void handleLine(String line, {required bool isErrorOutput}) {
      if (line.startsWith(_progressPrefix)) {
        final values = line.substring(_progressPrefix.length).split('|');
        if (values.length >= 4) {
          final downloaded = _parseInt(values[0]) ?? 0;
          final total = _parseInt(values[1]) ?? _parseInt(values[2]);
          onProgress(
            MusicPreparationProgress(
              phase: MusicQueueItemPhase.downloading,
              fraction: total == null || total <= 0
                  ? null
                  : (downloaded / total).clamp(0.0, 1.0).toDouble(),
            ),
          );
        }
        return;
      }

      if (line.startsWith(_filePrefix)) {
        finalPath = line.substring(_filePrefix.length).trim();
        return;
      }

      if (isErrorOutput && line.trim().isNotEmpty) {
        stderr.writeln(line);
      }
    }

    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => handleLine(line, isErrorOutput: false));
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => handleLine(line, isErrorOutput: true));

    try {
      final exitCode = await process.exitCode.timeout(
        downloadTimeout,
        onTimeout: () {
          process.kill();
          throw const YtDlpException('YouTube download timed out');
        },
      );
      await Future.wait([stdoutDone, stderrDone]);

      if (exitCode != 0) {
        throw YtDlpException(
          _errorMessage('Unable to download YouTube audio', stderr.toString()),
          exitCode: exitCode,
        );
      }

      final path = finalPath;
      if (path == null || path.isEmpty) {
        throw const YtDlpException('yt-dlp did not report the downloaded file');
      }
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        throw const YtDlpException('yt-dlp did not produce an audio file');
      }

      if (!_isInside(file, stagingDirectory)) {
        throw const YtDlpException(
          'yt-dlp returned a file outside the staging directory',
        );
      }

      return file;
    } finally {
      try {
        process.kill();
        await process.exitCode;
        await Future.wait([stdoutDone, stderrDone]);
      } finally {
        if (identical(_activeProcess, process)) _activeProcess = null;
      }
    }
  }

  List<String> get _runtimeArguments {
    final path = denoPath;
    if (path == null || path.isEmpty) return const [];
    return ['--js-runtimes', 'deno:$path'];
  }

  Future<_ProcessOutput> _runCollectingOutput(
    List<String> args, {
    required Duration timeout,
  }) async {
    final process = await _start(args);
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();

    try {
      final exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          process.kill();
          throw const YtDlpException('YouTube metadata request timed out');
        },
      );
      return _ProcessOutput(
        exitCode: exitCode,
        stdout: await stdoutFuture,
        stderr: await stderrFuture,
      );
    } finally {
      try {
        process.kill();
        await process.exitCode;
        await Future.wait([stdoutFuture, stderrFuture]);
      } finally {
        if (identical(_activeProcess, process)) _activeProcess = null;
      }
    }
  }

  Future<Process> _start(List<String> args) async {
    final generation = _generation;
    if (_activeProcess != null) {
      throw const YtDlpException('Another yt-dlp operation is already running');
    }

    try {
      final process = await _processStarter(executable, args);
      if (generation != _generation) {
        process.kill();
        await Future.wait([
          process.stdout.drain<void>(),
          process.stderr.drain<void>(),
          process.exitCode,
        ]);
        throw const YtDlpException('Download canceled');
      }
      _activeProcess = process;
      return process;
    } on ProcessException catch (error) {
      throw YtDlpException(
        'YouTube downloader is unavailable. Install yt-dlp.exe and deno.exe '
        'in the tools folder next to the app. ${error.message}',
      );
    }
  }

  static Future<Process> _startProcess(
    String executable,
    List<String> arguments,
  ) =>
      Process.start(executable, arguments, runInShell: false);

  static bool _isInside(File file, Directory directory) {
    String normalize(String path) {
      final absolute = p.normalize(p.absolute(path)).replaceAll('\\', '/');
      return Platform.isWindows ? absolute.toLowerCase() : absolute;
    }

    final staging = normalize(directory.path);
    final candidate = normalize(file.path);
    return candidate.startsWith('$staging/');
  }

  static int? _parseInt(String value) {
    if (value == 'NA' || value.isEmpty) return null;
    return num.tryParse(value)?.round();
  }

  static String _errorMessage(String prefix, String stderr) {
    final detail = stderr.trim();
    if (detail.isEmpty) return prefix;
    final compact = detail.replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= 240) return '$prefix: $compact';
    return '$prefix: ${compact.substring(compact.length - 240)}';
  }

  @override
  Future<void> cancel() async {
    _generation++;
    final process = _activeProcess;
    process?.kill();
    await audioProcessor.cancel();
    if (process != null) await process.exitCode;
  }
}

class _ProcessOutput {
  final int exitCode;
  final String stdout;
  final String stderr;

  const _ProcessOutput({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}
