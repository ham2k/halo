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

### What the arms established

Builds 155 and 157, run on a machine that reproduces:

| Arm | Plugin built | Delegate | Channels | InitializeAsync | Result |
| --- | --- | --- | --- | --- | --- |
| `off` | no | - | - | - | launches |
| `registrar` | no | - | - | - | launches |
| `construct` | yes | yes | no | yes | ? |
| `nochannels` | yes | yes | no | yes | crashes |
| `nodelegate` | yes | **no** | yes | yes | crashes, and EARLIER -- before Sentry initialises |
| `noinit` | yes | yes | yes | **no** | crashes |
| unset | yes | yes | yes | yes | crashes |

Each of the plausible culprits has now been excluded by an arm that skips it
and dies anyway: the window proc delegate (`nodelegate`), the four channel
`SetUp` calls (`nochannels`), the WinRT radio enumeration (`noinit`), and
`GetRegistrar<>()` (`registrar`, which runs it and launches).

**Every arm that constructs `UniversalBlePlugin` crashes; every arm that does
not, launches.** What is left is two statements in `RegisterWithRegistrar`:
`std::make_unique<UniversalBlePlugin>(registrar)` and `AddPlugin`.

The `construct` arm splits those two -- it builds the plugin and returns before
`AddPlugin`, leaking it deliberately, because running the destructor there
would fold teardown into the answer.

### Step tracing

Bisecting bought one bit per release cycle, and the remaining window is two
statements plus a stretch **no arm can reach**: member initialisation runs
before the constructor's body, so nothing gated inside `RegisterWithRegistrar`
can probe it.

`HAM2K_BLE_TRACE=1` prints each step to `CONOUT$` and the debugger, so the last
line on the operator's console names the statement that dies:

```
01 c_api entered
02 calling GetRegistrar
03 GetRegistrar returned
04 constructing UniversalBlePlugin
05 UiThreadHandler ctor entered     <- opens the member-construction bracket
05b delegate registered
06 plugin ctor body reached         <- closes it: every member survived
07 plugin constructed
08 setting up channels
09 calling AddPlugin
10 registration complete
```

`05` and `06` are the pair that matters: `ui_thread_handler_` is the plugin's
first non-trivial member and members initialise in declaration order, so
everything between those two lines is the WinRT handles, the `ThreadSafeMap`s
with their `shared_mutex`es, and `peripheral_mutex_`.

Two properties of the gate are load-bearing. It is **silent unless asked for**,
or every Windows operator gets probe output on an ordinary launch. And it keys
off its **own** variable rather than `HAM2K_BLE_MODE`, because the arm that
most needs tracing is the control one -- with no mode set at all.

### What this is not

Not a fix, and still no claimed mechanism. The fault is
`EXCEPTION_ACCESS_VIOLATION_READ / 0x0` inside `mtx_do_lock` -- a null mutex --
and this plugin has no static or global mutex that could be null at
registration time. `mtx_do_lock` lives in MSVCP140, shared by every module, so
the caller remains unknown. `nodelegate` dying earlier than every other arm is
unexplained and worth keeping in view.

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
