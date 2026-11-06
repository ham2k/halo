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

  /// The contest exchange fields in the row, by key — or, where a test
  /// needs more than a plain text field, [exchangeControls] whole.
  List<String> exchangeKeys = const [];
  List<Map<String, dynamic>>? exchangeControls;
  List<Map<String, dynamic>> get _exchangeControls =>
      exchangeControls ??
      [
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
    config: () => (
      textControls: () => _exchangeControls,
      editingQso: null,
      operationUuid: 'op',
      serialNumbers: null,
      sequences: null,
      call: '',
      solo: false,
      autoAdvance: true,
      menuBelow: false,
    ),
    draftQsoData: () => const {},
    onPrimaryFieldKeyEvent: (node, event) => KeyEventResult.ignored,
    onAdvanceFocus: () {},
    onFocusChanged: (node, controller) {},
    onEdited: () {},
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
                rstAdvanceWhen: null,
                onRstComplete: () {},
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

  testWidgets('a squeezed row hands the focused field its ideal back on its own; a roomy one stays put', (tester) async {
    final h = _Harness()..exchangeKeys = const ['serial'];
    await tester.pumpWidget(h.host());
    final metrics = mainFieldMetrics(tester.element(find.byType(LoggingEntryRow)));
    double px(int chars) => mainFieldValueWidth(metrics, chars) + metrics.fullPadding;
    final serial = exchangeFieldChars(const {'kind': 'text'});
    // Every field at its min and the callsign at its ideal, with a little to
    // spare: room for any ONE field to take its ideal from the callsign, never
    // for all of them — so the row is squeezed and never overflows.
    final mins = [rstFieldChars.min, rstFieldChars.min, serial.min, stateFieldChars.min, gridFieldChars.min];
    final gaps = logButtonGap + mainFieldGroupGap + mainFieldGap + mainFieldGap + mainFieldGroupGap + mainFieldGroupGap;
    final width = 44 + gaps + px(callFieldChars.ideal) + mins.fold(0.0, (sum, chars) => sum + px(chars)) + 10;
    await tester.pumpWidget(h.host(width: width));
    await tester.pumpAndSettle();
    double widthOf(TextEditingController c) => tester.getSize(_fieldFor(c)).width;
    expect(widthOf(h.sent.controller), lessThan(px(rstFieldChars.ideal)), reason: 'the fields cannot all have their ideals here');

    // The trap: the widening only happens if the focus change rebuilds the
    // row, and nothing outside it is told about the focus change — for
    // every kind of trailing field, not only the reports.
    h.sent.focus.requestFocus();
    await tester.pumpAndSettle();
    expect(widthOf(h.sent.controller), moreOrLessEquals(px(rstFieldChars.ideal), epsilon: 0.01));
    expect(widthOf(h.rcvd.controller), lessThan(widthOf(h.sent.controller)), reason: 'the others stay short while the focused one has its ideal');
    h.grid.focus.requestFocus();
    await tester.pumpAndSettle();
    expect(widthOf(h.grid.controller), moreOrLessEquals(px(gridFieldChars.ideal), epsilon: 0.01));
    expect(widthOf(h.sent.controller), lessThan(px(rstFieldChars.ideal)));
    h.exchange.focusFor('serial').requestFocus();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ExchangeField)).width, moreOrLessEquals(px(serial.ideal), epsilon: 0.01));
    expect(widthOf(h.grid.controller), lessThan(px(gridFieldChars.ideal)));

    await tester.pumpWidget(h.host(width: 780));
    await tester.pumpAndSettle();
    final roomy = h.controlWalks;
    h.sent.focus.requestFocus();
    await tester.pumpAndSettle();
    expect(h.controlWalks, roomy, reason: 'off a row where every field has its ideal, a focus change would be a rebuild that changes nothing');
    expect(widthOf(h.sent.controller), greaterThanOrEqualTo(px(rstFieldChars.ideal)));
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

  group('an optional field (chars.min 0)', () {
    // Only the exchange fields, so the arithmetic below is the row's whole.
    Map<String, dynamic> text(String key, Map<String, dynamic> chars) => {
      'key': key,
      'label': key.toUpperCase(),
      'input': {'kind': 'text', 'chars': chars},
    };
    const typed = {'min': 3, 'ideal': 8};
    const optional = {'min': 0, 'ideal': 5};

    /// The width at which the callsign and the typed fields sit at their
    /// mins and the optional field at its ideal, gaps and padding whole —
    /// the narrowest row that keeps it.
    double keepsOptional(WidgetTester tester, _Harness h) {
      final metrics = mainFieldMetrics(tester.element(find.byType(LoggingEntryRow)));
      double px(int chars) => mainFieldValueWidth(metrics, chars);
      final count = h.exchangeControls!.length;
      return 44 +
          logButtonGap +
          count * mainFieldGap +
          (count + 1) * metrics.fullPadding +
          px(callFieldChars.min) +
          px(typed['min']!) * (count - 1) +
          px(optional['ideal']!);
    }

    Finder byLabel(String label) => find.widgetWithText(TextField, label);

    testWidgets('keeps its ideal while every field has its min, and leaves altogether once they do not', (tester) async {
      final h = _Harness()..exchangeControls = [text('a', typed), text('opt', optional)];
      await tester.pumpWidget(h.host(rst: const [], showState: false, showGrid: false));
      final fits = keepsOptional(tester, h);
      final metrics = mainFieldMetrics(tester.element(find.byType(LoggingEntryRow)));

      await tester.pumpWidget(h.host(width: fits + 1, rst: const [], showState: false, showGrid: false));
      await tester.pumpAndSettle();
      expect(byLabel('OPT'), findsOneWidget);
      // The trap: a min of 0 taken as written, so the optional field is the
      // first to shrink — to a sliver nobody can read.
      expect(
        tester.getSize(find.ancestor(of: byLabel('OPT'), matching: find.byType(ExchangeField))).width,
        greaterThanOrEqualTo(mainFieldValueWidth(metrics, optional['ideal']!)),
      );

      await tester.pumpWidget(h.host(width: fits - 1, rst: const [], showState: false, showGrid: false));
      await tester.pumpAndSettle();
      // The trap: kept, it takes the gaps and padding from the fields the
      // operator types into, for a field they never type into.
      expect(byLabel('OPT'), findsNothing);
      expect(byLabel('A'), findsOneWidget);
    });

    testWidgets('stays when focus gives another field its ideal', (tester) async {
      // Focus is set aside for the decision: a focused field squeezes the
      // others like any concession, and the row reflowing under the
      // operator's next keystroke would be worse than the squeeze.
      final h = _Harness()..exchangeControls = [text('a', typed), text('opt', optional)];
      await tester.pumpWidget(h.host(rst: const [], showState: false, showGrid: false));
      final fits = keepsOptional(tester, h);
      await tester.pumpWidget(h.host(width: fits + 1, rst: const [], showState: false, showGrid: false));
      await tester.pumpAndSettle();

      h.exchange.focusFor('a').requestFocus();
      await tester.pumpAndSettle();
      expect(byLabel('OPT'), findsOneWidget);
    });

    testWidgets('leaving does not take focus from the field after it', (tester) async {
      // The fields are positional children of one Row: without a key per
      // field, the one after the optional field inherits its slot's element,
      // and the text field the operator is in is torn down under them.
      final h = _Harness()..exchangeControls = [text('opt', optional), text('b', typed)];
      await tester.pumpWidget(h.host(rst: const [], showState: false, showGrid: false));
      final fits = keepsOptional(tester, h);
      await tester.pumpWidget(h.host(width: fits + 1, rst: const [], showState: false, showGrid: false));
      await tester.pumpAndSettle();
      await tester.showKeyboard(byLabel('B'));
      expect(h.exchange.focusFor('b').hasFocus, isTrue);

      await tester.pumpWidget(h.host(width: fits - 1, rst: const [], showState: false, showGrid: false));
      await tester.pumpAndSettle();
      expect(byLabel('OPT'), findsNothing, reason: 'the fixture has to have dropped it');
      expect(h.exchange.focusFor('b').hasFocus, isTrue);
    });

    testWidgets('once it has left, typing that moves on passes it by', (tester) async {
      // Its focus node keeps the context of the field it was attached to:
      // read as still on the row, the letter meant for the next field lands in
      // one the operator cannot see, and is logged from there.
      Map<String, dynamic> withRules(Map<String, dynamic> control, Map<String, dynamic> rules) => {
        ...control,
        'input': {...control['input'] as Map, ...rules},
      };
      final h = _Harness()
        ..exchangeControls = [
          withRules(text('a', typed), {'numeric': true, 'autoadvanceBefore': '[0-9]*[A-Z]'}),
          text('opt', optional),
          text('b', typed),
        ];
      await tester.pumpWidget(h.host(rst: const [], showState: false, showGrid: false));
      final fits = keepsOptional(tester, h);
      await tester.pumpWidget(h.host(width: fits + 1, rst: const [], showState: false, showGrid: false));
      await tester.pumpAndSettle();
      expect(byLabel('OPT'), findsOneWidget, reason: 'attached first, so its node has had a context');
      await tester.pumpWidget(h.host(width: fits - 1, rst: const [], showState: false, showGrid: false));
      await tester.pumpAndSettle();
      expect(byLabel('OPT'), findsNothing);

      await tester.showKeyboard(byLabel('A *'));
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '12', selection: TextSelection.collapsed(offset: 2)));
      await tester.pump();
      tester.testTextInput.updateEditingValue(const TextEditingValue(text: '12X', selection: TextSelection.collapsed(offset: 3)));
      await tester.pump();
      expect(h.exchange.valueOf('opt'), '');
      expect(h.exchange.valueOf('b'), 'X');
      expect(h.exchange.focusFor('b').hasFocus, isTrue);
    });
  });

  testWidgets('the segments of one group sit a hairline apart, squared where they meet', (tester) async {
    Map<String, dynamic> segment(String key, String? group) => {
      'key': key,
      'label': key.toUpperCase(),
      'group': ?group,
      'input': {'kind': 'text'},
    };
    final h = _Harness()..exchangeControls = [segment('nr', 'their'), segment('prec', 'their'), segment('zone', null)];
    await tester.pumpWidget(h.host(rst: const [], showState: false, showGrid: false));
    await tester.pumpAndSettle();
    final fields = find.byType(ExchangeField);
    Rect rect(int i) => tester.getRect(fields.at(i));
    expect(rect(1).left - rect(0).right, moreOrLessEquals(segmentDividerWidth, epsilon: 0.01), reason: 'one pill: the panel shows through a hairline');
    expect(rect(2).left - rect(1).right, moreOrLessEquals(mainFieldGap, epsilon: 0.01), reason: 'another group is another control');

    BorderRadius radius(String label) =>
        (tester.widget<TextField>(find.widgetWithText(TextField, label)).decoration!.border! as UnderlineInputBorder).borderRadius;
    const round = Radius.circular(4);
    expect(radius('NR'), const BorderRadius.only(topLeft: round));
    expect(radius('PREC'), const BorderRadius.only(topRight: round));
  });

  testWidgets('an event row takes the fields\' place and keeps the button where it was', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.host(eventFields: const Text('EVENT ROW'), leftieMode: true));
    expect(find.text('EVENT ROW'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'none of the QSO fields are built for an event');
    expect(tester.getTopRight(find.byKey(_submitKey)).dx, lessThan(tester.getTopLeft(find.text('EVENT ROW')).dx));
  });
}
