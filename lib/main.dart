import 'dart:async';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:media_kit/media_kit.dart';
import 'package:twitch_listener/app_router.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/autosaver.dart';
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
  WidgetsFlutterBinding.ensureInitialized();

  MediaKit.ensureInitialized();

  final settings = Settings();
  await settings.init();
  await settings.makeRequiredMigrations();

  final locator =
      AppServiceLocator.init(settings: settings, audioplayer: Audioplayer());

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
        return AppExitResponse.exit;
      });
}

class MyApp extends StatefulWidget {
  final ServiceLocator locator;
  final ApplicationRouter router;

  const MyApp({super.key, required this.locator, required this.router});

  Autosaver get autosaver => locator.provide();

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

    widget.autosaver.registerSaveCallback(_handleAutosaving);
    super.initState();
  }

  @override
  void dispose() {
    widget.autosaver.unregisterSaveCallback(_handleAutosaving);
    _wsSubscription.cancel();
    super.dispose();
  }

  bool _autosaved = false;

  Future<void> _handleAutosaving() async {
    setState(() {
      _autosaved = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _autosaved = false;
    });
  }

  static final _handledMessages = <String>{};

  final _chatMessages = <WsMessage>[];

  void _handleWebSocketMessage(WsMessage json) {
    final chatMessageId = json.payload.event?.messageId;
    final chatterId = json.payload.event?.chatterUserId;

    if (json.payload.event?.message?.text == '!удолі' && chatterId != null) {
      final previous = _chatMessages
          .lastWhereOrNull((m) => m.payload.event?.chatterUserId == chatterId);

      if (previous != null) {
        _chatMessages.remove(previous);
        _webSocketManager.removeChatMessage(previous.payload.event?.messageId);
      }

      _webSocketManager.removeChatMessage(chatMessageId);
      return;
    }

    if (json.payload.subscription?.type == 'channel.chat.message' &&
        chatMessageId != null &&
        chatterId != null) {
      _chatMessages.add(json);
    }

    final eventId = json.payload.event?.id;
    final rewardTitle = json.payload.event?.reward?.title;
    final userInput = json.payload.event?.userInput;

    if (rewardTitle != null &&
        eventId != null &&
        _handledMessages.add(eventId)) {
      _handleReward(rewardTitle, userInput: userInput);
    }
  }

  void _handleReward(String rewardTitle, {required String? userInput}) {
    final rewards = _settings.rewards.rewards
        .where((element) => element.name == rewardTitle);

    for (var reward in rewards) {
      _executor.execute(reward, userInput: userInput);
    }
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
          AnimatedOpacity(
              opacity: _autosaved ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: RippleIcon(
                size: 16,
                icon: Assets.assetsIcSaveWhite16dp,
                borderRadius: BorderRadius.circular(8),
                color: theme.textColorPrimary,
              )),
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

  @override
  void didUpdateWidget(covariant MyApp oldWidget) {
    if (widget.autosaver != oldWidget.autosaver) {
      oldWidget.autosaver.unregisterSaveCallback(_handleAutosaving);
      widget.autosaver.registerSaveCallback(_handleAutosaving);
    }
    super.didUpdateWidget(oldWidget);
  }
}
