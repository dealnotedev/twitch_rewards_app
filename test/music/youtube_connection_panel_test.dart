import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/youtube_browser_session.dart';
import 'package:twitch_listener/music/youtube_connection_controller.dart';
import 'package:twitch_listener/music/youtube_connection_panel.dart';
import 'package:twitch_listener/ui/themes.dart';

import 'fakes.dart';

void main() {
  late Directory directory;
  late FakeFetcher fetcher;
  late MusicRequestManager requests;
  late YoutubeConnectionController connection;
  late _Browser browser;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('youtube_panel_');
    browser = _Browser();
    connection = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, _, _) async {},
      onConnected: () => requests.resumePreparation(),
    );
  });
  void initialize() {
    fetcher = FakeFetcher();
    requests = MusicRequestManager(
      fetcher: fetcher,
      player: FakePlayer(),
      onPreparationHeld: connection.requireCheck,
    );
  }

  tearDown(() async {
    // This browser is resource-free. Async shutdown is covered by controller tests.
    connection.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> closeInWidgetZone(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final closing = requests.close();
    var closed = false;
    closing.then((_) => closed = true);
    for (var attempt = 0; attempt < 10 && !closed; attempt++) {
      // Verification runs real file I/O; let its playback futures finish too.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(closed, isTrue);
    await closing;
  }

  Widget app({bool dark = false, double scale = 1}) => MaterialApp(
    theme: dark ? Themes.dark : Themes.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: YoutubeConnectionPanel(
            connection: connection,
            requests: requests,
          ),
        ),
      ),
    ),
  );

  for (final width in [280.0, 520.0]) {
    testWidgets('connection states fit width $width with larger text', (
      tester,
    ) async {
      initialize();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        for (final status in YoutubeConnectionStatus.values) {
          connection.status = status;
          await tester.pumpWidget(app(dark: dark, scale: 2));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$status, dark=$dark');
          expect(find.text('YouTube connection'), findsOneWidget);
        }
      }
      await closeInWidgetZone(tester);
    });
  }

  testWidgets('connect, verify and confirm session removal', (tester) async {
    initialize();
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const ValueKey('music_youtube_connect')));
    await tester.pump();
    expect(browser.opened, isTrue);
    expect(find.byKey(const ValueKey('music_youtube_verify')), findsOneWidget);
    await tester.runAsync(() => connection.verify());
    await tester.pump();
    expect(connection.verifiedThisSession, isTrue);
    expect(browser.closed, isTrue);
    await tester.tap(find.byKey(const ValueKey('music_youtube_disconnect')));
    await tester.pump();
    expect(connection.hasSession, isTrue);
    await tester.tap(
      find.byKey(const ValueKey('music_youtube_disconnect_keep')),
    );
    await tester.pump();
    expect(connection.hasSession, isTrue);
    await tester.tap(find.byKey(const ValueKey('music_youtube_disconnect')));
    await tester.pump();
    final remove = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('music_youtube_disconnect_remove')),
        matching: find.byType(TextButton),
      ),
    );
    await tester.runAsync(() async {
      remove.onPressed!();
      for (var attempt = 0; attempt < 50 && connection.busy; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    expect(connection.hasSession, isFalse);
    expect(
      find.byKey(const ValueKey('music_youtube_disconnect')),
      findsNothing,
    );
    await closeInWidgetZone(tester);
  });

  testWidgets('holds queue and resumes automatically after verification', (
    tester,
  ) async {
    initialize();
    await tester.pumpWidget(app());
    fetcher.inspectError = const MusicTrackException(
      'bot check',
      errorType: MusicQueueErrorType.youtubeAccessRequired,
    );
    requests.enqueue(firstUrl);
    requests.enqueue(secondUrl);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('music_youtube_hold')), findsOneWidget);
    expect(requests.current.queue, hasLength(2));
    await tester.tap(find.byKey(const ValueKey('music_youtube_connect')));
    await tester.pump();
    await tester.runAsync(() => connection.verify());
    await tester.pump();
    await tester.pump();
    expect(requests.current.hold, isNull);
    expect(requests.current.nowPlaying, isNotNull);
    expect(find.byKey(const ValueKey('music_youtube_hold')), findsNothing);
    await closeInWidgetZone(tester);
  });
}

class _Browser implements YoutubeBrowserSession {
  bool opened = false;
  bool closed = false;
  @override
  Future<void> open(Uri url) async {
    opened = true;
    closed = false;
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<Uri> readYoutubeVideoUrl() async => Uri.parse(firstUrl);
  @override
  Future<List<Map<String, dynamic>>> readYoutubeCookies() async => [
    {'domain': '.youtube.com', 'name': 'session', 'value': 'fake'},
  ];
}
