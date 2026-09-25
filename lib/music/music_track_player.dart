import 'music_models.dart';

abstract interface class MusicTrackPlayer {
  /// Completes only when the track ends, fails, or is stopped.
  Future<void> play(DownloadedMusicTrack track,
      {required double volume,
      required void Function(Duration position) onPosition});
  Future<void> setPaused(bool paused);
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> stop();
}
