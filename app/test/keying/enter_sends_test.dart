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
import 'package:ham2k_logger/services/cat/cat_service.dart' show LocalRadio;
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

/// Stands in for the `template` hook without booting a JS engine: only
/// `{{qso.call}}`, `{{qso.notes}}`, `{{next.call}}` and `{{op.call}}` are
/// filled, and `{%bad%}` fails to parse.
class _TemplateExtensions extends ExtensionService {
  @override
  bool get ready => true;

  /// The `keyer` argument of the last render — which message is being sent.
  Map<String, dynamic>? lastKeyer;

  /// Holds every render until completed, so a test can act while one is in
  /// flight; and how many have started.
  Completer<void>? hold;
  int renders = 0;

  @override
  Future<void> start() async {}

  @override
  Future<String?> renderTemplate(
    String template, {
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    Map<String, dynamic>? next,
    int? qsoCount,
    Map<String, dynamic>? log,
    Map<String, dynamic>? keyer,
  }) async {
    renders++;
    await hold?.future;
    return template.contains('{%bad%}')
        ? throw const TemplateError('bad')
        : (lastKeyer = keyer, template).$2
              .replaceAll('{{qso.call}}', ((qso?['their'] as Map?)?['call'] as String?) ?? '')
              .replaceAll('{{qso.notes}}', (qso?['notes'] as String?) ?? '')
              .replaceAll('{{next.call}}', ((next?['their'] as Map?)?['call'] as String?) ?? '')
              .replaceAll('{{op.call}}', 'KI2D');
  }
}

void main() {
  late HaLoServices services;
  late _TemplateExtensions extensions;

  setUp(() async {
    extensions = _TemplateExtensions();
    final harness = await makeHaLoServices(extensions: extensions);
    services = harness.services;
    await harness.settings.setExperimentEnabled('keyer', true);
    await harness.settings.setExperimentEnabled('esm', true);
    await harness.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    await harness.settings.recordOnboardingShown(OnboardingFlows.operationSheet);
  });

  late String rig;

  Future<void> pumpOperation(WidgetTester tester, {String? mode}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final node = await services.cat.addNode(
      typeKey: 'placeholder-radio',
      name: 'Bench Rig',
      config: {...placeholderRadioModel.variants.single.defaultConfig, 'placeholderMode': ?mode},
    );
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

  testWidgets('in a Digital mode ESM is off whatever its switch says, and Enter logs', (tester) async {
    // A switch left on from a CW run must not key CW thanks over an FT8 or
    // RTTY contact, nor swallow the Enter that logs it.
    await pumpOperation(tester, mode: 'RTTY');
    services.cat.setEnterSends(on: true);
    expect(enterSends(tester), isNull);
    await unmount(tester);
  });

  // The trap: taking the air for radio B before asking whether the Enter
  // sends anything — a thanks slot left empty in set B stopping the CQ radio
  // A is calling, with nothing sent in its place.
  testWidgets("under SO2R, an Enter in set B with nothing to send leaves radio A's message going out", (tester) async {
    await services.settings.setExperimentEnabled('so2r', true);
    await services.settings.setCwMessage(3, '');
    await pumpOperation(tester);
    final right = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Right Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    await tester.runAsync(() => services.cat.connect(right.uuid));
    addTearDown(() => services.cat.disconnect(right.uuid));
    await services.cat.setRadio1(LocalRadio(rig));
    await services.cat.setRadio2(right.uuid);
    await tester.pump();
    services.cat.keyer('A').sendCw('CQ TEST');
    services.cat.noteOperatorRadio('B');

    services.cat.setEnterSends(on: true);
    tester.widget<LoggingControls>(find.byKey(const ValueKey('set-B'))).session.enterSends!()!.send([EsmMessage.thanks], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.keyer('A').cwProgress.value?.text, 'CQ TEST');
    await unmount(tester);
  });

  /// Two placeholder rigs as SO2R's radio A and Radio B, set A in front.
  Future<void> pumpSo2r(WidgetTester tester) async {
    await services.settings.setExperimentEnabled('so2r', true);
    await pumpOperation(tester);
    final right = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Right Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    await tester.runAsync(() => services.cat.connect(right.uuid));
    addTearDown(() => services.cat.disconnect(right.uuid));
    await services.cat.setRadio1(LocalRadio(rig));
    await services.cat.setRadio2(right.uuid);
    await tester.pump();
    services.cat.setEnterSends(on: true);
  }

  EnterSends esmOf(WidgetTester tester, String set) => tester.widget<LoggingControls>(find.byKey(ValueKey('set-$set'))).session.enterSends!()!;

  // The trap: a thanks still waiting on its log keyed after the operator has
  // moved to the other radio — it cuts off the CQ they keyed there since.
  testWidgets("under SO2R, a message the other radio was keyed over while it waited keys nothing", (tester) async {
    await pumpSo2r(tester);
    final logged = Completer<EsmLogged?>();
    esmOf(tester, 'A').send([EsmMessage.thanks], cwDraft, logged: logged.future);
    await tester.pump();
    services.cat.keyer('B').sendCw('CQ B');

    logged.complete((qso: cwDraft, next: cwDraft));
    await tester.pump();
    await tester.pump();
    expect(services.cat.keyer('A').cwProgress.value, isNull);
    expect(services.cat.keyer('A').waiting.value, isEmpty);
    expect(services.cat.keyer('B').cwProgress.value?.text, 'CQ B', reason: "B's CQ goes on");
    await unmount(tester);
  });

  testWidgets('under SO2R with messages queued, such a message waits its turn instead', (tester) async {
    await services.settings.setSo2rQueueMessages(true);
    await pumpSo2r(tester);
    final logged = Completer<EsmLogged?>();
    esmOf(tester, 'A').send([EsmMessage.thanks], cwDraft, logged: logged.future);
    await tester.pump();
    services.cat.keyer('B').sendCw('CQ B');

    logged.complete((qso: cwDraft, next: cwDraft));
    await tester.pump();
    await tester.pump();
    expect(services.cat.keyer('A').waiting.value.single.text, 'TU');
    await unmount(tester);
  });

  // The trap: one ESM queue for both radios — set B's Enter keys only once
  // set A's contact has logged.
  testWidgets("under SO2R, an Enter in set B never waits on set A's log", (tester) async {
    await pumpSo2r(tester);
    final logged = Completer<EsmLogged?>();
    esmOf(tester, 'A').send([EsmMessage.thanks], cwDraft, logged: logged.future);
    await tester.pump();

    esmOf(tester, 'B').send([EsmMessage.hisCall], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.keyer('B').cwProgress.value?.text, 'W1AW');
    logged.complete(null);
    await unmount(tester);
  });

  testWidgets('the messages of one step go out as ONE message, in N1MM order', (tester) async {
    // F5 then F2 of the seeded set. Keyed as one so the keyer area shows the
    // answer as it is heard, not as a message and a queue.
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    enterSends(tester)!.send([EsmMessage.hisCall, EsmMessage.exchange], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'W1AW 5NN');
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
    // A set with no exchange message must still give the caller their call
    // — a missing slot is the operator's choice, not a reason to key nothing.
    await services.settings.setCwMessage(2, '');
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    enterSends(tester)!.send([EsmMessage.hisCall, EsmMessage.exchange], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'W1AW');
    await unmount(tester);
  });

  // The thanks closes the contact as it was logged and speaks to the next
  // one. Rendered against the keypress's draft, it would miss what an
  // extension added on the way to the log; against the entry the log left,
  // `qso` would be the next station rather than the one being thanked.
  testWidgets('a step that logs keys its thanks against the contact as saved, with the entry the log left as next', (tester) async {
    await services.settings.setCwMessage(3, 'TU {{qso.call}} {{qso.notes}} {{next.call}}');
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    final logged = Completer<EsmLogged?>();
    enterSends(tester)!.send([EsmMessage.thanks], cwDraft, logged: logged.future);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value, isNull, reason: 'the thanks waits for the log');

    logged.complete((
      qso: const {
        'their': {'call': 'W1AW'},
        'mode': 'CW',
        'notes': 'DECORATED',
      },
      next: const {
        'their': {'call': 'K1ABC'},
        'mode': 'CW',
      },
    ));
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'TU W1AW DECORATED K1ABC');
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
    const next = (
      qso: cwDraft,
      next: {
        'their': {'call': ''},
        'mode': 'CW',
      },
    );
    esm.send([EsmMessage.hisCall, EsmMessage.exchange], cwDraft);
    await tester.pump();
    await tester.pump();
    esm.send([EsmMessage.thanks], cwDraft, logged: Future.value(next));
    await tester.pump();
    await tester.pump();
    esm.send(
      [EsmMessage.hisCall, EsmMessage.exchange],
      const {
        'their': {'call': 'K2XX'},
        'mode': 'CW',
      },
    );
    await tester.pump();
    await tester.pump();
    esm.send([EsmMessage.thanks], cwDraft, logged: Future.value(next));
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'W1AW 5NN');
    expect(services.cat.cwProgress.value?.pending, ['TU', 'K2XX 5NN', 'TU']);
    await unmount(tester);
  });

  // Enter cancels a CQ's repeat before it sends, so a second Enter that
  // finds the CQ still keying and holds it back must arm the chain again —
  // or the auto-CQ just stops, with nothing on screen to say so.
  testWidgets('a CQ held back as already keying keeps its repeat', (tester) async {
    await services.settings.setCwRepeat(true);
    await services.settings.setCwRepeatCooldown(5);
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

  // A repeat's send renders first and keys after. A chain ended in between —
  // an Escape, a tap, the VFO moving off the CQ — would otherwise key the CQ
  // anyway and arm a fresh chain, five minutes and all, behind it.
  testWidgets('a repeat whose chain ended while it rendered keys nothing', (tester) async {
    await services.settings.setCwRepeat(true);
    await services.settings.setCwRepeatCooldown(1);
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    enterSends(tester)!.send([EsmMessage.cq], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.keyerRepeating, isTrue);

    final firstRenders = extensions.renders;
    extensions.hold = Completer<void>();
    for (var i = 0; i < 120 && extensions.renders == firstRenders; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(extensions.renders, firstRenders + 1, reason: 'the repeat has started rendering its next CQ');
    expect(services.cat.cwSending, isFalse);

    services.cat.cancelKeyerRepeat();
    extensions.hold!.complete();
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwSending, isFalse);
    expect(services.cat.keyerRepeating, isFalse);
    await unmount(tester);
  });

  // A set with no TU still completes the contact: the second Enter of every
  // reports-only run is a thanks-only step, and an empty F3 must neither
  // throw nor leave the next step waiting behind it.
  testWidgets('a thanks with an empty slot keys nothing and holds nothing up', (tester) async {
    await services.settings.setCwMessage(3, '');
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    final esm = enterSends(tester)!;
    esm.send([EsmMessage.thanks], cwDraft, logged: Future.value((qso: cwDraft, next: cwDraft)));
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value, isNull);

    esm.send([EsmMessage.hisCall, EsmMessage.exchange], cwDraft);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, 'W1AW 5NN');
    await unmount(tester);
  });

  // A step renders its messages one at a time. A second Enter close behind
  // the first would otherwise render its TU while "W1AW 5NN" is still
  // rendering, and key the thanks before the answer it follows.
  testWidgets('a thanks never keys ahead of the step before it', (tester) async {
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    final esm = enterSends(tester)!;
    extensions.hold = Completer<void>();
    esm.send([EsmMessage.hisCall, EsmMessage.exchange], cwDraft);
    await tester.pump();
    esm.send([EsmMessage.thanks], cwDraft, logged: Future.value((qso: cwDraft, next: cwDraft)));
    await tester.pump();
    await tester.pump();
    expect(extensions.renders, 1, reason: 'the thanks waits for the answer before rendering at all');

    extensions.hold!.complete();
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(services.cat.cwProgress.value?.text, 'W1AW 5NN');
    expect(services.cat.cwProgress.value?.pending, ['TU']);
    await unmount(tester);
  });

  testWidgets('a log that failed gets no thanks', (tester) async {
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    enterSends(tester)!.send([EsmMessage.thanks], cwDraft, logged: Future.value());
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value, isNull);
    await unmount(tester);
  });

  // S&P's step that logs is its exchange, handed the log's future like any
  // step that logs. Only the thanks waits for it: an exchange held for the
  // log goes out after the contact is already closed.
  testWidgets('a step that logs without a thanks keys at the keypress', (tester) async {
    await pumpOperation(tester);
    services.cat.setEnterSends(on: true);
    enterSends(tester)!.send([EsmMessage.exchange], cwDraft, logged: Completer<EsmLogged?>().future);
    await tester.pump();
    await tester.pump();
    expect(services.cat.cwProgress.value?.text, '5NN');
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
