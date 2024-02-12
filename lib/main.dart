import 'dart:async';
import 'dart:convert';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:twitch_listener/di/app_service_locator.dart';
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/obs/obs_widget.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/reward_widget.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/twitch/twitch_api.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';
import 'package:twitch_listener/twitch/twitch_login_widget.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';
import 'package:twitch_listener/twitch_connect_widget.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  final settings = Settings();
  await settings.init();

  AppServiceLocator.init(settings);

  runApp(const MyApp());

  doWhenWindowReady(() {
    const initialSize = Size(640, 640);
    appWindow.minSize = initialSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<StatefulWidget> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyApp> {

  late final Settings _settings;

  @override
  void initState() {
    _settings = ServiceLocator.get();
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
            return LoggedWidget(creds: data);
          } else {
            return Center(
              child: TwitchLoginWidget(settings: _settings),
            );
          }
        });
  }
}

class LoggedWidget extends StatefulWidget {
  final TwitchCreds creds;

  const LoggedWidget({super.key, required this.creds});

  @override
  State<StatefulWidget> createState() => LoggedState();
}

class LoggedState extends State<LoggedWidget> {
  late final TwitchApi _twitchApi;
  late final ObsConnect _obsConnect;
  late final Settings _settings;

  late final StreamSubscription _wsSubscription;

  @override
  void initState() {
    _settings = ServiceLocator.get();
    _obsConnect = ServiceLocator.get();
    _twitchApi = ServiceLocator.get();

    final wsManager = ServiceLocator.get<WebSocketManager>();
    _wsSubscription = wsManager.messages.listen(_handleWebSocketMessage);
    super.initState();
  }

  ObsWebSocket? get _obs => _obsConnect.ws;

  Future<void> _enableInput(
      {required String inputName, required bool enabled}) {
    return _obs?.inputs.setInputMute(inputName, !enabled) ?? Future.value();
  }

  @override
  void dispose() {
    _wsSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _createBody(context),
    );
  }

  Widget _createBody(BuildContext context) {
    return StreamBuilder(
        stream: _settings.rewardsStream,
        initialData: _settings.rewards,
        builder: (cntx, snapshot) {
          final rewards = snapshot.requireData;
          return Column(
            children: [
              const SizedBox(
                height: 16,
              ),
              TwitchConnectWidget(
                settings: _settings,
                api: _twitchApi,
              ),
              const SizedBox(
                height: 16,
              ),
              ObsWidget(
                settings: _settings,
                connect: _obsConnect,
              ),
              const SizedBox(
                height: 8,
              ),
              ...rewards.rewards.map((e) => RewardWidget(
                    reward: e,
                    saveHook: _saveHook,
                    onDelete: _handleDeleteClick,
                    onPlay: _applyReward,
                  )),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFF363A46),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                        onPressed: _handleCreateClick,
                        child: const Text('Create')),
                    const SizedBox(
                      width: 8,
                    ),
                    ElevatedButton(
                        onPressed: _handleSaveClick,
                        child: const Text('Save all'))
                  ],
                ),
              )
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
    final reward = _settings.rewards.rewards
        .firstWhereOrNull((element) => element.name == rewardTitle);
    if (reward != null) {
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
          await _enableInput(
              inputName: action.inputName ?? '', enabled: action.enable);
          break;
      }
    }
  }

  void _handleCreateClick() {
    setState(() {
      _settings.rewards.rewards
          .add(Reward(name: '', handlers: [], expanded: true));
    });
  }

  void _handleDeleteClick(Reward reward) {
    setState(() {
      _settings.rewards.rewards.remove(reward);
    });
  }

  void _handleWebSocketMessage(dynamic json) {
    final rewardTitle =
    json['payload']?['event']?['reward']?['title'] as String?;
    if(rewardTitle != null){
      print(rewardTitle);
      _handleReward(rewardTitle);
    }
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
      child: Image.asset(
        Assets.assetsLogo,
        width: 24,
        height: 24,
        filterQuality: FilterQuality.medium,
      ),
    ))),
    const WindowButtons()
  ]));
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