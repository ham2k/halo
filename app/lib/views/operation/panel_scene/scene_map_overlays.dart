// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A map scene's images, laid on the world: each spread over a grid by its
// corners and placed again in each projection, as triangles a texture
// covers.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Offset;

import '../world_map/map_projection.dart';
import 'scene_model.dart';

/// How finely an overlay is laid: a grid this many cells a side, each
/// placed by its corners — fine enough that a picture bent round a pole
/// follows the projection rather than cutting corners.
const _overlayGrid = 32;

/// How many times over a cell at the disc's rim is halved, at most, to
/// follow the rim rather than leave the whole cell out.
const _rimSplits = 5;

/// A map image's four corners, top left, top right, bottom right, bottom left.
typedef OverlayCorners = (({double lat, double lon}), ({double lat, double lon}), ({double lat, double lon}), ({double lat, double lon}));

OverlayCorners overlayCornersOf(SceneMapOverlay o) => (o.corners[0], o.corners[1], o.corners[2], o.corners[3]);

/// A map image spread over its grid: points falling evenly in latitude and
/// longitude between its [corners], its texture the picture's as the unit
/// square. Made once for its corners, and placed again in each projection.
class OverlaySheet {
  final OverlayCorners corners;
  final List<double> _lats, _lons;
  final List<(double, double)> _at;
  final Float32List _uv;
  final Uint16List _cells;

  factory OverlaySheet(OverlayCorners corners) {
    const n = _overlayGrid;
    final (c0, c1, c2, c3) = corners;
    // Longitudes carried on from the top left's, so a picture across the
    // antimeridian is one piece: the right edge east of the left, however far
    // — a picture of the whole world runs from -180 to 180 — and the bottom
    // left the nearest way from the top left.
    double eastOf(double from, double lon) {
      final step = (lon - from) % 360;
      return from + (step == 0 && lon != from ? 360 : step);
    }

    final lats = [c0.lat, c1.lat, c2.lat, c3.lat];
    final bottomLeft = c0.lon + wrapLongitude(c3.lon - c0.lon);
    final lons = [c0.lon, eastOf(c0.lon, c1.lon), eastOf(bottomLeft, c2.lon), bottomLeft];
    final at = <(double, double)>[];
    final uv = Float32List(2 * (n + 1) * (n + 1));
    for (var j = 0; j <= n; j++) {
      for (var i = 0; i <= n; i++) {
        at.add(_mix(lats, lons, i / n, j / n));
        uv[2 * (j * (n + 1) + i)] = i / n;
        uv[2 * (j * (n + 1) + i) + 1] = j / n;
      }
    }
    final cells = Uint16List(n * n * 6);
    var k = 0;
    for (var j = 0; j < n; j++) {
      for (var i = 0; i < n; i++) {
        final top = j * (n + 1) + i, bottom = top + n + 1;
        cells.setAll(k, [top, top + 1, bottom, top + 1, bottom + 1, bottom]);
        k += 6;
      }
    }
    return OverlaySheet._(corners, lats, lons, at, uv, cells);
  }

  OverlaySheet._(this.corners, this._lats, this._lons, this._at, this._uv, this._cells);

  /// The latitude and longitude at [u], [v] of the picture.
  static (double, double) _mix(List<double> lats, List<double> lons, double u, double v) {
    double mix(List<double> q) => (q[0] * (1 - u) + q[1] * u) * (1 - v) + (q[3] * (1 - u) + q[2] * u) * v;
    return (mix(lats), mix(lons));
  }

  /// The sheet in [projection]. On a cylindrical projection it runs on past
  /// the world's edge in one piece, and again a turn the other way to reach
  /// in from the far edge. On the disc, a triangle with a corner not drawn,
  /// or a side that reaches across the rim, is halved where it does, up to
  /// [_rimSplits] times, and what still does is left out: the picture
  /// follows the rim to within a sliver.
  List<OverlayMesh> placeIn(MapProjection projection) {
    if (projection is CylindricalProjection) {
      final from = wrapLongitude(_lons[0] - projection.meridian);
      final easts = [for (final (_, lon) in _at) from + lon - _lons[0]];
      final low = easts.reduce(math.min), high = easts.reduce(math.max);
      OverlayMesh turned(double turn) {
        final positions = Float32List(2 * _at.length);
        for (final (k, (lat, _)) in _at.indexed) {
          final p = projection.place(lat, easts[k] + turn);
          positions[2 * k] = p.dx;
          positions[2 * k + 1] = p.dy;
        }
        return OverlayMesh(positions, _uv, _cells);
      }

      return [
        for (final turn in [0.0, if (high > 180) -360.0, if (low < -180) 360.0]) turned(turn),
      ];
    }
    final points = <Offset?>[for (final (lat, lon) in _at) projection.toMap(lat, lon)];
    final us = <double>[for (var k = 0; k < _uv.length; k += 2) _uv[k]];
    final vs = <double>[for (var k = 1; k < _uv.length; k += 2) _uv[k]];
    final longest = projection.longestStep;
    const finest = 1 / (_overlayGrid << _rimSplits);
    // A side is judged by its ends alone, and halved at one point however
    // many triangles share it, so the two either side of it agree.
    bool bad(int a, int b) => points[a] == null || points[b] == null || (points[a]! - points[b]!).distance > longest;
    bool halves(int a, int b) => bad(a, b) && math.max((us[a] - us[b]).abs(), (vs[a] - vs[b]).abs()) > finest * 1.5;
    final middles = <(int, int), int>{};
    int middle(int a, int b) => middles[a < b ? (a, b) : (b, a)] ??= () {
      final u = (us[a] + us[b]) / 2, v = (vs[a] + vs[b]) / 2;
      final (lat, lon) = _mix(_lats, _lons, u, v);
      points.add(projection.toMap(lat, lon));
      us.add(u);
      vs.add(v);
      return points.length - 1;
    }();
    final positions = <double>[], textures = <double>[];
    // A triangle split more than this is a sliver along a side it cannot
    // halve, and left out.
    const deepest = 3 * _rimSplits;
    void lay(int a, int b, int c, [int depth = 0]) {
      if (!bad(a, b) && !bad(b, c) && !bad(c, a)) {
        for (final k in [a, b, c]) {
          positions.addAll([points[k]!.dx, points[k]!.dy]);
          textures.addAll([us[k], vs[k]]);
        }
        return;
      }
      if (depth == deepest) return;
      final ab = halves(a, b) ? middle(a, b) : null;
      final bc = halves(b, c) ? middle(b, c) : null;
      final ca = halves(c, a) ? middle(c, a) : null;
      switch ((ab, bc, ca)) {
        case (null, null, null):
          return;
        case (final m?, null, null):
          lay(a, m, c, depth + 1);
          lay(m, b, c, depth + 1);
        case (null, final m?, null):
          lay(b, m, a, depth + 1);
          lay(m, c, a, depth + 1);
        case (null, null, final m?):
          lay(c, m, b, depth + 1);
          lay(m, a, b, depth + 1);
        case (final m?, final k?, null):
          lay(m, b, k, depth + 1);
          lay(a, m, k, depth + 1);
          lay(a, k, c, depth + 1);
        case (null, final m?, final k?):
          lay(m, c, k, depth + 1);
          lay(b, m, k, depth + 1);
          lay(b, k, a, depth + 1);
        case (final k?, null, final m?):
          lay(m, a, k, depth + 1);
          lay(c, m, k, depth + 1);
          lay(c, k, b, depth + 1);
        case (final m1?, final m2?, final m3?):
          lay(a, m1, m3, depth + 1);
          lay(m1, b, m2, depth + 1);
          lay(m3, m2, c, depth + 1);
          lay(m1, m2, m3, depth + 1);
      }
    }

    for (var k = 0; k < _cells.length; k += 3) {
      lay(_cells[k], _cells[k + 1], _cells[k + 2]);
    }
    return positions.isEmpty ? const [] : [OverlayMesh(Float32List.fromList(positions), Float32List.fromList(textures), null)];
  }
}

/// A map image's triangles in the projection's units, by their points
/// ([positions], x and y in turn), as [indices] picks them, or in threes
/// without; its texture the unit square.
class OverlayMesh {
  final Float32List positions, textureCoordinates;
  final Uint16List? indices;

  OverlayMesh(this.positions, this.textureCoordinates, this.indices);

  late final vertices = ui.Vertices.raw(ui.VertexMode.triangles, positions, textureCoordinates: textureCoordinates, indices: indices);
}
