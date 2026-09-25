import 'dart:async';

import 'package:twitch_listener/music/music_models.dart';
import 'package:twitch_listener/music/music_track_player.dart';

const firstUrl = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
const secondUrl = 'https://youtu.be/bbbbbbbbbbb';

MusicTrackMetadata metadata(Uri url,
        {Duration duration = const Duration(minutes: 3)}) =>
    MusicTrackMetadata(
        videoId: url.queryParameters['v'] ?? 'aaaaaaaaaaa',
        title: 'Track ${url.queryParameters['v']}',
        author: 'Artist',
        duration: duration,
        thumbnail: null,
        sourceUrl: url);

class FakeFetcher implements MusicTrackFetcher {
  final inspected = <Uri>[];
  final downloaded = <String>[];
  Completer<MusicTrackMetadata>? inspectGate;
  Completer<String>? downloadGate;
  Object? inspectError;
  Object? downloadError;
  Duration duration = const Duration(minutes: 3);
  int cancellations = 0;
  void Function(MusicPreparationProgress)? reportProgress;

  @override
  Future<MusicTrackMetadata> inspect(Uri url) async {
    inspected.add(url);
    final error = inspectError;
    inspectError = null;
    if (error != null) throw error;
    final gate = inspectGate;
    if (gate != null) {
      try {
        return await gate.future;
      } finally {
        if (inspectGate == gate) inspectGate = null;
      }
    }
    return metadata(url, duration: duration);
  }

  @override
  Future<String> obtain(
      {required MusicTrackMetadata metadata,
      required void Function(MusicPreparationProgress) onProgress}) async {
    downloaded.add(metadata.videoId);
    reportProgress = onProgress;
    onProgress(const MusicPreparationProgress(
        phase: MusicQueueItemPhase.downloading, fraction: .25));
    final error = downloadError;
    downloadError = null;
    if (error != null) throw error;
    final gate = downloadGate;
    if (gate != null) {
      try {
        return await gate.future;
      } finally {
        if (downloadGate == gate) downloadGate = null;
      }
    }
    return '${metadata.videoId}.media';
  }

  @override
  Future<void> cancel() async {
    cancellations++;
    if (inspectGate != null && !inspectGate!.isCompleted) {
      inspectGate!.completeError(StateError('Canceled'));
    }
    if (downloadGate != null && !downloadGate!.isCompleted) {
      downloadGate!.completeError(StateError('Canceled'));
    }
  }
}

class FakePlayer implements MusicTrackPlayer {
  final played = <DownloadedMusicTrack>[];
  Completer<void>? completion;
  void Function(Duration)? onPosition;
  bool paused = false;
  Duration? sought;
  double volume = 1;
  int stops = 0;
  Object? stopError;

  @override
  Future<void> play(DownloadedMusicTrack track,
      {required double volume,
      required void Function(Duration position) onPosition}) {
    played.add(track);
    this.volume = volume;
    this.onPosition = onPosition;
    return (completion = Completer<void>()).future;
  }

  void finish([Object? error]) {
    final current = completion;
    if (current == null || current.isCompleted) return;
    if (error == null) {
      current.complete();
    } else {
      current.completeError(error);
    }
  }

  @override
  Future<void> setPaused(bool paused) async {
    this.paused = paused;
  }

  @override
  Future<void> seek(Duration position) async {
    sought = position;
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
  }

  @override
  Future<void> stop() async {
    stops++;
    final error = stopError;
    stopError = null;
    if (error != null) throw error;
    finish();
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);
