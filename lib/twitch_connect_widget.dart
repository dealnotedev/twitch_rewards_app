import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/secrets.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/twitch/dto.dart';
import 'package:twitch_listener/twitch/twitch_api.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';

class TwitchConnectWidget extends StatefulWidget {
  final WebSocketManager webSocketManager;
  final Settings settings;

  const TwitchConnectWidget(
      {super.key, required this.settings, required this.webSocketManager});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<TwitchConnectWidget> {
  late final Settings _settings;
  late final TwitchApi _api;

  @override
  void initState() {
    _settings = widget.settings;
    _api = TwitchApi(settings: _settings, clientSecret: twitchClientSecret);

    _fetchUserInfo();
    super.initState();
  }

  UserDto? _user;
  bool _loading = false;

  Timer? _timer;

  Future<void> _fetchUserInfo() async {
    setState(() {
      _loading = true;
    });

    final data = await _api.getUser();
    _timer = Timer.periodic(
        const Duration(minutes: 1), (_) => _handleTimerTick(dto: data));

    setState(() {
      _loading = false;
      _user = data;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _createIndicator({required WsState state}) {
    final Color color;

    switch (state) {
      case WsState.initialConnecting:
      case WsState.reconnecting:
        color = Colors.yellow;
        break;

      case WsState.connected:
        color = Colors.green;
        break;

      case WsState.disconnected:
        color = Colors.red;
        break;

      case WsState.idle:
        color = Colors.grey;
        break;
    }

    return Container(
      width: 8,
      height: 8,
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(4), color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final avatar = user?.profileImageUrl;

    final Widget image;
    if (avatar != null && avatar.isNotEmpty) {
      image = ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatar,
          width: 32,
          height: 32,
          filterQuality: FilterQuality.medium,
        ),
      );
    } else {
      image = Image.asset(
        Assets.assetsIcTwitch32dp,
        filterQuality: FilterQuality.medium,
        width: 32,
        height: 32,
      );
    }

    final stream = _stream;
    return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: const Color(0xFF363A46),
            borderRadius: BorderRadius.circular(8)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          image,
          const SizedBox(
            width: 16,
          ),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                  children: [
                    StreamBuilder(
                        stream: widget.webSocketManager.stateShanges,
                        initialData: widget.webSocketManager.currentState,
                        builder: (_, snapshot) {
                          return _createIndicator(state: snapshot.requireData);
                        }),
                    const SizedBox(
                      width: 8,
                    ),
                    const Text(
                      'Twitch Connection',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 4,
                ),
                RichText(
                    text: TextSpan(children: [
                  const TextSpan(
                      text: 'Logged as: ',
                      style: TextStyle(color: Colors.grey)),
                  if (user != null) ...[
                    TextSpan(
                        text: user.displayName ?? user.login,
                        style: const TextStyle(color: Colors.green))
                  ] else if (_loading) ...[
                    const TextSpan(text: 'loading...')
                  ] else ...[
                    const TextSpan(
                        text: 'failed', style: TextStyle(color: Colors.red))
                  ]
                ])),
                if (stream != null) ...[
                  const SizedBox(
                    height: 8,
                  ),
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4)),
                    padding:
                        const EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 4),
                    child: Text(
                      '${stream.viewerCount} viewers',
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  )
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                      onPressed: _handleLogoutClick,
                      child: const Text('Logout')),
                )
              ]))
        ]));
  }

  void _handleLogoutClick() {
    _settings.saveTwitchAuth(null);
  }

  StreamDto? _stream;

  void _handleTimerTick({required UserDto dto}) async {
    final steam = await _api.getStreams(broadcasterId: dto.id).then((value) =>
        value.firstWhereOrNull((element) => element.userId == dto.id));

    setState(() {
      _stream = steam;
    });
  }
}
