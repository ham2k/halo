// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Enter Sends Messages, the app's half (docs/design/logging-fields.md § Enter
// Sends Messages): what the operation view hands the panel, and what reaches
// the keyer for each message ESM asks for. The panel's half — which step an
// Enter takes — is halo_widgets' logging_controls_esm_test.dart.
//
// Against a real CatService with the placeholder radio, which runs the real
// send queue, so what is asserted is what the queue was handed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

/// Stands in for the `template` hook without booting a JS engine: only
/// `{{qso.call}}` and `{{op.call}}` are filled.
class _TemplateExtensions extends ExtensionService {
  @override
  bool get ready => true;

  @override
  Future<void> start() async {}

  @override
  Future<String?> renderTemplate(
    String template, {
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    int? qsoCount,
    Map<String, dynamic>? log,
  }) async => template.replaceAll('{{qso.call}}', ((qso?['their'] as Map?)?['call'] as String?) ?? '').replaceAll('{{op.call}}', 'KI2D');
}

void main() {
  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices(extensions: _TemplateExtensions());
    services = harness.services;
    await harness.settings.setExperimentEnabled('gato', true);
    await harness.settings.setExperimentEnabled('keyer', true);
    await harness.settings.setExperimentEnabled('esm', true);
    await harness.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    await harness.settings.recordOnboardingShown(OnboardingFlows.operationSheet);
  });

  late String rig;

  Future<void> pumpOperation(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final node = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    rig = node.uuid;
    await tester.runAsync(() => services.cat.connect(rig));
    addTearDown(() => services.cat.disconnect(rig));
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

  /// The view's drift subscriptions schedule their cleanup on a timer, and
  /// the send queue paces on one; the framework reports either as a leak
  /// unless it is allowed to run.
  Future<void> unmount(WidgetTester tester) async {
    services.cat.stopCw();
    await tester.pump(const Duration(seconds: 62));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  EnterSends? enterSends(WidgetTester tester) => tester.widget<LoggingControls>(find.byType(LoggingControls)).session.enterSends?.call();

  const cwDraft = {
    'their': {'call': 'W1AW'},
    'mode': 'CW',
  };

  testWidgets('off, the panel is told so and Enter logs', (tester) async {
    await pumpOperation(tester);
    expect(enterSends(tester), isNull);
    await unmount(tester);
  });

  testWidgets('without its experiment, the switch is ignored and Enter logs', (tester) async {
    // ESM changes what Enter does; a switch left on from an earlier session
    // must not survive the experiment being turned off.
    await services.settings.setExperimentEnabled('esm', false);
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    expect(enterSends(tester), isNull);
    await unmount(tester);
  });

  testWidgets('on, it answers with the side the operator picked', (tester) async {
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true, running: false);
    expect(enterSends(tester)?.running, isFalse);
    await unmount(tester);
  });

  testWidgets('with nothing able to key, ESM is off whatever its switch says', (tester) async {
    // A switch left on while the rig is unplugged must not swallow Enters —
    // the operator would type calls that neither key nor log.
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    await tester.runAsync(() => services.cat.disconnect(rig));
    await tester.pump();
    expect(enterSends(tester), isNull);
    await unmount(tester);
  });

  testWidgets('the messages of one step go out as ONE message, in N1MM order', (tester) async {
    // F5 then F2 then F3 of the seeded set. Keyed as one so the keyer area
    // shows the answer as it is heard, not as a message and a queue.
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    enterSends(tester)!.send([EsmMessage.hisCall, EsmMessage.exchange, EsmMessage.thanks], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'W1AW 5NN TU');
    expect(services.cat.cwProgress.value?.pending, isEmpty);
    await unmount(tester);
  });

  testWidgets('an empty slot is skipped, not refused', (tester) async {
    // A set with no TU must still answer the caller — the contact completes
    // either way, and a missing thanks is the operator's choice.
    await services.settings.setCwMessage(3, '');
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    enterSends(tester)!.send([EsmMessage.hisCall, EsmMessage.exchange, EsmMessage.thanks], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'W1AW 5NN');
    await unmount(tester);
  });

  testWidgets('the draft handed over is what renders, not the view\'s own copy', (tester) async {
    // The log that follows the send wipes the draft; the call must come from
    // the Enter's snapshot or the thanks goes out with no call in it.
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    enterSends(tester)!.send(
      [EsmMessage.hisCall],
      const {
        'their': {'call': 'K1ABC'},
        'mode': 'CW',
      },
    );
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'K1ABC');
    await unmount(tester);
  });
}
