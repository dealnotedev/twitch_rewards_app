import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/ui/dropdown/dropdown_menu.dart';
import 'package:twitch_listener/ui/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/ui/dropdown/simple_dropdown.dart';
import 'package:twitch_listener/ui/themes.dart';

final _items = [
  Item(id: 'follow', title: 'Follow', icon: Assets.assetsIcThunderWhite16dp),
  Item(
    id: 'reward',
    title: 'Channel point reward',
    icon: Assets.assetsIcThunderWhite16dp,
  ),
  Item(id: 'message', title: 'Exact chat message'),
];

Future<GlobalKey> _pumpDropdown(
  WidgetTester tester, {
  bool compact = true,
  bool dark = false,
  double scale = 1,
  Size size = const Size(640, 480),
  Alignment alignment = Alignment.topRight,
  TextDirection direction = TextDirection.ltr,
  DropdownMenuWidth? menuWidth,
  ValueNotifier<String>? selection,
  List<Item<String>>? items,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final manager = DropdownManager();
  addTearDown(manager.clear);
  final key = GlobalKey();
  final selected = selection ?? ValueNotifier('follow');
  if (selection == null) addTearDown(selected.dispose);
  final theme = dark ? Themes.dark : Themes.light;

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: DropdownScope(
        manager: manager,
        child: Scaffold(
          body: Align(
            alignment: alignment,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ValueListenableBuilder<String>(
                valueListenable: selected,
                builder: (context, value, _) {
                  if (compact) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('Basic Settings')),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: SimpleDropdown<String>.compact(
                            theme: theme,
                            available: items ?? _items,
                            globalKey: key,
                            selected: value,
                            onSelected: (value) => selected.value = value,
                          ),
                        ),
                      ],
                    );
                  }
                  return SizedBox(
                    width: 160,
                    child: SimpleDropdown<String>(
                      theme: theme,
                      title: 'Trigger',
                      available: items ?? _items,
                      globalKey: key,
                      selected: value,
                      menuWidth: menuWidth ?? DropdownMenuWidth.anchor,
                      onSelected: (value) => selected.value = value,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('compact popup fits every option independently of selection, '
          'dark=$dark scale=$scale', (tester) async {
        final selected = ValueNotifier('follow');
        addTearDown(selected.dispose);
        final key = await _pumpDropdown(
          tester,
          dark: dark,
          scale: scale,
          selection: selected,
        );
        final shortButton = tester.getRect(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        final popup = find.byType(DropdownPopupMenu<String>);
        final firstRect = tester.getRect(popup);
        expect(firstRect.width, greaterThan(shortButton.width));
        expect(firstRect.right, closeTo(shortButton.right, .01));
        final longLabel = find.descendant(
          of: popup,
          matching: find.text('Channel point reward'),
        );
        final shortLabel = find.descendant(
          of: popup,
          matching: find.text('Follow'),
        );
        expect(
          tester.getSize(longLabel).height,
          closeTo(tester.getSize(shortLabel).height, .01),
          reason: 'the longest title fits on one line',
        );

        await tester.tap(longLabel);
        await tester.pumpAndSettle();
        expect(selected.value, 'reward');
        expect(popup, findsNothing);
        expect(
          tester.getSize(find.byKey(key)).width,
          greaterThan(shortButton.width),
        );

        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(tester.getSize(popup).width, closeTo(firstRect.width, .01));
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
    }
  }

  testWidgets('field popups keep matching the anchor by default', (
    tester,
  ) async {
    final key = await _pumpDropdown(tester, compact: false);
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(DropdownPopupMenu<String>)).width,
      closeTo(tester.getSize(find.byKey(key)).width, .01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a field can opt into content-sized popup width', (tester) async {
    final key = await _pumpDropdown(
      tester,
      compact: false,
      menuWidth: DropdownMenuWidth.content,
      scale: 1.5,
    );
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(DropdownPopupMenu<String>));
    expect(rect.width, greaterThan(tester.getSize(find.byKey(key)).width));
    expect(rect.right, lessThanOrEqualTo(632));
    expect(tester.takeException(), isNull);
  });

  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets('long menu stays inside a narrow window, $direction', (
      tester,
    ) async {
      final key = await _pumpDropdown(
        tester,
        size: const Size(320, 480),
        scale: 2,
        direction: direction,
        items: [
          Item(id: 'follow', title: 'Follow'),
          Item(
            id: 'long',
            title:
                'An exceptionally long localized trigger name that must wrap',
          ),
        ],
      );
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(DropdownPopupMenu<String>));
      expect(rect.left, greaterThanOrEqualTo(8));
      expect(rect.right, lessThanOrEqualTo(312));
      expect(rect.top, greaterThanOrEqualTo(8));
      expect(rect.bottom, lessThanOrEqualTo(472));
      final longOption = find.descendant(
        of: find.byType(DropdownPopupMenu<String>),
        matching: find.text(
          'An exceptionally long localized trigger name that must wrap',
        ),
      );
      await tester.tap(longOption);
      await tester.pumpAndSettle();
      expect(find.byType(DropdownPopupMenu<String>), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a bottom-edge popup opens above its button and can scroll', (
    tester,
  ) async {
    final selected = ValueNotifier('follow');
    addTearDown(selected.dispose);
    final key = await _pumpDropdown(
      tester,
      selection: selected,
      size: const Size(480, 320),
      alignment: Alignment.bottomRight,
      items: [
        Item(id: 'follow', title: 'Follow'),
        for (var i = 0; i < 20; i++) Item(id: '$i', title: 'Trigger $i'),
      ],
    );
    final button = tester.getRect(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    final popup = find.byType(DropdownPopupMenu<String>);
    final menu = tester.getRect(popup);
    expect(menu.bottom, lessThanOrEqualTo(button.top - 4));
    expect(menu.top, greaterThanOrEqualTo(8));
    final last = find.descendant(of: popup, matching: find.text('Trigger 19'));
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(selected.value, '19');
    expect(popup, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
