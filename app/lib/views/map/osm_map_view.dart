// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The zero-token, zero-dependency Map tab backend: OpenStreetMap raster
// tiles via flutter_map. Used automatically whenever no Mapbox token is
// configured (see map_panel.dart's facade routing), and works on every
// platform — the safety net a fresh checkout falls back to before
// MAPBOX_ACCESS_TOKEN is set in lib/config/secrets.dart. Has no globe —
// flutter_map is a 2D tile compositor, not a 3D renderer.
//
// QSOs are band-colored circles, the QTH a black one, connected by
// great-circle polylines (pre-densified by the facade); tapping a circle
// opens a callout with the QSO's details, tapping anywhere else closes it.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:latlong2/latlong.dart';

import 'map_marker_data.dart';
import 'map_popup.dart';

class OsmMapView extends StatefulWidget {
  final List<MapMarkerData> markers;
  final List<MapLineData> lines;

  const OsmMapView({super.key, required this.markers, this.lines = const []});

  @override
  State<OsmMapView> createState() => _OsmMapViewState();
}

class _OsmMapViewState extends State<OsmMapView> {
  final _mapController = MapController();
  String? _selectedMarkerId;

  @override
  void didUpdateWidget(OsmMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.markers, widget.markers)) {
      if (!widget.markers.any((m) => m.id == _selectedMarkerId)) _selectedMarkerId = null;
      // Refit only when the BASE markers change (a QSO logged), not on each
      // keystroke's highlight update — otherwise the map pans/zooms out from
      // under the operator as they type a call.
      final baseChanged = !listEquals(
        [for (final m in oldWidget.markers) if (!m.highlight) m],
        [for (final m in widget.markers) if (!m.highlight) m],
      );
      if (baseChanged) _fitCamera();
    }
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
    final selected = _selectedMarkerId == null
        ? null
        : widget.markers.where((m) => m.id == _selectedMarkerId).firstOrNull;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(48),
          maxZoom: 11,
        ),
        onTap: (_, _) => setState(() => _selectedMarkerId = null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ham2k.poloNext',
        ),
        // Base lines, then base markers, then the current QSO's highlight line
        // and marker in layers ABOVE them — flutter_map stacks children in
        // order, so the highlight paints over every base line AND marker.
        _lineLayer([for (final l in widget.lines) if (!l.highlight) l]),
        _markerLayer([for (final m in widget.markers) if (!m.highlight) m]),
        _lineLayer([for (final l in widget.lines) if (l.highlight) l]),
        _markerLayer([for (final m in widget.markers) if (m.highlight) m]),
        if (selected != null)
          MarkerLayer(markers: [
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
          ]),
        const _OsmAttribution(),
      ],
    );
  }

  PolylineLayer _lineLayer(List<MapLineData> lines) => PolylineLayer(
        // Off (default is ~0.4): the great-circle arcs are already densified
        // to a smooth curve by greatCirclePoints, and flutter_map's
        // Douglas–Peucker simplification otherwise collapses each into a few
        // straight segments — the whole point of the densified points is lost.
        simplificationTolerance: 0,
        polylines: [
          for (final line in lines)
            Polyline(
              points: [for (final p in line.points) LatLng(p.latitude, p.longitude)],
              color: line.color,
              // The current QSO's line is drawn thick so it stands out.
              strokeWidth: line.highlight ? 6 : 1.5,
            ),
        ],
      );

  MarkerLayer _markerLayer(List<MapMarkerData> markers) => MarkerLayer(markers: [
        for (final marker in markers)
          Marker(
            point: LatLng(marker.latitude, marker.longitude),
            // A generous transparent hit area around the small circle.
            width: 28 * marker.sizeFactor,
            height: 28 * marker.sizeFactor,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selectedMarkerId = marker.id),
              child: Center(child: MapCircleMarker(marker: marker)),
            ),
          ),
      ]);
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
  const _OsmAttribution();

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
              '© OpenStreetMap contributors',
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
