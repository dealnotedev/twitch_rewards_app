#include "listener_music_hotkey.h"

#include <cstdint>

namespace {
bool IsKeyboardKey(UINT key) {
  return key == VK_CANCEL ||
         (key >= VK_BACK && key < 0xff && key != VK_PACKET &&
          key != VK_PROCESSKEY);
}

UINT NormalizeKey(UINT key) {
  switch (key) {
    case VK_LCONTROL:
    case VK_RCONTROL:
      return VK_CONTROL;
    case VK_LMENU:
    case VK_RMENU:
      return VK_MENU;
    case VK_LSHIFT:
    case VK_RSHIFT:
      return VK_SHIFT;
    case VK_RWIN:
      return VK_LWIN;
    default:
      return key;
  }
}

UINT PhysicalVirtualKey(const RAWKEYBOARD& key) {
  const bool extended = (key.Flags & RI_KEY_E0) != 0;
  switch (key.VKey) {
    case VK_SHIFT: {
      const UINT side = MapVirtualKeyW(key.MakeCode, MAPVK_VSC_TO_VK_EX);
      return side == VK_LSHIFT || side == VK_RSHIFT ? side : VK_SHIFT;
    }
    case VK_CONTROL:
      return extended ? VK_RCONTROL : VK_LCONTROL;
    case VK_MENU:
      return extended ? VK_RMENU : VK_LMENU;
    default:
      return key.VKey;
  }
}
}  // namespace

ListenerMusicHotkey::ListenerMusicHotkey(flutter::BinaryMessenger* messenger,
                                         HWND window)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "listener/music_hotkey",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "setShortcut") {
          result->NotImplemented();
          return;
        }
        Keys shortcut;
        const auto* arguments = call.arguments();
        if (arguments && !arguments->IsNull()) {
          const auto* options = std::get_if<flutter::EncodableMap>(arguments);
          const flutter::EncodableList* keys = nullptr;
          if (options) {
            const auto entry = options->find(flutter::EncodableValue("keys"));
            if (entry != options->end()) {
              keys = std::get_if<flutter::EncodableList>(&entry->second);
            }
          }
          if (!keys || keys->empty()) {
            result->Error("invalid_shortcut", "Expected a list of keys.");
            return;
          }
          for (const auto& value : *keys) {
            const auto* key = std::get_if<int32_t>(&value);
            if (!key || !IsKeyboardKey(static_cast<UINT>(*key))) {
              result->Error("invalid_shortcut", "Invalid Windows key.");
              return;
            }
            shortcut.set(NormalizeKey(*key));
          }
        }
        result->Success(flutter::EncodableValue(SetShortcut(shortcut)));
      });
}

ListenerMusicHotkey::~ListenerMusicHotkey() {
  channel_->SetMethodCallHandler(nullptr);
  SetShortcut({});
}

bool ListenerMusicHotkey::SetShortcut(Keys keys) {
  if (shortcut_.none() != keys.none()) {
    RAWINPUTDEVICE keyboard{0x01, 0x06, RIDEV_REMOVE, nullptr};
    if (keys.any()) {
      keyboard.dwFlags = RIDEV_INPUTSINK | RIDEV_DEVNOTIFY;
      keyboard.hwndTarget = window_;
    }
    if (!RegisterRawInputDevices(&keyboard, 1, sizeof(keyboard))) return false;
    ResetPressedKeys();
  }
  shortcut_ = keys;
  matched_on_press_ = false;
  return true;
}

ListenerMusicHotkey::Keys ListenerMusicHotkey::PressedShortcutKeys() const {
  Keys keys;
  for (UINT key = VK_CANCEL; key < keys.size(); ++key) {
    if (pressed_.test(key)) keys.set(NormalizeKey(key));
  }
  return keys;
}

void ListenerMusicHotkey::HandleInput(HRAWINPUT input) {
  if (shortcut_.none()) return;

  RAWINPUT data{};
  UINT size = sizeof(data);
  const UINT copied = GetRawInputData(input, RID_INPUT, &data, &size,
                                      sizeof(RAWINPUTHEADER));
  if (copied == static_cast<UINT>(-1) || data.header.dwType != RIM_TYPEKEYBOARD) {
    return;
  }
  const auto& keyboard = data.data.keyboard;
  const UINT key = PhysicalVirtualKey(keyboard);
  const bool down = (keyboard.Flags & RI_KEY_BREAK) == 0;
  if (!IsKeyboardKey(key) || pressed_.test(key) == down) return;

  const Keys before = PressedShortcutKeys();
  pressed_.set(key, down);
  const Keys after = PressedShortcutKeys();
  if (before == after) return;

  // A chord fires on release, so a one-key binding can also be used as part
  // of another combination. Repeats and releasing extra keys cannot arm it.
  if (down) {
    matched_on_press_ = after == shortcut_;
  } else {
    if (matched_on_press_) channel_->InvokeMethod("pressed", nullptr);
    matched_on_press_ = false;
  }
}

void ListenerMusicHotkey::ResetPressedKeys() {
  pressed_.reset();
  matched_on_press_ = false;
}
