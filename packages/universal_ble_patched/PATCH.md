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

Build 155 ran the first three arms on a machine that reproduces the crash:

| Arm | Result |
| --- | --- |
| unset (control) | crashes at boot, no window |
| `off` | **launches** |
| `noinit` | crashes at boot, no window |

That confirms `universal_ble` as the cause and puts the fault in **registration**,
not in the Bluetooth work — `noinit` skips only `InitializeAsync()` and still
dies. It also rules out lazy initialization as a fix: `noinit` *is* lazy init's
boot behaviour.

`src/ham2k_ble_mode.h` now reads `HAM2K_BLE_MODE` as a ladder from the
known-good arm to the known-bad one. Each rung adds one step, so the first arm
that fails names the culprit:

| Value | Runs | 155 |
| --- | --- | --- |
| `off` | nothing | launches |
| `registrar` | + `GetRegistrar<PluginRegistrarWindows>()` | ? |
| `nochannels` | + construct the plugin (delegate hooked) and `AddPlugin`, no channel `SetUp` | ? |
| `nodelegate` | everything EXCEPT registering the window proc delegate | ? |
| `noinit` | everything except `InitializeAsync()` | crashes |
| unset | upstream | crashes |

`nodelegate` is deliberately off the spine: it is the only arm that subtracts
rather than adds, and it is the direct test of the window proc hook that
`mtx_do_lock` is reached through. Its destructor must skip
`UnregisterTopLevelWindowProcDelegate` — handing the engine an id it never
issued is its own crash, in exactly the arm whose result we most need to
trust, and it would read as "the delegate IS the problem".

Each arm announces itself on `CONOUT$` and via `OutputDebugStringW` —
deliberately not `printf`, which goes nowhere from this GUI-subsystem binary on
a normal `cmd` launch, since the runner only reattaches the CRT's stdout when
`AttachConsole` *fails* and a debugger is present. Build 155 confirmed the
announcement reaches the console.

### Reading the result

Whichever arm first fails, going down the ladder, contains the crash:

- **`registrar` fails** -> the Flutter wrapper's own registrar map, not this
  plugin's code at all.
- **`nochannels` fails** -> constructing the plugin or hooking the delegate.
  Cross-check against `nodelegate`.
- **`nodelegate` launches** (while `noinit` crashes) -> the window proc
  delegate registration is the crash, and the fix belongs in
  `ui_thread_handler.hpp`.
- **`nodelegate` also fails** -> the delegate is innocent and the crash is in
  the channel `SetUp` calls or plugin construction.

### What this is not

Not a fix, and not a theory about the mechanism. The observed fault is
`EXCEPTION_ACCESS_VIOLATION_READ / 0x0` inside `mtx_do_lock` — a null mutex —
and this plugin has no static or global mutex that could be null at
registration time. `mtx_do_lock` lives in MSVCP140, shared by every module, so
the caller is genuinely unknown. Three earlier rounds on HALO-290 were lost to
inventing a mechanism from a stack like this one; the ladder exists to avoid a
fourth.

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
`test/`), then re-apply: `ham2k_ble_mode.h` itself, its entry in
`PLUGIN_SOURCES`, its four guards (`kOff` and `kRegistrarOnly` in the C API,
`kNoChannels` in `RegisterWithRegistrar`, `kNoDelegate` plus the `registered_`
destructor guard in `ui_thread_handler.hpp`, `kNoInit` in the plugin
constructor), and the two Release-PDB lines.
`app/test/ble_plugin_overrides_test.dart` asserts each of those is present —
nothing in `./scripts/test.sh` compiles C++, so those assertions are the only
part of this patch a Dart test can see.
