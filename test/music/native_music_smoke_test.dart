import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:twitch_listener/music/media_kit_music_track_player.dart';
import 'package:twitch_listener/music/music_models.dart';

/// Optional real-backend check; regular tests use deterministic fake players.
/// MUSIC_SMOKE_FILE points at a short local track, MUSIC_MPV_LIBRARY at libmpv.
void main() {
  final file = Platform.environment['MUSIC_SMOKE_FILE'];
  test('native media_kit decodes original audio, pauses, seeks and completes',
      () async {
    MediaKit.ensureInitialized(
        libmpv: Platform.environment['MUSIC_MPV_LIBRARY']);
    final player = MediaKitMusicTrackPlayer();
    addTearDown(player.stop);
    final progressed = Completer<void>();
    final track = DownloadedMusicTrack(
        itemId: 'smoke',
        requestedBy: '',
        metadata: MusicTrackMetadata(
            videoId: 'smoke',
            title: 'Native playback test',
            author: '',
            duration: const Duration(seconds: 19),
            thumbnail: null,
            sourceUrl:
                Uri.parse('https://www.youtube.com/watch?v=jNQXAC9IVRw')),
        filePath: file!);
    final playback = player.play(track, volume: 0, onPosition: (position) {
      if (position > Duration.zero && !progressed.isCompleted)
        progressed.complete();
    });
    await progressed.future.timeout(const Duration(seconds: 10));
    await player.setPaused(true);
    await player.seek(const Duration(seconds: 16));
    await player.setVolume(0);
    await player.setPaused(false);
    await playback.timeout(const Duration(seconds: 15));
  },
      skip: file == null
          ? 'Set MUSIC_SMOKE_FILE for a real native playback check'
          : false);
}
