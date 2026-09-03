// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Info panel's history rows say where a past QSO was made from — the
// activation references of ITS operation, read off that operation's refs,
// because the cached title fragments exist only on the device that computed
// them and a synced log has none. A row from an operation that activated
// nothing says nothing, and the current operation's rows never say it.
//
// The refs an operation carries alongside its activations are the contest it
// is running (and, in an imported log, a stray hunting-type ref); a place
// line naming either would be wrong.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/call_info_panel.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> buildServices() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
    return HaLoServices(db, settings, extensions: extensions);
  }

  setUpAll(initializeDateFormatting);

  testWidgets('a past QSO names the park its operation activated; others say nothing', (tester) async {
    final services = await buildServices();
    final current = await services.operations.create(stationCall: 'N0DEV');
    final park = await services.operations.create(stationCall: 'N0DEV');
    await services.operations.saveData(Operation(uuid: park.uuid, data: {
      ...park.data,
      'refs': [
        {'type': 'potaActivation', 'ref': 'US-1234', 'name': 'North Lake SP'},
        {'type': 'arrlDx', 'ref': 'arrl-dx-2026'},
        {'type': 'pota', 'ref': 'US-9999', 'name': 'A Hunted Park'},
      ],
    }));
    final plain = await services.operations.create(stationCall: 'N0DEV');
    for (final (op, start) in [(current, 3000), (park, 2000), (plain, 1000)]) {
      await services.qsos.add(op.uuid, {'their': {'call': 'W1AW'}, 'band': '20m', 'startAtMillis': start});
    }

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: CallInfoPanel(operation: current, services: services, call: 'W1AW', guess: const {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('from US-1234 North Lake SP'), findsOneWidget);
    // Exactly one "from" line: not the contest, not the hunted park, not the
    // plain operation, and not the current operation's own row.
    expect(find.textContaining('from '), findsOneWidget);
  });
}
