// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Transfer records (docs/design/transfer.md §2, §7). What these guard:
// a push to one service must not make every contact read as changed for
// another; a push's own write-back must not mark its operation stale; and a
// write-back without a revision bump would be undone by the next stale copy
// sync brings in.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  test('a record key is the service and the destination, in lower case', () {
    expect(transferKey('qrz', 'KI2D'), 'qrz:ki2d', reason: 'a destination named in other capitals must not make a second record');
  });

  group('withTransferRecord', () {
    test("writes the destination's record at the revision, which becomes the contact's", () {
      final data = withTransferRecord({'updatedAtMillis': 100}, 'qrz:ki2d', {'id': '1'}, revision: 200);

      expect(data['updatedAtMillis'], 200);
      expect(transferRecordOf(data, 'qrz:ki2d'), {'id': '1', 'sentRevision': 200});
      expect(transferIsBehind(data, 'qrz:ki2d'), isFalse);
    });

    test('a destination that was up to date stays up to date when another is written', () {
      var data = withTransferRecord({'updatedAtMillis': 100}, 'qrz:ki2d', {'id': '1'}, revision: 200);
      data = withTransferRecord(data, 'qrz:n0club', {'id': 'c'}, revision: 300);

      expect(transferIsBehind(data, 'qrz:ki2d'), isFalse, reason: "the push to the club's logbook is bookkeeping, not a change KI2D's hasn't seen");
      expect(transferRecordOf(data, 'qrz:ki2d'), {'id': '1', 'sentRevision': 300}, reason: 'each logbook keeps its own record and id');
      expect(transferRecordOf(data, 'qrz:n0club'), {'id': 'c', 'sentRevision': 300});
    });

    test('a destination already behind stays behind when another is written', () {
      var data = withTransferRecord({'updatedAtMillis': 100}, 'qrz:ki2d', {'id': '1'}, revision: 200);
      data = {...data, 'updatedAtMillis': 250}; // an edit QRZ has not seen
      data = withTransferRecord(data, 'wavelog:main', {'id': 'w'}, revision: 300);

      expect(transferIsBehind(data, 'qrz:ki2d'), isTrue, reason: 'carrying it forward would hide the edit from the next push');
      expect(transferIsBehind(data, 'wavelog:main'), isFalse);
    });

    test('a null record clears the destination, and the key goes once nothing is left', () {
      final sent = withTransferRecord({'updatedAtMillis': 100}, 'qrz:ki2d', {'id': '1'}, revision: 200);
      final cleared = withTransferRecord(sent, 'qrz:ki2d', null, revision: 300);

      expect(transferRecordOf(cleared, 'qrz:ki2d'), isNull);
      expect(cleared.containsKey(qsoTransferKey), isFalse);
    });

    test('a contact never sent is not behind', () {
      expect(transferIsBehind({'updatedAtMillis': 100}, 'qrz:ki2d'), isFalse);
    });
  });

  group('QsoSelector', () {
    Qso qso(Map<String, dynamic> data, {bool deleted = false}) => Qso(uuid: 'q', operationUuid: 'op', data: {'band': '20m', ...data}, deleted: deleted);
    final sentToQrz = withTransferRecord({'updatedAtMillis': 100}, 'qrz:ki2d', {'id': '1'}, revision: 200);

    test('hunted reads the contact; activated reads its operation', () {
      final hunter = qso({
        'refs': [
          {'type': 'sota', 'ref': 'W1/AM-001'},
        ],
      });

      expect(const QsoSelector(hunted: 'sota').matches(hunter, destination: 'chase'), isTrue);
      expect(const QsoSelector(hunted: 'pota').matches(hunter, destination: 'chase'), isFalse);
      expect(
        const QsoSelector(activated: 'sota').matches(hunter, destination: 'chase'),
        isFalse,
        reason: 'the summit is the one worked, not the one activated',
      );
      expect(
        const QsoSelector(activated: 'potaActivation').matches(
          hunter,
          destination: 'main',
          operationRefs: [
            {'type': 'potaActivation', 'ref': 'US-1234'},
          ],
        ),
        isTrue,
      );
    });

    test('notSentTo and changedSince split the never-sent from the edited', () {
      expect(const QsoSelector(notSentTo: 'qrz').matches(qso({}), destination: 'ki2d'), isTrue);
      expect(const QsoSelector(notSentTo: 'qrz').matches(qso(sentToQrz), destination: 'ki2d'), isFalse);
      expect(const QsoSelector(changedSince: 'qrz').matches(qso(sentToQrz), destination: 'ki2d'), isFalse);
      expect(const QsoSelector(changedSince: 'qrz').matches(qso({...sentToQrz, 'updatedAtMillis': 300}), destination: 'ki2d'), isTrue);
      expect(
        const QsoSelector(changedSince: 'qrz').matches(qso({}), destination: 'ki2d'),
        isFalse,
        reason: 'never sent is not "changed since sent"',
      );
    });

    test('a record written from other operation content is changed, though the contact is not', () {
      final sentFrom = withTransferRecord({'updatedAtMillis': 100}, 'qrz:ki2d', {'id': '1', 'operationHash': 'a'}, revision: 200);
      const updates = QsoSelector(changedSince: 'qrz');
      expect(updates.matches(qso(sentFrom), destination: 'ki2d', operationHash: 'a'), isFalse);
      expect(
        updates.matches(qso(sentFrom), destination: 'ki2d', operationHash: 'b'),
        isTrue,
        reason: 'a corrected park or grid rewrites the record',
      );
      expect(
        updates.matches(qso({}), destination: 'ki2d', operationHash: 'b'),
        isFalse,
        reason: 'never sent is still not "changed since sent"',
      );
    });

    test('a service is read against the destination being counted; a record key names that record', () {
      expect(
        const QsoSelector(notSentTo: 'qrz').matches(qso(sentToQrz), destination: 'n0club'),
        isTrue,
        reason: "a contact in KI2D's logbook still owes the club's",
      );
      expect(
        const QsoSelector(notSentTo: 'qrz').matches(qso(sentToQrz), destination: 'KI2D'),
        isFalse,
        reason: 'capitals name the same record',
      );
      expect(const QsoSelector(notSentTo: 'qrz:ki2d').matches(qso(sentToQrz), destination: 'n0club'), isFalse);
    });

    test('events and tombstones are never contacts to send; a tombstone the destination holds is a delete owed to its updates', () {
      expect(const QsoSelector().matches(qso({'band': 'event'}), destination: 'ki2d'), isFalse);
      expect(const QsoSelector().matches(qso(sentToQrz, deleted: true), destination: 'ki2d'), isFalse);
      expect(const QsoSelector(changedSince: 'qrz').matchesDelete(qso(sentToQrz, deleted: true), 'qrz', destination: 'ki2d'), isTrue);
      expect(
        const QsoSelector(notSentTo: 'qrz').matchesDelete(qso(sentToQrz, deleted: true), 'qrz', destination: 'ki2d'),
        isFalse,
        reason: 'a push of what was never sent owes no deletes',
      );
      expect(const QsoSelector().matchesDelete(qso({}, deleted: true), 'qrz', destination: 'ki2d'), isFalse, reason: 'the service never had it');
      expect(
        const QsoSelector().matchesDelete(qso(sentToQrz, deleted: true), 'qrz', destination: 'n0club'),
        isFalse,
        reason: "the club's logbook never had it",
      );
    });
  });

  group('writing records back', () {
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
    tearDown(() => db.close());

    Future<Qso> logContact(String operationUuid, String call) => qsos.add(operationUuid, {
      'band': '20m',
      'mode': 'CW',
      'their': {'call': call},
    });

    test("a push's own write-back leaves a processed operation processed", () async {
      final op = await operations.create(stationCall: 'N0DEV');
      final qso = await logContact(op.uuid, 'W1AW');
      await operations.setStatus(op.uuid, OperationStatus.processed);

      await qsos.writeTransfers('qrz:ki2d', {
        qso.uuid: {'id': '42'},
      });

      expect((await operations.get(op.uuid))!.status, OperationStatus.processed);
      expect(transferRecordOf((await qsos.get(qso.uuid))!.data, 'qrz:ki2d')?['id'], '42');
    });

    test('the write bumps the sync revision and queues the contact for sync', () async {
      final qso = await logContact('', 'W1AW');
      await qsos.markSynced([qso]);

      await qsos.writeTransfers('qrz:ki2d', {
        qso.uuid: {'id': '42'},
      });

      final stored = (await qsos.get(qso.uuid))!;
      expect(stored.updatedAtMillis, greaterThan(qso.updatedAtMillis!));
      final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(qso.uuid))).getSingle();
      expect(row.synced, isFalse);
    });

    test('a tombstone keeps its record until the service confirms the delete, and stays deleted', () async {
      final qso = await logContact('', 'W1AW');
      await qsos.writeTransfers('qrz:ki2d', {
        qso.uuid: {'id': '42'},
      });
      await qsos.softDelete((await qsos.get(qso.uuid))!);

      await qsos.writeTransfers('qrz:ki2d', {qso.uuid: null});

      final row = await (db.select(db.qsos)..where((q) => q.uuid.equals(qso.uuid))).getSingle();
      expect(row.deleted, isTrue);
      expect(transferRecordOf(jsonDecode(row.data) as Map<String, dynamic>, 'qrz:ki2d'), isNull);
    });

    test('claims are not told: no contact content changed', () async {
      final qso = await logContact('', 'W1AW');
      final seen = <Set<String>?>[];
      qsos.changes.listen(seen.add);

      await qsos.writeTransfers('qrz:ki2d', {
        qso.uuid: {'id': '42'},
      });
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty);
    });

    // A push records its summary even when it fails partway, so the status
    // is the caller's to move, on success only. Saved as an edit, the summary
    // would run the segment pass, rewriting and re-syncing every event row on
    // each push.
    test('recording a push saves its summary as bookkeeping: the status stays, and no segment pass runs', () async {
      var segmentPasses = 0;
      final operations = OperationsRepository(db, onLocalSave: (_, _) async => segmentPasses++);
      final op = await operations.create(stationCall: 'N0DEV');
      await logContact(op.uuid, 'W1AW');
      await operations.setStatus(op.uuid, OperationStatus.completed);
      segmentPasses = 0;

      await operations.recordTransfer(op.uuid, 'qrz:ki2d', {'sentCount': 1});

      final stored = (await operations.get(op.uuid))!;
      expect(stored.status, OperationStatus.completed);
      expect(asQsonMap(stored.data[qsoTransferKey])?['qrz:ki2d'], {'sentCount': 1});
      expect(segmentPasses, 0);
    });
  });
}
