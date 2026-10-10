import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listener_updater/main.dart';
import 'package:listener_updater/platform/updater_host.dart';
import 'package:listener_updater/update_view_model.dart';

final class _InitializingHost extends Fake implements UpdaterHost {
  final initialized = Completer<void>();
  @override
  Future<void> initialize(String directory) => initialized.future;
}

void main() {
  testWidgets('honors the supplied light or dark theme', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final host = _InitializingHost();
      late UpdateViewModel model;
      await tester.pumpWidget(
        UpdaterApp(
          key: ValueKey(mode),
          themeMode: mode,
          createViewModel: () =>
              model = UpdateViewModel(directory: 'unused', host: host),
        ),
      );
      final context = tester.element(find.byType(Scaffold));
      expect(
        Theme.of(context).brightness,
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      host.initialized.complete();
      await model.check();
    }
  });
  testWidgets('the app disposes a model created by its factory', (
    tester,
  ) async {
    final host = _InitializingHost();
    late UpdateViewModel model;
    await tester.pumpWidget(
      UpdaterApp(
        createViewModel: () => model = UpdateViewModel(
          directory: 'unused-before-initialization',
          host: host,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(model.isDisposed, isTrue);
    host.initialized.complete();
    await model.check();
  });

  testWidgets(
    'the app leaves injected models with their owner after replacement',
    (tester) async {
      final firstHost = _InitializingHost();
      final secondHost = _InitializingHost();
      final first = UpdateViewModel(directory: 'unused', host: firstHost);
      final second = UpdateViewModel(directory: 'unused', host: secondHost);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(UpdaterApp.withViewModel(viewModel: first));
      await tester.pumpWidget(UpdaterApp.withViewModel(viewModel: second));
      expect(first.isDisposed, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(second.isDisposed, isFalse);
      first.dispose();
      second.dispose();
      firstHost.initialized.complete();
      secondHost.initialized.complete();
      await Future.wait([first.check(), second.check()]);
    },
  );
}
