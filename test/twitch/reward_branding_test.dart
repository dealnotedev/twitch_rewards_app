import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/audio/audioplayer.dart';
import 'package:twitch_listener/core/autosaver.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/rewards/reward_executor.dart';
import 'package:twitch_listener/rewards/rewards_state.dart';
import 'package:twitch_listener/ui/themes.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';
import 'package:twitch_listener/twitch/twitch_shared.dart';

import 'rewards_fakes.dart';

void main() {
  late RewardTestSettings settings;
  late RewardTestApi api;
  late TwitchShared shared;
  late Autosaver autosaver;
  late TwitchRewardsController controller;

  setUp(() {
    settings = RewardTestSettings();
    api = RewardTestApi();
    shared = TwitchShared();
    autosaver = Autosaver(delay: Duration.zero);
    controller = TwitchRewardsController(
      settings: settings,
      shared: shared,
      autosaver: autosaver,
      createApi: (_) => api,
      authorize: () async => null,
    );
  });

  tearDown(() async {
    controller.dispose();
    shared.redemptions.dispose();
    await settings.authChanges.close();
  });

  Widget screen({bool dark = false}) => MaterialApp(
    theme: dark ? Themes.dark : Themes.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: RewardsStateWidget(
          settings: settings,
          twitchShared: shared,
          rewardsController: controller,
          audioplayer: Audioplayer(),
          executor: _Executor(),
          autosaver: autosaver,
        ),
      ),
    ),
  );

  void setWindow(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  for (final dark in [false, true]) {
    testWidgets(
      'brands only linked Listener rewards, including disabled and read-only, dark=$dark',
      (tester) async {
        setWindow(tester);
        final own = _linked('own', 'Music');
        final disabled = _linked('own', 'Music')..disabled = true;
        final foreign = _linked('other', 'Water');
        final anotherChannel = _linked('own', 'Music', channel: 'another');
        final missing = _linked('missing', 'Missing');
        final titleOnly = Reward(name: 'Music', handlers: []);
        settings.rewards.rewards.addAll([
          own,
          disabled,
          foreign,
          anotherChannel,
          missing,
          titleOnly,
        ]);
        api.scopes = {'channel:read:redemptions'};
        await controller.refresh();
        await tester.pumpWidget(screen(dark: dark));
        await tester.pumpAndSettle();

        Finder badge(Reward reward) => find.descendant(
          of: find.byKey(ValueKey(reward)),
          matching: find.byTooltip('Created by Listener'),
        );
        expect(badge(own), findsOneWidget);
        expect(badge(disabled), findsOneWidget);
        for (final reward in [foreign, anotherChannel, missing, titleOnly]) {
          expect(badge(reward), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'branding follows verified ownership, unlinking, and account changes',
    (tester) async {
      setWindow(tester);
      final own = _linked('own', 'Music');
      settings.rewards.rewards.add(own);
      shared.setRewards(api.entries, broadcasterId: 'channel');
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Created by Listener'), findsNothing);

      await controller.refresh();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Created by Listener'), findsOneWidget);

      own.unlinkFromTwitch();
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Created by Listener'), findsNothing);

      own.linkToTwitch(
        rewardId: 'own',
        broadcasterId: 'channel',
        title: 'Music',
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Created by Listener'), findsOneWidget);

      await settings.saveTwitchAuth(credentials('another'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Created by Listener'), findsNothing);
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Created by Listener'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Reward _linked(String id, String name, {String channel = 'channel'}) =>
    Reward(name: name, handlers: [])
      ..linkToTwitch(rewardId: id, broadcasterId: channel, title: name);

class _Executor implements RewardExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
