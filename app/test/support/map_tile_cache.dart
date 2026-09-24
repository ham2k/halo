// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Any file that mounts `OsmMapView` calls `useTempMapTileCache()` in its
// `main`. The first TileLayer in an isolate creates flutter_map's built-in
// tile cache, a per-isolate singleton that asks path_provider for a directory
// asynchronously. With no plugin behind that channel the lookup throws
// MissingPluginException, and whether it lands inside the test that mounted
// the map, in a later one, or after the last one depends on timing alone.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void useTempMapTileCache() {
  late Directory cacheDir;
  setUpAll(() {
    cacheDir = Directory.systemTemp.createTempSync('halo_map_tile_cache');
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => cacheDir.path,
    );
  });
  tearDownAll(() => cacheDir.deleteSync(recursive: true));
}
