import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/app_router.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/autosaver.dart';
import 'package:twitch_listener/custom_switch.dart';
import 'package:twitch_listener/di/service_locator.dart';
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
import 'package:twitch_listener/twitch/reward_catalog.dart';
import 'package:twitch_listener/twitch/reward_editor.dart';
import 'package:twitch_listener/twitch/reward_form_field.dart';
import 'package:twitch_listener/twitch/reward_settings.dart';
import 'package:twitch_listener/twitch/reward_page.dart';
import 'package:twitch_listener/twitch/reward_color_picker.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';
import 'package:twitch_listener/twitch_shared.dart';

import 'rewards_fakes.dart';

void main() {
  late Reward reward;
  late RewardTestApi api;
  late TwitchRewardsController controller;

  Future<void> showEditor(
    WidgetTester tester, {
    bool dark = false,
    bool linked = false,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final action = RewardAction(type: RewardAction.typeDelay, millis: 3000);
    reward = Reward(name: 'Manual', handlers: [action]);
    addTearDown(action.dispose);
    if (linked) {
      reward.linkToTwitch(
        rewardId: 'own',
        broadcasterId: 'channel',
        title: 'Music',
      );
    }
    final settings = RewardTestSettings(localRewards: [reward]);
    api = RewardTestApi();
    final shared = TwitchShared();
    final autosaver = Autosaver(delay: Duration.zero);
    controller = TwitchRewardsController(
      settings: settings,
      shared: shared,
      autosaver: autosaver,
      createApi: (_) => api,
      authorize: () async => null,
    );
    addTearDown(() async {
      controller.dispose();
      shared.redemptions.dispose();
      await settings.authChanges.close();
    });
    await controller.refresh();
    final router = ApplicationRouter(locator: _Locator(controller));
    final dropdowns = DropdownManager();
    addTearDown(dropdowns.clear);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? Themes.dark : Themes.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [router],
        onGenerateRoute: router.routerFactory,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: DropdownScope(manager: dropdowns, child: child!),
          ),
        ),
        home: RewardConfiguratorWidget(
          reward: reward,
          audioplayer: Audioplayer(),
          twitchShared: shared,
          executor: _Executor(),
          youtubeConnection: _Connection(),
          musicRequests: _Requests(),
          autosaver: autosaver,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
      'fullscreen selection, ID lock and unlink preserve the chain, dark=$dark',
      (tester) async {
        await showEditor(tester, dark: dark);
        final action = reward.handlers.single;
        await tester.tap(find.text('Link Twitch reward'));
        await tester.pumpAndSettle();
        expect(find.byType(TwitchRewardCatalog), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(
          tester.getCenter(find.text('Save')).dy,
          tester.getCenter(find.text('Refresh')).dy,
        );
        expect(
          tester.getCenter(find.text('Save')).dx,
          greaterThan(tester.getCenter(find.text('Refresh')).dx),
        );
        expect(
          tester.getSize(find.byType(TwitchRewardPage)),
          const Size(640, 720),
        );
        expect(find.text('Created by Listener'), findsOneWidget);
        expect(find.text('Other channel rewards'), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);
        final name = tester.widget<Text>(find.text('Water'));
        expect(name.maxLines, 1);
        expect(name.overflow, TextOverflow.ellipsis);
        expect(
          tester.getCenter(find.text('Water')).dy,
          closeTo(
            tester
                .getCenter(
                  find.byKey(const ValueKey('twitch-reward-price-other')),
                )
                .dy,
            1,
          ),
        );
        final card = tester.getRect(
          find.byKey(const ValueKey('twitch-reward-row-other')),
        );
        await tester.tapAt(Offset(card.right - 4, card.center.dy));
        await tester.pump();
        expect(find.text('Water'), findsOneWidget);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(reward.twitchRewardId, 'other');
        expect(reward.twitchBroadcasterId, 'channel');
        expect(reward.name, 'Water');
        expect(reward.handlers.single, same(action));
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('reward-name')))
              .enabled,
          isFalse,
        );
        expect(find.text('Linked to Twitch'), findsOneWidget);
        await tester.tap(find.text('Unlink'));
        await tester.pumpAndSettle();
        expect(reward.isLinked, isFalse);
        expect(reward.name, 'Water');
        expect(reward.handlers.single, same(action));
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('reward-name')))
              .enabled,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'creation selects the reward and links only after saving the catalog',
    (tester) async {
      await showEditor(tester);
      for (var index = 0; index < 16; index++) {
        final id = 'extra-$index';
        api.entries.add(remoteReward(id, 'Extra reward $index', cost: 1));
        api.owned.add(id);
      }
      final action = reward.handlers.single;
      await tester.tap(find.text('Link Twitch reward'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create reward'));
      await tester.pumpAndSettle();
      expect(find.byType(TwitchRewardEditor), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(
        tester.getSize(find.byType(TwitchRewardPage)),
        const Size(640, 720),
      );
      expect(find.byType(RewardColorPicker), findsOneWidget);
      expect(
        tester.getCenter(find.text('Save')).dy,
        lessThan(tester.getTopLeft(find.text('Basic Settings')).dy),
      );
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Availability and limits'), findsOneWidget);
      String? savedColor;
      bool? savedInput;
      api.save = (id, value) async {
        savedColor = value.color;
        savedInput = value.inputRequired;
        return remoteReward('created', value.title, cost: value.cost);
      };
      await tester.enterText(find.byType(TextFormField).first, 'Music');
      await tester.tap(find.text('Require viewer text'));
      await tester.pumpAndSettle();
      final inputSwitch = find.byType(CustomSwitch).first;
      expect(tester.widget<CustomSwitch>(inputSwitch).value, isFalse);
      final inputRow = tester.getRect(
        find.ancestor(of: inputSwitch, matching: find.byType(Row)).first,
      );
      await tester.tapAt(Offset(inputRow.right - 4, inputRow.center.dy));
      await tester.pumpAndSettle();
      expect(tester.widget<CustomSwitch>(inputSwitch).value, isFalse);
      await tester.tap(inputSwitch);
      await tester.pumpAndSettle();
      final preset = find.byKey(const ValueKey('reward-color-#10B981'));
      await tester.ensureVisible(preset);
      await tester.tap(preset);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(TwitchRewardCatalog), findsOneWidget);
      expect(find.byType(TwitchRewardEditor), findsNothing);
      expect(reward.isLinked, isFalse);
      expect(reward.name, 'Manual');
      final selected = find.byKey(const ValueKey('twitch-reward-row-created'));
      expect(selected.hitTestable(), findsOneWidget);
      expect(
        find.ancestor(
          of: selected,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.selected == true,
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(TwitchRewardCatalog), findsNothing);
      expect(find.byType(RewardConfiguratorWidget), findsOneWidget);
      expect(reward.name, 'Music');
      expect(reward.twitchRewardId, 'created');
      expect(reward.handlers.single, same(action));
      expect(api.writes, 1);
      expect(savedColor, '#10B981');
      expect(savedInput, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final linked in [false, true]) {
    testWidgets(
      'leaving the catalog after creation preserves the link, linked=$linked',
      (tester) async {
        await showEditor(tester, linked: linked);
        await tester.tap(
          find.text(linked ? 'Change link' : 'Link Twitch reward'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Without reactions').first);
        await tester.enterText(find.byType(TextField), 'No matching rewards');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create reward'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, 'New music');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.byType(TwitchRewardCatalog), findsOneWidget);
        expect(find.byType(TwitchRewardEditor), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(
          find.byKey(const ValueKey('twitch-reward-row-created')).hitTestable(),
          findsOneWidget,
        );
        expect(reward.twitchRewardId, linked ? 'own' : isNull);
        expect(reward.name, linked ? 'Music' : 'Manual');
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(find.byType(TwitchRewardCatalog), findsNothing);
        expect(reward.twitchRewardId, linked ? 'own' : isNull);
        expect(reward.name, linked ? 'Music' : 'Manual');
        expect(api.writes, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'editing validates input and synchronizes the locked name after saving',
    (tester) async {
      await showEditor(tester, linked: true);
      await tester.tap(find.text('Change link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('Save')).dy,
        lessThan(tester.getTopLeft(find.text('Basic Settings')).dy),
      );
      await tester.enterText(find.byType(TextFormField).first, 'Renamed music');
      await tester.enterText(find.byType(TextFormField).at(1), '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(api.writes, 0);
      expect(find.text('Enter a whole number of at least 1.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), '800');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(TwitchRewardCatalog), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(reward.twitchRewardId, 'own');
      expect(reward.name, 'Renamed music');
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('reward-name')),
      );
      expect(field.enabled, isFalse);
      expect(field.controller!.text, 'Renamed music');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'numeric reward fields validate values, keyboard actions and empty limits',
    (tester) async {
      await showEditor(tester, linked: true);
      await tester.tap(find.text('Change link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      Finder inputFor(String label) => find.descendant(
        of: find.widgetWithText(RewardFormField, label),
        matching: find.byType(TextField),
      );
      const values = {
        'Cost, points': '800',
        'Cooldown, seconds (optional)': '60',
        'Limit per stream (optional)': '10',
        'Limit per viewer per stream (optional)': '2',
      };
      for (final entry in values.entries) {
        final field = inputFor(entry.key);
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        final input = tester.widget<TextField>(field);
        expect(
          input.keyboardType,
          const TextInputType.numberWithOptions(signed: false, decimal: false),
        );
        expect(input.autocorrect, isFalse);
        expect(input.enableSuggestions, isFalse);
        await tester.enterText(field, entry.value);
        for (final invalid in [
          'letters',
          '-5',
          '1.5',
          '1e3',
          '9223372036854775808',
        ]) {
          await tester.enterText(field, invalid);
          expect(input.controller!.text, entry.value, reason: entry.key);
        }
      }
      final cooldown = inputFor('Cooldown, seconds (optional)');
      final perStream = inputFor('Limit per stream (optional)');
      final perViewer = inputFor('Limit per viewer per stream (optional)');
      final cost = inputFor('Cost, points');
      await tester.ensureVisible(cooldown);
      await tester.pumpAndSettle();
      await tester.tap(cooldown);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(perStream).focusNode!.hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(perViewer).focusNode!.hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(perViewer).focusNode!.hasFocus, isFalse);

      await tester.enterText(cost, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(api.writes, 0);
      expect(find.text('Enter a whole number of at least 1.'), findsOneWidget);
      await tester.enterText(cost, '800');
      await tester.enterText(cooldown, '604801');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(api.writes, 0);
      expect(
        find.text('Enter a whole number from 1 to 604800, or leave blank.'),
        findsOneWidget,
      );
      await tester.enterText(cooldown, '60');
      await tester.enterText(perStream, '0');
      await tester.enterText(perViewer, '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(api.writes, 0);
      expect(
        find.text('Enter a whole number of at least 1.'),
        findsNWidgets(2),
      );
      await tester.enterText(perStream, '10');
      await tester.enterText(perViewer, '2');
      TwitchRewardSettings? saved;
      api.save = (id, value) async {
        saved = value;
        return remoteReward(id!, value.title, cost: value.cost);
      };
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved!.cost, 800);
      expect(saved!.cooldownSeconds, 60);
      expect(saved!.maxPerStream, 10);
      expect(saved!.maxPerUserPerStream, 2);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      for (final label in values.keys.skip(1)) {
        await tester.enterText(inputFor(label), '');
      }
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(api.writes, 2);
      expect(saved!.cooldownSeconds, isNull);
      expect(saved!.maxPerStream, isNull);
      expect(saved!.maxPerUserPerStream, isNull);
      expect(saved!.toJson()['is_global_cooldown_enabled'], isFalse);
      expect(saved!.toJson()['is_max_per_stream_enabled'], isFalse);
      expect(saved!.toJson()['is_max_per_user_per_stream_enabled'], isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('missing ID stays linked and new screens fit large text', (
    tester,
  ) async {
    await showEditor(tester, linked: true, scale: 2);
    api.entries = [];
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Linked reward is unavailable. Choose another reward or unlink it.',
      ),
      findsOneWidget,
    );
    expect(reward.isLinked, isTrue);
    await tester.tap(find.text('Change link'));
    await tester.pumpAndSettle();
    expect(find.text('No matching rewards'), findsNothing);
    expect(find.byKey(const ValueKey('twitch-reward-row-own')), findsNothing);
    expect(find.byKey(const ValueKey('twitch-reward-row-other')), findsNothing);
    await tester.tap(find.text('Create reward'));
    await tester.pumpAndSettle();
    expect(find.byType(TwitchRewardEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long reward names remain on one row with large text', (
    tester,
  ) async {
    await showEditor(tester, scale: 2);
    const title = 'A very long reward name with several words';
    api.entries[0] = remoteReward('own', title);
    await tester.tap(find.text('Link Twitch reward'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(title)).maxLines, 1);
    expect(
      tester.getCenter(find.text(title)).dy,
      closeTo(
        tester
            .getCenter(find.byKey(const ValueKey('twitch-reward-price-own')))
            .dy,
        1,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('branded search can be cleared and filters keep working', (
    tester,
  ) async {
    await showEditor(tester);
    reward.name = 'Music';
    await tester.tap(find.text('Link Twitch reward'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'No such reward');
    await tester.pumpAndSettle();
    expect(find.text('No matching rewards'), findsNothing);
    expect(find.byKey(const ValueKey('twitch-reward-row-own')), findsNothing);
    expect(find.byKey(const ValueKey('twitch-reward-row-other')), findsNothing);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is RippleIcon &&
            widget.icon == Assets.assetsIcCloseWhite16dp,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Water'), findsOneWidget);
    await tester.tap(find.text('Without reactions').first);
    await tester.pumpAndSettle();
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Music'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Locator extends ServiceLocator {
  final TwitchRewardsController controller;
  _Locator(this.controller);
  @override
  T provide<T>() => controller as T;
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
