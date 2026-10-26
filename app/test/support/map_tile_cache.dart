// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Any file that mounts `OsmMapView` calls `useTempMapTileCache()` in its
// `main`. The first TileLayer in an isolate creates flutter_map's built-in
// tile cache, a per-isolate singleton that asks path_provider for a directory
// asynchronously. With no plugin behind that channel the lookup throws
// MissingPluginException, and whether it lands inside the test that mounted
// the map, in a later one, or after the last one depends on timing alone.
//
// The singleton is made here, in setUpAll, rather than by the first map:
// its setup and its worker isolate's replies run in the zone that made it,
// and a testWidgets body's fake-async zone stops advancing when the test
// ends — a cache born there can never be shut down afterwards.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void useTempMapTileCache() {
  late Directory cacheDir;
  setUpAll(() {
    cacheDir = Directory.systemTemp.createTempSync('halo_map_tile_cache');
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => cacheDir.path,
    );
    BuiltInMapCachingProvider.getOrCreateInstance(cacheDirectory: cacheDir.path);
  });
  tearDownAll(() async {
    // The worker writes into this directory on its own schedule, and the
    // setup creates a folder in it; deleting under either fails ("Directory
    // not empty", or the setup's create finding no parent). destroy() waits
    // for both to stop.
    await BuiltInMapCachingProvider.getOrCreateInstance().destroy();
    cacheDir.deleteSync(recursive: true);
  });
}
