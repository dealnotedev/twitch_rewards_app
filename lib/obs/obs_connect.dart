import 'package:obs_websocket/obs_websocket.dart';

class ObsConnect {
  ObsWebSocket? _ws;

  ObsWebSocket? get ws => _ws;

  Future<void> apply(ObsWebSocket? ws) async {
    try {
      _ws?.close();
    } catch (_) {}

    _ws = ws;
  }

  Future<void> enableInput({required String inputName, required bool enabled}) {
    return _ws?.inputs.setInputMute(inputName, !enabled) ?? Future.value();
  }

  Future<void> enableSourceFilter(
      {required String sourceName,
      required String filterName,
      required bool enabled}) {
    return _ws?.filters.setSourceFilterEnabled(
            sourceName: sourceName,
            filterName: filterName,
            filterEnabled: enabled) ??
        Future.value();
  }
}
