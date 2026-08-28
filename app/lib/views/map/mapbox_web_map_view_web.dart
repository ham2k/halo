// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// MapLibre backend for Flutter web: the app is already running in a
// browser, so instead of a webview (see DESIGN.md §11) this mounts a plain
// div as an HtmlElementView, loads MapLibre GL JS with a <script> tag once,
// and drives the shared map script (map_gl_script.dart — same
// markers/lines/popups as the desktop webview backend) directly through
// js_interop.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../services/map_error_reporter.dart';
import 'map_gl_script.dart';
import 'map_load_notice.dart';
import 'map_marker_data.dart';
import 'map_zoom_controller.dart';

/// Loads MapLibre GL JS and injects the shared map script, once per page.
Future<void>? _glLoading;

/// A FAILED load is not cached: the next map open retries, because the
/// common cause is being offline at the moment the panel first opened — a
/// cached failure would keep the map dead for the whole page lifetime after
/// the device comes back into coverage.
Future<void> _ensureGlLoaded() {
  final loading = _glLoading ??= _loadGl();
  return loading.catchError((Object e, StackTrace s) {
    if (identical(_glLoading, loading)) _glLoading = null;
    Error.throwWithStackTrace(e, s);
  });
}

Future<void> _loadGl() async {
  final head = web.document.head!;

  head.append(web.HTMLLinkElement()
    ..rel = 'stylesheet'
    ..href = mapGlCssUrl);
  // Popup styling the webview backend gets from its own page's <style>.
  head.append(web.HTMLStyleElement()
    ..textContent = '.maplibregl-popup-content { padding: 6px 10px; border-radius: 8px; }');

  final script = web.HTMLScriptElement()..src = mapGlScriptUrl;
  final loaded = Completer<void>();
  script.addEventListener(
      'load', ((web.Event _) => loaded.complete()).toJS);
  script.addEventListener(
      'error', ((web.Event _) => loaded.completeError(StateError('$mapGlScriptUrl failed to load'))).toJS);
  head.append(script);
  await loaded.future;

  head.append(web.HTMLScriptElement()..textContent = mapGlScript);
}

class MapboxWebMapView extends StatefulWidget {
  final List<MapMarkerData> markers;
  final List<MapLineData> lines;

  /// Reference footprints — a SOTA activation zone and the like — filled
  /// under everything else. See map_marker_data.dart's MapShapeData.
  final List<MapShapeData> shapes;
  final MapProjection projection;
  final bool isDark;

  /// The light/dark style URLs to actually load — see
  /// MapboxWebviewMapView's fields of the same name.
  final String styleUrl;
  final String styleUrlDark;

  final MapZoomController? zoomController;

  /// When set, a marker click reports here instead of opening the built-in
  /// HTML popup — see map_gl_script.dart's `notifyClicks`. Null for the QSO
  /// map, which keeps its own popup.
  final ValueChanged<String>? onMarkerTap;

  const MapboxWebMapView(
      {super.key,
      required this.markers,
      this.lines = const [],
      this.shapes = const [],
      required this.projection,
      required this.isDark,
      required this.styleUrl,
      required this.styleUrlDark,
      this.zoomController,
      this.onMarkerTap});

  @override
  State<MapboxWebMapView> createState() => _MapboxWebMapViewState();
}

class _MapboxWebMapViewState extends State<MapboxWebMapView> {
  static int _instanceCounter = 0;

  /// Each State registers its own factory so the div (and the map handle
  /// created on it) is per-instance — platform view factories are global
  /// and can't be unregistered.
  late final String _viewType = 'polo-mapbox-web-map-${_instanceCounter++}';

  web.HTMLDivElement? _container;
  JSObject? _handle;
  bool _loadFailed = false;

  /// The shared script's event callback: 'style-timeout' and 'recovered'
  /// drive the in-panel notice, everything (bar 'recovered') goes to
  /// ErrorPolicy through the reporter. Only the banner needs [mounted] —
  /// the reporter is static, and an error draining during teardown is
  /// still evidence.
  void _onMapEvent(String kind, String message) {
    if (kind == 'marker-click') {
      widget.onMarkerTap?.call(message);
      return;
    }
    if (kind == 'recovered') {
      if (mounted && _loadFailed) setState(() => _loadFailed = false);
      return;
    }
    if (kind == 'style-timeout' && mounted && !_loadFailed) setState(() => _loadFailed = true);
    MapErrorReporter.report(backend: 'web', kind: kind, message: message);
  }

  @override
  void initState() {
    super.initState();
    widget.zoomController
      ?..onZoomIn = _zoomIn
      ..onZoomOut = _zoomOut
      ..onMoveTo = _moveTo;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final div = web.HTMLDivElement();
      div.style
        ..width = '100%'
        ..height = '100%';
      // See mapbox_webview_map_view.dart's same rule — MapLibre's globe has
      // no built-in way to paint what's beyond the sphere, so this shows
      // through the canvas wherever the globe doesn't cover it.
      div.style.background = mapLibreSpaceBackgroundCss();
      _container = div;
      unawaited(_createMap());
      return div;
    });
  }

  Future<void> _createMap() async {
    try {
      await _ensureGlLoaded();
      if (!mounted || _container == null || _handle != null) return;
      final gl = web.window.getProperty<JSObject>('poloMapGl'.toJS);
      final onEvent = ((JSString kind, JSString message) => _onMapEvent(kind.toDart, message.toDart)).toJS;
      _handle = gl.callMethodVarArgs<JSObject>('create'.toJS, [
        _container!,
        widget.styleUrl.toJS,
        widget.styleUrlDark.toJS,
        widget.isDark.toJS,
        onEvent,
        (widget.onMarkerTap != null).toJS,
      ]);
    } catch (e, s) {
      // A CDN load failure (offline at map open) or a create() throw (no
      // WebGL) would otherwise escape as a generic zone error: no offline
      // stamp, no banner, and a blank pane with no evidence — the exact
      // defect this backend's error channel exists to close.
      MapErrorReporter.report(backend: 'web', kind: 'gl-load', message: '$e', stack: s);
      if (mounted) setState(() => _loadFailed = true);
      return;
    }
    _applyProjection();
    // Dark mode is picked at creation (see create's initialDark) rather than
    // applied here — for MapLibre, doing it again on ready would swap the
    // style a second time and race the marker application right below it.
    // Defer the data (and its camera fit) one frame so the div has been
    // attached and laid out — fitBounds on a still-zero-sized container
    // computes a nonsense camera. The shared script's ResizeObserver keeps
    // the canvas itself tracking the layout after that.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyMarkers();
      _applyLines();
      _applyShapes();
    });
  }

  @override
  void didUpdateWidget(MapboxWebMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_handle == null) return;
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

  void _applyProjection() {
    _handle?.callMethod('setProjection'.toJS, widget.projection.name.toJS);
  }

  void _applyStyleUrls() {
    _handle?.callMethod('updateStyles'.toJS, widget.styleUrl.toJS, widget.styleUrlDark.toJS);
  }

  void _applyDark() {
    _handle?.callMethod('setDark'.toJS, widget.isDark.toJS);
  }

  void _applyMarkers() {
    _handle?.callMethod('setMarkersJson'.toJS, jsonEncode(mapMarkersPayload(widget.markers)).toJS);
  }

  void _applyLines() {
    _handle?.callMethod('setLinesJson'.toJS, jsonEncode(mapLinesPayload(widget.lines)).toJS);
  }

  void _applyShapes() {
    _handle?.callMethod('setShapesJson'.toJS, jsonEncode(mapShapesPayload(widget.shapes)).toJS);
  }

  void _moveTo(double latitude, double longitude, double zoom) =>
      _handle?.callMethod('moveTo'.toJS, latitude.toJS, longitude.toJS, zoom.toJS);

  void _zoomIn() => _handle?.callMethod('zoomIn'.toJS);
  void _zoomOut() => _handle?.callMethod('zoomOut'.toJS);

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
    _handle?.callMethod('remove'.toJS);
    _handle = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(child: HtmlElementView(viewType: _viewType)),
          if (_loadFailed) const MapLoadNotice(),
        ],
      );
}
