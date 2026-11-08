import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:twitch_listener/audio/audioplayer.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/rewards/actions/credit_points.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/rewards/reward_execution.dart';
import 'package:twitch_listener/rewards/reward_executor.dart';
import 'package:twitch_listener/rewards/reward_test.dart';
import 'package:twitch_listener/rewards/rewards_store.dart';
import 'package:twitch_listener/ui/themes.dart';

import '../music/fakes.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late RewardsStore store;
  late RewardExecutor executor;
  late _Obs obs;

  setUp(() async {
    store = await RewardsStore.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final music = MusicRequestManager(
      fetcher: FakeFetcher(),
      player: FakePlayer(),
    );
    addTearDown(music.close);
    addTearDown(store.close);
    obs = _Obs();
    executor = RewardExecutor(
      audioplayer: Audioplayer(),
      obs: obs,
      musicRequests: music,
      viewerBalances: store.viewerBalances,
    );
  });

  test(
    'empty amount uses redemption cost and updates names for the same ID',
    () async {
      final reward = Reward(
        name: 'Deposit',
        handlers: [
          RewardAction.create(RewardAction.typeCreditPoints),
          RewardAction(type: RewardAction.typeEnableInput, inputName: 'Mic'),
        ],
      );
      obs.onEnable = () async {
        expect(await store.viewerBalances.balanceOf('viewer'), 500);
      };
      final execution = RewardExecution();
      await executor.execute(
        reward,
        requesterId: 'viewer',
        requesterLogin: 'alice',
        requester: 'Alice',
        rewardCost: 500,
        userInput: '9000',
        execution: execution,
      );
      await execution.finish();
      expect(obs.calls, 1);
      obs.onEnable = null;
      await executor.execute(
        reward,
        requesterId: 'viewer',
        requesterLogin: 'new_login',
        requester: 'New Display Name',
        rewardCost: 100,
      );
      expect(await store.viewerBalances.balanceOf('viewer'), 600);
    },
  );

  test(
    'configured whole number overrides cost, including an explicit zero',
    () async {
      for (final amount in [42, 0]) {
        final reward = Reward(
          name: 'Deposit',
          handlers: [
            RewardAction(
              type: RewardAction.typeCreditPoints,
              pointsAmount: amount,
            ),
          ],
        );
        final restored = Reward.fromJson(
          jsonDecode(jsonEncode(reward.toJson())),
        );
        expect(restored.handlers.single.pointsAmount, amount);
        await executor.execute(
          restored,
          requesterId: 'viewer',
          rewardCost: 500,
        );
      }
      expect(await store.viewerBalances.balanceOf('viewer'), 42);
      final action = RewardAction.fromJson({
        'type': RewardAction.typeCreditPoints,
      });
      expect(action.pointsAmount, isNull);
    },
  );

  test(
    'fixed amounts work for commands, follows and raids without reward cost',
    () async {
      for (final type in [
        RewardTriggerType.command,
        RewardTriggerType.follow,
        RewardTriggerType.raid,
      ]) {
        await executor.execute(
          Reward(
            name: type.name,
            triggerType: type,
            handlers: [
              RewardAction(
                type: RewardAction.typeCreditPoints,
                pointsAmount: 5,
              ),
            ],
          ),
          requesterId: 'viewer',
        );
      }
      expect(await store.viewerBalances.balanceOf('viewer'), 15);
    },
  );

  test(
    'missing identity, absent cost and invalid amounts stop the chain safely',
    () async {
      final action = RewardAction(type: RewardAction.typeCreditPoints);
      final reward = Reward(
        name: 'Deposit',
        handlers: [
          action,
          RewardAction(type: RewardAction.typeEnableInput, inputName: 'Mic'),
        ],
      );
      await expectLater(
        executor.execute(reward, requester: 'Alice', rewardCost: 500),
        throwsStateError,
      );
      await expectLater(
        executor.execute(reward, requesterId: 'viewer'),
        throwsStateError,
      );
      action.pointsAmount = -10;
      await expectLater(
        executor.execute(reward, requesterId: 'viewer'),
        throwsRangeError,
      );
      expect(obs.calls, 0);
      expect(await store.viewerBalances.balanceOf('viewer'), 0);
      action.disabled = true;
      await executor.execute(reward);
      expect(obs.calls, 1);
      expect(await store.viewerBalances.balanceOf('viewer'), 0);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'amount field accepts integers and clearing restores reward cost, dark=$dark',
      (tester) async {
        final action = RewardAction(type: RewardAction.typeCreditPoints);
        var changes = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? Themes.dark : Themes.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CreditPointsWidget(
                action: action,
                changesCallback: () => changes++,
              ),
            ),
          ),
        );
        final field = find.byKey(const ValueKey('credit-points-amount'));
        expect(find.text('Reward cost'), findsOneWidget);
        await tester.enterText(field, '25');
        expect(action.pointsAmount, 25);
        for (final invalid in ['-5', '1.5', '10abc', '9223372036854775808']) {
          await tester.enterText(field, invalid);
          expect(action.pointsAmount, 25);
          expect(tester.widget<TextField>(field).controller!.text, '25');
        }
        await tester.enterText(field, '0');
        expect(action.pointsAmount, 0);
        tester.widget<TextField>(field).controller!.clear();
        await tester.pump();
        expect(action.pointsAmount, isNull);
        expect(changes, 3);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'manual test explains the required Twitch identity without changing money',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => testReward(
                  context,
                  Reward(
                    name: 'Deposit',
                    handlers: [
                      RewardAction(
                        type: RewardAction.typeCreditPoints,
                        pointsAmount: 5,
                      ),
                    ],
                  ),
                  executor,
                ),
                child: const Text('Test'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Test'));
      await tester.pump();
      expect(
        find.text(
          'To test viewer points, trigger this chain on Twitch. A real viewer ID is required.',
        ),
        findsOneWidget,
      );
      expect(
        await tester.runAsync(() => store.viewerBalances.balanceOf('viewer')),
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _Obs implements ObsConnect {
  int calls = 0;
  Future<void> Function()? onEnable;
  @override
  Future<void> enableInput({
    required String inputName,
    required bool enabled,
  }) async {
    calls++;
    await onEnable?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
