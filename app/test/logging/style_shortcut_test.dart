// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ⌥U, N1MM's Run/S&P key, as the Operation view hears it
// (docs/design/keyboard-shortcuts.md, logging-fields.md § Operating style).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/operating_style.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices();
    services = harness.services;
    await harness.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    await harness.settings.recordOnboardingShown(OnboardingFlows.operationSheet);
  });

  Future<void> pumpOperation(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final operation = await services.operations.create(stationCall: 'KI2D');
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> optionU(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump(const Duration(milliseconds: 100));
  }

  // The trap: handling it behind the keyer's gate, as the keys beside it
  // are. The style is what every contact records, keyer or no keyer, radio
  // or no radio — and a key pressed mid-pileup says nothing.
  testWidgets('switches Run and S&P with no keyer and no radio, silently', (tester) async {
    await pumpOperation(tester);
    final before = services.statusBar.items.length;
    services.cat.setStyle('A', OperatingStyle.run);
    await optionU(tester);
    expect(services.cat.styleOf('A'), OperatingStyle.normal);
    await optionU(tester);
    expect(services.cat.styleOf('A'), OperatingStyle.run);
    expect(services.statusBar.items.length, before);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets("under SO2R it switches the set the operator is in, and leaves the other's", (tester) async {
    await services.settings.setExperimentEnabled('so2r', true);
    await pumpOperation(tester);
    services.cat.setStyle('A', OperatingStyle.run);
    services.cat.setStyle('B', OperatingStyle.run);
    services.cat.noteOperatorRadio('B');
    await optionU(tester);
    expect((services.cat.styleOf('A'), services.cat.styleOf('B')), (OperatingStyle.run, OperatingStyle.normal));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
