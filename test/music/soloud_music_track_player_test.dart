import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/audio/soloud_audio.dart';
import 'package:twitch_listener/music/music_models.dart';
import 'package:twitch_listener/music/soloud_music_track_player.dart';

import 'fakes.dart';

void main() {
  late _Audio audio;
  late SoloudMusicTrackPlayer player;
  final track = DownloadedMusicTrack(
    itemId: '1',
    requestedBy: 'Viewer',
    metadata: metadata(Uri.parse(firstUrl)),
    filePath: 'sample.mp3',
  );

  setUp(() {
    audio = _Audio();
    player = SoloudMusicTrackPlayer(audio: audio);
  });
  tearDown(() => player.stop());

  test(
    'playback controls apply to the current voice until it finishes',
    () async {
      final positions = <Duration>[];
      final playing = player.play(track, volume: .4, onPosition: positions.add);
      audio.opening.complete(audio.voice);
      await flush();
      expect(audio.path, track.filePath);
      expect(audio.initialVolume, .4);
      expect(audio.voice.paused, isFalse);
      await player.setPaused(true);
      expect(audio.voice.paused, isTrue);
      const target = Duration(seconds: 25);
      await player.seek(target);
      expect(audio.voice.position, target);
      await player.setVolume(.65);
      expect(audio.voice.volume, .65);
      await player.setPaused(false);
      expect(audio.voice.paused, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 180));
      expect(positions, [target]);
      audio.voice.ended.complete();
      await playing;
      expect(audio.voice.closed, isTrue);
    },
  );

  test('stopping during loading closes the voice before it can play', () async {
    final playing = player.play(track, volume: .3, onPosition: (_) {});
    var stopped = false;
    final stopping = player.stop().then((_) => stopped = true);
    await flush();
    expect(stopped, isFalse);
    audio.opening.complete(audio.voice);
    await stopping;
    await playing;
    expect(audio.voice.paused, isTrue);
    expect(audio.voice.closed, isTrue);
  });

  test('failed load releases the playback slot for retry', () async {
    final playing = player.play(track, volume: .3, onPosition: (_) {});
    final failure = expectLater(playing, throwsStateError);
    audio.opening.completeError(StateError('Unable to decode track'));
    await failure;

    audio.opening = Completer<SoloudPlayback>()..complete(audio.voice);
    final retry = player.play(track, volume: .3, onPosition: (_) {});
    await player.stop();
    await retry;
    expect(audio.voice.closed, isTrue);
  });
}

class _Audio implements SoloudAudio {
  final voice = _Voice();
  var opening = Completer<SoloudPlayback>();
  String? path;
  double? initialVolume;

  @override
  Future<SoloudPlayback> playFile(
    String filePath, {
    required double volume,
    bool looping = false,
  }) {
    path = filePath;
    initialVolume = volume;
    return opening.future;
  }
}

class _Voice implements SoloudPlayback {
  final ended = Completer<void>();
  bool paused = true;
  bool closed = false;
  double? volume;
  @override
  Duration position = Duration.zero;

  @override
  Duration get length => const Duration(minutes: 1);

  @override
  Future<void> get completed => ended.future;

  @override
  bool get isActive => !closed && !ended.isCompleted;

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  void seek(Duration position) => this.position = position;

  @override
  void setPaused(bool paused) => this.paused = paused;

  @override
  void setVolume(double volume) => this.volume = volume;
}
