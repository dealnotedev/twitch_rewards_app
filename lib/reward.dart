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
  static const typePlayAudio = 'play_audio';
  static const typeEnableFilter = 'enable_filter';
  static const typeInvertFilter = 'invert_filter';

  final String type;

  String? inputName;

  bool enable;

  int duration;

  String? filePath;

  String? sourceName;

  String? filterName;

  RewardAction(
      {required this.type,
      this.enable = false,
      this.inputName,
      this.filePath,
      this.sourceName,
      this.filterName,
      this.duration = 0});

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'enable': enable,
      'filePath': filePath,
      'inputName': inputName,
      'sourceName': sourceName,
      'filterName': filterName,
      'duration': duration
    };
  }

  static RewardAction fromJson(dynamic json) {
    return RewardAction(
        type: json['type'] as String,
        duration: json['duration'] as int? ?? 0,
        enable: json['enable'] as bool? ?? false,
        filePath: json['filePath'] as String?,
        sourceName: json['sourceName'] as String?,
        filterName: json['filterName'] as String?,
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
