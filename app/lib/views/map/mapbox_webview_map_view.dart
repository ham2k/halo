// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Mapbox backend for desktop (macOS and Windows; Linux waits on a stable
// flutter_inappwebview_linux — see docs/backlog.md). No official Mapbox
// Flutter SDK covers desktop, so this loads Mapbox GL JS (which does support
// globe projection) into a webview, bridged to Dart for marker/line data in
// and load/error status out via `window.flutter_inappwebview.callHandler`.
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

class MapboxWebviewMapView extends StatefulWidget {
  final List<MapMarkerData> markers;
  final List<MapLineData> lines;
  final MapProjection projection;

  const MapboxWebviewMapView({
    super.key,
    required this.markers,
    this.lines = const [],
    required this.projection,
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
    _readyWatchdog = Timer(const Duration(seconds: 15), () {
      if (!mounted || _mapReady) return;
      setState(() => _loadFailed = true);
      MapErrorReporter.report(
          backend: 'webview', kind: 'never-ready', message: 'the map page never reported ready');
    });
  }

  @override
  void dispose() {
    _readyWatchdog?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MapboxWebviewMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;
    if (oldWidget.projection != widget.projection) _applyProjection();
    if (!listEquals(oldWidget.markers, widget.markers)) _applyMarkers();
    if (!listEquals(oldWidget.lines, widget.lines)) _applyLines();
  }

  Future<void> _applyProjection() async {
    await _controller?.evaluateJavascript(
      source: "window.poloSetProjection('${widget.projection.name}');",
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
        data: _html(secrets['MAPBOX_ACCESS_TOKEN'] ?? ''),
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
  static String _html(String token) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no" />
  <script>
    // Installed before anything can fail: an uncaught page error (mapbox-gl.js
    // missing so create() throws ReferenceError, WebGL init failing) happens
    // before the map's own error channel exists, and onConsoleMessage never
    // sees uncaught exceptions. Buffered until the bridge is ready — these
    // errors tend to fire exactly in the window where it isn't yet.
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
  <script src="https://api.mapbox.com/mapbox-gl-js/v3.9.0/mapbox-gl.js"></script>
  <link href="https://api.mapbox.com/mapbox-gl-js/v3.9.0/mapbox-gl.css" rel="stylesheet" />
  <style>
    body, html, #map { margin: 0; padding: 0; height: 100%; width: 100%; }
    .mapboxgl-popup-content { padding: 6px 10px; border-radius: 8px; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>$mapGlScript</script>
  <script>
    const handle = window.poloMapGl.create(document.getElementById('map'), '$token', function (kind, message) {
      window.flutter_inappwebview.callHandler('poloMapEvent', kind, message);
    });
    window.poloSetMarkers = handle.setMarkers;
    window.poloSetLines = handle.setLines;
    window.poloSetProjection = handle.setProjection;
    handle.onLoad(function () {
      window.flutter_inappwebview.callHandler('poloMapReady');
    });
  </script>
</body>
</html>
''';
}
