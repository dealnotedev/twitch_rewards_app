import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/points/viewer_balance.dart';
import 'package:twitch_listener/points/viewer_balances_screen.dart';
import 'package:twitch_listener/points/viewer_balances_store.dart';
import 'package:twitch_listener/ui/themes.dart';

const _alice = ViewerBalance(
  viewerId: '123456789',
  username: 'alice_login',
  displayName: 'Alice',
  balance: 950,
);
const _svitlana = ViewerBalance(
  viewerId: '987654321',
  username: 'svitlana',
  displayName: 'СвітЛана',
  balance: 200,
);

void main() {
  late _Store store;
  setUp(() => store = _Store());
  tearDown(() => store.events.close());

  Future<void> showScreen(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? Themes.dark : Themes.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: ViewerBalancesScreen(store: store)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(ValueKey('viewer-balance-$id'));
  final search = find.byKey(const ValueKey('viewer-balances-search'));

  for (final dark in [false, true]) {
    testWidgets(
      'table and literal substring search work for names and IDs, dark=$dark',
      (tester) async {
        await showScreen(tester, dark: dark);
        expect(find.text('Viewer name'), findsOneWidget);
        expect(find.text('Display name'), findsNothing);
        expect(find.text('Username'), findsNothing);
        expect(find.text('Twitch ID'), findsOneWidget);
        expect(find.text('Balance'), findsOneWidget);
        expect(find.byType(Tooltip), findsNothing);
        final id = find.text(_alice.viewerId);
        final name = find.text('Alice (@alice_login)');
        final amount = find.text('950');
        expect(name, findsOneWidget);
        expect(tester.getRect(id).right, lessThan(tester.getRect(name).left));
        expect(
          tester.getRect(name).right,
          lessThan(tester.getRect(amount).left),
        );
        expect(find.text('2 of 2 viewers'), findsOneWidget);
        expect(row(_alice.viewerId), findsOneWidget);
        expect(row(_svitlana.viewerId), findsOneWidget);
        for (final query in ['ICE_LOG', 'LiCe', '34567', '  ALICE  ']) {
          await tester.enterText(search, query);
          await tester.pumpAndSettle();
          expect(row(_alice.viewerId), findsOneWidget, reason: query);
          expect(row(_svitlana.viewerId), findsNothing, reason: query);
        }
        await tester.enterText(search, 'ІтЛА');
        await tester.pumpAndSettle();
        expect(row(_alice.viewerId), findsNothing);
        expect(row(_svitlana.viewerId), findsOneWidget);
        expect(find.text('1 of 2 viewers'), findsOneWidget);
        for (final query in ['missing', '%', '_']) {
          // '_' matches the literal underscore in alice_login, '%' matches none.
          await tester.enterText(search, query);
          await tester.pumpAndSettle();
          expect(
            row(_alice.viewerId),
            query == '_' ? findsOneWidget : findsNothing,
          );
          expect(row(_svitlana.viewerId), findsNothing);
          if (query != '_') {
            expect(find.text('No viewers match your search.'), findsOneWidget);
          }
        }
        tester.widget<TextField>(search).controller!.clear();
        await tester.pumpAndSettle();
        expect(row(_alice.viewerId), findsOneWidget);
        expect(row(_svitlana.viewerId), findsOneWidget);
        expect(
          store.loads,
          1,
          reason: 'Typing filters the loaded list without database queries',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'successful balance changes refresh the table and preserve the filter',
    (tester) async {
      await showScreen(tester);
      await tester.enterText(search, 'alice');
      await tester.pumpAndSettle();
      store.rows = [
        const ViewerBalance(
          viewerId: '123456789',
          username: 'alice_new',
          displayName: 'New Alice',
          balance: 999,
        ),
        _svitlana,
      ];
      store.events.add(null);
      await tester.pumpAndSettle();
      expect(find.text('New Alice (@alice_new)'), findsOneWidget);
      expect(find.text('999'), findsOneWidget);
      expect(find.text('950'), findsNothing);
      expect(row(_svitlana.viewerId), findsNothing);
      expect(tester.widget<TextField>(search).controller!.text, 'alice');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('handles empty data, database failure and refresh retry', (
    tester,
  ) async {
    store.fail = true;
    await showScreen(tester);
    expect(
      find.text('Could not load viewer balances. Select Refresh to try again.'),
      findsOneWidget,
    );
    store.fail = false;
    store.rows = [];
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No viewer balances yet. Credit viewer points from a reaction chain to get started.',
      ),
      findsOneWidget,
    );
    store.rows = [_alice];
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(row(_alice.viewerId), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'coalesces refreshes during a query and ignores a response after leaving',
    (tester) async {
      await showScreen(tester);
      final gate = Completer<List<ViewerBalance>>();
      store.nextLoad = gate.future;
      await tester.tap(find.text('Refresh'));
      await tester.pump();
      store.rows = [_svitlana];
      store.events.add(null);
      await tester.pump();
      gate.complete([_alice]);
      await tester.pumpAndSettle();
      expect(row(_alice.viewerId), findsNothing);
      expect(row(_svitlana.viewerId), findsOneWidget);
      final lateResult = Completer<List<ViewerBalance>>();
      store.nextLoad = lateResult.future;
      await tester.tap(find.text('Refresh'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      lateResult.complete([_alice]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long names and maximum balances fit large text without horizontal scrolling',
    (tester) async {
      store.rows = [
        for (var i = 0; i < 200; i++)
          ViewerBalance(
            viewerId: 'viewer-$i',
            username: 'very_long_username_$i',
            displayName: 'A very long display name for viewer $i',
            balance: ViewerBalancesStore.maxBalance,
          ),
      ];
      await showScreen(tester, dark: true, scale: 2);
      expect(row('viewer-0'), findsOneWidget);
      expect(row('viewer-199'), findsNothing, reason: 'Rows are built lazily');
      expect(find.byType(Tooltip), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
        findsNothing,
      );
      final maximum = find.text('9223372036854775807').first;
      final id = find.text('viewer-0');
      final name = find.text(
        'A very long display name for viewer 0 (@very_long_username_0)',
      );
      expect(name, findsOneWidget);
      expect(tester.getRect(id).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(id).right, lessThan(tester.getRect(name).left));
      expect(
        tester.getRect(name).right,
        lessThan(tester.getRect(maximum).left),
      );
      expect(tester.getRect(maximum).right, lessThanOrEqualTo(640));
      final list = tester.widget<ListView>(
        find.byKey(const ValueKey('viewer-balances-rows')),
      );
      list.controller!.jumpTo(3000);
      await tester.pumpAndSettle();
      expect(row('viewer-0'), findsNothing);
      await tester.enterText(search, 'viewer-199');
      await tester.pumpAndSettle();
      expect(row('viewer-199'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Store implements ViewerBalancesStore {
  final events = StreamController<void>.broadcast();
  List<ViewerBalance> rows = [_alice, _svitlana];
  bool fail = false;
  int loads = 0;
  Future<List<ViewerBalance>>? nextLoad;

  @override
  Stream<void> get changes => events.stream;

  @override
  Future<List<ViewerBalance>> loadBalances() async {
    loads++;
    if (fail) throw StateError('Database unavailable');
    final pending = nextLoad;
    nextLoad = null;
    return pending == null ? List.of(rows) : await pending;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
