// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The map page's Windows-only blur suppression is a string inside the page
// the widget hands the webview; nothing exercises it short of a Windows
// build, so a deleted line would bring back the erratic drag with nothing in
// the suite to point at it. See docs/quirks.md ("Windows: a map click blurs
// the page mid-press").

import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/views/map/map_gl_script.dart' show mapDefaultStyleUrl, mapDefaultStyleUrlDark;
import 'package:ham2k_logger/views/map/mapbox_webview_map_view.dart';

const _blurListener = "window.addEventListener('blur'";

String _page({required bool suppressWindowBlur}) => MapboxWebviewMapView.pageHtml(
      false, mapDefaultStyleUrl, mapDefaultStyleUrlDark, false,
      suppressWindowBlur: suppressWindowBlur,
    );

void main() {
  test('on Windows the page swallows window blur before MapLibre sees it', () {
    final page = _page(suppressWindowBlur: true);
    expect(page, contains(_blurListener));
    // Registered ahead of the GL script, or MapLibre's own listener runs first
    // and the drag is already disarmed by the time ours stops the event.
    expect(page.indexOf(_blurListener), lessThan(page.indexOf('maplibre-gl')));
  });

  test("elsewhere the page keeps MapLibre's blur-ends-the-drag behaviour", () {
    expect(_page(suppressWindowBlur: false), isNot(contains(_blurListener)));
  });
}
