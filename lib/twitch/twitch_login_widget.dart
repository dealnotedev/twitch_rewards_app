import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/secrets.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/twitch/twitch_authenticator.dart';

class TwitchLoginWidget extends StatefulWidget {
  final Settings settings;

  const TwitchLoginWidget({super.key, required this.settings});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<TwitchLoginWidget> {
  final _authenticator = TwitchAuthenticator(
      clientId: twitchClientId,
      clientSecret: twitchClientSecret,
      oauthRedirectUrl: twitchOauthRedirectUrl);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(4);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      constraints: const BoxConstraints(minHeight: 128),
      child: Center(
        child: Material(
          color: const Color(0xFF6542A6),
          borderRadius: radius,
          child: InkWell(
            onTap: _login2Twitch,
            borderRadius: radius,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    Assets.assetsIcTwitchWhite24dp,
                    width: 24,
                    height: 24,
                    filterQuality: FilterQuality.medium,
                  ),
                  const Gap(8),
                  const Text(
                    'Connect with Twitch',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login2Twitch() async {
    final creds = await _authenticator.login();
    await widget.settings.saveTwitchAuth(creds);
  }
}
