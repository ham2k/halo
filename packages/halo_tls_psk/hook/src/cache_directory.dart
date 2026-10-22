// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'package:hooks/hooks.dart';

/// Resolve the override without interpreting a Windows drive as a URI scheme.
/// Relative paths stay with hooks so their base is the consuming pubspec, not
/// this package's directory. Uri.directory also escapes spaces and Unicode.
Uri? cacheDirectoryOverride(HookInputUserDefines userDefines) {
  final path = userDefines['cache_dir'];
  if (path == null) return null;
  if (path is! String || path.isEmpty) {
    throw const FormatException('hooks.user_defines.halo_tls_psk.cache_dir must be a nonempty path');
  }
  if (RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(path) || path.startsWith(r'\\') || path.startsWith('//')) {
    return Uri.directory(path, windows: true);
  }
  return userDefines.path('cache_dir');
}
