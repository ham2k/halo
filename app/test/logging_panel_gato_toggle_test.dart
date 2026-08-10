// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The 'gato' experiment can flip while LoggingPanel stays mounted (e.g.
// toggled from the Experiments panel over this one). _onSettingsChanged
// has to notice and keep the cat listener's attachment — and _gatoEnabled,
// which initState/dispose use instead of re-reading the live flag — in
// sync right away: otherwise a toggle-off leaks the listener past dispose
// (a later CatService.notifyListeners() then calls setState() on a
// disposed State), and a toggle-on leaves the Station Configuration fields
// frozen at their initState values for the panel's whole lifetime.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
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

  testWidgets('turning the experiment off after mount does not leak the cat listener past dispose', (tester) async {
    await services.settings.setExperimentEnabled('gato', true);
    await tester.pumpWidget(wrap(panel()));
    await tester.pump(const Duration(milliseconds: 100));

    await services.settings.setExperimentEnabled('gato', false);
    await tester.pump();

    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pump(const Duration(seconds: 5)); // drain the controls' debounce/clock timers

    // A leaked listener would call setState() on the now-disposed panel the
    // next time anything touches CatService — addNode is a real trigger,
    // not just a bare notifyListeners() a mock could paper over.
    await expectLater(
      () => services.cat.addNode(typeKey: 'kenwood-serial', name: 'Test Radio'),
      returnsNormally,
    );
  });

  testWidgets('turning the experiment on while mounted starts reflecting live CAT state', (tester) async {
    await tester.pumpWidget(wrap(panel()));
    await tester.pump(const Duration(milliseconds: 100));

    LoggingControls controls() => tester.widget<LoggingControls>(find.byType(LoggingControls));
    expect(controls().hasConfiguredRadio, isFalse);

    await services.settings.setExperimentEnabled('gato', true);
    await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Test Radio');
    await tester.pump();

    expect(controls().hasConfiguredRadio, isTrue);
    expect(controls().radioName, 'Test Radio');
  });

  testWidgets('turning the experiment on with no radio ever configured still reveals the button', (tester) async {
    // Distinct from the test above: no addNode here. _onCatChanged's own
    // dirty-check only compares has/connected/name, which all stay
    // false/false/null when no radio exists either side of the toggle — so
    // _gatoEnabled changing has to trigger the rebuild on its own, not rely
    // on _onCatChanged noticing something else moved too.
    await tester.pumpWidget(wrap(panel()));
    await tester.pump(const Duration(milliseconds: 100));

    LoggingControls controls() => tester.widget<LoggingControls>(find.byType(LoggingControls));
    expect(controls().onOpenStationConfig, isNull);

    await services.settings.setExperimentEnabled('gato', true);
    await tester.pump();

    expect(controls().onOpenStationConfig, isNotNull);
  });
}
