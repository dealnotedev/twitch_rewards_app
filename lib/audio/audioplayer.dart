import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:twitch_listener/core/observable_value.dart';

import 'playback_completion.dart';

class Audioplayer {
  final Player Function(PlayerConfiguration configuration) _createPlayer;

  Audioplayer({
    Player Function(PlayerConfiguration configuration)? createPlayer,
  }) : _createPlayer =
           createPlayer ??
           ((configuration) => Player(configuration: configuration));

  Future<void> playFileWaitCompletion(
    String filePath, {
    required ObservableValue<double> volume,
    String title = 'Twitch Listener',
  }) async {
    final player = _createPlayer(PlayerConfiguration(title: title));
    final media = Media(filePath);
    final done = Completer<void>();
    final finished = done.future;
    unawaited(finished.catchError((Object _) {}));
    final completeSub = player.stream.completed.listen((completed) {
      if (completed && !done.isCompleted) done.complete();
    });
    final errorSub = player.stream.error.listen((error) {
      if (error.isNotEmpty && !done.isCompleted) {
        done.completeError(StateError(error));
      }
    });
    final volumeSub = volume.changes.listen((v) {
      player.setVolume(v * 100.0).catchError((Object error, StackTrace stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      });
    });
    try {
      await player.setPlaylistMode(PlaylistMode.none);
      await configureAudioCompletion(player);
      await player.setVolume(volume.current * 100.0);
      await player.open(media);
      await finished;
    } finally {
      await completeSub.cancel();
      await errorSub.cancel();
      await volumeSub.cancel();
      await player.dispose();
    }
  }

  Future<PlayToken> playFileInfinitely(
    String filePath, {
    required ObservableValue<double> volume,
    String title = 'Twitch Listener',
  }) async {
    final player = _createPlayer(PlayerConfiguration(title: title));
    final media = Media(filePath);

    await player.setPlaylistMode(PlaylistMode.single);
    await player.setVolume(volume.current * 100.0);
    await player.open(media);

    final volumeSub = volume.changes.listen((v) {
      player.setVolume(volume.current * 100.0);
    });

    return PlayToken(handle: player, volumeSub: volumeSub);
  }

  Future<void> cancelByToken(PlayToken token) async {
    token.volumeSub.cancel();
    token.handle.stop();
    token.handle.dispose();
  }
}

class PlayToken {
  final Player handle;
  final StreamSubscription<double> volumeSub;

  PlayToken({required this.handle, required this.volumeSub});
}
