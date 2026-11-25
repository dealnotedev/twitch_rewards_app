import 'dart:async';

import '../audio/soloud_audio.dart';
import 'music_models.dart';
import 'music_track_player.dart';

class SoloudMusicTrackPlayer implements MusicTrackPlayer {
  SoloudMusicTrackPlayer({SoloudAudio? audio})
    : _audio = audio ?? SoloudAudio.shared;

  final SoloudAudio _audio;
  _TrackPlayback? _current;

  @override
  Future<void> play(
    DownloadedMusicTrack track, {
    required double volume,
    required void Function(Duration position) onPosition,
  }) async {
    if (_current != null) throw StateError('Music playback is already active');
    final session = _TrackPlayback(
      _audio.playFile(track.filePath, volume: volume),
    );
    _current = session;
    SoloudPlayback? playback;
    Timer? progress;
    try {
      playback = await session.opening;
      if (session.stopRequested.isCompleted) return;
      playback.setPaused(false);
      final voice = playback;
      var lastPosition = Duration.zero;
      progress = Timer.periodic(const Duration(milliseconds: 150), (_) {
        if (!voice.isActive) return;
        final position = voice.position;
        if (lastPosition == position) return;
        lastPosition = position;
        onPosition(position);
      });
      await Future.any([playback.completed, session.stopRequested.future]);
    } finally {
      progress?.cancel();
      try {
        await playback?.close();
      } finally {
        _current = null;
        session.closed.complete();
      }
    }
  }

  Future<void> _control(void Function(SoloudPlayback) command) async {
    final session = _current;
    if (session == null) return;
    final playback = await session.opening;
    if (identical(_current, session) && !session.stopRequested.isCompleted) {
      command(playback);
    }
  }

  @override
  Future<void> setPaused(bool paused) =>
      _control((playback) => playback.setPaused(paused));

  @override
  Future<void> seek(Duration position) =>
      _control((playback) => playback.seek(position));

  @override
  Future<void> setVolume(double volume) =>
      _control((playback) => playback.setVolume(volume));

  @override
  Future<void> stop() async {
    final session = _current;
    if (session == null) return;
    if (!session.stopRequested.isCompleted) session.stopRequested.complete();
    await session.closed.future;
  }
}

class _TrackPlayback {
  _TrackPlayback(this.opening);

  final Future<SoloudPlayback> opening;
  final stopRequested = Completer<void>();
  final closed = Completer<void>();
}
