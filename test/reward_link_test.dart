import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/twitch/ws_event.dart';

void main() {
  test('ID links survive renames and never fall back to matching titles', () {
    final reward = Reward(name: 'Old title', handlers: []);
    reward.linkToTwitch(
      rewardId: 'id',
      broadcasterId: 'channel',
      title: 'Old title',
    );
    expect(
      reward.matchesRedemption(
        rewardId: 'id',
        title: 'New title',
        broadcasterId: 'channel',
      ),
      isTrue,
    );
    expect(
      reward.matchesRedemption(
        rewardId: 'another',
        title: 'Old title',
        broadcasterId: 'channel',
      ),
      isFalse,
    );
    expect(
      reward.matchesRedemption(
        rewardId: null,
        title: 'Old title',
        broadcasterId: 'channel',
      ),
      isFalse,
    );
    expect(
      reward.matchesRedemption(
        rewardId: 'id',
        title: 'Old title',
        broadcasterId: 'other channel',
      ),
      isFalse,
    );
    reward.disabled = true;
    expect(
      reward.matchesRedemption(
        rewardId: 'id',
        title: 'Old title',
        broadcasterId: 'channel',
      ),
      isFalse,
    );
  });

  test(
    'legacy entries still match exact titles and unlink preserves actions',
    () {
      final legacy = Reward.fromJson({'name': 'Manual', 'handlers': []});
      expect(legacy.isLinked, isFalse);
      expect(
        legacy.matchesRedemption(
          rewardId: 'any',
          title: 'Manual',
          broadcasterId: 'channel',
        ),
        isTrue,
      );
      final action = RewardAction(type: RewardAction.typeDelay, millis: 2000);
      addTearDown(action.dispose);
      legacy.handlers.add(action);
      legacy.linkToTwitch(
        rewardId: 'id',
        broadcasterId: 'channel',
        title: 'Renamed',
      );
      legacy.unlinkFromTwitch();
      expect(legacy.name, 'Renamed');
      expect(legacy.handlers.single, same(action));
      expect(legacy.twitchBroadcasterId, isNull);
      expect(
        legacy.matchesRedemption(
          rewardId: 'new',
          title: 'Renamed',
          broadcasterId: 'channel',
        ),
        isTrue,
      );
    },
  );

  test('EventSub parses the reward and broadcaster IDs used for dispatch', () {
    final event = WsMessageEvent.fromJson({
      'id': 'redemption',
      'broadcaster_user_id': 'channel',
      'reward': {'id': 'reward', 'title': 'Renamed', 'cost': 100},
    });
    expect(event.reward!.id, 'reward');
    expect(event.broadcasterUserId, 'channel');
  });
}
