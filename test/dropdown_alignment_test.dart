import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/rewards/actions/enable_input.dart';
import 'package:twitch_listener/rewards/actions/toggle_filter.dart';
import 'package:twitch_listener/rewards/actions/toggle_source.dart';
import 'package:twitch_listener/ui/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/ui/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/ui/dropdown/simple_dropdown.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/rewards/reward.dart';
import 'package:twitch_listener/ui/text_field_decoration.dart';
import 'package:twitch_listener/ui/themes.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'Windows dropdowns align with inputs, dark=$dark scale=$scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(960, 900);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final input = RewardAction(
            type: RewardAction.typeEnableInput,
            inputName: 'Microphone',
            enable: true,
          );
          final filter = RewardAction(
            type: RewardAction.typeToggleFilter,
            sourceName: 'Camera',
            filterName: 'Blur',
            action: 'enable',
          );
          final source = RewardAction(
            type: RewardAction.typeToggleSource,
            sceneName: 'Live',
            sourceName: 'Smoke',
            action: 'enable',
          );
          for (final action in [input, filter, source]) {
            addTearDown(action.dispose);
          }
          final manager = DropdownManager();
          addTearDown(manager.clear);
          final defaultDropdownKey = GlobalKey();
          final theme = dark ? Themes.dark : Themes.light;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: DropdownScope(
                manager: manager,
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      spacing: 24,
                      children: [
                        EnableInputWidget(
                          action: input,
                          changesCallback: () {},
                        ),
                        ToggleFilterWidget(
                          action: filter,
                          changesCallback: () {},
                        ),
                        ToggleSourceWidget(
                          action: source,
                          changesCallback: () {},
                        ),
                        SizedBox(
                          width: 160,
                          child: SimpleDropdown<bool>(
                            theme: theme,
                            title: 'Long selection',
                            available: [
                              Item(
                                id: true,
                                title: 'A selected value that exceeds the width of the field',
                              ),
                            ],
                            globalKey: defaultDropdownKey,
                            selected: true,
                            onSelected: (_) {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          for (final type in [
            EnableInputWidget,
            ToggleFilterWidget,
            ToggleSourceWidget,
          ]) {
            final section = find.byType(type);
            final field = find
                .descendant(
                  of: section,
                  matching: find.byType(TextFieldDecoration),
                )
                .first;
            final dropdown = find.descendant(
              of: section,
              matching: find.byWidgetPredicate(
                (widget) => widget is SimpleDropdown,
              ),
            );
            final button = find.descendant(
              of: dropdown,
              matching: find.byType(InkWell),
            );
            final inputRect = tester.getRect(field);
            final dropdownRect = tester.getRect(button);
            expect(
              dropdownRect.height,
              closeTo(inputRect.height, .01),
              reason: '$type height',
            );
            expect(
              dropdownRect.top,
              closeTo(inputRect.top, .01),
              reason: '$type top',
            );
            expect(
              dropdownRect.bottom,
              closeTo(inputRect.bottom, .01),
              reason: '$type bottom',
            );
          }
          expect(
            tester.getSize(find.byKey(defaultDropdownKey)).height,
            closeTo(
              tester.getSize(find.byType(TextFieldDecoration).first).height,
              .01,
            ),
          );

          final control = tester.widget<SimpleDropdown<bool>>(
            find.descendant(
              of: find.byType(EnableInputWidget),
              matching: find.byType(SimpleDropdown<bool>),
            ),
          );
          await tester.tap(find.byKey(control.globalKey));
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(DropdownPopupMenu<bool>),
              matching: find.text(
                control.available.firstWhere((item) => item.id == false).title,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(input.enable, isFalse);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
}
