import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/audio/audioplayer.dart';
import 'package:twitch_listener/core/observable_value.dart';
import 'package:twitch_listener/music/ffmpeg_audio_processor.dart';
import 'package:twitch_listener/music/music_models.dart';
import 'package:twitch_listener/music/soloud_music_track_player.dart';

import '../music/audio_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'SoLoud plays overlapping WAV effects and supports MP3 playback controls',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'listener-audio-',
      );
      addTearDown(() => directory.delete(recursive: true));
      const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        pathProvider,
        (_) async => directory.path,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(pathProvider, null));
      final wave = await writeAudioFixture(
        File('${directory.path}/sound.wav'),
        seconds: 3,
      );
      final normalized =
          await FfmpegAudioProcessor(
            executable: File('tools/ffmpeg.exe').absolute.path,
          ).normalize(
            input: wave,
            stagingDirectory: directory,
            duration: const Duration(seconds: 3),
            onProgress: (_) {},
          );
      final song = await normalized.rename('${directory.path}/song.media');
      final effect = await wave.rename('${directory.path}/звук.wav');

      final engine = SoLoud.instance;
      addTearDown(engine.deinit);
      final effects = Audioplayer();
      final music = SoloudMusicTrackPlayer();
      addTearDown(music.stop);
      final volume = ObservableValue<double>(current: 0);
      addTearDown(volume.dispose);

      final preview = await effects.playFileInfinitely(
        effect.path,
        volume: volume,
      );
      addTearDown(() => effects.cancelByToken(preview));
      engine.setGlobalVolume(0);
      final effectSource = engine.activeSounds.single;
      volume.set(3);
      await Future<void>.delayed(Duration.zero);
      expect(engine.getVolume(effectSource.handles.single), 3);

      final effectTime = Stopwatch()..start();
      final effectFinished = effects.playFileWaitCompletion(
        effect.path,
        volume: volume,
      );
      final reached = Completer<void>();
      final playing = music.play(
        DownloadedMusicTrack(
          itemId: 'smoke',
          requestedBy: '',
          metadata: MusicTrackMetadata(
            videoId: 'smoke',
            title: 'Audio test',
            author: '',
            duration: const Duration(seconds: 3),
            thumbnail: null,
            sourceUrl: Uri.parse('https://www.youtube.com/watch?v=jNQXAC9IVRw'),
          ),
          filePath: song.path,
        ),
        volume: 0,
        onPosition: (position) {
          if (position > Duration.zero && !reached.isCompleted) {
            reached.complete();
          }
        },
      );
      await reached.future.timeout(const Duration(seconds: 5));
      expect(effectSource.handles, hasLength(2));
      for (final handle in effectSource.handles) {
        expect(engine.getVolume(handle), 3);
      }
      await music.setPaused(true);
      await music.seek(const Duration(seconds: 2));
      await music.setVolume(0);
      await music.setPaused(false);
      await effects.cancelByToken(preview);
      await Future.wait([playing, effectFinished])
          .timeout(const Duration(seconds: 6));
      expect(
        effectTime.elapsed,
        greaterThan(const Duration(milliseconds: 2700)),
      );
      expect(engine.activeSounds, isEmpty);
    },
    skip: Platform.environment['LISTENER_TEST_NATIVE_AUDIO'] == '1'
        ? false
        : 'Set LISTENER_TEST_NATIVE_AUDIO=1 on Windows with an audio device.',
  );
}
