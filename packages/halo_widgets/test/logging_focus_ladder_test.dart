// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The focus ladder's contract (docs/design/logging-fields.md) on real focus
// nodes in a small tree, with no panel around them: where each key sends
// the keyboard, and where the caret lands when it gets there. The panel
// suites exercise the same rules through a whole entry; these pin which
// side of the seam moved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/src/logging_controls_ladder.dart';

/// Three main fields (Call, Sent, Grid), two pills (time, radio) with one and
/// two fields, and a fieldless `more`. The tree gives every node a context.
class _Harness {
  final call = TextEditingController(text: 'W1AW');
  final sent = TextEditingController(text: '59');
  final grid = TextEditingController(text: 'FN20');
  final callFocus = FocusNode(debugLabel: 'call');
  final sentFocus = FocusNode(debugLabel: 'sent');
  final gridFocus = FocusNode(debugLabel: 'grid');
  final eventTextFocus = FocusNode(debugLabel: 'event');
  final timeField = (FocusNode(debugLabel: 'time'), TextEditingController(text: '12:34'));
  final dateField = (FocusNode(debugLabel: 'date'), TextEditingController(text: '2026-09-16'));
  final freqField = (FocusNode(debugLabel: 'freq'), TextEditingController(text: '14285'));

  String? selected;
  bool locked = false;
  bool editingEvent = false;
  bool withGrid = true;
  bool skipSent = false;
  bool Function()? navigateToQsoList;
  final selects = <String?>[];
  final shows = <String?>[];

  late final LoggingFocusLadder ladder = LoggingFocusLadder(
    config: () => (
      primaryFields: () => [
        (key: 'call', label: 'Call', focus: callFocus, controller: call, hint: null, skipFocus: false),
        (key: 'sent', label: 'Sent', focus: sentFocus, controller: sent, hint: null, skipFocus: skipSent),
        if (withGrid) (key: 'grid', label: 'Grid', focus: gridFocus, controller: grid, hint: null, skipFocus: false),
      ],
      expandedFocusFor: (key) => switch (key) {
        'time' => timeField.$1,
        'radio' => freqField.$1,
        _ => null,
      },
      expandedFieldOrderFor: (key) => switch (key) {
        'time' => [timeField, dateField],
        'radio' => [freqField],
        _ => const [],
      },
      selectedControlKey: selected,
      fieldsLocked: () => locked,
      editingEvent: editingEvent,
      eventTextFocus: eventTextFocus,
      callFocus: callFocus,
      navigateToQsoList: navigateToQsoList,
      aboveLog: false,
    ),
    // The panel's tap: `more` and event rows are its business; the rest
    // comes straight back to the ladder.
    selectControl: (key) {
      selects.add(key);
      if (key == null) {
        ladder.closeControl();
      } else {
        ladder.openControl(key);
      }
    },
    showControl: (key) {
      shows.add(key);
      selected = key;
    },
  )..pillOrder = const ['time', 'radio', 'more'];

  /// The panel's own focus rule, applied here as its listeners apply it:
  /// the caret lands where the ladder says, else at the end.
  void wireCaretRule() {
    for (final (focus, controller) in [(callFocus, call), (sentFocus, sent), (gridFocus, grid)]) {
      focus.addListener(() {
        if (!focus.hasFocus) return;
        ladder.notePrimaryFocus(focus);
        controller.selection = TextSelection.collapsed(offset: ladder.takePendingCaretOffset(focus, controller) ?? controller.text.length);
      });
    }
    for (final node in [callFocus, sentFocus, gridFocus]) {
      node.onKeyEvent = ladder.onPrimaryFieldKeyEvent;
    }
  }

  Widget build() => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          Row(
            children: [
              for (final (node, key) in [(ladder.pillFocusFor('time'), 'time'), (ladder.pillFocusFor('radio'), 'radio'), (ladder.pillFocusFor('more'), 'more')])
                Focus(focusNode: node, child: Text(key)),
            ],
          ),
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (node, event) => selected == null ? KeyEventResult.ignored : ladder.onExpandedKeyEvent(selected!, event),
            child: Row(
              children: [
                for (final (node, controller) in [timeField, dateField, freqField])
                  SizedBox(
                    width: 80,
                    child: TextField(focusNode: node, controller: controller),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              // Keyed, so a field leaving the row is a real unmount rather
              // than an element reused for its neighbour — which is what
              // the panel's own row does, and what detaches the node.
              for (final (node, controller) in [(callFocus, call), (sentFocus, sent), if (withGrid) (gridFocus, grid)])
                SizedBox(
                  key: ValueKey(node.debugLabel),
                  width: 80,
                  child: TextField(focusNode: node, controller: controller),
                ),
              SizedBox(
                key: const ValueKey('event'),
                width: 80,
                child: TextField(focusNode: eventTextFocus),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void dispose() {
    ladder.dispose();
  }
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

void main() {
  testWidgets('Tab off the last main field wraps to Call, and Shift-Tab off Call wraps to the last', (tester) async {
    final h = _Harness()..wireCaretRule();
    await tester.pumpWidget(h.build());
    h.gridFocus.requestFocus();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.tab);
    expect(h.callFocus.hasFocus, isTrue);
    expect(h.call.selection.baseOffset, h.call.text.length, reason: 'a wrap lands at the end of the value');
    await _press(tester, LogicalKeyboardKey.tab, shift: true);
    expect(h.gridFocus.hasFocus, isTrue);
    h.dispose();
  });

  // The trap: a field dropped from the cycle must still be reachable, or an
  // operator correcting the serial they sent has to reach for the pointer.
  testWidgets('Space and Tab pass over a skipFocus field both ways; the arrows still stop on it', (tester) async {
    final h = _Harness()
      ..skipSent = true
      ..wireCaretRule();
    await tester.pumpWidget(h.build());
    h.callFocus.requestFocus();
    await tester.pump();
    h.ladder.advancePrimaryFocus();
    await tester.pump();
    expect(h.gridFocus.hasFocus, isTrue, reason: 'Space from Call skips Sent');
    h.ladder.advancePrimaryFocus();
    await tester.pump();
    expect(h.callFocus.hasFocus, isTrue);
    await _press(tester, LogicalKeyboardKey.tab);
    expect(h.gridFocus.hasFocus, isTrue, reason: 'Tab from Call skips Sent');
    await _press(tester, LogicalKeyboardKey.tab, shift: true);
    expect(h.callFocus.hasFocus, isTrue, reason: 'Shift-Tab from Grid skips Sent too');
    await _press(tester, LogicalKeyboardKey.tab, shift: true);
    expect(h.gridFocus.hasFocus, isTrue);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(h.gridFocus.hasFocus, isTrue, reason: 'caret at the end: Left moves within the value');
    h.grid.selection = const TextSelection.collapsed(offset: 0);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(h.sentFocus.hasFocus, isTrue, reason: 'the arrows are the way onto a skipped field');
    await _press(tester, LogicalKeyboardKey.tab);
    expect(h.gridFocus.hasFocus, isTrue, reason: 'Tab leaves a skipped field for the next stop');
    h.dispose();
  });

  testWidgets('an arrow at the edge of a value travels to the neighbour, and the caret keeps its direction', (tester) async {
    final h = _Harness()..wireCaretRule();
    await tester.pumpWidget(h.build());
    h.callFocus.requestFocus();
    await tester.pump();
    h.call.selection = TextSelection.collapsed(offset: h.call.text.length);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(h.sentFocus.hasFocus, isTrue);
    expect(h.sent.selection.baseOffset, 0, reason: 'rightward: the caret arrives at the start');
    h.sent.selection = const TextSelection.collapsed(offset: 0);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(h.callFocus.hasFocus, isTrue);
    expect(h.call.selection.baseOffset, h.call.text.length, reason: 'leftward: the caret arrives at the end');
    // Mid-value, the arrow is the field's own caret move.
    h.call.selection = const TextSelection.collapsed(offset: 1);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(h.callFocus.hasFocus, isTrue);
    h.dispose();
  });

  testWidgets('Up from a main field opens the remembered pill; locked fields do not climb', (tester) async {
    final h = _Harness()..wireCaretRule();
    await tester.pumpWidget(h.build());
    h.sentFocus.requestFocus();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(h.selects, ['time'], reason: 'the first pill, with nothing remembered');
    await tester.pump();
    // The pill hands the keyboard on to the control's own field a frame
    // later, as a tap does — a chip is never a resting stop.
    expect(h.timeField.$1.hasFocus, isTrue);

    // Down from inside the open control returns to the field the operator
    // was in, not to Call.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(h.shows.last, isNull);
    expect(h.sentFocus.hasFocus, isTrue);

    // The strip remembers where the keyboard was: land on Radio, drop back
    // to the field, and the next Up returns to Radio, not to the first pill.
    h.ladder.focusPillAndOpen('radio');
    await tester.pump();
    await tester.pump();
    expect(h.freqField.$1.hasFocus, isTrue);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(h.sentFocus.hasFocus, isTrue);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(h.selects.last, 'radio', reason: 'back to the pill the keyboard was last on');
    await tester.pump();

    h.locked = true;
    final before = h.selects.length;
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(h.selects.length, before, reason: 'a locked form has no pills to climb to');
    h.dispose();
  });

  testWidgets('on the pills, Left/Right wrap the strip and open what they land on; more never opens', (tester) async {
    final h = _Harness()..wireCaretRule();
    await tester.pumpWidget(h.build());
    // `more` never opens, so its pill is the one place the keyboard rests.
    h.ladder.focusPillAndOpen('more');
    await tester.pump();
    expect(h.selects, isEmpty);
    expect(h.ladder.pillFocusFor('more').hasFocus, isTrue);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(h.selects.last, 'time', reason: 'off the end of the strip, wrapping to its start');
    await tester.pump();
    // Crossing back onto more closes what was open and opens nothing.
    h.ladder.crossToPill('more', fromStart: true);
    await tester.pump();
    expect(h.shows.last, isNull, reason: 'the control left behind is closed');
    expect(h.selects.length, 1, reason: 'more itself never opens');
    expect(h.ladder.pillFocusFor('more').hasFocus, isTrue);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(h.selects.last, 'radio', reason: 'Left from the strip\'s end lands on its neighbour');
    h.dispose();
  });

  testWidgets('Tab inside an open control walks its fields, then crosses to the next pill\'s first field', (tester) async {
    final h = _Harness()..wireCaretRule();
    await tester.pumpWidget(h.build());
    h.ladder.crossToPill('time', fromStart: true);
    await tester.pump();
    await tester.pump();
    expect(h.timeField.$1.hasFocus, isTrue);
    await _press(tester, LogicalKeyboardKey.tab);
    expect(h.dateField.$1.hasFocus, isTrue, reason: 'the control\'s own fields first');
    await _press(tester, LogicalKeyboardKey.tab);
    await tester.pump();
    expect(h.shows.last, 'radio');
    expect(h.freqField.$1.hasFocus, isTrue, reason: 'then the next control, on its first field');
    await _press(tester, LogicalKeyboardKey.tab, shift: true);
    await tester.pump();
    expect(h.dateField.$1.hasFocus, isTrue, reason: 'back across, on the previous control\'s LAST field');
    h.dispose();
  });

  testWidgets('Enter inside a control closes it, back to the last main field', (tester) async {
    final h = _Harness()..wireCaretRule();
    await tester.pumpWidget(h.build());
    h.gridFocus.requestFocus();
    await tester.pump();
    h.ladder.crossToPill('radio', fromStart: true);
    await tester.pump();
    await tester.pump();
    expect(h.freqField.$1.hasFocus, isTrue);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(h.shows.last, isNull);
    expect(h.gridFocus.hasFocus, isTrue, reason: 'back where the operator was, not at Call');
    h.dispose();
  });

  testWidgets('Up from a control hands the keyboard to the QSO list, or falls back to the last field', (tester) async {
    final h = _Harness()..wireCaretRule();
    var handedUp = 0;
    h.navigateToQsoList = () {
      handedUp++;
      return false;
    };
    await tester.pumpWidget(h.build());
    h.sentFocus.requestFocus();
    await tester.pump();
    h.ladder.crossToPill('radio', fromStart: true);
    await tester.pump();
    await tester.pump();
    await _press(tester, LogicalKeyboardKey.arrowUp);
    expect(handedUp, 1);
    expect(h.sentFocus.hasFocus, isTrue, reason: 'the host had nowhere to put it, so the field takes it back');
    h.dispose();
  });

  testWidgets('a remembered field that is gone falls back to Call; an event row falls back to its text', (tester) async {
    final h = _Harness()..wireCaretRule();
    await tester.pumpWidget(h.build());
    h.gridFocus.requestFocus();
    await tester.pump();
    expect(h.gridFocus.hasFocus, isTrue);

    // The field the operator was in leaves the row (its contest ended, say):
    // its node has no context, and a request on it would be swallowed.
    h.withGrid = false;
    await tester.pumpWidget(h.build());
    h.ladder.focusLastPrimaryField();
    await tester.pump();
    expect(h.callFocus.hasFocus, isTrue, reason: 'Call, not a node with nowhere to be');

    h.editingEvent = true;
    h.ladder.focusLastPrimaryField();
    await tester.pump();
    expect(h.eventTextFocus.hasFocus, isTrue, reason: 'an event row has no callsign field to fall back to');
    h.dispose();
  });
}
