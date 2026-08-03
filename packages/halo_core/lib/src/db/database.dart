// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Storage schema, carried over from app-polo's proven shape (DESIGN.md §6):
// a JSON `data` blob as the source of truth plus a few indexed columns for
// querying, with `deleted`/`synced` flags driving soft deletes and dirty-flag
// sync. The `data` column always holds the full QSON record; indexed columns
// are derived from it on every write.

import 'package:drift/drift.dart';

part 'database.g.dart';

@DataClassName('OperationRow')
class Operations extends Table {
  TextColumn get uuid => text()();
  TextColumn get data => text().withDefault(const Constant('{}'))();

  /// Device-local state that never syncs (e.g. UI preferences per operation).
  TextColumn get localData => text().nullable()();
  IntColumn get startAtMillisMin => integer().nullable()();
  IntColumn get startAtMillisMax => integer().nullable()();
  IntColumn get qsoCount => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  /// Mirrors `data.updatedAtMillis` (stamped on every local write, app-polo
  /// convention) so sync can compare revisions without decoding the blob:
  /// `markSynced` only flips rows whose stamp still matches what was sent,
  /// and `mergeFromSync` skips inbound records older than the local row.
  IntColumn get updatedAtMillis => integer().nullable()();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DataClassName('QsoRow')
@TableIndex(name: 'qsos_operation_start', columns: {#operation, #startAtMillis})
class Qsos extends Table {
  TextColumn get uuid => text()();
  TextColumn get operation => text()();
  TextColumn get ourCall => text().nullable()();
  TextColumn get theirCall => text().nullable()();
  TextColumn get band => text().nullable()();
  TextColumn get mode => text().nullable()();
  IntColumn get startAtMillis => integer().nullable()();
  TextColumn get data => text().withDefault(const Constant('{}'))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  /// Cached plugin scoring results so list rendering never waits on the
  /// plugin runtime (DESIGN.md §4). Unused until the scoring hooks land.
  TextColumn get scoreCache => text().nullable()();

  /// See `Operations.updatedAtMillis`.
  IntColumn get updatedAtMillis => integer().nullable()();

  @override
  Set<Column> get primaryKey => {uuid};
}

/// A snapshot of every row from `Operations`/`Qsos` taken right before a
/// "replace" sync reconciliation (or a `SYNCALL` command) wipes the live
/// tables — see `OperationsRepository.backupAndClearAll`. Not a full schema
/// mirror: only what's needed to inspect or manually recover a backup,
/// tagged with the `backupId` (a UTC timestamp) that groups one event's
/// rows together.
@DataClassName('OperationBackupRow')
class OperationsBackup extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get backupId => text()();
  IntColumn get backupAtMillis => integer()();
  TextColumn get uuid => text()();
  TextColumn get data => text()();
  IntColumn get startAtMillisMin => integer().nullable()();
  IntColumn get startAtMillisMax => integer().nullable()();
  IntColumn get qsoCount => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

/// See `OperationsBackup`.
@DataClassName('QsoBackupRow')
class QsosBackup extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get backupId => text()();
  IntColumn get backupAtMillis => integer()();
  TextColumn get uuid => text()();
  TextColumn get operation => text()();
  TextColumn get data => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

@DataClassName('LookupRow')
class Lookups extends Table {
  TextColumn get category => text()();
  TextColumn get subCategory => text().nullable()();
  TextColumn get key => text()();
  TextColumn get name => text().nullable()();
  TextColumn get data => text().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();
  IntColumn get flags => integer().nullable()();
  IntColumn get updated => integer().nullable()();

  @override
  Set<Column> get primaryKey => {category, key};
}

/// Serial-number counters, one row per (operation, label) — the sequences a
/// contest sends as part of its exchange (docs/design/contests.md §5.8).
///
/// Device-local and never synced, like `score_cache` and `local_data`: the
/// numbers themselves are data of record and live on the QSOs, while this is
/// only a high-water mark. It can always be rebuilt as `max(serial across the
/// log, including soft-deleted rows) + 1`, which is what makes every hard case
/// — a delete, an edit, a crash, an inbound sync, an ADIF import — answerable
/// with "rebuild the counter, never the numbers".
@DataClassName('SequenceRow')
class Sequences extends Table {
  TextColumn get operation => text()();

  /// `<extensionKey>/<key>` plus any scope values, e.g. `cqwpx/serial` or
  /// `rsgb/serial/2m`. Computed by the core at allocation time from the
  /// committed QSO, never by the extension — only the core knows which band
  /// the QSO actually ended up on.
  TextColumn get label => text()();

  /// The next number to issue.
  IntColumn get nextValue => integer()();

  /// First number this sequence issues; the operator can set it when they
  /// logged the first hour on paper.
  IntColumn get startValue => integer().withDefault(const Constant(1))();

  IntColumn get updatedAtMillis => integer().nullable()();

  @override
  Set<Column> get primaryKey => {operation, label};
}

@DriftDatabase(tables: [Operations, Qsos, OperationsBackup, QsosBackup, Lookups, Sequences])
class HaLoDatabase extends _$HaLoDatabase {
  HaLoDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (Migrator m, int from, int to) async {
          // A file written by a NEWER build must not be quietly accepted.
          // drift routes a downgrade through here too — every `from < N`
          // guard no-ops and drift then stamps the file back down to `to`,
          // keeping whatever the newer version added. Reinstalling the newer
          // build afterwards re-runs its steps against a schema that already
          // has them, and `addColumn` is a one-way door (see below). Refusing
          // is the only outcome that keeps the log openable.
          if (from > to) {
            throw StateError(
              'This log was written by a newer version of Ham2K Logger '
              '(storage v$from; this build understands v$to). '
              'Update the app instead of opening it with this build.',
            );
          }

          // The whole upgrade is one transaction. `addColumn` is not
          // idempotent and drift only writes `user_version` once this
          // returns, so a step that fails partway would leave the earlier
          // steps applied with the version unchanged — and the next open
          // re-runs them, hitting `duplicate column name` for reads too,
          // permanently.
          await m.database.transaction(() async {
            if (from < 2) {
              await m.createTable(operationsBackup);
              await m.createTable(qsosBackup);
            }
            if (from < 3) {
              await m.createTable(lookups);
            }
            if (from < 4) {
              await m.addColumn(operations, operations.updatedAtMillis);
              await m.addColumn(qsos, qsos.updatedAtMillis);
            }
            if (from < 5) {
              // No backfill: the counter is derived, so an operation that
              // already has serials on its QSOs rebuilds its high-water mark
              // from the log the first time it allocates.
              await m.createTable(sequences);
            }
            if (from < 6) {
              await _backfillRevisionStamps(m);
            }
          });
        },
      );

  /// Copies the revision stamp out of each row's `data` blob into the mirrored
  /// column, wherever the column is null and the blob has one.
  ///
  /// The v4 step added the column and left it null for every existing row, on
  /// the reasoning that those rows carried no stamp either. That holds for
  /// rows this app wrote — but NOT for rows that arrived by sync: v3-era
  /// `mergeFromSync` stored the inbound record verbatim, so anything imported
  /// from app-polo landed with `updatedAtMillis` (or the older
  /// `updatedOnMillis`) inside its blob.
  ///
  /// `Operation.updatedAtMillis` reads that blob while `markSynced` matches on
  /// the column, so those rows came out of the upgrade with a stamp on one
  /// side and null on the other — exactly the divergence
  /// `QsosRepository._restamped` warns about, which makes `markSynced` match
  /// zero rows and re-push the record on every sync round, forever. This runs
  /// as its own version because installs that already took the v4 step will
  /// never run that one again.
  static Future<void> _backfillRevisionStamps(Migrator m) async {
    // `json_valid` guards the blob: a malformed one would make `json_extract`
    // throw and take the whole upgrade down with it.
    await m.database.customStatement('''
      UPDATE operations SET updated_at_millis = CAST(
        COALESCE(json_extract(data, '\$.updatedAtMillis'),
                 json_extract(data, '\$.updatedOnMillis')) AS INTEGER)
      WHERE updated_at_millis IS NULL AND json_valid(data)
        AND COALESCE(json_extract(data, '\$.updatedAtMillis'),
                     json_extract(data, '\$.updatedOnMillis')) IS NOT NULL
    ''');
    // Qso reads only the current spelling, so the column must mirror only it.
    await m.database.customStatement('''
      UPDATE qsos SET updated_at_millis =
        CAST(json_extract(data, '\$.updatedAtMillis') AS INTEGER)
      WHERE updated_at_millis IS NULL AND json_valid(data)
        AND json_extract(data, '\$.updatedAtMillis') IS NOT NULL
    ''');
  }
}
