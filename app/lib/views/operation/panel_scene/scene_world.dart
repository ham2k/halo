// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The world under a scene's maps — the `map` control and the rotator map
// alike: its palettes, and its land, outlines and night as paths projected
// once per projection, the night again each minute (docs/design/panel-scenes.md
// § Map). Whatever a map draws over it, and how its view moves, is the
// control's own.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:halo_core/halo_core.dart' show GridLocation, nowUtc;
import 'package:halo_widgets/halo_widgets.dart' show WallClock;

import '../../../services/error_reporting_service.dart';
import '../../map/map_grayline.dart' show antisolarPoint, capAround, graylineColor, graylineInstant;
import '../world_map/map_projection.dart';
import '../world_map/world_cells.dart';
import '../world_map/world_geometry.dart';
import 'scene_model.dart';

/// The world's colors, as a map's `palette` names them. A palette holds in
/// both app themes, only darker in the dark one: the map is a picture of the
/// world rather than a surface of the app.
class MapPalette {
  final Color sea, land, coast, background, backgroundDark;

  /// The lines between countries and the graticule; null, drawn from [coast].
  final Color? borders, graticule;

  /// Lines drawn over the map — a rotator's heading at rest and while
  /// turning, its target, a map's markers and lines — each picked to stand
  /// off this palette's sea and land both, over a [casing] that lifts them
  /// off whatever they cross.
  final Color heading, turning, target, casing;

  /// Whether the map is drawn darker in the app's dark theme. A palette
  /// with a face of its own, the same in both, keeps its colors too.
  final bool dimsInDark;

  const MapPalette({
    required this.sea,
    required this.land,
    required this.coast,
    required this.background,
    required this.backgroundDark,
    this.borders,
    this.graticule,
    required this.heading,
    required this.turning,
    required this.target,
    required this.casing,
    this.dimsInDark = true,
  });

  /// The red-ham-toolkit rotator widget's own.
  static const color = MapPalette(
    sea: Color(0xFF76ACD6),
    land: Color(0xFF9E7E3D),
    coast: Color(0xFF5C402E),
    background: Color(0xFFE4EEF5),
    backgroundDark: Color(0xFF1B2833),
    heading: Color(0xFF101010),
    turning: Color(0xFF0026FF),
    target: Color(0xFFFF5500),
    casing: Color(0xE6FFFFFF),
  );
  static const gray = MapPalette(
    sea: Color(0xFFDADADA),
    land: Color(0xFFA3A3A3),
    coast: Color(0xFF5E5E5E),
    background: Color(0xFFF0F0F0),
    backgroundDark: Color(0xFF262626),
    heading: Color(0xFF000000),
    turning: Color(0xFF0047FF),
    target: Color(0xFFFF4400),
    casing: Color(0xFFFFFFFF),
  );
  static const muted = MapPalette(
    sea: Color(0xFFB4C6D0),
    land: Color(0xFFCDBF9F),
    coast: Color(0xFF8C7B62),
    background: Color(0xFFEDE8DE),
    backgroundDark: Color(0xFF2A2722),
    heading: Color(0xFF1F160B),
    turning: Color(0xFF1D3FB0),
    target: Color(0xFFE0480A),
    casing: Color(0xF2FFFFFF),
  );

  /// Land and sea as far apart as they go, in an old wall map's colors:
  /// deep ocean, pale parchment land, dark coasts and sienna borders, for a
  /// screen in bright light or an operator who needs the edges plain. The
  /// heading turns crimson rather than blue while turning: blue would sink
  /// into the ocean.
  static const contrast = MapPalette(
    sea: Color(0xFF1F5FA8),
    land: Color(0xFFF3E3A1),
    coast: Color(0xFF3B2A1A),
    background: Color(0xFFF4EBD0),
    backgroundDark: Color(0xFF10233F),
    borders: Color(0xE6A0522D),
    graticule: Color(0x40FFFFFF),
    heading: Color(0xFF000000),
    turning: Color(0xFFC4002B),
    target: Color(0xFFFF6A00),
    casing: Color(0xFFFFFFFF),
  );

  /// KI2D's panels' Teal: the app's teal lightened and muted, the map in
  /// the steps of their waterfall's teal, on the same #a9c4cb face in both
  /// app themes, as their panels keep it.
  static const teal = MapPalette(
    sea: Color(0xFF3F8A9B),
    land: Color(0xFFD6EEF4),
    coast: Color(0xFF1F3A42),
    background: Color(0xFFA9C4CB),
    backgroundDark: Color(0xFFA9C4CB),
    borders: Color(0xCC2C5C68),
    graticule: Color(0x40FFFFFF),
    heading: Color(0xFF000000),
    turning: Color(0xFFA3261A),
    target: Color(0xFFFF8A4C),
    casing: Color(0xFFFFFFFF),
    dimsInDark: false,
  );

  static MapPalette named(String name) => switch (name) {
    'gray' => gray,
    'muted' => muted,
    'contrast' => contrast,
    'teal' => teal,
    _ => color,
  };

  Color backgroundFor(bool dark) => dark ? backgroundDark : background;
}

typedef MapColors = ({Color sea, Color land, Color coast});

/// How far toward black the dark theme takes the map's colors.
const double _darkDimming = 0.35;

/// The sea, land and coast a map's style and palette give, in [dark] or not.
MapColors mapColorsOf(SceneMapStyle style, {required bool dark}) {
  final palette = MapPalette.named(style.palette);
  Color dim(Color c) => dark && palette.dimsInDark ? Color.lerp(c, Colors.black, _darkDimming)! : c;
  return (sea: dim(style.sea ?? palette.sea), land: dim(style.land ?? palette.land), coast: dim(style.coast ?? palette.coast));
}

/// The night on a scene's map: sunset, civil and nautical twilight, each
/// step darker than the Map tab's four — night plain at a glance on a small
/// map — and each fading in across a degree and a half of the sun's
/// altitude, a narrow blend rather than a hard edge.
const _nightAltitudes = [-0.833, -6.0, -12.0];
double _nightStep({required bool dark}) => dark ? 0.25 : 0.2;
const _nightBlend = 1.5;

/// The most the night's edge is blurred, in pixels: a blend of degrees grows
/// with the zoom, and a blur hundreds of pixels wide costs more than the
/// rest of the map's frame.
const _nightBlurMost = 6.0;

Future<WorldOutlines>? _outlinesLoad;
Future<WorldOutlines>? _fineOutlinesLoad;
Future<List<Float32List>>? _divisionsLoad;

/// How many times the whole world a view is magnified (map zoom 3) from
/// which it draws Natural Earth's 1:50m land and borders. Further out,
/// 1:110m's are as fine as the pane can show, at a twelfth of the points.
const double fineCloseness = 8;

Future<WorldOutlines> _readOutlines(String asset) =>
    rootBundle.loadString(asset).then((text) => WorldOutlines.fromJson(jsonDecode(text) as Map<String, dynamic>));

/// Read once for the app's life: the assets never change under it.
Future<WorldOutlines> _loadOutlines() => _outlinesLoad ??= _readOutlines('assets/geo/world-110m.json');

/// Read the first time a view closes in to [fineCloseness]: most maps never do.
Future<WorldOutlines> _loadFineOutlines() => _fineOutlinesLoad ??= _readOutlines('assets/geo/world-50m.json');

/// The lines between the states and provinces of the largest countries
/// (scripts/admin1-outlines.py), drawn as the view closes in.
Future<List<Float32List>> _loadDivisions() => _divisionsLoad ??= rootBundle.loadString('assets/geo/admin1-50m.json').then((text) {
  final lines = (jsonDecode(text) as Map<String, dynamic>)['admin1'] as List<dynamic>;
  return [
    for (final line in lines.cast<List<dynamic>>()) Float32List.fromList([for (final v in line) (v as num) / 100]),
  ];
});

/// The land, coasts, borders and divisions drawn, in the projection's units.
typedef WorldLayers = ({Path land, Path coast, Path borders, Path divisions});

/// Half a cell's diagonal on the sphere, in radians: no point of it is
/// further from its middle.
final double _cellHalfDiagonal = degreesApart(0, 0, cellDegrees / 2, cellDegrees / 2) * math.pi / 180;

/// The outlines in one projection, in its own units: cut into cells
/// (world_cells.dart), each projected the first time a view takes it in,
/// and only the cells a view reaches drawn.
class WorldPaths {
  final MapProjection projection;
  final WorldOutlines? world;
  final List<Float32List>? divisionsSource;
  final List<WorldCell> cells;
  final Path graticule;

  /// On a cylindrical projection, the cells made ready for any meridian,
  /// for the next turn of it to take up.
  final WorldTurning? turning;

  /// Each cell's paths and how far they reach, once projected.
  final List<WorldLayers?> _projected;
  final List<Rect?> _reach;

  /// What [within] gave for the last few views: a repeating world is
  /// painted once a copy, each through its own view.
  final List<(Rect, WorldLayers)> _given = [];

  WorldPaths._(this.projection, this.world, this.divisionsSource, this.cells, this.graticule, this.turning)
    : _projected = List.filled(cells.length, null),
      _reach = List.filled(cells.length, null);

  /// [turning], when it was made for this projection's type and these
  /// outlines, places them at its meridian rather than making them ready
  /// again.
  factory WorldPaths(MapProjection projection, WorldOutlines? world, List<Float32List>? divisionsSource, {WorldTurning? turning}) {
    if (projection is CylindricalProjection) {
      final t = turning != null && turning.fits(projection, world, divisionsSource) ? turning : WorldTurning(projection, world, divisionsSource);
      return WorldPaths._(projection, world, divisionsSource, t.cells, t.graticule.stroke(projection.meridian), t);
    }
    return WorldPaths._(projection, world, divisionsSource, worldCells(world, divisionsSource), projectLines(projection, _graticule()), null);
  }

  /// The land, coasts, borders and divisions of the cells that reach into
  /// [view], in the projection's units. The land is one path, filled
  /// even-odd, so the edges where its cells meet cancel rather than show.
  WorldLayers within(Rect view) {
    for (final (at, layers) in _given) {
      if (at == view) return layers;
    }
    final land = Path()..fillType = PathFillType.evenOdd;
    final coast = Path(), borders = Path(), divisions = Path();
    for (var i = 0; i < cells.length; i++) {
      if (!_reaches(i, view)) continue;
      final cell = _projected[i] ??= _project(cells[i]);
      land.addPath(cell.land, Offset.zero);
      coast.addPath(cell.coast, Offset.zero);
      borders.addPath(cell.borders, Offset.zero);
      divisions.addPath(cell.divisions, Offset.zero);
    }
    final layers = (land: land, coast: coast, borders: borders, divisions: divisions);
    if (_given.length >= 4) _given.removeAt(0);
    _given.add((view, layers));
    return layers;
  }

  WorldLayers _project(WorldCell cell) {
    final projection = this.projection;
    if (projection is CylindricalProjection) {
      final shapes = turning!.shapesOf(cell);
      final m = projection.meridian;
      return (land: shapes.land.fill(m), coast: shapes.coast.stroke(m), borders: shapes.borders.stroke(m), divisions: shapes.divisions.stroke(m));
    }
    return (
      land: fillRings(projection, cell.land),
      coast: projectLines(projection, cell.coast),
      borders: projectLines(projection, cell.borders),
      divisions: projectLines(projection, cell.divisions),
    );
  }

  /// Whether cell [i] reaches into [view]. On a cylindrical projection its
  /// reach comes from its corners, without projecting it: x is the
  /// longitude east of the meridian times a factor that shrinks away from
  /// the equator, which is always a cell edge, so the cell is widest at a
  /// corner; and where it reaches 180° it is laid a turn round too. On
  /// the disc a cell is projected to know its reach.
  bool _reaches(int i, Rect view) {
    final projection = this.projection;
    // Behind the globe, by more than the cell's own half-diagonal: its middle
    // past the horizon by that much leaves none of it in front. A globe turns
    // on every frame of a drag, and projecting the hidden half of the world
    // to find it hidden would be half that frame's cost.
    if (projection is OrthographicProjection) {
      final cell = cells[i];
      final middle = projection.project(cell.south + cellDegrees / 2, cell.west + cellDegrees / 2);
      if (middle.depth < -math.sin(_cellHalfDiagonal)) return false;
    }
    if (projection is! CylindricalProjection) {
      final reach = _reach[i] ??= () {
        final cell = _projected[i] ??= _project(cells[i]);
        // An empty path's bounds are a point at the station, not nothing.
        final bounds = [
          for (final p in [cell.land, cell.coast, cell.borders, cell.divisions]) p.getBounds(),
        ].where((b) => b != Rect.zero);
        return bounds.isEmpty ? Rect.zero : bounds.reduce((a, b) => a.expandToInclude(b));
      }();
      return reach.overlaps(view);
    }
    if ((_reach[i] ??= _cylindricalReach(projection, cells[i])).overlaps(view)) return true;
    // Laid at the far edge too where it reaches 180°, as TurningShapes lays it.
    final west = wrapLongitude(cells[i].west - projection.meridian);
    if (west + cellDegrees >= 180 && _cylindricalReach(projection, cells[i], turn: -360).overlaps(view)) return true;
    return west <= -180 && _cylindricalReach(projection, cells[i], turn: 360).overlaps(view);
  }

  static Rect _cylindricalReach(CylindricalProjection projection, WorldCell cell, {double turn = 0}) {
    final west = wrapLongitude(cell.west - projection.meridian) + turn;
    final (south, north) = (math.max(cell.south, -89.9), math.min(cell.south + cellDegrees, 89.9));
    Rect? reach;
    for (final lat in [south, north]) {
      for (final east in [west, west + cellDegrees]) {
        final p = projection.place(lat, east);
        reach = reach == null ? Rect.fromPoints(p, p) : reach.expandToInclude(Rect.fromPoints(p, p));
      }
    }
    return reach!;
  }

  /// Parallels and meridians every 30°.
  static List<Float32List> _graticule() => [
    for (var lat = -60; lat <= 60; lat += 30)
      Float32List.fromList([
        for (var lon = -180; lon <= 180; lon += 2) ...[lon.toDouble(), lat.toDouble()],
      ]),
    for (var lon = -180; lon < 180; lon += 30)
      Float32List.fromList([
        for (var lat = -88; lat <= 88; lat += 2) ...[lon.toDouble(), lat.toDouble()],
      ]),
  ];
}

/// Lines of longitude, latitude pairs, each broken where the projection
/// does not draw a point or a step jumps across a seam, and at a pole: a
/// land ring's only points there are the cut that closes Antarctica, which
/// is not a coast.
Path projectLines(MapProjection projection, List<Float32List> lines) {
  final path = Path();
  for (final line in lines) {
    for (final run in projectRuns(projection, line)) {
      path.addPolygon(run, false);
    }
  }
  return path;
}

/// The edge of the night [radius] degrees round [center], as the fill takes it.
Float32List _nightRing(GridLocation center, double radius) => Float32List.fromList([
  for (final p in capAround(center, radius)) ...[p.longitude, p.latitude],
]);

/// The night [radius] degrees round [center], from [turning] where it was
/// made ready for this projection's type. Where it holds a pole that the
/// projection draws on its top or bottom edge, it runs on past it: the edge
/// clips it, and a blurred fill that ended there would fade along the pole,
/// in the middle of the night.
@visibleForTesting
Path nightCap(MapProjection projection, GridLocation center, double radius, {TurningShapes? turning}) {
  final cap = switch ((projection, turning)) {
    (final CylindricalProjection c, final t?) => t.fill(c.meridian),
    _ => fillRings(projection, [_nightRing(center, radius)]),
  };
  if (projection is CylindricalProjection && projection.toMap(90, 0) != null) {
    final world = projection.world;
    final (left, right) = (world.left - world.width, world.right + world.width);
    if (center.latitude + radius > 90) cap.addRect(Rect.fromLTRB(left, world.top - world.height, right, world.top));
    if (center.latitude - radius < -90) cap.addRect(Rect.fromLTRB(left, world.bottom, right, world.bottom + world.height));
  }
  return cap;
}

/// One cell's outlines made ready for a cylindrical projection at any meridian.
typedef CellShapes = ({TurningShapes land, TurningShapes coast, TurningShapes borders, TurningShapes divisions});

/// The world's cells made ready for one cylindrical projection at any
/// meridian (TurningShapes), each the first time a view takes it in.
class WorldTurning {
  final CylindricalProjection projection;
  final WorldOutlines? world;
  final List<Float32List>? divisionsSource;
  final List<WorldCell> cells;
  final TurningShapes graticule;
  final Map<WorldCell, CellShapes> _shapes = Map.identity();

  WorldTurning(this.projection, this.world, this.divisionsSource)
    : cells = worldCells(world, divisionsSource),
      graticule = TurningShapes.lines(projection, WorldPaths._graticule());

  Type get family => projection.runtimeType;

  CellShapes shapesOf(WorldCell cell) => _shapes[cell] ??= (
    land: TurningShapes.rings(projection, cell.land),
    coast: TurningShapes.lines(projection, cell.coast),
    borders: TurningShapes.lines(projection, cell.borders),
    divisions: TurningShapes.lines(projection, cell.divisions),
  );

  bool fits(CylindricalProjection projection, WorldOutlines? world, List<Float32List>? divisionsSource) =>
      family == projection.runtimeType && identical(this.world, world) && identical(this.divisionsSource, divisionsSource);
}

/// [line], longitude, latitude pairs, as the runs of points it is drawn as.
/// On a cylindrical projection a run crosses the antimeridian in one piece,
/// past the world's edge, and is laid again a turn the other way to reach in
/// from the far edge; on the disc it breaks where a step jumps across the rim.
List<List<Offset>> projectRuns(MapProjection projection, Float32List line) {
  if (projection is CylindricalProjection) return TurningShapes.lines(projection, [line]).runs(projection.meridian);
  final runs = <List<Offset>>[];
  final longest = projection.longestStep;
  List<Offset>? run;
  for (var i = 0; i + 1 < line.length; i += 2) {
    final lat = line[i + 1];
    final point = lat.abs() >= 89.99 ? null : projection.toMap(lat, line[i]);
    if (point == null) {
      run = null;
      continue;
    }
    if (run == null || (point - run.last).distance > longest) runs.add(run = []);
    run.add(point);
  }
  return runs;
}

/// [path] as dashes 6 pixels long, 10 apart; with [within], only those
/// that reach into it. Zoomed in, a ring round the world is millions of
/// pixels long, and dashing all of it costs seconds a frame for the few
/// hundred pixels the pane shows. A path goes no further than its length,
/// so a point [within] is not reached sooner than its distance from it
/// further along: the dashes before then are passed over a stretch at a
/// time, keeping their places along the path so a pan does not slide them.
Path dashedPath(Path path, {Rect? within}) {
  final out = Path();
  for (final metric in path.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      if (within != null) {
        final at = metric.getTangentForOffset(d)!.position;
        final away = math.max(math.max(within.left - at.dx, at.dx - within.right), math.max(within.top - at.dy, at.dy - within.bottom));
        if (away > 6) {
          d += math.max(10.0, (away / 10).floor() * 10.0);
          continue;
        }
      }
      out.addPath(metric.extractPath(d, math.min(d + 6, metric.length)), Offset.zero);
      d += 10;
    }
  }
  return out;
}

/// The world a map draws under its own: the outlines, loaded once, and the
/// land, outlines and night projected once per projection, the night again
/// each minute. [onChanged] is the owning State's setState.
class WorldMapBase {
  final VoidCallback onChanged;

  /// Names the map in an error report.
  final String errorContext;

  WorldMapBase({required this.onChanged, required this.errorContext});

  bool _disposed = false;
  WorldOutlines? _outlines;
  WorldOutlines? _fineOutlines;
  bool _fineAsked = false;
  List<Float32List>? _divisions;
  MapProjection? _projection;

  /// Whether the view is close enough for the 1:50m outlines.
  bool _fine = false;
  WorldPaths? paths;

  /// The night's caps, deepest last, in [_nightIn] at [_nightAt].
  List<Path>? _night;
  MapProjection? _nightIn;
  DateTime? _nightAt;

  /// The caps at [_nightAt] made ready for a cylindrical projection's type:
  /// a Robinson pan turns the world on every frame, and laying the caps out
  /// and preparing them again each time is most of the night's cost.
  List<TurningShapes>? _nightTurning;

  MapProjection? get projection => _projection;
  bool get hasOutlines => _outlines != null;

  void start() {
    WallClock.minutes.addListener(_onMinute);
    _loadOutlines().then((outlines) {
      if (_disposed) return;
      _outlines = outlines;
      _reproject();
    }, onError: (Object error, StackTrace stack) => ErrorReportingService.report(error, stack, context: '$errorContext:outlines'));
    _loadDivisions().then((divisions) {
      if (_disposed) return;
      _divisions = divisions;
      _reproject();
    }, onError: (Object error, StackTrace stack) => ErrorReportingService.report(error, stack, context: '$errorContext:divisions'));
  }

  void dispose() {
    _disposed = true;
    WallClock.minutes.removeListener(_onMinute);
  }

  /// A map that shows the night draws it again for the new minute.
  void _onMinute() {
    if (_night != null && !_disposed) onChanged();
  }

  /// The projection to draw in; null draws no world at all. Called from
  /// build, so it says nothing to [onChanged]: the frame being built draws
  /// what it set. [closeness] is the view's magnification, as [paint] takes
  /// it: from [fineCloseness] the 1:50m outlines are drawn, once read.
  void project(MapProjection? projection, {double closeness = 1}) {
    final fine = closeness >= fineCloseness;
    if (fine && projection != null && !_fineAsked) {
      _fineAsked = true;
      _loadFineOutlines().then((outlines) {
        if (_disposed) return;
        _fineOutlines = outlines;
        _reproject();
      }, onError: (Object error, StackTrace stack) => ErrorReportingService.report(error, stack, context: '$errorContext:fine outlines'));
    }
    if (_projection == projection && _fine == fine) return;
    _projection = projection;
    _fine = fine;
    if (projection == null) {
      paths = null;
      _night = null;
      return;
    }
    _reproject(notify: false);
  }

  void _reproject({bool notify = true}) {
    final projection = _projection;
    if (projection == null) return;
    final world = _fine ? _fineOutlines ?? _outlines : _outlines;
    if (paths?.projection != projection || paths?.world != world || paths?.divisionsSource != _divisions) {
      paths = WorldPaths(projection, world, _divisions, turning: paths?.turning);
      if (notify) onChanged();
    }
  }

  /// The night's caps at [at], one a step.
  List<Path> _nightFor(MapProjection projection, DateTime at) {
    if (_night case final night? when _nightIn == projection && _nightAt == at) return night;
    final center = antisolarPoint(at);
    if (_nightAt != at) _nightTurning = null;
    if (projection is CylindricalProjection && _nightTurning?.first.family != projection.runtimeType) {
      _nightTurning = [
        for (final altitude in _nightAltitudes) TurningShapes.rings(projection, [_nightRing(center, 90 + altitude)]),
      ];
    }
    final turning = projection is CylindricalProjection ? _nightTurning : null;
    final night = [for (final (i, altitude) in _nightAltitudes.indexed) nightCap(projection, center, 90 + altitude, turning: turning?[i])];
    _nightIn = projection;
    _nightAt = at;
    return _night = night;
  }

  /// The land, the night, then the outlines, drawn where the projection's
  /// point (0, 0) falls at [origin] and one of its units is [scale] pixels.
  /// [closeness] is how many times the whole world the view is magnified:
  /// the states and provinces come in as it closes in on a country.
  void paint(
    Canvas canvas, {
    required Offset origin,
    required double scale,
    required SceneMapStyle style,
    required MapColors colors,
    required double closeness,
    required bool dark,
  }) {
    final paths = this.paths;
    if (paths == null) return;
    final palette = MapPalette.named(style.palette);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    // Borders thicken as the view closes in, up to many pixels.
    final borderWidth = 0.5 + math.max(0, closeness - 2) * 0.15;
    // Only the cells the pane shows, and the widest stroke's half past them.
    final layers = paths.within(canvas.getLocalClipBounds().inflate((math.max(0.8, borderWidth) / 2 + 1) / scale));
    canvas.drawPath(layers.land, Paint()..color = colors.land);
    if (style.grayline) {
      // Blurred across the blend, in the projection's units as the canvas
      // is scaled: a degree is the world's breadth over 360 at the equator.
      final shade = Paint()
        ..color = graylineColor.withValues(alpha: _nightStep(dark: dark))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.min(_nightBlend / 3 * paths.projection.world.width / 360, _nightBlurMost / scale));
      for (final cap in _nightFor(paths.projection, graylineInstant(nowUtc()))) {
        canvas.drawPath(cap, shade);
      }
    } else {
      _night = null;
    }
    Paint line(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = width / scale;
    final coast = style.coast ?? colors.coast;
    canvas.drawPath(paths.graticule, line(style.graticule ?? palette.graticule ?? const Color(0x66444444), 0.5));
    // From 2.5x they fade in, fully from 4x: on the whole world they are a smudge.
    final divisions = ((closeness - 2.5) / 1.5).clamp(0.0, 1.0);
    final borders = style.borders ?? palette.borders ?? coast.withValues(alpha: 0.6);
    if (divisions > 0) canvas.drawPath(layers.divisions, line((style.divisions ?? borders).withValues(alpha: divisions * 0.6), 0.5));
    canvas.drawPath(layers.borders, line(borders, borderWidth));
    canvas.drawPath(layers.coast, line(coast, 0.8));
    canvas.restore();
  }
}
