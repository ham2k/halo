// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's half of the operation lifecycle: which logs it offers
// one for, and what it counts as the operator being at the radio.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/logging_scope.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/logging_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hour = 3600 * 1000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late HaLoServices services;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    db = HaLoDatabase(NativeDatabase.memory());
    services = HaLoServices(db, settings);
    await settings.setExperimentEnabled('cycle', true);
  });

  tearDown(() => db.close());

  Widget panel(Operation operation, List<Qso> qsos, {LoggingScope scope = LoggingScope.operation}) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: LoggingPanel(
          operation: operation,
          services: services,
          qsos: qsos,
          loggingControls: const [],
          onCommandAction: (action, [params]) async {},
          scope: scope,
        ),
      ),
    ),
  );

  testWidgets('chasing offers no lifecycle', (tester) async {
    // The chase log is no operation: what the panel is handed has no uuid,
    // reads as never started, and its START fails with nothing to start.
    final created = await tester.runAsync(() => services.operations.create(stationCall: 'N0CALL'));
    await tester.pumpWidget(panel(created!, const []));
    await tester.pump();
    expect(find.text('Mark the start'), findsOneWidget, reason: 'an unstarted operation offers START');

    const chasing = Operation(uuid: '', data: {'stationCall': 'N0CALL'});
    await tester.pumpWidget(panel(chasing, const [], scope: LoggingScope.chase));
    await tester.pump();
    expect(find.text('Mark the start'), findsNothing);
  });

  testWidgets('opening a quiet log is not logging into it', (tester) async {
    // The log arrives from a stream, so the panel's first build has none of
    // it and the next has all of it. Counted as a contact logged, that
    // growth holds a log three hours quiet open for half an hour.
    final operation = await tester.runAsync(() async {
      final created = await services.operations.create(stationCall: 'N0CALL');
      await services.operations.setStatus(created.uuid, OperationStatus.active, atMillis: nowMillis() - 3 * _hour);
      await services.qsos.add(created.uuid, {
        'their': {'call': 'W1AW'},
        'mode': 'CW',
        'band': '20m',
        'startAtMillis': nowMillis() - 3 * _hour,
      });
      return (await services.operations.get(created.uuid))!;
    });
    final qsos = await tester.runAsync(() => services.qsos.forOperation(operation!.uuid));

    await tester.pumpWidget(panel(operation!, const []));
    await tester.pumpWidget(panel(operation, qsos!));
    await tester.pump();
    expect(find.textContaining('Paused for'), findsOneWidget);
  });
}
