#ifndef RUNNER_LISTENER_MUSIC_HOTKEY_H_
#define RUNNER_LISTENER_MUSIC_HOTKEY_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>

class ListenerMusicHotkey {
 public:
  ListenerMusicHotkey(flutter::BinaryMessenger* messenger, HWND window);
  ~ListenerMusicHotkey();

  bool HandleHotkey(WPARAM id);

 private:
  bool SetShortcut(UINT modifiers, UINT key);

  const HWND window_;
  int active_id_ = 0;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_LISTENER_MUSIC_HOTKEY_H_
