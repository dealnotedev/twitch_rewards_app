import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:twitch_listener/reward_execution.dart';
import 'package:twitch_listener/reward_executor.dart';
import 'package:twitch_listener/settings.dart';

import 'redemption.dart';
import 'redemption_queue_entry.dart';
import 'rewards_controller.dart';
import 'reward_settings.dart';
import 'twitch_api.dart';
import 'twitch_creds.dart';
import 'ws_event.dart';

/// Owns live redemptions and their ten-minute return window in memory.
/// A new instance starts empty; retries never replay a reaction.
class RedemptionQueueController extends ChangeNotifier {
  static const confirmationDelay = Duration(minutes: 10);
  final Settings settings;
  final TwitchRewardsController rewards;
  final RewardExecutor executor;
  final TwitchApi Function(TwitchCreds) createApi;
  final DateTime Function() now;
  final _entries = <String, RedemptionQueueEntry>{};
  final _seen = <String>{};
  final _operations = <String, Future<void>>{};
  final _executions = <String, RewardExecution>{};
  final _retryAt = <String, DateTime>{};
  final _avatars = <String, Future<String?>>{};
  late final StreamSubscription<TwitchCreds?> _authSubscription;
  StreamSubscription<WsMessage>? _messagesSubscription;
  Timer? _timer;
  String? _account;
  int _generation = 0;
  bool _closed = false;
  bool _configuring = false;
  TwitchRewardsError? setupError;

  RedemptionQueueController({
    required this.settings,
    required this.rewards,
    required this.executor,
    required this.createApi,
    DateTime Function()? now,
    Stream<WsMessage>? messages,
    bool startTimer = true,
  }) : now = now ?? DateTime.now {
    _account = accountKey;
    rewards.addListener(_permissionsChanged);
    _authSubscription = settings.twitchAuthChanges.listen((_) {
      if (_account == accountKey) return;
      _generation++;
      _account = accountKey;
      _clear();
      _configuring = false;
      setupError = null;
      _notify();
    });
    _messagesSubscription = messages?.listen((message) {
      unawaited(handleMessage(message).catchError(_backgroundError));
    });
    _permissionsChanged();
    if (startTimer) {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(tick()),
      );
    }
  }

  String? get accountKey {
    final auth = settings.twitchAuth;
    return auth == null ? null : '${auth.clientId}:${auth.broadcasterId}';
  }

  // New arrivals stay above older requests, regardless of execution or timers.
  List<RedemptionQueueEntry> get entries => _entries.values
      .where((entry) => entry.manageable == true && !entry.terminal)
      .toList()
      .reversed
      .toList();

  RedemptionQueueEntry? find(String id) => _entries[id];
  bool isBusy(String id) => _operations.containsKey('$accountKey:$id');
  bool canDecide(RedemptionQueueEntry entry) =>
      !_closed &&
      entry.account == accountKey &&
      entry.manageable == true &&
      !entry.terminal &&
      entry.intent == null &&
      !isBusy(entry.id) &&
      rewards.canEdit(entry.redemption.rewardId);

  bool _active(int generation) =>
      !_closed && generation == _generation && _account == accountKey;

  void _notify() {
    if (!_closed) notifyListeners();
  }

  void _backgroundError(Object error, [StackTrace? stack]) {
    if (!_closed) debugPrint('Redemption queue: $error');
  }

  void _clear() {
    for (final execution in _executions.values) {
      unawaited(execution.cancel());
    }
    _executions.clear();
    _entries.clear();
    _seen.clear();
    _retryAt.clear();
    _avatars.clear();
  }

  void _permissionsChanged() {
    if (_closed) return;
    if (rewards.manageabilityKnown) {
      for (final entry in _entries.values) {
        entry.manageable = rewards.isManageable(entry.redemption.rewardId);
      }
      if (!rewards.loading) {
        unawaited(
          _enableRequestQueue(_generation).catchError(_backgroundError),
        );
      }
    }
    _notify();
  }

  Future<void> _enableRequestQueue(int generation) async {
    final auth = settings.twitchAuth;
    if (auth == null || !rewards.manageabilityKnown || _configuring) return;
    final bypassed = rewards.rewards
        .where(
          (reward) =>
              reward.skipRequestQueue && rewards.isManageable(reward.id),
        )
        .toList();
    if (bypassed.isEmpty) {
      setupError = null;
      _notify();
      return;
    }
    if (!rewards.canManage) {
      setupError = TwitchRewardsError.authorization;
      _notify();
      return;
    }
    _configuring = true;
    final api = createApi(auth);
    try {
      for (final reward in bypassed) {
        if (!_active(generation)) return;
        await api.updateCustomReward(
          reward.id,
          TwitchRewardSettings.fromReward(reward, skipRequestQueue: false),
        );
      }
      if (_active(generation)) {
        setupError = null;
        await rewards.refresh();
      }
    } catch (error) {
      if (_active(generation)) {
        setupError = TwitchRewardsController.classifyError(error);
      }
    } finally {
      api.close();
      if (_active(generation)) _configuring = false;
      _notify();
    }
  }

  Future<void> retrySetup() async {
    if (setupError == TwitchRewardsError.authorization ||
        setupError == TwitchRewardsError.forbidden) {
      await rewards.connect();
    } else {
      await rewards.refresh();
    }
    if (!_closed) await _enableRequestQueue(_generation);
  }

  Future<void> handleMessage(WsMessage message) async {
    final generation = _generation;
    final auth = settings.twitchAuth;
    final event = message.payload.event;
    final type = message.payload.subscription?.type;
    const prefix = 'channel.channel_points_custom_reward_redemption.';
    if (auth == null ||
        event == null ||
        event.id == null ||
        event.reward?.id == null ||
        event.broadcasterUserId != auth.broadcasterId ||
        (type != '${prefix}add' && type != '${prefix}update')) {
      return;
    }
    final seenKey = '${auth.clientId}:${auth.broadcasterId}:${event.id!}';
    final status = RedemptionStatus.parse(
      event.redemptionStatus ?? 'unfulfilled',
    );
    if (type == '${prefix}update') {
      if (status != RedemptionStatus.unfulfilled) {
        // An update only resolves a live entry. It never imports a request.
        _seen.add(seenKey);
        final entry = _entries[event.id];
        if (entry != null && !entry.terminal) {
          _complete(entry, status, generation);
        }
      }
      return;
    }
    if (_entries.containsKey(event.id) || !_seen.add(seenKey)) return;
    final redemption = _fromEvent(event, status);
    final matches = settings.rewards.rewards
        .where(
          (reward) => reward.matchesRedemption(
            rewardId: redemption.rewardId,
            title: redemption.title,
            broadcasterId: redemption.broadcasterId,
          ),
        )
        .toList();
    final manageable = rewards.manageabilityKnown
        ? rewards.isManageable(redemption.rewardId)
        : null;
    if (status != RedemptionStatus.unfulfilled || manageable == false) {
      await Future.wait(
        matches.map((reward) async {
          try {
            await executor.execute(
              reward,
              userInput: redemption.userInput,
              requester: redemption.userName,
            );
          } catch (error) {
            debugPrint('Reward reaction: $error');
          }
        }),
      );
      return;
    }
    final entry = RedemptionQueueEntry(
      account: accountKey!,
      redemption: redemption,
      manageable: manageable,
    );
    _entries[entry.id] = entry;
    _notify();
    unawaited(_loadAvatar(entry, auth, generation));
    final execution = RewardExecution();
    _executions[entry.id] = execution;
    try {
      if (!matches.any(
        (reward) => reward.handlers.any((action) => !action.disabled),
      )) {
        throw StateError('No enabled reactions');
      }
      final scheduling = Future.wait(
        matches.map(
          (reward) => executor.execute(
            reward,
            userInput: redemption.userInput,
            requester: redemption.userName,
            execution: execution,
          ),
        ),
        eagerError: true,
      );
      await Future.any<void>([
        scheduling.then<void>((_) {}),
        execution.failure,
      ]);
      await execution.finish();
      if (!_active(generation) || entry.terminal || entry.intent != null) {
        return;
      }
      entry.state = RedemptionQueueState.waiting;
      entry.confirmAt = now().add(confirmationDelay);
      _notify();
    } catch (error) {
      await execution.cancel();
      if (!_active(generation) || entry.terminal || entry.intent != null) {
        return;
      }
      entry.state = RedemptionQueueState.waiting;
      entry.intent = RedemptionStatus.canceled;
      _notify();
      await _send(entry, generation);
    } finally {
      if (identical(_executions[entry.id], execution)) {
        _executions.remove(entry.id);
      }
    }
  }

  TwitchRedemption _fromEvent(WsMessageEvent event, RedemptionStatus status) =>
      TwitchRedemption(
        id: event.id!,
        broadcasterId: event.broadcasterUserId!,
        rewardId: event.reward!.id!,
        title: event.reward!.title,
        cost: event.reward!.cost,
        userId: event.userId ?? '',
        userName: event.userName ?? '',
        userInput: event.userInput ?? '',
        redeemedAt: event.redeemedAt ?? now(),
        status: status,
      );

  Future<void> _loadAvatar(
    RedemptionQueueEntry entry,
    TwitchCreds auth,
    int generation,
  ) async {
    if (entry.avatarUrl != null || entry.redemption.userId.isEmpty) return;
    try {
      final future = _avatars.putIfAbsent(entry.redemption.userId, () async {
        final api = createApi(auth);
        try {
          return (await api.getViewer(entry.redemption.userId))
              ?.profileImageUrl;
        } finally {
          api.close();
        }
      });
      final url = await future;
      if (!_active(generation) || url == null || url.isEmpty) return;
      entry.avatarUrl = url;
      _notify();
    } catch (_) {
      if (_active(generation)) _avatars.remove(entry.redemption.userId);
    }
  }

  Future<void> confirmNow(String id) => _decide(id, RedemptionStatus.fulfilled);
  Future<void> refund(String id) => _decide(id, RedemptionStatus.canceled);

  Future<void> _decide(String id, RedemptionStatus status) async {
    final entry = _entries[id];
    if (entry == null || !canDecide(entry)) return;
    // Claim the decision before yielding, so opposing clicks cannot race.
    entry.intent = status;
    entry.error = null;
    if (status == RedemptionStatus.canceled) {
      unawaited(_executions[id]?.cancel() ?? Future.value());
    }
    _notify();
    await _send(entry, _generation);
  }

  Future<void> retry(String id) async {
    final entry = _entries[id];
    if (entry == null || entry.terminal || entry.intent == null) return;
    await _send(entry, _generation);
  }

  Future<void> tick() async {
    if (_closed) return;
    for (final entry in _entries.values.toList()) {
      if (entry.manageable != true || entry.terminal || isBusy(entry.id)) {
        continue;
      }
      if (entry.intent == null &&
          entry.state == RedemptionQueueState.waiting &&
          entry.confirmAt != null &&
          !entry.confirmAt!.isAfter(now())) {
        entry.intent = RedemptionStatus.fulfilled;
      }
      if (entry.intent != null &&
          !(_retryAt[entry.id]?.isAfter(now()) ?? false)) {
        await _send(entry, _generation);
      }
    }
  }

  Future<void> _send(RedemptionQueueEntry entry, int generation) {
    final key = '${entry.account}:${entry.id}';
    if (_operations.containsKey(key)) return _operations[key]!;
    if (!_active(generation) ||
        entry.account != accountKey ||
        entry.terminal ||
        entry.manageable != true ||
        entry.intent == null) {
      return Future.value();
    }
    // Register first: synchronous EventSub responses or failures must see busy.
    final done = Completer<void>();
    _operations[key] = done.future;
    _notify();
    unawaited(
      _sendInternal(entry, generation).then(
        (_) {
          _operations.remove(key);
          done.complete();
          _notify();
        },
        onError: (Object error, StackTrace stack) {
          _operations.remove(key);
          done.completeError(error, stack);
          _notify();
        },
      ),
    );
    return done.future;
  }

  Future<void> _sendInternal(RedemptionQueueEntry entry, int generation) async {
    TwitchApi? api;
    try {
      if (!rewards.canEdit(entry.redemption.rewardId)) {
        throw const TwitchRewardsException(TwitchRewardsError.authorization);
      }
      api = createApi(settings.twitchAuth!);
      final result = await api.setRedemptionStatus(
        rewardId: entry.redemption.rewardId,
        redemptionId: entry.id,
        status: entry.intent!,
      );
      if (_active(generation) && !entry.terminal) {
        _complete(entry, result.status, generation);
      }
    } catch (error) {
      if (!_active(generation) || entry.terminal) return;
      // A lost response may still be resolved by a live EventSub update.
      entry.error = TwitchRewardsController.classifyError(error);
      _retryAt[entry.id] = now().add(const Duration(seconds: 30));
      _notify();
    } finally {
      api?.close();
    }
  }

  void _complete(
    RedemptionQueueEntry entry,
    RedemptionStatus status,
    int generation,
  ) {
    if (status == RedemptionStatus.unfulfilled || !_active(generation)) return;
    entry.state = status == RedemptionStatus.fulfilled
        ? RedemptionQueueState.confirmed
        : RedemptionQueueState.refunded;
    entry.intent = null;
    entry.error = null;
    _retryAt.remove(entry.id);
    if (status == RedemptionStatus.canceled) {
      unawaited(_executions[entry.id]?.cancel() ?? Future.value());
    }
    _notify();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    rewards.removeListener(_permissionsChanged);
    _clear();
    await _authSubscription.cancel();
    await _messagesSubscription?.cancel();
    await Future.wait(_operations.values.toList());
    super.dispose();
  }
}
