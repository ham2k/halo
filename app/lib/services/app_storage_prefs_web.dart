// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

/// Web has no such thing as a preferences directory — its store is
/// `window.localStorage`. See app_storage_prefs.dart.
Future<void> redirectPreferencesDirectory(String directory) async {}

/// Nor a preferences file to write atomically — localStorage is the browser's
/// to keep consistent. See app_storage_prefs.dart.
Future<void> installAtomicPreferenceWrites() async {}

/// A dev data sandbox never applies on web: the store there is
/// `window.localStorage`, and the database is IndexedDB, so a browser tab
/// already has nothing to share with a desktop build. See
/// app_storage_prefs.dart.
Future<void> installSandboxPreferencesStore(String directory) async {}
