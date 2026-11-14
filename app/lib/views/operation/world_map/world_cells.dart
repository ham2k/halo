// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The world's outlines cut into cells [cellDegrees] on a side, so a map
// closed in on part of the world projects and draws only the cells its view
// overlaps, not the whole world (docs/design/panel-scenes.md, "Coasts and
// borders sharpen as the view closes in").
//
// Cut in latitude and longitude, once per outline set, they are the same
// cells under every projection, and a turning map places only the ones in
// view. A land ring is clipped to each cell as a polygon: filled together,
// even-odd in one path, the pieces are the land, since where two cells
// meet their cut edges are the same points, once each way, and cancel. The
// coasts are the same rings clipped as lines, so a cut edge is never
// stroked.

import 'dart:typed_data';

import 'world_geometry.dart';

/// A cell's side, in degrees.
const double cellDegrees = 10;

/// Latitude rows: a pole belongs to the row next to it.
const int _rows = 18;

/// One cell's share of the outlines, each as flat longitude, latitude pairs
/// in degrees, as [WorldOutlines] holds them.
class WorldCell {
  /// Its south-west corner. A longitude past 180 is a ring's, run on across
  /// the antimeridian.
  final double west, south;

  /// The land within it, as closed rings filled even-odd.
  final List<Float32List> land;

  /// The coasts, the borders, and the lines between states and provinces
  /// within it, as open lines.
  final List<Float32List> coast, borders, divisions;

  WorldCell(this.west, this.south, {this.land = const [], this.coast = const [], this.borders = const [], this.divisions = const []});
}

int _column(double lon) => ((lon + 180) / cellDegrees).floor();
int _row(double lat) => ((lat + 90) / cellDegrees).floor().clamp(0, _rows - 1);

/// A cell's key: rows never reach 64, so each column and row has its own.
/// A line may run on west of -180, into a column below 0.
int _key(int column, int row) => column * 64 + row;
int _columnOf(int key) => (key - key % 64) ~/ 64;

final _ringCuts = Expando<Map<int, List<Float32List>>>();
final _lineCuts = Expando<Map<int, List<Float32List>>>();
final _cells = Expando<Map<Object, List<WorldCell>>>();

/// [world] and [divisions] cut into the cells they reach, each cut once for
/// the app's life: the outlines never change under it.
List<WorldCell> worldCells(WorldOutlines? world, List<Float32List>? divisions) {
  final byDivisions = world == null ? null : _cells[world] ??= {};
  final key = divisions ?? const <Float32List>[];
  if (byDivisions?[key] case final cells?) return cells;
  final land = world == null ? const <int, List<Float32List>>{} : _ringCuts[world.land] ??= cutRings(world.land);
  final coast = world == null ? const <int, List<Float32List>>{} : _lineCuts[world.land] ??= cutLines(world.land);
  final borders = world == null ? const <int, List<Float32List>>{} : _lineCuts[world.borders] ??= cutLines(world.borders);
  final lines = divisions == null ? const <int, List<Float32List>>{} : _lineCuts[divisions] ??= cutLines(divisions);
  final keys = {...land.keys, ...coast.keys, ...borders.keys, ...lines.keys}.toList()..sort();
  final cells = [
    for (final k in keys)
      WorldCell(
        _columnOf(k) * cellDegrees - 180,
        (k % 64) * cellDegrees - 90,
        land: land[k] ?? const [],
        coast: coast[k] ?? const [],
        borders: borders[k] ?? const [],
        divisions: lines[k] ?? const [],
      ),
  ];
  byDivisions?[key] = cells;
  return cells;
}

/// [lines] cut where they cross from one cell to the next, each piece
/// listed under its cell's key. A step is split at every cell edge it
/// crosses, at the point it crosses it, so the pieces meet end to end.
///
/// A step to or from a pole is left out, as a projected line leaves it
/// out (projectRuns): a land ring's only points there are the cut that
/// closes Antarctica, and split at a cell edge, the step down to the pole
/// would leave a piece short of it to be drawn as a coast.
Map<int, List<Float32List>> cutLines(List<Float32List> lines) {
  final out = <int, List<Float32List>>{};
  for (final line in lines) {
    var key = -1 << 30;
    var run = <double>[];
    void close() {
      if (run.length >= 4) (out[key] ??= []).add(Float32List.fromList(run));
      key = -1 << 30;
      run = [];
    }

    for (var i = 0; i + 3 < line.length; i += 2) {
      final x0 = line[i].toDouble(), y0 = line[i + 1].toDouble(), x1 = line[i + 2].toDouble(), y1 = line[i + 3].toDouble();
      if (y0.abs() >= 89.99 || y1.abs() >= 89.99) {
        close();
        continue;
      }
      final cuts = <double>[0, ..._crossings(x0, x1, 180), ..._crossings(y0, y1, 90), 1]..sort();
      for (var c = 0; c + 1 < cuts.length; c++) {
        final (a, b) = (cuts[c], cuts[c + 1]);
        if (b <= a) continue;
        final mid = (a + b) / 2;
        final k = _key(_column(x0 + (x1 - x0) * mid), _row(y0 + (y1 - y0) * mid));
        if (k != key) {
          close();
          key = k;
          run = [x0 + (x1 - x0) * a, y0 + (y1 - y0) * a];
        }
        run
          ..add(x0 + (x1 - x0) * b)
          ..add(y0 + (y1 - y0) * b);
      }
    }
    close();
  }
  return out;
}

/// Where a step from [from] to [to] crosses a cell edge, as shares of the
/// step: the edges lie at whole multiples of [cellDegrees] past -[offset].
Iterable<double> _crossings(double from, double to, double offset) sync* {
  if (from == to) return;
  final (low, high) = from < to ? (from, to) : (to, from);
  for (var edge = ((low + offset) / cellDegrees).floor() + 1; edge * cellDegrees - offset < high; edge++) {
    yield (edge * cellDegrees - offset - from) / (to - from);
  }
}

/// [rings] clipped to each cell they reach, as closed rings listed under
/// its key: first to each column, then each column's piece to each row.
/// Where a ring leaves a cell and comes back, its piece runs along the
/// cell's edge between, out and back over the same points, which even-odd
/// fills as nothing.
Map<int, List<Float32List>> cutRings(List<Float32List> rings) {
  final out = <int, List<Float32List>>{};
  for (final ring in rings) {
    if (ring.length < 6) continue;
    final points = [for (final v in ring) v.toDouble()];
    final (west, east) = _span(points, 0);
    for (var column = _column(west); column <= _column(east); column++) {
      final lon = column * cellDegrees - 180;
      final strip = _clip(points, 0, lon, lon + cellDegrees);
      if (strip.length < 6) continue;
      final (south, north) = _span(strip, 1);
      for (var row = _row(south); row <= _row(north); row++) {
        final lat = row * cellDegrees - 90;
        // The poles are the outer rows' edges: a ring closed along one (Antarctica's) keeps it.
        final piece = _clip(strip, 1, row == 0 ? -90 : lat, row == _rows - 1 ? 90 : lat + cellDegrees);
        // Closed as the outlines' rings are, back on its first point.
        if (piece.length >= 6 && _area(piece).abs() > 1e-9) (out[_key(column, row)] ??= []).add(Float32List.fromList([...piece, piece[0], piece[1]]));
      }
    }
  }
  return out;
}

/// The least and most of [points]' longitudes ([axis] 0) or latitudes (1).
(double, double) _span(List<double> points, int axis) {
  var low = points[axis], high = points[axis];
  for (var i = axis; i < points.length; i += 2) {
    if (points[i] < low) low = points[i];
    if (points[i] > high) high = points[i];
  }
  return (low, high);
}

/// [points], a ring, clipped to [low]..[high] on [axis] (Sutherland and
/// Hodgman's, against one side and then the other).
List<double> _clip(List<double> points, int axis, double low, double high) =>
    _clipSide(_clipSide(points, axis, low, keepAbove: true), axis, high, keepAbove: false);

List<double> _clipSide(List<double> points, int axis, double edge, {required bool keepAbove}) {
  final out = <double>[];
  final n = points.length ~/ 2;
  if (n == 0) return out;
  bool inside(int i) => keepAbove ? points[i * 2 + axis] >= edge : points[i * 2 + axis] <= edge;
  for (var i = 0; i < n; i++) {
    final j = (i + 1) % n;
    final (inI, inJ) = (inside(i), inside(j));
    if (inI) {
      out
        ..add(points[i * 2])
        ..add(points[i * 2 + 1]);
    }
    if (inI != inJ) {
      final a = points[i * 2 + axis], b = points[j * 2 + axis];
      final t = (edge - a) / (b - a);
      final x = points[i * 2] + (points[j * 2] - points[i * 2]) * t;
      final y = points[i * 2 + 1] + (points[j * 2 + 1] - points[i * 2 + 1]) * t;
      out
        ..add(axis == 0 ? edge : x)
        ..add(axis == 0 ? y : edge);
    }
  }
  return out;
}

/// Twice the ring's signed area, in square degrees.
double _area(List<double> points) {
  var sum = 0.0;
  final n = points.length ~/ 2;
  for (var i = 0; i < n; i++) {
    final j = (i + 1) % n;
    sum += points[i * 2] * points[j * 2 + 1] - points[j * 2] * points[i * 2 + 1];
  }
  return sum;
}
