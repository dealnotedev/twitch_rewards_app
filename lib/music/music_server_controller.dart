import 'package:flutter/foundation.dart';
import 'package:dart_music_player_protocol/dart_music_player_protocol_io.dart';

/// Publishes the existing player on this computer; owns no playback resources.
class MusicServerController extends ChangeNotifier {
  final MusicControlServer _server;
  Future<void> _pending = Future.value();
  bool _closed = false;
  String? error;

  MusicServerController(
    MusicRequests requests, {
    int port = MusicControlProtocol.listenerPort,
  }) : _server = MusicControlServer(requests: requests, requestedPort: port);

  int? get port => _server.port;

  Future<void> start() => _pending = _pending.then((_) async {
    if (_closed) return;
    try {
      await _server.start();
      error = null;
    } catch (failure) {
      error = failure.toString();
    }
    if (!_closed) notifyListeners();
  });

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _pending;
    await _server.close();
    dispose();
  }
}
