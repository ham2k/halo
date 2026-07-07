// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The zero-token, zero-dependency Map tab backend: OpenStreetMap raster
// tiles via flutter_map. Used automatically whenever no Mapbox token is
// configured (see operation_map_tab.dart's facade routing), and works on
// every platform — the safety net a fresh checkout falls back to before
// lib/config/mapbox_token.dart is filled in. Has no globe projection —
// flutter_map is a 2D tile compositor, not a 3D renderer.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:polo_widgets/polo_widgets.dart';

import 'map_marker_data.dart';

class OsmMapView extends StatefulWidget {
  final List<MapMarkerData> markers;

  const OsmMapView({super.key, required this.markers});

  @override
  State<OsmMapView> createState() => _OsmMapViewState();
}

class _OsmMapViewState extends State<OsmMapView> {
  final _mapController = MapController();

  @override
  void didUpdateWidget(OsmMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.markers, widget.markers)) _fitCamera();
  }

  void _fitCamera() {
    if (widget.markers.isEmpty) return;
    _mapController.fitCamera(CameraFit.coordinates(
      coordinates: [for (final m in widget.markers) LatLng(m.latitude, m.longitude)],
      padding: const EdgeInsets.all(48),
      maxZoom: 11,
    ));
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = [for (final m in widget.markers) LatLng(m.latitude, m.longitude)];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(48),
          maxZoom: 11,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ham2k.poloNext',
        ),
        MarkerLayer(markers: [
          for (final marker in widget.markers)
            Marker(
              point: LatLng(marker.latitude, marker.longitude),
              width: marker.kind == MapMarkerKind.qth ? 32 : 120,
              height: marker.kind == MapMarkerKind.qth ? 32 : 46,
              alignment: marker.kind == MapMarkerKind.qth ? Alignment.center : Alignment.topCenter,
              child: marker.kind == MapMarkerKind.qth
                  ? Icon(MdiIcons.radioTower, color: marker.color, size: 28)
                  : _QsoMarker(marker: marker),
            ),
        ]),
        const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
      ],
    );
  }
}

class _QsoMarker extends StatelessWidget {
  final MapMarkerData marker;

  const _QsoMarker({required this.marker});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: [marker.label, if (marker.sublabel != null) marker.sublabel!].join(' — '),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_pin, color: marker.color, size: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              marker.label,
              style: poloMonoStyle(context, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
