import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twitch_listener/ui/buttons.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/ui/themes.dart';
import 'package:twitch_listener/twitch/dto.dart';
import 'package:twitch_listener/twitch/redemption_queue_entry.dart';
import 'package:twitch_listener/twitch/reward_delete_dialog.dart';
import 'package:twitch_listener/twitch/reward_editor.dart';
import 'package:twitch_listener/twitch/rewards_controller.dart';

import 'redemption_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const previewDirectory = String.fromEnvironment(
      'REWARD_DELETE_PREVIEW_DIR',
    );
    if (previewDirectory.isEmpty || !Platform.isWindows) return;
    final loader = FontLoader('Roboto')
      ..addFont(
        File('C:/Windows/Fonts/segoeui.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      )
      ..addFont(
        File('C:/Windows/Fonts/seguisb.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
    await loader.load();
  });
  void window(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  Widget app(
    Widget home, {
    bool dark = false,
    double scale = 1,
    GlobalKey? preview,
  }) => MaterialApp(
    theme: dark ? Themes.dark : Themes.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => RepaintBoundary(
      key: preview,
      child: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: child!),
      ),
    ),
    home: home,
  );

  Future<void> openEditor(
    WidgetTester tester,
    QueueHarness h, {
    bool dark = false,
    bool creating = false,
    RedemptionDto? reward,
  }) async {
    window(tester, 720);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<RedemptionDto>(
                builder: (_) => TwitchRewardEditor(
                  controller: h.rewards,
                  reward: creating ? null : reward ?? h.rewards.rewards.first,
                ),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
        dark: dark,
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  Future<void> finishDeletion(WidgetTester tester) async {
    final forbidden = AppLocalizations.of(
      tester.element(find.byType(TwitchRewardEditor)),
    )!.twitch_rewards_error_forbidden;
    for (var frame = 0; frame < 24; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.text(forbidden, skipOffstage: false),
        findsNothing,
        reason: 'Successful deletion must not flash a permission error',
      );
    }
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
      'empty requests show Cancel and Delete; deletion returns from the editor, dark=$dark',
      (tester) async {
        final h = (await tester.runAsync(QueueHarness.create))!;
        addTearDown(h.close);
        await openEditor(tester, h, dark: dark);
        await tester.tap(find.widgetWithText(CustomButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(find.byType(TwitchRewardDeleteDialog), findsOneWidget);
        expect(find.text('0 pending requests'), findsOneWidget);
        expect(find.text('0 points'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(TwitchRewardDeleteDialog),
            matching: find.byType(CustomButton),
          ),
          findsNWidgets(2),
        );
        expect(find.text('Confirm and delete'), findsNothing);
        expect(find.text('Refund and delete'), findsNothing);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(h.api.deleteCalls, isEmpty);
        expect(h.api.pendingReads, 1);
        expect(find.byType(TwitchRewardEditor), findsOneWidget);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(TwitchRewardDeleteDialog),
            matching: find.widgetWithText(CustomButton, 'Delete'),
          ),
        );
        await finishDeletion(tester);
        expect(h.api.deleteCalls, ['own']);
        expect(h.api.pendingReads, 2);
        expect(find.byType(TwitchRewardEditor), findsNothing);
        expect(find.text('Open editor'), findsOneWidget);
        expect(h.settings.rewards.rewards.single.isLinked, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('refund choice removes completed requests from the live queue', (
    tester,
  ) async {
    final h = (await tester.runAsync(QueueHarness.create))!;
    addTearDown(h.close);
    await h.queue.handleMessage(redemptionMessage('one'));
    h.api.pendingRedemptions = [
      redemption('one'),
      redemption('old-session', cost: 500),
    ];
    await openEditor(tester, h);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('2 pending requests'), findsOneWidget);
    expect(find.text('1250 points'), findsOneWidget);
    expect(h.queue.entries.single.id, 'one');
    h.api.pendingRedemptions.add(redemption('arrived-after-preview'));
    await tester.tap(find.text('Refund and delete'));
    await finishDeletion(tester);
    expect(h.api.pendingReads, 2);
    expect(h.api.patches.map((patch) => patch.$1), [
      'one',
      'old-session',
      'arrived-after-preview',
    ]);
    expect(h.api.deleteCalls, ['own']);
    expect(h.queue.entries, isEmpty);
    expect(h.queue.find('one')!.state, RedemptionQueueState.refunded);
    expect(find.byType(TwitchRewardEditor), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pending count can fail and retry without changing the reward', (
    tester,
  ) async {
    final h = (await tester.runAsync(QueueHarness.create))!;
    addTearDown(h.close);
    h.api.beforePendingRead = () async {
      throw const TwitchRewardsException(TwitchRewardsError.network);
    };
    await openEditor(tester, h);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load pending requests.'), findsOneWidget);
    expect(find.text('0 pending requests'), findsNothing);
    expect(h.api.deleteCalls, isEmpty);
    expect(h.api.patches, isEmpty);
    expect(
      tester
          .widget<CustomButton>(
            find.widgetWithText(CustomButton, 'Confirm and delete'),
          )
          .onTap,
      isNotNull,
    );
    h.api.beforePendingRead = null;
    h.api.pendingRedemptions = [redemption('old-session')];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('1 pending request'), findsOneWidget);
    expect(find.text('750 points'), findsOneWidget);
    expect(h.api.pendingReads, 2);
    expect(h.queue.entries, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.api.deleteCalls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the dialog can close while the count is loading', (
    tester,
  ) async {
    final h = (await tester.runAsync(QueueHarness.create))!;
    addTearDown(h.close);
    final reading = Completer<void>();
    h.api.beforePendingRead = () => reading.future;
    await openEditor(tester, h);
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Loading pending requests…'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(TwitchRewardDeleteDialog), findsNothing);
    reading.complete();
    await tester.pump();
    expect(h.api.deleteCalls, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a real deletion error stays visible and allows retry', (
    tester,
  ) async {
    final h = (await tester.runAsync(QueueHarness.create))!;
    addTearDown(h.close);
    h.api.deleteError = const TwitchRewardsException(
      TwitchRewardsError.forbidden,
    );
    h.api.pendingRedemptions = [redemption('one')];
    await openEditor(tester, h);
    final forbidden = AppLocalizations.of(
      tester.element(find.byType(TwitchRewardEditor)),
    )!.twitch_rewards_error_forbidden;
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm and delete'));
    await tester.pumpAndSettle();
    expect(find.text(forbidden), findsOneWidget);
    expect(find.byType(TwitchRewardEditor), findsOneWidget);
    expect(h.rewards.isManageable('own'), isTrue);
    h.api.deleteError = null;
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm and delete'));
    await finishDeletion(tester);
    expect(find.byType(TwitchRewardEditor), findsNothing);
    expect(h.api.deleteCalls, ['own', 'own']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Delete is absent when creating or viewing a foreign reward', (
    tester,
  ) async {
    final h = (await tester.runAsync(QueueHarness.create))!;
    addTearDown(h.close);
    await openEditor(tester, h, creating: true);
    expect(find.widgetWithText(CustomButton, 'Delete'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await openEditor(tester, h, reward: h.rewards.rewards.last);
    expect(find.widgetWithText(CustomButton, 'Delete'), findsNothing);
    expect(
      find.text(
        AppLocalizations.of(tester.element(find.byType(TwitchRewardEditor)))!
            .twitch_rewards_error_forbidden,
      ),
      findsOneWidget,
    );
    expect(h.api.deleteCalls, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'empty dialog fits both themes, narrow windows, and enlarged text',
    (tester) async {
      for (final dark in [false, true]) {
        for (final width in [320.0, 720.0]) {
          for (final scale in [1.0, 1.8]) {
            window(tester, width);
            final preview = GlobalKey();
            await tester.pumpWidget(
              app(
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => TwitchRewardDeleteDialog(
                        rewardTitle: 'Грай музика — довга назва нагороди',
                        loadSummary: () async =>
                            const TwitchRewardPendingSummary(
                              count: 0,
                              points: 0,
                            ),
                      ),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
                dark: dark,
                scale: scale,
                preview: preview,
              ),
            );
            await tester.tap(find.text('Delete'));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'dark=$dark, width=$width, scale=$scale',
            );
            if (scale == 1) {
              await _capture(
                tester,
                preview,
                'dialog-empty-${dark ? 'dark' : 'light'}-${width.toInt()}.png',
              );
            }
            await tester.tap(find.text('Cancel'));
            await tester.pumpAndSettle();
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
    },
  );
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  const directory = String.fromEnvironment('REWARD_DELETE_PREVIEW_DIR');
  if (directory.isEmpty) return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File('$directory/$name').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
