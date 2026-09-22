// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A record's `deleted` flag does not arrive as a JSON boolean. This app is
// the only writer that spells one that way: PoLo copies its SQLite column
// straight into what it pushes (the integer 1), and LoFi's delete endpoint
// writes the same integer into the stored blob, which LoFi then hands back
// verbatim. Read strictly against `true`, every one of those is "not
// deleted" — a tombstoned operation comes back to life, silently, and for
// good, because the record that would correct it ties on the revision stamp
// from then on and the staleness gate skips it.
//
// The tie is not only the old bug's doing: LoFi's delete does not touch
// `updatedAtMillis`, so a web delete ALWAYS ties with the live copy a device
// already holds. Both halves are needed for a delete to travel at all.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  group('asQsonBool', () {
    test('accepts every dialect a flag reaches us in', () {
      // The integer is PoLo's and LoFi's; the strings are what a blob that
      // round-trips through a stringly-typed store comes back as. Losing any
      // one of them resurrects the record it was meant to bury.
      for (final value in <Object>[true, 1, 'true', '1']) {
        expect(asQsonBool(value), isTrue, reason: '$value (${value.runtimeType}) means deleted');
      }
    });

    test('reads a false flag as false rather than as merely present', () {
      // `!!0` is TRUE in Ruby, which is how the server once marked live
      // records deleted — so this is enumerated, never probed for
      // truthiness. `0` and `'0'` are PoLo's spelling for a LIVE record and
      // travel on every one of them.
      for (final value in <Object?>[null, false, 0, '0', 'false', '']) {
        expect(asQsonBool(value), isFalse, reason: '$value must not delete anything');
      }
    });

    test('an unrecognised spelling leaves the log alone rather than guessing', () {
      // Rails would cast every one of these true, so a record spelled this
      // way IS deleted server-side and stays visible here. That asymmetry is
      // chosen: the alternative rule — everything but a known false value is
      // a tombstone — hides an operator's log on any value nobody meant as a
      // delete. A writer that starts producing one of these gets added to
      // asQsonBool by name, and this expectation flips with it.
      for (final value in <Object?>['yes', 'on', 't', 2]) {
        expect(asQsonBool(value), isFalse, reason: '$value is not a spelling any writer produces');
      }
    });
  });

  group('inbound operations', () {
    late HaLoDatabase db;
    late OperationsRepository operations;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      operations = OperationsRepository(db);
    });

    tearDown(() async => db.close());

    test('a record deleted in PoLo arrives deleted, not live', () async {
      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'VK1AO', 'deleted': 1, 'updatedAtMillis': 1000},
      ]);

      expect((await operations.get('op'))!.deleted, isTrue);
      expect(await operations.watchAll().first, isEmpty, reason: 'a tombstone must not reach the home list');
    });

    test('a live record from PoLo carries deleted: 0 and stays live', () async {
      // The other half of the dialect, and the one that would break if the
      // flag were read for presence rather than for value.
      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'VK1AO', 'deleted': 0, 'updatedAtMillis': 1000},
      ]);

      expect((await operations.get('op'))!.deleted, isFalse);
      expect(await operations.watchAll().first, hasLength(1));
    });

    test('a tombstone that ties on the stamp still buries the row it names', () async {
      // Exactly what a delete from the LoFi web UI looks like: the same
      // record, the same `updatedAtMillis`, one flag added. Rejected as
      // stale, the delete would never reach this device at all.
      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'VK1AO', 'updatedAtMillis': 1000},
      ]);
      expect((await operations.get('op'))!.deleted, isFalse, reason: 'sanity: live to begin with');

      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'VK1AO', 'updatedAtMillis': 1000, 'deleted': 1},
      ]);

      expect((await operations.get('op'))!.deleted, isTrue);
    });

    test('a tie leaves the row it already agrees with alone', () async {
      // The repair must not fire on every re-delivery of an ordinary record:
      // nothing here disagrees, and a write would dirty a settled row.
      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'VK1AO', 'userTitle': 'Kept', 'updatedAtMillis': 1000},
      ]);
      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'VK1AO', 'userTitle': 'Kept', 'updatedAtMillis': 1000},
      ]);

      final row = (await operations.get('op'))!;
      expect(row.deleted, isFalse);
      expect(row.userTitle, 'Kept');
    });

    test('an OLDER tombstone never undoes a newer local revision', () async {
      // Strictly stale, not tied: the operator edited the operation after the
      // delete and that edit is the newest thing anyone holds. Widening the
      // repair from "tie" to "stale" would silently re-delete their work.
      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'VK1AO', 'updatedAtMillis': 2000},
      ]);

      await operations.mergeFromSync([
        {'uuid': 'op', 'stationCall': 'VK1AO', 'updatedAtMillis': 1000, 'deleted': 1},
      ]);

      expect((await operations.get('op'))!.deleted, isFalse);
    });

    test('a tie leaves a row with unpushed local edits alone', () async {
      // A dirty row's own revision has not reached the server yet, so the
      // record that ties with it describes a world that has not seen it. The
      // push settles which one wins; a repair here would pre-empt it.
      final op = await operations.create(stationCall: 'VK1AO');
      await (db.update(
        db.operations,
      )..where((row) => row.uuid.equals(op.uuid))).write(const OperationsCompanion(synced: Value(false), updatedAtMillis: Value(1000)));

      await operations.mergeFromSync([
        {'uuid': op.uuid, 'stationCall': 'VK1AO', 'updatedAtMillis': 1000, 'deleted': 1},
      ]);

      expect((await operations.get(op.uuid))!.deleted, isFalse);
    });
  });

  group('inbound QSOs', () {
    late HaLoDatabase db;
    late OperationsRepository operations;
    late QsosRepository qsos;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      operations = OperationsRepository(db);
      qsos = QsosRepository(db);
    });

    tearDown(() async => db.close());

    test('a contact deleted in PoLo arrives deleted', () async {
      final op = await operations.create(stationCall: 'VK1AO');
      await qsos.mergeFromSync([
        {
          'uuid': 'qso',
          'operation': op.uuid,
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': 1000,
          'updatedAtMillis': 1000,
          'deleted': 1,
        },
      ]);

      expect((await qsos.get('qso'))!.deleted, isTrue);
    });

    test('a tombstone that ties buries the contact and drops it from the count', () async {
      // The count is a cached column no query recomputes on its own, so a
      // repair that only flips the flag leaves the operation claiming a
      // contact its log no longer shows.
      final op = await operations.create(stationCall: 'VK1AO');
      const record = {
        'uuid': 'qso',
        'operation': null,
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': 1000,
        'updatedAtMillis': 1000,
      };
      await qsos.mergeFromSync([
        {...record, 'operation': op.uuid},
      ]);
      expect((await operations.get(op.uuid))!.qsoCount, 1, reason: 'sanity: counted while live');

      await qsos.mergeFromSync([
        {...record, 'operation': op.uuid, 'deleted': 1},
      ]);

      expect((await qsos.get('qso'))!.deleted, isTrue);
      expect((await operations.get(op.uuid))!.qsoCount, 0);
    });

    test('an OLDER tombstone never undoes a newer local revision', () async {
      final op = await operations.create(stationCall: 'VK1AO');
      await qsos.mergeFromSync([
        {
          'uuid': 'qso',
          'operation': op.uuid,
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': 1000,
          'updatedAtMillis': 2000,
        },
      ]);

      await qsos.mergeFromSync([
        {
          'uuid': 'qso',
          'operation': op.uuid,
          'their': {'call': 'W1AW'},
          'band': '20m',
          'mode': 'SSB',
          'startAtMillis': 1000,
          'updatedAtMillis': 1000,
          'deleted': 1,
        },
      ]);

      expect((await qsos.get('qso'))!.deleted, isFalse);
    });
  });
}
