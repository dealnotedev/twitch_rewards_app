import 'dart:async';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/app_router.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/di/app_service_locator.dart';
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/obs/obs_widget.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_executor.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/ripple_icon.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/simple_widgets.dart';
import 'package:twitch_listener/themes.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';
import 'package:twitch_listener/twitch/twitch_login_widget.dart';
import 'package:twitch_listener/twitch/ws_event.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';
import 'package:twitch_listener/twitch_connect_widget.dart';

void main() async {
  final soloud = SoLoud.instance;
  await soloud.init();

  final settings = Settings();
  await settings.init();

  final locator = AppServiceLocator.init(
      settings: settings, audioplayer: Audioplayer(soloud: soloud));

  final dropdownManager = DropdownManager();

  final router =
      ApplicationRouter(locator: locator, dropdownManager: dropdownManager);

  runApp(MyApp(
    locator: locator,
    router: router,
  ));

  doWhenWindowReady(() {
    const initialSize = Size(640, 720);
    appWindow.minSize = initialSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });

  AppLifecycleListener(
      binding: WidgetsBinding.instance,
      onExitRequested: () async {
        soloud.deinit();
        return AppExitResponse.exit;
      });
}

class MyApp extends StatefulWidget {
  final ServiceLocator locator;
  final ApplicationRouter router;

  const MyApp({super.key, required this.locator, required this.router});

  @override
  State<StatefulWidget> createState() => _RebornPageState();
}

class _RebornPageState extends State<MyApp> {
  late final Settings _settings;
  late final RewardExecutor _executor;
  late final ApplicationRouter _router;

  final _dropdownmanager = DropdownManager();

  @override
  void initState() {
    _settings = widget.locator.provide();
    _executor = widget.locator.provide();
    _router = widget.router;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Themes.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        navigatorObservers: [_router],
        home: DropdownScope(
            manager: _dropdownmanager,
            child: Builder(builder: (context) {
              final theme = Theme.of(context);
              return Scaffold(
                  backgroundColor: theme.surfacePrimary,
                  body: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _dropdownmanager.clear(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(child: _createWindowTitleBarBox(context)),
                        SimpleDivider(theme: theme),
                        Expanded(
                            child: Navigator(
                          onGenerateRoute: _router.routerFactory,
                          initialRoute: ApplicationRouter.routeRoot,
                        ))
                      ],
                    ),
                  ));
            })));
  }
}

class _MyHomePageState extends State<MyApp> {
  late final Settings _settings;

  @override
  void initState() {
    _settings = widget.locator.provide();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF404450),
        body: Column(
          children: [
            Container(
                color: const Color(0xFF363A46),
                child: _createWindowTitleBarBox(context)),
            Expanded(child: _createRoot(context))
          ],
        ),
      ),
    );
  }

  Widget _createRoot(BuildContext context) {
    return StreamBuilder(
        stream: _settings.twitchAuthChanges,
        initialData: _settings.twitchAuth,
        builder: (cntx, snapshot) {
          final data = snapshot.data;
          if (data != null) {
            return LoggedWidget(creds: data, locator: widget.locator);
          } else {
            return Center(
              child: TwitchLoginWidget(settings: _settings),
            );
          }
        });
  }
}

class LoggedWidget extends StatefulWidget {
  final ServiceLocator locator;
  final TwitchCreds creds;

  const LoggedWidget({super.key, required this.creds, required this.locator});

  @override
  State<StatefulWidget> createState() => LoggedState();
}

class LoggedState extends State<LoggedWidget> {
  late final ObsConnect _obs;
  late final Settings _settings;
  late final WebSocketManager _wsManager;
  late final Audioplayer _audioplayer;
  late final RewardExecutor _executor;

  late final StreamSubscription<WsMessage> _wsSubscription;

  final _searchController = TextEditingController();

  @override
  void initState() {
    _settings = widget.locator.provide();
    _obs = widget.locator.provide();
    _wsManager = widget.locator.provide();
    _audioplayer = widget.locator.provide();
    _executor = widget.locator.provide();

    _wsSubscription = _wsManager.messages.listen(_handleWebSocketMessage);
    _searchController.addListener(_handleSearchQuery);
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _wsSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: _createBody(context),
        )),
        Divider(
          height: 1,
          thickness: 1,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF363A46),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                  onPressed: _handleCreateClick, child: const Text('Create')),
              const Gap(8),
              ElevatedButton(
                  onPressed: _handleSaveClick, child: const Text('Save all'))
            ],
          ),
        )
      ],
    );
  }

  Widget _createBody(BuildContext context) {
    return StreamBuilder(
        stream: _settings.rewardsStream,
        initialData: _settings.rewards,
        builder: (cntx, snapshot) {
          final rewards = snapshot.requireData;
          final q = _searchController.text.toLowerCase().trim();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(16),
              TwitchConnectWidget(
                webSocketManager: _wsManager,
                settings: _settings,
              ),
              const Gap(16),
              ObsWidget(
                settings: _settings,
                connect: _obs,
              ),
              const Gap(16),
              Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: TextField(
                  maxLines: 1,
                  controller: _searchController,
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                  decoration: const DefaultInputDecoration(
                      hintText: 'Type to search...'),
                ),
              ),
              const Gap(8),
              ...rewards.rewards
                  .where((r) => q.isEmpty || r.name.toLowerCase().contains(q))
                  .map((e) => RewardWidget(
                        key: Key(e.id),
                        reward: e,
                        audioplayer: _audioplayer,
                        saveHook: _saveHook,
                        onDelete: _handleDeleteClick,
                        onPlay: _applyReward,
                      ))
            ],
          );
        });
  }

  final _saveHook = SaveHook();

  void _handleSaveClick() {
    _saveHook.save();
    _settings.saveRewards(_settings.rewards);
  }

  void _handleReward(String rewardTitle) {
    final rewards = _settings.rewards.rewards
        .where((element) => element.name == rewardTitle);

    for (var reward in rewards) {
      _applyReward(reward);
    }
  }

  void _handleCreateClick() {
    setState(() {
      _settings.rewards.rewards
          .insert(0, Reward(name: '', handlers: [], expanded: true));
    });
  }

  void _handleDeleteClick(Reward reward) {
    setState(() {
      _settings.rewards.rewards.remove(reward);
    });
  }

  static final _handledMessages = <String>{};

  void _handleWebSocketMessage(WsMessage json) {
    final eventId = json.payload.event?.id;
    final rewardTitle = json.payload.event?.reward?.title;

    if (rewardTitle != null &&
        eventId != null &&
        _handledMessages.add(eventId)) {
      _handleReward(rewardTitle);
    }
  }

  void _handleSearchQuery() {
    setState(() {});
  }

  void _applyReward(Reward reward) {
    _executor.execute(reward);
  }
}

enum Voice { normal, helium, brutal, robo }

Widget _createWindowTitleBarBox(BuildContext context) {
  final theme = Theme.of(context);
  return Container(
      color: theme.surfaceSecondary,
      height: 40,
      child: Row(children: [
        Expanded(
            child: MoveWindow(
                child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Tooltip(
                message: 'It\'s dealnoteDev',
                child:
                    SimpleIcon.simpleSquare(Assets.assetsIcLogo20dp, size: 20),
              ),
              const Gap(12),
              Expanded(
                  child: Text(
                context.localizations.app_title,
                style: TextStyle(
                    color: theme.textColorPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              )),
            ],
          ),
        ))),
        RippleIcon(
          borderRadius: BorderRadius.circular(8),
          icon: Assets.assetsIcMinimizeWhite16dp,
          size: 16,
          color: theme.textColorPrimary,
          onTap: () {
            appWindow.minimize();
          },
        ),
        RippleIcon(
          borderRadius: BorderRadius.circular(8),
          icon: Assets.assetsIcMaximizeWhite16dp,
          size: 16,
          color: theme.textColorPrimary,
          onTap: () {
            appWindow.maximizeOrRestore();
          },
        ),
        RippleIcon(
          borderRadius: BorderRadius.circular(8),
          icon: Assets.assetsIcCloseWhite16dp,
          hoverColor: const Color(0xFFD4183D),
          size: 16,
          color: theme.textColorPrimary,
          onTap: () {
            appWindow.close();
          },
        ),
        const Gap(8)
      ]));
}
