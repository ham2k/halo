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

  @override
  Set<Column> get primaryKey => {uuid};
}

@DriftDatabase(tables: [Operations, Qsos])
class PoloDatabase extends _$PoloDatabase {
  PoloDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
