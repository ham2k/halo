// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pins the SET of files — across the app and the widget package — that reach
// an entry point of `flutter_inappwebview` needing a registered platform
// implementation.
//
// On Linux the endorsed implementation is a stub that registers nothing
// (packages/flutter_inappwebview_linux_stub), so `InAppWebViewPlatform.instance`
// stays unset and every one of those entry points fails on it alike: the
// widget, the headless view, either browser, and the WebView2 environment.
// Each site is therefore paired with a guard that keeps Linux from reaching
// it, and the guard need not live in the file it protects — a new site added
// without one is a crash in whatever pane hosts it.
//
// Covered are the entry points that put a web view on screen or make the
// environment one runs in. The plugin's other platform-backed APIs — the
// cookie manager, web storage, the standalone controllers — resolve through
// the same null and carry the same hazard; none is used here, and the first
// use has to widen `_construction` along with the inventory below.
//
// Nothing else catches that. The Dart suite runs on one platform and never
// registers an implementation at all, `flutter analyze` sees a perfectly
// well-typed widget, and the AppImage that would fail is only built from a
// tag — so the earliest natural signal is a release. This test is the
// executable half of the inventory in
// packages/flutter_inappwebview_linux_stub/pubspec.yaml, which has to be read
// and updated whenever this set moves.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The five files allowed to reach one, as paths relative to `app/` — so a
/// file in the widget package reads as `../packages/halo_widgets/lib/…`.
const _expectedCallSites = {
  'lib/views/settings_view.dart', // the OAuth login page
  'lib/views/operation/panel_content_view.dart', // the HTML extension panel
  'lib/views/operation/website/website_panel.dart', // the Web Site pane
  'lib/views/map/mapbox_webview_map_view.dart', // the MapLibre map backend
  'lib/services/windows_webview.dart', // the shared WebView2 environment
};

/// A use, not a mention. The literal `(` is what does the work: it excludes
/// `InAppWebViewSettings(`, `InAppWebViewInitialData(`, `InAppWebViewController`
/// and `InAppWebViewPlatform` — and `WebViewEnvironmentSettings(` with them —
/// none of which need a registered platform implementation. `\b` excludes a
/// longer name ending in the same word. Every name is spelled out rather than
/// left to a prefix, because `Headless…` and the two browsers carry the same
/// Linux hazard as the widget and would otherwise slip past; the optional
/// `.name` admits the named constructors and statics, which is the only way
/// `WebViewEnvironment` is ever reached — it has no unnamed constructor.
final _construction = RegExp(
  r'\b(?:(?:Headless)?InAppWebView|InAppBrowser|ChromeSafariBrowser|WebViewEnvironment)(?:\.\w+)?\(',
);

/// Every `.dart` file under the app's and the widget package's `lib/`, with
/// forward-slashed paths so the expected set above reads the same on Windows.
List<File> _appSources() {
  final roots = [Directory('lib'), Directory('../packages/halo_widgets/lib')];
  // Loudly, not vacuously: a suite run from an unexpected cwd would otherwise
  // scan nothing, find nothing, and pass while enforcing nothing at all.
  for (final root in roots) {
    if (!root.existsSync()) {
      fail('expected ${root.path} to exist — run this suite from the app package (cwd: ${Directory.current.path})');
    }
  }
  return [
    for (final root in roots)
      ...root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
  ];
}

void main() {
  test('exactly five files reach a platform-backed flutter_inappwebview API', () {
    final found = <String>{};
    for (final file in _appSources()) {
      for (final line in file.readAsLinesSync()) {
        // Several files discuss the widget in prose, and the guards are
        // explained where they live, so only code counts.
        if (line.trimLeft().startsWith('//')) continue;
        if (_construction.hasMatch(line)) found.add(file.path.replaceAll(r'\', '/'));
      }
    }

    final added = found.difference(_expectedCallSites).toList()..sort();
    final removed = _expectedCallSites.difference(found).toList()..sort();

    expect(
      found,
      _expectedCallSites,
      reason:
          'The set of web view call sites changed (paths relative to app/).\n'
          '${added.isEmpty ? '' : 'Added:\n${added.map((p) => '  + $p').join('\n')}\n'}'
          '${removed.isEmpty ? '' : 'Removed:\n${removed.map((p) => '  - $p').join('\n')}\n'}'
          '\n'
          'A new call site needs a guard of its own keeping Linux out — there is\n'
          'no web view there, and building one throws. `WindowsWebView.isAvailable()`\n'
          'is NOT that guard: it returns true off Windows.\n'
          '\n'
          'Then update the inventory comment in\n'
          'packages/flutter_inappwebview_linux_stub/pubspec.yaml, which names each\n'
          'call site and the guard protecting it, and is what a future retirement\n'
          'of the Linux stub is revisited against. A removed site has to come out\n'
          'of that list too.',
    );
  });
}
