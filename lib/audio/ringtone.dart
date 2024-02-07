import 'dart:ffi';
import 'dart:io';

import 'package:twitch_listener/audio/audio_utils.dart';
import 'package:win32/win32.dart';

class RingtoneUtils {
  static void play(String asset, bool loop) async {
    if (Platform.isWindows) {
      final uri = await AudioPlayer().loadAsset(asset);

      if (loop) {
        PlaySound(TEXT(File.fromUri(uri).path), NULL,
            SND_FILENAME | SND_ASYNC | SND_LOOP);
      } else {
        PlaySound(TEXT(File.fromUri(uri).path), NULL, SND_FILENAME | SND_ASYNC);
      }
    }
  }

  static void pause() async {
    if (Platform.isWindows) {
      PlaySound(Pointer.fromAddress(0), 0, 0);
    }
  }
}