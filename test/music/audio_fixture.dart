import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Generate PCM locally so the shipped FFmpeg needs no signal generators,
/// WAV encoder, device support or lavfi input solely for tests.
Future<File> writeAudioFixture(
  File file, {
  double amplitude = .2,
  int channels = 2,
  int seconds = 12,
  int sampleRate = 48000,
  bool dynamicVolume = false,
  bool peaks = false,
}) async {
  final frames = seconds * sampleRate;
  final dataBytes = frames * channels * 4;
  final data = ByteData(44 + dataBytes);
  void tag(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, dataBytes + 36, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 3, Endian.little); // IEEE float PCM
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * channels * 4, Endian.little);
  data.setUint16(32, channels * 4, Endian.little);
  data.setUint16(34, 32, Endian.little);
  tag(36, 'data');
  data.setUint32(40, dataBytes, Endian.little);
  final random = Random(42);
  for (var frame = 0; frame < frames; frame++) {
    final t = frame / sampleRate;
    final value = peaks
        ? .02 * sin(2 * pi * 440 * t) +
            (frame % sampleRate < sampleRate ~/ 1000 ? .8 : 0)
        : amplitude *
            (dynamicVolume && t < seconds / 2 ? .1 : 1) *
            (.5 * sin(2 * pi * 440 * t) +
                .2 * sin(2 * pi * 1000 * t) +
                .1 * (random.nextDouble() * 2 - 1));
    for (var channel = 0; channel < channels; channel++) {
      data.setFloat32(
          44 + (frame * channels + channel) * 4, value, Endian.little);
    }
  }
  return file.writeAsBytes(data.buffer.asUint8List());
}
