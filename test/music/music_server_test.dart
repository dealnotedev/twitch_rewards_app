import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_music_player_protocol/dart_music_player_protocol_io.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/music_server_controller.dart';

import 'fakes.dart';

void main() {
  test('publishes the real Listener queue, preparation phases and playback controls', () async {
    final fetcher = FakeFetcher();
    final player = FakePlayer();
    final manager = MusicRequestManager(
      fetcher: fetcher,
      player: player,
      volume: 0.6,
    );
    final server = MusicServerController(manager, port: 0);
    await server.start();
    expect(server.error, isNull);
    final remote = RemoteMusicRequests(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}'),
      reconnectDelays: const [Duration(milliseconds: 20)],
    );
    addTearDown(() async {
      await remote.close();
      await server.close();
      await manager.close();
    });
    remote.start();
    await until(
      () =>
          remote.currentConnection.phase ==
          MusicControlConnectionPhase.connected,
      label: 'step 1',
    );
    expect(remote.current.volume, 0.6);
    manager.enqueue(firstUrl, requester: 'first');
    await until(() => remote.current.nowPlaying != null, label: 'step 2');
    expect(remote.current.nowPlaying!.item.requestedBy, 'first');

    fetcher.downloadGate = Completer<String>();
    manager.enqueue(secondUrl, requester: 'second');
    await until(() => fetcher.downloaded.length == 2, label: 'step 3');
    fetcher.reportProgress!(
      const MusicPreparationProgress(
        phase: MusicQueueItemPhase.analyzing,
        fraction: 0.4,
      ),
    );
    await until(
      () =>
          remote.current.queue.firstOrNull?.phase ==
          MusicQueueItemPhase.analyzing,
      label: 'step 4',
    );
    expect(remote.current.queue.single.preparationProgress, 0.4);
    fetcher.reportProgress!(
      const MusicPreparationProgress(
        phase: MusicQueueItemPhase.normalizing,
        fraction: 0.7,
      ),
    );
    await until(
      () =>
          remote.current.queue.firstOrNull?.phase ==
          MusicQueueItemPhase.normalizing,
      label: 'step 5',
    );
    fetcher.downloadGate!.complete('second.mp3');
    await until(
      () =>
          remote.current.queue.firstOrNull?.phase == MusicQueueItemPhase.ready,
      label: 'step 6',
    );
    expect(await remote.setPaused(true), isTrue);
    expect(player.paused, isTrue);
    expect(await remote.seek(const Duration(seconds: 23)), isTrue);
    expect(player.sought, const Duration(seconds: 23));
    expect(await remote.remove(remote.current.queue.single.id), isTrue);
    expect(manager.current.queue, isEmpty);
    expect(await remote.skip(), isTrue);
    await until(() => remote.current.nowPlaying == null, label: 'step 7');

    expect(manager.enqueue(firstUrl), isTrue);
    await until(
      () => remote.current.nowPlaying != null,
      label: 'step 8',
      diagnostic: () =>
          'manager revision ${manager.current.revision}, queue ${manager.current.queue.map((i) => i.phase)}, playing ${manager.current.nowPlaying?.item.id}, error ${manager.current.lastError?.details}; remote revision ${remote.current.revision}, connection ${remote.currentConnection.phase}, error ${remote.currentConnection.lastError}',
    );
    final stops = player.stops;
    await server.close();
    await until(
      () =>
          remote.currentConnection.phase ==
          MusicControlConnectionPhase.reconnecting,
      label: 'step 9',
    );
    expect(remote.current.nowPlaying, isNull);
    expect(manager.current.nowPlaying, isNotNull);
    expect(player.stops, stops);
  });

  test(
    'occupied server port reports failure, retries and never stops playback',
    () async {
      final occupied = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final player = FakePlayer();
      final manager = MusicRequestManager(
        fetcher: FakeFetcher(),
        player: player,
      );
      manager.enqueue(firstUrl);
      await until(() => player.played.isNotEmpty, label: 'step 10');
      final server = MusicServerController(manager, port: occupied.port);
      addTearDown(() async {
        await server.close();
        await manager.close();
        await occupied.close(force: true);
      });
      await server.start();
      expect(server.error, isNotNull);
      expect(manager.current.nowPlaying, isNotNull);
      await occupied.close(force: true);
      await server.start();
      expect(server.error, isNull);
      expect(server.port, isNotNull);
      expect(player.stops, 0);
    },
  );
}

Future<void> until(
  bool Function() condition, {
  String label = '',
  String Function()? diagnostic,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'Listener music transport did not settle: $label ${diagnostic?.call()}',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
