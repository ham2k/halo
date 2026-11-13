// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The projections a scene's maps are drawn in (docs/design/panel-scenes.md §
// Map). Each turns a place into a point in its own units — x east, y DOWN,
// north up — and back, and says how far its world reaches and where its
// seams are, which is all the outlines and the markers need.

import 'dart:math' as math;
import 'dart:ui' show Offset, Path, Rect;

import 'package:halo_core/halo_core.dart' show GridLocation;

const double _toRadians = math.pi / 180;

abstract class MapProjection {
  /// Where a place falls, or null where this projection does not draw it:
  /// past Web Mercator's poles, too near the azimuthal map's antipode.
  Offset? toMap(double latitude, double longitude);

  /// The place a point stands for, or null off the world.
  GridLocation? toEarth(double x, double y);

  /// The box the whole world lies in.
  Rect get world;

  /// The world's edge.
  Path get edge;

  /// A step between two neighbouring points of a line longer than this
  /// crosses a seam — the antimeridian, the antipode — and is not drawn.
  double get longestStep;
}

/// Azimuthal equidistant, centred on [center], scaled to a disc of radius 1
/// whose rim is the antipode: the one map on which every straight line out
/// of the centre is the great circle a beam travels along, so a heading is
/// drawn as a plain radius.
class AzimuthalProjection implements MapProjection {
  /// Points this close to the antipode, as a fraction of the way round the
  /// Earth, are not drawn: past it the projection stretches a step of a line
  /// across the rim.
  static const double antipodeCutoff = 0.97;

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
    return GridLocation(lat / _toRadians, wrapLongitude(lon / _toRadians));
  }

  @override
  Offset? toMap(double latitude, double longitude) {
    final p = project(latitude, longitude);
    return p.distance > math.pi * antipodeCutoff ? null : Offset(p.x, p.y);
  }

  @override
  GridLocation? toEarth(double x, double y) => locate(x, y);

  /// The place the whole rim stands for.
  GridLocation get antipode => GridLocation(-center.latitude, wrapLongitude(center.longitude + 180));

  @override
  Rect get world => const Rect.fromLTRB(-1, -1, 1, 1);

  @override
  Path get edge => Path()..addOval(world);

  @override
  double get longestStep => 0.25;

  @override
  bool operator ==(Object other) => other is AzimuthalProjection && other.center == center;

  @override
  int get hashCode => Object.hash(AzimuthalProjection, center);
}

/// A projection whose x is the longitude east of its [meridian] times a
/// factor of the latitude alone, so a place a turn east of another,
/// unwrapped, lands a world's breadth along the same parallel: a ring or a line that crosses
/// the antimeridian is placed in one piece, running on past the world's edge,
/// and drawn a turn west as well to fill the other side.
abstract class CylindricalProjection implements MapProjection {
  double get meridian;

  /// Where [latitude] falls [east] degrees east of [meridian], not wrapped:
  /// past ±180 it is off the world's edge. Past a cut pole it is placed
  /// beyond the world's top or bottom rather than dropped, so a ring round
  /// the pole still closes off the map.
  Offset place(double latitude, double east);
}

/// A cylindrical projection whose world is a rectangle: x is the longitude
/// east of [meridian] in radians, from -π to π, and y the latitude's alone.
/// Copies of its world side by side make one seamless strip, so a view of it
/// goes on round the world by drawing the next copy rather than turning it.
abstract class RectangularProjection implements CylindricalProjection {
  @override
  final double meridian;

  const RectangularProjection(this.meridian);

  /// How far north of the equator [latitude] falls, in radians of the
  /// equator's length: negative south of it.
  double heightOf(double latitude);

  /// The latitude at [height], the inverse of [heightOf].
  double latitudeAt(double height);

  /// The latitude the world is cut at, north and south.
  double get maxLatitude => 90;

  /// The height of the world's top edge.
  double get top => heightOf(maxLatitude);

  @override
  Offset? toMap(double latitude, double longitude) {
    if (latitude.abs() > maxLatitude) return null;
    return place(latitude, wrapLongitude(longitude - meridian));
  }

  @override
  Offset place(double latitude, double east) => Offset(east * _toRadians, -heightOf(latitude));

  @override
  GridLocation? toEarth(double x, double y) {
    if (x.abs() > math.pi || y.abs() > top) return null;
    return GridLocation(latitudeAt(-y), wrapLongitude(meridian + x / _toRadians));
  }

  @override
  Rect get world => Rect.fromLTRB(-math.pi, -top, math.pi, top);

  @override
  Path get edge => Path()..addRect(world);

  @override
  double get longestStep => math.pi;

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType && other is RectangularProjection && other.meridian == meridian;

  @override
  int get hashCode => Object.hash(runtimeType, meridian);
}

/// Web Mercator, as the web's tiled maps draw it: conformal, and cut at the
/// latitude where the world comes out square.
class MercatorProjection extends RectangularProjection {
  static const double cutLatitude = 85.0511287798;

  const MercatorProjection(super.meridian);

  @override
  double get maxLatitude => cutLatitude;

  @override
  double get top => math.pi;

  /// Held short of the poles, which are infinitely far: a ring round a pole
  /// still closes, off the world's edge.
  @override
  double heightOf(double latitude) => math.log(math.tan(math.pi / 4 + latitude.clamp(-89.5, 89.5) * _toRadians / 2));

  @override
  double latitudeAt(double height) => math.atan(_sinh(height)) / _toRadians;
}

/// Plate carrée: the latitude itself, so the world is twice as wide as it is
/// tall and every Maidenhead square of a size is the same rectangle.
class EquirectangularProjection extends RectangularProjection {
  const EquirectangularProjection(super.meridian);

  @override
  double heightOf(double latitude) => latitude * _toRadians;

  @override
  double latitudeAt(double height) => height / _toRadians;
}

/// Miller's: Mercator's look with the stretch toward the poles tempered, so
/// the poles are a finite way up and drawn.
class MillerProjection extends RectangularProjection {
  const MillerProjection(super.meridian);

  @override
  double heightOf(double latitude) => 1.25 * math.log(math.tan(math.pi / 4 + 0.4 * latitude * _toRadians));

  @override
  double latitudeAt(double height) => (2.5 * math.atan(math.exp(0.8 * height)) - 0.625 * math.pi) / _toRadians;
}

/// Patterson's, a compromise between Miller's and plate carrée that keeps
/// the high latitudes from swelling: Patterson, Šavrič and Jenny's
/// polynomial, as PROJ draws it. Its inverse has no closed form and is
/// found by Newton's method, a few steps from the latitude's own height.
class PattersonProjection extends RectangularProjection {
  static const double _k1 = 1.0148, _k2 = 0.23185, _k3 = -0.14499, _k4 = 0.02406;

  const PattersonProjection(super.meridian);

  @override
  double heightOf(double latitude) {
    final phi = latitude * _toRadians;
    final phi2 = phi * phi;
    return phi * (_k1 + phi2 * phi2 * (_k2 + phi2 * (_k3 + _k4 * phi2)));
  }

  @override
  double latitudeAt(double height) {
    var phi = height;
    for (var i = 0; i < 20; i++) {
      final phi2 = phi * phi;
      final value = phi * (_k1 + phi2 * phi2 * (_k2 + phi2 * (_k3 + _k4 * phi2)));
      final slope = _k1 + phi2 * phi2 * (5 * _k2 + phi2 * (7 * _k3 + 9 * _k4 * phi2));
      final step = (value - height) / slope;
      phi -= step;
      if (step.abs() < 1e-11) break;
    }
    return phi / _toRadians;
  }
}

/// Robinson's, for a whole world that looks like the world: neither equal
/// area nor conformal, but the shapes and sizes both near enough. Its table
/// is the one Robinson published, every 5° of latitude, read between the
/// rows as a straight line.
class RobinsonProjection implements CylindricalProjection {
  static const double _xScale = 0.8487;
  static const double _yScale = 1.3523;

  /// Each parallel's length, and its height, by 5° of latitude from the equator.
  static const List<double> _x = [
    1.0000, 0.9986, 0.9954, 0.9900, 0.9822, 0.9730, 0.9600, 0.9427, 0.9216, 0.8962, //
    0.8679, 0.8350, 0.7986, 0.7597, 0.7186, 0.6732, 0.6213, 0.5722, 0.5322,
  ];
  static const List<double> _y = [
    0.0000, 0.0620, 0.1240, 0.1860, 0.2480, 0.3100, 0.3720, 0.4340, 0.4958, 0.5571, //
    0.6176, 0.6769, 0.7346, 0.7903, 0.8435, 0.8936, 0.9394, 0.9761, 1.0000,
  ];

  @override
  final double meridian;

  const RobinsonProjection(this.meridian);

  static (double, double) _row(double latitude) {
    final at = (latitude.abs() / 5).clamp(0.0, 18.0);
    final i = math.min(at.floor(), 17);
    final t = at - i;
    return (_x[i] + (_x[i + 1] - _x[i]) * t, _y[i] + (_y[i + 1] - _y[i]) * t);
  }

  @override
  Offset? toMap(double latitude, double longitude) => place(latitude, wrapLongitude(longitude - meridian));

  @override
  Offset place(double latitude, double east) {
    final (x, y) = _row(latitude);
    return Offset(_xScale * x * east * _toRadians, -_yScale * y * latitude.sign);
  }

  /// A step along the parallel at [latitude], in degrees of longitude, for
  /// [dx] of the projection's units: what a pan turns the world by to move
  /// the place under the pointer that far.
  static double degreesAcross(double dx, {double latitude = 0}) => dx / (_xScale * _row(latitude).$1) / _toRadians;

  @override
  GridLocation? toEarth(double x, double y) {
    final height = -y / _yScale;
    if (height.abs() > 1) return null;
    var i = 0;
    while (i < 17 && _y[i + 1] < height.abs()) {
      i++;
    }
    final t = (height.abs() - _y[i]) / (_y[i + 1] - _y[i]);
    final latitude = (i + t) * 5 * height.sign;
    final (length, _) = _row(latitude);
    final lon = x / (_xScale * length);
    if (lon.abs() > math.pi) return null;
    return GridLocation(latitude, wrapLongitude(meridian + lon / _toRadians));
  }

  @override
  Rect get world => const Rect.fromLTRB(-_xScale * math.pi, -_yScale, _xScale * math.pi, _yScale);

  @override
  Path get edge {
    final path = Path();
    for (var lat = -90; lat <= 90; lat += 5) {
      final (x, y) = _row(lat.toDouble());
      final p = Offset(_xScale * x * math.pi, -_yScale * y * lat.sign);
      lat == -90 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    for (var lat = 90; lat >= -90; lat -= 5) {
      final (x, y) = _row(lat.toDouble());
      path.lineTo(-_xScale * x * math.pi, -_yScale * y * lat.sign);
    }
    return path..close();
  }

  @override
  double get longestStep => _xScale * math.pi;

  @override
  bool operator ==(Object other) => other is RobinsonProjection && other.meridian == meridian;

  @override
  int get hashCode => Object.hash(RobinsonProjection, meridian);
}

/// The heading from the centre of an azimuthal map to a point on it (any
/// scale), in degrees clockwise from north, 0–360.
double headingOf(double x, double y) => (math.atan2(x, -y) / _toRadians + 360) % 360;

/// [longitude] brought into -180 to 180.
double wrapLongitude(double longitude) => (longitude + 180) % 360 - 180;

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;

/// The great circle from [from] to [to], as places no more than [stepDeg]
/// apart along it: the shortest way round the Earth, which is how a signal
/// and a line between two stations both go.
List<GridLocation> greatCircle(GridLocation from, GridLocation to, {double stepDeg = 1}) {
  (double, double, double) unit(GridLocation p) {
    final lat = p.latitude * _toRadians, lon = p.longitude * _toRadians;
    return (math.cos(lat) * math.cos(lon), math.cos(lat) * math.sin(lon), math.sin(lat));
  }

  final (ax, ay, az) = unit(from);
  final (bx, by, bz) = unit(to);
  final angle = math.acos((ax * bx + ay * by + az * bz).clamp(-1.0, 1.0));
  final steps = math.max(1, (angle / _toRadians / stepDeg).ceil());
  final sinAngle = math.sin(angle);
  if (sinAngle < 1e-9) return [from, to];
  return [
    for (var i = 0; i <= steps; i++)
      () {
        final t = i / steps;
        final a = math.sin((1 - t) * angle) / sinAngle, b = math.sin(t * angle) / sinAngle;
        final (x, y, z) = (a * ax + b * bx, a * ay + b * by, a * az + b * bz);
        return GridLocation(math.atan2(z, math.sqrt(x * x + y * y)) / _toRadians, math.atan2(y, x) / _toRadians);
      }(),
  ];
}
