class Prediction {
  final String id;
  final String broadcasterId;
  final String broadcasterName;
  final String broadcasterLogin;
  final String title;
  final String? winningOutcomeId;
  final int predictionWindow;
  final String status;
  final DateTime createdAt;
  final DateTime? lockedAt;
  final DateTime? endedAt;

  final List<Outcome> outcomes;

  Prediction(
      {required this.id,
      required this.broadcasterId,
      required this.broadcasterName,
      required this.broadcasterLogin,
      required this.title,
      required this.winningOutcomeId,
      required this.predictionWindow,
      required this.status,
      required this.outcomes,
      required this.createdAt,
      required this.lockedAt,
      required this.endedAt});

  static Prediction fromJson(dynamic json) {
    return Prediction(
        id: json['id'] as String,
        outcomes:
            (json['outcomes'] as List<dynamic>).map(Outcome.fromJson).toList(),
        broadcasterId: json['broadcaster_id'] as String,
        broadcasterName: json['broadcaster_name'] as String,
        broadcasterLogin: json['broadcaster_login'] as String,
        title: json['title'] as String,
        winningOutcomeId: json['winning_outcome_id'] as String?,
        predictionWindow: json['prediction_window'] as int,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        lockedAt: _parseOptionalDate(json, 'locked_at'),
        endedAt: _parseOptionalDate(json, 'ended_at'));
  }

  static DateTime? _parseOptionalDate(dynamic json, String name) {
    final value = json[name] as String?;
    return value != null ? DateTime.parse(value).toLocal() : null;
  }
}

class Outcome {
  final String id;
  final String title;
  final int users;
  final int channelPoints;
  final String color;
  final List<Predictor> topPredictors;

  Outcome(
      {required this.id,
      required this.title,
      required this.users,
      required this.channelPoints,
      required this.color,
      required this.topPredictors});

  static Outcome fromJson(dynamic json) {
    return Outcome(
        id: json['id'] as String,
        title: json['title'] as String,
        users: json['users'] as int? ?? 0,
        channelPoints: json['channelPoints'] as int? ?? 0,
        color: json['color'] as String,
        topPredictors: (json['topPredictors'] as List<dynamic>? ?? [])
            .map(Predictor.fromJson)
            .toList());
  }
}

class Predictor {
  final String userId;
  final String userName;
  final String userLogin;
  final int channelPointsUsed;
  final int channelPointsWon;

  Predictor(
      {required this.userId,
      required this.userName,
      required this.userLogin,
      required this.channelPointsUsed,
      required this.channelPointsWon});

  static Predictor fromJson(dynamic json) => Predictor(
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userLogin: json['user_login'] as String,
      channelPointsUsed: json['channel_points_used'] as int,
      channelPointsWon: json['channel_points_won'] as int);
}

class StreamDto {
  final int viewerCount;
  final String userId;

  StreamDto({required this.viewerCount, required this.userId});

  static StreamDto fromJson(dynamic json) => StreamDto(
      viewerCount: json['viewer_count'] as int,
      userId: json['user_id'] as String);
}

class RedemptionDto {
  final String id;
  final bool enabled;
  final int cost;
  final String title;
  final String? prompt;
  final bool userInputRequired;
  final bool paused;
  final bool isInStock;

  final ImageDto? image;
  final ImageDto defaultImage;

  RedemptionDto(
      {required this.id,
      required this.enabled,
      required this.cost,
      required this.title,
      required this.prompt,
      required this.userInputRequired,
      required this.paused,
      required this.isInStock,
      required this.defaultImage,
      required this.image});

  static RedemptionDto fromJson(dynamic json) {
    final imageJson = json['image'];
    return RedemptionDto(
        id: json['id'] as String,
        enabled: json['is_enabled'] as bool,
        cost: json['cost'] as int,
        title: json['title'] as String,
        prompt: json['prompt'] as String?,
        userInputRequired: json['is_user_input_required'] as bool,
        paused: json['is_paused'] as bool,
        isInStock: json['is_in_stock'] as bool,
        defaultImage: ImageDto.fromJson(json['default_image']),
        image: imageJson != null ? ImageDto.fromJson(imageJson) : null);
  }

  @override
  String toString() {
    return title;
  }
}

class ImageDto {
  final String url1x;
  final String url2x;
  final String url4x;

  ImageDto({required this.url1x, required this.url2x, required this.url4x});

  static ImageDto fromJson(dynamic json) {
    return ImageDto(
        url1x: json['url_1x'] as String,
        url2x: json['url_2x'] as String,
        url4x: json['url_4x'] as String);
  }
}

class UserDto {
  final String id;
  final String login;
  final String? displayName;
  final String? profileImageUrl;

  UserDto(
      {required this.id,
      required this.login,
      required this.displayName,
      required this.profileImageUrl});

  static UserDto fromJson(dynamic json) {
    return UserDto(
        id: json['id'] as String,
        login: json['login'] as String,
        displayName: json['display_name'] as String?,
        profileImageUrl: json['profile_image_url'] as String?);
  }
}
