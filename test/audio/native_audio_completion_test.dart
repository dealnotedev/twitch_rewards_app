import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:twitch_listener/audio/audioplayer.dart';
import 'package:twitch_listener/core/observable_value.dart';
import 'package:twitch_listener/music/media_kit_music_track_player.dart';
import 'package:twitch_listener/music/music_models.dart';

import '../music/audio_fixture.dart';

/// Run with AUDIO_MPV_LIBRARY pointing to the shipped libmpv library.
/// A simulated audio device makes output buffering independent of hardware.
void main() {
  final library = Platform.environment['AUDIO_MPV_LIBRARY'];

  group(
    'native audio completion',
    () {
      late Directory directory;
      late File audio;
      final players = <_BufferedPlayer>[];

      setUpAll(() {
        MediaKit.ensureInitialized(libmpv: library);
      });

      setUp(() async {
        directory = await Directory.systemTemp.createTemp(
          'listener-audio-end-',
        );
        audio = await writeAudioFixture(
          File('${directory.path}/three-seconds.wav'),
          seconds: 3,
        );
      });

      tearDown(() async {
        for (final player in players) {
          if (!player.disposed) await player.dispose();
        }
        players.clear();
        await directory.delete(recursive: true);
      });

      _BufferedPlayer createPlayer(PlayerConfiguration configuration) {
        final player = _BufferedPlayer(configuration);
        players.add(player);
        return player;
      }

      test('reward sounds play the buffered tail before disposal', () async {
        final volume = ObservableValue<double>(current: 0);
        addTearDown(volume.dispose);
        await Audioplayer(createPlayer: createPlayer)
            .playFileWaitCompletion(audio.path, volume: volume)
            .timeout(const Duration(seconds: 10));

        expect(
          players.single.endPosition,
          closeTo(3, .01),
          reason: 'Disposal must not discard buffered reward audio.',
        );
      });

      test('music tracks play the buffered tail before disposal', () async {
        final player = MediaKitMusicTrackPlayer(
          createPlayer: () => createPlayer(const PlayerConfiguration()),
        );
        addTearDown(player.stop);
        final track = DownloadedMusicTrack(
          itemId: 'completion',
          requestedBy: '',
          metadata: MusicTrackMetadata(
            videoId: 'completion',
            title: 'Audio completion test',
            author: '',
            duration: const Duration(seconds: 3),
            thumbnail: null,
            sourceUrl: Uri.parse('https://www.youtube.com/watch?v=jNQXAC9IVRw'),
          ),
          filePath: audio.path,
        );

        await player
            .play(track, volume: 0, onPosition: (_) {})
            .timeout(const Duration(seconds: 10));

        expect(
          players.single.endPosition,
          closeTo(3, .01),
          reason: 'Disposal must not discard buffered music audio.',
        );
      });
    },
    skip: library == null
        ? 'Set AUDIO_MPV_LIBRARY to check native audio completion'
        : false,
  );
}

class _BufferedPlayer extends Player {
  double? endPosition;
  bool disposed = false;

  _BufferedPlayer(PlayerConfiguration configuration)
    : super(configuration: configuration);

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    final native = platform as NativePlayer;
    await native.setProperty('ao', 'null');
    await native.setProperty('audio-buffer', '0.5');
    await super.open(playable, play: play);
  }

  @override
  Future<void> dispose() async {
    endPosition = double.tryParse(
      await (platform as NativePlayer).getProperty('time-pos'),
    );
    await super.dispose();
    disposed = true;
  }
}
