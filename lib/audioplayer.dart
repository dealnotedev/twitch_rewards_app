import 'dart:async';

import 'package:minisound/engine.dart' as minisound;
import 'package:minisound/engine_flutter.dart';
import 'package:twitch_listener/observable_value.dart';

class Audioplayer {
  final minisound.Engine engine;

  Audioplayer({required this.engine});

  Future<void> playFileWaitCompletion(String filePath,
      {required ObservableValue<double> volume}) async {
    final source = await engine.loadSoundFile(filePath);

    final duration = source.duration;

    final volumeSub = volume.changes.listen((v) {
      source.volume = v;
    });

    source.volume = volume.current;
    source.play();

    await Future.delayed(duration);

    volumeSub.cancel();
    source.stop();
  }

  Future<PlayToken> playFileInfinitely(String filePath,
      {required ObservableValue<double> volume}) async {
    final source = await engine.loadSoundFile(filePath);

    source.volume = volume.current;
    source.playLooped();

    final volumeSub = volume.changes.listen((v) {
      source.volume = v;
    });

    return PlayToken(handle: source, volumeSub: volumeSub);
  }

  Future<void> cancelByToken(PlayToken token) async {
    token.volumeSub.cancel();
    token.handle.stop();
  }
}

class PlayToken {
  final LoadedSound handle;
  final StreamSubscription<double> volumeSub;

  PlayToken({required this.handle, required this.volumeSub});
}
