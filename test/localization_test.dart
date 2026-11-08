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
import 'package:twitch_listener/di/service_locator.dart';
import 'package:twitch_listener/l10n/app_localizations.dart';
import 'package:twitch_listener/music/music_requests.dart';
import 'package:twitch_listener/music/youtube_connection_controller.dart';
import 'package:twitch_listener/rewards/rewards_store.dart';
import 'package:twitch_listener/twitch/ws_event.dart';
import 'package:twitch_listener/twitch/ws_manager.dart';
import 'package:twitch_listener/ui/dropdown/dropdown_scope.dart';
import 'package:twitch_listener/ui/simple_icon.dart';
import 'package:twitch_listener/updates/update_controller.dart';
import 'package:twitch_listener/updates/update_notice.dart';

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
    for (final (count, points, actions, reactions, requests, enabled) in [
      (0, 'балів', 'дій', 'реакцій', 'запитів', 'увімкнених'),
      (1, 'бал', 'дія', 'реакція', 'запит', 'увімкнена'),
      (2, 'бали', 'дії', 'реакції', 'запити', 'увімкнені'),
      (5, 'балів', 'дій', 'реакцій', 'запитів', 'увімкнених'),
      (11, 'балів', 'дій', 'реакцій', 'запитів', 'увімкнених'),
      (21, 'бал', 'дія', 'реакція', 'запит', 'увімкнена'),
      (22, 'бали', 'дії', 'реакції', 'запити', 'увімкнені'),
      (25, 'балів', 'дій', 'реакцій', 'запитів', 'увімкнених'),
      (101, 'бал', 'дія', 'реакція', 'запит', 'увімкнена'),
      (111, 'балів', 'дій', 'реакцій', 'запитів', 'увімкнених'),
    ]) {
      expect(strings.x_points(count), '$count $points');
      expect(strings.x_actions(count), '$count $actions');
      expect(
        strings.channel_points_reactions_info(count, count),
        '$count $reactions • $count $enabled',
      );
      expect(
        strings.twitch_rewards_delete_pending(count),
        '$count $requests в очікуванні',
      );
    }
    expect(
      strings.channel_points_reactions_info(5, 1),
      '5 реакцій • 1 увімкнена',
    );
    expect(
      strings.channel_points_reactions_info(1, 0),
      '1 реакція • 0 увімкнених',
    );
  });

  group('saved language', () {
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

    test('cycles, persists after restart and keeps the chosen theme', () async {
      expect(settings.appearance.language, AppLanguage.english);
      await settings.toggleLanguage();
      await settings.setBrightness(AppBrightness.dark);
      final restarted = Settings();
      await restarted.init();
      expect(restarted.appearance.language, AppLanguage.ukrainian);
      expect(restarted.appearance.brightness, AppBrightness.dark);
      await restarted.toggleLanguage();
      expect(restarted.appearance.language, AppLanguage.english);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language'), 'en');
      // Each click advances from the current setting even before a rebuild.
      await Future.wait([
        restarted.toggleLanguage(),
        restarted.toggleLanguage(),
      ]);
      expect(restarted.appearance.language, AppLanguage.english);
      expect(prefs.getString('language'), 'en');
    });

    test('unsupported saved languages fall back to English', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', 'unsupported');
      final restarted = Settings();
      await restarted.init();
      expect(restarted.appearance.language, AppLanguage.english);
    });

    for (final language in AppLanguage.values) {
      testWidgets(
        'toolbar cycles from ${language.code}, preserves edits and passes locale to updater',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(640, 720);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await settings.setLanguage(language);
          final websocket = _WebSocketManager();
          final launches = <String>[];
          final locator = _Locator({
            Settings: settings,
            WebSocketManager: websocket,
            Autosaver: Autosaver(delay: Duration.zero),
            MusicRequestManager: MusicRequestManager(
              fetcher: FakeFetcher(),
              player: FakePlayer(),
            ),
            YoutubeConnectionController: _Connection(),
            UpdateController: UpdateController(
              check: () async => '9.0.0',
              launch: (locale, _) async => launches.add(locale),
            ),
          });
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
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

          Future<void> checkLanguage(AppLanguage current) async {
            final strings = lookupAppLocalizations(Locale(current.code));
            expect(find.text(strings.reward_configure_title), findsOneWidget);
            expect(find.text('Незбережені зміни'), findsOneWidget);
            final icon = tester.widget<SimpleIcon>(
              find.descendant(
                of: find.byKey(const ValueKey('language-switch')),
                matching: find.byType(SimpleIcon),
              ),
            );
            expect(icon.icon, 'assets/ic_locale_${current.code}_16dp.svg');
            expect(
              find.ancestor(
                of: find.byKey(const ValueKey('language-switch')),
                matching: find.byType(Tooltip),
              ),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
          }

          await checkLanguage(language);
          final editorContext = tester.element(find.byType(TextField));
          DropdownScope.of(editorContext).show(
            editorContext,
            key: router.editorKey,
            builder: (_) => const Text('Open language-dependent menu'),
          );
          await tester.pumpAndSettle();
          expect(find.text('Open language-dependent menu'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('language-switch')));
          await tester.pumpAndSettle();
          expect(find.text('Open language-dependent menu'), findsNothing);
          await checkLanguage(language.next);
          final strings = lookupAppLocalizations(Locale(language.next.code));
          await tester.tap(find.text(strings.updateOpen));
          await tester.pumpAndSettle();
          expect(launches, [language.next.code]);
          await settings.setBrightness(AppBrightness.dark);
          await tester.pumpAndSettle();
          await checkLanguage(language.next);
          await tester.tap(find.byKey(const ValueKey('language-switch')));
          await tester.pumpAndSettle();
          await checkLanguage(language);
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
      (settings) => MaterialPageRoute<void>(
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
      );
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
