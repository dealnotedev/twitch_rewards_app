import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:twitch_listener/secrets.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/twitch/twitch_api.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';
import 'package:twitch_listener/twitch/ws_event.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketManager {
  final bool _listenChat;
  final bool _listenFollow;
  final String _url;
  final Settings _settings;

  final _registrations = <_Registration>{};

  final _messagesSubject = StreamController<WsMessage>.broadcast();
  final _stateSubject = StreamController<WsStateEvent>.broadcast();

  WsState _state = WsState.idle;

  DateTime? _lastDisconnectTime;

  bool _waitReconnect = false;

  _Channel? _channel;

  StreamSubscription<dynamic>? _subscription;

  Completer<void>? _registrationCompleter;

  WsState get currentState => _state;

  Stream<WsMessage> get messages => _messagesSubject.stream;

  WebSocketManager(this._url, this._settings,
      {required bool listenChat, required bool listenFollow})
      : _listenChat = listenChat,
        _listenFollow = listenFollow {
    _settings.twitchAuthStream.listen(_handleAuth);
  }

  void _changeState(WsState state) {
    debugPrint('Ws state: $state');

    Duration? offlineDuration;

    switch (state) {
      case WsState.idle:
        _lastDisconnectTime = null;
        break;

      case WsState.disconnected:
        _lastDisconnectTime = DateTime.now();
        break;

      case WsState.connected:
        final lastDisconnect = _lastDisconnectTime;
        if (lastDisconnect != null) {
          offlineDuration = DateTime.now().difference(lastDisconnect);
        }
        break;
      default:
        // ignore
        break;
    }

    final stateBefore = _state;
    _state = state;

    _stateSubject.add(
      WsStateEvent(stateBefore, state, offlineDuration: offlineDuration),
    );
  }

  Stream<WsStateEvent> get state => Stream.value(
        WsStateEvent(_state, _state),
      ).concatWith([_stateSubject.stream]);

  Stream<WsState> get stateShanges =>
      _stateSubject.stream.map((event) => event.current);

  void _connectInternal() async {
    switch (_state) {
      case WsState.connected:
      case WsState.initialConnecting:
      case WsState.reconnecting:
        return;

      case WsState.idle:
        _changeState(WsState.initialConnecting);
        break;

      case WsState.disconnected:
        _changeState(WsState.reconnecting);
        break;
    }

    final _Channel channel;

    try {
      final ws = await WebSocket.connect(_url);
      ws.pingInterval = const Duration(seconds: 10);

      channel = _channel = _Channel(channel: IOWebSocketChannel(ws));
      _changeState(WsState.connected);
    } catch (e) {
      _onClosed();
      return;
    }

    _subscription = channel.channel.stream.listen((dynamic event) {
      final json = jsonDecode(event);
      final sessionId = json['payload']?['session']?['id'] as String?;

      if (sessionId != null) {
        channel.sessionId = sessionId;

        _checkWsRegistration();
        return;
      }

      final encoded = jsonEncode(json);
      print('WEBSOCKET $encoded');

      final msg = WsMessage.fromJson(json);
      _messagesSubject.add(msg);
    }, onDone: _onClosed);
  }

  void write(String message) {
    _channel?.channel.sink.add(message);
  }

  void _destroyCurrentConnection(WsState state) {
    _subscription?.cancel();

    _channel?.channel.sink.close(1000);
    _channel = null;

    _changeState(state);
  }

  void _onClosed() {
    _destroyCurrentConnection(WsState.disconnected);

    if (_waitReconnect) {
      return;
    }

    _waitReconnect = true;

    Future.delayed(const Duration(seconds: 5), () {
      _waitReconnect = false;
      _connectInternal();
    });
  }

  void _handleAuth(TwitchCreds? auth) {
    if (auth == null) {
      _destroyCurrentConnection(WsState.idle);
      return;
    }

    switch (_state) {
      case WsState.connected:
        _checkWsRegistration();
        break;

      case WsState.disconnected:
      case WsState.initialConnecting:
      case WsState.reconnecting:
        break;

      case WsState.idle:
        _connectInternal();
        break;
    }
  }

  void _checkWsRegistration() async {
    final sessionId = _channel?.sessionId;
    final broadcasterId = _settings.twitchAuth?.broadcasterId;

    if (sessionId == null || broadcasterId == null) return;

    await _registrationCompleter?.future;

    final completer = _registrationCompleter = Completer<void>();

    final api = TwitchApi(
      broadcasterId: broadcasterId,
      settings: _settings,
      clientSecret: twitchClientSecret,
    );

    try {
      await _registerInternal(
        api,
        _Registration(
          _RegistrationType.rewards,
          sessionId: sessionId,
          broadcasterId: broadcasterId,
        ),
      );

      if(_listenFollow){
        await _registerInternal(
          api,
          _Registration(
            _RegistrationType.follow,
            sessionId: sessionId,
            broadcasterId: broadcasterId,
          ),
        );
      }

      if (_listenChat) {
        await _registerInternal(
          api,
          _Registration(
            _RegistrationType.chat,
            sessionId: sessionId,
            broadcasterId: broadcasterId,
          ),
        );
      }
    } on DioException catch (e) {
      print('Api Error ${e.response?.statusCode} with message ${e.message}');
      rethrow;
    } finally {
      completer.complete();
    }
  }

  Future<void> _registerInternal(
    TwitchApi api,
    _Registration registration,
  ) async {
    if (_registrations.contains(registration)) return;

    switch (registration.type) {
      case _RegistrationType.chat:
        await api.subscribeChat(
          broadcasterUserId: registration.broadcasterId,
          sessionId: registration.sessionId,
        );
        break;

      case _RegistrationType.rewards:
        await api.subscribeCustomRewards(
          broadcasterUserId: registration.broadcasterId,
          sessionId: registration.sessionId,
        );
        break;

      case _RegistrationType.follow:
        await api.subscribeFollowEvents(
          broadcasterUserId: registration.broadcasterId,
          sessionId: registration.sessionId,
        );
        break;
    }

    _registrations.add(registration);
  }
}

class _Channel {
  final IOWebSocketChannel channel;

  String? sessionId;

  _Channel({required this.channel});
}

enum _RegistrationType { rewards, follow, chat }

class _Registration {
  final _RegistrationType type;
  final String sessionId;
  final String broadcasterId;

  _Registration(
    this.type, {
    required this.sessionId,
    required this.broadcasterId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Registration &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          sessionId == other.sessionId &&
          broadcasterId == other.broadcasterId;

  @override
  int get hashCode =>
      type.hashCode ^ sessionId.hashCode ^ broadcasterId.hashCode;
}

enum WsState { initialConnecting, connected, disconnected, reconnecting, idle }

class WsStateEvent {
  final WsState before;
  final WsState current;

  final Duration? offlineDuration;

  WsStateEvent(this.before, this.current, {this.offlineDuration});

  bool get changed => before != current;
}
