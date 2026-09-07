// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `getHistoryForCall` backs the `call-history` lookup extension's
// `ctx.getHistoryForCall` — the one host call that reads QSOs across every
// operation rather than one. These tests cover the Dart side of that
// bridge; the extension's own field-selection logic is covered by
// `extensions/lookups/call-history/src/buildCallHistoryLookup.test.ts`.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late OperationsRepository operations;
  late QsosRepository qsos;
  late ExtensionService extensions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = HaLoDatabase(NativeDatabase.memory());
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
    await qsos.add(opA.uuid, {'their': {'call': 'KI2D'}, 'startAtMillis': 1000});
    final newer = await qsos.add(opB.uuid, {'their': {'call': 'KI2D'}, 'startAtMillis': 2000});
    await qsos.add(opA.uuid, {'their': {'call': 'W1AW'}, 'startAtMillis': 3000});

    final result = await extensions.debugHandleHostCall('getHistoryForCall', {'call': 'ki2d'}) as List;

    expect(result, hasLength(2));
    expect((result.first as Map)['uuid'], newer.uuid);
  });

  test('a QSO carries its own uuid, so the extension can exclude itself from re-enrichment', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    final saved = await qsos.add(op.uuid, {'their': {'call': 'KI2D'}});

    final result = await extensions.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D'}) as List;

    expect((result.single as Map)['uuid'], saved.uuid);
  });

  test('a deleted operation\'s QSOs are excluded, same as historyForCall', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    await qsos.add(op.uuid, {'their': {'call': 'KI2D'}});
    await operations.softDelete(op.uuid);

    final result = await extensions.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D'});

    expect(result, isEmpty);
  });

  test('caps at a handful of rows — the extension only ever reads the most recent match', () async {
    final op = await operations.create(stationCall: 'N0DEV');
    for (var i = 0; i < 8; i++) {
      await qsos.add(op.uuid, {'their': {'call': 'KI2D'}, 'startAtMillis': i});
    }

    final result = await extensions.debugHandleHostCall('getHistoryForCall', {'call': 'KI2D'}) as List;

    expect(result, hasLength(5));
  });
}
