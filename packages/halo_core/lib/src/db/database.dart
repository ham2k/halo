// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Storage schema, carried over from app-polo's proven shape (DESIGN.md §6):
// a JSON `data` blob as the source of truth plus a few indexed columns for
// querying, with `deleted`/`synced` flags driving soft deletes and dirty-flag
// sync. The `data` column always holds the full QSON record; indexed columns
// are derived from it on every write.

import 'dart:convert';

import 'package:drift/drift.dart';
// The wrapper drift reports a background-isolate failure through; see
// LogFromNewerBuild.within, which exists entirely because of it.
import 'package:drift/isolate.dart' show DriftRemoteException;

import '../dev_log.dart';
import '../models/location_repair.dart';

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

  /// Set alongside `deleted` when a Test Operation is deleted
  /// (`OperationsRepository.purge`, docs: Test Operations): the tombstone
  /// still pushes through the normal dirty-row sync, and once that push is
  /// acknowledged the row is physically removed. LoFi removes a purged
  /// record outright rather than keeping the tombstone, so no other device
  /// hears of it from there; peer sync still carries the flag. `purged`
  /// alone doesn't say WHO gets to act on it without asking — see
  /// [purgedLocally].
  BoolColumn get purged => boolean().withDefault(const Constant(false))();

  /// True only when THIS device is the one that called
  /// `OperationsRepository.purge` — never set by `mergeFromSync`, which
  /// leaves it at its default `false` no matter what the incoming record's
  /// `purged` says. `hardDeletePurged`'s auto-sweep requires this: a
  /// locally-initiated purge already went through a confirmation dialog on
  /// this device, so it's safe to remove once synced, but a `purged` flag
  /// that only ever arrived via sync has not been confirmed HERE and must
  /// wait for the operator to say so (`OperationsRepository.
  /// confirmReceivedPurges`) — the whole point of `purged` travelling to
  /// another device at all (in practice from a peer; LoFi relays none) is
  /// so every device that receives it asks, not so it silently agrees.
  BoolColumn get purgedLocally => boolean().withDefault(const Constant(false))();

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

  /// See `Operations.purged` — set on every QSO of a Test Operation when the
  /// operation is purged.
  BoolColumn get purged => boolean().withDefault(const Constant(false))();

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

/// Raw QSOs captured from another logging program (docs: "Listen for other
/// apps"), before the operator has decided whether to add them to any
/// operation's log. App-wide like `Lookups` — a capture isn't tied to an
/// operation until [addedToOperation] says so, since the listener runs
/// independently of which operation (if any) is open.
///
/// Device-local and never synced: the source program is running on THIS
/// machine, and a capture is either added to the log (where it syncs as a
/// normal QSO) or it isn't.
@DataClassName('InboundCaptureRow')
@TableIndex(name: 'inbound_captures_dedupe_key', columns: {#dedupeKey}, unique: true)
class InboundCaptures extends Table {
  TextColumn get uuid => text()();

  /// The program that sent it, e.g. `n1mm`. Only one exists today, but the
  /// buffer's shape shouldn't have to change to add a second.
  TextColumn get source => text()();

  /// A dedup key derived from the capture's own fields (call/band/mode/time),
  /// so a program that broadcasts the same contact twice doesn't queue it
  /// twice. Not the primary key: [uuid] is what the UI and
  /// `addedToOperation` reference, and re-deriving the dedup key on every
  /// query would be wasted work a plain unique index avoids.
  TextColumn get dedupeKey => text()();

  /// QSON, same shape `Qso.data` uses — built directly from the capture so
  /// accepting it is a plain `qsos.add`, not a second translation.
  TextColumn get data => text()();

  IntColumn get receivedAtMillis => integer()();

  /// Null while pending. Set to the operation's uuid once the operator adds
  /// it to a log — kept (not deleted) so a re-arriving duplicate broadcast is
  /// still recognized by [dedupeKey] as already handled.
  TextColumn get addedToOperation => text().nullable()();

  @override
  Set<Column> get primaryKey => {uuid};
}

/// The device-local outbox for peer device sync (HALO-310) — NOT LoFi cloud
/// sync, which `synced` alone drives. One append-only row per local write to
/// an `Operations`/`Qsos` record made while that record's operation is
/// actively shared with a peer (`PeerOutbox.activeOperationUuid`); `seq`
/// (SQLite's native rowid) is the per-device monotonic cursor a reconnecting
/// peer catches up from. `data` is a full record snapshot shaped exactly like
/// one entry of `mergeFromSync`'s input list (i.e. it round-trips straight
/// into `mergeFromPeer`), not a diff — so a peer only ever needs the latest
/// row per `recordUuid`, never a replay of every intermediate edit.
///
/// Pruned to the newest row per [recordUuid] after every scan
/// (`PeerOutbox._pruneSuperseded`), which is what keeps this bounded at
/// roughly one row per record rather than growing with every edit. Safe
/// precisely because a row is a full snapshot: the row that superseded a
/// deleted one carries a higher [seq], so a peer catching up from any cursor
/// still receives that record's current state.
///
/// [seq] must therefore stay `AUTOINCREMENT` — SQLite would otherwise recycle
/// the rowid of a pruned row, and a peer's stored cursor (`PeerCursors`)
/// would silently start pointing into the wrong part of the log.
///
/// Neither index below is the shape it looks like it should be, and both are
/// on the path that runs after every logged contact:
///
/// - `peer_events_operation_seq` leads on `(operationUuid, seq)` because that
///   is what `PeerOutbox.eventsSince` seeks on; those two may not be
///   reordered. [recordUuid] and [updatedAtMillis] trail them purely as
///   payload, so `PeerOutbox._alreadyRecorded` is answered from the index
///   alone. Drop them and SQLite seeks into the table once per entry — and
///   since [data] is a full snapshot, only a couple of rows share a page, so
///   reading two small columns costs about what reading the whole operation
///   costs.
/// - `peer_events_operation_record` is what lets `_pruneSuperseded` seek the
///   records a scan touched. Scoping that statement to their uuids does NOT
///   by itself avoid walking the operation: an `IN` list only drives seeks if
///   [recordUuid] is indexed. Without this index the prune costs grow with
///   the operation's size rather than with the handful of records edited.
@DataClassName('PeerEventRow')
@TableIndex(name: 'peer_events_operation_seq', columns: {#operationUuid, #seq, #recordUuid, #updatedAtMillis})
@TableIndex(name: 'peer_events_operation_record', columns: {#operationUuid, #recordUuid})
class PeerEvents extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get operationUuid => text()();

  /// `'operation'` or `'qso'` — which repository's `mergeFromPeer` the
  /// catch-up reader hands this row's [data] to.
  TextColumn get kind => text()();
  TextColumn get recordUuid => text()();
  IntColumn get updatedAtMillis => integer().nullable()();
  TextColumn get data => text()();
}

/// Per-peer, per-operation receive-side bookkeeping: the highest [PeerEvents]
/// `seq` THIS device has already applied FROM [peerDeviceId]'s own outbox —
/// what a reconnect handshake reports so the peer knows how far back to
/// replay. Device-local, never synced, like `Sequences`.
@DataClassName('PeerCursorRow')
class PeerCursors extends Table {
  TextColumn get peerDeviceId => text()();
  TextColumn get operationUuid => text()();
  IntColumn get lastAppliedSeq => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {peerDeviceId, operationUuid};
}

/// Peer devices this operator has confirmed, once, on THIS device
/// (trust-on-first-use — docs: HALO-310 pairing). Presence of a row IS the
/// trust: a peer announcing [peerDeviceId] is admitted without asking again,
/// and removing the row un-trusts it.
///
/// Device-local and never synced, like `Sequences` and `PeerCursors` — trust
/// is a statement about what THIS operator confirmed at THIS device, and
/// syncing it would let one paired device silently vouch for a third.
///
/// [name] is what the peer called itself when it paired, kept only so the
/// list reads as devices rather than uuids. It is self-asserted and must
/// never be treated as identity — [peerDeviceId] is the only identifier
/// anything may key off.
@DataClassName('PeerTrustRow')
class PeerTrust extends Table {
  TextColumn get peerDeviceId => text()();
  TextColumn get name => text()();
  IntColumn get pairedAtMillis => integer()();
  IntColumn get lastSeenAtMillis => integer().nullable()();

  @override
  Set<Column> get primaryKey => {peerDeviceId};
}

/// The best claim per checklist slot, per source (docs/design/claims.md §5).
/// Synced through LoFi and backed up, but never over peer links: a claim is
/// about the whole log, not one shared operation.
///
/// [uuid] is derived from the slot and source (`claimUuid`), so every device
/// computing the same slot writes the same row. A slot's `log` row is
/// derivable from the log and is stored anyway, so a device holding only
/// part of the log still reads whole checklists.
///
/// `claims_qso` answers "which slots does this contact hold?", the question
/// every edit, deletion and synced change of a contact asks.
/// `claims_checklist` answers one holder's checklist.
@DataClassName('ClaimRow')
@TableIndex(name: 'claims_qso', columns: {#qso})
@TableIndex(name: 'claims_checklist', columns: {#program, #holder, #edition})
class Claims extends Table {
  TextColumn get uuid => text()();
  TextColumn get program => text()();
  TextColumn get holder => text()();

  /// Empty for a lifetime program.
  TextColumn get edition => text().withDefault(const Constant(''))();
  TextColumn get ref => text()();

  /// Null: any band.
  TextColumn get band => text().nullable()();

  /// Null: any mode.
  TextColumn get mode => text().nullable()();

  /// `log`, or `import:<batchId>`.
  TextColumn get source => text()();

  /// A `ClaimLevel` name.
  TextColumn get level => text()();

  /// When the claiming contact happened; null when an import did not say.
  IntColumn get atMillis => integer().nullable()();

  /// The claiming contact; null for an import that matched none.
  TextColumn get qso => text().nullable()();

  /// `by`, `label`, `guess`, and an import's own fields.
  TextColumn get data => text().withDefault(const Constant('{}'))();

  /// The program version that computed this row.
  IntColumn get version => integer()();

  /// Raised by a rescan; outranks the claim itself on merge (§7).
  IntColumn get epoch => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAtMillis => integer().nullable()();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DriftDatabase(tables: [Operations, Qsos, OperationsBackup, QsosBackup, Lookups, Sequences, InboundCaptures, PeerEvents, PeerCursors, PeerTrust, Claims])
class HaLoDatabase extends _$HaLoDatabase {
  HaLoDatabase(super.executor);

  @override
  int get schemaVersion => 15;

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
      if (from > to) throw LogFromNewerBuild(storage: from, understood: to);

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
        if (from < 7) {
          await m.addColumn(operations, operations.purged);
          await m.addColumn(qsos, qsos.purged);
        }
        if (from < 8) {
          await m.addColumn(operations, operations.purgedLocally);
        }
        if (from < 9) {
          await m.createTable(inboundCaptures);
        }
        // `createTable` does not create a table's own declared indexes
        // (see the migration test's note on this trap) — a device that
        // upgraded to v9 before this index existed needs its own step,
        // not just adding the annotation and leaving v9's step alone.
        if (from < 10) {
          await m.createIndex(inboundCapturesDedupeKey);
        }
        if (from < 11) {
          await m.createTable(peerEvents);
          await m.createTable(peerCursors);
          await m.createIndex(peerEventsOperationSeq);
        }
        if (from < 12) {
          await m.createTable(peerTrust);
        }
        // Widening an index means REPLACING it. `createIndex` issues a
        // bare `CREATE INDEX` with no `IF NOT EXISTS`, and every install
        // that took v11 already holds the narrow shape under this name —
        // so without the drop this step throws, and with a drop bolted on
        // later but no version bump it would never run at all.
        if (from < 13) {
          await m.drop(peerEventsOperationSeq);
          await m.createIndex(peerEventsOperationSeq);
          await m.createIndex(peerEventsOperationRecord);
        }
        if (from < 14) {
          await _repairStatedLocations(m);
        }
        if (from < 15) {
          await m.createTable(claims);
          await m.createIndex(claimsQso);
          await m.createIndex(claimsChecklist);
        }
      });
    },
  );

  /// Reconciles the two halves of every operation's location already stored
  /// — the same repair an incoming record now gets (`repairStatedLocation`,
  /// docs/design/locations.md), applied once to what arrived before it.
  ///
  /// The repair runs where a record ENTERS, so an operation that landed from
  /// a grid-only peer earlier is otherwise fixed only by that record being
  /// delivered again, which a normal sync round has no reason to do. It keeps
  /// answering distances and map positions from a coordinate the operator
  /// moved away from, or claims a locator that places nowhere and so draws no
  /// QTH at all.
  ///
  /// Operations only, like the merge it mirrors — a contact's own two halves
  /// disagreeing is the operator stating a position, not a stale half (see
  /// [repairStatedLocation]).
  ///
  /// The stamps are deliberately untouched. This states nothing new about the
  /// record — it drops a half that was already being ignored or was never a
  /// location — and bumping the revision would push every repaired row back
  /// out, which for a long log means re-uploading it to say what the other
  /// end cannot store anyway.
  ///
  /// The SQL narrows to candidates and decides nothing: a row qualifies when
  /// it carries a coordinate (which a locator may contradict) or a grid whose
  /// first four characters are not a field pair followed by square digits
  /// (which nothing can place). That GLOB is `gridCell`'s own entry test —
  /// field letters A–R, then two digits — so no row the repair would change
  /// is filtered out. It admits a little more than that: whitespace around a
  /// locator, and a `grid` of the wrong type entirely, both fail the GLOB and
  /// are read for real in Dart.
  ///
  /// A row whose halves agree is read and left exactly as it was — the
  /// operator's log is not rewritten to say nothing.
  static Future<void> _repairStatedLocations(Migrator m) async {
    var repaired = 0;
    var after = 0;
    while (true) {
      final rows = await m.database
          .customSelect(
            "SELECT rowid AS row_id, data FROM operations WHERE rowid > ? AND json_valid(data) AND ("
            r"json_extract(data, '$.lat') IS NOT NULL OR "
            r"(json_extract(data, '$.grid') IS NOT NULL AND "
            r"json_extract(data, '$.grid') NOT GLOB '[A-Ra-r][A-Ra-r][0-9][0-9]*')"
            ") ORDER BY rowid LIMIT 500",
            variables: [Variable<int>(after)],
          )
          .get();
      if (rows.isEmpty) break;
      for (final row in rows) {
        after = row.read<int>('row_id');
        final decoded = jsonDecode(row.read<String>('data'));
        // Unreachable for a row that passed `json_valid` and holds an object,
        // which every operation record is — logged rather than skipped in
        // silence because the one way to reach it is a blob no writer of ours
        // produced, and this is the only pass that will ever look at it.
        if (decoded is! Map<String, dynamic>) {
          DevLog.instance.log('migration', {'step': 'repairStatedLocations', 'skipped': after});
          continue;
        }
        if (!repairStatedLocation(decoded)) continue;
        repaired++;
        await m.database.customStatement('UPDATE operations SET data = ? WHERE rowid = ?', [jsonEncode(decoded), after]);
      }
    }
    // The count is the only trace this pass leaves: the rows it changes keep
    // their revision stamps, so nothing else afterwards can say it ran, and
    // what it dropped is not recoverable from the record it dropped it from.
    if (repaired > 0) DevLog.instance.log('migration', {'step': 'repairStatedLocations', 'repaired': repaired});
  }

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

/// A log file written by a build newer than this one, refused rather than
/// migrated back down (see the `from > to` guard in [HaLoDatabase.migration]).
///
/// Its own type rather than a StateError with a recognizable message: this is
/// the payload of an ErrorPolicy rule, and a rule that matches on message
/// text eventually claims a real error that merely reads the same. It also
/// carries the two versions as numbers, so a caller can say which build wrote
/// the log without parsing them back out of a sentence.
class LogFromNewerBuild implements Exception {
  const LogFromNewerBuild({required this.storage, required this.understood});

  /// The storage version the file on disk is at.
  final int storage;

  /// The highest storage version this build knows how to read.
  final int understood;

  /// This refusal, wherever it is in [error] — or null if [error] is
  /// something else entirely.
  ///
  /// The app opens its database over a background isolate
  /// (`driftDatabase(native:)` → `NativeDatabase.createBackgroundConnection`),
  /// and drift reports anything raised on the far side as a
  /// `DriftRemoteException` holding the original in `remoteCause`. So the
  /// exception this class describes NEVER arrives as itself in the running
  /// app — only in a test that opens a `NativeDatabase` in-process. Any
  /// `catch (e) if (e is LogFromNewerBuild)`, or any policy matching on the
  /// type, silently stops working the moment it leaves the test harness.
  /// Every such site goes through here instead.
  ///
  /// A loop rather than one unwrap: the request crosses the boundary in both
  /// directions, and a re-raised remote error can be wrapped again.
  static LogFromNewerBuild? within(Object? error) {
    var current = error;
    while (current is DriftRemoteException) {
      current = current.remoteCause;
    }
    return current is LogFromNewerBuild ? current : null;
  }

  @override
  String toString() =>
      'LogFromNewerBuild: this log was written by a newer version of Ham2K Logger '
      '(storage v$storage; this build understands v$understood)';
}
