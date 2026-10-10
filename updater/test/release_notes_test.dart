import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listener_updater/l10n/generated/updater_localizations.dart';
import 'package:listener_updater/release_notes.dart';
import 'package:listener_updater/updater_view.dart';

import 'test_fonts.dart';

const markdown = '''
# Listener 1.1.0

## What's new

- **Flutter updater** with *English and Ukrainian*.
- Keep your settings and use `Ctrl+Shift+O`.
  - Download and verify the package.
  - Save and close the listener.

1. Open the updater.
2. Select **Update**.

> Your settings and Twitch sign-in will be kept.

~~~powershell
./tool/build_release.ps1
~~~

| Download | Purpose |
| --- | --- |
| Release.zip | Full installation |
| update.zip | Application update |

~~Manual archive copying~~ is no longer needed.

[Release page](https://github.com/dealnotedev/twitch_rewards_app/releases/tag/1.1.0)
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.isWindows) {
      final font = File('${Platform.environment['WINDIR']}/Fonts/consola.ttf');
      await (FontLoader(
        'Consolas',
      )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    }
    await loadTestFonts();
  });

  Widget app(Widget child, {String language = 'en', GlobalKey? boundary}) =>
      MaterialApp(
        locale: Locale(language),
        localizationsDelegates: UpdaterLocalizations.localizationsDelegates,
        supportedLocales: UpdaterLocalizations.supportedLocales,
        theme: updaterTheme(),
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ),
      );

  testWidgets(
    'renders Markdown structure, keeps text selectable and opens a link',
    (tester) async {
      tester.view.physicalSize = const Size(660, 940);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opened = <Uri>[];
      final boundary = GlobalKey();
      await tester.pumpWidget(
        app(
          ReleaseNotes(
            data: markdown,
            openLink: (uri) async => opened.add(uri),
          ),
          boundary: boundary,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      expect(find.text('Listener 1.1.0', findRichText: true), findsWidgets);
      expect(find.text('# Listener 1.1.0', findRichText: true), findsNothing);
      expect(find.byType(Table), findsOneWidget);
      expect(find.byType(SelectableText), findsWidgets);
      final heading = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .firstWhere(
            (text) => text.textSpan?.toPlainText() == 'Listener 1.1.0',
          );
      expect(heading.textSpan!.style!.fontSize, 22);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/previews/markdown.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      final link = find.text('Release page', findRichText: true).last;
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(
        opened.single.toString(),
        'https://github.com/dealnotedev/twitch_rewards_app/releases/tag/1.1.0',
      );
    },
  );

  testWidgets('non-web links do not launch local files or commands', (
    tester,
  ) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      app(
        ReleaseNotes(
          data: '[Local file](file:///C:/Windows/notepad.exe)\n\n[Command](javascript:alert%281%29)',
          openLink: (uri) async => opened.add(uri),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local file', findRichText: true).last);
    await tester.tap(find.text('Command', findRichText: true).last);
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(tester.takeException(), null);
  });

  testWidgets('browser errors are localized', (tester) async {
    await tester.pumpWidget(
      app(
        ReleaseNotes(
          data: '[Release page](https://github.com)',
          openLink: (_) async => throw StateError('Cannot launch'),
        ),
        language: 'uk',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Release page', findRichText: true).last);
    await tester.pumpAndSettle();
    expect(
      find.text('Не вдалося відкрити посилання. Спробуйте ще.'),
      findsOneWidget,
    );
    expect(tester.takeException(), null);
  });
}
