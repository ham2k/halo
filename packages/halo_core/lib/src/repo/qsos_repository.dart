// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Contacts: the only writer to the `qsos` table — local edits, batch
// imports, and the merge paths sync and peers arrive through. The contract
// every repository keeps is stated in repo_support.dart.

import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../app_clock.dart';
import '../db/database.dart';
import 'sequences.dart';
import '../dev_log.dart';
import '../models/models.dart';
import '../models/qso_merge.dart';
import '../models/segments.dart';
import '../models/qson_values.dart';
import 'write_policy.dart';

import 'operations_repository.dart';
import 'repo_support.dart';

/// SQLite's default bound-variable limit is 999. [historyForCalls]'s query
/// binds a few more params alongside the `IN` clause itself (the `deleted`/
/// `uuid.isNull()` checks), so this stays under that with room to spare
/// rather than pushing all the way to 999. As large as it safely can,
/// though, not just "safe": each chunk is a full query+decode round trip,
/// and a re-import whose `theirCall`s mostly already exist pays for a much
/// bigger result set per chunk than a fresh one does, so fewer, larger
/// chunks matter more here than for a fresh import's near-empty results.
const _inClauseChunkSize = 900;

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

  /// Throws [WriteRefused] if a NEW contact in [operationUuid] may not be
  /// written right now — see [WritePolicy].
  ///
  /// [ourCall] is consulted only when [operationUuid] is empty: a contact
  /// inside an operation is made with that operation's station call, so the
  /// operation decides. For a contact with no operation the declared call is
  /// the only identity there is, exactly as a new operation's own callsign is
  /// (`markedForTravel`).
  ///
  /// Reads nothing at all unless the clock is travelled, so the ordinary
  /// logging path pays for this with one boolean.
  Future<void> _refuseNewQso(String operationUuid, {String ourCall = ''}) async {
    if (!AppClock.instance.isTravelling) return;
    final refusal = WritePolicy.forQso(
      operation: await _operationFor(operationUuid),
      ourCall: operationUuid.isEmpty ? ourCall : '',
    );
    if (refusal != null) throw refusal;
  }

  /// Throws [WriteRefused] if the STORED contact [uuid] may not be written.
  ///
  /// Judged on the row in the database, never on the caller's copy. The
  /// caller's is a selection-time snapshot — the same one [_writeDeleted]
  /// already refuses to trust for its own write — and an edit that declared
  /// `our.call` as a test call would otherwise be its own permission slip,
  /// admitting a rewrite of a real contact's times in a single step.
  ///
  /// A row that is gone is not refused: the write below finds nothing and
  /// does nothing, which is the same outcome by a quieter route.
  Future<void> _refuseStoredQso(String uuid) async {
    if (!AppClock.instance.isTravelling) return;
    final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(uuid))).getSingleOrNull();
    if (row == null) return;
    final stored = qsoFromRow(row);
    final refusal = WritePolicy.forQso(
      operation: await _operationFor(stored.operationUuid),
      ourCall: stored.operationUuid.isEmpty ? stored.ourCall : '',
    );
    if (refusal != null) throw refusal;
  }

  /// The stored operation [uuid] names, or null when it names none.
  ///
  /// Only the station call is read, so the row is decoded here rather than
  /// reaching for `OperationsRepository` — this repository holds none, and the
  /// derived columns play no part in the judgement.
  Future<Operation?> _operationFor(String uuid) async {
    if (uuid.isEmpty) return null;
    final row = await (db.select(db.operations)..where((op) => op.uuid.equals(uuid))).getSingleOrNull();
    if (row == null) return null;
    return Operation(uuid: row.uuid, data: jsonDecode(row.data) as Map<String, dynamic>);
  }

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
    // A number the operator was shown is written even when the log already
    // holds it — it went on the air — but the record says so
    // (docs/design/contests.md §5.8.1): the alert is the honest outcome of two
    // positions sending one number, and a silently duplicated log is not.
    final duplicate = sent != null && await sequences!.isIssued(operationUuid, request, sent);
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
      data: {...qso.data, 'refs': refs, if (duplicate) Qso.serialConflictKey: true},
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
    data['uuid'] ??= uuidGenerator.v4();
    data['updatedAtMillis'] = realNowMillis();

    var qso = Qso(uuid: data['uuid'] as String, operationUuid: operationUuid, data: data);
    await _refuseNewQso(operationUuid, ourCall: qso.ourCall);

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
      await db.into(db.qsos).insert(_companionFor(qso, 'qsos:add'));
      await refreshOperationCounters(operationUuid);
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
  /// [description] is what the row shows in the list ("for ARRL 10G Sep •
  /// at FN20rm"), composed by the caller from the override. Stored rather
  /// than composed at render — a deliberate divergence from polo, whose
  /// `EventSegmentItem` recomposes per frame: naming a reference here means
  /// an async hook call per ref, which a list row cannot make. Null when the
  /// caller could not compose one; the row then renders what it can from
  /// the override itself.
  Future<Qso> addEvent(
    String operationUuid, {
    required String kind,
    required int atMillis,
    Map<String, dynamic>? operation,
    String? description,
  }) {
    return add(operationUuid, {
      'band': 'event',
      'startAtMillis': atMillis,
      'event': {
        'event': kind,
        'operation': ?operation,
        'description': ?description,
      },
    });
  }

  Future<Qso?> get(String uuid) async {
    final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(uuid))).getSingleOrNull();
    return row == null ? null : qsoFromRow(row);
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
    // The plan-time snapshots the updates were merged from, by uuid. Any
    // row that moved past its snapshot between planning and this write (a
    // sync pull landing while the import's confirm dialog sat open) gets
    // its update re-merged against the row as it is NOW
    // ([mergeConcurrentEdit]), so the concurrent revision's fields survive
    // wherever the file didn't touch them. An update without a snapshot
    // writes as given.
    Map<String, Qso> updateBases = const {},
    // `false` for a caller writing one operation across many chunked calls
    // (a large import) — the counters only need to be right after the LAST
    // chunk, so the intermediate ones pass `false` here and the caller runs
    // [refreshOperationCounters] itself, once, after the final chunk.
    bool refreshCounters = true,
  }) async {
    if (inserts.isEmpty && updates.isEmpty) return 0;
    // Judged on the operation alone, unlike [add] — a bulk write names one
    // operation, and letting individual test-called records through would
    // land them inside a real operation, where nothing can find them again:
    // every cleanup path this feature relies on works per operation.
    await _refuseNewQso(operationUuid);

    final toInsert = <Qso>[];
    for (final data in inserts) {
      // One uuid, used for both the row and the QSON it carries — generating
      // it twice would give the record two identities. Typed loosely because
      // this data came out of a file: `as String?` would throw on a numeric
      // uuid rather than falling back.
      final supplied = data['uuid'];
      final uuid = supplied is String && supplied.isNotEmpty ? supplied : uuidGenerator.v4();
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
      // `db.batch()`, not one `.insert()`/`.write()` call per row — a large
      // import (thousands of records) otherwise pays a separate
      // prepare/bind/execute round trip per row; batching compiles the whole
      // set into one statement, the same way `insertLookupBatch` already does
      // for lookup rows. Still inside `db.transaction()`, so a duplicate uuid
      // still throws and rolls the whole batch back (`batch.insert`'s default
      // conflict mode matches `.insert()`'s).
      if (toInsert.isNotEmpty) {
        await db.batch((batch) {
          for (final qso in toInsert) {
            batch.insert(db.qsos, _companionFor(qso, 'qsos:writeBatch'));
          }
        });
        written += toInsert.length;
      }
      if (updates.isNotEmpty) {
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
        final stampedByUuid = <String, Qso>{
          for (final qso in updates)
            qso.uuid: _restamped(Qso(
              uuid: qso.uuid,
              operationUuid: qso.operationUuid,
              data: {...qso.data, 'uuid': qso.uuid},
            )),
        };
        // `batch.update` has no return value, unlike the row-by-row `.write()`
        // this replaces — so which uuids actually exist is checked up front,
        // inside the same transaction (so nothing else can change it
        // underneath this read). An update whose uuid is no longer in the
        // table affects no rows; counting it anyway would report an import as
        // complete while a record deleted since the plan was built silently
        // didn't land.
        //
        // Chunked at [_inClauseChunkSize], the same as [historyForCalls] — a
        // caller that hands a large re-import's merges straight through
        // (`adif_import_flow.dart` does not chunk its own `writeBatch` call)
        // would otherwise build one `IN` clause with one bound variable per
        // update, and a big enough operation exceeds SQLite's limit on a
        // record count this method used to have no such ceiling on at all.
        final updateUuids = stampedByUuid.keys.toList();
        final existingUuids = <String>{};
        for (var i = 0; i < updateUuids.length; i += _inClauseChunkSize) {
          final chunk = updateUuids.sublist(i, math.min(i + _inClauseChunkSize, updateUuids.length));
          if (updateBases.isEmpty) {
            // No snapshots to reconcile against: the uuid projection is all
            // the check needs. Selecting full rows here would jsonDecode
            // every target's blob inline, mid-transaction — the same decode
            // [historyForCalls] routes through an isolate above 200 rows —
            // and a single corrupt blob would abort a batch whose UPDATE
            // would have overwritten it anyway.
            final rows = await (db.selectOnly(db.qsos)
                  ..addColumns([db.qsos.uuid])
                  ..where(db.qsos.uuid.isIn(chunk)))
                .map((row) => row.read(db.qsos.uuid)!)
                .get();
            existingUuids.addAll(rows);
            continue;
          }
          // Re-merge any target that moved past its plan-time snapshot —
          // see [updateBases]. Inside the same transaction as the write, so
          // the row read here is the row the batch below overwrites.
          final rows = await (db.select(db.qsos)..where((q) => q.uuid.isIn(chunk))).get();
          for (final row in rows) {
            existingUuids.add(row.uuid);
            final base = updateBases[row.uuid];
            if (base == null) continue;
            // `edited` is the already-stamped planned update — byte-identical
            // to the caller's data apart from `updatedAtMillis`, which the
            // outer restamp below overwrites anyway.
            final planned = stampedByUuid[row.uuid]!;
            final Qso current;
            try {
              current = qsoFromRow(row);
            } catch (_) {
              // A corrupt stored blob can't be merged with — write the
              // planned update as-is, which replaces the bad blob.
              continue;
            }
            if (current.data['updatedAtMillis'] == base.data['updatedAtMillis']) continue;
            stampedByUuid[row.uuid] = _restamped(Qso(
              uuid: row.uuid,
              operationUuid: planned.operationUuid,
              data: mergeConcurrentEdit(base: base.data, current: current.data, edited: planned.data),
            ));
          }
        }
        await db.batch((batch) {
          for (final uuid in existingUuids) {
            batch.update(db.qsos, _companionFor(stampedByUuid[uuid]!, 'qsos:writeBatch'),
                where: (q) => q.uuid.equals(uuid));
          }
        });
        written += existingUuids.length;
      }
      if (refreshCounters) await refreshOperationCounters(operationUuid);
    });

    sequences?.invalidate();
    onChange?.call();
    return written;
  }

  /// [basedOn] is the record the editor loaded — the snapshot [qso]'s data
  /// was composed from. When given, the row is re-read inside the
  /// transaction and, if something else (a sync pull, a peer merge, a
  /// background lookup) moved it past that snapshot while the editor sat
  /// open, the concurrent revision's fields survive wherever this edit
  /// didn't touch them ([mergeConcurrentEdit]). Without the re-read, the
  /// whole-record write reverts the concurrent revision — and, restamped
  /// newer, the reversion wins on every device at the next sync. Same
  /// reasoning as [_writeDeleted]'s re-read.
  Future<void> update(Qso qso, {Qso? basedOn}) async {
    await _refuseStoredQso(qso.uuid);
    var stamped = _restamped(qso);
    await db.transaction(() async {
      if (basedOn != null) {
        final current = await get(qso.uuid);
        if (current != null && current.data['updatedAtMillis'] != basedOn.data['updatedAtMillis']) {
          stamped = _restamped(Qso(
            uuid: qso.uuid,
            operationUuid: qso.operationUuid,
            data: mergeConcurrentEdit(base: basedOn.data, current: current.data, edited: qso.data),
          ));
        }
      }
      await (db.update(db.qsos)..where((q) => q.uuid.equals(stamped.uuid)))
          .write(_companionFor(stamped, 'qsos:update'));
      await refreshOperationCounters(stamped.operationUuid);
    });
    // An edit can change a serial by hand, and never routes through the
    // allocator — so the memoized high-water mark can no longer be trusted.
    // AFTER the commit: invalidating first would let a scan started in between
    // read the pre-edit log and memoize that as current.
    sequences?.invalidate();
    onChange?.call();
  }

  /// Marks the QSO carrying [number] on [request]'s sequence as a serial
  /// another position also sent (docs/design/contests.md §5.8.1) — the
  /// write-back for a conflict that reaches this device after its own QSO
  /// was committed. A no-op when no such QSO is here, or it is marked already.
  Future<void> markSerialConflict(String operationUuid, SequenceRequest request, int number) async {
    final rows = await (db.select(db.qsos)..where((q) => q.operation.equals(operationUuid))).get();
    for (final row in rows) {
      final qso = Qso(
        uuid: row.uuid,
        operationUuid: row.operation,
        data: jsonDecode(row.data) as Map<String, dynamic>,
        deleted: row.deleted,
      );
      if (qso.isEvent || qso.serialConflict || !request.includes(qso)) continue;
      if (request.serialOn(qso) != number) continue;
      await update(Qso(
        uuid: qso.uuid,
        operationUuid: qso.operationUuid,
        data: {...qso.data, Qso.serialConflictKey: true},
        deleted: qso.deleted,
        scoreCache: qso.scoreCache,
      ));
      return;
    }
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
    await _refuseStoredQso(qso.uuid);
    var changed = false;
    await db.transaction(() async {
      final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(qso.uuid))).getSingleOrNull();
      if (row == null) return; // hard-deleted since selection — nothing to flip
      final stamped = _restamped(qsoFromRow(row));
      await (db.update(db.qsos)..where((q) => q.uuid.equals(stamped.uuid))).write(
        QsosCompanion(
          deleted: Value(deleted),
          synced: const Value(false),
          data: Value(encodeQsoData(stamped.data, 'qsos:writeDeleted')),
          updatedAtMillis: Value(stamped.updatedAtMillis),
        ),
      );
      await refreshOperationCounters(stamped.operationUuid);
      changed = true;
    });
    if (changed) onChange?.call();
  }

  /// Live test contacts that belong to no operation.
  ///
  /// Purging works per operation everywhere else — `purgeTestOperations` walks
  /// operations, and the received-purge prompt is keyed on operation uuids —
  /// so a contact with no operation is reachable by none of it. The travelled
  /// clock can author exactly these (a test call is the only thing identifying
  /// one), which is what makes the omission a leak rather than a corner.
  ///
  /// Filtered in Dart, not SQL: [isTestCall] matches `/`-separated SEGMENTS,
  /// which no LIKE pattern expresses, and the set being scanned is contacts
  /// with no operation at all — every loose contact on the account, since sync
  /// carries them between devices, but still not the size of the log.
  Future<List<Qso>> testQsosWithoutOperation() async {
    final rows = await (db.select(db.qsos)
          ..where((q) => q.operation.equals('') & q.purged.equals(false)))
        .get();
    return (await qsosFromRows(rows)).where((qso) => isTestCall(qso.ourCall)).toList();
  }

  /// Tombstones [uuids] as purged, the same two-step [purgeForOperation]
  /// applies: the row stays until sync has carried the tombstone, and
  /// [hardDeletePurgedOrphans] removes it after that.
  ///
  /// Only ever called with contacts that have no operation, and only for TEST
  /// data — see `testQsosWithoutOperation`. A contact with no operation is
  /// ordinary data that happens to belong to nothing, and purging one is the
  /// operator's explicit act, never a consequence of having no operation.
  ///
  /// Removal is not prompt, and does not have to be: the row is `deleted` as
  /// well as `purged` from the moment this returns, so nothing shows it. The
  /// hard delete waits for a sync round that runs the gated sweep — in
  /// practice the first round of a later session — and on a device with sync
  /// switched off it never comes at all, since `synced` never becomes true.
  /// That is the same deal [purgeForOperation] and `hardDeletePurged` have
  /// always made for operations.
  Future<int> purgeQsos(Iterable<String> uuids) async {
    final ids = uuids.toList();
    if (ids.isEmpty) return 0;
    var purged = 0;
    await db.transaction(() async {
      for (final uuid in ids) {
        final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(uuid))).getSingleOrNull();
        if (row == null) continue;
        // Re-checked inside the transaction, not trusted from the caller's
        // list: that list is built before a confirmation dialog the operator
        // may sit on indefinitely, and sync rounds run while travelling now,
        // so an inbound edit can give a row an operation — or a real call —
        // in between. A purge is unrecoverable and invisible once done.
        final stored = qsoFromRow(row);
        if (stored.operationUuid.isNotEmpty || !isTestCall(stored.ourCall)) continue;
        final stamped = _restamped(qsoFromRow(row));
        await (db.update(db.qsos)..where((q) => q.uuid.equals(uuid))).write(
          QsosCompanion(
            deleted: const Value(true),
            purged: const Value(true),
            synced: const Value(false),
            data: Value(encodeQsoData(stamped.data, 'qsos:purge')),
            updatedAtMillis: Value(stamped.updatedAtMillis),
          ),
        );
        purged++;
      }
    });
    if (purged > 0) onChange?.call();
    return purged;
  }

  /// Soft-deletes with `purged: true` every QSO of [operationUuid],
  /// regardless of its current `deleted` state — the QSO-side half of
  /// `OperationsRepository.purge`. Unlike a normal operation delete (which
  /// deliberately leaves QSOs alone, see [historyForCall]'s doc), a purge is
  /// unrecoverable by design, so touching every QSO row directly is safe:
  /// there's no "undelete" state left to lose track of.
  Future<void> purgeForOperation(String operationUuid) async {
    await _refuseNewQso(operationUuid);
    await db.transaction(() async {
      final rows = await (db.select(db.qsos)..where((q) => q.operation.equals(operationUuid))).get();
      for (final row in rows) {
        // The mirrored column must match `stamped.data`'s own
        // `updatedAtMillis`, not a separately-captured timestamp — a
        // divergence here is exactly what makes `markSynced`'s stamp
        // comparison fail forever and the row re-push in a loop.
        final stamped = _restamped(qsoFromRow(row));
        await (db.update(db.qsos)..where((q) => q.uuid.equals(stamped.uuid))).write(
          QsosCompanion(
            deleted: const Value(true),
            purged: const Value(true),
            synced: const Value(false),
            data: Value(encodeQsoData(stamped.data, 'qsos:purge')),
            updatedAtMillis: Value(stamped.updatedAtMillis),
          ),
        );
      }
    });
    onChange?.call();
  }

  /// See `OperationsRepository.hardDeletePurged` — the QSO-side half, run
  /// after a purged operation's row has already been hard-deleted so an
  /// orphaned QSO never outlives its operation.
  Future<void> hardDeletePurgedForOperation(String operationUuid) async {
    await (db.delete(db.qsos)
          ..where((q) => q.operation.equals(operationUuid) & q.purged.equals(true) & q.synced.equals(true)))
        .go();
  }

  /// Removes every QSO of [operationUuid], no flags checked — for a
  /// confirmed RECEIVED purge (`OperationsRepository.confirmReceivedPurges`),
  /// where [hardDeletePurgedForOperation]'s `purged && synced` predicate
  /// isn't reliable: operations and QSOs arrive in separate sync batches, so
  /// an operator can confirm as soon as the operation record lands, before
  /// this operation's QSOs' own purge tombstones have. A QSO left behind by
  /// that predicate would have no operation row to belong to any more, yet
  /// would keep surfacing in call history and dupe checks forever. Once the
  /// operator has agreed the whole operation goes, every QSO under it goes
  /// too — there is no partial-purge state left to preserve.
  Future<void> hardDeleteAllForOperation(String operationUuid) async {
    await (db.delete(db.qsos)..where((q) => q.operation.equals(operationUuid))).go();
  }

  /// Removes every purged QSO whose operation no longer exists on this
  /// device — QSOs whose own purge tombstone arrived after the operation
  /// they belong to was already gone (removed here through the
  /// received-purge confirmation, or hard-deleted by
  /// `OperationsRepository.hardDeletePurged` after this device's own purge
  /// synced). Nothing else can ever reach them: every other purge sweep is
  /// keyed by an operation uuid that has to still be there to be found, so
  /// without this they are unreclaimable — invisible (a purged QSO always
  /// carries `deleted: true`, which every read filters on) yet growing the
  /// database for the life of the install, with no operation left to name
  /// them in any future sweep.
  ///
  /// Safe precisely because a QSO is only ever purged as part of its whole
  /// operation ([purgeForOperation] is the only writer of `purged`): an
  /// orphaned purged QSO always belongs to an operation someone confirmed
  /// removing. Still gated on `synced`, so a local purge that hasn't
  /// reached the server yet keeps its tombstone to push.
  /// "Orphan" here means PURGED and already pushed — never merely
  /// operation-less. All three conditions are load-bearing, and the name
  /// invites dropping the first one: a contact with no operation, or one
  /// whose operation was deleted, is ordinary data and must survive this
  /// however long it sits there. Only an explicit purge marks a contact for
  /// removal, and `synced` is what proves the other devices have been told.
  Future<int> hardDeletePurgedOrphans() async {
    final liveOperations = db.selectOnly(db.operations)..addColumns([db.operations.uuid]);
    return (db.delete(db.qsos)
          ..where((q) => q.purged.equals(true) & q.synced.equals(true) & q.operation.isNotInQuery(liveOperations)))
        .go();
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
        purged: qso.purged,
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
    return _forOperationQuery(operationUuid, includeDeleted: includeDeleted).watch().asyncMap(qsosFromRows);
  }

  /// The same rows as [watchForOperation], read once. For a one-off read
  /// (a command that needs the log as it stands), not `watchForOperation(...)
  /// .first`: a drift stream's first value never arrives inside a widget
  /// test's fake-async zone, so a caller awaiting it there hangs.
  Future<List<Qso>> forOperation(String operationUuid, {bool includeDeleted = false}) async {
    return qsosFromRows(await _forOperationQuery(operationUuid, includeDeleted: includeDeleted).get());
  }

  /// Rewrites the override on the operation's latest `start`/`break` row to
  /// [override], so the current stretch follows an edit to the operation
  /// (see `OperationsRepository.onLocalSave`). No segment, or one already
  /// stating this: no write — a restamp is a revision every other device
  /// receives, and a no-op one is churn on the sync. Returns whether a row
  /// was written.
  ///
  /// [describe] is called ONLY once a row is going to be written: composing
  /// a description is an extension fan-out, too expensive to pay on an
  /// unsegmented log's every save.
  ///
  /// A null result CLEARS the stored description rather than keeping it.
  /// Reaching here means the override is changing, so the old line describes
  /// a location or a reference set the row no longer states — keeping it
  /// would leave the row reading "at FN20rm" beside an override that says
  /// FN31, and sync that contradiction to every device. Cleared, the row
  /// falls back to what its own override can say (`EventRow`).
  Future<bool> restampLatestSegment(
    String operationUuid,
    Map<String, dynamic> override, {
    Future<String?> Function()? describe,
  }) async {
    Qso? latest;
    for (final row in await eventsForOperation(operationUuid)) {
      if (eventKindOpensSegment(row.eventKind)) latest = row;
    }
    if (latest == null) return false;
    final event = latest.event ?? const <String, dynamic>{};
    if (jsonEncode(event['operation']) == jsonEncode(override)) return false;
    final description = await describe?.call();
    await update(Qso(
      uuid: latest.uuid,
      operationUuid: latest.operationUuid,
      data: {
        ...latest.data,
        'event': {
          ...event,
          'operation': override,
          'description': description,
        }..removeWhere((key, value) => key == 'description' && value == null),
      },
    ));
    return true;
  }

  /// Rewrites `our.call` on every real contact of the LATEST segment that
  /// does not already carry [stationCall]. Returns how many were written.
  ///
  /// The station call is what a segment states (`segmentOverrideKeys`), so a
  /// contact inside one cannot disagree with it: the segment IS the claim
  /// about which station was on the air for that stretch. Unlike the operator
  /// — who hands the key over mid-segment, and whose restamp is therefore the
  /// operator's own judgment call — there is nothing here for anyone to
  /// decide, so this runs unasked from `onLocalSave`.
  ///
  /// Contacts before the latest segment are left alone: an earlier stretch
  /// genuinely ran under the call its own segment names, and rewriting it
  /// would be this method claiming the operation had always been one station.
  /// A log with no segment rows at all has one implicit segment covering
  /// everything, so every contact follows.
  ///
  /// Event rows are skipped ([Qso.isRealContact]): a break marker is not a
  /// contact and has no station to be wrong about.
  Future<int> restampSegmentStationCall(String operationUuid, String stationCall) async {
    final call = stationCall.trim();
    if (call.isEmpty) return 0;
    var from = 0;
    for (final row in await eventsForOperation(operationUuid)) {
      if (eventKindOpensSegment(row.eventKind)) from = row.startAtMillis ?? from;
    }
    final contacts = [
      for (final qso in await forOperation(operationUuid))
        if (qso.isRealContact && (qso.startAtMillis ?? 0) >= from && qso.ourCall != call) qso,
    ];
    if (contacts.isEmpty) return 0;
    return writeBatch(
      operationUuid: operationUuid,
      updates: [
        for (final qso in contacts)
          Qso(
            uuid: qso.uuid,
            operationUuid: qso.operationUuid,
            data: {
              ...qso.data,
              'our': {...?asQsonMap(qso.data['our']), 'call': call},
            },
          ),
      ],
      // Read a moment ago, and a sync pull landing in between must survive
      // everywhere this restamp does not reach.
      updateBases: {for (final qso in contacts) qso.uuid: qso},
    );
  }

  /// Just the operation's event rows (`band = 'event'` — see [Qso.isEvent]),
  /// oldest first. What the segment writers and [restampLatestSegment] read:
  /// decoding a whole 5000-QSO log to find a handful of markers is a cost
  /// paid on every local operation save.
  Future<List<Qso>> eventsForOperation(String operationUuid) async {
    final query = db.select(db.qsos)
      ..where((q) => q.operation.equals(operationUuid) & q.deleted.equals(false) & q.band.equals('event'))
      ..orderBy([(q) => OrderingTerm(expression: q.startAtMillis)]);
    return qsosFromRows(await query.get());
  }

  /// When the operation's earliest real contact was, or null for a log with
  /// none — where a `start` marker goes (just before it). In SQL rather than
  /// over a decoded list, for the same reason as [eventsForOperation].
  Future<int?> firstContactMillis(String operationUuid) async {
    final min = db.qsos.startAtMillis.min();
    final query = db.selectOnly(db.qsos)
      ..addColumns([min])
      ..where(db.qsos.operation.equals(operationUuid) &
          db.qsos.deleted.equals(false) &
          db.qsos.band.equals('event').not());
    return (await query.getSingleOrNull())?.read(min);
  }

  SimpleSelectStatement<$QsosTable, QsoRow> _forOperationQuery(String operationUuid, {required bool includeDeleted}) {
    return db.select(db.qsos)
      ..where((q) => includeDeleted
          ? q.operation.equals(operationUuid)
          : q.operation.equals(operationUuid) & q.deleted.equals(false))
      ..orderBy([(q) => OrderingTerm(expression: q.startAtMillis)]);
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
  ///
  /// [limit], when given, bounds the SQL query itself (not a post-fetch
  /// truncation) — for a caller like `call-history`'s lookup source that
  /// only ever reads the most recent match or two: without it, a station
  /// worked hundreds of times ships its entire history across the extension
  /// bridge for an answer that only ever uses the first row. Applied before
  /// the event-marker filter below, so it is a headroom bound, not an exact
  /// result count.
  Future<List<Qso>> historyForCall(String call, {int? limit}) async {
    final normalized = call.trim().toUpperCase();
    if (normalized.isEmpty) return const [];
    final query = db.select(db.qsos).join([
      leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
    ])
      ..where(db.qsos.theirCall.equals(normalized) &
          db.qsos.deleted.equals(false) &
          (db.operations.deleted.equals(false) | db.operations.uuid.isNull()))
      ..orderBy([OrderingTerm(expression: db.qsos.startAtMillis, mode: OrderingMode.desc)]);
    if (limit != null) query.limit(limit);
    final rows = await query.get();
    return [
      for (final row in rows.map((r) => qsoFromRow(r.readTable(db.qsos))))
        if (!row.isEvent) row,
    ];
  }

  /// When each contact [historyForCall] would list started, most recent
  /// first — the call-info's "worked before" pill, which buckets them by
  /// day. One column rather than the rows, so a callsign worked hundreds of
  /// times does not ship every QSO's data to answer a handful of counts.
  ///
  /// [excludingUuid] leaves one QSO out: the QSO being EDITED is already in
  /// the log, and counting it would call a station worked once "worked once
  /// before" while its own QSO is open.
  ///
  /// The same rules as [historyForCall], in SQL: soft-deleted QSOs and QSOs
  /// of deleted operations drop out, and so do event markers — via
  /// [_isContact], since a bare `band != 'event'` is NULL for a band-less
  /// QSO and would drop it too. A QSO with no start time still counts, as
  /// a zero.
  Future<List<int>> historyStartTimesForCall(String call, {String? excludingUuid}) async {
    final normalized = call.trim().toUpperCase();
    if (normalized.isEmpty) return const [];
    final query = db.selectOnly(db.qsos).join([
      leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
    ])
      ..addColumns([db.qsos.startAtMillis])
      ..where(db.qsos.theirCall.equals(normalized) &
          db.qsos.deleted.equals(false) &
          _isContact &
          (excludingUuid == null ? const Constant(true) : db.qsos.uuid.equals(excludingUuid).not()) &
          (db.operations.deleted.equals(false) | db.operations.uuid.isNull()))
      ..orderBy([OrderingTerm(expression: db.qsos.startAtMillis, mode: OrderingMode.desc)]);
    final rows = await query.get();
    return [for (final row in rows) row.read(db.qsos.startAtMillis) ?? 0];
  }

  /// [historyForCall] for every one of [calls] in a single query — an ADIF
  /// import matching a large file's counterparties one callsign at a time
  /// turns into thousands of sequential round trips. Chunked at
  /// [_inClauseChunkSize] for SQLite's bound-variable limit; [watchForOurCalls]
  /// does not chunk its own `IN` list, since every caller today passes it a
  /// single callsign.
  ///
  /// [onChunk], when given, is called after every chunk with (calls looked
  /// up so far, total calls) — real progress for a caller that would
  /// otherwise have nothing but "still working" for however long the
  /// chunks take.
  Future<List<Qso>> historyForCalls(Iterable<String> calls, {void Function(int done, int total)? onChunk}) async {
    final normalized = calls.map((c) => c.trim().toUpperCase()).where((c) => c.isNotEmpty).toSet().toList();
    if (normalized.isEmpty) return const [];
    final results = <Qso>[];
    for (var i = 0; i < normalized.length; i += _inClauseChunkSize) {
      final chunk = normalized.sublist(i, math.min(i + _inClauseChunkSize, normalized.length));
      final query = db.select(db.qsos).join([
        leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
      ])
        ..where(db.qsos.theirCall.isIn(chunk) &
            db.qsos.deleted.equals(false) &
            (db.operations.deleted.equals(false) | db.operations.uuid.isNull()));
      final rows = await query.get();
      // `qsosFromRows`, not a bare `.map(qsoFromRow)` — a chunk from an
      // established callsign can itself clear the isolate-offload
      // threshold, and this runs while the import's progress dialog is
      // animating.
      final decoded = await qsosFromRows([for (final row in rows) row.readTable(db.qsos)]);
      results.addAll(decoded.where((qso) => !qso.isEvent));
      // A caller's progress UI throwing (a disposed notifier, a formatting
      // edge case) must not fail the lookup itself, or discard whatever
      // chunks already decoded cleanly.
      try {
        onChunk?.call(math.min(i + _inClauseChunkSize, normalized.length), normalized.length);
      } catch (e) {
        DevLog.instance.log('historyForCalls-onChunk-error', {'error': e.toString()});
      }
    }
    return results;
  }

  /// Every station callsign QSOs have been logged under, across every
  /// operation, with how many QSOs each has — the Logs experiment's
  /// callsign picker (docs card HALO-273), which shows the count as a pill
  /// next to each entry. Matches the denormalized `ourCall` column (stored
  /// uppercase), same join shape as [historyForCall]: a deleted operation's
  /// QSOs drop out even though deleting an operation does not tombstone
  /// them.
  Stream<Map<String, int>> watchDistinctOurCalls() {
    final count = db.qsos.uuid.count();
    final query = db.selectOnly(db.qsos).join([
      leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
    ])
      ..addColumns([db.qsos.ourCall, count])
      ..where(db.qsos.ourCall.isNotNull() &
          db.qsos.ourCall.equals('').not() &
          db.qsos.deleted.equals(false) &
          // Event markers (start/break/end) carry no real callsign —
          // excluded the same way `historyForCall` excludes them from a
          // QSO list, or a callsign whose only rows are markers shows up
          // in this picker with nothing behind it. `_isContact`, not a
          // bare `band != 'event'`: that reads NULL — not true — for a
          // QSO logged without a band, silently dropping it too.
          _isContact &
          (db.operations.deleted.equals(false) | db.operations.uuid.isNull()))
      ..groupBy([db.qsos.ourCall]);
    return query.watch().map((rows) {
      final calls = <String, int>{};
      for (final row in rows) {
        final call = row.read(db.qsos.ourCall);
        if (call != null && call.isNotEmpty) calls[call] = row.read(count) ?? 0;
      }
      return calls;
    });
  }

  /// Every non-deleted QSO logged under any of [calls] (own station
  /// callsign), across every operation, oldest first — the Logs experiment's
  /// QSO table, scoped by its "log filter". Same join shape as
  /// [historyForCall], but on `ourCall` instead of `theirCall`, and live
  /// (the log filter's callsign selection can change under the caller).
  /// Unlike [historyForCalls], [calls] is not chunked — stay well under
  /// SQLite's bound-variable limit (~999) if the log filter ever grows past a
  /// single callsign.
  Stream<List<Qso>> watchForOurCalls(Iterable<String> calls) {
    final normalized = calls.map((c) => c.trim().toUpperCase()).where((c) => c.isNotEmpty).toSet().toList();
    if (normalized.isEmpty) return Stream.value(const []);
    final query = db.select(db.qsos).join([
      leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
    ])
      ..where(db.qsos.ourCall.isIn(normalized) &
          db.qsos.deleted.equals(false) &
          (db.operations.deleted.equals(false) | db.operations.uuid.isNull()))
      ..orderBy([OrderingTerm(expression: db.qsos.startAtMillis)]);
    return query.watch().asyncMap((rows) async {
      final decoded = await qsosFromRows([for (final row in rows) row.readTable(db.qsos)]);
      // Same exclusion `historyForCall` applies — an event marker is not a
      // QSO, and this view has no concept of one to render or edit.
      return decoded.where((qso) => !qso.isEvent).toList();
    });
  }

  /// Up to `limit` dirty QSOs, most recent first — mirrors `sync.js`'s
  /// `queryQSOs("WHERE synced IS false ... ORDER BY startAtMillis DESC")`.
  /// [excluding] holds records back WITHOUT marking them clean — the sync
  /// engine's refusal quarantine (see `SyncEngine.refusalQuarantine`). Skipped
  /// in the query rather than filtered after it: this is a `LIMIT`, so a
  /// refused record that sorts early would otherwise fill the batch every
  /// round and nothing behind it would ever be offered again.
  Future<List<Qso>> unsyncedBatch(int limit, {Set<String> excluding = const {}}) async {
    final query = (db.select(db.qsos)
      ..where((q) => excluding.isEmpty
          ? q.synced.equals(false)
          : q.synced.equals(false) & q.uuid.isNotIn(excluding.toList()))
      ..orderBy([(q) => OrderingTerm(expression: q.startAtMillis, mode: OrderingMode.desc)])
      ..limit(limit));
    return (await query.get()).map(qsoFromRow).toList();
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

  /// A row of the qsos table that is a contact rather than a start/break/end
  /// marker. The ONE definition — every count the operator reads as "QSOs"
  /// uses it, and LoFi's `QSO.contacts` scope mirrors it so the Sync panel can
  /// put the two numbers side by side.
  ///
  /// `band` is nullable, and `NOT (band = 'event')` is NULL — not true — for a
  /// QSO logged without one, so the null case has to be spelled out or those
  /// QSOs silently leave the count.
  Expression<bool> get _isContact => db.qsos.band.equals('event').not() | db.qsos.band.isNull();

  /// See `OperationsRepository.syncCounts`. `total` applies the same rule
  /// `historyForCall` does — a QSO is gone when its own flag says so or when
  /// its operation's does — so deleting an operation drops its contacts from
  /// the count without touching a single QSO row.
  ///
  /// Event markers (start/break/end, `Qso.isEvent`) are not contacts and are
  /// excluded, the same way [syncCountsForOperation] excludes them: anything
  /// labelled "QSOs" to the operator must mean the number they logged. LoFi's
  /// `QSO.contacts` scope applies the same filter so the two sides stay comparable
  /// in the Sync panel's Synced Data row.
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

  /// How many CONTACTS the server has not received — [syncCounts]'s `total`
  /// rule with `synced == false` added. Distinct from `pending`, which
  /// counts every dirty ROW (tombstones and event markers included) because
  /// it answers the sync loop's "anything to push?"; this one gates
  /// destructive wipe flows, where the number shown to the operator must
  /// mean "logged QSOs that exist nowhere else". A dirty tombstone is
  /// un-pushed state too, but its loss direction is a resurrection, not a
  /// vanished contact — counting it would make the warning wrong in both
  /// magnitude and direction.
  Future<int> unsyncedContactCount() async {
    final count = db.qsos.uuid.count();
    final query = db.selectOnly(db.qsos).join([
      leftOuterJoin(db.operations, db.operations.uuid.equalsExp(db.qsos.operation)),
    ])
      ..addColumns([count])
      ..where(db.qsos.synced.equals(false) &
          db.qsos.deleted.equals(false) &
          _isContact &
          (db.operations.deleted.equals(false) | db.operations.uuid.isNull()));
    return (await query.getSingle()).read(count) ?? 0;
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
        final uuid = asQsonString(incoming['uuid']);
        // A null or absent operation is a contact that belongs to none — the
        // server's own shape for one (`QSO#sync_data_attributes` writes
        // `operation&.uuid`), and what it returns for every loose contact this
        // device pushes. It maps onto the local `''`. Skipping those records
        // makes the loose half of a log a one-way trip: it uploads, the server
        // stores it, and no device ever gets it back.
        //
        // A PRESENT operation of the wrong type is a different thing and still
        // fails closed: it names an operation whose uuid this cannot read, so
        // filing the record as loose would silently detach a contact from the
        // operation it belongs to.
        final rawOperation = incoming['operation'];
        final operationUuid = rawOperation == null ? '' : asQsonString(rawOperation);
        if (uuid == null || operationUuid == null) continue;

        final data = Map<String, dynamic>.from(incoming)..remove('operation');
        final deleted = asQsonBool(data.remove('deleted'));
        // See OperationsRepository.mergeFromSync: carried through, never
        // acted on by a receiving device.
        final purged = data.remove('purged') == true;
        normalizeLegacyStamps(data);
        watermark.include(asQsonNum(data['syncedAtMillis'])?.toInt());

        final existing = existingByUuid[uuid];
        // Never create a row from a purge tombstone — see
        // `OperationsRepository.mergeFromSync` for why re-delivery makes
        // this load-bearing. A tombstone for a QSO this device does not have
        // stands for nothing worth keeping, whichever writer produced it:
        // `purgeForOperation` when a whole operation goes, or `purgeQsos` for
        // a test contact belonging to no operation.
        if (existing == null && purged) continue;
        final incomingUpdatedAtMillis = asQsonNum(data['updatedAtMillis'])?.toInt();
        if (existing != null &&
            inboundIsStale(
              existingUpdatedAtMillis: existing.updatedAtMillis,
              existingSynced: existing.synced,
              incomingUpdatedAtMillis: incomingUpdatedAtMillis,
            )) {
          // See OperationsRepository.mergeFromSync: the flag alone, because
          // the rest of the record is what the staleness gate just rejected.
          if (inboundRepairsTombstone(
            existingDeleted: existing.deleted,
            existingSynced: existing.synced,
            existingUpdatedAtMillis: existing.updatedAtMillis,
            incomingDeleted: deleted,
            incomingUpdatedAtMillis: incomingUpdatedAtMillis,
          )) {
            await (db.update(db.qsos)..where((q) => q.uuid.equals(uuid)))
                .write(const QsosCompanion(deleted: Value(true)));
            // The contact leaves the operation's cached count, which is a
            // column no query recomputes on its own.
            if (existing.operation.isNotEmpty) affectedOperations.add(existing.operation);
          }
          continue;
        }

        final qso = Qso(uuid: uuid, operationUuid: operationUuid, data: data);

        await db.into(db.qsos).insertOnConflictUpdate(
              _companionFor(qso, 'qsos:mergeFromSync')
                  .copyWith(synced: const Value(true), deleted: Value(deleted), purged: Value(purged)),
            );
        // `''` names no operation, so there are no counters to refresh.
        if (operationUuid.isNotEmpty) affectedOperations.add(operationUuid);
        // The operation the record LEAVES, when the inbound copy moves it —
        // into another operation, or (now that a null operation is honoured)
        // out into the general log. Its cached `qsoCount` and start/end
        // bounds are columns, recomputed only by an explicit refresh, so
        // without this they keep counting a contact that is no longer there.
        if (existing != null && existing.operation != operationUuid && existing.operation.isNotEmpty) {
          affectedOperations.add(existing.operation);
        }
      }
      for (final operationUuid in affectedOperations) {
        await refreshOperationCounters(operationUuid);
      }
    });
    // Another device's numbers arrived without passing through the allocator,
    // so re-derive rather than hand out one already on the air. AFTER the
    // commit — see `update` above for why the ordering matters.
    sequences?.invalidate();
    // No onChange() here — see OperationsRepository.mergeFromSync.
    return watermark;
  }

  /// Applies QSOs received from a peer device (HALO-310) — see
  /// `OperationsRepository.mergeFromPeer`'s doc for why this is a sibling of
  /// [mergeFromSync] rather than a caller of it: same upsert/staleness shape,
  /// but left `synced: false` and fires [onChange] so this device still
  /// offers the record to LoFi cloud sync on its own next round.
  Future<void> mergeFromPeer(List<Map<String, dynamic>> qsos) async {
    final affectedOperations = <String>{};
    final incomingUuids = [for (final m in qsos) m['uuid']].whereType<String>().toList();
    await db.transaction(() async {
      final existingRows = incomingUuids.isEmpty
          ? const <QsoRow>[]
          : await (db.select(db.qsos)..where((q) => q.uuid.isIn(incomingUuids))).get();
      final existingByUuid = {for (final r in existingRows) r.uuid: r};

      for (final incoming in qsos) {
        final uuid = asQsonString(incoming['uuid']);
        // Deliberately NOT [mergeFromSync]'s mapping of a null operation onto
        // the local `''`: peer sharing is scoped to one operation, and
        // `PeerOutbox` only ever emits rows carrying that uuid — so a peer
        // record naming no operation is a malformed frame, not a loose
        // contact, and belongs on the floor.
        final operationUuid = asQsonString(incoming['operation']);
        if (uuid == null || operationUuid == null) continue;

        final data = Map<String, dynamic>.from(incoming)..remove('operation');
        final deleted = asQsonBool(data.remove('deleted'));
        final purged = data.remove('purged') == true;
        normalizeLegacyStamps(data);

        final existing = existingByUuid[uuid];
        // See [mergeFromSync] and `OperationsRepository.mergeFromPeer`: a
        // tombstone for a QSO this device does not have stands for nothing
        // worth keeping.
        if (existing == null && purged) continue;
        if (existing != null &&
            inboundIsStale(
              existingUpdatedAtMillis: existing.updatedAtMillis,
              existingSynced: existing.synced,
              incomingUpdatedAtMillis: asQsonNum(data['updatedAtMillis'])?.toInt(),
            )) {
          continue;
        }

        final qso = Qso(uuid: uuid, operationUuid: operationUuid, data: data);
        await db.into(db.qsos).insertOnConflictUpdate(
              _companionFor(qso, 'qsos:mergeFromPeer').copyWith(deleted: Value(deleted), purged: Value(purged)),
            );
        affectedOperations.add(operationUuid);
      }
      for (final operationUuid in affectedOperations) {
        await refreshOperationCounters(operationUuid);
      }
    });
    // A peer's QSO may carry a serial this device's allocator has never seen.
    sequences?.invalidate();
    onChange?.call();
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

  /// [context] names the write path for [encodeQsoData]'s violation
  /// reports. Required rather than defaulted: a single shared label would
  /// make a wrong-typed field arriving from a peer indistinguishable from one
  /// our own importer wrote, which is the only question those reports exist
  /// to answer.
  QsosCompanion _companionFor(Qso qso, String context) => QsosCompanion(
        uuid: Value(qso.uuid),
        operation: Value(qso.operationUuid),
        ourCall: Value(qso.ourCall),
        theirCall: Value(qso.theirCall),
        band: Value(qso.band),
        mode: Value(qso.mode),
        startAtMillis: Value(qso.startAtMillis),
        data: Value(encodeQsoData(qso.data, context)),
        synced: const Value(false),
        updatedAtMillis: Value(qso.updatedAtMillis),
      );

  /// `qsoCount`/`startAtMillisMin/Max` are a locally derived cache — never
  /// part of the JSON payload sync sends (see `SyncEngine._buildPayload`) —
  /// so refreshing them must not flip `synced` back to false. Doing so
  /// would make an operation perpetually "dirty" any time its QSOs change,
  /// even after a round already sent its actual (unchanged) content.
  ///
  /// Public (not called only from within this class) so a caller writing in
  /// many chunks — [writeBatch] with `refreshCounters: false` per chunk — can
  /// run this once after the last one, instead of once per chunk.
  Future<void> refreshOperationCounters(String operationUuid) async {
    // Self-transacting (drift nests a transaction() called from inside
    // another via a savepoint, so this stays cheap for the callers that
    // already wrap it in their own) — the SELECT and the UPDATE below have
    // to be atomic with respect to a concurrent write to the same
    // operation's QSOs, or the UPDATE can overwrite fresher counters with
    // the stale ones this SELECT computed. `refreshTouchedCounters` in
    // `logs_view.dart` is the one caller that has never had an outer
    // transaction of its own to rely on for that.
    await db.transaction(() async {
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
    });
  }
}
