// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, kReleaseMode, visibleForTesting;

/// Reads a debug-only string flag: the compile-time `--dart-define` value
/// ([defineValue]) if set, otherwise — off web, and not under `flutter test`
/// — the `[name]` environment variable. Returns `''` in release builds and
/// when unset.
///
/// [String.fromEnvironment] needs a const literal, so callers read the
/// dart-define at the call site and pass it in:
/// `debugEnvFlag(const String.fromEnvironment('DEV_LABEL'), 'DEV_LABEL')`.
String debugEnvFlag(String defineValue, String name) {
  if (kReleaseMode) return '';
  if (defineValue.isNotEmpty) return defineValue;
  // A flag exported in the developer's shell for a manual `flutter run`
  // must not silently change behavior when that same shell later runs
  // `flutter test` — dart-define, which a test run doesn't inherit from the
  // shell, is unaffected by this guard.
  if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
    final env = Platform.environment[name];
    if (env != null && env.isNotEmpty) return env;
  }
  return '';
}

/// The directory a dev data sandbox keeps this launch's app data in —
/// database, data-file cache and preferences — instead of the one directory
/// every build of this edition otherwise shares.
///
/// NOT the whole environment: secure storage is keyed by bundle id and no
/// flag redirects it, so a sandboxed launch still holds the real install's
/// sync device key. `seedSyncEnabledDefault` leaves sync off here for that
/// reason.
///
/// An absolute path, named explicitly by whoever starts the app; nothing is
/// derived from the checkout, because there is no layout every worktree
/// agrees on. Empty means the normal, shared location.
///
/// An environment variable and NOT a dart-define, unlike every other flag
/// here: the macOS single-instance guard is native code, which cannot read a
/// dart-define. Accepting one would sandbox the Dart side while leaving that
/// guard armed, so the second build would be killed at launch — the exact
/// failure this flag exists to prevent, reachable by spelling it the way all
/// its neighbours are spelled. Hence the empty `defineValue`.
///
/// Debug builds only, and `kDebugMode` rather than [debugEnvFlag]'s release
/// check, because that check still answers in PROFILE mode while
/// AppDelegate's `#if DEBUG` does not. Disagreeing there would sandbox a
/// profile build's data and then terminate its second instance.
String get devDataDirectory => debugDataDirectoryOverride ?? (kDebugMode ? debugEnvFlag('', 'HALO_DEV_DATA') : '');

/// Stands in for the environment variable in tests, which cannot set one for
/// their own process — so without this the branches that depend on being
/// sandboxed have no way to be exercised at all.
@visibleForTesting
String? debugDataDirectoryOverride;
