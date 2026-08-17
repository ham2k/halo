// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `onUpgrade` path in database.dart, which until this file had never been
// executed by anything. Every other test builds a fresh in-memory database, so
// they all take `onCreate` — on the one path that carries an operator's
// existing log, which is their data of record, and where a mistake is silent.
//
// HOW THE OLD SCHEMAS ARE BUILT. drift's schema tooling wants a
// `drift_schemas/*.json` dump per historical version and this project has
// none. Each old schema is instead derived by UNDOING the migration steps from
// a fresh current database: drop `sequences` for v4, drop the two
// `updatedAtMillis` columns for v3, and so on.
//
// KNOW WHAT THAT CANNOT CATCH. The fixture is built by `onCreate`, so it is
// derived from the same declarations the migration is checked against. A
// column or index added to a table WITHOUT a matching `schemaVersion` bump
// therefore appears in the fixture too, survives untouched, and matches — the
// most common drift mistake is invisible to the upgrade tests by construction.
// `the current schema matches its golden snapshot` at the bottom is what
// covers that instead: the snapshot is a committed artifact rather than a
// re-derivation, so changing a table without updating it fails loudly and the
// author has to decide whether a version bump is owed.
//
// The v1 endpoint is verified against the real thing — the tables at 9f0885cf
// (`packages/polo_core/lib/src/db/database.dart`, before the HaLo rename) are
// current-minus-`updatedAtMillis`, column for column, including the
// `qsos_operation_start` index.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// What each version added, newest first — the inverse of `onUpgrade`.
/// Undoing an entry takes a database from that version down to the one below.
///
/// Every version from 2 up must appear, which the first test asserts: a
/// missing entry would leave the newest addition in the fixture, and drift's
/// `createTable` is `CREATE TABLE IF NOT EXISTS`, so that step would silently
/// no-op instead of being exercised.
const _undoToGetPreviousVersion = <int, List<String>>{
  8: ['ALTER TABLE operations DROP COLUMN purged_locally'],
  7: [
    'ALTER TABLE operations DROP COLUMN purged',
    'ALTER TABLE qsos DROP COLUMN purged',
  ],
  // v6 changed no schema entities — it backfills revision stamps — so there is
  // nothing to undo. The entry exists so the coverage check passes, and to
  // record that the version was considered.
  6: [],
  5: ['DROP TABLE sequences'],
  4: [
    'ALTER TABLE operations DROP COLUMN updated_at_millis',
    'ALTER TABLE qsos DROP COLUMN updated_at_millis',
  ],
  3: ['DROP TABLE lookups'],
  2: ['DROP TABLE operations_backup', 'DROP TABLE qsos_backup'],
};

/// The schema every fresh install must produce. Regenerate with
/// `dart run tool/dump_schema.dart` after a deliberate schema change — and ask
/// whether `schemaVersion` and a migration step are owed along with it.
final _goldenSchemaFile = File('test/golden/schema.sql');

void main() {
  late Directory tempDir;
  late int currentVersion;

  setUpAll(() async {
    // Read from the database rather than hardcoding: a literal here would
    // leave the newest migration step untested the moment someone bumps the
    // version, which is exactly what this file exists to prevent.
    final probe = HaLoDatabase(NativeDatabase.memory());
    currentVersion = probe.schemaVersion;
    await probe.close();
  });

  setUp(() => tempDir = Directory.systemTemp.createTempSync('halo_migration_test'));
  tearDown(() {
    // Guarded so a setUp failure surfaces as itself rather than as a deletion
    // error against a path that was never created.
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File dbFile([String name = 'db']) => File('${tempDir.path}/$name.sqlite');

  /// A database file at [version], with [whileAtOldVersion] applied before it
  /// is closed — i.e. while the schema really is the old one.
  Future<void> createAtVersion(
    File file,
    int version, {
    Future<void> Function(HaLoDatabase db)? whileAtOldVersion,
  }) async {
    final db = HaLoDatabase(NativeDatabase(file));
    try {
      // Any statement forces drift to open the file and run `onCreate`, which
      // builds the CURRENT schema — the starting point we then walk backwards.
      // Awaiting it also lets drift's own `user_version` write land before the
      // one below overwrites it.
      await db.customStatement('SELECT 1');

      for (var v = currentVersion; v > version; v--) {
        for (final statement in _undoToGetPreviousVersion[v]!) {
          await db.customStatement(statement);
        }
      }
      await db.customStatement('PRAGMA user_version = $version');
      if (whileAtOldVersion != null) await whileAtOldVersion(db);
    } finally {
      // Not optional: the undo statements above are the ones this file is
      // designed to see fail, and a leaked handle turns that clear failure
      // into a teardown error about deleting an open file.
      await db.close();
    }
  }

  /// `sqlite_master` for the entities drift manages, normalized so two
  /// databases differing only in whitespace compare equal.
  Future<List<String>> schemaOf(HaLoDatabase db) async {
    final rows = await db
        .customSelect(
          "SELECT sql FROM sqlite_master "
          "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    final schema =
        rows.map((r) => r.read<String>('sql').replaceAll(RegExp(r'\s+'), ' ').trim()).toList();
    // Without this the comparison silently vacates if the query ever returns
    // nothing: `expect([], [])` passes.
    expect(schema, isNotEmpty, reason: 'sqlite_master query returned no entities at all');
    return schema;
  }

  Future<int> userVersionOf(HaLoDatabase db) async =>
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version');

  /// An operator's log as it would actually be on disk. Values are BOUND, not
  /// interpolated — `jsonEncode` escapes `"` and `\` but not `'`, so an
  /// apostrophe in a fixture value (`Field Day '26`, seeded below on purpose)
  /// would otherwise break every test using this seed with a SQL syntax error
  /// naming a token rather than the value.
  ///
  /// Raw SQL rather than the repositories because the Dart API only knows the
  /// CURRENT schema, and these rows have to be written in the shape of the
  /// version under test.
  Future<void> seedOperatorLog(HaLoDatabase db, {required bool hasStampColumn}) async {
    final stampColumn = hasStampColumn ? ', updated_at_millis' : '';
    final stampValue = hasStampColumn ? ', ?' : '';

    await db.customStatement(
      'INSERT INTO operations (uuid, data, local_data, start_at_millis_min, '
      'start_at_millis_max, qso_count, deleted, synced$stampColumn) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?$stampValue)',
      [
        'op-1',
        jsonEncode({'stationCall': 'KI2D', 'userTitle': "Field Day '26"}),
        jsonEncode({'lastPane': 'log'}),
        1780000000000,
        1780003600000,
        2,
        0,
        1,
        if (hasStampColumn) 1780003600000,
      ],
    );
    // Deliberately NULL in local_data and both bounds: a rebuild that landed
    // NOT NULL DEFAULT '' on local_data would make every operation read throw
    // FormatException from jsonDecode(''), i.e. the app would not open at all.
    await db.customStatement(
      'INSERT INTO operations (uuid, data, local_data, start_at_millis_min, '
      'start_at_millis_max, qso_count, deleted, synced$stampColumn) '
      'VALUES (?, ?, NULL, NULL, NULL, ?, ?, ?$stampValue)',
      [
        'op-deleted',
        jsonEncode({'stationCall': 'KI2D', 'userTitle': 'Scratch'}),
        1,
        1,
        0,
        if (hasStampColumn) null,
      ],
    );

    Future<void> qso(
      String uuid,
      String call,
      String band,
      String mode,
      int at, {
      int deleted = 0,
      int synced = 0,
      String operation = 'op-1',
      int? stamp,
    }) {
      return db.customStatement(
        'INSERT INTO qsos (uuid, operation, our_call, their_call, band, mode, '
        'start_at_millis, data, deleted, synced, score_cache$stampColumn) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL$stampValue)',
        [
          uuid,
          operation,
          'KI2D',
          call,
          band,
          mode,
          at,
          jsonEncode({
            'their': {'call': call},
            if (stamp != null) 'updatedAtMillis': stamp,
          }),
          deleted,
          synced,
          if (hasStampColumn) stamp,
        ],
      );
    }

    await qso('qso-1', 'W1AW', '20m', 'SSB', 1780000000000, synced: 1, stamp: 1780000000000);
    await qso('qso-2', 'K1ABC', '40m', 'CW', 1780003600000);
    await qso('qso-deleted', 'N0PE', '20m', 'FT8', 1780001000000, deleted: 1);
    // Under the soft-deleted operation, so the operations-to-QSOs relationship
    // is represented on a migrated database.
    await qso('qso-orphan', 'VK3ABC', '15m', 'SSB', 1780002000000, operation: 'op-deleted');
  }

  group('the fixtures themselves', () {
    test('the undo map covers every version, so no step goes unexercised', () {
      // The failure this guards is silent: a missing entry leaves the newest
      // addition in the fixture, and `createTable` is CREATE TABLE IF NOT
      // EXISTS, so the step no-ops rather than erroring and the whole file
      // goes green having tested nothing about it.
      expect(
        _undoToGetPreviousVersion.keys.toSet(),
        {for (var v = 2; v <= currentVersion; v++) v},
        reason: 'schemaVersion is $currentVersion — add the matching undo entry '
            '(an empty list if that version changed no schema entities)',
      );
    });

    test('walking back really does reach each version', () async {
      for (var version = 1; version < currentVersion; version++) {
        // Asserted before the file is closed: reopening is what triggers the
        // upgrade, so every table would be back by then.
        await createAtVersion(dbFile('undo_v$version'), version, whileAtOldVersion: (db) async {
          expect(await userVersionOf(db), version, reason: 'v$version stamp');

          final tables = (await db
                  .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' "
                      "AND name NOT LIKE 'sqlite_%' ORDER BY name")
                  .get())
              .map((r) => r.read<String>('name'))
              .toSet();

          expect(tables.contains('operations'), isTrue, reason: 'v$version');
          expect(tables.contains('qsos'), isTrue, reason: 'v$version');
          expect(tables.contains('operations_backup'), version >= 2, reason: 'v$version backups');
          expect(tables.contains('qsos_backup'), version >= 2, reason: 'v$version backups');
          expect(tables.contains('lookups'), version >= 3, reason: 'v$version lookups');
          expect(tables.contains('sequences'), version >= 5, reason: 'v$version sequences');

          for (final table in ['operations', 'qsos']) {
            final columns = (await db.customSelect('PRAGMA table_info($table)').get())
                .map((r) => r.read<String>('name'))
                .toSet();
            expect(columns.contains('updated_at_millis'), version >= 4,
                reason: 'v$version $table stamps');
          }
        });
      }
    });
  });

  group('every supported upgrade path', () {
    for (var from = 1; from <= 7; from++) {
      test('v$from keeps the operator\'s log intact', () async {
        final file = dbFile();
        await createAtVersion(file, from,
            whileAtOldVersion: (db) => seedOperatorLog(db, hasStampColumn: from >= 4));

        final db = HaLoDatabase(NativeDatabase(file));
        addTearDown(db.close);

        expect(await userVersionOf(db), currentVersion,
            reason: 'the upgrade must land on the current version');

        final ops = await db.customSelect('SELECT * FROM operations ORDER BY uuid').get();
        expect(ops.map((r) => r.read<String>('uuid')), ['op-1', 'op-deleted']);
        expect(jsonDecode(ops.first.read<String>('data')),
            {'stationCall': 'KI2D', 'userTitle': "Field Day '26"});
        expect(jsonDecode(ops.first.read<String>('local_data')), {'lastPane': 'log'});
        expect(ops.first.read<int>('qso_count'), 2);
        // Soft deletes and dirty flags drive sync; losing either silently
        // resurrects deleted rows or re-uploads settled ones.
        expect(ops.last.read<bool>('deleted'), isTrue);
        expect(ops.first.read<bool>('synced'), isTrue);
        expect(ops.last.read<bool>('synced'), isFalse);
        // NULLs must stay NULL — see the seed's comment.
        expect(ops.last.read<String?>('local_data'), isNull);
        expect(ops.last.read<int?>('start_at_millis_min'), isNull);
        expect(ops.last.read<int?>('start_at_millis_max'), isNull);
        expect(ops.first.read<int>('start_at_millis_min'), 1780000000000);
        expect(ops.first.read<int>('start_at_millis_max'), 1780003600000);

        final qsos = await db.customSelect('SELECT * FROM qsos ORDER BY uuid').get();
        expect(qsos.map((r) => r.read<String>('uuid')),
            ['qso-1', 'qso-2', 'qso-deleted', 'qso-orphan']);
        final first = qsos.first;
        expect(jsonDecode(first.read<String>('data'))['their'], {'call': 'W1AW'});
        // The only column linking a QSO to its operation, and there is no
        // foreign key anywhere to catch a migration that blanked it.
        expect(qsos.map((r) => r.read<String>('operation')),
            ['op-1', 'op-1', 'op-1', 'op-deleted']);
        expect(first.read<String>('our_call'), 'KI2D');
        expect(first.read<String>('their_call'), 'W1AW');
        expect(first.read<String>('band'), '20m');
        expect(first.read<String>('mode'), 'SSB');
        expect(first.read<int>('start_at_millis'), 1780000000000);
        expect(first.read<String?>('score_cache'), isNull);
        expect(first.read<bool>('synced'), isTrue);
        expect(qsos[1].read<bool>('synced'), isFalse);
        expect(qsos[2].read<bool>('deleted'), isTrue);
      });

      test('v$from produces the schema a fresh install gets', () async {
        // drift's own comparator: it builds the reference by running
        // `createAll` on a scratch database, so it needs no committed dump,
        // and it reports a column-level diff instead of two walls of CREATE
        // TABLE text.
        //
        // Know its reach. Both sides come from the same declarations, so a
        // migration written through the drift API cannot diverge from
        // `onCreate` — only a hand-written `customStatement` DDL step can,
        // which is exactly the kind this schema has now acquired. A
        // declaration changing without a version bump is covered by the
        // golden-snapshot test instead.
        final file = dbFile();
        await createAtVersion(file, from);
        final db = HaLoDatabase(NativeDatabase(file));
        addTearDown(db.close);
        await db.validateDatabaseSchema();
      });
    }

    test('a pre-existing row can be written to after the upgrade', () async {
      // Reading migrated rows is one thing; writing to one is what the app
      // does next, and it exercises the added column on a row that predates
      // it — which a brand-new row never does.
      final file = dbFile();
      await createAtVersion(file, 1,
          whileAtOldVersion: (db) => seedOperatorLog(db, hasStampColumn: false));

      final db = HaLoDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final operations = OperationsRepository(db);
      final qsos = QsosRepository(db);

      final existing = await operations.get('op-1');
      expect(existing, isNotNull);
      expect(existing!.stationCall, 'KI2D');
      expect(await qsos.get('qso-1'), isNotNull);

      await operations.saveData(Operation(
        uuid: existing.uuid,
        data: {...existing.data, 'userTitle': 'Renamed after upgrade'},
      ));
      final rewritten = await operations.get('op-1');
      expect(rewritten!.userTitle, 'Renamed after upgrade');
      // saveData stamps both the blob and the column; they must agree, or
      // markSynced never matches this row again.
      expect(rewritten.updatedAtMillis, isNotNull);
      expect(
        (await db
                .customSelect("SELECT updated_at_millis FROM operations WHERE uuid = 'op-1'")
                .getSingle())
            .read<int?>('updated_at_millis'),
        rewritten.updatedAtMillis,
      );

      final created = await operations.create(stationCall: 'W1AW', userTitle: 'New');
      expect((await operations.get(created.uuid))!.stationCall, 'W1AW');
    });
  });

  group('the revision stamps sync depends on', () {
    test('a stamp already in the blob reaches the mirrored column', () async {
      // v3-era `mergeFromSync` stored inbound records verbatim, so anything
      // imported from app-polo carries updatedAtMillis INSIDE its blob.
      // `Operation.updatedAtMillis` reads the blob while `markSynced` matches
      // on the column, so leaving the column null left the pair divergent —
      // markSynced then matched zero rows and the whole imported log
      // re-uploaded on every sync round, forever.
      final file = dbFile();
      await createAtVersion(file, 3, whileAtOldVersion: (db) async {
        await db.customStatement(
          'INSERT INTO operations (uuid, data, qso_count, deleted, synced) VALUES (?, ?, 0, 0, 1)',
          ['op-synced', jsonEncode({'stationCall': 'KI2D', 'updatedAtMillis': 1779000000000})],
        );
        await db.customStatement(
          'INSERT INTO operations (uuid, data, qso_count, deleted, synced) VALUES (?, ?, 0, 0, 1)',
          // The older app-polo spelling, which Operation still accepts.
          ['op-legacy', jsonEncode({'stationCall': 'KI2D', 'updatedOnMillis': 1778000000000})],
        );
        await db.customStatement(
          'INSERT INTO qsos (uuid, operation, data, deleted, synced) VALUES (?, ?, ?, 0, 1)',
          [
            'qso-synced',
            'op-synced',
            jsonEncode({
              'their': {'call': 'W1AW'},
              'updatedAtMillis': 1779000000000,
            }),
          ],
        );
      });

      final db = HaLoDatabase(NativeDatabase(file));
      addTearDown(db.close);

      Future<int?> stampOf(String table, String uuid) async => (await db.customSelect(
            'SELECT updated_at_millis FROM $table WHERE uuid = ?',
            variables: [Variable<String>(uuid)],
          ).getSingle())
              .read<int?>('updated_at_millis');

      expect(await stampOf('operations', 'op-synced'), 1779000000000);
      expect(await stampOf('operations', 'op-legacy'), 1778000000000);
      expect(await stampOf('qsos', 'qso-synced'), 1779000000000);

      // The behaviour that actually matters: blob and column must agree, which
      // is what lets markSynced find the row.
      final op = await OperationsRepository(db).get('op-synced');
      expect(op!.updatedAtMillis, await stampOf('operations', 'op-synced'),
          reason: 'blob and column must agree or markSynced re-pushes forever');
    });

    test('a row with no stamp anywhere stays NULL', () async {
      // The other half of the rule: null on both sides is how sync says "no
      // revision information". Backfilling `now()` instead would make every
      // old row look newer than the server's copy and win every merge.
      final file = dbFile();
      await createAtVersion(file, 3,
          whileAtOldVersion: (db) => seedOperatorLog(db, hasStampColumn: false));

      final db = HaLoDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(
        (await db
                .customSelect("SELECT updated_at_millis FROM operations WHERE uuid = 'op-1'")
                .getSingle())
            .read<int?>('updated_at_millis'),
        isNull,
      );
      expect(
        (await db
                .customSelect("SELECT updated_at_millis FROM qsos WHERE uuid = 'qso-2'")
                .getSingle())
            .read<int?>('updated_at_millis'),
        isNull,
      );
    });

    test('a malformed blob does not take the whole upgrade down', () async {
      // json_extract throws on invalid JSON and the backfill runs inside the
      // migration transaction, so one corrupt row must not make the log
      // unopenable.
      final file = dbFile();
      await createAtVersion(file, 3, whileAtOldVersion: (db) async {
        await db.customStatement(
          'INSERT INTO operations (uuid, data, qso_count, deleted, synced) VALUES (?, ?, 0, 0, 0)',
          ['op-corrupt', 'not json at all'],
        );
      });

      final db = HaLoDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(await userVersionOf(db), currentVersion);
      expect(await db.customSelect('SELECT * FROM operations').get(), hasLength(1));
    });
  });

  group('the tables and rows each step adds', () {
    test('rows already in the added tables survive later upgrades', () async {
      // Data survival was only ever proven for operations and qsos. A step
      // that rebuilt `lookups` would wipe the operator's offline reference
      // cache; one that rebuilt the backup tables would destroy the
      // last-resort copy taken right before a replace-sync wipes the log.
      final file = dbFile();
      await createAtVersion(file, 3, whileAtOldVersion: (db) async {
        await db.customStatement(
          'INSERT INTO lookups (category, key, name, lat, lon) VALUES (?, ?, ?, ?, ?)',
          ['pota', 'US-0001', 'A park', 41.5, -73.5],
        );
        await db.customStatement(
          'INSERT INTO operations_backup (backup_id, backup_at_millis, uuid, data, qso_count, '
          'deleted) VALUES (?, ?, ?, ?, ?, ?)',
          ['b1', 1780000000000, 'op-1', '{}', 0, 0],
        );
        await db.customStatement(
          'INSERT INTO qsos_backup (backup_id, backup_at_millis, uuid, operation, data, deleted) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          ['b1', 1780000000000, 'qso-1', 'op-1', '{}', 0],
        );
      });

      final db = HaLoDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final lookup = await db.customSelect('SELECT * FROM lookups').getSingle();
      expect(lookup.read<String>('name'), 'A park');
      expect(lookup.read<double>('lat'), 41.5);
      final opBackup = await db.customSelect('SELECT * FROM operations_backup').getSingle();
      expect(opBackup.read<String>('uuid'), 'op-1');
      expect(opBackup.read<String>('backup_id'), 'b1');
      expect(
        (await db.customSelect('SELECT * FROM qsos_backup').getSingle()).read<String>('operation'),
        'op-1',
      );
    });

    test('the tables each step adds are writable and read back what was written', () async {
      final file = dbFile();
      await createAtVersion(file, 1,
          whileAtOldVersion: (db) => seedOperatorLog(db, hasStampColumn: false));

      final db = HaLoDatabase(NativeDatabase(file));
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO sequences (operation, label, next_value, start_value) VALUES (?, ?, ?, ?)',
        ['op-1', 'cqwpx/serial', 7, 1],
      );
      // The values, not a row count: an INSERT that returned already proves
      // the table exists, so counting rows would assert nothing.
      final seq = await db.customSelect('SELECT * FROM sequences').getSingle();
      expect(seq.read<String>('label'), 'cqwpx/serial');
      expect(seq.read<int>('next_value'), 7);
      expect(seq.read<int>('start_value'), 1);
    });

    test('the indexes a fresh install has are present after an upgrade too', () async {
      // `onUpgrade` never issues a createIndex, and `Migrator.createTable`
      // does not create a table's indexes — so an index added to a future
      // table without an explicit step would leave upgraded installs
      // table-scanning while fresh ones stay fast.
      Future<List<String>> indexesOf(HaLoDatabase db) async => (await db
              .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' "
                  "AND name NOT LIKE 'sqlite_%' ORDER BY name")
              .get())
          .map((r) => r.read<String>('name'))
          .toList();

      final file = dbFile();
      await createAtVersion(file, 1);
      final upgraded = HaLoDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final upgradedIndexes = await indexesOf(upgraded);

      final fresh = HaLoDatabase(NativeDatabase.memory());
      await fresh.customStatement('SELECT 1');
      final freshIndexes = await indexesOf(fresh);
      await fresh.close();

      expect(upgradedIndexes, contains('qsos_operation_start'));
      expect(upgradedIndexes, freshIndexes);
    });
  });

  group('paths that must not silently succeed', () {
    test('a log written by a NEWER build is refused, not restamped', () async {
      // drift routes a downgrade through onUpgrade too: every `from < N` guard
      // no-ops and drift then stamps the file back down, keeping whatever the
      // newer version added. Reinstalling the newer build afterwards re-runs
      // its steps against a schema that already has them, and addColumn is a
      // one-way door.
      final file = dbFile();
      await createAtVersion(file, currentVersion, whileAtOldVersion: (db) async {
        await db.customStatement('PRAGMA user_version = ${currentVersion + 1}');
      });

      final db = HaLoDatabase(NativeDatabase(file));
      await expectLater(
        db.customSelect('SELECT * FROM operations').get(),
        throwsA(anything),
        reason: 'opening a newer log must fail loudly rather than restamp it',
      );
      await db.close();

      // And the file must be left exactly as the newer build wrote it.
      final raw = sqlite3.open(file.path);
      addTearDown(raw.dispose);
      expect(raw.userVersion, currentVersion + 1,
          reason: 'the newer version stamp must survive the refused open');
    });

    test('an upgrade that fails partway applies nothing at all', () async {
      // The whole upgrade runs in one transaction, so a step that throws must
      // leave the file exactly as it was. Without that, drift writes
      // user_version only after onUpgrade returns, so the earlier steps stay
      // applied while the version still says otherwise — and the next open
      // re-runs them. `addColumn` is not idempotent, so that state is a
      // one-way door: `duplicate column name`, for reads too, forever.
      //
      // Poisoning the v4 step is how the failure is induced: a v1 file whose
      // `operations` already has the column that step adds. The v2 and v3
      // steps run first and succeed, so if the transaction is not doing its
      // job their tables survive the throw.
      final file = dbFile();
      await createAtVersion(file, 1, whileAtOldVersion: (db) async {
        await seedOperatorLog(db, hasStampColumn: false);
        await db.customStatement('ALTER TABLE operations ADD COLUMN updated_at_millis INTEGER');
      });

      final db = HaLoDatabase(NativeDatabase(file));
      await expectLater(
        db.customSelect('SELECT * FROM operations').get(),
        throwsA(anything),
        reason: 'the poisoned step must surface as a real error',
      );
      await db.close();

      // Inspected raw, because the drift instance above is now in a failed
      // state and reopening one would just re-run the migration.
      final raw = sqlite3.open(file.path);
      addTearDown(raw.dispose);
      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toSet();

      expect(raw.userVersion, 1, reason: 'a failed upgrade must not advance the version');
      expect(tables.contains('operations_backup'), isFalse,
          reason: 'the v2 step ran before the failing one — it must have rolled back');
      expect(tables.contains('lookups'), isFalse,
          reason: 'the v3 step ran before the failing one — it must have rolled back');
      // And the operator's rows are untouched, so a fixed build can still open
      // the file.
      expect(raw.select('SELECT * FROM qsos'), hasLength(4));
    });

    test('opening an already-current database runs no migration steps', () async {
      // The earlier version of this test could not fail: it compared a schema
      // captured after the operation under test, and deleting the whole
      // onUpgrade body left it green. Re-running any step here would throw
      // (the v4 addColumn would hit a duplicate column), so surviving the open
      // with the rows intact is the real assertion.
      final file = dbFile();
      await createAtVersion(file, currentVersion,
          whileAtOldVersion: (db) => seedOperatorLog(db, hasStampColumn: true));

      final db = HaLoDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(await userVersionOf(db), currentVersion);
      await db.validateDatabaseSchema();
      expect(await db.customSelect('SELECT * FROM qsos').get(), hasLength(4));
      expect(await db.customSelect('SELECT * FROM operations').get(), hasLength(2));
    });
  });

  test('the current schema matches its golden snapshot', () async {
    // The one check not derived from the declarations under test. Adding a
    // column or index without bumping `schemaVersion` is invisible to every
    // upgrade test above — the fixture is built by onCreate, so it gets the
    // addition for free — but it cannot be invisible here.
    //
    // When this fails: if the schema change was intended, regenerate the
    // snapshot AND decide whether `schemaVersion` and a migration step are
    // owed. A change with neither is the bug this exists to catch.
    final fresh = HaLoDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    final actual = await schemaOf(fresh);

    expect(_goldenSchemaFile.existsSync(), isTrue,
        reason: 'missing ${_goldenSchemaFile.path} — regenerate with tool/dump_schema.dart');
    final golden = _goldenSchemaFile
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty && !line.startsWith('--'))
        .toList();

    expect(actual, golden,
        reason: 'the schema changed — regenerate the snapshot, and check whether '
            'schemaVersion and a migration step are owed');
  });
}
