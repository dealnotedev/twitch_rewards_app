import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:twitch_listener/music/media_kit_music_track_player.dart';
import 'package:twitch_listener/music/music_models.dart';

import 'fakes.dart';

void main() {
  late _NativePlayer native;
  late MediaKitMusicTrackPlayer player;
  final track = DownloadedMusicTrack(
      itemId: '1',
      requestedBy: 'Viewer',
      metadata: metadata(Uri.parse(firstUrl)),
      filePath: 'sample.webm');

  setUp(() {
    native = _NativePlayer();
    player = MediaKitMusicTrackPlayer(createPlayer: () => native);
  });
  tearDown(() async {
    await player.stop();
    await native.events.close();
  });

  test('configures native playback and waits for completion before disposal',
      () async {
    final positions = <Duration>[];
    final playing = player.play(track, volume: .4, onPosition: positions.add);
    await flush();
    expect(native.volume, 40);
    expect(native.opened, isNotNull);
    expect(native.mode, PlaylistMode.none);
    native.events.positions.add(const Duration(seconds: 12));
    await flush();
    expect(positions, [const Duration(seconds: 12)]);
    await player.setPaused(true);
    expect(native.paused, isTrue);
    await player.setPaused(false);
    expect(native.paused, isFalse);
    await player.seek(const Duration(seconds: 25));
    expect(native.sought, const Duration(seconds: 25));
    await player.setVolume(.65);
    expect(native.volume, 65);
    native.events.completions.add(true);
    await playing;
    expect(native.disposals, 1);
    expect(native.events.completions.hasListener, isFalse);
  });

  test('stop during opening waits for native disposal and completes playback',
      () async {
    native.openGate = Completer();
    final playing = player.play(track, volume: .3, onPosition: (_) {});
    await flush();
    var stopped = false;
    final stopping = player.stop().then((_) => stopped = true);
    await flush();
    expect(stopped, isFalse);
    native.openGate!.complete();
    await stopping;
    await playing;
    expect(native.disposals, 1);
  });

  test('stop immediately prevents opening audio', () async {
    final playing = player.play(track, volume: .3, onPosition: (_) {});
    await player.stop();
    await playing;
    expect(native.opened, isNull);
    expect(native.disposals, 1);
  });

  test('native error while opening fails playback and releases the player',
      () async {
    native.openGate = Completer();
    final playing = player.play(track, volume: .3, onPosition: (_) {});
    final expectation = expectLater(playing, throwsStateError);
    await flush();
    native.events.errors.add('Cannot decode track');
    await flush();
    native.openGate!.complete();
    await expectation;
    expect(native.disposals, 1);
  });

  test('failed native open releases the player', () async {
    native.openError = StateError('Unable to open');
    await expectLater(
        player.play(track, volume: .3, onPosition: (_) {}), throwsStateError);
    expect(native.disposals, 1);
  });
}

class _NativePlayer implements Player {
  final events = _Events();
  Completer<void>? openGate;
  Object? openError;
  Playable? opened;
  double? volume;
  PlaylistMode? mode;
  bool paused = false;
  Duration? sought;
  int disposals = 0;

  @override
  PlayerStream get stream => events;
  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
  }

  @override
  Future<void> setPlaylistMode(PlaylistMode mode) async {
    this.mode = mode;
  }

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opened = playable;
    if (openError != null) throw openError!;
    await openGate?.future;
  }

  @override
  Future<void> pause() async {
    paused = true;
  }

  @override
  Future<void> play() async {
    paused = false;
  }

  @override
  Future<void> seek(Duration duration) async {
    sought = duration;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Events implements PlayerStream {
  final completions = StreamController<bool>.broadcast();
  final errors = StreamController<String>.broadcast();
  final positions = StreamController<Duration>.broadcast();
  @override
  Stream<bool> get completed => completions.stream;
  @override
  Stream<String> get error => errors.stream;
  @override
  Stream<Duration> get position => positions.stream;
  Future<void> close() async {
    await completions.close();
    await errors.close();
    await positions.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
