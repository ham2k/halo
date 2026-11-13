// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The world a scene's maps draw: its land and borders, and the shapes they
// and the night make in any projection (map_projection.dart), as paths in
// the projection's own units — sharp at any zoom, and drawn the moment a
// view moves.
//
// A ring is filled in even-odd, every ring at once, so a lake's ring cuts its
// hole in the land round it. On the azimuthal map the whole rim is ONE
// point, the antipode, and a ring round it (New Zealand from Spain, China
// from Argentina) projects inside out: its inside on Earth is its outside on
// the disc. Filling the rim too whenever the antipode is inside turns it back,
// with no clipping on the sphere.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Path, PathFillType;

import 'map_projection.dart';

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
}

/// Whether [rings] hold the place at [latitude], [longitude], in even-odd: a
/// lake is not land. Each ring is also laid a turn west and a turn east: a
/// ring that crosses the antimeridian runs on past ±180 in one piece, and
/// its far side belongs at the other edge.
bool ringsHold(List<Float32List> rings, double latitude, double longitude) {
  final lon = wrapLongitude(longitude);
  var crossings = 0;
  for (final ring in rings) {
    for (var i = 0; i + 3 < ring.length; i += 2) {
      final y1 = ring[i + 1];
      final y2 = ring[i + 3];
      if ((y1 <= latitude) == (y2 <= latitude)) continue;
      final x1 = ring[i];
      final x = x1 + (latitude - y1) * (ring[i + 2] - x1) / (y2 - y1);
      if (x < lon) crossings++;
      if (x - 360 < lon) crossings++;
      if (x + 360 < lon) crossings++;
    }
  }
  return crossings.isOdd;
}

/// How far past the azimuthal map's rim a shape round the antipode is
/// filled, as a share of the disc: the rim clips it, and a blurred fill that
/// ended at the rim would fade there, where the antipode is.
const double _pastRim = 0.1;

/// What [rings] enclose, in [projection]'s units, filled even-odd.
Path fillRings(MapProjection projection, List<Float32List> rings) {
  switch (projection) {
    case final CylindricalProjection cylinder:
      return TurningShapes.rings(cylinder, rings).fill(cylinder.meridian);
    case final AzimuthalProjection disc:
      final path = Path()..fillType = PathFillType.evenOdd;
      for (final ring in rings) {
        if (ring.length < 6) continue;
        final points = <Offset>[];
        for (var i = 0; i + 1 < ring.length; i += 2) {
          final next = (i + 2) % ring.length;
          _alongDisc(disc, ring[i + 1], ring[i], ring[next + 1], ring[next], points, 0);
        }
        path.addPolygon(points, true);
      }
      final antipode = disc.antipode;
      if (ringsHold(rings, antipode.latitude, antipode.longitude)) path.addOval(disc.world.inflate(_pastRim));
      return path;
    default:
      throw UnsupportedError('No fill for ${projection.runtimeType}');
  }
}

/// Rings or lines made ready for a cylindrical projection at any meridian.
/// Its x is the longitude east of the meridian times a factor of the
/// latitude alone, so each point's factor and height are worked out once,
/// with its longitude east of its piece's first, carried on unwrapped; a
/// turn of the projection then places each point with one multiply. A
/// Robinson map turns on every frame of a pan, and placing every outline and
/// line again from its latitude each time costs that frame several times as
/// much.
class TurningShapes {
  /// The projection's type: one meridian of it is as good as another.
  final Type family;
  final List<_Piece> _pieces;
  final bool _closed;

  TurningShapes._(this.family, this._pieces, this._closed);

  /// [rings] as closed shapes: each runs on past ±180 in one piece, as the
  /// outlines and the night's caps are laid out.
  factory TurningShapes.rings(CylindricalProjection projection, List<Float32List> rings) => TurningShapes._(projection.runtimeType, [
    for (final ring in rings)
      if (ring.length >= 6) _Piece.of(projection, ring, 0, ring.length ~/ 2, wrapSteps: false),
  ], true);

  /// [lines] as open ones, broken at a pole, where a land ring's only points
  /// are the cut that closes Antarctica, and each step taken the short way
  /// round, so a line across the antimeridian runs on past it.
  factory TurningShapes.lines(CylindricalProjection projection, List<Float32List> lines) {
    final pieces = <_Piece>[];
    for (final line in lines) {
      var start = -1;
      final count = line.length ~/ 2;
      for (var i = 0; i <= count; i++) {
        final atPole = i == count || line[i * 2 + 1].abs() >= 89.99;
        if (atPole) {
          if (start >= 0) pieces.add(_Piece.of(projection, line, start, i, wrapSteps: true));
          start = -1;
        } else if (start < 0) {
          start = i;
        }
      }
    }
    return TurningShapes._(projection.runtimeType, pieces, false);
  }

  /// Each piece at [meridian], once where it lies and again a turn the other
  /// way where it runs on past an edge, to reach in from the far one.
  List<List<Offset>> runs(double meridian) => [
    for (final piece in _pieces)
      for (final turn in piece.turns(meridian)) piece.at(meridian, turn),
  ];

  /// The rings at [meridian], filled even-odd.
  Path fill(double meridian) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final run in runs(meridian)) {
      path.addPolygon(run, _closed);
    }
    return path;
  }

  /// The lines at [meridian].
  Path stroke(double meridian) {
    final path = Path();
    for (final run in runs(meridian)) {
      path.addPolygon(run, false);
    }
    return path;
  }
}

class _Piece {
  final double firstLon, low, high;
  final Float64List factor, height, east;

  _Piece(this.firstLon, this.low, this.high, this.factor, this.height, this.east);

  /// Points [from] to [to] of [line]. [wrapSteps] takes each step the short
  /// way round; a ring's own longitudes already run on unwrapped.
  factory _Piece.of(CylindricalProjection projection, Float32List line, int from, int to, {required bool wrapSteps}) {
    final n = to - from;
    final factor = Float64List(n), height = Float64List(n), east = Float64List(n);
    var low = 0.0, high = 0.0;
    for (var k = 0; k < n; k++) {
      final i = from + k;
      final lat = line[i * 2 + 1].toDouble();
      final zero = projection.place(lat, 0);
      factor[k] = projection.place(lat, 1).dx - zero.dx;
      height[k] = zero.dy;
      if (k > 0) {
        final step = line[i * 2] - line[i * 2 - 2];
        east[k] = east[k - 1] + (wrapSteps ? wrapLongitude(step) : step);
        low = math.min(low, east[k]);
        high = math.max(high, east[k]);
      }
    }
    return _Piece(line[from * 2].toDouble(), low, high, factor, height, east);
  }

  double _start(double meridian) => wrapLongitude(firstLon - meridian);

  Iterable<double> turns(double meridian) {
    final start = _start(meridian);
    return [0.0, if (start + high > 180) -360.0, if (start + low < -180) 360.0];
  }

  List<Offset> at(double meridian, double turn) {
    final start = _start(meridian) + turn;
    return [for (var k = 0; k < east.length; k++) Offset(factor[k] * (start + east[k]), height[k])];
  }
}

/// The step from one point of a ring to the next on the disc, split until no
/// piece is long: near the antipode a short step on Earth sweeps round the
/// rim, and drawn straight it would cut across the map.
void _alongDisc(AzimuthalProjection disc, double lat1, double lon1, double lat2, double lon2, List<Offset> out, int depth) {
  final a = disc.project(lat1, lon1);
  if (depth == 0) out.add(Offset(a.x, a.y));
  final b = disc.project(lat2, lon2);
  if (depth >= 10 || ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)) < 0.02 * 0.02) return;
  final lat = (lat1 + lat2) / 2, lon = (lon1 + lon2) / 2;
  _alongDisc(disc, lat1, lon1, lat, lon, out, depth + 1);
  final m = disc.project(lat, lon);
  out.add(Offset(m.x, m.y));
  _alongDisc(disc, lat, lon, lat2, lon2, out, depth + 1);
}
