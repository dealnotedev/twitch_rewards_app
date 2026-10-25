import 'redemption.dart';
import 'rewards_controller.dart';

enum RedemptionQueueState { executing, waiting, confirmed, refunded }

/// A live in-memory entry belongs to one OAuth application and one channel.
class RedemptionQueueEntry {
  final String account;
  final TwitchRedemption redemption;
  RedemptionQueueState state;
  bool? manageable;
  DateTime? confirmAt;
  RedemptionStatus? intent;
  TwitchRewardsError? error;
  String? avatarUrl;

  RedemptionQueueEntry({
    required this.account,
    required this.redemption,
    this.state = RedemptionQueueState.executing,
    this.manageable,
    this.confirmAt,
    this.intent,
    this.error,
    this.avatarUrl,
  });

  String get id => redemption.id;
  bool get terminal =>
      state == RedemptionQueueState.confirmed ||
      state == RedemptionQueueState.refunded;
}
