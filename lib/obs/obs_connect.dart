import 'package:obs_websocket/obs_websocket.dart';

class ObsConnect {
  ObsWebSocket? _ws;

  ObsWebSocket? get ws => _ws;

  Future<void> apply(ObsWebSocket? ws) async {
    try {
      _ws?.close();
    } catch (_) {

    }

    _ws = ws;
  }
}
