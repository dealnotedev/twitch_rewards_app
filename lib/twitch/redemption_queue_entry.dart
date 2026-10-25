import 'redemption.dart';
import 'rewards_controller.dart';

enum RedemptionQueueState { executing, waiting, confirmed, refunded, removed }

/// A live in-memory entry belongs to one OAuth application and one channel.
class RedemptionQueueEntry {
  final String account;
  final TwitchRedemption redemption;
  RedemptionQueueState state;
  bool? manageable;
  DateTime? confirmAt;
  Duration? pausedRemaining;
  RedemptionStatus? intent;
  TwitchRewardsError? error;
  String? avatarUrl;

  RedemptionQueueEntry({
    required this.account,
    required this.redemption,
    this.state = RedemptionQueueState.executing,
    this.manageable,
    this.confirmAt,
    this.pausedRemaining,
    this.intent,
    this.error,
    this.avatarUrl,
  });

  String get id => redemption.id;
  bool get isPaused => pausedRemaining != null;
  bool get hasTimer => confirmAt != null || isPaused;

  Duration remainingAt(DateTime time) {
    final remaining =
        pausedRemaining ?? confirmAt?.difference(time) ?? Duration.zero;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get terminal =>
      state == RedemptionQueueState.confirmed ||
      state == RedemptionQueueState.refunded ||
      state == RedemptionQueueState.removed;
}
