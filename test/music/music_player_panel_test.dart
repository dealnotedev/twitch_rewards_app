import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/actions/volume_slider.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/music/music_player_panel.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/themes.dart';

import 'fakes.dart';

void main() {
  late FakePlayer player;
  late MusicRequestManager manager;

  void initialize({FakeFetcher? fetcher}) {
    player = FakePlayer();
    manager =
        MusicRequestManager(fetcher: fetcher ?? FakeFetcher(), player: player);
  }

  Future<void> closeInWidgetZone(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final closing = manager.close();
    await tester.pump();
    await closing;
  }

  Widget app({bool dark = false, Widget? page}) => MaterialApp(
      theme: dark ? Themes.dark : Themes.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: Column(children: [
        Expanded(child: page ?? const SizedBox()),
        MusicPlayerPanel(requests: manager),
      ])));

  testWidgets('hidden when idle, errors visible even without a track',
      (tester) async {
    initialize();
    await tester.pumpWidget(app());
    expect(find.byIcon(Icons.music_note_rounded), findsNothing);
    manager.enqueue('bad');
    await tester.pump();
    expect(
        find.text('Enter a link to a single YouTube video.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('music-dismiss-error')));
    await tester.pump();
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    await closeInWidgetZone(tester);
  });

  for (final width in [360.0, 640.0, 1100.0]) {
    testWidgets('player fits width $width and controls the shared queue',
        (tester) async {
      initialize();
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      manager.enqueue(firstUrl, requester: 'Viewer A');
      manager.enqueue(secondUrl, requester: 'Viewer B');
      await tester.pumpWidget(app(dark: width == 640));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Track aaaaaaaaaaa'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byTooltip('Next track'), findsOneWidget);
      expect(find.byTooltip('Music queue'), findsOneWidget);
      expect(tester.getCenter(find.byKey(const ValueKey('music-cover'))).dy,
          tester.getCenter(find.byKey(const ValueKey('music-pause'))).dy);
      await tester.tap(find.byKey(const ValueKey('music-pause')));
      await tester.pumpAndSettle();
      expect(manager.current.nowPlaying!.paused, isTrue);
      expect(find.byTooltip('Resume'), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('music-queue')),
          matching: find.text('1')));
      await tester.pumpAndSettle();
      expect(find.text('Track bbbbbbbbbbb'), findsOneWidget);
      final volume = tester.widget<VolumeSlider>(find.byType(VolumeSlider));
      volume.onChangeChange!(.27);
      volume.onChangeEnd!(.27);
      await tester.pumpAndSettle();
      expect(player.volume, .27);
      expect(find.text('27%'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('music-next')));
      await tester.pumpAndSettle();
      expect(manager.current.nowPlaying!.item.requestedBy, 'Viewer B');
      expect(tester.takeException(), isNull);
      await closeInWidgetZone(tester);
    });
  }

  testWidgets('panel and playback survive navigation and route pop',
      (tester) async {
    initialize();
    manager.enqueue(firstUrl);
    await tester.pumpWidget(app(
        page: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
                builder: (context) => Center(
                    child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => Center(
                                    child: TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Back'))))),
                        child: const Text('Edit reward')))))));
    await tester.pumpAndSettle();
    final id = manager.current.nowPlaying!.item.id;
    await tester.tap(find.text('Edit reward'));
    await tester.pumpAndSettle();
    expect(find.text('Track aaaaaaaaaaa'), findsOneWidget);
    expect(find.byKey(const ValueKey('music-pause')), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(manager.current.nowPlaying!.item.id, id);
    expect(player.played, hasLength(1));
    await closeInWidgetZone(tester);
  });

  testWidgets('pending download is visible and removable before playback',
      (tester) async {
    final fetcher = FakeFetcher()..downloadGate = Completer();
    initialize(fetcher: fetcher);
    manager.enqueue(firstUrl);
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('music-queue')));
    await tester.pump();
    await tester.tap(
        find.byKey(ValueKey('music-remove-${manager.current.queue.first.id}')));
    await tester.pumpAndSettle();
    expect(manager.current.queue, isEmpty);
    expect(player.played, isEmpty);
    await closeInWidgetZone(tester);
  });

  testWidgets('analysis and normalization display their own progress',
      (tester) async {
    final fetcher = FakeFetcher()..downloadGate = Completer();
    initialize(fetcher: fetcher);
    manager.enqueue(firstUrl);
    await tester.pumpWidget(app());
    await tester.pump();
    fetcher.reportProgress!(const MusicPreparationProgress(
        phase: MusicQueueItemPhase.analyzing, fraction: .4));
    await tester.pump();
    await tester.pump();
    expect(find.text('Analyzing loudness… 40%'), findsOneWidget);
    fetcher.reportProgress!(const MusicPreparationProgress(
        phase: MusicQueueItemPhase.normalizing, fraction: .2));
    await tester.pump();
    await tester.pump();
    expect(find.text('Normalizing audio… 20%'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        .2);
    await closeInWidgetZone(tester);
  });
}
