import 'dart:async';

import 'package:uuid/uuid.dart';

import 'music_models.dart';
import 'music_track_player.dart';

export 'music_models.dart';

/// Shared by all reward actions and independent of Twitch settlement and OBS.
class MusicRequestManager {
  final MusicTrackFetcher _fetcher;
  final MusicTrackPlayer _player;
  final Future<void> Function(double)? _saveVolume;
  final int maxQueueLength;
  final Duration maxDuration;
  final _states = StreamController<MusicQueueSnapshot>.broadcast();
  final _queue = <_Request>[];
  _Request? _active;
  _Request? _preparing;
  Future<void>? _preparation;
  Future<void>? _playback;
  Future<bool>? _skipping;
  Future<void> _volumeSave = Future.value();
  Future<void>? _closing;
  bool _closed = false;
  double _volume;
  MusicQueueError? _error;
  late MusicQueueSnapshot _current;

  MusicRequestManager({
    required MusicTrackFetcher fetcher,
    required MusicTrackPlayer player,
    double volume = 1,
    Future<void> Function(double)? saveVolume,
    this.maxQueueLength = 10,
    this.maxDuration = const Duration(minutes: 10),
  })  : _fetcher = fetcher,
        _player = player,
        _volume = volume.isFinite ? volume.clamp(0, 1).toDouble() : 1,
        _saveVolume = saveVolume {
    _current = MusicQueueSnapshot(
        revision: 0,
        nowPlaying: null,
        queue: const [],
        lastError: null,
        volume: _volume);
  }

  MusicQueueSnapshot get current => _current;
  Stream<MusicQueueSnapshot> get states => _states.stream;

  /// Only accepts the request. Preparation and playback run independently.
  bool enqueue(String? input, {String requester = ''}) {
    if (_closed) return false;
    final text = input?.trim() ?? '';
    final url = parseYoutubeUrl(text);
    if (url == null) {
      _setError(MusicQueueError(
          requester: requester,
          type: text.isEmpty
              ? MusicQueueErrorType.missingYoutubeUrl
              : MusicQueueErrorType.invalidYoutubeUrl));
      return false;
    }
    if (_queue.length + (_active == null ? 0 : 1) >= maxQueueLength) {
      _setError(MusicQueueError(
          requester: requester, type: MusicQueueErrorType.queueFull));
      return false;
    }
    _error = null;
    _queue.add(_Request(
        id: const Uuid().v4(), requestedBy: requester, sourceUrl: url));
    _emit();
    _ensurePreparing();
    return true;
  }

  static Uri? parseYoutubeUrl(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('//')) text = 'https:$text';
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      return null;
    }
    final host = uri.host.toLowerCase();
    String? id;
    if (host == 'youtu.be' && uri.pathSegments.length == 1) {
      id = uri.pathSegments.single;
    } else if (const [
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'music.youtube.com'
    ].contains(host)) {
      if (uri.path == '/watch') {
        id = uri.queryParameters['v'];
      } else if (uri.pathSegments.length == 2 &&
          const ['shorts', 'embed', 'live'].contains(uri.pathSegments.first)) {
        id = uri.pathSegments[1];
      }
    }
    if (id == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) return null;
    // Drop playlists, timestamps and unrelated parameters: one action, one track.
    return Uri.https('www.youtube.com', '/watch', {'v': id});
  }

  void _ensurePreparing() {
    if (_closed || _preparation != null) return;
    _preparation = _prepareLoop();
  }

  Future<void> _prepareLoop() async {
    // Keep assignment of _preparation ahead of even an empty loop's finally.
    await Future<void>.value();
    try {
      while (!_closed) {
        final request = _queue
            .where((r) => r.phase == MusicQueueItemPhase.resolving)
            .firstOrNull;
        if (request == null) break;
        _preparing = request;
        try {
          final metadata = await _fetcher.inspect(request.sourceUrl);
          if (_closed || !_queue.contains(request)) continue;
          if (metadata.duration <= Duration.zero ||
              metadata.duration > maxDuration) {
            _queue.remove(request);
            _setError(MusicQueueError(
                requester: request.requestedBy,
                type: MusicQueueErrorType.trackTooLongOrLive));
            continue;
          }
          request.metadata = metadata;
          request.phase = MusicQueueItemPhase.downloading;
          _emit();
          final file = await _fetcher.obtain(
              metadata: metadata,
              onProgress: (p) {
                if (_closed || !_queue.contains(request)) return;
                request.phase = p.phase;
                request.progress = p.fraction;
                _emit();
              });
          if (_closed || !_queue.contains(request)) continue;
          request.filePath = file;
          request.phase = MusicQueueItemPhase.ready;
          request.progress = 1;
          _emit();
        } catch (error) {
          if (_queue.remove(request) && !_closed) {
            _setError(_operationError(request, error));
          }
        } finally {
          _preparing = null;
          _startIfPossible();
        }
      }
    } finally {
      _preparation = null;
    }
  }

  void _startIfPossible() {
    if (_closed ||
        _active != null ||
        _queue.isEmpty ||
        _queue.first.phase != MusicQueueItemPhase.ready) {
      return;
    }
    final request = _queue.removeAt(0);
    _active = request;
    request.startedAt = DateTime.now();
    _emit();
    _playback = _play(request);
  }

  Future<void> _play(_Request request) async {
    try {
      await _player.play(
          DownloadedMusicTrack(
              itemId: request.id,
              requestedBy: request.requestedBy,
              metadata: request.metadata!,
              filePath: request.filePath!),
          volume: _volume, onPosition: (position) {
        if (_closed || _active != request) return;
        request.position = position;
        _emit();
      });
    } catch (error) {
      if (!_closed) _error = _operationError(request, error);
    } finally {
      if (_active == request) _active = null;
      _emit();
      _startIfPossible();
    }
  }

  Future<bool> setPaused(bool paused) async {
    final request = _active;
    if (_closed || request == null) return false;
    try {
      await _player.setPaused(paused);
      if (_closed || _active != request) return false;
      request.paused = paused;
      _emit();
      return true;
    } catch (error) {
      _setError(_operationError(request, error));
      return false;
    }
  }

  Future<bool> seek(Duration position) async {
    final request = _active;
    if (_closed || request == null) return false;
    final duration = request.metadata!.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : position > duration
            ? duration
            : position;
    try {
      await _player.seek(target);
      if (_closed || _active != request) return false;
      request.position = target;
      _emit();
      return true;
    } catch (error) {
      _setError(_operationError(request, error));
      return false;
    }
  }

  Future<bool> skip() => _skipping ??= _skip();

  Future<bool> _skip() async {
    await Future<void>.value();
    final request = _active;
    try {
      if (_closed || request == null) return false;
      await _player.stop();
      return true;
    } catch (error) {
      if (request != null) _setError(_operationError(request, error));
      return false;
    } finally {
      _skipping = null;
    }
  }

  Future<bool> remove(String id) async {
    if (_closed) return false;
    final index = _queue.indexWhere((r) => r.id == id);
    if (index < 0) return false;
    final request = _queue.removeAt(index);
    _emit();
    if (_preparing == request) await _fetcher.cancel();
    _startIfPossible();
    return true;
  }

  Future<void> setVolume(double volume, {bool persist = false}) async {
    if (_closed || !volume.isFinite) return;
    _volume = volume.clamp(0, 1).toDouble();
    _emit();
    try {
      await _player.setVolume(_volume);
    } catch (error) {
      _setError(_operationError(_active, error));
    }
    if (persist) await saveVolume();
  }

  Future<void> saveVolume() {
    final value = _volume;
    // Keep rapid slider releases ordered on disk, too.
    return _volumeSave = _volumeSave.then((_) async {
      try {
        await _saveVolume?.call(value);
      } catch (error) {
        _setError(_operationError(_active, error));
      }
    });
  }

  void dismissError() {
    _error = null;
    _emit();
  }

  void _setError(MusicQueueError error) {
    _error = error;
    _emit();
  }

  static MusicQueueError _operationError(_Request? request, Object error) {
    final text = error.toString();
    return MusicQueueError(
        requester: request?.requestedBy ?? '',
        type: MusicQueueErrorType.operationFailed,
        details: text.length <= 320 ? text : '${text.substring(0, 317)}...');
  }

  void _emit() {
    if (_closed) return;
    final active = _active;
    _current = MusicQueueSnapshot(
        revision: _current.revision + 1,
        nowPlaying: active == null
            ? null
            : MusicNowPlaying(
                item: active.view,
                startedAt: active.startedAt!,
                position: active.position,
                positionUpdatedAt: DateTime.now(),
                paused: active.paused),
        queue: List.unmodifiable(_queue.map((r) => r.view)),
        lastError: _error,
        volume: _volume);
    _states.add(_current);
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    await _fetcher.cancel();
    await _player.stop();
    await _preparation;
    await _playback;
    await _volumeSave;
    await _states.close();
  }
}

class _Request {
  final String id;
  final String requestedBy;
  final Uri sourceUrl;
  MusicQueueItemPhase phase = MusicQueueItemPhase.resolving;
  MusicTrackMetadata? metadata;
  String? filePath;
  double? progress;
  DateTime? startedAt;
  Duration position = Duration.zero;
  bool paused = false;

  _Request(
      {required this.id, required this.requestedBy, required this.sourceUrl});

  MusicQueueItem get view => MusicQueueItem(
      id: id,
      requestedBy: requestedBy,
      sourceUrl: sourceUrl,
      phase: phase,
      title: metadata?.title,
      author: metadata?.author,
      duration: metadata?.duration,
      thumbnail: metadata?.thumbnail,
      preparationProgress: progress);
}
