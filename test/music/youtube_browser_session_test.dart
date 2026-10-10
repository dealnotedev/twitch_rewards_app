import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/music/youtube_browser_session.dart';

void main() {
  test(
    'uses a dedicated profile and loopback CDP to read only YouTube cookies',
    () async {
      final profile = await Directory.systemTemp.createTemp('youtube_browser_');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final process = _BrowserProcess();
      final commands = <Map<String, dynamic>>[];
      final arguments = <String>[];
      final connections = <WebSocket>[];
      var pages = <Map<String, dynamic>>[
        {'type': 'page', 'url': 'https://accounts.google.com/'},
        {
          'type': 'page',
          'url': 'https://www.youtube.com/watch?v=4YFu4dvMHHY&list=test',
          // Ignore the supplied remote host; use the local port we launched.
          'webSocketDebuggerUrl': 'ws://untrusted.invalid/devtools/page/test',
        },
      ];
      server.listen((request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          connections.add(socket);
          socket.listen((event) {
            final command = jsonDecode(event as String) as Map<String, dynamic>;
            commands.add(command);
            // Real CDP includes asynchronous events unrelated to our command.
            socket.add(jsonEncode({'method': 'Network.event'}));
            socket.add(
              jsonEncode({
                'id': command['id'],
                'result': command['method'] == 'Network.getCookies'
                    ? {
                        'cookies': [
                          {
                            'domain': '.youtube.com',
                            'name': 'test',
                            'value': 'fake',
                          },
                        ],
                      }
                    : {},
              }),
            );
            if (command['method'] == 'Browser.close') {
              process.finished.complete(0);
            }
          });
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(
              request.uri.path == '/json/version'
                  ? <String, dynamic>{
                      'Browser': 'fake',
                      'webSocketDebuggerUrl':
                          'ws://untrusted.invalid/devtools/browser/test',
                    }
                  : pages,
            ),
          );
          await request.response.close();
        }
      });
      final browser = ManagedYoutubeBrowserSession(
        profileDirectory: profile,
        findBrowser: () => 'fake-edge',
        allocatePort: () async => server.port,
        startProcess: (executable, args) async {
          expect(executable, 'fake-edge');
          arguments.addAll(args);
          return process;
        },
      );
      addTearDown(() async {
        await browser.close();
        for (final connection in connections) {
          await connection.close();
        }
        await server.close(force: true);
        await profile.delete(recursive: true);
      });
      final url = Uri.parse('https://www.youtube.com/watch?v=test');
      await browser.open(url);
      expect(arguments, contains('--user-data-dir=${profile.absolute.path}'));
      expect(arguments, contains('--remote-debugging-address=127.0.0.1'));
      expect(arguments, contains('--remote-debugging-port=${server.port}'));
      expect(arguments, isNot(contains('--remote-debugging-port=0')));
      expect(arguments.last, url.toString());
      expect(
        await browser.readYoutubeVideoUrl(),
        Uri.parse('https://www.youtube.com/watch?v=4YFu4dvMHHY'),
      );
      expect(await browser.readYoutubeCookies(), hasLength(1));
      final request = commands.single;
      expect(request['method'], 'Network.getCookies');
      expect((request['params'] as Map)['urls'], [
        'https://www.youtube.com/',
        'https://www.youtube.com/watch',
      ]);
      for (final candidates in [
        <Map<String, dynamic>>[
          {'type': 'page', 'url': 'https://www.youtube.com/'},
          {
            'type': 'page',
            'url': 'https://www.youtube.com.evil.test/watch?v=4YFu4dvMHHY',
          },
        ],
        <Map<String, dynamic>>[
          ...pages,
          {
            'type': 'page',
            'url': 'https://www.youtube.com/watch?v=abcdefghijk',
          },
        ],
      ]) {
        pages = candidates;
        await expectLater(
          browser.readYoutubeVideoUrl(),
          throwsA(
            isA<YoutubeConnectionException>().having(
              (error) => error.issue,
              'issue',
              YoutubeConnectionIssue.chooseVideo,
            ),
          ),
        );
      }
      pages = [
        {'type': 'page', 'url': 'https://www.youtube.com/shorts/4YFu4dvMHHY'},
      ];
      expect(
        await browser.readYoutubeVideoUrl(),
        Uri.parse('https://www.youtube.com/watch?v=4YFu4dvMHHY'),
      );
      await browser.close();
      expect(commands.last['method'], 'Browser.close');
      expect(process.killed, isFalse);
    },
  );

  test('reports a missing browser without starting a process', () async {
    final browser = ManagedYoutubeBrowserSession(
      profileDirectory: Directory.systemTemp,
      findBrowser: () => null,
      startProcess: (_, _) async => throw StateError('must not launch'),
    );
    await expectLater(
      browser.open(Uri.parse('https://www.youtube.com/')),
      throwsA(
        isA<YoutubeConnectionException>().having(
          (e) => e.issue,
          'issue',
          YoutubeConnectionIssue.browserUnavailable,
        ),
      ),
    );
  });
}

class _BrowserProcess implements Process {
  final finished = Completer<int>();
  bool killed = false;

  @override
  Future<int> get exitCode => finished.future;

  @override
  int get pid => 1;

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!finished.isCompleted) finished.complete(0);
    return true;
  }
}
