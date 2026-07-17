#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  SetUpWindowChromeChannel();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::SetUpWindowChromeChannel() {
  window_chrome_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "ham2k/window_chrome",
          &flutter::StandardMethodCodec::GetInstance());
  window_chrome_channel_->SetMethodCallHandler([this](const auto& call,
                                                      auto result) {
    const std::string& method = call.method_name();
    HWND hwnd = GetHandle();
    if (!hwnd) {
      result->Error("no_window", "Window no longer exists");
      return;
    }
    if (method == "performHeaderDoubleClickAction" ||
        method == "toggleMaximizeWindow") {
      // Windows title-bar double-click convention: toggle maximize.
      ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
      result->Success();
    } else if (method == "minimizeWindow") {
      ShowWindow(hwnd, SW_MINIMIZE);
      result->Success();
    } else if (method == "closeWindow") {
      PostMessage(hwnd, WM_CLOSE, 0, 0);
      result->Success();
    } else if (method == "startWindowDrag") {
      // Success is reported BEFORE entering the system move loop —
      // WM_NCLBUTTONDOWN on the caption blocks in a modal loop until the
      // drag ends, and the Dart future shouldn't wait on that. Handing the
      // drag to the system (rather than moving the window ourselves) keeps
      // Aero Snap working.
      result->Success();
      // A fast flick can release the button during the channel round-trip;
      // starting the move loop then would glue the window to the cursor
      // (the child view already consumed the WM_LBUTTONUP).
      if (GetAsyncKeyState(VK_LBUTTON) & 0x8000) {
        POINT cursor;
        GetCursorPos(&cursor);
        ReleaseCapture();
        SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION,
                    MAKELPARAM(cursor.x, cursor.y));
      }
    } else if (method == "getIsMaximized") {
      // Dart pulls this at startup: the maximize pushes below only fire on
      // transitions, so a fresh Dart side (launch, hot restart) would
      // otherwise assume "not maximized" forever.
      result->Success(flutter::EncodableValue(IsZoomed(hwnd) != FALSE));
    } else if (method == "showSystemMenu") {
      // Right-clicking a real title bar opens the window system menu; the
      // header gesture area restores that path for the chromeless window.
      result->Success();
      HMENU menu = GetSystemMenu(hwnd, FALSE);
      if (menu) {
        POINT cursor;
        GetCursorPos(&cursor);
        // TPM_RETURNCMD hands back the chosen command instead of posting
        // it to the owner, so menu selection works from this non-menu
        // message context.
        UINT command = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON,
                                      cursor.x, cursor.y, 0, hwnd, nullptr);
        if (command != 0) {
          PostMessage(hwnd, WM_SYSCOMMAND, command, 0);
        }
      }
    } else if (method == "setMinimumSize") {
      // The resize floor (layouts.md's minWindowSize), already multiplied by
      // the UI scale on the Flutter side — same contract as the macOS
      // runner's setMinimumSize.
      const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
      const double* width = nullptr;
      const double* height = nullptr;
      if (args) {
        auto width_it = args->find(flutter::EncodableValue("width"));
        auto height_it = args->find(flutter::EncodableValue("height"));
        if (width_it != args->end()) {
          width = std::get_if<double>(&width_it->second);
        }
        if (height_it != args->end()) {
          height = std::get_if<double>(&height_it->second);
        }
      }
      if (width && height) {
        SetMinimumContentSize(*width, *height);
        result->Success();
      } else {
        result->Error("bad_args", "Expected width and height doubles");
      }
    } else {
      // setTitleBarHeight and the like are macOS-only concerns.
      result->NotImplemented();
    }
  });
}

void FlutterWindow::OnDestroy() {
  if (window_chrome_channel_) {
    window_chrome_channel_->SetMethodCallHandler(nullptr);
    window_chrome_channel_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;

    case WM_SIZE: {
      // The Flutter-drawn caption buttons swap their maximize/restore glyph
      // on this (windowsWindowIsMaximized in platform_chrome.dart). Only
      // the two state transitions are pushed — plain resizes stay silent —
      // and the Dart-side ValueNotifier dedupes repeats.
      if (window_chrome_channel_ &&
          (wparam == SIZE_MAXIMIZED || wparam == SIZE_RESTORED)) {
        window_chrome_channel_->InvokeMethod(
            "maximizedChanged",
            std::make_unique<flutter::EncodableValue>(wparam == SIZE_MAXIMIZED));
      }
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
