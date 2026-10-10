import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

/// One bounded, anonymous request per Listener startup. Failures stay silent.
final class UpdateCheck {
  UpdateCheck({Dio? dio, Future<String?> Function()? readVersion})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: {
                'User-Agent': 'TwitchListener',
                'Accept': 'application/vnd.github+json',
                'X-GitHub-Api-Version': '2022-11-28',
              },
            ),
          ),
      _readVersion =
          readVersion ??
          (() =>
              const MethodChannel('listener/update')
                  .invokeMethod<String>('getAppVersion'));

  final Dio _dio;
  final Future<String?> Function() _readVersion;
  final CancelToken _cancel = CancelToken();

  Future<String?> newerVersion() async {
    try {
      final installed = _version(await _readVersion());
      if (installed == null || _cancel.isCancelled) return null;
      final response = await _dio
          .get<Map<String, dynamic>>(
            'https://api.github.com/repos/dealnotedev/twitch_rewards_app/releases/latest',
            cancelToken: _cancel,
          )
          .timeout(const Duration(seconds: 10));
      final release = response.data;
      if (release == null ||
          release['draft'] == true ||
          release['prerelease'] == true) {
        return null;
      }
      final tag = release['tag_name'];
      final latest = _version(tag is String ? tag : null);
      if (latest == null) return null;
      final assets = release['assets'];
      if (assets is! List ||
          !assets.any(
            (asset) =>
                asset is Map &&
                asset['name'] == 'update.zip' &&
                asset['size'] is int &&
                asset['size'] > 0 &&
                RegExp(r'^sha256:[a-fA-F0-9]{64}$')
                    .hasMatch(asset['digest'] is String ? asset['digest'] : ''),
          )) {
        return null;
      }
      for (var i = 0; i < latest.length; i++) {
        if (latest[i] > installed[i]) {
          return tag as String;
        }
        if (latest[i] < installed[i]) return null;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      dispose();
    }
  }

  void dispose() {
    _cancel.cancel();
    _dio.close(force: true);
  }

  static List<int>? _version(String? value) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$')
        .firstMatch(value ?? '');
    if (match == null) return null;
    return [for (var i = 1; i <= 4; i++) int.parse(match.group(i) ?? '0')];
  }
}
