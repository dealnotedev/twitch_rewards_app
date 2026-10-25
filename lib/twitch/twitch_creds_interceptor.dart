import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fresh_dio/fresh_dio.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';

class TwitchCredsInterceptor extends Fresh<TwitchCreds> {
  TwitchCredsInterceptor({
    required Settings settings,
    required String clientSecret,
    TwitchCreds? expectedCredentials,
  }) : super(
         refreshToken: (t, _) => _refreshToken(t, clientSecret),
         tokenHeader: (token) => {
           'Authorization': 'Bearer ${token.accessToken}',
           'Client-Id': token.clientId,
         },
         tokenStorage: _SettingTokenStorage(
           settings: settings,
           expectedCredentials: expectedCredentials,
         ),
       );

  static Future<TwitchCreds> _refreshToken(
    TwitchCreds? token,
    String clientSecret,
  ) {
    if (token == null) {
      throw StateError('No token found');
    }

    debugPrint('Try to refresh token...');

    final body = <String, String>{
      'refresh_token': token.refreshToken,
      'client_id': token.clientId,
      'client_secret': clientSecret,
      'grant_type': 'refresh_token',
    };

    return Dio()
        .post(
          'https://id.twitch.tv/oauth2/token',
          data: FormData.fromMap(body),
          options: Options(contentType: "application/x-www-form-urlencoded"),
        )
        .then((value) => value.data)
        .then(
          (json) => token.copy(
            accessToken: json['access_token'] as String,
            refreshToken: json['refresh_token'] as String,
          ),
        );
  }
}

class _SettingTokenStorage extends TokenStorage<TwitchCreds> {
  final Settings settings;
  final TwitchCreds? expectedCredentials;

  _SettingTokenStorage({required this.settings, this.expectedCredentials});

  void _checkAccount() {
    final expected = expectedCredentials;
    if (expected != null &&
        (settings.twitchAuth?.clientId != expected.clientId ||
            settings.twitchAuth?.broadcasterId != expected.broadcasterId)) {
      throw StateError('Twitch account changed');
    }
  }

  @override
  Future<void> delete() {
    _checkAccount();
    return settings.saveTwitchAuth(null);
  }

  @override
  Future<TwitchCreds?> read() {
    _checkAccount();
    return Future.value(settings.twitchAuth);
  }

  @override
  Future<void> write(TwitchCreds token) {
    _checkAccount();
    return settings.saveTwitchAuth(token);
  }
}
