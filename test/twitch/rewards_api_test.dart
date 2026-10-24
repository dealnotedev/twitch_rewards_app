import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/twitch/reward_settings.dart';
import 'package:twitch_listener/twitch/twitch_api.dart';

import 'rewards_fakes.dart';

void main() {
  test('Helix discovery and writes use channel IDs and the documented reward fields', () async {
    final settings = RewardTestSettings();
    addTearDown(settings.authChanges.close);
    final adapter = _RewardAdapter();
    final api = TwitchApi(
      settings: settings,
      clientSecret: 'test-secret',
      broadcasterId: 'channel',
    );
    api.dio.httpClientAdapter = adapter;
    addTearDown(() => api.dio.close(force: true));
    await api.getCustomRewards(onlyManageable: true);
    expect(adapter.last.queryParameters, {
      'broadcaster_id': 'channel',
      'only_manageable_rewards': true,
    });
    expect(
      await api.getGrantedScopes(),
      contains('channel:manage:redemptions'),
    );
    expect(adapter.last.uri.host, 'id.twitch.tv');
    const value = TwitchRewardSettings(
      title: 'New reward',
      cost: 500,
      inputRequired: true,
      cooldownSeconds: 60,
      maxPerStream: 5,
      maxPerUserPerStream: 1,
    );
    final created = await api.createCustomReward(value);
    expect(adapter.last.method, 'POST');
    expect(adapter.last.uri.path, '/helix/channel_points/custom_rewards');
    expect(adapter.last.queryParameters, {'broadcaster_id': 'channel'});
    expect(adapter.last.data['is_user_input_required'], isTrue);
    expect(adapter.last.data.containsKey('is_paused'), isFalse);
    expect(created.cooldownSeconds, 60);
    expect(created.maxPerStream, 5);
    expect(created.maxPerUserPerStream, 1);
    await api.updateCustomReward(
      'reward',
      const TwitchRewardSettings(title: 'Renamed', cost: 250, paused: true),
    );
    expect(adapter.last.method, 'PATCH');
    expect(adapter.last.queryParameters, {
      'broadcaster_id': 'channel',
      'id': 'reward',
    });
    expect(adapter.last.data['is_paused'], isTrue);
    expect(adapter.last.data['is_global_cooldown_enabled'], isFalse);
    expect(adapter.last.data['is_max_per_stream_enabled'], isFalse);
    expect(adapter.last.data['is_max_per_user_per_stream_enabled'], isFalse);
  });
}

class _RewardAdapter implements HttpClientAdapter {
  late RequestOptions last;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    final data = options.uri.host == 'id.twitch.tv'
        ? {
            'scopes': ['channel:manage:redemptions'],
          }
        : {
            'data': [
              {
                'id': 'reward',
                'title': 'New reward',
                'cost': 500,
                'prompt': 'Prompt',
                'is_enabled': true,
                'is_user_input_required': true,
                'is_paused': false,
                'is_in_stock': true,
                'background_color': '#123456',
                'max_per_stream_setting': {
                  'is_enabled': true,
                  'max_per_stream': 5,
                },
                'max_per_user_per_stream_setting': {
                  'is_enabled': true,
                  'max_per_user_per_stream': 1,
                },
                'global_cooldown_setting': {
                  'is_enabled': true,
                  'global_cooldown_seconds': 60,
                },
                'default_image': {
                  'url_1x': 'image',
                  'url_2x': 'image',
                  'url_4x': 'image',
                },
              },
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
