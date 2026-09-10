// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CommandInterpretationModel on its own — what the field's input mode is
// retained from, when a message reaches the host, and which answers are
// dropped as stale. The widget suite exercises the same through the field;
// these pin the model's contract where a panel would hide which side moved.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/src/call_field_text.dart';
import 'package:halo_widgets/src/logging_controls_command.dart';

class _Harness {
  String text = '';
  final interpreted = <String>[];
  final messages = <String?>[];
  int notifications = 0;
  Map<String, dynamic>? Function(String input) answer = (input) => null;

  late final model = CommandInterpretationModel(
    config: () => (
      interpretCommand: (input, [operation, qso, execute = false]) async {
        interpreted.add('$input${execute ? ' execute' : ''}');
        return answer(input);
      },
      editingQso: null,
      operationData: () => const {'uuid': 'op'},
      onMessageChanged: messages.add,
    ),
    callText: () => CallFieldText(text, cursor: text.length, stacking: true),
    qsoData: () => const {},
  )..addListener(() => notifications++);
}

void main() {
  testWidgets('the describe preview is debounced and applied only while the text still matches', (tester) async {
    final h = _Harness();
    h.answer = (input) => {'describe': 'Tune to $input'};
    h.text = '14285';
    h.model.scheduleDescribe();
    expect(h.interpreted, isEmpty);
    await tester.pump(const Duration(milliseconds: 150));
    expect(h.model.message, 'Tune to 14285');
    expect(h.messages, ['Tune to 14285']);
    expect(h.model.hasExecutableCommand, isTrue);

    h.model.keystroke();
    h.text = '142850';
    expect(h.model.message, isNull);
    expect(h.messages.last, isNull, reason: 'the host hears the message went, once');
    h.model.scheduleDescribe();
    h.text = '1428500';
    await tester.pump(const Duration(milliseconds: 150));
    expect(h.interpreted.last, '142850');
    expect(h.model.message, isNull, reason: 'the answer was for text the operator has moved past');
    h.model.dispose();
  });

  testWidgets('a retained command holds the input mode through the keystrokes that type its parameters',
      (tester) async {
    final h = _Harness();
    h.answer = (input) => input == 'NOTE' ? {'expectsParams': true, 'mixedCase': true} : null;
    h.text = 'NOTE';
    h.model.scheduleDescribe();
    await tester.pump(const Duration(milliseconds: 150));
    expect(h.model.fieldAcceptsSpaces, isTrue);
    expect(h.model.hasExecutableCommand, isFalse, reason: 'still awaiting its parameters');

    h.model.keystroke();
    h.text = 'NOTE Called Bob';
    expect(h.model.mixedCase, isTrue, reason: 'the retained mode survives the per-keystroke reset');
    h.model.scheduleDescribe();
    await tester.pump(const Duration(milliseconds: 150));
    expect(h.model.expectsParams, isTrue,
        reason: 'a null answer does not snap back while the text holds characters the callsign filter would strip');

    h.text = 'W1AW';
    h.model.scheduleDescribe();
    await tester.pump(const Duration(milliseconds: 150));
    expect(h.model.fieldAcceptsSpaces, isFalse, reason: 'plain callsign text lets the mode reset');
    h.model.dispose();
  });

  testWidgets('a message reaches the host only when it changes, and a confirmation clears itself',
      (tester) async {
    final h = _Harness();
    h.text = 'RELOAD';
    h.model.showError('No such thing');
    h.model.showError('No such thing');
    expect(h.messages, ['No such thing']);
    h.model.commandExecuted(confirm: 'Done');
    expect(h.messages, ['No such thing', 'Done']);
    await tester.pump(const Duration(seconds: 5));
    expect(h.model.message, isNull);
    expect(h.messages, ['No such thing', 'Done', null]);
    h.model.commandExecuted(confirm: null);
    expect(h.messages.length, 3, reason: 'null after null is not a change');
    h.model.dispose();
  });

  testWidgets('an error shown after a confirmation owns the slot: the confirmation timer must not clear it',
      (tester) async {
    final h = _Harness();
    h.model.commandExecuted(confirm: 'Done');
    h.model.showError('Failed');
    await tester.pump(const Duration(seconds: 5));
    expect(h.model.message, 'Failed');
    h.model.dispose();
  });

  testWidgets('interpretNow reuses the debounced answer, and reports a stale one', (tester) async {
    final h = _Harness();
    h.answer = (input) => {'describe': input};
    h.text = 'CW';
    h.model.scheduleDescribe();
    await tester.pump(const Duration(milliseconds: 150));
    final reused = await h.model.interpretNow(applyToDisplay: false);
    expect(reused.interpretation, isNotNull);
    expect(h.interpreted, ['CW'], reason: 'no second round trip for the same text');

    h.model.keystroke();
    h.text = 'CWX';
    final pending = h.model.interpretNow(applyToDisplay: true);
    h.text = 'CWXY';
    final result = await pending;
    expect(result.stale, isTrue);
    expect(h.model.message, isNull, reason: 'a stale answer is not shown');
    h.model.dispose();
  });

  testWidgets('a pushed update applies only for the input it was asked about', (tester) async {
    final h = _Harness();
    final updates = StreamController<Map<String, dynamic>>();
    h.model.bind(updates.stream);
    h.text = 'SOLAR';
    updates.add({'input': 'SOLAR', 'interpretation': {'describe': 'SFI 150'}});
    updates.add({'input': 'WX', 'interpretation': {'describe': 'Rain'}});
    await tester.pump();
    expect(h.model.message, 'SFI 150');
    // Closed with the listener still attached: a controller nobody listens
    // to never delivers its done event, and the close would hang.
    await updates.close();
    h.model.dispose();
  });
}
