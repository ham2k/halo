// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Great-circle math and QSO location resolution for the Map tab — the Dart
// ports of @ham2k/lib-geo-tools' distanceOnEarth/fmtDistance/
// locationForQSONInfo and app-polo's geodesic line interpolation
// (MapboxMapWithQSOs' _generateGeodesicPoints), kept in core Dart for the
// same reason as grid.dart: the map is core UI, not extension territory.

import 'dart:math';

import 'entity_locations.dart';
import 'grid.dart';

const _earthRadiusKm = 6371.0;

/// For unit conversion by display code — formatting (separators, unit
/// labels) is the app layer's job, where locale and i18n live.
const kmPerMile = 1.609344;

double _deg2rad(double deg) => deg * pi / 180;

/// Haversine distance between two points, in kilometers.
double distanceOnEarthKm(GridLocation a, GridLocation b) {
  final lat1 = _deg2rad(a.latitude);
  final lon1 = _deg2rad(a.longitude);
  final lat2 = _deg2rad(b.latitude);
  final lon2 = _deg2rad(b.longitude);
  final sinLat = sin((lat2 - lat1) / 2);
  final sinLon = sin((lon2 - lon1) / 2);
  final h = sinLat * sinLat + cos(lat1) * cos(lat2) * sinLon * sinLon;
  return _earthRadiusKm * 2 * atan2(sqrt(h), sqrt(1 - h));
}

/// Initial great-circle bearing from [from] to [to], in degrees clockwise
/// from true north (0–360). The port of @ham2k/lib-geo-tools' bearingForQSON,
/// used by the logging panel's call-info line when the "show bearing" setting
/// is on.
double bearingOnEarthDeg(GridLocation from, GridLocation to) {
  final lat1 = _deg2rad(from.latitude);
  final lat2 = _deg2rad(to.latitude);
  final dLon = _deg2rad(to.longitude - from.longitude);
  final y = sin(dLon) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
  final deg = atan2(y, x) * 180 / pi;
  return (deg + 360) % 360;
}

// Placeholder grids some sources emit when they have no real location —
// never worth a marker (same skip-list as locationForQSONInfo).
const _placeholderGrids = {'AA00', 'AA00AA'};

/// Which fallback [locationForQsoInfoWithSource] used — a `grid` fix is exact;
/// `region` (state/province centroid) and `entity` (DXCC centroid) are coarse,
/// so display code can mark them approximate or suppress the least precise.
enum QsoLocationSource { grid, region, entity }

/// Resolves the best-available coordinates for one end of a QSO, in the same
/// priority order as app-polo's map: an actual grid square, else the
/// state/province centroid for `entityPrefix`+`state` (US/Canada/Australia),
/// else the DXCC entity centroid for `entityPrefix`, else null. Also reports
/// which source produced the location.
({GridLocation location, QsoLocationSource source})? locationForQsoInfoWithSource({
  String? grid,
  String? entityPrefix,
  String? state,
}) {
  if (grid != null && !_placeholderGrids.contains(grid.toUpperCase())) {
    if (gridToLocation(grid) case final location?) {
      return (location: location, source: QsoLocationSource.grid);
    }
  }
  if (entityPrefix == null || entityPrefix.isEmpty) return null;
  final region = state?.trim().toUpperCase();
  if (region != null && region.isNotEmpty) {
    if (entityRegionLocations['$entityPrefix-$region'] case final location?) {
      return (location: location, source: QsoLocationSource.region);
    }
  }
  if (entityLocations[entityPrefix] case final location?) {
    return (location: location, source: QsoLocationSource.entity);
  }
  return null;
}

/// The location alone (see [locationForQsoInfoWithSource]) — kept for callers
/// (e.g. the map) that don't need the source.
GridLocation? locationForQsoInfo({String? grid, String? entityPrefix, String? state}) =>
    locationForQsoInfoWithSource(grid: grid, entityPrefix: entityPrefix, state: state)?.location;

/// Points along the great circle from [start] to [end], split into multiple
/// polylines where the arc crosses the antimeridian (so a 2D map doesn't
/// draw a line smeared across the whole world). Each inner list is one
/// contiguous polyline. Returns an empty list for (near-)zero-length arcs.
List<List<GridLocation>> greatCirclePoints(GridLocation start, GridLocation end, {int numPoints = 100}) {
  final lam1 = _deg2rad(start.longitude);
  final phi1 = _deg2rad(start.latitude);
  final lam2 = _deg2rad(end.longitude);
  final phi2 = _deg2rad(end.latitude);

  // Angular distance (haversine, on the unit sphere).
  final d = 2 *
      asin(sqrt(pow(sin((phi2 - phi1) / 2), 2) + cos(phi1) * cos(phi2) * pow(sin((lam2 - lam1) / 2), 2)));
  if (d < 1e-9) return const [];
  // (Near-)antipodal endpoints have no unique great-circle path, and the
  // slerp below divides by sin(d) ≈ 0, producing garbage points smeared
  // across the map — skip the line rather than draw nonsense.
  if (pi - d < 1e-6) return const [];

  // Spherical interpolation at fraction f of the way along the arc.
  GridLocation pointAt(double f) {
    final a = sin((1 - f) * d) / sin(d);
    final b = sin(f * d) / sin(d);
    final x = a * cos(phi1) * cos(lam1) + b * cos(phi2) * cos(lam2);
    final y = a * cos(phi1) * sin(lam1) + b * cos(phi2) * sin(lam2);
    final z = a * sin(phi1) + b * sin(phi2);
    final lon = (atan2(y, x) * 180 / pi + 540) % 360 - 180;
    final lat = atan2(z, sqrt(x * x + y * y)) * 180 / pi;
    return GridLocation(lat, lon);
  }

  final segments = <List<GridLocation>>[[]];
  GridLocation? prev;

  for (var i = 0; i <= numPoints; i++) {
    final point = pointAt(i / numPoints);

    if (prev != null && (point.longitude - prev.longitude).abs() > 180) {
      // The arc jumped across the ±180° antimeridian between this point and
      // the previous one. Adjacent samples are ≤ ~2° of arc apart, so
      // latitude is effectively linear between them: interpolate the
      // crossing latitude by each point's longitude-distance to the
      // meridian, close the current polyline at the edge, and start a new
      // one on the other side.
      final prevGap = 180 - prev.longitude.abs();
      final gapSum = prevGap + (180 - point.longitude.abs());
      final f = gapSum == 0 ? 0.5 : prevGap / gapSum;
      final crossingLat = prev.latitude + (point.latitude - prev.latitude) * f;
      final exitLon = prev.longitude < 0 ? -180.0 : 180.0;
      segments.last.add(GridLocation(crossingLat, exitLon));
      segments.add([GridLocation(crossingLat, -exitLon)]);
    }

    segments.last.add(point);
    prev = point;
  }
  return segments;
}
