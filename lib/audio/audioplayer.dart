import 'dart:async';

import 'package:twitch_listener/core/observable_value.dart';

import 'soloud_audio.dart';

class Audioplayer {
  Audioplayer({SoloudAudio? audio}) : _audio = audio ?? SoloudAudio.shared;

  final SoloudAudio _audio;

  Future<void> playFileWaitCompletion(
    String filePath, {
    required ObservableValue<double> volume,
    String title = 'Twitch Listener',
  }) async {
    final token = await _play(filePath, volume);
    try {
      await token._playback.completed;
    } finally {
      await cancelByToken(token);
    }
  }

  Future<PlayToken> playFileInfinitely(
    String filePath, {
    required ObservableValue<double> volume,
    String title = 'Twitch Listener',
  }) => _play(filePath, volume, looping: true);

  Future<PlayToken> _play(
    String filePath,
    ObservableValue<double> volume, {
    bool looping = false,
  }) async {
    final playback = await _audio.playFile(
      filePath,
      volume: volume.current,
      looping: looping,
    );
    final subscription = volume.changes.listen(playback.setVolume);
    final token = PlayToken._(playback, subscription);
    try {
      playback.setVolume(volume.current);
      playback.setPaused(false);
      return token;
    } catch (_) {
      await cancelByToken(token);
      rethrow;
    }
  }

  Future<void> cancelByToken(PlayToken token) async {
    await token._volumeSubscription.cancel();
    await token._playback.close();
  }
}

class PlayToken {
  final SoloudPlayback _playback;
  final StreamSubscription<double> _volumeSubscription;

  PlayToken._(this._playback, this._volumeSubscription);
}
