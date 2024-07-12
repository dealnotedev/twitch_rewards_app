import 'dart:async';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/audio/ringtone.dart';
import 'package:twitch_listener/di/app_service_locator.dart';
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/input_sender.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/obs/obs_widget.dart';
import 'package:twitch_listener/process_finder.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/themes.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';
import 'package:twitch_listener/twitch/twitch_login_widget.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';
import 'package:twitch_listener/twitch_connect_widget.dart';
import 'package:win32/win32.dart' as win32;

void main() async {
  final settings = Settings();
  await settings.init();

  final locator = AppServiceLocator.init(settings);

  runApp(MyApp(locator: locator));

  doWhenWindowReady(() {
    const initialSize = Size(640, 720);
    appWindow.minSize = initialSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}

class MyApp extends StatefulWidget {
  final ServiceLocator locator;

  const MyApp({super.key, required this.locator});

  @override
  State<StatefulWidget> createState() => _MyHomePageState();
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

  late final StreamSubscription _wsSubscription;

  final _searchController = TextEditingController();

  @override
  void initState() {
    _settings = widget.locator.provide();
    _obs = widget.locator.provide();
    _wsManager = widget.locator.provide();

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
          color: Colors.white.withOpacity(0.1),
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
                  .where((r) =>
                      q.isEmpty ||
                      (r.name.toLowerCase().contains(q)) ||
                      r.groups.toLowerCase().contains(q))
                  .map((e) => RewardWidget(
                        key: Key(e.id),
                        reward: e,
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

  final _activeRewards = <_RewardEvent>{};

  void _applyReward(Reward reward) async {
    final groups = reward.groups.split(',').where((g) => g.isNotEmpty).toSet();

    _activeRewards.where((r) => r.constainsGroup(groups)).forEach((r) {
      debugPrint('${r.reward.name} will be interruped');
      r.interrupted = true;
    });

    final event = _RewardEvent(
        reward: reward,
        groups: reward.groups.split(',').where((g) => g.isNotEmpty).toSet());
    _activeRewards.add(event);

    for (var action in reward.handlers) {
      if (event.interrupted) break;

      try {
        await _executeAction(action);
      } catch (_) {}
    }

    _activeRewards.remove(event);
  }

  Future<void> _executeAction(RewardAction action) async {
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
          await _obs.toggleSource(sceneName: sceneName, sourceName: sourceName);
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
          RingtoneUtils.playFile(filePath);
        }
        break;
    }
  }

  void _handleCreateClick() {
    setState(() {
      _settings.rewards.rewards.insert(
          0, Reward(name: '', handlers: [], expanded: true, groups: ''));
    });
  }

  void _handleDeleteClick(Reward reward) {
    setState(() {
      _settings.rewards.rewards.remove(reward);
    });
  }

  static final _handledMessages = <String>{};

  void _handleWebSocketMessage(dynamic json) {
    final eventId = json['payload']?['event']?['id'] as String?;
    final rewardTitle =
        json['payload']?['event']?['reward']?['title'] as String?;

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

WindowTitleBarBox _createWindowTitleBarBox(BuildContext context) {
  return WindowTitleBarBox(
      child: Row(children: [
    Expanded(
        child: MoveWindow(
            child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Tooltip(
        message: 'It\'s dealnoteDev',
        child: Image.asset(
          Assets.assetsLogo,
          width: 24,
          height: 24,
          filterQuality: FilterQuality.medium,
        ),
      ),
    ))),
    const WindowButtons()
  ]));
}

class _RewardEvent {
  final Reward reward;
  final Set<String> groups;

  bool interrupted = false;

  _RewardEvent({required this.reward, required this.groups});

  bool constainsGroup(Iterable<String> groups) {
    for (String g in groups) {
      if (this.groups.contains(g)) {
        return true;
      }
    }
    return false;
  }
}

class WindowButtons extends StatelessWidget {
  static final buttonColors = WindowButtonColors(
      iconNormal: const Color(0xFF737A8B),
      mouseOver: const Color(0xFFF6A00C),
      mouseDown: const Color(0xFF805306),
      iconMouseOver: const Color(0xFF805306),
      iconMouseDown: const Color(0xFFFFD500));

  static final closeButtonColors = WindowButtonColors(
      mouseOver: const Color(0xFFD32F2F),
      mouseDown: const Color(0xFFB71C1C),
      iconNormal: const Color(0xFF737A8B),
      iconMouseOver: Colors.white);

  const WindowButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(colors: closeButtonColors),
      ],
    );
  }
}
