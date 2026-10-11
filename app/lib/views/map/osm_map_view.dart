// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Map tab backend for platforms with no webview to run MapLibre GL JS
// in: OpenStreetMap raster tiles via flutter_map (see map_panel.dart's
// facade routing). Has no globe — flutter_map is a 2D tile compositor, not
// a 3D renderer.
//
// QSOs are band-colored circles, the QTH a black one, connected by
// great-circle polylines (pre-densified by the facade); tapping a circle
// opens a callout with the QSO's details, tapping anywhere else closes it.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;

import '../../services/connectivity_service.dart';
import '../../services/error_policy.dart' show ErrorPolicy;
import '../../services/map_error_reporter.dart';
import 'map_marker_data.dart';
import 'map_popup.dart';
import 'map_zoom_controller.dart';

class OsmMapView extends StatefulWidget {
  final List<MapMarkerData> markers;
  final List<MapLineData> lines;

  /// Reference footprints — a SOTA activation zone and the like — filled
  /// under everything else. See map_marker_data.dart's MapShapeData.
  final List<MapShapeData> shapes;
  final bool isDark;
  final MapZoomController? zoomController;

  /// When set, a marker tap reports here instead of opening the built-in
  /// [MapPopupCard] callout — mirrors the GL backends' `notifyClicks`. Null
  /// for the QSO map, which keeps its own callout.
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
  /// [MapFrame]. Unlike the GL backends' this does not lay the map out at the
  /// frame's size: the caller puts it in a box of that size, since scaling a
  /// Flutter map is Flutter's job. Read once, when the map is first built.
  final MapFrame? frame;

  const OsmMapView({
    super.key,
    required this.markers,
    this.lines = const [],
    this.shapes = const [],
    required this.isDark,
    this.zoomController,
    this.onMarkerTap,
    this.onCameraChanged,
    this.onMapTap,
    this.zoomFades,
    this.frame,
  });

  /// How long the online edge waits before tiles that failed are reset. Like
  /// the GL backends' reload (map_gl_script.dart): the edge can arrive the
  /// moment an interface does, before DNS answers, and a reset into that gap
  /// fails every tile again with no second edge coming.
  static const backOnlineDelay = Duration(seconds: 2);

  @override
  State<OsmMapView> createState() => _OsmMapViewState();
}

class _OsmMapViewState extends State<OsmMapView> {
  final _mapController = MapController();

  /// Coming back online refetches the tiles, when one went unanswered since
  /// the last time: flutter_map keeps a failed tile as failed, so a map that lost
  /// coverage stays grey where it did. A map with nothing failed is left
  /// alone — a reset drops every tile before reloading, and a healthy map
  /// would flash grey on every connectivity flap.
  final _reset = StreamController<void>.broadcast();
  StreamSubscription<bool>? _offlineChanges;
  Timer? _resetTimer;
  bool _tileFailed = false;
  Timer? _replayFit;
  String? _selectedMarkerId;

  @override
  void initState() {
    super.initState();
    _offlineChanges = ConnectivityService.offlineChanges.listen((offline) {
      _resetTimer?.cancel();
      if (offline) return;
      _resetTimer = Timer(OsmMapView.backOnlineDelay, () {
        if (!_tileFailed) return;
        _tileFailed = false;
        _reset.add(null);
      });
    });
    widget.zoomController
      ?..onZoomIn = _zoomIn
      ..onZoomOut = _zoomOut
      ..onMoveTo = _moveTo
      ..onFitTo = _fitTo
      ..onRefit = _fitCamera
      ..onCamera = _camera;
    if (widget.frame != null) widget.zoomController?.onSettled = _settled;
  }

  /// The tile a framed map draws at each place, to say when the picture is
  /// whole — see [_settled]. By place, and the latest: a reset after coming
  /// back online replaces every tile with a new one at the same place, and a
  /// TileImage equals any other at its place, so a set would keep the
  /// disposed ones — never ready — for good.
  final _tiles = <TileCoordinates, TileImage>{};

  Widget _trackTile(BuildContext context, Widget tileWidget, TileImage tile) {
    _tiles[tile.coordinates] = tile;
    return tileWidget;
  }

  /// Once every tile has arrived or failed, and a frame has drawn them: a
  /// picture taken sooner has holes where the network was slow.
  Future<void> _settled() async {
    const step = Duration(milliseconds: 100);
    for (var waited = Duration.zero; waited < mapSnapshotTimeout; waited += step) {
      if (!mounted) break;
      if (_tiles.isNotEmpty && _tiles.values.every((t) => t.readyToDisplay)) {
        await WidgetsBinding.instance.endOfFrame;
        return;
      }
      await Future<void>.delayed(step);
    }
    throw const MapSnapshotException('the map did not finish loading');
  }

  Future<MapCameraView?> _camera() async {
    final camera = _mapController.camera;
    return (
      camera: MapCameraPosition(latitude: camera.center.latitude, longitude: camera.center.longitude, zoom: camera.zoom, bearing: -camera.rotation),
      viewport: camera.nonRotatedSize,
      popup: widget.onMarkerTap == null ? _selectedMarkerId : null,
    );
  }

  void _moveTo(double latitude, double longitude, double zoom) => _mapController.move(LatLng(latitude, longitude), zoom);

  /// Fitted around longitude 0 and moved back: flutter_map takes no longitude
  /// past ±180, and a fit is the same at any longitude on a Mercator map.
  void _fitTo(List<GridLocation> points) {
    if (points.isEmpty) return;
    final longitudes = points.map((p) => p.longitude);
    final offset = (longitudes.reduce(math.min) + longitudes.reduce(math.max)) / 2;
    final fitted = CameraFit.coordinates(
      coordinates: [for (final p in points) LatLng(p.latitude, p.longitude - offset)],
      padding: const EdgeInsets.all(48),
      maxZoom: _fitMaxZoom,
    ).fit(_mapController.camera);
    final longitude = (fitted.center.longitude + offset + 540) % 360 - 180;
    _mapController.move(LatLng(fitted.center.latitude, longitude), fitted.zoom);
  }

  void _zoomIn() => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
  void _zoomOut() => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);

  @override
  void didUpdateWidget(OsmMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pruneCaches();
    if (!listEquals(oldWidget.markers, widget.markers)) {
      if (!widget.markers.any((m) => m.id == _selectedMarkerId)) _selectedMarkerId = null;
      // Refit only when the BASE markers change (a QSO logged), not on each
      // keystroke's highlight update — otherwise the map pans/zooms out from
      // under the operator as they type a call. A map that keys its fit
      // (MapMarkerData.fitKey) refits when the key changes, and only then.
      final oldFitted = _fitted(oldWidget.markers), newFitted = _fitted(widget.markers);
      final newKey = newFitted.map((m) => m.fitKey).nonNulls.firstOrNull;
      final baseChanged = newKey != null ? newKey != oldFitted.map((m) => m.fitKey).nonNulls.firstOrNull : !listEquals(oldFitted, newFitted);
      // While the camera follows a QSO (MapZoomController.lastFit), the
      // markers' own fit stands aside, as in the GL script.
      if (baseChanged && widget.frame == null && widget.zoomController?.lastFit == null) _fitCamera();
    }
  }

  /// The markers the camera fits: the base ones, less any a host keeps out of
  /// the fit ([MapMarkerData.fitsCamera]).
  static List<MapMarkerData> _fitted(List<MapMarkerData> markers) => [
    for (final m in markers)
      if (!m.highlight && m.fitsCamera) m,
  ];

  /// [MapZoomController.fitMaxZoom] on flutter_map's own scale.
  static const _fitMaxZoom = MapZoomController.fitMaxZoom + 1;

  /// The GL-scale zoom of the camera [context] is under, for a fade.
  static double _glZoom(BuildContext context) => MapZoomController.glZoomOf(osmZoom: MapCamera.of(context).zoom);

  void _fitCamera() {
    final fitted = _fitted(widget.markers);
    if (fitted.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(coordinates: [for (final m in fitted) LatLng(m.latitude, m.longitude)], padding: const EdgeInsets.all(48), maxZoom: _fitMaxZoom),
    );
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
    if (controller?.onRefit == _fitCamera) controller?.onRefit = null;
    if (controller?.onCamera == _camera) controller?.onCamera = null;
    if (controller?.onSettled == _settled) controller?.onSettled = null;
    _replayFit?.cancel();
    _offlineChanges?.cancel();
    _resetTimer?.cancel();
    _reset.close();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = [
      for (final m in widget.markers)
        if (m.fitsCamera) LatLng(m.latitude, m.longitude),
    ];
    final selected = _selectedMarkerId == null || widget.onMarkerTap != null ? null : widget.markers.where((m) => m.id == _selectedMarkerId).firstOrNull;
    final frame = widget.frame?.camera;
    final footprints = _footprintLayers();
    // Wrapped at full strength too, so the highlight coming and going does
    // not remount every base marker under it.
    final baseOpacity = widget.markers.any((m) => m.highlight) ? mapDimmedOpacity : 1.0;

    return FlutterMap(
      mapController: _mapController,
      options: frame != null
          ? MapOptions(
              initialCenter: LatLng(frame.latitude, frame.longitude),
              initialZoom: frame.zoom,
              // flutter_map turns the map clockwise; a bearing names the
              // direction that ends up at the top.
              initialRotation: -frame.bearing,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            )
          : MapOptions(
              initialCameraFit: CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48), maxZoom: _fitMaxZoom),
              // A QSO framed before this backend came up: the fit above is
              // to the markers. Once the frame is over — flutter_map applies
              // that fit after this callback, in the same frame.
              onMapReady: () {
                if (widget.zoomController?.lastFit == null) return;
                _replayFit = Timer(Duration.zero, () {
                  if (widget.zoomController?.lastFit case final points?) _fitTo(points);
                });
              },
              onTap: (_, point) {
                setState(() => _selectedMarkerId = null);
                if (widget.onMarkerTap != null) widget.onMapTap?.call(GridLocation(point.latitude, point.longitude));
              },
              onPositionChanged: (camera, _) => widget.onCameraChanged?.call((
                camera: MapCameraPosition(
                  latitude: camera.center.latitude,
                  longitude: camera.center.longitude,
                  zoom: MapZoomController.glZoomOf(osmZoom: camera.zoom),
                ),
                bounds: mapViewBounds(
                  south: camera.visibleBounds.south,
                  west: camera.visibleBounds.west,
                  north: camera.visibleBounds.north,
                  east: camera.visibleBounds.east,
                ),
              )),
            ),
      children: [
        TileLayer(
          // CARTO's Dark Matter tiles in dark mode — plain OSM has no dark
          // variant of its own — free and tokenless like the light tiles,
          // but built from OSM data via CARTO rather than OSM's own server,
          // hence the attribution swap below.
          urlTemplate: widget.isDark ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ham2k.poloNext',
          // A picture is taken once, so its tiles show at full strength the
          // moment they arrive, and say when they have.
          tileDisplay: widget.frame != null ? const TileDisplay.instantaneous() : const TileDisplay.fadeIn(),
          tileBuilder: widget.frame != null ? _trackTile : null,
          reset: _reset.stream,
          // Otherwise a failed tile is swallowed by flutter_map and the pane
          // just shows grey squares with no evidence anywhere. The tile URL
          // is stripped from the message (NetworkImageLoadException embeds
          // it): the reporter dedups by message, and one per-URL variant per
          // tile would burn its whole upload budget on one failure class.
          errorTileCallback: (tile, error, stackTrace) {
            // An answer — a 404, OSM's 429 or 403 — is no better after a reset.
            if (ErrorPolicy.isTransportFailure(error)) _tileFailed = true;
            MapErrorReporter.report(backend: 'osm', kind: 'tile-load', message: '$error'.replaceAll(RegExp(r'https?://\S+'), '<tile url>'), stack: stackTrace);
          },
        ),
        // Base lines, then base markers, then the current QSO's highlight line
        // and marker in layers ABOVE them — flutter_map stacks children in
        // order, so the highlight paints over every base line AND marker.
        if (widget.shapes.any((shape) => shape.dashed)) _fadedWithZoom(footprints.dashed, widget.zoomFades?.dashedShapes),
        _fadedWithZoom(footprints.solid, widget.zoomFades?.solidShapes),
        if (widget.shapes.any((shape) => shape.isLine && !shape.dashed)) _fadedWithZoom(footprints.lines, widget.zoomFades?.solidShapes),
        Opacity(
          opacity: baseOpacity,
          child: _lineLayer([
            for (final l in widget.lines)
              if (!l.highlight) l,
          ]),
        ),
        Opacity(
          opacity: baseOpacity,
          child: _markerLayer([
            for (final m in widget.markers)
              if (!m.highlight && m.dimsBehindHighlight) m,
          ]),
        ),
        _markerLayer([
          for (final m in widget.markers)
            if (!m.highlight && !m.dimsBehindHighlight) m,
        ]),
        _lineLayer([
          for (final l in widget.lines)
            if (l.highlight) l,
        ]),
        _markerLayer([
          for (final m in widget.markers)
            if (m.highlight) m,
        ]),
        if (selected != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(selected.latitude, selected.longitude),
                width: MapPopupCard.maxWidth,
                height: 96,
                // The point sits at the popup's bottom center, so the card
                // floats just above the tapped circle.
                alignment: Alignment.topCenter,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: MapPopupCard(marker: selected),
                  ),
                ),
              ),
            ],
          ),
        // A picture carries its credit in its own layout (see [osmAttribution]).
        if (widget.frame == null) _OsmAttribution(isDark: widget.isDark),
      ],
    );
  }

  /// The footprint layers as last built, and the shapes they were built from.
  /// Rebuilt only for different shapes: a layer handed the same instance again is
  /// not rebuilt, and flutter_map keeps its projection of every point — a
  /// fresh layer per frame of a drag would re-project a national forest's
  /// outline sixty times a second.
  List<MapShapeData>? _shapeLayersFrom;
  ({Widget solid, Widget lines, Widget dashed})? _shapeLayers;

  ({Widget solid, Widget lines, Widget dashed}) _footprintLayers() {
    // Equal, not identical: a pane builds its list afresh each time, and a
    // shape compares by id and colour, never point by point.
    if (_shapeLayers case final built? when listEquals(_shapeLayersFrom, widget.shapes)) return built;
    _shapeLayersFrom = widget.shapes;
    return _shapeLayers = (
      solid: PolygonLayer(
        // Off for the same reason as the polylines below: a boundary is a
        // survey's own outline, and simplifying it moves the edge the
        // activator is judging their position against.
        simplificationTolerance: 0,
        polygons: [
          for (final shape in widget.shapes)
            if (!shape.isLine && !shape.dashed)
              Polygon(
                points: [for (final p in shape.rings.first) LatLng(p.latitude, p.longitude)],
                holePointsList: [
                  for (final ring in shape.rings.skip(1)) [for (final p in ring) LatLng(p.latitude, p.longitude)],
                ],
                color: shape.color.withValues(alpha: 0.18),
                borderColor: shape.color.withValues(alpha: 0.9),
                borderStrokeWidth: 2,
              ),
        ],
      ),
      // The footprints that are lines — a trail or a river that is the park —
      // stroked like an area's edge, and never closed into one.
      lines: PolylineLayer(
        simplificationTolerance: 0,
        polylines: [
          for (final shape in widget.shapes)
            if (shape.isLine && !shape.dashed)
              Polyline(points: [for (final p in shape.rings.first) LatLng(p.latitude, p.longitude)], color: shape.color.withValues(alpha: 0.9), strokeWidth: 2),
        ],
      ),
      // Suggestions nobody has picked, as edges alone, under every solid
      // shape. Every ring is stroked, holes included, so a dashed area and
      // its solid form trace the same lines.
      dashed: PolylineLayer(
        simplificationTolerance: 0,
        polylines: [
          for (final shape in widget.shapes)
            if (shape.dashed)
              for (final ring in shape.rings)
                Polyline(
                  points: [for (final p in ring) LatLng(p.latitude, p.longitude)],
                  color: shape.color.withValues(alpha: 0.8),
                  strokeWidth: 1.25,
                  // Dots: a suggestion's edge is context, and any length of
                  // dash reads as a boundary of its own.
                  pattern: const StrokePattern.dotted(spacingFactor: 2),
                ),
        ],
      ),
    );
  }

  /// [layer] faded in over [band] ([MapZoomFades]), following the camera
  /// frame by frame. The layer itself is the same instance every frame — only
  /// the opacity around it changes — and at full strength it is not wrapped.
  Widget _fadedWithZoom(Widget layer, MapZoomFade? band) {
    if (band == null) return layer;
    return Builder(
      builder: (context) {
        final opacity = mapZoomFadeOpacity(band, _glZoom(context));
        return opacity >= 1 ? layer : Opacity(opacity: opacity, child: layer);
      },
    );
  }

  /// The layer objects by id, kept across builds and replaced only for an
  /// entry whose data changed: a rebuild of this widget — every emission of a
  /// long log, every settings notification — otherwise turned thousands of
  /// contacts back into `LatLng` lists and `Marker` subtrees for the layers to
  /// diff against what they already had.
  final _polylines = <String, ({MapLineData data, Polyline line})>{};
  final _markerWidgets = <String, ({MapMarkerData data, double scale, Marker marker})>{};

  Polyline _polylineFor(MapLineData line) {
    final cached = _polylines[line.id];
    if (cached != null && cached.data == line) return cached.line;
    final built = Polyline(
      points: [for (final p in line.points) LatLng(p.latitude, p.longitude)],
      color: line.color,
      // The current QSO's line is drawn thick so it stands out.
      strokeWidth: line.highlight ? 6 : 1.5,
    );
    _polylines[line.id] = (data: line, line: built);
    return built;
  }

  Marker _markerFor(MapMarkerData marker, double scale) {
    final cached = _markerWidgets[marker.id];
    if (cached != null && cached.data == marker && cached.scale == scale) return cached.marker;
    final built = Marker(
      point: LatLng(marker.latitude, marker.longitude),
      // A generous transparent hit area around the small circle.
      width: 28 * marker.sizeFactor,
      height: 28 * marker.sizeFactor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onMarkerTap != null ? widget.onMarkerTap!(marker.id) : setState(() => _selectedMarkerId = marker.id),
        child: Center(
          child: marker.fadesWithZoom
              // A builder of its own, so the fade follows the camera frame
              // by frame without rebuilding every other marker.
              ? Builder(
                  builder: (context) => Opacity(
                    opacity: mapZoomFadeOpacity(widget.zoomFades?.markers, _glZoom(context)),
                    child: MapCircleMarker(marker: marker, scale: scale),
                  ),
                )
              : MapCircleMarker(marker: marker, scale: scale),
        ),
      ),
    );
    _markerWidgets[marker.id] = (data: marker, scale: scale, marker: built);
    return built;
  }

  /// Drops cache entries for ids no longer drawn, so a long session does not
  /// hold every contact ever deleted.
  void _pruneCaches() {
    final lineIds = {for (final l in widget.lines) l.id};
    final markerIds = {for (final m in widget.markers) m.id};
    _polylines.removeWhere((id, _) => !lineIds.contains(id));
    _markerWidgets.removeWhere((id, _) => !markerIds.contains(id));
  }

  PolylineLayer _lineLayer(List<MapLineData> lines) => PolylineLayer(
    // Off (default is ~0.4): the great-circle arcs are already densified
    // to a smooth curve by greatCirclePoints, and flutter_map's
    // Douglas–Peucker simplification otherwise collapses each into a few
    // straight segments — the whole point of the densified points is lost.
    simplificationTolerance: 0,
    polylines: [for (final line in lines) _polylineFor(line)],
  );

  /// Under a builder reading the camera, so the markers shrink with the zoom
  /// ([mapMarkerScaleAt]). The scale is rounded to a twentieth: each step
  /// rebuilds every marker, and a pinch would otherwise do it every frame.
  Widget _markerLayer(List<MapMarkerData> markers) => Builder(
    builder: (context) {
      final scale = (mapMarkerScaleAt(_glZoom(context)) * 20).round() / 20;
      return MarkerLayer(markers: [for (final marker in markers) _markerFor(marker, scale)]);
    },
  );
}

/// The credit for this backend's tiles. CARTO's dark tiles are still built
/// from OSM's data, so both credits apply — the tile usage policy requires the
/// one whose server actually served the tiles.
String osmAttribution({required bool isDark}) => isDark ? '© OpenStreetMap contributors © CARTO' : '© OpenStreetMap contributors';

/// The OSM credit the tile usage policy requires, in the map's bottom-right.
///
/// Ours rather than flutter_map's [SimpleAttributionWidget], which lays its
/// prefix and source out in an unconstrained `Row(mainAxisSize: min)` and so
/// overflows — visibly striped in debug, silently clipped in release — on any
/// map pane narrower than the credit's natural width. The Map tab in the split
/// layout is routinely that narrow. A lone [Text] has no flex to overflow: it
/// ellipsizes into whatever width it is given.
class _OsmAttribution extends StatelessWidget {
  final bool isDark;

  const _OsmAttribution({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: ColoredBox(
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xxs),
            child: Text(
              osmAttribution(isDark: isDark),
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
