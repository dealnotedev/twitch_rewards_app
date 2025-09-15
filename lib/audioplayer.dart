import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:twitch_listener/observable_value.dart';

class Audioplayer {
  Audioplayer();

  Future<void> playFileWaitCompletion(String filePath,
      {required ObservableValue<double> volume,
      String title = 'Twitch Listener'}) async {
    final player = Player(configuration: PlayerConfiguration(title: title));
    final media = Media(filePath);

    await player.setPlaylistMode(PlaylistMode.none);
    await player.setVolume(volume.current * 100.0);
    await player.open(media);

    final volumeSub = volume.changes.listen((v) {
      player.setVolume(volume.current * 100.0);
    });

    await player.stream.completed.where((t) => t).first;

    volumeSub.cancel();
    await player.stop();
    await player.dispose();
  }

  Future<PlayToken> playFileInfinitely(String filePath,
      {required ObservableValue<double> volume,
      String title = 'Twitch Listener'}) async {
    final player = Player(configuration: PlayerConfiguration(title: title));
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
