import 'dart:async';
import 'dart:convert';

import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';

class Settings {
  static const _kTwitchAuth = 'twitch_auth';
  static const _kObsWsUrl = 'obs_ws_url';
  static const _kObsWsPassword = 'obs_ws_password';
  static const _kRewards = 'rewards';

  late Rewards rewards;

  Future<void> init() async {
    await initTwitchCreds();
    await initObsPrefs();
    await initRewards();
  }

  final _rewardsSubject = StreamController<Rewards>.broadcast();

  Stream<Rewards> get rewardsStream => _rewardsSubject.stream;

  Future<void> saveRewards(Rewards rewards) async {
    final prefs = await SharedPreferences.getInstance();

    prefs.setString(_kRewards, jsonEncode(rewards.toJson()));

    this.rewards = rewards;
    _rewardsSubject.add(rewards);
  }

  Stream<TwitchCreds?> get twitchAuthStream =>
      Stream.value(twitchAuth).concatWith([_twitchAuthSubject.stream]);

  String? obsWsUrl;
  String? obsWsPassword;

  Future<void> initObsPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    obsWsUrl = prefs.getString(_kObsWsUrl) ?? 'ws://127.0.0.1:4455';
    obsWsPassword = prefs.getString(_kObsWsPassword);
  }

  Future<void> initRewards() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kRewards);

    rewards = json != null
        ? Rewards.fromJson(jsonDecode(json))
        : Rewards(rewards: []);
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
