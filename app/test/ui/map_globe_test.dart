// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The globe shows its near half. What lies behind must not show through:
// a place behind drawn where it would fall on the far side lands on top of
// the near one, and a shape that goes behind, filled as its points fall,
// spreads its far half over the face of the globe.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;
import 'package:ham2k_logger/views/map/map_grayline.dart' show capAround;
import 'package:ham2k_logger/views/operation/world_map/map_projection.dart';
import 'package:ham2k_logger/views/operation/world_map/world_geometry.dart';

/// The ring [radius] degrees round [lat], [lon], as the map lays a circle out.
Float32List _ring(double lat, double lon, double radius) => Float32List.fromList([
  for (final p in capAround(GridLocation(lat, lon), radius)) ...[p.longitude, p.latitude],
]);

void main() {
  final globe = OrthographicProjection(const GridLocation(40, -30));

  test('a place in front comes back from where it is drawn, and one behind is not drawn', () {
    for (final (lat, lon) in [(40.0, -30.0), (10.0, -60.0), (70.0, 20.0), (-20.0, -10.0)]) {
      final at = globe.toMap(lat, lon)!;
      final back = globe.toEarth(at.dx, at.dy)!;
      expect(back.latitude, closeTo(lat, 1e-6));
      expect(back.longitude, closeTo(lon, 1e-6));
    }
    expect(globe.toMap(-40, 150), isNull, reason: 'the far side of the Earth');
    expect(globe.toEarth(0.8, 0.8), isNull, reason: 'past the rim');
  });

  test('a shape behind the globe fills nothing, and one across the horizon fills only its near part', () {
    final behind = fillRings(globe, [_ring(-40, 150, 10)]);
    for (final p in [Offset.zero, const Offset(0.5, 0.5), const Offset(-0.9, 0.1)]) {
      expect(behind.contains(p), isFalse);
    }
    // Round a place on the horizon: its near half is the crescent inside the rim.
    final edge = globe.toEarth(0.999, 0)!;
    final across = fillRings(globe, [_ring(edge.latitude, edge.longitude, 15)]);
    expect(across.contains(const Offset(0.98, 0)), isTrue, reason: 'its near half, inside the rim: 11.5° in from it');
    expect(across.contains(const Offset(0.3, 0)), isFalse, reason: 'not spread over the face of the globe');
    expect(across.contains(const Offset(-0.9, 0)), isFalse);
  });

  test('a shape round the point behind the globe\'s middle fills the band of it that shows round the rim', () {
    // 120° round the antipode reaches 30° past the horizon, all the way round.
    // A degree off it: a ring round a pole starts and ends on its middle's
    // meridian, which through the antipode itself turns a half circle on
    // the rim, either way round.
    final round = fillRings(globe, [_ring(-40, 151, 120)]);
    expect(round.contains(const Offset(0.97, 0)), isTrue);
    expect(round.contains(const Offset(0, -0.97)), isTrue);
    expect(round.contains(Offset.zero), isFalse);
    expect(round.contains(const Offset(0.5, 0)), isFalse, reason: 'sin 60°, 0.87, is where it starts');
  });

  // A circle's ring ends where it began only if it misses the poles: one
  // round a pole ends at the pole, the meridian back to its start one of
  // its edges. Left out, the circle is filled inside out; closed by a chord
  // instead of round the rim, a slice across the globe's face is.
  test('a circle round a pole fills what it holds and nothing else, whichever way the globe faces', () {
    final ring = _ring(-34, 151, 72);
    for (final facing in [const GridLocation(-34, 151), const GridLocation(-34, -29), const GridLocation(-80, 60), const GridLocation(20, -100)]) {
      final view = OrthographicProjection(facing);
      final fill = fillRings(view, [ring]);
      var wrong = 0, seen = 0;
      for (var x = -0.95; x < 1; x += 0.1) {
        for (var y = -0.95; y < 1; y += 0.1) {
          final place = view.toEarth(x, y);
          if (place == null) continue;
          final apart = degreesApart(place.latitude, place.longitude, -34, 151);
          if ((apart - 72).abs() < 3) continue; // On its edge, where a step's straight cut differs.
          seen++;
          if (fill.contains(Offset(x, y)) != apart < 72) wrong++;
        }
      }
      expect(wrong, 0, reason: 'facing ${facing.latitude}, ${facing.longitude}: $wrong of $seen places');
    }
  });
}
