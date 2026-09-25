import 'dart:io';

import 'package:path/path.dart' as p;

class MusicToolPaths {
  final String ytDlpExecutable;
  final String? denoPath;

  const MusicToolPaths({required this.ytDlpExecutable, required this.denoPath});

  factory MusicToolPaths.resolve({required Directory executableDirectory}) {
    final toolsDirectory = p.join(executableDirectory.path, 'tools');
    String? bundled(String name) {
      final candidate = p.join(toolsDirectory, name);
      return File(candidate).existsSync() ? candidate : null;
    }

    return MusicToolPaths(
      ytDlpExecutable: bundled('yt-dlp.exe') ?? 'yt-dlp.exe',
      denoPath: bundled('deno.exe'),
    );
  }
}
