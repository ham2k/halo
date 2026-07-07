// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

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
    qsos = QsosRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create and watch operations', () async {
    final op = await operations.create(stationCall: 'ki2d', title: 'Test op');
    expect(op.stationCall, 'KI2D');

    final all = await operations.watchAll().first;
    expect(all, hasLength(1));
    expect(all.first.title, 'Test op');
    expect(all.first.qsoCount, 0);
  });

  test('adding QSOs updates counters and indexed columns', () async {
    final op = await operations.create(stationCall: 'KI2D');

    await qsos.add(op.uuid, {
      'our': {'call': 'KI2D', 'sent': '59'},
      'their': {'call': 'W1AW', 'sent': '57'},
      'freq': 14285.0,
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': 1000,
    });
    await qsos.add(op.uuid, {
      'our': {'call': 'KI2D', 'sent': '599'},
      'their': {'call': 'EA4XYZ', 'sent': '579'},
      'freq': 7025.0,
      'band': '40m',
      'mode': 'CW',
      'startAtMillis': 2000,
    });

    final updated = await operations.get(op.uuid);
    expect(updated!.qsoCount, 2);
    expect(updated.startAtMillisMin, 1000);
    expect(updated.startAtMillisMax, 2000);

    final list = await qsos.watchForOperation(op.uuid).first;
    expect(list.map((q) => q.theirCall), ['W1AW', 'EA4XYZ']);
    expect(list.first.freq, 14285.0);
    expect(list.first.sentRST, '59');
    expect(list.first.receivedRST, '57');
  });

  test('watch stream emits on new QSOs', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final emissions = <int>[];
    final subscription = qsos.watchForOperation(op.uuid).listen((list) => emissions.add(list.length));

    await pumpEventQueue();
    await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'SSB',
    });
    await pumpEventQueue();

    expect(emissions, containsAllInOrder([0, 1]));
    await subscription.cancel();
  });

  test('soft delete hides QSO and refreshes counters', () async {
    final op = await operations.create(stationCall: 'KI2D');
    final qso = await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
      'mode': 'CW',
    });

    await qsos.softDelete(qso);

    final list = await qsos.watchForOperation(op.uuid).first;
    expect(list, isEmpty);
    final updated = await operations.get(op.uuid);
    expect(updated!.qsoCount, 0);
  });

  test('soft deleted operations disappear from watchAll', () async {
    final op = await operations.create(stationCall: 'KI2D');
    await operations.softDelete(op.uuid);
    expect(await operations.watchAll().first, isEmpty);
  });

  test('a brand-new operation with no QSOs sorts to the top, not the bottom', () async {
    final active = await operations.create(stationCall: 'KI2D', title: 'Active op');
    await qsos.add(active.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 1000});

    // New operation has a NULL startAtMillisMax; SQLite sorts NULLs last in
    // DESC by default, which would otherwise bury it at the end.
    final fresh = await operations.create(stationCall: 'KI2D', title: 'Fresh op');

    final all = await operations.watchAll().first;
    expect(all.map((o) => o.title), [fresh.title, active.title]);
  });

  test('multiple operations with no QSOs sort by createdAtMillis descending', () async {
    final op1 = await operations.create(stationCall: 'KI2D', title: 'First created');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final op2 = await operations.create(stationCall: 'KI2D', title: 'Second created');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final op3 = await operations.create(stationCall: 'KI2D', title: 'Third created');

    final all = await operations.watchAll().first;
    expect(all.map((o) => o.title).take(3), [
      op3.title,
      op2.title,
      op1.title,
    ]);
  });
}
