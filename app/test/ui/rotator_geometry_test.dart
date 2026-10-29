// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rotator map turns the antenna to the angle of a tap from the centre.
// That is only the heading to the place tapped because the projection keeps
// every great circle from the centre straight — the property a different
// projection (or a sign slip in this one) quietly breaks, sending the beam
// somewhere else while the map looks right.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/views/operation/rotator/rotator_geometry.dart';

void main() {
  final pairs = [
    ('FN31pr', 'IO91wm'), // New England to London
    ('FN31pr', 'PM95'), // over the pole to Japan
    ('IN80do', 'RF80'), // Spain to New Zealand, near the antipode
    ('FF51', 'QF56'), // Chile to Australia, across the antimeridian
    ('BL11', 'CO70'), // Hawaii to Alaska, the other way across it
  ];

  test('a place\'s angle from the centre is the great-circle heading to it', () {
    for (final (from, to) in pairs) {
      final home = gridToLocation(from)!;
      final there = gridToLocation(to)!;
      final spot = AzimuthalProjection(home).project(there.latitude, there.longitude);
      expect(headingOf(spot.x, spot.y), closeTo(bearingOnEarthDeg(home, there), 0.01), reason: '$from → $to');
    }
  });

  test('distance from the centre is distance round the Earth, and the rim is the antipode', () {
    for (final (from, to) in pairs) {
      final home = gridToLocation(from)!;
      final there = gridToLocation(to)!;
      final spot = AzimuthalProjection(home).project(there.latitude, there.longitude);
      final radius = math.sqrt(spot.x * spot.x + spot.y * spot.y);
      expect(radius, closeTo(distanceOnEarthKm(home, there) / (math.pi * 6371), 0.001), reason: '$from → $to');
    }
    final home = gridToLocation('FN31pr')!;
    final antipode = AzimuthalProjection(home).project(-home.latitude, home.longitude - 180);
    expect(math.sqrt(antipode.x * antipode.x + antipode.y * antipode.y), closeTo(1, 1e-6));
  });

  test('locate finds the place a point on the disc was projected from', () {
    for (final (from, to) in pairs) {
      final projection = AzimuthalProjection(gridToLocation(from)!);
      final there = gridToLocation(to)!;
      final spot = projection.project(there.latitude, there.longitude);
      final back = projection.locate(spot.x, spot.y)!;
      expect(back.latitude, closeTo(there.latitude, 1e-6));
      expect(back.longitude, closeTo(there.longitude, 1e-6));
    }
    expect(AzimuthalProjection(gridToLocation('FN31pr')!).locate(0.8, 0.8), isNull, reason: 'outside the disc');
  });

  // The panel's grayline setting turns the night off by drawing with no
  // instant: a raster that shaded one anyway would leave the setting doing
  // nothing.
  test('a raster with no instant is all day, and one with an instant has a night side', () {
    final raster = DiscRaster(AzimuthalProjection(gridToLocation('FN31pr')!), LandMask.fill(const []), 64);
    Set<int> colours(DateTime? utc) {
      final pixels = raster.pixels(sea: 0xFF76ACD6, land: 0xFF9E7E3D, night: 0xFF000814, nightStep: 0.1, utc: utc);
      return {
        for (var i = 0; i < pixels.length; i += 4)
          if (pixels[i + 3] != 0) pixels[i] << 16 | pixels[i + 1] << 8 | pixels[i + 2],
      };
    }

    expect(colours(null), {0x76ACD6});
    expect(colours(DateTime.utc(2026, 10, 29, 12)).length, greaterThan(1));
  });

  group('the land mask', () {
    late LandMask mask;
    setUpAll(() {
      final json = jsonDecode(File('assets/geo/world-110m.json').readAsStringSync()) as Map<String, dynamic>;
      mask = WorldOutlines.fromJson(json).mask;
    });

    test('fills land and leaves the sea', () {
      expect(mask.isLand(38.5, -98), isTrue, reason: 'Kansas');
      expect(mask.isLand(-15, 25), isTrue, reason: 'Zambia');
      expect(mask.isLand(30, -40), isFalse, reason: 'the North Atlantic');
      expect(mask.isLand(0, -150), isFalse, reason: 'the Pacific');
    });

    // A ring that crosses the antimeridian runs on past +180, and only the
    // copy laid a turn west fills its far side; Antarctica goes the whole
    // way round, and only its closure along the pole makes it a polygon.
    test('fills land across the antimeridian and round the South Pole', () {
      expect(mask.isLand(66, -173), isTrue, reason: 'Chukotka, east of 180');
      expect(mask.isLand(66, 175), isTrue, reason: 'Chukotka, west of 180');
      expect(mask.isLand(-85, 0), isTrue, reason: 'Antarctica');
      expect(mask.isLand(-89.9, 120), isTrue, reason: 'the pole itself');
      expect(mask.isLand(-50, 0), isFalse, reason: 'the Southern Ocean, north of it');
    });
  });
}
