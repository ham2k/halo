// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Native BundleStorage: one directory per extension key under the app data
// directory, one file per bundle entry.

import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:path/path.dart' as p;

import '../app_storage.dart';
import 'bundle_storage.dart';
import 'installed_extensions.dart';

/// Directory under the app's data directory holding installed extensions, one
/// subdirectory per key.
const kInstalledExtensionsDirName = 'extensions';

BundleStorage createBundleStorage() => FileBundleStorage();

class FileBundleStorage implements BundleStorage {
  /// [root] is for tests — the real one resolves through
  /// `appDataDirectory()`, which reaches a plugin.
  FileBundleStorage({Directory? root}) : _rootOverride = root;

  final Directory? _rootOverride;

  Future<Directory> _root() async {
    final root = _rootOverride ?? Directory(p.join((await appDataDirectory()).path, kInstalledExtensionsDirName));
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  @override
  Future<Map<String, String?>> manifests() async {
    final root = await _root();
    final found = <String, String?>{};
    await for (final entry in root.list()) {
      if (entry is! Directory) continue;
      final manifest = File(p.join(entry.path, kManifestEntry));
      try {
        found[p.basename(entry.path)] = await manifest.exists() ? await manifest.readAsString() : null;
      } catch (e) {
        // One unreadable manifest must not cost the operator the rest: it
        // reads as absent, and the listing skips that one and says why.
        debugPrint('[extensions] could not read ${manifest.path}: $e');
        found[p.basename(entry.path)] = null;
      }
    }
    return found;
  }

  @override
  Future<String?> readText(String key, String name) async {
    final file = File(p.join((await _root()).path, key, name));
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String key, Map<String, List<int>> files) async {
    final dir = Directory(p.join((await _root()).path, key));
    // Replaced whole rather than merged: a file the new version dropped must
    // not linger and keep being served.
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    for (final MapEntry(key: name, value: bytes) in files.entries) {
      final target = InstalledExtensions.safeJoin(dir.path, name);
      // Belt and braces — the archive checks already refused the bundle over
      // an escaping name, so reaching this is a bug rather than an attack.
      if (target == null) continue;
      final out = File(target);
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes);
    }
  }

  @override
  Future<void> remove(String key) async {
    final dir = Directory(p.join((await _root()).path, key));
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
