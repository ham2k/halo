#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // The `ham2k/window_chrome` channel: the chromeless window (see
  // win32_window.cpp's custom frame) has no caption, so the Flutter side
  // provides the title-bar behaviors — drag, double-click, and the drawn
  // caption buttons (halo_widgets platform_chrome.dart) — and this channel
  // carries their actions plus our maximize-state pushes back.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_chrome_channel_;

  // The `ham2k/open_file` channel — the SAME name and method macOS's
  // AppDelegate invokes, so the Dart side (OpenedFilesService) needs to know
  // nothing about which platform handed it a file. Carries arguments a second
  // launch forwarded to this instance.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      open_file_channel_;

  void SetUpWindowChromeChannel();
  void SetUpOpenFileChannel();

  // Turns a forwarded WM_COPYDATA payload into an `openFiles` call. Returns
  // whether the message was ours.
  bool HandleForwardedArguments(COPYDATASTRUCT* cds);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
