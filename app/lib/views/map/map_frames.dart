// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The boxes a map pane frames with no current QSO (MapFraming): a
// continent's, the world's, and the box around a line.

import 'dart:math' as math;

import 'package:halo_core/halo_core.dart' show GridLocation;

/// A box in degrees, its longitudes unwrapped: [east] runs past 180 for a
/// box across the antimeridian, as MapZoomController.fitTo takes them.
typedef MapBox = ({double south, double west, double north, double east});

/// Each continent's box, by the DXCC data's two-letter code: its land and
/// near islands, not every far-flung entity counted to it.
const Map<String, MapBox> continentBoxes = {
  'NA': (south: 7, west: -168, north: 72, east: -52),
  'SA': (south: -56, west: -82, north: 13, east: -34),
  'EU': (south: 35, west: -25, north: 71, east: 45),
  'AF': (south: -35, west: -18, north: 38, east: 52),
  'AS': (south: -11, west: 25, north: 77, east: 190),
  'OC': (south: -48, west: 110, north: 20, east: 185),
  'AN': (south: -90, west: -180, north: -60, east: 180),
};

/// The inhabited world: the polar seas left off, where a fit would spend
/// half the pane.
const MapBox worldBox = (south: -60, west: -180, north: 75, east: 180);

/// The box MapMovement.zoomLocation frames around a QSO: some 550 km across
/// at any latitude, the region a grid square or a guessed location stands
/// for.
MapBox regionAround(GridLocation at) {
  // Degrees of latitude, each about 111 km.
  const half = 2.5;
  final halfLongitude = half / math.max(0.2, math.cos(at.latitude * math.pi / 180));
  return (
    south: math.max(-85, at.latitude - half),
    west: at.longitude - halfLongitude,
    north: math.min(85, at.latitude + half),
    east: at.longitude + halfLongitude,
  );
}

/// The box around [points], whose longitudes run on unwrapped from one to the
/// next (highlightFocus).
MapBox boxAround(List<GridLocation> points) {
  var south = 90.0, north = -90.0, west = double.infinity, east = double.negativeInfinity;
  for (final p in points) {
    if (p.latitude < south) south = p.latitude;
    if (p.latitude > north) north = p.latitude;
    if (p.longitude < west) west = p.longitude;
    if (p.longitude > east) east = p.longitude;
  }
  return (south: south, west: west, north: north, east: east);
}
