import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:listener_updater/launch_options.dart';
import 'package:listener_updater/l10n/generated/updater_localizations.dart';
import 'package:listener_updater/platform/updater_host.dart';
import 'package:listener_updater/update_view_model.dart';
import 'package:listener_updater/updater_view.dart';
import 'package:path/path.dart' as p;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('updater/host');
  LaunchOptions parse(
    List<String> args, [
    Locale system = const Locale('uk'),
  ]) => LaunchOptions.parse(
    args,
    executable: p.join(
      Directory.systemTemp.path,
      'Listener App',
      'updater',
      'listener_updater.exe',
    ),
    systemLocale: system,
  );

  test('standalone finds the parent installation and uses system locale', () {
    expect(p.basename(parse([]).directory), 'Listener App');
    expect(parse([]).locale, const Locale('uk'));
    expect(parse([], const Locale('fr')).locale, const Locale('en'));
  });
  test('arguments work in either order and normalize regional locales', () {
    final dir = p.join(Directory.systemTemp.path, 'Other Listener');
    expect(parse(['--locale', 'en-US', '--install-dir', dir]).directory, dir);
    expect(
      parse(['--locale', 'en-US', '--install-dir', dir]).locale,
      const Locale('en'),
    );
    expect(
      parse(['--install-dir', dir, '--locale', 'uk_UA']).locale,
      const Locale('uk'),
    );
    expect(parse(['--locale', 'de']).locale, const Locale('en'));
    expect(parse(['--locale', '--install-dir', dir]).directory, dir);
    expect(parse(['--locale']).locale, const Locale('uk'));
  });
  test('passes themes and uses the system for standalone launches', () {
    expect(parse([]).themeMode, ThemeMode.system);
    expect(
      parse(['--theme', 'dark', '--locale', 'uk']).themeMode,
      ThemeMode.dark,
    );
    expect(
      parse(['--locale', 'en', '--theme', 'light']).themeMode,
      ThemeMode.light,
    );
    expect(parse(['--theme', 'unknown']).themeMode, ThemeMode.system);
    expect(parse(['--theme']).themeMode, ThemeMode.system);
  });
  for (final language in ['en', 'uk']) {
    test(
      '$language localizes the native window title and viewModel errors',
      () async {
        final strings = lookupUpdaterLocalizations(Locale(language));
        final calls = <MethodCall>[];
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          calls.add(call);
          return null;
        });
        addTearDown(
          () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final dir = Directory.systemTemp.createTempSync('updater-locale-');
        addTearDown(() => dir.deleteSync(recursive: true));
        final viewModel = UpdateViewModel(
          directory: dir.path,
          host: WindowsUpdaterHost(title: strings.windowTitle),
        );
        addTearDown(viewModel.dispose);
        UpdatePresentation presentation() =>
            UpdatePresentation.fromState(viewModel.state.current, strings);
        expect(presentation().title, strings.checkingTitle);
        await viewModel.check();
        expect(calls.single.method, 'initialize');
        expect(calls.single.arguments, {
          'directory': dir.path,
          'title': strings.windowTitle,
          'dark': false,
        });
        expect(viewModel.state.current.phase, UpdatePhase.error);
        expect(presentation().title, strings.errorTitle);
        expect(presentation().detail, strings.invalidInstallation);
        expect(presentation().action, strings.retry);
      },
    );
  }
}
