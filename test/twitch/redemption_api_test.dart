import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/twitch/redemption.dart';
import 'package:twitch_listener/twitch/twitch_api.dart';

import 'redemption_fakes.dart';
import 'rewards_fakes.dart';

void main() {
  test(
    'redemption decisions, live updates, and avatars use Helix contracts',
    () async {
      final settings = RewardTestSettings();
      addTearDown(settings.authChanges.close);
      final adapter = _Adapter();
      final api = TwitchApi(
        settings: settings,
        clientSecret: 'test',
        broadcasterId: 'channel',
      );
      api.dio.httpClientAdapter = adapter;
      addTearDown(api.close);
      await api.setRedemptionStatus(
        rewardId: 'own',
        redemptionId: 'one',
        status: RedemptionStatus.canceled,
      );
      expect(adapter.last.method, 'PATCH');
      expect(adapter.last.data, {'status': 'CANCELED'});
      expect(adapter.last.queryParameters, {
        'broadcaster_id': 'channel',
        'reward_id': 'own',
        'id': 'one',
      });
      expect(
        adapter.last.uri.path,
        '/helix/channel_points/custom_rewards/redemptions',
      );
      expect(
        (await api.getViewer('viewer'))!.profileImageUrl,
        'https://example.com/avatar.png',
      );
      expect(adapter.last.queryParameters, {'id': 'viewer'});
      await api.subscribeCustomRewards(
        broadcasterUserId: 'channel',
        sessionId: 'session',
        updates: true,
      );
      expect(
        adapter.last.data['type'],
        'channel.channel_points_custom_reward_redemption.update',
      );
      expect(RedemptionStatus.parse('cancelled'), RedemptionStatus.canceled);
    },
  );

  test(
    'an API pinned to the previous account never sends a new account token',
    () async {
      final settings = RewardTestSettings();
      addTearDown(settings.authChanges.close);
      final adapter = _Adapter();
      final api = TwitchApi(
        settings: settings,
        clientSecret: 'test',
        broadcasterId: 'channel',
        expectedCredentials: settings.twitchAuth,
      );
      api.dio.httpClientAdapter = adapter;
      addTearDown(api.close);
      await settings.saveTwitchAuth(credentials('another-channel'));
      await expectLater(api.getViewer('viewer'), throwsA(anything));
      expect(adapter.calls, 0);
    },
  );
}

class _Adapter implements HttpClientAdapter {
  late RequestOptions last;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    calls++;
    final data = options.path == '/users'
        ? {
            'data': [
              {
                'id': 'viewer',
                'login': 'viewer',
                'profile_image_url': 'https://example.com/avatar.png',
              },
            ],
          }
        : {
            'data': [
              redemption(
                'one',
                status: options.method == 'PATCH'
                    ? RedemptionStatus.canceled
                    : RedemptionStatus.unfulfilled,
              ).toJson(),
            ],
          };
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
