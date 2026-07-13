import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/rewards_store.dart';

void main() {
  setUpAll(sqfliteFfiInit);

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
