import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/twitch/redemption.dart';
import 'package:twitch_listener/twitch/redemption_queue_entry.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';

import 'redemption_fakes.dart';
import 'rewards_fakes.dart';

void main() {
  test('pending summary includes earlier sessions without importing or settling requests', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    await h.queue.handleMessage(redemptionMessage('current'));
    h.api.pendingRedemptions = [
      redemption('current'),
      redemption('old-session', cost: 500),
      redemption('other-reward', rewardId: 'other'),
      redemption('already-confirmed', status: RedemptionStatus.fulfilled),
    ];
    final summary = await h.rewards.getPendingSummary(
      'own',
      expectedAccount: h.rewards.accountKey,
    );
    expect(summary.count, 2);
    expect(summary.points, 1250);
    expect(h.api.pendingReads, 1);
    expect(h.queue.entries.single.id, 'current');
    expect(h.queue.find('old-session'), isNull);
    expect(h.api.avatarReads, 1);
    expect(h.api.patches, isEmpty);
    expect(h.api.deleteCalls, isEmpty);
    expect(h.rewards.canEdit('own'), isTrue);
    expect(h.rewards.saving, isFalse);
  });

  test(
    'pending summary rejects a response from the previous account',
    () async {
      final h = await QueueHarness.create();
      addTearDown(h.close);
      h.api.pendingRedemptions = [redemption('one')];
      h.api.beforePendingRead = () =>
          h.settings.saveTwitchAuth(credentials('another'));
      await expectLater(
        h.rewards.getPendingSummary(
          'own',
          expectedAccount: h.rewards.accountKey,
        ),
        throwsA(
          isA<TwitchRewardsException>().having(
            (error) => error.kind,
            'kind',
            TwitchRewardsError.accountChanged,
          ),
        ),
      );
      expect(h.api.deleteCalls, isEmpty);
      expect(h.api.patches, isEmpty);
    },
  );

  test(
    'confirm and delete resolves only the target reward without a history read',
    () async {
      final h = await QueueHarness.create();
      addTearDown(h.close);
      h.api.entries.add(remoteReward('other', 'Water'));
      h.api.owned.add('other');
      final other =
          Reward(
            name: 'Water',
            handlers: [RewardAction(type: RewardAction.typeDelay)],
          )..linkToTwitch(
            rewardId: 'other',
            broadcasterId: 'channel',
            title: 'Water',
          );
      h.settings.rewards.rewards.add(other);
      await h.rewards.refresh();
      final own = h.settings.rewards.rewards.first;
      final action = own.handlers.single;
      await h.queue.handleMessage(redemptionMessage('one'));
      await h.queue.handleMessage(redemptionMessage('two', rewardId: 'other'));
      h.api.beforeDelete = () =>
          h.queue.handleMessage(redemptionMessage('during-delete'));

      await h.rewards.deleteReward(
        'own',
        refundPoints: false,
        expectedAccount: h.rewards.accountKey,
      );

      expect(h.api.pendingReads, 0);
      expect(h.api.deleteCalls, ['own']);
      expect(h.queue.find('one')!.state, RedemptionQueueState.confirmed);
      expect(
        h.queue.find('during-delete')!.state,
        RedemptionQueueState.confirmed,
      );
      expect(h.queue.entries.single.id, 'two');
      expect(h.rewards.rewards.map((reward) => reward.id), ['other']);
      expect(h.rewards.canEdit('own'), isFalse);
      expect(own.twitchRewardId, 'own');
      expect(own.handlers.single, same(action));
      expect(h.shared.findReward(own), isNull);
      h.clock = h.clock.add(const Duration(minutes: 11));
      await h.queue.tick();
      expect(h.api.patches, [('two', RedemptionStatus.fulfilled)]);
    },
  );

  test('partial refunds disappear immediately; failure stops deletion and retry reads the remainder', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    await h.queue.handleMessage(redemptionMessage('one'));
    await h.queue.handleMessage(redemptionMessage('two'));
    h.api.pendingRedemptions = [
      redemption('one'),
      redemption('two'),
      redemption('old-session'),
    ];
    var calls = 0;
    h.api.beforePatch = () async {
      if (++calls == 2) {
        throw DioException(
          requestOptions: RequestOptions(),
          response: Response(requestOptions: RequestOptions(), statusCode: 404),
        );
      }
    };
    await expectLater(
      h.rewards.deleteReward(
        'own',
        refundPoints: true,
        expectedAccount: h.rewards.accountKey,
      ),
      throwsA(
        isA<TwitchRewardsException>().having(
          (error) => error.kind,
          'kind',
          TwitchRewardsError.redemptionChanged,
        ),
      ),
    );
    expect(h.api.deleteCalls, isEmpty);
    expect(h.queue.find('one')!.state, RedemptionQueueState.refunded);
    expect(h.queue.entries.single.id, 'two');
    expect(h.rewards.canEdit('own'), isTrue);

    h.api.beforePatch = null;
    await h.rewards.deleteReward(
      'own',
      refundPoints: true,
      expectedAccount: h.rewards.accountKey,
    );
    expect(h.api.pendingReads, 2);
    expect(h.api.patches.map((patch) => patch.$1), [
      'one',
      'two',
      'two',
      'old-session',
    ]);
    expect(h.api.deleteCalls, ['own']);
    expect(h.queue.entries, isEmpty);
    expect(h.queue.find('two')!.state, RedemptionQueueState.refunded);
    expect(h.queue.find('old-session'), isNull);
    expect(h.api.avatarReads, 1);
    expect(h.executor.calls, 2);
  });

  test('a failed DELETE keeps the reward and leaves only unresolved requests in the queue', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    await h.queue.handleMessage(redemptionMessage('one'));
    h.api.pendingRedemptions = [redemption('one')];
    h.api.beforeDelete = () =>
        h.queue.handleMessage(redemptionMessage('new-request'));
    h.api.deleteError = StateError('Delete failed');
    await expectLater(
      h.rewards.deleteReward(
        'own',
        refundPoints: true,
        expectedAccount: h.rewards.accountKey,
      ),
      throwsA(isA<TwitchRewardsException>()),
    );
    expect(h.queue.find('one')!.state, RedemptionQueueState.refunded);
    expect(h.queue.entries.single.id, 'new-request');
    expect(h.rewards.rewards.map((reward) => reward.id), contains('own'));
    expect(h.rewards.saving, isFalse);
  });

  test('a rejected DELETE never hides unresolved requests or removes cached ownership', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    await h.queue.handleMessage(redemptionMessage('one'));
    h.api.deleteError = DioException(
      requestOptions: RequestOptions(),
      response: Response(requestOptions: RequestOptions(), statusCode: 404),
    );
    await expectLater(
      h.rewards.deleteReward(
        'own',
        refundPoints: false,
        expectedAccount: h.rewards.accountKey,
      ),
      throwsA(
        isA<TwitchRewardsException>().having(
          (error) => error.kind,
          'kind',
          TwitchRewardsError.notFound,
        ),
      ),
    );
    expect(h.queue.entries.single.id, 'one');
    expect(h.queue.find('one')!.state, RedemptionQueueState.waiting);
    expect(h.rewards.canEdit('own'), isTrue);
  });

  test(
    'automatic confirmation keeps running during deletion-time reads',
    () async {
      final h = await QueueHarness.create();
      addTearDown(h.close);
      await h.queue.handleMessage(redemptionMessage('one'));
      h.api.pendingRedemptions = [redemption('one')];
      final reading = Completer<void>();
      h.api.beforePendingRead = () => reading.future;
      final deleting = h.rewards.deleteReward(
        'own',
        refundPoints: true,
        expectedAccount: h.rewards.accountKey,
      );
      await flushQueue();
      h.clock = h.clock.add(const Duration(minutes: 11));
      await h.queue.tick();
      expect(h.api.patches, [('one', RedemptionStatus.fulfilled)]);
      reading.complete();
      await deleting;
      expect(h.api.deleteCalls, ['own']);
      expect(h.queue.entries, isEmpty);
    },
  );

  test(
    'account changes during a refund read prevent writes or deletion',
    () async {
      final h = await QueueHarness.create();
      addTearDown(h.close);
      h.api.pendingRedemptions = [redemption('one')];
      h.api.beforePendingRead = () =>
          h.settings.saveTwitchAuth(credentials('another'));
      await expectLater(
        h.rewards.deleteReward(
          'own',
          refundPoints: true,
          expectedAccount: h.rewards.accountKey,
        ),
        throwsA(
          isA<TwitchRewardsException>().having(
            (error) => error.kind,
            'kind',
            TwitchRewardsError.accountChanged,
          ),
        ),
      );
      expect(h.api.patches, isEmpty);
      expect(h.api.deleteCalls, isEmpty);
    },
  );

  test('foreign rewards and read-only authorization cannot delete', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    await expectLater(
      h.rewards.deleteReward(
        'other',
        refundPoints: false,
        expectedAccount: h.rewards.accountKey,
      ),
      throwsA(
        isA<TwitchRewardsException>().having(
          (error) => error.kind,
          'kind',
          TwitchRewardsError.forbidden,
        ),
      ),
    );
    h.api.scopes = {'channel:read:redemptions'};
    await h.rewards.refresh();
    await expectLater(
      h.rewards.deleteReward(
        'own',
        refundPoints: true,
        expectedAccount: h.rewards.accountKey,
      ),
      throwsA(
        isA<TwitchRewardsException>().having(
          (error) => error.kind,
          'kind',
          TwitchRewardsError.authorization,
        ),
      ),
    );
    expect(h.api.pendingReads, 0);
    expect(h.api.deleteCalls, isEmpty);
  });
}
