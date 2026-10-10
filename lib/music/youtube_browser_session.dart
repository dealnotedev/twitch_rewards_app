import 'dart:async';
import 'dart:convert';
import 'dart:io';

abstract interface class YoutubeBrowserSession {
  Future<void> open(Uri url);

  Future<Uri> readYoutubeVideoUrl();

  Future<List<Map<String, dynamic>>> readYoutubeCookies();

  Future<void> close();
}

enum YoutubeConnectionIssue {
  browserUnavailable,
  browserClosed,
  verificationRequired,
  downloadBlocked,
  rateLimited,
  chooseVideo,
  videoUnavailable,
  videoTooLongOrLive,
  networkUnavailable,
  toolsUnavailable,
  storageUnavailable,
  checkFailed,
}

class YoutubeConnectionException implements Exception {
  final YoutubeConnectionIssue issue;

  const YoutubeConnectionException(this.issue);
}

/// Opens an app-owned browser profile. Never attaches to a personal profile.
class ManagedYoutubeBrowserSession implements YoutubeBrowserSession {
  final Directory profileDirectory;
  final String? Function() _findBrowser;
  final Future<Process> Function(String, List<String>) _startProcess;
  final Future<int> Function() _allocatePort;
  Process? _process;
  Uri? _endpoint;
  String? _browserSocketPath;
  bool _exited = false;

  ManagedYoutubeBrowserSession({
    required this.profileDirectory,
    String? Function()? findBrowser,
    Future<Process> Function(String, List<String>)? startProcess,
    Future<int> Function()? allocatePort,
  }) : _findBrowser = findBrowser ?? findInstalledBrowser,
       _startProcess = startProcess ?? _start,
       _allocatePort = allocatePort ?? _unusedLoopbackPort;

  static Future<int> _unusedLoopbackPort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  static Future<Process> _start(String executable, List<String> arguments) =>
      Process.start(executable, arguments, runInShell: false);

  static String? findInstalledBrowser() {
    if (!Platform.isWindows) return null;
    final environment = Platform.environment;
    for (final relative in [
      r'Microsoft\Edge\Application\msedge.exe',
      r'Google\Chrome\Application\chrome.exe',
    ]) {
      for (final key in ['ProgramFiles(x86)', 'ProgramFiles', 'LOCALAPPDATA']) {
        final root = environment[key];
        if (root == null) continue;
        final path = '$root\\$relative';
        if (File(path).existsSync()) return path;
      }
    }
    return null;
  }

  @override
  Future<void> open(Uri url) async {
    await close();
    final executable = _findBrowser();
    if (executable == null) {
      throw const YoutubeConnectionException(
        YoutubeConnectionIssue.browserUnavailable,
      );
    }
    await profileDirectory.create(recursive: true);
    _exited = false;
    try {
      final port = await _allocatePort();
      _endpoint = Uri.parse('http://127.0.0.1:$port');
      final process = await _startProcess(executable, [
        '--user-data-dir=${profileDirectory.absolute.path}',
        '--remote-debugging-address=127.0.0.1',
        // Chromium marks port=0 as automation (navigator.webdriver=true),
        // which can prevent users from signing in to Google.
        '--remote-debugging-port=$port',
        '--no-first-run',
        '--no-default-browser-check',
        '--new-window',
        url.toString(),
      ]);
      _process = process;
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      unawaited(
        process.exitCode.then((_) {
          if (identical(_process, process)) _exited = true;
        }),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(deadline) && !_exited) {
        try {
          final version = await _readJson('/json/version') as Map;
          final socket = Uri.tryParse(
            version['webSocketDebuggerUrl'] as String? ?? '',
          );
          if (socket != null && socket.path.startsWith('/devtools/browser/')) {
            _browserSocketPath = socket.path;
            return;
          }
        } on SocketException {
          // The browser process has not started accepting requests yet.
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    } on ProcessException {
      await close();
      throw const YoutubeConnectionException(
        YoutubeConnectionIssue.browserUnavailable,
      );
    } catch (_) {
      await close();
      rethrow;
    }
    await close();
    throw const YoutubeConnectionException(
      YoutubeConnectionIssue.browserClosed,
    );
  }

  @override
  Future<Uri> readYoutubeVideoUrl() async {
    final pages = await _readJson('/json/list') as List;
    final videos = <Uri>{};
    for (final page in pages.cast<Map>()) {
      final url = Uri.tryParse(page['url'] as String? ?? '');
      if (page['type'] != 'page' ||
          url == null ||
          (url.host != 'youtube.com' && !url.host.endsWith('.youtube.com'))) {
        continue;
      }
      final videoId = url.path == '/watch'
          ? url.queryParameters['v']
          : (url.pathSegments.length == 2 &&
                    ['shorts', 'live'].contains(url.pathSegments.first)
                ? url.pathSegments.last
                : null);
      if (videoId != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId)) {
        // Avoid playlists, tracking parameters and incidental account URLs.
        videos.add(Uri.https('www.youtube.com', '/watch', {'v': videoId}));
      }
    }
    // Never silently check a different tab. A single dedicated video tab is
    // unambiguous even when the settings window is in the foreground.
    if (videos.length == 1) return videos.single;
    throw const YoutubeConnectionException(YoutubeConnectionIssue.chooseVideo);
  }

  Future<dynamic> _readJson(String path) async {
    final endpoint = _endpoint;
    if (endpoint == null || _exited) {
      throw const YoutubeConnectionException(
        YoutubeConnectionIssue.browserClosed,
      );
    }
    final client = HttpClient()
      ..findProxy = ((_) => 'DIRECT')
      ..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(endpoint.resolve(path));
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw const YoutubeConnectionException(
          YoutubeConnectionIssue.browserClosed,
        );
      }
      return jsonDecode(
        await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 3)),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _command(
    String socketPath,
    String method, [
    Map<String, dynamic> parameters = const {},
  ]) async {
    // Use the loopback endpoint we launched, never a host supplied by a page.
    if (!socketPath.startsWith('/devtools/')) {
      throw const YoutubeConnectionException(
        YoutubeConnectionIssue.browserClosed,
      );
    }
    final url = _endpoint!.replace(scheme: 'ws', path: socketPath);
    final socket = await WebSocket.connect(url.toString())
        .timeout(const Duration(seconds: 3));
    try {
      final reply = socket
          .map((event) => jsonDecode(event as String))
          .firstWhere((event) => event is Map && event['id'] == 1)
          .timeout(const Duration(seconds: 5));
      socket.add(jsonEncode({'id': 1, 'method': method, 'params': parameters}));
      final data = await reply;
      if (data['error'] != null) {
        throw const YoutubeConnectionException(
          YoutubeConnectionIssue.checkFailed,
        );
      }
      return (data['result'] as Map?)?.cast<String, dynamic>() ?? {};
    } finally {
      await socket.close();
    }
  }

  @override
  Future<List<Map<String, dynamic>>> readYoutubeCookies() async {
    try {
      final pages = await _readJson('/json/list') as List;
      final page = pages.cast<Map>().where((page) {
        final url = Uri.tryParse(page['url'] as String? ?? '');
        return page['type'] == 'page' &&
            url != null &&
            (url.host == 'youtube.com' || url.host.endsWith('.youtube.com'));
      }).firstOrNull;
      if (page == null) {
        throw const YoutubeConnectionException(
          YoutubeConnectionIssue.verificationRequired,
        );
      }
      final socket = Uri.parse(page['webSocketDebuggerUrl'] as String);
      final result = await _command(socket.path, 'Network.getCookies', {
        'urls': ['https://www.youtube.com/', 'https://www.youtube.com/watch'],
      });
      return (result['cookies'] as List)
          .cast<Map>()
          .map((cookie) => cookie.cast<String, dynamic>())
          .toList();
    } on YoutubeConnectionException {
      rethrow;
    } catch (_) {
      throw const YoutubeConnectionException(
        YoutubeConnectionIssue.browserClosed,
      );
    }
  }

  @override
  Future<void> close() async {
    final process = _process;
    if (process == null) return;
    try {
      if (!_exited && _endpoint != null && _browserSocketPath != null) {
        try {
          await _command(_browserSocketPath!, 'Browser.close');
        } catch (_) {
          // Closing the browser can close the socket before its reply arrives.
        }
      }
      if (!_exited) {
        try {
          await process.exitCode.timeout(const Duration(seconds: 3));
        } on TimeoutException {
          process.kill();
        }
      }
    } finally {
      _process = null;
      _endpoint = null;
      _browserSocketPath = null;
    }
  }
}

/// Only YouTube cookies are persisted; malformed rows cannot inject domains.
String youtubeCookiesToNetscape(List<Map<String, dynamic>> cookies) {
  final rows = <String>['# Netscape HTTP Cookie File'];
  for (final cookie in cookies) {
    final domain = cookie['domain'];
    final name = cookie['name'];
    final value = cookie['value'];
    final path = cookie['path'] ?? '/';
    if (domain is! String ||
        name is! String ||
        value is! String ||
        path is! String ||
        name.isEmpty) {
      continue;
    }
    final host = domain.startsWith('.') ? domain.substring(1) : domain;
    if (host != 'youtube.com' && !host.endsWith('.youtube.com')) continue;
    if ([
      domain,
      name,
      value,
      path,
    ].any((field) => field.contains(RegExp(r'[\t\r\n]')))) {
      continue;
    }
    final expires = cookie['expires'];
    rows.add(
      [
        '${cookie['httpOnly'] == true ? '#HttpOnly_' : ''}$domain',
        domain.startsWith('.') ? 'TRUE' : 'FALSE',
        path,
        cookie['secure'] == true ? 'TRUE' : 'FALSE',
        expires is num && expires > 0 ? '${expires.floor()}' : '0',
        name,
        value,
      ].join('\t'),
    );
  }
  if (rows.length == 1) {
    throw const YoutubeConnectionException(
      YoutubeConnectionIssue.verificationRequired,
    );
  }
  return '${rows.join('\r\n')}\r\n';
}
