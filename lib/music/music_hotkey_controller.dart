import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:twitch_listener/core/settings.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/player_shortcut.dart';

enum MusicHotkeyResult { saved, unavailable, saveFailed }

class MusicHotkeyController extends ChangeNotifier {
  static const _channel = MethodChannel('listener/music_hotkey');

  final Settings _settings;
  final MusicRequestManager _requests;
  late Future<void> _pending;
  PlayerShortcut? _active;
  bool _closed = false;

  MusicHotkeyController(this._settings, this._requests) {
    _channel.setMethodCallHandler(_handleMethodCall);
    _pending = _restore();
  }

  PlayerShortcut? get shortcut => _settings.playPauseShortcut;
  bool get registrationFailed => shortcut != null && shortcut != _active;
  bool recording = false;

  Future<void> _restore() async {
    final saved = shortcut;
    if (saved == null) return;
    if (await _register(saved)) _active = saved;
    if (!_closed) notifyListeners();
  }

  Future<MusicHotkeyResult> change(PlayerShortcut? next) {
    if (_closed) return Future.value(MusicHotkeyResult.unavailable);
    final operation = _pending.then((_) => _change(next));
    _pending = operation.then((_) {});
    return operation;
  }

  Future<MusicHotkeyResult> _change(PlayerShortcut? next) async {
    final previous = _active;
    if (next != previous && !await _register(next)) {
      return MusicHotkeyResult.unavailable;
    }
    _active = next;
    if (next != shortcut) {
      try {
        await _settings.savePlayPauseShortcut(next);
      } catch (error) {
        debugPrint('Saving the player shortcut failed: $error');
        if (next != previous) {
          if (await _register(previous)) {
            _active = previous;
          } else if (await _register(null)) {
            _active = null;
          }
        }
        if (!_closed) notifyListeners();
        return MusicHotkeyResult.saveFailed;
      }
    }
    if (!_closed) notifyListeners();
    return MusicHotkeyResult.saved;
  }

  Future<bool> _register(PlayerShortcut? shortcut) async {
    try {
      return await _channel.invokeMethod<bool>(
            'setShortcut',
            shortcut?.toJson(),
          ) ==
          true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'pressed' || _closed || _active == null) return;
    if (recording &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    await _requests.togglePaused();
  }

  Future<void> close() async {
    _closed = true;
    _channel.setMethodCallHandler(null);
    await _pending;
    if (_active != null) await _register(null);
    dispose();
  }
}
