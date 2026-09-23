// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Sent and Rcvd reports: the default a mode implies, completing a
// shorthand report, jumpAfterRST, and switchSentRcvd.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  testWidgets('a radio mode change refreshes the default RST placeholder', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '59');

    fakeRadio.setVfo('vfoA', freq: 14030, mode: 'CW');
    await tester.pumpAndSettle();

    // A seed that sets the mode without rebuilding the fields leaves 59
    // standing in for a CW report — and 59 is what then gets logged.
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '599');
  });

  testWidgets('a radio mode change leaves an RST the operator edited alone', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.pump();

    fakeRadio.setVfo('vfoA', freq: 14030, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).controller!.text, '57');
  });

  // The default report is a placeholder, never real text: an operator reaching
  // for Sent to give a true 57 must be able to type it, not clear a pre-filled
  // 59 first. What gets LOGGED is unchanged — the default becomes real on the
  // way out, so nothing downstream (export, scoring, LoTW) ever sees a blank
  // report.
  testWidgets('HALO-83: a blank RST shows the mode default as a placeholder and logs it as a real value', (tester) async {
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(field('Sent').controller!.text, isEmpty, reason: 'the default must not be pre-filled');
    expect(field('Rcvd').controller!.text, isEmpty);
    expect(field('Sent').decoration!.hintText, '59');
    expect(field('Rcvd').decoration!.hintText, '59');

    // One keystroke replaces the default outright — the thing a pre-filled
    // "59" costs you.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.sentRST, '57', reason: 'a typed report wins over the default');
    expect(logged.single.receivedRST, '59', reason: 'the untouched placeholder is what gets stored');
  });

  testWidgets('HALO-83: a shorthand report is completed when focus leaves the field', (tester) async {
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5');
    await tester.pump();
    expect(field('Sent').controller!.text, '5', reason: 'never mid-keystroke — 5 could still be becoming 57');

    // Space is the ordinary way out of a report field.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5 ');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'test setup');
    expect(field('Sent').controller!.text, '55');
  });

  testWidgets('HALO-83: the report the operator logs from is completed too, though Enter never blurs it', (tester) async {
    // The trap: expanding only on blur (which is all PoLo does, where Enter
    // DOES blur) leaves the very field the operator submitted from carrying a
    // bare "5" into the record — and it is the last field they touch, so it is
    // the commonest one.
    await tester.pumpWidget(host());
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '4');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.receivedRST, '44');
  });

  testWidgets('HALO-83: on CW a shorthand report gains its tone digit', (tester) async {
    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeInterpretCommand)));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'CW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '5');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.mode, 'CW', reason: 'test setup');
    expect(logged.single.sentRST, '579');
    expect(logged.single.receivedRST, '559');
  });

  testWidgets('HALO-83: the operator\'s own default report replaces the standard one', (tester) async {
    // A CW operator sending "5NN" wants that in the log, not 599 — and the
    // placeholder has to show what will actually be stored, or the setting is
    // invisible until the QSO is already logged.
    await tester.pumpWidget(
      host(
        commands: CommandHooks(interpretCommand: fakeInterpretCommand),
        prefs: LoggingPreferences(defaultReportCW: '5NN'),
      ),
    );
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(field('Sent').decoration!.hintText, '59', reason: 'test setup: still on phone');

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'CW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));
    expect(field('Sent').decoration!.hintText, '5NN');

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.sentRST, '5NN');
    expect(logged.single.receivedRST, '5NN');
  });

  testWidgets('HALO-83: editing a saved QSO with no RST does not invent one', (tester) async {
    // A blank field on a saved record is stored data, not a stand-in — filling
    // it in would rewrite a QSO the operator only opened to look at, and the
    // hint has to stay away for the same reason (it would promise a value the
    // save never writes).
    final existingQso = (await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'startAtMillis': 1000000,
        'freq': 7100,
        'mode': 'SSB',
      }),
    ))!;
    var saved = false;
    await tester.pumpWidget(
      host(
        session: LoggingSession(editingQso: existingQso, onEditCanceled: () => saved = true),
      ),
    );
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(field('Sent').controller!.text, isEmpty);
    expect(field('Sent').decoration!.hintText, isNull);

    // From a field: with nothing focused, the Enter reaches no handler and
    // nothing is saved for the assertions below to be about.
    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // The save changes nothing it can be recognised by, so the wait is on
    // the panel closing the edit, which it does only once the write returned.
    final logged = await waitForQsosWhere(tester, 'the edit to be saved', (_) => saved);
    expect(logged.single.sentRST, anyOf(isNull, isEmpty));
    expect(logged.single.receivedRST, anyOf(isNull, isEmpty));
  });

  testWidgets('HALO-143: jumpAfterRST moves on once a report is complete, and stays put until then', (tester) async {
    await tester.pumpWidget(host(prefs: LoggingPreferences(jumpAfterRST: true)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();

    // One digit is not a report — jumping here would make a true 57
    // untypeable.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'two characters is a full report on phone');

    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '59');
    await tester.pump();
    expect(field('Their call').focusNode!.hasFocus, isTrue, reason: 'the last report wraps on to the callsign');
  });

  testWidgets('HALO-143: jumpAfterRST waits for the tone digit on CW, so aurora reports stay typeable', (tester) async {
    // The trap a two-character threshold would set: on CW a `44` still owes
    // its `A` (or its tone), so jumping at two makes `44A` and `5NN`
    // unreachable — the operator is thrown into the next field mid-report.
    await tester.pumpWidget(
      host(
        commands: CommandHooks(interpretCommand: fakeInterpretCommand),
        prefs: LoggingPreferences(jumpAfterRST: true),
      ),
    );
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'CW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '44');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue, reason: 'two characters is not a full CW report');

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '44A');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue);
    expect(field('Sent').controller!.text, '44A', reason: 'the aurora report survives intact');
  });

  testWidgets('HALO-143: jumpAfterRST does not fire while correcting an already-complete report', (tester) async {
    // PoLo tests `length >= full` on every keystroke, so editing a field that
    // already holds a full report throws focus away on the first character.
    // Firing on the upward crossing only is what makes a correction possible.
    await tester.pumpWidget(host(prefs: LoggingPreferences(jumpAfterRST: true)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '59');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'test setup: it jumped once');

    // Back to Sent to fix it. Every keystroke from here leaves the field at or
    // above the full length, and none of them may jump.
    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '599');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5991');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: jumpAfterRST off leaves focus alone', (tester) async {
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '59');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: jumpAfterRST does not apply on the FT modes, whose report has no fixed length', (tester) async {
    // -9, +05 and -12 are all real SNR reports, so no length means "done".
    // Any threshold here is wrong for some of them; the setting sits out.
    await tester.pumpWidget(
      host(
        commands: CommandHooks(interpretCommand: fakeInterpretCommand),
        prefs: LoggingPreferences(jumpAfterRST: true),
      ),
    );
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'FT8');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '-12');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: switchSentRcvd swaps the row and the keyboard path through it together', (tester) async {
    // The pair that must not drift: the row's own order and the Space cycle's.
    // A swap applied to only one of them leaves Space skipping backwards
    // through fields the operator sees left to right.
    await tester.pumpWidget(host(prefs: LoggingPreferences(switchSentRcvd: true)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    double left(String label) => tester.getTopLeft(find.widgetWithText(TextField, label)).dx;
    expect(left('Rcvd'), lessThan(left('Sent')), reason: 'Rcvd is drawn first');

    // Space walks Call → Rcvd → Sent, following what is on screen. Entered in
    // two steps because the interceptor only claims a genuine single-space
    // insertion at the end of the value, not a bulk replacement that happens
    // to end in one.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW ');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'Space reaches the leftmost report first');

    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), ' ');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: focusing a complete report on a QSO opened for editing does not jump', (tester) async {
    // A QSO CONSTRUCTED already-editing is populated before the jump
    // listeners exist, so the baseline they compare against has to be seeded
    // from the fields rather than left at zero. Without it this needs no
    // typing at all to go wrong: gaining focus collapses the selection, which
    // is a value change, which reads as "0 -> 3" and jumps — and the next
    // field, equally unseeded, jumps again. Tapping Sent to fix a 599 walks
    // the operator straight past Rcvd and out of the reports entirely.
    final existingQso = (await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'our': {'sent': '599'},
        'their': {'call': 'W1AW', 'sent': '599'},
        'startAtMillis': 1000000,
        'freq': 7020,
        'mode': 'CW',
      }),
    ))!;
    await tester.pumpWidget(
      host(
        session: LoggingSession(editingQso: existingQso),
        prefs: LoggingPreferences(jumpAfterRST: true),
      ),
    );
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(field('Sent').controller!.text, '599', reason: 'test setup');
    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue, reason: 'merely arriving in a full field must not move on');

    // And a correcting keystroke on top of it stays put too.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5991');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: switchSentRcvd reaches the More pane, which is a separate order expression', (tester) async {
    // The pane round-trips through a Map of field keys, not through the
    // controllers the row shares, so its order is written out a second time —
    // and a second expression is a second chance to get the ternary backwards.
    // A pane contradicting the row that opened it is the whole failure.
    await tester.pumpWidget(host(prefs: LoggingPreferences(switchSentRcvd: true)));
    await openControl(tester, MdiIcons.pencil);
    await tester.pumpAndSettle();

    final sent = find.text('Sent');
    final rcvd = find.text('Rcvd');
    expect(sent, findsWidgets);
    expect(rcvd, findsWidgets);
    expect(tester.getTopLeft(rcvd.last).dy, lessThan(tester.getTopLeft(sent.last).dy), reason: 'the pane stacks its fields, so Rcvd first means Rcvd higher');
  });

  testWidgets('HALO-143: switchSentRcvd keeps each value on its own field, it only moves them', (tester) async {
    // The failure a pure-display swap invites: reversing the widgets without
    // reversing what they are bound to silently logs the reports backwards.
    await tester.pumpWidget(host(prefs: LoggingPreferences(switchSentRcvd: true)));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '33');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.sentRST, '57');
    expect(logged.single.receivedRST, '33');
  });
}
