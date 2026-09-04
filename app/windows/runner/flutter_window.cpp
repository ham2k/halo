#include "flutter_window.h"

#include "ham2k_ipc.h"

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
  SetUpOpenFileChannel();

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

void FlutterWindow::SetUpOpenFileChannel() {
  // Deliberately the SAME channel name and method macOS's AppDelegate uses,
  // so `OpenedFilesService` needs no per-platform branch: a file opened on a
  // Mac and one forwarded from a second Windows launch arrive identically.
  open_file_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "ham2k/open_file",
          &flutter::StandardMethodCodec::GetInstance());
}

bool FlutterWindow::HandleForwardedArguments(COPYDATASTRUCT* cds) {
  if (cds == nullptr || cds->dwData != kHam2kArgumentsMessageId) {
    return false;
  }
  // No channel yet means the engine has not finished starting, and that gap
  // is REAL: `Win32Window::Create` creates the titled, correctly-classed
  // window — findable by the sender — before `OnCreate` builds the engine and
  // this channel.
  //
  // Refusing is the right answer rather than queueing, because refusing is
  // ANSWERED: returning false here makes the WM_COPYDATA reply something
  // other than TRUE, and the sending process is still alive and waiting on
  // it. It keeps the arguments and starts normally instead. A queue here
  // would take responsibility for them at the one moment this side cannot
  // yet act on them.
  if (open_file_channel_ == nullptr || cds->cbData == 0 || cds->lpData == nullptr) {
    return false;
  }

  // UTF-8, NUL-separated, one argument per run, trailing NUL after the last.
  // Walked by length rather than by strlen over the whole block, because
  // `cbData` is the only thing that bounds it — the sender's buffer is not
  // ours and nothing here may read past it.
  const char* data = static_cast<const char*>(cds->lpData);
  flutter::EncodableList paths;
  size_t start = 0;
  for (size_t i = 0; i < cds->cbData; i++) {
    if (data[i] != '\0') {
      continue;
    }
    if (i > start) {
      paths.push_back(flutter::EncodableValue(std::string(data + start, i - start)));
    }
    start = i + 1;
  }
  // A final run with no terminator — a sender that changed its mind about the
  // trailing NUL should not cost the last argument.
  if (start < cds->cbData) {
    paths.push_back(
        flutter::EncodableValue(std::string(data + start, cds->cbData - start)));
  }
  if (paths.empty()) {
    return false;
  }

  // One call carrying every argument, matching the macOS side's batching —
  // the Dart handler reads `paths` as a list and filters for what it acts on.
  open_file_channel_->InvokeMethod(
      "openFiles", std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
                       {flutter::EncodableValue("paths"), flutter::EncodableValue(paths)},
                   }));
  return true;
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
    case WM_COPYDATA:
      // A second launch handed us its arguments and exited. Ours
      // only — app_links puts its own links through the same message with a
      // different id, and returns nullopt for everything else, so both
      // handlers see every WM_COPYDATA and each answers for exactly one id.
      if (HandleForwardedArguments(reinterpret_cast<COPYDATASTRUCT*>(lparam))) {
        // WM_COPYDATA is documented as returning TRUE when the receiver
        // processed it, and the sender's SendMessage is blocking on this.
        return TRUE;
      }
      break;

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
