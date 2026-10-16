import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/autosaver.dart';
import 'package:twitch_listener/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/youtube_connection_controller.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_configurator.dart';
import 'package:twitch_listener/reward_executor.dart';
import 'package:twitch_listener/ripple_icon.dart';
import 'package:twitch_listener/themes.dart';
import 'package:twitch_listener/twitch_shared.dart';

void main() {
  Future<Reward> showConfigurator(
    WidgetTester tester, {
    bool dark = true,
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 680);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final action = RewardAction(
      type: RewardAction.typePlayAudios,
      randomize: true,
      count: 1,
      audios: [
        AudioEntry(path: r'C:\sounds\first.mp3'),
        AudioEntry(path: r'C:\sounds\second.mp3'),
        AudioEntry(path: r'C:\sounds\third.mp3'),
      ],
    );
    addTearDown(action.dispose);
    final reward = Reward(name: 'Random sound', handlers: [action]);
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
        expect(find.text('1 action'), findsOneWidget);
        expect(tester.getTopLeft(find.text('Reward Name')).dy, lessThan(200));
        for (final audio in reward.handlers.single.audios) {
          expect(find.text(audio.path).hitTestable(), findsOneWidget);
        }
      },
    );
  }

  testWidgets('action count follows adding and deleting reactions', (
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
    expect(find.text('0 actions'), findsOneWidget);

    await tester.tap(find.text('Add New Reaction'));
    await tester.pump();
    await tester.tap(find.text('Delay'));
    await tester.pumpAndSettle();
    expect(reward.handlers.single.type, RewardAction.typeDelay);
    expect(find.text('1 action'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary fits larger text at the minimum window width', (
    tester,
  ) async {
    await showConfigurator(tester, textScale: 2);
    expect(find.text('1 action'), findsOneWidget);
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
