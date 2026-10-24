import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/themes.dart';
import 'package:twitch_listener/twitch/reward_color_picker.dart';

void main() {
  late TextEditingController color;
  late GlobalKey<FormState> form;
  late GlobalKey pickerBoundary;

  Future<void> showPicker(
    WidgetTester tester, {
    bool enabled = true,
    bool dark = false,
  }) async {
    color = TextEditingController(text: '#6441AD');
    form = GlobalKey<FormState>();
    pickerBoundary = GlobalKey();
    addTearDown(color.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? Themes.dark : Themes.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 568,
              child: Form(
                key: form,
                child: RepaintBoundary(
                  key: pickerBoundary,
                  child: RewardColorPicker(
                    controller: color,
                    cost: 500,
                    enabled: enabled,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('HEX input paints exact RGB in preview, dark=$dark', (
      tester,
    ) async {
      await showPicker(tester, dark: dark);
      for (final hex in ['#392e5c', '#7aa7ff', '#00ff00']) {
        await tester.enterText(find.byType(TextFormField), hex);
        await tester.pumpAndSettle();
        final preview = tester.getTopLeft(
          find.byKey(const ValueKey('reward-color-preview')),
        );
        final origin = tester.getTopLeft(find.byKey(pickerBoundary));
        final sample = preview - origin + const Offset(12, 12);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(pickerBoundary),
        );
        final rgb = await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final offset =
                (sample.dy.floor() * image.width + sample.dx.floor()) * 4;
            return (bytes!.getUint8(offset) << 16) |
                (bytes.getUint8(offset + 1) << 8) |
                bytes.getUint8(offset + 2);
          } finally {
            image.dispose();
          }
        });
        expect(rgb, int.parse(hex.substring(1), radix: 16), reason: hex);
      }
    });

    testWidgets(
      'palette, direct input and validation stay synchronized, dark=$dark',
      (tester) async {
        await showPicker(tester, dark: dark);
        await tester.tap(find.byKey(const ValueKey('reward-color-#10B981')));
        await tester.pumpAndSettle();
        expect(color.text, '#10B981');
        await tester.enterText(find.byType(TextFormField), '#00FF00');
        await tester.pumpAndSettle();
        expect(
          tester.widget<Slider>(find.byType(Slider)).value,
          closeTo(120, .01),
        );
        expect(form.currentState!.validate(), isTrue);
        await tester.enterText(find.byType(TextFormField), '#XYZ');
        expect(form.currentState!.validate(), isFalse);
        await tester.pumpAndSettle();
        expect(find.text('Enter a color such as #6441AD.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saturation and brightness can be selected with pointer and keyboard',
    (tester) async {
      await showPicker(tester);
      final plane = find.byKey(const ValueKey('reward-color-plane'));
      await tester.tapAt(tester.getCenter(plane));
      await tester.pumpAndSettle();
      final before = HSVColor.fromColor(
        Color(int.parse('FF${color.text.substring(1)}', radix: 16)),
      );
      expect(before.saturation, closeTo(.5, .01));
      expect(before.value, closeTo(.5, .01));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final after = HSVColor.fromColor(
        Color(int.parse('FF${color.text.substring(1)}', radix: 16)),
      );
      expect(after.saturation, greaterThan(before.saturation));
      expect(after.value, lessThan(before.value));
      expect(form.currentState!.validate(), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saving disables pointer changes and manual color edits', (
    tester,
  ) async {
    await showPicker(tester, enabled: false);
    await tester.tap(find.byKey(const ValueKey('reward-color-#EF4444')));
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('reward-color-plane'))),
    );
    await tester.pumpAndSettle();
    expect(color.text, '#6441AD');
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
