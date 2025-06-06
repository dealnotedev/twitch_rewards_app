import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';

class AppServiceLocator extends ServiceLocator {
  static late final AppServiceLocator instance;

  static AppServiceLocator init(Settings settings) {
    instance = AppServiceLocator._(settings);
    return instance;
  }

  final Settings settings;
  final Map<Type, Object> map = {};

  AppServiceLocator._(this.settings) {
    final wsManager = WebSocketManager(
        'wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30',
        settings,
        listenChat: false,
        listenFollow: false);

    map[Settings] = settings;
    map[ServiceLocator] = this;
    map[WebSocketManager] = wsManager;
    map[ObsConnect] = ObsConnect(settings: settings);
  }

  @override
  T provide<T>() => map[T] as T;
}
