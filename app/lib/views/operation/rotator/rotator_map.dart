// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rotator's map: the world as seen from the station (rotator_geometry.dart
// says why this projection), with the beam drawn over it — where the antenna
// points, where it was told to go, and the station being worked. A tap turns
// the antenna toward wherever it lands.
//
// The look follows the Node-RED rotator widget in red-ham-toolkit, which
// this ports without its zoom: a whole-world disc is the only view in which
// every heading reaches the rim.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:halo_core/halo_core.dart' show GridLocation, nowUtc;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../../services/cat/equipment.dart' show rotatorArrivedWithin, rotatorHeadingGap;
import '../../../services/error_reporting_service.dart';
import '../../map/map_grayline.dart' show graylineColor, graylineInstant, graylineStepOpacity;
import 'rotator_geometry.dart';

/// The world's colours, as the panel's Theme setting picks them. The beam,
/// target and station keep theirs whichever it is: they are what the map is
/// for, and every palette here is quiet enough to carry them.
///
/// The map is a picture of the world rather than a surface of the app, so a
/// palette holds in both app themes, only darker in the dark one.
class RotatorMapPalette {
  final Color sea;
  final Color land;
  final Color coast;

  /// The pane behind the disc, in a light app theme and a dark one. Each
  /// stays as light or as dark as the app's own surface, so the rim, the
  /// compass letters and the buttons keep the theme's ink on it.
  final Color background;
  final Color backgroundDark;

  const RotatorMapPalette({required this.sea, required this.land, required this.coast, required this.background, required this.backgroundDark});

  Color backgroundFor({required bool dark}) => dark ? backgroundDark : background;

  /// The red-ham-toolkit widget's own.
  static const color = RotatorMapPalette(
    sea: Color(0xFF76ACD6),
    land: Color(0xFF9E7E3D),
    coast: Color(0xFF5C402E),
    background: Color(0xFFE4EEF5),
    backgroundDark: Color(0xFF1B2833),
  );
  static const gray = RotatorMapPalette(
    sea: Color(0xFFDADADA),
    land: Color(0xFFA3A3A3),
    coast: Color(0xFF5E5E5E),
    background: Color(0xFFF0F0F0),
    backgroundDark: Color(0xFF262626),
  );
  static const muted = RotatorMapPalette(
    sea: Color(0xFFB4C6D0),
    land: Color(0xFFCDBF9F),
    coast: Color(0xFF8C7B62),
    background: Color(0xFFEDE8DE),
    backgroundDark: Color(0xFF2A2722),
  );
}

const _current = Color(0xFF001EF9);
const _target = Color(0xFFFF4400);
const _aligned = Color(0xFF000000);
const _dx = Color(0xFFFF0000);
const _hud = Color(0xD9C8C8C8);

/// How far toward black the dark theme takes the map's colours.
const double _darkDimming = 0.35;

/// The room outside the rim for the N, E, S and W labels.
const double _labelMargin = 16;

/// How close to the DX station's dot, in logical pixels, a tap turns to the
/// station's own heading rather than the tapped point's.
const double _dxSnap = 12;

/// Lines are broken this close to the antipode, as a fraction of the way
/// round the Earth: past it the projection stretches a step of the outline
/// across the rim.
const double _antipodeCutoff = 0.97;

/// A step longer than this, as a fraction of the disc's radius, crosses the
/// antipode — it went round the back — and is not drawn.
const double _longestStep = 0.25;

Future<WorldOutlines>? _outlinesLoad;

/// Read once for the app's life: the asset never changes under it.
Future<WorldOutlines> _loadOutlines() =>
    _outlinesLoad ??= rootBundle.loadString('assets/geo/world-110m.json').then((text) => WorldOutlines.fromJson(jsonDecode(text) as Map<String, dynamic>));

class RotatorMap extends StatefulWidget {
  /// Where the station is: the map's centre. Null draws a compass with no
  /// map under it — the headings are still true, there is just no world.
  final GridLocation? home;

  /// The station being worked, marked where it is.
  final GridLocation? dx;

  /// Where the antenna points, and where it was told to go — see
  /// [EquipmentState.rotatorTarget]. Null when not known.
  final int? azimuth;
  final int? target;
  final int? elevation;

  /// The beam's width in degrees, drawn around [azimuth]; 0 draws none.
  final int beamWidth;

  final RotatorMapPalette palette;

  /// Whether the night side is shaded over the map.
  final bool grayline;

  /// Whether the rotator is connected and answering. A map of one that is
  /// not shows no heading and turns nothing.
  final bool live;

  /// Connected, but no longer answering: says so where [live] would show the
  /// heading, rather than "disconnected".
  final bool stale;

  final ValueChanged<int>? onTurn;

  /// Laid over the top-right corner: the connection and stop buttons.
  final Widget? actions;

  const RotatorMap({
    super.key,
    required this.home,
    this.dx,
    this.azimuth,
    this.target,
    this.elevation,
    this.beamWidth = 30,
    this.palette = RotatorMapPalette.color,
    this.grayline = true,
    required this.live,
    this.stale = false,
    this.onTurn,
    this.actions,
  });

  @override
  State<RotatorMap> createState() => _RotatorMapState();
}

class _RotatorMapState extends State<RotatorMap> {
  WorldOutlines? _outlines;
  AzimuthalProjection? _projection;
  _Outlines? _paths;
  DiscRaster? _raster;
  ui.Image? _image;

  /// The raster size asked for by the last layout, in device pixels.
  int _wantedSize = 0;
  bool _dark = false;

  /// Bumped for every image asked for, so a slow decode cannot land after a
  /// newer one.
  int _imageSeq = 0;

  @override
  void initState() {
    super.initState();
    WallClock.minutes.addListener(_onMinute);
    _loadOutlines().then((outlines) {
      if (!mounted) return;
      _outlines = outlines;
      _rebuild();
    }, onError: (Object error, StackTrace stack) => ErrorReportingService.report(error, stack, context: 'rotator:outlines'));
  }

  @override
  void didUpdateWidget(RotatorMap old) {
    super.didUpdateWidget(old);
    if (old.home != widget.home) {
      _rebuild();
    } else if (old.palette != widget.palette || old.grayline != widget.grayline) {
      _paintNight();
    }
  }

  @override
  void dispose() {
    WallClock.minutes.removeListener(_onMinute);
    _image?.dispose();
    super.dispose();
  }

  /// A new centre or size: everything projected is projected again.
  void _rebuild() {
    final home = widget.home;
    final outlines = _outlines;
    if (home == null || outlines == null || _wantedSize == 0) {
      _projection = null;
      _paths = null;
      _raster = null;
      _setImage(null);
      return;
    }
    final projection = AzimuthalProjection(home);
    final paths = _Outlines(projection, outlines);
    // The outlines show now; the land and night once the image decodes.
    setState(() {
      _projection = projection;
      _paths = paths;
    });
    _raster = DiscRaster(projection, outlines.mask, _wantedSize);
    _paintNight();
  }

  /// With no grayline the picture has nothing in it that a minute moves.
  void _onMinute() {
    if (widget.grayline) _paintNight();
  }

  void _paintNight() {
    final raster = _raster;
    if (raster == null) return;
    int argb(Color color) => (_dark ? Color.lerp(color, Colors.black, _darkDimming)! : color).toARGB32();
    final pixels = raster.pixels(
      sea: argb(widget.palette.sea),
      land: argb(widget.palette.land),
      night: graylineColor.toARGB32(),
      nightStep: graylineStepOpacity(dark: _dark),
      utc: widget.grayline ? graylineInstant(nowUtc()) : null,
    );
    final seq = ++_imageSeq;
    ui.decodeImageFromPixels(pixels, raster.size, raster.size, ui.PixelFormat.rgba8888, (image) {
      if (!mounted || seq != _imageSeq) {
        image.dispose();
        return;
      }
      _setImage(image);
    });
  }

  void _setImage(ui.Image? image) {
    if (image == null) _imageSeq++;
    final old = _image;
    setState(() => _image = image);
    old?.dispose();
  }

  /// Asked from build, acted on after it: a raster is too slow to make
  /// inside a frame, and a setState there is not allowed.
  void _want(int size, bool dark) {
    if (size == _wantedSize && dark == _dark) return;
    final resize = size != _wantedSize;
    _wantedSize = size;
    _dark = dark;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (resize) {
        _rebuild();
      } else {
        _paintNight();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = context.t.operation.layout.panels;
    return LayoutBuilder(
      builder: (context, constraints) {
        final radius = math.max(0.0, math.min(constraints.maxWidth, constraints.maxHeight) / 2 - _labelMargin);
        // Whole steps of 64, so dragging a pane's edge makes a new raster
        // now and then rather than every frame; capped, as past it a pixel
        // is finer than the 110m outlines it shows.
        final pixels = (radius * 2 * MediaQuery.devicePixelRatioOf(context) / 64).ceil().clamp(2, 10) * 64;
        _want(radius > 0 ? pixels : 0, dark);
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: widget.live && widget.onTurn != null ? (details) => _tap(details.localPosition, center, radius) : null,
                child: CustomPaint(
                  painter: _RotatorPainter(
                    radius: radius,
                    projection: _projection,
                    outlines: _paths,
                    image: _image,
                    dark: dark,
                    palette: widget.palette,
                    dx: widget.dx,
                    azimuth: widget.live ? widget.azimuth : null,
                    target: widget.live ? widget.target : null,
                    beamWidth: widget.beamWidth,
                    labels: [p.rotatorNorth, p.rotatorEast, p.rotatorSouth, p.rotatorWest],
                    labelStyle: Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.bold),
                    rimColor: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: _Hud(live: widget.live, stale: widget.stale, azimuth: widget.azimuth, target: widget.target, elevation: widget.elevation),
            ),
            if (widget.actions != null) Positioned(right: 0, top: 0, child: widget.actions!),
          ],
        );
      },
    );
  }

  void _tap(Offset at, Offset center, double radius) {
    final offset = at - center;
    if (offset.distance > radius) return;
    var heading = headingOf(offset.dx, offset.dy);
    final projection = _projection;
    final dx = widget.dx;
    if (projection != null && dx != null) {
      final spot = projection.project(dx.latitude, dx.longitude);
      if ((Offset(spot.x, spot.y) * radius - offset).distance <= _dxSnap) heading = headingOf(spot.x, spot.y);
    }
    widget.onTurn!(heading.round() % 360);
  }
}

/// The current heading and the target, as the widget's corner pill puts
/// them: "45° ➜ 290°" while turning, "290°" once there.
class _Hud extends StatelessWidget {
  final bool live;
  final bool stale;
  final int? azimuth;
  final int? target;
  final int? elevation;

  const _Hud({required this.live, required this.stale, this.azimuth, this.target, this.elevation});

  @override
  Widget build(BuildContext context) {
    final p = context.t.operation.layout.panels;
    final style = Theme.of(context).textTheme.titleSmall!.copyWith(fontFamily: 'RobotoMono', fontWeight: FontWeight.bold);
    final azimuth = this.azimuth;
    final target = this.target;
    final turning = azimuth != null && target != null && rotatorHeadingGap(azimuth, target) > rotatorArrivedWithin;
    final heading = !live
        ? TextSpan(
            text: stale ? p.rotatorNotResponding : p.rotatorDisconnected,
            style: style.copyWith(color: Colors.black54, fontFamily: null),
          )
        : azimuth == null
        ? TextSpan(
            text: p.rotatorNoReading,
            style: style.copyWith(color: _aligned),
          )
        : turning
        ? TextSpan(
            style: style,
            children: [
              TextSpan(
                text: '$azimuth°',
                style: const TextStyle(color: _current),
              ),
              const TextSpan(
                text: ' ➜ ',
                style: TextStyle(color: _aligned),
              ),
              TextSpan(
                text: '$target°',
                style: const TextStyle(color: _target),
              ),
            ],
          )
        : TextSpan(
            text: '$azimuth°',
            style: style.copyWith(color: _aligned),
          );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
      decoration: BoxDecoration(color: _hud, borderRadius: BorderRadius.circular(Space.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(heading),
          if (live && elevation != null)
            Text(
              p.rotatorElevation(degrees: elevation!),
              style: style.copyWith(color: _aligned, fontSize: (style.fontSize ?? 14) * 0.8),
            ),
        ],
      ),
    );
  }
}

/// The outlines projected once per centre, on a disc of radius 1.
class _Outlines {
  final Path coast;
  final Path borders;
  final Path graticule;

  _Outlines(AzimuthalProjection projection, WorldOutlines world)
    : coast = _linePath(projection, world.land),
      borders = _linePath(projection, world.borders),
      graticule = _linePath(projection, _graticule());

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

  /// Each line broken where it nears the antipode or jumps across it, and
  /// at a pole: a land ring's only points there are the cut that closes
  /// Antarctica, which is not a coast.
  static Path _linePath(AzimuthalProjection projection, List<Float32List> lines) {
    final path = Path();
    for (final line in lines) {
      Offset? last;
      for (var i = 0; i + 1 < line.length; i += 2) {
        final lat = line[i + 1];
        final p = projection.project(lat, line[i]);
        if (lat.abs() >= 89.99 || p.distance > math.pi * _antipodeCutoff) {
          last = null;
          continue;
        }
        final point = Offset(p.x, p.y);
        if (last == null || (point - last).distance > _longestStep) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
        last = point;
      }
    }
    return path;
  }
}

class _RotatorPainter extends CustomPainter {
  final double radius;
  final AzimuthalProjection? projection;
  final _Outlines? outlines;
  final ui.Image? image;
  final bool dark;
  final RotatorMapPalette palette;
  final GridLocation? dx;
  final int? azimuth;
  final int? target;
  final int beamWidth;

  /// North, east, south and west, in that order.
  final List<String> labels;
  final TextStyle labelStyle;
  final Color rimColor;

  _RotatorPainter({
    required this.radius,
    required this.projection,
    required this.outlines,
    required this.image,
    required this.dark,
    required this.palette,
    required this.dx,
    required this.azimuth,
    required this.target,
    required this.beamWidth,
    required this.labels,
    required this.labelStyle,
    required this.rimColor,
  });

  Color _dim(Color color) => dark ? Color.lerp(color, Colors.black, _darkDimming)! : color;

  /// A heading as the canvas measures angles: from east, clockwise.
  static double _angle(num heading) => (heading - 90) * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    final center = size.center(Offset.zero);
    final disc = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(center, radius, Paint()..color = projection == null ? rimColor.withValues(alpha: 0.06) : _dim(palette.sea));
    if (image case final image?) {
      canvas.save();
      canvas.clipPath(Path()..addOval(disc));
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), disc, Paint()..filterQuality = FilterQuality.medium);
      canvas.restore();
    }
    if (outlines case final outlines?) {
      canvas.save();
      canvas.clipPath(Path()..addOval(disc));
      canvas.translate(center.dx, center.dy);
      canvas.scale(radius);
      Paint line(Color color, double width) => Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = width / radius;
      canvas.drawPath(outlines.graticule, line(const Color(0x66444444), 0.5));
      canvas.drawPath(outlines.borders, line(_dim(palette.coast).withValues(alpha: 0.6), 0.5));
      canvas.drawPath(outlines.coast, line(_dim(palette.coast), 0.8));
      canvas.restore();
    }

    _paintBeam(canvas, center);

    if ((projection, dx) case (final projection?, final dx?)) {
      final spot = projection.project(dx.latitude, dx.longitude);
      final at = center + Offset(spot.x, spot.y) * radius;
      canvas.drawCircle(at, 5, Paint()..color = _dx);
      canvas.drawCircle(
        at,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white,
      );
    }
    if (projection != null) {
      canvas.drawCircle(center, 5, Paint()..color = Colors.white);
      canvas.drawCircle(center, 3.5, Paint()..color = const Color(0xFF222222));
    }

    _paintRim(canvas, center);
  }

  void _paintBeam(Canvas canvas, Offset center) {
    final azimuth = this.azimuth;
    if (azimuth == null) return;
    final target = this.target;
    final turning = target != null && rotatorHeadingGap(azimuth, target) > rotatorArrivedWithin;
    final color = turning ? _current : _aligned;
    if (beamWidth > 0) {
      final sweep = beamWidth.clamp(1, 360) * math.pi / 180;
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..arcTo(Rect.fromCircle(center: center, radius: radius), _angle(azimuth) - sweep / 2, sweep, false)
          ..close(),
        Paint()..color = color.withValues(alpha: 0.22),
      );
    }
    if (turning) _paintArrow(canvas, center, target, _target);
    _paintArrow(canvas, center, azimuth, color);
  }

  void _paintArrow(Canvas canvas, Offset center, int heading, Color color) {
    final direction = Offset(math.cos(_angle(heading)), math.sin(_angle(heading)));
    final normal = Offset(-direction.dy, direction.dx);
    final tip = center + direction * radius;
    const head = 12.0;
    canvas.drawLine(
      center,
      tip - direction * head,
      Paint()
        ..color = color
        ..strokeWidth = 2.5,
    );
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((tip - direction * head + normal * head / 2).dx, (tip - direction * head + normal * head / 2).dy)
        ..lineTo((tip - direction * head - normal * head / 2).dx, (tip - direction * head - normal * head / 2).dy)
        ..close(),
      Paint()..color = color,
    );
  }

  void _paintRim(Canvas canvas, Offset center) {
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..color = rimColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, rim);
    for (var heading = 0; heading < 360; heading += 10) {
      final direction = Offset(math.cos(_angle(heading)), math.sin(_angle(heading)));
      final length = heading % 30 == 0 ? 7.0 : 4.0;
      canvas.drawLine(center + direction * (radius - length), center + direction * radius, rim..strokeWidth = 1);
    }
    for (var quarter = 0; quarter < 4; quarter++) {
      final heading = quarter * 90;
      final text = TextPainter(
        text: TextSpan(
          text: labels[quarter],
          style: labelStyle.copyWith(color: rimColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final direction = Offset(math.cos(_angle(heading)), math.sin(_angle(heading)));
      final at = center + direction * (radius + _labelMargin / 2);
      text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(_RotatorPainter old) =>
      old.radius != radius ||
      old.outlines != outlines ||
      old.image != image ||
      old.dark != dark ||
      old.palette != palette ||
      old.dx != dx ||
      old.azimuth != azimuth ||
      old.target != target ||
      old.beamWidth != beamWidth ||
      !listEquals(old.labels, labels) ||
      old.labelStyle != labelStyle ||
      old.rimColor != rimColor;
}
