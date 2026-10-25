import 'package:dio/dio.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/twitch/dto.dart';
import 'package:twitch_listener/twitch/twitch_creds_interceptor.dart';
import 'package:twitch_listener/twitch/reward_settings.dart';
import 'package:twitch_listener/twitch/redemption.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';

class Statuses {
  static const resolved = 'RESOLVED';
  static const active = 'ACTIVE';
  static const locked = 'LOCKED';
  static const canceled = 'CANCELED';
}

class TwitchApi {
  late final Dio dio;

  final String broadcasterId;

  void close() => dio.close(force: true);

  TwitchApi({
    required Settings settings,
    required String clientSecret,
    required this.broadcasterId,
    TwitchCreds? expectedCredentials,
  }) {
    final interceptor = TwitchCredsInterceptor(
      settings: settings,
      clientSecret: clientSecret,
      expectedCredentials: expectedCredentials,
    );
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.twitch.tv/helix',
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    if (expectedCredentials != null) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final current = settings.twitchAuth;
            if (current?.clientId != expectedCredentials.clientId ||
                current?.broadcasterId != expectedCredentials.broadcasterId) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                  error: StateError('Twitch account changed'),
                ),
              );
            } else {
              handler.next(options);
            }
          },
        ),
      );
    }
    dio.interceptors.add(interceptor);
  }

  Future<int> cleanupInactiveEventSubs() async {
    final resp = await dio.get('/eventsub/subscriptions');
    final data = (resp.data['data'] as List).cast<Map<String, dynamic>>();

    int count = 0;

    for (final sub in data) {
      final status = sub['status'];
      final id = sub['id'];

      if (status == 'websocket_disconnected') {
        await dio.delete(
          '/eventsub/subscriptions',
          queryParameters: {'id': id},
        );
        count++;
      }
    }

    return count;
  }

  Future<void> subscribeCustomRewards({
    required String? broadcasterUserId,
    required String sessionId,
    bool updates = false,
  }) {
    final data = {
      'version': '1',
      'type':
          'channel.channel_points_custom_reward_redemption.${updates ? 'update' : 'add'}',
      'condition': {'broadcaster_user_id': broadcasterUserId},
      'transport': {'session_id': sessionId, 'method': 'websocket'},
    };

    return dio.post('/eventsub/subscriptions', data: data);
  }

  Future<TwitchRedemption> setRedemptionStatus({
    required String rewardId,
    required String redemptionId,
    required RedemptionStatus status,
  }) async {
    if (status == RedemptionStatus.unfulfilled) {
      throw ArgumentError.value(status);
    }
    final response = await dio.patch(
      '/channel_points/custom_rewards/redemptions',
      queryParameters: {
        'broadcaster_id': broadcasterId,
        'reward_id': rewardId,
        'id': redemptionId,
      },
      data: {'status': status.wireValue},
    );
    return TwitchRedemption.fromJson(response.data['data'][0]);
  }

  Future<UserDto?> getViewer(String id) async {
    final response = await dio.get('/users', queryParameters: {'id': id});
    final users = response.data['data'] as List<dynamic>;
    return users.isEmpty ? null : UserDto.fromJson(users.first);
  }

  Future<void> deleteChatMessage({
    required String broadcasterUserId,
    required String messageId,
  }) {
    return dio.delete(
      '/moderation/chat',
      queryParameters: {
        'broadcaster_id': broadcasterUserId,
        'moderator_id': broadcasterUserId,
        'message_id': messageId,
      },
    );
  }

  Future<List<RedemptionDto>> getCustomRewards({bool onlyManageable = false}) {
    return dio
        .get(
          '/channel_points/custom_rewards',
          queryParameters: {
            'broadcaster_id': broadcasterId,
            if (onlyManageable) 'only_manageable_rewards': true,
          },
        )
        .then((response) => response.data)
        .then((json) {
          return ((json['data'] as List<dynamic>)
              .map(RedemptionDto.fromJson)
              .toList());
        });
  }

  Future<Set<String>> getGrantedScopes() async {
    final response = await dio.get('https://id.twitch.tv/oauth2/validate');
    return (response.data['scopes'] as List<dynamic>).cast<String>().toSet();
  }

  Future<RedemptionDto> createCustomReward(
    TwitchRewardSettings settings,
  ) async {
    final response = await dio.post(
      '/channel_points/custom_rewards',
      queryParameters: {'broadcaster_id': broadcasterId},
      data: settings.toJson(creating: true),
    );
    return RedemptionDto.fromJson(response.data['data'][0]);
  }

  Future<RedemptionDto> updateCustomReward(
    String id,
    TwitchRewardSettings settings,
  ) async {
    final response = await dio.patch(
      '/channel_points/custom_rewards',
      queryParameters: {'broadcaster_id': broadcasterId, 'id': id},
      data: settings.toJson(),
    );
    return RedemptionDto.fromJson(response.data['data'][0]);
  }

  Future<void> subscribeChat({
    required String? broadcasterUserId,
    required String sessionId,
  }) {
    final data = {
      'version': '1',
      'type': 'channel.chat.message',
      'condition': {
        'broadcaster_user_id': broadcasterUserId,
        'user_id': broadcasterUserId,
      },
      'transport': {'session_id': sessionId, 'method': 'websocket'},
    };

    return dio.post('/eventsub/subscriptions', data: data);
  }

  Future<void> subscribeFollowEvents({
    required String? broadcasterUserId,
    required String sessionId,
  }) {
    final data = {
      'version': '2',
      'type': 'channel.follow',
      'condition': {
        'broadcaster_user_id': broadcasterUserId,
        'moderator_user_id': broadcasterUserId,
      },
      'transport': {'session_id': sessionId, 'method': 'websocket'},
    };

    return dio.post('/eventsub/subscriptions', data: data);
  }

  Future<UserDto> getUser() {
    return dio
        .get('/users')
        .then((value) => value.data)
        .then((value) => value['data'] as List<dynamic>)
        .then((value) => value[0])
        .then(UserDto.fromJson);
  }

  Future<List<StreamDto>> getStreams({required String? broadcasterId}) {
    return dio
        .get('/streams', queryParameters: {'user_id': broadcasterId})
        .then((value) => value.data)
        .then((json) => json['data'] as List<dynamic>)
        .then((value) => value.map(StreamDto.fromJson).toList());
  }

  Future<Prediction> endPrediction({
    required String? broadcasterId,
    required String id,
    required String status,
    required String? winningOutcomeId,
  }) {
    return dio
        .patch(
          '/predictions',
          data: {
            'broadcaster_id': broadcasterId,
            'id': id,
            'status': status,
            'winning_outcome_id': ?winningOutcomeId,
          },
        )
        .then((value) => value.data)
        .then(_parseResponse)
        .then((value) => value[0]);
  }

  Future<Prediction> createPrediction({
    required String? broadcasterId,
    required String title,
    required List<String> outcomes,
    required int predictionWindow,
  }) {
    return dio
        .post(
          '/predictions',
          data: {
            'broadcaster_id': broadcasterId,
            'title': title,
            'outcomes': outcomes.map((e) => {'title': e}).toList(),
            'prediction_window': predictionWindow,
          },
        )
        .then((value) => value.data)
        .then(_parseResponse)
        .then((value) => value[0]);
  }

  Future<List<Prediction>> getPredictions({
    required String? broadcasterId,
    required int? count,
    required String? after,
    String? predictionId,
  }) {
    return dio
        .get(
          '/predictions',
          queryParameters: {
            'first': ?count,
            'after': ?after,
            'id': ?predictionId,
            'broadcaster_id': broadcasterId,
          },
        )
        .then((value) => value.data)
        .then(_parseResponse);
  }

  List<Prediction> _parseResponse(dynamic json) =>
      (json['data'] as List<dynamic>).map(Prediction.fromJson).toList();
}
