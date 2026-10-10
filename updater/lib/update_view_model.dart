import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:observable_state/observable_state.dart';

import 'core/app_version.dart';
import 'core/installation.dart';
import 'core/release_client.dart';
import 'core/update_failure.dart';
import 'core/update_package.dart';
import 'platform/updater_host.dart';

void _recover(Installation installation) => installation.recover();
void _prepare(Installation installation) => installation.prepare();
void _clean(Installation installation) => installation.cleanWork();
void _apply((Installation, PackageManifest) args) => args.$1.apply(args.$2);
PackageManifest _extract((String, String, AppVersion) args) =>
    extractPackage(args.$1, args.$2, args.$3);

enum UpdatePhase {
  checking,
  current,
  available,
  downloading,
  verifying,
  stopping,
  installing,
  recovering,
  done,
  error,
}

enum UpdateOperation { check, install, open }

final class UpdateState {
  const UpdateState({
    this.stage = UpdatePhase.checking,
    this.process = const FailableProcess<UpdateOperation>.initial(),
    this.critical = false,
    this.installedVersion,
    this.release,
    this.progress,
  });

  final UpdatePhase stage;
  final FailableProcess<UpdateOperation> process;
  final bool critical;
  final AppVersion? installedVersion;
  final Release? release;
  final double? progress;

  UpdatePhase get phase => process.isFailed ? UpdatePhase.error : stage;
  bool get busy => process.isActive;
  UpdateIssue? get error => switch (process.error) {
    UpdateIssue issue => issue,
    _ => null,
  };
  bool get canInstall => release?.download != null && installedVersion != null;
  int get releaseComparison =>
      installedVersion!.matchesRelease(release!.version)
      ? 0
      : release!.version.compareTo(installedVersion!);

  UpdateState copyWith({
    UpdatePhase? stage,
    FailableProcess<UpdateOperation>? process,
    bool? critical,
    Nullable<AppVersion>? installedVersion,
    Nullable<Release>? release,
    Nullable<double>? progress,
  }) => UpdateState(
    stage: stage ?? this.stage,
    process: process ?? this.process,
    critical: critical ?? this.critical,
    installedVersion: installedVersion.getOr(this.installedVersion),
    release: release.getOr(this.release),
    progress: progress.getOr(this.progress),
  );
}

final class DownloadProgress {
  const DownloadProgress({this.received = 0, this.total = 0});

  final int received;
  final int total;
  double? get fraction => total > 0 ? (received / total).clamp(0, 1) : null;
}

final class UpdateViewModel extends BaseViewModel {
  UpdateViewModel({
    required this.directory,
    required this.host,
    ReleaseClient? client,
  }) : client = client ?? ReleaseClient() {
    _state = register(
      ObservableValue<UpdateState>(
        current: const UpdateState(
          process: FailableProcess<UpdateOperation>.loading(
            UpdateOperation.check,
          ),
        ),
      ),
    );
    _download = register(
      ObservableValue<DownloadProgress>(current: const DownloadProgress()),
    );
    _checking = _runCheck().whenComplete(() => _checking = null);
  }

  late final ObservableValue<UpdateState> _state;
  late final ObservableValue<DownloadProgress> _download;

  Observable<UpdateState> get state => _state;
  Observable<DownloadProgress> get download => _download;

  final String directory;
  final UpdaterHost host;
  final ReleaseClient client;
  Installation? _installation;
  CancelToken _cancellation = CancelToken();
  Future<void>? _checking;

  void _status(UpdatePhase stage, {double? fraction}) {
    if (isDisposed) return;
    _state.set(
      _state.current.copyWith(stage: stage, progress: Nullable(fraction)),
    );
  }

  void _complete() {
    if (!isDisposed && _state.current.process.isActive) {
      _state.set(
        _state.current.copyWith(
          process: const FailableProcess<UpdateOperation>.initial(),
        ),
      );
    }
  }

  Future<void> check() {
    if (_checking case final pending?) return pending;
    if (isDisposed || _state.current.busy) return Future.value();
    _cancellation = CancelToken();
    _state.set(
      _state.current.copyWith(
        stage: UpdatePhase.checking,
        progress: const Nullable(null),
        process: const FailableProcess<UpdateOperation>.loading(
          UpdateOperation.check,
        ),
      ),
    );
    return _checking = _runCheck().whenComplete(() => _checking = null);
  }

  Future<void> _runCheck() async {
    try {
      await host.initialize(directory);
      if (isDisposed) return;
      final installation = await compute(Installation.new, directory);
      if (isDisposed) return;
      _installation = installation;
      if (installation.needsRecovery) {
        await _withInstallLock(() async {
          _status(UpdatePhase.recovering);
          await host.stopListener();
          await compute(_recover, installation);
        });
      }
      final version = await host.readVersion();
      if (isDisposed) return;
      _state.set(_state.current.copyWith(installedVersion: Nullable(version)));
      if (isDisposed) return;
      final latest = await client.latest(_cancellation);
      if (isDisposed) return;
      _state.set(_state.current.copyWith(release: Nullable(latest)));
      if (_state.current.release != null) {
        if (_state.current.release!.download == null) {
          throw const UpdateFailure(UpdateIssue.packageUnavailable);
        }
        _status(UpdatePhase.available, fraction: 0);
      } else {
        _status(UpdatePhase.current, fraction: 1);
      }
    } catch (error, stack) {
      _error(error, stack);
    } finally {
      _complete();
    }
  }

  Future<void> activate() async {
    if (isDisposed || _state.current.busy) return;
    if (_state.current.phase == UpdatePhase.error) {
      await check();
      return;
    }
    if (!_state.current.canInstall ||
        _state.current.phase == UpdatePhase.done) {
      _state.set(
        _state.current.copyWith(
          process: const FailableProcess<UpdateOperation>.loading(
            UpdateOperation.open,
          ),
        ),
      );
      try {
        await host.startListener();
        if (!isDisposed) await host.close();
      } catch (error, stack) {
        _error(error, stack);
      } finally {
        _complete();
      }
      return;
    }
    await _install();
  }

  Future<void> _install() async {
    final installation = _installation!;
    final target = _state.current.release!;
    _cancellation = CancelToken();
    _state.set(
      _state.current.copyWith(
        stage: UpdatePhase.downloading,
        progress: const Nullable(0),
        process: const FailableProcess<UpdateOperation>.loading(
          UpdateOperation.install,
        ),
      ),
    );
    if (isDisposed) return;
    _download.set(const DownloadProgress());
    if (isDisposed) return;
    Object? failure;
    StackTrace? failureStack;
    try {
      await compute(_prepare, installation);
      if (isDisposed) return;
      await client.download(target, installation.archive, _cancellation, (
        count,
        total,
      ) {
        if (isDisposed) return;
        _download.set(DownloadProgress(received: count, total: total));
      });
      if (isDisposed) return;
      _status(UpdatePhase.verifying);
      final package = await compute(_extract, (
        installation.archive,
        installation.stage,
        target.version,
      ));
      if (_cancellation.isCancelled) throw _cancellation.cancelError!;
      await _withInstallLock(() async {
        _status(UpdatePhase.stopping);
        await host.stopListener();
        _status(UpdatePhase.installing);
        await compute(_apply, (installation, package));
      });
      if (isDisposed) return;
      _state.set(
        _state.current.copyWith(installedVersion: Nullable(package.version)),
      );
      _status(UpdatePhase.done, fraction: 1);
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    } finally {
      try {
        await compute(_clean, installation);
      } on FileSystemException {
        /* Keep recoverable files. */
      } finally {
        // Retry must remain blocked until the old installation cleanup ends.
        if (failure != null) {
          _error(failure, failureStack!);
        } else {
          _complete();
        }
      }
    }
  }

  Future<void> _withInstallLock(Future<void> Function() operation) async {
    if (!await host.beginInstall()) {
      throw const UpdateFailure(UpdateIssue.updateBusy);
    }
    if (!isDisposed) _state.set(_state.current.copyWith(critical: true));
    try {
      await operation();
    } finally {
      await host.endInstall();
      if (!isDisposed) _state.set(_state.current.copyWith(critical: false));
    }
  }

  void cancel() {
    if (!isDisposed && !_state.current.critical) {
      _cancellation.cancel('User cancelled');
    }
  }

  void _error(Object error, StackTrace stack) {
    if (isDisposed) return;
    final issue = switch (error) {
      UpdateFailure e => e.issue,
      UpdateFileFailure e => e.issue,
      DioException e when CancelToken.isCancel(e) => UpdateIssue.cancelled,
      DioException() || HttpException() => UpdateIssue.network,
      FileSystemException() => UpdateIssue.fileSystem,
      FormatException() => UpdateIssue.invalidPackage,
      _ => UpdateIssue.unexpected,
    };
    _state.set(
      _state.current.copyWith(
        process: FailableProcess<UpdateOperation>.failed(
          issue,
          token: _state.current.process.token,
          cause: error,
          stackTrace: stack,
        ),
        progress: const Nullable(0),
      ),
    );
  }

  @override
  void dispose() {
    if (isDisposed) return;
    super.dispose();
    _cancellation.cancel();
    client.close();
  }
}
