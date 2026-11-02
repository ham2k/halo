// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SWAP, the logging panel's half (docs/design/logging-fields.md § SO2R and
// docs/design/cat.md § Radio B, for SO2R): when it is refused, and what the
// operator is told. The sets' half — entries and VFOs moving — is
// halo_widgets' logging_controls_so2r_swap_test.dart; the radios' is
// cat/cat_so2r_swap_test.dart.
//
// Against a real CatService with two placeholder radios as Radio A and B.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart' show LocalRadio;
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  late HaLoServices services;
  late String rigA, rigB;

  setUp(() async {
    final harness = await makeHaLoServices();
    services = harness.services;
    await harness.settings.setExperimentEnabled('keyer', true);
    await harness.settings.setExperimentEnabled('so2r', true);
    await harness.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    await harness.settings.recordOnboardingShown(OnboardingFlows.operationSheet);
  });

  /// An operation under SO2R, Radio A on 14025 and Radio B on 7025, with a
  /// call in each set.
  Future<void> pumpSo2r(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Future<String> rig(String name) async {
      final node = await services.cat.addNode(typeKey: 'placeholder-radio', name: name, config: placeholderRadioModel.variants.single.defaultConfig);
      await tester.runAsync(() => services.cat.connect(node.uuid));
      addTearDown(() => services.cat.disconnect(node.uuid));
      return node.uuid;
    }

    rigA = await rig('Left Rig');
    rigB = await rig('Right Rig');
    await services.cat.setRadio1(LocalRadio(rigA));
    await services.cat.setRadio2(rigB);
    final operation = await services.operations.create(stationCall: 'KI2D');
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    services.radio.setVfo('vfoA', freq: 14025, mode: 'CW');
    services.radio.setVfo('vfoB', freq: 7025, mode: 'CW');
    await tester.pump();
    await tester.enterText(callField('A'), 'W1AW');
    await tester.enterText(callField('B'), 'K1ABC');
    await tester.pump();
  }

  /// The view's drift subscriptions and the send queue clean up on timers.
  Future<void> unmount(WidgetTester tester) async {
    services.cat.stopCw();
    await tester.pump(const Duration(seconds: 62));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Future<void> swap(WidgetTester tester) async {
    await tester.widget<LoggingControls>(find.byKey(const ValueKey('set-B'))).commands.onCommandAction!('swapRadios');
    await tester.pump();
    await tester.pump();
  }

  String callIn(WidgetTester tester, String set) => tester.widget<TextField>(callField(set)).controller!.text;
  String? said() => services.statusBar.items.where((item) => item.key == 'commandAction').firstOrNull?.text;
  (double?, double?) vfos() => (services.radio.vfo('vfoA').freq, services.radio.vfo('vfoB').freq);

  testWidgets('SWAP moves each entry and each radio, and says so', (tester) async {
    await pumpSo2r(tester);

    await swap(tester);

    expect((callIn(tester, 'A'), callIn(tester, 'B')), ('K1ABC', 'W1AW'));
    expect(vfos(), (7025, 14025));
    expect(said(), t.commands.swapDone);
    await unmount(tester);
  });

  // The trap: a radio retuned under a message sends the rest of it on the
  // other radio's frequency — the refusal is what keeps SWAP from ever
  // moving a radio under RF, and a refusal that moved anything first would
  // not.
  for (final radio in ['A', 'B']) {
    testWidgets('a message going out on Radio $radio refuses SWAP, with nothing moved', (tester) async {
      await pumpSo2r(tester);
      services.cat.keyer(radio).sendCw('CQ TEST');
      await tester.pump();

      await swap(tester);

      expect((callIn(tester, 'A'), callIn(tester, 'B')), ('W1AW', 'K1ABC'));
      expect(vfos(), (14025, 7025));
      expect(said(), anyOf(t.commands.swapOnAir(radio: radio), t.commands.swapKeyerBusy(radio: radio)));
      await unmount(tester);
    });
  }

  // A rig that is not connected cannot be told where to go: its entry and
  // VFO move, and when it connects its own frequency wins over the entry's.
  // The operator has to hear that from SWAP, not find it out at the log.
  testWidgets('a radio that is not connected does not stop SWAP, and is named', (tester) async {
    await pumpSo2r(tester);
    await tester.runAsync(() => services.cat.disconnect(rigB));
    await tester.pump();

    await swap(tester);

    expect((callIn(tester, 'A'), callIn(tester, 'B')), ('K1ABC', 'W1AW'));
    expect(said(), t.commands.swapNotConnected(radio: 'B'));
    await unmount(tester);
  });
}

Finder callField(String set) => find.descendant(of: find.byKey(ValueKey('set-$set')), matching: find.widgetWithText(TextField, 'Their call'));
