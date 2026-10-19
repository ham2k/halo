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
import 'package:halo_core/halo_core.dart' show GridLocation;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show PlatformViewCover;
import 'package:web/web.dart' as web;

import '../../services/connectivity_service.dart';
import '../../services/map_error_reporter.dart';
import 'map_gl_script.dart';
import 'map_marker_data.dart';
import 'map_grayline.dart';
import 'map_overlays.dart';
import 'map_unavailable_state.dart';
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

  // The library is read out of the app bundle, not fetched from a CDN, so
  // there is nothing to await a load event for: appending a script with
  // textContent executes it synchronously.
  await preloadMapGlLibrary();
  head.append(web.HTMLStyleElement()..textContent = mapGlLibraryCss);
  // Popup styling the webview backend gets from its own page's <style>.
  head.append(web.HTMLStyleElement()..textContent = '.maplibregl-popup-content { padding: 6px 10px; border-radius: 8px; }');

  head.append(web.HTMLScriptElement()..textContent = mapGlLibrarySource);
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

  /// See MapboxWebviewMapView's field of the same name.
  final MapFrame? frame;

  /// See MapboxWebviewMapView's field of the same name.
  final MapOverlays? overlays;

  /// See MapboxWebviewMapView's field of the same name.
  final DateTime? graylineAt;

  /// See MapboxWebviewMapView's field of the same name.
  final bool spreadOverlaps;

  /// See MapboxWebviewMapView's field of the same name.
  final MapMarkerFocus? focus;

  const MapboxWebMapView({
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
    this.graylineAt,
    this.spreadOverlaps = false,
    this.focus,
  });

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

  /// Completed once [_createMap] has made the map or given up, for a snapshot
  /// asked for before then to wait on.
  final _created = Completer<void>();

  /// Whether the first full set has reached the script — what a patch merges into.
  bool _dataApplied = false;

  /// Drives [MapUnavailableState]. Set when the map gives up, cleared by the
  /// script's 'recovered' signal — a map that recovers must not keep the
  /// empty state.
  bool _unavailable = false;

  /// The shared script's event callback: everything bar 'recovered' goes to
  /// ErrorPolicy through the reporter, and a stuck style also raises the
  /// empty state. What the operator is told is the CONDITION only
  /// ([MapUnavailableState]) — the kind naming the cause is evidence, and
  /// never reaches them. Only the empty state needs [mounted]; the reporter
  /// is static, and an error draining during teardown is still evidence.
  void _onMapEvent(String kind, String message) {
    if (kind == 'marker-click') {
      widget.onMarkerTap?.call(message);
      return;
    }
    if (kind == 'map-click') {
      if ([for (final part in message.split(',')) double.tryParse(part)] case [final latitude?, final longitude?]) {
        widget.onMapTap?.call(GridLocation(latitude, longitude));
      } else {
        MapErrorReporter.report(backend: 'web', kind: 'map-click-malformed', message: message);
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
        MapErrorReporter.report(backend: 'web', kind: 'camera-malformed', message: message);
      }
      return;
    }
    if (kind == 'recovered') {
      if (mounted && _unavailable) setState(() => _unavailable = false);
      return;
    }
    // 'style-timeout' is the payload watchdog — markers waiting on a style
    // that never parsed, so the pane is blank. 'style-swap-timeout' is
    // deliberately absent: there the previous style is still up with the data
    // restored onto it, and covering a working map would be the worse error.
    if (kind == 'style-timeout' && mounted && !_unavailable) setState(() => _unavailable = true);
    MapErrorReporter.report(backend: 'web', kind: kind, message: message);
  }

  /// The app's online and offline edges, for the script's reload — see
  /// map_gl_script.dart's `reload` and `cancelReload`.
  StreamSubscription<bool>? _offlineChanges;

  @override
  void initState() {
    super.initState();
    _offlineChanges = ConnectivityService.offlineChanges.listen((offline) {
      _handle?.callMethod((offline ? 'cancelReload' : 'reload').toJS);
    });
    widget.zoomController
      ?..onZoomIn = _zoomIn
      ..onZoomOut = _zoomOut
      ..onMoveTo = _moveTo
      ..onFitTo = _fitTo
      ..onRefit = _refit
      ..onCamera = _camera
      ..onSnapshot = _snapshot;
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
        switch (widget.frame) {
          null => null,
          final frame => {...frame.camera.toJson(), 'width': frame.width, 'height': frame.height, 'background': mapLibreSpaceBackgroundCss()}.jsify(),
        },
      ]);
      if (!_created.isCompleted) _created.complete();
    } catch (e, s) {
      if (!_created.isCompleted) _created.complete();
      // A CDN load failure (offline at map open) or a create() throw (no
      // WebGL) would otherwise escape as a generic zone error: no offline
      // stamp, no empty state, and a blank pane with no evidence — the exact
      // defect this backend's error channel exists to close.
      MapErrorReporter.report(backend: 'web', kind: 'gl-load', message: '$e', stack: s);
      if (mounted) setState(() => _unavailable = true);
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
      _applyZoomFades();
      _applySpread();
      _applyFocus();
      _applyCreditLabels();
      _applyMarkers();
      _applyLines();
      _applyShapes();
      _applyOverlays();
      if (widget.graylineAt != null) _applyGrayline();
      _dataApplied = true;
      if (widget.zoomController?.lastFit case final points?) _fitTo(points);
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
    // See MapboxWebviewMapView.didUpdateWidget: a patch over the set. Not
    // before the first full set has gone over (`_dataApplied`): a patch
    // merges into what the script holds, and until then it holds nothing —
    // the post-frame apply reads the widget's lists as they stand, so nothing
    // that lands in that window is lost.
    if (!_dataApplied) return;
    if (!identical(oldWidget.markers, widget.markers)) {
      final markers = diffMarkers(oldWidget.markers, widget.markers);
      if (patchIsSmaller(markers, total: widget.markers.length)) {
        _handle?.callMethod('patchMarkersJson'.toJS, jsonEncode(mapMarkersPatchPayload(markers)).toJS);
      } else if (!listEquals(oldWidget.markers, widget.markers)) {
        _applyMarkers();
      }
    }
    if (!identical(oldWidget.lines, widget.lines)) {
      final lines = diffLines(oldWidget.lines, widget.lines);
      if (patchIsSmaller(lines, total: widget.lines.length)) {
        _handle?.callMethod('patchLinesJson'.toJS, jsonEncode(mapLinesPatchPayload(lines)).toJS);
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

  void _applyProjection() {
    _handle?.callMethod('setProjection'.toJS, widget.projection.name.toJS);
  }

  void _applyStyleUrls() {
    // The tone travels with the URLs: this call replaces _applyDark for a
    // style change (see didUpdateWidget), so it is the only chance the script
    // gets to learn which slot the new pick should show.
    _handle?.callMethod('updateStyles'.toJS, widget.styleUrl.toJS, widget.styleUrlDark.toJS, widget.isDark.toJS);
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

  void _applyZoomFades() {
    _handle?.callMethod('setZoomFadesJson'.toJS, jsonEncode(mapZoomFadesPayload(widget.zoomFades)).toJS);
  }

  void _applyShapes() {
    _handle?.callMethod('setShapesJson'.toJS, jsonEncode(mapShapesPayload(widget.shapes, credit: mapOutlinesCredit(context.t, widget.shapes))).toJS);
  }

  void _applyFocus() {
    _handle?.callMethod('setFocusJson'.toJS, jsonEncode(mapMarkerFocusPayload(widget.focus)).toJS);
  }

  void _applyCreditLabels() {
    _handle?.callMethod('setCreditLabelsJson'.toJS, jsonEncode(mapCreditLabels(context.t)).toJS);
  }

  void _applySpread() {
    _handle?.callMethod('setSpread'.toJS, widget.spreadOverlaps.toJS);
  }

  void _applyOverlays() {
    final overlays = widget.overlays;
    if (overlays == null) return;
    _handle?.callMethod('setOverlaysJson'.toJS, jsonEncode(mapOverlaysPayload(overlays, dark: widget.isDark, t: context.t)).toJS);
  }

  void _applyGrayline() {
    final at = widget.graylineAt;
    _handle?.callMethod('setGraylineJson'.toJS, (at == null ? 'null' : jsonEncode(mapGraylinePayload(at, dark: widget.isDark))).toJS);
  }

  void _moveTo(double latitude, double longitude, double zoom) => _handle?.callMethod('moveTo'.toJS, latitude.toJS, longitude.toJS, zoom.toJS);
  // Not before the first data apply, which frames the controller's lastFit
  // itself: until then there is no map, or no container to size a fit by.
  void _fitTo(List<GridLocation> points) {
    if (_dataApplied) _handle?.callMethod('fitToJson'.toJS, jsonEncode(mapFitPayload(points)).toJS);
  }

  void _refit() {
    if (_dataApplied) _handle?.callMethod('refit'.toJS);
  }

  /// A tap on a map still being made waits for it first rather than doing
  /// nothing.
  Future<MapCameraView?> _camera() async {
    await _created.future.timeout(mapCameraWait, onTimeout: () {});
    return mapCameraViewFromJson(_handle?.callMethod<JSAny?>('camera'.toJS).dartify());
  }

  /// Waits for the map when it is still being made: an operator can press
  /// Copy the moment a postcard opens.
  Future<Uint8List> _snapshot(double pixelRatio) async {
    await _created.future.timeout(mapSnapshotTimeout, onTimeout: () => throw const MapSnapshotException('the map never came up'));
    final handle = _handle;
    if (handle == null) throw const MapSnapshotException('the map could not be drawn');
    try {
      final url = await handle.callMethod<JSPromise<JSString>>('snapshot'.toJS, pixelRatio.toJS).toDart;
      return decodeDataUrl(url.toDart);
    } catch (e) {
      if (isMapSnapshotOutcome('$e')) throw MapSnapshotException('$e');
      rethrow;
    }
  }

  void _zoomIn() => _handle?.callMethod('zoomIn'.toJS);
  void _zoomOut() => _handle?.callMethod('zoomOut'.toJS);

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
    _offlineChanges?.cancel();
    _handle?.callMethod('remove'.toJS);
    _handle = null;
    _dataApplied = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      // Covered while a route sits over the map's: a dropdown's menu has
      // nothing of its own to put between its clicks and the map.
      Positioned.fill(
        child: PlatformViewCover(child: HtmlElementView(viewType: _viewType)),
      ),
      if (_unavailable) const Positioned.fill(child: MapUnavailableState()),
    ],
  );
}
