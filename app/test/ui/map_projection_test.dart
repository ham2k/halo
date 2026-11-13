// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene's map answers a click by asking where on Earth the point is
// (toEarth) and draws the land, markers and lines by projecting places
// (toMap). The two must be one another's inverse, or a click on a marker
// reports a place a few hundred kilometres off it while the map still looks
// like a map. The lines must follow the great
// circle, which is the whole reason a radio map draws them, and cross its
// seam into the next copy of the world rather than streak back across it.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_world.dart' show projectLines;
import 'package:ham2k_logger/views/operation/world_map/map_camera.dart';
import 'package:ham2k_logger/views/operation/world_map/map_projection.dart';

void main() {
  final places = [
    const GridLocation(40.7, -74), // New York
    const GridLocation(35.7, 139.7), // Tokyo, past the antimeridian from a meridian of -74
    const GridLocation(-33.9, 151.2), // Sydney
    const GridLocation(-54.8, -68.3), // Ushuaia
    const GridLocation(64.1, -21.9), // Reykjavík
    const GridLocation(0.1, 179.9), // on the antimeridian
  ];

  group('each projection finds the place a point was projected from', () {
    for (final (name, projection) in [
      ('mercator', const MercatorProjection(0)),
      ('mercator off Greenwich', const MercatorProjection(-74)),
      ('equirectangular', const EquirectangularProjection(-74)),
      ('miller', const MillerProjection(-74)),
      ('patterson', const PattersonProjection(-74)),
      ('robinson', const RobinsonProjection(0)),
      ('robinson off Greenwich', const RobinsonProjection(150)),
      ('azimuthal', AzimuthalProjection(const GridLocation(40.7, -74))),
    ]) {
      test(name, () {
        for (final place in places) {
          final p = projection.toMap(place.latitude, place.longitude);
          if (p == null) continue;
          final back = projection.toEarth(p.dx, p.dy)!;
          expect(back.latitude, closeTo(place.latitude, 1e-6), reason: '$place');
          expect(wrapLongitude(back.longitude - place.longitude), closeTo(0, 1e-6), reason: '$place');
        }
      });
    }
  });

  test('Web Mercator is the web\'s: a square world cut at 85.05°, the meridian in the middle', () {
    const projection = MercatorProjection(-74);
    expect(projection.toMap(MercatorProjection.cutLatitude, -74)!.dy, closeTo(-math.pi, 1e-6));
    expect(projection.toMap(0, -74)!.distance, closeTo(0, 1e-9));
    expect(projection.toMap(0, 106)!.dx.abs(), closeTo(math.pi, 1e-6), reason: 'the far side of the meridian is the edge');
    expect(projection.toMap(86, 0), isNull, reason: 'past the cut, nothing is drawn rather than pinned to the edge');
  });

  // Each formula checked against its published value at the pole, where a
  // wrong coefficient shows most; Patterson's inverse is a search, so it is
  // checked all the way up, where its slope is steepest.
  test('the rectangular worlds that reach the poles: plate carrée twice as wide as tall, Miller\'s and Patterson\'s poles where they publish them', () {
    expect(const EquirectangularProjection(0).world.size, Size(2 * math.pi, math.pi));
    expect(const MillerProjection(0).top, closeTo(2.3034, 1e-4));
    expect(const PattersonProjection(0).top, closeTo(1.790857183, 1e-8));
    for (final projection in [const EquirectangularProjection(0), const MillerProjection(0), const PattersonProjection(0)]) {
      expect(projection.toMap(90, 0)!.dy, closeTo(-projection.top, 1e-9), reason: '${projection.runtimeType}: the pole is the top edge');
    }
    const patterson = PattersonProjection(0);
    for (var lat = -90.0; lat <= 90; lat += 0.5) {
      expect(patterson.latitudeAt(patterson.heightOf(lat)), closeTo(lat, 1e-7), reason: '$lat');
    }
  });

  test('Robinson\'s is the published table: 60° sits at 0.7346 of the height, the poles 0.5322 as long as the equator', () {
    const projection = RobinsonProjection(0);
    expect(projection.toMap(60, 0)!.dy, closeTo(-1.3523 * 0.7346, 1e-9));
    expect(projection.toMap(0, 180)!.dx.abs(), closeTo(0.8487 * math.pi, 1e-9));
    expect(projection.toMap(90, 180)!.dx.abs() / projection.toMap(0, 180)!.dx.abs(), closeTo(0.5322, 1e-9));
    expect(projection.toEarth(0.8487 * math.pi * 0.9, -1.3523 * 0.999), isNull, reason: 'outside the world\'s edge near the pole');
  });

  test('a great circle is the shortest way, not the straight line on the map', () {
    const ny = GridLocation(40.7, -74), tokyo = GridLocation(35.7, 139.7);
    final path = greatCircle(ny, tokyo);
    var length = 0.0;
    for (var i = 1; i < path.length; i++) {
      length += distanceOnEarthKm(path[i - 1], path[i]);
    }
    expect(length, closeTo(distanceOnEarthKm(ny, tokyo), 1));
    // The way over the Arctic: a line along the parallels would never pass 41°.
    expect(path.map((p) => p.latitude).reduce(math.max), greaterThan(65));
    expect(path.first.latitude, closeTo(ny.latitude, 1e-9));
    expect(path.last.longitude, closeTo(tokyo.longitude, 1e-9));
  });

  // A line across the seam drawn as one stroke from its last point on one
  // side to its first on the other streaks across the whole map; dropped at
  // the seam, a map that repeats east and west shows it with a gap there.
  test('a line that crosses the seam runs on past the edge and in from the other, never back across the map', () {
    for (final projection in <CylindricalProjection>[const MercatorProjection(0), const PattersonProjection(0), const RobinsonProjection(0)]) {
      final across = projectLines(projection, [
        Float32List.fromList([178, 10, 179.5, 10, -179.5, 10, -178, 10]),
      ]);
      final world = projection.world;
      final pieces = across.computeMetrics().map((m) => m.extractPath(0, m.length).getBounds()).toList();
      expect(pieces, hasLength(2), reason: '${projection.runtimeType}: once from each edge');
      for (final piece in pieces) {
        expect(piece.width, lessThan(world.width * 0.02), reason: '${projection.runtimeType}');
        expect(
          piece.left < world.right && piece.right > world.right || piece.left < world.left && piece.right > world.left,
          isTrue,
          reason: '${projection.runtimeType}: across an edge',
        );
      }
    }
  });

  group('the camera', () {
    const projection = MercatorProjection(0);

    test('zoom 0 fits the whole world in the pane, and each level doubles it', () {
      final camera = MapCamera(const Size(800, 500), projection, zoom: 0, center: Offset.zero, margin: 0);
      expect(projection.world.height * camera.scale, closeTo(500, 1e-6));
      final closer = MapCamera(const Size(800, 500), projection, zoom: 1, center: Offset.zero, margin: 0);
      expect(closer.scale / camera.scale, closeTo(2, 1e-9));
    });

    test('a pan stops where the view would leave its bounds, and a view wider than them sits at their middle', () {
      final bounds = projectedBounds(projection, north: 60, south: 20, west: -130, east: -60);
      final far = MapCamera(const Size(400, 400), projection, zoom: 4, center: const Offset(3, -3), bounds: bounds);
      expect(far.visible.right, closeTo(bounds.right, 1e-9));
      expect(far.visible.top, closeTo(bounds.top, 1e-9));
      final wide = MapCamera(const Size(400, 400), projection, zoom: 0, center: const Offset(3, -3), bounds: bounds);
      expect(wide.center, bounds.center);
    });

    // Without the wrap a pan stops at the antimeridian, and the Pacific is
    // split across both edges of the map at any zoom.
    test('a camera that wraps goes on round the world, and finds the place under a point on any copy', () {
      final camera = MapCamera(const Size(800, 500), projection, zoom: 2, center: const Offset(math.pi * 1.5, 0), wraps: true);
      expect(camera.center.dx, closeTo(-math.pi * 0.5, 1e-9), reason: 'a world\'s breadth east is the same place');
      expect(camera.copies, hasLength(1));
      final seam = MapCamera(const Size(800, 500), projection, zoom: 2, center: const Offset(math.pi * 0.99, 0), wraps: true);
      expect(seam.copies, [0, projection.world.width], reason: 'the view runs past the east edge into the next copy');
      final east = seam.placeAt(seam.toScreen(const Offset(math.pi * 1.1, 0)))!;
      expect(east.longitude, closeTo(-162, 1e-6));
    });

    test('a zoom keeps the place under the pointer where it was', () {
      final camera = MapCamera(const Size(800, 500), projection, zoom: 2, center: const Offset(0.5, -0.5));
      const pointer = Offset(620, 140);
      final under = camera.toMap(pointer);
      final next = MapCamera(const Size(800, 500), projection, zoom: 3.5, center: camera.centerKeeping(under, pointer, 3.5));
      expect(next.toScreen(under).dx, closeTo(pointer.dx, 1e-6));
      expect(next.toScreen(under).dy, closeTo(pointer.dy, 1e-6));
    });
  });

  // A covering view that lets the pane run past a curved edge shows the
  // panel's background in its corners; one that holds it too far in keeps
  // the operator from zooming out to the widest view that fills the pane.
  test('a view that covers fills the pane with the world at its widest, and a pan stops at the edge', () {
    const pane = Size(400, 400);
    for (final projection in <MapProjection>[const RobinsonProjection(0), AzimuthalProjection(const GridLocation(40, -74))]) {
      final name = '${projection.runtimeType}';
      final widest = MapCamera.coverZoom(pane, projection);
      final corners = [Offset.zero, const Offset(400, 0), const Offset(0, 400), const Offset(400, 400)];
      final camera = MapCamera(pane, projection, zoom: widest, center: Offset.zero, cover: true);
      expect(corners.every((c) => camera.placeAt(c) != null), isTrue, reason: '$name: every corner on the world');
      final wider = MapCamera(pane, projection, zoom: widest - 0.02, center: Offset.zero);
      expect(corners.every((c) => wider.placeAt(c) != null), isFalse, reason: '$name: the least zoom that does');
      final pushed = MapCamera(pane, projection, zoom: widest + 1, center: const Offset(0.3, -5), cover: true);
      expect(corners.every((c) => pushed.placeAt(c) != null), isTrue, reason: '$name: panned off the top, held on it');
      expect(pushed.center.dy, lessThan(-0.05), reason: '$name: as far toward it as the pane allows');
    }
    // Plate carrée is half as tall as wide: in a square pane its height sets the widest view, and it still wraps.
    const plate = EquirectangularProjection(0);
    final widest = MapCamera.coverZoom(pane, plate, wraps: true);
    expect(MapCamera(pane, plate, zoom: widest, center: Offset.zero, wraps: true).visible.height, closeTo(plate.world.height, 1e-9));
    final up = MapCamera(pane, plate, zoom: widest + 1, center: const Offset(4, -5), wraps: true, cover: true);
    expect(up.visible.top, closeTo(plate.world.top, 1e-9));
  });

  // Wrapped, bounds the whole way round put their east edge on their west
  // one, and the box stops a step short, leaving the last 22.5° out of reach.
  test('pan bounds the whole way round hold the whole world\'s breadth', () {
    for (final projection in <MapProjection>[const MercatorProjection(0), const PattersonProjection(0)]) {
      final box = projectedBounds(projection, north: 80, south: -60, west: -180, east: 180);
      expect(box.width, closeTo(projection.world.width, 1e-9), reason: '${projection.runtimeType}');
    }
  });
}
