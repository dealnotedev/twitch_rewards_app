import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/rewards/rewards_store.dart';

void main() {
  test('existing configurations default to the Reward trigger', () {
    final reward = Reward.fromJson({'name': 'Music', 'handlers': []});
    expect(reward.triggerType, RewardTriggerType.reward);
    expect(
      reward.matchesRedemption(
        rewardId: 'id',
        title: 'Music',
        broadcasterId: 'channel',
      ),
      isTrue,
    );
  });

  for (final type in [
    RewardTriggerType.command,
    RewardTriggerType.raid,
    RewardTriggerType.follow,
  ]) {
    test('$type does not run for a channel point redemption', () {
      final reward = Reward(name: 'Music', handlers: [], triggerType: type);
      expect(
        reward.matchesRedemption(
          rewardId: 'id',
          title: 'Music',
          broadcasterId: 'channel',
        ),
        isFalse,
      );
      reward.linkToTwitch(
        rewardId: 'id',
        broadcasterId: 'channel',
        title: 'Music',
      );
      expect(
        reward.matchesRedemption(
          rewardId: 'id',
          title: 'Music',
          broadcasterId: 'channel',
        ),
        isFalse,
      );
    });
  }

  test(
    'trigger choices survive database saves together with links and actions',
    () async {
      sqfliteFfiInit();
      final store = await RewardsStore.open(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(store.close);
      final originals = [
        for (final type in RewardTriggerType.values)
          Reward(
            name: type.name,
            triggerType: type,
            twitchRewardId: 'reward-id',
            twitchBroadcasterId: 'channel',
            handlers: [RewardAction(type: RewardAction.typeDelay, millis: 700)],
          ),
      ];
      for (final reward in originals) {
        addTearDown(reward.handlers.single.dispose);
      }
      final command = originals.firstWhere(
        (reward) => reward.triggerType == RewardTriggerType.command,
      );
      command.name = '!Music';
      await store.save(Rewards(rewards: originals));
      final loaded = (await store.load()).rewards;
      expect(
        loaded.map((reward) => reward.triggerType),
        RewardTriggerType.values,
      );
      for (final reward in loaded) {
        addTearDown(reward.handlers.single.dispose);
        expect(reward.twitchRewardId, 'reward-id');
        expect(reward.twitchBroadcasterId, 'channel');
        expect(reward.handlers.single.millis, 700);
      }
      final restoredCommand = loaded.firstWhere(
        (reward) => reward.triggerType == RewardTriggerType.command,
      );
      expect(restoredCommand.name, '!Music');
    },
  );
}
