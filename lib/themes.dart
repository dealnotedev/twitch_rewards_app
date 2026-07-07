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
      scaffoldBackgroundColor: const Color(0xFFF6F7FA),
      dividerColor: const Color(0xFFE2E6EE),
      splashColor: const Color(0xFF6441A5).withValues(alpha: 0.08),
      highlightColor: const Color(0xFF6441A5).withValues(alpha: 0.05),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFF6441A5),
        selectionColor: Color(0x336441A5),
        selectionHandleColor: Color(0xFF6441A5),
      ),
      colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.deepPurple,
              brightness: Brightness.light,
              backgroundColor: const Color(0xFFF6F7FA))
          .copyWith(
              primary: const Color(0xFF6441A5),
              secondary: const Color(0xFF0F8B8D),
              surface: const Color(0xFFF6F7FA)));

  static ThemeData dark = ThemeData.dark(useMaterial3: false).copyWith(
      scaffoldBackgroundColor: const Color(0xFF101216),
      dividerColor: const Color(0xFF2A3038),
      splashColor: const Color(0xFFA98EFF).withValues(alpha: 0.12),
      highlightColor: const Color(0xFFA98EFF).withValues(alpha: 0.07),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Color(0xFFA98EFF),
        selectionColor: Color(0x44A98EFF),
        selectionHandleColor: Color(0xFFA98EFF),
      ),
      colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.deepPurple,
              brightness: Brightness.dark,
              backgroundColor: const Color(0xFF101216))
          .copyWith(
              primary: const Color(0xFFA98EFF),
              secondary: const Color(0xFF57C7C9),
              surface: const Color(0xFF101216)));
}

extension ThemeExt on ThemeData {
  Color get textColorPrimary =>
      dark ? const Color(0xFFF3F5F7) : const Color(0xFF171A1F);

  bool get dark => brightness == Brightness.dark;

  Color get textColorSecondary =>
      dark ? const Color(0xFFA2A9B4) : const Color(0xFF68707D);

  Color get textColorDisabled =>
      dark ? const Color(0xFF5D6570) : const Color(0xFFB0B7C3);

  Color get surfacePrimary => colorScheme.surface;

  Color get surfaceSecondary =>
      dark ? const Color(0xFF171A1F) : const Color(0xFFFFFFFF);

  Color get surfaceTertiary =>
      dark ? const Color(0xFF1D2229) : const Color(0xFFF0F3F8);

  Color get inputBackground =>
      dark ? const Color(0xFF111419) : const Color(0xFFF7F8FB);

  Color get border => dark ? const Color(0xFF2A3038) : const Color(0xFFDDE3EC);

  Color get borderActive =>
      dark ? const Color(0xFFA98EFF) : const Color(0xFF6441A5);

  Color get accentColor =>
      dark ? const Color(0xFFA98EFF) : const Color(0xFF6441A5);

  Color get accentSubtle =>
      dark ? const Color(0x332A1E4A) : const Color(0xFFF0ECFF);

  Color get positiveColor =>
      dark ? const Color(0xFF70D69A) : const Color(0xFF147E42);

  Color get positiveSubtle =>
      dark ? const Color(0x33235C3A) : const Color(0xFFEAF8EF);

  Color get buttonColorPrimary =>
      dark ? const Color(0xFFA98EFF) : const Color(0xFF6441A5);

  Color get buttonColorSecondary =>
      dark ? const Color(0xFF1D2229) : const Color(0xFFFFFFFF);

  Color get buttonColorAlternative =>
      dark ? const Color(0xFF262C35) : const Color(0xFFEFF2F7);

  Color get textColorPrimaryInverted =>
      dark ? const Color(0xFF111419) : const Color(0xFFFFFFFF);

  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: dark
              ? Colors.black.withValues(alpha: 0.18)
              : const Color(0xFF1A2433).withValues(alpha: 0.06),
          offset: const Offset(0, 8),
          blurRadius: 20,
        )
      ];

  BoxDecoration get cardDecoration => BoxDecoration(
      color: surfaceSecondary,
      border: Border.all(
          color: border,
          width: 0.5,
          strokeAlign: BorderSide.strokeAlignOutside),
      borderRadius: BorderRadius.circular(8),
      boxShadow: cardShadow);
}
