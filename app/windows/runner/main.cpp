#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "app_links/app_links_plugin_c_api.h"
#include "flutter_window.h"
#include "halo_edition.h"
#include "utils.h"

// One instance per edition, and the way a `com.ham2k://` link reaches the copy
// already running (HALO-178).
//
// Windows answers a registered URL scheme by LAUNCHING the handler with the
// link as its argument — it has no notion of delivering it to a live process.
// Without this, every deep link starts a second copy of the app on the same
// SQLite log, which is a worse bug than the one the registration fixes.
//
// Scoped by the window TITLE, which is `HALO_PRODUCT_NAME_W` — a per-edition
// compile-time constant ("Windows Logger", "Windows Logger Next", "Windows
// Logger (Dev)"). So the three editions never see each other here, which is
// right: they keep separate data directories and are separate applications
// that happen to share a codebase.

// Whether everything this process was launched with can actually be handed
// to the instance already running.
//
// Only a URL can. `app_links` accepts an argument matching `scheme:` — at
// least TWO characters before the colon, so `C:\...\thing.h2kext` is not one
// (and must not be: it is a path, not a link).
//
// This is the difference between single-instancing and silently eating an
// argument. A double-clicked `.h2kext` reaches the app as `argv[1]` of a
// fresh process and is installed from `launchArguments` on the Dart side
// (HALO-422); forwarding-and-exiting on one would raise the window, send
// nothing, and lose the bundle with no error anywhere. So a launch carrying
// something undeliverable starts normally instead — the same second instance
// it has always started, no worse than before, and the extension installs.
//
// Delivering opened FILES to the running instance too is the way to close
// that properly, and needs a message of our own plus a Dart-side receiver.
static bool CanForwardEverything() {
  int argc = 0;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return false;
  }
  // No arguments at all: nothing to lose, so a plain second launch just
  // raises the window. That IS the single-instance behaviour.
  bool forwardable = (argc == 1);
  if (argc == 2) {
    const std::wstring arg(argv[1]);
    const size_t colon = arg.find(L':');
    // `scheme:` with a scheme of two or more characters — deliberately the
    // same shape app_links itself tests for, since it is what decides whether
    // `SendAppLink` will carry this argument.
    forwardable = colon != std::wstring::npos && colon >= 2;
  }
  ::LocalFree(argv);
  return forwardable;
}

static bool ForwardToRunningInstance() {
  if (!CanForwardEverything()) {
    return false;
  }
  // The class name Flutter's own runner registers (win32_window.cpp's
  // `kWindowClassName`); matching upstream's documented example.
  HWND hwnd = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", HALO_PRODUCT_NAME_W);
  if (!hwnd) {
    return false;
  }

  // Raise BEFORE handing anything over. `SendAppLink` uses a blocking
  // `SendMessage`, which does not return while the other instance's UI thread
  // is stuck — so sending first means a hung instance leaves the operator
  // with no window and one invisible blocked process per click, while raising
  // first at least surfaces the app they asked for.
  WINDOWPLACEMENT place = {sizeof(WINDOWPLACEMENT)};
  ::GetWindowPlacement(hwnd, &place);
  switch (place.showCmd) {
    case SW_SHOWMAXIMIZED:
      ::ShowWindow(hwnd, SW_SHOWMAXIMIZED);
      break;
    case SW_SHOWMINIMIZED:
      ::ShowWindow(hwnd, SW_RESTORE);
      break;
    default:
      ::ShowWindow(hwnd, SW_NORMAL);
      break;
  }
  ::SetForegroundWindow(hwnd);

  // Hands over the link this process was started with, if any. A plain second
  // launch carries none and this sends nothing, which is why the raise above
  // is the whole behaviour in that case.
  //
  // NOTE app_links 6.4.1 sizes the WM_COPYDATA payload as
  // `link.size() * sizeof(wchar_t)` while `GetLink()` returns a UTF-8
  // std::string, so the kernel copies about twice the source allocation out
  // of this process. The RESULT is correct — the copy always includes the
  // terminating NUL and the receiver stops there — and calling the package's
  // own entry point keeps us matching whatever it expects, rather than
  // hand-rolling the message around a private constant. Re-check this on any
  // app_links version bump.
  SendAppLink(hwnd);
  return true;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
#ifndef _DEBUG
  // Release and profile only. A debug build is what `flutter run -d windows`
  // produces, and single-instancing that would make a second run silently
  // raise the first one and exit instead of starting the code just built —
  // the dev loop failing in a way that looks like a broken build.
  if (ForwardToRunningInstance()) {
    return EXIT_SUCCESS;
  }
#endif

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(HALO_PRODUCT_NAME_W, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
