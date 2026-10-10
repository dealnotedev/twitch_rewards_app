import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listener_updater/core/app_version.dart';
import 'package:listener_updater/core/installation.dart';
import 'package:listener_updater/core/release_client.dart';
import 'package:listener_updater/core/update_package.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory sandbox;
  const version = AppVersion(1, 1, 0, 3);
  final required = {
    listenerExecutable: 'new exe',
    'flutter_windows.dll': 'new engine',
    'libmpv-2.dll': 'audio engine',
    'sqlite3.dll': 'database engine',
    'tools/yt-dlp.exe': 'downloader',
    'tools/deno.exe': 'javascript engine',
    'tools/ffmpeg.exe': 'audio processor',
    'data/app.so': 'new app',
    'data/icudtl.dat': 'new ICU',
    'data/flutter_assets/AssetManifest.bin': 'assets',
    'new_plugin.dll': 'new plugin',
    'native_assets.json': '{}',
  };
  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('listener-updater-test-');
  });
  tearDown(() {
    sandbox.deleteSync(recursive: true);
  });
  String folder() {
    final directory = Directory(
      p.join(sandbox.path, 'fixture-${sandbox.listSync().length}'),
    );
    directory.createSync();
    return directory.path;
  }

  Map<String, String> payload() {
    final files = Map<String, String>.of(required);
    final roots = {
      ...files.keys.map((name) => name.split('/').first),
      manifestName,
    }.toList();
    files[manifestName] = jsonEncode(
      PackageManifest(version: version, roots: roots).toJson(),
    );
    return files;
  }

  String zip(Map<String, String> files, {void Function(Archive)? customize}) {
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile.string(entry.key, entry.value));
    }
    customize?.call(archive);
    final file = File(p.join(folder(), 'update.zip'))
      ..writeAsBytesSync(ZipEncoder().encode(archive));
    return file.path;
  }

  ({String root, Installation installer, PackageManifest package}) fixture() {
    final root = folder();
    File(p.join(root, listenerExecutable)).writeAsStringSync('old exe');
    File(p.join(root, 'flutter_windows.dll')).writeAsStringSync('old engine');
    File(p.join(root, 'tray_manager_plugin.dll'))
        .writeAsStringSync('old plugin');
    Directory(p.join(root, 'data')).createSync();
    File(p.join(root, 'data', 'old.asset')).writeAsStringSync('old asset');
    Directory(p.join(root, 'updater')).createSync();
    File(p.join(root, 'updater', 'listener_updater.exe'))
        .writeAsStringSync('updater');
    File(p.join(root, 'notes.txt')).writeAsStringSync('user file');
    File(p.join(root, manifestName)).writeAsStringSync(
      jsonEncode(
        const PackageManifest(
          version: AppVersion(1, 0, 0),
          roots: [
            listenerExecutable,
            'flutter_windows.dll',
            'tray_manager_plugin.dll',
            'data',
            manifestName,
          ],
        ).toJson(),
      ),
    );
    final installer = Installation(root)..prepare();
    final package = extractPackage(zip(payload()), installer.stage, version);
    return (root: root, installer: installer, package: package);
  }

  void original(String root) {
    expect(
      File(p.join(root, listenerExecutable)).readAsStringSync(),
      'old exe',
    );
    expect(
      File(p.join(root, 'flutter_windows.dll')).readAsStringSync(),
      'old engine',
    );
    expect(
      File(p.join(root, 'data', 'old.asset')).readAsStringSync(),
      'old asset',
    );
    expect(File(p.join(root, 'new_plugin.dll')).existsSync(), false);
    expect(File(p.join(root, 'notes.txt')).readAsStringSync(), 'user file');
    expect(
      File(p.join(root, 'updater', 'listener_updater.exe')).readAsStringSync(),
      'updater',
    );
  }

  test('versions compare numbers and Flutter build suffixes', () {
    expect(
      AppVersion.parse('1.10.0').compareTo(AppVersion.parse('1.9.9')),
      greaterThan(0),
    );
    expect(AppVersion.parse('1.1.0+3'), version);
    expect(() => AppVersion.parse('1.1.0.3'), throwsFormatException);
    expect(() => AppVersion.parse('v1.1.0'), throwsFormatException);
    expect(version.matchesRelease(const AppVersion(1, 1, 0)), true);
    expect(() => AppVersion.parse('1.1.0-beta'), throwsFormatException);
  });
  test('valid archive accepts a tag without its build suffix', () {
    expect(
      extractPackage(
        zip(payload()),
        folder(),
        const AppVersion(1, 1, 0),
      ).version,
      version,
    );
  });

  test('accepts undeclared files and overwrites existing arbitrary roots', () {
    final f = fixture();
    f.installer.prepare();
    final files = payload()
      ..['notes.txt'] = 'updated notes'
      ..['translations/en.json'] = '{}'
      ..['new-tool.exe'] = 'new tool'
      ..['updater/listener_updater.exe'] = 'must not replace'
      ..['UpDaTeR/new.dll'] = 'must not add';
    final package = extractPackage(zip(files), f.installer.stage, version);
    expect(
      package.roots,
      containsAll(['notes.txt', 'translations', 'new-tool.exe']),
    );
    expect(package.roots.any(isUpdaterRoot), false);
    expect(Directory(p.join(f.installer.stage, 'updater')).existsSync(), false);
    f.installer.apply(package);
    expect(
      File(p.join(f.root, 'notes.txt')).readAsStringSync(),
      'updated notes',
    );
    expect(
      File(p.join(f.root, 'translations', 'en.json')).readAsStringSync(),
      '{}',
    );
    expect(File(p.join(f.root, 'new-tool.exe')).readAsStringSync(), 'new tool');
    expect(
      File(p.join(f.root, 'updater', 'listener_updater.exe'))
          .readAsStringSync(),
      'updater',
    );
    expect(File(p.join(f.root, 'updater', 'new.dll')).existsSync(), false);
    expect(PackageManifest.read(f.root).roots, contains('translations'));
  });
  test('rolls back arbitrary files and removes newly added folders', () {
    final f = fixture();
    f.installer.prepare();
    final files = payload()
      ..['notes.txt'] = 'updated notes'
      ..['translations/en.json'] = '{}';
    final package = extractPackage(zip(files), f.installer.stage, version);
    expect(
      () => f.installer.apply(
        package,
        afterInstall: (name) {
          if (name == package.roots.last) {
            throw const FileSystemException('Injected failure');
          }
        },
      ),
      throwsA(isA<FileSystemException>()),
    );
    original(f.root);
    expect(Directory(p.join(f.root, 'translations')).existsSync(), false);
  });

  for (final unsafe in [
    '../escape',
    '/absolute',
    'C:/escape',
    'data/../escape',
    'data/a:stream',
    'data/CON.txt',
    'data/trailing.',
    '.listener-update/transaction.json',
    'data//bad',
  ]) {
    test('reject unsafe archive path $unsafe', () {
      expect(
        () =>
            extractPackage(zip(payload()..[unsafe] = 'bad'), folder(), version),
        throwsFormatException,
      );
    });
  }
  test('reject case-insensitive archive collisions', () {
    expect(
      () => extractPackage(
        zip(payload()..['DATA/app.so'] = 'duplicate'),
        folder(),
        version,
      ),
      throwsFormatException,
    );
  });
  test('reject symlink entries', () {
    final archive = zip(
      payload(),
      customize: (archive) {
        final link = ArchiveFile.string('data/link', 'target')
          ..symbolicLink = '../target'
          ..mode = 0xa1ff;
        archive.addFile(link);
      },
    );
    expect(
      () => extractPackage(archive, folder(), version),
      throwsFormatException,
    );
  });
  test('reject missing runtime file', () {
    expect(
      () => extractPackage(
        zip(payload()..remove('data/app.so')),
        folder(),
        version,
      ),
      throwsFormatException,
    );
  });
  test('reject package version mismatch', () {
    expect(
      () => extractPackage(zip(payload()), folder(), const AppVersion(2, 0, 0)),
      throwsFormatException,
    );
  });
  test('requires the installed manifest before touching application files', () {
    final f = fixture();
    File(p.join(f.root, manifestName)).deleteSync();
    expect(() => Installation(f.root), throwsA(isA<FileSystemException>()));
    expect(
      () => f.installer.apply(f.package),
      throwsA(isA<FileSystemException>()),
    );
    expect(f.installer.needsRecovery, false);
    original(f.root);
  });

  test('reject an unrelated installation directory', () {
    expect(() => Installation(folder()), throwsA(isA<FileSystemException>()));
  });
  test(
    'install replaces managed roots and preserves user files and updater',
    () {
      final f = fixture();
      f.installer.apply(f.package);
      expect(
        File(p.join(f.root, listenerExecutable)).readAsStringSync(),
        'new exe',
      );
      expect(File(p.join(f.root, 'data', 'old.asset')).existsSync(), false);
      expect(
        File(p.join(f.root, 'tray_manager_plugin.dll')).existsSync(),
        false,
      );
      expect(File(p.join(f.root, 'notes.txt')).readAsStringSync(), 'user file');
      expect(
        File(p.join(f.root, 'updater', 'listener_updater.exe'))
            .readAsStringSync(),
        'updater',
      );
      expect(f.installer.needsRecovery, false);
      f.installer.cleanWork();
    },
  );
  for (final name in [
    listenerExecutable,
    'flutter_windows.dll',
    'data',
    'new_plugin.dll',
    manifestName,
  ]) {
    test('rollback after replacing $name', () {
      final f = fixture();
      expect(
        () => f.installer.apply(
          f.package,
          afterInstall: (installed) {
            if (installed == name) {
              throw const FileSystemException('Injected failure');
            }
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      original(f.root);
      expect(f.installer.needsRecovery, false);
    });
  }
  test(
    'recover interruption with a missing executable, without deleting backup',
    () {
      final f = fixture();
      final backup = Directory(p.join(f.installer.work, 'backup'))
        ..createSync();
      File(p.join(f.installer.work, 'transaction.json')).writeAsStringSync(
        jsonEncode({
          'schema': 1,
          'entries': [
            {'name': listenerExecutable, 'hadOriginal': true},
            {'name': 'new_plugin.dll', 'hadOriginal': false},
          ],
        }),
      );
      File(p.join(f.root, listenerExecutable))
          .renameSync(p.join(backup.path, listenerExecutable));
      File(p.join(f.root, 'new_plugin.dll')).writeAsStringSync('partial');
      final reopened = Installation(f.root)..cleanWork();
      expect(reopened.needsRecovery, true);
      reopened.recover();
      reopened.recover();
      original(f.root);
    },
  );
  test('reject malicious recovery journal before touching user files', () {
    final f = fixture();
    File(p.join(f.installer.work, 'transaction.json')).writeAsStringSync(
      jsonEncode({
        'schema': 1,
        'entries': [
          {'name': '../notes.txt', 'hadOriginal': false},
        ],
      }),
    );
    expect(f.installer.recover, throwsFormatException);
    expect(File(p.join(f.root, 'notes.txt')).readAsStringSync(), 'user file');
  });
  test('reject Windows junction in work directory', () {
    if (!Platform.isWindows) return;
    final root = folder();
    File(p.join(root, listenerExecutable)).writeAsStringSync('old exe');
    final outside = folder();
    File(p.join(outside, 'preserve.txt')).writeAsStringSync('keep');
    final result = Process.runSync('powershell.exe', [
      '-NoProfile',
      '-Command',
      "New-Item -ItemType Junction -Path '${p.join(root, '.listener-update').replaceAll("'", "''")}' -Target '${outside.replaceAll("'", "''")}' | Out-Null",
    ]);
    expect(result.exitCode, 0);
    expect(() => Installation(root), throwsA(isA<FileSystemException>()));
    expect(File(p.join(outside, 'preserve.txt')).readAsStringSync(), 'keep');
    Link(p.join(root, '.listener-update')).deleteSync();
  });

  final bytes = utf8.encode('archive payload');
  Release downloadable({String? digest, int? size}) => Release(
    version: version,
    notes: '',
    download: Uri.parse(
      'https://github.com/dealnotedev/twitch_rewards_app/releases/download/1.1.0/update.zip',
    ),
    size: size ?? bytes.length,
    digest: digest ?? 'sha256:${sha256.convert(bytes)}',
  );
  ReleaseClient client(ResponseBody Function(RequestOptions) respond) {
    final dio = Dio()..httpClientAdapter = FakeAdapter(respond);
    final result = ReleaseClient(dio: dio);
    addTearDown(result.close);
    return result;
  }

  ResponseBody body(List<int> data, [int status = 200]) =>
      ResponseBody.fromBytes(data, status);
  test('download verifies SHA-256 and size', () async {
    final file = p.join(folder(), 'download.zip');
    await client((_) => body(bytes))
        .download(downloadable(), file, CancelToken(), (_, _) {});
    expect(File(file).readAsBytesSync(), bytes);
  });
  test('reject corrupt download', () async {
    await expectLater(
      client((_) => body(bytes)).download(
        downloadable(digest: 'sha256:${'0' * 64}'),
        p.join(folder(), 'download.zip'),
        CancelToken(),
        (_, _) {},
      ),
      throwsFormatException,
    );
  });
  for (final size in [bytes.length - 1, bytes.length + 1]) {
    test('reject download with wrong length $size', () async {
      await expectLater(
        client((_) => body(bytes)).download(
          downloadable(size: size),
          p.join(folder(), 'download.zip'),
          CancelToken(),
          (_, _) {},
        ),
        throwsFormatException,
      );
    });
  }
  test('reject absent checksum before downloading', () async {
    final source = client(
      (_) => throw StateError('Unexpected network request'),
    );
    await expectLater(
      source.download(
        Release(
          version: version,
          notes: '',
          size: 1,
          download: downloadable().download,
        ),
        p.join(folder(), 'download.zip'),
        CancelToken(),
        (_, _) {},
      ),
      throwsFormatException,
    );
  });
  test('cancel download before it starts', () async {
    final cancellation = CancelToken()..cancel();
    await expectLater(
      client((_) => body(bytes)).download(
        downloadable(),
        p.join(folder(), 'download.zip'),
        cancellation,
        (_, _) {},
      ),
      throwsA(isA<DioException>()),
    );
  });
  test('GitHub 404 means no release', () async {
    expect(await client((_) => body([], 404)).latest(CancelToken()), null);
  });
  test('parse old release without update.zip', () {
    final release = Release.fromJson({
      'tag_name': '1.0.1',
      'body': 'Notes',
      'assets': [],
    });
    expect(release.version, const AppVersion(1, 0, 1));
    expect(release.download, null);
  });
  test('reject asset outside the release repository', () {
    expect(
      () => Release.fromJson({
        'tag_name': '1.1.0',
        'assets': [
          {
            'name': 'update.zip',
            'browser_download_url': 'https://example.com/update.zip',
            'size': 3,
          },
        ],
      }),
      throwsFormatException,
    );
  });
  test('GitHub throttling returns an actionable error', () async {
    await expectLater(
      client((_) => body([], 403)).latest(CancelToken()),
      throwsFormatException,
    );
  });
}

final class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);
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
