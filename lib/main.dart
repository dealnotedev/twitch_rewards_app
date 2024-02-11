import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/secrets.dart';
import 'package:twitch_listener/twitch/settings.dart';
import 'package:twitch_listener/twitch/twitch_api.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';
import 'package:twitch_listener/twitch/twitch_login_widget.dart';
import 'package:video_player/video_player.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'audio/ringtone.dart';

void main() async {
  await Settings.instance.init();

  runApp(const MyApp());

  doWhenWindowReady(() {
    const initialSize = Size(640, 360);
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
  final _settings = Settings.instance;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: Colors.green,
        body: _createRoot(context),
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
            return VideoPlayWidget(creds: data);
          } else {
            return const Center(
              child: TwitchLoginWidget(),
            );
          }
        });
  }
}

class _Media {
  final VideoPlayerController controller;
  final File file;

  _Media({required this.controller, required this.file});
}

class VideoPlayWidget extends StatefulWidget {
  final TwitchCreds creds;

  const VideoPlayWidget({super.key, required this.creds});

  @override
  State<StatefulWidget> createState() => VideoPlayState();
}

class VideoPlayState extends State<VideoPlayWidget> {
  @override
  void initState() {
    final settings = Settings.instance;
    final twitchApi = TwitchApi(
        settings: Settings.instance, clientSecret: twitchClientSecret);

    _subsReward(settings, twitchApi);
    _prepareObs();
    super.initState();
  }

  ObsWebSocket? _obs;

  Future<void> _prepareObs() async {
    final obs = _obs = await ObsWebSocket.connect('ws://127.0.0.1:4455',
        password: 'w7yiuBi2JF70EAZ2');
    await obs.stream.status;

    _mirrorScene(false);
    _enableVoiceInputs(Voice.normal);
  }

  Future<void> _mirrorScene(bool mirrored) async {
    final items = await _obs?.sceneItems.list('Scene');
    final game =
        items?.firstWhere((element) => element.sourceName == 'Game Capture');

    _obs?.sendRequest(Request(
      'SetSceneItemTransform',
      requestData: {
        'sceneName': 'Scene',
        'sceneItemId': game?.sceneItemId,
        'sceneItemTransform': {
          'width': mirrored ? -1920 : 1920,
          'height': 1080,
          'scaleY': 0.5,
          'scaleX': mirrored ? -0.5 : 0.5,
          'positionY': 0,
          'positionX': mirrored ? 1920 : 0
        }
      },
    ));
  }

  bool _blackWhite = false;
  bool _mirror = false;

  Future<void> _toggleBlackWhite() async {
    _blackWhite = !_blackWhite;

    await _obs?.filters.setSourceFilterEnabled(
        sourceName: 'Game Capture',
        filterName: 'BlackWhite',
        filterEnabled: _blackWhite);
  }

  Future<void> _enableVoiceInputs(Voice voice) async {
    await _obs?.inputs
        .setInputMute('Mic/Aux', voice != Voice.normal && voice != Voice.robo);
    await _obs?.inputs
        .setInputMute('Helium', voice != Voice.helium && voice != Voice.robo);
    await _obs?.inputs
        .setInputMute('Brutal', voice != Voice.brutal && voice != Voice.robo);
  }

  Future<void> _toggleNarkomania() async {
    await _obs?.filters.setSourceFilterEnabled(
        sourceName: 'Game Capture',
        filterName: 'Narkomania',
        filterEnabled: true);

    await Future.delayed(const Duration(seconds: 20));

    await _obs?.filters.setSourceFilterEnabled(
        sourceName: 'Game Capture',
        filterName: 'Narkomania',
        filterEnabled: false);
  }

  Future<void> _subsReward(Settings settings, TwitchApi api) async {
    final sessionId = await _connectToEventSub();

    try {
      await api.subscribeCustomRewards(
          broadcasterUserId: settings.twitchAuth?.broadcasterId,
          sessionId: sessionId);
    } on DioException catch (e) {
      print(e.response?.data);
    }
  }

  Future<String> _connectToEventSub() async {
    final channel = WebSocketChannel.connect(Uri.parse(
        'wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30'));
    await channel.ready;

    final completer = Completer<String>();

    channel.stream.listen((event) {
      final json = jsonDecode(event);
      print(event);

      final sessionId = json['payload']?['session']?['id'] as String?;
      if (sessionId != null) {
        completer.complete(sessionId);
      }

      final rewardTitle =
          json['payload']?['event']?['reward']?['title'] as String?;
      switch (rewardTitle) {
        case 'Та ти шо':
          RingtoneUtils.play(Assets.assetsVideoplayback);
          break;

        case 'Робо':
          _handleVoiceChange(Voice.robo, const Duration(minutes: 1),
              key: DateTime.now().microsecondsSinceEpoch);
          break;

        case 'Брутальність':
          _handleVoiceChange(Voice.brutal, const Duration(minutes: 1),
              key: DateTime.now().microsecondsSinceEpoch);
          break;

        case 'Пустити гелій на 1хв':
          _handleVoiceChange(Voice.helium, const Duration(minutes: 1),
              key: DateTime.now().microsecondsSinceEpoch);
          break;

        case 'Пан Роман':
          RingtoneUtils.play(Assets.assets1707257933102);
          break;

        case 'Чіпі':
          RingtoneUtils.play(Assets.assetsChipi);
          break;

        case 'Здивуватися як V4NS_':
          RingtoneUtils.play(Assets.assets1707249127111);
          break;

        case 'Похвалити':
          RingtoneUtils.play(Assets.assets1707249117387);
          break;

        case 'Дзеркало':
          _mirror = !_mirror;
          _mirrorScene(_mirror);
          break;

        case 'Підніми її':
          RingtoneUtils.play(Assets.assets1707241703596);
          break;

        case 'Дар\'я сміється':
          RingtoneUtils.play(Assets.assetsDaria);
          break;

        case 'Хто відповідальний':
          RingtoneUtils.play(Assets.assets1707241061568);
          break;

        case 'Чорно-біле':
          _toggleBlackWhite();
          break;

        case 'Наркоманія':
          _toggleNarkomania();
          break;

        case 'Хто я':
          RingtoneUtils.play(Assets.assets1707240876273);
          break;

        case 'Шо він зробив':
          RingtoneUtils.play(Assets.assets1707171410229);
          break;

        case 'Шо він йому казав':
          RingtoneUtils.play(Assets.assets1707170056254);
          break;

        case 'Ох і хуїта':
          RingtoneUtils.play(Assets.assets1189758809049149541);
          break;

        case 'Рандомна Нарізка':
          _handlePlayRandomHighlightRequest(VideoType.saber);
          break;

        case 'Добра бійка':
          _handlePlayRandomHighlightRequest(VideoType.funny);
          break;

        case 'Смерть півня':
          _handlePlayRandomHighlightRequest(VideoType.death);
          break;
      }
    }, onError: (e) {
      print(e);
    });

    print('Wss connected');
    return completer.future;
  }

  @override
  void dispose() {
    _media?.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _createBody(context);
  }

  File _findRandomHighlight(VideoType type) {
    final Directory directory;
    switch (type) {
      case VideoType.death:
        directory = Directory('C:\\Users\\dealn\\Desktop\\reward\\deaths');
        break;

      case VideoType.saber:
        directory = Directory('C:\\Users\\dealn\\Desktop\\reward\\saber');
        break;

      case VideoType.funny:
        directory = Directory('C:\\Users\\dealn\\Desktop\\reward\\funny');
        break;
    }

    final all = directory.listSync();

    final mp4 = all
        .where((element) => element.path.endsWith('.mp4'))
        .map((e) => e as File)
        .toList();
    return mp4[Random().nextInt(mp4.length)];
  }

  _Media? _media;

  Widget? _createVideoPlayer() {
    final media = _media;

    if (media != null) {
      return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 4)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16.0 / 9.0,
            child: VideoPlayer(
              media.controller,
              key: Key(media.file.path),
            ),
          ),
        ),
      );
    } else {
      return null;
    }
  }

  Widget _createBody(BuildContext context) {
    final player = _createVideoPlayer();
    return Stack(
      alignment: Alignment.center,
      children: [
        if (player != null) player,
        SizedBox(
          height: double.infinity,
          width: double.infinity,
          child: MoveWindow(),
        ),
      ],
    );
  }

  void _resetVideo() async {
    await _media?.controller.dispose();
    setState(() {
      _media = null;
    });
  }

  void _handlePlayRandomHighlightRequest(VideoType type) async {
    _resetVideo();

    final file = _findRandomHighlight(type);
    print(file);

    final controller = VideoPlayerController.file(file);
    controller.addListener(() {
      final event = controller.value;

      if (_media?.controller == controller && event.isCompleted) {
        _resetVideo();
      }
    });

    await controller.initialize();

    setState(() {
      _media = _Media(controller: controller, file: file);
      _media?.controller.play();
    });
  }

  int? _activeVoiceKey;

  Future<void> _showHeliumSmoke(Duration duration) async {
    final smoke = await _obs?.sceneItems.list('Scene').then(
        (value) => value.firstWhere((item) => item.sourceName == 'Smoke'));

    if (smoke != null) {
      await _obs?.sceneItems.setEnabled(SceneItemEnableStateChanged(
          sceneName: 'Scene',
          sceneItemId: smoke.sceneItemId,
          sceneItemEnabled: true));
      await Future.delayed(duration);
      await _obs?.sceneItems.setEnabled(SceneItemEnableStateChanged(
          sceneName: 'Scene',
          sceneItemId: smoke.sceneItemId,
          sceneItemEnabled: false));
    }
  }

  void _handleVoiceChange(Voice voice, Duration duration,
      {required int key}) async {
    _activeVoiceKey = key;

    if (voice == Voice.helium) {
      await _showHeliumSmoke(const Duration(seconds: 5));
    }

    await _enableVoiceInputs(voice);
    await Future.delayed(duration);

    if (_activeVoiceKey == key) {
      await _enableVoiceInputs(Voice.normal);
    }
  }
}

enum VideoType { death, saber, funny }

enum Voice { normal, helium, brutal, robo }
