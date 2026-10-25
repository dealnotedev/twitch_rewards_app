import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/twitch/redemption.dart';
import 'package:twitch_listener/twitch/redemption_queue_entry.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';

import 'redemption_fakes.dart';
import 'rewards_fakes.dart';

void main() {
  test('pauses one countdown and resumes its exact remaining time', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    await h.queue.handleMessage(redemptionMessage('one'));
    await h.queue.handleMessage(redemptionMessage('two'));
    h.clock = h.clock.add(
      const Duration(minutes: 2, seconds: 17, milliseconds: 250),
    );
    h.queue.toggleTimer('one');
    final entry = h.queue.find('one')!;
    const remaining = Duration(minutes: 7, seconds: 42, milliseconds: 750);
    expect(entry.isPaused, isTrue);
    expect(entry.confirmAt, isNull);
    expect(entry.remainingAt(h.clock), remaining);
    h.clock = h.clock.add(const Duration(hours: 1));
    await h.queue.tick();
    expect(h.api.patches, [('two', RedemptionStatus.fulfilled)]);
    expect(entry.remainingAt(h.clock), remaining);
    h.queue.toggleTimer('one');
    expect(entry.isPaused, isFalse);
    expect(entry.confirmAt, h.clock.add(remaining));
    h.clock = h.clock.add(remaining - const Duration(milliseconds: 1));
    await h.queue.tick();
    expect(h.api.patches, hasLength(1));
    h.clock = h.clock.add(const Duration(milliseconds: 1));
    await h.queue.tick();
    expect(h.api.patches, [
      ('two', RedemptionStatus.fulfilled),
      ('one', RedemptionStatus.fulfilled),
    ]);
  });

  for (final status in [
    RedemptionStatus.fulfilled,
    RedemptionStatus.canceled,
  ]) {
    test('manual $status is available while the timer is paused', () async {
      final h = await QueueHarness.create();
      addTearDown(h.close);
      await h.queue.handleMessage(redemptionMessage('one'));
      h.queue.toggleTimer('one');
      expect(h.queue.canDecide(h.queue.find('one')!), isTrue);
      await (status == RedemptionStatus.fulfilled
          ? h.queue.confirmNow('one')
          : h.queue.refund('one'));
      expect(h.queue.entries, isEmpty);
      h.clock = h.clock.add(const Duration(hours: 1));
      await h.queue.tick();
      expect(h.api.patches, [('one', status)]);
    });
  }

  test(
    'local removal leaves Twitch untouched and ignores duplicate delivery',
    () async {
      final h = await QueueHarness.create();
      addTearDown(h.close);
      await h.queue.handleMessage(redemptionMessage('one'));
      h.queue.toggleTimer('one');
      h.queue.remove('one');
      expect(h.queue.entries, isEmpty);
      expect(h.queue.find('one')!.state, RedemptionQueueState.removed);
      expect(h.queue.canDecide(h.queue.find('one')!), isFalse);
      expect(h.queue.canToggleTimer(h.queue.find('one')!), isFalse);
      await h.queue.handleMessage(redemptionMessage('one'));
      h.clock = h.clock.add(const Duration(hours: 1));
      await h.queue.tick();
      await h.queue.confirmNow('one');
      await h.queue.refund('one');
      expect(h.executor.calls, 1);
      expect(h.api.patches, isEmpty);
      expect(h.api.pendingReads, 0);
      expect(h.api.deleteCalls, isEmpty);
    },
  );

  for (final failure in [false, true]) {
    test(
      'removing an executing reaction does not cancel or settle it, failure=$failure',
      () async {
        final h = await QueueHarness.create();
        addTearDown(h.close);
        final effect = Completer<void>();
        var canceled = false;
        h.executor.run = (execution) async {
          execution!.track(effect.future, cancel: () async => canceled = true);
        };
        final handled = h.queue.handleMessage(redemptionMessage('one'));
        await flushQueue();
        expect(h.queue.canToggleTimer(h.queue.find('one')!), isFalse);
        h.queue.remove('one');
        expect(canceled, isFalse);
        expect(h.queue.entries, isEmpty);
        if (failure) {
          effect.completeError(StateError('Effect failed later'));
        } else {
          effect.complete();
        }
        await handled;
        h.clock = h.clock.add(const Duration(hours: 1));
        await h.queue.tick();
        expect(h.queue.find('one')!.state, RedemptionQueueState.removed);
        expect(h.api.patches, isEmpty);
        expect(h.executor.calls, 1);
      },
    );
  }

  test('removing a failed decision stops retries even without management permission', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    await h.queue.handleMessage(redemptionMessage('one'));
    h.api.beforePatch = () async {
      throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );
    };
    await h.queue.confirmNow('one');
    h.api.scopes = {'channel:read:redemptions'};
    await h.rewards.refresh();
    expect(h.queue.canDecide(h.queue.find('one')!), isFalse);
    expect(h.queue.canRemove(h.queue.find('one')!), isTrue);
    h.queue.remove('one');
    h.clock = h.clock.add(const Duration(hours: 1));
    await h.queue.tick();
    await h.queue.retry('one');
    expect(h.queue.entries, isEmpty);
    expect(h.api.patches, [('one', RedemptionStatus.fulfilled)]);
  });

  test('an already sent decision cannot be removed or paused', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    await h.queue.handleMessage(redemptionMessage('one'));
    final response = Completer<void>();
    h.api.beforePatch = () => response.future;
    final deciding = h.queue.confirmNow('one');
    expect(h.queue.canRemove(h.queue.find('one')!), isFalse);
    expect(h.queue.canToggleTimer(h.queue.find('one')!), isFalse);
    h.queue.remove('one');
    h.queue.toggleTimer('one');
    expect(h.queue.entries.single.state, RedemptionQueueState.waiting);
    response.complete();
    await deciding;
    expect(h.queue.find('one')!.state, RedemptionQueueState.confirmed);
  });

  test(
    'starts ten minutes after completion and handles delivery duplicates once',
    () async {
      final h = await QueueHarness.create();
      addTearDown(h.close);
      final gate = Completer<void>();
      h.executor.run = (_) => gate.future;
      final handled = h.queue.handleMessage(redemptionMessage('one'));
      await flushQueue();
      expect(h.queue.entries.single.state, RedemptionQueueState.executing);
      expect(h.queue.entries.single.confirmAt, isNull);
      h.clock = h.clock.add(const Duration(minutes: 4));
      await h.queue.tick();
      expect(h.api.patches, isEmpty);
      gate.complete();
      await handled;
      expect(
        h.queue.entries.single.confirmAt,
        h.clock.add(const Duration(minutes: 10)),
      );
      await h.queue.handleMessage(redemptionMessage('one'));
      expect(h.executor.calls, 1);
      h.clock = h.clock.add(const Duration(minutes: 9, seconds: 59));
      await h.queue.tick();
      expect(h.api.patches, isEmpty);
      h.clock = h.clock.add(const Duration(seconds: 1));
      await h.queue.tick();
      expect(h.api.patches, [('one', RedemptionStatus.fulfilled)]);
      expect(h.queue.entries, isEmpty);
      expect(h.queue.find('one')!.state, RedemptionQueueState.confirmed);
    },
  );

  test('waits for background effects, caches viewer avatars, refunds a late failure', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    final effect = Completer<void>();
    final started = Completer<void>();
    final scheduling = Completer<void>();
    h.executor.run = (execution) async {
      execution!.track(effect.future);
      started.complete();
      await scheduling.future;
    };
    final handled = h.queue.handleMessage(redemptionMessage('one'));
    await started.future;
    expect(h.queue.entries.single.state, RedemptionQueueState.executing);
    effect.completeError(StateError('Player failed'));
    await handled;
    scheduling.complete();
    expect(h.api.patches, [('one', RedemptionStatus.canceled)]);
    h.executor.run = null;
    await h.queue.handleMessage(redemptionMessage('two'));
    await flushQueue();
    expect(h.queue.entries.single.avatarUrl, 'https://example.com/viewer.png');
    expect(h.api.avatarReads, 1);
  });

  test(
    'manual confirmation claims the decision before a competing refund',
    () async {
      final h = await QueueHarness.create();
      addTearDown(h.close);
      await h.queue.handleMessage(redemptionMessage('one'));
      final response = Completer<void>();
      h.api.beforePatch = () => response.future;
      final confirming = h.queue.confirmNow('one');
      expect(h.queue.canDecide(h.queue.find('one')!), isFalse);
      await h.queue.refund('one');
      await flushQueue();
      expect(h.api.patches, [('one', RedemptionStatus.fulfilled)]);
      response.complete();
      await confirming;
      expect(h.queue.entries, isEmpty);
    },
  );

  test(
    'manual refund during execution cannot later turn into confirmation',
    () async {
      final h = await QueueHarness.create();
      addTearDown(h.close);
      final effect = Completer<void>();
      h.executor.run = (_) => effect.future;
      final handled = h.queue.handleMessage(redemptionMessage('one'));
      await flushQueue();
      await h.queue.refund('one');
      effect.complete();
      await handled;
      h.clock = h.clock.add(const Duration(hours: 1));
      await h.queue.tick();
      expect(h.api.patches, [('one', RedemptionStatus.canceled)]);
    },
  );

  test('live terminal update resolves a lost PATCH response without reading history', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    await h.queue.handleMessage(redemptionMessage('one'));
    h.api.patchError = DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.receiveTimeout,
    );
    await h.queue.confirmNow('one');
    expect(h.queue.entries.single.intent, RedemptionStatus.fulfilled);
    await h.queue.handleMessage(
      redemptionMessage(
        'one',
        type: 'update',
        status: RedemptionStatus.fulfilled,
      ),
    );
    await h.queue.retry('one');
    expect(h.api.patches, [('one', RedemptionStatus.fulfilled)]);
    expect(h.executor.calls, 1);
    expect(h.queue.entries, isEmpty);
  });

  test('terminal update arriving before add prevents replay', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    await h.queue.handleMessage(
      redemptionMessage(
        'one',
        type: 'update',
        status: RedemptionStatus.canceled,
      ),
    );
    await h.queue.handleMessage(redemptionMessage('one'));
    expect(h.executor.calls, 0);
    expect(h.queue.entries, isEmpty);
    expect(h.queue.find('one'), isNull);
  });

  test('other applications rewards execute without settlement', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    h.settings.rewards.rewards.single.unlinkFromTwitch();
    await h.queue.handleMessage(redemptionMessage('other', rewardId: 'other'));
    expect(h.executor.calls, 1);
    expect(h.queue.entries, isEmpty);
    expect(h.api.patches, isEmpty);
  });

  test('account switch clears memory and ignores an old response', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    await h.queue.handleMessage(redemptionMessage('one'));
    final gate = Completer<void>();
    h.api.beforePatch = () => gate.future;
    final deciding = h.queue.confirmNow('one');
    await flushQueue();
    await h.settings.saveTwitchAuth(credentials('another-channel'));
    await flushQueue();
    gate.complete();
    await deciding;
    expect(h.queue.entries, isEmpty);
    expect(h.queue.find('one'), isNull);
  });

  test('restart starts empty and forgets pending deadlines', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    await h.queue.handleMessage(redemptionMessage('waiting'));
    h.queue.toggleTimer('waiting');
    expect(h.queue.find('waiting')!.isPaused, isTrue);
    h.api.statuses['waiting'] = RedemptionStatus.unfulfilled;
    await h.queue.close();
    h.clock = h.clock.add(const Duration(hours: 1));
    await h.start();
    expect(h.queue.entries, isEmpty);
    expect(h.queue.find('waiting'), isNull);
    await h.queue.tick();
    expect(h.api.patches, isEmpty);
    expect(h.executor.calls, 1);
    await h.queue.handleMessage(redemptionMessage('new'));
    expect(h.queue.entries.single.id, 'new');
    expect(h.executor.calls, 2);
    expect(h.api.avatarReads, 2);
  });

  test(
    'unknown live updates never populate the queue or load viewer data',
    () async {
      final h = await QueueHarness.create();
      addTearDown(h.close);
      h.api.statuses['old'] = RedemptionStatus.unfulfilled;
      await h.queue.handleMessage(redemptionMessage('old', type: 'update'));
      await h.queue.handleMessage(
        redemptionMessage(
          'completed',
          type: 'update',
          status: RedemptionStatus.fulfilled,
        ),
      );
      expect(h.queue.entries, isEmpty);
      expect(h.queue.find('old'), isNull);
      expect(h.queue.find('completed'), isNull);
      expect(h.executor.calls, 0);
      expect(h.api.patches, isEmpty);
      expect(h.api.avatarReads, 0);
    },
  );

  test(
    'restart forgets failed decisions instead of retrying old writes',
    () async {
      final h = await QueueHarness.create();
      addTearDown(h.close);
      await h.queue.handleMessage(redemptionMessage('one'));
      h.api.patchError = DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );
      await h.queue.refund('one');
      expect(h.queue.entries.single.intent, RedemptionStatus.canceled);
      await h.queue.close();
      await h.start();
      h.clock = h.clock.add(const Duration(hours: 1));
      await h.queue.tick();
      expect(h.queue.entries, isEmpty);
      expect(h.api.patches, [('one', RedemptionStatus.canceled)]);
      expect(h.executor.calls, 1);
    },
  );

  test('enables delayed confirmation only for owned rewards and reports failed setup', () async {
    final h = await QueueHarness.create();
    addTearDown(h.close);
    h.api.entries = [
      remoteReward('own', 'Music', skipRequestQueue: true),
      remoteReward('other', 'Foreign', skipRequestQueue: true),
    ];
    h.api.save = (id, value) async {
      expect(id, 'own');
      expect(value.skipRequestQueue, isFalse);
      throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );
    };
    await h.queue.retrySetup();
    expect(h.queue.setupError, TwitchRewardsError.network);
    h.api.save = (id, value) async {
      h.api.entries = [
        remoteReward('own', 'Music'),
        remoteReward('other', 'Foreign', skipRequestQueue: true),
      ];
      return h.api.entries.first;
    };
    await h.queue.retrySetup();
    expect(h.queue.setupError, isNull);
    expect(h.api.writes, 2);
    expect(h.api.entries.last.skipRequestQueue, isTrue);
  });
}
