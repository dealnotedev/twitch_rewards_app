import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/simple_indicator.dart';
import 'package:twitch_listener/themes.dart';
import 'package:twitch_listener/twitch/redemption_queue_controller.dart';
import 'package:twitch_listener/twitch/redemption_queue_entry.dart';
import 'package:twitch_listener/twitch/redemption_queue_panel.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';
import 'package:twitch_listener/updates/update_controller.dart';
import 'package:twitch_listener/updates/update_notice.dart';

import 'redemption_fakes.dart';

Widget _screen(
  _PanelController controller, {
  UpdateController? update,
  double scale = 1,
  bool dark = true,
  bool widthReference = false,
}) => MaterialApp(
  theme: dark ? Themes.dark : Themes.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (update != null) UpdateNotice(controller: update),
          RedemptionQueuePanel(controller: controller),
          if (widthReference)
            const SizedBox(
              key: ValueKey('width-reference'),
              width: double.infinity,
              height: 1,
            ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('queue follows window width immediately during rapid resizing', (
    tester,
  ) async {
    final controller = _PanelController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(720, 900);
    await tester.pumpWidget(_screen(controller, widthReference: true));
    final queue = find.descendant(
      of: find.byType(RedemptionQueuePanel),
      matching: find.byType(AnimatedSize),
    );
    final reference = find.byKey(const ValueKey('width-reference'));
    for (final width in [1100.0, 640.0, 960.0, 720.0, 1050.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pump();
      expect(tester.getSize(reference).width, width);
      expect(
        tester.getSize(queue).width,
        tester.getSize(reference).width,
        reason: 'The queue must follow the window without a width animation',
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getSize(queue).width, width);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows viewer avatars, branded points and both decisions', (
    tester,
  ) async {
    final controller = _PanelController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_screen(controller));
    final avatar = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is NetworkImage,
    );
    expect(avatar, findsOneWidget);
    expect(
      (tester.widget<Image>(avatar).image as NetworkImage).url,
      'https://example.com/viewer.png',
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SimpleIndicator && widget.text == '750 points',
      ),
      findsNWidgets(2),
    );
    expect(find.text('1 total'), findsOneWidget);
    expect(find.byTooltip('Confirm now'), findsOneWidget);
    expect(find.byTooltip('Refund points'), findsOneWidget);
    expect(find.text('Confirm now'), findsNothing);
    expect(find.text('Refund points'), findsNothing);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Reaction completed'), findsNothing);
    final status = find.byTooltip('Reaction completed');
    expect(status, findsOneWidget);
    expect(
      tester.getCenter(status).dy,
      closeTo(tester.getCenter(find.text('Music')).dy, 1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('executing status has no track details or countdown', (
    tester,
  ) async {
    final controller = _PanelController(state: RedemptionQueueState.executing);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_screen(controller));
    expect(find.text('Reaction in progress'), findsNothing);
    expect(find.byTooltip('Reaction in progress'), findsOneWidget);
    expect(find.text('Auto confirmation'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('Track'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('confirmation slides right before closing the row and panel', (
    tester,
  ) async {
    final controller = _PanelController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_screen(controller));
    final row = find.byKey(
      const ValueKey('redemption-test-client:channel-one'),
    );
    final originalSize = tester.getSize(row);
    final originalPosition = tester.getTopLeft(find.text('Viewer'));
    await tester.tap(find.byTooltip('Confirm now'));
    await tester.pump();
    expect(controller.confirmed, 'one');
    expect(find.byTooltip('Execution confirmed'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('Viewer'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Viewer')).dx,
      greaterThan(originalPosition.dx),
    );
    expect(tester.getSize(row), originalSize);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.text('Viewer'), findsNothing);
    expect(find.text('Reward queue'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('refund button sends the selected redemption to the controller', (
    tester,
  ) async {
    final controller = _PanelController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_screen(controller));
    await tester.tap(find.byTooltip('Refund points'));
    await tester.pump();
    expect(controller.refunded, 'one');
    expect(find.byTooltip('Points refunded'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'queue follows the update banner and takes its position on dismissal',
    (tester) async {
      final controller = _PanelController();
      addTearDown(controller.dispose);
      final update = UpdateController(check: () async => '2.5.0');
      addTearDown(update.dispose);
      await tester.pumpWidget(_screen(controller, update: update));
      await tester.pump();
      final before = tester.getTopLeft(find.text('Reward queue')).dy;
      expect(
        before,
        greaterThan(tester.getBottomLeft(find.byType(UpdateNotice)).dy),
      );
      update.dismiss();
      await tester.pump();
      final after = tester.getTopLeft(find.text('Reward queue')).dy;
      expect(after, lessThan(before));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('fits narrow windows, enlarged text, and both themes', (
    tester,
  ) async {
    final controller = _PanelController();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final dark in [true, false]) {
      for (final width in [320.0, 640.0, 1100.0]) {
        tester.view.physicalSize = Size(width, 1100);
        await tester.pumpWidget(_screen(controller, scale: 1.6, dark: dark));
        await tester.pump();
        final problem = tester.takeException();
        expect(
          problem,
          isNull,
          reason:
              'width $width, dark $dark: ${problem is FlutterError ? problem.diagnostics.map((node) => node.toStringDeep()).join() : problem}',
        );
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _PanelController extends ChangeNotifier
    implements RedemptionQueueController {
  final record = RedemptionQueueEntry(
    account: 'test-client:channel',
    redemption: redemption('one'),
    manageable: true,
    state: RedemptionQueueState.waiting,
    confirmAt: DateTime.utc(2026, 10, 25, 12, 10),
    avatarUrl: 'https://example.com/viewer.png',
  );
  String? confirmed;
  String? refunded;
  _PanelController({
    RedemptionQueueState state = RedemptionQueueState.waiting,
  }) {
    record.state = state;
    if (state == RedemptionQueueState.executing) record.confirmAt = null;
  }
  @override
  DateTime Function() get now => _now;
  DateTime _now() => DateTime.utc(2026, 10, 25, 12);
  @override
  String get accountKey => 'test-client:channel';
  @override
  TwitchRewardsError? get setupError => null;
  @override
  List<RedemptionQueueEntry> get entries => record.terminal ? [] : [record];
  @override
  bool canDecide(RedemptionQueueEntry entry) => !entry.terminal;
  @override
  bool isBusy(String id) => false;
  @override
  Future<void> confirmNow(String id) async {
    confirmed = id;
    record.state = RedemptionQueueState.confirmed;
    notifyListeners();
  }

  @override
  Future<void> refund(String id) async {
    refunded = id;
    record.state = RedemptionQueueState.refunded;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
