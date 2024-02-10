class Reward {
  final String name;

  final List<RewardAction> handlers;

  Reward({required this.name, required this.handlers});

  Map<String, dynamic> toJson() {
    return {'name': name, 'handlers': handlers.map((e) => e.toJson()).toList()};
  }

  static Reward fromJson(dynamic json) {
    return Reward(
        name: json['name'] as String,
        handlers: (json['handlers'] as List<dynamic>)
            .map(RewardAction.fromJson)
            .toList());
  }
}

class RewardAction {
  final String type;

  RewardAction({required this.type});

  Map<String, dynamic> toJson() {
    return {'type': type};
  }

  static RewardAction fromJson(dynamic json) {
    return RewardAction(type: json['type'] as String);
  }
}

class Rewards {
  final List<Reward> rewards;

  Rewards({required this.rewards});

  Map<String, dynamic> toJson() {
    return {'rewards': rewards.map((e) => e.toJson()).toList()};
  }

  static Rewards fromJson(dynamic json) {
    return Rewards(
        rewards:
            (json['rewards'] as List<dynamic>).map(Reward.fromJson).toList());
  }
}
