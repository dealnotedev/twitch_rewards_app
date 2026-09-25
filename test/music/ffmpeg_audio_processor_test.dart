import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/music/ffmpeg_audio_processor.dart';
import 'package:twitch_listener/music/music_models.dart';

import 'fake_music_process.dart';

const measurements = '''
FFmpeg diagnostic before statistics
{"input_i":"-25.00","input_tp":"-8.00","input_lra":"4.00",
 "input_thresh":"-35.00","target_offset":"0.15"}
''';

void main() {
  late Directory root;
  late File input;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('loudnorm_test_');
    input = await File('${root.path}/source.webm').writeAsBytes([1]);
  });
  tearDown(() => root.delete(recursive: true));

  Future<File> normalize(FfmpegAudioProcessor processor,
          {void Function(MusicPreparationProgress)? onProgress}) =>
      processor.normalize(
        input: input,
        stagingDirectory: root,
        duration: const Duration(seconds: 10),
        onProgress: onProgress ?? (_) {},
      );

  test('measures the input then encodes once with the measured values',
      () async {
    final calls = <List<String>>[];
    final progress = <MusicPreparationProgress>[];
    final processor = FfmpegAudioProcessor(
        executable: 'ffmpeg',
        processStarter: (_, args) async {
          calls.add(args);
          if (calls.length == 2) await File(args.last).writeAsBytes([7, 8]);
          return TestAudioProcess.completed(
              stderr: measurements,
              stdout: 'out_time_us=5000000\nprogress=continue\n');
        });
    final output = await normalize(processor, onProgress: progress.add);
    expect(await output.readAsBytes(), [7, 8]);
    expect(calls, hasLength(2));
    expect(calls.first, containsAllInOrder(['-f', 'null', '-']));
    final filter = calls.last[calls.last.indexOf('-af') + 1];
    expect(filter, contains('measured_I=-25.0'));
    expect(filter, contains('measured_TP=-8.0'));
    expect(filter, contains('measured_LRA=4.0'));
    expect(filter, contains('measured_thresh=-35.0'));
    expect(filter, contains('offset=0.15:linear=true'));
    expect(calls.last,
        containsAllInOrder(['-ar', '48000', '-ac', '2', '-c:a', 'libmp3lame']));
    expect(
        progress.map((p) => p.phase),
        containsAllInOrder([
          MusicQueueItemPhase.analyzing,
          MusicQueueItemPhase.normalizing,
        ]));
    expect(progress.where((p) => p.fraction == .5), hasLength(2));
  });

  for (final stats in [
    'not JSON',
    '{"input_i":"-inf"}',
    measurements.replaceFirst('-25.00', 'NaN'),
    measurements.replaceFirst('-25.00', '-120.0'),
  ]) {
    test('rejects missing, silent or invalid measurements: $stats', () async {
      var starts = 0;
      final processor = FfmpegAudioProcessor(
          executable: 'ffmpeg',
          processStarter: (_, __) async {
            starts++;
            return TestAudioProcess.completed(stderr: stats);
          });
      await expectLater(
          normalize(processor), throwsA(isA<AudioProcessingException>()));
      expect(starts, 1);
      expect(await File('${root.path}/normalized.mp3').exists(), isFalse);
    });
  }

  test('cancel between passes prevents encoding from starting', () async {
    var starts = 0;
    Future<void>? cancellation;
    late FfmpegAudioProcessor processor;
    processor = FfmpegAudioProcessor(
        executable: 'ffmpeg',
        processStarter: (_, __) async {
          starts++;
          return TestAudioProcess.completed(stderr: measurements);
        });
    await expectLater(
        normalize(processor, onProgress: (p) {
          if (p.phase == MusicQueueItemPhase.normalizing) {
            cancellation = processor.cancel();
          }
        }),
        throwsA(isA<AudioProcessingException>()));
    await cancellation;
    expect(starts, 1);
  });

  test(
      'cancel while process creation is pending kills it and prevents encoding',
      () async {
    final starting = Completer<Process>();
    final started = Completer<void>();
    final processor = FfmpegAudioProcessor(
        executable: 'ffmpeg',
        processStarter: (_, __) {
          started.complete();
          return starting.future;
        });
    final processing = expectLater(
        normalize(processor), throwsA(isA<AudioProcessingException>()));
    await started.future;
    final canceled = processor.cancel();
    final process = TestAudioProcess();
    starting.complete(process);
    await canceled;
    await processing;
    expect(process.killed, isTrue);
  });

  test('timeout terminates the process and releases the processor for retry',
      () async {
    final process = TestAudioProcess();
    var starts = 0;
    final processor = FfmpegAudioProcessor(
        executable: 'ffmpeg',
        passTimeout: const Duration(milliseconds: 20),
        processStarter: (_, args) async {
          starts++;
          if (starts == 1) return process;
          if (starts == 3) await File(args.last).writeAsBytes([1]);
          return TestAudioProcess.completed(stderr: measurements);
        });
    await expectLater(
        normalize(processor),
        throwsA(isA<AudioProcessingException>()
            .having((e) => e.message, 'message', contains('timed out'))));
    expect(process.killed, isTrue);
    expect(await (await normalize(processor)).exists(), isTrue);
  });

  test('failed encode never returns a partially written output', () async {
    var starts = 0;
    final processor = FfmpegAudioProcessor(
        executable: 'ffmpeg',
        processStarter: (_, args) async {
          if (++starts == 1) {
            return TestAudioProcess.completed(stderr: measurements);
          }
          await File(args.last).writeAsBytes([1]);
          return TestAudioProcess.completed(
              stderr: 'Encoder failed', exitCode: 1);
        });
    await expectLater(
        normalize(processor),
        throwsA(isA<AudioProcessingException>()
            .having((e) => e.message, 'message', contains('Encoder failed'))));
  });

  test('missing executable produces an actionable error', () async {
    final processor = FfmpegAudioProcessor(
        executable: 'missing-ffmpeg',
        processStarter: (exe, args) =>
            throw ProcessException(exe, args, 'Not found'));
    await expectLater(
        normalize(processor),
        throwsA(isA<AudioProcessingException>()
            .having((e) => e.message, 'message', contains('tools folder'))));
  });
}
