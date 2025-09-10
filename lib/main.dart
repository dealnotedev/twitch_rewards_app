import 'dart:async';
import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/connection_status.dart';
import 'package:twitch_listener/di/app_service_locator.dart';
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/input_sender.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/obs/obs_state.dart';
import 'package:twitch_listener/obs/obs_widget.dart';
import 'package:twitch_listener/process_finder.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_config.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/rewards_state.dart';
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
import 'package:twitch_listener/twitch_state.dart';
import 'package:twitch_listener/viewers_counter.dart';
import 'package:win32/win32.dart' as win32;

void main() async {
  final soloud = SoLoud.instance;
  await soloud.init();

  final settings = Settings();
  await settings.init();

  final locator = AppServiceLocator.init(
      settings: settings, audioplayer: Audioplayer(soloud: soloud));

  runApp(MyApp(locator: locator));

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

  const MyApp({super.key, required this.locator});

  @override
  State<StatefulWidget> createState() => _RebornPageState();
}

class _RebornPageState extends State<MyApp> {
  final _dropdownmanager = DropdownManager();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: Themes.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        navigatorObservers: [
          DropdownNavigationObserver(manager: _dropdownmanager)
        ],
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
                            child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Gap(16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Gap(16),
                                  Expanded(
                                    child: TwitchStateWidget(
                                        twitchShared: widget.locator.provide(),
                                        webSocketManager:
                                            widget.locator.provide(),
                                        settings: widget.locator.provide()),
                                  ),
                                  const Gap(16),
                                  Expanded(
                                    child: ObsStateWidget(
                                        connect: widget.locator.provide(),
                                        settings: widget.locator.provide()),
                                  ),
                                  const Gap(16),
                                ],
                              ),
                              const Gap(16),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: RewardsStateWidget(
                                  audioplayer: widget.locator.provide(),
                                  settings: _settings,
                                  twitchShared: widget.locator.provide(),
                                ),
                              ),
                              const Gap(312),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  spacing: 8,
                                  children: [
                                    Expanded(
                                      child: _createDropDown(context, theme,
                                          key: _globalKey),
                                    ),
                                    Expanded(
                                        child: _createDropDown(context, theme,
                                            key: _globalKey2)),
                                    Expanded(
                                        child: _createDropDown(context, theme,
                                            key: _globalKey3))
                                  ],
                                ),
                              ),
                              const Gap(612),
                            ],
                          ),
                        ))
                      ],
                    ),
                  ));
            })));
  }

  final _globalKey = GlobalKey();
  final _globalKey2 = GlobalKey();
  final _globalKey3 = GlobalKey();

  late final Settings _settings;

  @override
  void initState() {
    _settings = widget.locator.provide();
    super.initState();
  }

  Widget _createDropDown(BuildContext context, ThemeData theme,
      {required GlobalKey key}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConnectionStatusWidget(
                theme: theme, status: ConnectionStatus.connected),
            const Gap(4),
            ViewersCounter(theme: theme, count: 12),
          ],
        ),
        const Gap(4),
        CustomButton(
          text: context.localizations.button_connect,
          style: CustomButtonStyle.primary,
          theme: theme,
          onTap: () {},
        ),
        const Gap(4),
        Text(
          'Wait for Completion',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: theme.textColorPrimary),
        ),
        const Gap(4),
        Material(
          borderRadius: BorderRadius.circular(8),
          color: theme.inputBackground,
          child: InkWell(
            onTap: () {
              _showDropdownPopup(context, key: key);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              key: key,
              decoration: BoxDecoration(
                border: Border.all(color: theme.border, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                      child: Text(
                    'Yes',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: theme.textColorPrimary),
                  )),
                  SimpleIcon.simpleSquare(Assets.assetsIcArrowDownWhite12dp,
                      size: 12, color: theme.textColorDisabled)
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  void _showDropdownPopup(BuildContext context,
      {required GlobalKey key}) async {
    if (key != _globalKey3) {
      final manager = DropdownScope.of(context);
      showDialog(
          routeSettings: const RouteSettings(name: '/channel_points_setting'),
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.5),
          context: context,
          builder: (context) {
            final theme = Theme.of(context);
            return Dialog(
              insetPadding: const EdgeInsets.all(48),
              backgroundColor: theme.surfacePrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: RewardConfigWidget(dropdownManager: manager),
            );
          });
      return;
    }

    final manager = DropdownScope.of(context);
    manager.show(context, builder: (cntx) {
      return DropdownPopupMenu<bool>(
        selected: true,
        items: [
          Item(id: true, title: context.localizations.yes),
          Item(id: false, title: context.localizations.no)
        ],
        onTap: (bool id) {
          manager.dismiss(key);
        },
      );
    }, key: key);
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

  late final StreamSubscription<WsMessage> _wsSubscription;

  final _searchController = TextEditingController();

  @override
  void initState() {
    _settings = widget.locator.provide();
    _obs = widget.locator.provide();
    _wsManager = widget.locator.provide();
    _audioplayer = widget.locator.provide();

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

  void _applyReward(Reward reward) async {
    for (var action in reward.handlers) {
      switch (action.type) {
        case RewardAction.typeDelay:
          await Future.delayed(Duration(seconds: action.duration));
          break;

        case RewardAction.typeEnableInput:
          await _obs.enableInput(
              inputName: action.inputName ?? '', enabled: action.enable);
          break;

        case RewardAction.typeEnableFilter:
          final sourceName = action.sourceName;
          final filterName = action.filterName;

          if (sourceName != null &&
              sourceName.isNotEmpty &&
              filterName != null &&
              filterName.isNotEmpty) {
            await _obs.enableSourceFilter(
                sourceName: sourceName,
                filterName: filterName,
                enabled: action.enable);
          }
          break;

        case RewardAction.typeFlipSource:
          final sourceName = action.sourceName;
          final sceneName = action.sceneName;

          if (sourceName != null &&
              sourceName.isNotEmpty &&
              sceneName != null &&
              sceneName.isNotEmpty) {
            await _obs.flipSource(
                rootSceneName: sceneName,
                sourceName: sourceName,
                horizontal: action.horizontal,
                vertical: action.vertical);
          }
          break;

        case RewardAction.typeInvertFilter:
          final sourceName = action.sourceName;
          final filterName = action.filterName;

          if (sourceName != null &&
              sourceName.isNotEmpty &&
              filterName != null &&
              filterName.isNotEmpty) {
            await _obs.invertSourceFilter(
                sourceName: sourceName, filterName: filterName);
          }
          break;

        case RewardAction.typeSetScene:
          final sceneNames = action.targets;
          if (sceneNames.isNotEmpty) {
            await _obs.enableScene(sceneNames: sceneNames);
          }
          break;

        case RewardAction.typeCrashProcess:
          final target = action.target;
          if (target != null) {
            compute(_crashProcess, target);
          }
          break;

        case RewardAction.typeToggleSource:
          final sourceName = action.sourceName;
          final sceneName = action.sceneName;

          if (sourceName != null &&
              sourceName.isNotEmpty &&
              sceneName != null &&
              sceneName.isNotEmpty) {
            await _obs.toggleSource(
                sceneName: sceneName, sourceName: sourceName);
          }
          break;

        case RewardAction.typeSendInput:
          final inputs = action.inputs;
          if (inputs.isNotEmpty) {
            InputSender.sendInputs(inputs);
          }
          break;

        case RewardAction.typeEnableSource:
          final sourceName = action.sourceName;
          final sceneName = action.sceneName;

          if (sourceName != null &&
              sourceName.isNotEmpty &&
              sceneName != null &&
              sceneName.isNotEmpty) {
            await _obs.enableSource(
                sceneName: sceneName,
                sourceName: sourceName,
                enabled: action.enable);
          }
          break;

        case RewardAction.typePlayAudio:
          final filePath = action.filePath;

          if (filePath != null && filePath.isNotEmpty) {
            _audioplayer.playFileWaitCompletion(filePath,
                volume: action.volume);
          }
          break;

        case RewardAction.typePlayAudios:
          if (action.awaitCompletion) {
            await _playAudios(action);
          } else {
            _playAudios(action);
          }
          break;
      }
    }
  }

  Future<void> _playAudios(RewardAction action) async {
    final all = List.of(action.audios);
    final count = action.count;

    if (all.isEmpty) return;

    final List<AudioEntry> audios;

    if (action.randomize) {
      all.shuffle();

      if (count != null) {
        audios = all.take(count).toList();
      } else {
        audios = all;
      }
    } else {
      audios = all;
    }

    for (int i = 0; i < audios.length; i++) {
      final file = audios[i];

      if (i > 0) {
        await Future.delayed(const Duration(milliseconds: 250));
      }
      await _audioplayer.playFileWaitCompletion(file.path, volume: file.volume);
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

  static void _crashProcess(String processName) {
    ProcessFinder.initialize();

    final processId = ProcessFinder.listRunningProcesses()
        .where((element) {
          return element.name.trim() == processName;
        })
        .firstOrNull
        ?.processId;

    if (processId != null) {
      final handle = win32.OpenProcess(
          win32.PROCESS_ACCESS_RIGHTS.PROCESS_TERMINATE, 0, processId);

      win32.TerminateProcess(handle, 0);
      win32.CloseHandle(handle);
    }

    ProcessFinder.uninitialize();
  }

  void _handleSearchQuery() {
    setState(() {});
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
