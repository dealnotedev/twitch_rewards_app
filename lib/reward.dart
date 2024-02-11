class Reward {
  String name;

  final List<RewardAction> handlers;

  bool expanded;

  Reward({required this.name, required this.handlers, this.expanded = false});

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
  static const typeEnableInput = 'enable_input';
  static const typeDelay = 'delay';

  final String type;

  String? inputName;

  bool enable;

  int duration;

  RewardAction(
      {required this.type,
      this.enable = false,
      this.inputName,
      this.duration = 0});

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'enable': enable,
      'inputName': inputName,
      'duration': duration
    };
  }

  static RewardAction fromJson(dynamic json) {
    return RewardAction(
        type: json['type'] as String,
        duration: json['duration'] as int? ?? 0,
        enable: json['enable'] as bool? ?? false,
        inputName: json['inputName'] as String?);
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
