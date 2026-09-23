// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Power control: whether it is in the row, where its value comes from,
// the More pane's Power field, and what reaches the contact and the VFO.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  group('Power control', () {
    // The whole feature's premise: power is optional, and the operator asks
    // for it. A control that shipped ON would put a watts field in front of
    // every operator who never logs power.
    testWidgets('is not in the row until the operator has asked for it', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.byIcon(MdiIcons.flash), findsNothing);
    });

    // The saved order is what records the operator's decision — the settings
    // dialog always writes every key it offered — so a control named there
    // and absent from the hidden set is one they kept.
    testWidgets('appears once the saved order names it', (tester) async {
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power'])));
      await tester.pump();

      expect(find.byIcon(MdiIcons.flash), findsOneWidget);
    });

    testWidgets('stays out when the operator turned it off', (tester) async {
      // Named in the order (so the decision was made) AND hidden — the
      // "decided against" state, which must not read as "never asked".
      await tester.pumpWidget(
        host(
          strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power'], hiddenControlKeys: const {'power'}),
        ),
      );
      await tester.pump();

      expect(find.byIcon(MdiIcons.flash), findsNothing);
    });

    testWidgets('a typed power reaches the VFO when the field loses focus', (tester) async {
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power'])));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);

      await tester.enterText(find.widgetWithText(TextField, 'Power'), '5');
      await tester.pump();
      expect(tunedRadio.vfoA.power, isNull, reason: 'mid-typing, "1" of "100" must not reach the radio');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(tunedRadio.vfoA.power, 5, reason: 'the VFO is the one home for power — CAT forwards it to the rig from there');
    });

    testWidgets('the field mirrors a power the VFO already carries', (tester) async {
      final radio = FakeVfoStore()
        ..setVfo('vfoA', freq: 14285, mode: 'SSB')
        ..setVfo('vfoA', power: 100);
      await tester.pumpWidget(
        host(
          radio: baseRadio().copyWith(radioService: radio),
          strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power']),
        ),
      );
      await tester.pump();
      await openControl(tester, MdiIcons.flash);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Power')).controller!.text, '100');
    });

    testWidgets('a logged QSO carries the power while the control is shown', (tester) async {
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power'])));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);
      await tester.enterText(find.widgetWithText(TextField, 'Power'), '5');
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.power, 5, reason: 'showing the control is the operator asking for the power to be logged');
    });

    testWidgets('a QSO logged without the control carries no power', (tester) async {
      // The other half of the rule. Without it the stamp would be
      // unconditional, and every operator would silently start logging
      // whatever power the app last heard about.
      final radio = FakeVfoStore()
        ..setVfo('vfoA', freq: 14285, mode: 'SSB')
        ..setVfo('vfoA', power: 100);
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: radio)));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.power, isNull);
    });

    testWidgets('the More pane offers a Power field, after Mode', (tester) async {
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power'])));
      await tester.pump();
      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();

      final power = find.text('Power');
      expect(power, findsWidgets);
      // The pane stacks its fields, so "after Mode" is "lower than Mode" —
      // and still inside the QSO section, which is what stops it drifting
      // down among the fields that describe something else. Ours is the one
      // in that section: "Their power" is a different field, further down.
      expect(tester.getTopLeft(power.last).dy, greaterThan(tester.getTopLeft(find.text('Mode').last).dy));
      expect(tester.getTopLeft(power.last).dy, lessThan(tester.getTopLeft(find.text('Their info').last).dy));
    });

    testWidgets('the pane offers it while the app captures power, with the control out of the row', (tester) async {
      // Station Configuration's "Track Station Info" stamps the power on
      // every QSO. A value being logged that the entry cannot show is a value
      // nothing can correct.
      await tester.pumpWidget(host(radio: baseRadio().copyWith(trackingPower: true)));
      await tester.pump();
      expect(find.byIcon(MdiIcons.flash), findsNothing, reason: 'tracking is not the control');

      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();
      expect(find.text('Power'), findsWidgets);
    });

    testWidgets('the pane offers it for a record that carries one, though nothing tracks power', (tester) async {
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'power': 5,
      });
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();
      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();

      expect(find.text('Power'), findsWidgets);
    });

    testWidgets('the pane omits it when nothing tracks power and the QSO has none', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();

      expect(find.text('Power'), findsNothing);
    });

    testWidgets('a power typed into the pane reaches the logged QSO and the VFO', (tester) async {
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power'])));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Power'), '10');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tunedRadio.vfoA.power, 10, reason: 'a pane Save is a deliberate statement, like its frequency');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      expect(logged.single.power, 10);
    });

    testWidgets("a record's power survives a save that only corrected its RST", (tester) async {
      // The round-trip trap: with the control off, the field is the only
      // place the value lives while the record is open, so a gate that only
      // wrote power for a visible control would drop it here.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW', 'sent': '55'},
        'band': '20m',
        'mode': 'SSB',
        'power': 5,
      });
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '59');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsosWhere(tester, 'the edited Rcvd', (logged) => logged.single.receivedRST == '59');
      expect(logged.single.power, 5);
    });

    testWidgets('a power from an edited record does not leak onto the next QSO', (tester) async {
      // Nothing is tracking power here, so the field is never re-seeded — a
      // value left in it after the edit closes would go on stamping every
      // contact logged afterwards, frozen at whatever that one record said.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'power': 5,
      });
      final key = GlobalKey();
      Widget at({Qso? editing}) => KeyedSubtree(
        key: key,
        child: host(session: LoggingSession(editingQso: editing)),
      );

      await tester.pumpWidget(at(editing: existing));
      await tester.pump();
      await tester.pumpWidget(at());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 2);
      expect(logged.firstWhere((q) => q.theirCall == 'K1ABC').power, isNull);
    });

    testWidgets('emptying the field clears a power off the record', (tester) async {
      // The map is merged over the stored QSO, so omitting the key when the
      // field is empty would leave the old value standing and a wrong power
      // could never be corrected — only overwritten.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'power': 100,
      });
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();
      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Power'), '');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      // A second, visible edit, so the assertion below can't pass on a save
      // that never happened — an emptied field is not a value Enter can see.
      await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '59');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsosWhere(tester, 'the edited Rcvd', (logged) => logged.single.receivedRST == '59');
      expect(logged.single.power, isNull);
    });

    testWidgets('switching the control on fills the field from the VFO', (tester) async {
      // The field only follows the VFO while power is in play, so the build
      // that turns it on is the one chance to catch up — otherwise the chip
      // reads "—" and a QSO logged before the next VFO change carries none.
      final radio = FakeVfoStore()
        ..setVfo('vfoA', freq: 14285, mode: 'SSB')
        ..setVfo('vfoA', power: 100);
      final key = GlobalKey();
      Widget at(List<String> order) => KeyedSubtree(
        key: key,
        child: host(
          radio: baseRadio().copyWith(radioService: radio),
          strip: ControlStripSettings(controlOrder: order),
        ),
      );

      await tester.pumpWidget(at(const []));
      await tester.pump();
      await tester.pumpWidget(at(const ['time', 'radio', 'power']));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Power')).controller!.text, '100');
    });

    testWidgets('is offered beside Radio, not last, to an operator with a saved order', (tester) async {
      // Every operator who has ever saved the settings dialog has a stored
      // order, and a key missing from it used to be appended — so the one
      // control that ships off would arrive at the very end of the row, past
      // More, however deliberately the descriptor list placed it. The dialog
      // is where it's first seen, and where saving records the placement.
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'more'])));
      await tester.pump();
      await tester.tap(find.byIcon(MdiIcons.cog));
      await tester.pumpAndSettle();

      // Inside the dialog's list, where each row is a ListTile — the chip
      // strip behind it carries labels of its own.
      double rowY(String label) => tester.getTopLeft(find.ancestor(of: find.text(label), matching: find.byType(ListTile)).first).dy;
      expect(rowY('Power'), greaterThan(rowY('Radio')));
      expect(rowY('Power'), lessThan(rowY('More')));
    });

    testWidgets("editing a QSO shows its own power, and does not retune the radio", (tester) async {
      final radio = FakeVfoStore()
        ..setVfo('vfoA', freq: 14285, mode: 'SSB')
        ..setVfo('vfoA', power: 100);
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'power': 5,
      });
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: existing),
          radio: baseRadio().copyWith(radioService: radio),
          strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power']),
        ),
      );
      await tester.pump();
      await openControl(tester, MdiIcons.flash);

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Power')).controller!.text,
        '5',
        reason: "a record's own power is what it was worked at, not what the rig is set to now",
      );

      await tester.enterText(find.widgetWithText(TextField, 'Power'), '10');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(radio.vfoA.power, 100, reason: 'editing an existing QSO applies changes to the QSO, never the VFO');
    });
  });
}
