// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Against a real CatService with the placeholder radio (which keys nothing,
// but runs the real send queue and reports a speed like a real rig), so
// what the strip shows is what the queue reports, not a hand-built stand-in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';
import 'package:ham2k_logger/views/keyer_area.dart';

import 'support/halo_test_support.dart';

/// Stands in for the `template` hook without booting a JS engine: only
/// `{{ qso.call }}` is filled, which is all a label test needs.
class _TemplateExtensions extends ExtensionService {
  @override
  bool get ready => true;

  @override
  Future<void> start() async {}

  @override
  Future<String?> renderTemplate(String template, {Map<String, dynamic>? operation, Map<String, dynamic>? qso, int? qsoCount}) async =>
      template.replaceAll('{{ qso.call }}', ((qso?['their'] as Map?)?['call'] as String?) ?? '');

  /// How many times the labels crossed the bridge — the batching is the point.
  int batches = 0;

  @override
  Future<List<({String? text, String? error})>?> renderTemplates(List<String> templates,
      {Map<String, dynamic>? operation, Map<String, dynamic>? qso, int? qsoCount}) async {
    batches++;
    return [for (final t in templates) (text: await renderTemplate(t, qso: qso), error: null)];
  }
}

PanelRenderContext contextFor(String call) => PanelRenderContext(
      operation: null,
      qso: {
        'their': {'call': call},
      },
      qsoCount: 0,
      spotsRevision: 0,
      lookupRevision: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices(extensions: _TemplateExtensions());
    final settings = harness.settings;
    services = harness.services;
    // A keying radio becomes the key in use only with the experiment on.
    await settings.setExperimentEnabled('keyer', true);
  });

  Future<void> connectPlaceholder(WidgetTester tester) async {
    final node = await services.cat.addNode(
      typeKey: 'placeholder-radio',
      name: 'Bench Rig',
      config: placeholderRadioModel.variants.single.defaultConfig,
    );
    await tester.runAsync(() => services.cat.connect(node.uuid));
    addTearDown(() => services.cat.disconnect(node.uuid));
    expect(services.cat.canKeyCw, isTrue, reason: 'sanity');
  }

  final sent = <int>[];
  Widget host({bool suppressed = false, PanelRenderContext? templateContext, bool phone = false}) => TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Column(children: [
              KeyerArea(
                cat: services.cat,
                services: services,
                onSendMessage: sent.add,
                suppressed: suppressed,
                templateContext: templateContext,
                phone: phone,
              ),
            ]),
          ),
        ),
      );

  final messageText = find.byWidgetPredicate((w) => w is Text && w.textSpan != null);

  /// The rendered message's spans: (sent, pending).
  (String, String) spansOf(WidgetTester tester) {
    final rich = tester.widget<Text>(messageText);
    final spans = (rich.textSpan as TextSpan).children!.cast<TextSpan>();
    return (spans[0].text!, spans[1].text!);
  }

  double stripHeight(WidgetTester tester) => tester.getSize(find.byType(KeyerArea)).height;

  testWidgets('takes no room while nothing has been keyed', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    expect(find.text('22 wpm'), findsNothing);
    expect(stripHeight(tester), 0);
  });

  testWidgets('slides down with a message: the speed pill, then the message with sent characters set apart', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    services.cat.sendCw('ET'); // at 22 WPM: E ends at 55 ms, T at 382 ms
    await tester.pump();
    final atStart = stripHeight(tester);
    await tester.pump(const Duration(milliseconds: 100));
    // The trap: showing the strip at full size at once — the point of the
    // slide is that the fields move down rather than jump.
    expect(stripHeight(tester), greaterThan(atStart));
    expect(find.text('22 wpm'), findsOneWidget, reason: 'the placeholder rig comes up at 22 WPM');
    await tester.pump(const Duration(milliseconds: 200));
    expect(spansOf(tester), ('E', 'T'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(spansOf(tester), ('ET', ''));
    await tester.pump(const Duration(seconds: 62));
  });

  testWidgets('a finished message leaves the strip, and the strip STAYS: only the operator sends it away', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    services.cat.sendCw('ET');
    await tester.pump(); // the first frame starts the tickers; time passes from here
    await tester.pump(const Duration(seconds: 1));
    final full = stripHeight(tester);
    expect(messageText, findsNothing, reason: 'the queue drained (ET plus the trailing gap is under a second)');
    expect(find.text('22 wpm'), findsOneWidget);

    // The trap this test exists for: a timer taking the strip away. The
    // buttons on it are what the NEXT message is sent from, so a strip that
    // vanished while the operator read the screen is one they have to summon
    // back before they can key at all.
    await tester.pump(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('22 wpm'), findsOneWidget);
    expect(stripHeight(tester), full);
  });

  testWidgets('a message during the linger cancels the hide', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    services.cat.sendCw('E');
    await tester.pump(); // the first frame starts the tickers; time passes from here
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 58));

    services.cat.sendCw('ET');
    await tester.pump();
    expect(spansOf(tester), ('', 'ET'));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('22 wpm'), findsOneWidget, reason: 'the old hide timer must not fire on the new message');
    await tester.pump(const Duration(seconds: 62));
  });

  testWidgets('a message stopped short leaves the strip too', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    services.cat.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
    await tester.pump(); // the first frame starts the tickers; time passes from here
    await tester.pump(const Duration(milliseconds: 500));
    expect(messageText, findsOneWidget);
    services.cat.stopCw(); // Esc
    await tester.pump();
    expect(messageText, findsNothing, reason: 'what did not go out is not shown as if it had');
    expect(find.text('22 wpm'), findsOneWidget);
    await tester.pump(const Duration(seconds: 62));
  });

  testWidgets('messages pressed while one is keying show behind it, without restarting it', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    services.cat.sendCw('ET');
    await tester.pump(); // the first frame starts the tickers; time passes from here
    await tester.pump(const Duration(milliseconds: 100));
    expect(spansOf(tester), ('E', 'T'));

    // The trap: re-keying on the report object, which restarts the bar
    // from zero every time another key is pressed.
    services.cat.sendCw('5NN');
    services.cat.sendCw('TU');
    await tester.pump();
    expect(spansOf(tester), ('E', 'T'), reason: 'the same message keeps its place');
    expect(find.text(' · 5NN'), findsOneWidget);
    expect(find.text(' · TU'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 62));
  });

  testWidgets('tapping the pill opens the speed dialog, and Enter sets the radio', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    services.cat.sendCw('E');
    await tester.pump(); // the first frame starts the tickers; time passes from here
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('22 wpm'));
    await tester.pumpAndSettle();
    expect(find.text('CW Keying'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'WPM'), '25');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(services.cat.keyerSpeed, 25, reason: 'the placeholder reported the set back, like a real rig');
    expect(find.text('25 wpm'), findsOneWidget);
    expect(find.text('CW Keying'), findsNothing, reason: 'the dialog closed on Enter');
    await tester.pump(const Duration(seconds: 62));
  });

  testWidgets('the dialog\'s custom message goes to the queue on Enter or Send, and the dialog closes', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    services.cat.sendCw('E');
    await tester.pump(); // the first frame starts the tickers; time passes from here
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('22 wpm'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Messages'), findsOneWidget, reason: 'the way to the message editor heads the dialog');
    expect(find.text('Custom Message'), findsOneWidget, reason: 'its own section');
    await tester.enterText(find.widgetWithText(TextField, 'Message'), 'hello there');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Message')).controller!.text, 'HELLO THERE',
        reason: 'uppercased as typed, on a hardware keyboard too');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(services.cat.cwProgress.value?.text, 'HELLO THERE', reason: 'as typed, sanitized by the queue — no template');
    expect(find.text('CW Keying'), findsNothing, reason: 'closes: the keyer area is where the message is watched');

    // The Send button reads the field without it having to lose focus.
    await tester.tap(find.text('22 wpm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Message'), 'tu');
    await tester.tap(find.text('Send'));
    await tester.pump();
    final progress = services.cat.cwProgress.value!;
    expect([progress.text, ...progress.pending], contains('TU'), reason: 'queued behind, or already going out');
    await tester.pumpAndSettle();
    expect(find.text('CW Keying'), findsNothing);
    await tester.pump(const Duration(seconds: 62));
  });

  testWidgets('tapping the message keying stops it and the queue; tapping a queued one drops only it', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    services.cat.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
    services.cat.sendCw('5NN');
    services.cat.sendCw('TU');
    await tester.pump(); // the first frame starts the tickers; time passes from here
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(' · 5NN'), findsOneWidget);
    expect(find.text(' · TU'), findsOneWidget);

    await tester.tap(find.text(' · 5NN'));
    await tester.pump();
    expect(find.text(' · 5NN'), findsNothing, reason: 'only that one');
    expect(find.text(' · TU'), findsOneWidget);
    expect(messageText, findsOneWidget, reason: 'the message keying is untouched');

    await tester.tap(messageText);
    await tester.pump();
    expect(messageText, findsNothing);
    expect(find.text(' · TU'), findsNothing, reason: 'everything behind it goes too');
    expect(services.cat.cwSending, isFalse);
    await tester.pump(const Duration(seconds: 62));
  });

  testWidgets('KEYER brings the area up idle: a button per message with text, sending through the host', (tester) async {
    await connectPlaceholder(tester);
    await services.settings.setCwMessage(1, 'CQ CQ DE {{ op.call }} K');
    await services.settings.setCwMessageLabel(1, 'CQ');
    await services.settings.setCwMessage(3, '{{ qso.call }} 5NN TU');
    await tester.pumpWidget(host());
    expect(stripHeight(tester), 0);

    services.cat.showKeyerArea();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('22 wpm'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'CQ'), findsOneWidget, reason: 'labelled by its label');
    expect(find.widgetWithText(InkWell, 'F3'), findsOneWidget, reason: 'or by its key');
    expect(find.widgetWithText(InkWell, 'F2'), findsNothing, reason: 'only messages with text');

    sent.clear();
    await tester.tap(find.widgetWithText(InkWell, 'F3'));
    expect(sent, [3]);

    // Opened on purpose, it stays until sent from or closed — no linger.
    await tester.pump(const Duration(seconds: 90));
    expect(find.text('22 wpm'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Close the keyer area'));
    await tester.pump(); // the first frame starts the tickers; time passes from here
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(stripHeight(tester), 0);
  });

  testWidgets('a label written as a template renders against the draft, debounced, and follows it', (tester) async {
    await connectPlaceholder(tester);
    await services.settings.setCwMessage(1, '{{ qso.call }} 5NN TU');
    await services.settings.setCwMessageLabel(1, '{{ qso.call }} 5NN');
    await services.settings.setCwMessage(2, 'TU');
    await services.settings.setCwMessageLabel(2, 'Thanks');
    await services.settings.setCwMessage(4, '{{ qso.call }} TU');
    await services.settings.setCwMessageLabel(4, 'TU {{ qso.call }}');
    await tester.pumpWidget(host(templateContext: contextFor('K1ABC')));
    services.cat.showKeyerArea();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('{{ qso.call }} 5NN'), findsOneWidget, reason: 'as written until the render lands');
    await tester.pump(cwLabelRenderDelay);
    await tester.pump();
    expect(find.text('K1ABC 5NN'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Thanks'), findsOneWidget, reason: 'a plain label never goes to the bridge');

    // The draft moves: the label follows, after the delay, not per letter.
    await tester.pumpWidget(host(templateContext: contextFor('W2XYZ')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('K1ABC 5NN'), findsOneWidget, reason: 'the old text holds while the debounce runs');
    await tester.pump(cwLabelRenderDelay);
    await tester.pump();
    expect(find.text('W2XYZ 5NN'), findsOneWidget);
    expect((services.extensions as _TemplateExtensions).batches, 2, reason: 'one crossing per render, whatever the label count');
    await tester.tap(find.bySemanticsLabel('Close the keyer area'));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('editing a logged QSO hides the area, and it comes back once editing ends', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    services.cat.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K CQ CQ CQ DE N0DEV N0DEV N0DEV K');
    await tester.pump(); // the first frame starts the tickers; time passes from here
    await tester.pump(const Duration(seconds: 1));
    final full = stripHeight(tester);
    expect(full, greaterThan(0));

    await tester.pumpWidget(host(suppressed: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(stripHeight(tester), 0, reason: 'a message being corrected is not one to key at');
    services.cat.showKeyerArea();
    await tester.pump(const Duration(seconds: 1));
    expect(stripHeight(tester), 0, reason: 'nor does KEYER bring it up meanwhile');

    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(stripHeight(tester), full, reason: 'still keying, so it returns');
    services.cat.stopCw();
    await tester.pump(const Duration(seconds: 62));
  });

  testWidgets('the X slides the area away before the linger is up; the next message brings it back', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    services.cat.sendCw('E');
    await tester.pump(); // the first frame starts the tickers; time passes from here
    await tester.pump(const Duration(seconds: 1));
    final full = stripHeight(tester);

    await tester.tap(find.bySemanticsLabel('Close the keyer area'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(stripHeight(tester), lessThan(full), reason: 'sliding up');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('22 wpm'), findsNothing);
    expect(stripHeight(tester), 0);

    services.cat.sendCw('ET');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('22 wpm'), findsOneWidget);
    expect(stripHeight(tester), full);
    await tester.pump(const Duration(seconds: 62));
  });

  testWidgets('a speed outside the keyer\'s range is clamped, not sent as typed', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    services.cat.sendCw('E');
    await tester.pump(); // the first frame starts the tickers; time passes from here
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('22 wpm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'WPM'), '99');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(services.cat.keyerSpeed, 50, reason: 'the placeholder keyer tops out at 50');
    await tester.pump(const Duration(seconds: 62));
  });

  testWidgets('in a Phone mode the strip is the voice keyer\'s: a voice pill, a button per memory of the radio', (tester) async {
    await connectPlaceholder(tester);
    await services.settings.setCwMessage(1, 'CQ CQ DE {{ op.call }} K');
    await services.settings.setVoiceMessageLabel(2, 'CQ POTA');
    await tester.pumpWidget(host(templateContext: contextFor('N0CALL'), phone: true));
    services.cat.showKeyerArea();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Voice'), findsOneWidget, reason: 'the pill says whose strip this is');
    expect(find.text('22 wpm'), findsNothing, reason: 'a keyer speed means nothing to a voice memory');
    // The RADIO's memories, every one, labelled where a label exists.
    expect(find.widgetWithText(InkWell, 'M1'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'CQ POTA'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'M8'), findsOneWidget, reason: 'the placeholder has eight');
    expect(find.widgetWithText(InkWell, 'F1'), findsNothing, reason: 'the CW message with text is not offered here');

    // A button plays straight through CatService — no template, nothing to
    // render — and the strip shows the memory in the message's place.
    await tester.tap(find.widgetWithText(InkWell, 'CQ POTA'));
    await tester.pump();
    expect(services.cat.voiceActivity.value?.memory, 2);
    expect(find.text('Playing CQ POTA'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'M1'), findsNothing, reason: 'the buttons wait under the message');
    // Tapping it stops it (Esc's other form), and the buttons come back.
    await tester.tap(find.text('Playing CQ POTA'));
    await tester.pump();
    expect(services.cat.voiceActivity.value, isNull);
    expect(find.widgetWithText(InkWell, 'M1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 62));
  });

  testWidgets('a memory playing brings the strip up by itself, and it stays after, like a CW message', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host(templateContext: contextFor('N0CALL'), phone: true));
    expect(stripHeight(tester), 0);
    services.cat.playVoiceMemory(3); // F3
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Playing M3'), findsOneWidget);
    // The placeholder's pretend playback ends on its own.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Playing M3'), findsNothing);
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('Voice'), findsOneWidget, reason: 'the strip stays until the operator closes it');
  });

  testWidgets('a doubtful play reads like any other on the strip: no question mark mid-air', (tester) async {
    await connectPlaceholder(tester);
    await services.settings.setVoiceMessageLabel(2, 'CQ POTA');
    await tester.pumpWidget(host(templateContext: contextFor('N0CALL'), phone: true));
    // What a session reports when the radio said "not going" before ever
    // saying "going" — the placeholder never polls, so it is set directly.
    services.cat.voiceActivity.value = const VoiceActivity(memory: 2, doubtful: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Doubt is real and still stops a refused play; it is not something to
    // ASK the operator about while audio may be going out, since they cannot
    // answer it from here. The Voice Messages dialog is where it is said.
    expect(find.text('Playing CQ POTA'), findsOneWidget);
    expect(find.text('Playing CQ POTA?'), findsNothing);
    services.cat.voiceActivity.value = null;
    await tester.pump();
  });

  testWidgets('a CW draft keeps the CW strip, whatever the radio can play', (tester) async {
    await connectPlaceholder(tester);
    await services.settings.setCwMessage(1, 'CQ');
    // The seeded Default set labels its first message; cleared here so the
    // button shows its KEY, which is what this test is about.
    await services.settings.setCwMessageLabel(1, '');
    await tester.pumpWidget(host(templateContext: contextFor('N0CALL')));
    services.cat.showKeyerArea();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('22 wpm'), findsOneWidget);
    expect(find.text('Voice'), findsNothing);
    expect(find.widgetWithText(InkWell, 'F1'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'M1'), findsNothing);
  });

  testWidgets('the buttons stay down for a whole repeat chain, not only for its waits', (tester) async {
    await connectPlaceholder(tester);
    await services.settings.setCwMessage(1, 'CQ');
    await services.settings.setCwMessageLabel(1, '');
    await tester.pumpWidget(host(templateContext: contextFor('N0CALL')));
    services.cat.showKeyerArea();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.widgetWithText(InkWell, 'F1').hitTestable(), findsOneWidget);

    // A chain armed with nothing keying and no wait yet: the GAP between a
    // wait ending and the next message reaching the radio, which is a
    // template render long. Buttons flashing back for it read as the
    // repeats having stopped. (Hit-testable, because the row stays mounted
    // behind a Visibility to keep its rendered labels.)
    services.cat.armKeyerRepeat(delay: const Duration(seconds: 3), text: 'CQ', send: () {});
    await tester.pump();
    expect(find.widgetWithText(InkWell, 'F1').hitTestable(), findsNothing);

    services.cat.cancelKeyerRepeat();
    await tester.pump();
    expect(find.widgetWithText(InkWell, 'F1').hitTestable(), findsOneWidget);
  });

  testWidgets('a mode flip keeps the CW buttons mounted, so their rendered labels survive it', (tester) async {
    await connectPlaceholder(tester);
    await services.settings.setCwMessage(1, 'CQ');
    await services.settings.setCwMessageLabel(1, '{{ qso.call }} CQ');
    final extensions = services.extensions as _TemplateExtensions;
    // ONE context across the flips: a draft that did not move is the same
    // object, which is what _MessageButtons compares.
    final context = contextFor('N0CALL');
    await tester.pumpWidget(host(templateContext: context));
    services.cat.showKeyerArea();
    await tester.pump();
    await tester.pump(cwLabelRenderDelay);
    await tester.pump();
    expect(find.widgetWithText(InkWell, 'N0CALL CQ'), findsOneWidget);
    final batches = extensions.batches;

    await tester.pumpWidget(host(templateContext: context, phone: true));
    await tester.pump(const Duration(seconds: 1));
    expect(find.widgetWithText(InkWell, 'M1'), findsOneWidget);
    await tester.pumpWidget(host(templateContext: context));
    await tester.pump();
    // The trap: a slot that swaps widget types remounts _MessageButtons,
    // which comes back showing the raw template and crosses the bridge
    // again for a draft that has not moved.
    expect(find.widgetWithText(InkWell, 'N0CALL CQ'), findsOneWidget);
    expect(extensions.batches, batches, reason: 'no render for a draft that did not move');
    await tester.pump(const Duration(seconds: 62));
  });
}
