import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:win32/win32.dart';

/// A Windows virtual key and the modifiers accepted by RegisterHotKey.
class PlayerShortcut {
  final int keyCode;
  final int modifiers;

  const PlayerShortcut._(this.keyCode, this.modifiers);

  static PlayerShortcut? tryCreate(int keyCode, int modifiers) {
    const allowedModifiers = MOD_CONTROL | MOD_ALT | MOD_SHIFT;
    if (modifiers & ~allowedModifiers != 0) return null;
    final isFunctionKey = keyCode >= VK_F1 && keyCode <= VK_F24;
    if (keyCode == VK_F12) return null;
    if (isFunctionKey || keyCode == VK_MEDIA_PLAY_PAUSE) {
      return PlayerShortcut._(keyCode, modifiers);
    }

    // Keep ordinary typing (including Shift with a letter) available system-wide.
    if (modifiers & (MOD_CONTROL | MOD_ALT) == 0) return null;
    if (kWindowsToLogicalKey[keyCode] == null ||
        keyCode == VK_ESCAPE ||
        isModifierKey(keyCode) ||
        keyCode == VK_CAPITAL ||
        keyCode == VK_NUMLOCK ||
        keyCode == VK_SCROLL) {
      return null;
    }
    return PlayerShortcut._(keyCode, modifiers);
  }

  static bool isModifierKey(int keyCode) =>
      keyCode == VK_SHIFT ||
      keyCode == VK_CONTROL ||
      keyCode == VK_MENU ||
      keyCode == VK_LWIN ||
      keyCode == VK_RWIN ||
      keyCode >= VK_LSHIFT && keyCode <= VK_RMENU;

  List<String> get labels => [
    if (modifiers & MOD_CONTROL != 0) 'Ctrl',
    if (modifiers & MOD_ALT != 0) 'Alt',
    if (modifiers & MOD_SHIFT != 0) 'Shift',
    keyCode == VK_SPACE ? 'Space' : kWindowsToLogicalKey[keyCode]!.keyLabel,
  ];

  Map<String, int> toJson() => {'keyCode': keyCode, 'modifiers': modifiers};

  static PlayerShortcut? fromPreference(Object? value) {
    if (value is! String) return null;
    try {
      return switch (jsonDecode(value)) {
        {'keyCode': final int keyCode, 'modifiers': final int modifiers} =>
          tryCreate(keyCode, modifiers),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerShortcut &&
      other.keyCode == keyCode &&
      other.modifiers == modifiers;

  @override
  int get hashCode => Object.hash(keyCode, modifiers);
}
