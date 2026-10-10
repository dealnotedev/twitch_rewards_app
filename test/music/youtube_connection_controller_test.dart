import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/yt_dlp_music_track_fetcher.dart';
import 'package:twitch_listener/music/youtube_browser_session.dart';
import 'package:twitch_listener/music/youtube_connection_controller.dart';

const _cookies = [
  {
    'domain': '.youtube.com',
    'name': 'test_session',
    'value': 'fake-value',
    'path': '/',
    'httpOnly': true,
    'secure': true,
    'expires': -1,
  },
  {'domain': '.google.com', 'name': 'other-site', 'value': 'must-not-save'},
];

void main() {
  late Directory directory;
  late _Browser browser;
  YoutubeConnectionController? controller;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('youtube_connection_');
    browser = _Browser();
  });
  tearDown(() async {
    await controller?.close();
    await directory.delete(recursive: true);
  });

  File savedSession() => File('${directory.path}/cookies.txt');

  Future<void> saveSession(String content) =>
      savedSession().writeAsString(content);

  test('checks the video selected in the browser after restart', () async {
    final selected = Uri.parse('https://www.youtube.com/watch?v=selected123');
    controller = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, url, _) async {
        if (url != selected) {
          // Actual output of the formerly hardcoded public test clip.
          throw const YtDlpException(
            'This YouTube video is unavailable. Please choose another.',
            errorType: MusicQueueErrorType.youtubeUnavailable,
            diagnostic: 'yt-dlp: ERROR: [youtube] BaW_jenozKc: This video is unavailable',
          );
        }
      },
    );
    await controller!.connect();
    browser.selectedUrl = selected;
    await controller!.verify();
    expect(
      controller!.status,
      YoutubeConnectionStatus.connected,
      reason: 'A removed test clip must not reject the playable browser video',
    );
  });

  for (final failure in {
    MusicQueueErrorType.youtubeUnavailable: 'videoUnavailable',
    MusicQueueErrorType.youtubeDownloadBlocked: 'downloadBlocked',
    MusicQueueErrorType.youtubeRateLimited: 'rateLimited',
    MusicQueueErrorType.trackTooLongOrLive: 'videoTooLongOrLive',
    MusicQueueErrorType.networkUnavailable: 'networkUnavailable',
    MusicQueueErrorType.musicToolsUnavailable: 'toolsUnavailable',
  }.entries) {
    test('keeps the actionable reason ${failure.key.name}', () async {
      controller = YoutubeConnectionController(
        directory: directory,
        browser: browser,
        toolVersion: () async => '2026.08.19',
        verifyAccess: (_, _, _) async => throw YtDlpException(
          'failure',
          errorType: failure.key,
          exitCode: 1,
          diagnostic: 'ERROR: preparation failed https://media.test/file?token=secret token=secret',
        ),
      );
      await controller!.connect();
      await controller!.verify();
      expect(controller!.issue?.name, failure.value);
      expect(controller!.checkedVideoUrl, browser.selectedUrl);
      expect(controller!.diagnostic, contains('ERROR: preparation failed'));
      expect(controller!.diagnostic, contains('yt-dlp 2026.08.19'));
      expect(controller!.diagnostic, isNot(contains('secret')));
      expect(controller!.cookieFilePath, isNull);
      // The browser was closed for the check; reopening returns to the video.
      expect(controller!.status, YoutubeConnectionStatus.disconnected);
      await controller!.connect();
      expect(browser.url, browser.selectedUrl);
      expect(controller!.diagnostic, isNull);
    });
  }

  test(
    'saves only YouTube after verification and restores it on restart',
    () async {
      final blockedUrl = Uri.parse('https://youtu.be/blocked');
      var checked = false;
      var connected = 0;
      final progress = <double?>[];
      controller = YoutubeConnectionController(
        directory: directory,
        browser: browser,
        onConnected: () => connected++,
        verifyAccess: (file, url, onProgress) async {
          expect(url, blockedUrl);
          expect(
            await File(file).readAsString(),
            contains('test_session\tfake-value'),
          );
          expect(
            await File(file).readAsString(),
            isNot(contains('google.com')),
          );
          expect(controller!.cookieFilePath, isNull);
          expect(
            browser.closed,
            isTrue,
            reason: 'An open YouTube tab rotates the exported cookies',
          );
          onProgress(
            const MusicPreparationProgress(
              phase: MusicQueueItemPhase.downloading,
              fraction: .25,
            ),
          );
          progress.add(controller!.checkProgress);
          checked = true;
        },
      );
      controller!.requireCheck(
        MusicQueueErrorType.youtubeAccessRequired,
        blockedUrl,
      );
      expect(controller!.issue, YoutubeConnectionIssue.verificationRequired);
      await controller!.connect();
      expect(browser.url, blockedUrl);
      expect(controller!.status, YoutubeConnectionStatus.awaitingVerification);
      await controller!.verify();
      expect(checked, isTrue);
      expect(progress, [0.25]);
      expect(controller!.checkProgress, isNull);
      expect(controller!.status, YoutubeConnectionStatus.connected);
      expect(controller!.verifiedThisSession, isTrue);
      expect(controller!.issue, isNull);
      expect(connected, 1);
      final saved = controller!.cookieFilePath!;
      expect(await File('$saved.pending').exists(), isFalse);
      await controller!.close();
      controller = YoutubeConnectionController(
        directory: directory,
        browser: browser,
        verifyAccess: (_, _, _) async {},
      );
      expect(controller!.cookieFilePath, saved);
      expect(controller!.status, YoutubeConnectionStatus.connected);
      expect(controller!.verifiedThisSession, isFalse);
      final profile = Directory('${directory.path}/browser');
      await profile.create();
      await File('${profile.path}/app-session').writeAsString('test');
      await controller!.disconnect();
      expect(controller!.cookieFilePath, isNull);
      expect(await File(saved).exists(), isFalse);
      expect(await profile.exists(), isFalse);
    },
  );

  test(
    'failed verification does not save a session or falsely show connected',
    () async {
      controller = YoutubeConnectionController(
        directory: directory,
        browser: browser,
        verifyAccess: (_, _, _) async => throw const MusicTrackException(
          'challenge',
          errorType: MusicQueueErrorType.youtubeAccessRequired,
        ),
      );
      await controller!.connect();
      await controller!.verify();
      expect(controller!.status, YoutubeConnectionStatus.disconnected);
      expect(controller!.issue, YoutubeConnectionIssue.verificationRequired);
      expect(controller!.cookieFilePath, isNull);
      expect(await directory.list().toList(), isEmpty);
      expect(browser.closed, isTrue);
    },
  );

  test('a browser problem before export keeps the window for fixing', () async {
    controller = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, _, _) async {},
    );
    await controller!.connect();
    browser.error = const YoutubeConnectionException(
      YoutubeConnectionIssue.chooseVideo,
    );
    await controller!.verify();
    expect(controller!.status, YoutubeConnectionStatus.awaitingVerification);
    expect(controller!.issue, YoutubeConnectionIssue.chooseVideo);
    expect(browser.closed, isFalse);
  });

  test('closed browser offers reconnection', () async {
    browser.error = const YoutubeConnectionException(
      YoutubeConnectionIssue.browserClosed,
    );
    controller = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, _, _) async {},
    );
    await controller!.connect();
    await controller!.verify();
    expect(controller!.issue, YoutubeConnectionIssue.browserClosed);
    browser.error = null;
    await controller!.connect();
    await controller!.verify();
    expect(controller!.status, YoutubeConnectionStatus.connected);
  });

  test('cancel closes the browser and keeps the saved session', () async {
    await saveSession('saved');
    controller = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, _, _) async {},
    );
    expect(controller!.status, YoutubeConnectionStatus.connected);
    await controller!.connect();
    expect(controller!.status, YoutubeConnectionStatus.awaitingVerification);
    await controller!.cancel();
    expect(controller!.status, YoutubeConnectionStatus.connected);
    expect(browser.closed, isTrue);
    expect(await savedSession().readAsString(), 'saved');
  });

  test('cancelling a running check keeps the saved session', () async {
    await saveSession('saved');
    final entered = Completer<void>();
    final result = Completer<void>();
    controller = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, _, _) {
        entered.complete();
        return result.future;
      },
      cancelVerification: () async {
        if (!result.isCompleted) result.complete();
      },
    );
    await controller!.connect();
    final verification = controller!.verify();
    await entered.future;
    await controller!.cancel();
    await verification;
    expect(controller!.status, YoutubeConnectionStatus.connected);
    expect(await savedSession().readAsString(), 'saved');
    expect(await File('${savedSession().path}.pending').exists(), isFalse);
  });

  test('a music request block keeps a saved session in use', () async {
    await saveSession('saved');
    final url = Uri.parse('https://youtu.be/blocked');
    controller = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, _, _) async {},
    );
    controller!.requireCheck(MusicQueueErrorType.youtubeDownloadBlocked, url);
    expect(controller!.status, YoutubeConnectionStatus.connected);
    expect(controller!.issue, YoutubeConnectionIssue.downloadBlocked);
    expect(controller!.cookieFilePath, isNotNull);
    await controller!.connect();
    expect(browser.url, url);
    await controller!.cancel();
    expect(
      controller!.issue,
      YoutubeConnectionIssue.downloadBlocked,
      reason: 'Cancelling does not hide why requests are paused',
    );
  });

  test('a successful run writes cookie updates back', () async {
    await saveSession('saved');
    controller = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, _, _) async {},
    );
    final failed = (await controller!.leaseCookies())!;
    expect(await File(failed.path).readAsString(), 'saved');
    await File(failed.path).writeAsString('failed run');
    await failed.release(succeeded: false);
    expect(await savedSession().readAsString(), 'saved');

    final succeeded = (await controller!.leaseCookies())!;
    await File(succeeded.path).writeAsString('updated by yt-dlp');
    await succeeded.release(succeeded: true);
    expect(await savedSession().readAsString(), 'updated by yt-dlp');
    expect(await File(failed.path).exists(), isFalse);
    expect(await File(succeeded.path).exists(), isFalse);
  });

  test('removes copies left by interrupted runs but not active ones', () async {
    await saveSession('saved');
    final stale = File('${directory.path}/runs/interrupted.txt');
    await stale.create(recursive: true);
    controller = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, _, _) async {},
    );
    final active = (await controller!.leaseCookies())!;
    expect(await stale.exists(), isFalse);
    await stale.create(recursive: true);
    await controller!.disconnect();
    expect(await stale.exists(), isFalse);
    expect(await File(active.path).exists(), isTrue);
    await active.release(succeeded: true);
    expect(await File(active.path).exists(), isFalse);
  });

  test('a run that outlives disconnect does not restore the session', () async {
    await saveSession('saved');
    controller = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, _, _) async {},
    );
    final lease = (await controller!.leaseCookies())!;
    await controller!.disconnect();
    await File(lease.path).writeAsString('stale');
    await lease.release(succeeded: true);
    expect(await savedSession().exists(), isFalse);
    expect(controller!.cookieFilePath, isNull);
    expect(await controller!.leaseCookies(), isNull);
  });

  test('a run that outlives reconnection keeps the new session', () async {
    await saveSession('old');
    controller = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, _, _) async {},
    );
    final lease = (await controller!.leaseCookies())!;
    await controller!.connect();
    await controller!.verify();
    await File(lease.path).writeAsString('stale');
    await lease.release(succeeded: true);
    expect(
      await savedSession().readAsString(),
      contains('test_session\tfake-value'),
    );
  });

  test(
    'shutdown cancels an in-flight check and never saves its cookies',
    () async {
      final entered = Completer<void>();
      final result = Completer<void>();
      controller = YoutubeConnectionController(
        directory: directory,
        browser: browser,
        verifyAccess: (_, _, _) {
          entered.complete();
          return result.future;
        },
        cancelVerification: () async {
          if (!result.isCompleted) result.complete();
        },
      );
      await controller!.connect();
      final verification = controller!.verify();
      await entered.future;
      await controller!.close();
      await verification;
      expect(controller!.cookieFilePath, isNull);
      expect(await directory.list().toList(), isEmpty);
    },
  );

  test('cookie export rejects unrelated and injected domains', () {
    final output = youtubeCookiesToNetscape([
      ..._cookies,
      {'domain': '.youtube.com.evil.test', 'name': 'wrong', 'value': 'x'},
      {
        'domain': '.youtube.com',
        'name': 'injection',
        'value': 'x\n.evil.test\tTRUE',
      },
    ]);
    expect(
      output,
      '# Netscape HTTP Cookie File\r\n'
      '#HttpOnly_.youtube.com\tTRUE\t/\tTRUE\t0\ttest_session\tfake-value\r\n',
    );
    expect(
      () => youtubeCookiesToNetscape([_cookies.last]),
      throwsA(isA<YoutubeConnectionException>()),
    );
  });
}

class _Browser implements YoutubeBrowserSession {
  Uri? url;
  Uri? selectedUrl;
  bool closed = false;
  Object? error;

  @override
  Future<void> open(Uri value) async {
    url = value;
    selectedUrl = value.path == '/watch' || value.host == 'youtu.be'
        ? value
        : Uri.parse('https://www.youtube.com/watch?v=4YFu4dvMHHY');
    closed = false;
  }

  @override
  Future<Uri> readYoutubeVideoUrl() async {
    if (error != null) throw error!;
    return selectedUrl!;
  }

  @override
  Future<List<Map<String, dynamic>>> readYoutubeCookies() async {
    if (error != null) throw error!;
    return _cookies;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
