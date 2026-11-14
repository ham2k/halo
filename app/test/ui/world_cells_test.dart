// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A map draws only the cells of the world its view reaches. Each cut is a
// way to lose land or invent it: a cell's land that is not the land there,
// a cell left out of a view that shows it, a coast drawn along a cut.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/views/operation/panel_scene/scene_world.dart' show WorldPaths;
import 'package:ham2k_logger/views/operation/world_map/map_projection.dart';
import 'package:ham2k_logger/views/operation/world_map/world_cells.dart';
import 'package:ham2k_logger/views/operation/world_map/world_geometry.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;

void main() {
  for (final asset in ['world-110m', 'world-50m']) {
    group(asset, () {
      late WorldOutlines world;
      late List<WorldCell> cells;
      setUpAll(() {
        world = WorldOutlines.fromJson(jsonDecode(File('assets/geo/$asset.json').readAsStringSync()) as Map<String, dynamic>);
        cells = worldCells(world, null);
      });

      // Clipped wrongly, a ring that leaves a cell and comes back, a lake,
      // or Antarctica closed along the pole fills its cell's sea or empties
      // its land.
      test('the cells hold the land the whole rings hold, and no more', () {
        final random = math.Random(7);
        final pieces = [for (final cell in cells) ...cell.land];
        for (var n = 0; n < 4000; n++) {
          final lat = random.nextDouble() * 179.8 - 89.9, lon = random.nextDouble() * 360 - 180;
          expect(ringsHold(pieces, lat, lon), ringsHold(world.land, lat, lon), reason: '$lat, $lon');
        }
      });

      // A coast cut at each cell edge is the same coast, and no more: a
      // piece of the step down to the pole that closes Antarctica would be
      // drawn as a coast across it.
      test('the cells\' coasts are the coast, cut where it crosses an edge', () {
        double length(Iterable<Float32List> lines) {
          var sum = 0.0;
          for (final line in lines) {
            for (var i = 0; i + 3 < line.length; i += 2) {
              if (line[i + 1].abs() >= 89.99 || line[i + 3].abs() >= 89.99) continue;
              sum += math.sqrt(math.pow(line[i + 2] - line[i], 2) + math.pow(line[i + 3] - line[i + 1], 2));
            }
          }
          return sum;
        }

        expect(length([for (final cell in cells) ...cell.coast]), closeTo(length(world.land), 0.01));
        expect(length([for (final cell in cells) ...cell.borders]), closeTo(length(world.borders), 0.01));
      });

      // Each piece is drawn only when its cell is in view: a piece filed
      // under the wrong cell is culled where it shows.
      test('every piece lies in its cell', () {
        for (final cell in cells) {
          for (final piece in [...cell.land, ...cell.coast, ...cell.borders]) {
            for (var i = 0; i + 1 < piece.length; i += 2) {
              expect(piece[i], inInclusiveRange(cell.west - 1e-3, cell.west + cellDegrees + 1e-3), reason: 'cell ${cell.west}, ${cell.south}');
              expect(piece[i + 1], inInclusiveRange(cell.south - 1e-3, cell.south + cellDegrees + 1e-3), reason: 'cell ${cell.west}, ${cell.south}');
            }
          }
        }
      });

      // A repeating map's copies are each cut on whole pixels: land that
      // stopped at 180° would leave the pixel the cut falls in part bare, a
      // hairline down the Bering Strait.
      test('land at 180° runs on past the edge of a repeating world', () {
        const mercator = MercatorProjection(0);
        final edge = mercator.toMap(66, 179.999)!;
        final view = Rect.fromCenter(center: edge, width: 0.1, height: 0.1);
        final land = WorldPaths(mercator, world, null).within(view).land;
        expect(land.contains(Offset(mercator.world.right + 0.002, edge.dy)), isTrue, reason: 'Chukotka, past the east edge');
        expect(land.contains(Offset(mercator.world.left - 0.002, edge.dy)), isTrue, reason: 'Chukotka, past the west edge');
      });

      // The view's own land, wherever it is: across the seam of a turned
      // Robinson map, where a cell is laid a turn west to reach in from the far
      // edge, round
      // Antarctica, and on the disc next to the antipode, where a cell's
      // land is filled inside out.
      test('a view draws the land it shows, in every projection', () {
        final views = <(MapProjection, GridLocation, double)>[
          (const MercatorProjection(0), const GridLocation(36, 138), 0.2), // Japan
          (const RobinsonProjection(-155), const GridLocation(0, 26), 0.15), // the Congo at the left edge: its cell runs on past 180° and is laid a turn west
          (const RobinsonProjection(-30), const GridLocation(-80, 160), 0.2), // Antarctica
          (const EquirectangularProjection(0), const GridLocation(66, 179), 0.1), // Chukotka, across 180
          (AzimuthalProjection(const GridLocation(40.4, -3.7)), const GridLocation(-38, 176), 0.05), // New Zealand from Spain
          (AzimuthalProjection(const GridLocation(40.7, -74)), const GridLocation(51.5, 0), 0.1), // London from New York
        ];
        for (final (projection, middle, half) in views) {
          final paths = WorldPaths(projection, world, null, turning: null);
          final c = switch (projection) {
            final AzimuthalProjection disc => Offset(disc.project(middle.latitude, middle.longitude).x, disc.project(middle.latitude, middle.longitude).y),
            _ => projection.toMap(middle.latitude, middle.longitude)!,
          };
          final view = Rect.fromCenter(center: c, width: half * 2, height: half * 2);
          final drawn = paths.within(view).land, whole = fillRings(projection, world.land);
          var differ = 0;
          for (var i = 0; i <= 40; i++) {
            for (var j = 0; j <= 40; j++) {
              final p = view.topLeft + Offset(view.width * i / 40, view.height * j / 40);
              // Past a curved world's edge the whole world's fill runs on, and the map's clip cuts it.
              if (projection.edge.contains(p) && drawn.contains(p) != whole.contains(p)) differ++;
            }
          }
          // A coast cut at a cell edge gains a point on the projected curve
          // that the whole ring's chord passes a hair away from, so a sample
          // on the coast may differ; a cell left out differs in hundreds.
          expect(differ, lessThan(17), reason: '${projection.runtimeType} round ${middle.latitude}, ${middle.longitude}');
          expect(
            drawn.computeMetrics().length,
            lessThan(whole.computeMetrics().length),
            reason: 'only part of the world, ${projection.runtimeType} round ${middle.latitude}, ${middle.longitude}',
          );
        }
      });
    });
  }

  // A border is only unwrapped from where it starts: one that starts at
  // -179 and runs west goes on past -180, into columns below 0.
  test('a line west of -180 is filed under its own cell', () {
    final cells = worldCells(
      WorldOutlines(
        land: const [],
        borders: [
          Float32List.fromList([-179, 5, -185, 5]),
        ],
      ),
      null,
    );
    expect([for (final c in cells) (c.west, c.south)], unorderedEquals([(-180.0, 0.0), (-190.0, 0.0)]));
  });
}
