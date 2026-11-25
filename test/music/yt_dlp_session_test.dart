import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/music/ffmpeg_audio_processor.dart';
import 'package:twitch_listener/music/music_file_cache.dart';
import 'package:twitch_listener/music/music_models.dart';
import 'package:twitch_listener/music/yt_dlp_music_track_fetcher.dart';

import 'fake_music_process.dart';
import 'fakes.dart';

void main() {
  late Directory root;
  late FfmpegAudioProcessor processor;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('yt_dlp_session_');
    var pass = 0;
    processor = FfmpegAudioProcessor(
      executable: 'ffmpeg',
      processStarter: (_, args) async {
        if (++pass % 2 == 1) {
          return TestAudioProcess.completed(
            stderr:
                '{"input_i":"-25","input_tp":"-8","input_lra":"4",'
                '"input_thresh":"-35","target_offset":"0"}',
          );
        }
        await File(args.last).writeAsBytes([7, 8, 9]);
        return TestAudioProcess.completed();
      },
    );
  });
  tearDown(() => root.delete(recursive: true));

  YtDlpMusicTrackFetcher fetcher(
    MusicProcessStarter starter, {
    YtDlpCookieSource? cookies,
  }) => YtDlpMusicTrackFetcher(
    executable: 'yt-dlp',
    denoPath: null,
    audioProcessor: processor,
    cache: MusicFileCache(
      rootDirectory: root,
      maxBytes: 0,
      profileName: processor.cacheProfile,
    ),
    cookies: cookies,
    processStarter: starter,
  );

  test(
    'leases cookies per run and downloads using inspected metadata',
    () async {
      final argsByRun = <List<String>>[];
      final released = <bool>[];
      final sourceJson = jsonEncode({
        'id': 'aaaaaaaaaaa',
        'title': 'Track',
        'duration': 60,
        'uploader': 'Artist',
      });
      var leases = 0;
      final downloader = fetcher((_, args) async {
        argsByRun.add(args);
        if (args.contains('--skip-download')) {
          return TestAudioProcess.completed(stdout: sourceJson);
        }
        expect(
          jsonDecode(
            await File(args[args.indexOf('--load-info-json') + 1])
                .readAsString(),
          ),
          containsPair('id', 'aaaaaaaaaaa'),
        );
        expect(args, isNot(contains(firstUrl)));
        final audio = File('${args[args.indexOf('--paths') + 1]}/audio.webm');
        await audio.writeAsBytes([1, 2, 3]);
        return TestAudioProcess.completed(stdout: 'YT_FILE:${audio.path}\n');
      }, cookies: () async => _Lease('run ${++leases}.txt', released.add));
      final track = await downloader.inspect(Uri.parse(firstUrl));
      final audio = await downloader.obtain(
        metadata: track,
        onProgress: (_) {},
      );
      expect(await File(audio).readAsBytes(), [7, 8, 9]);
      expect(argsByRun[0][argsByRun[0].indexOf('--cookies') + 1], 'run 1.txt');
      expect(argsByRun[1][argsByRun[1].indexOf('--cookies') + 1], 'run 2.txt');
      expect(
        argsByRun.expand((a) => a),
        isNot(contains('--cookies-from-browser')),
      );
      expect(released, [true, true]);
    },
  );

  test(
    'failed media retrieval releases cookies without saving changes',
    () async {
      final released = <bool>[];
      final downloader = fetcher(
        (_, _) async => TestAudioProcess.completed(
          exitCode: 1,
          stderr:
              'ERROR: unable to download video data: HTTP Error 403: Forbidden',
        ),
        cookies: () async => _Lease('session.txt', released.add),
      );
      await expectLater(
        downloader.obtain(
          metadata: metadata(Uri.parse(firstUrl)),
          onProgress: (_) {},
        ),
        throwsA(
          isA<YtDlpException>().having(
            (e) => e.errorType,
            'reason',
            MusicQueueErrorType.youtubeDownloadBlocked,
          ),
        ),
      );
      expect(released, [false]);
    },
  );

  test('cancel during cookie leasing never starts a stale process', () async {
    final leaseReady = Completer<YtDlpCookieLease?>();
    final released = <bool>[];
    var started = 0;
    final downloader = fetcher((_, _) async {
      started++;
      return TestAudioProcess.completed();
    }, cookies: () => leaseReady.future);
    final inspecting = downloader.inspect(Uri.parse(firstUrl));
    final expectation = expectLater(inspecting, throwsA(isA<YtDlpException>()));
    await downloader.cancel();
    leaseReady.complete(_Lease('stale.txt', released.add));
    await expectation;
    expect(started, 0);
    expect(released, [false]);
  });

  test('classifies the actual error independently of preceding warnings', () {
    final cases = {
      "Sign in to confirm you're not a bot. Use --cookies":
          MusicQueueErrorType.youtubeAccessRequired,
      'unable to download video data: HTTP Error 403: Forbidden':
          MusicQueueErrorType.youtubeDownloadBlocked,
      "This content isn't available, try again later":
          MusicQueueErrorType.youtubeRateLimited,
      'HTTP Error 429: Too Many Requests':
          MusicQueueErrorType.youtubeRateLimited,
      'Private video. Sign in. Use --cookies':
          MusicQueueErrorType.youtubeUnavailable,
      'Sign in to confirm your age. Use --cookies':
          MusicQueueErrorType.youtubeUnavailable,
      'Video unavailable': MusicQueueErrorType.youtubeUnavailable,
      'Unable to download webpage: connection refused':
          MusicQueueErrorType.networkUnavailable,
      'No supported JavaScript runtime':
          MusicQueueErrorType.musicToolsUnavailable,
    };
    for (final entry in cases.entries) {
      expect(
        YtDlpMusicTrackFetcher.classifyFailure(
          'WARNING: cookies are no longer valid\nERROR: ${entry.key}',
        ),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('reports and caches the installed downloader version', () async {
    var starts = 0;
    final downloader = fetcher((_, args) async {
      starts++;
      expect(args, contains('--version'));
      return TestAudioProcess.completed(stdout: '2026.08.19\r\n');
    });
    expect(await downloader.readVersion(), '2026.08.19');
    expect(await downloader.readVersion(), '2026.08.19');
    expect(starts, 1);
  });
}

class _Lease implements YtDlpCookieLease {
  @override
  final String path;
  final void Function(bool) onRelease;
  _Lease(this.path, this.onRelease);
  @override
  Future<void> release({required bool succeeded}) async => onRelease(succeeded);
}
