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
import 'package:twitch_listener/reward_executor.dart';
import 'package:twitch_listener/ripple_icon.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/simple_widgets.dart';
import 'package:twitch_listener/themes.dart';
import 'package:twitch_listener/twitch/ws_event.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';

void main() async {
  final soloud = SoLoud.instance;
  await soloud.init();

  final settings = Settings();
  await settings.init();
  await settings.makeRequiredMigrations();

  final locator = AppServiceLocator.init(
      settings: settings, audioplayer: Audioplayer(soloud: soloud));

  final router = ApplicationRouter(locator: locator);

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
  late final WebSocketManager _webSocketManager;
  late final ApplicationRouter _router;
  late final Settings _settings;
  late final RewardExecutor _executor;

  late final StreamSubscription<WsMessage> _wsSubscription;

  @override
  void initState() {
    _router = widget.router;
    _settings = widget.locator.provide();
    _webSocketManager = widget.locator.provide();
    _executor = widget.locator.provide();
    _wsSubscription =
        _webSocketManager.messages.listen(_handleWebSocketMessage);
    super.initState();
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

  void _handleReward(String rewardTitle) {
    final rewards = _settings.rewards.rewards
        .where((element) => element.name == rewardTitle);

    for (var reward in rewards) {
      _executor.execute(reward);
    }
  }

  @override
  void dispose() {
    _wsSubscription.cancel();
    super.dispose();
  }

  final _dropdownManager =
      DropdownManager(offset: const Offset(0, -_toolbarHeight));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: _settings.appearanceChanges,
        initialData: _settings.appearance,
        builder: (context, snapshot) {
          final appearance = snapshot.requireData;

          final ThemeMode themeMode;
          switch (appearance.brightness) {
            case AppBrightness.system:
              themeMode = ThemeMode.system;
              break;

            case AppBrightness.dark:
              themeMode = ThemeMode.dark;
              break;

            case AppBrightness.light:
              themeMode = ThemeMode.light;
              break;
          }

          return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: Themes.light,
              darkTheme: Themes.dark,
              themeMode: themeMode,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: DropdownScope(
                  manager: _dropdownManager,
                  child: Builder(builder: (context) {
                    final theme = Theme.of(context);
                    return Scaffold(
                        backgroundColor: theme.surfacePrimary,
                        body: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => DropdownScope.of(context).clear(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  child: _createWindowTitleBarBox(
                                      context, theme,
                                      appearance: appearance)),
                              SimpleDivider(theme: theme),
                              Expanded(
                                  child: Navigator(
                                observers: [
                                  _router,
                                  DropdownNavigationObserver(
                                      manager: _dropdownManager)
                                ],
                                onGenerateRoute: _router.routerFactory,
                                initialRoute: ApplicationRouter.routeRoot,
                              ))
                            ],
                          ),
                        ));
                  })));
        });
  }

  static const _toolbarHeight = 40.0;

  Widget _createWindowTitleBarBox(BuildContext context, ThemeData theme,
      {required Appearance appearance}) {
    final String brigthessIcon;
    switch (appearance.brightness) {
      case AppBrightness.system:
        brigthessIcon = Assets.assetsIcSunMoonWhite16dp;
        break;
      case AppBrightness.dark:
        brigthessIcon = Assets.assetsIcMoonWhite16dp;
        break;
      case AppBrightness.light:
        brigthessIcon = Assets.assetsIcSunWhite16dp;
        break;
    }
    return Container(
        color: theme.surfaceSecondary,
        height: _toolbarHeight,
        child: Row(children: [
          Expanded(
              child: MoveWindow(
                  child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Tooltip(
                  message: 'It\'s dealnoteDev',
                  child: SimpleIcon.simpleSquare(Assets.assetsIcLogo20dp,
                      size: 20),
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
            size: 16,
            icon: brigthessIcon,
            borderRadius: BorderRadius.circular(8),
            color: theme.textColorPrimary,
            onTap: () {
              _settings.toggleBrightness(appearance.brightness);
            },
          ),
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
}
