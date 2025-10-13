import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';

class Settings {
  static const _kTwitchAuth = 'twitch_auth';
  static const _kObsWsUrl = 'obs_ws_url';
  static const _kObsWsPassword = 'obs_ws_password';
  static const _kRewards = 'rewards';
  static const _kBrightness = 'brightness';

  late Rewards rewards;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _initTwitchCreds(prefs);
    _initObsPrefs(prefs);
    _initRewards(prefs);

    appearance = _extractAppearance(prefs);
  }

  Future<void> makeRequiredMigrations() async {
    int changes = 0;

    for (var reward in rewards.rewards) {
      for (int i = 0; i < reward.handlers.length; i++) {
        final action = reward.handlers[i];

        if (action.type == RewardAction.typeEnableFilter) {
          reward.handlers[i] = RewardAction(type: RewardAction.typeToggleFilter)
            ..filterName = action.filterName
            ..sourceName = action.sourceName
            ..action = action.enable ? 'enable' : 'disable';
          changes++;
        }

        if (action.type == RewardAction.typeInvertFilter) {
          reward.handlers[i] = RewardAction(type: RewardAction.typeToggleFilter)
            ..filterName = action.filterName
            ..sourceName = action.sourceName
            ..action = 'toggle';
          changes++;
        }

        if (action.type == RewardAction.typeToggleSource &&
            action.action == null) {
          reward.handlers[i].action = 'toggle';
          changes++;
        }

        if (action.type == RewardAction.typeEnableSource) {
          reward.handlers[i] = RewardAction(type: RewardAction.typeToggleSource)
            ..sceneName = action.sceneName
            ..sourceName = action.sourceName
            ..action = action.enable ? 'enable' : 'disable';
          changes++;
        }
      }
    }

    if (changes > 0) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString(_kRewards, jsonEncode(rewards.toJson()));
    }
  }

  final _rewardsSubject = StreamController<Rewards>.broadcast();

  Stream<Rewards> get rewardsStream => _rewardsSubject.stream;

  Future<void> saveRewards(Rewards rewards) async {
    final prefs = await SharedPreferences.getInstance();

    prefs.setString(_kRewards, jsonEncode(rewards.toJson()));

    this.rewards = rewards;
    _rewardsSubject.add(rewards);

    print('Saved');
  }

  Stream<TwitchCreds?> get twitchAuthStream =>
      Stream.value(twitchAuth).concatWith([_twitchAuthSubject.stream]);

  ObsPrefs? obsPrefs;

  void _initObsPrefs(SharedPreferences prefs) {
    obsPrefs = ObsPrefs(
        url: prefs.getString(_kObsWsUrl) ?? 'ws://127.0.0.1:4455',
        password: prefs.getString(_kObsWsPassword));
  }

  void _initRewards(SharedPreferences prefs) {
    final json = prefs.getString(_kRewards);

    rewards = json != null
        ? Rewards.fromJson(jsonDecode(json))
        : Rewards(rewards: []);
  }

  Stream<ObsPrefs?> get obsPrefsChanges => _obsPrefsSubject.stream;

  Stream<ObsPrefs?> get obsPrefsStream =>
      Stream.value(obsPrefs).concatWith([_obsPrefsSubject.stream]);

  final _obsPrefsSubject = StreamController<ObsPrefs?>.broadcast();

  Future<void> saveObsPrefs(
      {required String url, required String password}) async {
    final updated = obsPrefs = ObsPrefs(url: url, password: password);
    _obsPrefsSubject.add(updated);

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

  void _initTwitchCreds(SharedPreferences prefs) {
    final json = prefs.getString(_kTwitchAuth);

    twitchAuth = json != null ? TwitchCreds.fromJson(jsonDecode(json)) : null;
  }

  final _appearanceSubject = StreamController<Appearance>.broadcast();

  late Appearance appearance;

  Stream<Appearance> get appearanceChanges => _appearanceSubject.stream;

  static Appearance _extractAppearance(SharedPreferences prefs) {
    return Appearance(
        brightness: AppBrightness.findByName(prefs.getString(_kBrightness)));
  }

  void toggleBrightness(AppBrightness current) {
    final all = [...AppBrightness.values, ...AppBrightness.values];
    final next = all[all.indexOf(current) + 1];
    setBrightness(next);
  }

  void setBrightness(AppBrightness brightness) {
    appearance = appearance.copy(brightness: brightness);
    _appearanceSubject.add(appearance);

    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_kBrightness, brightness.name));
  }
}

class ObsPrefs {
  final String? url;
  final String? password;

  ObsPrefs({required this.url, required this.password});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ObsPrefs &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          password == other.password;

  @override
  int get hashCode => url.hashCode ^ password.hashCode;
}

class Appearance {
  final AppBrightness brightness;

  Appearance({required this.brightness});

  Appearance copy({AppBrightness? brightness}) {
    return Appearance(brightness: brightness ?? this.brightness);
  }
}

enum AppBrightness {
  system('system'),
  dark('dark'),
  light('light');

  const AppBrightness(this.value);

  final String value;

  static AppBrightness findByName(String? name) {
    return AppBrightness.values
            .firstWhereOrNull((element) => element.value == name) ??
        AppBrightness.system;
  }
}
