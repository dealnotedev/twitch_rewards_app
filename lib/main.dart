import 'dart:ui';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:twitch_listener/app/app.dart';
import 'package:twitch_listener/app/app_router.dart';
import 'package:twitch_listener/audio/audioplayer.dart';
import 'package:twitch_listener/core/settings.dart';
import 'package:twitch_listener/di/app_service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MediaKit.ensureInitialized();

  final settings = Settings();
  await settings.init();
  await settings.makeRequiredMigrations();

  final locator = AppServiceLocator.init(
    settings: settings,
    audioplayer: Audioplayer(),
  );

  final router = ApplicationRouter(locator: locator);

  runApp(ListenerApp(locator: locator, router: router));

  doWhenWindowReady(() {
    const initialSize = Size(640, 720);
    appWindow.minSize = initialSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });

  AppLifecycleListener(
    binding: WidgetsBinding.instance,
    onExitRequested: () async {
      await locator.closeRedemptions();
      await locator.closeMusic();
      return AppExitResponse.exit;
    },
  );
}
