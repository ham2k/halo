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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:latlong2/latlong.dart';

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

  const OsmMapView({
    super.key,
    required this.markers,
    this.lines = const [],
    this.shapes = const [],
    required this.isDark,
    this.zoomController,
    this.onMarkerTap,
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
      ..onMoveTo = _moveTo;
  }

  void _moveTo(double latitude, double longitude, double zoom) => _mapController.move(LatLng(latitude, longitude), zoom);

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
      // under the operator as they type a call.
      final baseChanged = !listEquals(
        [
          for (final m in oldWidget.markers)
            if (!m.highlight) m,
        ],
        [
          for (final m in widget.markers)
            if (!m.highlight) m,
        ],
      );
      if (baseChanged) _fitCamera();
    }
  }

  void _fitCamera() {
    if (widget.markers.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(coordinates: [for (final m in widget.markers) LatLng(m.latitude, m.longitude)], padding: const EdgeInsets.all(48), maxZoom: 11),
    );
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
    _offlineChanges?.cancel();
    _resetTimer?.cancel();
    _reset.close();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = [for (final m in widget.markers) LatLng(m.latitude, m.longitude)];
    final selected = _selectedMarkerId == null || widget.onMarkerTap != null ? null : widget.markers.where((m) => m.id == _selectedMarkerId).firstOrNull;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48), maxZoom: 11),
        onTap: (_, _) => setState(() => _selectedMarkerId = null),
      ),
      children: [
        TileLayer(
          // CARTO's Dark Matter tiles in dark mode — plain OSM has no dark
          // variant of its own — free and tokenless like the light tiles,
          // but built from OSM data via CARTO rather than OSM's own server,
          // hence the attribution swap below.
          urlTemplate: widget.isDark ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ham2k.poloNext',
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
        _shapeLayer(),
        _lineLayer([
          for (final l in widget.lines)
            if (!l.highlight) l,
        ]),
        _markerLayer([
          for (final m in widget.markers)
            if (!m.highlight) m,
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
        _OsmAttribution(isDark: widget.isDark),
      ],
    );
  }

  /// The footprints, under the lines and dots so an area never covers what
  /// sits inside it. Holes are the rings after the first, GeoJSON's own
  /// convention (see mapShapesFromGeojson).
  PolygonLayer _shapeLayer() => PolygonLayer(
    // Off for the same reason as the polylines below: a boundary is a
    // survey's own outline, and simplifying it moves the edge the
    // activator is judging their position against.
    simplificationTolerance: 0,
    polygons: [
      for (final shape in widget.shapes)
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
  );

  /// The layer objects by id, kept across builds and replaced only for an
  /// entry whose data changed: a rebuild of this widget — every emission of a
  /// long log, every settings notification — otherwise turned thousands of
  /// contacts back into `LatLng` lists and `Marker` subtrees for the layers to
  /// diff against what they already had.
  final _polylines = <String, ({MapLineData data, Polyline line})>{};
  final _markerWidgets = <String, ({MapMarkerData data, Marker marker})>{};

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

  Marker _markerFor(MapMarkerData marker) {
    final cached = _markerWidgets[marker.id];
    if (cached != null && cached.data == marker) return cached.marker;
    final built = Marker(
      point: LatLng(marker.latitude, marker.longitude),
      // A generous transparent hit area around the small circle.
      width: 28 * marker.sizeFactor,
      height: 28 * marker.sizeFactor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onMarkerTap != null ? widget.onMarkerTap!(marker.id) : setState(() => _selectedMarkerId = marker.id),
        child: Center(child: MapCircleMarker(marker: marker)),
      ),
    );
    _markerWidgets[marker.id] = (data: marker, marker: built);
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

  MarkerLayer _markerLayer(List<MapMarkerData> markers) => MarkerLayer(markers: [for (final marker in markers) _markerFor(marker)]);
}

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
              // CARTO's dark tiles are still built from OSM's data, so both
              // credits apply — the tile usage policy requires the one whose
              // server actually served the tiles.
              isDark ? '© OpenStreetMap contributors © CARTO' : '© OpenStreetMap contributors',
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
