#ifndef RUNNER_UPDATER_HOST_H_
#define RUNNER_UPDATER_HOST_H_
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <filesystem>
#include <memory>

class UpdaterHost {
 public:
  UpdaterHost(flutter::BinaryMessenger* messenger, HWND window);
  ~UpdaterHost();
  bool close_blocked() const { return update_mutex_ != nullptr; }

 private:
  bool ListenerRunning(bool request_exit);
  void ReleaseUpdateLock();
  HWND window_;
  HANDLE update_mutex_ = nullptr;
  std::filesystem::path installation_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
#endif
