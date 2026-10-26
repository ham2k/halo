// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two indexes the write path and the sync round lean on, proven by the
// plans SQLite picks for the REAL queries. Without them the unsynced batch
// is a scan of the whole log and a sort, three times a sync round, and the
// live counters read every row of an operation to test `deleted` and `band`
// after the `(operation, start_at_millis)` index found them. The SQL is
// captured from the repositories through drift's interceptor, so a query
// that drifts away from its index fails here, not on an operator's log.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

class _Capture extends QueryInterceptor {
  final statements = <(String, List<Object?>)>[];

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor, String statement, List<Object?> args) {
    statements.add((statement, args));
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  late HaLoDatabase db;
  late _Capture capture;
  late QsosRepository qsos;
  late String operationUuid;

  setUp(() async {
    capture = _Capture();
    db = HaLoDatabase(NativeDatabase.memory().interceptWith(capture));
    qsos = QsosRepository(db);
    final created = await OperationsRepository(db).create(stationCall: 'N0CALL');
    operationUuid = created.uuid;
    for (var i = 0; i < 3; i++) {
      await qsos.add(operationUuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': 1000 + i,
      });
    }
    capture.statements.clear();
  });

  tearDown(() => db.close());

  /// The plan SQLite picks for the latest SELECT the repositories ran with
  /// [fragment] in it, as one string of its steps.
  Future<String> planOf(String fragment) async {
    final (sql, args) = capture.statements.lastWhere((s) => s.$1.contains(fragment));
    final rows = await db.customSelect('EXPLAIN QUERY PLAN $sql', variables: [for (final arg in args) Variable(arg)]).get();
    return rows.map((row) => row.data['detail']).join('\n');
  }

  test('the unsynced batch walks its own index in send order: no scan, no sort', () async {
    await qsos.unsyncedBatch(50);

    final plan = await planOf('synced');
    expect(plan, contains('USING INDEX qsos_synced_start'));
    expect(plan, isNot(contains('SCAN')));
    expect(plan, isNot(contains('TEMP B-TREE')));
  });

  test("an operation's counters come from the covering index, without reading a row", () async {
    await qsos.refreshOperationCounters(operationUuid);

    expect(await planOf('MIN('), contains('USING COVERING INDEX qsos_operation_counters'));
  });

  test('the live count behind a resumed read comes from the covering index too', () async {
    // The count is taken only on a read that resumes from a cursor; the
    // first read has none and reads the whole log instead.
    final first = await qsos.changesSince(operationUuid, null);
    await qsos.add(operationUuid, {
      'their': {'call': 'K1ABC'},
      'band': '40m',
      'mode': 'CW',
      'startAtMillis': 2000,
    });
    capture.statements.clear();
    await qsos.changesSince(operationUuid, first.cursor);

    expect(await planOf('COUNT(*)'), contains('USING COVERING INDEX qsos_operation_counters'));
  });
}
