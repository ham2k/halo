// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The keyer's two surfaces: the line in the info area (KeyerArea), which
// shows what is going out while something is, and the keyer control's panel
// (KeyerControls), which holds what starts a message.
//
// Against a real CatService with the placeholder radio (which keys nothing,
// but runs the real send queue and reports a speed like a real rig), so what
// the line shows is what the queue reports, not a hand-built stand-in.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show EsmFacts, MdiIcons;
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/cw_live_typing.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/main_vfo.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';
import 'package:ham2k_logger/views/cw_messages_dialog.dart' show cwMessageNumberIcons;
import 'package:ham2k_logger/views/keyer_area.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

/// Stands in for the `template` hook without booting a JS engine: only
/// `{{ qso.call }}` and `{{ keyer.msgN }}` are filled, which is all a label
/// test needs.
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
    Map<String, dynamic>? next,
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
    services = harness.services;
    // A keying radio becomes the key in use only with the experiment on.
    await harness.settings.setExperimentEnabled('keyer', true);
  });

  Future<void> connectPlaceholder(WidgetTester tester) async {
    final node = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    await tester.runAsync(() => services.cat.connect(node.uuid));
    addTearDown(() => services.cat.disconnect(node.uuid));
    expect(services.cat.canKeyCw, isTrue, reason: 'sanity');
  }

  /// The CW messages, all eight, in place of the seeded set's.
  Future<void> messages(Map<int, (String, String)> entries) async {
    for (var n = 1; n <= 8; n++) {
      await services.settings.setCwMessage(n, entries[n]?.$1 ?? '');
      await services.settings.setCwMessageLabel(n, entries[n]?.$2 ?? '');
    }
  }

  final sent = <int>[];

  /// The line, and under it the panel, as the logging panel lays them out.
  Widget host({
    bool suppressed = false,
    PanelRenderContext? templateContext,
    bool phone = false,
    bool digital = false,
    bool enterSends = false,
    ValueNotifier<EsmFacts?>? esmFacts,
    bool panel = true,
  }) => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            KeyerArea(cat: services.cat, services: services, suppressed: suppressed, phone: phone, digital: digital),
            if (panel)
              KeyerControls(
                services: services,
                phone: phone,
                onSendMessage: (n, radio) => sent.add(n),
                templateContext: templateContext,
                enterSends: enterSends,
                esmFacts: esmFacts == null ? null : {'A': esmFacts},
              ),
          ],
        ),
      ),
    ),
  );

  Finder inLine(Finder finder) => find.descendant(of: find.byType(KeyerArea), matching: finder);
  Finder inPanel(Finder finder) => find.descendant(of: find.byType(KeyerControls), matching: finder);
  Finder button(String label) => inPanel(find.widgetWithText(InkWell, label));
  bool enabled(WidgetTester tester, Finder finder) => tester.widget<InkWell>(finder).onTap != null;

  final messageText = inLine(find.byWidgetPredicate((w) => w is Text && w.textSpan != null));

  /// The rendered message's spans: (sent, pending).
  (String, String) spansOf(WidgetTester tester) {
    final rich = tester.widget<Text>(messageText);
    final spans = (rich.textSpan as TextSpan).children!.cast<TextSpan>();
    return (spans[0].text!, spans[1].text!);
  }

  double lineHeight(WidgetTester tester) => tester.getSize(find.byType(KeyerArea)).height;

  /// Pumps until nothing is keying any more.
  Future<void> pumpUntilIdle(WidgetTester tester) async {
    for (var i = 0; i < 200 && (services.cat.cwProgress.value != null || services.cat.voiceActivity.value != null); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(services.cat.cwProgress.value, isNull, reason: 'sanity: it ended');
  }

  group('the line', () {
    testWidgets('takes no room while nothing is going out', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host(panel: false));
      expect(lineHeight(tester), 0);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets("slides down with a message: the keyer's icon, then the message with sent characters set apart", (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host(panel: false));
      services.cat.sendCw('ET'); // at 22 WPM: E ends at 55 ms, T at 382 ms
      await tester.pump();
      final atStart = lineHeight(tester);
      await tester.pump(const Duration(milliseconds: 100));
      // The trap: showing the line at full size at once — the point of the
      // slide is that what is under it moves down rather than jumps.
      expect(lineHeight(tester), greaterThan(atStart));
      expect(inLine(find.byIcon(MdiIcons.key)), findsOneWidget, reason: 'no pill: the icon says whose line this is');
      await tester.pump(const Duration(milliseconds: 200));
      expect(spansOf(tester), ('E', 'T'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(spansOf(tester), ('ET', ''));
      await tester.pump(const Duration(seconds: 62));
    });

    // A radio reports a memory, and the queue a message, ended a little
    // before the last of it is heard: a line gone at that moment reads as
    // the message cut short.
    testWidgets('stays a second after a message ends, showing it, then slides away', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host(panel: false));
      services.cat.sendCw('ET');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final full = lineHeight(tester);
      await pumpUntilIdle(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(lineHeight(tester), full);
      expect(messageText, findsOneWidget, reason: 'the message it last showed, not an empty line');

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(lineHeight(tester), 0);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('a message during that second keeps it up, showing the new one', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host(panel: false));
      services.cat.sendCw('E');
      await tester.pump();
      await pumpUntilIdle(tester);
      await tester.pump(const Duration(milliseconds: 500));

      services.cat.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(spansOf(tester).$1, startsWith('CQ'), reason: 'the old linger must not take the new message away');
      services.cat.stopCw();
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('a message stopped short leaves at once, not shown going on as if it had gone out', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host(panel: false));
      services.cat.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(messageText, findsOneWidget);
      services.cat.stopCw(); // Esc
      await tester.pump();
      expect(messageText, findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      expect(lineHeight(tester), 0, reason: 'no second of a stopped message');
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('messages pressed while one is keying show behind it, without restarting it', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host(panel: false));
      services.cat.sendCw('ET');
      await tester.pump();
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
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('tapping the message keying stops it and the queue; tapping a queued one drops only it', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host(panel: false));
      services.cat.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K');
      services.cat.sendCw('5NN');
      services.cat.sendCw('TU');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

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

    testWidgets('editing a logged QSO hides it, and it comes back once editing ends', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host(panel: false));
      services.cat.sendCw('CQ CQ CQ DE N0DEV N0DEV N0DEV K CQ CQ CQ DE N0DEV N0DEV N0DEV K');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final full = lineHeight(tester);
      expect(full, greaterThan(0));

      await tester.pumpWidget(host(suppressed: true, panel: false));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(lineHeight(tester), 0, reason: 'a message being corrected is not one to key at');

      await tester.pumpWidget(host(panel: false));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(lineHeight(tester), full, reason: 'still keying, so it returns');
      services.cat.stopCw();
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('a memory playing brings it up by itself, under the microphone', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host(templateContext: contextFor('N0CALL'), phone: true, panel: false));
      expect(lineHeight(tester), 0);
      services.cat.playVoiceMemory(3, repeat: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // The label alone — the icon and the bar say it plays — and a memory
      // with no label is "Message 3", never a bare "M3" under a bar.
      expect(inLine(find.text('Message 3')), findsOneWidget);
      expect(find.textContaining('Playing'), findsNothing);
      expect(inLine(find.byIcon(MdiIcons.microphone)), findsOneWidget);
      // The placeholder's pretend playback ends on its own.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 2)); // the second it stays
      await tester.pump(const Duration(milliseconds: 300)); // and the slide away
      expect(lineHeight(tester), 0, reason: 'gone once nothing is playing');
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('a doubtful play reads like any other: no question mark mid-air', (tester) async {
      await connectPlaceholder(tester);
      await services.settings.setVoiceMessageLabel(2, 'CQ POTA');
      await tester.pumpWidget(host(templateContext: contextFor('N0CALL'), phone: true, panel: false));
      // What a session reports when the radio said "not going" before ever
      // saying "going" — the placeholder never polls, so it is set directly.
      services.cat.voiceActivity.value = const VoiceActivity(memory: 2, doubtful: true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // Doubt is real and still stops a refused play; it is not something to
      // ASK the operator about while audio may be going out, since they
      // cannot answer it from here. The Phone Keyer dialog is where it is said.
      expect(inLine(find.text('CQ POTA')), findsOneWidget);
      expect(find.text('CQ POTA?'), findsNothing);
      services.cat.voiceActivity.value = null;
      await tester.pump(const Duration(seconds: 62));
    });

    // A message made from the operator's words has no measured duration:
    // without the length its activity carries, its bar is the indeterminate
    // one on every play, where a CW message's is paced from the start.
    testWidgets('a message made as it plays paces its bar by the length it was made with', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host(templateContext: contextFor('N0CALL'), phone: true, panel: false));
      services.cat.voiceActivity.value = const VoiceActivity(memory: 2);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(inLine(find.byType(LinearProgressIndicator)), findsOneWidget, reason: 'while it is made, nothing knows how long it runs');
      services.cat.voiceActivity.value = const VoiceActivity(memory: 2, lengthMs: 4000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(inLine(find.byType(LinearProgressIndicator)), findsNothing);
      final bar = tester.widget<FractionallySizedBox>(inLine(find.byType(FractionallySizedBox)));
      expect(bar.widthFactor, closeTo(0.5, 0.01), reason: 'paced from when its length was known');
      services.cat.voiceActivity.value = null;
      await tester.pump(const Duration(seconds: 62));
    });

    // A message made from words shows what it says, set apart as it is said
    // like a CW message's sent characters; shown by its label, the operator
    // cannot tell how far through a call it is.
    testWidgets('a message made from words shows its words, the ones said set apart', (tester) async {
      await connectPlaceholder(tester);
      await services.settings.setVoiceMessageLabel(2, 'Their call');
      await tester.pumpWidget(host(templateContext: contextFor('N0CALL'), phone: true, panel: false));
      // Up while it is made, as a message made from words is.
      services.cat.voiceActivity.value = const VoiceActivity(memory: 2);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      services.cat.voiceActivity.value = const VoiceActivity(
        memory: 2,
        lengthMs: 2000,
        script: VoiceScript('K8AB 59', [(atMs: 0, said: 1), (atMs: 500, said: 2), (atMs: 1000, said: 4), (atMs: 1500, said: 7)]),
      );
      await tester.pump();
      String said() {
        final words = find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == 'K8AB 59');
        final bold = StringBuffer();
        tester.widget<RichText>(inLine(words)).text.visitChildren((span) {
          if (span is TextSpan && span.text != null && span.style?.fontWeight == FontWeight.bold) bold.write(span.text);
          return true;
        });
        return bold.toString();
      }

      await tester.pump(const Duration(milliseconds: 600));
      expect(inLine(find.text('Their call')), findsNothing, reason: 'its words, not its label');
      expect(said(), 'K8');
      await tester.pump(const Duration(milliseconds: 500));
      expect(said(), 'K8AB');
      services.cat.voiceActivity.value = null;
      await tester.pump(const Duration(seconds: 62));
    });

    // The trap: one radio's keyer shown for both sets — radio B's message
    // waiting its turn with nothing on screen to say so, or shown in radio
    // A's info area as if it were going out there.
    testWidgets("under SO2R each radio's line is its own: what it plays, and what waits for the other", (tester) async {
      await services.settings.setExperimentEnabled('so2r', true);
      await services.settings.setSo2rQueueMessages(true);
      final cat = services.cat;
      Future<String> rig(String name) async {
        final node = await cat.addNode(typeKey: 'placeholder-radio', name: name, config: placeholderRadioModel.variants.single.defaultConfig);
        await tester.runAsync(() => cat.connect(node.uuid));
        addTearDown(() => cat.disconnect(node.uuid));
        return node.uuid;
      }

      final left = await rig('Left Rig'), right = await rig('Right Rig');
      await cat.setRadio1(LocalRadio(left));
      await cat.setRadio2(right);
      await services.settings.setVoiceMessageLabel(2, 'CQ LEFT');
      await services.settings.setVoiceMessageLabel(3, 'QRZ RIGHT', radio: 'B');
      await services.settings.setVoiceMessageLabel(4, 'TU RIGHT', radio: 'B');
      Widget line(String radio) => KeyerArea(key: ValueKey(radio), cat: cat, radio: radio, services: services, phone: true);
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(body: Column(children: [line('A'), line('B')])),
          ),
        ),
      );
      Finder inRadio(String radio, Finder finder) => find.descendant(of: find.byKey(ValueKey(radio)), matching: finder);

      cat.keyer('A').playVoiceMemory(2);
      cat.keyer('B').playVoiceMemory(3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(inRadio('A', find.text('CQ LEFT')), findsOneWidget);
      expect(inRadio('A', find.textContaining('RIGHT')), findsNothing);
      expect(inRadio('B', find.text('QRZ RIGHT')), findsOneWidget, reason: "radio B's memory, waiting for radio A");
      expect(inRadio('B', find.byType(LinearProgressIndicator)), findsOneWidget, reason: 'under a bar that cannot say how long');
      cat.keyer('B').queueVoiceMemory(4);
      await tester.pump();
      expect(inRadio('B', find.text(' · TU RIGHT')), findsOneWidget, reason: 'a second memory waiting there, behind the first');
      cat.keyer('A').stopVoice();
      cat.keyer('B').stopVoice();
      await tester.pump(const Duration(seconds: 62));
    });
  });

  group('the panel', () {
    testWidgets('the ESM pill is there only with its experiment, and steps Off, Run, S&P', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host());
      expect(find.text('ESM Off'), findsNothing, reason: "Enter is not the keyer's without EXP ESM");

      await tester.pumpWidget(host(enterSends: true));
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
      await tester.pump(const Duration(seconds: 62));
    });

    group('the next Enter', () {
      const answering = (callEmpty: false, canLog: true, answered: false, hasExchange: true, exchangeCopied: false, callFocused: false, incompleteCall: false);

      bool tinted(WidgetTester tester, String label) {
        final material = find.ancestor(of: button(label), matching: find.byType(Material)).first;
        return tester.widget<Material>(material).color != Colors.transparent;
      }

      // The tint is the operator's read of what Enter is about to key, so it
      // must follow the same step table Enter does — the side of the pileup
      // as much as the entry — and show nothing the Enter would not send.
      testWidgets('tints the messages ESM would key, by the side of the pileup', (tester) async {
        await connectPlaceholder(tester);
        await messages({1: ('CQ', 'CQ'), 2: ('EXCH', 'EXCH'), 3: ('TU', 'TU'), 4: ('MY', 'MY'), 5: ('HIS', 'HIS'), 8: ('AGN', 'AGN')});
        final facts = ValueNotifier<EsmFacts?>(null);
        addTearDown(facts.dispose);
        services.cat.setEnterSends(on: true, running: true);
        await tester.pumpWidget(host(enterSends: true, esmFacts: facts));
        // A tinted label, and `+log` on the one carrying the submit button's
        // icon: an Enter that logs must say so, and one that does not must not.
        List<String> lit() => [
          for (final label in ['CQ', 'EXCH', 'TU', 'MY', 'HIS', 'AGN'])
            if (tinted(tester, label)) find.descendant(of: button(label), matching: find.byIcon(MdiIcons.upload)).evaluate().isEmpty ? label : '$label+log',
        ];

        expect(lit(), isEmpty, reason: 'nothing published: no Enter would reach ESM');

        facts.value = (callEmpty: true, canLog: false, answered: false, hasExchange: true, exchangeCopied: false, callFocused: true, incompleteCall: false);
        await tester.pump();
        expect(lit(), ['CQ']);

        facts.value = answering;
        await tester.pump();
        expect(lit(), ['EXCH', 'HIS']);

        facts.value = (callEmpty: false, canLog: true, answered: true, hasExchange: true, exchangeCopied: true, callFocused: false, incompleteCall: false);
        await tester.pump();
        expect(lit(), ['TU+log']);

        services.cat.setEnterSends(running: false);
        await tester.pump();
        expect(lit(), ['EXCH+log'], reason: 'S&P sends the exchange and logs');

        facts.value = answering;
        await tester.pump();
        expect(lit(), ['MY'], reason: 'S&P calls with our call');

        services.cat.setEnterSends(on: false);
        await tester.pump();
        expect(lit(), isEmpty, reason: 'with ESM off Enter only logs');
        await tester.pump(const Duration(seconds: 62));
      });

      // Voice plays memories and the operator says the call: a memory tinted
      // for their call would be one Enter does not play.
      testWidgets('in a Phone mode, tints the memories but never their call', (tester) async {
        await connectPlaceholder(tester);
        final facts = ValueNotifier<EsmFacts?>(answering);
        addTearDown(facts.dispose);
        services.cat.setEnterSends(on: true, running: true);
        await tester.pumpWidget(host(templateContext: contextFor('N0CALL'), phone: true, enterSends: true, esmFacts: facts));
        await tester.pump();

        expect(tinted(tester, 'M2'), isTrue);
        expect(tinted(tester, 'M5'), isFalse);
        expect(tinted(tester, 'M1'), isFalse);
        await tester.pump(const Duration(seconds: 62));
      });
    });

    testWidgets('the draft turning Digital ends keyboard mode, as Phone does', (tester) async {
      // The keyer control closes when its chip turns disabled, taking the
      // field with it; a mode left on there would key what was typed into
      // the next five idle seconds with nowhere to see or stop it.
      await connectPlaceholder(tester);
      await tester.pumpWidget(host(panel: false));
      services.cat.toggleKeyboardMode();
      await tester.pump();
      expect(services.cat.cwTyping.value, isNotNull);
      await tester.pumpWidget(host(panel: false, digital: true));
      expect(services.cat.cwTyping.value, isNull);
      await tester.pump(const Duration(seconds: 62));
    });

    test('in a Digital mode its chip stays in the row, plainly the Keyer, and disabled', () {
      // A chip that vanished with the mode would move every pill after it;
      // one still reading "25 WPM" would claim a keyer that keys nothing here.
      final digital = keyerHostControl(services: services, superMode: 'Digital').spec();
      expect(digital.enabled, isFalse);
      expect(digital.icon, MdiIcons.key);
      expect(digital.summary, 'Keyer');
      expect(keyerHostControl(services: services, superMode: 'CW').spec().enabled, isTrue);
    });

    // A row whose buttons came and went as messages were written would move
    // every button after the one being edited; a row of eight with the last
    // five empty is buttons nobody can use.
    testWidgets('a button per message up to the last with anything in it; an empty one disabled, a label-less one by its key', (tester) async {
      await connectPlaceholder(tester);
      await messages({1: ('CQ CQ DE N0DEV K', 'CQ'), 3: ('5NN TU', '')});
      await tester.pumpWidget(host());
      await tester.pump();

      expect(button('CQ'), findsOneWidget, reason: 'labelled by its label');
      expect(button('M3'), findsOneWidget, reason: 'or by its key');
      final second = find.ancestor(of: inPanel(find.byIcon(cwMessageNumberIcons[1])), matching: find.byType(InkWell)).first;
      expect(enabled(tester, second), isFalse, reason: 'nothing to send');
      expect(
        find.descendant(of: second, matching: find.byType(Text)),
        findsNothing,
        reason: 'no message and no label: no label either',
      );
      expect(inPanel(find.byIcon(cwMessageNumberIcons[3])), findsNothing, reason: 'nothing past the last message');

      sent.clear();
      await tester.tap(button('M3'));
      expect(sent, [3]);
      await tester.pump(const Duration(seconds: 62));
    });

    // A template on a button reads as noise until it is rendered, and which
    // buttons show and what they say waits on what the labels read.
    testWidgets('a label written as a template is rendered before the buttons show, and follows the draft, debounced', (tester) async {
      await connectPlaceholder(tester);
      await messages({1: ('{{ qso.call }} 5NN TU', '{{ qso.call }} RST'), 2: ('TU', 'Thanks')});
      final extensions = services.extensions as _TemplateExtensions;
      await tester.pumpWidget(host(templateContext: contextFor('K1ABC')));
      expect(button('{{ qso.call }} RST').hitTestable(), findsNothing, reason: 'hidden until the render lands');
      await tester.pump();
      await tester.pump();
      expect(button('K1ABC RST').hitTestable(), findsOneWidget);
      expect(button('Thanks').hitTestable(), findsOneWidget, reason: 'a plain label never goes to the bridge');
      expect(extensions.batches, 1, reason: 'one crossing for every label');

      // The draft moves: the label follows, after the delay, not per letter.
      await tester.pumpWidget(host(templateContext: contextFor('W2XYZ')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(button('K1ABC RST'), findsOneWidget, reason: 'the old text holds while the debounce runs');
      await tester.pump(cwLabelRenderDelay);
      await tester.pump();
      expect(button('W2XYZ RST'), findsOneWidget);
      expect(extensions.batches, 2);
      await tester.pump(const Duration(seconds: 62));
    });

    // The panel is mounted each time the keyer control opens: a render per
    // open would cross the bridge again for a draft that has not moved, and
    // show nothing until it came back.
    testWidgets('opened again for the same draft, the labels show at once, rendered once', (tester) async {
      await connectPlaceholder(tester);
      await messages({1: ('CQ', '{{ qso.call }} AGAIN')});
      final extensions = services.extensions as _TemplateExtensions;
      final draft = contextFor('N0REP');
      await tester.pumpWidget(host(templateContext: draft));
      await tester.pump();
      await tester.pump();
      expect(button('N0REP AGAIN').hitTestable(), findsOneWidget);
      final batches = extensions.batches;

      await tester.pumpWidget(host(templateContext: draft, panel: false));
      await tester.pumpWidget(host(templateContext: draft));
      expect(button('N0REP AGAIN').hitTestable(), findsOneWidget, reason: 'the first frame, not after a render');
      await tester.pump(const Duration(seconds: 1));
      expect(extensions.batches, batches);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('with nothing that can key CW, it says so where the buttons would be', (tester) async {
      // A capability, not a connection: buttons that can never work are
      // replaced by the reason, while a capable rig that is off keeps them.
      await messages({1: ('CQ', 'CQ')});
      await tester.pumpWidget(host());
      expect(find.text('Not supported by current radio'), findsOneWidget);
      expect(button('CQ'), findsNothing);
    });

    testWidgets("in a Phone mode it is the voice keyer's: a button per memory, playing straight through the keyer", (tester) async {
      await connectPlaceholder(tester);
      await services.settings.setVoiceMessageLabel(2, 'CQ POTA');
      await tester.pumpWidget(host(templateContext: contextFor('N0CALL'), phone: true));

      expect(button('M1'), findsOneWidget);
      expect(button('CQ POTA'), findsOneWidget);
      expect(button('M8'), findsOneWidget, reason: 'the placeholder has eight, and says nothing of which hold audio');
      expect(inPanel(find.byIcon(MdiIcons.keyboardOutline)), findsNothing, reason: "keyboard mode is the CW keyer's");

      await tester.tap(button('CQ POTA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // the line slides in
      expect(services.cat.voiceActivity.value?.memory, 2);
      expect(inLine(find.text('CQ POTA')), findsOneWidget);
      // Tapping it stops it (Esc's other form).
      await tester.tap(inLine(find.text('CQ POTA')));
      await tester.pump();
      expect(services.cat.voiceActivity.value, isNull);
      await tester.pump(const Duration(seconds: 62));
    });

    // Unshown, a memory pressed over another looks lost until it starts;
    // and with no way to drop one, a wrong press can only be Escaped with
    // everything else.
    testWidgets('a memory pressed while one plays waits behind it on the line, and a tap drops it', (tester) async {
      await connectPlaceholder(tester);
      await services.settings.setVoiceMessageLabel(2, 'CQ POTA');
      await services.settings.setVoiceMessageLabel(4, 'Thanks');
      await tester.pumpWidget(host(templateContext: contextFor('N0CALL'), phone: true));

      await tester.tap(button('CQ POTA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // the line slides in
      await tester.tap(button('M3'));
      await tester.tap(button('Thanks'));
      await tester.pump();
      expect(services.cat.voiceActivity.value?.memory, 2, reason: 'queued, not played over the one going out');
      expect(inLine(find.text(' · Message 3')), findsOneWidget);
      expect(inLine(find.text(' · Thanks')), findsOneWidget);

      await tester.tap(inLine(find.text(' · Message 3')));
      await tester.pump();
      expect(inLine(find.text(' · Message 3')), findsNothing);
      expect(inLine(find.text(' · Thanks')), findsOneWidget, reason: 'only the one tapped goes');
      expect(services.cat.voiceActivity.value?.memory, 2, reason: 'the memory playing plays on');

      services.cat.stopVoice();
      await tester.pump();
      expect(inLine(find.text(' · Thanks')), findsNothing, reason: 'a stop takes the queue with it');
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('the repeat button turns message 1 repeating on and off, ending a chain counting down', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host());
      expect(services.settings.cwRepeat, isFalse);
      await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.repeatOff));
      await tester.pump();
      expect(services.settings.cwRepeat, isTrue);

      services.cat.armKeyerRepeat(delay: const Duration(seconds: 3), text: 'CQ', send: () {});
      await tester.tap(find.widgetWithIcon(IconButton, MdiIcons.repeat));
      await tester.pump();
      expect(services.settings.cwRepeat, isFalse);
      expect(services.cat.keyerRepeatActive.value, isFalse, reason: 'off is a stop, not only a setting for the next CQ');
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('its settings button opens the CW messages, whose speed field sets the radio within its range', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(host());
      await tester.tap(find.bySemanticsLabel('CW Keyer Messages'));
      await tester.pumpAndSettle();

      final range = services.cat.keyerSpeedRange!;
      final offered = [for (final item in tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).items!) item.value];
      expect(offered.first, range.min);
      expect(offered.last, range.max, reason: 'nothing past what the keyer takes');
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25 WPM').last);
      await tester.pumpAndSettle();
      expect(services.cat.keyerSpeed, 25, reason: 'the placeholder reported the set back, like a real rig');
      await tester.pump(const Duration(seconds: 62));
    });

    // One strip for both SO2R sets: a panel that stayed radio A's would key
    // radio A from set B.
    testWidgets("under SO2R it is the operator's set's radio's", (tester) async {
      await services.settings.setExperimentEnabled('so2r', true);
      final cat = services.cat;
      Future<String> rig(String name) async {
        final node = await cat.addNode(typeKey: 'placeholder-radio', name: name, config: placeholderRadioModel.variants.single.defaultConfig);
        await tester.runAsync(() => cat.connect(node.uuid));
        addTearDown(() => cat.disconnect(node.uuid));
        return node.uuid;
      }

      final left = await rig('Left Rig'), right = await rig('Right Rig');
      await cat.setRadio1(LocalRadio(left));
      await cat.setRadio2(right);
      await services.settings.setVoiceMessageLabel(2, 'CQ LEFT');
      await services.settings.setVoiceMessageLabel(2, 'CQ RIGHT', radio: 'B');
      await tester.pumpWidget(host(phone: true));
      expect(button('CQ LEFT'), findsOneWidget);

      cat.noteOperatorRadio('B');
      await tester.pump();
      expect(button('CQ RIGHT'), findsOneWidget);
      await tester.tap(button('CQ RIGHT'));
      await tester.pump();
      expect(cat.keyer('B').voiceActivity.value?.memory, 2);
      expect(cat.keyer('A').voiceActivity.value, isNull);
      cat.keyer('B').stopVoice();
      await tester.pump(const Duration(seconds: 62));
    });
  });

  group('keyboard mode', () {
    final callFocus = FocusNode();
    var advanced = 0;

    /// What the logging panel puts around them: a call field holding the
    /// focus, and Space bound panel-wide to advance to the next field.
    Widget panelHost() => TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.space): () => advanced++},
            child: Column(
              children: [
                TextField(focusNode: callFocus, autofocus: true),
                KeyerArea(cat: services.cat, services: services),
                KeyerControls(services: services, phone: false, onSendMessage: (n, radio) => sent.add(n)),
              ],
            ),
          ),
        ),
      ),
    );

    Finder field() => inPanel(find.byType(TextField));

    Future<void> startTyping(WidgetTester tester) async {
      await connectPlaceholder(tester);
      await messages({1: ('CQ CQ DE N0DEV K', 'CQ'), 2: ('5NN', '5NN')});
      await tester.pumpWidget(panelHost());
      await tester.tap(find.byIcon(MdiIcons.keyboardOutline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // the line slides in
    }

    testWidgets('takes the keyboard from the call field', (tester) async {
      await startTyping(tester);
      // The trap: `autofocus`, which only takes a focus nobody holds — the
      // operator presses the button and types into the call field.
      expect(callFocus.hasFocus, isFalse);
      expect(tester.widget<TextField>(field()).focusNode!.hasFocus, isTrue);
      await tester.pump(const Duration(seconds: 62));
    });

    // The field takes the buttons' place: the buttons after it moving as the
    // mode comes and goes would put the repeat under the pointer meant for
    // the keyboard.
    testWidgets("the field takes the message buttons' place at their width, and the buttons after them stay put", (tester) async {
      await connectPlaceholder(tester);
      await messages({1: ('CQ CQ DE N0DEV K', 'CQ'), 2: ('5NN', '5NN')});
      await tester.pumpWidget(panelHost());
      final repeatAt = tester.getTopLeft(find.byIcon(MdiIcons.repeatOff));
      await tester.tap(find.byIcon(MdiIcons.keyboardOutline));
      await tester.pump();
      expect(field(), findsOneWidget);
      expect(button('CQ').hitTestable(), findsNothing, reason: 'under the field');
      expect(tester.getTopLeft(find.byIcon(MdiIcons.repeatOff)), repeatAt);
      expect(tester.getSize(field()).height, tester.getSize(find.ancestor(of: button('CQ'), matching: find.byType(Material)).first).height);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets("Space types a space, not the panel's next-field", (tester) async {
      await startTyping(tester);
      await tester.enterText(field(), 'k');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(advanced, 0);
      expect(tester.widget<TextField>(field()).controller!.text, 'K ');
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets("a keystroke never resets the keyboard's composing word", (tester) async {
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
      final states = [
        for (final call in tester.testTextInput.log)
          if (call.method == 'TextInput.setEditingState') call.arguments as Map,
      ];
      expect(states.every((state) => state['composingBase'] == 3), isTrue, reason: '$states');
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

    testWidgets("Escape stopping the key first (the operation view's handler) keys nothing held", (tester) async {
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
      await tester.tap(messageText);
      await tester.pump();
      expect(services.cat.cwSending, isFalse, reason: 'DE N0DEV must not go out after the stop');
      expect(field(), findsOneWidget, reason: 'the mode stays, ready for a fresh message');
      expect(tester.widget<TextField>(field()).controller!.text, isEmpty);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('⌥K starts it and asks for the keyer control, where its field is, and ends it', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(panelHost());
      final requests = services.cat.keyer('A').keyboardModeRequests.value;
      services.cat.toggleKeyboardMode();
      await tester.pump();
      expect(field(), findsOneWidget);
      expect(services.cat.keyer('A').keyboardModeRequests.value, requests + 1, reason: 'what opens the keyer control');
      await tester.pump(const Duration(seconds: 1));
      expect(lineHeight(tester), greaterThan(0), reason: 'the line is up while the mode is on');
      services.cat.toggleKeyboardMode();
      await tester.pump();
      expect(field(), findsNothing);
      await tester.pump(const Duration(seconds: 62));
    });

    testWidgets('starting it ends a CQ repeat', (tester) async {
      await connectPlaceholder(tester);
      await tester.pumpWidget(panelHost());
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
      // The trap: a progress view that is rebuilt as the mode ends is a new
      // one, whose bar starts over — the message reads as going out again.
      await tester.pump(const Duration(milliseconds: 16));
      expect(spansOf(tester).$1.length, greaterThanOrEqualTo(before));
      await tester.pump(const Duration(seconds: 62));
    });
  });
}
