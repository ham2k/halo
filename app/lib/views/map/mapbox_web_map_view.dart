// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Conditional facade for the Flutter-web map backend: on the web the
// real implementation (MapLibre GL JS mounted on an HtmlElementView — see
// DESIGN.md §11, "a webview doesn't make sense on web, since the app itself
// is already running in a browser") is compiled in; everywhere else a
// never-instantiated stub keeps dart:ui_web / package:web out of native
// builds. map_panel.dart only constructs MapboxWebMapView behind a kIsWeb
// check.

export 'mapbox_web_map_view_stub.dart' if (dart.library.js_interop) 'mapbox_web_map_view_web.dart';
