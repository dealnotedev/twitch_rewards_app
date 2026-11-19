import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:win32/win32.dart';

/// An unordered set of Windows virtual keys pressed together.
class PlayerShortcut {
  final List<int> keys;

  PlayerShortcut._(List<int> keys) : keys = List.unmodifiable(keys);

  static PlayerShortcut? tryCreate(Iterable<int> keys) {
    final normalized = keys.map(normalizeKey).toSet().toList()..sort();
    if (normalized.isEmpty || normalized.any((key) => !isKeyboardKey(key))) {
      return null;
    }
    return PlayerShortcut._(normalized);
  }

  static bool isKeyboardKey(int key) =>
      key == VK_CANCEL ||
      key >= VK_BACK && key < 0xff && key != VK_PACKET && key != VK_PROCESSKEY;

  static int normalizeKey(int key) => switch (key) {
    VK_LCONTROL || VK_RCONTROL => VK_CONTROL,
    VK_LMENU || VK_RMENU => VK_MENU,
    VK_LSHIFT || VK_RSHIFT => VK_SHIFT,
    VK_RWIN => VK_LWIN,
    _ => key,
  };

  static String label(int key) => switch (key) {
    VK_CONTROL => 'Ctrl',
    VK_MENU => 'Alt',
    VK_SHIFT => 'Shift',
    VK_LWIN => 'Win',
    VK_SPACE => 'Space',
    _ => switch (kWindowsToLogicalKey[key]?.keyLabel) {
      final String name when name.isNotEmpty => name,
      _ => 'VK 0x${key.toRadixString(16).toUpperCase()}',
    },
  };

  List<String> get labels {
    const modifiers = [VK_CONTROL, VK_MENU, VK_SHIFT, VK_LWIN];
    return [
      for (final key in modifiers)
        if (keys.contains(key)) label(key),
      for (final key in keys)
        if (!modifiers.contains(key)) label(key),
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
