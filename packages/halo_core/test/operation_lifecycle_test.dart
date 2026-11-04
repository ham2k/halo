// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operation lifecycle (docs/design/data-model.md §The Log Data): which
// state an operation holds, and what moves it. Both halves are load-bearing for uploads —
// `completed` vs `paused` is what tells an uploader whether a log is safe to
// send, and `processed → completed` is the only staleness signal it gets
// without hashing anything — so the rules are pinned here rather than left to
// be inferred from the sweep's behaviour.

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

const _minute = 60 * 1000;
const _hour = 3600 * 1000;
const _day = 24 * _hour;

Operation _op({String? status, int? lastQsoAt, int? statusAt, int? processedAt, int qsoCount = 0, List<Map<String, dynamic>> refs = const []}) => Operation(
  uuid: 'op',
  qsoCount: qsoCount,
  startAtMillisMax: lastQsoAt,
  data: {'stationCall': 'N0DEV', 'createdAtMillis': 0, 'status': ?status, 'statusAtMillis': ?statusAt, 'processedAtMillis': ?processedAt, 'refs': refs},
);

extension on Operation {
  Operation withCreatedAt(int millis) =>
      Operation(uuid: uuid, qsoCount: qsoCount, startAtMillisMax: startAtMillisMax, data: {...data, 'createdAtMillis': millis});
}

void main() {
  group('sweep rules', () {
    const now = 100 * _day;

    test('an active operation pauses only after a long silence', () {
      final quiet = _op(status: OperationStatus.active, qsoCount: 5, lastQsoAt: now - 13 * _hour);
      final busy = _op(status: OperationStatus.active, qsoCount: 5, lastQsoAt: now - 11 * _hour);
      expect(sweptStatusFor(quiet, nowMillis: now), OperationStatus.paused);
      expect(sweptStatusFor(busy, nowMillis: now), isNull);
    });

    test('a freshly imported historical log is not active', () {
      // Created NOW, contacts from years ago — an ADIF import. Folding the
      // creation date into "last sign of life" would call it active for the
      // next twelve hours.
      final imported = _op(status: OperationStatus.active, qsoCount: 400, lastQsoAt: now - 400 * _day).withCreatedAt(now);
      expect(sweptStatusFor(imported, nowMillis: now), OperationStatus.paused);
    });

    test('an operation started but not yet logged into ages from its start', () {
      // `startAtMillisMax` is NULL for a QSO-less operation, and a comparison
      // against NULL is neither true nor false — without the fallback this
      // operation would sit on `active` for good.
      final started = _op(status: OperationStatus.active, statusAt: now - 13 * _hour);
      expect(sweptStatusFor(started, nowMillis: now), OperationStatus.paused);
    });

    test('nothing infers completed', () {
      // The whole reason the timeout lands on `paused`: "I am done" is a
      // claim about intent that no silence can make on the operator's behalf,
      // and an uploader reads `completed` as "safe to upload".
      for (var days = 1; days <= 60; days++) {
        final stale = _op(status: OperationStatus.active, qsoCount: 5, lastQsoAt: now - days * _day);
        expect(sweptStatusFor(stale, nowMillis: now), OperationStatus.paused);
      }
      final paused = _op(status: OperationStatus.paused, qsoCount: 5, lastQsoAt: now - 60 * _day);
      expect(sweptStatusFor(paused, nowMillis: now), isNull);
    });

    test('a processed operation archives a week later', () {
      expect(
        sweptStatusFor(
          _op(status: OperationStatus.processed, processedAt: now - 8 * _day),
          nowMillis: now,
        ),
        OperationStatus.archived,
      );
      expect(
        sweptStatusFor(
          _op(status: OperationStatus.processed, processedAt: now - 6 * _day),
          nowMillis: now,
        ),
        isNull,
      );
      // No stamp at all — a record that reached `processed` through some
      // older path — must not archive on a NULL comparison reading as true.
      expect(sweptStatusFor(_op(status: OperationStatus.processed), nowMillis: now), isNull);
    });

    test('an absent status is derived, never an error', () {
      // Two populations never carry one: everything logged before the
      // lifecycle existed, and everything app-polo writes, forever.
      expect(sweptStatusFor(_op(), nowMillis: now), OperationStatus.fresh);
      expect(
        sweptStatusFor(
          _op(
            refs: [
              {'type': 'pota', 'ref': 'US-0001'},
            ],
          ),
          nowMillis: now,
        ),
        OperationStatus.ready,
      );
      expect(sweptStatusFor(_op(qsoCount: 3, lastQsoAt: now - _hour), nowMillis: now), OperationStatus.active);
      expect(sweptStatusFor(_op(qsoCount: 3, lastQsoAt: now - 30 * _day), nowMillis: now), OperationStatus.paused);
    });

    test('new and ready with contacts in them are derived again', () {
      // Neither state is reached by logging, so contacts in one mean the
      // status was decided without them — a bulk import that never went
      // through the per-contact path, or a derivation made while the
      // operation had synced ahead of its own QSOs. Both are otherwise
      // terminal: nothing else in the rules would ever move the operation
      // again, and a 3,000-contact log would sit at `new` for good.
      final imported = _op(status: OperationStatus.fresh, qsoCount: 3000, lastQsoAt: now - _hour);
      expect(sweptStatusFor(imported, nowMillis: now), OperationStatus.active);
      final old = _op(status: OperationStatus.ready, qsoCount: 40, lastQsoAt: now - 30 * _day);
      expect(sweptStatusFor(old, nowMillis: now), OperationStatus.paused);
      // An empty one is exactly where it belongs and must not churn.
      expect(sweptStatusFor(_op(status: OperationStatus.ready), nowMillis: now), isNull);
    });

    test('a setup stamp is no sign of life when the status is derived again', () {
      // A `ready` stamp records when Setup was accepted — today, for a log
      // imported today — and counted as activity it would call last year's
      // contacts a log being written.
      final imported = _op(status: OperationStatus.ready, qsoCount: 40, lastQsoAt: now - 30 * _day, statusAt: now);
      expect(sweptStatusFor(imported, nowMillis: now), OperationStatus.paused);
    });

    test('a status this build has never heard of is left alone', () {
      // Absent and unrecognised are different: a state a newer build wrote is
      // a decision this one cannot evaluate, and deriving over the top of it
      // would undo that decision on every five-minute tick.
      expect(sweptStatusFor(_op(status: 'submitted', qsoCount: 3, lastQsoAt: 0), nowMillis: now), isNull);
      expect(statusIsKnown('submitted'), isFalse);
    });
  });

  group('the sweep', () {
    late HaLoDatabase db;
    late OperationsRepository operations;
    late QsosRepository qsos;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      operations = OperationsRepository(db);
      qsos = QsosRepository(db);
    });

    tearDown(() async => db.close());

    /// An operation last touched [agoMillis] ago: one contact then, and the
    /// status stamped then too, which is what `setStatus` would have left
    /// behind at the time. Written through `saveData` as `setStatus` writes,
    /// so the mirrored columns come out of the same path production uses.
    Future<Operation> seed({required int agoMillis, String? status}) async {
      final op = await operations.create(stationCall: 'N0DEV');
      await qsos.add(op.uuid, {
        'startAtMillis': nowMillis() - agoMillis,
        'band': '20m',
        'mode': 'CW',
        'their': {'call': 'W1AW'},
      });
      await operations.saveData(
        Operation(uuid: op.uuid, data: {...op.data, 'status': ?status, 'statusAtMillis': nowMillis() - agoMillis}),
        lifecycleOnly: true,
      );
      return (await operations.get(op.uuid))!;
    }

    OperationLifecycleSweeper sweeper() => OperationLifecycleSweeper(operations: operations);

    test('the status column follows the blob, so the sweep can select on it', () async {
      // The candidate query reads the COLUMN while every rule reads the blob.
      // A write path that updates one and not the other gives a sweep that
      // never sees the operation it is meant to fix.
      final op = await seed(agoMillis: _hour, status: OperationStatus.processed);
      final row = await (db.select(db.operations)..where((o) => o.uuid.equals(op.uuid))).getSingle();
      expect(row.status, OperationStatus.processed);
      expect(await operations.lifecycleSweepCandidates(), [op.uuid]);
    });

    test('an operation with a long silence is paused', () async {
      final op = await seed(agoMillis: 20 * _hour, status: OperationStatus.active);
      expect(await sweeper().runOnce(), 1);
      expect((await operations.get(op.uuid))!.status, OperationStatus.paused);
    });

    test('it iterates to a fixed point rather than taking one step', () async {
      // An app closed for a fortnight has operations that crossed several
      // thresholds at once. Deriving `processed` and stopping would leave it
      // a state short for another five minutes — and the same one step short
      // on every tick after that if the derivation is what moves it.
      final op = await operations.create(stationCall: 'N0DEV');
      await operations.saveData(
        Operation(uuid: op.uuid, data: {...op.data, 'status': OperationStatus.processed, 'processedAtMillis': nowMillis() - 30 * _day}),
        lifecycleOnly: true,
      );
      expect(await sweeper().runOnce(), 1);
      expect((await operations.get(op.uuid))!.status, OperationStatus.archived);
    });

    test('each operation it moves costs one write, not a second read to confirm it is done', () async {
      // The first pass after an upgrade moves every operation on the device,
      // in sequence, while the operator is opening a log. A read per step
      // doubles that for nothing.
      for (var i = 0; i < 3; i++) {
        await seed(agoMillis: 20 * _hour, status: OperationStatus.active);
      }
      final counting = _CountingOperations(db);
      expect(await OperationLifecycleSweeper(operations: counting).runOnce(), 3);
      expect(counting.infers, 3);
    });

    test('an explicit restart holds against an old log', () async {
      // An operator who reopens a two-week-old log to add the contacts they
      // wrote on paper must not have it paused out from under them on the
      // next tick. The last CONTACT is ancient; entering `active` is not.
      final op = await seed(agoMillis: 14 * _day, status: OperationStatus.paused);
      await operations.setStatus(op.uuid, OperationStatus.active);
      expect(await sweeper().runOnce(), 0);
      expect((await operations.get(op.uuid))!.status, OperationStatus.active);
    });

    test('an operation filled by a bulk import is picked up', () async {
      // The whole bulk path — ADIF import, paste, mass edits — writes through
      // `writeBatch`, which does not touch contacts one at a time. Without
      // its own hook the operation stays at `new` with the import inside it,
      // and `new` is not a state anything else moves.
      final op = await operations.create(stationCall: 'N0DEV');
      await qsos.writeBatch(
        operationUuid: op.uuid,
        inserts: [
          for (var i = 0; i < 5; i++)
            {
              'startAtMillis': nowMillis() - _hour,
              'band': '20m',
              'mode': 'CW',
              'their': {'call': 'W1AW'},
            },
        ],
      );
      expect((await operations.get(op.uuid))!.status, OperationStatus.fresh);
      expect(await sweeper().runOnce(), 1);
      expect((await operations.get(op.uuid))!.status, OperationStatus.active);
    });

    test('a derived state is dated from the last contact, not from the pass', () async {
      // Stamped by the pass, a log last written eleven hours ago would read
      // as live for another twelve — the panel offering a live row over it
      // for a day — instead of pausing within the hour.
      final op = await operations.create(stationCall: 'N0DEV');
      final contactAt = nowMillis() - 11 * _hour;
      await qsos.writeBatch(
        operationUuid: op.uuid,
        inserts: [
          {
            'startAtMillis': contactAt,
            'band': '20m',
            'mode': 'CW',
            'their': {'call': 'W1AW'},
          },
        ],
      );
      await sweeper().runOnce();
      final derived = (await operations.get(op.uuid))!;
      expect(derived.status, OperationStatus.active);
      expect(derived.statusAtMillis, contactAt);
      expect(sweptStatusFor(derived, nowMillis: nowMillis() + 2 * _hour), OperationStatus.paused);
    });

    test('an explicit restart is stamped even when the state does not move', () async {
      // The panel calls an operation quiet long before the record calls it
      // paused, so RESTART routinely lands on a record that already says
      // `active`. If that writes nothing, the stamp never moves, the panel
      // measures the same silence a moment later, and the one control the
      // operator has does nothing at all — while the entry row stays locked.
      final op = await seed(agoMillis: 40 * _minute, status: OperationStatus.active);
      final before = (await operations.get(op.uuid))!.statusAtMillis;

      final result = await operations.setStatus(op.uuid, OperationStatus.active, evenIfUnchanged: true);

      expect(result, isNotNull);
      expect((await operations.get(op.uuid))!.statusAtMillis, greaterThan(before!));
      // And the reopened operation is no longer silent by the sweep's rule
      // either, so the next pass leaves it alone.
      expect(await sweeper().runOnce(), 0);
    });

    test('an inferred transition still writes nothing when nothing moves', () async {
      // The escape above is for explicit transitions ONLY. Left on by
      // default, every settled operation would be restamped and re-pushed on
      // every five-minute tick, for the life of the log.
      final op = await seed(agoMillis: 40 * _minute, status: OperationStatus.active);
      final before = (await operations.get(op.uuid))!.statusAtMillis;
      expect(await operations.setStatus(op.uuid, OperationStatus.active), isNull);
      expect((await operations.get(op.uuid))!.statusAtMillis, before);
    });

    test('a second pass over settled operations changes nothing', () async {
      // Every device sweeps, so a pass that kept finding work would push a
      // sync revision every five minutes for the life of the log.
      await seed(agoMillis: 20 * _hour, status: OperationStatus.active);
      final pass = sweeper();
      expect(await pass.runOnce(), 1);
      expect(await pass.runOnce(), 0);
    });

    test('what a pass infers stays on this device until the operation is next saved', () async {
      // Sent, an inferred status carries this device's whole copy out as the
      // newest revision: from a device behind on sync, or one first seeing a
      // record app-polo stripped of its status, that reverts every edit made
      // elsewhere — an operator's Finish among them.
      final op = await seed(agoMillis: 20 * _hour, status: OperationStatus.active);
      await (db.update(db.operations)..where((o) => o.uuid.equals(op.uuid))).write(const OperationsCompanion(synced: Value(true)));
      final before = await (db.select(db.operations)..where((o) => o.uuid.equals(op.uuid))).getSingle();

      expect(await sweeper().runOnce(), 1);
      final swept = await (db.select(db.operations)..where((o) => o.uuid.equals(op.uuid))).getSingle();
      expect(swept.status, OperationStatus.paused);
      expect(swept.synced, isTrue);
      expect(swept.updatedAtMillis, before.updatedAtMillis);

      await operations.saveData(Operation(uuid: op.uuid, data: {...op.data, 'grid': 'FN31'}));
      final saved = await (db.select(db.operations)..where((o) => o.uuid.equals(op.uuid))).getSingle();
      expect(saved.status, OperationStatus.paused, reason: 'the next save carries it out');
      expect(saved.synced, isFalse);
    });

    test('an inferred move is decided from the operation as it stands at the write', () async {
      // A pass working through a backlog reaches each operation a while
      // after it listed them. Decided from an earlier read, it pauses a log
      // the operator finished in the meantime.
      final op = await seed(agoMillis: 20 * _hour, status: OperationStatus.active);
      await Future.wait([
        operations.inferStatus(op.uuid, (stored) => stored.status == OperationStatus.active ? (status: OperationStatus.paused, atMillis: null) : null),
        operations.setStatus(op.uuid, OperationStatus.completed),
      ]);
      expect((await operations.get(op.uuid))!.status, OperationStatus.completed);
    });

    test('a pass that fails is handed on, not thrown', () async {
      // The pass is unawaited: a throw out of it is an unhandled error, every
      // five minutes, and what that deserves is the app's reporting's call.
      final reported = Completer<String?>();
      final failing = OperationLifecycleSweeper(operations: _FailingOperations(db), onError: (e, st, {context}) => reported.complete(context));
      addTearDown(failing.stop);
      failing.start();
      expect(await reported.future.timeout(const Duration(seconds: 5)), 'lifecycle:sweep');
    });

    test('an operation that will not sweep is reported once, and the rest of the pass goes on', () async {
      // Stopping at the bad row leaves every candidate after it unswept for
      // good; reporting it on every pass sends the same failure up every
      // five minutes, each as a new error.
      final broken = await operations.create(stationCall: 'N0DEV');
      await (db.update(
        db.operations,
      )..where((o) => o.uuid.equals(broken.uuid))).write(const OperationsCompanion(data: Value('not json at all'), status: Value(null)));
      final quiet = await seed(agoMillis: 20 * _hour, status: OperationStatus.active);
      final contexts = <String?>[];
      final sweeper = OperationLifecycleSweeper(operations: operations, onError: (e, st, {context}) => contexts.add(context));

      expect(await sweeper.runOnce(), 1);
      await sweeper.runOnce();

      expect((await operations.get(quiet.uuid))!.status, OperationStatus.paused);
      expect(contexts, ['lifecycle:sweep:operation']);
    });

    test('a status the blob carries and the column never received is mirrored', () async {
      // Synced in while this device ran a build that kept the key without
      // the column. Nothing is due to move, and left unmirrored, an edit in
      // the sent log finds no `processed` to revert and it archives untouched.
      final op = await seed(agoMillis: _hour, status: OperationStatus.processed);
      await (db.update(db.operations)..where((o) => o.uuid.equals(op.uuid))).write(const OperationsCompanion(status: Value(null)));

      expect(await sweeper().runOnce(), 0);

      final row = await (db.select(db.operations)..where((o) => o.uuid.equals(op.uuid))).getSingle();
      expect(row.status, OperationStatus.processed);
    });
  });

  group('the log moving under the status', () {
    late HaLoDatabase db;
    late OperationsRepository operations;
    late QsosRepository qsos;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      operations = OperationsRepository(db);
      qsos = QsosRepository(
        db,
        onLocalContact: (uuid, {required isNewContact, int? atMillis, bool bulk = false}) =>
            operations.followContact(uuid, isNewContact: isNewContact, atMillis: atMillis, bulk: bulk),
      );
    });

    tearDown(() async => db.close());

    Future<Operation> seedAt(String status) async {
      final op = await operations.create(stationCall: 'N0DEV');
      await operations.setStatus(op.uuid, status);
      return (await operations.get(op.uuid))!;
    }

    Future<Qso> logContact(String operationUuid) => qsos.add(operationUuid, {
      'band': '20m',
      'mode': 'CW',
      'their': {'call': 'W1AW'},
    });

    test('a new contact reopens a paused operation', () async {
      final op = await seedAt(OperationStatus.paused);
      await logContact(op.uuid);
      expect((await operations.get(op.uuid))!.status, OperationStatus.active);
    });

    test('an edit to a processed operation reverts it, and no further', () async {
      // This IS the uploaders' staleness notification: `processed → completed`,
      // at operation granularity, with nothing computed. Reverting to
      // `active` instead would claim the operator is back at the radio.
      final op = await seedAt(OperationStatus.active);
      final qso = await logContact(op.uuid);
      await operations.setStatus(op.uuid, OperationStatus.processed);
      final processed = (await operations.get(op.uuid))!;

      await qsos.update(
        Qso(
          uuid: qso.uuid,
          operationUuid: op.uuid,
          data: {
            ...qso.data,
            'their': {'call': 'W1AW/P'},
          },
        ),
      );

      final reverted = (await operations.get(op.uuid))!;
      expect(reverted.status, OperationStatus.completed);
      // The stamp records when the operator declared the log done. Moved to
      // now, it would compare equal to the edited contact's own revision and
      // hide the very edit that caused the revert.
      expect(reverted.statusAtMillis, processed.statusAtMillis);
      // What has been sent stays answerable after the log changes.
      expect(reverted.processedAtMillis, processed.processedAtMillis);
    });

    test('deleting a contact reverts it too', () async {
      final op = await seedAt(OperationStatus.active);
      final qso = await logContact(op.uuid);
      await operations.setStatus(op.uuid, OperationStatus.processed);
      await qsos.softDelete(qso);
      expect((await operations.get(op.uuid))!.status, OperationStatus.completed);
    });

    test('reopening is not an edit: an edit never drags an active log anywhere', () async {
      final op = await seedAt(OperationStatus.active);
      final qso = await logContact(op.uuid);
      await qsos.update(Qso(uuid: qso.uuid, operationUuid: op.uuid, data: {...qso.data, 'notes': 'fixed'}));
      expect((await operations.get(op.uuid))!.status, OperationStatus.active);
    });

    test('an explicit pause is not a segment boundary', () async {
      // Pausing writes a `pause` row. Were it a boundary, every stretch after
      // a lunch break would resolve to the base operation instead of whatever
      // the log was actually running under.
      final op = await seedAt(OperationStatus.active);
      await qsos.addEvent(op.uuid, kind: 'pause', atMillis: nowMillis(), operation: {'grid': 'FN20'});
      final rows = await qsos.forOperation(op.uuid);
      expect(SegmentedOperation.from(operation: op.data, qsos: rows).isSegmented, isFalse);
    });

    test('a bulk import into a closed log edits it, and reopens nothing', () async {
      // An import is not the operator at the radio. Read as one, a re-import
      // into a finished log would undo the finish, and the sweep would then
      // pause what the operator had declared done.
      Future<String?> afterImport(String status) async {
        final op = await seedAt(status);
        await qsos.writeBatch(
          operationUuid: op.uuid,
          inserts: [
            {
              'band': '20m',
              'mode': 'CW',
              'their': {'call': 'W1AW'},
            },
          ],
        );
        return (await operations.get(op.uuid))!.status;
      }

      expect(await afterImport(OperationStatus.completed), OperationStatus.completed);
      expect(await afterImport(OperationStatus.paused), OperationStatus.paused);
      // Still the staleness signal: what was sent no longer matches the log.
      expect(await afterImport(OperationStatus.processed), OperationStatus.completed);
    });

    test('logging an old contact reopens the log as of now, not as of the contact', () async {
      // The operator entering this morning's paper log is at the radio now.
      // Dated from the contact, the panel would read the log as hours quiet
      // and lock the row between entries, and the sweep would pause it under
      // them.
      final op = await seedAt(OperationStatus.paused);
      final before = nowMillis();
      await qsos.add(op.uuid, {
        'startAtMillis': before - 5 * _hour,
        'band': '20m',
        'mode': 'CW',
        'their': {'call': 'W1AW'},
      });
      final reopened = (await operations.get(op.uuid))!;
      expect(reopened.status, OperationStatus.active);
      expect(reopened.statusAtMillis, greaterThanOrEqualTo(before));
    });

    test('a save from an older copy keeps the status moved since', () async {
      // The Location screen and the Setup sheet hold their copy while the
      // operator fills them in. A Finish synced in meanwhile, written back
      // over with the copy's `active`, would reopen a log nobody reopened.
      final copy = await seedAt(OperationStatus.active);
      await operations.setStatus(copy.uuid, OperationStatus.completed);
      final finished = (await operations.get(copy.uuid))!;
      await operations.saveData(Operation(uuid: copy.uuid, data: {...copy.data, 'grid': 'FN31'}));
      final saved = (await operations.get(copy.uuid))!;
      expect(saved.status, OperationStatus.completed);
      expect(saved.statusAtMillis, finished.statusAtMillis);
      expect(saved.data['grid'], 'FN31');
    });

    test('accepting Setup on a copy read before a contact leaves the log active', () async {
      // Judged on the copy, a sheet opened on a `new` log would walk it
      // back to `ready` and offer START over a log with contacts in it.
      final copy = await seedAt(OperationStatus.fresh);
      await logContact(copy.uuid);
      await operations.saveAcceptedSetup(copy);
      expect((await operations.get(copy.uuid))!.status, OperationStatus.active);
    });

    test('a contact into an active log writes nothing to the operation', () async {
      // Old or live: a write per contact moves the operation's revision,
      // which syncs it and costs every contact a full rescore.
      final op = await seedAt(OperationStatus.active);
      final stamped = (await operations.get(op.uuid))!.updatedAtMillis;
      await qsos.add(op.uuid, {
        'startAtMillis': nowMillis() - 5 * _hour,
        'band': '20m',
        'mode': 'CW',
        'their': {'call': 'W1AW'},
      });
      expect((await operations.get(op.uuid))!.updatedAtMillis, stamped);
    });

    test('an imported log is active as of its newest contact, not as of now', () async {
      // An ADIF import of last year's log comes through the same "new
      // contact" path a live QSO does. Stamped `now`, the operation would sit
      // `active` for the next twelve hours — the sweep measures silence from
      // the later of the last contact and the status stamp, so a fresh stamp
      // makes a finished log look like one being written. Stamped from the
      // newest contact instead, the very next sweep pauses it.
      final op = await seedAt(OperationStatus.fresh);
      final lastImported = nowMillis() - 300 * _day;
      await qsos.writeBatch(
        operationUuid: op.uuid,
        inserts: [
          for (var i = 0; i < 3; i++)
            {
              'startAtMillis': lastImported - i * _hour,
              'band': '20m',
              'mode': 'CW',
              'their': {'call': 'W1AW'},
            },
        ],
      );

      final imported = (await operations.get(op.uuid))!;
      expect(imported.status, OperationStatus.active);
      expect(imported.statusAtMillis, lastImported);
      expect(sweptStatusFor(imported, nowMillis: nowMillis()), OperationStatus.paused);
    });

    test('a chunked import stamps from the chunk, not the counters', () async {
      // A large import passes `refreshCounters: false` per chunk and refreshes
      // once at the end, so while the first chunks land the operation's
      // `startAtMillisMax` still holds whatever it held before the import.
      // Reading the COLUMN there would stamp a year-old log as active right
      // now — the very thing the timestamp is threaded through for.
      final op = await seedAt(OperationStatus.fresh);
      final lastImported = nowMillis() - 300 * _day;
      await qsos.writeBatch(
        operationUuid: op.uuid,
        refreshCounters: false,
        inserts: [
          for (var i = 0; i < 3; i++)
            {
              'startAtMillis': lastImported - i * _hour,
              'band': '20m',
              'mode': 'CW',
              'their': {'call': 'W1AW'},
            },
        ],
      );

      final imported = (await operations.get(op.uuid))!;
      expect(imported.status, OperationStatus.active);
      expect(imported.statusAtMillis, lastImported);
    });

    test('a batch of event rows moves nothing', () async {
      // `onLocalContact`'s contract excludes event rows at every call site,
      // and the bulk path has to keep it: a batch of segment markers changes
      // no contact, so it owes a processed operation no correction.
      final op = await seedAt(OperationStatus.active);
      await logContact(op.uuid);
      await operations.setStatus(op.uuid, OperationStatus.processed);
      await qsos.writeBatch(
        operationUuid: op.uuid,
        inserts: [
          {
            'startAtMillis': nowMillis(),
            'band': 'event',
            'event': {'event': 'break'},
          },
        ],
      );
      expect((await operations.get(op.uuid))!.status, OperationStatus.processed);
    });

    test('a live contact is still stamped as it is logged', () async {
      // The counterpart: an ordinary QSO carries no `startAtMillis` of its
      // own until `add` stamps it now, so the same rule has to leave a log
      // being written looking live.
      final op = await seedAt(OperationStatus.paused);
      await logContact(op.uuid);
      final live = (await operations.get(op.uuid))!;
      expect(live.status, OperationStatus.active);
      expect(sweptStatusFor(live, nowMillis: nowMillis()), isNull);
    });

    test('a bulk EDIT over a processed operation reverts it', () async {
      // A mass edit is the likeliest thing there is to invalidate an upload,
      // and it never goes near the per-contact path.
      final op = await seedAt(OperationStatus.active);
      final qso = await logContact(op.uuid);
      await operations.setStatus(op.uuid, OperationStatus.processed);
      await qsos.writeBatch(
        operationUuid: op.uuid,
        updates: [
          Qso(uuid: qso.uuid, operationUuid: op.uuid, data: {...qso.data, 'notes': 'corrected'}),
        ],
      );
      expect((await operations.get(op.uuid))!.status, OperationStatus.completed);
    });

    test('a background enrichment is not an edit', () async {
      // The lookup queue folds a QRZ result into `their.guess` with nobody
      // watching. Reverting on that would have a background service
      // un-archive logs and push sync revisions the operator cannot account
      // for. Accepted cost: an enrichment landing after an upload does make
      // the ADIF stale, and only the per-QSO hash catches it.
      final op = await seedAt(OperationStatus.active);
      final qso = await logContact(op.uuid);
      await operations.setStatus(op.uuid, OperationStatus.processed);
      await qsos.update(
        Qso(
          uuid: qso.uuid,
          operationUuid: op.uuid,
          data: {
            ...qso.data,
            'their': {
              'call': 'W1AW',
              'guess': {'name': 'Hiram'},
            },
          },
        ),
        operatorEdit: false,
      );
      expect((await operations.get(op.uuid))!.status, OperationStatus.processed);
    });

    test('an event row is not a contact and moves nothing', () async {
      // The lifecycle's own transitions are written AS event rows, so feeding
      // them back through this hook would have each transition fight itself.
      final op = await seedAt(OperationStatus.completed);
      await qsos.addEvent(op.uuid, kind: 'break', atMillis: nowMillis());
      expect((await operations.get(op.uuid))!.status, OperationStatus.completed);
    });

    test('a serial conflict another position reports is not an edit', () async {
      // Written back as an operator edit, the report walks a sent log back
      // to `completed` — a revision nobody at this position made.
      const serial = SequenceDescriptor(refType: 'cqwpx', field: 'serial', key: 'cqwpx/serial');
      final numbered = QsosRepository(
        db,
        sequences: SequencesRepository(db),
        onLocalContact: (uuid, {required isNewContact, int? atMillis, bool bulk = false}) =>
            operations.followContact(uuid, isNewContact: isNewContact, atMillis: atMillis, bulk: bulk),
      );
      final op = await seedAt(OperationStatus.active);
      final logged = await numbered.add(
        op.uuid,
        {
          'band': '20m',
          'mode': 'CW',
          'their': {'call': 'W1AW'},
        },
        serialSequences: [serial],
      );
      await operations.setStatus(op.uuid, OperationStatus.processed);
      await numbered.markSerialConflict(op.uuid, serial.requestFor(logged), 1);
      expect((await numbered.get(logged.uuid))!.serialConflict, isTrue, reason: 'the report itself lands');
      expect((await operations.get(op.uuid))!.status, OperationStatus.processed);
    });

    test('a status this build does not know survives a contact', () async {
      // A newer build's status means something this one cannot evaluate; the
      // sweep leaves it alone, and a contact replacing it would undo that
      // build's decision on every device.
      final op = await operations.create(stationCall: 'N0DEV');
      await operations.saveData(Operation(uuid: op.uuid, data: {...op.data, 'status': 'someday'}), lifecycleOnly: true);
      await logContact(op.uuid);
      expect((await operations.get(op.uuid))!.status, 'someday');
    });

    test('saving a contact that is no longer there leaves a sent log sent', () async {
      // Nothing in the log changed, so nothing an upload holds is stale.
      final op = await seedAt(OperationStatus.active);
      final qso = await logContact(op.uuid);
      await operations.setStatus(op.uuid, OperationStatus.processed);
      await (db.delete(db.qsos)..where((q) => q.uuid.equals(qso.uuid))).go();
      await qsos.update(qso);
      expect((await operations.get(op.uuid))!.status, OperationStatus.processed);
    });

    test('moving a contact out of a sent log makes that log stale too', () async {
      // The log it left has changed as much as the one it joined, and an
      // upload of it now claims a contact it no longer holds.
      final sent = await seedAt(OperationStatus.active);
      final qso = await logContact(sent.uuid);
      await operations.setStatus(sent.uuid, OperationStatus.processed);
      final other = await seedAt(OperationStatus.active);
      await qsos.update(Qso(uuid: qso.uuid, operationUuid: other.uuid, data: qso.data));
      expect((await operations.get(sent.uuid))!.status, OperationStatus.completed);
    });

    test('a status set while a save is in flight survives it, and the save does too', () async {
      // Each writes the whole record from its own read. Interleaved, the
      // later write puts back what the earlier one changed — whichever of
      // the two started first.
      for (final statusFirst in [true, false]) {
        final copy = await seedAt(OperationStatus.active);
        Future<void> setting() => operations.setStatus(copy.uuid, OperationStatus.completed);
        Future<void> saving() => operations.saveData(Operation(uuid: copy.uuid, data: {...copy.data, 'grid': 'FN31'}));
        await Future.wait(statusFirst ? [setting(), saving()] : [saving(), setting()]);
        final saved = (await operations.get(copy.uuid))!;
        expect(saved.status, OperationStatus.completed, reason: 'status first: $statusFirst');
        expect(saved.data['grid'], 'FN31', reason: 'status first: $statusFirst');
      }
    });
  });

  group('a record arriving from a client that knows no lifecycle', () {
    late HaLoDatabase db;
    late OperationsRepository operations;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      operations = OperationsRepository(db);
    });

    tearDown(() async => db.close());

    test('survives a stored blob that will not decode', () async {
      // This runs inside the merge transaction, for every inbound record that
      // carries no status — which is every app-polo record, forever. A throw
      // here rolls the whole batch back, so one corrupt row on disk wedges
      // sync permanently instead of letting the row heal.
      final op = await operations.create(stationCall: 'N0DEV');
      await (db.update(db.operations)..where((o) => o.uuid.equals(op.uuid))).write(const OperationsCompanion(data: Value('not json at all')));

      await operations.mergeFromSync([
        {'uuid': op.uuid, 'stationCall': 'N0DEV', 'userTitle': 'healed', 'updatedAtMillis': nowMillis() + 1000},
      ]);

      expect((await operations.get(op.uuid))!.userTitle, 'healed');
    });

    test('does not strip the status, or the stamps with it', () async {
      // app-polo, and every halo build older than the lifecycle, round-trip
      // an operation without these keys. A merge replaces the blob wholesale,
      // so a polo user renaming an operation would erase the operator's
      // "completed" on every device — and the sweep would then re-derive it
      // as `paused`, quietly walking back a declaration only the operator is
      // allowed to make.
      final op = await operations.create(stationCall: 'N0DEV');
      await operations.setStatus(op.uuid, OperationStatus.completed);
      final before = (await operations.get(op.uuid))!;

      await operations.mergeFromSync([
        {
          'uuid': op.uuid,
          'stationCall': 'N0DEV',
          'userTitle': 'renamed in polo',
          'createdAtMillis': before.createdAtMillis,
          'updatedAtMillis': before.updatedAtMillis! + 1000,
        },
      ]);

      final after = (await operations.get(op.uuid))!;
      expect(after.userTitle, 'renamed in polo');
      expect(after.status, OperationStatus.completed);
      expect(after.statusAtMillis, before.statusAtMillis);
      // And the restore is SILENT. Marking the row dirty would push it, and
      // on the first pull after an upgrade every inbound record lacks a
      // status — a whole account's operations going back out at once.
      expect(after.synced, isTrue);
    });

    test('a record that carries a status brings its own stamps with it', () async {
      final op = await operations.create(stationCall: 'N0DEV');
      await operations.setStatus(op.uuid, OperationStatus.active);
      final before = (await operations.get(op.uuid))!;

      await operations.mergeFromSync([
        {'uuid': op.uuid, 'stationCall': 'N0DEV', 'status': OperationStatus.completed, 'updatedAtMillis': before.updatedAtMillis! + 1000},
      ]);
      final after = (await operations.get(op.uuid))!;
      expect(after.status, OperationStatus.completed);
      // No restoration, so no repair: the record is taken as sent and stays
      // marked synced. The four keys move as one — an older stamp restored
      // under this newer status would date a declaration nobody made.
      expect(after.statusAtMillis, isNull);
      expect(after.synced, isTrue);
    });
  });

  group('setStatus', () {
    late HaLoDatabase db;
    late OperationsRepository operations;

    setUp(() {
      db = HaLoDatabase(NativeDatabase.memory());
      operations = OperationsRepository(db);
    });

    tearDown(() async => db.close());

    test('processed is stamped on the way in and survives the revert', () async {
      final op = await operations.create(stationCall: 'N0DEV');
      await operations.setStatus(op.uuid, OperationStatus.processed);
      final processedAt = (await operations.get(op.uuid))!.processedAtMillis;
      expect(processedAt, isNotNull);
      await operations.setStatus(op.uuid, OperationStatus.completed, restamp: false);
      expect((await operations.get(op.uuid))!.processedAtMillis, processedAt);
    });

    test('an export marks a started log sent, and an unstarted one nothing', () async {
      // Marked sent, an empty log loses its START and is archived a week
      // later with nothing in it.
      final op = await operations.create(stationCall: 'N0DEV');
      expect(await operations.markExported(op.uuid), isNull);
      final unsent = (await operations.get(op.uuid))!;
      expect(unsent.status, op.status);
      expect(unsent.processedAtMillis, isNull);
      await operations.setStatus(op.uuid, OperationStatus.active);
      await operations.markExported(op.uuid);
      expect((await operations.get(op.uuid))!.status, OperationStatus.processed);
    });
  });
}

class _CountingOperations extends OperationsRepository {
  int infers = 0;

  _CountingOperations(super.db);

  @override
  Future<Operation?> inferStatus(String uuid, ({String status, int? atMillis})? Function(Operation operation) decide) {
    infers++;
    return super.inferStatus(uuid, decide);
  }
}

class _FailingOperations extends OperationsRepository {
  _FailingOperations(super.db);

  @override
  Future<List<String>> lifecycleSweepCandidates() => Future.error(StateError('database is gone'));
}
