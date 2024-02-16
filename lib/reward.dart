import 'package:uuid/uuid.dart';

class Reward {
  String name;

  final String id;
  final List<RewardAction> handlers;

  bool expanded;

  Reward({required this.name, required this.handlers, this.expanded = false})
      : id = const Uuid().v4();

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
  static const typeFlipSource = 'flip_source';
  static const typeEnableSource = 'enable_source';

  final String type;

  String? inputName;

  bool enable;

  int duration;

  String? filePath;

  String? sourceName;

  String? filterName;

  String? sceneName;

  bool horizontal;
  bool vertical;

  RewardAction(
      {required this.type,
      this.enable = false,
      this.inputName,
      this.filePath,
      this.sourceName,
      this.filterName,
      this.sceneName,
      this.horizontal = false,
      this.vertical = false,
      this.duration = 0});

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'enable': enable,
      'filePath': filePath,
      'inputName': inputName,
      'sourceName': sourceName,
      'filterName': filterName,
      'sceneName': sceneName,
      'duration': duration,
      'horizontal': horizontal,
      'vertical': vertical
    };
  }

  static RewardAction fromJson(dynamic json) {
    return RewardAction(
        type: json['type'] as String,
        horizontal: json['horizontal'] as bool? ?? false,
        vertical: json['vertical'] as bool? ?? false,
        duration: json['duration'] as int? ?? 0,
        enable: json['enable'] as bool? ?? false,
        filePath: json['filePath'] as String?,
        sourceName: json['sourceName'] as String?,
        filterName: json['filterName'] as String?,
        sceneName: json['sceneName'] as String?,
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
