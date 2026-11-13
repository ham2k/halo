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
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/views/map/map_grayline.dart' show antisolarPoint, capAround;
import 'package:ham2k_logger/views/operation/panel_scene/scene_map.dart' show mapCircleFill;
import 'package:ham2k_logger/views/operation/panel_scene/scene_world.dart' show WorldPaths, nightCap;
import 'package:ham2k_logger/views/operation/world_map/map_projection.dart';
import 'package:ham2k_logger/views/operation/world_map/world_geometry.dart';

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

  group('the land', () {
    late WorldOutlines world;
    setUpAll(() {
      final json = jsonDecode(File('assets/geo/world-110m.json').readAsStringSync()) as Map<String, dynamic>;
      world = WorldOutlines.fromJson(json);
    });

    test('holds land and leaves the sea', () {
      expect(ringsHold(world.land, 38.5, -98), isTrue, reason: 'Kansas');
      expect(ringsHold(world.land, -15, 25), isTrue, reason: 'Zambia');
      expect(ringsHold(world.land, 30, -40), isFalse, reason: 'the North Atlantic');
      expect(ringsHold(world.land, 0, -150), isFalse, reason: 'the Pacific');
    });

    // A ring that crosses the antimeridian runs on past +180, and only the
    // copy laid a turn west holds its far side; Antarctica goes the whole
    // way round, and only its closure along the pole makes it a polygon.
    test('holds land across the antimeridian and round the South Pole', () {
      expect(ringsHold(world.land, 66, -173), isTrue, reason: 'Chukotka, east of 180');
      expect(ringsHold(world.land, 66, 175), isTrue, reason: 'Chukotka, west of 180');
      expect(ringsHold(world.land, -85, 0), isTrue, reason: 'Antarctica');
      expect(ringsHold(world.land, -89.9, 120), isTrue, reason: 'the pole itself');
      expect(ringsHold(world.land, -50, 0), isFalse, reason: 'the Southern Ocean, north of it');
    });

    // The fill is what the operator sees as land: a projection that lays a
    // ring across its seam wrongly floods the sea along that meridian, and an
    // azimuthal map whose antipode is on land turns every continent into sea
    // and the sea into land, while every coastline stays where it belongs.
    test('is filled where it is in every projection, across the seam and round the antipode', () {
      for (final projection in <MapProjection>[
        const MercatorProjection(0),
        const MercatorProjection(-74),
        const EquirectangularProjection(-74),
        const PattersonProjection(0),
        const RobinsonProjection(150),
        AzimuthalProjection(gridToLocation('FN31pr')!),
        AzimuthalProjection(gridToLocation('IN80do')!), // Spain: its antipode is in New Zealand
      ]) {
        final land = fillRings(projection, world.land);
        bool filled(double lat, double lon) => land.contains(switch (projection) {
          // The whole disc, up to the antipode the map leaves undrawn.
          final AzimuthalProjection disc => Offset(disc.project(lat, lon).x, disc.project(lat, lon).y),
          _ => projection.toMap(lat, lon)!,
        });
        final name = '${projection.runtimeType} ${projection is AzimuthalProjection ? projection.center : ''}';
        expect(filled(38.5, -98), isTrue, reason: 'Kansas, $name');
        expect(filled(-15, 25), isTrue, reason: 'Zambia, $name');
        expect(filled(30, -40), isFalse, reason: 'the North Atlantic, $name');
        expect(filled(-30, -120), isFalse, reason: 'the South Pacific, $name');
        expect(filled(66, -173), isTrue, reason: 'Chukotka, east of 180, $name');
        expect(filled(66, 175), isTrue, reason: 'Chukotka, west of 180, $name');
        expect(filled(-80, 0), isTrue, reason: 'Antarctica, $name');
      }
      final spain = AzimuthalProjection(gridToLocation('IN80do')!);
      final north = spain.project(-38, 176); // the North Island, a few degrees off the antipode
      expect(fillRings(spain, world.land).contains(Offset(north.x, north.y)), isTrue, reason: 'the land round the antipode, which projects inside out');
    });

    // The night's caps go through the same fill: one round a pole has no
    // edge of its own there, and filled as the ring alone it would shade the
    // day side of the world and leave the polar night lit.
    test('a night that holds a pole is filled up to the pole, not round the other side', () {
      final midwinter = DateTime.utc(2026, 12, 21, 12);
      final cap = capAround(antisolarPoint(midwinter), 90 - 0.833);
      final ring = Float32List.fromList([
        for (final p in cap) ...[p.longitude, p.latitude],
      ]);
      for (final projection in <MapProjection>[
        const MercatorProjection(0),
        const MillerProjection(0),
        const RobinsonProjection(0),
        AzimuthalProjection(const GridLocation(40, -74)),
      ]) {
        final night = fillRings(projection, [ring]);
        expect(night.contains(projection.toMap(80, 0)!), isTrue, reason: 'the Arctic in December, ${projection.runtimeType}');
        expect(night.contains(projection.toMap(-60, 0)!), isFalse, reason: 'the Antarctic in December, ${projection.runtimeType}');
        expect(night.contains(projection.toMap(0, 180)!), isTrue, reason: 'midnight at noon UTC, ${projection.runtimeType}');
        expect(night.contains(projection.toMap(0, 0)!), isFalse, reason: 'noon, ${projection.runtimeType}');
      }
    });

    // The rim clips a fill round the antipode, and the night is blurred:
    // ended at the rim, it would fade there, where the antipode, the middle
    // of the night when it is in night, is.
    test('round the antipode, the fill runs on past the rim', () {
      final spain = AzimuthalProjection(gridToLocation('IN80do')!);
      expect(fillRings(spain, world.land).contains(const Offset(1.03, 0)), isTrue);
    });

    // The outlines made ready for one cylindrical projection are reused as
    // it turns; taken up by another, they would draw its world in the first
    // one's shape.
    test('the outlines made ready for one projection are not taken up by another', () {
      final robinson = WorldPaths(const RobinsonProjection(0), world, null);
      final turned = WorldPaths(const RobinsonProjection(40), world, null, turning: robinson.turning);
      expect(identical(turned.turning, robinson.turning), isTrue, reason: 'a turn of the same projection takes them up');
      final mercator = WorldPaths(const MercatorProjection(0), world, null, turning: robinson.turning);
      expect(mercator.land.getBounds(), WorldPaths(const MercatorProjection(0), world, null).land.getBounds());
    });
  });

  // A blurred night that ends at the pole's edge fades along it, a lighter
  // band in the middle of the polar night.
  test('a night that holds a pole the map draws on its edge runs on past the edge', () {
    final midwinter = antisolarPoint(DateTime.utc(2026, 12, 21, 12));
    for (final projection in <CylindricalProjection>[const EquirectangularProjection(0), const PattersonProjection(0), const RobinsonProjection(0)]) {
      final night = nightCap(projection, midwinter, 90 - 0.833);
      final top = projection.world.top;
      expect(night.contains(Offset(0, top - 0.01)), isTrue, reason: '${projection.runtimeType}: past the North Pole in December');
      expect(night.contains(Offset(0, -top + 0.01)), isFalse, reason: '${projection.runtimeType}: past the South Pole, in daylight');
    }
  });

  // A circle wider than 90° and its middle's latitude holds both poles, and
  // its edge is a plain loop round the antipode; filled as it is, the map
  // shades the far side of the Earth and leaves the station's own side bare.
  test('a distance circle that holds both poles is filled on the station\'s side', () {
    const ny = GridLocation(40.7, -74);
    for (final projection in <MapProjection>[const MercatorProjection(0), const RobinsonProjection(0), AzimuthalProjection(ny)]) {
      Offset at(double lat, double lon) => switch (projection) {
        final AzimuthalProjection disc => Offset(disc.project(lat, lon).x, disc.project(lat, lon).y),
        _ => projection.toMap(lat, lon)!,
      };
      final wide = mapCircleFill(projection, ny, 15000);
      expect(wide.contains(at(ny.latitude, ny.longitude)), isTrue, reason: '${projection.runtimeType}: New York, in its own circle');
      expect(wide.contains(at(-20.7, 106)), isFalse, reason: '${projection.runtimeType}: the Indian Ocean, 20° from its antipode');
      final near = mapCircleFill(projection, ny, 1000);
      expect(near.contains(at(ny.latitude, ny.longitude)), isTrue, reason: '${projection.runtimeType}: a small one too');
      expect(near.contains(at(0, 0)), isFalse, reason: '${projection.runtimeType}');
    }
  });

  // The caps are made ready once for a projection's type and turned with
  // its meridian; made ready for one meridian and drawn at another, they
  // must cover what a fresh projection would.
  test('the night made ready once turns with a Robinson map as a fresh one is laid', () {
    final at = antisolarPoint(DateTime.utc(2026, 6, 21, 3));
    final turning = TurningShapes.rings(const RobinsonProjection(0), [
      Float32List.fromList([
        for (final p in capAround(at, 90 - 6)) ...[p.longitude, p.latitude],
      ]),
    ]);
    const turned = RobinsonProjection(40);
    final reused = nightCap(turned, at, 90 - 6, turning: turning);
    final fresh = nightCap(turned, at, 90 - 6);
    for (var lat = -80.0; lat <= 80; lat += 20) {
      for (var lon = -170.0; lon <= 170; lon += 20) {
        final p = turned.toMap(lat, lon)!;
        expect(reused.contains(p), fresh.contains(p), reason: '$lat, $lon');
      }
    }
  });
}
