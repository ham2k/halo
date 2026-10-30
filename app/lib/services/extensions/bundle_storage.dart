// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where installed extensions' files are kept: the persistence under
// InstalledExtensions, and the only part of it that differs by platform —
// files in the app data directory natively, IndexedDB on web. Everything that
// decides WHAT gets stored (the zip walk, the manifest rules, the key checks)
// stays in InstalledExtensions and runs the same everywhere.
// See docs/design/extension-install.md, "Where installed bundles live".

export 'bundle_storage_io.dart' if (dart.library.js_interop) 'bundle_storage_web.dart' show createBundleStorage;

/// One extension per key, each a set of named files replaced whole.
///
/// Keys reach here already checked against `kSafeKeyPattern`, and file names
/// against the archive rules, so a backend stores what it is given.
abstract class BundleStorage {
  /// Every stored key, with its `manifest.json` as text — null where the key
  /// has files but no manifest that reads. What a listing reads, in one pass,
  /// and one bad manifest costs only its own key.
  Future<Map<String, String?>> manifests();

  /// The file [name] under [key] as UTF-8 text, or null when it is not there.
  Future<String?> readText(String key, String name);

  /// Replaces everything under [key] with [files].
  Future<void> write(String key, Map<String, List<int>> files);

  /// Removes everything under [key]. Nothing there is not an error.
  Future<void> remove(String key);
}
