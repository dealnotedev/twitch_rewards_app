#include <bitsdojo_window_windows/bitsdojo_window_plugin.h>
auto bdw = bitsdojo_window_configure(BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP);

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <memory>

#include "flutter_window.h"
#include "utils.h"
#include <hid_listener/hid_listener_plugin_windows.h>

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE update_mutex = OpenMutexW(
      SYNCHRONIZE, FALSE, L"Local\\TwitchListener.UpdateInProgress");
  if (update_mutex) {
    CloseHandle(update_mutex);
    return EXIT_FAILURE;
  }

  using ScopedHandle = std::unique_ptr<void, decltype(&CloseHandle)>;
  // Create the event first so a second launch can request activation even
  // before the first instance has created its window or started its message loop.
  ScopedHandle activate_event(
      CreateEventW(nullptr, FALSE, FALSE, L"Local\\TwitchListener.Activate"),
      CloseHandle);
  if (!activate_event) {
    return EXIT_FAILURE;
  }
  ScopedHandle single_instance(
      CreateMutexW(nullptr, FALSE, L"Local\\TwitchListener.SingleInstance"),
      CloseHandle);
  const bool already_running = GetLastError() == ERROR_ALREADY_EXISTS;
  if (!single_instance) {
    return EXIT_FAILURE;
  }
  if (already_running) {
    HWND existing =
        FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"twitch_listener");
    if (existing) {
      DWORD process_id = 0;
      GetWindowThreadProcessId(existing, &process_id);
      AllowSetForegroundWindow(process_id);
    }
    return SetEvent(activate_event.get()) ? EXIT_SUCCESS : EXIT_FAILURE;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  // Use the Skia renderer for Windows builds.
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);

  // TODO: dealnotedev, Remove this after engine fix.
  // This forces Flutter to use a separate thread for Dart.
  // This mode will be removed in a future version of Flutter.
  project.set_ui_thread_policy(flutter::UIThreadPolicy::RunOnSeparateThread);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"twitch_listener", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  HidListener listener;

  HANDLE activation = activate_event.get();
  bool running = true;
  int exit_code = EXIT_SUCCESS;
  while (running) {
    const DWORD wait = MsgWaitForMultipleObjects(
        1, &activation, FALSE, INFINITE, QS_ALLINPUT);
    if (wait == WAIT_FAILED) {
      exit_code = EXIT_FAILURE;
      break;
    }
    if (wait == WAIT_OBJECT_0) {
      HWND existing = window.GetHandle();
      ShowWindow(existing, IsIconic(existing) ? SW_RESTORE : SW_SHOW);
      SetForegroundWindow(existing);
    }

    ::MSG msg;
    while (::PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
      if (msg.message == WM_QUIT) {
        running = false;
        break;
      }
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
    }
  }

  ::CoUninitialize();
  return exit_code;
}
