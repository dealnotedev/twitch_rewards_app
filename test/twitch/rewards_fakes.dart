import 'dart:async';

import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/twitch/dto.dart';
import 'package:twitch_listener/twitch/reward_settings.dart';
import 'package:twitch_listener/twitch/twitch_api.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';

TwitchCreds credentials([String channel = 'channel']) => TwitchCreds(
  accessToken: 'test-access',
  refreshToken: 'test-refresh',
  clientId: 'test-client',
  broadcasterId: channel,
);

class RewardTestSettings extends Settings {
  final authChanges = StreamController<TwitchCreds?>.broadcast();
  RewardTestSettings({List<Reward>? localRewards}) {
    twitchAuth = credentials();
    rewards = Rewards(rewards: localRewards ?? []);
  }
  @override
  Stream<TwitchCreds?> get twitchAuthChanges => authChanges.stream;
  @override
  Future<void> saveTwitchAuth(TwitchCreds? creds) async {
    twitchAuth = creds;
    authChanges.add(creds);
  }
}

RedemptionDto remoteReward(
  String id,
  String title, {
  int cost = 300,
  bool skipRequestQueue = false,
}) => RedemptionDto(
  id: id,
  title: title,
  cost: cost,
  skipRequestQueue: skipRequestQueue,
  enabled: true,
  prompt: 'Viewer prompt',
  userInputRequired: false,
  paused: false,
  isInStock: true,
  image: null,
  defaultImage: ImageDto(
    url1x: 'https://example.com/icon.png',
    url2x: 'https://example.com/icon.png',
    url4x: 'https://example.com/icon.png',
  ),
);

class RewardTestApi implements TwitchApi {
  @override
  void close() {}
  List<RedemptionDto> entries = [
    remoteReward('own', 'Music'),
    remoteReward('other', 'Water'),
  ];
  Set<String> owned = {'own'};
  Set<String> scopes = {
    'channel:read:redemptions',
    'channel:manage:redemptions',
  };
  Future<List<RedemptionDto>> Function(bool)? load;
  Future<RedemptionDto> Function(String?, TwitchRewardSettings)? save;
  int writes = 0;

  @override
  Future<List<RedemptionDto>> getCustomRewards({
    bool onlyManageable = false,
  }) async => load != null
      ? load!(onlyManageable)
      : entries.where((r) => !onlyManageable || owned.contains(r.id)).toList();
  @override
  Future<Set<String>> getGrantedScopes() async => scopes;
  @override
  Future<RedemptionDto> createCustomReward(TwitchRewardSettings value) async {
    writes++;
    return save != null
        ? save!(null, value)
        : remoteReward('created', value.title, cost: value.cost);
  }

  @override
  Future<RedemptionDto> updateCustomReward(
    String id,
    TwitchRewardSettings value,
  ) async {
    writes++;
    return save != null
        ? save!(id, value)
        : remoteReward(id, value.title, cost: value.cost);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
