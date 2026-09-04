// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// MapLibre GL JS map backend in a webview, bridged to Dart for marker/line
// data in and load/error status out via
// `window.flutter_inappwebview.callHandler`. Runs on every webview-capable
// platform — macOS, Windows (Linux has no web view to run it in — see
// docs/quirks.md), and iOS/Android, where it replaces a native map SDK
// because MapLibre Native (unlike MapLibre GL JS) has no globe projection.
//
// Windows also needs the app's own WebView2 environment (WindowsWebView);
// building this view without one, on a machine that can't create it, leaves
// a permanently blank pane instead of routing to the OSM backend.
//
// QSOs are band-colored circles, the QTH a black one, connected by
// great-circle lines — all GL layers over two GeoJSON sources (the lines
// pre-densified by the facade), so that the current QSO's line can paint over
// the other stations' circles.
// Clicking a circle opens a maplibregl.Popup with the QSO's details, styled
// to match the Flutter backends' MapPopupCard.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../services/error_reporting_service.dart';
import '../../services/windows_webview.dart';
import '../../services/map_error_reporter.dart';
import 'map_gl_script.dart';
import 'map_unavailable_state.dart';
import 'map_marker_data.dart';
import 'map_zoom_controller.dart';

class MapboxWebviewMapView extends StatefulWidget {
  final List<MapMarkerData> markers;
  final List<MapLineData> lines;

  /// Reference footprints — a SOTA activation zone and the like — filled
  /// under everything else. See map_marker_data.dart's MapShapeData.
  final List<MapShapeData> shapes;
  final MapProjection projection;
  final bool isDark;

  /// The light/dark style URLs to actually load — [mapDefaultStyleUrl] and
  /// [mapDefaultStyleUrlDark] by default, or both pointing at the same pinned
  /// style when the operator picked one via [SettingsService.mapStyle].
  /// Threaded in from map_panel.dart, so this widget doesn't need to know
  /// about the map-style setting at all.
  final String styleUrl;
  final String styleUrlDark;

  final MapZoomController? zoomController;

  /// When set, a marker click reports here instead of opening the built-in
  /// HTML popup — see map_gl_script.dart's `notifyClicks`. Null for the QSO
  /// map, which keeps its own popup.
  final ValueChanged<String>? onMarkerTap;

  const MapboxWebviewMapView({
    super.key,
    required this.markers,
    this.lines = const [],
    this.shapes = const [],
    required this.projection,
    required this.isDark,
    required this.styleUrl,
    required this.styleUrlDark,
    this.zoomController,
    this.onMarkerTap,
  });

  @override
  State<MapboxWebviewMapView> createState() => _MapboxWebviewMapViewState();
}

class _MapboxWebviewMapViewState extends State<MapboxWebviewMapView> {
  InAppWebViewController? _controller;
  bool _mapReady = false;

  /// Drives [MapUnavailableState]. Set when the map gives up, cleared by the
  /// page reporting in — a map that recovers must not keep the empty state.
  bool _unavailable = false;

  /// Covers the window before the page's own error channel exists: if
  /// maplibre-gl.js never loads (offline at map open, DNS, a proxy) or WebGL
  /// init throws, the inline script dies before `create()` installs the
  /// watchdog, `poloMapReady` never fires, and without this timer the pane
  /// is blank with no evidence anywhere.
  Timer? _readyWatchdog;

  /// One 'poloMapEvent' call from the page: everything bar 'recovered' goes
  /// to ErrorPolicy through the reporter, and the kinds that leave the pane
  /// blank also raise the empty state. What the operator is told is the
  /// CONDITION only ([MapUnavailableState]) — the kind naming the cause is
  /// evidence, and never reaches them. Only the empty state needs [mounted];
  /// the reporter is static, and an error draining during teardown is still
  /// evidence.
  void _onMapEvent(String kind, String message) {
    if (kind == 'marker-click') {
      widget.onMarkerTap?.call(message);
      return;
    }
    if (kind == 'recovered') {
      if (mounted && _unavailable) setState(() => _unavailable = false);
      return;
    }
    // Which kinds mean the operator has NO map, as opposed to a degraded
    // one: 'style-timeout' is the payload watchdog (markers waiting on a
    // style that never parsed), and a 'page-error' before ready is the page
    // dying before the map object exists — the same condition the web
    // backend catches synchronously as 'gl-load'. Without the second, that
    // failure is known within a second and shown only when the 15s
    // never-ready watchdog gets to it.
    //
    // Deliberately NOT here: 'style-swap-timeout' (the previous style is
    // still up with the data restored onto it — a working map), and a
    // 'page-error' after ready, which must not blank a map already drawn.
    final noMap = kind == 'style-timeout' || (kind == 'page-error' && !_mapReady);
    if (noMap && mounted && !_unavailable) setState(() => _unavailable = true);
    MapErrorReporter.report(backend: 'webview', kind: kind, message: message);
  }

  @override
  void initState() {
    super.initState();
    widget.zoomController
      ?..onZoomIn = _zoomIn
      ..onZoomOut = _zoomOut
      ..onMoveTo = _moveTo;
    _readyWatchdog = Timer(const Duration(seconds: 15), () {
      if (!mounted || _mapReady) return;
      setState(() => _unavailable = true);
      MapErrorReporter.report(
          backend: 'webview', kind: 'never-ready', message: 'the map page never reported ready');
    });
  }

  @override
  void dispose() {
      // Identity-guarded, never a blind null: when the facade swaps backends
      // (a webview probe answering, so OsmMapView gives way to the GL view),
      // Flutter runs the incoming State's initState during the build and this
      // dispose afterwards — so clearing unconditionally would wipe the
      // handlers the live backend has just installed and leave the camera
      // inert for the rest of the session.
    final controller = widget.zoomController;
    if (identical(controller?.onZoomIn, _zoomIn)) controller?.onZoomIn = null;
    if (identical(controller?.onZoomOut, _zoomOut)) controller?.onZoomOut = null;
    if (identical(controller?.onMoveTo, _moveTo)) controller?.onMoveTo = null;
    _readyWatchdog?.cancel();
    // The last thing this app's own code knows before the native platform
    // view underneath actually tears down (HALO-290) — a subsequent native
    // crash carries no Dart stack of its own to say so.
    ErrorReportingService.breadcrumb('map webview disposing', category: 'webview');
    super.dispose();
  }

  void _moveTo(double latitude, double longitude, double zoom) =>
      _controller?.evaluateJavascript(source: 'window.poloMoveTo($latitude, $longitude, $zoom);');

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
    if (!listEquals(oldWidget.shapes, widget.shapes)) _applyShapes();
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
      // The tone travels with the URLs — see the web backend's own note.
      source: "window.poloUpdateStyles('${widget.styleUrl}', '${widget.styleUrlDark}', ${widget.isDark});",
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

  Future<void> _applyShapes() async {
    final data = jsonEncode(mapShapesPayload(widget.shapes));
    await _controller?.evaluateJavascript(source: 'window.poloSetShapes($data);');
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
        data: _html(widget.isDark, widget.styleUrl, widget.styleUrlDark, widget.onMarkerTap != null),
        baseUrl: WebUri('https://ham2k.com/'),
      ),
      initialSettings: InAppWebViewSettings(transparentBackground: true),
      onConsoleMessage: (controller, message) => debugPrint('[map-webview] ${message.message}'),
      onWebViewCreated: (controller) {
        ErrorReportingService.breadcrumb('map webview created', category: 'webview');
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'poloMapReady',
          callback: (args) {
            _mapReady = true;
            _readyWatchdog?.cancel();
            // An empty state raised by the watchdog is stale the moment the
            // page reports in; the style watchdog re-raises it if the map is
            // ready but its style is stuck.
            if (mounted && _unavailable) setState(() => _unavailable = false);
            _applyProjection();
            // Dark mode is picked at creation (see _html/create's initialDark)
            // rather than applied here — for MapLibre, doing it again on
            // ready would swap the style a second time and race the marker
            // application right below it.
            _applyMarkers();
            _applyLines();
            _applyShapes();
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
        if (_unavailable) const Positioned.fill(child: MapUnavailableState()),
      ],
    );
  }

  // The marker/line/popup logic lives in the shared mapGlScript (also used
  // by the Flutter web backend); this page just hosts it and bridges the
  // window.polo* entry points the Dart side calls. The script's event
  // callback crosses on its own 'poloMapEvent' handler rather than riding
  // onConsoleMessage: a console line is a debug print, and these have to
  // reach ErrorPolicy.
  static String _html(bool isDark, String styleUrl, String styleUrlDark, bool notifyClicks) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no" />
  <script>
    // Installed before anything can fail: an uncaught page error (the GL
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
  <script src="$mapGlScriptUrl"
    onerror="__poloPageError('failed to load the maplibre script from $mapGlScriptUrl')"></script>
  <link href="$mapGlCssUrl" rel="stylesheet" />
  <style>
    body, html, #map { margin: 0; padding: 0; height: 100%; width: 100%; }
    .maplibregl-popup-content { padding: 6px 10px; border-radius: 8px; }
    #map { background: ${mapLibreSpaceBackgroundCss()}; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>$mapGlScript</script>
  <script>
    const handle = window.poloMapGl.create(
      document.getElementById('map'), '$styleUrl', '$styleUrlDark',
      $isDark,
      function (kind, message) {
        window.flutter_inappwebview.callHandler('poloMapEvent', kind, message);
      }, $notifyClicks);
    window.poloSetMarkers = handle.setMarkers;
    window.poloSetLines = handle.setLines;
    window.poloSetShapes = handle.setShapes;
    window.poloSetProjection = handle.setProjection;
    window.poloMoveTo = handle.moveTo;
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
