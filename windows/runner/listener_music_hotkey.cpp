#include "listener_music_hotkey.h"

#include <cstdint>

namespace {
constexpr int kHotkeyId = 0x4C01;
constexpr UINT kAllowedModifiers = MOD_CONTROL | MOD_ALT | MOD_SHIFT;

const int32_t* ReadInt(const flutter::EncodableMap& map, const char* name) {
  const auto field = map.find(flutter::EncodableValue(name));
  return field == map.end() ? nullptr : std::get_if<int32_t>(&field->second);
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
        const auto* arguments = call.arguments();
        if (!arguments || arguments->IsNull()) {
          result->Success(flutter::EncodableValue(SetShortcut(0, 0)));
          return;
        }
        const auto* shortcut = std::get_if<flutter::EncodableMap>(arguments);
        const auto* key = shortcut ? ReadInt(*shortcut, "keyCode") : nullptr;
        const auto* modifiers =
            shortcut ? ReadInt(*shortcut, "modifiers") : nullptr;
        if (!key || !modifiers || *key <= 0 || *key > 0xFE ||
            (static_cast<UINT>(*modifiers) & ~kAllowedModifiers) != 0) {
          result->Error("invalid_shortcut", "Invalid Windows hotkey.");
          return;
        }
        result->Success(flutter::EncodableValue(SetShortcut(*modifiers, *key)));
      });
}

ListenerMusicHotkey::~ListenerMusicHotkey() {
  channel_->SetMethodCallHandler(nullptr);
  SetShortcut(0, 0);
}

bool ListenerMusicHotkey::SetShortcut(UINT modifiers, UINT key) {
  // Keep the existing shortcut registered until Windows accepts its replacement.
  const int next_id = active_id_ == kHotkeyId ? kHotkeyId + 1 : kHotkeyId;
  if (key != 0 &&
      !RegisterHotKey(window_, next_id, modifiers | MOD_NOREPEAT, key)) {
    return false;
  }
  if (active_id_ != 0 && !UnregisterHotKey(window_, active_id_)) {
    if (key != 0) UnregisterHotKey(window_, next_id);
    return false;
  }
  active_id_ = key == 0 ? 0 : next_id;
  return true;
}

bool ListenerMusicHotkey::HandleHotkey(WPARAM id) {
  if (active_id_ == 0 || id != static_cast<WPARAM>(active_id_)) return false;
  channel_->InvokeMethod("pressed", nullptr);
  return true;
}
