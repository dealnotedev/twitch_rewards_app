import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'app_version.dart';
import 'update_failure.dart';

final class Release {
  const Release({
    required this.version,
    required this.notes,
    this.download,
    this.size = 0,
    this.digest,
  });
  final AppVersion version;
  final String notes;
  final Uri? download;
  final int size;
  final String? digest;

  factory Release.fromJson(Map<String, dynamic> json) {
    Uri? download;
    var size = 0;
    String? digest;
    for (final asset in json['assets'] as List<dynamic>? ?? []) {
      if (asset['name'] != 'update.zip') continue;
      download = Uri.parse(asset['browser_download_url'] as String);
      if (download.scheme != 'https' ||
          download.host != 'github.com' ||
          !download.path.startsWith(
            '/${ReleaseClient.repository}/releases/download/',
          )) {
        throw const UpdateFailure(UpdateIssue.invalidUrl);
      }
      size = asset['size'] as int;
      digest = asset['digest'] as String?;
      break;
    }
    return Release(
      version: AppVersion.parse(json['tag_name'] as String),
      notes: json['body'] as String? ?? '',
      download: download,
      size: size,
      digest: digest,
    );
  }
}

final class ReleaseClient {
  ReleaseClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 25),
              receiveTimeout: const Duration(seconds: 45),
              headers: {
                'User-Agent': 'TwitchListener-Updater/1.0',
                'X-GitHub-Api-Version': '2022-11-28',
              },
            ),
          );
  static const repository = 'dealnotedev/twitch_rewards_app';
  static const maxArchiveSize = 512 * 1024 * 1024;
  final Dio _dio;

  Future<Release?> latest(CancelToken cancellation) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/$repository/releases/latest',
        cancelToken: cancellation,
      );
      final json = response.data!;
      if (json['draft'] == true || json['prerelease'] == true) return null;
      return Release.fromJson(json);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      if ([403, 429].contains(error.response?.statusCode)) {
        throw const UpdateFailure(UpdateIssue.rateLimited);
      }
      rethrow;
    }
  }

  Future<void> download(
    Release release,
    String destination,
    CancelToken cancellation,
    void Function(int received, int total) onProgress,
  ) async {
    if (release.download == null) {
      throw const UpdateFailure(UpdateIssue.packageUnavailable);
    }
    if (release.size <= 0 ||
        release.size > maxArchiveSize ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(release.digest ?? '')) {
      throw const UpdateFailure(UpdateIssue.invalidMetadata);
    }
    final response = await _dio.get<ResponseBody>(
      release.download.toString(),
      options: Options(responseType: ResponseType.stream),
      cancelToken: cancellation,
    );
    final output = await File(destination).open(mode: FileMode.writeOnly);
    var received = 0;
    try {
      await for (final bytes in response.data!.stream) {
        if (cancellation.isCancelled) throw cancellation.cancelError!;
        received += bytes.length;
        if (received > release.size) {
          cancellation.cancel('Unexpected download size');
          throw const UpdateFailure(UpdateIssue.downloadSizeMismatch);
        }
        await output.writeFrom(bytes);
        onProgress(received, release.size);
      }
      await output.flush();
    } finally {
      await output.close();
    }
    if (cancellation.isCancelled) throw cancellation.cancelError!;
    final digest = await sha256.bind(File(destination).openRead()).first;
    if (received != release.size ||
        digest.toString() != release.digest!.substring(7).toLowerCase()) {
      throw const UpdateFailure(UpdateIssue.checksumMismatch);
    }
  }

  void close() => _dio.close(force: true);
}
