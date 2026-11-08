import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:twitch_listener/core/observable_value.dart';
import 'package:twitch_listener/secrets.dart';
import 'package:twitch_listener/core/settings.dart';
import 'package:twitch_listener/twitch/twitch_api.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';
import 'package:twitch_listener/twitch/ws_event.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketManager {
  final bool _listenChat;
  final bool _listenFollow;
  final bool _listenRaid;
  final String _url;
  final Settings _settings;
  final TwitchApi Function(String broadcasterId)? _createApi;

  final _registrations = <_Registration>{};

  final _messagesSubject = StreamController<WsMessage>.broadcast();
  final _stateSubject = StreamController<WsStateEvent>.broadcast();
  final _reauthorizationRequired = ObservableValue<Set<TwitchEventType>>(
    current: const {},
  );
  String? _authorizationBroadcasterId;

  WsState _state = WsState.idle;

  DateTime? _lastDisconnectTime;

  bool _waitReconnect = false;

  _Channel? _channel;

  StreamSubscription<dynamic>? _subscription;

  Completer<void>? _registrationCompleter;

  WsState get currentState => _state;

  Stream<WsMessage> get messages => _messagesSubject.stream;

  ObservableValue<Set<TwitchEventType>> get reauthorizationRequired =>
      _reauthorizationRequired;

  WebSocketManager(
    this._url,
    this._settings, {
    required this._listenChat,
    required this._listenFollow,
    this._listenRaid = false,
    this._createApi,
  }) {
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

  Stream<WsStateEvent> get state =>
      Stream.value(WsStateEvent(_state, _state))
          .concatWith([_stateSubject.stream]);

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
      debugPrint('WEBSOCKET $encoded');

      if (json['metadata']?['message_type'] == 'revocation' &&
          _channel == channel) {
        _handleRevocation(json['payload']?['subscription']);
      }

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
    if (_authorizationBroadcasterId != auth?.broadcasterId) {
      _authorizationBroadcasterId = auth?.broadcasterId;
      _reauthorizationRequired.set(const {});
    }
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

    final api = _apiFor(broadcasterId);

    try {
      final cleaned = await api.cleanupInactiveEventSubs();
      debugPrint('$cleaned');
    } catch (_) {}

    try {
      for (final type in [
        if (_listenRaid) _RegistrationType.raid,
        _RegistrationType.rewards,
        _RegistrationType.rewardUpdates,
        if (_listenFollow) _RegistrationType.follow,
        if (_listenChat) _RegistrationType.chat,
      ]) {
        final registration = _Registration(
          type,
          sessionId: sessionId,
          broadcasterId: broadcasterId,
        );
        final eventType = switch (type) {
          _RegistrationType.raid => TwitchEventType.raid,
          _RegistrationType.follow => TwitchEventType.follow,
          _ => null,
        };
        try {
          await _registerInternal(api, registration);
          if (eventType != null && _isCurrentRegistration(registration)) {
            _setReauthorizationRequired(eventType, false);
          }
        } on DioException catch (e) {
          if (eventType != null &&
              _isCurrentRegistration(registration) &&
              (e.response?.statusCode == 401 ||
                  e.response?.statusCode == 403)) {
            _setReauthorizationRequired(eventType, true);
          }
          debugPrint(
            'EventSub ${type.name}: ${e.response?.statusCode} ${e.message}',
          );
        }
      }
    } finally {
      completer.complete();
    }
  }

  bool _isCurrentRegistration(_Registration registration) =>
      _channel?.sessionId == registration.sessionId &&
      _settings.twitchAuth?.broadcasterId == registration.broadcasterId;

  void _setReauthorizationRequired(TwitchEventType type, bool needed) {
    final current = _reauthorizationRequired.current;
    if (current.contains(type) == needed) return;
    final updated = {...current};
    if (needed) {
      updated.add(type);
    } else {
      updated.remove(type);
    }
    _reauthorizationRequired.set(Set.unmodifiable(updated));
  }

  void _handleRevocation(dynamic subscription) {
    if (subscription is! Map) return;
    final type = switch (subscription['type']) {
      'channel.raid' => TwitchEventType.raid,
      'channel.follow' => TwitchEventType.follow,
      _ => null,
    };
    if (type == null) return;
    final targetId =
        subscription['condition']?[type == TwitchEventType.raid
            ? 'to_broadcaster_user_id'
            : 'broadcaster_user_id'];
    if (targetId == null || targetId != _settings.twitchAuth?.broadcasterId) {
      return;
    }
    final registrationType = type == TwitchEventType.raid
        ? _RegistrationType.raid
        : _RegistrationType.follow;
    _registrations.removeWhere(
      (registration) =>
          registration.type == registrationType &&
          _isCurrentRegistration(registration),
    );
    if (subscription['status'] == 'authorization_revoked') {
      _setReauthorizationRequired(type, true);
    }
  }

  TwitchApi _apiFor(String broadcasterId) =>
      _createApi?.call(broadcasterId) ??
      TwitchApi(
        broadcasterId: broadcasterId,
        settings: _settings,
        clientSecret: twitchClientSecret,
      );

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

      case _RegistrationType.rewardUpdates:
        await api.subscribeCustomRewards(
          broadcasterUserId: registration.broadcasterId,
          sessionId: registration.sessionId,
          updates: true,
        );
        break;

      case _RegistrationType.raid:
        await api.subscribeRaidEvents(
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

  void removeChatMessage(String? messageId) {
    final broadcasterId = _settings.twitchAuth?.broadcasterId;

    if (messageId != null && broadcasterId != null) {
      final api = _apiFor(broadcasterId);
      api.deleteChatMessage(
        broadcasterUserId: broadcasterId,
        messageId: messageId,
      );
    }
  }
}

class _Channel {
  final IOWebSocketChannel channel;

  String? sessionId;

  _Channel({required this.channel});
}

enum _RegistrationType { rewards, rewardUpdates, follow, chat, raid }

enum TwitchEventType { raid, follow }

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
