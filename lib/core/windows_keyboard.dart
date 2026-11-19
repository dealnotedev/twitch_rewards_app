import 'package:flutter/services.dart';
import 'package:win32/win32.dart';

bool isWindowsKeyboardKey(int key) =>
    key == VK_CANCEL ||
    key >= VK_BACK && key < 0xff && key != VK_PACKET && key != VK_PROCESSKEY;

int normalizeWindowsShortcutKey(int key) => switch (key) {
  VK_LCONTROL || VK_RCONTROL => VK_CONTROL,
  VK_LMENU || VK_RMENU => VK_MENU,
  VK_LSHIFT || VK_RSHIFT => VK_SHIFT,
  VK_RWIN => VK_LWIN,
  _ => key,
};

String windowsShortcutKeyLabel(int key) =>
    switch (normalizeWindowsShortcutKey(key)) {
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

class ShortcutRecording {
  static int _activeCount = 0;

  static bool get isActive => _activeCount > 0;

  static Future<T> run<T>(Future<T> Function() record) async {
    _activeCount++;
    try {
      return await record();
    } finally {
      _activeCount--;
    }
  }
}
