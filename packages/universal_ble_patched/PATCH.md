# Vendored `universal_ble` 2.1.1

A copy of `universal_ble` 2.1.1 from pub.dev, minus `example/` and `test/`,
carrying one temporary diagnostic patch. `app/pubspec.yaml` and
`app_dist/pubspec.yaml` both point `universal_ble` at this directory.

**This whole package is scaffolding for HALO-290 and is meant to be deleted.**
Unlike the other vendored packages here, it fixes nothing: it exists to make a
single signed Windows release answer a question we cannot answer any other way.
Once the A/B below has its answer, either drop the override and go back to the
published package, or replace this file with a real patch.

## The HALO-290 boot A/B switch

### Why

On the reporter's Windows 10 laptop the app dies before any window appears:
Process Monitor records exit status `0xC0000005` (`STATUS_ACCESS_VIOLATION`),
and the retained minidump (`HALO-NEXT-78`) resolves to

```
wWinMain (main.cpp:39) → DispatchMessageWorker
  → Win32Window::WndProc (win32_window.cpp:238)
  → FlutterWindow::MessageHandler (flutter_window.cpp:157)
  → flutter::WindowProcDelegateManager::OnTopLevelWindowProc
  → FlutterDesktopViewControllerHandleTopLevelWindowProc
  → ... → mtx_do_lock (mutex.cpp:103)
```

Build 145 boots, 146 does not, and this plugin is the only native Windows
plugin added in that range (`e9d29d56`, HALO-342). Two things make it the
prime suspect rather than merely the newest change:

- Its constructor calls `InitializeAsync()` unconditionally, from inside
  `RegisterPlugins()` — i.e. before the first frame, on every launch, with no
  Dart-side opt-out. `peer_ble_io.dart`'s own doc comment states the opposite
  invariant ("the radio must stay untouched until the sub-switch starts the
  transport"), and `peerBleEnabled` defaults false; the Dart side keeps that
  bargain and the plugin breaks it in C++.
- Of the three plugins in this app that register a top-level window proc
  delegate (`app_links`, `flutter_inappwebview_windows`, this one), it is the
  only one that takes a `std::mutex` inside a window message —
  `ui_thread_handler.hpp`'s `HandleWindowMessage`. That is the `mtx_do_lock`
  frame. `app_links` has no mutex at all, and the webview's delegate forwards
  to `platformUtil` without locking (and owns no platform view this early).

Prior passes on HALO-290 shipped three separate fixes reasoned out from
Sentry's nearest-export symbolication, and none of them stopped the crash. The
switch exists so the next one is decided by evidence.

### What it does

`src/ham2k_ble_mode.h` reads `HAM2K_BLE_MODE` once per process:

| Value | Behaviour |
| --- | --- |
| unset | Register and initialize, exactly as upstream. **The control arm.** |
| `noinit` | Register (channels and the window proc delegate are hooked) but skip `InitializeAsync()`. |
| `off` | Never register: no delegate, no channels, no init. |

Two call sites, both guarding upstream lines rather than replacing them:

- `windows/universal_ble_plugin_c_api.cpp` returns before
  `RegisterWithRegistrar` on `off`.
- `windows/src/universal_ble_plugin.cpp`'s constructor returns before
  `InitializeAsync()` on `noinit`.

Each arm prints one line to the attached console. That announcement is
load-bearing: the crash kills the process before Dart runs, so it is the only
evidence of which arm the operator actually got — an env var set in the wrong
shell is otherwise indistinguishable from an arm that did not help.

### Reading the result

- **`off` boots, `noinit` crashes** → the window proc delegate and its mutex
  are the crash, independent of any BLE work. The fix is in
  `ui_thread_handler.hpp` (upstream `main` has since added an `accepting_`
  flag and a `Shutdown()` there; note `hwnd_` is still written and read across
  threads unsynchronized, which upstream has *not* fixed).
- **Both boot** → the WinRT radio enumeration in `InitializeAsync()` is the
  trigger. The fix is to make it lazy, on first Dart-side use.
- **Neither boots** → this plugin is not the cause and the theory is dead,
  which is worth just as much as a confirmation.

### What deliberately is NOT in here

Upstream `main` (unreleased 2.2.0) wraps `InitializeAsync()` in
`try`/`catch`; 2.1.1 has no exception handling there at all, and an escaping
exception from a `winrt::fire_and_forget` coroutine calls `std::terminate()`.
That is a real defect on this exact boot path and we want it — **but not in
this build**. Landing it would change the control arm, and an experiment whose
control has been quietly improved answers nothing. It goes in the build after
this one.

## Release PDBs

`windows/CMakeLists.txt` adds `/Zi` (compile) and `/DEBUG` (link) for Release.
Both are needed: MSVC emits the linked PDB only when the linker gets `/DEBUG`,
and `/Zi` alone leaves compiler-side PDBs that
`app_dist/ci/build-windows.ps1`'s `sentry-cli debug-files upload` never finds.
This is debug info only — it changes no generated code, which is what lets it
ride along in the control arm.

Without it, a crash whose real site is inside this plugin resolves in Sentry to
the nearest exported symbol with no line and no non-exported frames, which is
precisely how three rounds of HALO-290 came to attribute this plugin's frames
to MSVCP140's `mtx_do_lock`.

## Re-vendoring

Copy the new package over this directory (keep dropping `example/` and
`test/`), then re-apply: the two `ham2k_ble_mode.h` guards, the header itself,
its entry in `PLUGIN_SOURCES`, and the two Release-PDB lines.
`app/test/ble_plugin_overrides_test.dart` asserts each of those is present —
nothing in `./scripts/test.sh` compiles C++, so those assertions are the only
part of this patch a Dart test can see.
