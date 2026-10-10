import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;

import 'package:path/path.dart' as p;

final class LaunchOptions {
  const LaunchOptions({
    required this.directory,
    required this.locale,
    this.themeMode = ThemeMode.system,
  });
  final String directory;
  final Locale locale;
  final ThemeMode themeMode;

  factory LaunchOptions.parse(
    List<String> arguments, {
    required String executable,
    required Locale systemLocale,
  }) {
    var directory = p.dirname(executable);
    if (p.basename(directory).toLowerCase() == 'updater') {
      directory = p.dirname(directory);
    }
    var locale = supportedLocale(systemLocale.toLanguageTag());
    var themeMode = ThemeMode.system;
    for (var i = 0; i < arguments.length; i++) {
      final option = arguments[i];
      if ((option == '--install-dir' ||
              option == '--locale' ||
              option == '--theme') &&
          i + 1 < arguments.length &&
          !arguments[i + 1].startsWith('--')) {
        final value = arguments[++i];
        if (option == '--install-dir') {
          directory = p.normalize(p.absolute(value));
        } else if (option == '--locale') {
          locale = supportedLocale(value);
        } else {
          themeMode = switch (value.toLowerCase()) {
            'dark' => ThemeMode.dark,
            'light' => ThemeMode.light,
            _ => ThemeMode.system,
          };
        }
      }
    }
    return LaunchOptions(
      directory: directory,
      locale: locale,
      themeMode: themeMode,
    );
  }

  static Locale supportedLocale(String value) => Locale(
    value.replaceAll('_', '-').split('-').first.toLowerCase() == 'uk'
        ? 'uk'
        : 'en',
  );
}
