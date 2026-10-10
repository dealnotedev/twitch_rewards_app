import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:twitch_listener/music/ffmpeg_audio_processor.dart';
import 'package:twitch_listener/music/music_file_cache.dart';
import 'package:twitch_listener/music/music_models.dart';

typedef MusicProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments,
);

class YtDlpException extends MusicTrackException {
  final int? exitCode;
  final String? diagnostic;

  const YtDlpException(
    super.message, {
    this.exitCode,
    this.diagnostic,
    super.errorType,
  });
}

/// A cookie file reserved for one yt-dlp process. yt-dlp rewrites its cookie
/// file when it exits, so concurrent or stale runs must not share the saved
/// session file directly.
abstract interface class YtDlpCookieLease {
  String get path;

  /// Called once the process has exited. [succeeded] reports exit code 0.
  Future<void> release({required bool succeeded});
}

typedef YtDlpCookieSource = Future<YtDlpCookieLease?> Function();

/// A cookie file owned by a single process, such as a connection check.
class YtDlpCookieFile implements YtDlpCookieLease {
  @override
  final String path;

  const YtDlpCookieFile(this.path);

  @override
  Future<void> release({required bool succeeded}) async {}
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
  final YtDlpCookieSource? cookies;

  Process? _activeProcess;
  int _generation = 0;
  ({String videoId, String json})? _inspected;
  String? _version;

  YtDlpMusicTrackFetcher({
    required this.executable,
    required this.denoPath,
    required this.cache,
    required this.audioProcessor,
    this.inspectTimeout = const Duration(seconds: 20),
    this.downloadTimeout = const Duration(minutes: 15),
    MusicProcessStarter? processStarter,
    this.cookies,
  }) : _processStarter = processStarter ?? _startProcess {
    if (cache.profileName != audioProcessor.cacheProfile) {
      throw ArgumentError('Music cache must use the audio processor profile');
    }
  }

  @override
  Future<MusicTrackMetadata> inspect(Uri sourceUrl) async {
    _inspected = null;
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
      throw _failure(result.stderr, result.exitCode);
    }

    try {
      final json = jsonDecode(result.stdout);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }

      if (json['is_live'] == true || json['live_status'] == 'is_live') {
        throw const YtDlpException(
          'Live streams are not supported',
          errorType: MusicQueueErrorType.trackTooLongOrLive,
        );
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
      _inspected = (videoId: videoId, json: result.stdout);

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
          metadata: metadata,
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
    required MusicTrackMetadata metadata,
    required Directory stagingDirectory,
    required void Function(MusicPreparationProgress progress) onProgress,
  }) async {
    final generation = _generation;
    final inspected = _inspected;
    _inspected = null;
    final infoFile = inspected?.videoId == metadata.videoId
        ? File(p.join(stagingDirectory.path, 'info.json'))
        : null;
    await infoFile?.writeAsString(inspected!.json, flush: true);
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
      if (infoFile != null) ...[
        '--load-info-json',
        infoFile.path,
      ] else
        metadata.sourceUrl.toString(),
    ];

    final lease = await cookies?.call();
    var succeeded = false;
    try {
      _checkGeneration(generation);
      final stderr = StringBuffer();
      String? finalPath;
      final process = await _start([..._cookieArguments(lease), ...args]);

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
            throw const YtDlpException(
              'YouTube download timed out',
              errorType: MusicQueueErrorType.networkUnavailable,
            );
          },
        );
        await Future.wait([stdoutDone, stderrDone]);

        if (exitCode != 0) {
          throw _failure(stderr.toString(), exitCode);
        }

        succeeded = true;
        final path = finalPath;
        if (path == null || path.isEmpty) {
          throw const YtDlpException(
            'yt-dlp did not report the downloaded file',
          );
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
    } finally {
      await lease?.release(succeeded: succeeded);
    }
  }

  /// The yt-dlp release for support details, or null when it is unavailable.
  Future<String?> readVersion() async {
    final cached = _version;
    if (cached != null) return cached;
    try {
      final process = await _processStarter(executable, const [
        '--ignore-config',
        '--version',
      ]);
      final output = process.stdout.transform(utf8.decoder).join();
      unawaited(process.stderr.drain<void>());
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      final version = (await output).trim();
      if (exitCode != 0 || version.isEmpty || version.contains('\n')) {
        return null;
      }
      return _version = version;
    } on Object {
      return null;
    }
  }

  List<String> get _runtimeArguments {
    final path = denoPath;
    if (path == null || path.isEmpty) return const [];
    return ['--js-runtimes', 'deno:$path'];
  }

  static List<String> _cookieArguments(YtDlpCookieLease? lease) =>
      lease == null ? const [] : ['--cookies', lease.path];

  /// Maps yt-dlp output to a reason. ERROR lines decide; warnings are only a
  /// fallback, because yt-dlp prints them before unrelated failures too.
  static MusicQueueErrorType classifyFailure(String stderr) {
    final errors = LineSplitter.split(stderr)
        .where((line) => line.trimLeft().startsWith('ERROR:'))
        .join('\n')
        .toLowerCase();
    final type = _classify(errors.isEmpty ? stderr.toLowerCase() : errors);
    if (type != MusicQueueErrorType.operationFailed) return type;

    final text = stderr.toLowerCase();
    if (_containsAny(text, _toolFailures)) {
      return MusicQueueErrorType.musicToolsUnavailable;
    }
    if (text.contains('cookies are no longer valid')) {
      return MusicQueueErrorType.youtubeAccessRequired;
    }
    return MusicQueueErrorType.operationFailed;
  }

  static const _toolFailures = [
    'ffmpeg not found',
    'ffprobe and ffmpeg not found',
    'no supported javascript runtime',
  ];

  static MusicQueueErrorType _classify(String text) {
    if (text.contains('http error 403') &&
        text.contains('unable to download video data')) {
      return MusicQueueErrorType.youtubeDownloadBlocked;
    }
    // A rate limit is reported as "This content isn't available", so it must
    // be recognized before unavailable videos.
    if (_containsAny(text, const [
      "content isn't available, try again later",
      'rate-limited',
      'http error 429',
      'too many requests',
    ])) {
      return MusicQueueErrorType.youtubeRateLimited;
    }
    if (text.contains('captcha')) {
      return MusicQueueErrorType.youtubeAccessRequired;
    }
    // yt-dlp appends "Use --cookies" to every reason that mentions signing in,
    // including private and age-restricted videos. Those concern one video.
    if (_containsAny(text, const [
      'private video',
      'confirm your age',
      'age-restricted',
      'inappropriate for some users',
      'members-only',
      'join this channel',
      'video unavailable',
      'video is unavailable',
      'video has been removed',
      'no longer available',
      'account has been terminated',
      'available in your country',
      'not available from your location',
    ])) {
      return MusicQueueErrorType.youtubeUnavailable;
    }
    if (_containsAny(text, const [
      'not a bot',
      'sign in to confirm',
      'login required',
      'use --cookies',
      'cookies are no longer valid',
      'http error 403',
    ])) {
      return MusicQueueErrorType.youtubeAccessRequired;
    }
    if (_containsAny(text, const [
      'timed out',
      'unable to download webpage',
      'name resolution',
      'failed to resolve',
      'getaddrinfo failed',
      'network is unreachable',
      'connection reset',
      'connection refused',
    ])) {
      return MusicQueueErrorType.networkUnavailable;
    }
    if (_containsAny(text, _toolFailures)) {
      return MusicQueueErrorType.musicToolsUnavailable;
    }
    return MusicQueueErrorType.operationFailed;
  }

  static bool _containsAny(String text, List<String> values) =>
      values.any(text.contains);

  static YtDlpException _failure(String stderr, int exitCode) {
    final type = classifyFailure(stderr);
    return YtDlpException(
      switch (type) {
        MusicQueueErrorType.youtubeDownloadBlocked =>
          'YouTube blocked this audio download (403).',
        MusicQueueErrorType.youtubeRateLimited =>
          'YouTube temporarily limited requests from this computer.',
        MusicQueueErrorType.youtubeAccessRequired => 'YouTube needs verification. Connect YouTube in the Play YouTube Track card.',
        MusicQueueErrorType.youtubeUnavailable =>
          'This YouTube video is unavailable. Please choose another.',
        MusicQueueErrorType.networkUnavailable =>
          'Unable to reach YouTube. Check your internet connection.',
        MusicQueueErrorType.musicToolsUnavailable =>
          'Music components are unavailable. Reinstall the application.',
        _ => 'Unable to prepare this track. Please try again later.',
      },
      errorType: type,
      exitCode: exitCode,
      diagnostic: _errorMessage('yt-dlp', stderr),
    );
  }

  Future<_ProcessOutput> _runCollectingOutput(
    List<String> args, {
    required Duration timeout,
  }) async {
    final generation = _generation;
    final lease = await cookies?.call();
    var succeeded = false;
    try {
      _checkGeneration(generation);
      final process = await _start([..._cookieArguments(lease), ...args]);
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();

      try {
        final exitCode = await process.exitCode.timeout(
          timeout,
          onTimeout: () {
            process.kill();
            throw const YtDlpException(
              'YouTube metadata request timed out',
              errorType: MusicQueueErrorType.networkUnavailable,
            );
          },
        );
        succeeded = exitCode == 0;
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
    } finally {
      await lease?.release(succeeded: succeeded);
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
        'in the tools folder next to the app.',
        errorType: MusicQueueErrorType.musicToolsUnavailable,
        diagnostic: 'Unable to start $executable: ${error.message}',
      );
    }
  }

  void _checkGeneration(int generation) {
    if (generation != _generation) {
      throw const YtDlpException('Music preparation canceled');
    }
  }

  static Future<Process> _startProcess(
    String executable,
    List<String> arguments,
  ) => Process.start(executable, arguments, runInShell: false);

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
    // Warnings may precede the failure, and long help URLs may follow it.
    // Keep the actual error and its beginning so the reason stays visible.
    final errorStart = RegExp(
      r'^\s*ERROR:',
      multiLine: true,
    ).firstMatch(detail);
    final relevant = errorStart == null
        ? detail
        : detail.substring(errorStart.start);
    final compact = relevant.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= 240) return '$prefix: $compact';
    return '$prefix: ${compact.substring(0, 237)}...';
  }

  @override
  Future<void> cancel() async {
    _generation++;
    _inspected = null;
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
