import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/core/autosaver.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/twitch/dto.dart';
import 'package:twitch_listener/twitch/reward_settings.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';
import 'package:twitch_listener/twitch/twitch_shared.dart';

import 'rewards_fakes.dart';

void main() {
  late RewardTestSettings settings;
  late RewardTestApi api;
  late TwitchShared shared;
  late TwitchRewardsController controller;
  setUp(() {
    settings = RewardTestSettings();
    api = RewardTestApi();
    shared = TwitchShared();
    controller = TwitchRewardsController(
      settings: settings,
      shared: shared,
      autosaver: Autosaver(delay: Duration.zero),
      createApi: (_) => api,
      authorize: () async => credentials(),
    );
  });
  tearDown(() async {
    controller.dispose();
    shared.redemptions.dispose();
    await settings.authChanges.close();
  });
  Matcher failure(TwitchRewardsError kind) => throwsA(
    isA<TwitchRewardsException>().having((error) => error.kind, 'kind', kind),
  );

  test(
    'old read-only authorization can select any reward but cannot write',
    () async {
      api.scopes = {'channel:read:redemptions'};
      await controller.refresh();
      expect(controller.error, isNull);
      expect(controller.isManageable('own'), isTrue);
      expect(controller.canManage, isFalse);
      expect(controller.select('other').reward.title, 'Water');
      await expectLater(
        controller.saveReward(
          const TwitchRewardSettings(title: 'New', cost: 10),
          expectedAccount: controller.accountKey,
        ),
        failure(TwitchRewardsError.authorization),
      );
      expect(api.writes, 0);
    },
  );

  test(
    'Twitch ownership, rather than local configuration, controls editing',
    () async {
      await controller.refresh();
      expect(controller.canEdit('own'), isTrue);
      expect(controller.canEdit('other'), isFalse);
      await expectLater(
        controller.saveReward(
          const TwitchRewardSettings(title: 'Water', cost: 100),
          id: 'other',
          expectedAccount: controller.accountKey,
        ),
        failure(TwitchRewardsError.forbidden),
      );
      expect(api.writes, 0);
    },
  );

  test('failed permission discovery keeps rewards selectable without granting edits', () async {
    api.load = (manageable) async {
      if (manageable) throw StateError('Unavailable');
      return api.entries;
    };
    await controller.refresh();
    expect(controller.rewards, hasLength(2));
    expect(controller.permissionError, isTrue);
    expect(controller.manageabilityKnown, isFalse);
    expect(controller.canEdit('own'), isFalse);
    expect(controller.select('other').broadcasterId, 'channel');
  });

  test('refresh renames linked entries by ID and preserves manual names and actions', () async {
    final action = RewardAction(type: RewardAction.typeDelay, millis: 100);
    addTearDown(action.dispose);
    final linked = Reward(
      name: 'Old name',
      handlers: [action],
      twitchRewardId: 'own',
      twitchBroadcasterId: 'channel',
    );
    final manual = Reward(name: 'Old name', handlers: []);
    settings.rewards.rewards.addAll([linked, manual]);
    await controller.refresh();
    expect(linked.name, 'Music');
    expect(manual.name, 'Old name');
    expect(linked.handlers.single, same(action));
    expect(shared.findReward(linked)!.id, 'own');
    api.entries = [remoteReward('replacement', 'Music')];
    await controller.refresh();
    expect(shared.findReward(linked), isNull);
    expect(linked.isLinked, isTrue);
    expect(linked.name, 'Music');
  });

  test(
    'a response for the previous account cannot replace the current rewards',
    () async {
      final response = Completer<List<RedemptionDto>>();
      api.load = (_) => response.future;
      final refresh = controller.refresh();
      await settings.saveTwitchAuth(credentials('another'));
      await Future<void>.delayed(Duration.zero);
      response.complete(api.entries);
      await refresh;
      expect(shared.redemptions.current, isEmpty);
      expect(shared.broadcasterId, isNull);
      expect(controller.canManage, isFalse);
    },
  );

  test('token refresh on the same channel preserves loaded rewards and permissions', () async {
    await controller.refresh();
    await settings.saveTwitchAuth(
      credentials().copy(accessToken: 'replacement'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(shared.redemptions.current, hasLength(2));
    expect(controller.canEdit('own'), isTrue);
  });

  test('an older refresh cannot overwrite a successful edit', () async {
    final local = Reward(
      name: 'Music',
      handlers: [],
      twitchRewardId: 'own',
      twitchBroadcasterId: 'channel',
    );
    settings.rewards.rewards.add(local);
    await controller.refresh();
    final response = Completer<List<RedemptionDto>>();
    api.load = (manageable) =>
        manageable ? Future.value(api.entries) : response.future;
    final refresh = controller.refresh();
    await controller.saveReward(
      const TwitchRewardSettings(title: 'Renamed', cost: 500),
      id: 'own',
      expectedAccount: controller.accountKey,
    );
    response.complete(api.entries);
    await refresh;
    expect(local.name, 'Renamed');
    expect(shared.findReward(local)!.title, 'Renamed');
  });

  test(
    'creation returns a manageable reward without touching local actions',
    () async {
      await controller.refresh();
      final created = await controller.saveReward(
        const TwitchRewardSettings(title: 'New reward', cost: 100),
        expectedAccount: controller.accountKey,
      );
      expect(created.id, 'created');
      expect(controller.canEdit(created.id), isTrue);
      expect(controller.select(created.id).broadcasterId, 'channel');
      expect(settings.rewards.rewards, isEmpty);
    },
  );

  test(
    'failed saves retain local data and revoked access disables further edits',
    () async {
      await controller.refresh();
      api.save = (id, value) async => throw DioException(
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 401),
      );
      await expectLater(
        controller.saveReward(
          const TwitchRewardSettings(title: 'New', cost: 100),
          id: 'own',
          expectedAccount: controller.accountKey,
        ),
        failure(TwitchRewardsError.authorization),
      );
      expect(controller.rewards.first.title, 'Music');
      expect(controller.canManage, isFalse);
      expect(controller.saving, isFalse);
    },
  );

  test('account changes invalidate a form before a request is sent', () async {
    await controller.refresh();
    final previous = controller.accountKey;
    await settings.saveTwitchAuth(credentials('another'));
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      controller.saveReward(
        const TwitchRewardSettings(title: 'New', cost: 1),
        expectedAccount: previous,
      ),
      failure(TwitchRewardsError.accountChanged),
    );
    expect(api.writes, 0);
  });
}
