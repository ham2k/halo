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
import 'package:http/http.dart' as http;
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;
import 'package:halo_i18n/halo_i18n.dart';

import '../../config/user_agent.dart';
import '../../services/connectivity_service.dart';
import '../../services/error_reporting_service.dart';
import '../../services/windows_webview.dart';
import '../../services/map_error_reporter.dart';
import 'map_gl_script.dart';
import 'map_ready_watchdog.dart';
import 'map_unavailable_state.dart';
import 'map_marker_data.dart';
import 'map_grayline.dart';
import 'map_overlays.dart';
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

  /// Where the camera came to rest — its centre, its zoom on the GL
  /// backends' scale (512-pixel tiles) whatever the backend, see
  /// [MapZoomController.glZoomOf], and the box it shows. Reported after every
  /// move.
  final ValueChanged<MapCameraSettled>? onCameraChanged;

  /// A tap that landed on no marker, at the map point it landed on — for a
  /// host that decides what else is there (the Activities map's outlines).
  /// Only reported alongside [onMarkerTap]: the QSO map keeps its own popup.
  final ValueChanged<GridLocation>? onMapTap;

  /// What this map fades in as it closes in — see [MapZoomFades].
  final MapZoomFades? zoomFades;

  /// Makes this a picture of the map rather than a map to explore — see
  /// [MapFrame]. Read once, when the page is built.
  final MapFrame? frame;

  /// What this map lays over its basemap — see [MapOverlays]. Null for a map
  /// that offers no layers, which then never sends any.
  final MapOverlays? overlays;

  /// Whether the credits sit in the bottom-left corner rather than the
  /// bottom-right, for a host whose own controls hold that one.
  final bool creditsLeft;

  /// The instant whose night side the map shades — see map_grayline.dart.
  /// Null for none. A new instant is a new payload, so a host hands it
  /// [graylineInstant]'s minute rather than the clock's every reading.
  final DateTime? graylineAt;

  /// Whether markers that would overlap close in are moved apart, each with
  /// a line back to a dot on its own point — see map_gl_script.dart's
  /// `setSpread`. For a map of places, never one of contacts, where a
  /// grid square's worth of stations on one point is the picture.
  final bool spreadOverlaps;

  /// The marker brought forward over the rest, and what steps back behind
  /// it — see [MapMarkerFocus].
  final MapMarkerFocus? focus;

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
    this.onCameraChanged,
    this.onMapTap,
    this.zoomFades,
    this.frame,
    this.overlays,
    this.creditsLeft = false,
    this.graylineAt,
    this.spreadOverlaps = false,
    this.focus,
  });

  @override
  State<MapboxWebviewMapView> createState() => _MapboxWebviewMapViewState();

  // The marker/line/popup logic lives in the shared mapGlScript (also used
  // by the Flutter web backend); this page just hosts it and bridges the
  // window.polo* entry points the Dart side calls. The script's event
  // callback crosses on its own 'poloMapEvent' handler rather than riding
  // onConsoleMessage: a console line is a debug print, and these have to
  // reach ErrorPolicy.
  //
  // `suppressWindowBlur` is for Windows. There the composition-hosted
  // WebView2 takes keyboard focus on every mousedown the plugin forwards,
  // and the runner takes it straight back (its WM_ACTIVATE handler refocuses
  // the Flutter view — the webview's window lives under a hidden owned
  // top-level, so Chromium focusing itself deactivates the main window). The
  // page sees a window `blur` in the middle of every press, and MapLibre's
  // handler manager treats a blur as "stop every gesture", which disarms the
  // drag that press just started; whether the blur lands before or after
  // the mousedown is a race, so drags fail on and off. The blur is swallowed
  // before MapLibre's own listener runs (ours registers first, so it runs
  // first) — and with it every later `blur` listener on `window`, so none
  // may be added to this page and expected to fire on Windows. Not done
  // elsewhere: the blur-cancels-drag behaviour is what ends a drag cleanly
  // when the window really does lose focus mid-gesture. On Windows that
  // case now rides on MapLibre's other guard instead — a mousemove whose
  // `buttons` no longer carries the pressed button resets the drag — so a
  // drag interrupted by a real focus loss ends on the next move rather than
  // following the cursor.
  @visibleForTesting
  static String pageHtml(
    bool isDark,
    String styleUrl,
    String styleUrlDark,
    bool notifyClicks, {
    required bool suppressWindowBlur,
    required String glSource,
    required String glCss,
    MapFrame? frame,
  }) =>
      '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no" />
  <script>
    ${suppressWindowBlur ? "window.addEventListener('blur', function (e) { e.stopImmediatePropagation(); }, true);" : ''}
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
  <script>$glSource</script>
  <style>$glCss</style>
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
      }, $notifyClicks, ${frame == null ? 'null' : jsonEncode({...frame.camera.toJson(), 'width': frame.width, 'height': frame.height, 'background': mapLibreSpaceBackgroundCss()})});
    window.poloSetMarkers = handle.setMarkers;
    window.poloSetLines = handle.setLines;
    window.poloPatchMarkers = handle.patchMarkers;
    window.poloPatchLines = handle.patchLines;
    window.poloSetShapes = handle.setShapes;
    window.poloSetOverlays = handle.setOverlays;
    window.poloSetGrayline = handle.setGrayline;
    window.poloSetSpread = handle.setSpread;
    window.poloSetFocus = handle.setFocus;
    window.poloSetCreditLabels = handle.setCreditLabels;
    window.poloSetCreditsSide = handle.setCreditsSide;
    window.poloFetchText = function (url) {
      return window.flutter_inappwebview.callHandler('poloFetchText', url).then(function (answer) {
        if (answer && answer.missing) return null;
        if (!answer || answer.error) throw new Error((answer && answer.error) || 'no answer');
        return answer.body;
      });
    };
    window.poloSetZoomFades = handle.setZoomFades;
    window.poloSetProjection = handle.setProjection;
    window.poloMoveTo = handle.moveTo;
    window.poloFitTo = handle.fitTo;
    window.poloRefit = handle.refit;
    window.poloZoomIn = handle.zoomIn;
    window.poloZoomOut = handle.zoomOut;
    window.poloResetNorth = handle.resetNorth;
    window.poloCamera = handle.camera;
    window.poloSnapshot = handle.snapshot;
    window.poloSetDark = handle.setDark;
    window.poloUpdateStyles = handle.updateStyles;
    window.poloReload = handle.reload;
    window.poloCancelReload = handle.cancelReload;
    handle.onLoad(function () {
      window.flutter_inappwebview.callHandler('poloMapReady');
    });
  </script>
</body>
</html>
''';
}

class _MapboxWebviewMapViewState extends State<MapboxWebviewMapView> with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  bool _mapReady = false;

  /// [_mapReady], for a snapshot asked for before the page has made its map
  /// to wait on.
  final _ready = Completer<void>();

  /// The style the page was built with — see the ready handler.
  late final ({String url, String urlDark, bool isDark}) _pageStyle;

  /// Drives [MapUnavailableState]. Set when the map gives up, cleared by the
  /// page reporting in — a map that recovers must not keep the empty state.
  bool _unavailable = false;

  /// The two ready horizons and everything that decides between them — see
  /// [MapReadyWatchdog], which owns them so that the 'ready-late' arrival can
  /// be tested without a platform view.
  late final _readyWatchdog = MapReadyWatchdog(
    onUnavailable: () {
      if (mounted) setState(() => _unavailable = true);
    },
  );

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
    if (kind == 'map-click') {
      if ([for (final part in message.split(',')) double.tryParse(part)] case [final latitude?, final longitude?]) {
        widget.onMapTap?.call(GridLocation(latitude, longitude));
      } else {
        MapErrorReporter.report(backend: 'webview', kind: 'map-click-malformed', message: message);
      }
      return;
    }
    if (kind == 'orientation') {
      if ([for (final part in message.split(',')) double.tryParse(part)] case [final bearing?, final pitch?]) {
        // Not after teardown: the controller belongs to the backend that
        // replaced this one, and a turn still in flight would raise the
        // compass over its north-up map.
        if (mounted) widget.zoomController?.reportOrientation(MapOrientation(bearing: bearing, pitch: pitch));
      } else {
        MapErrorReporter.report(backend: 'webview', kind: 'orientation-malformed', message: message);
      }
      return;
    }
    if (kind == 'camera') {
      Object? decoded;
      try {
        decoded = jsonDecode(message);
      } on FormatException {
        decoded = null;
      }
      if ((MapCameraPosition.fromJson(decoded), decoded) case (
        final camera?,
        {'south': final num south, 'west': final num west, 'north': final num north, 'east': final num east},
      )) {
        final bounds = mapViewBounds(south: south.toDouble(), west: west.toDouble(), north: north.toDouble(), east: east.toDouble());
        widget.onCameraChanged?.call((camera: camera, bounds: bounds));
      } else {
        // The page and this side disagree about the report's shape — and the
        // zoom gates, the outlines and the exploring all hang on it.
        MapErrorReporter.report(backend: 'webview', kind: 'camera-malformed', message: message);
      }
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
    // failure is known within a second and shown only when the grace timer
    // gets to it.
    //
    // Deliberately NOT here: 'style-swap-timeout' (the previous style is
    // still up with the data restored onto it — a working map), and a
    // 'page-error' after ready, which must not blank a map already drawn.
    final noMap = kind == 'style-timeout' || (kind == 'page-error' && !_mapReady);
    if (noMap && mounted && !_unavailable) setState(() => _unavailable = true);
    MapErrorReporter.report(backend: 'webview', kind: kind, message: message);
  }

  /// The app's online and offline edges, for the page's reload — see
  /// map_gl_script.dart's `reload` and `cancelReload`. Sent before ready too:
  /// a map opened offline is exactly the one that never reports in until its
  /// style is fetched again.
  StreamSubscription<bool>? _offlineChanges;

  @override
  void initState() {
    super.initState();
    _pageStyle = (url: widget.styleUrl, urlDark: widget.styleUrlDark, isDark: widget.isDark);
    WidgetsBinding.instance.addObserver(this);
    _offlineChanges = ConnectivityService.offlineChanges.listen((offline) {
      // Guarded: the page may not have run its script yet, and the edge is
      // no reason to throw in it.
      final call = offline ? 'poloCancelReload' : 'poloReload';
      _controller?.evaluateJavascript(source: 'window.$call && window.$call();');
    });
    widget.zoomController
      ?..onZoomIn = _zoomIn
      ..onZoomOut = _zoomOut
      ..onMoveTo = _moveTo
      ..onFitTo = _fitTo
      ..onRefit = _refit
      ..onCamera = _camera
      ..onSnapshot = _snapshot
      ..onResetNorth = _resetNorth
      ..resetOrientation();
  }

  /// Both halves of "is this map being painted", ANDed the way every other
  /// visibility-gated pane in the app does it (website, spots, solar,
  /// weather, remote screen): a pane can stop being painted because its tab
  /// was deselected OR because the whole app went away, and MapLibre's `load`
  /// is equally impossible either way. Without the second half, a screen that
  /// locks while the style is still fetching reports a map that was never
  /// given a frame to draw in.
  bool _appVisible = true;
  bool _dockVisible = false;

  static bool _visibleIn(AppLifecycleState state) => state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = _visibleIn(state);
    if (visible == _appVisible) return;
    _appVisible = visible;
    _readyWatchdog.setVisible(_dockVisible && _appVisible);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Outside a dock this answers true on the first call and never changes,
    // so the horizons start on the same frame the pane is first built.
    _dockVisible = DockPaneVisibility.of(context);
    _readyWatchdog.setVisible(_dockVisible && _appVisible);
  }

  @override
  void dispose() {
    // Guarded, never a blind null: when the facade swaps backends
    // (a webview probe answering, so OsmMapView gives way to the GL view),
    // Flutter runs the incoming State's initState during the build and this
    // dispose afterwards — so clearing unconditionally would wipe the
    // handlers the live backend has just installed and leave the camera
    // inert for the rest of the session. By `==`, not `identical`: each
    // tear-off of a method is a new object, equal to the one installed but
    // never identical to it, and a handler left behind is called on a dead
    // map by the camera's timers.
    final controller = widget.zoomController;
    if (controller?.onZoomIn == _zoomIn) controller?.onZoomIn = null;
    if (controller?.onZoomOut == _zoomOut) controller?.onZoomOut = null;
    if (controller?.onMoveTo == _moveTo) controller?.onMoveTo = null;
    if (controller?.onFitTo == _fitTo) controller?.onFitTo = null;
    if (controller?.onRefit == _refit) controller?.onRefit = null;
    if (controller?.onCamera == _camera) controller?.onCamera = null;
    if (controller?.onSnapshot == _snapshot) controller?.onSnapshot = null;
    if (controller?.onResetNorth == _resetNorth) controller?.onResetNorth = null;
    WidgetsBinding.instance.removeObserver(this);
    _offlineChanges?.cancel();
    _readyWatchdog.dispose();
    // The last thing this app's own code knows before the native platform
    // view underneath actually tears down (HALO-290) — a subsequent native
    // crash carries no Dart stack of its own to say so.
    ErrorReportingService.breadcrumb('map webview disposing', category: 'webview');
    super.dispose();
  }

  void _moveTo(double latitude, double longitude, double zoom) => _controller?.evaluateJavascript(source: 'window.poloMoveTo($latitude, $longitude, $zoom);');
  // Not before the page reports in: until then `poloFitTo` may not exist yet,
  // and the ready handler frames the controller's lastFit itself.
  void _fitTo(List<GridLocation> points) {
    if (_mapReady) _controller?.evaluateJavascript(source: 'window.poloFitTo(${jsonEncode(mapFitPayload(points))});');
  }

  void _refit() {
    if (_mapReady) _controller?.evaluateJavascript(source: 'window.poloRefit();');
  }

  /// Null until the page has made its map — and then only if it answers.
  /// Null when the page never made its map, or never answered — a tap on a
  /// map still loading waits for it first rather than doing nothing.
  Future<MapCameraView?> _camera() async {
    await _ready.future.timeout(mapCameraWait, onTimeout: () {});
    if (!_mapReady) return null;
    return mapCameraViewFromJson(await _controller?.evaluateJavascript(source: 'window.poloCamera();'));
  }

  /// Waits for the page's map when it is still coming up: an operator can
  /// press Copy the moment a postcard opens.
  Future<Uint8List> _snapshot(double pixelRatio) async {
    await _ready.future.timeout(mapSnapshotTimeout, onTimeout: () => throw const MapSnapshotException('the map never came up'));
    final controller = _controller;
    if (controller == null) throw const MapSnapshotException('the map never came up');
    final result = await controller.callAsyncJavaScript(functionBody: 'return await window.poloSnapshot(pixelRatio);', arguments: {'pixelRatio': pixelRatio});
    final error = result?.error;
    if (error != null && isMapSnapshotOutcome(error)) throw MapSnapshotException(error);
    final value = result?.value;
    if (error != null || value is! String) throw StateError('map snapshot failed: ${error ?? 'no answer'}');
    return decodeDataUrl(value);
  }

  void _zoomIn() => _controller?.evaluateJavascript(source: 'window.poloZoomIn();');
  void _zoomOut() => _controller?.evaluateJavascript(source: 'window.poloZoomOut();');
  void _resetNorth() => _controller?.evaluateJavascript(source: 'window.poloResetNorth();');

  @override
  void didUpdateWidget(MapboxWebviewMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;
    if (oldWidget.projection != widget.projection) _applyProjection();
    if (oldWidget.creditsLeft != widget.creditsLeft) _applyCreditsSide();
    // A pinned-style change takes precedence over isDark: applying both
    // would swap the style twice for one operator action.
    if (oldWidget.styleUrl != widget.styleUrl || oldWidget.styleUrlDark != widget.styleUrlDark) {
      _applyStyleUrls();
    } else if (oldWidget.isDark != widget.isDark) {
      _applyDark();
    }
    // A patch carries what changed; the set carries everything. One logged
    // contact is one marker and one line either way, but as a set it is every
    // contact's, encoded here and parsed in the webview, per emission. The
    // same list instance — a pane that is hidden, a rebuild for a reason the
    // map does not read — is not even diffed.
    if (!identical(oldWidget.markers, widget.markers)) {
      final markers = diffMarkers(oldWidget.markers, widget.markers);
      if (patchIsSmaller(markers, total: widget.markers.length)) {
        _patchMarkers(markers);
      } else if (!listEquals(oldWidget.markers, widget.markers)) {
        _applyMarkers();
      }
    }
    if (!identical(oldWidget.lines, widget.lines)) {
      final lines = diffLines(oldWidget.lines, widget.lines);
      if (patchIsSmaller(lines, total: widget.lines.length)) {
        _patchLines(lines);
      } else if (!listEquals(oldWidget.lines, widget.lines)) {
        _applyLines();
      }
    }
    if (!listEquals(oldWidget.shapes, widget.shapes)) _applyShapes();
    if (oldWidget.zoomFades != widget.zoomFades) _applyZoomFades();
    if (oldWidget.overlays != widget.overlays || oldWidget.isDark != widget.isDark) _applyOverlays();
    if (oldWidget.graylineAt != widget.graylineAt || (widget.graylineAt != null && oldWidget.isDark != widget.isDark)) _applyGrayline();
    if (oldWidget.spreadOverlaps != widget.spreadOverlaps) _applySpread();
    if (oldWidget.focus != widget.focus) _applyFocus();
  }

  Future<void> _applyProjection() async {
    await _controller?.evaluateJavascript(source: "window.poloSetProjection('${widget.projection.name}');");
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

  Future<void> _patchMarkers(MapDiff<MapMarkerData> diff) async {
    final data = jsonEncode(mapMarkersPatchPayload(diff));
    await _controller?.evaluateJavascript(source: 'window.poloPatchMarkers($data);');
  }

  Future<void> _patchLines(MapDiff<MapLineData> diff) async {
    final data = jsonEncode(mapLinesPatchPayload(diff));
    await _controller?.evaluateJavascript(source: 'window.poloPatchLines($data);');
  }

  Future<void> _applyZoomFades() async {
    final data = jsonEncode(mapZoomFadesPayload(widget.zoomFades));
    await _controller?.evaluateJavascript(source: 'window.poloSetZoomFades($data);');
  }

  Future<void> _applyShapes() async {
    final data = jsonEncode(mapShapesPayload(widget.shapes, credit: mapOutlinesCredit(context.t, widget.shapes)));
    await _controller?.evaluateJavascript(source: 'window.poloSetShapes($data);');
  }

  Future<void> _applyFocus() async {
    final data = jsonEncode(mapMarkerFocusPayload(widget.focus));
    await _controller?.evaluateJavascript(source: 'window.poloSetFocus($data);');
  }

  Future<void> _applyCreditLabels() async {
    await _controller?.evaluateJavascript(source: 'window.poloSetCreditLabels(${jsonEncode(mapCreditLabels(context.t))});');
  }

  Future<void> _applyCreditsSide() async {
    await _controller?.evaluateJavascript(source: "window.poloSetCreditsSide('${widget.creditsLeft ? 'left' : 'right'}');");
  }

  Future<void> _applySpread() async {
    await _controller?.evaluateJavascript(source: 'window.poloSetSpread(${widget.spreadOverlaps});');
  }

  Future<void> _applyOverlays() async {
    final overlays = widget.overlays;
    if (overlays == null) return;
    final data = jsonEncode(mapOverlaysPayload(overlays, dark: widget.isDark, t: context.t));
    await _controller?.evaluateJavascript(source: 'window.poloSetOverlays($data);');
  }

  Future<void> _applyGrayline() async {
    final at = widget.graylineAt;
    final data = at == null ? 'null' : jsonEncode(mapGraylinePayload(at, dark: widget.isDark));
    await _controller?.evaluateJavascript(source: 'window.poloSetGrayline($data);');
  }

  /// A bundle the page's script asked for (see map_gl_script.dart's
  /// `fetchText`), as `{body}` or `{error}` — the script reports the error
  /// through its own channel, offline stamp and all.
  static Future<Map<String, String>> _fetchText(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': await ham2kUserAgent()}).timeout(const Duration(seconds: 30));
      // The script's fetchText answers a 4xx with null: no bundle for that cell.
      if (response.statusCode >= 400 && response.statusCode < 500) return {'missing': '${response.statusCode}'};
      if (response.statusCode != 200) return {'error': 'HTTP ${response.statusCode}'};
      return {'body': response.body};
    } catch (e) {
      return {'error': '$e'};
    }
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
        data: MapboxWebviewMapView.pageHtml(
          widget.isDark,
          widget.styleUrl,
          widget.styleUrlDark,
          widget.onMarkerTap != null,
          suppressWindowBlur: defaultTargetPlatform == TargetPlatform.windows,
          glSource: mapGlLibrarySource,
          glCss: mapGlLibraryCss,
          frame: widget.frame,
        ),
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
            if (!_ready.isCompleted) _ready.complete();
            _readyWatchdog.markReady();
            // An empty state raised by the grace horizon is stale the moment
            // the page reports in; the style watchdog re-raises it if the map
            // is ready but its style is stuck.
            if (mounted && _unavailable) setState(() => _unavailable = false);
            _applyProjection();
            // Dark mode and the style are picked at creation (see
            // _html/create's initialDark) rather than applied here — for
            // MapLibre, doing it again on ready would swap the style a second
            // time and race the marker application right below it. Unless
            // they changed while the page came up: didUpdateWidget sends a
            // page with no map nothing, so a pick made then would be lost.
            if (widget.styleUrl != _pageStyle.url || widget.styleUrlDark != _pageStyle.urlDark) {
              _applyStyleUrls();
            } else if (widget.isDark != _pageStyle.isDark) {
              _applyDark();
            }
            _applyZoomFades();
            _applySpread();
            _applyFocus();
            _applyCreditLabels();
            if (widget.creditsLeft) _applyCreditsSide();
            _applyMarkers();
            _applyLines();
            _applyShapes();
            _applyOverlays();
            if (widget.graylineAt != null) _applyGrayline();
            if (widget.zoomController?.lastFit case final points?) _fitTo(points);
            return null;
          },
        );
        controller.addJavaScriptHandler(handlerName: 'poloFetchText', callback: (List<dynamic> args) => _fetchText('${args.firstOrNull}'));
        controller.addJavaScriptHandler(
          handlerName: 'poloMapEvent',
          callback: (List<dynamic> args) {
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
}
