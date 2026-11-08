import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/app/app.dart';
import 'package:twitch_listener/app/app_router.dart';
import 'package:twitch_listener/core/autosaver.dart';
import 'package:twitch_listener/core/observable_value.dart';
import 'package:twitch_listener/core/settings.dart';
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/youtube_connection_controller.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/rewards/reward_execution.dart';
import 'package:twitch_listener/rewards/reward_executor.dart';
import 'package:twitch_listener/twitch/ws_event.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';
import 'package:twitch_listener/updates/update_controller.dart';

import '../music/fakes.dart';
import '../twitch/rewards_fakes.dart';

WsMessage _chatMessage(
  String id,
  String text, {
  String broadcasterId = 'channel',
  String type = 'channel.chat.message',
}) => WsMessage.fromJson({
  'payload': {
    'subscription': {'type': type},
    'event': {
      'broadcaster_user_id': broadcasterId,
      'chatter_user_id': 'viewer',
      'chatter_user_name': 'Viewer',
      'chatter_user_login': 'viewer_login',
      'message_id': id,
      'message_type': 'text',
      'message': {'text': text, 'fragments': []},
    },
  },
});

void main() {
  group('follows', () {
    testWidgets('start every active Follow chain and pass the follower name', (
      tester,
    ) async {
      final follow = Reward(
        name: 'Welcome follower',
        triggerType: RewardTriggerType.follow,
        handlers: [],
      );
      final unnamed = Reward(
        name: '',
        triggerType: RewardTriggerType.follow,
        handlers: [],
      );
      final h = await _pumpApp(tester, [
        follow,
        unnamed,
        Reward(
          name: 'Follower',
          triggerType: RewardTriggerType.follow,
          disabled: true,
          handlers: [],
        ),
        Reward(
          name: 'Follower',
          triggerType: RewardTriggerType.raid,
          handlers: [],
        ),
        Reward(
          name: 'Follower',
          triggerType: RewardTriggerType.command,
          handlers: [],
        ),
        Reward(name: 'Follower', handlers: []),
      ]);
      h.websocket.events.add(_followNotification('follow-1'));
      await tester.pumpAndSettle();
      expect(h.executor.calls.map((call) => call.reward), [follow, unnamed]);
      expect(
        h.executor.calls.map((call) => call.requesterId),
        everyElement('follower'),
      );
      expect(
        h.executor.calls.map((call) => call.requesterLogin),
        everyElement('follower'),
      );
      expect(
        h.executor.calls.map((call) => call.requester),
        everyElement('Follower'),
      );
      expect(
        h.executor.calls.map((call) => call.userInput),
        everyElement(isNull),
      );
      follow.disabled = true;
      unnamed.triggerType = RewardTriggerType.raid;
      h.websocket.events.add(_followNotification('changed-settings'));
      await tester.pumpAndSettle();
      expect(h.executor.calls, hasLength(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('deduplicate follow deliveries independently of raids', (
      tester,
    ) async {
      final follow = Reward(
        name: 'Welcome',
        triggerType: RewardTriggerType.follow,
        handlers: [],
      );
      final raid = Reward(
        name: 'Welcome raid',
        triggerType: RewardTriggerType.raid,
        handlers: [],
      );
      final h = await _pumpApp(tester, [follow, raid]);
      h.websocket.events.add(_followNotification('same-id'));
      h.websocket.events.add(_followNotification('same-id'));
      h.websocket.events.add(_followNotification('new-id'));
      h.websocket.events.add(_raidNotification('same-id'));
      await tester.pumpAndSettle();
      expect(h.executor.calls.map((call) => call.reward), [
        follow,
        follow,
        raid,
      ]);
    });

    testWidgets('ignore foreign, incomplete and logged-out follow events', (
      tester,
    ) async {
      final h = await _pumpApp(tester, [
        Reward(
          name: 'Welcome',
          triggerType: RewardTriggerType.follow,
          handlers: [],
        ),
      ]);
      h.websocket.events.add(
        _followNotification('foreign', broadcasterId: 'other'),
      );
      h.websocket.events.add(_followNotification(null));
      h.websocket.events.add(_followNotification(''));
      h.websocket.events.add(_followNotification('no-user', userId: null));
      h.websocket.events.add(_followNotification('empty-user', userId: ''));
      h.websocket.events.add(
        _followNotification('not-follow', type: 'channel.raid'),
      );
      await tester.pumpAndSettle();
      expect(h.executor.calls, isEmpty);
      h.settings.twitchAuth = null;
      h.websocket.events.add(_followNotification('logged-out'));
      await tester.pumpAndSettle();
      expect(h.executor.calls, isEmpty);
      h.settings.twitchAuth = credentials();
      h.websocket.events.add(_followNotification('valid'));
      await tester.pumpAndSettle();
      expect(h.executor.calls, hasLength(1));
    });
  });

  for (final dark in [false, true]) {
    testWidgets('permission warnings are not shown globally, dark=$dark', (
      tester,
    ) async {
      final h = await _pumpApp(tester, [], dark: dark);
      final warning = find.byKey(
        const ValueKey('twitch-events-permission-warning'),
      );
      expect(warning, findsNothing);
      h.websocket.reauthorizationRequired.set({TwitchEventType.follow});
      await tester.pumpAndSettle();
      expect(warning, findsNothing);
      h.websocket.reauthorizationRequired.set({
        TwitchEventType.follow,
        TwitchEventType.raid,
      });
      await tester.pumpAndSettle();
      expect(warning, findsNothing);
      h.websocket.reauthorizationRequired.set({});
      await tester.pumpAndSettle();
      expect(warning, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  group('incoming raids', () {
    testWidgets('run active Raid chains regardless of their label', (
      tester,
    ) async {
      final raid = Reward(
        name: 'Welcome raiders',
        triggerType: RewardTriggerType.raid,
        twitchRewardId: 'old-link',
        twitchBroadcasterId: 'channel',
        handlers: [RewardAction(type: RewardAction.typeDelay)],
      );
      final unnamed = Reward(
        name: '',
        triggerType: RewardTriggerType.raid,
        handlers: [],
      );
      final h = await _pumpApp(tester, [
        raid,
        unnamed,
        Reward(
          name: 'Raider',
          triggerType: RewardTriggerType.raid,
          disabled: true,
          handlers: [],
        ),
        Reward(name: 'Raider', handlers: []),
        Reward(
          name: 'Raider',
          triggerType: RewardTriggerType.command,
          handlers: [],
        ),
        Reward(
          name: 'Raider',
          triggerType: RewardTriggerType.follow,
          handlers: [],
        ),
      ]);
      h.websocket.events.add(_raidNotification('raid-1'));
      await tester.pumpAndSettle();
      expect(h.executor.calls.map((call) => call.reward), [raid, unnamed]);
      expect(
        h.executor.calls.map((call) => call.requesterId),
        everyElement('raider'),
      );
      expect(
        h.executor.calls.map((call) => call.requesterLogin),
        everyElement('raider'),
      );
      expect(
        h.executor.calls.map((call) => call.requester),
        everyElement('Raider'),
      );
      expect(
        h.executor.calls.map((call) => call.userInput),
        everyElement(isNull),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'deduplicate delivery IDs but allow another raid from the same channel',
      (tester) async {
        final raid = Reward(
          name: 'Welcome',
          triggerType: RewardTriggerType.raid,
          handlers: [],
        );
        final command = Reward(
          name: '!hello',
          triggerType: RewardTriggerType.command,
          handlers: [],
        );
        final h = await _pumpApp(tester, [raid, command]);
        h.websocket.events.add(_raidNotification('same-id'));
        h.websocket.events.add(_raidNotification('same-id'));
        h.websocket.events.add(_raidNotification('new-id'));
        // Chat and EventSub IDs belong to separate namespaces.
        h.websocket.events.add(_chatMessage('same-id', '!hello'));
        await tester.pumpAndSettle();
        expect(h.executor.calls.map((call) => call.reward), [
          raid,
          raid,
          command,
        ]);
      },
    );

    testWidgets(
      'ignore outgoing, foreign, incomplete and logged-out notifications',
      (tester) async {
        final h = await _pumpApp(tester, [
          Reward(
            name: 'Welcome',
            triggerType: RewardTriggerType.raid,
            handlers: [],
          ),
        ]);
        h.websocket.events.add(
          _raidNotification('outgoing', from: 'channel', to: 'other'),
        );
        h.websocket.events.add(_raidNotification('foreign', to: 'other'));
        h.websocket.events.add(_raidNotification(null));
        h.websocket.events.add(_raidNotification(''));
        h.websocket.events.add(_raidNotification('no-source', from: null));
        h.websocket.events.add(_raidNotification('empty-source', from: ''));
        h.websocket.events.add(_raidNotification('no-target', to: null));
        h.websocket.events.add(
          _raidNotification('not-raid', type: 'channel.follow'),
        );
        h.websocket.events.add(
          WsMessage.fromJson({
            'payload': {
              'subscription': {'type': 'channel.raid'},
            },
          }),
        );
        await tester.pumpAndSettle();
        expect(h.executor.calls, isEmpty);
        h.settings.twitchAuth = null;
        h.websocket.events.add(_raidNotification('logged-out'));
        await tester.pumpAndSettle();
        expect(h.executor.calls, isEmpty);
        h.settings.twitchAuth = credentials();
        h.websocket.events.add(_raidNotification('valid'));
        await tester.pumpAndSettle();
        expect(h.executor.calls, hasLength(1));
      },
    );

    testWidgets('use live Active and trigger type settings', (tester) async {
      final raid = Reward(
        name: 'Welcome',
        triggerType: RewardTriggerType.raid,
        handlers: [],
      );
      final h = await _pumpApp(tester, [raid]);
      raid.disabled = true;
      h.websocket.events.add(_raidNotification('disabled'));
      await tester.pumpAndSettle();
      expect(h.executor.calls, isEmpty);
      raid.disabled = false;
      h.websocket.events.add(_raidNotification('enabled'));
      await tester.pumpAndSettle();
      expect(h.executor.calls, hasLength(1));
      raid.triggerType = RewardTriggerType.follow;
      h.websocket.events.add(_raidNotification('follow'));
      await tester.pumpAndSettle();
      expect(h.executor.calls, hasLength(1));
      raid.triggerType = RewardTriggerType.raid;
      raid.name = 'Renamed';
      h.websocket.events.add(_raidNotification('renamed'));
      await tester.pumpAndSettle();
      expect(h.executor.calls, hasLength(2));
    });
  });

  testWidgets('an incoming chat command starts its configured chain', (
    tester,
  ) async {
    final command = Reward(
      name: '!hello',
      triggerType: RewardTriggerType.command,
      handlers: [RewardAction(type: RewardAction.typeDelay)],
    );
    final h = await _pumpApp(tester, [command]);

    h.websocket.events.add(_chatMessage('message-1', '!hello'));
    await tester.pumpAndSettle();

    expect(h.executor.calls.map((call) => call.reward), [same(command)]);
    expect(h.executor.calls.single.requester, 'Viewer');
    expect(h.executor.calls.single.requesterId, 'viewer');
    expect(h.executor.calls.single.requesterLogin, 'viewer_login');
    expect(h.executor.calls.single.userInput, '!hello');
    expect(tester.takeException(), isNull);
  });

  testWidgets('only active Command chains match the whole message exactly', (
    tester,
  ) async {
    final active = Reward(
      name: '!hello',
      triggerType: RewardTriggerType.command,
      handlers: [],
    );
    final h = await _pumpApp(tester, [
      active,
      Reward(
        name: '!hello',
        triggerType: RewardTriggerType.command,
        disabled: true,
        handlers: [],
      ),
      Reward(name: '!hello', handlers: []),
      Reward(name: '!hello', triggerType: RewardTriggerType.raid, handlers: []),
      Reward(
        name: '!hello',
        triggerType: RewardTriggerType.follow,
        handlers: [],
      ),
      Reward(name: '', triggerType: RewardTriggerType.command, handlers: []),
    ]);
    for (final text in [
      '',
      '!Hello',
      ' !hello',
      '!hello ',
      '!hello extra',
      '!hello2',
    ]) {
      h.websocket.events.add(_chatMessage('mismatch-$text', text));
    }
    await tester.pumpAndSettle();
    expect(h.executor.calls, isEmpty);
    h.websocket.events.add(_chatMessage('match', '!hello'));
    await tester.pumpAndSettle();
    expect(h.executor.calls.map((call) => call.reward), [same(active)]);
  });

  testWidgets(
    'replayed messages run once and new messages can repeat a command',
    (tester) async {
      final h = await _pumpApp(tester, [
        Reward(
          name: '!hello',
          triggerType: RewardTriggerType.command,
          handlers: [],
        ),
      ]);
      final message = _chatMessage('same-id', '!hello');
      h.websocket.events.add(message);
      h.websocket.events.add(message);
      await tester.pumpAndSettle();
      expect(h.executor.calls, hasLength(1));
      h.websocket.events.add(_chatMessage('new-id', '!hello'));
      await tester.pumpAndSettle();
      expect(h.executor.calls, hasLength(2));
    },
  );

  testWidgets('foreign, malformed, non-chat and logged-out events do not run', (
    tester,
  ) async {
    final h = await _pumpApp(tester, [
      Reward(
        name: '!hello',
        triggerType: RewardTriggerType.command,
        handlers: [],
      ),
    ]);
    h.websocket.events.add(
      _chatMessage('foreign', '!hello', broadcasterId: 'other'),
    );
    h.websocket.events.add(
      _chatMessage('other-type', '!hello', type: 'channel.follow'),
    );
    h.websocket.events.add(WsMessage.fromJson({'payload': {}}));
    h.websocket.events.add(
      WsMessage.fromJson({
        'payload': {
          'subscription': {'type': 'channel.chat.message'},
          'event': {
            'broadcaster_user_id': 'channel',
            'message': {'text': '!hello', 'fragments': []},
          },
        },
      }),
    );
    await tester.pumpAndSettle();
    expect(h.executor.calls, isEmpty);
    h.settings.twitchAuth = null;
    h.websocket.events.add(_chatMessage('logged-out', '!hello'));
    await tester.pumpAndSettle();
    expect(h.executor.calls, isEmpty);
    h.settings.twitchAuth = credentials();
    h.websocket.events.add(_chatMessage('valid', '!hello'));
    await tester.pumpAndSettle();
    expect(h.executor.calls, hasLength(1));
  });

  testWidgets('one failing chain does not prevent other matching chains', (
    tester,
  ) async {
    final failed = Reward(
      name: '!hello',
      triggerType: RewardTriggerType.command,
      handlers: [],
    );
    final successful = Reward(
      name: '!hello',
      triggerType: RewardTriggerType.command,
      handlers: [],
    );
    final h = await _pumpApp(tester, [failed, successful]);
    var finished = false;
    h.executor.run = (reward) async {
      if (identical(reward, failed)) throw StateError('Expected test failure');
      finished = true;
    };
    h.websocket.events.add(_chatMessage('one', '!hello'));
    await tester.pumpAndSettle();
    expect(h.executor.calls.map((call) => call.reward), [failed, successful]);
    expect(finished, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a waiting chain does not block a later chat message', (
    tester,
  ) async {
    final h = await _pumpApp(tester, [
      Reward(
        name: '!hello',
        triggerType: RewardTriggerType.command,
        handlers: [],
      ),
    ]);
    final waiting = Completer<void>();
    h.executor.run = (_) =>
        h.executor.calls.length == 1 ? waiting.future : Future<void>.value();
    h.websocket.events.add(_chatMessage('one', '!hello'));
    await tester.pumpAndSettle();
    h.websocket.events.add(_chatMessage('two', '!hello'));
    await tester.pumpAndSettle();
    expect(waiting.isCompleted, isFalse);
    expect(h.executor.calls, hasLength(2));
    waiting.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('live name and Active changes are used for subsequent messages', (
    tester,
  ) async {
    final command = Reward(
      name: '!hello',
      triggerType: RewardTriggerType.command,
      handlers: [],
    );
    final h = await _pumpApp(tester, [command]);
    command.name = '!updated';
    h.websocket.events.add(_chatMessage('old', '!hello'));
    h.websocket.events.add(_chatMessage('new', '!updated'));
    await tester.pumpAndSettle();
    expect(h.executor.calls, hasLength(1));
    command.disabled = true;
    h.websocket.events.add(_chatMessage('disabled', '!updated'));
    await tester.pumpAndSettle();
    expect(h.executor.calls, hasLength(1));
    command.disabled = false;
    h.websocket.events.add(_chatMessage('enabled', '!updated'));
    await tester.pumpAndSettle();
    expect(h.executor.calls, hasLength(2));
  });

  testWidgets(
    'the existing delete command still removes the previous message',
    (tester) async {
      final h = await _pumpApp(tester, [
        Reward(
          name: '!удолі',
          triggerType: RewardTriggerType.command,
          handlers: [],
        ),
      ]);
      h.websocket.events.add(_chatMessage('previous', 'ordinary chat message'));
      h.websocket.events.add(_chatMessage('delete', '!удолі'));
      await tester.pumpAndSettle();
      expect(h.websocket.deleted, ['previous', 'delete']);
      expect(h.executor.calls, hasLength(1));
    },
  );
}

WsMessage _followNotification(
  String? id, {
  String broadcasterId = 'channel',
  String? userId = 'follower',
  String type = 'channel.follow',
}) => WsMessage.fromJson({
  'metadata': {
    'message_id': id,
    'message_type': 'notification',
    'subscription_type': type,
    'subscription_version': '2',
  },
  'payload': {
    'subscription': {'id': 'follow-subscription', 'type': type},
    'event': {
      'broadcaster_user_id': broadcasterId,
      'user_id': userId,
      'user_login': 'follower',
      'user_name': 'Follower',
      'followed_at': '2026-11-08T12:00:00Z',
    },
  },
});

WsMessage _raidNotification(
  String? id, {
  String? from = 'raider',
  String? to = 'channel',
  String type = 'channel.raid',
}) => WsMessage.fromJson({
  'metadata': {
    'message_id': id,
    'message_type': 'notification',
    'subscription_type': type,
    'subscription_version': '1',
  },
  'payload': {
    'subscription': {'id': 'raid-subscription', 'type': type},
    'event': {
      'from_broadcaster_user_id': from,
      'from_broadcaster_user_login': 'raider',
      'from_broadcaster_user_name': 'Raider',
      'to_broadcaster_user_id': to,
      'to_broadcaster_user_login': 'channel',
      'to_broadcaster_user_name': 'Channel',
      'viewers': 42,
    },
  },
});

typedef _Harness = ({
  RewardTestSettings settings,
  _WebSocketManager websocket,
  _Executor executor,
});

Future<_Harness> _pumpApp(
  WidgetTester tester,
  List<Reward> rewards, {
  bool dark = false,
}) async {
  for (final reward in rewards) {
    for (final action in reward.handlers) {
      addTearDown(action.dispose);
    }
  }
  final settings = RewardTestSettings(localRewards: rewards)
    ..appearance = Appearance(
      brightness: dark ? AppBrightness.dark : AppBrightness.light,
    );
  final websocket = _WebSocketManager();
  final executor = _Executor();
  final music = MusicRequestManager(
    fetcher: FakeFetcher(),
    player: FakePlayer(),
  );
  final locator = _Locator({
    Settings: settings,
    WebSocketManager: websocket,
    RewardExecutor: executor,
    Autosaver: Autosaver(delay: Duration.zero),
    UpdateController: UpdateController(check: () async => null),
    MusicRequestManager: music,
    YoutubeConnectionController: _Connection(),
  });
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await websocket.events.close();
    websocket.reauthorizationRequired.dispose();
    await settings.authChanges.close();
  });
  await tester.pumpWidget(
    ListenerApp(
      locator: locator,
      router: _Router(locator: locator),
    ),
  );
  await tester.pumpAndSettle();
  return (settings: settings, websocket: websocket, executor: executor);
}

class _Locator extends ServiceLocator {
  final Map<Type, Object> dependencies;
  _Locator(this.dependencies);

  @override
  T provide<T>() => dependencies[T] as T;
}

class _Router extends ApplicationRouter {
  _Router({required super.locator});

  @override
  RouteFactory get routerFactory =>
      (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SizedBox.shrink(),
      );
}

class _WebSocketManager implements WebSocketManager {
  final events = StreamController<WsMessage>.broadcast();
  final deleted = <String?>[];

  @override
  final reauthorizationRequired = ObservableValue<Set<TwitchEventType>>(
    current: const {},
  );

  @override
  Stream<WsMessage> get messages => events.stream;

  @override
  void removeChatMessage(String? messageId) => deleted.add(messageId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Executor implements RewardExecutor {
  final calls =
      <
        ({
          Reward reward,
          String? userInput,
          String requester,
          String? requesterId,
          String? requesterLogin,
        })
      >[];
  Future<void> Function(Reward)? run;

  @override
  Future<void> execute(
    Reward reward, {
    String? userInput,
    String requester = '',
    String? requesterId,
    String? requesterLogin,
    int? rewardCost,
    RewardExecution? execution,
  }) async {
    calls.add((
      reward: reward,
      userInput: userInput,
      requester: requester,
      requesterId: requesterId,
      requesterLogin: requesterLogin,
    ));
    await run?.call(reward);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Connection implements YoutubeConnectionController {
  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
