import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/music/ffmpeg_audio_processor.dart';
import 'package:twitch_listener/music/music_file_cache.dart';
import 'package:twitch_listener/music/yt_dlp_music_track_fetcher.dart';

import 'fake_music_process.dart';
import 'fakes.dart';

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

    final processor = FfmpegAudioProcessor(executable: 'fake-ffmpeg');
    final fetcher = YtDlpMusicTrackFetcher(
      executable: 'fake-yt-dlp',
      denoPath: null,
      audioProcessor: processor,
      cache: MusicFileCache(
          rootDirectory: cacheDirectory,
          maxBytes: 0,
          profileName: processor.cacheProfile),
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

  for (final failEncoding in [false, true]) {
    test('download/normalize/cache pipeline (encode fails: $failEncoding)',
        () async {
      final root = await Directory.systemTemp.createTemp('music_pipeline_');
      addTearDown(() => root.delete(recursive: true));
      var downloads = 0;
      var ffmpegCalls = 0;
      final processor = FfmpegAudioProcessor(
          executable: 'ffmpeg',
          processStarter: (_, args) async {
            ffmpegCalls++;
            if (ffmpegCalls.isOdd) {
              return TestAudioProcess.completed(
                  stderr: '{"input_i":"-25","input_tp":"-8","input_lra":"4",'
                      '"input_thresh":"-35","target_offset":"0"}');
            }
            await File(args.last).writeAsBytes([7, 8, 9]);
            return TestAudioProcess.completed(
                exitCode: failEncoding ? 1 : 0,
                stderr: failEncoding ? 'Encoder failed' : '');
          });
      final cache = MusicFileCache(
          rootDirectory: root,
          maxBytes: 0,
          profileName: processor.cacheProfile);
      final fetcher = YtDlpMusicTrackFetcher(
          executable: 'yt-dlp',
          denoPath: null,
          cache: cache,
          audioProcessor: processor,
          processStarter: (_, args) async {
            downloads++;
            final directory = args[args.indexOf('--paths') + 1];
            final original =
                await File('$directory/audio.webm').writeAsBytes([1, 2, 3]);
            return TestAudioProcess.completed(
                stdout: 'YT_FILE:${original.path}\n');
          });
      final track = metadata(Uri.parse(firstUrl));
      if (failEncoding) {
        await expectLater(fetcher.obtain(metadata: track, onProgress: (_) {}),
            throwsA(isA<AudioProcessingException>()));
        expect(
            await root.list(recursive: true).where((e) => e is File).toList(),
            isEmpty);
      } else {
        final first = await fetcher.obtain(metadata: track, onProgress: (_) {});
        final second =
            await fetcher.obtain(metadata: track, onProgress: (_) {});
        expect(first, second);
        expect(await File(first).readAsBytes(), [7, 8, 9]);
        expect(downloads, 1);
        expect(ffmpegCalls, 2);
        expect(
            await root.list(recursive: true).where((e) => e is File).toList(),
            hasLength(1));
      }
    });
  }
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
