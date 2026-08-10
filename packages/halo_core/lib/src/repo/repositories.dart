// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Repositories are the only writers to the database. Every write keeps the
// indexed columns derived from the JSON `data`, marks rows dirty for sync
// (`synced = false`), and maintains the operation's cached counters. Reads
// for the UI are reactive drift streams — the database is the source of
// truth and, later, the multi-window bus (DESIGN.md §8).

import 'dart:convert';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_clock.dart';
import '../db/database.dart';
import 'sequences.dart';
import '../dev_log.dart';
import '../models/models.dart';

const _uuidGenerator = Uuid();


/// Whether an inbound sync record should be skipped in favor of the local
/// row it would overwrite. Both sides carry a revision stamp
/// (`updatedAtMillis`, written on every local edit and round-tripped through
/// the server inside the record's JSON): when both stamps exist, the inbound
/// record only wins if it is strictly newer — same rule as app-polo's
/// `mergeSyncQSOs`. Without unconditional-overwrite protection here, a pull
/// racing a local edit (or a "combine" backfill pulling this device's own
/// older copies back down) silently reverts local changes and marks them
/// synced. When the inbound record has no stamp (pre-stamp history), only
/// local rows with unpushed edits (`synced == false`) are protected; clean
/// rows accept it.
/// Rewrites app-polo's older `*OnMillis` spellings to the `*AtMillis` ones
/// this app reads, in place, the way polo's own `operationsDB.js` does on
/// read. Inbound sync can carry either, and the merge below compares
/// revisions BEFORE anything goes through the model's getters — so without
/// this a legacy record looks revision-less and loses every comparison.
void _normalizeLegacyStamps(Map<String, dynamic> data) {
  for (final (legacy, current) in const [
    ('createdOnMillis', 'createdAtMillis'),
    ('updatedOnMillis', 'updatedAtMillis'),
  ]) {
    final value = data.remove(legacy);
    if (value != null) data.putIfAbsent(current, () => value);
  }
}

bool _inboundIsStale({
  required int? existingUpdatedAtMillis,
  required bool existingSynced,
  required int? incomingUpdatedAtMillis,
}) {
  if (existingUpdatedAtMillis != null && incomingUpdatedAtMillis != null) {
    return existingUpdatedAtMillis >= incomingUpdatedAtMillis;
  }
  return incomingUpdatedAtMillis == null && !existingSynced;
}

/// Tracks the min/max `syncedAtMillis` seen while merging one inbound sync
/// batch — see `OperationsRepository.mergeFromSync`.
class SyncWatermark {
  int? earliestSyncedAtMillis;
  int? latestSyncedAtMillis;

  void include(int? syncedAtMillis) {
    if (syncedAtMillis == null) return;
    if (earliestSyncedAtMillis == null || syncedAtMillis < earliestSyncedAtMillis!) {
      earliestSyncedAtMillis = syncedAtMillis;
    }
    if (latestSyncedAtMillis == null || syncedAtMillis > latestSyncedAtMillis!) {
      latestSyncedAtMillis = syncedAtMillis;
    }
  }
}

class OperationsRepository {
  final HaLoDatabase db;

  /// Notified after every local write so the sync engine can debounce a
  /// small-batch round (DESIGN.md §4) — kept as a plain callback rather than
  /// a direct dependency so this repository doesn't need to know the sync
  /// engine's type.
  final void Function()? onChange;

  OperationsRepository(this.db, {this.onChange});

  Future<Operation> create({required String stationCall, String userTitle = ''}) async {
    final operation = Operation(
      uuid: _uuidGenerator.v4(),
      data: {
        'stationCall': stationCall.toUpperCase(),
        'userTitle': userTitle,
        // The creation DATE is what the operator reads, so it travels; the
        // revision stamp is what another device compares against, so it does
        // not (realNowMillis's doc comment, docs/design/time.md §1).
        'createdAtMillis': nowMillis(),
        'updatedAtMillis': realNowMillis(),
      },
    );
    await db.into(db.operations).insert(OperationsCompanion.insert(
          uuid: operation.uuid,
          data: Value(jsonEncode(operation.data)),
          // The column mirrors the revision stamp inside `data`, so it reads
          // the same real clock.
          updatedAtMillis: Value(operation.data['updatedAtMillis'] as int),
        ));
    onChange?.call();
    return operation;
  }

  Stream<List<Operation>> watchAll() {
    // Sorting falls back to fields within the JSON data blob (like
    // createdAtMillis) for operations with no QSOs, so the sort happens
    // in Dart rather than SQL.
    final query = (db.select(db.operations)
      ..where((op) => op.deleted.equals(false)));
    return query.watch().map((rows) {
      final list = rows.map(_operationFromRow).toList();
      list.sort((a, b) {
        final aTime = a.startAtMillisMax ?? a.createdAtMillis ?? 0;
        final bTime = b.startAtMillisMax ?? b.createdAtMillis ?? 0;
        final cmp = bTime.compareTo(aTime);
        if (cmp != 0) return cmp;

        // Tie-breaker: createdAtMillis DESC (most recently created first)
        final aCreated = a.createdAtMillis ?? 0;
        final bCreated = b.createdAtMillis ?? 0;
        return bCreated.compareTo(aCreated);
      });
      return list;
    });
  }

  Future<Operation?> get(String uuid) async {
    final row = await (db.select(db.operations)..where((op) => op.uuid.equals(uuid))).getSingleOrNull();
    return row == null ? null : _operationFromRow(row);
  }

  /// Reactive single-operation query — emits the current row and every later
  /// version (counter refreshes, detail/activity/location edits, and the
  /// `localData` scoring summary a rescore writes). Lets views bind the
  /// operation instead of manually re-fetching after each mutating action, so
  /// there's no stale copy or hand-rolled `localData` merge to keep in sync.
  /// Emits null if the operation doesn't exist (or is hard-deleted).
  Stream<Operation?> watchOperation(String uuid) {
    return (db.select(db.operations)..where((op) => op.uuid.equals(uuid)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _operationFromRow(row));
  }

  Future<void> saveData(Operation operation) async {
    final now = realNowMillis();
    final data = {...operation.data, 'updatedAtMillis': now};
    await (db.update(db.operations)..where((op) => op.uuid.equals(operation.uuid))).write(
      OperationsCompanion(
        data: Value(jsonEncode(data)),
        synced: const Value(false),
        updatedAtMillis: Value(now),
      ),
    );
    onChange?.call();
  }

  Future<void> softDelete(String uuid) async {
    // Re-stamps `data.updatedAtMillis` too (not just the flags): the delete
    // must sync as a revision newer than the record it tombstones, or other
    // devices' merge comparison would discard it as stale.
    final now = realNowMillis();
    final operation = await get(uuid);
    var companion = OperationsCompanion(
      deleted: const Value(true),
      synced: const Value(false),
      updatedAtMillis: Value(now),
    );
    if (operation != null) {
      companion = companion.copyWith(data: Value(jsonEncode({...operation.data, 'updatedAtMillis': now})));
    }
    await (db.update(db.operations)..where((op) => op.uuid.equals(uuid))).write(companion);
    onChange?.call();
  }

  /// Up to `limit` dirty operations, most-recently-active first — the same
  /// selection app-polo's sync loop uses for its "large batch" round
  /// (`sync.js`'s `queryOperations('WHERE synced IS false ...')`).
  Future<List<Operation>> unsyncedBatch(int limit) async {
    final query = (db.select(db.operations)
      ..where((op) => op.synced.equals(false))
      ..orderBy([
        (op) => OrderingTerm(expression: op.startAtMillisMax, mode: OrderingMode.desc, nulls: NullsOrder.first),
      ])
      ..limit(limit));
    return (await query.get()).map(_operationFromRow).toList();
  }

  /// Fetches specific operations by uuid (e.g. the parents of a QSO batch),
  /// optionally narrowed to ones still unsynced.
  Future<List<Operation>> byUuids(List<String> uuids, {bool onlyUnsynced = false}) async {
    if (uuids.isEmpty) return const [];
    final query = db.select(db.operations)..where((op) => op.uuid.isIn(uuids));
    if (onlyUnsynced) query.where((op) => op.synced.equals(false));
    return (await query.get()).map(_operationFromRow).toList();
  }

  Future<bool> hasUnsynced() async {
    final row =
        await (db.select(db.operations)..where((op) => op.synced.equals(false))..limit(1)).getSingleOrNull();
    return row != null;
  }

  /// Flips the sent rows to `synced = true` — but only those whose revision
  /// stamp still matches what was actually sent. A row edited while the
  /// sync round's network call was in flight has a newer stamp (and
  /// `synced = false` again); marking it unconditionally would silently
  /// swallow that edit forever.
  Future<void> markSynced(Iterable<Operation> sent) async {
    final list = sent.toList();
    if (list.isEmpty) return;
    await db.transaction(() async {
      for (final o in list) {
        final stamp = o.updatedAtMillis;
        await (db.update(db.operations)
              ..where((op) =>
                  op.uuid.equals(o.uuid) &
                  (stamp == null ? op.updatedAtMillis.isNull() : op.updatedAtMillis.equals(stamp))))
            .write(const OperationsCompanion(synced: Value(true)));
      }
    });
  }

  /// Total and pending-sync counts, reported in the sync payload's `meta`
  /// (mirrors `getSyncCounts()` in app-polo's `sync.js`).
  ///
  /// `total` is what this device HOLDS, so tombstones don't count — they're
  /// records that no longer exist as far as the user is concerned. `pending`
  /// is what it still owes the server, so tombstones DO count: a delete only
  /// reaches other devices by being pushed.
  Future<({int total, int pending})> syncCounts() async {
    final count = db.operations.uuid.count();
    Future<int> countWhere(Expression<bool> predicate) async {
      final query = db.selectOnly(db.operations)
        ..addColumns([count])
        ..where(predicate);
      return (await query.getSingle()).read(count) ?? 0;
    }

    return (
      total: await countWhere(db.operations.deleted.equals(false)),
      pending: await countWhere(db.operations.synced.equals(false)),
    );
  }

  /// Upserts operations received from the sync server. Leaves the locally
  /// derived counters (`qsoCount`, `startAtMillisMin/Max`) alone — they get
  /// recomputed from this device's own QSOs once any of this operation's
  /// QSOs are merged in too, and shouldn't be clobbered by the server's view
  /// of them in the meantime.
  ///
  /// Returns the min/max `syncedAtMillis` seen in this batch — a server-side
  /// watermark distinct from `startAtMillis`, carried on every inbound
  /// record — so `SyncEngine` can track "synced since" for the next pull,
  /// mirroring app-polo's `mergeSyncOperations`.
  Future<SyncWatermark> mergeFromSync(List<Map<String, dynamic>> operations) async {
    final watermark = SyncWatermark();
    final incomingUuids = [for (final m in operations) m['uuid']].whereType<String>().toList();
    await db.transaction(() async {
      final existingRows = incomingUuids.isEmpty
          ? const <OperationRow>[]
          : await (db.select(db.operations)..where((op) => op.uuid.isIn(incomingUuids))).get();
      final existingByUuid = {for (final r in existingRows) r.uuid: r};

      for (final incoming in operations) {
        final uuid = incoming['uuid'] as String?;
        if (uuid == null) continue;
        final data = Map<String, dynamic>.from(incoming)..remove('uuid');
        final deleted = data.remove('deleted') == true;
        _normalizeLegacyStamps(data);
        watermark.include((data['syncedAtMillis'] as num?)?.toInt());

        final existing = existingByUuid[uuid];
        if (existing != null &&
            _inboundIsStale(
              existingUpdatedAtMillis: existing.updatedAtMillis,
              existingSynced: existing.synced,
              incomingUpdatedAtMillis: (data['updatedAtMillis'] as num?)?.toInt(),
            )) {
          continue;
        }

        await db.into(db.operations).insertOnConflictUpdate(OperationsCompanion(
              uuid: Value(uuid),
              data: Value(jsonEncode(data)),
              deleted: Value(deleted),
              synced: const Value(true),
              updatedAtMillis: Value((data['updatedAtMillis'] as num?)?.toInt()),
            ));
      }
    });
    // No onChange() here: everything just written is already marked
    // synced, so there's nothing new for the outbound side to react to.
    return watermark;
  }

  /// Marks every operation dirty, deleted ones included — used when
  /// "combining" local data into a newly linked account (DESIGN.md's sync
  /// reconciliation flow): the account has no idea this device's data
  /// exists yet, so all of it needs to go out, not just whatever changed
  /// since the last (different-account) sync. Mirrors app-polo's
  /// `resetSyncedStatus`.
  Future<void> resetSyncedStatus() async {
    await db.update(db.operations).write(const OperationsCompanion(synced: Value(false)));
  }

  /// Copies every operation (deleted ones included) into `OperationsBackup`
  /// under `backupId`, then deletes all of them from the live table — used
  /// when "replacing" local data with a different account's, or by the
  /// `SYNCALL` command. Mirrors app-polo's `clearAllOperationData`, but as a
  /// portable copy-then-delete instead of its SQLite-specific `ALTER TABLE
  /// RENAME` trick.
  Future<void> backupAndClearAll(String backupId) async {
    final now = nowMillis();
    await db.transaction(() async {
      final rows = await db.select(db.operations).get();
      for (final row in rows) {
        await db.into(db.operationsBackup).insert(OperationsBackupCompanion.insert(
              backupId: backupId,
              backupAtMillis: now,
              uuid: row.uuid,
              data: row.data,
              startAtMillisMin: Value(row.startAtMillisMin),
              startAtMillisMax: Value(row.startAtMillisMax),
              qsoCount: Value(row.qsoCount),
              deleted: Value(row.deleted),
            ));
      }
      await db.delete(db.operations).go();
    });
  }

  Operation _operationFromRow(OperationRow row) => Operation(
        uuid: row.uuid,
        data: jsonDecode(row.data) as Map<String, dynamic>,
        qsoCount: row.qsoCount,
        startAtMillisMin: row.startAtMillisMin,
        startAtMillisMax: row.startAtMillisMax,
        deleted: row.deleted,
        synced: row.synced,
        localData: row.localData == null ? const {} : jsonDecode(row.localData!) as Map<String, dynamic>,
      );

  /// Merges [patch] into this operation's device-local, never-synced state
  /// (e.g. `ScoringService` writing its `scoring` summary blob under that
  /// key). Never touches `synced` — `localData` isn't part of what syncs.
  Future<void> updateLocalData(String uuid, Map<String, dynamic> patch) async {
    await db.transaction(() async {
      final operation = await get(uuid);
      if (operation == null) return;
      final merged = {...operation.localData, ...patch};
      await (db.update(db.operations)..where((op) => op.uuid.equals(uuid))).write(
        OperationsCompanion(localData: Value(jsonEncode(merged))),
      );
    });
  }
}

Qso _qsoFromRow(QsoRow row) => Qso(
      uuid: row.uuid,
      operationUuid: row.operation,
      data: jsonDecode(row.data) as Map<String, dynamic>,
      deleted: row.deleted,
      scoreCache: row.scoreCache,
    );

/// Below this, decoding inline is cheaper than an isolate's spawn cost;
/// above it, [_qsoFromRow]'s per-row `jsonDecode` is real enough CPU work
/// (not the framework's usual sub-millisecond synchronous calls) that
/// running it on the UI isolate blocks that isolate's frame pump for long
/// enough to read as a stall rather than a stutter — moving it off-isolate
/// trades a slightly later result for a UI thread that stays free to
/// animate the transition while it waits.
const _qsoRowDecodeIsolateThreshold = 200;

Future<List<Qso>> _qsosFromRows(List<QsoRow> rows) async {
  if (rows.length < _qsoRowDecodeIsolateThreshold) return rows.map(_qsoFromRow).toList();
  try {
    return await Isolate.run(() => rows.map(_qsoFromRow).toList());
  } catch (_) {
    // Isolate.spawn doesn't exist on web (dart2js/DDC) — halo_core is pure
    // Dart with no Flutter dependency, so there's no `kIsWeb` to branch on
    // up front — and any other isolate-infrastructure failure (spawn
    // refused under memory pressure, etc.) deserves the same recovery:
    // `watchForOperation`'s callers `.listen()` this without an `onError`,
    // so an error here would otherwise silently kill live rescoring instead
    // of just costing a slower decode. A genuinely malformed row still
    // throws the same way it did before this existed — inline decoding
    // doesn't change what a bad row does, only where a healthy one runs.
    return rows.map(_qsoFromRow).toList();
  }
}

class QsosRepository {
  final HaLoDatabase db;

  /// See `OperationsRepository.onChange`.
  final void Function()? onChange;

  /// Serial-number allocation (docs/design/contests.md §5.8). Null outside the
  /// app, where nothing declares a sequence; `add` then allocates nothing,
  /// which keeps `halo_core` free of any extension knowledge.
  ///
  /// Allocation must be atomic with the insert, so it happens here — but WHICH
  /// sequences exist is extension-declared, so the caller passes the
  /// descriptors to `add` instead of this layer going looking for them.
  final SequencesRepository? sequences;

  QsosRepository(this.db, {this.onChange, this.sequences});

  /// Settles the serial on [qso]'s ref.
  ///
  /// A number already on the ref WINS — it is what the logging panel showed the
  /// operator, which is what they sent on the air, so the log has to agree with
  /// it. The sequence is then raised past it so it can never be issued again.
  /// This is the normal path for a QSO logged through the UI.
  ///
  /// Allocation is the fallback, for QSOs that arrive without a number: the
  /// second and later calls of a call list, an extension-driven `addQso`, or
  /// any headless caller. It happens here, inside the insert transaction, so
  /// two of them can't collide.
  ///
  /// Returns a QSO with a fresh data map rather than mutating: a call-list
  /// batch shares one `refs` list across every `add()`, so mutating in place
  /// would give every call in the batch the first one's number.
  Future<Qso> _withAllocatedSerial(String operationUuid, Qso qso, SequenceRequest request) async {
    final refs = [
      for (final ref in qso.refs) Map<String, dynamic>.from(ref),
    ];
    final index = refs.indexWhere((r) => r['type'] == request.refType);

    final existing = index < 0 ? null : refs[index][request.field];
    final sent = existing is int ? existing : int.tryParse('${existing ?? ''}'.trim());

    // Either way the field ends up an int, so exports and the derived
    // high-water mark never have to care which path a number came from.
    final value = sent ?? await sequences!.allocate(operationUuid, request);
    if (sent != null) await sequences!.raiseTo(operationUuid, request, sent);
    // Keep the derived-mark memo exact rather than making the next insert
    // rescan the log — this is the hot path, once per QSO.
    sequences!.noteIssued(operationUuid, request, value);

    if (index < 0) {
      refs.add({'type': request.refType, request.field: value});
    } else {
      refs[index][request.field] = value;
    }
    return Qso(
      uuid: qso.uuid,
      operationUuid: qso.operationUuid,
      data: {...qso.data, 'refs': refs},
      deleted: qso.deleted,
      scoreCache: qso.scoreCache,
    );
  }

  /// Inserts a QSO from QSON data, deriving the indexed columns and
  /// refreshing the operation's counters, all in one transaction.
  ///
  /// [serialSequences] are the sequences the operation's contests declared
  /// (docs/design/contests.md §5.8); each fills its field on the QSO's ref
  /// unless the operator typed a number themselves.
  Future<Qso> add(
    String operationUuid,
    Map<String, dynamic> qsoData, {
    List<SequenceDescriptor> serialSequences = const [],
  }) async {
    final data = Map<String, dynamic>.from(qsoData);
    data['startAtMillis'] ??= nowMillis();
    data['uuid'] ??= _uuidGenerator.v4();
    data['updatedAtMillis'] = realNowMillis();

    var qso = Qso(uuid: data['uuid'] as String, operationUuid: operationUuid, data: data);

    await db.transaction(() async {
      // Serial numbers are allocated HERE — once, at commit, atomically with
      // the insert (docs/design/contests.md §5.8). Anywhere earlier is
      // app-polo's root defect: a number claimed while composing leaks when the
      // QSO is wiped, and tapping a spot mid-QSO gives two QSOs the same one.
      //
      // The label is resolved from the QSO as committed, not from whatever band
      // was selected when the descriptor was fetched — the operator can still
      // change band between the lookup and pressing Enter.
      //
      // Event rows never allocate. NOTE/TODO/SOLAR/WEATHER annotations reach
      // this same `add` from the extension runtime carrying `band: 'event'`,
      // and burning a serial on each would silently gap the contest log.
      if (!qso.isEvent && sequences != null) {
        for (final descriptor in serialSequences) {
          qso = await _withAllocatedSerial(operationUuid, qso, descriptor.requestFor(qso));
        }
        // A real contact inserted with NO declared sequences may still carry a
        // serial on a ref — an ADIF import, or an extension's `addQso` command.
        // We can't know which labels it touched, so drop the memo and let the
        // next peek re-derive rather than issue a number already in the log.
        if (serialSequences.isEmpty && qso.refs.isNotEmpty) sequences!.invalidate();
      }
      await db.into(db.qsos).insert(_companionFor(qso));
      await _refreshOperationCounters(operationUuid);
    });
    onChange?.call();
    // Structured dev event — real contacts only, not timeline markers.
    if (!qso.isEvent) {
      DevLog.instance.log('qso', {
        'uuid': qso.uuid,
        'op': operationUuid,
        'call': (data['their'] as Map?)?['call'],
        'band': data['band'],
        'mode': data['mode'],
      });
    }
    return qso;
  }

  /// Adds a start/break/end marker to the QSO timeline (see `Qso.isEvent`).
  /// [operation] makes this a SEGMENT boundary rather than a plain marker: a
  /// `break`/`start` carrying one states the operation for the stretch that
  /// follows — a second park, a rover's new grid (docs/design/contests.md
  /// §5.1.3). It is a complete statement, not a diff: attributes it omits fall
  /// back to the base operation, never to the previous segment, so whatever
  /// calls this is responsible for restating anything meant to persist.
  Future<Qso> addEvent(
    String operationUuid, {
    required String kind,
    required int atMillis,
    Map<String, dynamic>? operation,
  }) {
    return add(operationUuid, {
      'band': 'event',
      'startAtMillis': atMillis,
      'event': {'event': kind, if (operation != null) 'operation': operation},
    });
  }

  Future<Qso?> get(String uuid) async {
    final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(uuid))).getSingleOrNull();
    return row == null ? null : _qsoFromRow(row);
  }

  /// Writes a whole batch — new contacts inserted, existing ones updated — in
  /// ONE transaction, refreshing the operation's counters once and firing
  /// [onChange] once. Returns the number of rows written.
  ///
  /// [add] and [update] each open their own transaction and each refresh the
  /// counters, which is right for logging a contact and wrong for importing a
  /// thousand: the per-QSO cost is small but the per-QSO `onChange` rebuilds
  /// the QSO list every time, so an import would redraw the log once per
  /// contact while it ran.
  ///
  /// **Allocates no serial numbers.** An import carries whatever numbers the
  /// file had; issuing new ones would renumber someone's contest log. The
  /// memoized high-water mark is invalidated instead, so the next contact
  /// logged by hand re-derives it from a log that now includes these — the
  /// same reasoning as [update]'s hand-edited serial.
  ///
  /// **A uuid already in the table throws and rolls the whole batch back** —
  /// half an import is worse than none, since the operator can retry a failure
  /// but cannot easily find what a partial one landed. `uuid` is the primary
  /// key ACROSS operations, not within one, so this fires both for a plan
  /// built against a log that has since changed AND for a record that already
  /// exists in a different operation. The second is a re-import rather than a
  /// stale plan, and a caller that wants to support it (importing a QSON
  /// export into a new operation) has to strip or remap the uuids first.
  ///
  /// **QSON values must already be well-typed.** `startAtMillis` is coerced
  /// because it is the one field this method sets itself, but `band`, `mode`
  /// and the rest reach drift's typed columns as they came, so a file that
  /// puts a number where a string belongs throws a cast error mid-batch.
  /// Validating a whole record is the parser's job, not this one's.
  Future<int> writeBatch({
    required String operationUuid,
    List<Map<String, dynamic>> inserts = const [],
    List<Qso> updates = const [],
  }) async {
    if (inserts.isEmpty && updates.isEmpty) return 0;

    final toInsert = <Qso>[];
    for (final data in inserts) {
      // One uuid, used for both the row and the QSON it carries — generating
      // it twice would give the record two identities. Typed loosely because
      // this data came out of a file: `as String?` would throw on a numeric
      // uuid rather than falling back.
      final supplied = data['uuid'];
      final uuid = supplied is String && supplied.isNotEmpty ? supplied : _uuidGenerator.v4();
      toInsert.add(Qso(
        uuid: uuid,
        operationUuid: operationUuid,
        data: {
          ...data,
          'uuid': uuid,
          // Coerced, not passed through: a file can carry "1721736000000" as
          // a string, and drift's typed column would throw a cast error
          // partway through the batch rather than rejecting the record.
          'startAtMillis': _millisOf(data['startAtMillis']) ?? nowMillis(),
          'updatedAtMillis': realNowMillis(),
        },
      ));
    }

    // A row's own `operationUuid` is what gets written, so an update carrying a
    // different one would MOVE that row — and this method refreshes the
    // counters of the operation it was given, leaving the one the row came
    // from permanently stale, since nothing recomputes it until the next write
    // there. Moving a contact between operations is a different job with a
    // different name; refusing is louder than silently corrupting a count.
    final targeted = <String>{};
    for (final qso in updates) {
      if (qso.operationUuid != operationUuid) {
        throw ArgumentError.value(
          qso.operationUuid,
          'updates',
          'QSO ${qso.uuid} belongs to a different operation than this batch',
        );
      }
      // Two updates for one row would apply in order, the second discarding
      // the first's merge, and BOTH would count as written. A plan that
      // targets a record twice has not finished folding; combining them here
      // would hide that.
      if (!targeted.add(qso.uuid)) {
        throw ArgumentError.value(qso.uuid, 'updates', 'QSO appears twice in one batch');
      }
    }

    var written = 0;
    await db.transaction(() async {
      for (final qso in toInsert) {
        await db.into(db.qsos).insert(_companionFor(qso));
        written++;
      }
      for (final qso in updates) {
        // The row is keyed on `qso.uuid`, so the QSON must agree. A merged
        // record takes the newer side's fields — `uuid` among them — so a QSON
        // import can hand back a map carrying the INCOMING file's uuid, and
        // writing it verbatim would leave the row with two identities.
        // `deleted` and `scoreCache` are deliberately NOT carried:
        // `_companionFor` writes neither column, so passing them would suggest
        // an authority this path does not have. It follows that an update
        // against a soft-deleted row succeeds into a tombstone and counts as
        // written while staying invisible — callers build their plan from
        // `watchForOperation`, which excludes deleted rows, so a plan should
        // never target one.
        final stamped = _restamped(Qso(
          uuid: qso.uuid,
          operationUuid: qso.operationUuid,
          data: {...qso.data, 'uuid': qso.uuid},
        ));
        // An update whose uuid is no longer in the table affects no rows.
        // Counting it anyway would report an import as complete while a record
        // deleted since the plan was built silently didn't land.
        written += await (db.update(db.qsos)..where((q) => q.uuid.equals(stamped.uuid)))
            .write(_companionFor(stamped));
      }
      await _refreshOperationCounters(operationUuid);
    });

    sequences?.invalidate();
    onChange?.call();
    return written;
  }

  Future<void> update(Qso qso) async {
    final stamped = _restamped(qso);
    await db.transaction(() async {
      await (db.update(db.qsos)..where((q) => q.uuid.equals(stamped.uuid))).write(_companionFor(stamped));
      await _refreshOperationCounters(stamped.operationUuid);
    });
    // An edit can change a serial by hand, and never routes through the
    // allocator — so the memoized high-water mark can no longer be trusted.
    // AFTER the commit: invalidating first would let a scan started in between
    // read the pre-edit log and memoize that as current.
    sequences?.invalidate();
    onChange?.call();
  }

  Future<void> softDelete(Qso qso) => _writeDeleted(qso, deleted: true);

  /// Restores a soft-deleted QSO. Pushing sends
  /// `deleted` only when true (see `SyncEngine._buildPayload`), so the
  /// restored record's payload simply omits the key.
  Future<void> undelete(Qso qso) => _writeDeleted(qso, deleted: false);

  /// Flips the deleted flag, re-stamping `data.updatedAtMillis` (rewriting
  /// `data`, not just flags): the write must sync as a revision newer than
  /// the record it tombstones/restores, or other devices' merge comparison
  /// would discard it. Re-reads the row inside the transaction rather than
  /// trusting the caller's [qso] — that's a selection-time snapshot which
  /// can sit on screen indefinitely, and sync may have merged a newer
  /// revision since; restamping the snapshot would clobber those edits on
  /// every device.
  Future<void> _writeDeleted(Qso qso, {required bool deleted}) async {
    var changed = false;
    await db.transaction(() async {
      final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(qso.uuid))).getSingleOrNull();
      if (row == null) return; // hard-deleted since selection — nothing to flip
      final stamped = _restamped(_qsoFromRow(row));
      await (db.update(db.qsos)..where((q) => q.uuid.equals(stamped.uuid))).write(
        QsosCompanion(
          deleted: Value(deleted),
          synced: const Value(false),
          data: Value(jsonEncode(stamped.data)),
          updatedAtMillis: Value(stamped.updatedAtMillis),
        ),
      );
      await _refreshOperationCounters(stamped.operationUuid);
      changed = true;
    });
    if (changed) onChange?.call();
  }

  /// A copy of [qso] with a fresh revision stamp in its data — every local
  /// write goes through this so `data.updatedAtMillis` and the mirrored
  /// column never diverge (a divergent pair would make `markSynced`'s
  /// stamp comparison fail forever and the row re-push in a loop).
  Qso _restamped(Qso qso) => Qso(
        uuid: qso.uuid,
        operationUuid: qso.operationUuid,
        data: {...qso.data, 'updatedAtMillis': realNowMillis()},
        deleted: qso.deleted,
        scoreCache: qso.scoreCache,
      );

  /// A timestamp as milliseconds, whatever shape it arrived in. Mirrors
  /// `qso_merge.dart`'s reader: if the two disagree about a string timestamp,
  /// a record matches nothing during planning and is then inserted anyway —
  /// a duplicate of a contact already in the log.
  static int? _millisOf(Object? value) {
    if (value is num) return value.isFinite ? value.toInt() : null;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Stream<List<Qso>> watchForOperation(String operationUuid, {bool includeDeleted = false}) {
    final query = (db.select(db.qsos)
      ..where((q) => includeDeleted
          ? q.operation.equals(operationUuid)
          : q.operation.equals(operationUuid) & q.deleted.equals(false))
      ..orderBy([(q) => OrderingTerm(expression: q.startAtMillis)]));
    return query.watch().asyncMap(_qsosFromRows);
  }

  /// Every non-deleted, non-event QSO with [call] across every operation, most
  /// recent first — for the call-info detail's QSO history. Matches the
  /// denormalized `theirCall` column (stored uppercase), so no JSON parsing.
  ///
  /// Deleting an operation deliberately does NOT tombstone its QSOs — that
  /// would be unrecoverable, since undeleting could no longer tell which of
  /// them the user had deleted individually beforehand. So a cross-operation
  /// query has to join: a QSO counts as gone when its own flag says so OR
  /// when the operation it belongs to is deleted. The join is a LEFT OUTER
  /// one because a QSO can outlive its operation row (an inbound sync batch
  /// can carry QSOs before the operation they belong to arrives) — those
  /// count as present, same as before.
  Future<List<Qso>> historyForCall(String call) async {
    final normalized = call.trim().toUpperCase();
    if (normalized.isEmpty) return const [];
    final query = db.select(db.qsos).join([
      leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
    ])
      ..where(db.qsos.theirCall.equals(normalized) &
          db.qsos.deleted.equals(false) &
          (db.operations.deleted.equals(false) | db.operations.uuid.isNull()))
      ..orderBy([OrderingTerm(expression: db.qsos.startAtMillis, mode: OrderingMode.desc)]);
    final rows = await query.get();
    return [
      for (final row in rows.map((r) => _qsoFromRow(r.readTable(db.qsos))))
        if (!row.isEvent) row,
    ];
  }

  /// Up to `limit` dirty QSOs, most recent first — mirrors `sync.js`'s
  /// `queryQSOs("WHERE synced IS false ... ORDER BY startAtMillis DESC")`.
  Future<List<Qso>> unsyncedBatch(int limit) async {
    final query = (db.select(db.qsos)
      ..where((q) => q.synced.equals(false))
      ..orderBy([(q) => OrderingTerm(expression: q.startAtMillis, mode: OrderingMode.desc)])
      ..limit(limit));
    return (await query.get()).map(_qsoFromRow).toList();
  }

  Future<bool> hasUnsynced() async {
    final row = await (db.select(db.qsos)..where((q) => q.synced.equals(false))..limit(1)).getSingleOrNull();
    return row != null;
  }

  /// See `OperationsRepository.markSynced` — only rows whose revision stamp
  /// still matches the sent copy are marked, so an edit made while the
  /// round's network call was in flight stays dirty and re-pushes.
  Future<void> markSynced(Iterable<Qso> sent) async {
    final list = sent.toList();
    if (list.isEmpty) return;
    await db.transaction(() async {
      for (final q in list) {
        final stamp = q.updatedAtMillis;
        await (db.update(db.qsos)
              ..where((row) =>
                  row.uuid.equals(q.uuid) &
                  (stamp == null ? row.updatedAtMillis.isNull() : row.updatedAtMillis.equals(stamp))))
            .write(const QsosCompanion(synced: Value(true)));
      }
    });
  }

  /// See `OperationsRepository.syncCounts`. `total` applies the same rule
  /// `historyForCall` does — a QSO is gone when its own flag says so or when
  /// its operation's does — so deleting an operation drops its contacts from
  /// the count without touching a single QSO row.
  ///
  /// Event markers (start/break/end, `Qso.isEvent`) are not contacts and are
  /// excluded, the same way [syncCountsForOperation] excludes them: anything
  /// labelled "QSOs" to the operator must mean the number they logged. LoFi's
  /// `Account#stats` applies the same filter so the two sides stay comparable
  /// in the Sync panel's Synced Data row.
  /// A row of the qsos table that is a contact rather than a start/break/end
  /// marker. The ONE definition — every count the operator reads as "QSOs"
  /// uses it, and LoFi's `QSO.contacts` scope mirrors it so the Sync panel can
  /// put the two numbers side by side.
  ///
  /// `band` is nullable, and `NOT (band = 'event')` is NULL — not true — for a
  /// QSO logged without one, so the null case has to be spelled out or those
  /// QSOs silently leave the count.
  Expression<bool> get _isContact => db.qsos.band.equals('event').not() | db.qsos.band.isNull();

  Future<({int total, int pending})> syncCounts() async {
    final count = db.qsos.uuid.count();

    final totalQuery = db.selectOnly(db.qsos).join([
      leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
    ])
      ..addColumns([count])
      ..where(db.qsos.deleted.equals(false) &
          _isContact &
          (db.operations.deleted.equals(false) | db.operations.uuid.isNull()));
    final totalCount = (await totalQuery.getSingle()).read(count) ?? 0;

    final pendingQuery = db.selectOnly(db.qsos)
      ..addColumns([count])
      ..where(db.qsos.synced.equals(false));
    final pendingCount = (await pendingQuery.getSingle()).read(count) ?? 0;

    return (total: totalCount, pending: pendingCount);
  }

  /// Same as [syncCounts], but scoped to one operation's (non-deleted) rows,
  /// and split into real QSOs vs. event markers (start/break/end, see
  /// `Qso.isEvent`) — for the Exports Panel's per-operation sync summary,
  /// which exports only real QSOs (`ExportService._qsoListFor`) and would
  /// otherwise show a pending count inflated by markers that never export.
  Future<({int total, int pending, int eventTotal, int eventPending})> syncCountsForOperation(String operationUuid) async {
    final count = db.qsos.uuid.count();
    Future<int> countWhere(Expression<bool> where) async {
      final result = await (db.selectOnly(db.qsos)
            ..addColumns([count])
            ..where(where))
          .getSingle();
      return result.read(count) ?? 0;
    }

    final base = db.qsos.operation.equals(operationUuid) & db.qsos.deleted.equals(false);
    // Not `_isContact.not()`: a QSO with no band belongs to neither side under
    // a naive negation, and would vanish from the panel entirely.
    final isEvent = db.qsos.band.equals('event');

    final total = await countWhere(base & _isContact);
    final pending = await countWhere(base & _isContact & db.qsos.synced.equals(false));
    final eventTotal = await countWhere(base & isEvent);
    final eventPending = await countWhere(base & isEvent & db.qsos.synced.equals(false));

    return (total: total, pending: pending, eventTotal: eventTotal, eventPending: eventPending);
  }

  /// Upserts QSOs received from the sync server and refreshes the counters
  /// of every operation they belong to. See `OperationsRepository.mergeFromSync`
  /// for the returned watermark's purpose.
  Future<SyncWatermark> mergeFromSync(List<Map<String, dynamic>> qsos) async {
    final watermark = SyncWatermark();
    final affectedOperations = <String>{};
    final incomingUuids = [for (final m in qsos) m['uuid']].whereType<String>().toList();
    await db.transaction(() async {
      final existingRows = incomingUuids.isEmpty
          ? const <QsoRow>[]
          : await (db.select(db.qsos)..where((q) => q.uuid.isIn(incomingUuids))).get();
      final existingByUuid = {for (final r in existingRows) r.uuid: r};

      for (final incoming in qsos) {
        final uuid = incoming['uuid'] as String?;
        final operationUuid = incoming['operation'] as String?;
        if (uuid == null || operationUuid == null) continue;

        final data = Map<String, dynamic>.from(incoming)..remove('operation');
        final deleted = data.remove('deleted') == true;
        _normalizeLegacyStamps(data);
        watermark.include((data['syncedAtMillis'] as num?)?.toInt());

        final existing = existingByUuid[uuid];
        if (existing != null &&
            _inboundIsStale(
              existingUpdatedAtMillis: existing.updatedAtMillis,
              existingSynced: existing.synced,
              incomingUpdatedAtMillis: (data['updatedAtMillis'] as num?)?.toInt(),
            )) {
          continue;
        }

        final qso = Qso(uuid: uuid, operationUuid: operationUuid, data: data);

        await db.into(db.qsos).insertOnConflictUpdate(
              _companionFor(qso).copyWith(synced: const Value(true), deleted: Value(deleted)),
            );
        affectedOperations.add(operationUuid);
      }
      for (final operationUuid in affectedOperations) {
        await _refreshOperationCounters(operationUuid);
      }
    });
    // Another device's numbers arrived without passing through the allocator,
    // so re-derive rather than hand out one already on the air. AFTER the
    // commit — see `update` above for why the ordering matters.
    sequences?.invalidate();
    // No onChange() here — see OperationsRepository.mergeFromSync.
    return watermark;
  }

  /// See `OperationsRepository.resetSyncedStatus`.
  Future<void> resetSyncedStatus() async {
    await db.update(db.qsos).write(const QsosCompanion(synced: Value(false)));
  }

  /// See `OperationsRepository.backupAndClearAll`.
  Future<void> backupAndClearAll(String backupId) async {
    final now = nowMillis();
    await db.transaction(() async {
      final rows = await db.select(db.qsos).get();
      for (final row in rows) {
        await db.into(db.qsosBackup).insert(QsosBackupCompanion.insert(
              backupId: backupId,
              backupAtMillis: now,
              uuid: row.uuid,
              operation: row.operation,
              data: row.data,
              deleted: Value(row.deleted),
            ));
      }
      await db.delete(db.qsos).go();
    });
    sequences?.invalidate();
  }

  /// Batch-writes cached scoring results, one row update per QSO but all in
  /// a single transaction — the counterpart to the `scoring` hook's single
  /// coarse batched call (DESIGN.md §4). Score cache is locally derived, not
  /// synced content, so this never touches `synced` or fires [onChange];
  /// `watchForOperation` streams pick up the change on their own since it's
  /// still a write to the `qsos` table.
  Future<void> updateScoreCache(Map<String, String> scoreCacheByUuid) async {
    if (scoreCacheByUuid.isEmpty) return;
    await db.batch((batch) {
      for (final entry in scoreCacheByUuid.entries) {
        batch.update(
          db.qsos,
          QsosCompanion(scoreCache: Value(entry.value)),
          where: (q) => q.uuid.equals(entry.key),
        );
      }
    });
  }

  QsosCompanion _companionFor(Qso qso) => QsosCompanion(
        uuid: Value(qso.uuid),
        operation: Value(qso.operationUuid),
        ourCall: Value(qso.ourCall),
        theirCall: Value(qso.theirCall),
        band: Value(qso.band),
        mode: Value(qso.mode),
        startAtMillis: Value(qso.startAtMillis),
        data: Value(jsonEncode(qso.data)),
        synced: const Value(false),
        updatedAtMillis: Value(qso.updatedAtMillis),
      );

  /// `qsoCount`/`startAtMillisMin/Max` are a locally derived cache — never
  /// part of the JSON payload sync sends (see `SyncEngine._buildPayload`) —
  /// so refreshing them must not flip `synced` back to false. Doing so
  /// would make an operation perpetually "dirty" any time its QSOs change,
  /// even after a round already sent its actual (unchanged) content.
  Future<void> _refreshOperationCounters(String operationUuid) async {
    final count = db.qsos.uuid.count();
    final minStart = db.qsos.startAtMillis.min();
    final maxStart = db.qsos.startAtMillis.max();
    // Event pseudo-QSOs (start/break/end markers) share the qsos table but
    // aren't real contacts — exclude them from the count and time range.
    final notEvent = db.qsos.band.isNull() | db.qsos.band.equals('event').not();
    final query = db.selectOnly(db.qsos)
      ..addColumns([count, minStart, maxStart])
      ..where(db.qsos.operation.equals(operationUuid) & db.qsos.deleted.equals(false) & notEvent);
    final row = await query.getSingle();

    await (db.update(db.operations)..where((op) => op.uuid.equals(operationUuid))).write(
      OperationsCompanion(
        qsoCount: Value(row.read(count) ?? 0),
        startAtMillisMin: Value(row.read(minStart)),
        startAtMillisMax: Value(row.read(maxStart)),
      ),
    );
  }
}

class LookupRepository {
  final HaLoDatabase db;

  LookupRepository(this.db);

  /// Performs a bulk insert or replace of lookup rows inside a single transaction.
  Future<void> insertLookupBatch(List<LookupRow> rows) async {
    await db.transaction(() async {
      await db.batch((batch) {
        for (final row in rows) {
          batch.insert(
            db.lookups,
            row,
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  /// Deletes all lookups within a specific category.
  Future<void> deleteCategory(String category) async {
    await (db.delete(db.lookups)..where((l) => l.category.equals(category))).go();
  }

  /// Deletes all lookups in a category that do not have the specified updated flag value (stale data).
  Future<void> deleteCategoryStale(String category, int updatedValue) async {
    await (db.delete(db.lookups)
          ..where((l) => l.category.equals(category) & l.updated.equals(updatedValue).not()))
        .go();
  }

  /// Retrieves a single lookup row by category and key.
  Future<LookupRow?> getLookup(String category, String key) async {
    return await (db.select(db.lookups)
          ..where((l) => l.category.equals(category) & l.key.equals(key)))
        .getSingleOrNull();
  }

  /// Searches lookups in a category by matching query prefix on key or name.
  Future<List<LookupRow>> queryLookups(String category, String query) async {
    return await (db.select(db.lookups)
          ..where((l) =>
              l.category.equals(category) &
              (l.key.like('%$query%') | l.name.like('%$query%')))
          ..limit(100))
        .get();
  }

  /// Searches lookups in a category by proximity to a lat/lon coordinate
  /// within a delta, closest first. Ordering (by squared distance, cheaper
  /// than a real Haversine and fine for ranking within this small bounding
  /// box) has to happen before the `limit` — otherwise the cap keeps
  /// whichever 100 rows the query planner happens to hit first rather than
  /// the 100 actually nearest to the caller, and a close-by entry can be
  /// dropped in favor of farther ones.
  Future<List<LookupRow>> queryLookupsByLocation(
      String category, double lat, double lon, double delta) async {
    final latDelta = db.lookups.lat - Variable(lat);
    final lonDelta = db.lookups.lon - Variable(lon);
    final distanceSquared = latDelta * latDelta + lonDelta * lonDelta;
    return await (db.select(db.lookups)
          ..where((l) =>
              l.category.equals(category) &
              l.lat.isBetweenValues(lat - delta, lat + delta) &
              l.lon.isBetweenValues(lon - delta, lon + delta))
          ..orderBy([(l) => OrderingTerm.asc(distanceSquared)])
          ..limit(100))
        .get();
  }
}
