import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
      {super.key,
      required this.settings,
      required this.webSocketManager});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<TwitchConnectWidget> {
  late final Settings _settings;

  @override
  void initState() {
    _settings = widget.settings;
    _fetchUserInfo();
    super.initState();
  }

  UserDto? _user;
  bool _loading = false;

  Future<void> _fetchUserInfo() async {
    setState(() {
      _loading = true;
    });

    final data =
        await TwitchApi(settings: _settings, clientSecret: twitchClientSecret)
            .getUser();

    setState(() {
      _loading = false;
      _user = data;
    });
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
}
