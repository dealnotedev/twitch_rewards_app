import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path/path.dart' as p;

// Reward sounds can use up to 300% gain.
const _maxVoiceVolume = 3.0;

class SoloudAudio {
  SoloudAudio(this._engine);

  static final shared = SoloudAudio(SoLoud.instance);

  final SoLoud _engine;
  final _sources = <String, _LoadedSound>{};
  Future<void>? _initializing;

  Future<void> _ensureInitialized() async {
    if (_engine.isInitialized) return;
    final initializing = _initializing ??= _engine.init();
    try {
      await initializing;
    } finally {
      if (identical(_initializing, initializing)) _initializing = null;
    }
  }

  Future<SoloudPlayback> playFile(
    String filePath, {
    required double volume,
    bool looping = false,
  }) async {
    await _ensureInitialized();
    final path = p.normalize(p.absolute(filePath));
    final key = p.canonicalize(path);
    var disposing = _sources[key]?.disposing;
    while (disposing != null) {
      await disposing;
      disposing = _sources[key]?.disposing;
    }
    // SoLoud deduplicates files by path. Keep the source alive until every
    // voice using it has closed, including other previews of the same file.
    final entry = _sources.putIfAbsent(
      key,
      () => _LoadedSound(_engine.loadFile(path)),
    );
    entry.users++;
    AudioSource? source;
    try {
      final loaded = source = await entry.loading;
      if (_engine.getAudioDeviceState() != AudioDeviceState.started) {
        // Surface device errors before waiting for a voice to finish.
        await _engine.startAudioDevice();
      }
      final handle = _engine.play(
        loaded,
        volume: volume.clamp(0.0, _maxVoiceVolume),
        paused: true,
        looping: looping,
      );
      if (!_engine.getIsValidVoiceHandle(handle)) {
        throw StateError('Could not start audio playback: $filePath');
      }
      return SoloudPlayback._(
        _engine,
        loaded,
        handle,
        () => _release(key, entry, loaded),
      );
    } catch (_) {
      await _release(key, entry, source);
      rethrow;
    }
  }

  Future<void> _release(
    String key,
    _LoadedSound entry,
    AudioSource? source,
  ) async {
    if (--entry.users != 0) return;
    if (source == null) {
      _sources.remove(key);
      return;
    }
    await (entry.disposing = _engine.disposeSource(source).whenComplete(() {
      _sources.remove(key);
    }));
  }
}

class _LoadedSound {
  _LoadedSound(this.loading);

  final Future<AudioSource> loading;
  Future<void>? disposing;
  int users = 0;
}

/// A paused voice that owns a reference to its loaded audio source.
class SoloudPlayback {
  SoloudPlayback._(
    this._engine,
    AudioSource source,
    this._handle,
    this._release,
  ) : length = _engine.getLength(source) {
    _events = source.soundEvents.listen((event) {
      if (event.handle == _handle && !_completed.isCompleted) {
        _completed.complete();
      }
    });
  }

  final SoLoud _engine;
  final SoundHandle _handle;
  final Future<void> Function() _release;
  final Duration length;
  final _completed = Completer<void>();
  late final StreamSubscription<StreamSoundEvent> _events;
  Future<void>? _closing;

  Future<void> get completed => _completed.future;
  bool get isActive =>
      !_completed.isCompleted && _engine.getIsValidVoiceHandle(_handle);
  Duration get position => _engine.getPosition(_handle);

  void setPaused(bool paused) {
    if (isActive) _engine.setPause(_handle, paused);
  }

  void seek(Duration position) {
    if (isActive) _engine.seek(_handle, position > length ? length : position);
  }

  void setVolume(double volume) {
    if (isActive) {
      _engine.setVolume(_handle, volume.clamp(0.0, _maxVoiceVolume));
    }
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    await _events.cancel();
    try {
      if (isActive) await _engine.stop(_handle);
    } finally {
      if (!_completed.isCompleted) _completed.complete();
      await _release();
    }
  }
}
