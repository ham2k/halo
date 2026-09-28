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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

/// Stands in for the `template` hook without booting a JS engine: only
/// `{{qso.call}}` and `{{op.call}}` are filled, and `{%bad%}` fails to parse.
class _TemplateExtensions extends ExtensionService {
  @override
  bool get ready => true;

  /// The `keyer` argument of the last render — which message is being sent.
  Map<String, dynamic>? lastKeyer;

  @override
  Future<void> start() async {}

  @override
  Future<String?> renderTemplate(
    String template, {
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    int? qsoCount,
    Map<String, dynamic>? log,
    Map<String, dynamic>? keyer,
  }) async => template.contains('{%bad%}')
      ? throw const TemplateError('bad')
      : (lastKeyer = keyer, template).$2.replaceAll('{{qso.call}}', ((qso?['their'] as Map?)?['call'] as String?) ?? '').replaceAll('{{op.call}}', 'KI2D');
}

void main() {
  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices(extensions: _TemplateExtensions());
    services = harness.services;
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

  // `current` is what stops a message including itself: without it, F3
  // naming `{{ keyer.msg3 }}` would expand once more before the chain
  // noticed, and key its own text twice.
  testWidgets('a message is rendered knowing which one it is, beside the whole set', (tester) async {
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    enterSends(tester)!.send([EsmMessage.hisCall], cwDraft);
    await tester.pump();
    await tester.pump();
    final keyer = (services.extensions as _TemplateExtensions).lastKeyer;
    expect(keyer?['current'], 5);
    expect(keyer?['messages'], services.settings.activeCwMessageSet.messages);
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

  // The thanks closes the contact and speaks to the next one: on a stack,
  // "TU {{qso.call}}" rendered at the keypress would thank the station just
  // logged instead of calling the one up next. It still has to go out LAST,
  // though it renders after the log — ahead of the exchange is gibberish.
  testWidgets('a step that logs keys its thanks against the entry the log left, after the rest', (tester) async {
    await services.settings.setCwMessage(3, 'TU {{qso.call}}');
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    final logged = Completer<Map<String, dynamic>?>();
    enterSends(tester)!.send([EsmMessage.hisCall, EsmMessage.exchange, EsmMessage.thanks], cwDraft, logged: logged.future);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'W1AW 5NN', reason: 'the thanks waits for the log');
    expect(services.cat.cwProgress.value?.pending, isEmpty);

    logged.complete(const {
      'their': {'call': 'K1ABC'},
      'mode': 'CW',
    });
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'W1AW 5NN');
    expect(services.cat.cwProgress.value?.pending, ['TU K1ABC']);
    await unmount(tester);
  });

  // Enter pressed twice before the first CQ is over must not leave a second
  // CQ waiting behind it — the operator hears one and the rig keys two.
  // Only the SAME message is held back: AGN? behind the exchange is the next
  // thing to say, not a repeat.
  testWidgets('an Enter does not queue a message already keying or waiting', (tester) async {
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    final esm = enterSends(tester)!;
    esm.send([EsmMessage.hisCall, EsmMessage.exchange], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'W1AW 5NN');

    esm.send([EsmMessage.hisCall, EsmMessage.exchange], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.pending, isEmpty, reason: 'the same message, still keying');

    esm.send([EsmMessage.again], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.pending, ['AGN?'], reason: 'a different message queues');

    esm.send([EsmMessage.again], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.pending, ['AGN?'], reason: 'and is itself not queued twice');
    await unmount(tester);
  });

  // Every thanks is the same `TU`. Typed ahead, the next contact's thanks
  // finds the last one still waiting — and deduped against it, the second
  // station would never be thanked.
  testWidgets('each contact gets its own thanks, even with the last one still queued', (tester) async {
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    final esm = enterSends(tester)!;
    const next = {
      'their': {'call': ''},
      'mode': 'CW',
    };
    esm.send([EsmMessage.hisCall, EsmMessage.exchange, EsmMessage.thanks], cwDraft, logged: Future.value(next));
    await tester.pump();
    await tester.pump();
    esm.send(
      [EsmMessage.hisCall, EsmMessage.exchange, EsmMessage.thanks],
      const {
        'their': {'call': 'K2XX'},
        'mode': 'CW',
      },
      logged: Future.value(next),
    );
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'W1AW 5NN');
    expect(services.cat.cwProgress.value?.pending, ['TU', 'K2XX 5NN', 'TU']);
    await unmount(tester);
  });

  // "Half an exchange is not an exchange": with F2 failing, the station got
  // neither its call nor its report, and a TU alone would close a contact
  // the other side never had.
  testWidgets('a thanks does not follow a first part that failed to render', (tester) async {
    await services.settings.setCwMessage(2, '{%bad%}');
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    enterSends(tester)!.send([EsmMessage.hisCall, EsmMessage.exchange, EsmMessage.thanks], cwDraft, logged: Future.value(cwDraft));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value, isNull, reason: 'nothing keyed at all');
    await unmount(tester);
  });

  // Only a first part that FAILED holds the thanks back. One that renders to
  // nothing had nothing to say — like an empty slot, which never stopped a
  // contact completing — and withholding the TU for it would do so silently.
  testWidgets('a first part that renders to nothing still lets the thanks through', (tester) async {
    await services.settings.setCwMessage(2, '{{qso.call}}');
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    const blank = {
      'their': {'call': ''},
      'mode': 'CW',
    };
    enterSends(tester)!.send([EsmMessage.hisCall, EsmMessage.exchange, EsmMessage.thanks], blank, logged: Future.value(blank));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'TU');
    await unmount(tester);
  });

  // Enter cancels a CQ's repeat before it sends, so a second Enter that
  // finds the CQ still keying and holds it back must arm the chain again —
  // or the auto-CQ just stops, with nothing on screen to say so.
  testWidgets('a CQ held back as already keying keeps its repeat', (tester) async {
    await services.settings.setCwRepeatDelay(5);
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    final esm = enterSends(tester)!;
    esm.send([EsmMessage.cq], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.keyerRepeatActive.value, isTrue);

    esm.send([EsmMessage.cq], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.pending, isEmpty);
    expect(services.cat.keyerRepeatActive.value, isTrue);
    await unmount(tester);
  });

  testWidgets('a log that failed gets no thanks', (tester) async {
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    enterSends(tester)!.send([EsmMessage.hisCall, EsmMessage.exchange, EsmMessage.thanks], cwDraft, logged: Future.value());
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'W1AW 5NN');
    expect(services.cat.cwProgress.value?.pending, isEmpty);
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
