/// Helix uses uppercase statuses; EventSub sends their lowercase equivalents.
enum RedemptionStatus {
  unfulfilled,
  fulfilled,
  canceled;

  String get wireValue => name.toUpperCase();

  static RedemptionStatus parse(String value) => switch (value.toLowerCase()) {
    'unfulfilled' => unfulfilled,
    'fulfilled' => fulfilled,
    'canceled' || 'cancelled' => canceled,
    _ => throw FormatException('Unknown redemption status', value),
  };
}

class TwitchRedemption {
  final String id;
  final String broadcasterId;
  final String rewardId;
  final String title;
  final int cost;
  final String userId;
  final String userName;
  final String userInput;
  final DateTime redeemedAt;
  final RedemptionStatus status;

  const TwitchRedemption({
    required this.id,
    required this.broadcasterId,
    required this.rewardId,
    required this.title,
    required this.cost,
    required this.userId,
    required this.userName,
    required this.userInput,
    required this.redeemedAt,
    required this.status,
  });

  factory TwitchRedemption.fromJson(dynamic json) => TwitchRedemption(
    id: json['id'] as String,
    broadcasterId:
        (json['broadcaster_id'] ?? json['broadcaster_user_id']) as String,
    rewardId: json['reward']['id'] as String,
    title: json['reward']['title'] as String,
    cost: json['reward']['cost'] as int,
    userId: json['user_id'] as String,
    userName: json['user_name'] as String,
    userInput: json['user_input'] as String? ?? '',
    redeemedAt: DateTime.parse(json['redeemed_at'] as String),
    status: RedemptionStatus.parse(json['status'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'broadcaster_id': broadcasterId,
    'reward': {'id': rewardId, 'title': title, 'cost': cost},
    'user_id': userId,
    'user_name': userName,
    'user_input': userInput,
    'redeemed_at': redeemedAt.toUtc().toIso8601String(),
    'status': status.wireValue,
  };
}
