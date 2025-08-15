import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:twitch_listener/observable_value.dart';

class Audioplayer {
  final SoLoud soloud;

  Audioplayer({required this.soloud});

  Future<void> playFileWaitCompletion(String filePath,
      {required ObservableValue<double> volume}) async {
    final source = await soloud.loadFile(filePath);

    final duration = soloud.getLength(source);
    final handle = await soloud.play(source, volume: volume.current);

    final volumeSub = volume.changes.listen((v) {
      soloud.setVolume(handle, v);
    });

    await Future.delayed(duration);

    volumeSub.cancel();
    await soloud.stop(handle);
  }

  Future<PlayToken> playFileInfinitely(String filePath,
      {required ObservableValue<double> volume}) async {
    final source = await soloud.loadFile(filePath);
    final handle =
        await soloud.play(source, volume: volume.current, looping: true);

    final volumeSub = volume.changes.listen((v) {
      soloud.setVolume(handle, v);
    });

    return PlayToken(handle: handle, volumeSub: volumeSub);
  }

  Future<void> cancelByToken(PlayToken token) {
    token.volumeSub.cancel();
    return soloud.stop(token.handle);
  }
}

class PlayToken {
  final SoundHandle handle;
  final StreamSubscription<double> volumeSub;

  PlayToken({required this.handle, required this.volumeSub});
}
