// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Map tab draws with no network at all — only the tiles and the style
// need one. That holds only while MapLibre itself is read out of the app
// bundle, and nothing else in the suite can see it break: no test renders a
// webview, and a page that silently went back to fetching the library from a
// CDN looks identical until an operator opens the map somewhere with no
// signal. Which is where they open it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/views/map/map_gl_script.dart';
import 'package:ham2k_logger/views/map/mapbox_webview_map_view.dart';

/// Every Dart file that builds a map page, read as source. The CDN check has
/// to be a source scan: a URL that is never fetched in a test still ships.
Iterable<File> _mapSources() =>
    Directory('lib/views/map').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'));

void main() {
  test('the page inlines the library instead of fetching it', () {
    final page = MapboxWebviewMapView.pageHtml(
      false, mapDefaultStyleUrl, mapDefaultStyleUrlDark, false,
      suppressWindowBlur: false,
      glSource: 'GL_SOURCE_SENTINEL',
      glCss: 'GL_CSS_SENTINEL',
    );
    expect(page, contains('GL_SOURCE_SENTINEL'));
    expect(page, contains('GL_CSS_SENTINEL'));
    // A `src`/`href` for the library is the regression: it turns a bundled
    // asset back into a network fetch on the map's critical path.
    expect(
      page,
      isNot(contains('<script src=')),
      reason: 'the library must be inlined, not fetched',
    );
    expect(page, isNot(contains('<link ')));
  });

  test('no map source fetches the library from a CDN', () {
    for (final file in _mapSources()) {
      // Comments are stripped, not scanned: map_gl_script.dart names the
      // upstream URL on purpose, as the re-vendor instruction. A mention is
      // documentation; a URL in code is a network fetch on the map's
      // critical path, and only the second is the regression.
      final code = file
          .readAsLinesSync()
          .where((line) {
            final trimmed = line.trimLeft();
            return !trimmed.startsWith('//') && !trimmed.startsWith('*');
          })
          .join('\n');
      expect(
        code,
        isNot(contains('unpkg.com')),
        reason: '${file.path} fetches from unpkg; MapLibre is vendored under '
            'assets/maplibre/ precisely so the map does not need the network',
      );
    }
  });

  test('the vendored library is on disk, with its licence', () {
    // Declared in pubspec.yaml under `assets/maplibre/`. Asset directories are
    // not recursive and a rename would leave the loader throwing at runtime on
    // a path nothing else checks.
    for (final name in ['maplibre-gl.js', 'maplibre-gl.css', 'LICENSE.txt']) {
      expect(
        File('assets/maplibre/$name').existsSync(),
        isTrue,
        reason: 'assets/maplibre/$name is missing; the map cannot draw without '
            'it, and LICENSE.txt is required because MapLibre is BSD-3-Clause '
            'and this ships a copy',
      );
    }
  });

  test('the preload resolves the bundled asset paths', () async {
    // Guards the pubspec declaration, not just the files: an asset present on
    // disk but undeclared fails only at runtime, on the one screen that needs
    // it. rootBundle in a test reads through the same manifest the app does.
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(mapGlScriptAsset, 'assets/maplibre/maplibre-gl.js');
    expect(mapGlCssAsset, 'assets/maplibre/maplibre-gl.css');
    await preloadMapGlLibrary();
    expect(mapGlLibrarySource, contains('maplibre'));
    expect(mapGlLibraryCss, contains('maplibregl'));
  });

  test('the page build reads the library synchronously', () {
    // The whole point of the preload. An async read here makes the map pane
    // unbuildable under testWidgets, where fakeAsync never advances real file
    // I/O: the web view waits forever for a library sitting on disk, and every
    // widget test of the Map tab stops seeing a map at all.
    setMapGlLibraryForTests(source: 'SYNC_SOURCE', css: 'SYNC_CSS');
    expect(mapGlLibrarySource, 'SYNC_SOURCE');
    expect(mapGlLibraryCss, 'SYNC_CSS');
  });

  test('the pinned version matches what is vendored', () {
    // The constant is what a re-vendor is checked against; if it drifts from
    // the file, the next upgrade diffs against the wrong baseline.
    final source = File('assets/maplibre/maplibre-gl.js').readAsStringSync();
    expect(
      source.substring(0, 4000),
      contains(mapGlVersion),
      reason: 'mapGlVersion ($mapGlVersion) does not appear in the vendored '
          "library's header — one of the two was updated without the other",
    );
  });
}
