// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where a `map` control's view sits over its projection: how far it is
// zoomed, what is in its middle, and how far a pan may take it
// (docs/design/panel-scenes.md § Map).

import 'dart:math' as math;
import 'dart:ui';

import 'package:halo_core/halo_core.dart' show GridLocation;

import 'map_projection.dart';

/// One view of a projection in a pane: built per layout, zoom and pan, and
/// asked where things are by everything that draws or hit-tests the map.
class MapCamera {
  final Size size;
  final MapProjection projection;

  /// 0 fits the whole world in the pane; each step closer doubles the scale.
  final double zoom;

  /// The point of the projection in the pane's middle, after the limits.
  final Offset center;

  /// Pixels per unit of the projection.
  final double scale;

  /// Whether the world repeats east and west, a copy beside each edge, so a
  /// pan goes on round it rather than stopping at the antimeridian.
  final bool wraps;

  MapCamera._(this.size, this.projection, this.zoom, this.center, this.scale, this.wraps);

  /// [center] is where the view was asked to be. It stays inside [bounds]
  /// (the whole world when null), as far as keeps the view over them; a
  /// view wider than the bounds sits at their middle. A camera that [wraps]
  /// holds only the north and south, and brings the middle back into the
  /// world the same place a world's breadth away. One that [cover]s, on a
  /// world whose edge is a curve and with no bounds, draws the middle in
  /// toward the world's own until every corner of the pane is on the world;
  /// zoomed out past [coverZoom], it sits at the world's middle. On a curved
  /// world with no bounds, the middle itself stays on the world.
  factory MapCamera(
    Size size,
    MapProjection projection, {
    required double zoom,
    required Offset center,
    Rect? bounds,
    bool wraps = false,
    bool cover = false,
    double margin = 2,
  }) {
    final world = projection.world;
    final scale = _fit(size, world, margin) * math.pow(2, zoom);
    if (scale <= 0) return MapCamera._(size, projection, zoom, center, scale, wraps);
    final limit = bounds ?? world;
    final halfW = size.width / 2 / scale, halfH = size.height / 2 / scale;
    if (cover && bounds == null && projection is! RectangularProjection) {
      return MapCamera._(size, projection, zoom, _drawnIn(projection, center, halfW, halfH), scale, wraps);
    }
    double hold(double c, double half, double lo, double hi) => hi - lo <= 2 * half ? (lo + hi) / 2 : c.clamp(lo + half, hi - half);
    final x = wraps ? world.left + (center.dx - world.left) % world.width : hold(center.dx, halfW, limit.left, limit.right);
    var held = Offset(x, hold(center.dy, halfH, limit.top, limit.bottom));
    // A curved world fills its box only in part: held to the box alone, the
    // middle can come to rest past the edge, off the world, where it names
    // no place for the scene to keep.
    if (bounds == null && projection is! RectangularProjection) held = _drawnIn(projection, held, 0, 0);
    return MapCamera._(size, projection, zoom, held, scale, wraps);
  }

  static double _fit(Size size, Rect world, double margin) =>
      math.max(0.0, math.min((size.width - 2 * margin) / world.width, (size.height - 2 * margin) / world.height));

  /// The least zoom at which a view that covers shows nothing past the
  /// world's edge, or past [bounds]: the pane's full height of the world
  /// when it [wraps], the box's height and breadth otherwise, and on a
  /// world with a curved edge the largest view of the pane's shape that
  /// fits inside it, about the world's middle.
  static double coverZoom(Size size, MapProjection projection, {Rect? bounds, bool wraps = false, double margin = 2}) {
    final fit = _fit(size, projection.world, margin);
    if (fit <= 0) return 0;
    double need;
    if (bounds != null || projection is RectangularProjection) {
      final limit = bounds ?? projection.world;
      need = math.max(wraps ? 0.0 : size.width / limit.width, size.height / limit.height);
    } else {
      // Every view about the middle that fits is inside every larger one
      // that fits, so the least scale that fits is found by halving.
      var lo = fit, hi = fit * math.pow(2, 16);
      for (var i = 0; i < 30; i++) {
        final mid = math.sqrt(lo * hi);
        _onWorld(projection, Offset.zero, size.width / 2 / mid, size.height / 2 / mid) ? hi = mid : lo = mid;
      }
      need = hi;
    }
    return math.max(0.0, math.log(need / fit) / math.ln2);
  }

  /// Whether a view [halfW] by [halfH] either side of [center] lies on the
  /// world: its middle, its corners and the middles of its sides, which is
  /// enough on the convex worlds a curved edge bounds.
  static bool _onWorld(MapProjection projection, Offset center, double halfW, double halfH) {
    for (final dx in [-halfW, 0.0, halfW]) {
      for (final dy in [-halfH, 0.0, halfH]) {
        if (projection.toEarth(center.dx + dx, center.dy + dy) == null) return false;
      }
    }
    return true;
  }

  /// [center], or the point nearest it toward the world's middle whose view
  /// lies on the world. Those points make a convex set round the middle, so
  /// the way in is found by halving.
  static Offset _drawnIn(MapProjection projection, Offset center, double halfW, double halfH) {
    if (_onWorld(projection, center, halfW, halfH)) return center;
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 24; i++) {
      final t = (lo + hi) / 2;
      _onWorld(projection, center * t, halfW, halfH) ? lo = t : hi = t;
    }
    return center * lo;
  }

  Offset get middle => size.center(Offset.zero);

  Offset toScreen(Offset point) => middle + (point - center) * scale;

  Offset toMap(Offset screen) => center + (screen - middle) / scale;

  /// Where the projection's point (0, 0) falls on screen.
  Offset get origin => toScreen(Offset.zero);

  /// The stretch of the projection in the pane.
  Rect get visible => Rect.fromCenter(center: center, width: size.width / scale, height: size.height / scale);

  /// How far east, in the projection's units, each copy of the world in the
  /// pane lies: the world itself alone unless the camera [wraps].
  List<double> get copies => copiesWithin(0);

  /// [copies], and those whose world lies within [padding] pixels of the
  /// pane's sides: a marker on the edge of one reaches into the pane.
  List<double> copiesWithin(double padding) {
    if (!wraps) return const [0];
    final world = projection.world, view = visible.inflate(padding / scale);
    final first = ((view.left - world.left) / world.width).floor();
    final last = ((view.right - world.left) / world.width).floor();
    return [for (var k = first; k <= last; k++) k * world.width];
  }

  /// [point], a world's breadth at a time, into the world itself.
  Offset intoWorld(Offset point) {
    if (!wraps) return point;
    final world = projection.world;
    return Offset(world.left + (point.dx - world.left) % world.width, point.dy);
  }

  /// The place under the pane's [screen] point, or null off the world.
  GridLocation? placeAt(Offset screen) {
    final p = intoWorld(toMap(screen));
    return projection.toEarth(p.dx, p.dy);
  }

  /// The zoom and center that keep the projection's point [at] under the
  /// pane's [screen] point while the scale goes to [zoom].
  Offset centerKeeping(Offset at, Offset screen, double zoom) {
    final next = scale * math.pow(2, zoom - this.zoom);
    return at - (screen - middle) / next;
  }
}

/// The box a pan's bounds, in latitude and longitude, make in [projection]:
/// the box round the points of their edges, since a parallel or a meridian
/// is a curve in some projections. An [east] less than [west] crosses the
/// antimeridian. On a cylindrical projection the points are placed east of
/// its meridian without wrapping: wrapped, bounds the whole way round put
/// their east edge on their west one, and the box loses its last step.
Rect projectedBounds(MapProjection projection, {required double north, required double south, required double west, required double east}) {
  final span = east >= west ? east - west : east + 360 - west;
  final from = projection is CylindricalProjection ? wrapLongitude(west - projection.meridian) : 0.0;
  Offset? at(double lat, double lon) => switch (projection) {
    final RectangularProjection r => r.place(lat.clamp(-r.maxLatitude, r.maxLatitude).toDouble(), from + lon - west),
    final CylindricalProjection c => c.place(lat, from + lon - west),
    _ => projection.toMap(lat, lon),
  };
  Rect? box;
  const steps = 16;
  for (var i = 0; i <= steps; i++) {
    for (var j = 0; j <= steps; j++) {
      if (i != 0 && i != steps && j != 0 && j != steps) continue;
      final p = at(south + (north - south) * i / steps, west + span * j / steps);
      if (p == null) continue;
      box = box == null ? Rect.fromPoints(p, p) : box.expandToInclude(Rect.fromPoints(p, p));
    }
  }
  return box ?? projection.world;
}
