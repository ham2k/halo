// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  group('distanceOnEarthKm', () {
    test('matches the known NYC–London great-circle distance', () {
      // ~5,570 km surface distance — the map's popup distances must be real
      // distances, not chord lengths or degree deltas.
      const nyc = GridLocation(40.7128, -74.0060);
      const london = GridLocation(51.5074, -0.1278);
      expect(distanceOnEarthKm(nyc, london), closeTo(5570, 20));
    });

    test('is zero for identical points', () {
      const p = GridLocation(37.6, -119.7);
      expect(distanceOnEarthKm(p, p), 0);
    });
  });

  group('bearingOnEarthDeg', () {
    test('points due east along the equator', () {
      // Same latitude, target to the east ⇒ ~90° (drifts slightly poleward
      // over long spans, so allow a small tolerance).
      final bearing = bearingOnEarthDeg(const GridLocation(0, 0), const GridLocation(0, 10));
      expect(bearing, closeTo(90, 0.5));
    });

    test('points due north along a meridian', () {
      final bearing = bearingOnEarthDeg(const GridLocation(0, 0), const GridLocation(10, 0));
      expect(bearing, closeTo(0, 0.5));
    });

    test('points due south along a meridian', () {
      final bearing = bearingOnEarthDeg(const GridLocation(10, 0), const GridLocation(0, 0));
      expect(bearing, closeTo(180, 0.5));
    });

    test('is normalized to 0–360 (west reads as 270, not -90)', () {
      final bearing = bearingOnEarthDeg(const GridLocation(0, 0), const GridLocation(0, -10));
      expect(bearing, closeTo(270, 0.5));
    });

    test('NYC→London heads roughly northeast', () {
      const nyc = GridLocation(40.7128, -74.0060);
      const london = GridLocation(51.5074, -0.1278);
      expect(bearingOnEarthDeg(nyc, london), closeTo(51, 5));
    });
  });

  group('locationForQsoInfo', () {
    test('prefers the grid over any coarser source', () {
      final location = locationForQsoInfo(grid: 'FN31pr', entityPrefix: 'K', state: 'CA')!;
      expect(location.latitude, closeTo(41.71, 0.05));
    });

    test('ignores placeholder grids and falls back to the state centroid', () {
      // AA00/AA00aa are "no real location" placeholders some sources emit —
      // plotting them would put the QSO in the Gulf of Guinea.
      final location = locationForQsoInfo(grid: 'AA00aa', entityPrefix: 'K', state: 'CA')!;
      expect(location.latitude, closeTo(37.6, 0.1));
      expect(location.longitude, closeTo(-119.7, 0.1));
    });

    test('uses the state/province centroid when there is no grid', () {
      final location = locationForQsoInfo(entityPrefix: 'VE', state: 'on')!;
      // Case-insensitive region match; Ontario, not the VE entity centroid.
      expect(location.longitude, closeTo(-85.5, 3));
    });

    test('falls back to the DXCC entity centroid for unknown regions', () {
      final withBogusState = locationForQsoInfo(entityPrefix: 'F', state: 'ZZ')!;
      final entityOnly = locationForQsoInfo(entityPrefix: 'F')!;
      expect(withBogusState.latitude, entityOnly.latitude);
      expect(withBogusState.longitude, entityOnly.longitude);
    });

    test('returns null when nothing usable is present', () {
      expect(locationForQsoInfo(), isNull);
      expect(locationForQsoInfo(grid: 'not-a-grid'), isNull);
      expect(locationForQsoInfo(entityPrefix: 'NOT-A-PREFIX'), isNull);
    });
  });

  group('greatCirclePoints', () {
    test('follows the great circle, not the rhumb line', () {
      // NYC→London: the great circle arcs well north of both endpoints'
      // latitudes — a straight lat/lon interpolation would never exceed 51.5°.
      const nyc = GridLocation(40.7128, -74.0060);
      const london = GridLocation(51.5074, -0.1278);
      final segments = greatCirclePoints(nyc, london);
      expect(segments, hasLength(1));
      final maxLat = segments.first.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
      expect(maxLat, greaterThan(52));
      expect(segments.first.first.latitude, closeTo(nyc.latitude, 0.01));
      expect(segments.first.last.latitude, closeTo(london.latitude, 0.01));
    });

    test('splits at the antimeridian instead of smearing across the map', () {
      // Tokyo→San Francisco crosses ±180°: one polyline must end at the
      // +180 edge and the next resume at -180, otherwise a 2D map draws a
      // line across the entire world.
      const tokyo = GridLocation(35.68, 139.65);
      const sf = GridLocation(37.77, -122.42);
      final segments = greatCirclePoints(tokyo, sf);
      expect(segments, hasLength(2));
      expect(segments[0].last.longitude, 180);
      expect(segments[1].first.longitude, -180);
      expect(segments[0].last.latitude, closeTo(segments[1].first.latitude, 0.01));
      for (final segment in segments) {
        for (var i = 1; i < segment.length; i++) {
          expect((segment[i].longitude - segment[i - 1].longitude).abs(), lessThan(180));
        }
      }
    });

    test('returns nothing for a zero-length arc', () {
      const p = GridLocation(35.68, 139.65);
      expect(greatCirclePoints(p, p), isEmpty);
    });

    test('returns nothing for antipodal endpoints instead of a garbage path', () {
      // Antipodal points have no unique great circle; the slerp divides by
      // sin(d) ≈ 0 and would emit points smeared across the whole map. Grid
      // centers and entity centroids are quantized, so exact antipodes are
      // constructible from real QSO data.
      expect(greatCirclePoints(const GridLocation(10, 95), const GridLocation(-10, -85)), isEmpty);
    });

    test('never leaves an antimeridian-sized jump inside one polyline', () {
      // A crossing that fails to split draws a line across the whole map —
      // the exact artifact this function exists to prevent.
      const cases = [
        (GridLocation(35.68, 139.65), GridLocation(37.77, -122.42)), // Tokyo–SF
        (GridLocation(85, 170), GridLocation(85, -170)), // near-pole crossing
        (GridLocation(-40, 175), GridLocation(-35, -110)), // southern ocean
      ];
      for (final (a, b) in cases) {
        for (final segment in greatCirclePoints(a, b)) {
          for (var i = 1; i < segment.length; i++) {
            expect((segment[i].longitude - segment[i - 1].longitude).abs(), lessThan(180),
                reason: 'jump within a polyline for $a → $b');
          }
        }
      }
    });
  });
}
