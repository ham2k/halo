// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An operation's location has two halves and every writer of one puts both
// down together (docs/design/locations.md). app-polo's location screen does
// not: it stores `grid` alone, so an operation moved there keeps the
// coordinate it had — and a coordinate OUTRANKS the grid at every reader,
// which means the map, the distances and the nearby search all answer for
// where the operator no longer is, while the location screen shows the
// locator they just typed. The same screen writes `''` for a location never
// set, which is not null and so reads as "located" to everything that asks.
//
// Both are repaired where an outside record enters, so no reader has to
// distrust what it reads. An operation's record only: a QSO's own Latitude
// and Longitude are the operator stating where a station is, and they
// deliberately outlive an edit to the grid beside them, so the two
// disagreeing there is a statement rather than a stale half.

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  group('repairStatedLocation', () {
    test('drops a coordinate that falls outside the stated square', () {
      // FN31pr's own center, under a locator half the continent away.
      final fields = <String, dynamic>{'grid': 'DM33xk', 'lat': 41.7292, 'lon': -72.7292};
      expect(repairStatedLocation(fields), isTrue);
      expect(fields, {'grid': 'DM33xk'});
    });

    test('keeps a coordinate the square contains', () {
      // A fix inside the square says MORE than the square — it is what the
      // locator was derived from, and dropping it would throw away the
      // precision this whole shape exists to keep.
      final fields = <String, dynamic>{'grid': 'FN31pr', 'lat': 41.7292, 'lon': -72.7292};
      expect(repairStatedLocation(fields), isFalse);
      expect(fields['lat'], 41.7292);
    });

    test('keeps a station standing on a cell boundary', () {
      // A coordinate that has been through an ADIF file is rounded, so an
      // edge is a tolerance, not a comparison — this pair is the corner of
      // FN31 and must not read as contradicting it.
      final cell = gridCell('FN31')!;
      final corner = GridLocation(cell.center.latitude + cell.latSize / 2, cell.center.longitude + cell.lonSize / 2);
      final fields = <String, dynamic>{'grid': 'FN31', 'lat': corner.latitude, 'lon': corner.longitude};
      expect(repairStatedLocation(fields), isFalse);
    });

    test('drops a locator that names no place, and the source that describes it', () {
      for (final unplaceable in ['', '   ', 'IL2', 'nonsense']) {
        final fields = <String, dynamic>{'grid': unplaceable, 'gridSource': 'gps', 'stationCall': 'N0DEV'};
        expect(repairStatedLocation(fields), isTrue, reason: 'grid "$unplaceable"');
        expect(fields, {'stationCall': 'N0DEV'}, reason: 'grid "$unplaceable"');
      }
    });

    // app-polo follows `gridSource: 'refs'` as this app writes it, and
    // removing the park clears the grid to `''` while its merge keeps the
    // pair. Left behind, that pair places the operation at the park it no
    // longer references, as a location no rule here will ever move again.
    test('drops the coordinate beside a locator that was emptied', () {
      final fields = <String, dynamic>{'grid': '', 'gridSource': '', 'lat': 41.7292, 'lon': -72.7292};
      expect(repairStatedLocation(fields), isTrue);
      expect(fields, isEmpty);
    });

    test('leaves a record that states no grid at all', () {
      final fields = <String, dynamic>{'lat': 41.7292, 'lon': -72.7292};
      expect(repairStatedLocation(fields), isFalse);
      expect(fields, {'lat': 41.7292, 'lon': -72.7292});
    });

    test('leaves a placeholder locator alone, both halves of it', () {
      // `AA00` decodes like any other square, off Antarctica. Reading it as a
      // statement about where the station is would evict a real coordinate in
      // favour of a place that names nothing.
      final fields = <String, dynamic>{'grid': 'AA00', 'lat': 41.7292, 'lon': -72.7292};
      expect(repairStatedLocation(fields), isFalse);
      expect(fields['lat'], 41.7292);
    });

    test('drops a placeholder pair beside a real locator', () {
      // No reader in the app takes 0,0 or the AA00aa center as a location, but
      // extension hooks receive the stored record raw; kept, the pair outranks
      // the square for them and places the station at Null Island or the pole.
      for (final (lat, lon) in [(0, 0), (-89.979167, -179.958333)]) {
        final fields = <String, dynamic>{'grid': 'FN31pr', 'lat': lat, 'lon': lon};
        expect(repairStatedLocation(fields), isTrue, reason: '$lat,$lon');
        expect(fields, {'grid': 'FN31pr'});
      }
    });

    test('never reads a country-file centroid as the coordinate to judge', () {
      // A `locSource: 'prefix'` pair may be west-positive and is refused wherever
      // one is read; judging the grid against it would mirror the station
      // about the prime meridian and then drop the locator's own coordinate
      // for disagreeing with a pair nothing trusts.
      final fields = <String, dynamic>{'grid': 'FN31pr', 'lat': 41.0, 'lon': 72.0, 'locSource': 'prefix'};
      expect(repairStatedLocation(fields), isFalse);
      expect(fields['lat'], 41.0);
    });
  });

  group('the coordinate it judges against', () {
    test('reads the ADIF form the program this repair exists for actually sends', () {
      // app-polo's import copies `MY_LAT`/`LAT` verbatim, so a well-formed
      // coordinate arrives as a string and the QSON normalizer converts it —
      // AFTER this runs. Judging the raw value would find no coordinate on
      // exactly the records written by the writer being repaired, and the
      // contradicting pair would then be coerced into a number and stored.
      final fields = <String, dynamic>{'grid': 'DM33xk', 'lat': 'N041 43.750', 'lon': 'W072 43.750'};
      expect(repairStatedLocation(fields), isTrue);
      expect(fields, {'grid': 'DM33xk'});
    });

    test('keeps a coordinate an ADIF round trip rounded over the edge', () {
      // The margin past a cell's edge is a FRACTION of the cell, which for a
      // ten-character square (19m of latitude) is under a metre — finer than
      // the thousandth of a minute ADIF stores. A station at the very edge of
      // its own square would then come back from a file outside it and lose
      // the coordinate for contradicting the locator it was derived from.
      // Half a step is the most that rounding can move a stored value.
      const grid = 'FN31pr55aa';
      final cell = gridCell(grid)!;
      final overTheEdge = GridLocation(cell.center.latitude + cell.latSize / 2 + 1 / 120000, cell.center.longitude + cell.lonSize / 2 + 1 / 120000);
      final fields = <String, dynamic>{'grid': grid, 'lat': overTheEdge.latitude, 'lon': overTheEdge.longitude};
      expect(repairStatedLocation(fields), isFalse);
    });

    test('an explicit null locator is a record with none, not one to rewrite', () {
      // Rewriting every such row would touch logs that have nothing wrong
      // with them, for a record that already reads as unlocated.
      final fields = <String, dynamic>{'grid': null, 'stationCall': 'N0DEV'};
      expect(repairStatedLocation(fields), isFalse);
      expect(fields.containsKey('grid'), isTrue);
    });
  });

  group('through a sync merge', () {
    late HaLoDatabase db;
    late OperationsRepository operations;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      operations = OperationsRepository(db);
    });

    tearDown(() async => db.close());

    test('an operation relocated by a grid-only peer measures from the new square', () async {
      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'N0DEV', 'grid': 'FN31pr', 'lat': 41.7292, 'lon': -72.7292, 'updatedAtMillis': 1000},
      ]);
      expect((await operations.get('op'))!.location?.latitude, 41.7292, reason: 'sanity: the fix is kept');

      // The peer rewrote the locator and knows nothing about the pair.
      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'N0DEV', 'grid': 'DM33xk', 'lat': 41.7292, 'lon': -72.7292, 'updatedAtMillis': 2000},
      ]);

      final stored = (await operations.get('op'))!;
      expect(stored.exactLocation, isNull);
      expect(stored.location, gridToLocation('DM33xk'));
      expect(stored.displayGrid, 'DM33xk', reason: 'the locator the operator typed is what is shown');
    });

    test('an operation with no location set arrives with none, not with an empty one', () async {
      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'N0DEV', 'grid': '', 'updatedAtMillis': 1000},
      ]);

      final stored = (await operations.get('op'))!;
      // Not `''`: every reader asking whether this operation has a grid gets
      // a straight answer, including the one that decides whether to offer it
      // a location at all (`locationFollowsRefs`).
      expect(stored.grid, isNull);
      expect(stored.location, isNull);
    });
  });
}
