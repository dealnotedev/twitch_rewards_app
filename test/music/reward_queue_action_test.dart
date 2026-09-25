import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_executor.dart';

import 'fakes.dart';

void main() {
  test('queue action persists and returns before resolving or playing',
      () async {
    final fetcher = FakeFetcher()..inspectGate = Completer();
    final player = FakePlayer();
    final manager = MusicRequestManager(fetcher: fetcher, player: player);
    addTearDown(manager.close);
    final obs = _Obs();
    final executor = RewardExecutor(
        audioplayer: Audioplayer(), obs: obs, musicRequests: manager);
    final reward =
        Reward.fromJson(jsonDecode(jsonEncode(Reward(name: 'Song', handlers: [
      RewardAction.create(RewardAction.typeQueueTrack),
      RewardAction(
          type: RewardAction.typeEnableInput, inputName: 'Mic', enable: true),
    ]).toJson())));

    await executor.execute(reward, userInput: firstUrl, requester: 'Alice');
    expect(reward.handlers.first.type, RewardAction.typeQueueTrack);
    expect(manager.current.queue.single.requestedBy, 'Alice');
    expect(player.played, isEmpty);
    expect(obs.enabled, isTrue, reason: 'The next action must run immediately');
  });

  test('disabled queue actions do not submit requests', () async {
    final manager =
        MusicRequestManager(fetcher: FakeFetcher(), player: FakePlayer());
    addTearDown(manager.close);
    final executor = RewardExecutor(
        audioplayer: Audioplayer(), obs: _Obs(), musicRequests: manager);
    await executor.execute(
        Reward(name: 'Song', handlers: [
          RewardAction(type: RewardAction.typeQueueTrack, disabled: true),
        ]),
        userInput: firstUrl);
    expect(manager.current.queue, isEmpty);
    expect(manager.current.nowPlaying, isNull);
  });
}

class _Obs implements ObsConnect {
  bool enabled = false;
  @override
  Future<void> enableInput(
      {required String inputName, required bool enabled}) async {
    this.enabled = enabled;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
