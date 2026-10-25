import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/audio/audioplayer.dart';
import 'package:twitch_listener/core/autosaver.dart';
import 'package:twitch_listener/ui/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/youtube_connection_controller.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/rewards/reward_configurator.dart';
import 'package:twitch_listener/rewards/reward_executor.dart';
import 'package:twitch_listener/ui/ripple_icon.dart';
import 'package:twitch_listener/ui/themes.dart';
import 'package:twitch_listener/twitch/twitch_shared.dart';

void main() {
  Future<Reward> showConfigurator(
    WidgetTester tester, {
    bool dark = true,
    double textScale = 1,
    List<RewardAction>? initialActions,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 680);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final actions =
        initialActions ??
        [
          RewardAction(
            type: RewardAction.typePlayAudios,
            randomize: true,
            count: 1,
            audios: [
              AudioEntry(path: r'C:\sounds\first.mp3'),
              AudioEntry(path: r'C:\sounds\second.mp3'),
              AudioEntry(path: r'C:\sounds\third.mp3'),
            ],
          ),
        ];
    for (final action in actions) {
      addTearDown(action.dispose);
    }
    final reward = Reward(name: 'Random sound', handlers: actions);
    final dropdowns = DropdownManager();
    addTearDown(dropdowns.clear);

    await tester.pumpWidget(
      View(
        view: _UnavailableDisplayView(
          view: tester.view,
          platformDispatcher: tester.platformDispatcher,
          display: tester.view.display,
        ),
        child: MaterialApp(
          theme: dark ? Themes.dark : Themes.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: DropdownScope(
            manager: dropdowns,
            child: Scaffold(
              body: RewardConfiguratorWidget(
                reward: reward,
                audioplayer: Audioplayer(),
                twitchShared: TwitchShared(),
                executor: _Executor(),
                youtubeConnection: _Connection(),
                musicRequests: _Requests(),
                autosaver: Autosaver(delay: Duration.zero),
              ),
            ),
          ),
        ),
      ),
      wrapWithView: false,
    );
    await tester.pump();
    return reward;
  }

  for (final dark in [false, true]) {
    testWidgets(
      'random audio configuration renders without display data, dark=$dark',
      (tester) async {
        final reward = await showConfigurator(tester, dark: dark);

        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(find.text('1 action'), findsNothing);
        expect(find.text('Link Twitch reward'), findsOneWidget);
        expect(tester.getTopLeft(find.text('Reward Name')).dy, lessThan(200));
        for (final audio in reward.handlers.single.audios) {
          expect(find.text(audio.path).hitTestable(), findsOneWidget);
        }
      },
    );
  }

  testWidgets('reactions can still be added and deleted without the summary', (
    tester,
  ) async {
    final reward = await showConfigurator(tester);
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is RippleIcon &&
                widget.icon == Assets.assetsIcDeleteWhite16dp,
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(reward.handlers, isEmpty);
    expect(find.text('0 actions'), findsNothing);

    await tester.tap(find.text('Add New Reaction'));
    await tester.pump();
    await tester.tap(find.text('Delay'));
    await tester.pumpAndSettle();
    expect(reward.handlers.single.type, RewardAction.typeDelay);
    expect(find.text('1 action'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('link controls fit larger text at the minimum window width', (
    tester,
  ) async {
    await showConfigurator(tester, textScale: 2);
    expect(find.text('Link Twitch reward'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging reactions down and up preserves their order', (
    tester,
  ) async {
    final first = RewardAction(type: RewardAction.typeDelay, millis: 1000);
    final second = RewardAction(type: RewardAction.typeDelay, millis: 2000);
    final third = RewardAction(type: RewardAction.typeDelay, millis: 3000);
    final reward = await showConfigurator(
      tester,
      initialActions: [first, second, third],
    );
    tester.view.physicalSize = const Size(640, 1400);
    await tester.pumpAndSettle();

    Future<void> dragReaction(Finder handle, double targetY) async {
      final start = tester.getCenter(handle);
      final drag = await tester.startGesture(start);
      await tester.pump();
      await drag.moveBy(Offset(0, targetY > start.dy ? 20 : -20));
      await tester.pump();
      await drag.moveTo(Offset(start.dx, targetY));
      await tester.pumpAndSettle();
      await drag.up();
      await tester.pumpAndSettle();
    }

    final handles = find.byType(ReorderableDragStartListener);
    await dragReaction(
      handles.first,
      tester.getBottomLeft(find.byKey(ValueKey(third.id))).dy +
          tester.getSize(find.byKey(ValueKey(third.id))).height,
    );
    expect(reward.handlers.map((action) => action.millis), [2000, 3000, 1000]);

    await dragReaction(
      handles.last,
      tester.getTopLeft(find.byKey(ValueKey(second.id))).dy -
          tester.getSize(find.byKey(ValueKey(second.id))).height,
    );
    expect(reward.handlers.map((action) => action.millis), [1000, 2000, 3000]);
    expect(tester.takeException(), isNull);
  });
}

// FlutterView.display can throw when the engine has no matching display record.
// The configurator must not need display metadata to show a reward's settings.
class _UnavailableDisplayView extends TestFlutterView {
  _UnavailableDisplayView({
    required super.view,
    required super.platformDispatcher,
    required super.display,
  });

  @override
  TestDisplay get display =>
      throw StateError('Display metadata is unavailable');
}

class _Executor implements RewardExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Connection implements YoutubeConnectionController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Requests implements MusicRequestManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
