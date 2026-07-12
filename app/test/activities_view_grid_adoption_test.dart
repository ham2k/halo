// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `gridToAdoptAfterAddingRef` decides whether adding an activity ref should
// fill in the operation's still-unset grid — from live GPS when the ref is
// close by, or from the first ref's own grid when there's no GPS fix at all.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

void main() {
  const gps = GridLocation(41.69, -74.54);

  group('operation already has a grid', () {
    test('never overrides it, even for a very close ref with no GPS fix', () {
      expect(
        gridToAdoptAfterAddingRef(
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
    test('adopts the GPS grid when the added ref is within 15km', () {
      expect(
        gridToAdoptAfterAddingRef(
          operationGrid: null,
          gpsPosition: gps,
          distanceKm: 5,
          refsAfterAdd: const [],
        ),
        locationToGrid6(gps.latitude, gps.longitude),
      );
    });

    test('does nothing when the added ref is farther than 15km', () {
      expect(
        gridToAdoptAfterAddingRef(
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
        gridToAdoptAfterAddingRef(
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
    test("adopts the first ref's own grid", () {
      expect(
        gridToAdoptAfterAddingRef(
          operationGrid: null,
          gpsPosition: null,
          distanceKm: null,
          refsAfterAdd: [
            {'ref': 'US-1234', 'grid': 'FN21ab'},
          ],
        ),
        'FN21ab',
      );
    });

    test('does nothing when the first ref has no grid of its own', () {
      expect(
        gridToAdoptAfterAddingRef(
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
        gridToAdoptAfterAddingRef(
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
