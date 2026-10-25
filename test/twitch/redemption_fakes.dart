import 'dart:async';

import 'package:twitch_listener/autosaver.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_execution.dart';
import 'package:twitch_listener/reward_executor.dart';
import 'package:twitch_listener/twitch/dto.dart';
import 'package:twitch_listener/twitch/redemption.dart';
import 'package:twitch_listener/twitch/redemption_queue_controller.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';
import 'package:twitch_listener/twitch/ws_event.dart';
import 'package:twitch_listener/twitch_shared.dart';

import 'rewards_fakes.dart';

TwitchRedemption redemption(
  String id, {
  String rewardId = 'own',
  RedemptionStatus status = RedemptionStatus.unfulfilled,
}) => TwitchRedemption(
  id: id,
  broadcasterId: 'channel',
  rewardId: rewardId,
  title: 'Music',
  cost: 750,
  userId: 'viewer',
  userName: 'Viewer',
  userInput: 'hello',
  redeemedAt: DateTime.utc(2026, 10, 25),
  status: status,
);

WsMessage redemptionMessage(
  String id, {
  String type = 'add',
  String rewardId = 'own',
  RedemptionStatus status = RedemptionStatus.unfulfilled,
}) => WsMessage.fromJson({
  'payload': {
    'subscription': {
      'type': 'channel.channel_points_custom_reward_redemption.$type',
    },
    'event': {
      ...redemption(id, rewardId: rewardId, status: status).toJson(),
      'broadcaster_user_id': 'channel',
      'status': status.name,
    },
  },
});

class RedemptionTestApi extends RewardTestApi {
  final statuses = <String, RedemptionStatus>{};
  final patches = <(String, RedemptionStatus)>[];
  Future<void> Function()? beforePatch;
  Object? patchError;
  int avatarReads = 0;

  @override
  Future<TwitchRedemption> setRedemptionStatus({
    required String rewardId,
    required String redemptionId,
    required RedemptionStatus status,
  }) async {
    patches.add((redemptionId, status));
    await beforePatch?.call();
    statuses[redemptionId] = status;
    final error = patchError;
    patchError = null;
    if (error != null) throw error;
    return redemption(redemptionId, status: status);
  }

  @override
  Future<UserDto?> getViewer(String id) async {
    avatarReads++;
    return UserDto(
      id: id,
      login: 'viewer',
      displayName: 'Viewer',
      profileImageUrl: 'https://example.com/viewer.png',
    );
  }
}

class RedemptionTestExecutor implements RewardExecutor {
  int calls = 0;
  Future<void> Function(RewardExecution?)? run;
  @override
  Future<void> execute(
    Reward reward, {
    String? userInput,
    String requester = '',
    RewardExecution? execution,
  }) async {
    calls++;
    await run?.call(execution);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class QueueHarness {
  final settings = RewardTestSettings(
    localRewards: [
      Reward(
        name: 'Music',
        handlers: [RewardAction(type: RewardAction.typeDelay)],
      )..linkToTwitch(
        rewardId: 'own',
        broadcasterId: 'channel',
        title: 'Music',
      ),
    ],
  );
  final api = RedemptionTestApi();
  final executor = RedemptionTestExecutor();
  final shared = TwitchShared();
  DateTime clock = DateTime.utc(2026, 10, 25, 12);
  late TwitchRewardsController rewards;
  late RedemptionQueueController queue;

  static Future<QueueHarness> create() async {
    final harness = QueueHarness();
    harness.rewards = TwitchRewardsController(
      settings: harness.settings,
      shared: harness.shared,
      autosaver: Autosaver(delay: Duration.zero),
      createApi: (_) => harness.api,
      authorize: () async => null,
    );
    await harness.rewards.refresh();
    await harness.start();
    return harness;
  }

  Future<void> start() async {
    queue = RedemptionQueueController(
      settings: settings,
      rewards: rewards,
      executor: executor,
      createApi: (_) => api,
      now: () => clock,
      startTimer: false,
    );
    await flushQueue();
  }

  Future<void> close() async {
    await queue.close();
    rewards.dispose();
    await settings.authChanges.close();
    shared.redemptions.dispose();
    for (final reward in settings.rewards.rewards) {
      for (final action in reward.handlers) {
        action.dispose();
      }
    }
  }
}

Future<void> flushQueue() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
