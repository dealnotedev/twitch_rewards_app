import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/audio/audioplayer.dart';
import 'package:twitch_listener/core/observable_value.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/rewards/reward_executor.dart';

import '../music/fakes.dart';

void main() {
  late _RecordingAudioplayer player;
  late RewardExecutor executor;

  setUp(() {
    player = _RecordingAudioplayer();
    final music = MusicRequestManager(
      fetcher: FakeFetcher(),
      player: FakePlayer(),
    );
    addTearDown(music.close);
    executor = RewardExecutor(
      audioplayer: player,
      obs: _UnusedObs(),
      musicRequests: music,
    );
  });

  test('each cycle plays every sound once even with repeated input', () async {
    final paths = List.generate(12, (index) => 'sound-$index.wav');
    final reward = _audioReward(paths);

    for (var cycle = 0; cycle < 4; cycle++) {
      final start = player.paths.length;
      for (var i = 0; i < paths.length; i++) {
        await executor.execute(
          reward,
          userInput: cycle.isEven ? 'hello' : null,
        );
      }

      expect(player.paths.skip(start), unorderedEquals(paths));
      if (start > 0) {
        expect(player.paths[start], isNot(player.paths[start - 1]));
      }
    }
  });

  test('multiple sounds finish one cycle before starting the next', () async {
    final paths = List.generate(5, (index) => 'sound-$index.wav');
    final reward = _audioReward(paths, count: 2);

    for (var start = 0; start < paths.length * 2; start += 2) {
      await executor.execute(reward);
      expect(player.paths.skip(start).toSet(), hasLength(2));
    }

    expect(player.paths.take(paths.length), unorderedEquals(paths));
    expect(player.paths.skip(paths.length), unorderedEquals(paths));
    expect(player.paths[5], isNot(player.paths[4]));
  });

  test('one, several and all sounds use the same cycle', () async {
    final paths = ['a.wav', 'b.wav', 'c.wav', 'd.wav'];
    final reward = _audioReward(paths);
    final action = reward.handlers.single;
    var total = 0;
    for (final count in [1, null, 2, 1]) {
      final start = total;
      final length = count ?? paths.length;
      action.count = count;
      await executor.execute(reward);
      total += length;
      expect(player.paths, hasLength(total));
      expect(player.paths.skip(start).toSet(), hasLength(length));
    }

    expect(player.paths.take(paths.length), unorderedEquals(paths));
    expect(player.paths.skip(paths.length), unorderedEquals(paths));
  });

  test(
    'an oversized count is capped at the number of distinct sounds',
    () async {
      final paths = ['a.wav', 'b.wav'];
      final reward = _audioReward([...paths, 'a.wav'], count: 5);

      await executor.execute(reward);
      expect(player.paths, unorderedEquals(paths));
      await executor.execute(reward);
      expect(player.paths.skip(2), unorderedEquals(paths));
      expect(player.paths[2], isNot(player.paths[1]));
    },
  );

  test('reactions with identical files have independent cycles', () async {
    final paths = ['first.wav', 'second.wav'];
    final first = _audioReward(paths);
    final second = _audioReward(paths);

    await Future.wait([
      executor.execute(first),
      executor.execute(second),
      executor.execute(first),
      executor.execute(second),
    ]);

    expect([player.paths[0], player.paths[2]], unorderedEquals(paths));
    expect([player.paths[1], player.paths[3]], unorderedEquals(paths));
  });

  test('changing the files replaces the active cycle', () async {
    final reward = _audioReward(['a.wav', 'b.wav', 'c.wav']);
    await executor.execute(reward);
    final previous = player.paths.single;

    final newPaths = [previous, 'd.wav', 'e.wav'];
    reward.handlers.single.audios = [
      for (final path in newPaths) AudioEntry(path: path),
    ];
    for (final _ in newPaths) {
      await executor.execute(reward);
    }

    expect(player.paths[1], isNot(previous));
    expect(player.paths.skip(1), unorderedEquals(newPaths));
  });

  test('duplicate paths represent one sound in a cycle', () async {
    final reward = _audioReward(['a.wav', 'a.wav', 'b.wav']);
    for (var i = 0; i < 4; i++) {
      await executor.execute(reward);
    }

    final first = player.paths[0];
    final second = player.paths[1];
    expect([first, second], unorderedEquals(['a.wav', 'b.wav']));
    expect(player.paths, [first, second, first, second]);

    reward.handlers.single.audios.removeWhere((audio) => audio.path == 'b.wav');
    await executor.execute(reward);
    await executor.execute(reward);
    expect(player.paths.skip(4), ['a.wav', 'a.wav']);
  });
}

Reward _audioReward(List<String> paths, {int count = 1}) => Reward(
  name: 'Sounds',
  handlers: [
    RewardAction(
      type: RewardAction.typePlayAudios,
      audios: [for (final path in paths) AudioEntry(path: path)],
      randomize: true,
      count: count,
      awaitCompletion: true,
    ),
  ],
);

class _RecordingAudioplayer extends Audioplayer {
  final paths = <String>[];

  @override
  Future<void> playFileWaitCompletion(
    String filePath, {
    required ObservableValue<double> volume,
    String title = 'Twitch Listener',
  }) async {
    paths.add(filePath);
  }
}

class _UnusedObs implements ObsConnect {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
