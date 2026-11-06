// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What an exchange field shows beside what the operator types: a `suffix`
// drawn after the value, a display-only field (`editable: false`) showing
// what we send, and an optional field (`chars.min: 0`) the operator can hide.
// Each is drawn, never typed — so the tests read both the screen and what is
// logged.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

Map<String, dynamic> _control(String key, String label, Map<String, dynamic> input) => {
  'key': 'ss/$key',
  'label': label,
  'icon': 'flag-checkered',
  'input': {'kind': 'text', 'refType': 'ss', 'field': key, ...input},
};

Widget _panel(List<Map<String, dynamic>> controls, {LoggingPreferences? prefs}) => host(
  log: LogHooks(operation: running(['ss']), qsosRepository: qsos),
  activities: ActivityHooks(activityControls: controls),
  prefs: prefs,
);

/// The field labelled [label], with or without the `*` Auto-advance Fields
/// adds.
Finder _field(String label) =>
    find.ancestor(of: find.byWidgetPredicate((w) => w is Text && (w.data == label || w.data == '$label *')), matching: find.byType(TextField));

/// The text the field paints — its value and anything drawn after it.
String _painted(WidgetTester tester, String label) =>
    tester.state<EditableTextState>(find.descendant(of: _field(label), matching: find.byType(EditableText))).renderEditable.text!.toPlainText();

Future<void> _logWith(WidgetTester tester, String call) async {
  await tester.enterText(_field('Their call'), call);
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
}

void main() {
  installLoggingHarness();

  group('a suffix', () {
    final controls = [
      _control('power', 'Pwr', {'numeric': true, 'suffix': ' W'}),
    ];

    testWidgets('is drawn after a value the operator is not editing, and only then', (tester) async {
      await tester.pumpWidget(_panel(controls));
      expect(_painted(tester, 'Pwr'), '', reason: 'an empty field draws no units for a value it does not have');

      await tester.enterText(_field('Pwr'), '100');
      await tester.pump();
      // The trap: units in a field being edited sit after the caret, and read
      // as something to delete.
      expect(_painted(tester, 'Pwr'), '100');

      await tester.showKeyboard(_field('Their call'));
      await tester.pump();
      expect(_painted(tester, 'Pwr'), '100 W');
      expect(tester.widget<TextField>(_field('Pwr')).controller!.text, '100', reason: 'drawn, never part of the value');

      await tester.showKeyboard(_field('Pwr'));
      await tester.pump();
      expect(_painted(tester, 'Pwr'), '100');
    });

    testWidgets('never reaches the log', (tester) async {
      await tester.pumpWidget(_panel(controls));
      await tester.enterText(_field('Pwr'), '100');
      await tester.pump();
      await tester.showKeyboard(_field('Their call'));
      await tester.pump();
      expect(_painted(tester, 'Pwr'), '100 W', reason: 'the suffix has to be on screen for this to prove anything');

      await _logWith(tester, 'W1AW');
      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'ss', 'power': '100'},
      ]);
    });
  });

  group('a display-only field', () {
    // Our own exchange, shown beside theirs so the operator can read it off
    // the row: something sent, never typed.
    final controls = [
      _control('serial', 'Nr', {'numeric': true, 'autoadvanceBefore': '[0-9]*[A-Z]'}),
      _control('ours', 'Ours', {'editable': false, 'value': 'A 79 ENY'}),
      _control('prec', 'Prec', {'maxLength': 1}),
    ];

    bool focused(WidgetTester tester, String label) => tester.widget<TextField>(_field(label)).focusNode!.hasFocus;

    testWidgets('shows its value, in no text field', (tester) async {
      await tester.pumpWidget(_panel(controls));
      expect(find.text('A 79 ENY'), findsOneWidget);
      expect(_field('Ours'), findsNothing, reason: 'a text field is something to type into, and this is not');
    });

    testWidgets('is passed over by Space and Tab', (tester) async {
      // A stop in the walk the operator can do nothing in costs a keystroke
      // per contact, every contact.
      await tester.pumpWidget(_panel(controls));
      await tester.showKeyboard(_field('Nr'));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(focused(tester, 'Prec'), isTrue, reason: 'Space');

      await tester.showKeyboard(_field('Nr'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focused(tester, 'Prec'), isTrue, reason: 'Tab');
    });

    testWidgets('is passed over by typing that moves on, and nothing is logged from it', (tester) async {
      // Typing flows field to field through the group; a display-only field
      // in its path that took the letter would put it where nobody can see or
      // correct it — and log it.
      await tester.pumpWidget(_panel(controls, prefs: const LoggingPreferences(autoAdvanceFields: true)));
      await tester.showKeyboard(_field('Nr'));
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '12', selection: TextSelection.collapsed(offset: 2)));
      await tester.pump();
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '12B', selection: TextSelection.collapsed(offset: 3)));
      await tester.pump();
      expect(tester.widget<TextField>(_field('Prec')).controller!.text, 'B');
      expect(focused(tester, 'Prec'), isTrue);

      await _logWith(tester, 'W1AW');
      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'ss', 'serial': '12', 'prec': 'B'},
      ]);
    });
  });

  group('our exchange', () {
    // SS's serial: the number to edit, and what we send after it to read off.
    final controls = [
      _control('ourSerial', 'Our #', {
        'numeric': true,
        'placeholder': '#',
        'ourExchange': 'A KI2D 79 ENY',
        'chars': {'min': 3, 'ideal': 3, 'max': 5},
      }),
    ];

    double width(WidgetTester tester) => tester.getSize(_field('Our #')).width;

    testWidgets('is drawn after the value and the placeholder, in a field widened for it, while included', (tester) async {
      await tester.pumpWidget(_panel(controls));
      final included = width(tester);
      expect(find.text('# A KI2D 79 ENY'), findsOneWidget, reason: 'an empty field says what goes out after the number');
      await tester.enterText(_field('Our #'), '12');
      await tester.showKeyboard(_field('Their call'));
      await tester.pump();
      expect(_painted(tester, 'Our #'), '12 A KI2D 79 ENY');

      // The trap: the extension sizes the field for the serial alone, so a
      // host that drew the exchange without widening for it would clip it to
      // its first letter or two.
      await tester.pumpWidget(_panel(controls, prefs: const LoggingPreferences(includeOurExchange: false)));
      // The row animates a field's width to its new size.
      await tester.pump(const Duration(seconds: 1));
      expect(_painted(tester, 'Our #'), '12', reason: 'left out, the field holds the number alone');
      expect(find.text('# A KI2D 79 ENY'), findsNothing);
      expect(width(tester), lessThan(included), reason: 'and gives the room it took back to the row');
    });

    testWidgets('never reaches the log', (tester) async {
      await tester.pumpWidget(_panel(controls));
      await tester.enterText(_field('Our #'), '12');
      await _logWith(tester, 'W1AW');
      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'ss', 'ourSerial': '12'},
      ]);
    });
  });

  group('an optional field', () {
    final controls = [
      _control('serial', 'Nr', {'numeric': true}),
      _control('ours', 'Ours', {
        'editable': false,
        'value': 'A 79 ENY',
        'chars': {'min': 0, 'ideal': 8},
      }),
    ];

    testWidgets('is on the row by default', (tester) async {
      await tester.pumpWidget(_panel(controls));
      expect(find.text('A 79 ENY'), findsOneWidget);
    });

    testWidgets('leaves the row when the operator hides optional fields, and only it does', (tester) async {
      await tester.pumpWidget(_panel(controls, prefs: const LoggingPreferences(showOptionalFields: false)));
      expect(find.text('A 79 ENY'), findsNothing);
      expect(_field('Nr'), findsOneWidget, reason: 'a field the operator types into is never optional');
    });
  });
}
