enum MusicQueueItemPhase { resolving, downloading, ready }

enum MusicQueueErrorType {
  missingYoutubeUrl,
  invalidYoutubeUrl,
  queueFull,
  trackTooLongOrLive,
  operationFailed,
}

class MusicQueueError {
  final String requester;
  final MusicQueueErrorType type;
  final String? details;

  const MusicQueueError({
    required this.requester,
    required this.type,
    this.details,
  });

  String get signature => '$requester|$type|${details ?? ''}';
}

class MusicTrackMetadata {
  final String videoId;
  final String title;
  final String author;
  final Duration duration;
  final Uri? thumbnail;
  final Uri sourceUrl;

  const MusicTrackMetadata({
    required this.videoId,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnail,
    required this.sourceUrl,
  });
}

class DownloadedMusicTrack {
  final String itemId;
  final String requestedBy;
  final MusicTrackMetadata metadata;
  final String filePath;

  const DownloadedMusicTrack({
    required this.itemId,
    required this.requestedBy,
    required this.metadata,
    required this.filePath,
  });
}

class MusicQueueItem {
  final String id;
  final String requestedBy;
  final Uri sourceUrl;
  final MusicQueueItemPhase phase;
  final String? title;
  final String? author;
  final Duration? duration;
  final Uri? thumbnail;
  final double? downloadProgress;

  const MusicQueueItem({
    required this.id,
    required this.requestedBy,
    required this.sourceUrl,
    required this.phase,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnail,
    required this.downloadProgress,
  });
}

class MusicNowPlaying {
  final MusicQueueItem item;
  final DateTime startedAt;
  final Duration position;
  final DateTime positionUpdatedAt;
  final bool paused;

  const MusicNowPlaying({
    required this.item,
    required this.startedAt,
    required this.position,
    required this.positionUpdatedAt,
    required this.paused,
  });
}

class MusicQueueSnapshot {
  final int revision;
  final MusicNowPlaying? nowPlaying;
  final List<MusicQueueItem> queue;
  final MusicQueueError? lastError;
  final double volume;

  const MusicQueueSnapshot({
    required this.revision,
    required this.nowPlaying,
    required this.queue,
    required this.lastError,
    this.volume = 1,
  });

  static const empty = MusicQueueSnapshot(
    revision: 0,
    nowPlaying: null,
    queue: [],
    lastError: null,
  );
}

class MusicDownloadProgress {
  final int downloadedBytes;
  final int? totalBytes;
  final Duration? eta;

  const MusicDownloadProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.eta,
  });

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (downloadedBytes / total).clamp(0.0, 1.0).toDouble();
  }
}

abstract interface class MusicTrackFetcher {
  Future<MusicTrackMetadata> inspect(Uri sourceUrl);

  /// Returns a fetcher-owned local file. Callers must not delete it.
  Future<String> obtain({
    required MusicTrackMetadata metadata,
    required void Function(MusicDownloadProgress progress) onProgress,
  });

  Future<void> cancel();
}
