import 'package:dart_music_player_protocol/dart_music_player_protocol.dart';
export 'package:dart_music_player_protocol/dart_music_player_protocol.dart';

class MusicPreparationProgress {
  final MusicQueueItemPhase phase;
  final double? fraction;

  const MusicPreparationProgress({required this.phase, this.fraction});
}

abstract interface class MusicTrackFetcher {
  Future<MusicTrackMetadata> inspect(Uri sourceUrl);

  /// Returns a fetcher-owned local file. Callers must not delete it.
  Future<String> obtain({
    required MusicTrackMetadata metadata,
    required void Function(MusicPreparationProgress progress) onProgress,
  });

  Future<void> cancel();
}
