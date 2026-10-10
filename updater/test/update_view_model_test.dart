import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:observable_state/observable_state.dart';
import 'package:listener_updater/core/app_version.dart';
import 'package:listener_updater/core/release_client.dart';
import 'package:listener_updater/core/update_package.dart';
import 'package:listener_updater/platform/updater_host.dart';
import 'package:listener_updater/update_view_model.dart';
import 'package:listener_updater/updater_view.dart';
import 'package:listener_updater/core/update_failure.dart';
import 'package:listener_updater/l10n/generated/updater_localizations.dart';

import 'dart:ui';

import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late FakeHost host;
  late UpdateViewModel viewModel;
  const target = AppVersion(1, 1, 0, 3);
  final strings = lookupUpdaterLocalizations(const Locale('en'));
  UpdatePresentation presentation() =>
      UpdatePresentation.fromState(viewModel.state.current, strings);
  var corrupt = false;
  var tag = '1.1.0';
  var missingPackage = false;
  var noRelease = false;

  setUp(() {
    corrupt = false;
    tag = '1.1.0';
    missingPackage = false;
    noRelease = false;
    directory = Directory.systemTemp.createTempSync('updater-viewModel-');
    File(p.join(directory.path, listenerExecutable)).writeAsStringSync('old');
    File(p.join(directory.path, manifestName)).writeAsStringSync(
      jsonEncode(
        const PackageManifest(
          version: AppVersion(1, 0, 0),
          roots: [listenerExecutable, manifestName],
        ).toJson(),
      ),
    );
    host = FakeHost();
    final archive = Archive();
    final files = {
      listenerExecutable: 'new',
      'flutter_windows.dll': 'engine',
      'libmpv-2.dll': 'audio engine',
      'sqlite3.dll': 'database engine',
      'tools/yt-dlp.exe': 'downloader',
      'tools/deno.exe': 'javascript engine',
      'tools/ffmpeg.exe': 'audio processor',
      'data/app.so': 'app',
      'data/icudtl.dat': 'icu',
      'data/flutter_assets/AssetManifest.bin': 'manifest',
      manifestName: jsonEncode(
        PackageManifest(
          version: target,
          roots: [
            listenerExecutable,
            'flutter_windows.dll',
            'data',
            manifestName,
          ],
        ).toJson(),
      ),
    };
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile.string(entry.key, entry.value));
    }
    final bytes = ZipEncoder().encode(archive);
    final dio = Dio()
      ..httpClientAdapter = Responses((options) {
        if (options.uri.host == 'api.github.com') {
          if (noRelease) return ResponseBody.fromString('', 404);
          return ResponseBody.fromString(
            jsonEncode({
              'tag_name': tag,
              'draft': false,
              'prerelease': false,
              'body': 'Release notes',
              'assets': [
                if (!missingPackage)
                  {
                    'name': 'update.zip',
                    'size': bytes.length,
                    'digest':
                        'sha256:${corrupt ? '0' * 64 : sha256.convert(bytes)}',
                    'browser_download_url': 'https://github.com/dealnotedev/twitch_rewards_app/releases/download/1.1.0/update.zip',
                  },
              ],
            }),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        return ResponseBody.fromBytes(bytes, 200);
      });
    viewModel = UpdateViewModel(
      directory: directory.path,
      host: host,
      client: ReleaseClient(dio: dio),
    );
  });
  tearDown(() {
    viewModel.dispose();
    directory.deleteSync(recursive: true);
  });

  test(
    'constructor starts checking and callers join the same request',
    () async {
      expect(host.calls, ['initialize']);
      expect(viewModel.state.current.busy, isTrue);
      expect(viewModel.state.current.process.token, UpdateOperation.check);
      final checking = viewModel.check();
      expect(viewModel.check(), same(checking));
      await checking;
      expect(host.calls, ['initialize', 'version']);
      expect(viewModel.state.current.phase, UpdatePhase.available);
    },
  );

  test(
    'download progress notifies without replacing the installation state',
    () async {
      await viewModel.check();
      UpdateState? downloading;
      var notifications = 0;
      final phaseSubscription = viewModel.state.changes.listen((state) {
        if (state.phase == UpdatePhase.downloading) downloading = state;
      });
      final progressSubscription = viewModel.download.changes.listen((
        progress,
      ) {
        if (progress.received == 0) return;
        notifications++;
        expect(viewModel.state.current, same(downloading));
        expect(progress.fraction, greaterThan(0));
      });
      addTearDown(phaseSubscription.cancel);
      addTearDown(progressSubscription.cancel);
      await viewModel.activate();
      expect(notifications, greaterThan(0));
      expect(viewModel.state.current.phase, UpdatePhase.done);
    },
  );

  test(
    'a synchronous download listener cannot start a second installation',
    () async {
      await viewModel.check();
      Future<void>? nestedInstall;
      var notified = false;
      // The reset to zero is not a change, so react to the first progress.
      final subscription = viewModel.download.changes.listen((_) {
        if (!notified) {
          notified = true;
          nestedInstall = viewModel.activate();
        }
      });
      addTearDown(subscription.cancel);
      await viewModel.activate();
      await nestedInstall;
      expect(notified, isTrue);
      expect(host.calls.where((call) => call == 'begin'), hasLength(1));
      expect(viewModel.state.current.phase, UpdatePhase.done);
    },
  );

  test('check, download, validate, stop, install and open through Flutter viewModel', () async {
    await viewModel.check();
    expect(viewModel.state.current.phase, UpdatePhase.available);
    expect(host.calls, ['initialize', 'version']);
    await viewModel.activate();
    expect(viewModel.state.current.phase, UpdatePhase.done);
    expect(viewModel.state.current.busy, false);
    expect(viewModel.state.current.installedVersion, target);
    expect(
      File(p.join(directory.path, listenerExecutable)).readAsStringSync(),
      'new',
    );
    expect(host.calls, ['initialize', 'version', 'begin', 'stop', 'end']);
    await viewModel.activate();
    expect(host.calls.sublist(host.calls.length - 2), ['start', 'close']);
  });

  for (final scenario in [
    (installed: target, tag: '1.1.0', reinstall: true),
    (installed: target, tag: '1.1.0+3', reinstall: true),
    (installed: const AppVersion(2, 0, 0, 9), tag: '1.1.0', reinstall: false),
    (installed: const AppVersion(1, 1, 0, 4), tag: '1.1.0+3', reinstall: false),
  ]) {
    test('installs ${scenario.tag} over ${scenario.installed}', () async {
      host.version = scenario.installed;
      tag = scenario.tag;
      await viewModel.check();
      expect(viewModel.state.current.phase, UpdatePhase.available);
      expect(
        presentation().action,
        scenario.reinstall
            ? strings.reinstallListener
            : strings.downgradeListener(tag),
      );
      expect(host.calls, ['initialize', 'version']);
      expect(
        File(p.join(directory.path, listenerExecutable)).readAsStringSync(),
        'old',
      );
      await viewModel.activate();
      expect(viewModel.state.current.phase, UpdatePhase.done);
      expect(viewModel.state.current.installedVersion, target);
      expect(
        File(p.join(directory.path, listenerExecutable)).readAsStringSync(),
        'new',
      );
      expect(host.calls, ['initialize', 'version', 'begin', 'stop', 'end']);
      expect(presentation().action, strings.openListener);
      await viewModel.activate();
      expect(host.calls.sublist(host.calls.length - 2), ['start', 'close']);
    });
  }
  test(
    'reinstallation still verifies the checksum before closing the listener',
    () async {
      host.version = target;
      corrupt = true;
      await viewModel.check();
      await viewModel.activate();
      expect(viewModel.state.current.phase, UpdatePhase.error);
      expect(host.calls, ['initialize', 'version']);
      expect(
        File(p.join(directory.path, listenerExecutable)).readAsStringSync(),
        'old',
      );
    },
  );
  test('missing package cannot reinstall or downgrade', () async {
    host.version = const AppVersion(2, 0, 0);
    missingPackage = true;
    await viewModel.check();
    expect(viewModel.state.current.phase, UpdatePhase.error);
    expect(viewModel.state.current.error, UpdateIssue.packageUnavailable);
    expect(host.calls, ['initialize', 'version']);
  });
  test(
    'no GitHub release still offers opening the installed listener',
    () async {
      noRelease = true;
      await viewModel.check();
      expect(viewModel.state.current.phase, UpdatePhase.current);
      expect(presentation().action, strings.openListener);
      await viewModel.activate();
      expect(host.calls, ['initialize', 'version', 'start', 'close']);
    },
  );

  test('bad checksum never closes the listener or replaces files', () async {
    corrupt = true;
    await viewModel.check();
    await viewModel.activate();
    expect(viewModel.state.current.phase, UpdatePhase.error);
    final process =
        viewModel.state.current.process as FailedProcess<UpdateOperation>;
    expect(process.error, UpdateIssue.checksumMismatch);
    expect(process.token, UpdateOperation.install);
    expect(process.cause, isA<UpdateFailure>());
    expect(process.stackTrace, isNotNull);
    expect(viewModel.state.current.busy, isFalse);
    expect(host.calls, ['initialize', 'version']);
    expect(
      File(p.join(directory.path, listenerExecutable)).readAsStringSync(),
      'old',
    );
  });
  test('unresponsive listener releases gate without replacing files', () async {
    host.failStop = true;
    await viewModel.check();
    await viewModel.activate();
    expect(viewModel.state.current.phase, UpdatePhase.error);
    expect(viewModel.state.current.critical, false);
    expect(host.calls, ['initialize', 'version', 'begin', 'stop', 'end']);
    expect(
      File(p.join(directory.path, listenerExecutable)).readAsStringSync(),
      'old',
    );
  });
  test('another updater holding the lock prevents installation', () async {
    host.lockAvailable = false;
    await viewModel.check();
    await viewModel.activate();
    expect(viewModel.state.current.phase, UpdatePhase.error);
    expect(host.calls, ['initialize', 'version', 'begin']);
    expect(
      File(p.join(directory.path, listenerExecutable)).readAsStringSync(),
      'old',
    );
  });
  test('cancelling download keeps listener running', () async {
    await viewModel.check();
    final subscription = viewModel.download.changes.listen((progress) {
      if (progress.received > 0) {
        viewModel.cancel();
      }
    });
    addTearDown(subscription.cancel);
    await viewModel.activate();
    expect(viewModel.state.current.phase, UpdatePhase.error);
    expect(host.calls, ['initialize', 'version']);
    expect(
      File(p.join(directory.path, listenerExecutable)).readAsStringSync(),
      'old',
    );
  });
}

final class FakeHost implements UpdaterHost {
  final calls = <String>[];
  AppVersion version = const AppVersion(1, 0, 1, 2);
  bool failStop = false;
  bool lockAvailable = true;
  @override
  Future<void> initialize(String directory) async {
    calls.add('initialize');
  }

  @override
  Future<AppVersion> readVersion() async {
    calls.add('version');
    return version;
  }

  @override
  Future<bool> beginInstall() async {
    calls.add('begin');
    return lockAvailable;
  }

  @override
  Future<void> endInstall() async {
    calls.add('end');
  }

  @override
  Future<void> stopListener() async {
    calls.add('stop');
    if (failStop) throw const FormatException('Close listener manually');
  }

  @override
  Future<void> startListener() async {
    calls.add('start');
  }

  @override
  Future<void> close() async {
    calls.add('close');
  }
}

final class Responses implements HttpClientAdapter {
  Responses(this.respond);
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
