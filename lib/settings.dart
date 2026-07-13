import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/rewards_store.dart';
import 'package:twitch_listener/twitch/twitch_creds.dart';

class Settings {
  static const _kTwitchAuth = 'twitch_auth';
  static const _kObsWsUrl = 'obs_ws_url';
  static const _kObsWsPassword = 'obs_ws_password';
  static const _kRewards = 'rewards';
  static const _kBrightness = 'brightness';

  late Rewards rewards;
  late final SharedPreferences _prefs;
  late final RewardsStore _rewardsStore;

  Future<void> init() async {
    final prefs = _prefs = await _loadPreferences();

    _initTwitchCreds(prefs);
    _initObsPrefs(prefs);
    await _initRewards(prefs);

    appearance = _extractAppearance(prefs);
  }

  static Future<SharedPreferences> _loadPreferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      if (!Platform.isWindows && !Platform.isLinux) {
        rethrow;
      }
      await _resetPreferencesFile();
      return SharedPreferences.getInstance();
    }
  }

  static Future<void> _resetPreferencesFile() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(path.join(directory.path, 'shared_preferences.json'));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> makeRequiredMigrations() async {
    int changes = 0;

    for (var reward in rewards.rewards) {
      for (int i = 0; i < reward.handlers.length; i++) {
        final action = reward.handlers[i];

        if (action.type == RewardAction.typeDelay && action.duration != null) {
          action.millis = (action.duration ?? 0) * 1000;
          action.duration = null;
          changes++;
        }

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
      await _rewardsStore.save(rewards);
    }
  }

  final _rewardsSubject = StreamController<Rewards>.broadcast();

  Stream<Rewards> get rewardsStream => _rewardsSubject.stream;

  Future<void> saveRewards(Rewards rewards) async {
    await _rewardsStore.save(rewards);

    this.rewards = rewards;
    _rewardsSubject.add(rewards);
  }

  Stream<TwitchCreds?> get twitchAuthStream =>
      Stream.value(twitchAuth).concatWith([_twitchAuthSubject.stream]);

  ObsPrefs? obsPrefs;

  void _initObsPrefs(SharedPreferences prefs) {
    obsPrefs = ObsPrefs(
        url: prefs.getString(_kObsWsUrl) ?? 'ws://127.0.0.1:4455',
        password: prefs.getString(_kObsWsPassword));
  }

  Future<void> _initRewards(SharedPreferences prefs) async {
    final legacyJson = prefs.getString(_kRewards);
    _rewardsStore = await RewardsStore.open();
    rewards = await _rewardsStore.loadAndMigrate(legacyJson);

    if (legacyJson != null) {
      await prefs.remove(_kRewards);
    }
  }

  Stream<ObsPrefs?> get obsPrefsChanges => _obsPrefsSubject.stream;

  Stream<ObsPrefs?> get obsPrefsStream =>
      Stream.value(obsPrefs).concatWith([_obsPrefsSubject.stream]);

  final _obsPrefsSubject = StreamController<ObsPrefs?>.broadcast();

  Future<void> saveObsPrefs(
      {required String url, required String password}) async {
    final updated = obsPrefs = ObsPrefs(url: url, password: password);
    _obsPrefsSubject.add(updated);

    await _prefs.setString(_kObsWsUrl, url);
    await _prefs.setString(_kObsWsPassword, password);
  }

  Future<void> saveTwitchAuth(TwitchCreds? creds) async {
    if (creds != null) {
      await _prefs.setString(_kTwitchAuth, jsonEncode(creds.toJson()));
    } else {
      await _prefs.remove(_kTwitchAuth);
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

  Future<void> setBrightness(AppBrightness brightness) async {
    appearance = appearance.copy(brightness: brightness);
    _appearanceSubject.add(appearance);

    await _prefs.setString(_kBrightness, brightness.name);
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
