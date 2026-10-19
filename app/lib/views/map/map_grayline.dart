// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The grayline: the night side of the Earth at an instant, shaded over the
// map in steps — under the horizon, then past civil, nautical and
// astronomical twilight — so the band where the sun is just below the
// horizon reads as the gradient between day and full night. Computed here
// once and drawn by every backend: the GL script as one picture of the world
// (map_gl_overlays_script.dart's `setGrayline`, which says why not as a fill
// layer), flutter_map as polygons.

import 'dart:math' as math;

import 'package:flutter/painting.dart' show Color;
import 'package:halo_core/halo_core.dart' show GridLocation, Qso;

/// The sun's altitude, in degrees, at each step of the shading, the
/// shallowest first: the horizon as sunrise and sunset tables put it
/// (refraction and the sun's half-width take it 0.833° under the geometric
/// one), then the ends of civil, nautical and astronomical twilight.
const graylineSunAltitudes = [-0.833, -6.0, -12.0, -18.0];

/// How dark each step lays over the map. Each step is laid over the ones
/// before it, so full night covers 1 − (1 − this)ⁿ of the map for n steps:
/// about a third on a light basemap, half on a dark one, which needs more
/// to show at all.
double graylineStepOpacity({required bool dark}) => dark ? 0.16 : 0.1;

const graylineColor = Color(0xFF000814);

/// [utc] to the minute: what a map is handed, so that a rebuild within the
/// minute hands it an equal instant and sends the backend nothing.
DateTime graylineInstant(DateTime utc) => DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute);

/// The [graylineInstant] of the contact in [qsos] whose uuid is [selected],
/// or else of the last real contact, or null when there is none: a map of
/// contacts shades the night the one picked out was made in, and the
/// operation's last otherwise — which holds for an operation reopened long
/// after.
DateTime? graylineAtContact(Iterable<Qso> qsos, {String? selected}) {
  int? at;
  for (final q in qsos) {
    final start = q.startAtMillis;
    if (start == null) continue;
    if (selected != null && q.uuid == selected) {
      at = start;
      break;
    }
    if (q.isRealContact && (at == null || start > at)) at = start;
  }
  return at == null ? null : graylineInstant(DateTime.fromMillisecondsSinceEpoch(at, isUtc: true));
}

/// Where the sun stands overhead at [utc] — the Astronomical Almanac's
/// low-precision solar position, within a hundredth of a degree from 1950 to
/// 2050: far inside a pixel at any zoom the grayline is worth looking at.
GridLocation subsolarPoint(DateTime utc) {
  double rad(double degrees) => degrees * math.pi / 180;
  // Days since J2000.0 (2000-01-01 12:00 TT, near enough UTC here).
  final n = utc.millisecondsSinceEpoch / Duration.millisecondsPerDay - 10957.5;
  final meanAnomaly = rad(357.528 + 0.9856003 * n);
  final eclipticLongitude = rad(280.460 + 0.9856474 * n + 1.915 * math.sin(meanAnomaly) + 0.020 * math.sin(2 * meanAnomaly));
  final obliquity = rad(23.439 - 0.0000004 * n);
  final declination = math.asin(math.sin(obliquity) * math.sin(eclipticLongitude));
  final rightAscension = math.atan2(math.cos(obliquity) * math.sin(eclipticLongitude), math.cos(eclipticLongitude)) * 180 / math.pi;
  final siderealDegrees = 280.46061837 + 360.98564736629 * n;
  return GridLocation(declination * 180 / math.pi, _wrap(rightAscension - siderealDegrees));
}

/// The part of the Earth where the sun stands below each of
/// [graylineSunAltitudes] at [utc], one ring each, in the same order.
///
/// Each is a cap around the point opposite the sun. Its longitudes run on
/// without wrapping, past ±180 where it crosses that meridian; a cap that
/// holds a pole goes the whole way round and is closed along that pole, a
/// point every 90° so that a renderer that wraps each point back into ±180
/// can still tell which way it went.
List<List<GridLocation>> graylineCaps(DateTime utc) {
  final sun = subsolarPoint(utc);
  final center = GridLocation(-sun.latitude, _wrap(sun.longitude + 180));
  return [for (final altitude in graylineSunAltitudes) _cap(center, 90 + altitude)];
}

/// [graylineCaps] as the GL script's `setGrayline` takes them: each ring as
/// [longitude, latitude] pairs.
Map<String, dynamic> mapGraylinePayload(DateTime utc, {required bool dark}) => {
  'color': '#${(graylineColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
  'opacity': graylineStepOpacity(dark: dark),
  'rings': [
    for (final ring in graylineCaps(utc))
      [
        for (final p in ring) [_round(p.longitude), _round(p.latitude)],
      ],
  ],
};

/// Bearing steps around a cap's edge.
const _capSteps = 180;

List<GridLocation> _cap(GridLocation center, double radiusDegrees) {
  final lat = center.latitude * math.pi / 180;
  final r = radiusDegrees * math.pi / 180;
  final ring = <GridLocation>[];
  double? previous;
  for (var step = 0; step < _capSteps; step++) {
    final bearing = 2 * math.pi * step / _capSteps;
    final pointLat = math.asin(math.sin(lat) * math.cos(r) + math.cos(lat) * math.sin(r) * math.cos(bearing));
    final delta = math.atan2(math.sin(bearing) * math.sin(r) * math.cos(lat), math.cos(r) - math.sin(lat) * math.sin(pointLat)) * 180 / math.pi;
    var lon = center.longitude + delta;
    // Carried on from the last point rather than wrapped: see graylineCaps.
    if (previous != null) {
      while (lon - previous > 180) {
        lon -= 360;
      }
      while (lon - previous < -180) {
        lon += 360;
      }
    }
    previous = lon;
    ring.add(GridLocation(pointLat * 180 / math.pi, lon));
  }
  // Round the pole the cap holds, if it holds one: its edge never comes back
  // to the longitude it started at.
  final turned = ring.last.longitude - ring.first.longitude;
  if (turned.abs() > 180) {
    final pole = center.latitude + radiusDegrees > 90 ? 90.0 : -90.0;
    final end = ring.first.longitude + (turned > 0 ? 360 : -360);
    // Back to where the edge started, a world over, before the pole: going
    // straight up from the last point leaves out the sliver between them.
    ring.add(GridLocation(ring.first.latitude, end));
    for (var quarter = 0; quarter <= 4; quarter++) {
      ring.add(GridLocation(pole, end - (end - ring.first.longitude) * quarter / 4));
    }
  }
  return ring;
}

double _wrap(double longitude) => (longitude + 180) % 360 - 180;

double _round(double value) => (value * 1e4).roundToDouble() / 1e4;
