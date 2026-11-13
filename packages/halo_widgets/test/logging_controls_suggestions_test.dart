// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Picking a draft suggestion (docs/design/logging-fields.md § Draft
// suggestions). The traps are in what a walk puts back: a second pick that
// kept the first one's fields would log a station with another's report, a
// walk past the last that did not restore what was typed would leave the
// operator with no way back to their own text, and one that restored it over
// an edit made after a pick would throw that edit away.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

const _list = DraftSuggestionList(
  forCall: 'K1A',
  drafts: [
    DraftSuggestion(
      call: 'K1AB',
      qso: {
        'their': {'call': 'K1AB', 'sent': '579'},
      },
    ),
    DraftSuggestion(
      call: 'K1AC',
      qso: {
        'their': {'call': 'K1AC'},
      },
    ),
  ],
);

void main() {
  installLoggingHarness();

  late DraftSuggestions suggestions;
  setUp(() => suggestions = DraftSuggestions());
  tearDown(() => suggestions.dispose());

  TextEditingController field(WidgetTester tester, String label) => tester.widget<TextField>(find.widgetWithText(TextField, label)).controller!;

  Future<void> altY(WidgetTester tester, {bool shift = false}) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await sendChord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyY);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  Future<void> typed(WidgetTester tester, String call) async {
    await tester.pumpWidget(host(session: LoggingSession(draftSuggestions: suggestions)));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), call);
    await tester.pump();
    suggestions.list = _list;
    await tester.pump();
  }

  testWidgets('Alt-Y walks the list and back to what was typed, each pick laid over the contact as typed', (tester) async {
    await typed(tester, 'K1A');
    final rcvd = field(tester, 'Rcvd').text;

    await altY(tester);
    expect(field(tester, 'Their call').text, 'K1AB');
    expect(field(tester, 'Rcvd').text, '579');
    expect(suggestions.picked, 0);

    await altY(tester);
    expect(field(tester, 'Their call').text, 'K1AC');
    expect(field(tester, 'Rcvd').text, rcvd, reason: "K1AB's report is not K1AC's");

    await altY(tester);
    expect(field(tester, 'Their call').text, 'K1A');
    expect(field(tester, 'Rcvd').text, rcvd);
    expect(suggestions.picked, isNull);
    expect(suggestions.showing, isTrue, reason: 'back on the text the list was made for');

    await altY(tester, shift: true);
    expect(field(tester, 'Their call').text, 'K1AC', reason: 'Shift-Alt-Y walks the other way');
  });

  testWidgets('Alt-Y walks only the calls the line has room for', (tester) async {
    await typed(tester, 'K1A');
    suggestions.shownCount = 1;

    await altY(tester);
    expect(field(tester, 'Their call').text, 'K1AB');
    await altY(tester);
    expect(field(tester, 'Their call').text, 'K1A', reason: 'K1AC is off the line, so the walk never lands on a call the operator cannot see');
  });

  // A pick changes the call, and its lookup lands a moment later with a
  // guess, a prefill and a name. Read as an edit, it would make K1AB's
  // contact the one the walk returns to, and lay K1AC over K1AB's report.
  testWidgets('what lands after a pick is no edit: the walk goes on, and back to the text typed', (tester) async {
    await typed(tester, 'K1A');
    // Typed, so the patch below has no empty report to fill with a default.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.pump();
    final rcvd = field(tester, 'Rcvd').text;
    await altY(tester);
    expect(field(tester, 'Rcvd').text, '579');

    // As a lookup landing: a name the operator never typed.
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          draftSuggestions: suggestions,
          draftPatch: (
            serial: 1,
            patch: {
              'their': {'name': 'Bob'},
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await altY(tester);
    expect(field(tester, 'Their call').text, 'K1AC');
    expect(field(tester, 'Rcvd').text, rcvd, reason: "K1AB's report is not K1AC's");
    await altY(tester);
    expect(field(tester, 'Their call').text, 'K1A');
  });

  testWidgets('an edit after a pick is what the walk returns to', (tester) async {
    await typed(tester, 'K1A');
    await altY(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '55');
    await tester.pump();

    await altY(tester);
    expect(field(tester, 'Their call').text, 'K1AC');
    expect(field(tester, 'Sent').text, '55', reason: 'what the operator typed after the pick stays');

    await altY(tester);
    expect(field(tester, 'Their call').text, 'K1AB', reason: 'the contact as edited, not the text typed before the first pick');
    expect(field(tester, 'Sent').text, '55');
  });

  testWidgets('a tap on the line picks out of turn, and Alt-Y carries on from there', (tester) async {
    await typed(tester, 'K1A');
    suggestions.tap(_list, 1);
    await tester.pump();
    expect(field(tester, 'Their call').text, 'K1AC');
    expect(suggestions.picked, 1);

    await altY(tester);
    expect(field(tester, 'Their call').text, 'K1A');
  });

  testWidgets('typing on leaves the list behind, and Alt-Y is then claimed and does nothing', (tester) async {
    await typed(tester, 'K1A');
    await altY(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABX');
    await tester.pump();
    expect(suggestions.picked, isNull);
    expect(suggestions.showing, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    final claimed = await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(claimed, isTrue, reason: 'unclaimed, macOS types Option+Y into the field');
    expect(field(tester, 'Their call').text, 'K1ABX');
  });

  // A LoggingControls remounted over the same set — the controls moved above
  // the log — wires its tap before the old one's dispose runs.
  test("a panel going unwires only its own tap, and a tap reaches it only for the list it was drawn from", () {
    final taps = <String>[];
    void older(int index) => taps.add('older $index');
    void newer(int index) => taps.add('newer $index');
    suggestions
      ..list = _list
      ..onTap = older
      ..onTap = newer
      ..releaseTap(older)
      ..tap(_list, 1)
      ..tap(const DraftSuggestionList(forCall: 'K1A', drafts: []), 0);
    expect(taps, ['newer 1']);
  });

  test('a new list keeps the pick when it still holds the call, and drops it when it does not', () {
    suggestions
      ..list = _list
      ..call = 'K1AB'
      ..picked = 0
      ..list = const DraftSuggestionList(
        forCall: 'K1AB',
        drafts: [
          DraftSuggestion(
            call: 'W1AB',
            qso: {
              'their': {'call': 'W1AB'},
            },
          ),
          DraftSuggestion(
            call: 'K1AB',
            qso: {
              'their': {'call': 'K1AB'},
            },
          ),
        ],
      );
    expect(suggestions.picked, 1);
    suggestions.list = const DraftSuggestionList(forCall: 'K1AB', drafts: []);
    expect(suggestions.picked, isNull);
    expect(suggestions.showing, isFalse, reason: 'an empty list shows nothing');
  });
}
