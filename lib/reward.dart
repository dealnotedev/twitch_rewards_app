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
  static const typePlayAudios = 'play_audios';
  static const typeEnableFilter = 'enable_filter';
  static const typeInvertFilter = 'invert_filter';
  static const typeFlipSource = 'flip_source';
  static const typeEnableSource = 'enable_source';
  static const typeSetScene = 'set_scene';
  static const typeCrashProcess = 'crash_process';
  static const typeToggleSource = 'toggle_source';
  static const typeSendInput = 'send_input';

  final String type;

  final String id;

  String? inputName;

  bool enable;

  int duration;

  String? filePath;

  String? sourceName;

  String? filterName;

  String? sceneName;

  bool horizontal;
  bool vertical;

  String? target;

  List<String> targets;

  List<InputEntry> inputs;

  bool awaitCompletion;

  int? count;

  bool randomize;

  RewardAction(
      {required this.type,
      this.enable = false,
      this.inputName,
      this.filePath,
      this.sourceName,
      this.filterName,
      this.sceneName,
      this.target,
      this.count,
      this.randomize = false,
      this.awaitCompletion = false,
      this.horizontal = false,
      this.vertical = false,
      List<String>? targets,
      this.inputs = const [],
      this.duration = 0})
      : id = const Uuid().v4(),
        targets = targets ?? <String>[];

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
      'target': target,
      'horizontal': horizontal,
      'vertical': vertical,
      'targets': targets,
      'count': count,
      'randomize': randomize,
      'awaitCompletion': awaitCompletion,
      'inputs': inputs.map((e) => e.toJson()).toList()
    };
  }

  static RewardAction fromJson(dynamic json) {
    final targetsJson = json['targets'] as List<dynamic>?;
    final inputsJson = json['inputs'] as List<dynamic>?;
    return RewardAction(
        randomize: json['randomize'] as bool? ?? false,
        count: json['count'] as int?,
        type: json['type'] as String,
        horizontal: json['horizontal'] as bool? ?? false,
        vertical: json['vertical'] as bool? ?? false,
        duration: json['duration'] as int? ?? 0,
        enable: json['enable'] as bool? ?? false,
        filePath: json['filePath'] as String?,
        target: json['target'] as String?,
        awaitCompletion: json['awaitCompletion'] as bool? ?? false,
        targets: targetsJson != null
            ? targetsJson.map((e) => e.toString()).toList()
            : [],
        inputs: inputsJson != null
            ? inputsJson.map(InputEntry.fromJson).toList()
            : [],
        sourceName: json['sourceName'] as String?,
        filterName: json['filterName'] as String?,
        sceneName: json['sceneName'] as String?,
        inputName: json['inputName'] as String?);
  }
}

class InputEntry {
  final int code;
  final int type;
  final String name;

  InputEntry({required this.code, required this.type, required this.name});

  static InputEntry fromJson(dynamic json) {
    return InputEntry(
        code: json['code'] as int,
        type: json['type'] as int,
        name: json['name'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'code': code, 'type': type, 'name': name};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InputEntry &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          type == other.type &&
          name == other.name;

  @override
  int get hashCode => code.hashCode ^ type.hashCode ^ name.hashCode;

  @override
  String toString() {
    return name;
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
