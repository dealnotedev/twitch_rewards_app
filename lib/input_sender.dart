import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:twitch_listener/reward.dart';
import 'package:win32/win32.dart';

class InputSender {
  void sendTestKey() async {
    final kbd = calloc<INPUT>(2);
    kbd[0].type = INPUT_TYPE.INPUT_MOUSE;
    kbd[0].ki.wVk = VIRTUAL_KEY.VK_RBUTTON;
    kbd[0].ki.dwFlags = MOUSE_EVENT_FLAGS.MOUSEEVENTF_RIGHTDOWN;

    kbd[1].type = INPUT_TYPE.INPUT_MOUSE;
    kbd[1].ki.wVk = VIRTUAL_KEY.VK_RBUTTON;
    kbd[1].ki.dwFlags = MOUSE_EVENT_FLAGS.MOUSEEVENTF_RIGHTUP;

    //kbd[1].type = INPUT_TYPE.INPUT_KEYBOARD;
    //kbd[1].ki.wVk = 86;
    //kbd[1].ki.dwFlags = KEYBD_EVENT_FLAGS.KEYEVENTF_KEYUP | KEYBD_EVENT_FLAGS.KEYEVENTF_EXTENDEDKEY;

    /*kbd[2].type = INPUT_TYPE.INPUT_KEYBOARD;
    kbd[2].ki.wVk = 162;
    kbd[2].ki.dwFlags = KEYBD_EVENT_FLAGS.KEYEVENTF_KEYUP;

    kbd[3].type = INPUT_TYPE.INPUT_KEYBOARD;
    kbd[3].ki.wVk = 86;
    kbd[3].ki.dwFlags = KEYBD_EVENT_FLAGS.KEYEVENTF_KEYUP;*/

    SendInput(2, kbd, sizeOf<INPUT>());

    calloc.free(kbd);
  }

  void mouseTest() {
    final mouse = calloc<INPUT>();
    mouse.ref.type = INPUT_TYPE.INPUT_MOUSE;
    mouse.ref.mi.dwFlags = MOUSE_EVENT_FLAGS.MOUSEEVENTF_RIGHTDOWN;
    int result = SendInput(1, mouse, sizeOf<INPUT>());
    if (result != TRUE) print('Error: ${GetLastError()}');

    //Sleep(1000);

    mouse.ref.mi.dwFlags = MOUSE_EVENT_FLAGS.MOUSEEVENTF_RIGHTUP;
    result = SendInput(1, mouse, sizeOf<INPUT>());
    if (result != TRUE) print('Error: ${GetLastError()}');
  }

  static void sendInputs(List<InputEntry> inputs) {
    print(inputs);

    final kbd = calloc<INPUT>(inputs.length * 2);

    for (int i = 0; i < inputs.length; i++) {
      final input = inputs[i];

      kbd[i].type = INPUT_TYPE.INPUT_KEYBOARD;
      kbd[i].ki.wVk = input.code;
    }

    for (int i = 0; i < inputs.length; i++) {
      final input = inputs[i];

      kbd[i + inputs.length].type = INPUT_TYPE.INPUT_KEYBOARD;
      kbd[i + inputs.length].ki.wVk = input.code;
      kbd[i + inputs.length].ki.dwFlags = KEYBD_EVENT_FLAGS.KEYEVENTF_KEYUP;
    }

    SendInput(inputs.length * 2, kbd, sizeOf<INPUT>());
    calloc.free(kbd);
  }
}
