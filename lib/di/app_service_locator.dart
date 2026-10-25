import 'dart:async';
import 'dart:io';

import 'package:twitch_listener/audio/audioplayer.dart';
import 'package:twitch_listener/core/autosaver.dart';
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/obs/obs_connect.dart';
import 'package:twitch_listener/music/media_kit_music_track_player.dart';
import 'package:twitch_listener/music/ffmpeg_audio_processor.dart';
import 'package:twitch_listener/music/music_file_cache.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/music_server_controller.dart';
import 'package:twitch_listener/music/music_tool_paths.dart';
import 'package:twitch_listener/music/yt_dlp_music_track_fetcher.dart';
import 'package:twitch_listener/music/youtube_browser_session.dart';
import 'package:twitch_listener/music/youtube_connection_controller.dart';
import 'package:twitch_listener/rewards/reward_executor.dart';
import 'package:twitch_listener/core/settings.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';
import 'package:twitch_listener/twitch/twitch_shared.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';
import 'package:twitch_listener/twitch/twitch_api.dart';
import 'package:twitch_listener/twitch/twitch_authenticator.dart';
import 'package:twitch_listener/secrets.dart';
import 'package:twitch_listener/updates/update_controller.dart';
import 'package:twitch_listener/twitch/redemption_queue_controller.dart';

class AppServiceLocator extends ServiceLocator {
  static late final AppServiceLocator instance;

  static AppServiceLocator init({
    required Settings settings,
    required Audioplayer audioplayer,
  }) {
    instance = AppServiceLocator._(settings, audioplayer);
    return instance;
  }

  final Settings settings;
  final Audioplayer audioplayer;
  final Map<Type, Object> map = {};
  late final MusicServerController musicServer;
  Future<void>? _musicClosing;
  Future<void>? _redemptionsClosing;

  Future<void> closeRedemptions() =>
      _redemptionsClosing ??= provide<RedemptionQueueController>().close();

  Future<void> closeMusic() => _musicClosing ??= () async {
    await musicServer.close();
    await provide<MusicRequestManager>().close();
    await provide<YoutubeConnectionController>().close();
  }();

  AppServiceLocator._(this.settings, this.audioplayer) {
    final wsManager = WebSocketManager(
      'wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30',
      settings,
      listenChat: true,
      listenFollow: false,
    );

    final obs = ObsConnect(settings: settings);
    final tools = MusicToolPaths.resolve(
      executableDirectory: File(Platform.resolvedExecutable).parent,
    );
    final audioProcessor = FfmpegAudioProcessor(
      executable: tools.ffmpegExecutable,
    );
    final musicCache = MusicFileCache(
      rootDirectory: defaultMusicCacheDirectory(),
      profileName: audioProcessor.cacheProfile,
      maxBytes: 2 * 1024 * 1024 * 1024,
    );
    final sessionDirectory = Directory(
      '${musicCache.rootDirectory.parent.path}${Platform.pathSeparator}youtube-session',
    );
    late final YoutubeConnectionController youtubeConnection;
    late final MusicRequestManager musicRequests;
    final trackFetcher = YtDlpMusicTrackFetcher(
      executable: tools.ytDlpExecutable,
      denoPath: tools.denoPath,
      audioProcessor: audioProcessor,
      cache: musicCache,
      cookies: () => youtubeConnection.leaseCookies(),
    );
    YtDlpMusicTrackFetcher? youtubeProbe;
    var youtubeProbeCanceled = false;
    youtubeConnection = YoutubeConnectionController(
      directory: sessionDirectory,
      browser: ManagedYoutubeBrowserSession(
        profileDirectory: Directory(
          '${sessionDirectory.path}${Platform.pathSeparator}browser',
        ),
      ),
      toolVersion: trackFetcher.readVersion,
      onConnected: () => musicRequests.resumePreparation(),
      cancelVerification: () async {
        youtubeProbeCanceled = true;
        await youtubeProbe?.cancel();
      },
      verifyAccess: (cookies, url, onProgress) async {
        youtubeProbeCanceled = false;
        // A fresh cache makes the check retrieve audio from YouTube every time.
        final checkCache = Directory(
          '${sessionDirectory.path}${Platform.pathSeparator}check',
        );
        if (await checkCache.exists()) await checkCache.delete(recursive: true);
        // The probe and queue can run concurrently, so each owns its processor.
        final processor = FfmpegAudioProcessor(
          executable: tools.ffmpegExecutable,
        );
        final probe = YtDlpMusicTrackFetcher(
          executable: tools.ytDlpExecutable,
          denoPath: tools.denoPath,
          audioProcessor: processor,
          cache: MusicFileCache(
            rootDirectory: checkCache,
            maxBytes: 0,
            profileName: processor.cacheProfile,
          ),
          cookies: () async => YtDlpCookieFile(cookies),
          downloadTimeout: const Duration(minutes: 2),
        );
        youtubeProbe = probe;
        try {
          final metadata = await probe.inspect(url);
          if (youtubeProbeCanceled) return;
          if (metadata.duration > musicRequests.maxDuration) {
            throw const MusicTrackException(
              'Choose a video within the track duration limit.',
              errorType: MusicQueueErrorType.trackTooLongOrLive,
            );
          }
          await probe.obtain(metadata: metadata, onProgress: onProgress);
        } finally {
          youtubeProbe = null;
          try {
            if (await checkCache.exists()) {
              await checkCache.delete(recursive: true);
            }
          } on FileSystemException {
            // Removed before the next check.
          }
        }
      },
    );
    musicRequests = MusicRequestManager(
      fetcher: trackFetcher,
      player: MediaKitMusicTrackPlayer(),
      volume: settings.musicVolume,
      saveVolume: settings.saveMusicVolume,
      onPreparationHeld: youtubeConnection.requireCheck,
    );
    musicServer = MusicServerController(musicRequests);
    unawaited(musicServer.start());
    map[MusicServerController] = musicServer;

    final executor = RewardExecutor(
      audioplayer: audioplayer,
      obs: obs,
      musicRequests: musicRequests,
    );

    final autosaver = Autosaver(delay: const Duration(seconds: 2));

    map[Settings] = settings;
    map[UpdateController] = UpdateController();
    map[ServiceLocator] = this;
    map[WebSocketManager] = wsManager;
    map[ObsConnect] = obs;
    map[RewardExecutor] = executor;
    map[MusicRequestManager] = musicRequests;
    map[YoutubeConnectionController] = youtubeConnection;
    map[Audioplayer] = audioplayer;
    final twitchShared = TwitchShared();
    map[TwitchShared] = twitchShared;
    map[TwitchRewardsController] = TwitchRewardsController(
      settings: settings,
      shared: twitchShared,
      autosaver: autosaver,
      createApi: (creds) => TwitchApi(
        settings: settings,
        clientSecret: twitchClientSecret,
        broadcasterId: creds.broadcasterId,
        expectedCredentials: creds,
      ),
      authorize: () => TwitchAuthenticator(
        clientId: twitchClientId,
        clientSecret: twitchClientSecret,
        oauthRedirectUrl: twitchOauthRedirectUrl,
      ).login(),
    );
    map[Autosaver] = autosaver;
    map[RedemptionQueueController] = RedemptionQueueController(
      settings: settings,
      rewards: provide(),
      executor: executor,
      messages: wsManager.messages,
      createApi: (creds) => TwitchApi(
        settings: settings,
        clientSecret: twitchClientSecret,
        broadcasterId: creds.broadcasterId,
        expectedCredentials: creds,
      ),
    );
  }

  @override
  T provide<T>() => map[T] as T;
}
