// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `locationFollowsRefs` places an operation that has no location of its own
// from its references, and keeps following them only while the location is
// one it placed (docs/design/locations.md, "Located by its references").

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

const _park = {'type': 'potaActivation', 'ref': 'US-1234', 'grid': 'FN21ab', 'lat': 41.7135, 'lon': -74.5278};
const _parkLocation = GridLocation(41.7135, -74.5278);
const _otherPark = {'type': 'potaActivation', 'ref': 'US-5678', 'grid': 'FN31pr', 'lat': 41.71, 'lon': -72.73};
const _trail = {'type': 'potaActivation', 'ref': 'US-4567', 'grid': 'FM05', 'lat': 35.6, 'lon': -83.5, 'largeArea': true};

/// [before] with its refs replaced, the way every writer of refs builds the
/// record it saves.
Map<String, dynamic> _withRefs(Map<String, dynamic> before, List<Map<String, dynamic>> refs) => {...before, 'refs': refs};

void main() {
  group('an operation with no location', () {
    test("takes the first ref's published coordinate", () {
      final after = _withRefs({}, [_park]);
      expect(locationFollowsRefs({}, after), isTrue);
      expect(after['lat'], _parkLocation.latitude);
      expect(after['lon'], _parkLocation.longitude);
      // Derived from the coordinate, not copied from the ref's coarser `grid`:
      // the pair stored on the operation has to agree with itself.
      expect(after['grid'], locationToGrid6(_parkLocation.latitude, _parkLocation.longitude));
      expect(after['gridSource'], refsGridSource);
    });

    test("falls back to the ref's own grid for a program that publishes no coordinates", () {
      final after = _withRefs({}, [
        {'type': 'x', 'ref': 'X-1', 'grid': 'FN21ab'},
      ]);
      locationFollowsRefs({}, after);
      expect(after['grid'], 'FN21ab');
      // The square's center, the pair a hand-stated grid is written with — it
      // claims nothing the grid did not.
      expect(Operation(uuid: 'op', data: after).location, gridToLocation('FN21ab'));
    });

    test('skips refs that cannot place it, and takes the first that can', () {
      final after = _withRefs({}, [
        {'type': 'x', 'ref': 'X-1'},
        // AA00 decodes like any other square; adopted, it would stand the
        // operation off Antarctica, outranking every honest source.
        {'type': 'x', 'ref': 'X-2', 'grid': 'AA00'},
        _trail,
        _otherPark,
      ]);
      locationFollowsRefs({}, after);
      expect(after['lat'], _otherPark['lat']);
    });

    // The guard this exists for: a trail or a multi-state park publishes one
    // point for hundreds of kilometres of reference, and an operation placed
    // there would compute every distance and nearby search from the wrong
    // state.
    test('is never placed by a largeArea ref', () {
      final after = _withRefs({}, [_trail]);
      expect(locationFollowsRefs({}, after), isFalse);
      expect(Operation(uuid: 'op', data: after).location, isNull);
    });

    // An operation from a grid-only peer carries `grid: ''` for a location
    // never set (locations.md), and `''` is not null. Judged on the raw field
    // it reads as located and never gets a second chance.
    test('counts a stored grid that names no place as no location', () {
      for (final unplaceable in ['', 'IL2']) {
        final before = {'grid': unplaceable};
        final after = _withRefs(before, [_park]);
        expect(locationFollowsRefs(before, after), isTrue, reason: 'grid "$unplaceable" is not a location');
        expect(after['gridSource'], refsGridSource);
      }
    });
  });

  group('a location the refs placed', () {
    late Map<String, dynamic> placed;
    setUp(() {
      placed = _withRefs({}, [_park]);
      locationFollowsRefs({}, placed);
    });

    test('moves when the park is replaced', () {
      final after = _withRefs(placed, [_otherPark]);
      expect(locationFollowsRefs(placed, after), isTrue);
      expect(after['lat'], _otherPark['lat']);
      expect(after['gridSource'], refsGridSource);
    });

    // All four keys at once: a grid left behind without its pair, or a pair
    // without its grid, would leave a half-location answering for a park the
    // operation no longer references.
    test('is cleared, whole, when no ref can place it any more', () {
      for (final refs in [
        <Map<String, dynamic>>[],
        [_trail],
      ]) {
        final after = _withRefs(placed, refs);
        expect(locationFollowsRefs(placed, after), isTrue);
        expect(after.keys, isNot(anyOf(contains('grid'), contains('gridSource'), contains('lat'), contains('lon'))));
      }
    });

    test('stays put when a second park is added', () {
      final after = _withRefs(placed, [_park, _otherPark]);
      expect(locationFollowsRefs(placed, after), isFalse);
      expect(after['lat'], _parkLocation.latitude);
    });
  });

  group('a location from anywhere else', () {
    test('is never touched by the refs', () {
      for (final source in ['manual', 'gps', null]) {
        final before = {'grid': 'EM79', 'gridSource': source, 'lat': 39.5, 'lon': -84.0};
        final after = _withRefs(before, [_park]);
        expect(locationFollowsRefs(before, after), isFalse, reason: 'gridSource $source');
        expect(after['grid'], 'EM79');
      }
    });

    // The Location screen and the refs can change in one save — the sheet
    // writes its whole draft at once. What the operator stated wins.
    test('stated in the same write outranks the refs', () {
      final before = <String, dynamic>{};
      final after = {
        'refs': [_park],
        'grid': 'EM79',
        'gridSource': 'manual',
        'lat': 39.5,
        'lon': -84.0,
      };
      expect(locationFollowsRefs(before, after), isFalse);
      expect(after['grid'], 'EM79');
    });
  });

  test('a write that leaves the refs alone changes nothing', () {
    final before = _withRefs({'title': 'a'}, [_park]);
    final after = {...before, 'title': 'b'};
    expect(locationFollowsRefs(before, after), isFalse);
    expect(after.containsKey('grid'), isFalse);
  });

  group('OperationsRepository.saveData', () {
    late HaLoDatabase db;
    tearDown(() async => db.close());

    // Every local writer of refs goes through here — the Activities view, a
    // deep-linked operation, an import — so this is the one place the rule
    // cannot be bypassed by a writer that forgot it.
    test('places, keeps and clears an operation by the refs it saves', () async {
      db = HaLoDatabase(NativeDatabase.memory());
      final operations = OperationsRepository(db);
      final op = await operations.create(stationCall: 'N0DEV');
      Future<Operation> save(List<Map<String, dynamic>> refs) async {
        final current = (await operations.get(op.uuid))!;
        await operations.saveData(Operation(uuid: op.uuid, data: _withRefs(current.data, refs)));
        return (await operations.get(op.uuid))!;
      }

      expect((await save([_park])).location, _parkLocation);
      expect((await save([_park, _otherPark])).location, _parkLocation);
      expect((await save([])).location, isNull);
    });

    // The Activities view runs the rule on its draft at every refs edit, and
    // the operator can clear the location on the Location screen after that.
    // The save compares against the stored row, which predates the sheet:
    // refs changed, no location — re-run there, the rule puts the cleared
    // location back.
    test('leaves a draft as the sheet decided it when told the refs are handled', () async {
      db = HaLoDatabase(NativeDatabase.memory());
      final operations = OperationsRepository(db);
      final op = await operations.create(stationCall: 'N0DEV');
      final draft = _withRefs(op.data, [_park]);
      locationFollowsRefs(op.data, draft);
      final cleared = {...draft, 'grid': null, 'gridSource': null, 'lat': null, 'lon': null};

      await operations.saveData(Operation(uuid: op.uuid, data: cleared), followRefs: false);
      expect((await operations.get(op.uuid))!.location, isNull);

      final other = await operations.create(stationCall: 'N0DEV');
      await operations.saveData(Operation(uuid: other.uuid, data: {...cleared}));
      expect((await operations.get(other.uuid))!.location, _parkLocation, reason: 'the trap the flag exists for');
    });
  });
}
