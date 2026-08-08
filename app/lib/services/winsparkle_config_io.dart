// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// WinSparkle settings the `auto_updater` plugin declares no method channel
// for, bound straight to the DLL it already bundles beside the exe
// (its CMakeLists links WinSparkle.lib and copies WinSparkle.dll into the
// build), so this needs no fork of the plugin and no second copy of the
// library.
//
// WHY EACH ONE IS HERE — none is optional:
//
//   win_sparkle_set_app_build_version
//     Without it WinSparkle compares the exe's whole FileVersion STRING
//     against the appcast's version. Its comparator classifies '-' and '+' as
//     string parts and compares them with a plain lexicographic compare, so
//     "26.8.1-alpha1+125" sorts ABOVE "26.8.1+130" ('-' is 0x2D, '+' is 0x2B)
//     and the older install judges itself newer, permanently. Handing it the
//     bare build number moves the comparison onto integers, exactly as macOS
//     compares CFBundleVersion, and no cosmetic change to a version NAME can
//     strand a fleet again. The appcast must then carry the build number in
//     `sparkle:version` and the display string in `sparkle:shortVersionString`
//     — app_dist/ci/build-windows.ps1 emits both.
//
//   win_sparkle_set_update_check_interval
//     The plugin DOES expose this one, but calls it after its setFeedURL —
//     which is where it runs win_sparkle_init(), and every function here is
//     documented "can only be called BEFORE the first call to
//     win_sparkle_init()". Setting it here puts it in the supported order.
//
// ORDERING IS A CONTRACT, NOT A PREFERENCE. All of these belong to
// winsparkle.h's Configuration group, which is before-init only, and the
// plugin calls win_sparkle_init() inside its setFeedURL handler. So this must
// run before the FIRST setFeedURL of the process — see
// AutoUpdateService._ensureConfigured, which is the one place that happens.

import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'error_reporting_service.dart';

typedef _SetAppBuildVersionNative = Void Function(Pointer<Utf16>);
typedef _SetAppBuildVersion = void Function(Pointer<Utf16>);
typedef _SetIntNative = Void Function(Int32);
typedef _SetInt = void Function(int);

/// Applies the WinSparkle settings above. Returns whether they were actually
/// applied — false off Windows (where there is no WinSparkle at all) and false
/// if the DLL or a symbol can't be resolved.
///
/// Never throws. A missing symbol leaves the updater on its previous
/// behaviour, which is degraded but working; it must not take down the boot
/// path that calls this.
bool configureWinSparkleBeforeInit({
  required String buildVersion,
  required int checkIntervalSeconds,
}) {
  if (!Platform.isWindows) return false;

  try {
    // Already loaded — the plugin links the import library, so the DLL comes
    // in with the exe. This resolves that same module rather than mapping a
    // second copy, which is what keeps this shim and the plugin talking to one
    // WinSparkle instance.
    final lib = DynamicLibrary.open('WinSparkle.dll');

    final setAppBuildVersion =
        lib.lookupFunction<_SetAppBuildVersionNative, _SetAppBuildVersion>('win_sparkle_set_app_build_version');
    final setCheckInterval =
        lib.lookupFunction<_SetIntNative, _SetInt>('win_sparkle_set_update_check_interval');

    final build = buildVersion.toNativeUtf16();
    try {
      setAppBuildVersion(build);
    } finally {
      // `malloc`, matching `toNativeUtf16`'s own allocator — `Allocator.free`
      // is only defined against pointers that allocator produced. The two
      // happen to share an implementation on Windows today, which is exactly
      // what would make a divergence show up as heap corruption rather than a
      // failure. The callee copies the string, so freeing here is safe.
      malloc.free(build);
    }

    setCheckInterval(checkIntervalSeconds);
    return true;
  } catch (e, st) {
    // Reached when the DLL is absent or a symbol name is wrong. Neither is
    // recoverable here, and the caller carries on — but this must NOT pass
    // quietly. The fallback state is the stranded one this whole shim exists
    // to escape: version comparison drops back to the FileVersion string, and
    // an affected install then never takes an update again. A release Windows
    // build is a GUI app with no console, so a debugPrint alone would leave
    // that with no signal anywhere at all.
    debugPrint('[auto-update] WinSparkle configuration unavailable: $e');
    ErrorReportingService.report(e, st, context: 'auto-update:winsparkle-config');
    return false;
  }
}
