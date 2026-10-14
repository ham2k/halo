// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `QsosRepository.changesSince`: what the extension runtime keeps its copy of
// a log in step with. The trap throughout is a copy that drifts from the log
// silently — a change the cursor walked past, or a reset that never came.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

/// A reader's copy of one log, kept the way the extension runtime keeps it.
class Copy {
  Copy(this.repository, this.operationUuid);
  final QsosRepository repository;
  final String operationUuid;
  String? cursor;
  final rows = <String, Map<String, dynamic>>{};
  QsoLogChanges? last;

  Future<QsoLogChanges> sync() async {
    final changes = last = await repository.changesSince(operationUuid, cursor);
    if (changes.reset) rows.clear();
    for (final qso in changes.qsos) {
      rows[qso.uuid] = qso.data;
    }
    changes.removed.forEach(rows.remove);
    cursor = changes.cursor;
    return changes;
  }

  Future<void> expectMatchesLog() async {
    final log = await repository.forOperation(operationUuid);
    expect(rows.keys.toSet(), {for (final qso in log) qso.uuid});
    for (final qso in log) {
      expect(rows[qso.uuid], qso.data, reason: '${qso.uuid} is stale in the copy');
    }
  }
}

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;

  setUp(() {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Map<String, dynamic> contact(String call, int startAt) => {
    'their': {'call': call},
    'mode': 'CW',
    'startAtMillis': startAt,
  };

  test('a reader with no cursor is handed the whole log', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    await qsos.add(op.uuid, contact('K1ABC', 2000));
    final copy = Copy(qsos, op.uuid);

    final changes = await copy.sync();

    expect(changes.reset, isTrue);
    expect(changes.qsos.map((q) => q.theirCall), ['W1AW', 'K1ABC']);
    await copy.expectMatchesLog();
  });

  test('after that it is handed only what changed: an add, an edit, a delete', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final first = await qsos.add(op.uuid, contact('W1AW', 1000));
    final second = await qsos.add(op.uuid, contact('K1ABC', 2000));
    final copy = Copy(qsos, op.uuid);
    await copy.sync();

    final third = await qsos.add(op.uuid, contact('N0DEV', 3000));
    await qsos.update(Qso(uuid: first.uuid, operationUuid: op.uuid, data: {...first.data, 'notes': 'edited'}));
    await qsos.softDelete(second);
    final changes = await copy.sync();

    expect(changes.reset, isFalse);
    expect({for (final qso in changes.qsos) qso.uuid}, {first.uuid, third.uuid});
    expect(changes.removed, [second.uuid]);
    await copy.expectMatchesLog();
  });

  test('nothing changed is an empty answer, and a write to another operation is nothing', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final other = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final copy = Copy(qsos, op.uuid);
    await copy.sync();

    await qsos.add(other.uuid, contact('K1ABC', 2000));
    final changes = await copy.sync();

    expect(changes.reset, isFalse);
    expect(changes.qsos, isEmpty);
    expect(changes.removed, isEmpty);
  });

  test("a rescore's score cache is no change to a copy of the contacts", () async {
    // A full rescore caches a verdict on every contact. Counted as a change,
    // it would hand the copy the whole log after every edit, open and merge.
    final op = await operations.create(stationCall: 'KI2D');
    final logged = [for (var i = 0; i < 600; i++) await qsos.add(op.uuid, contact('K${i}AB', 1000 + i))];
    final copy = Copy(qsos, op.uuid);
    await copy.sync();

    await qsos.updateScoreCache(op.uuid, {for (final qso in logged) qso.uuid: '{"core":{}}'});
    final changes = await copy.sync();

    expect(changes.reset, isFalse);
    expect(changes.qsos, isEmpty);
    expect(changes.count, 600);
  });

  test('every answer counts the log, so a copy can tell it missed a write the ledger never saw', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final copy = Copy(qsos, op.uuid);
    expect((await copy.sync()).count, 1);

    // A write past the repository, which records no footprint.
    await db.into(db.qsos).insert(QsosCompanion.insert(uuid: 'stranger', operation: op.uuid, startAtMillis: const Value(2000)));
    final changes = await copy.sync();

    expect(changes.qsos, isEmpty, reason: 'the ledger knows nothing of it');
    expect(changes.count, 2);
    expect(copy.rows.length, isNot(changes.count), reason: 'which the count gives away');
  });

  test('a contact a sync merge moves to another operation leaves one copy and joins the other', () async {
    final from = await operations.create(stationCall: 'KI2D');
    final to = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(from.uuid, contact('W1AW', 1000));
    final fromCopy = Copy(qsos, from.uuid);
    final toCopy = Copy(qsos, to.uuid);
    await fromCopy.sync();
    await toCopy.sync();

    await qsos.mergeFromSync([
      {...qso.data, 'operation': to.uuid, 'updatedAtMillis': (qso.updatedAtMillis ?? 0) + 1},
    ]);

    expect((await fromCopy.sync()).removed, [qso.uuid]);
    expect((await toCopy.sync()).qsos.single.uuid, qso.uuid);
    await fromCopy.expectMatchesLog();
    await toCopy.expectMatchesLog();
  });

  test('a contact a sync merge brings in with an old stamp still arrives', () async {
    // The reason the cursor is not a time: a station that logged offline
    // syncs contacts stamped before the reader last asked.
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 5000));
    final copy = Copy(qsos, op.uuid);
    await copy.sync();

    await qsos.mergeFromSync([
      {...contact('K1ABC', 1000), 'uuid': 'late-arrival', 'operation': op.uuid, 'updatedAtMillis': 1},
    ]);
    final changes = await copy.sync();

    expect(changes.reset, isFalse);
    expect(changes.qsos.single.uuid, 'late-arrival');
    await copy.expectMatchesLog();
  });

  test('a cursor the repository never issued, or one past what the ledger holds, reads the whole log', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final copy = Copy(qsos, op.uuid);
    await copy.sync();

    // A repository made again — a restored database — counts from zero, so the
    // same position must not be taken for a place in its ledger.
    final again = QsosRepository(db);
    expect((await again.changesSince(op.uuid, copy.cursor)).reset, isTrue);
    expect((await qsos.changesSince(op.uuid, 'nonsense')).reset, isTrue);

    for (var i = 0; i < 300; i++) {
      await qsos.add(op.uuid, contact('K${i}AB', 2000 + i));
    }
    expect((await copy.sync()).reset, isTrue, reason: 'the ledger no longer reaches back to the cursor');
    await copy.expectMatchesLog();
  });

  test('a write that reaches every row reads the whole log', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await qsos.add(op.uuid, contact('W1AW', 1000));
    final copy = Copy(qsos, op.uuid);
    await copy.sync();

    await qsos.hardDeleteAllForOperation(op.uuid);

    expect((await copy.sync()).reset, isTrue);
    await copy.expectMatchesLog();
  });

  test('a copy kept by changes alone matches the log through a run of mixed writes', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final other = await operations.create(stationCall: 'KI2D');
    final copy = Copy(qsos, op.uuid);
    await copy.sync();
    final logged = <Qso>[];
    for (var i = 0; i < 60; i++) {
      switch (i % 6) {
        case 0 || 1 || 2:
          logged.add(await qsos.add(op.uuid, contact('K${i}AB', 1000 * (60 - i))));
        case 3:
          final qso = logged[i ~/ 2];
          await qsos.update(Qso(uuid: qso.uuid, operationUuid: op.uuid, data: {...qso.data, 'startAtMillis': 500 + i, 'notes': 'moved in time'}));
        case 4:
          await qsos.softDelete(logged[i ~/ 3]);
        case 5:
          final qso = logged[i ~/ 4];
          await qsos.update(Qso(uuid: qso.uuid, operationUuid: other.uuid, data: qso.data));
      }
      if (i % 4 == 0) {
        expect((await copy.sync()).reset, isFalse);
        await copy.expectMatchesLog();
      }
    }
    await copy.sync();
    await copy.expectMatchesLog();
  });
}
