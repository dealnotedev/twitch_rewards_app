import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:twitch_listener/core/windows_keyboard.dart';
import 'package:win32/win32.dart';

/// An unordered set of Windows virtual keys pressed together.
class PlayerShortcut {
  final List<int> keys;

  PlayerShortcut._(List<int> keys) : keys = List.unmodifiable(keys);

  static PlayerShortcut? tryCreate(Iterable<int> keys) {
    final normalized = keys.map(normalizeWindowsShortcutKey).toSet().toList()
      ..sort();
    if (normalized.isEmpty ||
        normalized.any((key) => !isWindowsKeyboardKey(key))) {
      return null;
    }
    return PlayerShortcut._(normalized);
  }

  List<String> get labels {
    const modifiers = [VK_CONTROL, VK_MENU, VK_SHIFT, VK_LWIN];
    return [
      for (final key in modifiers)
        if (keys.contains(key)) windowsShortcutKeyLabel(key),
      for (final key in keys)
        if (!modifiers.contains(key)) windowsShortcutKeyLabel(key),
    ];
  }

  Map<String, List<int>> toJson() => {'keys': keys};

  static PlayerShortcut? fromPreference(Object? value) {
    if (value is! String) return null;
    try {
      return switch (jsonDecode(value)) {
        {'keys': final List<Object?> keys}
            when keys.every((key) => key is int) =>
          tryCreate(keys.cast<int>()),
        {'keyCode': final int key, 'modifiers': final int modifiers}
            when modifiers & ~(MOD_CONTROL | MOD_ALT | MOD_SHIFT) == 0 =>
          tryCreate([
            if (modifiers & MOD_CONTROL != 0) VK_CONTROL,
            if (modifiers & MOD_ALT != 0) VK_MENU,
            if (modifiers & MOD_SHIFT != 0) VK_SHIFT,
            key,
          ]),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerShortcut && listEquals(keys, other.keys);

  @override
  int get hashCode => Object.hashAll(keys);
}
