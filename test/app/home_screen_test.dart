import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/app/app_router.dart';
import 'package:twitch_listener/app/home_screen.dart';
import 'package:twitch_listener/audio/audioplayer.dart';
import 'package:twitch_listener/core/autosaver.dart';
import 'package:twitch_listener/core/observable_value.dart';
import 'package:twitch_listener/core/settings.dart';
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/youtube_connection_controller.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/obs/obs_state.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/rewards/reward_configurator.dart';
import 'package:twitch_listener/rewards/reward_executor.dart';
import 'package:twitch_listener/rewards/rewards_state.dart';
import 'package:twitch_listener/twitch/redemption_queue_controller.dart';
import 'package:twitch_listener/twitch/redemption_queue_panel.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';
import 'package:twitch_listener/twitch/twitch_shared.dart';
import 'package:twitch_listener/twitch/twitch_state.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';
import 'package:twitch_listener/ui/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/ui/themes.dart';
import 'package:twitch_listener/updates/update_controller.dart';
import 'package:twitch_listener/updates/update_notice.dart';

import '../twitch/rewards_fakes.dart';

void main() {
  late _Settings settings;
  late TwitchShared shared;
  late TwitchRewardsController rewards;
  late RedemptionQueueController redemptions;
  late UpdateController updates;
  late _ObsConnect obs;
  late _Locator locator;

  setUp(() {
    settings = _Settings()..twitchAuth = null;
    shared = TwitchShared();
    final autosaver = Autosaver(delay: Duration.zero);
    final executor = _Executor();
    rewards = TwitchRewardsController(
      settings: settings,
      shared: shared,
      autosaver: autosaver,
      createApi: (_) => RewardTestApi(),
      authorize: () async => null,
    );
    redemptions = RedemptionQueueController(
      settings: settings,
      rewards: rewards,
      executor: executor,
      createApi: (_) => RewardTestApi(),
      startTimer: false,
    );
    updates = UpdateController(check: () async => '9.0.0');
    obs = _ObsConnect();
    locator = _Locator({
      Settings: settings,
      TwitchShared: shared,
      Autosaver: autosaver,
      Audioplayer: Audioplayer(),
      RewardExecutor: executor,
      TwitchRewardsController: rewards,
      RedemptionQueueController: redemptions,
      UpdateController: updates,
      ObsConnect: obs,
      WebSocketManager: _WebSocketManager(),
      YoutubeConnectionController: _Connection(),
      MusicRequestManager: _Requests(),
    });
  });

  tearDown(() async {
    await redemptions.close();
    rewards.dispose();
    updates.dispose();
    obs.state.dispose();
    shared.redemptions.dispose();
    await settings.authChanges.close();
  });

  test('root route preserves its name and arguments', () {
    final router = ApplicationRouter(locator: locator);
    final arguments = Object();
    final route = router.routerFactory(
      RouteSettings(name: ApplicationRouter.routeRoot, arguments: arguments),
    )!;

    expect(route.settings.name, ApplicationRouter.routeRoot);
    expect(route.settings.arguments, same(arguments));
  });

  testWidgets('home screen renders panels and navigation returns to root', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final router = ApplicationRouter(locator: locator);
    final dropdowns = DropdownManager();
    addTearDown(dropdowns.clear);
    await tester.pumpWidget(
      MaterialApp(
        theme: Themes.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: ApplicationRouter.routeRoot,
        onGenerateRoute: router.routerFactory,
        navigatorObservers: [router],
        builder: (context, child) => Scaffold(
          body: DropdownScope(manager: dropdowns, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(TwitchStateWidget), findsOneWidget);
    expect(find.byType(ObsStateWidget), findsOneWidget);
    expect(find.byType(UpdateNotice), findsOneWidget);
    expect(find.byType(RedemptionQueuePanel), findsOneWidget);
    expect(find.byType(RewardsStateWidget), findsOneWidget);
    expect(find.text('Version 9.0.0 is available'), findsOneWidget);
    expect(ApplicationRouter.current, ApplicationRouter.routeRoot);

    final addReward = find.text('Add New Reward');
    await tester.ensureVisible(addReward);
    await tester.tap(addReward);
    await tester.pumpAndSettle();
    expect(find.byType(RewardConfiguratorWidget), findsOneWidget);

    ApplicationRouter.popToRoot(
      tester.element(find.byType(RewardConfiguratorWidget)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(RewardConfiguratorWidget), findsNothing);
    expect(ApplicationRouter.current, ApplicationRouter.routeRoot);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Locator extends ServiceLocator {
  final Map<Type, Object> dependencies;
  _Locator(this.dependencies);

  @override
  T provide<T>() => dependencies[T] as T;
}

class _Settings extends RewardTestSettings {
  @override
  Future<void> saveRewards(Rewards rewards) async {
    this.rewards = rewards;
  }
}

class _WebSocketManager implements WebSocketManager {
  @override
  WsState get currentState => WsState.idle;

  @override
  Stream<WsState> get stateShanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ObsConnect implements ObsConnect {
  @override
  final state = ObservableValue(current: ObsState.failed);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Executor implements RewardExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Connection implements YoutubeConnectionController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Requests implements MusicRequestManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
