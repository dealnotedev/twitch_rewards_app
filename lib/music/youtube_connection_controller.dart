import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/yt_dlp_music_track_fetcher.dart';
import 'package:twitch_listener/music/youtube_browser_session.dart';

enum YoutubeConnectionStatus {
  disconnected,
  opening,
  awaitingVerification,
  checking,
  connected,
}

typedef YoutubeAccessVerifier = Future<void> Function(
  String cookieFile,
  Uri url,
  void Function(MusicPreparationProgress progress) onProgress,
);

class YoutubeConnectionController extends ChangeNotifier {
  static final _youtubeUrl = Uri.parse('https://www.youtube.com/');
  final Directory directory;
  final YoutubeBrowserSession browser;
  final YoutubeAccessVerifier verifyAccess;
  final Future<void> Function()? cancelVerification;

  /// Called after a successful check, for example to resume waiting requests.
  final VoidCallback? onConnected;

  /// The yt-dlp release, added to the settings-only support details.
  final Future<String?> Function()? toolVersion;

  YoutubeConnectionStatus status = YoutubeConnectionStatus.disconnected;
  YoutubeConnectionIssue? issue;
  Uri? checkedVideoUrl;
  String? diagnostic;

  /// Audio download progress of a running check, or null when unknown.
  double? checkProgress;

  /// Whether a check succeeded since the app started.
  bool verifiedThisSession = false;

  Uri? _verificationUrl;
  YoutubeConnectionIssue? _requiredIssue;
  bool _hasSession;
  bool _removing = false;
  bool _staleRunsRemoved = false;
  int _generation = 0;
  int _leases = 0;
  final _activeRuns = <String>{};
  Future<void> _sessionWrites = Future.value();
  bool _closed = false;
  bool _cancelRequested = false;
  Future<void>? _opening;
  Future<void>? _verification;

  YoutubeConnectionController({
    required this.directory,
    required this.browser,
    required this.verifyAccess,
    this.cancelVerification,
    this.onConnected,
    this.toolVersion,
  }) : _hasSession = _sessionFile(directory).existsSync() {
    if (_hasSession) status = YoutubeConnectionStatus.connected;
  }

  static File _sessionFile(Directory directory) =>
      File('${directory.path}${Platform.pathSeparator}cookies.txt');

  File get _cookies => _sessionFile(directory);

  Directory get _runsDirectory =>
      Directory('${directory.path}${Platform.pathSeparator}runs');

  /// Whether a verified YouTube session is saved on this computer.
  bool get hasSession => _hasSession;

  String? get cookieFilePath => _hasSession ? _cookies.path : null;

  bool get busy =>
      _removing ||
      status == YoutubeConnectionStatus.opening ||
      status == YoutubeConnectionStatus.checking;

  YoutubeConnectionStatus get _idleStatus => _hasSession
      ? YoutubeConnectionStatus.connected
      : YoutubeConnectionStatus.disconnected;

  bool get _stopped => _closed || _cancelRequested;

  /// Records why music preparation stopped. A saved session is kept: it may
  /// work again after the streamer checks the connection.
  void requireCheck(MusicQueueErrorType reason, Uri url) {
    if (_closed) return;
    final required = switch (reason) {
      MusicQueueErrorType.youtubeDownloadBlocked =>
        YoutubeConnectionIssue.downloadBlocked,
      MusicQueueErrorType.youtubeRateLimited =>
        YoutubeConnectionIssue.rateLimited,
      _ => YoutubeConnectionIssue.verificationRequired,
    };
    _requiredIssue = required;
    _verificationUrl = url;
    // Do not replace the result of a connection attempt in progress.
    if (!busy && status != YoutubeConnectionStatus.awaitingVerification) {
      issue = required;
    }
    notifyListeners();
  }

  /// A private copy of the saved session for one yt-dlp run. A successful run
  /// writes YouTube's cookie updates back unless the session changed meanwhile.
  Future<YtDlpCookieLease?> leaseCookies() async {
    if (_closed || !_hasSession) return null;
    final generation = _generation;
    final copy = File(
      '${_runsDirectory.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}-${_leases++}.txt',
    );
    try {
      await _writeSession(() async {
        if (!_staleRunsRemoved) {
          _staleRunsRemoved = true;
          await _removeIdleRuns();
        }
        await _runsDirectory.create(recursive: true);
        _activeRuns.add(copy.path);
        await _cookies.copy(copy.path);
      });
    } on FileSystemException {
      _activeRuns.remove(copy.path);
      return null;
    }
    return _SessionLease(
      copy.path,
      (succeeded) => _releaseLease(copy, generation, succeeded),
    );
  }

  Future<void> _releaseLease(File copy, int generation, bool succeeded) async {
    try {
      if (succeeded) {
        await _writeSession(() async {
          if (generation != _generation || !_hasSession) return;
          await copy.rename(_cookies.path);
        });
      }
    } on FileSystemException {
      // The saved session stays as it was.
    } finally {
      _activeRuns.remove(copy.path);
      try {
        if (await copy.exists()) await copy.delete();
      } on FileSystemException {
        // Removed with the next lease or disconnect.
      }
    }
  }

  /// Deletes session copies left by interrupted runs. Copies still used by a
  /// running yt-dlp process are deleted when that process is released.
  Future<void> _removeIdleRuns() async {
    try {
      if (!await _runsDirectory.exists()) return;
      await for (final entity in _runsDirectory.list(followLinks: false)) {
        if (_activeRuns.contains(entity.path)) continue;
        try {
          await entity.delete(recursive: true);
        } on FileSystemException {
          // Best effort: leftover copies are never read again.
        }
      }
    } on FileSystemException {
      // Best effort: leftover copies are never read again.
    }
  }

  /// Serializes changes to the saved session so a stale yt-dlp run cannot
  /// overwrite a newer session or recreate a removed one.
  Future<void> _writeSession(Future<void> Function() action) {
    final result = _sessionWrites.then((_) => action());
    _sessionWrites = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> connect() {
    if (_closed || _removing) return Future.value();
    if (status == YoutubeConnectionStatus.opening) {
      return _opening ?? Future.value();
    }
    if (status == YoutubeConnectionStatus.checking) return Future.value();
    return _opening = _connect();
  }

  Future<void> _connect() async {
    status = YoutubeConnectionStatus.opening;
    issue = null;
    checkedVideoUrl = null;
    diagnostic = null;
    checkProgress = null;
    verifiedThisSession = false;
    notifyListeners();
    try {
      await browser.open(_verificationUrl ?? _youtubeUrl);
      if (_closed) return;
      status = YoutubeConnectionStatus.awaitingVerification;
    } catch (error) {
      if (_closed) return;
      issue = _issueFor(error);
      status = _idleStatus;
    }
    if (!_closed) notifyListeners();
  }

  Future<void> verify() {
    if (!_closed && status == YoutubeConnectionStatus.checking) {
      return _verification ?? Future.value();
    }
    if (_closed || status != YoutubeConnectionStatus.awaitingVerification) {
      return Future.value();
    }
    _cancelRequested = false;
    return _verification = _verify();
  }

  Future<void> _verify() async {
    status = YoutubeConnectionStatus.checking;
    issue = null;
    diagnostic = null;
    checkProgress = null;
    notifyListeners();
    final pending = File('${_cookies.path}.pending');
    var browserOpen = true;
    try {
      // Use the video the user actually played, including after a restart.
      // A fixed external test video can be removed or region-restricted.
      final url = await browser.readYoutubeVideoUrl();
      checkedVideoUrl = url;
      // Reopening after a failed check returns to the same video.
      _verificationUrl = url;
      if (_stopped) return;
      final cookies = await browser.readYoutubeCookies();
      if (_stopped) return;
      await directory.create(recursive: true);
      await pending.writeAsString(
        youtubeCookiesToNetscape(cookies),
        flush: true,
      );
      // Close the dedicated browser immediately. YouTube rotates the cookies
      // of open sessions, which would invalidate the exported copy, and the
      // local debugging port should stay open no longer than needed.
      browserOpen = false;
      await browser.close();
      if (_stopped) return;
      // Do not show success merely because a browser has supplied cookies.
      await verifyAccess(pending.path, url, (progress) {
        if (_closed || status != YoutubeConnectionStatus.checking) return;
        checkProgress = progress.fraction;
        notifyListeners();
      });
      if (_stopped) return;
      await _writeSession(() async {
        await pending.copy(_cookies.path);
        _generation++;
        _hasSession = true;
      });
      if (_closed) return;
      status = YoutubeConnectionStatus.connected;
      verifiedThisSession = true;
      _verificationUrl = null;
      _requiredIssue = null;
      onConnected?.call();
    } catch (error) {
      if (_closed) return;
      issue = _issueFor(error);
      if (error is YtDlpException) {
        final details = await _diagnosticFor(error);
        if (_closed) return;
        diagnostic = details;
      }
      // While the browser is still open, the problem can be fixed there.
      status = browserOpen
          ? YoutubeConnectionStatus.awaitingVerification
          : _idleStatus;
    } finally {
      try {
        if (await pending.exists()) await pending.delete();
      } on FileSystemException {
        issue = YoutubeConnectionIssue.storageUnavailable;
      }
      checkProgress = null;
      if (!_closed) notifyListeners();
    }
  }

  /// Settings-only support details. Never publish these on the overlay or
  /// control protocol. URLs (which may carry media tokens) and paths are
  /// removed.
  Future<String> _diagnosticFor(YtDlpException error) async {
    final detail = (error.diagnostic ?? error.message)
        .replaceAll(RegExp(r'https?://\S+'), '[URL]')
        .replaceAll(RegExp(r'[a-zA-Z]:[\\/][^\r\n]+'), '[local path]')
        .replaceAllMapped(
          RegExp(
            r'(cookie|authorization|token|password)\s*[:=]\s*\S+',
            caseSensitive: false,
          ),
          (match) => '${match[1]}=[redacted]',
        );
    final version = await toolVersion?.call();
    return [
      '${error.errorType.name}'
          '${error.exitCode == null ? '' : ' (exit ${error.exitCode})'}',
      if (version != null) 'yt-dlp $version',
      detail,
    ].join('\n');
  }

  /// Stops connecting and closes the browser. The saved session is kept.
  Future<void> cancel() async {
    if (_closed ||
        (status != YoutubeConnectionStatus.awaitingVerification &&
            status != YoutubeConnectionStatus.checking)) {
      return;
    }
    if (status == YoutubeConnectionStatus.checking) {
      _cancelRequested = true;
      await cancelVerification?.call();
      await _verification;
      if (_closed) return;
    }
    await browser.close();
    if (_closed) return;
    status = _idleStatus;
    issue = _requiredIssue;
    checkedVideoUrl = null;
    diagnostic = null;
    checkProgress = null;
    notifyListeners();
  }

  /// Removes the saved session and the dedicated browser profile.
  Future<void> disconnect() async {
    if (_closed || busy) return;
    _removing = true;
    notifyListeners();
    try {
      await browser.close();
      await _writeSession(() async {
        // In-flight yt-dlp runs must not write the removed session back.
        // They still use their copies, which are deleted when they finish.
        _generation++;
        if (await _cookies.exists()) await _cookies.delete();
        _hasSession = false;
        await _removeIdleRuns();
      });
      // This is exclusively our profile, under the app's session directory.
      final profile = Directory(
        '${directory.path}${Platform.pathSeparator}browser',
      );
      // Chromium's child processes may release profile files just after the
      // main process exits. Give them a short grace period before reporting an
      // actionable storage error.
      for (var attempt = 0; attempt < 12; attempt++) {
        try {
          if (await profile.exists()) await profile.delete(recursive: true);
          break;
        } on FileSystemException {
          if (attempt == 11) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      status = YoutubeConnectionStatus.disconnected;
      issue = null;
      _requiredIssue = null;
      _verificationUrl = null;
      checkedVideoUrl = null;
      diagnostic = null;
      verifiedThisSession = false;
    } catch (error) {
      issue = _issueFor(error);
      status = _idleStatus;
    } finally {
      _removing = false;
      if (!_closed) notifyListeners();
    }
  }

  static YoutubeConnectionIssue _issueFor(Object error) {
    if (error is YoutubeConnectionException) return error.issue;
    if (error is FileSystemException) {
      return YoutubeConnectionIssue.storageUnavailable;
    }
    if (error is MusicTrackException) {
      return switch (error.errorType) {
        MusicQueueErrorType.youtubeAccessRequired =>
          YoutubeConnectionIssue.verificationRequired,
        MusicQueueErrorType.youtubeDownloadBlocked =>
          YoutubeConnectionIssue.downloadBlocked,
        MusicQueueErrorType.youtubeRateLimited =>
          YoutubeConnectionIssue.rateLimited,
        MusicQueueErrorType.youtubeUnavailable =>
          YoutubeConnectionIssue.videoUnavailable,
        MusicQueueErrorType.trackTooLongOrLive =>
          YoutubeConnectionIssue.videoTooLongOrLive,
        MusicQueueErrorType.networkUnavailable =>
          YoutubeConnectionIssue.networkUnavailable,
        MusicQueueErrorType.musicToolsUnavailable =>
          YoutubeConnectionIssue.toolsUnavailable,
        _ => YoutubeConnectionIssue.checkFailed,
      };
    }
    return YoutubeConnectionIssue.checkFailed;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await cancelVerification?.call();
    await _opening;
    await _verification;
    await browser.close();
    await _sessionWrites;
    dispose();
  }
}

class _SessionLease implements YtDlpCookieLease {
  @override
  final String path;
  final Future<void> Function(bool succeeded) _onRelease;
  bool _released = false;

  _SessionLease(this.path, this._onRelease);

  @override
  Future<void> release({required bool succeeded}) async {
    if (_released) return;
    _released = true;
    await _onRelease(succeeded);
  }
}
