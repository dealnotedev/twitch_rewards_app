import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/buttons.dart';
import 'package:twitch_listener/connection_status.dart';
import 'package:twitch_listener/extensions.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/secrets.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/simple_icon.dart';
import 'package:twitch_listener/themes.dart';
import 'package:twitch_listener/twitch/dto.dart';
import 'package:twitch_listener/twitch/twitch_api.dart';
import 'package:twitch_listener/twitch/twitch_authenticator.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';
import 'package:twitch_listener/viewers_counter.dart';

class TwitchStateWidget extends StatefulWidget {
  final WebSocketManager webSocketManager;
  final Settings settings;

  const TwitchStateWidget(
      {super.key, required this.webSocketManager, required this.settings});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<TwitchStateWidget> {
  late final WebSocketManager _ws;
  late final Settings _settings;

  StreamSubscription<WsState>? _wsSubs;
  StreamSubscription<TwitchCreds?>? _twitchSubs;

  @override
  void initState() {
    _ws = widget.webSocketManager;
    _settings = widget.settings;

    _twitchCreds = _settings.twitchAuth;
    _wsState = _ws.currentState;

    _wsSubs = _ws.stateShanges.listen(_handleWsChanges);
    _twitchSubs = _settings.twitchAuthChanges.listen(_handleTwitchChanges);

    _handleTwitchAuth();
    super.initState();
  }

  @override
  void dispose() {
    _wsSubs?.cancel();
    _twitchSubs?.cancel();
    super.dispose();
  }

  late TwitchCreds? _twitchCreds;
  late WsState _wsState;

  UserDto? _user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final user = _user;
    final avatar = _user?.profileImageUrl;

    final String title;
    final String subtitle;

    if (user != null) {
      title = user.displayName ?? user.login;
      subtitle = context.localizations.twitch_login_authorized;
    } else if (_twitchCreds != null) {
      title = context.localizations.twitch_connection_loading;
      subtitle = context.localizations.please_wait;
    } else {
      title = context.localizations.twitch_connection_not_connected;
      subtitle = context.localizations.twitch_login_click_to_connect;
    }

    final viewers = _stream?.viewerCount;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          border: Border.all(
              color: theme.dividerColor,
              width: 0.5,
              strokeAlign: BorderSide.strokeAlignOutside),
          borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SimpleIcon.simpleSquare(Assets.assetsIcTwitch16dp, size: 16),
              const Gap(8),
              Expanded(
                  child: Text(
                context.localizations.twitch_connection_title,
                style: TextStyle(fontSize: 14, color: theme.textColorPrimary),
              ))
            ],
          ),
          const Gap(16),
          Row(
            children: [
              SizedBox(
                height: 32,
                width: 32,
                child: Stack(
                  children: [
                    if (avatar != null) ...[
                      ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: avatar,
                          width: 32,
                          height: 32,
                          filterQuality: FilterQuality.medium,
                        ),
                      )
                    ] else ...[
                      Container(
                        alignment: Alignment.center,
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: theme.buttonColorAlternative),
                        child: Text(
                          '?',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.textColorPrimary,
                              height: 1),
                        ),
                      )
                    ]
                  ],
                ),
              ),
              const Gap(16),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: theme.textColorPrimary),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 10, color: theme.textColorSecondary),
                  )
                ],
              )),
              const Gap(16),
              ConnectionStatusWidget(theme: theme, status: _connectionStatus),
              if (viewers != null) ...[
                const Gap(8),
                ViewersCounter(theme: theme, count: viewers)
              ]
            ],
          ),
          const Gap(8),
          if (_twitchCreds != null) ...[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CustomButton(
                text: context.localizations.button_logout,
                style: CustomButtonStyle.secondary,
                theme: theme,
                onTap: _twitchLogout,
              ),
            )
          ] else ...[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CustomButton(
                text: context.localizations.button_connect,
                style: CustomButtonStyle.primary,
                theme: theme,
                onTap: _login2Twitch,
              ),
            )
          ]
        ],
      ),
    );
  }

  ConnectionStatus get _connectionStatus {
    switch (_wsState) {
      case WsState.initialConnecting:
      case WsState.reconnecting:
        return ConnectionStatus.connecting;

      case WsState.connected:
        return ConnectionStatus.connected;

      case WsState.disconnected:
      case WsState.idle:
        return ConnectionStatus.disconnected;
    }
  }

  Timer? _timer;

  Future<void> _fetchUserInfo(TwitchApi api) async {
    final data = await api.getUser();

    setState(() {
      _user = data;
    });

    _timer = Timer.periodic(
        const Duration(minutes: 1), (_) => _handleTimerTick(api, dto: data));
  }

  void _handleWsChanges(WsState event) {
    setState(() {
      _wsState = event;
    });
  }

  void _handleTwitchAuth() {
    if (_twitchCreds != null) {
      final api =
          TwitchApi(settings: _settings, clientSecret: twitchClientSecret);
      _fetchUserInfo(api);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _handleTwitchChanges(TwitchCreds? event) {
    setState(() {
      _user = null;
      _stream = null;
      _twitchCreds = event;
    });

    _handleTwitchAuth();
  }

  StreamDto? _stream;

  void _handleTimerTick(TwitchApi api, {required UserDto dto}) async {
    final steam = await api.getStreams(broadcasterId: dto.id).then((value) =>
        value.firstWhereOrNull((element) => element.userId == dto.id));

    setState(() {
      _stream = steam;
    });
  }

  final _authenticator = TwitchAuthenticator(
      clientId: twitchClientId,
      clientSecret: twitchClientSecret,
      oauthRedirectUrl: twitchOauthRedirectUrl);

  void _twitchLogout() {
    _settings.saveTwitchAuth(null);
  }

  Future<void> _login2Twitch() async {
    final creds = await _authenticator.login();
    await widget.settings.saveTwitchAuth(creds);
  }
}
