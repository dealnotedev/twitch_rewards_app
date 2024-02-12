import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart';

class RingtoneUtils {
  static void play(String asset, {bool loop = false}) async {
    if (Platform.isWindows) {
      final uri = await loadAsset(asset);

      if (loop) {
        PlaySound(TEXT(File.fromUri(uri).path), NULL,
            SND_FILENAME | SND_ASYNC | SND_LOOP);
      } else {
        PlaySound(TEXT(File.fromUri(uri).path), NULL, SND_FILENAME | SND_ASYNC);
      }
    }
  }

  static void playFile(String path, {bool loop = false}) {
    if (Platform.isWindows) {
      if (loop) {
        PlaySound(TEXT(path), NULL, SND_FILENAME | SND_ASYNC | SND_LOOP);
      } else {
        PlaySound(TEXT(path), NULL, SND_FILENAME | SND_ASYNC);
      }
    }
  }

  static void pause() async {
    if (Platform.isWindows) {
      PlaySound(Pointer.fromAddress(0), 0, 0);
    }
  }

  static Future<Uri> loadAsset(String assetPath) async {
    final file = await _getCacheFile(assetPath);
    // Not technically inter-isolate-safe, although low risk. Could consider
    // locking the file or creating a separate lock file.
    if (!file.existsSync()) {
      file.createSync(recursive: true);
      await file.writeAsBytes(
          (await rootBundle.load(assetPath)).buffer.asUint8List());
    }
    return Uri.file(file.path);
  }

  /// Get file for caching asset media with proper extension
  static Future<File> _getCacheFile(final String assetPath) async =>
      File(p.joinAll([
        (await _getCacheDir()).path,
        'assets',
        ...Uri.parse(assetPath).pathSegments,
      ]));

  static Future<Directory> _getCacheDir() async =>
      Directory(p.join((await getTemporaryDirectory()).path, 'audio_cache'));
}
