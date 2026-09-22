// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// CommandInterpretationModel on its own — what the field's input mode is
// retained from, when a message reaches the host, and which answers are
// dropped as stale. The widget suite exercises the same through the field;
// these pin the model's contract where a panel would hide which side moved.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/src/call_field_text.dart';
import 'package:halo_widgets/src/logging_controls_command.dart';

class _Harness {
  String text = '';
  bool editing = false;
  final interpreted = <String>[];
  final messages = <String?>[];
  int notifications = 0;
  Map<String, dynamic>? Function(String input) answer = (input) => null;

  /// The answer to an `execute: true` interpretation, when it differs from
  /// the preview's — a hook whose preview leaves the commands cheap.
  Map<String, dynamic>? Function(String input)? answerForExecution;

  late final model = CommandInterpretationModel(
    config: () => (
      interpretCommand: (input, [operation, qso, execute = false]) async {
        interpreted.add('$input${execute ? ' execute' : ''}');
        return execute && answerForExecution != null ? answerForExecution!(input) : answer(input);
      },
      editingQso: editing ? const Qso(uuid: 'q', operationUuid: 'op', data: {}) : null,
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

  testWidgets('a retained command holds the input mode through the keystrokes that type its parameters', (tester) async {
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
    expect(h.model.expectsParams, isTrue, reason: 'a null answer does not snap back while the text holds characters the callsign filter would strip');

    h.text = 'W1AW';
    h.model.scheduleDescribe();
    await tester.pump(const Duration(milliseconds: 150));
    expect(h.model.fieldAcceptsSpaces, isFalse, reason: 'plain callsign text lets the mode reset');
    h.model.dispose();
  });

  testWidgets('a message reaches the host only when it changes, and a confirmation clears itself', (tester) async {
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

  testWidgets('an error shown after a confirmation owns the slot: the confirmation timer must not clear it', (tester) async {
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
    updates.add({
      'input': 'SOLAR',
      'interpretation': {'describe': 'SFI 150'},
    });
    updates.add({
      'input': 'WX',
      'interpretation': {'describe': 'Rain'},
    });
    await tester.pump();
    expect(h.model.message, 'SFI 150');
    // Closed with the listener still attached: a controller nobody listens
    // to never delivers its done event, and the close would hang.
    await updates.close();
    h.model.dispose();
  });

  group('Enter on the call field', () {
    /// The panel's side of [CommandInterpretationModel.runOnEnter]: its
    /// double-log guard, its field, its actions, its failure channel.
    ({Future<bool> Function() enter, List<String> log, void Function() setLogging}) wire(_Harness h, {Object? throwOnDispatch}) {
      final log = <String>[];
      var logging = false;
      Future<bool> enter() => h.model.runOnEnter(
        alreadyLogging: () => logging,
        whileLogging: (body) async {
          log.add('logging on');
          logging = true;
          try {
            await body();
          } finally {
            logging = false;
            log.add('logging off');
          }
        },
        clearField: () {
          log.add('cleared');
          // The real field's listener reads a programmatic clear as a
          // keystroke, which drops the message.
          h.model.keystroke();
        },
        dispatch: (commands, {required skipOnlineLookup}) async {
          log.add('dispatch ${commands.join(',')} skipOnline=$skipOnlineLookup');
          if (throwOnDispatch != null) {
            log.add('failed: $throwOnDispatch');
            return;
          }
        },
      );
      return (enter: enter, log: log, setLogging: () => logging = true);
    }

    test('a plain callsign is not a command: Enter falls through to logging, nothing cleared', () async {
      final h = _Harness();
      final w = wire(h);
      h.text = 'W1AW';
      expect(await w.enter(), isFalse);
      expect(w.log, isEmpty);
      expect(h.interpreted, ['W1AW'], reason: "Enter's own interpretation, once");
      h.model.dispose();
    });

    test('a command that cannot run here shows why and keeps the text; one awaiting parameters falls through', () async {
      final h = _Harness();
      final w = wire(h);
      h.answer = (input) => {'error': 'Not while editing'};
      h.text = 'RELOAD';
      expect(await w.enter(), isTrue);
      expect(h.model.message, 'Not while editing');
      expect(w.log, isEmpty, reason: 'nothing ran, nothing cleared');

      h.answer = (input) => {'expectsParams': true, 'describe': 'NOTE …'};
      h.text = 'NOTE';
      expect(await w.enter(), isFalse, reason: 'still being typed: Enter is just Enter');
      expect(w.log, isEmpty);
      h.model.dispose();
    });

    test('an executable command is re-interpreted for execution, clears the field, confirms and dispatches', () async {
      final h = _Harness();
      final w = wire(h);
      h.answer = (input) => {'describe': 'Tune'};
      h.answerForExecution = (input) => {
        'commands': ['setVfo'],
        'confirm': 'Tuned',
        'skipOnlineLookup': true,
      };
      h.text = '14285';
      expect(await w.enter(), isTrue);
      expect(h.interpreted, ['14285', '14285 execute'], reason: "the preview's commands may be a cheap placeholder; the run asks again with execute");
      expect(w.log, ['logging on', 'cleared', 'dispatch setVfo skipOnline=true', 'logging off']);
      expect(h.model.message, 'Tuned');
      h.model.dispose();
    });

    test('a dispatch that fails is the panel\'s to report; the bracket still closes', () async {
      final h = _Harness();
      final w = wire(h, throwOnDispatch: StateError('disk full'));
      h.answer = (input) => {
        'commands': ['addQso'],
      };
      h.text = 'SEED';
      expect(await w.enter(), isTrue);
      expect(w.log.last, 'logging off');
      expect(w.log, contains('failed: Bad state: disk full'));
      h.model.dispose();
    });

    test('nothing to consider while editing, with an empty field, or without an interpreter', () async {
      final h = _Harness();
      final w = wire(h);
      h.answer = (input) => {
        'commands': ['setVfo'],
      };
      h.text = '';
      expect(await w.enter(), isFalse);
      h.text = '14285';
      h.editing = true;
      expect(await w.enter(), isFalse, reason: 'an edit never runs the text as a command');
      expect(h.interpreted, isEmpty, reason: 'not even interpreted');
      h.model.dispose();
    });

    test('a call that moved on, or a second Enter racing the first, consumes Enter and runs nothing', () async {
      final h = _Harness();
      final w = wire(h);
      // The preview await returns to a field that no longer holds the text
      // it was asked about — the second Enter of an auto-repeat is already
      // in flight for it.
      h.answer = (input) {
        h.text = 'W1AW';
        return {
          'commands': ['setVfo'],
        };
      };
      h.text = '14285';
      expect(await w.enter(), isTrue);
      expect(w.log, isEmpty, reason: 'consumed, and nothing ran for the text that is gone');

      // The first Enter commits to logging while this one is still awaiting
      // its interpretation: the flag is read AFTER that await, or the race
      // is not seen.
      h.answer = (input) {
        w.setLogging();
        return {
          'commands': ['setVfo'],
        };
      };
      h.text = '7200';
      expect(await w.enter(), isTrue, reason: 'the racing Enter is dropped, not run twice');
      expect(w.log, isEmpty);
      h.model.dispose();
    });

    test('a call that moves on during the execute-time round trip runs nothing, and the field is kept', () async {
      final h = _Harness();
      final w = wire(h);
      h.answer = (input) => {'describe': 'Tune'};
      // Key auto-repeat fires well inside an extension round trip: the second
      // Enter's own interpretation is what changes the field here.
      h.answerForExecution = (input) {
        h.text = 'W1AW';
        return {
          'commands': ['setVfo'],
        };
      };
      h.text = '14285';
      expect(await w.enter(), isTrue);
      expect(w.log, ['logging on', 'logging off'], reason: 'nothing cleared, nothing dispatched');
      h.model.dispose();
    });

    test('an execute-time error keeps the text; a null execution runs nothing', () async {
      final h = _Harness();
      final w = wire(h);
      h.answer = (input) => {'describe': 'Solar'};
      h.answerForExecution = (input) => {'error': 'Fetch failed'};
      h.text = 'SOLAR';
      expect(await w.enter(), isTrue);
      expect(h.model.message, 'Fetch failed');
      expect(w.log, ['logging on', 'logging off'], reason: 'the bracket closed; the field was not cleared');

      // No hook answered the execute-time interpretation.
      h.answerForExecution = (input) => null;
      expect(await w.enter(), isTrue);
      expect(w.log, ['logging on', 'logging off', 'logging on', 'logging off'], reason: 'nothing to run');
      h.model.dispose();
    });
  });
}
