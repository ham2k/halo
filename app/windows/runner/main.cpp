#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "app_links/app_links_plugin_c_api.h"
#include "flutter_window.h"
#include "ham2k_ipc.h"
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

// Every argument this launch carries, UTF-8 and NUL-separated.
//
// ALL of them, with no attempt to work out which ones `app_links` will also
// take. Its rule is `^([a-z][a-z0-9+.-]+):` — a scheme must START with a
// letter — and any second copy of that rule here is a source of silent loss:
// an argument this side calls a link and app_links does not is one nobody
// carries. `\\?\C:\...`, the extended-length path the shell produces for a
// long filename, is exactly that shape.
//
// Sending a link on this channel as well costs nothing: it reaches the Dart
// side's opened-files handler, which acts only on the extension it knows and
// ignores everything else. Duplication is cheap; a dropped argument is not.
//
// NUL-separated rather than joined, because a Windows path may contain almost
// anything except NUL.
static std::string AllArguments() {
  int argc = 0;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::string();
  }

  std::string payload;
  for (int i = 1; i < argc; i++) {
    std::wstring arg(argv[i]);

    // A path is resolved HERE, where the launching process's own working
    // directory is the one the operator typed it against. The instance that
    // receives it has a different cwd entirely, so `halo ./thing.h2kext`
    // would otherwise name a file that does not exist there.
    //
    // Only for an argument that actually IS an existing file: that is a fact
    // rather than a guess, and running a URL through GetFullPathName would
    // mangle it into a path.
    if (::GetFileAttributesW(arg.c_str()) != INVALID_FILE_ATTRIBUTES) {
      wchar_t full[MAX_PATH * 4];
      const DWORD length = ::GetFullPathNameW(arg.c_str(), MAX_PATH * 4, full, nullptr);
      if (length > 0 && length < MAX_PATH * 4) {
        arg.assign(full, length);
      }
    }

    const int size = ::WideCharToMultiByte(CP_UTF8, 0, arg.c_str(), (int)arg.size(), nullptr, 0,
                                           nullptr, nullptr);
    if (size <= 0) {
      continue;
    }
    std::string utf8((size_t)size, 0);
    ::WideCharToMultiByte(CP_UTF8, 0, arg.c_str(), (int)arg.size(), &utf8[0], size, nullptr,
                          nullptr);
    payload += utf8;
    payload.push_back('\0');
  }
  ::LocalFree(argv);
  return payload;
}

// Hands [payload] to the running instance, and reports whether it ARRIVED.
//
// The receipt is the whole point. `WM_COPYDATA` returns TRUE only when the
// receiver processed it, and the receiver refuses when its Flutter engine is
// not up yet — the window is created and findable before `OnCreate` builds
// the channel, so that gap is real rather than theoretical. Without checking,
// this process would exit successfully having delivered nothing.
//
// A private id rather than app_links': `APPLINK_MSG_ID` is internal to that
// package and means "this is a link", so borrowing it would both misdescribe
// the payload and break if the package renumbered.
//
// `cbData` is the true byte length of the buffer — not, as app_links' own
// sender computes, twice it.
//
// SendMessageTimeout rather than SendMessage: this blocks on the other
// process's UI thread, and a wedged instance would otherwise hold this one
// forever, invisibly, once per launch. A timeout reads as "not delivered",
// which the caller can still recover from.
static bool SendArgumentsToInstance(HWND hwnd, const std::string& payload) {
  if (payload.empty()) {
    return true;  // Nothing to deliver, so nothing can be lost.
  }
  COPYDATASTRUCT cds = {0};
  cds.dwData = kHam2kArgumentsMessageId;
  cds.cbData = (DWORD)payload.size();
  cds.lpData = (PVOID)payload.data();

  DWORD_PTR handled = FALSE;
  const LRESULT sent =
      ::SendMessageTimeout(hwnd, WM_COPYDATA, (WPARAM)hwnd, (LPARAM)(LPVOID)&cds,
                           SMTO_ABORTIFHUNG, 5000, &handled);
  return sent != 0 && handled == TRUE;
}

static bool ForwardToRunningInstance() {
  // The class name Flutter's own runner registers (win32_window.cpp's
  // `kWindowClassName`); matching upstream's documented example.
  HWND hwnd = ::FindWindow(L"FLUTTER_RUNNER_WIN32_WINDOW", HALO_PRODUCT_NAME_W);
  if (!hwnd) {
    return false;
  }

  // Nothing is given up until the hand-over is confirmed. A window can exist
  // whose engine is still starting, and the operator can quit the app in the
  // instant between finding it and sending — in both cases this launch is
  // still the only thing holding the arguments, so it starts normally and
  // acts on them itself. A second instance is a bad outcome the operator can
  // see and close; a swallowed file is one they cannot.
  if (!SendArgumentsToInstance(hwnd, AllArguments())) {
    return false;
  }

  // The link half. `SendAppLink` carries a lone `scheme:` argument and
  // nothing else, so it is additive to the payload above rather than an
  // alternative to it — and it runs only now that the instance has proved it
  // is alive and answering.
  SendAppLink(hwnd);

  // Raise last: an operator who clicked something is owed the window, and by
  // here it is known to be a window that actually took what was sent.
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
      // Not SW_NORMAL: on a snapped window that restores the pre-snap rect.
      ::ShowWindow(hwnd, SW_SHOW);
      break;
  }
  ::SetForegroundWindow(hwnd);
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
  // new console when running with a debugger. A launch from a Command
  // Prompt attaches too but inherits no stdout handle at all (GUI
  // subsystem), so the streams are pointed at the console there; under
  // 'flutter run' stdout is the tool's pipe — the VM service URI travels
  // on it — and must be left alone.
  HANDLE inherited_stdout = ::GetStdHandle(STD_OUTPUT_HANDLE);
  bool has_stdout =
      inherited_stdout != nullptr && inherited_stdout != INVALID_HANDLE_VALUE;
  if (::AttachConsole(ATTACH_PARENT_PROCESS)) {
    if (!has_stdout) {
      RedirectStreamsToConsole();
    }
  } else if (::IsDebuggerPresent()) {
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
