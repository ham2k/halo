// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Contacts: the only writer to the `qsos` table — local edits, batch
// imports, and the merge paths sync and peers arrive through. The contract
// every repository keeps is stated in repo_support.dart.

import 'dart:async';
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
import '../uuid.dart';
import 'write_policy.dart';

import 'operations_repository.dart';
import 'claim_record_queries.dart';
import 'live_log_queries.dart';
import 'qso_history_queries.dart';
import 'qso_log_stream.dart';
import 'qso_sync_queries.dart';
import 'repo_support.dart';

/// What [QsosRepository.changesSince] found: the log's rows that joined or
/// changed, the uuids that left it, and the cursor to ask from next time. A
/// [reset] answer carries the whole log in [qsos] and replaces whatever copy
/// the reader held.
///
/// [count] is how many rows the log holds now. A reader whose copy then
/// holds another number has missed a write the ledger never recorded, and
/// asks for the whole log rather than keep a copy it knows is wrong.
class QsoLogChanges {
  final String cursor;
  final bool reset;
  final List<Qso> qsos;
  final List<String> removed;
  final int count;

  const QsoLogChanges({required this.cursor, required this.count, this.reset = false, this.qsos = const [], this.removed = const []});
}

class QsosRepository with QsoHistoryQueries, ClaimRecordQueries, LiveLogQueries, QsoSyncQueries {
  @override
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

  /// See [QsoWriteLedger]: what each write touched, for [watchForOperation].
  final _ledger = QsoWriteLedger();

  /// The running followers, one per operation and view of it — every listener
  /// of that log shares it (see [QsoLogFollower]). An entry leaves when its
  /// last listener cancels.
  final _followers = <(String, bool), QsoLogFollower>{};

  final _changes = StreamController<Set<String>?>.broadcast();

  /// The contacts each write changed, anywhere in the log: what a listener
  /// that keeps something derived from every contact (claims, docs/design/
  /// claims.md §6) re-reads. Null for a write that may have changed any of
  /// them. Local edits, imports, and what sync and peers merge all arrive
  /// here; writes that change no contact's content — the score cache, sync
  /// bookkeeping — do not.
  ///
  /// Emitted from inside the write's transaction, like the ledger: a listener
  /// reading the contacts back waits on that transaction, so it never reads
  /// them ahead of the write. A write that rolls back after emitting costs a
  /// listener one needless re-read, never a missed change.
  Stream<Set<String>?> get changes => _changes.stream;

  /// Inside the write's transaction, as its last step, only when a statement
  /// reached a row — [QsoWriteLedger] says why; drift lets nothing assert it.
  void _touch(Iterable<String> operations, Iterable<String> uuids) => _touchRows({for (final operation in operations) operation: uuids.toSet()});
  void _touchRows(QsoWriteFootprint rowsByOperation) {
    _ledger.record(rowsByOperation);
    final changed = {for (final uuids in rowsByOperation.values) ...uuids};
    if (changed.isNotEmpty) _changes.add(changed);
  }

  void _touchAll() {
    _ledger.record(null);
    _changes.add(null);
  }

  /// [_touchAll] for a write that only removed rows already deleted: the
  /// open lists re-read, but no contact's content changed, so [changes]
  /// stays quiet — it would cost a whole-log rescan of every chasing program.
  void _touchAllTombstones() => _ledger.record(null);

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
    final refusal = WritePolicy.forQso(operation: await _operationFor(operationUuid), ourCall: operationUuid.isEmpty ? ourCall : '');
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
    final refusal = WritePolicy.forQso(operation: await _operationFor(stored.operationUuid), ourCall: stored.operationUuid.isEmpty ? stored.ourCall : '');
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
    final refs = [for (final ref in qso.refs) Map<String, dynamic>.from(ref)];
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
  Future<Qso> add(String operationUuid, Map<String, dynamic> qsoData, {List<SequenceDescriptor> serialSequences = const []}) async {
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
      _touch([operationUuid], [qso.uuid]);
    });
    onChange?.call();
    // Structured dev event — real contacts only, not timeline markers.
    if (!qso.isEvent) {
      DevLog.instance.log('qso', {'uuid': qso.uuid, 'op': operationUuid, 'call': (data['their'] as Map?)?['call'], 'band': data['band'], 'mode': data['mode']});
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
  Future<Qso> addEvent(String operationUuid, {required String kind, required int atMillis, Map<String, dynamic>? operation, String? description}) {
    return add(operationUuid, {
      'band': 'event',
      // Placeholder calls, the shape polo's own markers have always had
      // (`newEventQSO`: `our.call = 'EVENT'`, `their.call = KIND`). Not
      // decoration: polo's sync ingests every inbound row through
      // `qsoKey`, which destructures `our.call` and `their.call` and
      // throws on a row without them — and that throw escapes the whole
      // sync round, so a single marker from here stalled a polo device
      // forever, one page short of every contact behind it (HALO-609).
      // Nothing here reads them: `isEvent` is `band == 'event'`, and every
      // callsign query already excludes markers by that test.
      'our': {'call': 'EVENT'},
      'their': {'call': kind.toUpperCase()},
      'startAtMillis': atMillis,
      'event': {'event': kind, 'operation': ?operation, 'description': ?description},
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
  @override
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
      toInsert.add(
        Qso(
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
        ),
      );
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
        throw ArgumentError.value(qso.operationUuid, 'updates', 'QSO ${qso.uuid} belongs to a different operation than this batch');
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
    final touched = [for (final qso in toInsert) qso.uuid];
    // The operation each updated row is in NOW: one a sync pull moved since
    // the plan was built moves back here, and its log has to hear it ([update]).
    final leaving = <String>{};
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
          for (final qso in updates) qso.uuid: _restamped(Qso(uuid: qso.uuid, operationUuid: qso.operationUuid, data: {...qso.data, 'uuid': qso.uuid})),
        };
        // `batch.update` has no return value, unlike the row-by-row `.write()`
        // this replaces — so which uuids actually exist is checked up front,
        // inside the same transaction (so nothing else can change it
        // underneath this read). An update whose uuid is no longer in the
        // table affects no rows; counting it anyway would report an import as
        // complete while a record deleted since the plan was built silently
        // didn't land.
        //
        // Chunked at [inClauseChunkSize], the same as [historyForCalls] — a
        // caller that hands a large re-import's merges straight through
        // (`adif_import_flow.dart` does not chunk its own `writeBatch` call)
        // would otherwise build one `IN` clause with one bound variable per
        // update, and a big enough operation exceeds SQLite's limit on a
        // record count this method used to have no such ceiling on at all.
        final updateUuids = stampedByUuid.keys.toList();
        final existingUuids = <String>{};
        for (var i = 0; i < updateUuids.length; i += inClauseChunkSize) {
          final chunk = updateUuids.sublist(i, math.min(i + inClauseChunkSize, updateUuids.length));
          if (updateBases.isEmpty) {
            // No snapshots to reconcile against: the uuid projection is all
            // the check needs. Selecting full rows here would jsonDecode
            // every target's blob inline, mid-transaction — the same decode
            // [historyForCalls] routes through an isolate above 200 rows —
            // and a single corrupt blob would abort a batch whose UPDATE
            // would have overwritten it anyway.
            final rows =
                await (db.selectOnly(db.qsos)
                      ..addColumns([db.qsos.uuid, db.qsos.operation])
                      ..where(db.qsos.uuid.isIn(chunk)))
                    .map((row) => (uuid: row.read(db.qsos.uuid)!, operation: row.read(db.qsos.operation)!))
                    .get();
            for (final row in rows) {
              existingUuids.add(row.uuid);
              leaving.add(row.operation);
            }
            continue;
          }
          // Re-merge any target that moved past its plan-time snapshot —
          // see [updateBases]. Inside the same transaction as the write, so
          // the row read here is the row the batch below overwrites.
          final rows = await (db.select(db.qsos)..where((q) => q.uuid.isIn(chunk))).get();
          for (final row in rows) {
            existingUuids.add(row.uuid);
            leaving.add(row.operation);
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
            stampedByUuid[row.uuid] = _restamped(
              Qso(
                uuid: row.uuid,
                operationUuid: planned.operationUuid,
                data: mergeConcurrentEdit(base: base.data, current: current.data, edited: planned.data),
              ),
            );
          }
        }
        await db.batch((batch) {
          for (final uuid in existingUuids) {
            batch.update(db.qsos, _companionFor(stampedByUuid[uuid]!, 'qsos:writeBatch'), where: (q) => q.uuid.equals(uuid));
          }
        });
        written += existingUuids.length;
        touched.addAll(existingUuids);
      }
      if (refreshCounters) await refreshOperationCounters(operationUuid);
      // A batch is only issued for uuids that exist, so updates that all
      // missed add no statement — and a batch with none notifies nothing.
      if (touched.isNotEmpty) _touch({operationUuid, ...leaving}, touched);
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
      // Raw, decoded only against a snapshot. The operation is written from
      // the caller's copy, so an edit saved from a snapshot a sync pull has
      // since moved MOVES the row back, and the log it leaves has to hear it.
      final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(qso.uuid))).getSingleOrNull();
      if (basedOn != null && row != null) {
        final current = qsoFromRow(row);
        if (current.data['updatedAtMillis'] != basedOn.data['updatedAtMillis']) {
          stamped = _restamped(
            Qso(
              uuid: qso.uuid,
              operationUuid: qso.operationUuid,
              data: mergeConcurrentEdit(base: basedOn.data, current: current.data, edited: qso.data),
            ),
          );
        }
      }
      final rows = await (db.update(db.qsos)..where((q) => q.uuid.equals(stamped.uuid))).write(_companionFor(stamped, 'qsos:update'));
      await refreshOperationCounters(stamped.operationUuid);
      if (rows > 0) _touch({stamped.operationUuid, ?row?.operation}, [stamped.uuid]);
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
      final qso = Qso(uuid: row.uuid, operationUuid: row.operation, data: jsonDecode(row.data) as Map<String, dynamic>, deleted: row.deleted);
      if (qso.isEvent || qso.serialConflict || !request.includes(qso)) continue;
      if (request.serialOn(qso) != number) continue;
      await update(
        Qso(
          uuid: qso.uuid,
          operationUuid: qso.operationUuid,
          data: {...qso.data, Qso.serialConflictKey: true},
          deleted: qso.deleted,
          scoreCache: qso.scoreCache,
        ),
      );
      return;
    }
  }

  @override
  Future<void> softDelete(Qso qso) => _writeDeleted(qso, deleted: true);

  /// Restores a soft-deleted QSO. Pushing sends
  /// `deleted` only when true (see `SyncEngine._buildPayload`), so the
  /// restored record's payload simply omits the key.
  @override
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
      _touch([stamped.operationUuid], [stamped.uuid]);
      changed = true;
    });
    if (changed) onChange?.call();
  }

  /// The QSO-side half of `undeleteOperationWithQsos`: restores every
  /// contact of [operationUuid] tombstoned with [stamp] — the ones that went
  /// with the operation — under one new stamp, dirty again for the push.
  Future<void> undeleteStamped(String operationUuid, int stamp) => db.transaction(() async {
    final rows = await (db.select(db.qsos)..where((q) => q.operation.equals(operationUuid) & q.deleted.equals(true) & q.updatedAtMillis.equals(stamp))).get();
    final now = realNowMillis();
    for (final row in rows) {
      await (db.update(db.qsos)..where((q) => q.uuid.equals(row.uuid))).write(
        QsosCompanion(
          deleted: const Value(false),
          synced: const Value(false),
          // The column mirrors the data's own stamp — see [_restamped].
          data: Value(encodeQsoData({...qsoFromRow(row).data, 'updatedAtMillis': now}, 'qsos:undeleteForOperation')),
          updatedAtMillis: Value(now),
        ),
      );
    }
    await refreshOperationCounters(operationUuid);
    if (rows.isNotEmpty) _touch([operationUuid], [for (final row in rows) row.uuid]);
  });

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
    final rows = await (db.select(db.qsos)..where((q) => q.operation.equals('') & q.purged.equals(false))).get();
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
    final touched = <String>[];
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
        touched.add(uuid);
      }
      if (touched.isNotEmpty) _touch([''], touched);
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
      if (rows.isNotEmpty) _touch([operationUuid], [for (final row in rows) row.uuid]);
    });
    onChange?.call();
  }

  /// See `OperationsRepository.hardDeletePurged` — the QSO-side half, run
  /// after a purged operation's row has already been hard-deleted so an
  /// orphaned QSO never outlives its operation.
  Future<void> hardDeletePurgedForOperation(String operationUuid) => db.transaction(() async {
    final removed = await (db.delete(db.qsos)..where((q) => q.operation.equals(operationUuid) & q.purged.equals(true) & q.synced.equals(true))).go();
    if (removed > 0) _touchAllTombstones();
  });

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
  Future<void> hardDeleteAllForOperation(String operationUuid) => db.transaction(() async {
    final removed = await (db.delete(db.qsos)..where((q) => q.operation.equals(operationUuid))).go();
    if (removed > 0) _touchAll();
  });

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
  Future<int> hardDeletePurgedOrphans() => db.transaction(() async {
    final liveOperations = db.selectOnly(db.operations)..addColumns([db.operations.uuid]);
    final removed = await (db.delete(db.qsos)..where((q) => q.purged.equals(true) & q.synced.equals(true) & q.operation.isNotInQuery(liveOperations))).go();
    if (removed > 0) _touchAllTombstones();
    return removed;
  });

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

  /// The operation's log, oldest first, re-emitted on every change to it.
  ///
  /// Not a drift query stream: one of those re-runs its whole query on ANY
  /// write to the table, so a log of thousands of rows is re-read and decoded
  /// several times per logged contact (the insert, the lookup enrichment, the
  /// score cache, the sync mark) and once more for every write to some other
  /// operation. This reads the log once, then follows the table's update
  /// stream and consults [_ledger]: rows a write to this operation named are
  /// re-read by uuid and patched into place, a write naming only other
  /// operations emits nothing, and an update the ledger cannot account for —
  /// a writer outside this repository — reads the whole log again. Every
  /// emission is a new list; a consumer may keep the previous one.
  ///
  /// Broadcast, like the drift stream it stands in for, and shared like it:
  /// every listener of one log follows it through one follower, and a late
  /// listener is handed the list held so far.
  Stream<List<Qso>> watchForOperation(String operationUuid, {bool includeDeleted = false}) {
    final key = (operationUuid, includeDeleted);
    return Stream.multi((listener) {
      var follower = _followers[key];
      if (follower == null) {
        late final QsoLogFollower started;
        started = QsoLogFollower(
          db: db,
          ledger: _ledger,
          operationUuid: operationUuid,
          includeDeleted: includeDeleted,
          all: () => forOperation(operationUuid, includeDeleted: includeDeleted),
          onIdle: () => _followers.removeWhere((_, f) => identical(f, started)),
        );
        follower = started;
        // Kept only once it is running: a start that throws must not leave an
        // entry every later listener attaches to and hears nothing from.
        follower.start();
        _followers[key] = follower;
      }
      follower.attach(listener);
    }, isBroadcast: true);
  }

  /// The same rows as [watchForOperation], read once. For a one-off read
  /// (a command that needs the log as it stands), not `watchForOperation(...)
  /// .first`: a stream's first value never arrives inside a widget test's
  /// fake-async zone, so a caller awaiting it there hangs — and with another
  /// listener live, the first value is the shared follower's held list, which
  /// a write in flight may not have reached yet.
  Future<List<Qso>> forOperation(String operationUuid, {bool includeDeleted = false}) async {
    return qsosFromRows(await _forOperationQuery(operationUuid, includeDeleted: includeDeleted).get());
  }

  /// How [operationUuid]'s log — as [forOperation] reads it — has changed
  /// since [cursor], for a reader that keeps its own copy and cannot follow
  /// [watchForOperation]: the extension runtime, which would otherwise read
  /// the whole log on every `getQsos`.
  ///
  /// Answers from [_ledger], like the log stream ([rereadTouched]): every row
  /// a write named under this operation is read again by uuid, so one that
  /// left the log — deleted, purged, moved to another operation — is reported
  /// removed, and one that joined or changed is reported in
  /// [QsoLogChanges.qsos]. Reading again is idempotent, so a footprint whose
  /// write then failed costs a read and changes nothing. A score-cache write
  /// changes nothing such a reader holds, and is passed over.
  ///
  /// The whole log instead ([QsoLogChanges.reset]) when the changes cannot
  /// be told: no cursor, one this repository never issued, one older than
  /// the ledger reaches, a write that reached every row, or more rows than
  /// one read by uuid should name.
  ///
  /// The cursor is taken BEFORE the rows are read. A write landing between
  /// the two is then read again on the next call — never skipped, which is
  /// what taking it after would risk.
  Future<QsoLogChanges> changesSince(String operationUuid, String? cursor) async {
    final position = _ledger.positionOf(cursor);
    final next = _ledger.cursor;
    final footprints = position == null ? null : _ledger.since(position, contentOnly: true);
    // The rows and the count in one transaction, so they describe one moment:
    // a contact logged between the two would leave the count one ahead of
    // what the reader holds, and send it the whole log for nothing.
    final changes = await db.transaction(() async {
      final reread = footprints == null ? null : await rereadTouched(db, footprints, operationUuid, includeDeleted: false, limit: _changesLimit);
      if (reread == null) return null;
      return (reread: reread, count: await _liveCount(operationUuid));
    });
    if (changes == null) {
      final log = await forOperation(operationUuid);
      return QsoLogChanges(cursor: next, reset: true, qsos: log, count: log.length);
    }
    final kept = {for (final qso in changes.reread.fresh) qso.uuid};
    return QsoLogChanges(
      cursor: next,
      qsos: changes.reread.fresh,
      removed: [
        for (final uuid in changes.reread.touched)
          if (!kept.contains(uuid)) uuid,
      ],
      count: changes.count,
    );
  }

  /// How many rows [forOperation] would read, without reading them.
  Future<int> _liveCount(String operationUuid) async {
    final count = db.qsos.uuid.count();
    final query = db.selectOnly(db.qsos)
      ..addColumns([count])
      ..where(db.qsos.operation.equals(operationUuid) & db.qsos.deleted.equals(false));
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Rows one [changesSince] reads by uuid before reading the whole log is
  /// the better move. Higher than the log stream's limit: what a reset costs
  /// this reader is the whole log crossing into the extension runtime, far
  /// more than a longer read here — and still well under SQLite's
  /// bound-variable limit.
  static const _changesLimit = 500;

  /// Brings the operation's segment rows up to date with a local edit (see
  /// `OperationsRepository.onLocalSave`): the LATEST `start`/`break` row takes
  /// [override], so the current stretch follows the edit, and EVERY row that
  /// carries an override — the earlier segments and any `stop` — gets its
  /// description recomposed, so a change to how a stretch is worded (a
  /// reference renamed, a party naming its county) reaches rows already
  /// written. Only a row whose override or description actually changes is
  /// written: a restamp is a revision every other device receives, and a
  /// no-op one is churn on the sync. Returns whether any row was written.
  ///
  /// No segment rows at all — the common, unsegmented log — costs one query
  /// and no [describe] call; composing a description is an extension fan-out
  /// per row, which only a segmented log pays.
  ///
  /// [describe] is handed each row's kind and the override it will state.
  /// A null result means the description could not be composed in full. On
  /// the row whose override is CHANGING it CLEARS the stored one rather than
  /// keeping it: the old line describes a location or a reference set the
  /// row no longer states, and keeping it would leave the row reading "at
  /// FN20rm" beside an override that says FN31, and sync that contradiction
  /// to every device. On a row whose override stands, null keeps what the
  /// row has — a runtime that is down is no reason to blank a good line.
  Future<bool> restampSegments(
    String operationUuid,
    Map<String, dynamic> override, {
    Future<String?> Function(String kind, Map<String, dynamic> override)? describe,
  }) async {
    final events = await eventsForOperation(operationUuid);
    Qso? latest;
    for (final row in events) {
      if (eventKindOpensSegment(row.eventKind)) latest = row;
    }
    if (latest == null) return false;

    final rows = [
      for (final row in events)
        if ((row.event ?? const <String, dynamic>{})['operation'] is Map || row.uuid == latest.uuid) row,
    ];
    // Described in PARALLEL: each description is an extension fan-out with
    // its own timeout, and a save awaits this whole pass — a rover's dozen
    // segments must cost one hook latency, not twelve in a row.
    final descriptions = await Future.wait(
      rows.map((row) {
        final stored = (row.event?['operation'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        final rowOverride = row.uuid == latest!.uuid ? override : stored;
        return describe?.call(row.eventKind ?? 'break', rowOverride) ?? Future<String?>.value();
      }),
    );

    var written = false;
    for (final (i, row) in rows.indexed) {
      final event = row.event ?? const <String, dynamic>{};
      final stored = (event['operation'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final rowOverride = row.uuid == latest.uuid ? override : stored;
      final overrideChanged = jsonEncode(stored) != jsonEncode(rowOverride);
      final description = descriptions[i];
      final keepDescription = description == null && !overrideChanged;
      final descriptionChanged = !keepDescription && description != event['description'];
      if (!overrideChanged && !descriptionChanged) continue;
      await update(
        Qso(
          uuid: row.uuid,
          operationUuid: row.operationUuid,
          data: {
            ...row.data,
            'event': {...event, 'operation': rowOverride, if (!keepDescription) 'description': description}
              ..removeWhere((key, value) => key == 'description' && value == null),
          },
        ),
      );
      written = true;
    }
    return written;
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
  /// oldest first. What the segment writers and [restampSegments] read:
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
      ..where(db.qsos.operation.equals(operationUuid) & db.qsos.deleted.equals(false) & isContact);
    return (await query.getSingleOrNull())?.read(min);
  }

  SimpleSelectStatement<$QsosTable, QsoRow> _forOperationQuery(String operationUuid, {required bool includeDeleted}) {
    return db.select(db.qsos)
      ..where((q) => includeDeleted ? q.operation.equals(operationUuid) : q.operation.equals(operationUuid) & q.deleted.equals(false))
      ..orderBy([(q) => OrderingTerm(expression: q.startAtMillis)]);
  }

  /// See `OperationsRepository.markSynced` — only rows whose revision stamp
  /// still matches the sent copy are marked, so an edit made while the
  /// round's network call was in flight stays dirty and re-pushes.
  Future<void> markSynced(Iterable<Qso> sent) async {
    final list = sent.toList();
    if (list.isEmpty) return;
    await db.transaction(() async {
      var marked = 0;
      for (final q in list) {
        final stamp = q.updatedAtMillis;
        marked +=
            await (db.update(db.qsos)
                  ..where((row) => row.uuid.equals(q.uuid) & (stamp == null ? row.updatedAtMillis.isNull() : row.updatedAtMillis.equals(stamp))))
                .write(const QsosCompanion(synced: Value(true)));
      }
      // `synced` is a column [Qso] does not carry, so nothing a log stream
      // shows has changed: an empty footprint pairs with the table update
      // and no stream re-reads anything for it.
      if (marked > 0) _touch(const [], const []);
    });
  }

  /// Upserts QSOs received from the sync server and refreshes the counters
  /// of every operation they belong to. See `OperationsRepository.mergeFromSync`
  /// for the returned watermark's purpose.
  Future<SyncWatermark> mergeFromSync(List<Map<String, dynamic>> qsos) async {
    final watermark = SyncWatermark();
    final affectedOperations = <String>{};
    // Filed under EACH operation a row touches, `''` included: a loose contact
    // has no counters to refresh, but a stream of the loose log exists.
    final touched = <String, Set<String>>{};
    final incomingUuids = [for (final m in qsos) m['uuid']].whereType<String>().toList();
    await db.transaction(() async {
      final existingRows = incomingUuids.isEmpty ? const <QsoRow>[] : await (db.select(db.qsos)..where((q) => q.uuid.isIn(incomingUuids))).get();
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
            await (db.update(db.qsos)..where((q) => q.uuid.equals(uuid))).write(const QsosCompanion(deleted: Value(true)));
            (touched[existing.operation] ??= {}).add(uuid);
            // The contact leaves the operation's cached count, which is a
            // column no query recomputes on its own.
            if (existing.operation.isNotEmpty) affectedOperations.add(existing.operation);
          }
          continue;
        }

        final qso = Qso(uuid: uuid, operationUuid: operationUuid, data: data);

        await db
            .into(db.qsos)
            .insertOnConflictUpdate(
              _companionFor(qso, 'qsos:mergeFromSync').copyWith(synced: const Value(true), deleted: Value(deleted), purged: Value(purged)),
            );
        (touched[operationUuid] ??= {}).add(uuid);
        if (existing != null) (touched[existing.operation] ??= {}).add(uuid);
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
      if (touched.isNotEmpty) _touchRows(touched);
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
    final touched = <String, Set<String>>{};
    final incomingUuids = [for (final m in qsos) m['uuid']].whereType<String>().toList();
    await db.transaction(() async {
      final existingRows = incomingUuids.isEmpty ? const <QsoRow>[] : await (db.select(db.qsos)..where((q) => q.uuid.isIn(incomingUuids))).get();
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
        await db.into(db.qsos).insertOnConflictUpdate(_companionFor(qso, 'qsos:mergeFromPeer').copyWith(deleted: Value(deleted), purged: Value(purged)));
        (touched[operationUuid] ??= {}).add(uuid);
        affectedOperations.add(operationUuid);
        // The log the row leaves when a peer moved it has to drop the row.
        if (existing != null) (touched[existing.operation] ??= {}).add(uuid);
      }
      for (final operationUuid in affectedOperations) {
        await refreshOperationCounters(operationUuid);
      }
      if (touched.isNotEmpty) _touchRows(touched);
    });
    // A peer's QSO may carry a serial this device's allocator has never seen.
    sequences?.invalidate();
    onChange?.call();
  }

  /// See `OperationsRepository.resetSyncedStatus`.
  Future<void> resetSyncedStatus() => db.transaction(() async {
    final rows = await db.update(db.qsos).write(const QsosCompanion(synced: Value(false)));
    // See [markSynced]: `synced` is invisible to a log stream.
    if (rows > 0) _touch(const [], const []);
  });

  /// See `OperationsRepository.backupAndClearAll`.
  Future<void> backupAndClearAll(String backupId) async {
    final now = nowMillis();
    await db.transaction(() async {
      final rows = await db.select(db.qsos).get();
      for (final row in rows) {
        await db
            .into(db.qsosBackup)
            .insert(
              QsosBackupCompanion.insert(
                backupId: backupId,
                backupAtMillis: now,
                uuid: row.uuid,
                operation: row.operation,
                data: row.data,
                deleted: Value(row.deleted),
              ),
            );
      }
      await db.delete(db.qsos).go();
      if (rows.isNotEmpty) _touchAll();
    });
    sequences?.invalidate();
  }

  /// Batch-writes cached scoring results, one row update per QSO but all in
  /// a single transaction — the counterpart to the `scoring` hook's single
  /// coarse batched call (DESIGN.md §4). Score cache is locally derived, not
  /// synced content, so this never touches `synced` or fires [onChange];
  /// `watchForOperation` streams pick up the change on their own since it's
  /// still a write to the `qsos` table. [operationUuid] is the operation
  /// every uuid belongs to — a scoring pass is one operation's — and is what
  /// lets other operations' streams ignore the write.
  Future<void> updateScoreCache(String operationUuid, Map<String, String> scoreCacheByUuid) async {
    if (scoreCacheByUuid.isEmpty) return;
    await db.transaction(() async {
      await db.batch((batch) {
        for (final entry in scoreCacheByUuid.entries) {
          batch.update(db.qsos, QsosCompanion(scoreCache: Value(entry.value)), where: (q) => q.uuid.equals(entry.key));
        }
      });
      // The ledger, not [changes]: a verdict is derived, and a listener
      // re-deriving from the contacts has nothing new to read.
      _ledger.record({operationUuid: scoreCacheByUuid.keys.toSet()}, cacheOnly: true);
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
    // `logs/logs_adif_drop.dart` is the one caller that has never had an outer
    // transaction of its own to rely on for that.
    await db.transaction(() async {
      final count = db.qsos.uuid.count();
      final minStart = db.qsos.startAtMillis.min();
      final maxStart = db.qsos.startAtMillis.max();
      // Event pseudo-QSOs (start/break/end markers) share the qsos table but
      // aren't real contacts — exclude them from the count and time range.
      final query = db.selectOnly(db.qsos)
        ..addColumns([count, minStart, maxStart])
        ..where(db.qsos.operation.equals(operationUuid) & db.qsos.deleted.equals(false) & isContact);
      final row = await query.getSingle();

      await (db.update(db.operations)..where((op) => op.uuid.equals(operationUuid))).write(
        OperationsCompanion(qsoCount: Value(row.read(count) ?? 0), startAtMillisMin: Value(row.read(minStart)), startAtMillisMax: Value(row.read(maxStart))),
      );
    });
  }
}
