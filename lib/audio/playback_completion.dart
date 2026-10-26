import 'package:media_kit/media_kit.dart';

/// Make native completion wait for the audio output buffer to drain.
/// Each finite playback owns its player, so gapless EOF would let disposal
/// discard audio that is still queued on the output device.
Future<void> configureAudioCompletion(Player player) async {
  final native = player.platform;
  if (native is NativePlayer) {
    await native.setProperty('gapless-audio', 'no');
  }
}
