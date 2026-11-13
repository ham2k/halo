// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `listOperations` is how an extension finds the operations at all: every
// other log read takes a uuid it has no other way to learn.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:ham2k_logger/services/extensions/extension_service.dart';
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

  tearDown(() async => db.close());

  test('answers [] when no log is attached', () async {
    expect(await ExtensionService().debugHandleHostCall('listOperations', {}), isEmpty);
  });

  test('lists the most recent first, leaves a deleted one out, and says which are open and which is in front', () async {
    final older = await operations.create(stationCall: 'N0DEV', userTitle: 'Field Day');
    final newer = await operations.create(stationCall: 'N0DEV/P');
    final gone = await operations.create(stationCall: 'N0DEV');
    await qsos.add(older.uuid, {
      'their': {'call': 'K1AB'},
      'band': '20m',
      'startAtMillis': 1000,
    });
    await qsos.add(newer.uuid, {
      'their': {'call': 'K2AB'},
      'band': '40m',
      'startAtMillis': 5000,
    });
    await operations.softDelete(gone.uuid);
    extensions
      ..openOperationUuids = (() => [older.uuid, newer.uuid])
      ..frontOperationUuid = (() => newer.uuid);

    final result = (await extensions.debugHandleHostCall('listOperations', {'extensionKey': 'mcp'}) as List).cast<Map>();
    expect(result.map((o) => o['uuid']), [newer.uuid, older.uuid]);
    expect(result.first, containsPair('front', true));
    expect(result.last, allOf(containsPair('title', 'Field Day'), containsPair('open', true), containsPair('front', false), containsPair('qsoCount', 1)));
    expect(result.last, containsPair('startAtMillisMax', 1000));
  });

  test('with open, answers the open ones alone, the front one first, however old, and never a deleted one', () async {
    final front = await operations.create(stationCall: 'N0DEV', userTitle: 'Old one, opened again');
    final behind = await operations.create(stationCall: 'N0DEV');
    // Still shown in a view, deleted from another device since.
    final gone = await operations.create(stationCall: 'N0DEV');
    await operations.softDelete(gone.uuid);
    for (var i = 0; i < 3; i++) {
      await operations.create(stationCall: 'N0DEV');
    }
    extensions
      ..openOperationUuids = (() => [gone.uuid, behind.uuid, front.uuid])
      ..frontOperationUuid = (() => front.uuid);

    final result = (await extensions.debugHandleHostCall('listOperations', {'open': true}) as List).cast<Map>();
    expect(result.map((o) => o['uuid']), [front.uuid, behind.uuid]);
    expect(result.first, containsPair('front', true));
    await expectLater(extensions.debugHandleHostCall('listOperations', {'open': 'yes'}), throwsA(isA<ExtensionHostException>()));
  });

  test('answers at most limit, and rejects a limit out of range or an option it does not know', () async {
    for (var i = 0; i < 3; i++) {
      await operations.create(stationCall: 'N0DEV');
    }
    expect(await extensions.debugHandleHostCall('listOperations', {'limit': 2}), hasLength(2));
    for (final params in [
      {'limit': 0},
      {'limit': 501},
      {'limit': '5'},
      {'limt': 5},
    ]) {
      await expectLater(extensions.debugHandleHostCall('listOperations', params), throwsA(isA<ExtensionHostException>()), reason: '$params');
    }
  });
}
