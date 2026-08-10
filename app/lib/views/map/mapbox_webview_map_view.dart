// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Browser-engine map backend in a webview, bridged to Dart for marker/line
// data in and load/error status out via
// `window.flutter_inappwebview.callHandler`. Two roles:
//   - Mapbox GL JS on desktop (macOS and Windows; Linux has no web view to
//     run it in — see docs/quirks.md), where no official Mapbox Flutter SDK
//     exists and GL JS is the only globe projection.
//   - MapLibre GL JS on every webview-capable platform including iOS and
//     Android, under the MAPLIBRE experiment — MapLibre Native has no globe
//     projection, so on mobile the experiment trades the native Mapbox SDK
//     for a webview rather than for MapLibre's own SDK.
//
// On Windows the webview is WebView2, whose NavigateToString ignores
// InAppWebViewInitialData.baseUrl — the page runs from an about:blank-like
// origin and map tile requests carry no Referer. Keep the Mapbox token free
// of URL restrictions (or issue a separate restricted one for web) or the
// Windows map breaks while every other platform keeps working.
//
// Windows also needs the app's own WebView2 environment (WindowsWebView);
// building this view without one, on a machine that can't create it, leaves
// a permanently blank pane instead of routing to the OSM backend.
//
// QSOs are band-colored circles, the QTH a black one, connected by
// great-circle lines — all GL layers over two GeoJSON sources (the lines
// pre-densified by the facade), so that the current QSO's line can paint over
// the other stations' circles.
// Clicking a circle opens a mapboxgl.Popup with the QSO's details, styled
// to match the Flutter backends' MapPopupCard.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../config/secrets.dart';
import '../../services/windows_webview.dart';
import '../../services/map_error_reporter.dart';
import 'map_gl_script.dart';
import 'map_load_notice.dart';
import 'map_marker_data.dart';
import 'map_zoom_controller.dart';

class MapboxWebviewMapView extends StatefulWidget {
  final List<MapMarkerData> markers;
  final List<MapLineData> lines;
  final MapProjection projection;
  final MapGlEngine engine;
  final bool isDark;

  /// The light/dark style URLs to actually load — [MapGlEngine.styleUrl] and
  /// [.styleUrlDark] by default, or both pointing at the same pinned style
  /// when the operator picked one via [SettingsService.mapStyle]. Threaded in
  /// from map_panel.dart rather than read off `engine` here, so this widget
  /// doesn't need to know about the map-style setting at all.
  final String styleUrl;
  final String styleUrlDark;

  final MapZoomController? zoomController;

  const MapboxWebviewMapView({
    super.key,
    required this.markers,
    this.lines = const [],
    required this.projection,
    required this.engine,
    required this.isDark,
    required this.styleUrl,
    required this.styleUrlDark,
    this.zoomController,
  });

  @override
  State<MapboxWebviewMapView> createState() => _MapboxWebviewMapViewState();
}

class _MapboxWebviewMapViewState extends State<MapboxWebviewMapView> {
  InAppWebViewController? _controller;
  bool _mapReady = false;
  bool _loadFailed = false;

  /// Covers the window before the page's own error channel exists: if
  /// mapbox-gl.js never loads (offline at map open, DNS, a proxy) or WebGL
  /// init throws, the inline script dies before `create()` installs the
  /// watchdog, `poloMapReady` never fires, and without this timer the pane
  /// is blank with no evidence anywhere.
  Timer? _readyWatchdog;

  /// One 'poloMapEvent' call from the page: 'style-timeout' and 'recovered'
  /// drive the in-panel notice, everything (bar 'recovered') goes to
  /// ErrorPolicy through the reporter. Only the banner needs [mounted] —
  /// the reporter is static, and an error draining during teardown is
  /// still evidence.
  void _onMapEvent(String kind, String message) {
    if (kind == 'recovered') {
      if (mounted && _loadFailed) setState(() => _loadFailed = false);
      return;
    }
    if (kind == 'style-timeout' && mounted && !_loadFailed) setState(() => _loadFailed = true);
    MapErrorReporter.report(backend: 'webview', kind: kind, message: message);
  }

  @override
  void initState() {
    super.initState();
    widget.zoomController
      ?..onZoomIn = _zoomIn
      ..onZoomOut = _zoomOut;
    _readyWatchdog = Timer(const Duration(seconds: 15), () {
      if (!mounted || _mapReady) return;
      setState(() => _loadFailed = true);
      MapErrorReporter.report(
          backend: 'webview', kind: 'never-ready', message: 'the map page never reported ready');
    });
  }

  @override
  void dispose() {
    widget.zoomController
      ?..onZoomIn = null
      ..onZoomOut = null;
    _readyWatchdog?.cancel();
    super.dispose();
  }

  void _zoomIn() => _controller?.evaluateJavascript(source: 'window.poloZoomIn();');
  void _zoomOut() => _controller?.evaluateJavascript(source: 'window.poloZoomOut();');

  @override
  void didUpdateWidget(MapboxWebviewMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;
    if (oldWidget.projection != widget.projection) _applyProjection();
    // A pinned-style change takes precedence over isDark: applying both
    // would swap the style twice for one operator action.
    if (oldWidget.styleUrl != widget.styleUrl || oldWidget.styleUrlDark != widget.styleUrlDark) {
      _applyStyleUrls();
    } else if (oldWidget.isDark != widget.isDark) {
      _applyDark();
    }
    if (!listEquals(oldWidget.markers, widget.markers)) _applyMarkers();
    if (!listEquals(oldWidget.lines, widget.lines)) _applyLines();
  }

  Future<void> _applyProjection() async {
    await _controller?.evaluateJavascript(
      source: "window.poloSetProjection('${widget.projection.name}');",
    );
  }

  Future<void> _applyDark() async {
    await _controller?.evaluateJavascript(source: 'window.poloSetDark(${widget.isDark});');
  }

  Future<void> _applyStyleUrls() async {
    await _controller?.evaluateJavascript(
      source: "window.poloUpdateStyles('${widget.styleUrl}', '${widget.styleUrlDark}');",
    );
  }

  Future<void> _applyMarkers() async {
    final data = jsonEncode(mapMarkersPayload(widget.markers));
    await _controller?.evaluateJavascript(source: 'window.poloSetMarkers($data);');
  }

  Future<void> _applyLines() async {
    final data = jsonEncode(mapLinesPayload(widget.lines));
    await _controller?.evaluateJavascript(source: 'window.poloSetLines($data);');
  }

  @override
  Widget build(BuildContext context) {
    final webview = InAppWebView(
      // Null off Windows, where the platform's own webview needs no
      // environment; on Windows this is the one map_panel proved it could
      // create, so the plugin doesn't fall back to making its own next to
      // the exe (see WindowsWebView).
      webViewEnvironment: WindowsWebView.environment,
      initialData: InAppWebViewInitialData(
        data: _html(widget.engine, secrets['MAPBOX_ACCESS_TOKEN'] ?? '', widget.isDark, widget.styleUrl, widget.styleUrlDark),
        baseUrl: WebUri('https://ham2k.com/'),
      ),
      initialSettings: InAppWebViewSettings(transparentBackground: true),
      onConsoleMessage: (controller, message) => debugPrint('[map-webview] ${message.message}'),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'poloMapReady',
          callback: (args) {
            _mapReady = true;
            _readyWatchdog?.cancel();
            // A never-ready banner shown by the watchdog is stale the
            // moment the page reports in; the style watchdog re-raises it
            // if the map is ready but its style is stuck.
            if (mounted && _loadFailed) setState(() => _loadFailed = false);
            _applyProjection();
            // Dark mode is picked at creation (see _html/create's initialDark)
            // rather than applied here — for MapLibre, doing it again on
            // ready would swap the style a second time and race the marker
            // application right below it.
            _applyMarkers();
            _applyLines();
            return null;
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'poloMapEvent',
          callback: (args) {
            if (args.length >= 2) {
              _onMapEvent('${args[0]}', '${args[1]}');
            } else {
              debugPrint('[map-webview] malformed poloMapEvent: $args');
            }
            return null;
          },
        );
      },
    );
    return Stack(
      children: [
        Positioned.fill(child: webview),
        if (_loadFailed) const MapLoadNotice(),
      ],
    );
  }

  // The marker/line/popup logic lives in the shared mapGlScript (also used
  // by the Flutter web backend); this page just hosts it and bridges the
  // window.polo* entry points the Dart side calls. The script's event
  // callback crosses on its own 'poloMapEvent' handler rather than riding
  // onConsoleMessage: a console line is a debug print, and these have to
  // reach ErrorPolicy.
  static String _html(MapGlEngine engine, String token, bool isDark, String styleUrl, String styleUrlDark) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no" />
  <script>
    // Installed before anything can fail: an uncaught page error (the engine
    // script missing so create() throws ReferenceError, WebGL init failing)
    // happens before the map's own error channel exists, and onConsoleMessage
    // never sees uncaught exceptions. Buffered until the bridge is ready —
    // these errors tend to fire exactly in the window where it isn't yet.
    window.__poloPendingErrors = [];
    function __poloPageError(text) {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('poloMapEvent', 'page-error', text);
      } else {
        window.__poloPendingErrors.push(text);
      }
    }
    window.onerror = function (message, source, line) {
      __poloPageError(message + ' (' + source + ':' + line + ')');
      return false;
    };
    window.addEventListener('flutter_inappwebviewready', function () {
      var pending = window.__poloPendingErrors;
      window.__poloPendingErrors = [];
      pending.forEach(__poloPageError);
    });
  </script>
  <script src="${engine.scriptUrl}"
    onerror="__poloPageError('failed to load the ${engine.name} script from ${engine.scriptUrl}')"></script>
  <link href="${engine.cssUrl}" rel="stylesheet" />
  <style>
    body, html, #map { margin: 0; padding: 0; height: 100%; width: 100%; }
    .mapboxgl-popup-content, .maplibregl-popup-content { padding: 6px 10px; border-radius: 8px; }
    ${engine == MapGlEngine.maplibre ? '#map { background: ${mapLibreSpaceBackgroundCss()}; }' : ''}
  </style>
</head>
<body>
  <div id="map"></div>
  <script>$mapGlScript</script>
  <script>
    const handle = window.poloMapGl.create(
      document.getElementById('map'), '${engine.name}', '$token', '$styleUrl', '$styleUrlDark',
      $isDark,
      function (kind, message) {
        window.flutter_inappwebview.callHandler('poloMapEvent', kind, message);
      });
    window.poloSetMarkers = handle.setMarkers;
    window.poloSetLines = handle.setLines;
    window.poloSetProjection = handle.setProjection;
    window.poloZoomIn = handle.zoomIn;
    window.poloZoomOut = handle.zoomOut;
    window.poloSetDark = handle.setDark;
    window.poloUpdateStyles = handle.updateStyles;
    handle.onLoad(function () {
      window.flutter_inappwebview.callHandler('poloMapReady');
    });
  </script>
</body>
</html>
''';
}
