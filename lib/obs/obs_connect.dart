import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obs_websocket/event.dart';
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
      if (tick % 25 == 0) {
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

  Future<void> _fillSceneItemsIncludeGroups(String sceneName,
      {required List<_SourceEntry> all,
      String? groupName,
      required bool includeGroups}) async {
    final List<SceneItemDetail>? list;

    if (groupName != null) {
      list = await _ws?.sceneItems.getGroupSceneItemList(groupName);
    } else {
      list = await _ws?.sceneItems.list(sceneName);
    }

    if (list != null) {
      all.addAll(
          list.map((e) => _SourceEntry(groupName: groupName, detail: e)));

      if (includeGroups) {
        for (var source in list) {
          if (source.isGroup ?? false) {
            await _fillSceneItemsIncludeGroups(sceneName,
                all: all,
                groupName: source.sourceName,
                includeGroups: includeGroups);
          }
        }
      }
    }
  }

  Future<_SourceEntry?> _findSource(String sceneName, String sourceName,
      {bool recursively = true}) async {
    final List<_SourceEntry> all = [];
    await _fillSceneItemsIncludeGroups(sceneName,
        all: all, includeGroups: recursively);
    return all.firstWhereOrNull((s) => s.detail.sourceName == sourceName);
  }

  Future<void> toggleSource(
      {required String sceneName, required String sourceName}) async {
    final source = await _findSource(sceneName, sourceName, recursively: true);

    if (source != null) {
      final enabled = source.detail.sceneItemEnabled;

      await _ws?.sceneItems.setEnabled(SceneItemEnableStateChanged(
          sceneName: source.groupName ?? sceneName,
          sceneItemId: source.detail.sceneItemId,
          sceneItemEnabled: !enabled));
    }
  }

  Future<void> enableSource(
      {required String sceneName,
      required String sourceName,
      required bool enabled}) async {
    final source = await _findSource(sceneName, sourceName, recursively: true);

    if (source != null) {
      await _ws?.sceneItems.setEnabled(SceneItemEnableStateChanged(
          sceneName: source.groupName ?? sceneName,
          sceneItemId: source.detail.sceneItemId,
          sceneItemEnabled: enabled));
    }
  }

  Future<void> enableScene({required List<String> sceneNames}) async {
    final current = await _ws?.scenes.getCurrentProgramScene();
    final currentIndex = current != null ? sceneNames.indexOf(current) : -1;

    final String nextSceneName;
    if (currentIndex != -1 && currentIndex != sceneNames.length - 1) {
      nextSceneName = sceneNames[currentIndex + 1];
    } else {
      nextSceneName = sceneNames[0];
    }

    return _ws?.scenes.setCurrentProgramScene(nextSceneName) ?? Future.value();
  }

  Future<void> flipSource(
      {required String rootSceneName,
      required String sourceName,
      required bool horizontal,
      required bool vertical}) async {
    final source = await _findSource(rootSceneName, sourceName);

    if (source == null) return;

    final sceneName = source.groupName ?? rootSceneName;

    final response = (await _ws?.sendRequest(Request('GetSceneItemTransform',
            requestData: {
          'sceneName': sceneName,
          'sceneItemId': source.detail.sceneItemId
        })))
        ?.responseData;

    final transform = response?['sceneItemTransform'];

    final scaleX = transform['scaleX'] as double;
    final scaleY = transform['scaleY'] as double;

    final data = {
      'sceneName': sceneName,
      'sceneItemId': source.detail.sceneItemId,
      'sceneItemTransform': {
        'scaleY': vertical ? -scaleY : scaleY,
        'scaleX': horizontal ? -scaleX : scaleX
      }
    };

    _ws?.sendRequest(Request('SetSceneItemTransform', requestData: data));
  }

  Future<void> enableInput({required String inputName, required bool enabled}) {
    return _ws?.inputs
            .setInputMute(inputName: inputName, inputMuted: !enabled) ??
        Future.value();
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

class _SourceEntry {
  final String? groupName;
  final SceneItemDetail detail;

  _SourceEntry({required this.groupName, required this.detail});
}
