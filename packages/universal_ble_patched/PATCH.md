# Vendored `universal_ble` 2.1.1

A copy of `universal_ble` 2.1.1 from pub.dev, minus `example/` and `test/`,
carrying two real patches to its Windows code. `app/pubspec.yaml` and
`app_dist/pubspec.yaml` both point `universal_ble` at this directory.

Half of what is here is ported from upstream `main` and will arrive on its own
in a future release; the other half upstream has not fixed. The re-vendoring
notes at the bottom say which is which, because taking upstream's newer copy of
`ui_thread_handler.hpp` wholesale would silently drop the half they do not have.

## What HALO-290 turned out to be, and what this package is not

This package began as scaffolding for HALO-290's boot crash — a runtime A/B
switch (`HAM2K_BLE_MODE`) with six arms and a step trace, so one signed release
could carry every arm of an experiment we could not run any other way. That
apparatus is gone; the arms, the trace and their guard tests were deleted once
the card had its answer.

**The boot crash was not this plugin's fault.** It was an MSVC ABI mismatch:
since VS 2022 17.10 `std::mutex`'s constructor is `constexpr`, so the object is
zero-initialized at compile time instead of by `_Mtx_init_in_situ`. Run that
binary against an older `MSVCP140.dll` and the old `mtx_do_lock` dereferences a
pointer field the new implementation never populates, faulting on address 0.
Fixed by shipping the VC++ runtime app-local (HALO-568). This plugin was merely
the first on the boot path to construct and lock a `std::mutex`, which is why
it looked like a clean 145 -> 146 regression and why every A/B arm that
constructed the plugin crashed while `off` and `registrar` launched.

The patches that remain are unrelated to that, and stand on their own merits.

## The UI-thread hop's teardown gate

`ui_thread_handler.hpp` hops work from a WinRT thread-pool thread onto the UI
thread by queueing it and poking the top-level window proc. The minidump from
build 162 puts `universal_ble_plugin.dll` directly beneath a faulting
`mtx_do_lock`, reached from the UI thread's message loop, on a mutex whose
internal pointer reads as zero -- a lock taken on an object that is going away.

Two defects, one of them upstream's and one it still has:

`Post()` and the queue drain had no notion of teardown, so work queued while
the handler was being destroyed ran against members already reset, and a window
message posted before destruction still found the delegate registered
afterwards. `accepting_`, checked under the mutex in both, closes that. The
delegate is unregistered LAST, since the flag is what makes an already-queued
message harmless and must be false before the delegate can stop being called.
This half is ported from upstream `main` (`05e7e73`).

`hwnd_` is written by the UI thread on the first window message and read by
whichever thread calls `Post()`, with no synchronization at all -- a data race
on every launch. It is `std::atomic` here. **Upstream has NOT fixed this**, so a
re-vendor that takes upstream's newer copy of this file wholesale would drop it
while looking like an upgrade; a guard test says so.

`~UniversalBlePlugin` calls `Shutdown()` FIRST. Members are destroyed after the
destructor body, so without that call the delegate is still hooked and still
draining while `ClearServices()` and the channel resets run underneath the
queued callbacks -- several of which capture `this`.

Not claimed: that this is proven to fix the boot crash. The minidump names the
module, not the function -- the plugin's PDB has never reached Sentry (see
below), so the four frames under the fault are still unresolved.

## Known missing: upstream's `InitializeAsync` guard

`InitializeAsync()` in `windows/src/universal_ble_plugin.cpp` is a
`winrt::fire_and_forget` coroutine that `co_await`s
`Radio::GetRadiosAsync()` with **no try/catch**, in 2.1.1 and here. An
escaping `hresult_error` -- radio access denied, an RPC failure, the WinRT
service not up yet -- escapes the coroutine's promise, which calls
`std::terminate()`. That is a process kill from inside `RegisterPlugins()`,
before the first frame, with nothing logged and nothing reported.

Upstream `main` wraps the body. We have NOT taken that hunk: it was withheld
on purpose while HALO-290's A/B was running, because the unset arm had to stay
byte-for-byte upstream behaviour for the experiment's control to mean anything.
The A/B is over, so the reason is gone and only the gap remains.

Note this is a genuine C++ exception and a `catch` does close it -- unlike
HALO-290's own fault, which was an SEH access violation that MSVC's
`catch (...)` does not catch under `/EHsc`. The two were conflated once; they
are different failures.

Also unguarded on the same path: `initialized_ = true` is the last statement,
so any failure short of terminating leaves it false forever and
`GetBluetoothAvailabilityState` answers `kUnknown` indefinitely, with no log
line. `peer_ble_io.dart` polls that getter and gives up on BLE, so the user
sees "Bluetooth unavailable" for a failure nothing recorded.

## Release PDBs

`windows/CMakeLists.txt` adds `/Zi` (compile) and `/DEBUG` (link) for Release.
Both are needed: MSVC emits the linked PDB only when the linker gets `/DEBUG`,
and `/Zi` alone leaves compiler-side PDBs the release pipeline's symbol upload
never finds. This is debug info only -- it changes no generated code.

Without it, a crash whose real site is inside this plugin resolves in Sentry to
the nearest exported symbol with no line and no non-exported frames, which is
how several rounds of HALO-290 came to attribute this plugin's frames to
MSVCP140's `mtx_do_lock`.

`app/windows/CMakeLists.txt` now applies the same two flags across the whole
generated plugin list, so these lines are redundant for the app build. They are
kept because they belong to the package: a re-vendor should not silently lose
them, and nothing guarantees the app-level loop outlives this directory.

Note that as of build 166 the pipeline's symbol upload is **broken** (it fails
with `error: Invalid checksum` and the failure is swallowed into a warning), so
no plugin PDB has actually reached Sentry yet. That is tracked separately; it
does not make these flags wrong.

## Re-vendoring

Copy the new package over this directory (keep dropping `example/` and
`test/`), then re-apply, in this order:

1. **The teardown gate** in `ui_thread_handler.hpp` -- `accepting_`, the
   `Shutdown()` method, and the `accepting_` checks inside `Post()` and the
   queue drain. **Check upstream first:** this half is theirs (`05e7e73`), so a
   new enough copy may already have it, in which case take theirs.
2. **The atomic `hwnd_`** in the same file. **Upstream does NOT have this.**
   Their copy declares a plain `HWND hwnd_ = 0`, which races between the UI
   thread and every `Post()` caller. Taking their file wholesale drops this fix
   while looking like an upgrade -- this is the hunk to watch for.
3. **`ui_thread_handler_.Shutdown()`** as the FIRST statement of
   `~UniversalBlePlugin` in `universal_ble_plugin.cpp`. Ordering is the whole
   point; placed after `ClearServices()` it closes nothing.
4. **The two Release-PDB lines** in `windows/CMakeLists.txt`.

Deliberately NOT applied, and tracked above: upstream's try/catch around
`InitializeAsync`. If a re-vendor brings a copy that has it, **keep theirs** --
it closes a real `std::terminate` path.

`app/test/platform/ble_plugin_overrides_test.dart` asserts each of those is present --
nothing in `./scripts/test.sh` compiles C++ or configures CMake, so those
assertions are the only part of this patch a Dart test can see.
