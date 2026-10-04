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

    test('an exact coordinate outranks the grid, rather than filling in for a missing one', () {
      // The grid is normally DERIVED from the coordinate, so the two agree to
      // within the square — this fixture disagrees on purpose, because a
      // resolver that treats `exact` as a fallback still passes every
      // agreeing case.
      const fix = GridLocation(41.7135, -72.7278);
      final resolved = locationForQsoInfoWithSource(exact: fix, grid: 'AA00', entityPrefix: 'K', state: 'CA')!;
      expect(resolved.location, fix);
      expect(resolved.source, QsoLocationSource.exact);
    });

    test('an exact coordinate is not approximate; the centroid fallbacks are', () {
      // Drives the "~" and the rounding on the call-info distance line: a
      // fix rendered as approximate understates what the app knows, and a
      // country centroid rendered as exact overstates it badly.
      expect(QsoLocationSource.exact.isApproximate, isFalse);
      expect(QsoLocationSource.grid.isApproximate, isFalse);
      expect(QsoLocationSource.region.isApproximate, isTrue);
      expect(QsoLocationSource.entity.isApproximate, isTrue);
    });

    test('falls through to the grid when the coordinate is absent', () {
      final resolved = locationForQsoInfoWithSource(grid: 'FN31pr')!;
      expect(resolved.source, QsoLocationSource.grid);
    });
  });

  group('locationFromGuess', () {
    test('a coordinate tagged as a country-file centroid is refused, whatever its sign', () {
      // `locSource: 'prefix'` is lib-country-files' tag, and the `lon` under
      // it is cty.dat's WEST-POSITIVE one: K's centroid arrives as +91.87, in
      // Kazakhstan. Reading it would beat the guess's own grid AND the
      // correctly-signed entityLocations table, so both signs are refused —
      // one that happens to look plausible is still the wrong convention.
      expect(locationFromGuess({'lat': 37.6, 'lon': 91.87, 'locSource': 'prefix'}), isNull);
      expect(locationFromGuess({'lat': 51.3, 'lon': -9.7, 'locSource': 'prefix'}), isNull);
    });

    test('a real lookup coordinate answers', () {
      // QRZ and the Ham2K lookup report a station's actual position and write
      // no `locSource` at all — refusing those would cost the map every fix
      // it has.
      expect(locationFromGuess({'lat': 41.7135, 'lon': -72.7278}), const GridLocation(41.7135, -72.7278));
      expect(locationFromGuess(null), isNull);
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
      // (The Tokyo–SF crossing is covered by the split test above, which
      // additionally checks the split structure itself.)
      const cases = [
        (GridLocation(85, 170), GridLocation(85, -170)), // near-pole crossing
        (GridLocation(-40, 175), GridLocation(-35, -110)), // southern ocean
      ];
      for (final (a, b) in cases) {
        for (final segment in greatCirclePoints(a, b)) {
          for (var i = 1; i < segment.length; i++) {
            expect((segment[i].longitude - segment[i - 1].longitude).abs(), lessThan(180), reason: 'jump within a polyline for $a → $b');
          }
        }
      }
    });
  });

  group('circleOnEarth', () {
    test('every point is the radius away from the centre, at any latitude', () {
      // A circle built in raw degrees is an ellipse everywhere but the
      // equator — at 64°N a degree of longitude is less than half a degree of
      // latitude, and an activator would be told they were in range when
      // they were not.
      for (final center in const [GridLocation(0, 0), GridLocation(51.5, -0.12), GridLocation(64.1, -21.9), GridLocation(-45.0, 170.5)]) {
        for (final point in circleOnEarth(center, 1.0)) {
          expect(distanceOnEarthKm(center, point), closeTo(1.0, 0.001), reason: 'around $center');
        }
      }
    });

    test('closes the ring on its own first point', () {
      final ring = circleOnEarth(const GridLocation(41.9, -74.4), 0.5, numPoints: 16);
      expect(ring, hasLength(17));
      expect(ring.last, ring.first);
    });

    test('stays continuous across the antimeridian', () {
      // Split like a great-circle line, an area would become two open halves
      // with nothing to fill.
      final ring = circleOnEarth(const GridLocation(-44.0, 179.999), 1.0);
      for (var i = 1; i < ring.length; i++) {
        expect((ring[i].longitude - ring[i - 1].longitude).abs(), lessThan(1));
      }
    });
  });
}
