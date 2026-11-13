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
Future<List<Float32List>>? _divisionsLoad;

/// Read once for the app's life: the assets never change under it.
Future<WorldOutlines> _loadOutlines() =>
    _outlinesLoad ??= rootBundle.loadString('assets/geo/world-110m.json').then((text) => WorldOutlines.fromJson(jsonDecode(text) as Map<String, dynamic>));

/// The lines between the states and provinces of the largest countries
/// (scripts/admin1-outlines.py), drawn as the view closes in.
Future<List<Float32List>> _loadDivisions() => _divisionsLoad ??= rootBundle.loadString('assets/geo/admin1-50m.json').then((text) {
  final lines = (jsonDecode(text) as Map<String, dynamic>)['admin1'] as List<dynamic>;
  return [
    for (final line in lines.cast<List<dynamic>>()) Float32List.fromList([for (final v in line) (v as num) / 100]),
  ];
});

/// The outlines projected once per projection, in its own units.
class WorldPaths {
  final MapProjection projection;
  final WorldOutlines? world;
  final List<Float32List>? divisionsSource;
  final Path land, coast, borders, graticule, divisions;

  /// On a cylindrical projection, the outlines made ready for any meridian,
  /// for the next turn of it to take up.
  final WorldTurning? turning;

  WorldPaths._(this.projection, this.world, this.divisionsSource, this.land, this.coast, this.borders, this.graticule, this.divisions, this.turning);

  /// [turning], when it was made for this projection's type and these
  /// outlines, places them at its meridian rather than projecting them again.
  factory WorldPaths(MapProjection projection, WorldOutlines? world, List<Float32List>? divisionsSource, {WorldTurning? turning}) {
    if (projection is CylindricalProjection) {
      final t = turning != null && turning.fits(projection, world, divisionsSource) ? turning : WorldTurning(projection, world, divisionsSource);
      final m = projection.meridian;
      return WorldPaths._(
        projection,
        world,
        divisionsSource,
        t.land?.fill(m) ?? Path(),
        t.coast?.stroke(m) ?? Path(),
        t.borders?.stroke(m) ?? Path(),
        t.graticule.stroke(m),
        t.divisions?.stroke(m) ?? Path(),
        t,
      );
    }
    return WorldPaths._(
      projection,
      world,
      divisionsSource,
      world == null ? Path() : fillRings(projection, world.land),
      world == null ? Path() : projectLines(projection, world.land),
      world == null ? Path() : projectLines(projection, world.borders),
      projectLines(projection, _graticule()),
      divisionsSource == null ? Path() : projectLines(projection, divisionsSource),
      null,
    );
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

/// The world's outlines made ready for one cylindrical projection at any
/// meridian (TurningShapes).
class WorldTurning {
  final Type family;
  final WorldOutlines? world;
  final List<Float32List>? divisionsSource;
  final TurningShapes? land, coast, borders, divisions;
  final TurningShapes graticule;

  WorldTurning(CylindricalProjection projection, this.world, this.divisionsSource)
    : family = projection.runtimeType,
      land = world == null ? null : TurningShapes.rings(projection, world.land),
      coast = world == null ? null : TurningShapes.lines(projection, world.land),
      borders = world == null ? null : TurningShapes.lines(projection, world.borders),
      graticule = TurningShapes.lines(projection, WorldPaths._graticule()),
      divisions = divisionsSource == null ? null : TurningShapes.lines(projection, divisionsSource);

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

/// [path] as dashes 6 pixels long, 10 apart.
Path dashedPath(Path path) {
  final out = Path();
  for (final metric in path.computeMetrics()) {
    for (var d = 0.0; d < metric.length; d += 10) {
      out.addPath(metric.extractPath(d, math.min(d + 6, metric.length)), Offset.zero);
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
  List<Float32List>? _divisions;
  MapProjection? _projection;
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
  /// what it set.
  void project(MapProjection? projection) {
    if (_projection == projection) return;
    _projection = projection;
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
    if (paths?.projection != projection || paths?.world != _outlines || paths?.divisionsSource != _divisions) {
      paths = WorldPaths(projection, _outlines, _divisions, turning: paths?.turning);
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
    canvas.drawPath(paths.land, Paint()..color = colors.land);
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
    if (divisions > 0) canvas.drawPath(paths.divisions, line((style.divisions ?? borders).withValues(alpha: divisions * 0.6), 0.5));
    canvas.drawPath(paths.borders, line(borders, 0.5 + math.max(0, closeness - 2) * 0.15));
    canvas.drawPath(paths.coast, line(coast, 0.8));
    canvas.restore();
  }
}
