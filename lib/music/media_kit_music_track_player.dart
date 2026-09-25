import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'music_models.dart';
import 'music_track_player.dart';

/// Owns a separate audio player; reward sound effects keep their own volumes.
class MediaKitMusicTrackPlayer implements MusicTrackPlayer {
  final Player Function() _createPlayer;
  _Playback? _session;
  double _volume = 1;

  MediaKitMusicTrackPlayer({Player Function()? createPlayer})
      : _createPlayer = createPlayer ??
            (() => Player(
                configuration:
                    const PlayerConfiguration(title: 'Music requests')));

  @override
  Future<void> play(DownloadedMusicTrack track,
      {required double volume,
      required void Function(Duration position) onPosition}) async {
    if (_session != null) throw StateError('Music playback is already active');
    _volume = volume;
    final session = _Playback(_createPlayer());
    _session = session;
    final player = session.player;
    final subscriptions = <StreamSubscription<dynamic>>[
      player.stream.completed.listen((completed) {
        if (completed) session.finish();
      }),
      player.stream.error.listen((error) {
        if (error.isNotEmpty) session.finish(StateError(error));
      }),
      player.stream.position.listen(onPosition),
    ];
    // Listen for errors immediately, including ones raised while opening.
    final finished = session.done.future;
    unawaited(finished.catchError((Object _) {}));
    try {
      session.opening = () async {
        await player.setPlaylistMode(PlaylistMode.none);
        await player.setVolume(_volume * 100);
        if (!session.stopped) await player.open(Media(track.filePath));
      }();
      await session.opening;
      await finished;
    } finally {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      try {
        await player.dispose();
      } finally {
        if (identical(_session, session)) _session = null;
        session.disposed.complete();
      }
    }
  }

  Future<void> _control(Future<void> Function(Player player) command) async {
    final session = _session;
    if (session == null) return;
    await session.opening;
    if (!identical(_session, session) || session.done.isCompleted) return;
    await command(session.player);
  }

  @override
  Future<void> setPaused(bool paused) =>
      _control((player) => paused ? player.pause() : player.play());

  @override
  Future<void> seek(Duration position) =>
      _control((player) => player.seek(position));

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0, 1).toDouble();
    await _control((player) => player.setVolume(_volume * 100));
  }

  @override
  Future<void> stop() async {
    final session = _session;
    if (session == null) return;
    session.stopped = true;
    session.finish();
    // play() disposes its native handle before the queue may start a new one.
    await session.disposed.future;
  }
}

class _Playback {
  final Player player;
  final done = Completer<void>();
  final disposed = Completer<void>();
  Future<void> opening = Future.value();
  bool stopped = false;

  _Playback(this.player);

  void finish([Object? error]) {
    if (done.isCompleted) return;
    if (error == null) {
      done.complete();
    } else {
      done.completeError(error);
    }
  }
}
