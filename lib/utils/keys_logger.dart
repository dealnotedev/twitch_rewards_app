import 'package:flutter/services.dart';
import 'package:hid_listener/hid_listener.dart';

class KeysLogger {
  KeysLogger._();

  static HidListenerBackend? _listenerBackend;

  static VoidCallback? listen(
    void Function({required int keyCode, required String keyLabel}) onKeyDown,
  ) {
    final backend = _getReadyBackend();
    if (backend == null) return null;

    final listenerId = backend.addKeyboardListener((event) {
      final data = event.data;
      // hid_listener 2.0.1 only emits RawKeyEvent. Keep its Windows virtual-key
      // codes for SendInput until the dependency supports a modern event API.
      // ignore: deprecated_member_use
      if (data is! RawKeyEventDataWindows) return;
      // ignore: deprecated_member_use
      if (event is! RawKeyDownEvent) return;

      onKeyDown(keyCode: data.keyCode, keyLabel: event.logicalKey.keyLabel);
    });
    if (listenerId == null) return null;
    return () => backend.removeKeyboardListener(listenerId);
  }

  static HidListenerBackend? _getReadyBackend() {
    final HidListenerBackend? prepared = _listenerBackend;

    if (prepared != null) {
      return prepared;
    }

    final created = getListenerBackend();

    if (created != null && created.initialize()) {
      return _listenerBackend = created;
    } else {
      return null;
    }
  }
}
