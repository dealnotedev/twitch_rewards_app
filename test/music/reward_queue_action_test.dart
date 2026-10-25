import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/audio/audioplayer.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/rewards/reward_executor.dart';
import 'package:twitch_listener/rewards/reward_execution.dart';

import 'fakes.dart';

void main() {
  test(
    'tracked music waits for playback while the next reaction runs immediately',
    () async {
      final player = FakePlayer();
      final manager = MusicRequestManager(
        fetcher: FakeFetcher(),
        player: player,
      );
      addTearDown(manager.close);
      final obs = _Obs();
      final executor = RewardExecutor(
        audioplayer: Audioplayer(),
        obs: obs,
        musicRequests: manager,
      );
      final execution = RewardExecution();
      await executor.execute(
        Reward(
          name: 'Song',
          handlers: [
            RewardAction.create(RewardAction.typeQueueTrack),
            RewardAction(
              type: RewardAction.typeEnableInput,
              inputName: 'Mic',
              enable: true,
            ),
          ],
        ),
        userInput: firstUrl,
        execution: execution,
      );
      var complete = false;
      final done = execution.finish().then((_) => complete = true);
      await flush();
      expect(obs.enabled, isTrue);
      expect(complete, isFalse);
      expect(player.played, hasLength(1));
      player.finish();
      await done;
      expect(complete, isTrue);
    },
  );

  test(
    'tracked music reports a late player failure and cancellation',
    () async {
      final player = FakePlayer();
      final manager = MusicRequestManager(
        fetcher: FakeFetcher(),
        player: player,
      );
      addTearDown(manager.close);
      final executor = RewardExecutor(
        audioplayer: Audioplayer(),
        obs: _Obs(),
        musicRequests: manager,
      );
      final execution = RewardExecution();
      await executor.execute(
        Reward(
          name: 'Song',
          handlers: [RewardAction.create(RewardAction.typeQueueTrack)],
        ),
        userInput: firstUrl,
        execution: execution,
      );
      final failed = expectLater(execution.finish(), throwsStateError);
      await flush();
      player.finish(StateError('Playback failed'));
      await failed;
      final canceled = RewardExecution();
      await executor.execute(
        Reward(
          name: 'Song',
          handlers: [RewardAction.create(RewardAction.typeQueueTrack)],
        ),
        userInput: secondUrl,
        execution: canceled,
      );
      await flush();
      await manager.skip();
      await expectLater(canceled.finish(), throwsStateError);
    },
  );

  test(
    'invalid music admission and incomplete actions fail tracked execution',
    () async {
      final manager = MusicRequestManager(
        fetcher: FakeFetcher(),
        player: FakePlayer(),
      );
      addTearDown(manager.close);
      final executor = RewardExecutor(
        audioplayer: Audioplayer(),
        obs: _Obs(),
        musicRequests: manager,
      );
      await expectLater(
        executor.execute(
          Reward(
            name: 'Song',
            handlers: [RewardAction.create(RewardAction.typeQueueTrack)],
          ),
          userInput: 'invalid',
          execution: RewardExecution(),
        ),
        throwsStateError,
      );
      await expectLater(
        executor.execute(
          Reward(
            name: 'OBS',
            handlers: [RewardAction(type: RewardAction.typeSetScene)],
          ),
          execution: RewardExecution(),
        ),
        throwsStateError,
      );
    },
  );
  test(
    'queue action persists and returns before resolving or playing',
    () async {
      final fetcher = FakeFetcher()..inspectGate = Completer();
      final player = FakePlayer();
      final manager = MusicRequestManager(fetcher: fetcher, player: player);
      addTearDown(manager.close);
      final obs = _Obs();
      final executor = RewardExecutor(
        audioplayer: Audioplayer(),
        obs: obs,
        musicRequests: manager,
      );
      final reward = Reward.fromJson(
        jsonDecode(
          jsonEncode(
            Reward(
              name: 'Song',
              handlers: [
                RewardAction.create(RewardAction.typeQueueTrack),
                RewardAction(
                  type: RewardAction.typeEnableInput,
                  inputName: 'Mic',
                  enable: true,
                ),
              ],
            ).toJson(),
          ),
        ),
      );

      await executor.execute(reward, userInput: firstUrl, requester: 'Alice');
      expect(reward.handlers.first.type, RewardAction.typeQueueTrack);
      expect(manager.current.queue.single.requestedBy, 'Alice');
      expect(player.played, isEmpty);
      expect(
        obs.enabled,
        isTrue,
        reason: 'The next action must run immediately',
      );
    },
  );

  test('disabled queue actions do not submit requests', () async {
    final manager = MusicRequestManager(
      fetcher: FakeFetcher(),
      player: FakePlayer(),
    );
    addTearDown(manager.close);
    final executor = RewardExecutor(
      audioplayer: Audioplayer(),
      obs: _Obs(),
      musicRequests: manager,
    );
    await executor.execute(
      Reward(
        name: 'Song',
        handlers: [
          RewardAction(type: RewardAction.typeQueueTrack, disabled: true),
        ],
      ),
      userInput: firstUrl,
    );
    expect(manager.current.queue, isEmpty);
    expect(manager.current.nowPlaying, isNull);
  });
}

class _Obs implements ObsConnect {
  bool enabled = false;
  @override
  Future<void> enableInput({
    required String inputName,
    required bool enabled,
  }) async {
    this.enabled = enabled;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
