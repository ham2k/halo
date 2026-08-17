// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `limit` bounds the SQL query itself, not a post-fetch truncation — added
// for `call-history`'s lookup source, which only ever reads the first
// (most recent) row. A caller worked hundreds of times must not ship its
// whole history across the extension bridge for that.

import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

void main() {
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
  });

  tearDown(() async => db.close());

  test('unset, historyForCall is unbounded (existing callers keep their contract)', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    for (var i = 0; i < 7; i++) {
      await qsos.add(op.uuid, {
        'their': {'call': 'W1AW'},
        'startAtMillis': i,
      });
    }
    expect((await qsos.historyForCall('W1AW')).length, 7);
  });

  test('limit caps the result, most recent first', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    for (var i = 0; i < 7; i++) {
      await qsos.add(op.uuid, {
        'their': {'call': 'W1AW'},
        'startAtMillis': i,
      });
    }
    final limited = await qsos.historyForCall('W1AW', limit: 3);
    expect(limited.length, 3);
    // Newest (highest startAtMillis) first — the 6, 5, 4 of the 0..6 range.
    expect(limited.map((q) => q.startAtMillis), [6, 5, 4]);
  });
}
