// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A map's label rides its edge into view: placed only where the edge is,
// it would vanish whenever the pane holds part of a circle but not its
// north, which zoomed in is nearly always; placed past the pane's side, it
// would be cut off; read right to left, it would be upside down.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/tools/distance_format.dart' show fmtGrouped;
import 'package:ham2k_logger/views/operation/panel_scene/scene_map_labels.dart';

void main() {
  const pane = Rect.fromLTWH(0, 0, 400, 300);
  // Along y = 150, from x = -400 to 800: three panes wide.
  final across = [
    [for (var x = -400.0; x <= 800; x += 40) Offset(x, 150)],
  ];

  test('in view, a label sits at its anchor', () {
    final at = placeMapLabel(across, pane, 60, const Offset(200, 150))!;
    expect(at.at, const Offset(200, 150));
    expect(at.angle, 0);
  });

  test('with its anchor out of view, it slides along the edge to the nearest place it fits whole', () {
    final at = placeMapLabel(across, pane, 60, const Offset(700, 150))!;
    expect(at.at.dx, closeTo(370, 1e-6), reason: 'its right end at the pane\'s side');
    final before = placeMapLabel(across, pane, 60, const Offset(-300, 150))!;
    expect(before.at.dx, closeTo(30, 1e-6));
  });

  test('one the scene placed is hidden while its place is out of view, not moved', () {
    expect(placeMapLabel(across, pane, 60, const Offset(700, 150), pinned: true), isNull);
    expect(placeMapLabel(across, pane, 60, const Offset(380, 150), pinned: true)!.at, const Offset(380, 150), reason: 'in view, its words run past the side');
    expect(placeMapLabel(across, pane, 60, const Offset(200, 150), pinned: true)!.at, const Offset(200, 150));
  });

  // Held to where the whole label fits, one at a line's start or end would
  // be half its width from there, never at it: hidden at every zoom.
  test('one the scene placed at a line\'s end sits there, running on past it', () {
    final line = [
      [const Offset(100, 150), const Offset(300, 150)],
    ];
    expect(placeMapLabel(line, pane, 60, const Offset(100, 150), pinned: true)!.at, const Offset(100, 150));
    expect(placeMapLabel(line, pane, 60, const Offset(300, 150), pinned: true)!.angle, 0);
  });

  test('an edge that crosses the pane between two points far apart still takes a label', () {
    // Zoomed in, a degree of a circle can be thousands of pixels: neither end is in view.
    final at = placeMapLabel(
      [
        [const Offset(-5000, 100), const Offset(5000, 200)],
      ],
      pane,
      60,
      const Offset(-5000, 100),
    );
    expect(at, isNotNull);
    expect(pane.contains(at!.at), isTrue);
  });

  test('a label reads upright whichever way its edge runs', () {
    final back = [
      [for (var x = 800.0; x >= -400; x -= 40) Offset(x, 150)],
    ];
    expect(placeMapLabel(back, pane, 60, const Offset(200, 150))!.angle, 0);
    final down = [
      [for (var y = 0.0; y <= 300; y += 10) const Offset(200, 0) + Offset(0, y)],
    ];
    final up = [down.single.reversed.toList()];
    expect(placeMapLabel(down, pane, 60, const Offset(200, 150))!.angle.abs(), closeTo(math.pi / 2, 1e-9));
    expect(placeMapLabel(up, pane, 60, const Offset(200, 150))!.angle.abs(), closeTo(math.pi / 2, 1e-9));
  });

  test('an edge too short in view for the words takes none', () {
    expect(
      placeMapLabel(
        [
          [const Offset(-100, 150), const Offset(30, 150)],
        ],
        pane,
        60,
        const Offset(0, 150),
      ),
      isNull,
    );
  });

  // A circle's ring starts at its north, where its label's anchor is: taken
  // from there, no place along it is both at the anchor and whole.
  test('its turn follows the curve under it, and it sits across where a ring closes', () {
    // A circle of radius 100 round (200, 150), its anchor at the top.
    final circle = [
      [for (var i = 0; i <= 180; i++) const Offset(200, 150) + Offset(math.sin(i * math.pi / 90), -math.cos(i * math.pi / 90)) * 100],
    ];
    final at = placeMapLabel(circle, pane, 60, const Offset(200, 50))!;
    expect(at.angle, closeTo(0, 1e-3));
    final side = placeMapLabel(circle, pane, 60, const Offset(300, 150))!;
    expect(side.angle.abs(), closeTo(math.pi / 2, 1e-3));
  });

  // A rotator's distance read off as text, "12345 km", is read wrong at a
  // glance where every other distance in the app is "12,345 km".
  test('a distance written as a number has thousands separators, and the decimals asked for', () {
    expect(fmtGrouped(12345.6), '12,346');
    expect(fmtGrouped(12345.6, decimals: 1), '12,345.6');
    expect(fmtGrouped(512), '512');
  });
}
