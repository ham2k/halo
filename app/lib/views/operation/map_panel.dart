// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Map tab facade: builds the backend-agnostic marker list once (every
// QSO whose lookup enrichment included a grid square, plus the operation's
// own QTH when its grid is set — nothing sets that yet, there's no
// location-editing UI in the Operation tab, but the marker is ready for
// when there is), then picks a rendering backend:
//   - iOS/Android: MapboxNativeMapView (mapbox_maps_flutter)
//   - macOS/Windows/Linux: MapboxWebviewMapView (Mapbox GL JS in a webview)
//   - Web, or no Mapbox token configured yet: OsmMapView (flutter_map/OSM),
//     the zero-token fallback every platform can render.
// Owns the mercator/globe projection toggle — OsmMapView ignores it (no
// globe support), the Mapbox backends honor it.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../config/mapbox_token.dart';
import '../map/map_marker_data.dart';
import '../map/mapbox_native_map_view.dart';
import '../map/mapbox_webview_map_view.dart';
import '../map/osm_map_view.dart';

class MapPanel extends StatefulWidget {
  final Operation operation;
  final List<Qso> qsos;

  const MapPanel({super.key, required this.operation, required this.qsos});

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> {
  MapProjection _projection = MapProjection.mercator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);

    final markers = <MapMarkerData>[
      if (gridToLocation(widget.operation.grid) case final qth?)
        MapMarkerData(
          id: 'qth',
          latitude: qth.latitude,
          longitude: qth.longitude,
          label: 'QTH',
          kind: MapMarkerKind.qth,
          color: theme.colorScheme.primary,
        ),
      for (final qso in widget.qsos)
        if (gridToLocation(qso.theirGrid) case final location?)
          MapMarkerData(
            id: qso.uuid,
            latitude: location.latitude,
            longitude: location.longitude,
            label: qso.theirCall,
            sublabel: qso.theirName,
            kind: MapMarkerKind.qso,
            color: poloColors.bandColor(qso.band),
          ),
    ];

    if (markers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No QSO locations yet.\nLookups that include a grid square will show up here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // Neither Mapbox backend covers web yet (mapbox_maps_flutter's web
    // support is prerelease-only) — TODO(map-web): revisit once it isn't.
    final usesMapbox = !kIsWeb && mapboxAccessToken.isNotEmpty;
    final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);

    final Widget map = !usesMapbox
        ? OsmMapView(markers: markers)
        : isMobile
            ? MapboxNativeMapView(markers: markers, projection: _projection)
            : MapboxWebviewMapView(markers: markers, projection: _projection);

    return Stack(
      children: [
        Positioned.fill(child: map),
        if (usesMapbox)
          Positioned(
            top: 8,
            right: 8,
            child: SegmentedButton<MapProjection>(
              segments: const [
                ButtonSegment(value: MapProjection.mercator, icon: Icon(Icons.map_outlined), label: Text('Flat')),
                ButtonSegment(value: MapProjection.globe, icon: Icon(Icons.public), label: Text('Globe')),
              ],
              selected: {_projection},
              onSelectionChanged: (selection) => setState(() => _projection = selection.first),
            ),
          ),
      ],
    );
  }
}
