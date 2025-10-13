import 'dart:async';

class Autosaver {
  final _saveCallbacks = <SaveCallback>[];

  Completer<void>? _completer;

  Completer<void>? _saving;

  final Duration delay;

  Autosaver({required this.delay});

  void notifyChanges() async {
    await _saving?.future;

    _completer?.complete();
    _completer = null;

    final completer = _completer = Completer<void>();

    await Future.delayed(delay);

    if (completer.isCompleted) return;

    final saving = _saving = Completer();

    try {
      for (var callback in _saveCallbacks) {
        await callback.call();
      }
    } finally {
      saving.complete();
    }
  }

  Future<void> get saving async {
    await _saving?.future;
  }

  void registerSaveCallback(SaveCallback callback) {
    _saveCallbacks.add(callback);
  }

  void unregisterSaveCallback(SaveCallback callback) {
    _saveCallbacks.remove(callback);
  }
}

typedef SaveCallback = Future<void> Function();
