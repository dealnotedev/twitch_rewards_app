#ifndef RUNNER_LISTENER_MUSIC_HOTKEY_H_
#define RUNNER_LISTENER_MUSIC_HOTKEY_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <bitset>
#include <memory>

class ListenerMusicHotkey {
 public:
  ListenerMusicHotkey(flutter::BinaryMessenger* messenger, HWND window);
  ~ListenerMusicHotkey();

  void HandleInput(HRAWINPUT input);
  void ResetPressedKeys();

 private:
  using Keys = std::bitset<256>;

  bool SetShortcut(Keys keys);
  Keys PressedShortcutKeys() const;

  const HWND window_;
  Keys shortcut_;
  Keys pressed_;
  bool matched_on_press_ = false;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_LISTENER_MUSIC_HOTKEY_H_
