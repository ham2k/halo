// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SO2R: two LoggingControls, one per radio, under one strip
// (docs/design/logging-fields.md § SO2R).

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_widgets/src/logging_controls_info_frame.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  late So2rLink link;
  late FakeVfoStore radioB;

  setUp(() {
    link = So2rLink();
    addTearDown(link.dispose);
    radioB = FakeVfoStore()..setVfo('vfoA', freq: 7025, mode: 'CW');
    addTearDown(radioB.dispose);
  });

  Widget twoSets({List<Qso> qsos = const [], LookupHooks lookups = const LookupHooks(), void Function(String radio)? onToggleRunning, String? transmitting}) {
    LoggingControls set(String radio, FakeVfoStore store) => LoggingControls(
      key: ValueKey('set-$radio'),
      so2r: So2rSet(radio: radio, link: link, running: radio == 'A', onToggleRunning: () => onToggleRunning?.call(radio), transmitting: radio == transmitting),
      log: LogHooks(operation: operation, qsosRepository: baseLog().qsosRepository, qsos: qsos),
      radio: RadioHookup(radioService: store, radioUpdates: store),
      prefs: LoggingPreferences(keyboardAccessory: keyboardAccessory),
      lookups: lookups,
    );
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            set('A', tunedRadio),
            set('B', radioB),
          ],
        ),
      ),
    );
  }

  Finder inSet(String radio, Finder finder) => find.descendant(of: find.byKey(ValueKey('set-$radio')), matching: finder);
  bool callFocused(WidgetTester t, String radio) {
    final semantics = inSet(radio, find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'field.call'));
    return t.widget<TextField>(find.descendant(of: semantics, matching: find.byType(TextField))).focusNode!.hasFocus;
  }

  testWidgets('one strip, drawn by set A, holding Time, both radios and nothing else', (t) async {
    await t.pumpWidget(twoSets());
    await t.pump();

    expect(inSet('B', find.byType(SecondaryControlRow)), findsNothing, reason: 'set B draws no strip of its own');
    expect(inSet('A', find.byType(SecondaryControlRow)), findsOneWidget);
    // The two Radio pills are told apart by their radio, and each reads its
    // own VFO — B's must not be a second copy of A's.
    expect(find.textContaining(RegExp(r'^A 14\D285'), findRichText: true), findsOneWidget);
    expect(find.textContaining(RegExp(r'^B 7\D025'), findRichText: true), findsOneWidget);
    expect(find.byIcon(MdiIcons.dotsHorizontal), findsNothing, reason: 'More is not one of the strip\'s controls under SO2R');
  });

  // The trap: a host rebuilding on everything the link fires for, set B's
  // Radio control edits included — some made while set B is being rebuilt —
  // is marked dirty mid-build. The host listens to the set alone.
  testWidgets("the host's activeSet fires for a change of set, never for an edit to Radio B", (t) async {
    final sets = twoSets();
    await t.pumpWidget(ValueListenableBuilder(valueListenable: link.activeSet, builder: (_, _, _) => sets));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.textContaining(RegExp(r'^B 7\D025'), findRichText: true), findsOneWidget, reason: "set A's strip still learns of Radio B");

    var fired = 0;
    link.activeSet.addListener(() => fired++);
    link.radioB!.freqController.text = '7030';
    expect(fired, 0);
    link.noteActive('B');
    expect(fired, 1);
  });

  testWidgets("each set's pill names its own radio, band and Run or S&P", (t) async {
    await t.pumpWidget(twoSets());
    await t.pump();
    for (final (radio, band, mode) in [('A', '20m', 'Run'), ('B', '40m', 'S&P')]) {
      final pill = find.descendant(
        of: find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'so2r.pill.$radio'),
        matching: find.byType(Text),
      );
      expect(t.widgetList<Text>(pill).map((text) => text.data), [radio, band, mode], reason: 'set $radio: letter, band, then Run or S&P');
    }
  });

  // The trap: stats over the whole operation, so both sets read alike and
  // neither tells the operator how its own radio is doing.
  testWidgets("each set's stats count its own radio's contacts, the unmarked ones as A's", (t) async {
    Qso qso(String uuid, [String? radio]) => Qso(
      uuid: uuid,
      operationUuid: operation.uuid,
      data: {
        if (radio != null) 'our': {'radio': radio},
      },
    );
    await t.pumpWidget(
      twoSets(
        qsos: [qso('1', 'A'), qso('2'), qso('3', 'B')],
        lookups: LookupHooks(operationStatsLines: (qsos) => ['${qsos.length} counted: ${qsos.map((q) => q.uuid).join(',')}']),
      ),
    );
    await t.pump();
    expect(inSet('A', find.text('2 counted: 1,2')), findsOneWidget);
    expect(inSet('B', find.text('1 counted: 3')), findsOneWidget);
  });

  // The pill sits before the callsign field only; without the inset the info
  // area runs on under the pill and its text starts left of the field's.
  testWidgets("each set's info area starts where its callsign field does", (t) async {
    await t.pumpWidget(twoSets());
    await t.pump();
    for (final radio in ['A', 'B']) {
      final call = inSet(radio, find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'field.call'));
      final info = inSet(radio, find.byType(LoggingInfoFrame));
      expect(t.getTopLeft(info).dx, moreOrLessEquals(t.getTopLeft(call).dx), reason: 'set $radio');
    }
  });

  // The trap: the Run / S&P line is inside the pill, whose own tap opens the
  // radio's control — a tap meant to flip the mode would open it instead.
  testWidgets("a tap on a pill's Run / S&P line flips that radio's mode, and opens nothing", (t) async {
    final toggled = <String>[];
    await t.pumpWidget(twoSets(onToggleRunning: toggled.add));
    await t.pump();
    await t.tap(inSet('B', find.text('S&P')));
    await settleControl(t);
    expect(toggled, ['B']);
    expect(link.radioB!.freqFocus.hasFocus, isFalse, reason: "Radio B's control stays closed");
  });

  // The trap: the pill shows the set with the keyboard, and the radio on the
  // air is often the OTHER one — a CQ running on A while the operator works B.
  testWidgets("the pill of the radio on the air is red, whichever set has the keyboard", (t) async {
    await t.pumpWidget(twoSets(transmitting: 'B'));
    await t.pump();
    Color pillColor(String radio) => t
        .widget<Material>(
          find
              .descendant(of: find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'so2r.pill.$radio'), matching: find.byType(Material))
              .first,
        )
        .color!;
    final error = Theme.of(t.element(find.byKey(const ValueKey('set-A')))).colorScheme.error;
    expect(link.active, 'A');
    expect(pillColor('B'), error);
    expect(pillColor('A'), isNot(error));
  });

  // The trap: both call fields autofocused, the last to mount (B) wins, and
  // every SO2R session starts on the second radio.
  testWidgets("set A's callsign field is the default focus, and the ladder runs A ⇄ B", (t) async {
    // A desktop: on a phone with no keyboard nothing takes the default focus.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await t.pumpWidget(twoSets());
      await t.pump();
      expect(callFocused(t, 'A'), isTrue);
      expect(callFocused(t, 'B'), isFalse);

      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      expect(callFocused(t, 'B'), isTrue, reason: 'Down from set A is set B');
      expect(link.active, 'B');

      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.pump();
      expect(callFocused(t, 'A'), isTrue, reason: 'Up from set B is set A, not the strip');
      expect(link.active, 'A');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // The trap: SO2R turned on remounting set A, whose old element's dispose
  // runs after the new one's mount and detaches the controller it had just
  // attached — the dev bridge, focus after a row pick and ⌘Z gone silent.
  testWidgets('turning SO2R on keeps set A mounted, attached and joined to the link', (t) async {
    final controller = LoggingControlsController();
    Widget panel({required bool so2r}) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            LoggingControls(
              key: const ValueKey('set-A'),
              so2r: so2r ? So2rSet(radio: 'A', link: link) : null,
              log: LogHooks(operation: operation, qsosRepository: baseLog().qsosRepository),
              session: LoggingSession(controller: controller),
              radio: RadioHookup(radioService: tunedRadio, radioUpdates: tunedRadio),
              prefs: LoggingPreferences(keyboardAccessory: keyboardAccessory),
            ),
            if (so2r)
              LoggingControls(
                key: const ValueKey('set-B'),
                so2r: So2rSet(radio: 'B', link: link),
                log: LogHooks(operation: operation, qsosRepository: baseLog().qsosRepository),
                radio: RadioHookup(radioService: radioB, radioUpdates: radioB),
                prefs: LoggingPreferences(keyboardAccessory: keyboardAccessory),
              ),
          ],
        ),
      ),
    );
    await t.pumpWidget(panel(so2r: false));
    // The strip's chips finish coming in, as they have long before anyone
    // types EXP SO2R.
    await t.pumpAndSettle();
    final state = t.state(find.byKey(const ValueKey('set-A')));
    await t.pumpWidget(panel(so2r: true));
    await t.pumpAndSettle();
    expect(t.state(find.byKey(const ValueKey('set-A'))), same(state));
    expect(controller.isAttached, isTrue);
    expect(find.textContaining(RegExp(r'^B 7\D025'), findRichText: true), findsOneWidget, reason: "set A joined the link, so its strip shows Radio B");

    await t.pumpWidget(panel(so2r: false));
    await t.pumpAndSettle();
    expect(controller.isAttached, isTrue);
    expect(link.radioB, isNull, reason: 'set B left with SO2R');

    // Off while in set B, and on again: the keyboard is in set A, and so is
    // what the panel speaks for and keys from.
    link.noteActive('B');
    await t.pumpWidget(panel(so2r: true));
    await t.pumpAndSettle();
    expect(link.active, 'A');
  });

  testWidgets("a tap on set B's pill opens Radio B in set A's strip", (t) async {
    await t.pumpWidget(twoSets());
    await t.pump();
    await t.tap(inSet('B', find.text('40m')));
    await settleControl(t);
    final freq = find.byWidgetPredicate((w) => w is TextField && identical(w.focusNode, link.radioB!.freqFocus));
    expect(freq, findsOneWidget, reason: "Radio B's own frequency field, in the shared strip");
    expect(link.radioB!.freqFocus.hasFocus, isTrue);
  });
}
