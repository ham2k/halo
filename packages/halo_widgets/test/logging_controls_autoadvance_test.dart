// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Typing through a grouped exchange under the Auto-advance Fields setting:
// `autoadvanceBefore` moving a keystroke on to the field it belongs in,
// `autoadvanceWhen` moving focus on once a value is complete, and a paste
// placed the same way. The fixture is shaped like Sweepstakes — serial,
// precedence, check, section — because that exchange is copied as one run of
// characters ("4A20ENY") and keyed without looking at which field has focus.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_widgets/src/logging_controls_autoadvance.dart' show AdvanceWhenFormatter, autoadvanceBefore, autoadvanceWhen;

import 'support/logging_controls_harness.dart';

Map<String, dynamic> _control(String key, String label, Map<String, dynamic> input) => {
  'key': 'ss/$key',
  'label': label,
  'icon': 'flag-checkered',
  'group': 'their',
  'input': {'kind': 'text', 'refType': 'ss', 'field': key, ...input},
};

/// Their serial (digits, until a letter moves it on), precedence (one letter,
/// complete as typed), check (complete at two digits) and section — the last
/// field has no rules of its own.
List<Map<String, dynamic>> _sweepstakes({String? checkSuggestion, String? sectionSuggestion, bool skipPrec = false}) => [
  _control('theirSerial', 'Nr', {'numeric': true, 'autoadvanceBefore': '[0-9]*[A-Z]'}),
  {
    ..._control('prec', 'Prec', {'maxLength': 1, 'autoadvanceWhen': '[QABUMS]'}),
    if (skipPrec) 'skipFocus': true,
  },
  _control('check', 'Ck', {'numeric': true, 'maxLength': 2, 'autoadvanceWhen': '[0-9]{2}', 'suggestedValue': ?checkSuggestion}),
  _control('section', 'Sec', {'maxLength': 3, 'suggestedValue': ?sectionSuggestion}),
];

const _labels = ['Nr', 'Prec', 'Ck', 'Sec'];

/// The field labelled [label], with or without the `*` the setting adds.
Finder _finder(String label) =>
    find.ancestor(of: find.byWidgetPredicate((w) => w is Text && (w.data == label || w.data == '$label *')), matching: find.byType(TextField));

TextField _field(WidgetTester tester, String label) => tester.widget<TextField>(_finder(label));

/// What the four fields hold, in order.
List<String> _values(WidgetTester tester) => [for (final label in _labels) _field(tester, label).controller!.text];

bool _focused(WidgetTester tester, String label) => _field(tester, label).focusNode!.hasFocus;

/// Types [chars] one keystroke at a time into whichever field has focus —
/// as a keyboard does, so a field that moves focus on mid-word gets the
/// next keystroke in the field it moved to.
Future<void> _type(WidgetTester tester, String chars) async {
  for (final char in chars.split('')) {
    final editable = tester.state<EditableTextState>(find.byWidgetPredicate((w) => w is EditableText && w.focusNode.hasFocus));
    final text = editable.textEditingValue.text + char;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
    await tester.pump();
  }
}

Future<void> _space(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.space);
  await tester.pump();
}

Widget _panel({bool skipPrec = false, bool autoAdvance = true}) => host(
  log: LogHooks(operation: running(['ss']), qsosRepository: qsos),
  activities: ActivityHooks(activityControls: _sweepstakes(skipPrec: skipPrec)),
  prefs: LoggingPreferences(autoAdvanceFields: autoAdvance),
);

void main() {
  installLoggingHarness();

  group('typing through a grouped exchange', () {
    testWidgets('one run of keystrokes lands in the field each character belongs to', (tester) async {
      // The trap: without autoadvance the serial's digits filter swallows the
      // "A", and every character after it piles into the serial field.
      await tester.pumpWidget(_panel());
      await tester.showKeyboard(_finder('Nr'));
      await _type(tester, '4A20ENY');
      expect(_values(tester), ['4', 'A', '20', 'ENY']);
      expect(_focused(tester, 'Sec'), isTrue, reason: 'focus ends where the last character landed');
    });

    testWidgets('a paste with spaces is placed by its spaces alone, the rules sitting out', (tester) async {
      // "12 B 33 CT" as a log or a spot carries it. With the rules applied,
      // the B's own move and then the space's would put the check in the
      // section.
      await tester.pumpWidget(_panel());
      await tester.enterText(_finder('Nr'), '12 B 33 CT');
      await tester.pump();
      expect(_values(tester), ['12', 'B', '33', 'CT']);
      expect(_focused(tester, 'Sec'), isTrue);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      expect(logged.single.refs, [
        {'type': 'ss', 'theirSerial': '12', 'prec': 'B', 'check': '33', 'section': 'CT'},
      ], reason: 'what the fields show is what is logged, each in its own field');
    });

    testWidgets('a run of spaces, or spaces ahead of the text, separate no more than one space does', (tester) async {
      // Column-aligned text pads with spaces. Each one moving on would land
      // every value after a double space one field late, and a leading one
      // would skip the field pasted into.
      await tester.pumpWidget(_panel());
      await tester.enterText(_finder('Nr'), '  12  B   33 CT');
      await tester.pump();
      expect(_values(tester), ['12', 'B', '33', 'CT']);
    });

    testWidgets('a field the operator may not edit is passed over', (tester) async {
      // Written to here, a read-only serial would log a number the operator
      // never sent; its `readOnly` stops typing, not text placed from another
      // field.
      await tester.pumpWidget(
        host(
          log: LogHooks(operation: running(['ss']), qsosRepository: qsos),
          activities: ActivityHooks(
            activityControls: [
              _sweepstakes()[0],
              _control('ours', 'Ours', {'kind': 'serial', 'editable': false}),
              ..._sweepstakes().skip(1),
            ],
          ),
          prefs: const LoggingPreferences(autoAdvanceFields: true),
        ),
      );
      await tester.enterText(_finder('Nr'), '12 B 33 CT');
      await tester.pump();
      expect(_values(tester), ['12', 'B', '33', 'CT']);
      expect(_field(tester, 'Ours').controller!.text, '');
    });

    testWidgets('a paste without spaces goes through the rules, and the last field keeps only what it can hold', (tester) async {
      // There is no field after the last one: the rest is not wrapped round
      // into the serial, nor anywhere else.
      await tester.pumpWidget(_panel());
      await tester.enterText(_finder('Nr'), '12B33ENYX');
      await tester.pump();
      expect(_values(tester), ['12', 'B', '33', 'ENY']);
    });

    testWidgets('a character typed into the middle of a value stays in that field', (tester) async {
      // An edit inside a value is a correction. Sending it on would also
      // rewrite this field to the text BEFORE the caret — "12" with the caret
      // at its start, plus an "A" for the next field, would leave the serial
      // empty.
      await tester.pumpWidget(_panel());
      await tester.showKeyboard(_finder('Nr'));
      await _type(tester, '12');
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '12', selection: TextSelection.collapsed(offset: 0)));
      await tester.pump();
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'A12', selection: TextSelection.collapsed(offset: 1)));
      await tester.pump();
      expect(_values(tester), ['12', '', '', '']);
      expect(_focused(tester, 'Nr'), isTrue);
    });

    testWidgets('a change anywhere in a value that completes it moves on', (tester) async {
      // `autoadvanceWhen` answers "is this value complete now", not "was a
      // character typed at the end": fixing the first digit of a check is as
      // complete as typing its second.
      await tester.pumpWidget(_panel());
      await tester.showKeyboard(_finder('Ck'));
      await _type(tester, '2');
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '2', selection: TextSelection.collapsed(offset: 0)));
      await tester.pump();
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '12', selection: TextSelection.collapsed(offset: 1)));
      await tester.pump();
      expect(_field(tester, 'Ck').controller!.text, '12');
      expect(_focused(tester, 'Sec'), isTrue);
    });

    testWidgets('a character a field refuses, with no autoadvanceBefore to carry it, is dropped', (tester) async {
      // Only `autoadvanceBefore` moves a keystroke on. A letter in the check
      // is a typo, and landing it in the section would hide it there.
      await tester.pumpWidget(_panel());
      await tester.showKeyboard(_finder('Ck'));
      await _type(tester, '2A');
      expect(_values(tester), ['', '', '2', '']);
      expect(_focused(tester, 'Ck'), isTrue);
    });

    test('a deletion that leaves a complete value never moves on', () async {
      // Backspace is a correction under way: a phone report `599` shortened
      // to a complete `59` must leave the operator in the field. Typing to a
      // complete value still moves on.
      var advanced = 0;
      final formatter = AdvanceWhenFormatter(RegExp(r'^\S{2}$'), () => advanced++);
      TextEditingValue value(String text) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      formatter.formatEditUpdate(value('599'), value('59'));
      formatter.formatEditUpdate(value('599'), const TextEditingValue(text: '59', selection: TextSelection.collapsed(offset: 1)));
      await Future<void>.delayed(Duration.zero);
      expect(advanced, 0);

      formatter.formatEditUpdate(value('5'), value('59'));
      formatter.formatEditUpdate(value('57'), value('59'));
      await Future<void>.delayed(Duration.zero);
      expect(advanced, 2);
    });

    testWidgets("a serial's step key steps the number rather than moving on", (tester) async {
      // A "." is no digit, so taken for typing it would land in the
      // precedence instead of correcting the number the operator just copied.
      await tester.pumpWidget(_panel());
      await tester.showKeyboard(_finder('Nr'));
      await _type(tester, '12.');
      expect(_values(tester), ['13', '', '', '']);
      await _type(tester, ',');
      expect(_values(tester), ['12', '', '', '']);
      expect(_focused(tester, 'Nr'), isTrue);
    });

    testWidgets('a field outside the typing order keeps its own keystrokes', (tester) async {
      // A `skipFocus` field is not a stop, so typing never flows from it; its
      // rules swallowing the keystroke instead would leave a field the
      // operator tapped into that ignores them.
      await tester.pumpWidget(_panel(skipPrec: true));
      await tester.showKeyboard(_finder('Prec'));
      await _type(tester, 'B');
      expect(_field(tester, 'Prec').controller!.text, 'B');
    });

    test('a field that takes spaces has no autoadvance rules', () {
      // A list a space separates has no point at which it is complete, and
      // moving on mid-list would split it across fields.
      final rules = {'autoadvanceWhen': 'A+', 'autoadvanceBefore': 'A+B'};
      expect(
        autoadvanceWhen({
          ...rules,
          'multiValue': {'separator': ' '},
        }),
        isNull,
      );
      expect(
        autoadvanceBefore({
          ...rules,
          'multiValue': {'separator': ' '},
        }),
        isNull,
      );
      expect(
        autoadvanceWhen({
          ...rules,
          'multiValue': {'separator': ','},
        }),
        isNotNull,
        reason: 'only a space-separated list is exempt',
      );
      expect(autoadvanceBefore(rules), isNotNull);
    });

    group('into a field holding a guess', () {
      Widget panel() => host(
        log: LogHooks(operation: running(['ss']), qsosRepository: qsos),
        lookups: LookupHooks(
          lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': <String, dynamic>{}},
        ),
        activities: ActivityHooks(
          activityControls: _sweepstakes(),
          refreshActivityControls: (qso) async => _sweepstakes(checkSuggestion: '79', sectionSuggestion: 'CT'),
        ),
        prefs: const LoggingPreferences(autoAdvanceFields: true),
      );

      Future<void> guessed(WidgetTester tester) async {
        await tester.pumpWidget(panel());
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
        await tester.pumpAndSettle();
        expect(_values(tester), ['', '', '79', 'CT'], reason: 'the fixture has to have made its guesses');
      }

      testWidgets('typing that flows into it starts it afresh', (tester) async {
        // The guess is the app's, not the operator's: appending to it makes
        // "792", which the check refuses.
        await guessed(tester);
        await tester.enterText(_finder('Nr'), '12B2');
        await tester.pump();
        expect(_values(tester), ['12', 'B', '2', 'CT']);
      });

      testWidgets('a whole exchange keyed over guesses replaces each one it reaches', (tester) async {
        // The trap: the first keystroke in a field showing a guess appended to
        // it — "792" refused, and the guessed check was logged.
        await guessed(tester);
        await tester.showKeyboard(_finder('Nr'));
        await _type(tester, '4A20ENY');
        expect(_values(tester), ['4', 'A', '20', 'ENY']);
      });

      testWidgets('a keystroke into it, after a move landed there, starts it afresh', (tester) async {
        // The same rule keyed rather than pasted: the B moves focus into the
        // check holding the guess, and the operator keys the check they heard.
        await guessed(tester);
        await tester.showKeyboard(_finder('Prec'));
        await _type(tester, 'B25');
        expect(_values(tester), ['', 'B', '25', 'CT']);
      });

      testWidgets('a keystroke it refuses leaves the guess standing', (tester) async {
        // Starting the check afresh before anything had landed in it would
        // blank the guess for a typo.
        await guessed(tester);
        await tester.showKeyboard(_finder('Prec'));
        await _type(tester, 'BE');
        expect(_values(tester), ['', 'B', '79', 'CT']);
        expect(_focused(tester, 'Ck'), isTrue);
      });

      testWidgets("a paste that lands the guess's own value makes it the operator's, kept when the call changes", (tester) async {
        // The trap: placing a value equal to the guess skipped marking it
        // typed, so a later call edit took the operator's check and section
        // back as the app's guesses for a station they no longer belong to.
        await tester.pumpWidget(
          host(
            log: LogHooks(operation: running(['ss']), qsosRepository: qsos),
            lookups: LookupHooks(
              lookup: (call, {required qso, required operation, required online, recentContext = false}) async => {'guess': <String, dynamic>{}},
            ),
            activities: ActivityHooks(
              activityControls: _sweepstakes(),
              refreshActivityControls: (qso) async =>
                  (qso['their'] as Map?)?['call'] == 'W1AW' ? _sweepstakes(checkSuggestion: '79', sectionSuggestion: 'CT') : _sweepstakes(),
            ),
            prefs: const LoggingPreferences(autoAdvanceFields: true),
          ),
        );
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
        await tester.pumpAndSettle();
        expect(_values(tester), ['', '', '79', 'CT'], reason: 'the fixture has to have made its guesses');

        await tester.enterText(_finder('Nr'), '12B79CT');
        await tester.pump();
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AX');
        await tester.pumpAndSettle();
        expect(_values(tester), ['12', 'B', '79', 'CT']);
      });

      testWidgets('a paste that only passes over it leaves the guess standing', (tester) async {
        // Two spaces after the B: the first reaches the check, the second
        // steps past it.
        await guessed(tester);
        await tester.enterText(_finder('Nr'), '12 B  CT');
        await tester.pump();
        expect(_values(tester), ['12', 'B', '79', 'CT']);
      });
    });
  });

  group("a field's own rules", () {
    testWidgets('text placed in a field goes through its transforms, as typing would', (tester) async {
      // The trap: placed text is written straight to the field, past its
      // formatters, so a transform the extension relies on never ran on a
      // paste or on a character carried in from the previous field.
      await tester.pumpWidget(
        host(
          log: LogHooks(operation: running(['ss']), qsosRepository: qsos),
          activities: ActivityHooks(
            activityControls: [
              _control('theirSerial', 'Nr', {'numeric': true, 'autoadvanceBefore': '[0-9]*[A-Z]'}),
              _control('zone', 'Zn', {
                'transforms': [
                  {'pattern': '^K', 'replacement': 'CQ-K'},
                ],
              }),
            ],
          ),
          prefs: const LoggingPreferences(autoAdvanceFields: true),
        ),
      );
      await tester.enterText(_finder('Nr'), '12K5');
      await tester.pump();
      expect(_field(tester, 'Zn').controller!.text, 'CQ-K5');
    });

    testWidgets('a grouped field that takes spaces keeps a paste whole', (tester) async {
      // Spaces separate its values, so placing the paste by its spaces would
      // split one list across the fields after it.
      await tester.pumpWidget(
        host(
          log: LogHooks(operation: running(['ss']), qsosRepository: qsos),
          activities: ActivityHooks(
            activityControls: [
              _control('counties', 'Cty', {
                'multiValue': {'separator': ' '},
              }),
              _control('section', 'Sec', {'maxLength': 3}),
            ],
          ),
          prefs: const LoggingPreferences(autoAdvanceFields: true),
        ),
      );
      await tester.enterText(_finder('Cty'), 'ALB ESX');
      await tester.pump();
      expect(_field(tester, 'Cty').controller!.text, 'ALB ESX');
      expect(_field(tester, 'Sec').controller!.text, '');
    });
  });

  group('the Auto-advance Fields setting', () {
    testWidgets('off, no field moves by itself', (tester) async {
      // Both rules are the setting's: off, a complete value stays put and a
      // keystroke the field refuses is dropped, as in any other field.
      await tester.pumpWidget(_panel(autoAdvance: false));
      await tester.showKeyboard(_finder('Nr'));
      await _type(tester, '4A');
      expect(_values(tester), ['4', '', '', '']);
      expect(_focused(tester, 'Nr'), isTrue);

      await tester.showKeyboard(_finder('Prec'));
      await _type(tester, 'B');
      expect(_focused(tester, 'Prec'), isTrue);
    });

    testWidgets('on, the Space after an automatic move is a move of its own', (tester) async {
      // Nothing makes that Space a no-op: Space always means "next field".
      await tester.pumpWidget(_panel());
      await tester.showKeyboard(_finder('Prec'));
      await _type(tester, 'B');
      expect(_focused(tester, 'Ck'), isTrue);
      await _space(tester);
      expect(_focused(tester, 'Sec'), isTrue);
    });

    testWidgets('marks only the fields that move on by themselves, and only while on', (tester) async {
      // The setting's description sends the operator looking for the mark; a
      // mark on the section would promise a move that never comes, and one
      // shown with the setting off promises it for nothing.
      await tester.pumpWidget(_panel());
      for (final label in ['Nr *', 'Prec *', 'Ck *', 'Sec']) {
        expect(find.widgetWithText(TextField, label), findsOneWidget, reason: label);
      }

      await tester.pumpWidget(_panel(autoAdvance: false));
      await tester.pump();
      expect(find.textContaining('*'), findsNothing);
    });
  });
}
