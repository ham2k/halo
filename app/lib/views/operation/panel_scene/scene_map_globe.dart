// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The globe's depth: what rounds its face, and the air round it, the one
// thing drawn past its rim. The face is lit from the upper left whatever
// the hour: the night the world draws is the sun's, this light is only
// there to show the shape.
//
// A RadialGradient's radius is a share of its box's shortest side, so on a
// box round the globe 0.5 is its rim.

import 'package:flutter/painting.dart';

/// Where the light falls on the globe's face, as a share of its radius.
const _light = Alignment(-0.42, -0.48);

/// The air round the globe when the scene names no color for it: its
/// alpha is how strong it is at the rim.
Color globeAirColor({required bool dark}) => dark ? const Color(0x996FA8FF) : const Color(0x998CB8FF);

/// Outside a globe of [radius] pixels at [middle], drawn before it: its
/// air, strongest at the rim and fading out [width] radii past it.
void paintGlobeAir(Canvas canvas, Offset middle, double radius, {required Color color, required double width}) {
  if (width <= 0 || color.a <= 0) return;
  final reach = radius * (1 + width);
  canvas.drawCircle(
    middle,
    reach,
    Paint()
      ..shader = RadialGradient(
        // Clear inside: with a sea that lets the world through, or no world, the air would tint its face.
        colors: [const Color(0x00000000), const Color(0x00000000), color, color.withValues(alpha: 0)],
        stops: [0, radius / reach, radius / reach, 1],
      ).createShader(Rect.fromCircle(center: middle, radius: reach)),
  );
}

/// Over the world and its night on a globe of [radius] pixels at [middle],
/// under what the scene draws: bright where it faces the light, falling to
/// dark round the far side and toward the rim all round, with a glint where
/// the light meets it, [depth] scaling how strongly, 0 leaving it flat; and
/// [air], when there is any, seen edge on just inside the rim.
void paintGlobeShade(Canvas canvas, Offset middle, double radius, {required bool dark, required double depth, Color? air}) {
  void fill(List<Color> colors, List<double> stops, {Alignment center = Alignment.center, double size = 0.5}) => canvas.drawCircle(
    middle,
    radius,
    Paint()..shader = RadialGradient(center: center, radius: size, colors: colors, stops: stops).createShader(Rect.fromCircle(center: middle, radius: radius)),
  );
  if (depth > 0) {
    fill(
      _deeper(const [Color(0x33FFFFFF), Color(0x00000000), Color(0x4D000000), Color(0x99000000)], depth),
      const [0, 0.3, 0.65, 1],
      center: _light,
      size: 0.75,
    );
    fill(_deeper(const [Color(0x00000000), Color(0x40000000)], depth), const [0.75, 1]);
  }
  if (air != null && air.a > 0) fill([air.withValues(alpha: 0), air.withValues(alpha: air.a * 0.6)], const [0.88, 1]);
  if (depth > 0) {
    final at = middle + Offset(_light.x * radius, _light.y * radius);
    canvas.drawCircle(
      at,
      radius * 0.35,
      Paint()
        ..shader = RadialGradient(
          colors: _deeper([Color(dark ? 0x26FFFFFF : 0x40FFFFFF), const Color(0x00FFFFFF)], depth),
        ).createShader(Rect.fromCircle(center: at, radius: radius * 0.35)),
    );
  }
}

/// [colors], each [depth] times as opaque, up to wholly.
List<Color> _deeper(List<Color> colors, double depth) => [for (final c in colors) c.withValues(alpha: (c.a * depth).clamp(0.0, 1.0))];
