import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';

class Settings {
  static final instance = Settings._();

  Settings._();

  static const _kTwitchAuth = 'twitch_auth';
  static const _kObsWsUrl = 'obs_ws_url';
  static const _kObsWsPassword = 'obs_ws_password';

  Future<void> init() async {
    await initTwitchCreds();
    await initObsPrefs();
  }

  String? obsWsUrl;
  String? obsWsPassword;

  Future<void> initObsPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    obsWsUrl = prefs.getString(_kObsWsUrl);
    obsWsPassword = prefs.getString(_kObsWsPassword);
  }

  Future<void> saveObsPrefs(
      {required String url, required String password}) async {
    obsWsUrl = url;
    obsWsPassword = password;

    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_kObsWsUrl, url);
    prefs.setString(_kObsWsPassword, password);
  }

  Future<void> saveTwitchAuth(TwitchCreds? creds) async {
    final prefs = await SharedPreferences.getInstance();

    if (creds != null) {
      prefs.setString(_kTwitchAuth, jsonEncode(creds.toJson()));
    } else {
      prefs.remove(_kTwitchAuth);
    }

    twitchAuth = creds;
    _twitchAuthSubject.add(creds);
  }

  Stream<TwitchCreds?> get twitchAuthChanges => _twitchAuthSubject.stream;

  late TwitchCreds? twitchAuth;

  final _twitchAuthSubject = StreamController<TwitchCreds?>.broadcast();

  Future<void> initTwitchCreds() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kTwitchAuth);

    twitchAuth = json != null ? TwitchCreds.fromJson(jsonDecode(json)) : null;
  }
}
