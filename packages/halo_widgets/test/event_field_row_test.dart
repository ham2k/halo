// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// EventFieldRow on its own: which kinds get an editable field, which get a
// read-only value, and what the panel hears back — and the read/write pair
// behind its NOTE/TODO text, where a record carrying BOTH keys shows the
// precedence that no panel test builds a record for.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/src/logging_controls_draft.dart' show qsoDataEquivalent;
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

  group('a record carrying both description and note', () {
    final both = _event('note', extra: {'description': 'shown', 'note': 'hidden'});

    test('reads the one AnnotationRow displays', () {
      // Reading `note` first would put text in the editor that the log does
      // not show for this row, and a save would then write it over what it does.
      expect(eventFieldsFromData(both.data).text, 'shown');
    });

    test('writes back to that same key, leaving the other alone', () {
      final saved = eventDataForSave(both, text: 'edited', done: false, startAtMillis: null);
      expect(saved['event'], containsPair('description', 'edited'));
      expect(saved['event'], containsPair('note', 'hidden'));
    });
  });

  // What the panel does with a row the operator only selected: read it into
  // the editor, write it straight back, and compare. Any difference reads as
  // an edit, and an edited row offers Revert where it should offer Delete.
  bool untouchedRoundTrips(Qso q) {
    final read = eventFieldsFromData(q.data);
    return qsoDataEquivalent(eventDataForSave(q, text: read.text, done: read.done, startAtMillis: null), q.data);
  }

  group('a row saved untouched writes back its own record', () {
    for (final (label, extra) in [
      ('a TODO with no event.data', <String, dynamic>{'note': 'x'}),
      ('a legacy TODO carrying a bare done', <String, dynamic>{'note': 'x', 'done': true}),
      (
        'a TODO PoLo unchecked over a bare done',
        <String, dynamic>{
          'note': 'x',
          'done': true,
          'data': {'done': false},
        },
      ),
      (
        'a TODO in the current shape',
        <String, dynamic>{
          'note': 'x',
          'data': {'done': true},
        },
      ),
    ]) {
      test(label, () => expect(untouchedRoundTrips(_event('todo', extra: extra)), isTrue));
    }

    test('a NOTE whose description is null', () {
      expect(untouchedRoundTrips(_event('note', extra: {'description': null, 'note': 'check later'})), isTrue);
    });

    test('a NOTE whose note is not a string, which the editor shows empty', () {
      // Writing the editor's '' back would replace a value the operator never
      // saw, and a save with no edit would sync that loss to every peer.
      expect(untouchedRoundTrips(_event('note', extra: {'note': 42})), isTrue);
    });
  });

  group("a TODO's done flag", () {
    test('reads data.done over a bare done, the way PoLo reads it', () {
      // PoLo unchecking a legacy TODO writes `data.done: false` and leaves the
      // bare `done: true` behind; OR-ing the two would show it done here while
      // PoLo shows it open.
      final unchecked = _event(
        'todo',
        extra: {
          'note': 'x',
          'done': true,
          'data': {'done': false},
        },
      );
      expect(eventFieldsFromData(unchecked.data).done, isFalse);
    });

    test('falls back to the bare done only when data.done is absent', () {
      expect(eventFieldsFromData(_event('todo', extra: {'note': 'x', 'done': true}).data).done, isTrue);
    });

    test('toggled on a legacy TODO, moves into data and drops the bare key', () {
      final legacy = _event('todo', extra: {'note': 'x', 'done': true});
      final event = eventDataForSave(legacy, text: 'x', done: false, startAtMillis: null)['event'] as Map;
      expect(event['data'], {'done': false});
      expect(event.containsKey('done'), isFalse, reason: 'a bare done left behind is what older readers would still see');
    });
  });

  test("a NOTE whose description is null writes its text back to note, the key it was read from", () {
    final q = _event('note', extra: {'description': null, 'note': 'check later'});
    final event = eventDataForSave(q, text: 'edited', done: false, startAtMillis: null)['event'] as Map;
    expect(event['note'], 'edited');
    expect(event['description'], isNull);
  });

  group('a malformed synced record still opens', () {
    test('a description that is not a string falls back to note', () {
      final q = _event('note', extra: {'description': 42, 'note': 'check later'});
      expect(eventFieldsFromData(q.data).text, 'check later');
    });

    test('a note that is not a string reads as empty', () {
      expect(
        eventFieldsFromData(
          _event(
            'note',
            extra: {
              'note': ['a'],
            },
          ).data,
        ).text,
        '',
      );
    });

    test('an event map with dynamic keys is read, not rejected', () {
      // A map handed over the extension bridge is Map<dynamic, dynamic> even
      // when every key is a string.
      final data = <String, dynamic>{
        'band': 'event',
        'event': <dynamic, dynamic>{'event': 'note', 'note': 'from a bridge'},
      };
      expect(eventFieldsFromData(data).text, 'from a bridge');
    });
  });
}
