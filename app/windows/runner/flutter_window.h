#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/method_result_functions.h>

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

  // The `ham2k/image_clipboard` channel: an image on the clipboard
  // (image_clipboard_io.dart), which Flutter's own Clipboard cannot do.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      image_clipboard_channel_;

  // A close the engine let through without asking the app whether it may
  // exit (see WM_CLOSE in MessageHandler): pending while the app says its
  // goodbyes, so a second click on close does not ask again, and ready once
  // it has, so the close it posts then goes through.
  bool close_pending_ = false;
  bool close_ready_ = false;

  // How long a close waits on the app's answer before closing without it:
  // past the app's own watchdog (hang_watchdog.dart's silence plus grace),
  // which ends a process wedged inside the teardown sooner.
  static constexpr UINT_PTR kCloseFallbackTimer = 0x4841;
  static constexpr UINT kCloseFallbackMs = 30000;

  // The app is done with its goodbyes, or cannot be asked: close for real.
  void FinishClose();

  void SetUpWindowChromeChannel();
  void SetUpOpenFileChannel();
  void SetUpImageClipboardChannel();

  // Turns a forwarded WM_COPYDATA payload into an `openFiles` call. Returns
  // whether the message was ours.
  bool HandleForwardedArguments(COPYDATASTRUCT* cds);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
