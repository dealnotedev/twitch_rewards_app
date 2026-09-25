import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/music/music_requests.dart';

import 'fakes.dart';

void main() {
  late FakeFetcher fetcher;
  late FakePlayer player;
  late MusicRequestManager manager;

  setUp(() {
    fetcher = FakeFetcher();
    player = FakePlayer();
    manager = MusicRequestManager(fetcher: fetcher, player: player);
  });
  tearDown(() => manager.close());

  test('normalizes video links and drops playlist and timestamp parameters',
      () {
    for (final url in [
      'youtu.be/aaaaaaaaaaa?t=30',
      '//music.youtube.com/watch?v=aaaaaaaaaaa&list=PL123',
      'https://youtube.com/shorts/aaaaaaaaaaa',
      'https://m.youtube.com/embed/aaaaaaaaaaa',
    ]) {
      expect(MusicRequestManager.parseYoutubeUrl(url).toString(), firstUrl);
    }
    for (final url in [
      '',
      'https://youtube.com/playlist?list=123',
      'https://youtube.com.evil.test/watch?v=aaaaaaaaaaa',
      'https://evil.test/aaaaaaaaaaa',
      'file:///tmp/audio.mp3',
      'https://user@youtube.com/watch?v=aaaaaaaaaaa',
      'https://youtube.com:8080/watch?v=aaaaaaaaaaa',
      '--exec calc',
      'https://youtu.be/short'
    ]) {
      expect(MusicRequestManager.parseYoutubeUrl(url), isNull, reason: url);
    }
  });

  test('enqueues immediately, preserves FIFO and advances on completion',
      () async {
    fetcher.inspectGate = Completer();
    expect(manager.enqueue(firstUrl, requester: 'Viewer A'), isTrue);
    expect(manager.enqueue(secondUrl, requester: 'Viewer B'), isTrue);
    expect(manager.current.queue, hasLength(2));
    expect(player.played, isEmpty);
    await flush();
    fetcher.inspectGate!.complete(metadata(Uri.parse(firstUrl)));
    await flush();
    expect(player.played.single.requestedBy, 'Viewer A');
    expect(manager.current.queue.single.requestedBy, 'Viewer B');
    expect(manager.current.queue.single.phase, MusicQueueItemPhase.ready);
    player.finish();
    await flush();
    expect(player.played.last.requestedBy, 'Viewer B');
    expect(manager.current.queue, isEmpty);
    player.finish();
    await flush();
    expect(manager.current.nowPlaying, isNull);
  });

  test('a new request never interrupts a paused active track', () async {
    manager.enqueue(firstUrl);
    await flush();
    await manager.setPaused(true);
    manager.enqueue(secondUrl);
    await flush();
    expect(player.played, hasLength(1));
    expect(manager.current.nowPlaying!.paused, isTrue);
    expect(player.paused, isTrue);
    expect(manager.current.queue, hasLength(1));
  });

  test('skip at the moment playback becomes active does not lose the command',
      () async {
    var skipped = false;
    final sub = manager.states.listen((s) {
      if (!skipped && s.nowPlaying?.item.requestedBy == 'first') {
        skipped = true;
        manager.skip();
      }
    });
    addTearDown(sub.cancel);
    manager.enqueue(firstUrl, requester: 'first');
    manager.enqueue(secondUrl, requester: 'second');
    await flush();
    expect(player.played, hasLength(2));
    expect(manager.current.nowPlaying!.item.requestedBy, 'second');
    expect(player.stops, 1);
  });

  test('overlapping skip commands only skip one track', () async {
    manager.enqueue(firstUrl);
    manager.enqueue(secondUrl);
    await flush();
    await Future.wait([manager.skip(), manager.skip()]);
    await flush();
    expect(player.played, hasLength(2));
    expect(player.stops, 1);
    expect(manager.current.nowPlaying, isNotNull);
  });

  test('failed metadata, download and playback do not wedge the queue',
      () async {
    fetcher.inspectError = StateError('Metadata failure');
    manager.enqueue(firstUrl);
    manager.enqueue(secondUrl);
    await flush();
    expect(player.played.single.metadata.videoId, 'bbbbbbbbbbb');
    expect(manager.current.lastError!.details, contains('Metadata failure'));
    fetcher.downloadError = StateError('Download failure');
    manager.enqueue(firstUrl);
    manager.enqueue(secondUrl);
    await flush();
    player.finish(StateError('Playback failure'));
    await flush();
    expect(player.played, hasLength(2));
    expect(manager.current.lastError!.details, contains('Playback failure'));
  });

  test('rejects missing input and oversized tracks before download', () async {
    expect(manager.enqueue(null), isFalse);
    expect(
        manager.current.lastError!.type, MusicQueueErrorType.missingYoutubeUrl);
    expect(fetcher.inspected, isEmpty);
    fetcher.duration = const Duration(minutes: 11);
    manager.enqueue(firstUrl);
    await flush();
    expect(fetcher.downloaded, isEmpty);
    expect(manager.current.queue, isEmpty);
    expect(manager.current.lastError!.type,
        MusicQueueErrorType.trackTooLongOrLive);
  });

  test('queue limit counts resolving and active requests', () async {
    await manager.close();
    manager = MusicRequestManager(
        fetcher: fetcher, player: player, maxQueueLength: 2);
    manager.enqueue(firstUrl);
    await flush();
    expect(manager.enqueue(secondUrl), isTrue);
    expect(manager.enqueue(firstUrl), isFalse);
    expect(manager.current.lastError!.type, MusicQueueErrorType.queueFull);
  });

  test('removing a downloading request cancels it and starts the next',
      () async {
    fetcher.downloadGate = Completer();
    manager.enqueue(firstUrl);
    manager.enqueue(secondUrl);
    await flush();
    final first = manager.current.queue.first;
    expect(first.phase, MusicQueueItemPhase.downloading);
    expect(first.downloadProgress, .25);
    await manager.remove(first.id);
    await flush();
    expect(fetcher.cancellations, 1);
    expect(player.played.single.metadata.videoId, 'bbbbbbbbbbb');
    expect(manager.current.lastError, isNull);
  });

  test('position comes from playback, and seeks clamp to track bounds',
      () async {
    manager.enqueue(firstUrl);
    await flush();
    player.onPosition!(const Duration(seconds: 7));
    expect(manager.current.nowPlaying!.position, const Duration(seconds: 7));
    await manager.seek(const Duration(minutes: 20));
    expect(player.sought, const Duration(minutes: 3));
    await manager.seek(const Duration(seconds: -1));
    expect(player.sought, Duration.zero);
  });

  test('music volume is clamped, persisted and inherited by later tracks',
      () async {
    await manager.close();
    final saved = <double>[];
    manager = MusicRequestManager(
        fetcher: fetcher,
        player: player,
        volume: .42,
        saveVolume: (v) async {
          saved.add(v);
        });
    manager.enqueue(firstUrl);
    await flush();
    expect(player.volume, .42);
    await manager.setVolume(.25, persist: true);
    expect(player.volume, .25);
    manager.enqueue(secondUrl);
    await flush();
    player.finish();
    await flush();
    expect(player.volume, .25);
    await manager.setVolume(2, persist: true);
    await manager.setVolume(double.nan);
    expect(manager.current.volume, 1);
    expect(saved, [.25, 1]);
  });

  test('a failed skip is visible and can be retried', () async {
    manager.enqueue(firstUrl);
    await flush();
    player.stopError = StateError('Stop failed');
    expect(await manager.skip(), isFalse);
    expect(manager.current.lastError!.details, contains('Stop failed'));
    expect(await manager.skip(), isTrue);
    await flush();
    expect(manager.current.nowPlaying, isNull);
  });

  test('close cancels preparation and playback and ignores subsequent requests',
      () async {
    manager.enqueue(firstUrl);
    await flush();
    fetcher.inspectGate = Completer();
    manager.enqueue(secondUrl);
    await flush();
    await manager.close();
    expect(player.stops, 1);
    expect(manager.enqueue(firstUrl), isFalse);
    expect(player.played, hasLength(1));
    await manager.close();
    expect(player.stops, 1);
  });
}
