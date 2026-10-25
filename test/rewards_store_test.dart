import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/rewards/rewards_store.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('persists ID links and unlinking without changing the reaction chain', () async {
    final store = await RewardsStore.open(factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath);
    addTearDown(store.close);
    final reward = Reward(name:'Linked', handlers:[RewardAction(type:RewardAction.typeDelay,millis:700)])
      ..linkToTwitch(rewardId:'remote',broadcasterId:'channel',title:'Linked');
    addTearDown(reward.handlers.single.dispose);
    await store.save(Rewards(rewards:[reward]));
    final loaded=(await store.load()).rewards.single;
    addTearDown(loaded.handlers.single.dispose);
    expect(loaded.twitchRewardId,'remote');
    expect(loaded.twitchBroadcasterId,'channel');
    loaded.unlinkFromTwitch();
    await store.save(Rewards(rewards:[loaded]));
    final unlinked=(await store.load()).rewards.single;
    addTearDown(unlinked.handlers.single.dispose);
    expect(unlinked.isLinked,isFalse);
    expect(unlinked.name,'Linked');
    expect(unlinked.handlers.single.millis,700);
  });

  test('imports legacy rewards once and persists subsequent changes', () async {
    final store = await RewardsStore.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(store.close);

    final legacy = Rewards(rewards: [
      Reward(name: 'First', handlers: []),
      Reward(name: 'Second', handlers: [], disabled: true),
    ]);

    final imported = await store.loadAndMigrate(jsonEncode(legacy.toJson()));

    expect(imported.rewards.map((reward) => reward.name), ['First', 'Second']);
    expect(imported.rewards.last.disabled, isTrue);

    await store.save(Rewards(rewards: [
      Reward(name: 'Current second', handlers: []),
      Reward(name: 'Current first', handlers: []),
    ]));

    final loaded = await store.loadAndMigrate(jsonEncode(legacy.toJson()));

    expect(
      loaded.rewards.map((reward) => reward.name),
      ['Current second', 'Current first'],
    );
  });
}
