import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';

import 'rewards_fakes.dart';

void main() {
  for (final listenRaid in [true, false]) {
    test('WebSocket registers Raid when enabled=$listenRaid', () async {
      final h = await _connect(listenRaid: listenRaid);
      expect(
        h.api.subscriptions.keys,
        containsAll(['reward-add', 'reward-update', 'chat']),
      );
      expect(h.api.subscriptions.containsKey('raid'), listenRaid);
      for (final subscription in h.api.subscriptions.values) {
        expect(subscription, (
          broadcasterId: 'channel',
          sessionId: 'test-session',
        ));
      }
      if (listenRaid) {
        final received = h.manager.messages.first;
        h.socket.add(
          jsonEncode({
            'metadata': {
              'message_id': 'raid-delivery',
              'message_type': 'notification',
            },
            'payload': {
              'subscription': {'type': 'channel.raid'},
              'event': {
                'from_broadcaster_user_id': 'raider',
                'from_broadcaster_user_name': 'Raider',
                'to_broadcaster_user_id': 'channel',
                'viewers': 42,
              },
            },
          }),
        );
        final notification = await received.timeout(const Duration(seconds: 5));
        expect(notification.notificationId, 'raid-delivery');
        expect(notification.payload.subscription?.type, 'channel.raid');
        expect(notification.payload.event?.fromBroadcasterUserId, 'raider');
        expect(notification.payload.event?.fromBroadcasterUserName, 'Raider');
        expect(notification.payload.event?.toBroadcasterUserId, 'channel');
      }
    });
  }

  test(
    'an unrelated EventSub scope error does not block Raid or chat',
    () async {
      final h = await _connect(listenRaid: true, rejectRewards: true);
      expect(h.api.subscriptions.keys, containsAll(['raid', 'chat']));
      expect(h.manager.currentState, WsState.connected);
    },
  );

  test(
    'Follow subscribes and receives the follower event over WebSocket',
    () async {
      final h = await _connect(listenRaid: true, listenFollow: true);
      expect(h.api.subscriptions['follow'], (
        broadcasterId: 'channel',
        sessionId: 'test-session',
      ));
      final received = h.manager.messages.first;
      h.socket.add(
        jsonEncode({
          'metadata': {
            'message_id': 'follow-delivery',
            'message_type': 'notification',
          },
          'payload': {
            'subscription': {'type': 'channel.follow'},
            'event': {
              'broadcaster_user_id': 'channel',
              'user_id': 'follower',
              'user_name': 'Follower',
              'followed_at': '2026-11-08T12:00:00Z',
            },
          },
        }),
      );
      final notification = await received.timeout(const Duration(seconds: 5));
      expect(notification.notificationId, 'follow-delivery');
      expect(notification.payload.event?.broadcasterUserId, 'channel');
      expect(notification.payload.event?.userId, 'follower');
      expect(notification.payload.event?.userName, 'Follower');
    },
  );

  for (final type in TwitchEventType.values) {
    for (final status in [401, 403]) {
      test(
        '$type authorization error $status requests relogin and clears after success',
        () async {
          final h = await _connect(
            listenRaid: true,
            listenFollow: true,
            eventErrors: {type: status},
          );
          expect(h.manager.reauthorizationRequired.current, {type});
          expect(h.api.subscriptions.keys, contains('chat'));
          h.api.eventErrors.clear();
          final cleared = _waitForAuthorization(h.manager, {});
          await h.settings.saveTwitchAuth(credentials());
          await cleared;
          expect(h.api.attempts[type], 2);
          expect(h.api.subscriptions.keys, containsAll(['raid', 'follow']));
        },
      );
    }

    test(
      '$type authorization revocation warns and registers again on relogin',
      () async {
        final h = await _connect(listenRaid: true, listenFollow: true);
        final warned = _waitForAuthorization(h.manager, {type});
        h.socket.add(
          jsonEncode({
            'metadata': {'message_type': 'revocation'},
            'payload': {
              'subscription': {
                'type': 'channel.${type.name}',
                'status': 'authorization_revoked',
                'condition': {
                  type == TwitchEventType.raid
                          ? 'to_broadcaster_user_id'
                          : 'broadcaster_user_id':
                      'channel',
                },
              },
            },
          }),
        );
        await warned;
        final cleared = _waitForAuthorization(h.manager, {});
        await h.settings.saveTwitchAuth(credentials());
        await cleared;
        expect(h.api.attempts[type], 2);
      },
    );
  }

  test('server errors do not show a missing-permissions warning', () async {
    final h = await _connect(
      listenRaid: true,
      listenFollow: true,
      eventErrors: {TwitchEventType.raid: 500, TwitchEventType.follow: 500},
    );
    expect(h.manager.reauthorizationRequired.current, isEmpty);
    expect(h.api.subscriptions.keys, contains('chat'));
  });

  test(
    'both missing permissions are reported and logout clears the warning',
    () async {
      final h = await _connect(
        listenRaid: true,
        listenFollow: true,
        eventErrors: {TwitchEventType.raid: 403, TwitchEventType.follow: 403},
      );
      expect(
        h.manager.reauthorizationRequired.current,
        TwitchEventType.values.toSet(),
      );
      final cleared = _waitForAuthorization(h.manager, {});
      await h.settings.saveTwitchAuth(null);
      await cleared;
      expect(h.manager.reauthorizationRequired.current, isEmpty);
    },
  );
}

Future<void> _waitForAuthorization(
  WebSocketManager manager,
  Set<TwitchEventType> expected,
) {
  final state = manager.reauthorizationRequired;
  if (setEquals(state.current, expected)) return Future.value();
  return state.changes
      .firstWhere((value) => setEquals(value, expected))
      .timeout(const Duration(seconds: 5))
      .then((_) {});
}

Future<
  ({WebSocketManager manager, WebSocket socket, _Api api, _Settings settings})
>
_connect({
  required bool listenRaid,
  bool listenFollow = false,
  bool rejectRewards = false,
  Map<TwitchEventType, int> eventErrors = const {},
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final settings = _Settings();
  final api = _Api(rejectRewards: rejectRewards, eventErrors: eventErrors);
  final connected = Completer<WebSocket>();
  final requests = server.listen((request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    connected.complete(socket);
    socket.add(
      jsonEncode({
        'metadata': {'message_type': 'session_welcome'},
        'payload': {
          'session': {'id': 'test-session'},
        },
      }),
    );
  });
  final manager = WebSocketManager(
    'ws://127.0.0.1:${server.port}',
    settings,
    listenChat: true,
    listenFollow: listenFollow,
    listenRaid: listenRaid,
    createApi: (broadcasterId) {
      expect(broadcasterId, 'channel');
      return api;
    },
  );
  addTearDown(() async {
    if (manager.currentState != WsState.idle) {
      final idle = manager.stateShanges.firstWhere(
        (state) => state == WsState.idle,
      );
      await settings.saveTwitchAuth(null);
      await idle.timeout(const Duration(seconds: 5));
    }
    if (connected.isCompleted) await (await connected.future).close();
    await requests.cancel();
    await server.close(force: true);
    await settings.authChanges.close();
  });
  await api.registered.future.timeout(const Duration(seconds: 5));
  return (
    manager: manager,
    socket: await connected.future,
    api: api,
    settings: settings,
  );
}

class _Settings extends RewardTestSettings {
  @override
  Stream<TwitchCreds?> get twitchAuthStream async* {
    yield twitchAuth;
    yield* authChanges.stream;
  }
}

class _Api extends RewardTestApi {
  final bool rejectRewards;
  final Map<TwitchEventType, int> eventErrors;
  final attempts = <TwitchEventType, int>{};
  _Api({
    required this.rejectRewards,
    required Map<TwitchEventType, int> eventErrors,
  }) : eventErrors = {...eventErrors};

  void _checkAuthorization(TwitchEventType type) {
    attempts.update(type, (count) => count + 1, ifAbsent: () => 1);
    final status = eventErrors[type];
    if (status == null) return;
    final request = RequestOptions(path: '/eventsub/subscriptions');
    throw DioException(
      requestOptions: request,
      response: Response<dynamic>(requestOptions: request, statusCode: status),
    );
  }

  final registered = Completer<void>();
  final subscriptions = <String, ({String? broadcasterId, String sessionId})>{};

  @override
  Future<int> cleanupInactiveEventSubs() async => 0;

  @override
  Future<void> subscribeRaidEvents({
    required String broadcasterUserId,
    required String sessionId,
  }) async {
    _checkAuthorization(TwitchEventType.raid);
    subscriptions['raid'] = (
      broadcasterId: broadcasterUserId,
      sessionId: sessionId,
    );
  }

  @override
  Future<void> subscribeFollowEvents({
    required String? broadcasterUserId,
    required String sessionId,
  }) async {
    _checkAuthorization(TwitchEventType.follow);
    subscriptions['follow'] = (
      broadcasterId: broadcasterUserId,
      sessionId: sessionId,
    );
  }

  @override
  Future<void> subscribeCustomRewards({
    required String? broadcasterUserId,
    required String sessionId,
    bool updates = false,
  }) async {
    if (rejectRewards) {
      final request = RequestOptions(path: '/eventsub/subscriptions');
      throw DioException(
        requestOptions: request,
        response: Response<dynamic>(requestOptions: request, statusCode: 403),
        message: 'Missing reward scope',
      );
    }
    subscriptions[updates ? 'reward-update' : 'reward-add'] = (
      broadcasterId: broadcasterUserId,
      sessionId: sessionId,
    );
  }

  @override
  Future<void> subscribeChat({
    required String? broadcasterUserId,
    required String sessionId,
  }) async {
    subscriptions['chat'] = (
      broadcasterId: broadcasterUserId,
      sessionId: sessionId,
    );
    if (!registered.isCompleted) registered.complete();
  }
}
