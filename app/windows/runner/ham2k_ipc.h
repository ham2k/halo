#ifndef RUNNER_HAM2K_IPC_H_
#define RUNNER_HAM2K_IPC_H_

#include <windows.h>

// The one message this app sends itself (HALO-488).
//
// Windows answers a registered scheme or file type by LAUNCHING the handler
// with the argument, never by delivering it to a live process — so the new
// process hands its arguments to the running one and exits, and this is what
// that hand-off is tagged with. `main.cpp` sends it; `flutter_window.cpp`
// receives it and invokes the same `ham2k/open_file` channel macOS's
// AppDelegate does.
//
// Distinct from app_links' own `WM_USER + 2`: that id means "this is a link"
// and is private to the package. Sharing it would misdescribe the payload and
// would break the moment either side renumbered — so the two ids live apart,
// and one message is never mistaken for the other.
//
// Sent as WM_COPYDATA `dwData`. The payload is UTF-8, NUL-separated, one
// argument per run, with a trailing NUL after the last — `cbData` is the true
// byte length, so the receiver walks it without a separate count.
constexpr ULONG_PTR kHam2kArgumentsMessageId = WM_USER + 101;

#endif  // RUNNER_HAM2K_IPC_H_
