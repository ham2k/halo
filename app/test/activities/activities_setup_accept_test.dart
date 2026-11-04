// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// OK on the Setup sheet accepts the setup, which moves a `new` operation to
// `ready`; every other way out only saves. Escape, back and a tap outside the
// sheet run the same save as OK, so the one flag between them is all that
// keeps an operator who opened Setup and backed out from being told the log
// is set up and waiting for START.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/activities_view.dart';

import '../support/halo_test_support.dart';

Future<(HaLoServices, Operation)> _harness() async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService(await SharedPreferences.getInstance());
  final services = HaLoServices(
    HaLoDatabase(NativeDatabase.memory()),
    settings,
    extensions: ExtensionServiceWithFakeHost(FakeExtensionHost(const {}))..settings = settings,
  );
  final created = await services.operations.create(stationCall: 'N0DEV');
  return (services, Operation(uuid: created.uuid, data: const {'refs': []}));
}

Future<OperationSheetState> _pumpSheet(WidgetTester tester, HaLoServices services, Operation operation) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: OperationSheet(services: services, operation: operation),
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return tester.state<OperationSheetState>(find.byType(OperationSheet));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OK accepts the setup: a new operation is ready', (tester) async {
    final (services, operation) = await tester.runAsync(_harness) as (HaLoServices, Operation);
    final sheet = await _pumpSheet(tester, services, operation);

    await tester.runAsync(() => sheet.saveAndClose(accept: true));

    final stored = (await tester.runAsync(() => services.operations.get(operation.uuid)))!;
    expect(stored.status, OperationStatus.ready);
  });

  testWidgets('backing out of the sheet saves and accepts nothing', (tester) async {
    final (services, operation) = await tester.runAsync(_harness) as (HaLoServices, Operation);
    final sheet = await _pumpSheet(tester, services, operation);

    await tester.runAsync(sheet.saveOrLeave);

    final stored = (await tester.runAsync(() => services.operations.get(operation.uuid)))!;
    expect(stored.status, OperationStatus.fresh);
  });
}
