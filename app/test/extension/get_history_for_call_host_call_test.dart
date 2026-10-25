// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `getHistoryForCall` backs the `call-history` lookup extension's
// `ctx.getHistoryForCall` — the one host call that reads QSOs across every
// operation rather than one. These tests cover the Dart side of that
// bridge; the extension's own field-selection logic is covered by the
// catalog's `ham2k-call-history`, in its `buildCallHistoryLookup.test.ts`.

import 'package:drift/drift.dart' show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts the reads of the qsos table, which is what tells a batch of
/// requests answered together from a queue of them answered one by one.
class _QsoReads extends QueryInterceptor {
  int count = 0;
  final statements = <String>[];

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor executor, String statement, List<Object?> args) {
    if (statement.contains('"qsos"')) {
      count++;
      statements.add(statement);
    }
    return executor.runSelect(statement, args);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _QsoReads reads;
  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late ExtensionService extensions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    reads = _QsoReads();
    db = HaLoDatabase(NativeDatabase.memory().interceptWith(reads));
    operations = OperationsRepository(db);
    qsos = QsosRepository(db);
    extensions = ExtensionService()
      ..operations = operations
      ..qsos = qsos;
  });

  tearDown(() async {
    await db.close();
  });

  test('answers [] when no service is attached', () async {
    final bare = ExtensionService();
    final result = await bare.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D'});
    expect(result, isEmpty);
  });

  test('returns matching QSOs across operations, most recent first, as raw QSON', () async {
    final opA = await operations.create(stationCall: 'N0DEV');
    final opB = await operations.create(stationCall: 'N0DEV');
    await qsos.add(opA.uuid, {
      'their': {'call': 'KI2D'},
      'startAtMillis': 1000,
    });
    final newer = await qsos.add(opB.uuid, {
      'their': {'call': 'KI2D'},
      'startAtMillis': 2000,
    });
    await qsos.add(opA.uuid, {
      'their': {'call': 'W1AW'},
      'startAtMillis': 3000,
    });

    final result = await extensions.debugHandleHostCall('getHistoryForCall', {'call': 'ki2d'}) as List;

    expect(result, hasLength(2));
    expect((result.first as Map)['uuid'], newer.uuid);
  });

  test('a QSO carries its own uuid, so the extension can exclude itself from re-enrichment', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    final saved = await qsos.add(op.uuid, {
      'their': {'call': 'KI2D'},
    });

    final result = await extensions.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D'}) as List;

    expect((result.single as Map)['uuid'], saved.uuid);
  });

  test('a deleted operation\'s QSOs are excluded, same as historyForCall', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    await qsos.add(op.uuid, {
      'their': {'call': 'KI2D'},
    });
    await operations.softDelete(op.uuid);

    final result = await extensions.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D'});

    expect(result, isEmpty);
  });

  test('caps at a handful of rows — the extension only ever reads the most recent match', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    for (var i = 0; i < 8; i++) {
      await qsos.add(op.uuid, {
        'their': {'call': 'KI2D'},
        'startAtMillis': i,
      });
    }

    final result = await extensions.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D'}) as List;

    expect(result, hasLength(5));
  });

  // The rules themselves are halo_core's history_filter_test.dart; these
  // prove the host hands the params to them rather than dropping them.
  test('options narrow the history before the cap', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    await qsos.add(op.uuid, {
      'their': {'call': 'KI2D'},
      'startAtMillis': 0,
      'refs': [
        {'type': 'cwt'},
      ],
    });
    for (var i = 1; i <= 6; i++) {
      await qsos.add(op.uuid, {
        'their': {'call': 'KI2D'},
        'startAtMillis': i,
      });
    }

    final result = await extensions.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D', 'refType': 'cwt'}) as List;

    expect(result.map((qso) => (qso as Map)['startAtMillis']), [0]);
  });

  test('limit raises the cap, up to 50', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    for (var i = 0; i < 60; i++) {
      await qsos.add(op.uuid, {
        'their': {'call': 'KI2D'},
        'startAtMillis': i,
      });
    }

    Future<int> count(int limit) async => (await extensions.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D', 'limit': limit}) as List).length;
    expect(await count(12), 12);
    expect(await count(500), 50);
  });

  // The spot board looks up a batch of callsigns at once, and each lookup
  // asks for its call's history. Answered one query each, a board's worth of
  // them queues, and every other reader of the database — the activity
  // search's nearby parks among them — waits behind it until it times out.
  test('requests landing together share one read, and each gets its own history, capped on its own', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    for (var i = 0; i < 7; i++) {
      await qsos.add(op.uuid, {
        'their': {'call': 'KI2D'},
        'startAtMillis': 100 + i,
      });
    }
    await qsos.add(op.uuid, {
      'their': {'call': 'W1AW'},
      'startAtMillis': 50,
    });
    reads.count = 0;

    final answers = await Future.wait([
      for (final call in ['KI2D', 'w1aw', 'N0NE']) extensions.debugHandleHostCall('getHistoryForCall', {'call': call}),
    ]);

    List<Object?> starts(Object? answer) => [for (final qso in answer! as List) (qso as Map)['startAtMillis']];
    expect(starts(answers[0]), [106, 105, 104, 103, 102]);
    expect(starts(answers[1]), [50]);
    expect(starts(answers[2]), isEmpty);
    expect(reads.count, lessThanOrEqualTo(2), reason: 'the newest of each call picked, then those rows read — not a read per call');
  });

  // The operator's own lookup usually asks alone. The shared query reads
  // every row of every call it names; alone, a station worked thousands of
  // times reads only its newest few, as the index walk stops at the LIMIT.
  test('a request alone is answered by one read that stops at its limit', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    for (var i = 0; i < 7; i++) {
      await qsos.add(op.uuid, {
        'their': {'call': 'KI2D'},
        'startAtMillis': 100 + i,
      });
    }
    reads.count = 0;
    reads.statements.clear();

    final answer = await extensions.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D', 'limit': 2});

    expect([for (final qso in answer as List) (qso as Map)['startAtMillis']], [106, 105]);
    expect(reads.count, 1);
    expect(reads.statements.single, contains('LIMIT'));
  });

  test('requests with different options are not answered by one another\'s query', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    await qsos.add(op.uuid, {
      'their': {'call': 'KI2D'},
      'band': '20m',
      'startAtMillis': 1,
    });
    await qsos.add(op.uuid, {
      'their': {'call': 'KI2D'},
      'band': '40m',
      'startAtMillis': 2,
    });

    final answers = await Future.wait([
      extensions.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D', 'band': '20m'}),
      extensions.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D'}),
    ]);

    expect([for (final qso in answers[0] as List) (qso as Map)['band']], ['20m']);
    expect([for (final qso in answers[1] as List) (qso as Map)['band']], ['40m', '20m']);
  });

  test('a malformed option throws, so the extension\'s promise rejects', () async {
    await expectLater(extensions.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D', 'fromDate': 'last tuesday'}), throwsFormatException);
  });

  test('a malformed option throws even with no log to answer from', () async {
    // Resolving [] there would hide the bad option until the one host that
    // has a log rejects it.
    await expectLater(ExtensionService().debugHandleHostCall('getHistoryForCall', {'call': 'KI2D', 'fromDate': 'last tuesday'}), throwsFormatException);
  });
}
