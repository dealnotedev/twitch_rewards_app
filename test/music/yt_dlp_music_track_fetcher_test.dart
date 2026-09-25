import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/music/music_file_cache.dart';
import 'package:twitch_listener/music/yt_dlp_music_track_fetcher.dart';

void main() {
  test('requests UTF-8 output from yt-dlp', () async {
    final cacheDirectory = await Directory.systemTemp.createTemp(
      'yt_dlp_encoding_test_',
    );
    addTearDown(() async {
      if (await cacheDirectory.exists()) {
        await cacheDirectory.delete(recursive: true);
      }
    });

    final fetcher = YtDlpMusicTrackFetcher(
      executable: 'fake-yt-dlp',
      denoPath: null,
      cache: MusicFileCache(rootDirectory: cacheDirectory, maxBytes: 0),
      processStarter: (_, arguments) async {
        final encodingIndex = arguments.indexOf('--encoding');
        final utf8Requested = encodingIndex >= 0 &&
            encodingIndex + 1 < arguments.length &&
            arguments[encodingIndex + 1].toLowerCase() == 'utf-8';
        return _FakeProcess(_metadataBytes(utf8Requested: utf8Requested));
      },
    );

    final metadata = await fetcher.inspect(Uri.parse('https://youtu.be/video'));

    expect(metadata.title, 'A–B');
  });
}

List<int> _metadataBytes({required bool utf8Requested}) {
  const prefix = '{"id":"video","title":"A';
  const suffix = 'B","uploader":"Artist","duration":60,'
      '"webpage_url":"https://youtu.be/video"}';
  return [
    ...ascii.encode(prefix),
    ...(utf8Requested ? utf8.encode('–') : const [0x96]),
    ...ascii.encode(suffix),
  ];
}

class _FakeProcess implements Process {
  final List<int> output;

  const _FakeProcess(this.output);

  @override
  Future<int> get exitCode async => 0;

  @override
  int get pid => 1;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  IOSink get stdin => throw UnsupportedError('stdin is unused');

  @override
  Stream<List<int>> get stdout => Stream.value(output);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}
