#include "listener_update.h"

#include <filesystem>
#include <shellapi.h>

ListenerUpdate::ListenerUpdate(flutter::BinaryMessenger* messenger, HWND window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "listener/update", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([window](
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() == "getAppVersion") {
      result->Success(flutter::EncodableValue(FLUTTER_VERSION));
      return;
    }
    if (call.method_name() != "openUpdater") {
      result->NotImplemented();
      return;
    }
    const auto* options = call.arguments()
        ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
    auto option = [options](const char* name) -> std::string {
      if (!options) return "";
      const auto found = options->find(flutter::EncodableValue(name));
      if (found == options->end()) return "";
      const auto* value = std::get_if<std::string>(&found->second);
      return value ? *value : "";
    };
    const auto locale = option("locale");
    const std::wstring language = locale.rfind("uk", 0) == 0 ? L"uk" : L"en";
    const std::wstring theme = option("theme") == "dark" ? L"dark" : L"light";
    wchar_t module_path[32768];
    const DWORD length = GetModuleFileNameW(nullptr, module_path, 32768);
    if (length == 0 || length >= 32768) {
      result->Error("UPDATER_PATH", "Cannot locate the application directory");
      return;
    }
    const auto directory = std::filesystem::path(module_path).parent_path();
    const auto updater = directory / L"updater" / L"listener_updater.exe";
    const std::wstring arguments = L"--install-dir \"" + directory.wstring() +
        L"\" --locale " + language + L" --theme " + theme;
    const auto launched = reinterpret_cast<INT_PTR>(ShellExecuteW(
        window, L"open", updater.c_str(), arguments.c_str(),
        updater.parent_path().c_str(), SW_SHOWNORMAL));
    if (launched <= 32) {
      result->Error("UPDATER_LAUNCH", "Cannot launch the updater");
      return;
    }
    result->Success();
  });
}
