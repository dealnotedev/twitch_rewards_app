import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/music/music_file_cache.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('music_file_cache_test_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('reuses a completed file for the same YouTube video ID', () async {
    final cache = MusicFileCache(rootDirectory: root, maxBytes: 0);
    var producerCalls = 0;

    Future<File> produce(Directory stagingDirectory) async {
      producerCalls++;
      return _writeFile(stagingDirectory, [1, 2, 3]);
    }

    final first = await cache.obtain(videoId: 'same-video', produce: produce);
    final second = await cache.obtain(videoId: 'same-video', produce: produce);

    expect(second, first);
    expect(producerCalls, 1);
    expect(await File(first).readAsBytes(), [1, 2, 3]);
    expect(first, endsWith('${Platform.pathSeparator}same-video.media'));
  });

  test('does not publish a failed production attempt', () async {
    final cache = MusicFileCache(rootDirectory: root, maxBytes: 0);

    await expectLater(
      cache.obtain(
        videoId: 'retry-video',
        produce: (stagingDirectory) async {
          await _writeFile(stagingDirectory, [1]);
          throw StateError('download failed');
        },
      ),
      throwsStateError,
    );

    var retryCalls = 0;
    final path = await cache.obtain(
      videoId: 'retry-video',
      produce: (stagingDirectory) async {
        retryCalls++;
        return _writeFile(stagingDirectory, [4, 5]);
      },
    );

    expect(retryCalls, 1);
    expect(await File(path).readAsBytes(), [4, 5]);
  });

  test('prunes the least recently used entry on the next session', () async {
    final seedCache = MusicFileCache(rootDirectory: root, maxBytes: 0);
    final olderPath = await seedCache.obtain(
      videoId: 'older-video',
      produce: (directory) => _writeFile(directory, [1, 2, 3]),
    );
    final newerPath = await seedCache.obtain(
      videoId: 'newer-video',
      produce: (directory) => _writeFile(directory, [4, 5, 6]),
    );
    await File(olderPath).setLastModified(DateTime(2026));
    await File(newerPath).setLastModified(DateTime(2026, 1, 2));

    final limitedCache = MusicFileCache(rootDirectory: root, maxBytes: 3);
    var producerCalls = 0;
    final cachedPath = await limitedCache.obtain(
      videoId: 'newer-video',
      produce: (directory) async {
        producerCalls++;
        return _writeFile(directory, [7, 8, 9]);
      },
    );

    expect(cachedPath, newerPath);
    expect(producerCalls, 0);
    expect(await File(olderPath).exists(), isFalse);
    expect(await File(newerPath).exists(), isTrue);
  });

  test('rejects a video ID that is unsafe for a file name', () async {
    final cache = MusicFileCache(rootDirectory: root, maxBytes: 0);

    await expectLater(
      cache.obtain(
        videoId: '../outside',
        produce: (directory) => _writeFile(directory, [1]),
      ),
      throwsArgumentError,
    );
  });

  test(
      'processing profiles never reuse the original or differently encoded file',
      () async {
    final native = MusicFileCache(rootDirectory: root, maxBytes: 0);
    final normalized = MusicFileCache(
        rootDirectory: root, maxBytes: 0, profileName: 'loudnorm-v1-i-16');
    final changed = MusicFileCache(
        rootDirectory: root, maxBytes: 0, profileName: 'loudnorm-v1-i-18');
    final original = await native.obtain(
        videoId: 'video', produce: (d) => _writeFile(d, [1]));
    final first = await normalized.obtain(
        videoId: 'video', produce: (d) => _writeFile(d, [2]));
    final second = await changed.obtain(
        videoId: 'video', produce: (d) => _writeFile(d, [3]));
    expect({original, first, second}, hasLength(3));
    expect(await File(first).readAsBytes(), [2]);
  });

  test('cancellation after production prevents publishing and cleans staging',
      () async {
    var canceled = false;
    final cache = MusicFileCache(rootDirectory: root, maxBytes: 0);
    await expectLater(
        cache.obtain(
            videoId: 'canceled',
            checkCanceled: () {
              if (canceled) throw StateError('Canceled');
            },
            produce: (d) async {
              final file = await _writeFile(d, [1]);
              canceled = true;
              return file;
            }),
        throwsStateError);
    expect(await root.list(recursive: true).where((e) => e is File).toList(),
        isEmpty);
  });
}

Future<File> _writeFile(Directory directory, List<int> bytes) async {
  final file = File('${directory.path}${Platform.pathSeparator}produced.media');
  await file.writeAsBytes(bytes);
  return file;
}
