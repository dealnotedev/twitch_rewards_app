import 'package:flutter/material.dart';

class DefaultInputDecoration extends InputDecoration {
  const DefaultInputDecoration({String? hintText})
      : super(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 14),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          fillColor: const Color(0xFF272E37),
          filled: true,
          isDense: true,
        );
}

class Themes {
  static ThemeData light = ThemeData.light(useMaterial3: false).copyWith(
      dividerColor: const Color(0xFFE5E5E5),
      colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.deepPurple,
              brightness: Brightness.light,
              backgroundColor: Colors.white)
          .copyWith(surface: Colors.white));

  static ThemeData dark = ThemeData.dark(useMaterial3: false).copyWith(
      dividerColor: const Color(0xFF3A3A3A),
      colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.deepPurple,
              brightness: Brightness.dark,
              backgroundColor: const Color(0xFF121212))
          .copyWith(surface: const Color(0xFF121212)));
}

extension ThemeExt on ThemeData {
  Color get textColorPrimary =>
      dark ? const Color(0xFFEEEEEE) : const Color(0xFF0A0A0A);

  bool get dark => brightness == Brightness.dark;

  Color get textColorSecondary =>
      dark ? const Color(0xFF8F8F8F) : const Color(0xFF717182);

  Color get textColorDisabled =>
      dark ? const Color(0xFF5A5A5A) : const Color(0xFFB2B2BB);

  Color get surfacePrimary => colorScheme.surface;

  Color get surfaceSecondary => dark ? const Color(0xFF1B1B1B) : Colors.white;

  Color get inputBackground =>
      dark ? const Color(0xFF1F1F1F) : const Color(0xFFF3F3F5);

  Color get border => dark ? const Color(0xFF292929) : const Color(0xFFF3F3F5);

  Color get borderActive =>
      dark ? const Color(0xFF555555) : const Color(0xFFA1A1A1);

  Color get buttonColorPrimary =>
      dark ? const Color(0xFFEEEEEE) : const Color(0xFF030213);

  Color get buttonColorSecondary =>
      dark ? const Color(0xFF1B1B1B) : const Color(0xFFFFFFFF);

  Color get buttonColorAlternative =>
      dark ? const Color(0xFF333333) : const Color(0xFFECEEF2);

  Color get textColorPrimaryInverted =>
      dark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
}
