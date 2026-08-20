// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The write gate is the ONLY thing standing between a travelled clock and a
// real log (docs/design/time.md §4). Nothing downstream catches a hole here:
// neither the sync account nor the clock bars a round any more, so a gap in
// these tests reaches the server, and a travelled `startAtMillis` on a REAL
// contact is indistinguishable from a genuine one the moment it lands on
// another device.
//
// Revision stamps are on the real clock either way, so none of this is about
// last-write-wins; it is about which records a travelled session may touch at
// all.

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db, sequences: SequencesRepository(db));
  });

  tearDown(() async {
    // AppClock is a process-wide singleton, so travel left on here would leak
    // into every test that runs after this file and fail them somewhere else
    // entirely.
    AppClock.instance.reset();
    await db.close();
  });

  void travel() => AppClock.instance.travel(delta: const Duration(days: 3));

  group('isTestCall', () {
    test('matches T or TEST as a whole segment, anywhere in the call', () {
      expect(isTestCall('KI2D/T'), isTrue);
      expect(isTestCall('KI2D/TEST'), isTrue);
      expect(isTestCall('ki2d/test'), isTrue, reason: 'case must not matter');
      // The suffix match this replaced missed these: the operator said T and
      // then added a portable modifier after it.
      expect(isTestCall('KI2D/T/P'), isTrue);
      expect(isTestCall('KI2D/TEST/M'), isTrue);
    });

    test('does not match a call that merely contains the letters', () {
      // A substring match would opt a real callsign into being test data, and
      // this predicate is what decides whether a travelled clock may write.
      expect(isTestCall('W1AW/TESTER'), isFalse);
      expect(isTestCall('TESTA'), isFalse);
      expect(isTestCall('KI2D'), isFalse);
    });

    test('does not match the standard modifiers a real operator signs with', () {
      for (final call in ['KI2D/P', 'KI2D/M', 'KI2D/MM', 'KI2D/AM', 'KI2D/QRP']) {
        expect(isTestCall(call), isFalse, reason: call);
      }
    });
  });

  group('with the clock on real time, nothing is refused', () {
    test('a real operation and its contacts are fully writable', () async {
      final op = await operations.create(stationCall: 'KI2D');
      expect(op.isTestOperation, isFalse, reason: 'no /TEST is added off the travelled clock');

      await operations.saveData(Operation(uuid: op.uuid, data: {...op.data, 'userTitle': 'Field Day'}));
      final qso = await qsos.add(op.uuid, {
        'their': {'call': 'W1AW'}
      });
      await qsos.update(Qso(uuid: qso.uuid, operationUuid: op.uuid, data: {...qso.data, 'notes': 'x'}));
      await qsos.softDelete(qso);
      await operations.softDelete(op.uuid);
      // Reaching here without throwing IS the assertion — the gate must be
      // inert when the clock is not travelled.
    });
  });

  group('while travelling, real records are refused', () {
    test('editing a real operation throws instead of writing', () async {
      final op = await operations.create(stationCall: 'KI2D');
      travel();

      await expectLater(
        operations.saveData(Operation(uuid: op.uuid, data: {...op.data, 'userTitle': 'changed'})),
        throwsA(isA<WriteRefused>()),
      );
      expect((await operations.get(op.uuid))!.userTitle, isNot('changed'),
          reason: 'the refusal must leave the row untouched, not throw after writing');
    });

    test('deleting a real operation is refused too', () async {
      final op = await operations.create(stationCall: 'KI2D');
      travel();
      await expectLater(operations.softDelete(op.uuid), throwsA(isA<WriteRefused>()));
      await expectLater(operations.purge(op.uuid), throwsA(isA<WriteRefused>()));
      expect((await operations.get(op.uuid))!.deleted, isFalse);
    });

    test('logging into a real operation is refused, and logs nothing', () async {
      final op = await operations.create(stationCall: 'KI2D');
      travel();
      await expectLater(
        qsos.add(op.uuid, {
          'their': {'call': 'W1AW'}
        }),
        throwsA(isA<WriteRefused>()),
      );
      expect(await qsos.watchForOperation(op.uuid).first, isEmpty);
    });

    test('editing and deleting an existing real contact are refused', () async {
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, {
        'their': {'call': 'W1AW'}
      });
      travel();
      await expectLater(
        qsos.update(Qso(uuid: qso.uuid, operationUuid: op.uuid, data: {...qso.data, 'notes': 'x'})),
        throwsA(isA<WriteRefused>()),
      );
      await expectLater(qsos.softDelete(qso), throwsA(isA<WriteRefused>()));
    });

    test('a bulk import into a real operation is refused as a whole', () async {
      final op = await operations.create(stationCall: 'KI2D');
      travel();
      await expectLater(
        qsos.writeBatch(operationUuid: op.uuid, inserts: [
          {
            'their': {'call': 'W1AW'}
          },
          {
            'their': {'call': 'K1ABC'}
          },
        ]),
        throwsA(isA<WriteRefused>()),
      );
      expect(await qsos.watchForOperation(op.uuid).first, isEmpty);
    });

    test('a test-called contact cannot be smuggled into a REAL operation', () async {
      // A contact inside an operation is made with that operation's station
      // call, so its own call is not an identity the gate may consult. Reading
      // it would carry a contact INTO a real operation while marking it test
      // data, where every cleanup path — all per-operation — is blind to it.
      //
      // BOTH write paths, because they are separate call sites: an earlier
      // version refused this only in `writeBatch`, and an extension's `addQso`
      // reaches `add` with arbitrary QSON.
      final op = await operations.create(stationCall: 'KI2D');
      travel();
      const smuggled = {
        'our': {'call': 'KI2D/TEST'},
        'their': {'call': 'W1AW'}
      };

      await expectLater(qsos.add(op.uuid, {...smuggled}), throwsA(isA<WriteRefused>()));
      await expectLater(
        qsos.writeBatch(operationUuid: op.uuid, inserts: [{...smuggled}]),
        throwsA(isA<WriteRefused>()),
      );
      expect(await qsos.watchForOperation(op.uuid).first, isEmpty);
    });

    test('an edit cannot declare itself test data to rewrite a real contact', () async {
      // The stored-record rule, for contacts. `update` is handed a
      // selection-time snapshot, so trusting the call IN that snapshot would
      // let one write both the permission and the rewrite — including the
      // contact's own times, which is the whole exposure.
      final loose = await qsos.add('', {
        'our': {'call': 'KI2D'},
        'their': {'call': 'W1AW'},
        'startAtMillis': 1780000000000,
      });
      travel();

      await expectLater(
        qsos.update(Qso(uuid: loose.uuid, operationUuid: '', data: {
          ...loose.data,
          'our': {'call': 'KI2D/TEST'},
          'startAtMillis': 1,
        })),
        throwsA(isA<WriteRefused>()),
      );
      expect((await qsos.get(loose.uuid))!.data['startAtMillis'], 1780000000000);
    });

    test('deleting a real contact cannot be unlocked by the snapshot either', () async {
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, {
        'their': {'call': 'W1AW'}
      });
      travel();
      await expectLater(
        qsos.softDelete(Qso(uuid: qso.uuid, operationUuid: op.uuid, data: {
          ...qso.data,
          'our': {'call': 'KI2D/TEST'},
        })),
        throwsA(isA<WriteRefused>()),
      );
      expect((await qsos.get(qso.uuid))!.deleted, isFalse);
    });
  });

  group('while travelling, test records stay writable', () {
    test('a test operation and its contacts work normally', () async {
      final op = await operations.create(stationCall: 'KI2D/T');
      travel();

      await operations.saveData(Operation(uuid: op.uuid, data: {...op.data, 'userTitle': 'Travelled'}));
      final qso = await qsos.add(op.uuid, {
        'their': {'call': 'W1AW'}
      });
      await qsos.update(Qso(uuid: qso.uuid, operationUuid: op.uuid, data: {...qso.data, 'notes': 'x'}));
      expect((await operations.get(op.uuid))!.userTitle, 'Travelled');
    });

    test('a contact with a test call and NO operation is allowed', () async {
      // The one case where the contact's own call decides: with no operation
      // there is nothing else to identify it by, and creating one declares its
      // call the same way creating an operation declares its station call.
      travel();
      final qso = await qsos.add('', {
        'our': {'call': 'KI2D/TEST'},
        'their': {'call': 'W1AW'},
      });
      expect((await qsos.get(qso.uuid))!.ourCall, 'KI2D/TEST');
    });

    test('a contact with a REAL call and no operation is refused', () async {
      travel();
      await expectLater(
        qsos.add('', {
          'our': {'call': 'KI2D'},
          'their': {'call': 'W1AW'}
        }),
        throwsA(isA<WriteRefused>()),
      );
    });
  });

  group('the escape hatches are closed', () {
    test('adding /TEST to a real operation does not unlock it', () async {
      // Judged on the STORED callsign. Judging the incoming edit instead would
      // make this one write its own permission slip, and every write after it.
      final op = await operations.create(stationCall: 'KI2D');
      travel();
      await expectLater(
        operations.saveData(Operation(uuid: op.uuid, data: {...op.data, 'stationCall': 'KI2D/TEST'})),
        throwsA(isA<WriteRefused>()),
      );
      expect((await operations.get(op.uuid))!.isTestOperation, isFalse);
    });

    test('removing /TEST from a test operation is refused, so nobody strands themselves', () async {
      // Not about protecting the log — about the operator. Allowing this would
      // commit the edit and then lock them out of the operation on the very
      // next write, with no way back short of ending travel.
      final op = await operations.create(stationCall: 'KI2D/T');
      travel();
      await expectLater(
        operations.saveData(Operation(uuid: op.uuid, data: {...op.data, 'stationCall': 'KI2D'})),
        throwsA(isA<WriteRefused>()),
      );
      expect((await operations.get(op.uuid))!.isTestOperation, isTrue);
    });

    test('an operation created while travelling is born marked', () async {
      travel();
      final op = await operations.create(stationCall: 'KI2D');
      expect(op.stationCall, 'KI2D/TEST');
      expect(op.isTestOperation, isTrue,
          reason: 'created unmarked it would be unwritable by the very gate that let it exist');
      // And it is immediately usable, which is the whole point of marking
      // rather than refusing.
      await qsos.add(op.uuid, {
        'their': {'call': 'W1AW'}
      });
    });

    test('every call of a multi-operator station gets marked, not just the last', () async {
      travel();
      final op = await operations.create(stationCall: 'KI2D, W1AW');
      expect(op.stationCall, 'KI2D/TEST, W1AW/TEST');
    });

    test('a call that is already test data is not marked twice', () async {
      travel();
      final op = await operations.create(stationCall: 'KI2D/T');
      expect(op.stationCall, 'KI2D/T');
    });

    test('an operation created with no callsign is still writable', () async {
      // `stationCalls` yields [''] for an empty call, and '' is not a test
      // call — so without the marking an operation created before its callsign
      // is known would be born unwritable.
      travel();
      final op = await operations.create(stationCall: '');
      expect(op.isTestOperation, isTrue);
      await qsos.add(op.uuid, {
        'their': {'call': 'W1AW'}
      });
    });
  });

  group('inbound records are never refused', () {
    test('a real operation and its contacts still merge in while travelling', () async {
      // Receiving real data is explicitly acceptable — the gate is about what
      // this device AUTHORS. Refusing here would break sync itself the moment
      // a developer travelled.
      travel();
      await operations.mergeFromSync([
        {'uuid': 'op-remote', 'stationCall': 'W1AW', 'updatedAtMillis': realNowMillis()},
      ]);
      await qsos.mergeFromSync([
        {
          'uuid': 'qso-remote',
          'operation': 'op-remote',
          'their': {'call': 'K1ABC'},
          'updatedAtMillis': realNowMillis(),
        },
      ]);
      expect((await operations.get('op-remote'))!.isTestOperation, isFalse);
      expect(await qsos.get('qso-remote'), isNotNull);
    });

    test('a peer record for a real operation merges in too', () async {
      travel();
      await qsos.mergeFromPeer([
        {
          'uuid': 'qso-peer',
          'operation': 'op-real',
          'their': {'call': 'K1ABC'},
          'updatedAtMillis': realNowMillis(),
        },
      ]);
      expect(await qsos.get('qso-peer'), isNotNull);
    });
  });

  group('test contacts with no operation can be cleaned up', () {
    // Every other cleanup path is keyed on an operation uuid — the PURGETESTS
    // command walks operations, and the received-purge prompt takes operation
    // uuids — so a contact with no operation is reachable by none of them.
    // The gate lets a travelled clock author exactly these, which is what
    // turns the omission into a leak.
    test('testQsosWithoutOperation finds them, and nothing else', () async {
      final op = await operations.create(stationCall: 'KI2D/T');
      await qsos.add(op.uuid, {
        'their': {'call': 'IN-AN-OP'}
      });
      final loose = await qsos.add('', {
        'our': {'call': 'KI2D/TEST'},
        'their': {'call': 'LOOSE-TEST'},
      });
      await qsos.add('', {
        'our': {'call': 'KI2D'},
        'their': {'call': 'LOOSE-REAL'},
      });

      final found = await qsos.testQsosWithoutOperation();
      expect(found.map((q) => q.uuid), [loose.uuid],
          reason: 'a contact inside an operation is that operation\'s to purge, and a '
              'loose contact with a REAL call is not test data at all');
    });

    test('purging them tombstones rather than deleting, so the removal syncs', () async {
      final loose = await qsos.add('', {
        'our': {'call': 'KI2D/TEST'},
        'their': {'call': 'W1AW'},
      });
      await qsos.markSynced([(await qsos.get(loose.uuid))!]);

      await qsos.purgeQsos([loose.uuid]);

      final row = (await qsos.get(loose.uuid))!;
      expect(row.deleted, isTrue);
      expect(row.purged, isTrue);
      // `synced` is a column rather than a model field, so read it directly.
      final synced = (await db
              .customSelect('SELECT synced FROM qsos WHERE uuid = ?',
                  variables: [Variable.withString(loose.uuid)])
              .getSingle())
          .read<bool>('synced');
      expect(synced, isFalse,
          reason: 'a purge the other devices never hear about leaves the contact alive there');
      expect(await qsos.testQsosWithoutOperation(), isEmpty,
          reason: 'and it must not be offered for purging twice');
    });

    test('the orphan sweep collects them once the tombstone has synced', () async {
      // This is what finishes the job, here and on every other device, and it
      // is why no new received-purge plumbing is needed: a contact with no
      // operation is already an orphan by that sweep's definition.
      final loose = await qsos.add('', {
        'our': {'call': 'KI2D/TEST'},
        'their': {'call': 'W1AW'},
      });
      await qsos.purgeQsos([loose.uuid]);
      expect(await qsos.hardDeletePurgedOrphans(), 0,
          reason: 'not while the tombstone is still unsynced — the other devices need it first');

      await qsos.markSynced([(await qsos.get(loose.uuid))!]);
      expect(await qsos.hardDeletePurgedOrphans(), 1);
      expect(await qsos.get(loose.uuid), isNull);
    });

    test('a purge from another device removes the contact this device holds', () async {
      // The receiving half, and it needs no confirmation prompt: that prompt
      // exists for whole operations, where a misclassified /T would take a
      // real log with it. One loose contact carries no such risk.
      final loose = await qsos.add('', {
        'our': {'call': 'KI2D/TEST'},
        'their': {'call': 'W1AW'},
      });
      await qsos.markSynced([(await qsos.get(loose.uuid))!]);

      await qsos.mergeFromSync([
        {
          'uuid': loose.uuid,
          'operation': '',
          'our': {'call': 'KI2D/TEST'},
          'their': {'call': 'W1AW'},
          'deleted': true,
          'purged': true,
          'updatedAtMillis': realNowMillis() + 1000,
        },
      ]);

      expect(await qsos.hardDeletePurgedOrphans(), 1);
      expect(await qsos.get(loose.uuid), isNull);
    });

    test('a contact with no operation is NOT swept just for having none', () async {
      // The invariant the sweep's name does not carry: "orphan" there means
      // PURGED and already pushed, not merely operation-less. A contact with
      // no operation is ordinary data — the sweep must leave it alone however
      // long it sits there, and whether or not it is test data.
      final looseTest = await qsos.add('', {
        'our': {'call': 'KI2D/TEST'},
        'their': {'call': 'W1AW'},
      });
      final looseReal = await qsos.add('', {
        'our': {'call': 'KI2D'},
        'their': {'call': 'K1ABC'},
      });
      // Synced, so the only condition left unmet is `purged` — otherwise this
      // would pass for the wrong reason.
      await qsos.markSynced([(await qsos.get(looseTest.uuid))!, (await qsos.get(looseReal.uuid))!]);

      expect(await qsos.hardDeletePurgedOrphans(), 0);
      expect(await qsos.get(looseTest.uuid), isNotNull);
      expect(await qsos.get(looseReal.uuid), isNotNull);
    });

    test('a contact whose operation was deleted is not swept either', () async {
      // Same invariant from the other side: losing an operation must not take
      // its contacts with it unless they were purged too.
      final op = await operations.create(stationCall: 'KI2D');
      final qso = await qsos.add(op.uuid, {
        'their': {'call': 'W1AW'}
      });
      await qsos.markSynced([(await qsos.get(qso.uuid))!]);
      await operations.hardDeleteOperation(op.uuid);

      expect(await qsos.hardDeletePurgedOrphans(), 0);
      expect(await qsos.get(qso.uuid), isNotNull);
    });

    test('purgeQsos re-checks each row and reports what it actually wrote', () async {
      // The list is built BEFORE a confirmation dialog the operator may sit on
      // indefinitely, and sync rounds run while travelling now — so a row can
      // gain an operation, or a real call, in between. A purge is
      // unrecoverable and invisible once done, so the list is a nomination,
      // not an instruction.
      final stillLoose = await qsos.add('', {
        'our': {'call': 'KI2D/TEST'},
        'their': {'call': 'W1AW'},
      });
      final adopted = await qsos.add('', {
        'our': {'call': 'KI2D/TEST'},
        'their': {'call': 'K1ABC'},
      });
      final nominated = [stillLoose.uuid, adopted.uuid, 'never-existed'];

      // The dialog is up; an inbound edit gives one of them an operation.
      final op = await operations.create(stationCall: 'W1AW');
      await qsos.mergeFromSync([
        {
          'uuid': adopted.uuid,
          'operation': op.uuid,
          'our': {'call': 'W1AW'},
          'their': {'call': 'K1ABC'},
          'updatedAtMillis': realNowMillis() + 5000,
        },
      ]);

      expect(await qsos.purgeQsos(nominated), 1,
          reason: 'only the row that still qualifies, and the count is what was written');
      expect((await qsos.get(stillLoose.uuid))!.purged, isTrue);
      expect((await qsos.get(adopted.uuid))!.purged, isFalse,
          reason: 'it belongs to an operation now, so it is that operation\'s to purge');
    });

    test('a purge for a contact this device never had creates nothing', () async {
      // `mergeFromSync` refuses to build a row out of a tombstone, so a
      // re-delivered purge cannot resurrect a contact as a corpse. Pinned here
      // because `purgeQsos` made that guard's original reasoning — "a QSO is
      // only ever purged with its whole operation" — no longer true.
      await qsos.mergeFromSync([
        {
          'uuid': 'never-seen',
          'operation': '',
          'our': {'call': 'KI2D/TEST'},
          'their': {'call': 'W1AW'},
          'deleted': true,
          'purged': true,
          'updatedAtMillis': realNowMillis(),
        },
      ]);
      expect(await qsos.get('never-seen'), isNull);
    });
  });
}
