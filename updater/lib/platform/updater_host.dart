import 'package:flutter/services.dart';

import '../core/app_version.dart';
import '../core/update_failure.dart';

abstract interface class UpdaterHost {
  Future<void> initialize(String directory);
  Future<AppVersion> readVersion();
  Future<bool> beginInstall();
  Future<void> endInstall();
  Future<void> stopListener();
  Future<void> startListener();
  Future<void> close();
}

final class WindowsUpdaterHost implements UpdaterHost {
  WindowsUpdaterHost({required this.title, this.dark = false});
  final String title;
  final bool dark;
  static const _channel = MethodChannel('updater/host');

  @override
  Future<void> initialize(String directory) => _channel.invokeMethod<void>(
    'initialize',
    {'directory': directory, 'title': title, 'dark': dark},
  );
  @override
  Future<AppVersion> readVersion() async =>
      AppVersion.parse((await _channel.invokeMethod<String>('readVersion'))!);
  @override
  Future<bool> beginInstall() async =>
      await _channel.invokeMethod<bool>('beginInstall') ?? false;
  @override
  Future<void> endInstall() => _channel.invokeMethod<void>('endInstall');
  @override
  Future<void> startListener() => _channel.invokeMethod<void>('startListener');
  @override
  Future<void> close() => _channel.invokeMethod<void>('close');

  @override
  Future<void> stopListener() async {
    await _channel.invokeMethod<void>('terminateListener');
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (await _channel.invokeMethod<bool>('isListenerRunning') == true) {
      if (DateTime.now().isAfter(deadline)) {
        throw const UpdateFailure(UpdateIssue.closeListener);
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}
