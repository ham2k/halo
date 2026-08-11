// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Station Configuration's "Track Station Info for each QSO" (HALO-263)
// captures rig/antenna/key at save time through LoggingControls'
// decorateQsoBeforeSave hook — the same seam extensions use to project their
// own data onto a QSO just before it's written.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/logging_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late Operation operation;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    services = HaLoServices(db, settings);
    operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
    await services.settings.setExperimentEnabled('gato', true);
  });

  Widget wrap(Widget child) => TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, height: 800, child: child),
          ),
        ),
      );

  LoggingPanel panel() => LoggingPanel(
        operation: operation,
        services: services,
        qsos: const [],
        loggingControls: const [],
        onCommandAction: (action, [params]) async {},
      );

  Future<Map<String, dynamic>> decorate(WidgetTester tester, Map<String, dynamic> qso) {
    final controls = tester.widget<LoggingControls>(find.byType(LoggingControls));
    return controls.decorateQsoBeforeSave!(qso);
  }

  testWidgets('captures only the tracked fields, leaving the rest of the QSO alone', (tester) async {
    await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Test Radio');
    await services.cat.addNode(typeKey: antennaModel.variants.first.key, name: 'Dipole');
    await services.cat.addNode(typeKey: keyModel.variants.first.key, name: 'Bug');
    await services.settings.setCurrentPower(100);
    await services.settings.setTrackStationInfo(true);
    await services.settings.setStationInfoTrackedFields({'rig', 'antenna', 'power'});

    await tester.pumpWidget(wrap(panel()));
    await tester.pump(const Duration(milliseconds: 100));

    final result = await decorate(tester, {
      'our': {'call': 'N0CALL'},
      'their': {'call': 'W1AW'},
    });

    expect(result['our']['rig'], 'Test Radio');
    expect(result['our']['antenna'], 'Dipole');
    expect(result['power'], 100, reason: 'top-level, alongside freq/band/mode — QSON convention, not our.power');
    expect(result['our']['call'], 'N0CALL', reason: 'existing our fields must survive the merge');
    expect(result['our'].containsKey('key'), isFalse, reason: 'key was not in stationInfoTrackedFields');
    expect(result['their']['call'], 'W1AW');
  });

  testWidgets('does not capture power when unset, even if tracked', (tester) async {
    await services.settings.setTrackStationInfo(true);
    await services.settings.setStationInfoTrackedFields({'power'});
    // currentPower left at its default (null/unset).

    await tester.pumpWidget(wrap(panel()));
    await tester.pump(const Duration(milliseconds: 100));

    final result = await decorate(tester, {'our': {}});

    expect(result.containsKey('power'), isFalse);
  });

  testWidgets('captures nothing when tracking is off', (tester) async {
    await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Test Radio');
    await services.settings.setStationInfoTrackedFields({'rig'});
    // trackStationInfo left at its default (off).

    await tester.pumpWidget(wrap(panel()));
    await tester.pump(const Duration(milliseconds: 100));

    final result = await decorate(tester, {'our': {}});

    expect(result['our'].containsKey('rig'), isFalse);
  });

  testWidgets('captures nothing for a field whose designation is None', (tester) async {
    await services.settings.setTrackStationInfo(true);
    await services.settings.setStationInfoTrackedFields({'rig', 'antenna'});
    // No radio, no antenna ever added — nothing to designate.

    await tester.pumpWidget(wrap(panel()));
    await tester.pump(const Duration(milliseconds: 100));

    final result = await decorate(tester, {'our': {}});

    expect(result['our'].containsKey('rig'), isFalse);
    expect(result['our'].containsKey('antenna'), isFalse);
  });
}
