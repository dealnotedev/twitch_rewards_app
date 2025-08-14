import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';

class AppServiceLocator extends ServiceLocator {
  static late final AppServiceLocator instance;

  static AppServiceLocator init({required Settings settings, required SoLoud soloud}) {
    instance = AppServiceLocator._(settings, soloud);
    return instance;
  }

  final Settings settings;
  final SoLoud soloud;
  final Map<Type, Object> map = {};

  AppServiceLocator._(this.settings, this.soloud) {
    final wsManager = WebSocketManager(
        'wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30',
        settings,
        listenChat: false,
        listenFollow: false);

    map[Settings] = settings;
    map[ServiceLocator] = this;
    map[WebSocketManager] = wsManager;
    map[ObsConnect] = ObsConnect(settings: settings);
    map[SoLoud] = soloud;
  }

  @override
  T provide<T>() => map[T] as T;
}
