import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/actions/delay.dart';
import 'package:twitch_listener/integer_input_formatter.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/reward.dart';
import 'package:twitch_listener/themes.dart';

void main() {
  const formatter = UnsignedIntegerInputFormatter();
  const oldValue = TextEditingValue(
    text: '500',
    selection: TextSelection.collapsed(offset: 2),
  );

  test(
    'invalid pasted numbers are rejected without changing their meaning',
    () {
      for (final text in [
        'text',
        '12a',
        '-100',
        '+100',
        '12.5',
        '1,5',
        '1e3',
        '0x10',
        '12\n',
        ' 12 ',
        '１２',
        '9223372036854775808',
        '9999999999999999999999999999999999999999',
      ]) {
        final value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        expect(
          formatter.formatEditUpdate(oldValue, value),
          same(oldValue),
          reason: text,
        );
      }
    },
  );

  test('empty input, zero and full 64-bit integers keep cursor and composing range', () {
    for (final text in ['', '0', '0005', '800', '9223372036854775807']) {
      final value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.isEmpty ? 0 : 1),
        composing: text.isEmpty
            ? TextRange.empty
            : const TextRange(start: 0, end: 1),
      );
      expect(formatter.formatEditUpdate(oldValue, value), same(value));
    }
  });

  test('a field-specific maximum rejects overflow without truncation', () {
    const bounded = UnsignedIntegerInputFormatter(maxValue: 10);
    expect(
      bounded.formatEditUpdate(oldValue, const TextEditingValue(text: '11')),
      same(oldValue),
    );
    expect(
      bounded
          .formatEditUpdate(oldValue, const TextEditingValue(text: '10'))
          .text,
      '10',
    );
    expect(
      bounded
          .formatEditUpdate(oldValue, const TextEditingValue(text: '0'))
          .text,
      '0',
    );
  });

  for (final dark in [false, true]) {
    testWidgets('delay input handles numbers, paste and clearing, dark=$dark', (
      tester,
    ) async {
      final action = RewardAction(type: RewardAction.typeDelay, millis: 1200);
      addTearDown(action.dispose);
      var clipboard = '';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboard = (call.arguments as Map)['text'] as String;
            return null;
          case 'Clipboard.getData':
            return {'text': clipboard};
          case 'Clipboard.hasStrings':
            return {'value': clipboard.isNotEmpty};
          default:
            return null;
        }
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? Themes.dark : Themes.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: DelayWidget(
                action: action,
                changesCallback: () => changes++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      final input = tester.widget<TextField>(field);
      expect(
        input.keyboardType,
        const TextInputType.numberWithOptions(signed: false, decimal: false),
      );
      expect(input.textInputAction, TextInputAction.done);
      expect(input.autocorrect, isFalse);
      expect(input.enableSuggestions, isFalse);

      for (final invalid in ['-50', '12.5', '25ms', '9223372036854775808']) {
        await tester.enterText(field, invalid);
        expect(input.controller!.text, '1200');
        expect(action.millis, 1200);
        expect(changes, 0);
      }
      await tester.enterText(field, '2500');
      expect(action.millis, 2500);
      expect(changes, 1);
      input.controller!.selection = const TextSelection.collapsed(offset: 1);
      expect(changes, 1);

      await Clipboard.setData(const ClipboardData(text: '-100'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(input.controller!.text, '2500');
      expect(action.millis, 2500);

      await tester.enterText(field, '');
      expect(action.millis, 0);
      expect(changes, 2);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(input.controller!.text, '0');
      expect(input.focusNode!.hasFocus, isFalse);

      const maximumMillis =
          0x7fffffffffffffff ~/ Duration.microsecondsPerMillisecond;
      await tester.enterText(field, '${maximumMillis + 1}');
      expect(input.controller!.text, '0');
      await tester.enterText(field, '$maximumMillis');
      expect(action.millis, maximumMillis);
      expect(
        Duration(milliseconds: action.millis).inMicroseconds,
        greaterThanOrEqualTo(0),
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
