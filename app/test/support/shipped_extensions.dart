// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A real extension runtime carrying what an install actually runs: the core
// extensions the app builds in, and the catalog bundles it pre-loads — POTA,
// SOTA, the lookups — installed through the real pre-load into a store of the
// test's own.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/bundle_storage_io.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/extensions/installed_extensions.dart';

/// Pre-loads the shipped bundles into a temporary store for [extensions],
/// without starting its runtime — for a test that times or races the start.
/// [extensions] needs its `settings` set: the pre-load records what it
/// installed there, and carries a built-in's on/off choice (`sota: true`) onto
/// its twin.
Future<void> preloadShippedExtensionsForTest(ExtensionService extensions) async {
  final root = Directory.systemTemp.createTempSync('halo-shipped-extensions');
  addTearDown(() => root.deleteSync(recursive: true));
  final index = jsonDecode(File('assets/extensions/index.json').readAsStringSync()) as Map<String, dynamic>;
  extensions.debugInstalledStore = InstalledExtensions(
    builtInKeys: () => {for (final entry in (index['extensions'] as List).cast<Map<String, dynamic>>()) entry['key'] as String},
    hostSharedModules: ((index['sharedModules'] as Map?) ?? const {}).cast<String, String>(),
    storage: FileBundleStorage(root: root),
    // The provenance the pre-load writes is what waives the reserved prefix.
    reservedPrefixAllowed: (_) => true,
  );
  await extensions.loadAvailableExtensions(force: true);
  await extensions.preloadShippedExtensions();
  await extensions.reloadAvailableExtensions();
  // A bundle that failed to pre-load is only reported, and its absence would
  // let a test of something else pass without it.
  final shipped = (jsonDecode(File('assets/preloaded-extensions/index.json').readAsStringSync())['preloaded'] as List).map((entry) => (entry as Map)['key']);
  expect(
    {
      for (final info in extensions.availableExtensions)
        if (info.isInstalled) info.key,
    },
    containsAll(shipped),
    reason: 'every shipped bundle pre-loads',
  );
}

/// [preloadShippedExtensionsForTest], then starts the runtime.
Future<void> startWithShippedExtensions(ExtensionService extensions) async {
  await preloadShippedExtensionsForTest(extensions);
  await extensions.start();
}
