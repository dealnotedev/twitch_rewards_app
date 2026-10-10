#ifndef RUNNER_LISTENER_UPDATE_H_
#define RUNNER_LISTENER_UPDATE_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <memory>

class ListenerUpdate {
 public:
  ListenerUpdate(flutter::BinaryMessenger* messenger, HWND window);

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif
