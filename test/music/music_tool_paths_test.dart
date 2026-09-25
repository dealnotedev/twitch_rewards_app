import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:twitch_listener/music/music_tool_paths.dart';

void main() {
  test('prefers bundled FFmpeg tools and otherwise resolves through PATH',
      () async {
    final root = await Directory.systemTemp.createTemp('music_tools_');
    addTearDown(() => root.delete(recursive: true));
    final unbundled = MusicToolPaths.resolve(executableDirectory: root);
    expect(unbundled.ffmpegExecutable, 'ffmpeg.exe');
    final tools = await Directory(p.join(root.path, 'tools')).create();
    await File(p.join(tools.path, 'ffmpeg.exe')).writeAsBytes([1]);
    final bundled = MusicToolPaths.resolve(executableDirectory: root);
    expect(bundled.ffmpegExecutable, p.join(tools.path, 'ffmpeg.exe'));
  });
}
