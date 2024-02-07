import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// https://github.com/ryanheise/just_audio/blob/master/just_audio/lib/just_audio.dart
class AudioPlayer {
  Future<Uri> loadAsset(String assetPath) async {
    if (kIsWeb) {
      // Mapping from extensions to content types for the web player. If an
      // extension is missing, please submit a pull request.
      const mimeTypes = {
        '.aac': 'audio/aac',
        '.mp3': 'audio/mpeg',
        '.ogg': 'audio/ogg',
        '.opus': 'audio/opus',
        '.wav': 'audio/wav',
        '.weba': 'audio/webm',
        '.mp4': 'audio/mp4',
        '.m4a': 'audio/mp4',
        '.aif': 'audio/x-aiff',
        '.aifc': 'audio/x-aiff',
        '.aiff': 'audio/x-aiff',
        '.m3u': 'audio/x-mpegurl',
      };
      // Default to 'audio/mpeg'
      final mimeType =
          mimeTypes[p.extension(assetPath).toLowerCase()] ?? 'audio/mpeg';
      return _encodeDataUrl(
          base64
              .encode((await rootBundle.load(assetPath)).buffer.asUint8List()),
          mimeType);
    } else {
      // For non-web platforms, extract the asset into a cache file and pass
      // that to the player.
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
  }

  Uri _encodeDataUrl(String base64Data, String mimeType) =>
      Uri.parse('data:$mimeType;base64,$base64Data');

  /// Get file for caching asset media with proper extension
  Future<File> _getCacheFile(final String assetPath) async => File(p.joinAll([
        (await _getCacheDir()).path,
        'assets',
        ...Uri.parse(assetPath).pathSegments,
      ]));

  Future<Directory> _getCacheDir() async => Directory(
      p.join((await getTemporaryDirectory()).path, 'audio_cache'));
}
