// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// LoggingEntryRow on its own — the row's placement and sizing contract, with
// no panel around it. The widget suite walks the same row through the panel
// (logging_controls_focus_test.dart); these pin what the row itself promises
// where a panel would hide which side moved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/src/call_field_text.dart';
import 'package:halo_widgets/src/logging_controls_command.dart';
import 'package:halo_widgets/src/logging_controls_entry_row.dart';
import 'package:halo_widgets/src/logging_controls_exchange.dart';
import 'package:halo_widgets/src/logging_controls_metrics.dart';
import 'package:halo_widgets/src/text_formatters.dart';

const _submitKey = ValueKey('submit');

class _Harness {
  _Harness() {
    addTearDown(dispose);
  }

  final call = (controller: TextEditingController(), focus: FocusNode());
  final sent = (controller: TextEditingController(), focus: FocusNode());
  final rcvd = (controller: TextEditingController(), focus: FocusNode());
  final state = (controller: TextEditingController(), focus: FocusNode());
  final grid = (controller: TextEditingController(), focus: FocusNode());

  /// The contest exchange fields in the row, by key.
  List<String> exchangeKeys = const [];
  List<Map<String, dynamic>> get _exchangeControls => [
    for (final key in exchangeKeys)
      {
        'key': key,
        'label': key.toUpperCase(),
        'input': {'kind': 'text'},
      },
  ];

  /// The row walks `textControls` every time it lays out, so a generator
  /// counts its layouts without reaching into it.
  int controlWalks = 0;
  Iterable<Map<String, dynamic>> _controls() sync* {
    controlWalks++;
    yield* _exchangeControls;
  }

  int submitted = 0;
  int exchangeSubmitted = 0;

  late final command = CommandInterpretationModel(
    config: () => (
      interpretCommand: (input, [operation, qso, execute = false]) async => null,
      editingQso: null,
      operationData: () => const {'uuid': 'op'},
      onMessageChanged: (_) {},
    ),
    callText: () => CallFieldText(call.controller.text, cursor: call.controller.text.length, stacking: true),
    qsoData: () => const {},
  );

  late final exchange = ExchangeFieldsModel(
    config: () => (textControls: () => _exchangeControls, editingQso: null, operationUuid: 'op', serialNumbers: null, sequences: null, call: ''),
    draftQsoData: () => const {},
    onPrimaryFieldKeyEvent: (node, event) => KeyEventResult.ignored,
    onFocusChanged: (node, controller) {},
  );

  late final virtualSpace = VirtualSpaceFormatter(() {});

  List<RstFieldSlot> get rstPair => [
    (focus: sent.focus, controller: sent.controller, label: 'Sent'),
    (focus: rcvd.focus, controller: rcvd.controller, label: 'Rcvd'),
  ];

  Widget host({double width = 780, bool leftieMode = false, List<RstFieldSlot>? rst, bool showState = true, bool showGrid = true, Widget? eventFields}) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: LoggingEntryRow(
                call: call,
                rstFields: rst ?? rstPair,
                rstPlaceholder: '59',
                numericKeyboardType: null,
                exchange: exchange,
                textControls: _controls(),
                state: showState ? state : null,
                stateHint: null,
                onStateChanged: (_) {},
                grid: showGrid ? grid : null,
                gridHint: null,
                onGridChanged: (_) {},
                command: command,
                virtualSpace: virtualSpace,
                commandVirtualSpace: virtualSpace,
                enabled: true,
                leftieMode: leftieMode,
                buttonWidth: 44,
                submitButton: const SizedBox(key: _submitKey, width: 44),
                eventFields: eventFields,
                onSubmitted: () => submitted++,
                onExchangeSubmitted: () => exchangeSubmitted++,
              ),
            ),
          ),
        ),
      );

  void dispose() {
    command.dispose();
    exchange.dispose();
    for (final slot in [call, sent, rcvd, state, grid]) {
      slot.controller.dispose();
      slot.focus.dispose();
    }
  }
}

Finder _fieldFor(TextEditingController controller) => find.byWidgetPredicate((w) => w is TextField && w.controller == controller);

void main() {
  testWidgets('the log button closes the row, and opens it in leftie mode', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.host());
    expect(
      tester.getTopLeft(find.byKey(_submitKey)).dx,
      greaterThan(tester.getTopRight(_fieldFor(h.grid.controller)).dx),
      reason: 'the button sits after the last field',
    );

    await tester.pumpWidget(h.host(leftieMode: true));
    expect(
      tester.getTopRight(find.byKey(_submitKey)).dx,
      lessThan(tester.getTopLeft(_fieldFor(h.call.controller)).dx),
      reason: 'a left-handed operator has it before the callsign',
    );
  });

  testWidgets('the fields follow the callsign in the order the panel hands them', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.host(rst: h.rstPair.reversed.toList()));
    final xs = [h.call, h.rcvd, h.sent, h.state, h.grid].map((f) => tester.getTopLeft(_fieldFor(f.controller)).dx);
    expect(xs, orderedEquals(xs.toList()..sort()), reason: 'the row never re-sorts what it is given');
    // The trap: the panel's Sent/Rcvd order is the one rule every surface
    // reads; a row that put Sent first on its own would disagree with the
    // path Space and Tab walk.
    expect(tester.getTopLeft(_fieldFor(h.rcvd.controller)).dx, lessThan(tester.getTopLeft(_fieldFor(h.sent.controller)).dx));
  });

  testWidgets('a squeezed row hands the focused field its width back on its own; a roomy one stays put', (tester) async {
    final h = _Harness()..exchangeKeys = const ['serial'];
    // Squeezed — five trailing fields want 332px of the 300 — yet wide enough
    // for any ONE of them at its full minimum beside the others at their
    // floors, so the row never overflows when the focused one takes it.
    await tester.pumpWidget(h.host(width: 300));
    double width(TextEditingController c) => tester.getSize(_fieldFor(c)).width;
    expect(width(h.sent.controller), lessThan(fixedFieldMinWidth), reason: 'five trailing fields cannot each get their minimum in 300px');

    // The trap: the widening only happens if the focus change rebuilds the
    // row, and nothing outside it is told about the focus change — for
    // every kind of trailing field, not only the reports.
    h.sent.focus.requestFocus();
    await tester.pumpAndSettle();
    expect(width(h.sent.controller), fixedFieldMinWidth);
    expect(width(h.rcvd.controller), lessThan(width(h.sent.controller)), reason: 'the others give up what the focused one takes');
    h.grid.focus.requestFocus();
    await tester.pumpAndSettle();
    expect(width(h.grid.controller), fixedFieldMinWidth);
    expect(width(h.sent.controller), lessThan(width(h.grid.controller)));
    h.exchange.focusFor('serial').requestFocus();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ExchangeField)).width, exchangeFieldMinWidth);
    expect(width(h.grid.controller), lessThan(fixedFieldMinWidth));

    await tester.pumpWidget(h.host(width: 780));
    await tester.pumpAndSettle();
    final roomy = h.controlWalks;
    h.sent.focus.requestFocus();
    await tester.pumpAndSettle();
    expect(h.controlWalks, roomy, reason: 'off a squeezed row a focus change would be a rebuild that changes nothing');
    expect(width(h.sent.controller), fixedFieldMinWidth);
  });

  testWidgets('Enter in a field asks to log and leaves the field focused', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.host());
    await tester.showKeyboard(_fieldFor(h.sent.controller));
    expect(h.sent.focus.hasFocus, isTrue);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(h.submitted, 1);
    // The trap: EditableText's default end-of-editing blurs the field BEFORE
    // it calls onSubmitted, so without the row's own onEditingComplete every
    // Enter would leave the operator with nothing focused.
    expect(h.sent.focus.hasFocus, isTrue, reason: 'the entry row is a loop the keyboard stays inside');

    await tester.showKeyboard(_fieldFor(h.call.controller));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(h.submitted, 2);
    expect(h.call.focus.hasFocus, isTrue);
  });

  testWidgets('an event row takes the fields\' place and keeps the button where it was', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.host(eventFields: const Text('EVENT ROW'), leftieMode: true));
    expect(find.text('EVENT ROW'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'none of the QSO fields are built for an event');
    expect(tester.getTopRight(find.byKey(_submitKey)).dx, lessThan(tester.getTopLeft(find.text('EVENT ROW')).dx));
  });
}
