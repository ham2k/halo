// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Mapbox backend for iOS/Android, via the official mapbox_maps_flutter
// native SDK — the only backend with real globe-projection support on
// mobile (MapLibre Native, the open-source fork, doesn't have it; only
// MapLibre GL JS does, which is why desktop uses a webview instead of
// MapLibre here — see the Map tab planning notes).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../config/mapbox_token.dart';
import 'map_marker_data.dart';

class MapboxNativeMapView extends StatefulWidget {
  final List<MapMarkerData> markers;
  final MapProjection projection;

  const MapboxNativeMapView({super.key, required this.markers, required this.projection});

  @override
  State<MapboxNativeMapView> createState() => _MapboxNativeMapViewState();
}

class _MapboxNativeMapViewState extends State<MapboxNativeMapView> {
  MapboxMap? _map;
  PointAnnotationManager? _annotations;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  @override
  void didUpdateWidget(MapboxNativeMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projection != widget.projection) _applyProjection();
    if (!listEquals(oldWidget.markers, widget.markers)) _applyMarkers();
  }

  Future<void> _applyProjection() async {
    await _map?.style.setProjection(StyleProjection(name: switch (widget.projection) {
      MapProjection.mercator => StyleProjectionName.mercator,
      MapProjection.globe => StyleProjectionName.globe,
    }));
  }

  Future<void> _applyMarkers() async {
    final annotations = _annotations;
    final map = _map;
    if (annotations == null || map == null) return;

    await annotations.deleteAll();
    await annotations.createMulti([
      for (final marker in widget.markers)
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(marker.longitude, marker.latitude)),
          textField: [marker.label, if (marker.sublabel != null) marker.sublabel!].join(' — '),
          textOffset: [0, 1.2],
          textColor: Colors.black.toARGB32(),
          textHaloColor: Colors.white.toARGB32(),
          textHaloWidth: 1.5,
          iconImage: 'marker-15',
          iconColor: marker.color.toARGB32(),
          iconSize: marker.kind == MapMarkerKind.qth ? 1.5 : 1.0,
        ),
    ]);

    if (widget.markers.isNotEmpty) {
      final camera = await map.cameraForCoordinatesPadding(
        [for (final m in widget.markers) Point(coordinates: Position(m.longitude, m.latitude))],
        CameraOptions(),
        MbxEdgeInsets(top: 48, left: 48, bottom: 48, right: 48),
        11,
        null,
      );
      await map.setCamera(camera);
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _annotations = await map.annotations.createPointAnnotationManager();
    await _applyProjection();
    await _applyMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      styleUri: MapboxStyles.STANDARD,
      onMapCreated: _onMapCreated,
    );
  }
}
