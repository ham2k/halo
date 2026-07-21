// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Mapbox backend for iOS/Android, via the official mapbox_maps_flutter
// native SDK — the only backend with real globe-projection support on
// mobile (MapLibre Native, the open-source fork, doesn't have it; only
// MapLibre GL JS does, which is why desktop uses a webview instead of
// MapLibre here — see the Map tab planning notes).
//
// QSOs are band-colored circle annotations, the QTH a black one, connected
// by great-circle polyline annotations. Tapping a circle shows a Flutter
// callout card overlaid at the circle's screen position (kept in place
// through camera moves via pixelForCoordinate); tapping the map dismisses.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../config/mapbox_token.dart';
import 'map_marker_data.dart';
import 'map_popup.dart';

class MapboxNativeMapView extends StatefulWidget {
  final List<MapMarkerData> markers;
  final List<MapLineData> lines;
  final MapProjection projection;

  const MapboxNativeMapView({
    super.key,
    required this.markers,
    this.lines = const [],
    required this.projection,
  });

  @override
  State<MapboxNativeMapView> createState() => _MapboxNativeMapViewState();
}

class _MapboxNativeMapViewState extends State<MapboxNativeMapView> {
  MapboxMap? _map;
  CircleAnnotationManager? _circles;
  PolylineAnnotationManager? _polylines;

  /// Separate managers for the current QSO's highlight, created AFTER the base
  /// ones (annotation managers render in creation order) so its line paints
  /// over every base circle and its marker over everything.
  PolylineAnnotationManager? _highlightPolylines;
  CircleAnnotationManager? _highlightCircles;

  /// Created annotation id → its marker, so the tap handler can find what was
  /// hit. Kept per group (base vs highlight) so re-applying only the highlight
  /// — which happens on every keystroke while a call is being entered — leaves
  /// the base map's entries intact.
  final _baseMarkersById = <String, MapMarkerData>{};
  final _highlightMarkersById = <String, MapMarkerData>{};

  MapMarkerData? _markerForAnnotation(String id) => _baseMarkersById[id] ?? _highlightMarkersById[id];

  static List<MapMarkerData> _markersFor(List<MapMarkerData> all, {required bool highlight}) =>
      [for (final m in all) if (m.highlight == highlight) m];
  static List<MapLineData> _linesFor(List<MapLineData> all, {required bool highlight}) =>
      [for (final l in all) if (l.highlight == highlight) l];

  /// Selection is tracked by marker id, not by MapMarkerData value, so a
  /// data refresh of the selected QSO (a lookup filling in details) updates
  /// the open callout instead of dismissing it — matching OsmMapView.
  String? _selectedMarkerId;
  Offset? _selectedScreenPoint;

  /// Serializes _applyAnnotations runs: an unserialized overlap would
  /// interleave deleteAll/createMulti between two runs, leaving duplicate
  /// annotations on the map and a stale _markersByAnnotationId.
  Future<void> _annotationApplications = Future.value();

  MapMarkerData? get _selectedMarker {
    final id = _selectedMarkerId;
    if (id == null) return null;
    return widget.markers.where((m) => m.id == id).firstOrNull;
  }

  /// A circle tap also reaches the map's own tap listener right after —
  /// this flag keeps that second event from instantly dismissing the popup
  /// the first one just opened.
  bool _ignoreNextMapTap = false;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  @override
  void didUpdateWidget(MapboxNativeMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projection != widget.projection) _applyProjection();
    // Re-apply only the group that actually changed. The highlight (current
    // QSO) changes on every keystroke; the base map usually doesn't, so this
    // avoids deleting and recreating every base annotation — and refitting the
    // camera — on each character typed.
    final baseChanged = !listEquals(_markersFor(oldWidget.markers, highlight: false), _markersFor(widget.markers, highlight: false)) ||
        !listEquals(_linesFor(oldWidget.lines, highlight: false), _linesFor(widget.lines, highlight: false));
    final highlightChanged =
        !listEquals(_markersFor(oldWidget.markers, highlight: true), _markersFor(widget.markers, highlight: true)) ||
            !listEquals(_linesFor(oldWidget.lines, highlight: true), _linesFor(widget.lines, highlight: true));
    if (baseChanged || highlightChanged) _applyAnnotations(base: baseChanged, highlight: highlightChanged);
  }

  Future<void> _applyProjection() async {
    await _map?.style.setProjection(StyleProjection(name: switch (widget.projection) {
      MapProjection.mercator => StyleProjectionName.mercator,
      MapProjection.globe => StyleProjectionName.globe,
    }));
    _repositionPopup();
  }

  void _applyAnnotations({required bool base, required bool highlight}) {
    _annotationApplications = _annotationApplications
        .then((_) => _applyAnnotationsNow(base: base, highlight: highlight))
        .catchError((Object e) => debugPrint('[map] annotation update failed: $e'));
  }

  Future<void> _applyAnnotationsNow({required bool base, required bool highlight}) async {
    final circles = _circles;
    final polylines = _polylines;
    final highlightPolylines = _highlightPolylines;
    final highlightCircles = _highlightCircles;
    final map = _map;
    if (circles == null ||
        polylines == null ||
        highlightPolylines == null ||
        highlightCircles == null ||
        map == null) {
      return;
    }

    if (_selectedMarkerId != null && _selectedMarker == null) _dismissPopup();

    PolylineAnnotationOptions lineOptions(MapLineData line) => PolylineAnnotationOptions(
          geometry: LineString(coordinates: [
            for (final p in line.points) Position(p.longitude, p.latitude),
          ]),
          lineColor: line.color.toARGB32(),
          // The current QSO's line is drawn thick so it stands out.
          lineWidth: line.highlight ? 6 : 1.5,
        );
    CircleAnnotationOptions circleOptions(MapMarkerData marker) => CircleAnnotationOptions(
          geometry: Point(coordinates: Position(marker.longitude, marker.latitude)),
          circleRadius: marker.kind == MapMarkerKind.qth ? 6 : 7 * marker.sizeFactor,
          circleColor: marker.color.toARGB32(),
          circleStrokeColor: (marker.kind == MapMarkerKind.qth ? Colors.white : Colors.black87).toARGB32(),
          circleStrokeWidth: marker.kind == MapMarkerKind.qth ? 2 : 1.5,
        );

    // Re-applies one group: clears its line + circle managers and its slice of
    // the id map, then recreates from the current widget data. The base group
    // and the highlight group are independent, so touching one leaves the
    // other on the map untouched.
    Future<void> applyGroup({
      required bool isHighlight,
      required PolylineAnnotationManager lineManager,
      required CircleAnnotationManager circleManager,
      required Map<String, MapMarkerData> idMap,
    }) async {
      await lineManager.deleteAll();
      await lineManager.createMulti([for (final line in _linesFor(widget.lines, highlight: isHighlight)) lineOptions(line)]);
      await circleManager.deleteAll();
      idMap.clear();
      final markers = _markersFor(widget.markers, highlight: isHighlight);
      final created = await circleManager.createMulti([for (final m in markers) circleOptions(m)]);
      for (var i = 0; i < created.length && i < markers.length; i++) {
        final annotation = created[i];
        if (annotation != null) idMap[annotation.id] = markers[i];
      }
    }

    if (base) {
      await applyGroup(
        isHighlight: false,
        lineManager: polylines,
        circleManager: circles,
        idMap: _baseMarkersById,
      );
    }
    if (highlight) {
      await applyGroup(
        isHighlight: true,
        lineManager: highlightPolylines,
        circleManager: highlightCircles,
        idMap: _highlightMarkersById,
      );
    }

    // Only refit the camera when the base map changed (initial load, a new QSO
    // logged) — not on every keystroke's highlight update, which would pan/zoom
    // the map out from under the operator as they type.
    if (base && widget.markers.isNotEmpty) {
      final camera = await map.cameraForCoordinatesPadding(
        [for (final m in widget.markers) Point(coordinates: Position(m.longitude, m.latitude))],
        CameraOptions(),
        MbxEdgeInsets(top: 48, left: 48, bottom: 48, right: 48),
        11,
        null,
      );
      await map.setCamera(camera);
      _repositionPopup();
    }
  }

  void _onCircleTapped(CircleAnnotation annotation) {
    final marker = _markerForAnnotation(annotation.id);
    if (marker == null) return;
    _ignoreNextMapTap = true;
    setState(() => _selectedMarkerId = marker.id);
    _repositionPopup();
  }

  void _dismissPopup() {
    if (_selectedMarkerId == null) return;
    setState(() {
      _selectedMarkerId = null;
      _selectedScreenPoint = null;
    });
  }

  /// Re-projects the selected marker to screen space — called on every
  /// camera change so the callout tracks its circle while panning/zooming.
  Future<void> _repositionPopup() async {
    final map = _map;
    final marker = _selectedMarker;
    if (map == null || marker == null) return;
    final screen = await map.pixelForCoordinate(
      Point(coordinates: Position(marker.longitude, marker.latitude)),
    );
    if (!mounted || _selectedMarkerId != marker.id) return;
    setState(() => _selectedScreenPoint = Offset(screen.x, screen.y));
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    map.addInteraction(TapInteraction.onMap((_) {
      if (_ignoreNextMapTap) {
        _ignoreNextMapTap = false;
        return;
      }
      _dismissPopup();
    }));
    _polylines = await map.annotations.createPolylineAnnotationManager();
    _circles = await map.annotations.createCircleAnnotationManager();
    _circles!.tapEvents(onTap: _onCircleTapped);
    // Created last, so they layer above the base line/circle managers.
    _highlightPolylines = await map.annotations.createPolylineAnnotationManager();
    _highlightCircles = await map.annotations.createCircleAnnotationManager();
    _highlightCircles!.tapEvents(onTap: _onCircleTapped);
    await _applyProjection();
    _applyAnnotations(base: true, highlight: true);
  }

  @override
  Widget build(BuildContext context) {
    final popupPoint = _selectedScreenPoint;
    return Stack(
      children: [
        Positioned.fill(
          child: MapWidget(
            styleUri: MapboxStyles.STANDARD,
            onMapCreated: _onMapCreated,
            onCameraChangeListener: (_) => _repositionPopup(),
          ),
        ),
        if (_selectedMarker != null && popupPoint != null)
          Positioned(
            left: popupPoint.dx - MapPopupCard.maxWidth / 2,
            bottom: null,
            top: popupPoint.dy - 96 - 14,
            width: MapPopupCard.maxWidth,
            height: 96,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: MapPopupCard(marker: _selectedMarker!),
              ),
            ),
          ),
      ],
    );
  }
}
