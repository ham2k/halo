// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Operations synced from a long-lived app-polo install can still carry its
// older `createdOnMillis`/`updatedOnMillis` spellings (polo rewrites them on
// read — `operationsDB.js`). Both matter here and fail silently:
//
//  - `createdAtMillis` is the ONLY date an operation with no QSOs has, so a
//    legacy empty operation with no fallback sorts as if created at epoch —
//    every one of them piling up at the bottom of the home list.
//  - `updatedAtMillis` decides which side of a sync merge wins, so a
//    revision-less legacy record loses to whatever it's compared against.

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  test('createdAtMillis reads the legacy spelling', () {
    const operation = Operation(uuid: 'op', data: {'createdOnMillis': 1700000000000});
    expect(operation.createdAtMillis, 1700000000000);
  });

  test('updatedAtMillis reads the legacy spelling', () {
    const operation = Operation(uuid: 'op', data: {'updatedOnMillis': 1700000000000});
    expect(operation.updatedAtMillis, 1700000000000);
  });

  test('the current spelling wins when a record somehow carries both', () {
    const operation = Operation(uuid: 'op', data: {'createdAtMillis': 2, 'createdOnMillis': 1});
    expect(operation.createdAtMillis, 2);
  });

  group('through a sync merge', () {
    late HaLoDatabase db;
    late OperationsRepository operations;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      operations = OperationsRepository(db);
    });

    tearDown(() async => db.close());

    test('an inbound legacy record keeps its dates, under the current names', () async {
      await operations.mergeFromSync([
        {'uuid': 'legacy-op', 'stationCall': 'N0DEV', 'createdOnMillis': 1700000000000, 'updatedOnMillis': 1700000000001},
      ]);

      final stored = (await operations.get('legacy-op'))!;
      expect(stored.createdAtMillis, 1700000000000);
      expect(stored.updatedAtMillis, 1700000000001);
      expect(stored.data.containsKey('createdOnMillis'), isFalse, reason: 'rewritten, not carried alongside');
    });

    test('a legacy record can still lose to a newer local edit', () async {
      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'N0DEV', 'updatedOnMillis': 2000},
      ]);
      // Same record, an older revision under the legacy name: must not win.
      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'CHANGED', 'updatedOnMillis': 1000},
      ]);

      expect((await operations.get('op'))!.stationCall, 'N0DEV');
    });
  });

  group('home ordering', () {
    late HaLoDatabase db;
    late OperationsRepository operations;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      operations = OperationsRepository(db);
    });

    tearDown(() async => db.close());

    test('operations with no QSOs sort by creation date, legacy ones included', () async {
      // Newest first, and the legacy-stamped one has to land by its date
      // rather than at the end.
      await operations.mergeFromSync([
        {'uuid': 'oldest', 'stationCall': 'N0DEV', 'createdAtMillis': 1000, 'updatedAtMillis': 1000},
        {'uuid': 'legacy-middle', 'stationCall': 'N0DEV', 'createdOnMillis': 2000, 'updatedOnMillis': 2000},
        {'uuid': 'newest', 'stationCall': 'N0DEV', 'createdAtMillis': 3000, 'updatedAtMillis': 3000},
      ]);

      final listed = await operations.watchAll().first;
      expect(listed.map((o) => o.uuid).toList(), ['newest', 'legacy-middle', 'oldest']);
    });
  });
}
