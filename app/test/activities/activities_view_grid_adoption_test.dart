// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `locationToAdoptAfterAddingRef` decides whether adding an activity ref should
// fill in the operation's still-unset location — from live GPS when the ref is
// close by, or from the first ref's own position when there's no GPS fix at
// all. It answers with the coordinate as well as the locator, and the two must
// always describe the same place.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

void main() {
  const gps = GridLocation(41.69, -74.54);

  group('operation already has a grid', () {
    test('never overrides it, even for a very close ref with no GPS fix', () {
      expect(
        locationToAdoptAfterAddingRef(
          operationGrid: 'FN21rq',
          gpsPosition: gps,
          distanceKm: 1,
          refsAfterAdd: [
            {'grid': 'FN21ab'},
          ],
        ),
        isNull,
      );
    });
  });

  group('GPS available', () {
    test('adopts the fix itself when the added ref is within 15km', () {
      final adopted = locationToAdoptAfterAddingRef(
        operationGrid: null,
        gpsPosition: gps,
        distanceKm: 5,
        refsAfterAdd: const [],
      )!;
      // The coordinate, not the square it falls in: a fix reduced to a grid on
      // the way in cannot be recovered afterwards, and every distance the
      // operation goes on to compute inherits the error.
      expect(adopted.location, gps);
      expect(adopted.source, 'gps');
      expect(adopted.grid, locationToGrid8(gps.latitude, gps.longitude));
      expect(adopted.grid, hasLength(8));
    });

    test('does nothing when the added ref is farther than 15km', () {
      expect(
        locationToAdoptAfterAddingRef(
          operationGrid: null,
          gpsPosition: gps,
          distanceKm: 15.1,
          refsAfterAdd: const [],
        ),
        isNull,
      );
    });

    test('does nothing when the ref has no known distance (e.g. manually typed)', () {
      expect(
        locationToAdoptAfterAddingRef(
          operationGrid: null,
          gpsPosition: gps,
          distanceKm: null,
          refsAfterAdd: const [],
        ),
        isNull,
      );
    });
  });

  group('no GPS fix', () {
    test("adopts the first ref's published coordinate when it has one", () {
      final adopted = locationToAdoptAfterAddingRef(
        operationGrid: null,
        gpsPosition: null,
        distanceKm: null,
        refsAfterAdd: [
          {'ref': 'US-1234', 'grid': 'FN21ab', 'lat': 41.7135, 'lon': -74.5278},
        ],
      )!;
      expect(adopted.location, const GridLocation(41.7135, -74.5278));
      // Derived from the coordinate rather than copied from the ref's own
      // `grid`, which is the coarser statement of the same place: the pair
      // stored on the operation has to agree with itself.
      expect(adopted.grid, locationToGrid8(41.7135, -74.5278));
    });

    test("falls back to the first ref's own grid for a program that publishes no coordinates", () {
      final adopted = locationToAdoptAfterAddingRef(
        operationGrid: null,
        gpsPosition: null,
        distanceKm: null,
        refsAfterAdd: [
          {'ref': 'US-1234', 'grid': 'FN21ab'},
        ],
      )!;
      expect(adopted.grid, 'FN21ab');
      expect(adopted.location, isNull, reason: 'a grid is all that was known — claiming a coordinate would invent one');
    });

    test('does nothing when the first ref has no location of its own', () {
      expect(
        locationToAdoptAfterAddingRef(
          operationGrid: null,
          gpsPosition: null,
          distanceKm: null,
          refsAfterAdd: [
            {'ref': 'US-1234'},
          ],
        ),
        isNull,
      );
    });

    test('does nothing with no refs at all', () {
      expect(
        locationToAdoptAfterAddingRef(
          operationGrid: null,
          gpsPosition: null,
          distanceKm: null,
          refsAfterAdd: const [],
        ),
        isNull,
      );
    });
  });
}
