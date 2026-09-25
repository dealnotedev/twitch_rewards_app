import 'dart:io';

import 'package:twitch_listener/audioplayer.dart';
import 'package:twitch_listener/autosaver.dart';
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/music/media_kit_music_track_player.dart';
import 'package:twitch_listener/music/music_file_cache.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/music_tool_paths.dart';
import 'package:twitch_listener/music/yt_dlp_music_track_fetcher.dart';
import 'package:twitch_listener/reward_executor.dart';
import 'package:twitch_listener/settings.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';
import 'package:twitch_listener/twitch_shared.dart';

class AppServiceLocator extends ServiceLocator {
  static late final AppServiceLocator instance;

  static AppServiceLocator init(
      {required Settings settings, required Audioplayer audioplayer}) {
    instance = AppServiceLocator._(settings, audioplayer);
    return instance;
  }

  final Settings settings;
  final Audioplayer audioplayer;
  final Map<Type, Object> map = {};

  AppServiceLocator._(this.settings, this.audioplayer) {
    final wsManager = WebSocketManager(
        'wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30',
        settings,
        listenChat: true,
        listenFollow: false);

    final obs = ObsConnect(settings: settings);
    final tools = MusicToolPaths.resolve(
        executableDirectory: File(Platform.resolvedExecutable).parent);
    final musicRequests = MusicRequestManager(
      fetcher: YtDlpMusicTrackFetcher(
        executable: tools.ytDlpExecutable,
        denoPath: tools.denoPath,
        cache: MusicFileCache(
            rootDirectory: defaultMusicCacheDirectory(),
            maxBytes: 2 * 1024 * 1024 * 1024),
      ),
      player: MediaKitMusicTrackPlayer(),
      volume: settings.musicVolume,
      saveVolume: settings.saveMusicVolume,
    );
    final executor = RewardExecutor(
        audioplayer: audioplayer, obs: obs, musicRequests: musicRequests);

    final autosaver = Autosaver(delay: const Duration(seconds: 2));

    map[Settings] = settings;
    map[ServiceLocator] = this;
    map[WebSocketManager] = wsManager;
    map[ObsConnect] = obs;
    map[RewardExecutor] = executor;
    map[MusicRequestManager] = musicRequests;
    map[Audioplayer] = audioplayer;
    map[TwitchShared] = TwitchShared();
    map[Autosaver] = autosaver;
  }

  @override
  T provide<T>() => map[T] as T;
}
