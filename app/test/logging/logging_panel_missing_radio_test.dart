// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel says what its contact lacks of the radio state in the
// FYI area (docs/design/logging-fields.md § The FYI area): the controls
// report it, the panel posts it as its radio's alerts.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/fyi_service.dart';
import 'package:ham2k_logger/views/operation/logging_panel.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late Operation operation;

  setUp(() async {
    final harness = await makeHaLoServices();
    services = harness.services;
    operation = await services.operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
  });

  Widget wrap(Widget child) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 800, child: child)),
    ),
  );

  LoggingPanel panel() =>
      LoggingPanel(operation: operation, services: services, qsos: const [], loggingControls: const [], onCommandAction: (action, [params]) async {});

  testWidgets('an untuned radio posts No Band as radio A\'s high-priority alert, withdrawn once it is tuned', (tester) async {
    await tester.pumpWidget(wrap(panel()));
    await tester.pump(const Duration(milliseconds: 100));

    final band = services.fyi.messageFor('band:A');
    expect(band, isNotNull, reason: 'the fresh install has no VFO');
    expect((band!.category, band.priority, band.radio), (FyiCategory.alert, FyiPriority.high, 'A'));
    // Through the strings package: the pill it replaces spoke the operator's
    // language, and a hardcoded "No Band" would pass every other check here.
    expect(band.text, t.loggingControls.missingBand);
    expect(band.dismissible, isFalse, reason: 'a condition the band pick answers; no tap puts it away');
    expect(band.onTap, isNotNull, reason: 'the tap opens the Radio control instead');
    expect(services.fyi.messageFor('mode:A'), isNotNull, reason: 'the field\'s SSB is a default nobody chose, which logging refuses too');

    services.radio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(services.fyi.messageFor('band:A'), isNull);
    expect(services.fyi.messageFor('mode:A'), isNull);

    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pump(const Duration(seconds: 5)); // drain the controls' debounce/clock timers
  });

  testWidgets('an emptied mode posts No Mode under its own key, and a tap on the pill opens the Radio control', (tester) async {
    // A tuned VFO: the Radio control does not open on mount, so the tap is
    // what opens it.
    services.radio.setVfo('vfoA', freq: 14285, mode: '');
    await tester.pumpWidget(wrap(panel()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(services.fyi.messageFor('band:A'), isNull, reason: 'tuned');
    final mode = services.fyi.messageFor('mode:A');
    expect(mode, isNotNull, reason: 'the mode branch posts under its own key');
    expect(mode!.text, t.loggingControls.missingMode);
    expect(mode.radio, 'A');
    expect(find.text(t.loggingControls.frequency), findsNothing, reason: 'sanity: the Radio control is closed');

    mode.onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The trap: a pill no tap puts away that also ignores the press.
    expect(find.text(t.loggingControls.frequency), findsOneWidget, reason: 'the tap opens the pick that answers it');

    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pump(const Duration(seconds: 5)); // drain the controls' debounce/clock timers
  });
}
