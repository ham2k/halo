// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Developer Mode QSON export: the raw QSON payload (operation + QSOs in one
// JSON file, same shape app-polo exports) must be offered only when developer
// mode is on, and must be generated core-side — no extension runtime needed —
// so it works even while the extension host is still booting.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/export_service.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late SettingsService settings;
  late ExportService exports;
  late Operation operation;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    settings = await SettingsService.load();
    final operations = OperationsRepository(db);
    final qsos = QsosRepository(db);
    // ExtensionService never started: host stays null, so extension-suggested
    // options are empty and any option we see comes from the core.
    exports = ExportService(extensions: ExtensionService(), qsos: qsos, settings: settings);

    final created = await operations.create(stationCall: 'N0CALL', title: 'Test Op');
    await qsos.add(created.uuid, {
      'their': {'call': 'W1AW'},
      'band': '20m',
      'mode': 'SSB',
      'startAtMillis': DateTime.utc(2026, 7, 15, 12).millisecondsSinceEpoch,
    });
    // Re-fetch so startAtMillisMax (stamped by the QSO write) is populated —
    // the QSON filename derives its date from it.
    operation = (await operations.get(created.uuid))!;
  });

  tearDown(() async {
    await db.close();
  });

  test('QSON option is hidden unless developer mode is enabled', () async {
    expect(await exports.getExportOptions(operation), isEmpty);

    await settings.setDeveloperMode(true);
    final options = await exports.getExportOptions(operation);
    expect(options, hasLength(1));
    expect(options.single['exportType'], 'devmode-qson');
    expect(options.single['selectedByDefault'], false);
    expect(options.single['filename'], endsWith('.qson'));
  });

  test('generates a single JSON file with operation data and QSOs, without the extension host', () async {
    await settings.setDeveloperMode(true);
    final options = await exports.getExportOptions(operation);

    final files = await exports.generateExports(operation, options);
    expect(files, hasLength(1));
    expect(files.single['mimeType'], 'application/json');
    expect(files.single['filename'], '2026-07-15.N0CALL.${operation.uuid.split('-').first}.qson');

    final decoded = jsonDecode(files.single['content'] as String) as Map<String, dynamic>;
    final operationData = decoded['operation'] as Map<String, dynamic>;
    expect(operationData['uuid'], operation.uuid);
    expect(operationData['stationCall'], 'N0CALL');
    expect(operationData['title'], 'Test Op');
    final qsoList = decoded['qsos'] as List;
    expect(qsoList, hasLength(1));
    expect((qsoList.single as Map)['their'], {'call': 'W1AW'});
  });
}
