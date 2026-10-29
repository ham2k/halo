// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rotator map's geometry. Its projection is azimuthal equidistant, the
// one map on which every straight line out of the centre is the great circle
// a beam travels along, so a heading is drawn as a plain radius and a tap's
// angle from the centre IS the heading to turn to.
//
// Land and night are filled by asking each pixel where on Earth it is,
// rather than by projecting polygons: the projection's whole rim is ONE
// point, the antipode, and a polygon around it (New Zealand from Spain, China
// from Argentina) projects inside out. Clipping polygons on the sphere is a
// library's worth of code; a pixel lookup has no such case. Only the outlines
// are drawn as lines, and a line only has to be broken where it crosses
// near the antipode.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show GridLocation;

import '../../map/map_grayline.dart' show graylineSunAltitudes, subsolarPoint;

const double _toRadians = math.pi / 180;

/// The map, centred on [center], scaled to a disc of radius 1 whose rim is
/// the antipode. Screen-oriented: x to the east, y DOWN, north up.
class AzimuthalProjection {
  final GridLocation center;
  final double _lon0;
  final double _sinLat0;
  final double _cosLat0;

  AzimuthalProjection(this.center)
    : _lon0 = center.longitude * _toRadians,
      _sinLat0 = math.sin(center.latitude * _toRadians),
      _cosLat0 = math.cos(center.latitude * _toRadians);

  /// Where [latitude], [longitude] fall on the disc, and how far round the
  /// Earth they are from the centre, in radians (π at the antipode).
  ({double x, double y, double distance}) project(double latitude, double longitude) {
    final lat = latitude * _toRadians;
    final dLon = longitude * _toRadians - _lon0;
    final sinLat = math.sin(lat);
    final cosLat = math.cos(lat);
    final cosDLon = math.cos(dLon);
    final distance = math.acos((_sinLat0 * sinLat + _cosLat0 * cosLat * cosDLon).clamp(-1.0, 1.0));
    final bearing = math.atan2(math.sin(dLon) * cosLat, _cosLat0 * sinLat - _sinLat0 * cosLat * cosDLon);
    final r = distance / math.pi;
    return (x: r * math.sin(bearing), y: -r * math.cos(bearing), distance: distance);
  }

  /// The place a point on the disc stands for, or null outside it.
  GridLocation? locate(double x, double y) {
    final r = math.sqrt(x * x + y * y);
    if (r > 1) return null;
    final c = r * math.pi;
    final bearing = math.atan2(x, -y);
    final sinC = math.sin(c);
    final cosC = math.cos(c);
    final lat = math.asin((_sinLat0 * cosC + _cosLat0 * sinC * math.cos(bearing)).clamp(-1.0, 1.0));
    final lon = _lon0 + math.atan2(math.sin(bearing) * sinC * _cosLat0, cosC - _sinLat0 * math.sin(lat));
    return GridLocation(lat / _toRadians, _wrap(lon / _toRadians));
  }
}

/// The heading from the centre to a point on the disc (any scale), in
/// degrees clockwise from north, 0–360.
double headingOf(double x, double y) => (math.atan2(x, -y) / _toRadians + 360) % 360;

/// Natural Earth's land and borders, as `assets/geo/world-110m.json` holds
/// them — see scripts/world-outlines.py for the shape, and why a ring can
/// reach past +180.
class WorldOutlines {
  /// Each ring as flat longitude, latitude pairs, in degrees.
  final List<Float32List> land;
  final List<Float32List> borders;

  WorldOutlines({required this.land, required this.borders});

  factory WorldOutlines.fromJson(Map<String, dynamic> json) {
    List<Float32List> lines(Object? value) => [
      for (final line in (value as List<dynamic>? ?? const []).cast<List<dynamic>>()) Float32List.fromList([for (final v in line) (v as num) / 100]),
    ];
    return WorldOutlines(land: lines(json['land']), borders: lines(json['borders']));
  }

  late final LandMask mask = LandMask.fill(land);
}

/// Which quarter-degree cells of the world are land, filled from the land
/// rings on a flat longitude/latitude grid — where, unlike on the disc, a
/// polygon is just a polygon.
class LandMask {
  static const int cellsPerDegree = 4;
  static const int columns = 360 * cellsPerDegree;
  static const int rows = 180 * cellsPerDegree;

  /// Row-major from the north pole and from -180: 1 for land.
  final Uint8List cells;

  LandMask._(this.cells);

  /// Even-odd across every ring at once, so a lake's ring cuts its hole in
  /// the land around it. Each ring is also laid one turn west: a ring that
  /// crosses the antimeridian runs on past +180, and its far side belongs
  /// at the west edge of the grid.
  factory LandMask.fill(List<Float32List> rings) {
    final cells = Uint8List(columns * rows);
    final crossings = <double>[];
    for (var row = 0; row < rows; row++) {
      final lat = 90 - (row + 0.5) / cellsPerDegree;
      crossings.clear();
      for (final ring in rings) {
        for (var i = 0; i + 3 < ring.length; i += 2) {
          final y1 = ring[i + 1];
          final y2 = ring[i + 3];
          if ((y1 <= lat) == (y2 <= lat)) continue;
          final x1 = ring[i];
          final x = x1 + (lat - y1) * (ring[i + 2] - x1) / (y2 - y1);
          crossings
            ..add(x)
            ..add(x - 360);
        }
      }
      crossings.sort();
      for (var i = 0; i + 1 < crossings.length; i += 2) {
        final from = ((crossings[i] + 180) * cellsPerDegree).round().clamp(0, columns);
        final to = ((crossings[i + 1] + 180) * cellsPerDegree).round().clamp(0, columns);
        cells.fillRange(row * columns + from, row * columns + to, 1);
      }
    }
    return LandMask._(cells);
  }

  bool isLand(double latitude, double longitude) {
    final row = ((90 - latitude) * cellsPerDegree).floor().clamp(0, rows - 1);
    final column = ((_wrap(longitude) + 180) * cellsPerDegree).floor().clamp(0, columns - 1);
    return cells[row * columns + column] == 1;
  }
}

/// The disc as a square of pixels: which are land and which sea, and where
/// on Earth each one is, kept so the night can be laid over it again each
/// minute without projecting anything.
class DiscRaster {
  final int size;

  /// Per pixel: 0 off the disc, 1 sea, 2 land.
  final Uint8List _surface;

  /// Per pixel, the place as a unit vector — what the sun's altitude there
  /// is a dot product with.
  final Float32List _points;

  DiscRaster._(this.size, this._surface, this._points);

  factory DiscRaster(AzimuthalProjection projection, LandMask mask, int size) {
    final surface = Uint8List(size * size);
    final points = Float32List(size * size * 3);
    final half = size / 2;
    for (var py = 0; py < size; py++) {
      for (var px = 0; px < size; px++) {
        final place = projection.locate((px + 0.5 - half) / half, (py + 0.5 - half) / half);
        if (place == null) continue;
        final i = py * size + px;
        surface[i] = mask.isLand(place.latitude, place.longitude) ? 2 : 1;
        final lat = place.latitude * _toRadians;
        final lon = place.longitude * _toRadians;
        points[i * 3] = math.cos(lat) * math.cos(lon);
        points[i * 3 + 1] = math.cos(lat) * math.sin(lon);
        points[i * 3 + 2] = math.sin(lat);
      }
    }
    return DiscRaster._(size, surface, points);
  }

  /// RGBA bytes: [sea] and [land] (0xAARRGGBB), each darkened toward [night]
  /// by [nightStep] for every one of [graylineSunAltitudes] the sun is below
  /// at [utc] — the Map tab's grayline steps. A null [utc] draws no night.
  Uint8List pixels({required int sea, required int land, required int night, required double nightStep, DateTime? utc}) {
    final steps = graylineSunAltitudes.length;
    // Each surface's colour after 0…steps layers of night.
    final shades = [
      for (final base in [0, sea, land]) [for (var n = 0; n <= steps; n++) _darken(base, night, 1 - math.pow(1 - nightStep, n).toDouble())],
    ];
    final thresholds = [for (final altitude in graylineSunAltitudes) math.sin(altitude * _toRadians)];
    final sun = utc == null ? null : subsolarPoint(utc);
    final sx = sun == null ? 0.0 : math.cos(sun.latitude * _toRadians) * math.cos(sun.longitude * _toRadians);
    final sy = sun == null ? 0.0 : math.cos(sun.latitude * _toRadians) * math.sin(sun.longitude * _toRadians);
    final sz = sun == null ? 0.0 : math.sin(sun.latitude * _toRadians);

    final out = Uint8List(size * size * 4);
    for (var i = 0; i < size * size; i++) {
      final kind = _surface[i];
      if (kind == 0) continue;
      var n = 0;
      if (sun != null) {
        final altitude = _points[i * 3] * sx + _points[i * 3 + 1] * sy + _points[i * 3 + 2] * sz;
        while (n < steps && altitude < thresholds[n]) {
          n++;
        }
      }
      final color = shades[kind][n];
      out[i * 4] = (color >> 16) & 0xFF;
      out[i * 4 + 1] = (color >> 8) & 0xFF;
      out[i * 4 + 2] = color & 0xFF;
      out[i * 4 + 3] = 0xFF;
    }
    return out;
  }
}

int _darken(int color, int toward, double amount) {
  int channel(int shift) {
    final from = (color >> shift) & 0xFF;
    final to = (toward >> shift) & 0xFF;
    return (from + (to - from) * amount).round() & 0xFF;
  }

  return 0xFF000000 | channel(16) << 16 | channel(8) << 8 | channel(0);
}

double _wrap(double longitude) => (longitude + 180) % 360 - 180;
