import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:twitch_listener/reward.dart';
import 'package:win32/win32.dart';

class InputSender {
  void mouseTest() {
    final mouse = calloc<INPUT>();
    mouse.ref.type = INPUT_MOUSE;
    mouse.ref.mi.dwFlags = MOUSEEVENTF_RIGHTDOWN;

    SendInput(1, mouse, sizeOf<INPUT>());

    mouse.ref.mi.dwFlags = MOUSEEVENTF_RIGHTUP;
    SendInput(1, mouse, sizeOf<INPUT>());

    calloc.free(mouse);
  }

  static void sendInputs(List<InputEntry> inputs) {
    final kbd = calloc<INPUT>(inputs.length * 2);

    for (int i = 0; i < inputs.length; i++) {
      final input = inputs[i];

      kbd[i].type = INPUT_KEYBOARD;
      kbd[i].ki.wVk = input.code;
    }

    for (int i = 0; i < inputs.length; i++) {
      final input = inputs[i];

      kbd[i + inputs.length].type = INPUT_KEYBOARD;
      kbd[i + inputs.length].ki.wVk = input.code;
      kbd[i + inputs.length].ki.dwFlags = KEYEVENTF_KEYUP;
    }

    SendInput(inputs.length * 2, kbd, sizeOf<INPUT>());
    calloc.free(kbd);
  }
}
