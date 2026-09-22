// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// EventFieldRow on its own: which kinds get an editable field, which get a
// read-only value, and what the panel hears back.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/src/logging_controls_event_row.dart';

Qso _event(String kind, {Map<String, dynamic> extra = const {}}) => Qso(
  uuid: 'e1',
  operationUuid: 'op',
  data: {
    'band': 'event',
    'event': {'event': kind, ...extra},
  },
);

class _Harness {
  _Harness() {
    addTearDown(() {
      controller.dispose();
      focus.dispose();
    });
  }

  final controller = TextEditingController();
  final focus = FocusNode();
  final doneChanges = <bool>[];
  int submitted = 0;

  Widget host(Qso qso, {bool enabled = true, bool todoDone = false}) => MaterialApp(
    home: Scaffold(
      body: EventFieldRow(
        editingQso: qso,
        textController: controller,
        textFocus: focus,
        enabled: enabled,
        todoDone: todoDone,
        onTodoDoneChanged: doneChanges.add,
        onSubmitted: () => submitted++,
      ),
    ),
  );
}

void main() {
  testWidgets('a NOTE row edits its text, and Enter asks to log', (tester) async {
    final h = _Harness();
    h.controller.text = 'Lunch';
    await tester.pumpWidget(h.host(_event('note')));
    expect(find.text('NOTE'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing, reason: 'only a TODO has a done state');
    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(h.submitted, 1);
  });

  testWidgets('a TODO row carries its done box; the panel hears a tap, and a locked row\'s box is inert', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.host(_event('todo')));
    expect(find.text('TODO'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    expect(h.doneChanges, [true], reason: 'the widget reports, the panel owns the value');

    await tester.pumpWidget(h.host(_event('todo'), todoDone: true, enabled: false));
    final locked = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(locked.value, isTrue);
    expect(locked.onChanged, isNull, reason: 'a staged or deleted row takes no edits');
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('SOLAR shows its description read-only, and BREAK shows a field-shaped nothing', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.host(_event('solar', extra: {'description': 'SFI 142 A 5 K 1'})));
    expect(find.text('SOLAR'), findsOneWidget);
    expect(find.text('SFI 142 A 5 K 1'), findsOneWidget);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.enabled, isFalse);
    // The trap: the stand-in exists so the row is a real field's height,
    // not to be typed in — and a second event's text must replace the first
    // (a TextFormField only reads initialValue once per State).
    await tester.pumpWidget(h.host(_event('solar', extra: {'description': 'SFI 150'})));
    expect(find.text('SFI 150'), findsOneWidget);
    expect(find.text('SFI 142 A 5 K 1'), findsNothing);

    await tester.pumpWidget(h.host(_event('break')));
    expect(find.text('BREAK'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget, reason: 'same height as an editable row');
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).initialValue, isEmpty);
  });
}
