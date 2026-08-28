#pragma once

// A runtime switch over this plugin's Windows boot path, for HALO-290.
//
// This plugin starts Bluetooth work from its own constructor, which runs
// inside `RegisterPlugins()` -- before the first frame, and with no way for
// Dart to opt out. `HAM2K_BLE_MODE` is the only way to vary that on a
// machine we cannot build for, so a single signed release can carry every
// arm of the A/B instead of needing one build per arm.
//
// Build 155 established that `off` launches and `noinit` crashes, so the
// fault is in REGISTRATION, not in the Bluetooth work. These arms bisect what
// is left, as a ladder from the known-good arm to the known-bad one -- each
// step adds exactly one thing, so whichever arm first fails names the culprit:
//
//   off          nothing at all runs.                        (155: launches)
//   registrar    + GetRegistrar<PluginRegistrarWindows>().
//   nochannels   + construct the plugin (delegate hooked) and AddPlugin,
//                  but none of the four channel SetUp calls.
//   nodelegate   + everything, EXCEPT registering the window proc delegate.
//   noinit       + everything except InitializeAsync().       (155: crashes)
//   (unset)      + InitializeAsync() too, i.e. upstream.      (155: crashes)
//
// `nodelegate` is off the ladder's spine on purpose: it is the one arm that
// subtracts rather than adds, and it is the direct test of the delegate
// registration that `mtx_do_lock` points at.
//
// The unset arm MUST stay byte-for-byte upstream's behaviour: it is the
// experiment's control, and a "harmless" fix folded into it would leave a
// result that says nothing. Delete this file, its two call sites and the
// override in app/pubspec.yaml once HALO-290 has its answer.
//
// See PATCH.md, "The HALO-290 boot A/B switch".

#include <windows.h>

// `_wcsicmp` is MSVC's own, declared in the C headers rather than by
// <windows.h> or by <cwchar>'s std:: surface -- include them explicitly rather
// than relying on a transitive include that a Windows SDK bump can drop.
#include <string.h>
#include <wchar.h>

namespace ham2k {

enum class BleMode {
  kNormal,
  kNoInit,
  kNoDelegate,
  kNoChannels,
  kRegistrarOnly,
  kOff,
};

// Announces the arm on the parent console AND the debugger.
//
// Deliberately NOT printf. The runner reopens the CRT's stdout onto CONOUT$
// inside `CreateAndAttachConsole()`, which it calls only when
// `AttachConsole(ATTACH_PARENT_PROCESS)` FAILS and a debugger is present
// (main.cpp). Launched from a normal `cmd`, AttachConsole succeeds, that
// branch never runs, and a printf from this GUI-subsystem binary goes
// nowhere -- silently, in exactly the scenario this line exists to serve.
// Opening CONOUT$ here works whenever a console is attached at all,
// regardless of what the CRT's streams happen to point at.
inline void AnnounceBleMode(const wchar_t *message) {
  ::OutputDebugStringW(message);
  const HANDLE console =
      ::CreateFileW(L"CONOUT$", GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
                    nullptr, OPEN_EXISTING, 0, nullptr);
  if (console == INVALID_HANDLE_VALUE) {
    return;  // No console attached (double-clicked): the debugger line stands.
  }
  DWORD written = 0;
  ::WriteConsoleW(console, message, static_cast<DWORD>(::wcslen(message)),
                  &written, nullptr);
  ::CloseHandle(console);
}

// Reads `HAM2K_BLE_MODE` once per process and announces the arm. The
// announcement is the whole point of reading it eagerly: the crash under
// investigation kills the process before Dart runs, so this line is the only
// evidence of which arm the operator actually got -- an env var set in the
// wrong shell is otherwise indistinguishable from an arm that did not help.
inline BleMode Ham2kBleMode() {
  static const BleMode mode = [] {
    wchar_t value[16] = {};
    const DWORD length =
        ::GetEnvironmentVariableW(L"HAM2K_BLE_MODE", value, ARRAYSIZE(value));
    // A length of 0 is "unset"; anything >= the buffer is a value far too
    // long to be one of ours, and is treated as unset rather than truncated
    // into an accidental match.
    if (length == 0 || length >= ARRAYSIZE(value)) {
      AnnounceBleMode(L"[ham2k] BLE mode: normal (HAM2K_BLE_MODE unset)\n");
      return BleMode::kNormal;
    }
    if (::_wcsicmp(value, L"off") == 0) {
      AnnounceBleMode(L"[ham2k] BLE mode: off - universal_ble is NOT registered\n");
      return BleMode::kOff;
    }
    if (::_wcsicmp(value, L"noinit") == 0) {
      AnnounceBleMode(
          L"[ham2k] BLE mode: noinit - universal_ble registered, "
          L"InitializeAsync skipped\n");
      return BleMode::kNoInit;
    }
    if (::_wcsicmp(value, L"nodelegate") == 0) {
      AnnounceBleMode(
          L"[ham2k] BLE mode: nodelegate - registered, but NO window proc "
          L"delegate\n");
      return BleMode::kNoDelegate;
    }
    if (::_wcsicmp(value, L"nochannels") == 0) {
      AnnounceBleMode(
          L"[ham2k] BLE mode: nochannels - plugin + delegate only, no "
          L"channels\n");
      return BleMode::kNoChannels;
    }
    if (::_wcsicmp(value, L"registrar") == 0) {
      AnnounceBleMode(
          L"[ham2k] BLE mode: registrar - GetRegistrar only, plugin never "
          L"constructed\n");
      return BleMode::kRegistrarOnly;
    }
    AnnounceBleMode(
        L"[ham2k] BLE mode: normal (HAM2K_BLE_MODE not recognised; "
        L"expected off/registrar/nochannels/nodelegate/noinit)\n");
    return BleMode::kNormal;
  }();
  return mode;
}

}  // namespace ham2k
