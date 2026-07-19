// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// Reads a debug-only string flag: the compile-time `--dart-define` value
/// ([defineValue]) if set, otherwise — off web — the `[name]` environment
/// variable. Returns `''` in release builds and when unset.
///
/// [String.fromEnvironment] needs a const literal, so callers read the
/// dart-define at the call site and pass it in:
/// `debugEnvFlag(const String.fromEnvironment('DEV_LABEL'), 'DEV_LABEL')`.
String debugEnvFlag(String defineValue, String name) {
  if (kReleaseMode) return '';
  if (defineValue.isNotEmpty) return defineValue;
  if (!kIsWeb) {
    final env = Platform.environment[name];
    if (env != null && env.isNotEmpty) return env;
  }
  return '';
}
