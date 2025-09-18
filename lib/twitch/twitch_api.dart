import 'package:dio/dio.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/twitch/dto.dart';
import 'package:twitch_listener/twitch/twitch_creds_interceptor.dart';

class Statuses {
  static const resolved = 'RESOLVED';
  static const active = 'ACTIVE';
  static const locked = 'LOCKED';
  static const canceled = 'CANCELED';
}

class TwitchApi {
  late final Dio dio;

  final String broadcasterId;

  TwitchApi(
      {required Settings settings,
      required String clientSecret,
      required this.broadcasterId}) {
    final interceptor =
        TwitchCredsInterceptor(settings: settings, clientSecret: clientSecret);
    dio = Dio(BaseOptions(baseUrl: 'https://api.twitch.tv/helix'));
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

  Future<void> subscribeCustomRewards(
      {required String? broadcasterUserId, required String sessionId}) {
    final data = {
      'version': '1',
      'type': 'channel.channel_points_custom_reward_redemption.add',
      'condition': {'broadcaster_user_id': broadcasterUserId},
      'transport': {'session_id': sessionId, 'method': 'websocket'}
    };

    return dio.post('/eventsub/subscriptions', data: data);
  }

  Future<List<RedemptionDto>> getCustomRewards() {
    return dio
        .get('/channel_points/custom_rewards',
            queryParameters: {'broadcaster_id': broadcasterId})
        .then((response) => response.data)
        .then((json) {
          return ((json['data'] as List<dynamic>)
              .map(RedemptionDto.fromJson)
              .toList());
        });
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

  Future<Prediction> endPrediction(
      {required String? broadcasterId,
      required String id,
      required String status,
      required String? winningOutcomeId}) {
    return dio
        .patch('/predictions', data: {
          'broadcaster_id': broadcasterId,
          'id': id,
          'status': status,
          if (winningOutcomeId != null) 'winning_outcome_id': winningOutcomeId
        })
        .then((value) => value.data)
        .then(_parseResponse)
        .then((value) => value[0]);
  }

  Future<Prediction> createPrediction(
      {required String? broadcasterId,
      required String title,
      required List<String> outcomes,
      required int predictionWindow}) {
    return dio
        .post('/predictions', data: {
          'broadcaster_id': broadcasterId,
          'title': title,
          'outcomes': outcomes.map((e) => {'title': e}).toList(),
          'prediction_window': predictionWindow
        })
        .then((value) => value.data)
        .then(_parseResponse)
        .then((value) => value[0]);
  }

  Future<List<Prediction>> getPredictions(
      {required String? broadcasterId,
      required int? count,
      required String? after,
      String? predictionId}) {
    return dio
        .get('/predictions', queryParameters: {
          if (count != null) 'first': count,
          if (after != null) 'after': after,
          if (predictionId != null) 'id': predictionId,
          'broadcaster_id': broadcasterId
        })
        .then((value) => value.data)
        .then(_parseResponse);
  }

  List<Prediction> _parseResponse(dynamic json) =>
      (json['data'] as List<dynamic>).map(Prediction.fromJson).toList();
}
