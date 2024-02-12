import 'package:obs_websocket/obs_websocket.dart';
import 'package:twitch_listener/extensions.dart';

class ObsConnect {
  ObsWebSocket? _ws;

  ObsWebSocket? get ws => _ws;

  Future<void> apply(ObsWebSocket? ws) async {
    try {
      _ws?.close();
    } catch (_) {}

    _ws = ws;
  }

  Future<void> enableSource(
      {required String sceneName,
      required String sourceName,
      required bool enabled}) async {
    final source = await _ws?.sceneItems.list(sceneName).then(
        (value) => value.firstWhere((item) => item.sourceName == sourceName));

    if (source != null) {
      await _ws?.sceneItems.setEnabled(SceneItemEnableStateChanged(
          sceneName: sceneName,
          sceneItemId: source.sceneItemId,
          sceneItemEnabled: enabled));
    }
  }

  Future<void> flipSource(
      {required String sceneName,
      required String sourceName,
      required bool horizontal,
      required bool vertical}) async {
    final items = await _ws?.sceneItems.list(sceneName) ?? [];
    final source =
        items.firstWhereOrNull((element) => element.sourceName == sourceName);

    if (source == null) return;

    final transform = (await _ws?.sendRequest(Request('GetSceneItemTransform',
            requestData: {
          'sceneName': sceneName,
          'sceneItemId': source.sceneItemId
        })))
        ?.responseData?['sceneItemTransform'];

    final width = transform['width'] as double;
    final height = transform['height'] as double;

    final scaleX = transform['scaleX'] as double;
    final scaleY = transform['scaleY'] as double;

    final positionX = transform['positionX'] as double;
    final positionY = transform['positionY'] as double;

    _ws?.sendRequest(Request(
      'SetSceneItemTransform',
      requestData: {
        'sceneName': sceneName,
        'sceneItemId': source.sceneItemId,
        'sceneItemTransform': {
          'width': horizontal ? -width : width,
          'height': vertical ? -height : height,
          'scaleY': vertical ? -scaleY : scaleY,
          'scaleX': horizontal ? -scaleX : scaleX,
          'positionY': vertical ? (positionY + height) : positionY,
          'positionX': horizontal ? (positionX + width) : positionX
        }
      },
    ));
  }

  Future<void> enableInput({required String inputName, required bool enabled}) {
    return _ws?.inputs.setInputMute(inputName, !enabled) ?? Future.value();
  }

  Future<void> invertSourceFilter(
      {required String sourceName, required String filterName}) async {
    final json = await _ws?.sendRequest(Request('GetSourceFilter',
        requestData: {'sourceName': sourceName, 'filterName': filterName}));

    final enabled = json?.responseData?['filterEnabled'] as bool?;
    if (enabled != null) {
      await enableSourceFilter(
          sourceName: sourceName, filterName: filterName, enabled: !enabled);
    }
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
