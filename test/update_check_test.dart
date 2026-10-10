import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/updates/update_check.dart';

void main() {
  Future<String?> check(
    String installed,
    String tag, {
    bool prerelease = false,
    bool draft = false,
    bool package = true,
    bool checksum = true,
    int status = 200,
  }) {
    final dio = Dio()
      ..httpClientAdapter = _Adapter((options) {
        expect(
          options.uri.toString(),
          'https://api.github.com/repos/dealnotedev/twitch_rewards_app/releases/latest',
        );
        return ResponseBody.fromString(
          jsonEncode({
            'tag_name': tag,
            'draft': draft,
            'prerelease': prerelease,
            'assets': [
              if (package)
                {
                  'name': 'update.zip',
                  'size': 1024,
                  'digest': checksum ? 'sha256:${'a' * 64}' : null,
                },
            ],
          }),
          status,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      });
    return UpdateCheck(
      dio: dio,
      readVersion: () async => installed,
    ).newerVersion();
  }

  test('compares numeric versions and handles build suffixes', () async {
    expect(await check('1.9.0+3', '1.10.0'), '1.10.0');
    expect(await check('1.1.0+3', '1.1.0'), null);
    expect(await check('1.1.0+3', '1.1.0+4'), '1.1.0+4');
    expect(await check('2.0.0', '1.9.9'), null);
    expect(await check('1.1.0', '1.1.0'), null);
  });
  test(
    'silently ignores unavailable, unstable and malformed releases',
    () async {
      expect(await check('1.0.0', '1.1.0', draft: true), null);
      expect(await check('1.0.0', '1.1.0', prerelease: true), null);
      expect(await check('1.0.0', '1.1.0', package: false), null);
      expect(await check('1.0.0', '1.1.0', checksum: false), null);
      expect(await check('1.0.0', '1.1.0', status: 403), null);
      expect(await check('1.0.0', '1.1.0', status: 404), null);
      expect(await check('1.0.0', '1.1.0-beta'), null);
      expect(await check('broken', '1.1.0'), null);
      expect(await check('1.0.0', 'v1.1.0'), null);
      expect(await check('1.0.0', '1.1.0.3'), null);
    },
  );
  test('network failures and disposal do not escape into startup', () async {
    final dio = Dio()
      ..httpClientAdapter = _Adapter(
        (options) => throw DioException(requestOptions: options),
      );
    expect(
      await UpdateCheck(
        dio: dio,
        readVersion: () async => '1.0.0',
      ).newerVersion(),
      null,
    );
    final cancelled = UpdateCheck(readVersion: () async => '1.0.0')..dispose();
    expect(await cancelled.newerVersion(), null);
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}
