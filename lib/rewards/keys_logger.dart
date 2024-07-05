import 'package:hid_listener/hid_listener.dart';

class KeysLogger {
  KeysLogger._();

  static HidListenerBackend? _listenerBackend;

  static HidListenerBackend? getReadyBackend() {
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
