import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twitch_listener/app/app.dart';
import 'package:twitch_listener/app/app_router.dart';
import 'package:twitch_listener/core/autosaver.dart';
import 'package:twitch_listener/core/extensions.dart';
import 'package:twitch_listener/core/settings.dart';
import 'package:twitch_listener/core/windows_keyboard.dart';
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/generated/assets.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/music/music_hotkey_controller.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/player_shortcut.dart';
import 'package:twitch_listener/music/youtube_connection_controller.dart';
import 'package:twitch_listener/rewards/rewards_store.dart';
import 'package:twitch_listener/twitch/ws_event.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';
import 'package:twitch_listener/ui/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/ui/key_combination_field.dart';
import 'package:twitch_listener/ui/ripple_icon.dart';
import 'package:twitch_listener/ui/themes.dart';
import 'package:twitch_listener/updates/update_controller.dart';
import 'package:twitch_listener/updates/update_notice.dart';
import 'package:win32/win32.dart';

import 'music/fakes.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('Ukrainian translates every message and preserves placeholders', () {
    Map<String, dynamic> read(String language) =>
        jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
            as Map<String, dynamic>;
    final english = read('en');
    final ukrainian = read('uk');
    final keys = english.keys.where((key) => !key.startsWith('@')).toSet();
    expect(ukrainian.keys.where((key) => !key.startsWith('@')).toSet(), keys);
    Set<String?> placeholders(String text) =>
        RegExp(r'\{(\w+)[,}]')
            .allMatches(text)
            .map((match) => match.group(1))
            .toSet();
    for (final key in keys) {
      expect(ukrainian[key], isNotEmpty, reason: key);
      expect(
        placeholders(ukrainian[key] as String),
        placeholders(english[key] as String),
        reason: key,
      );
    }
    expect(
      AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
      AppLanguage.values.map((language) => language.code),
    );
  });

  test('Ukrainian plurals handle zero, teens and compound numbers', () {
    final strings = lookupAppLocalizations(const Locale('uk'));
    for (final (count, points, actions, reactions, requests) in [
      (0, 'балів', 'дій', 'реакцій', 'запитів'),
      (1, 'бал', 'дія', 'реакція', 'запит'),
      (2, 'бали', 'дії', 'реакції', 'запити'),
      (5, 'балів', 'дій', 'реакцій', 'запитів'),
      (11, 'балів', 'дій', 'реакцій', 'запитів'),
      (21, 'бал', 'дія', 'реакція', 'запит'),
      (22, 'бали', 'дії', 'реакції', 'запити'),
      (25, 'балів', 'дій', 'реакцій', 'запитів'),
      (101, 'бал', 'дія', 'реакція', 'запит'),
      (111, 'балів', 'дій', 'реакцій', 'запитів'),
    ]) {
      expect(strings.x_points(count), '$count $points');
      expect(strings.x_actions(count), '$count $actions');
      expect(strings.x_reactions(count), '$count $reactions');
      expect(
        strings.twitch_rewards_delete_pending(count),
        '$count $requests в очікуванні',
      );
    }
  });

  group('application settings', () {
    late Settings settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp('listener-l10n-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => directory.path,
      );
      // Share the same database handle with Settings so it can be closed here.
      final store = await RewardsStore.open(
        databasePath: path.join(directory.path, 'rewards.db'),
      );
      addTearDown(() async {
        await store.close();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      });
      settings = Settings();
      await settings.init();
    });

    test(
      'language persists after restart and keeps the chosen theme',
      () async {
        expect(settings.appearance.language, AppLanguage.english);
        await settings.setLanguage(AppLanguage.ukrainian);
        await settings.setBrightness(AppBrightness.dark);
        final restarted = Settings();
        await restarted.init();
        expect(restarted.appearance.language, AppLanguage.ukrainian);
        expect(restarted.appearance.brightness, AppBrightness.dark);
        await restarted.setLanguage(AppLanguage.english);
        expect(restarted.appearance.language, AppLanguage.english);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('language'), 'en');
        await Future.wait([
          restarted.setLanguage(AppLanguage.ukrainian),
          restarted.setLanguage(AppLanguage.english),
        ]);
        expect(restarted.appearance.language, AppLanguage.english);
        expect(prefs.getString('language'), 'en');
      },
    );

    test('unsupported saved languages fall back to English', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', 'unsupported');
      final restarted = Settings();
      await restarted.init();
      expect(restarted.appearance.language, AppLanguage.english);
    });

    const hotkeyChannel = MethodChannel('listener/music_hotkey');

    test('restores a legacy shortcut and toggles the shared player', () async {
      final calls = <Object?>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(hotkeyChannel, (
        call,
      ) async {
        calls.add(call.arguments);
        return true;
      });
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          hotkeyChannel,
          null,
        ),
      );

      final shortcut = PlayerShortcut.tryCreate([VK_CONTROL, VK_F9])!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'music_play_pause_shortcut',
        jsonEncode({'keyCode': VK_F9, 'modifiers': MOD_CONTROL}),
      );
      final restarted = Settings();
      await restarted.init();
      expect(restarted.playPauseShortcut, shortcut);

      final player = FakePlayer();
      final requests = MusicRequestManager(
        fetcher: FakeFetcher(),
        player: player,
      );
      final hotkey = MusicHotkeyController(restarted, requests);
      addTearDown(requests.close);
      addTearDown(hotkey.close);
      requests.enqueue(firstUrl);
      await flush();
      expect(calls, [shortcut.toJson()]);

      Future<void> pressShortcut() =>
          binding.defaultBinaryMessenger.handlePlatformMessage(
            hotkeyChannel.name,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('pressed'),
            ),
            (_) {},
          );

      await pressShortcut();
      expect(requests.current.nowPlaying?.paused, isTrue);
      await ShortcutRecording.run(() async {
        await pressShortcut();
        expect(requests.current.nowPlaying?.paused, isTrue);
      });
      await pressShortcut();
      expect(requests.current.nowPlaying?.paused, isFalse);
    });

    testWidgets(
      'records single keys and chords while keeping the last saved shortcut '
      'if the listener fails',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(640, 720);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        binding.defaultBinaryMessenger.setMockMethodCallHandler(hotkeyChannel, (
          call,
        ) async {
          final arguments = call.arguments as Map<Object?, Object?>?;
          return !(arguments?['keys'] as List<Object?>? ?? []).contains(VK_F8);
        });
        addTearDown(
          () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
            hotkeyChannel,
            null,
          ),
        );

        final websocket = _WebSocketManager();
        final requests = MusicRequestManager(
          fetcher: FakeFetcher(),
          player: FakePlayer(),
        );
        final hotkey = MusicHotkeyController(settings, requests);
        final locator = _Locator({
          Settings: settings,
          WebSocketManager: websocket,
          Autosaver: Autosaver(delay: Duration.zero),
          MusicRequestManager: requests,
          MusicHotkeyController: hotkey,
          YoutubeConnectionController: _Connection(),
          UpdateController: UpdateController(check: () async => null),
        });
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await websocket.events.close();
        });
        final strings = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          ListenerApp(
            locator: locator,
            router: _Router(locator: locator),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open-editor')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Draft');

        final gear = find.byKey(const ValueKey('app-settings'));
        await tester.tap(gear);
        await tester.pumpAndSettle();
        expect(find.text(strings.player_shortcut_play_pause), findsOneWidget);
        await tester.tap(gear);
        await tester.pumpAndSettle();

        await tester.tap(find.text(strings.app_settings_appearance));
        await tester.pumpAndSettle();
        expect(find.text(strings.app_settings_theme), findsOneWidget);
        await tester.tap(find.text(strings.app_settings_theme_system));
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.app_settings_theme_dark));
        await tester.pumpAndSettle();
        expect(settings.appearance.brightness, AppBrightness.dark);
        expect(Theme.of(tester.element(gear)).brightness, Brightness.dark);
        await tester.tap(find.text(strings.app_settings_player));
        await tester.pumpAndSettle();

        await tester.tap(find.text(strings.player_shortcut_assign));
        await tester.pumpAndSettle();
        final shortcutPreview = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(KeyCombinationField),
        );
        final previewBoxes = find.descendant(
          of: shortcutPreview,
          matching: find.byType(DecoratedBox),
        );
        final previewTheme = Theme.of(tester.element(shortcutPreview));
        final background =
            tester.widget<DecoratedBox>(previewBoxes).decoration
                as BoxDecoration;
        expect(background.color, previewTheme.surfaceTertiary);
        expect(background.border, isNull);
        final hint = find.text(strings.shortcut_recording);
        expect(
          tester.getCenter(hint).dx,
          lessThan(tester.getCenter(shortcutPreview).dx),
        );
        final previewHeight = tester.getSize(shortcutPreview).height;

        await tester.sendKeyEvent(LogicalKeyboardKey.keyP, platform: 'windows');
        await tester.pump();
        expect(find.text('P'), findsOneWidget);
        expect(previewBoxes, findsNWidgets(2));
        expect(tester.getSize(shortcutPreview).height, previewHeight);
        await tester.tap(find.text(strings.shortcut_record_again));
        await tester.pump();
        await tester.sendKeyDownEvent(
          LogicalKeyboardKey.shiftLeft,
          platform: 'windows',
        );
        await tester.sendKeyEvent(
          LogicalKeyboardKey.enter,
          platform: 'windows',
        );
        await tester.sendKeyUpEvent(
          LogicalKeyboardKey.shiftLeft,
          platform: 'windows',
        );
        await tester.pump();
        expect(find.text('Shift'), findsOneWidget);
        expect(find.text('Enter'), findsOneWidget);
        expect(previewBoxes, findsNWidgets(3));
        expect(tester.getSize(shortcutPreview).height, previewHeight);
        await tester.tap(find.text(strings.shortcut_record_again));
        await tester.pump();
        await tester.sendKeyDownEvent(
          LogicalKeyboardKey.keyJ,
          platform: 'windows',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK, platform: 'windows');
        await tester.sendKeyUpEvent(
          LogicalKeyboardKey.keyJ,
          platform: 'windows',
        );
        await tester.pump();
        expect(find.text('J'), findsOneWidget);
        expect(find.text('K'), findsOneWidget);
        await tester.tap(find.text(strings.button_save_changes));
        await tester.pumpAndSettle();
        final shortcut = PlayerShortcut.tryCreate([VK_J, VK_K])!;
        expect(settings.playPauseShortcut, shortcut);
        final prefs = await SharedPreferences.getInstance();
        expect(
          PlayerShortcut.fromPreference(
            prefs.getString('music_play_pause_shortcut'),
          ),
          shortcut,
        );
        final savedCombination = find.byType(KeyCombinationField);
        expect(savedCombination, findsOneWidget);
        for (final label in ['J', 'K']) {
          expect(
            find.descendant(of: savedCombination, matching: find.text(label)),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(
            of: savedCombination,
            matching: find.byType(DecoratedBox),
          ),
          findsNWidgets(3),
        );

        await tester.tap(find.text(strings.player_shortcut_change));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.f8, platform: 'windows');
        await tester.pump();
        await tester.tap(find.text(strings.button_save_changes));
        await tester.pumpAndSettle();
        expect(find.text(strings.player_shortcut_unavailable), findsOneWidget);
        expect(settings.playPauseShortcut, shortcut);
        await tester.sendKeyEvent(
          LogicalKeyboardKey.escape,
          platform: 'windows',
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);

        await tester.tap(find.text(strings.player_shortcut_remove));
        await tester.pumpAndSettle();
        expect(settings.playPauseShortcut, isNull);
        expect(find.text(strings.player_shortcut_unassigned), findsOneWidget);
        await tester.tap(find.text(strings.button_back));
        await tester.pumpAndSettle();
        expect(find.text('Draft'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final close = hotkey.close();
        await tester.pump();
        await close;
      },
    );

    for (final language in AppLanguage.values) {
      final nextLanguage =
          AppLanguage.values[(language.index + 1) % AppLanguage.values.length];
      testWidgets(
        'changing ${language.code} in settings preserves edits and passes locale to updater',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(640, 720);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await settings.setLanguage(language);
          final websocket = _WebSocketManager();
          final launches = <String>[];
          final requests = MusicRequestManager(
            fetcher: FakeFetcher(),
            player: FakePlayer(),
          );
          final hotkey = MusicHotkeyController(settings, requests);
          final locator = _Locator({
            Settings: settings,
            WebSocketManager: websocket,
            Autosaver: Autosaver(delay: Duration.zero),
            MusicRequestManager: requests,
            MusicHotkeyController: hotkey,
            YoutubeConnectionController: _Connection(),
            UpdateController: UpdateController(
              check: () async => '9.0.0',
              launch: (locale, _) async => launches.add(locale),
            ),
          });
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            final close = hotkey.close();
            await tester.pump();
            await close;
            await websocket.events.close();
          });
          final router = _Router(locator: locator);
          await tester.pumpWidget(
            ListenerApp(locator: locator, router: router),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('open-editor')));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'Незбережені зміни');

          void checkLanguage(AppLanguage current) {
            final strings = lookupAppLocalizations(Locale(current.code));
            expect(find.text(strings.reward_configure_title), findsOneWidget);
            expect(find.text('Незбережені зміни'), findsOneWidget);
            expect(find.byKey(const ValueKey('language-switch')), findsNothing);
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is RippleIcon &&
                    widget.icon == Assets.assetsIcSunMoonWhite16dp,
              ),
              findsNothing,
            );
          }

          Future<void> changeLanguage(
            AppLanguage current,
            AppLanguage next,
          ) async {
            final strings = lookupAppLocalizations(Locale(current.code));
            await tester.tap(find.byKey(const ValueKey('app-settings')));
            await tester.pumpAndSettle();
            expect(find.text('Open language-dependent menu'), findsNothing);
            await tester.tap(find.text(strings.app_settings_appearance));
            await tester.pumpAndSettle();
            expect(find.text(strings.app_settings_language), findsOneWidget);
            await tester.tap(find.text(current.nativeName));
            await tester.pumpAndSettle();
            await tester.tap(find.text(next.nativeName));
            await tester.pumpAndSettle();
            expect(settings.appearance.language, next);

            final translated = lookupAppLocalizations(Locale(next.code));
            expect(find.text(translated.app_settings_language), findsOneWidget);
            await tester.tap(find.text(translated.button_back));
            await tester.pumpAndSettle();
          }

          checkLanguage(language);
          final editorContext = tester.element(find.byType(TextField));
          DropdownScope.of(editorContext).show(
            editorContext,
            key: router.editorKey,
            builder: (_) => const Text('Open language-dependent menu'),
          );
          await tester.pumpAndSettle();
          expect(find.text('Open language-dependent menu'), findsOneWidget);
          await changeLanguage(language, nextLanguage);
          checkLanguage(nextLanguage);
          final strings = lookupAppLocalizations(Locale(nextLanguage.code));
          await tester.tap(find.text(strings.updateOpen));
          await tester.pumpAndSettle();
          expect(launches, [nextLanguage.code]);
          await settings.setBrightness(AppBrightness.dark);
          await tester.pumpAndSettle();
          checkLanguage(nextLanguage);
          await changeLanguage(nextLanguage, language);
          checkLanguage(language);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

class _Locator extends ServiceLocator {
  final Map<Type, Object> dependencies;
  _Locator(this.dependencies);

  @override
  T provide<T>() => dependencies[T] as T;
}

class _Router extends ApplicationRouter {
  _Router({required super.locator});
  final editorKey = GlobalKey();

  @override
  RouteFactory get routerFactory =>
      (settings) => switch (settings.name) {
        '/' || '/editor' => MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => settings.name == '/editor'
              ? Column(
                  children: [
                    Text(context.localizations.reward_configure_title),
                    TextField(key: editorKey),
                    UpdateNotice(controller: locator.provide()),
                  ],
                )
              : TextButton(
                  key: const ValueKey('open-editor'),
                  onPressed: () => Navigator.of(context).pushNamed('/editor'),
                  child: Text(context.localizations.button_configure),
                ),
        ),
        _ => super.routerFactory(settings),
      };
}

class _WebSocketManager implements WebSocketManager {
  final events = StreamController<WsMessage>.broadcast();

  @override
  Stream<WsMessage> get messages => events.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Connection implements YoutubeConnectionController {
  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
