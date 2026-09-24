// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Against a real CatService with the placeholder radio (which keys nothing,
// but runs the real send queue and reports a speed like a real rig), so
// what the strip shows is what the queue reports, not a hand-built stand-in.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show MdiIcons;
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/cw_live_typing.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';
import 'package:ham2k_logger/views/keyer_area.dart';

import '../support/halo_test_support.dart';

/// Stands in for the `template` hook without booting a JS engine: only
/// `{{ qso.call }}` and `{{ keyer.msgN }}` are filled — the latter as the
/// hook does, with message N itself rendered — which is all a label test
/// needs.
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
    Map<String, dynamic>? keyer,
  }) async {
    final messages = (keyer?['messages'] as List?)?.cast<String>() ?? const <String>[];
    final expanded = template.replaceAllMapped(RegExp(r'\{\{ keyer\.msg(\d) \}\}'), (m) {
      final n = int.parse(m[1]!);
      return n <= messages.length ? messages[n - 1] : '';
    });
    return expanded.replaceAll('{{ qso.call }}', ((qso?['their'] as Map?)?['call'] as String?) ?? '');
  }

  /// How many times the labels crossed the bridge — the batching is the point.
  int batches = 0;

  @override
  Future<List<({String? text, String? error})>?> renderTemplates(
    List<String> templates, {
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    int? qsoCount,
    Map<String, dynamic>? keyer,
  }) async {
    batches++;
    return [for (final t in templates) (text: await renderTemplate(t, qso: qso, keyer: keyer), error: null)];
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
    final node = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    await tester.runAsync(() => services.cat.connect(node.uuid));
    addTearDown(() => services.cat.disconnect(node.uuid));
    expect(services.cat.canKeyCw, isTrue, reason: 'sanity');
  }

  final sent = <int>[];
  Widget host({bool suppressed = false, PanelRenderContext? templateContext, bool phone = false, bool enterSends = false}) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            KeyerArea(
              cat: services.cat,
              services: services,
              onSendMessage: sent.add,
              suppressed: suppressed,
              templateContext: templateContext,
              phone: phone,
              enterSends: enterSends,
            ),
          ],
        ),
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

  testWidgets('the ESM pill is there only with its experiment, and steps Off, Run, S&P', (tester) async {
    await connectPlaceholder(tester);
    await tester.pumpWidget(host());
    services.cat.showKeyerArea();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ESM Off'), findsNothing, reason: 'Enter is not the keyer\'s without EXP ESM');

    await tester.pumpWidget(host(enterSends: true));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('ESM Off'));
    await tester.pump();
    expect(services.cat.enterSends.value, (on: true, running: true));
    await tester.tap(find.text('ESM Run'));
    await tester.pump();
    expect(services.cat.enterSends.value, (on: true, running: false));
    await tester.tap(find.text('ESM S&P'));
    await tester.pump();
    // Off comes back as Run, so the next tap starts where a contest does.
    expect(services.cat.enterSends.value, (on: false, running: true));
  });

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
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Message')).controller!.text,
      'HELLO THERE',
      reason: 'uppercased as typed, on a hardware keyboard too',
    );
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
    // answer it from here. The Phone Keyer dialog is where it is said.
    expect(find.text('Playing CQ POTA'), findsOneWidget);
    expect(find.text('Playing CQ POTA?'), findsNothing);
    services.cat.voiceActivity.value = null;
    await tester.pump();
  });

  // A blank label is the common case, and the key's number says nothing
  // about what it sends. The template in a message has to come out RENDERED
  // — "{{ qso.call }} 5NN" on a button is noise — and until that render
  // lands the button must not show the `keyer.msgN` standing in for it.
  testWidgets('a message with no label is labelled with the message itself, rendered', (tester) async {
    await connectPlaceholder(tester);
    await services.settings.setCwMessage(1, 'CQ TEST');
    await services.settings.setCwMessageLabel(1, '');
    await services.settings.setCwMessage(3, '{{ qso.call }} 5NN');
    await services.settings.setCwMessageLabel(3, '');
    await tester.pumpWidget(host(templateContext: contextFor('W1AW')));
    services.cat.showKeyerArea();
    await tester.pump();
    expect(find.widgetWithText(InkWell, 'CQ TEST'), findsOneWidget, reason: 'plain text reads as itself at once');
    expect(find.widgetWithText(InkWell, 'F3'), findsOneWidget, reason: 'a template reads as its key until rendered');

    await tester.pump(const Duration(seconds: 1));
    expect(find.widgetWithText(InkWell, 'W1AW 5NN'), findsOneWidget);
    expect(find.textContaining('keyer'), findsNothing);

    // The label's template is `{{ keyer.msg3 }}` before and after the edit;
    // cached on that alone, the key would go on reading the old message.
    await services.settings.setCwMessage(3, '{{ qso.call }} TU');
    await tester.pump();
    expect(find.widgetWithText(InkWell, 'W1AW 5NN'), findsNothing, reason: 'the old message is not shown for the new one');
    await tester.pump(const Duration(seconds: 1));
    expect(find.widgetWithText(InkWell, 'W1AW TU'), findsOneWidget);
  });

  testWidgets('a CW draft keeps the CW strip, whatever the radio can play', (tester) async {
    await connectPlaceholder(tester);
    await services.settings.setCwMessage(1, 'CQ');
    // The seeded Default set labels its first message; cleared here so the
    // button reads as its message, not as a voice memory's label.
    await services.settings.setCwMessageLabel(1, '');
    await tester.pumpWidget(host(templateContext: contextFor('N0CALL')));
    services.cat.showKeyerArea();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('22 wpm'), findsOneWidget);
    expect(find.text('Voice'), findsNothing);
    expect(find.widgetWithText(InkWell, 'CQ'), findsOneWidget);
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
    expect(find.widgetWithText(InkWell, 'CQ').hitTestable(), findsOneWidget);

    // A chain armed with nothing keying and no wait yet: the GAP between a
    // wait ending and the next message reaching the radio, which is a
    // template render long. Buttons flashing back for it read as the
    // repeats having stopped. (Hit-testable, because the row stays mounted
    // behind a Visibility to keep its rendered labels.)
    services.cat.armKeyerRepeat(delay: const Duration(seconds: 3), text: 'CQ', send: () {});
    await tester.pump();
    expect(find.widgetWithText(InkWell, 'CQ').hitTestable(), findsNothing);

    services.cat.cancelKeyerRepeat();
    await tester.pump();
    expect(find.widgetWithText(InkWell, 'CQ').hitTestable(), findsOneWidget);
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

  group('keyboard mode', () {
    final callFocus = FocusNode();
    var advanced = 0;

    /// What the logging panel puts around the strip: a call field holding
    /// the focus, and Space bound panel-wide to advance to the next field.
    Widget panelHost() => TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.space): () => advanced++},
            child: Column(
              children: [
                TextField(focusNode: callFocus, autofocus: true),
                KeyerArea(cat: services.cat, services: services, onSendMessage: sent.add),
              ],
            ),
          ),
        ),
      ),
    );

    Finder field() => find.descendant(of: find.byType(KeyerArea), matching: find.byType(TextField));

    Future<void> startTyping(WidgetTester tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(panelHost());
      services.cat.showKeyerArea();
      await tester.pump(); // the first frame starts the slide; time passes from here
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byIcon(MdiIcons.keyboardOutline));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('takes the keyboard from the call field', (tester) async {
      await startTyping(tester);
      // The trap: `autofocus`, which only takes a focus nobody holds — the
      // operator presses the button and types into the call field.
      expect(callFocus.hasFocus, isFalse);
      expect(tester.widget<TextField>(field()).focusNode!.hasFocus, isTrue);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('Space types a space, not the panel\'s next-field', (tester) async {
      await startTyping(tester);
      await tester.enterText(field(), 'k');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(advanced, 0);
      expect(tester.widget<TextField>(field()).controller!.text, 'K ');
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('a keystroke never resets the keyboard\'s composing word', (tester) async {
      await startTyping(tester);
      await tester.pump(); // the field's connection opens; what it sends then is not a keystroke's
      tester.testTextInput.log.clear();
      // An on-screen keyboard mid-word: the D is still being composed.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(text: 'cq d', selection: TextSelection.collapsed(offset: 4), composing: TextRange(start: 3, end: 4)),
      );
      await tester.pump();
      // The trap: the field rewriting itself while its formatter runs, which
      // sends the platform a value with the composing word cleared — an
      // Android keyboard then repeats the letter.
      final sent = [
        for (final call in tester.testTextInput.log)
          if (call.method == 'TextInput.setEditingState') call.arguments as Map,
      ];
      expect(sent.every((state) => state['composingBase'] == 3), isTrue, reason: '$sent');
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('keys what is typed, and Enter lets the rest go out after the mode ends', (tester) async {
      await startTyping(tester);
      await tester.enterText(field(), 'cq ');
      expect(services.cat.cwProgress.value?.text, 'CQ', reason: 'a finished word goes the moment its space is typed');
      await tester.enterText(field(), 'cq de');
      expect(services.cat.cwProgress.value?.pending, isEmpty, reason: 'held while CQ keys, so Backspace still reaches it');

      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(field(), findsNothing);
      // The trap: ending the mode with the held tail still waiting for a
      // drain nobody listens for, so the operator's last word never keys.
      expect(services.cat.cwProgress.value?.pending, ['DE']);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('Escape stops what is keying and ends the mode', (tester) async {
      await startTyping(tester);
      await tester.enterText(field(), 'cq cq cq ');
      expect(services.cat.cwSending, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(field(), findsNothing);
      expect(services.cat.cwSending, isFalse);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('Escape stopping the key first (the operation view\'s handler) keys nothing held', (tester) async {
      // The operation view hears Escape through HardwareKeyboard, ahead of
      // the focus tree, and stops the key before the field does.
      bool stopFirst(KeyEvent event) => event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape && services.cat.stopKeying();
      HardwareKeyboard.instance.addHandler(stopFirst);
      addTearDown(() => HardwareKeyboard.instance.removeHandler(stopFirst));
      await startTyping(tester);
      await tester.enterText(field(), 'cq ');
      await tester.enterText(field(), 'cq de n0dev ');
      expect(services.cat.cwProgress.value?.text, 'CQ', reason: 'sanity: DE N0DEV is held behind it');
      // Everything the key is handed from here on. The field's own Escape
      // stops the key again right after, so the end state cannot tell — only
      // this can: a word keyed between the two stops is a word on the air.
      final keyed = <String>[];
      void record() {
        final text = services.cat.cwProgress.value?.text;
        if (text != null) keyed.add(text);
      }

      services.cat.cwProgress.addListener(record);
      addTearDown(() => services.cat.cwProgress.removeListener(record));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(field(), findsNothing);
      expect(keyed, isEmpty, reason: 'the held words must not go out after the stop');
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('tapping the message stops it, drops what is held, and keeps the mode', (tester) async {
      await startTyping(tester);
      await tester.enterText(field(), 'cq ');
      await tester.enterText(field(), 'cq de n0dev ');
      await tester.pump();
      await tester.tap(find.text('CQ').first);
      await tester.pump();
      expect(services.cat.cwSending, isFalse, reason: 'DE N0DEV must not go out after the stop');
      expect(field(), findsOneWidget, reason: 'the mode stays, ready for a fresh message');
      expect(tester.widget<TextField>(field()).controller!.text, isEmpty);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('the keyboard toggle shows the strip, starts the mode, and ends it', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(panelHost());
      services.cat.toggleKeyboardMode();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(field(), findsOneWidget);
      services.cat.toggleKeyboardMode();
      await tester.pump();
      expect(field(), findsNothing);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('starting it ends a CQ repeat', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(panelHost());
      services.cat.showKeyerArea();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      services.cat.armKeyerRepeat(delay: const Duration(seconds: 3), text: 'CQ', send: () {});
      await tester.pump();
      await tester.tap(find.byIcon(MdiIcons.keyboardOutline));
      await tester.pump();
      // Left armed, every typed piece draining restarts the wait, and
      // message 1 keys into the middle of the contact being typed.
      expect(services.cat.keyerRepeatActive.value, isFalse);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('the key going away ends it, rather than bolding words that went nowhere', (tester) async {
      await startTyping(tester);
      await tester.runAsync(() => services.cat.disconnect(services.cat.nodes.single.uuid));
      await tester.pump();
      expect(field(), findsNothing);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('five idle seconds end the mode without stopping what was typed', (tester) async {
      await startTyping(tester);
      await tester.enterText(field(), 'cq cq cq de n0dev');
      await tester.pump(cwLiveTypingIdle);
      expect(field(), findsNothing);
      expect(services.cat.cwSending, isTrue, reason: 'a timeout is Enter, not Escape');
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('the message keying carries on where it was when the mode ends', (tester) async {
      await startTyping(tester);
      await tester.enterText(field(), 'cq cq cq cq cq ');
      final id = services.cat.cwProgress.value!.id;
      await tester.pump(); // the first frame starts the bar; time passes from here
      await tester.pump(const Duration(seconds: 2));
      final before = spansOf(tester).$1.length;
      expect(before, greaterThan(0), reason: 'sanity: part of the message has gone out');
      await tester.pump(cwLiveTypingIdle);
      expect(field(), findsNothing);
      expect(services.cat.cwProgress.value?.id, id, reason: 'nothing was queued again');
      // The trap: a progress view that moves in the tree as the mode ends
      // is a new one, whose bar starts over — the message reads as going
      // out a second time.
      await tester.pump(const Duration(milliseconds: 16));
      expect(spansOf(tester).$1.length, greaterThanOrEqualTo(before));
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('is the CW keyer\'s only: no keyboard in the Phone strip', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host(phone: true));
      services.cat.showKeyerArea();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(MdiIcons.keyboardOutline), findsNothing);
      await tester.pump(const Duration(seconds: 62));
    });
  });
}
