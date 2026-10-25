import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/ui/themes.dart';
import 'package:twitch_listener/updates/update_controller.dart';
import 'package:twitch_listener/updates/update_notice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    if (Platform.isWindows) {
      for (final family in ['Roboto', 'Segoe UI']) {
        await (FontLoader(family)..addFont(
              File('${Platform.environment['WINDIR']}/Fonts/segoeui.ttf')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            ))
            .load();
      }
    }
  });

  Widget app(
    UpdateController controller,
    Brightness brightness, {
    GlobalKey? boundary,
  }) => MaterialApp(
    theme: brightness == Brightness.dark ? Themes.dark : Themes.light,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
    home: RepaintBoundary(
      key: boundary,
      child: Scaffold(
        body: Column(
          children: [
            const SizedBox(height: 16),
            UpdateNotice(controller: controller),
          ],
        ),
      ),
    ),
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'banner passes the visible ${brightness.name} theme and active locale',
      (tester) async {
        tester.view.physicalSize = const Size(640, 155);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final launches = <(String, String)>[];
        var checks = 0;
        final controller = UpdateController(
          check: () async {
            checks++;
            return '2.2.0';
          },
          launch: (locale, theme) async {
            launches.add((locale, theme));
          },
        );
        addTearDown(controller.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          app(controller, brightness, boundary: boundary),
        );
        await tester.pumpAndSettle();
        expect(find.text('Version 2.2.0 is available'), findsOneWidget);
        expect(tester.takeException(), null);
        await tester.tap(find.text('Open updater'));
        await tester.pumpAndSettle();
        expect(launches, [('en', brightness.name)]);
        await tester.pumpWidget(
          app(controller, brightness, boundary: boundary),
        );
        expect(checks, 1);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File(
            'build/previews/update-banner-${brightness.name}.png',
          );
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(find.byTooltip('Dismiss update notification'));
        await tester.pumpAndSettle();
        expect(find.text('Version 2.2.0 is available'), findsNothing);
      },
    );
  }

  testWidgets('failed launch remains visible and can be retried', (
    tester,
  ) async {
    var attempts = 0;
    final controller = UpdateController(
      check: () async => '2.2.0',
      launch: (_, _) async {
        if (++attempts == 1) throw StateError('missing updater');
      },
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(controller, Brightness.light));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open updater'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't open the updater"), findsOneWidget);
    await tester.tap(find.text('Open updater'));
    await tester.pumpAndSettle();
    expect(controller.launchFailed, false);
    expect(attempts, 2);
  });

  testWidgets('no release and failed checks leave the banner hidden', (
    tester,
  ) async {
    for (final check in <Future<String?> Function()>[
      () async => null,
      () async => throw StateError('offline'),
    ]) {
      final controller = UpdateController(check: check);
      await tester.pumpWidget(app(controller, Brightness.light));
      await tester.pumpAndSettle();
      expect(find.text('Open updater'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  test(
    'late check completion after disposal does not notify listeners',
    () async {
      final result = Completer<String?>();
      final controller = UpdateController(check: () => result.future);
      controller.dispose();
      result.complete('2.2.0');
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'launches once while opening and supplies the native arguments',
    () async {
      const channel = MethodChannel('listener/update');
      final completed = Completer<void>();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            await completed.future;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final controller = UpdateController(check: () async => '2.2.0');
      addTearDown(controller.dispose);
      final opening = controller.open(
        locale: 'uk',
        brightness: Brightness.dark,
      );
      await controller.open(locale: 'en', brightness: Brightness.light);
      completed.complete();
      await opening;
      expect(calls.single.method, 'openUpdater');
      expect(calls.single.arguments, {'locale': 'uk', 'theme': 'dark'});
    },
  );
}
