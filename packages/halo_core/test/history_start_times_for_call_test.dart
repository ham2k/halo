// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `historyStartTimesForCall` backs the call-info's worked-before pill, and it
// is its own SQL rather than `historyForCall` mapped — so every rule the list
// applies in Dart has to be re-stated in the query, and each one can silently
// drift on its own. These tests pin each rule against the list.

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

  tearDown(() async => db.close());

  test('counts contacts across operations, matching the list, case-insensitively', () async {
    final a = await operations.create(stationCall: 'N0DEV');
    final b = await operations.create(stationCall: 'N0DEV');
    await qsos.add(a.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'startAtMillis': 1000,
    });
    await qsos.add(a.uuid, {
      'their': {'call': 'W1AW'},
      'band': '40m',
      'startAtMillis': 3000,
    });
    await qsos.add(b.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'startAtMillis': 2000,
    });
    await qsos.add(b.uuid, {
      'their': {'call': 'K2ABC'},
      'band': '20m',
    });

    expect(await qsos.historyStartTimesForCall('w1aw'), [3000, 2000, 1000]);
    // The same rows the list answers with, in the list's order.
    expect(await qsos.historyStartTimesForCall('W1AW'), [for (final q in await qsos.historyForCall('W1AW')) q.startAtMillis]);
    expect(await qsos.historyStartTimesForCall(''), isEmpty);
    expect((await qsos.historyStartTimesForCall('NOBODY')).length, 0);
  });

  test('a soft-deleted QSO and a deleted operation both leave the count', () async {
    final live = await operations.create(stationCall: 'N0DEV');
    final doomed = await operations.create(stationCall: 'N0DEV');
    await qsos.add(live.uuid, {
      'their': {'call': 'W1AW'},
    });
    final byHand = await qsos.add(live.uuid, {
      'their': {'call': 'W1AW'},
    });
    await qsos.add(doomed.uuid, {
      'their': {'call': 'W1AW'},
    });
    expect((await qsos.historyStartTimesForCall('W1AW')).length, 3);

    await qsos.softDelete(byHand);
    expect((await qsos.historyStartTimesForCall('W1AW')).length, 2);

    await operations.softDelete(doomed.uuid);
    expect((await qsos.historyStartTimesForCall('W1AW')).length, 1);
  });

  test('event markers are not contacts, but a band-less QSO still is', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    // A marker that happens to carry a callsign must not count; a QSO logged
    // with no band at all must — `band != 'event'` is NULL for it, not true,
    // and a query written that way drops it.
    await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
      'band': 'event',
      'event': {'event': 'break'},
    });
    await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
    });

    expect((await qsos.historyStartTimesForCall('W1AW')).length, 1);
  });

  test('excludingUuid leaves the QSO being edited out of its own history', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    final earlier = await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
    });
    final editing = await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
    });

    expect((await qsos.historyStartTimesForCall('W1AW', excludingUuid: editing.uuid)).length, 1);
    expect((await qsos.historyStartTimesForCall('W1AW', excludingUuid: earlier.uuid)).length, 1);
    // Excluding a uuid that is not this call's changes nothing.
    expect((await qsos.historyStartTimesForCall('W1AW', excludingUuid: 'not-a-qso')).length, 2);
  });
}
