import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/music/ffmpeg_audio_processor.dart';

import 'audio_fixture.dart';

void main() {
  final ffmpeg =
      File(Platform.environment['MUSIC_FFMPEG'] ?? 'tools/ffmpeg.exe').absolute;
  final available = ffmpeg.existsSync();

  for (final name in [
    'aac.m4a',
    'opus.webm',
    'vorbis.ogg',
    'video-with-aac.mp4'
  ]) {
    test('normalizes and encodes $name as MP3', () async {
      final root = await Directory.systemTemp.createTemp('music_codec_');
      addTearDown(() => root.delete(recursive: true));
      final input = File('test/music/fixtures/$name').absolute;
      final output = await FfmpegAudioProcessor(executable: ffmpeg.path)
          .normalize(
              input: input,
              stagingDirectory: root,
              duration: const Duration(seconds: 4),
              onProgress: (_) {});
      final measured = await Process.run(ffmpeg.path, [
        '-hide_banner',
        '-nostdin',
        '-i',
        output.path,
        '-af',
        'loudnorm=I=-16:TP=-2:LRA=20:print_format=json',
        '-f',
        'null',
        '-',
      ]);
      expect(measured.exitCode, 0, reason: '${measured.stderr}');
      _expectStereoMp3(output, measured.stderr as String);
      final json = jsonDecode(RegExp(r'\{[^{}]*\}')
          .allMatches('${measured.stderr}')
          .last
          .group(0)!) as Map<String, dynamic>;
      expect(double.parse(json['input_i'] as String), closeTo(-16, .5));
      expect(double.parse(json['input_tp'] as String), lessThanOrEqualTo(-1.5));
    },
        skip:
            available ? false : 'Install tools/ffmpeg.exe or set MUSIC_FFMPEG');
  }

  for (final sample in [
    (name: 'quiet-mono', amplitude: .03, channels: 1, rate: 44100, dynamic: false),
    (name: 'loud-stereo', amplitude: .8, channels: 2, rate: 32000, dynamic: false),
    (name: 'dynamic-stereo', amplitude: .6, channels: 2, rate: 48000, dynamic: true),
    (name: 'peak-limited', amplitude: .6, channels: 2, rate: 48000, dynamic: false),
  ]) {
    test('real FFmpeg normalizes ${sample.name} to LUFS', () async {
      final root = await Directory.systemTemp.createTemp('music real ffmpeg_');
      addTearDown(() => root.delete(recursive: true));
      final processor = FfmpegAudioProcessor(executable: ffmpeg.path);
      final directory = await Directory('${root.path}/${sample.name}').create();
      final input = await writeAudioFixture(
          File('${directory.path}/source.wav'),
          amplitude: sample.amplitude,
          channels: sample.channels,
          sampleRate: sample.rate,
          dynamicVolume: sample.dynamic,
          peaks: sample.name == 'peak-limited');
      final output = await processor.normalize(
          input: input,
          stagingDirectory: directory,
          duration: const Duration(seconds: 12),
          onProgress: (_) {});
      // Measure the decoded MP3, including the effect of lossy encoding.
      final measured = await Process.run(ffmpeg.path, [
        '-hide_banner',
        '-nostdin',
        '-i',
        output.path,
        '-af',
        'loudnorm=I=-16:TP=-2:LRA=20:print_format=json',
        '-f',
        'null',
        '-',
      ]);
      expect(measured.exitCode, 0, reason: '${measured.stderr}');
      _expectStereoMp3(output, measured.stderr as String);
      final json = jsonDecode(RegExp(r'\{[^{}]*\}')
          .allMatches('${measured.stderr}')
          .last
          .group(0)!) as Map<String, dynamic>;
      final lufs = double.parse(json['input_i'] as String);
      final peak = double.parse(json['input_tp'] as String);
      expect(lufs, closeTo(-16, .5), reason: sample.name);
      expect(peak, lessThanOrEqualTo(-1.5), reason: sample.name);
      // ignore: avoid_print
      print('${sample.name}: $lufs LUFS, $peak dBTP');
    },
        skip:
            available ? false : 'Install tools/ffmpeg.exe or set MUSIC_FFMPEG',
        timeout: const Timeout(Duration(minutes: 2)));
  }

  test('real FFmpeg reports silence without attempting an invalid encode',
      () async {
    final root = await Directory.systemTemp.createTemp('music_silence_');
    addTearDown(() => root.delete(recursive: true));
    final input = await writeAudioFixture(File('${root.path}/silence.wav'),
        amplitude: 0, channels: 1, seconds: 2);
    final processor = FfmpegAudioProcessor(executable: ffmpeg.path);
    await expectLater(
        processor.normalize(
            input: input,
            stagingDirectory: root,
            duration: const Duration(seconds: 2),
            onProgress: (_) {}),
        throwsA(isA<AudioProcessingException>()));
    expect(await File('${root.path}/normalized.mp3').exists(), isFalse);
  }, skip: available ? false : 'Install tools/ffmpeg.exe or set MUSIC_FFMPEG');
}

void _expectStereoMp3(File output, String log) {
  final header = log.split('\nStream mapping:').first;
  expect(output.path, endsWith('.mp3'));
  expect(header, contains('Input #0, mp3, from '));
  expect(header,
      matches(RegExp(r'Audio: mp3\b[^\r\n]*?, 48000 Hz, stereo\b')));
  expect(header, isNot(contains('Video:')));
}
