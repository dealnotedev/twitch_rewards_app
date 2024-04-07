import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/observable_value.dart';
import 'package:twitch_listener/settings.dart';

class ObsConnect {
  final Settings settings;

  ObsWebSocket? _ws;

  StreamSubscription? _prefsSubscription;

  bool _released = false;

  ObsConnect({required this.settings}) {
    _prefsSubscription = settings.obsPrefsStream.listen(_connectIfCan);
    _startTickerLoop();
  }

  void _startTickerLoop() async {
    int tick = 0;
    while (true) {
      tick++;
      if (_released) break;

      await Future.delayed(const Duration(seconds: 10));
      await _handleTimerTick(tick);
    }
  }

  void release() {
    _released = true;
    _prefsSubscription?.cancel();

    _releaseConnection();
  }

  Future<void> _connectIfCan(ObsPrefs? prefs) async {
    _releaseConnection();

    final url = prefs?.url;
    final password = prefs?.password;

    if (url != null &&
        url.isNotEmpty &&
        password != null &&
        password.isNotEmpty) {
      state.set(ObsState.connecting);

      try {
        debugPrint('Try connect obs');

        final obs = await ObsWebSocket.connect(url,
            password: password, timeout: const Duration(seconds: 10));
        await obs.stream.status;

        debugPrint('Obs connected');

        if (settings.obsPrefs != prefs) {
          // This prefs is not actual now
          return;
        }

        _ws = obs;
        state.set(ObsState.connected);
      } catch (_) {
        state.set(ObsState.failed);
      }
    }
  }

  Future<void> _handleTimerTick(int tick) async {
    try {
      if (tick % 10 == 0) {
        throw StateError('Reconnect on $tick tick');
      }

      final ws = _ws;

      if (ws != null) {
        await ws.stream.status;
        return;
      }
    } catch (_) {
      debugPrint('Obs failed');
      _releaseConnection();
    }

    await _connectIfCan(settings.obsPrefs);
  }

  void _releaseConnection() {
    if (_ws == null) return;

    try {
      _ws?.close();
    } catch (_) {
    } finally {
      _ws = null;
    }

    state.set(ObsState.failed);
  }

  final state = ObservableValue(current: ObsState.failed);

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

  Future<void> enableScene({required String sceneName}) {
    return _ws?.scenes.setCurrentProgramScene(sceneName) ?? Future.value();
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

    final response = (await _ws?.sendRequest(Request('GetSceneItemTransform',
            requestData: {
          'sceneName': sceneName,
          'sceneItemId': source.sceneItemId
        })))
        ?.responseData;

    print('GetSceneItemTransform <- $response');

    final transform = response?['sceneItemTransform'];

    final width = transform['width'] as double;
    final height = transform['height'] as double;

    final scaleX = transform['scaleX'] as double;
    final scaleY = transform['scaleY'] as double;

    final positionX = transform['positionX'] as double;
    final positionY = transform['positionY'] as double;

    final data = {
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
    };

    print('SetSceneItemTransform -> $data');

    _ws?.sendRequest(Request('SetSceneItemTransform', requestData: data));
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

enum ObsState { failed, connecting, connected }
