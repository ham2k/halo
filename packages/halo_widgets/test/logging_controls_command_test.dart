// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Commands typed into the call field: how an interpretation is offered,
// applied and dispatched, where focus lands after one, and the frequency
// field's band shorthand. The note expansion a key stands for is beside
// this file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  testWidgets('call-field commands: frequency, band, and mode via space', (tester) async {
    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeInterpretCommand)));
    // Commands apply their changes without forcing the Radio control open
    // (see the dedicated test for that); open it manually here so the
    // assertions below can read its fields.
    await openControl(tester, MdiIcons.radio);

    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));
    Future<void> command(String text) async {
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), text);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      // Wait for all command execution and state dispatching to finish
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Frequency command fills the freq field and derives the band.
    await command('14285');
    expect(field('Their call').controller!.text, isEmpty);
    // NOT the focus-after-submit guard — `command()` uses sendKeyEvent, which
    // never finalizes the editing session, so this passes even when Enter blurs
    // the field. That case belongs to the "Enter keeps focus in the field that
    // submitted (real submit path)" group below; this only pins that a command
    // doesn't wander off with the focus while the shortcut path runs.
    expect(field('Their call').focusNode!.hasFocus, isTrue);
    expect(field('Frequency').controller!.text, '14285');
    expect(find.text('20m'), findsWidgets);

    // Mode command switches mode, and the RST placeholder follows it.
    await command('CW');
    expect(field('Sent').decoration!.hintText, '599');

    // Band command overrides band and clears the frequency.
    await command('40M');
    expect(field('Frequency').controller!.text, isEmpty);
    expect(find.text('40m'), findsWidgets);

    // Log a QSO with the band-only state: band recorded, no frequency.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    expect(logged.single.band, '40m');
    expect(logged.single.freq, isNull);
    expect(logged.single.mode, 'CW');
  });

  group('HALO-158: the frequency field also takes a band', () {
    TextField field(WidgetTester tester, String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    /// Types [text] into the Frequency field and leaves it with Space —
    /// which, from this field, hands focus back to the call field
    /// (`_handleSpace`) and so is the gesture that commits it.
    Future<void> typeFreqAndLeave(WidgetTester tester, String text) async {
      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), text);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
    }

    // `host()` seeds a radio tuned to 14285 / 20m, so every band asserted here
    // is deliberately NOT 20m — otherwise the seed alone would satisfy it.

    testWidgets('a band with its unit lands in the Band dropdown and empties the field', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      await typeFreqAndLeave(tester, '40m');

      expect(field(tester, 'Band').controller!.text, '40m');
      expect(field(tester, 'Frequency').controller!.text, isEmpty, reason: 'the text that named the band is not a frequency, and must not read as one');
    });

    testWidgets('a bare number names a band too, since the iOS keyboard here has no letters', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      await typeFreqAndLeave(tester, '15');

      expect(field(tester, 'Band').controller!.text, '15m');
      expect(field(tester, 'Frequency').controller!.text, isEmpty);
    });

    testWidgets('a real frequency is left exactly as typed', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      await typeFreqAndLeave(tester, '7123');

      expect(field(tester, 'Frequency').controller!.text, '7123', reason: 'a frequency inside a band is never re-read as a band');
      expect(field(tester, 'Band').controller!.text, '40m');
    });

    testWidgets('nothing resolves until the operator leaves the field', (tester) async {
      // The reason resolution is on commit rather than per keystroke: "40" is
      // a prefix of "40 something" as often as it is a request for 40m. Moving
      // this into `_band` or `_onFreqChanged` makes every frequency typed by
      // hand flicker through a band on its way, and breaks here.
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '40');
      await tester.pump();

      expect(field(tester, 'Band').controller!.text, isNot('40m'));
      expect(field(tester, 'Frequency').controller!.text, '40');
    });

    testWidgets('text that names no band is left alone', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      // 14m is not a band; rounding it to the nearest one would log a contact
      // on a band the operator never named.
      await typeFreqAndLeave(tester, '14m');

      expect(field(tester, 'Frequency').controller!.text, '14m');
    });

    testWidgets('a frequency the operator never typed is left alone, band number or not', (tester) async {
      // A general-coverage rig parked on WWVB reports 60 kHz, which is in no
      // band and reads exactly like the bare form of 60m. Opening the Radio
      // control focuses this field, so without a "did they change it?" gate,
      // opening the control and leaving it would swallow the reading and push
      // 60m back at the rig — no keystroke involved.
      final seeded = FakeVfoStore()..setVfo('vfoA', freq: 60, mode: 'SSB');
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: seeded)));
      await openControl(tester, MdiIcons.radio);

      expect(field(tester, 'Frequency').controller!.text, '60', reason: 'the seed must reach the field');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(field(tester, 'Frequency').controller!.text, '60');
      expect(seeded.vfoA.freq, 60);
      expect(seeded.vfoA.band, isNot('60m'));
    });

    testWidgets('a band typed into the field logs a band-only QSO', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      await typeFreqAndLeave(tester, '40m');
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.band, '40m');
      expect(logged.single.freq, isNull, reason: 'the operator named a band, not a frequency — HALO-24 is satisfied by the band alone');
    });
  });

  testWidgets('HALO-32: a frequency command with no mode of its own guesses one from the band plan', (tester) async {
    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeInterpretCommand)));
    await openControl(tester, MdiIcons.radio);

    // The fake frequency command mirrors the real radio-commands extension:
    // {setVfo: {freq}}, no mode — same as typing straight into the
    // Frequency field, this must fall back to guessing one from the band
    // plan (14074 kHz is FT8 territory) rather than leaving the prior mode.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '14074');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14074');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText,
      '+0',
      reason: 'FT8 exchanges a signal-to-noise figure, not an RST',
    );
  });

  // Enter must never cost the operator the field they were typing in. The
  // entry row is a loop the keyboard stays inside (docs/design/logging-fields.md
  // § "Moving between the main fields"), so Enter means "log", not "done
  // editing" — but `EditableText`'s default finalization unfocuses the field
  // BEFORE it calls `onSubmitted`, which made every Enter blur. The entry row
  // only looked intact because the two ordinary paths re-focus afterwards
  // (`_wipe` after a logged QSO, the `!_canLog` guard otherwise); every path
  // that didn't — running a command, saving an edit, a second Enter while one
  // was in flight — left nothing focused. `finishEditingWithoutBlur` suppresses
  // the blur at the field, so all of them are covered at once.
  //
  // These drive the submit the way the ENGINE does, via
  // `receiveAction(TextInputAction.done)`. That distinction is the whole point:
  // `sendKeyEvent(enter)` reaches `_log` through the panel's CallbackShortcuts
  // without ever finalizing the editing session, so it never blurs the field
  // and a test written that way passes against the broken code. Anything here
  // that switches back to sendKeyEvent stops testing this.
  //
  // The last three cases are the ones a re-focus inside `_log` could not pass,
  // and they are why the fix lives at the field: they submit from somewhere
  // other than the call field, or never reach the command branch at all.
  group('Enter keeps focus in the field that submitted (real submit path)', () {
    Future<void> submit(WidgetTester tester, Finder field, String input) async {
      await tester.enterText(field, input);
      await tester.pump(const Duration(milliseconds: 200)); // past the describe debounce
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400)); // command execution + dispatch
    }

    Finder callField() => find.widgetWithText(TextField, 'Their call');
    bool hasFocus(WidgetTester tester, Finder field) => tester.widget<TextField>(field).focusNode!.hasFocus;

    testWidgets('after an everyday frequency command', (tester) async {
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeInterpretCommand)));
      await submit(tester, callField(), '14285');
      expect(hasFocus(tester, callField()), isTrue);
      // …and the command really did run, so this isn't passing on a no-op.
      expect(tester.widget<TextField>(callField()).controller!.text, isEmpty);
    });

    // DEVPROGRESS was the reported case and DEVNOTICE the follow-up, but at this
    // layer they are one path — `_log` never inspects the action name, it just
    // hands it to `onCommandAction`. One case covers both; what actually differs
    // between them is downstream, in the status bar.
    testWidgets('after a command that only posts to the status bar', (tester) async {
      final dispatched = <String>[];
      Future<Map<String, dynamic>?> interpretDevProgress(
        String input, [
        Map<String, dynamic>? operation,
        Map<String, dynamic>? qso,
        bool execute = false,
      ]) async {
        if (input.trim().toUpperCase() != 'DEVPROGRESS') return null;
        return {
          'describe': 'Show an indeterminate dev progress bar?',
          'confirm': 'Added an indeterminate progress bar',
          'commands': [
            {
              'devProgress': {'icon': 'progress-clock', 'title': 'Dev progress'},
            },
          ],
        };
      }

      await tester.pumpWidget(
        host(
          commands: CommandHooks(interpretCommand: interpretDevProgress, onCommandAction: (a, [params]) async => dispatched.add(a)),
        ),
      );
      await submit(tester, callField(), 'DEVPROGRESS');
      expect(hasFocus(tester, callField()), isTrue);
      expect(dispatched, ['devProgress']);
    });

    testWidgets('and a plain QSO still does too, so the fix did not trade one for the other', (tester) async {
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeInterpretCommand)));
      await submit(tester, callField(), 'W1AW');
      expect(hasFocus(tester, callField()), isTrue);
      // Anchored: this case passes under every mutation of the fix (by design —
      // `_wipe` re-focuses either way), so without pinning that a contact was
      // actually logged it would also survive Enter becoming a no-op, where
      // focus simply never moves.
      expect((await waitForQsos(tester, 1)).single.theirCall, 'W1AW');
    });

    // The other half of `finishEditingWithoutBlur`. Supplying `onEditingComplete`
    // replaces the branch that ALSO cleared the composing region, so the helper
    // reinstates it — and that half is invisible to every other test here,
    // because `enterText` never produces a composing range. `updateEditingValue`
    // does, which is what makes this checkable at all.
    testWidgets('submitting clears the composing region the default would have', (tester) async {
      await tester.pumpWidget(host());
      final node = tester.widget<TextField>(callField()).focusNode!;
      node.requestFocus();
      await tester.pump();

      final state = tester.state<EditableTextState>(find.descendant(of: callField(), matching: find.byType(EditableText)));
      state.updateEditingValue(const TextEditingValue(text: 'W1A', selection: TextSelection.collapsed(offset: 3), composing: TextRange(start: 0, end: 3)));
      await tester.pump();
      expect(state.textEditingValue.composing.isValid, isTrue, reason: 'the IME state must be set up first');

      // Assert immediately — do NOT pump first. `_finalizeEditing`'s trailing
      // `_scheduleRestartConnection()` re-attaches the input connection a frame
      // later and clears the composing run on its own, so a settle pump here
      // makes this pass even with the helper emptied out. Verified: with a
      // pump, the no-op mutant survives; without one, it fails.
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(state.textEditingValue.composing.isValid, isFalse, reason: 'a live composing run must not survive the submit');
    });

    // Submitting from a field other than the callsign must leave focus THERE.
    // Re-focusing the call field inside `_log` looks equivalent until you try
    // this: it yanks the caret out of the field mid-entry, and rewrites
    // `_lastPrimaryFocus` with it, so collapsing a secondary control later
    // returns to the wrong field.
    //
    // `Sent` is an RST field, built by `LoggingEntryRow`'s fixed-field builder — one of the three build
    // sites, and NOT the exchange-field builder, which the next test covers.
    testWidgets('a command submitted from an RST field leaves focus in that field', (tester) async {
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeInterpretCommand)));
      final sent = find.widgetWithText(TextField, 'Sent');

      await tester.enterText(callField(), '14285');
      await tester.pump(const Duration(milliseconds: 200));
      tester.widget<TextField>(sent).focusNode!.requestFocus();
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400));

      expect(hasFocus(tester, sent), isTrue, reason: 'Enter from Sent must not move the caret to the call field');
      expect(hasFocus(tester, callField()), isFalse);
    });

    // The exchange-field builder is the third site, and the only one whose
    // `onSubmitted` is `_handleEnter()` rather than `_log()` — so it owns a
    // branch (accept a highlighted suggestion, then return without logging)
    // that neither other site has. Without this, deleting its
    // `onEditingComplete` passed all 245 tests.
    testWidgets('a command submitted from a contest exchange field leaves focus in that field', (tester) async {
      const theirSerial = {
        'key': 'cqwpx/theirSerial',
        'label': 'Their #',
        'icon': 'flag-checkered',
        'input': {'kind': 'text', 'refType': 'cqwpx', 'field': 'theirSerial', 'numeric': true},
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: LogHooks(operation: running(['cqwpx']), qsosRepository: qsos),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: const [theirSerial]),
              commands: CommandHooks(interpretCommand: fakeInterpretCommand),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final exchange = find.widgetWithText(TextField, 'Their #');
      expect(exchange, findsOneWidget, reason: 'the contest exchange field must actually be on screen');

      await tester.enterText(callField(), '14285');
      await tester.pump(const Duration(milliseconds: 200));
      tester.widget<TextField>(exchange).focusNode!.requestFocus();
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400));

      expect(hasFocus(tester, exchange), isTrue, reason: 'Enter from a contest exchange must not move the caret to the call field');
      expect(hasFocus(tester, callField()), isFalse);
    });

    // Saving an edit returns through `onEditCanceled`, which never touched
    // focus — a path no amount of re-focusing inside the command branch reaches.
    testWidgets('saving an edited QSO with Enter keeps focus', (tester) async {
      final existingQso = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'startAtMillis': 1000000,
          'freq': 7100,
          'mode': 'SSB',
        }),
      ))!;
      var canceled = false;
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: existingQso, onEditCanceled: () => canceled = true),
        ),
      );

      await submit(tester, callField(), 'W1AWX');
      expect(canceled, isTrue, reason: 'the edit should have been saved, not ignored');
      expect(hasFocus(tester, callField()), isTrue);
    });

    // A second Enter while the first command is still in flight. This one
    // reaches `_log`'s `_isLogging` guard and returns there — but only because
    // `SLOW` is a RECOGNIZED command, so the describe debounce has already
    // cached an interpretation and the await below it is skipped. A plain
    // callsign never caches one, which is the case the next test covers; do not
    // read this one as proving the guard holds generally.
    testWidgets('a second Enter while a slow command is in flight keeps focus', (tester) async {
      final release = Completer<void>();
      Future<Map<String, dynamic>?> slowCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
        if (input.trim().toUpperCase() != 'SLOW') return null;
        if (execute) await release.future;
        return {
          'describe': 'Run the slow one?',
          'confirm': 'Ran it',
          'commands': [
            {
              'devStatus': {'text': 'done'},
            },
          ],
        };
      }

      await tester.pumpWidget(
        host(
          commands: CommandHooks(interpretCommand: slowCommand, onCommandAction: (a, [p]) async {}),
        ),
      );
      await tester.enterText(callField(), 'SLOW');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.testTextInput.receiveAction(TextInputAction.done); // starts executing, awaits release
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done); // returns at the _isLogging guard
      await tester.pump();

      release.complete();
      await tester.pump(const Duration(milliseconds: 400));
      expect(hasFocus(tester, callField()), isTrue);
    });

    // The same QSO must never be logged twice. `_log`'s `_isLogging` guard runs
    // at entry, but the flag isn't set until a branch commits to logging — and
    // in between sits an `await interpretCommand(...)`. A plain callsign
    // interprets to null, so nothing is ever cached and EVERY logging Enter
    // goes through that await: a second Enter arriving inside it passed the
    // entry guard too, and both go on to write the contact.
    //
    // Keeping focus is what makes this reachable from the on-screen keyboard,
    // so it belongs to this group — but the window is not specific to a
    // command, and the case above cannot catch it (it types a recognized
    // command, which caches an interpretation and skips the await, and it
    // asserts focus rather than how many QSOs exist).
    //
    // The latency here stands in for the real thing: `interpretCommand` and the
    // decorate-before-save hook are both JS-runtime round-trips, and key
    // auto-repeat (~33-90ms on macOS) fires well inside them.
    testWidgets('a second Enter during the interpret round-trip does not log the QSO twice', (tester) async {
      var interpretCalls = 0;
      Future<Map<String, dynamic>?> slowNullInterpret(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
        interpretCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return null; // a callsign is not a command — the ordinary logging path
      }

      // Latency on the save path too, and this half is essential: without it
      // the first Enter finishes and `_wipe`s the field before the second
      // resumes, so the `_call != call` staleness check catches the duplicate
      // by accident and the test passes against the bug.
      await tester.pumpWidget(
        host(
          log: baseLog().copyWith(
            decorateQsoBeforeSave: (data, _) async {
              await Future<void>.delayed(const Duration(milliseconds: 60));
              return data;
            },
          ),
          commands: CommandHooks(interpretCommand: slowNullInterpret),
        ),
      );
      await tester.enterText(callField(), 'W1AW');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 30)); // inside the 50ms await
      await tester.testTextInput.receiveAction(TextInputAction.done);

      final logged = await qsosAfterWaiting(tester, watchFor: 2);
      expect(logged, hasLength(1), reason: 'the second Enter must not log a duplicate contact');
      // One call from the describe debounce during the pump above, then one per
      // Enter — so this pins that BOTH Enters really entered `_log` and reached
      // the await. Without it the test could pass on a second Enter that never
      // arrived, which proves nothing.
      expect(interpretCalls, 3, reason: 'both Enters must reach _log for this to be testing anything');
    });
  });

  testWidgets('an async interpretation push updates the message but never dispatches commands (issue #189)', (tester) async {
    final updates = StreamController<Map<String, dynamic>>();
    addTearDown(updates.close);
    Future<Map<String, dynamic>?> interpret(String input, [operation, qso, execute = false]) async {
      return {'describe': 'Fetching…'};
    }

    String? lastMessage;
    await tester.pumpWidget(
      host(
        commands: CommandHooks(interpretCommand: interpret, interpretationUpdates: updates.stream, onCommandMessageChanged: (message) => lastMessage = message),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SOLAR');
    await tester.pump(const Duration(milliseconds: 200)); // past the 150ms describe debounce
    expect(lastMessage, 'Fetching…');

    // The command hook's background fetch resolves and pushes the real
    // reading — same shape `host.updateInterpretation` sends across the
    // bridge (see extension_host_test.dart for that half of the contract).
    updates.add({
      'input': 'SOLAR',
      'interpretation': {'describe': 'Solar flux: 120'},
    });
    await tester.pump();
    expect(lastMessage, 'Solar flux: 120');

    // Crucially: the push only ever updates what's displayed. Only Enter
    // (interpretCommand's execute:true call) may log anything — proven here
    // by the call field still holding its typed text, since _log() is what
    // clears it.
    expect(find.widgetWithText(TextField, 'Their call'), findsOneWidget);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'SOLAR');
  });

  testWidgets('a push for an input the user has since typed past is dropped, not applied stale (issue #189)', (tester) async {
    final updates = StreamController<Map<String, dynamic>>();
    addTearDown(updates.close);
    Future<Map<String, dynamic>?> interpret(String input, [operation, qso, execute = false]) async {
      return {'describe': 'Fetching…'};
    }

    String? lastMessage;
    await tester.pumpWidget(
      host(
        commands: CommandHooks(interpretCommand: interpret, interpretationUpdates: updates.stream, onCommandMessageChanged: (message) => lastMessage = message),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SOLAR');
    await tester.pump(const Duration(milliseconds: 200));
    expect(lastMessage, 'Fetching…');

    // The user typed past SOLAR before its fetch resolved.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'SOLARX');
    await tester.pump(const Duration(milliseconds: 200));

    // A late push for the abandoned "SOLAR" input must not resurrect it.
    updates.add({
      'input': 'SOLAR',
      'interpretation': {'describe': 'Solar flux: 120'},
    });
    await tester.pump();
    expect(lastMessage, isNot('Solar flux: 120'));
  });

  testWidgets('clearing the frequency keeps the band it was last on', (tester) async {
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);

    // A frequency derives its band.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
    await tester.pump();
    expect(find.text('20m'), findsWidgets);

    // Clearing the frequency must NOT drop the band — it stays 20m.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '');
    await tester.pump();
    expect(find.text('20m'), findsWidgets);

    // Logging now records that retained band, with no frequency.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged, hasLength(1));
    expect(logged.single.band, '20m');
    expect(logged.single.freq, isNull);
  });

  testWidgets('HALO-32: a repeated mode guess does not reset the Sent/Rcvd cursor', (tester) async {
    // Regression test: the guess used to reapply unconditionally whenever
    // it was non-null, even when it equaled the current mode — and
    // TextEditingController.text's setter always collapses the selection,
    // so it force-moved the cursor in Sent/Rcvd on every such keystroke.
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);

    // Land on FT8 first (14074 kHz).
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14074');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');

    // Operator repositions the cursor in Sent without typing (so _rstsTouched
    // stays false) — e.g. clicking partway into the default RST.
    final sent = tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).controller!;
    sent.selection = const TextSelection.collapsed(offset: 0);

    // Another keystroke whose frequency is still inside the same FT8
    // segment (14074-14077) — the guess is unchanged.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14075');
    await tester.pump();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
    expect(
      sent.selection,
      const TextSelection.collapsed(offset: 0),
      reason: 'the guess did not change, so the RSTs must not have been rewritten out from under the cursor',
    );
  });

  testWidgets('HALO-32: typing a frequency guesses its mode from the band plan', (tester) async {
    await tester.pumpWidget(host()); // tunedRadio seeds Mode as SSB
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');

    // 14074 kHz is FT8 territory in the band plan.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14074');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText,
      '+0',
      reason: 'the mode guess refreshes the default report placeholder too',
    );

    // 5332 kHz (a 60m channel) is a frequency the band plan has no single
    // mode for. Both edits happen inside the same continuous session (the
    // field never settles/blurs between them), so a null guess here falls
    // back to the mode as it stood before this session started (SSB) —
    // rather than leaving it stuck on the earlier
    // FT8 guess, which would otherwise survive purely because it happened
    // to be the last edit that DID match something.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '5332');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');
  });

  testWidgets('HALO-52: knowing the operator\'s country scopes the band-plan mode guess', (tester) async {
    // 7100 kHz is US-only Data/RTTY territory (7080-7125 kHz), narrower than
    // but overlapping the generic, unscoped 40m Phone/SSB segment
    // (7060-7300 kHz) that wins when the operator's country isn't known —
    // see the un-scoped assertion below, which pins that as the pre-existing
    // (if not quite right for a US station) default.
    //
    // Both halves of the operator's scope, never just the country: a lone
    // country code is discarded (see radio.dart's `_bestSegmentFor`), and
    // the panel is fed both from one DXCC entity anyway — operation_view's
    // `ourGuess` sets `_ourItuRegion` and `_ourCountryCode` together.
    await tester.pumpWidget(host(radio: baseRadio().copyWith(ourItuRegion: 2, ourCountryCode: 'us'))); // tunedRadio seeds Mode as SSB
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7100');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'RTTY');
  });

  testWidgets('HALO-52: without a country, the same frequency falls back to the generic unscoped segment', (tester) async {
    await tester.pumpWidget(host()); // tunedRadio seeds Mode as SSB
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7100');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');
  });

  testWidgets('HALO-32: a transient mid-typing match does not strand the mode when the finished frequency has none', (tester) async {
    // Typing "18001" character by character passes through "1800" (a real
    // 160m match, guesses RTTY) before landing on "18001" itself, which
    // falls in the real gap between 160m (ends 2000) and 17m (starts
    // 18068) — modeForFrequency returns null there. The transient RTTY
    // guess must not survive; the mode must end back where it started.
    await tester.pumpWidget(host()); // tunedRadio seeds Mode as SSB
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');

    for (final prefix in ['1', '18', '180', '1800', '18001']) {
      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), prefix);
      await tester.pump();
    }

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '18001');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');
  });

  testWidgets('call-field command awaiting params (expectsParams) allows space but stays uppercase, and Enter does not execute it', (tester) async {
    Future<Map<String, dynamic>?> fakeReloadPrefix(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() == 'RELOAD') return {'expectsParams': true};
      return null;
    }

    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeReloadPrefix)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD');
    await tester.pump(const Duration(milliseconds: 200)); // let the debounced interpret() resolve

    // Space is now a literal character, not the advance-focus shortcut.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(field('Their call').controller!.text, 'RELOAD ');
    expect(field('Their call').focusNode!.hasFocus, isTrue);

    // Typed lowercase is still uppercased: expectsParams alone lifts the
    // callsign character restriction (spaces), but only a command that
    // declares `mixedCase: true` lifts the uppercase-only rule — all
    // logging input is uppercase unless explicitly mixed-case.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD pota');
    await tester.pump();
    expect(field('Their call').controller!.text, 'RELOAD POTA');

    // Enter doesn't execute or clear an incomplete command.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));
    expect(field('Their call').controller!.text, 'RELOAD POTA');
  });

  testWidgets('call-field command declaring mixedCase keeps lowercase, even once the command is complete', (tester) async {
    // Mirrors the real annotation-commands NOTE: `mixedCase: true` on BOTH
    // the bare-prefix result and the complete result. The second half is
    // what keeps "NOTE Called Bob," + more typing from being snapped back
    // to uppercase after the debounced interpret() sees a complete command.
    Future<Map<String, dynamic>?> fakeNoteCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      final match = RegExp(r'^NOTE(?:\s+(.*))?$', caseSensitive: false).firstMatch(input.trim());
      if (match == null) return null;
      final text = match.group(1)?.trim();
      if (text == null || text.isEmpty) return {'expectsParams': true, 'mixedCase': true};
      return {
        'mixedCase': true,
        'describe': 'Add note "$text"?',
        'commands': [
          {
            'updateQso': {'notes': text},
          },
        ],
      };
    }

    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeNoteCommand)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE');
    await tester.pump(const Duration(milliseconds: 200));

    // Lowercase is preserved while the command awaits its parameter.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE Called Bob');
    await tester.pump(const Duration(milliseconds: 200)); // interpret() now sees a COMPLETE command

    // Space stays literal and further lowercase still isn't uppercased —
    // the complete interpretation's mixedCase keeps the field free-text.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(field('Their call').controller!.text, 'NOTE Called Bob ');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE Called Bob on the phone');
    await tester.pump();
    expect(field('Their call').controller!.text, 'NOTE Called Bob on the phone');
  });

  testWidgets('primary State and Grid fields uppercase typed input', (tester) async {
    // A formatter, not just TextCapitalization (a soft-keyboard hint that
    // does nothing for hardware keyboards): logging values are uppercase
    // unless explicitly mixed-case.
    await tester.pumpWidget(host(prefs: LoggingPreferences(showStateField: true, showGridField: true)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'State'), 'fl');
    await tester.enterText(find.widgetWithText(TextField, 'Grid'), 'fn31pr');
    await tester.pump();
    expect(field('State').controller!.text, 'FL');
    expect(field('Grid').controller!.text, 'FN31PR');
  });

  testWidgets('Sent/Rcvd accept letter RSTs and uppercase them', (tester) async {
    // Letters are legitimate in RSTs (CW's "5NN", aurora "59A"), and the
    // Edit QSO pane accepts them — a digits-only filter here would silently
    // strip a pane-saved letter on the next inline keystroke, because
    // filtering formatters re-run over the whole text.
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5nn');
    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '59a');
    await tester.pump();
    expect(field('Sent').controller!.text, '5NN');
    expect(field('Rcvd').controller!.text, '59A');
  });

  testWidgets('abandoning a mixed-case command does not collapse the typed prose on the next keystroke', (tester) async {
    // Regression test: after "NOTE Called Bob" is edited into "NOT Called
    // Bob" (no longer a command), snapping the field straight back to
    // callsign mode would make the next keystroke re-run the callsign
    // character filter over the ENTIRE text — silently deleting every
    // space ("NOTCALLEDBOB…") with no undo. The retained free-text mode
    // must survive until the field is cleared instead.
    Future<Map<String, dynamic>?> fakeNoteCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      final match = RegExp(r'^NOTE(?:\s+(.*))?$', caseSensitive: false).firstMatch(input.trim());
      if (match == null) return null;
      final text = match.group(1)?.trim();
      if (text == null || text.isEmpty) return {'expectsParams': true, 'mixedCase': true};
      return {
        'mixedCase': true,
        'describe': 'Add note "$text"?',
        'commands': [
          {
            'updateQso': {'notes': text},
          },
        ],
      };
    }

    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeNoteCommand)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE Called Bob');
    await tester.pump(const Duration(milliseconds: 200));

    // Break the command prefix, let the debounced interpret() see it's no
    // longer a command, then keep typing.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOT Called Bob');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOT Called Bobs');
    await tester.pump();
    expect(field('Their call').controller!.text, 'NOT Called Bobs');

    // Clearing the field ends the retained free-text mode: a callsign typed
    // next is uppercased normally again.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'w1aw');
    await tester.pump();
    expect(field('Their call').controller!.text, 'W1AW');
  });

  testWidgets('populating from a suggested QSO clears a lingering command state', (tester) async {
    // Regression test: type a complete NOTE command, then tap a spot — the
    // populate path runs under the populate bracket, which suppresses
    // _onCallChanged's own per-keystroke reset, so without an explicit
    // reset the call field would show W1AW while still in the note's
    // free-prose mode, and the stale interpretation would make Space
    // insert a literal space instead of advancing focus.
    Future<Map<String, dynamic>?> fakeNoteCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      final match = RegExp(r'^NOTE(?:\s+(.*))?$', caseSensitive: false).firstMatch(input.trim());
      if (match == null) return null;
      final text = match.group(1)?.trim();
      if (text == null || text.isEmpty) return {'expectsParams': true, 'mixedCase': true};
      return {
        'mixedCase': true,
        'describe': 'Add note "$text"?',
        'commands': [
          {
            'updateQso': {'notes': text},
          },
        ],
      };
    }

    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeNoteCommand)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE hi');
    await tester.pump(const Duration(milliseconds: 200)); // complete mixedCase interpretation stored

    // Tap a spot: didUpdateWidget applies the suggestion.
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: {
            'their': {'call': 'W1AW'},
          },
        ),
        commands: CommandHooks(interpretCommand: fakeNoteCommand),
      ),
    );
    await tester.pump();
    expect(field('Their call').controller!.text, 'W1AW');

    // Space advances focus (no stale literal-space insertion)…
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(field('Their call').controller!.text, 'W1AW');
    expect(field('Sent').focusNode!.hasFocus, isTrue);

    // …and the field is back in callsign mode: lowercase gets uppercased.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'w1aw/p');
    await tester.pump();
    expect(field('Their call').controller!.text, 'W1AW/P');
  });

  testWidgets('call-field command awaiting params: space typed immediately (before the debounce resolves) is still recognized, not lost', (tester) async {
    // Regression test: _handleSpace must not trust a stale, debounce-lagged
    // _commandExpectsParams — it re-checks (or reuses an already-resolved)
    // interpretation synchronously before deciding, so a space typed right
    // after "RELOAD" in one fluent motion (no pause for the 150ms debounce)
    // still inserts a literal space instead of silently advancing focus.
    Future<Map<String, dynamic>?> fakeReloadPrefix(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() == 'RELOAD') return {'expectsParams': true};
      return null;
    }

    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeReloadPrefix)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOAD');
    // No pump/wait here — space arrives before the 150ms debounce could
    // possibly have resolved.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(field('Their call').controller!.text, 'RELOAD ');
    expect(field('Their call').focusNode!.hasFocus, isTrue);
  });

  testWidgets('call-field command parameters reach interpretCommand with their original case, not uppercased', (tester) async {
    // Regression test: the call field's own _call getter uppercases
    // everything (callsigns are case-insensitive), but that same value must
    // not leak into the argument passed to interpretCommand once a command
    // is capturing free text (e.g. NOTE's message) — otherwise lowercase
    // typed by the user is silently destroyed before the extension ever
    // sees it.
    final seenInputs = <String>[];
    Future<Map<String, dynamic>?> fakeNotePrefix(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      seenInputs.add(input);
      // mixedCase, like the real NOTE command: without it the field's own
      // uppercase formatter would destroy the lowercase before
      // interpretCommand could ever see it.
      if (input.trim().toUpperCase() == 'NOTE') return {'expectsParams': true, 'mixedCase': true};
      return null;
    }

    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeNotePrefix)));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE');
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOTE Called Bob, good signal');
    await tester.pump(const Duration(milliseconds: 200));

    expect(seenInputs, contains('NOTE Called Bob, good signal'));
  });

  testWidgets('a command action with no local widget effect (e.g. reloadDataFiles) still forwards to onCommandAction', (tester) async {
    // Regression test: _dispatchActions has an explicit per-action whitelist
    // (setVfo/updateQso/addQso/updateSettings/syncAll/setCallField/devNotice/
    // devStatus/devProgress/reloadDataFiles) — adding a new CommandAction field to the
    // SDK types without also adding its case here means the command
    // interprets fine but silently no-ops on execution, exactly what
    // happened when reloadDataFiles first shipped without this wiring.
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeReloadCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() != 'RELOADALL') return null;
      return {
        'describe': 'Reload all data files?',
        'confirm': 'Reloading all data files…',
        'commands': [
          {
            'reloadDataFiles': {'target': 'ALL'},
          },
        ],
      };
    }

    await tester.pumpWidget(
      host(
        commands: CommandHooks(
          interpretCommand: fakeReloadCommand,
          onCommandAction: (action, [params]) async {
            dispatched.add(MapEntry(action, params));
          },
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOADALL');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    // MapEntry has no value equality, so compare key/value separately
    // rather than the list of MapEntry objects directly.
    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'reloadDataFiles');
    expect(dispatched.single.value, {'target': 'ALL'});
  });

  testWidgets('a settings write from a command is the app\'s to make, like every other named action', (tester) async {
    // The trap: the panel holds no settings engine, so a command whose
    // `updateSettings` it kept for itself would write nothing and say
    // nothing — the host's own confirm text is the only feedback.
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeDevmode(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() != 'DEVMODE') return null;
      return {
        'describe': 'Developer mode on',
        'confirm': 'Developer mode on',
        'commands': [
          {
            'updateSettings': {'developerMode': true},
          },
        ],
      };
    }

    await tester.pumpWidget(
      host(
        commands: CommandHooks(
          interpretCommand: fakeDevmode,
          onCommandAction: (action, [params]) async {
            dispatched.add(MapEntry(action, params));
          },
        ),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'DEVMODE');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'updateSettings');
    expect(dispatched.single.value, {'developerMode': true});
  });

  testWidgets('devHammer forwards to onCommandAction', (tester) async {
    // The same whitelist trap as the test above. A missing branch here is
    // especially quiet for DEVHAMMER: interpretation still matches and the
    // palette still prints the extension's confirmation, so the tester is
    // told the status bar is being hammered while nothing happens at all —
    // which reads as the churn no longer provoking the bug.
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeHammerCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() != 'DEVHAMMER') return null;
      return {
        'describe': 'Churn the status bar?',
        'confirm': 'Hammering the status bar',
        'commands': [
          {
            'devHammer': {'seconds': 5},
          },
        ],
      };
    }

    await tester.pumpWidget(
      host(
        commands: CommandHooks(
          interpretCommand: fakeHammerCommand,
          onCommandAction: (action, [params]) async {
            dispatched.add(MapEntry(action, params));
          },
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'DEVHAMMER');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'devHammer');
    expect(dispatched.single.value, {'seconds': 5});
  });

  testWidgets('the settings-command actions (updateSetting/openSettings) forward to onCommandAction', (tester) async {
    // Same silent-no-op trap as the reloadDataFiles test above. SET/SHOW/HIDE
    // are especially prone to it: the describe preview is produced entirely by
    // the hook, so a missing branch here shows the operator "Change Zero Beat
    // to Off?", clears the field, prints the confirmation — and changes
    // nothing at all.
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeSettingsCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      switch (input.trim().toUpperCase()) {
        case 'SETONE':
          return {
            'describe': 'Change Zero Beat to Off?',
            'confirm': 'Zero Beat set to Off',
            'commands': [
              {
                'updateSetting': {'key': 'avoidZeroBeat', 'value': false},
              },
            ],
          };
        case 'SETTWO':
          return {
            'describe': 'Open Bands…',
            'commands': [
              {
                'openSettings': {
                  'keys': ['bands'],
                  'title': 'Bands',
                },
              },
            ],
          };
        default:
          return null;
      }
    }

    await tester.pumpWidget(
      host(
        commands: CommandHooks(
          interpretCommand: fakeSettingsCommand,
          onCommandAction: (action, [params]) async {
            dispatched.add(MapEntry(action, params));
          },
        ),
      ),
    );

    final field = find.widgetWithText(TextField, 'Their call');
    await tester.enterText(field, 'SETONE');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(field, 'SETTWO');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(2));
    expect(dispatched[0].key, 'updateSetting');
    expect(dispatched[0].value, {'key': 'avoidZeroBeat', 'value': false});
    expect(dispatched[1].key, 'openSettings');
    expect(dispatched[1].value, {
      'keys': ['bands'],
      'title': 'Bands',
    });
  });

  testWidgets('setPower (the POWER command) forwards to onCommandAction, same whitelist trap as reloadDataFiles', (tester) async {
    // Unlike setVfo it has no QSO-scoped widget state of its own to update
    // here — a missing branch would still show "Change power to 5W?" /
    // "Power set to 5W" and silently do nothing.
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakePowerCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() != '5W') return null;
      return {
        'describe': 'Change power to **5W**?',
        'confirm': 'Power set to **5W**',
        'commands': [
          {
            'setPower': {'watts': 5},
          },
        ],
      };
    }

    await tester.pumpWidget(
      host(
        commands: CommandHooks(
          interpretCommand: fakePowerCommand,
          onCommandAction: (action, [params]) async {
            dispatched.add(MapEntry(action, params));
          },
        ),
      ),
    );

    final field = find.widgetWithText(TextField, 'Their call');
    await tester.enterText(field, '5W');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'setPower');
    expect(dispatched.single.value, {'watts': 5});
  });

  testWidgets('a paramless overlay action (devTester) forwards to onCommandAction', (tester) async {
    // Same silent-no-op trap as the reloadDataFiles test above, for the
    // paramless `{devTester: {}}` shape: without its _dispatchActions
    // branch, DEVTESTER interprets fine but submitting it does nothing.
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeTesterCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() != 'DEVTESTER') return null;
      return {
        'describe': 'Show the tester-notes overlay?',
        'confirm': 'Showing the tester-notes overlay',
        'commands': [
          {'devTester': <String, dynamic>{}},
        ],
      };
    }

    await tester.pumpWidget(
      host(
        commands: CommandHooks(interpretCommand: fakeTesterCommand, onCommandAction: (action, [params]) async => dispatched.add(MapEntry(action, params))),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'DEVTESTER');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'devTester');
    expect(dispatched.single.value, isNull);
  });

  // The round submit button is the primary submit affordance on mobile (no
  // hardware keyboard). It calls the same _log() as Enter, but was gated on
  // _canLog — false for a command, which isn't a callsign — so a command could
  // previously only be run from Enter / the on-screen keyboard's return key,
  // never this button. Its icon carries no text, so it's found by its icon.
  Finder submitButton() => find.widgetWithIcon(FilledButton, MdiIcons.upload);

  testWidgets('tapping the submit button accepts a recognized command, the same as Enter', (tester) async {
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeReloadCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() != 'RELOADALL') return null;
      return {
        'describe': 'Reload all data files?',
        'confirm': 'Reloading all data files…',
        'commands': [
          {
            'reloadDataFiles': {'target': 'ALL'},
          },
        ],
      };
    }

    await tester.pumpWidget(
      host(
        commands: CommandHooks(interpretCommand: fakeReloadCommand, onCommandAction: (action, [params]) async => dispatched.add(MapEntry(action, params))),
      ),
    );

    // A plain empty field: nothing to submit, button disabled.
    expect(tester.widget<FilledButton>(submitButton()).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'RELOADALL');
    // Let the 150ms describe debounce retain the interpretation and rebuild.
    await tester.pump(const Duration(milliseconds: 200));

    // The fix: a recognized command enables the button even though it isn't a
    // callsign (so _canLog is false).
    expect(tester.widget<FilledButton>(submitButton()).onPressed, isNotNull, reason: 'a complete command must enable the submit button, not just Enter');

    // Tapping the BUTTON (not Enter) runs the command.
    await tester.tap(submitButton());
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'reloadDataFiles');
    expect(dispatched.single.value, {'target': 'ALL'});
  });

  testWidgets('the submit button stays disabled while a command still awaits its parameters', (tester) async {
    // A bare command prefix (EXP before its token) is incomplete — Enter falls
    // through and logs nothing, and the button must not offer to submit it.
    Future<Map<String, dynamic>?> fakeExpPrefix(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      final match = RegExp(r'^EXP(?:\s+(\S+))?$', caseSensitive: false).firstMatch(input.trim());
      if (match == null) return null;
      if (match.group(1) == null) return {'expectsParams': true};
      return {'describe': 'Toggle experiment ${match.group(1)}?', 'commands': const []};
    }

    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeExpPrefix)));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP');
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<FilledButton>(submitButton()).onPressed, isNull, reason: 'a bare EXP still awaiting its token has nothing to submit');

    // Completing it (a token) enables the button.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP FOO');
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<FilledButton>(submitButton()).onPressed, isNotNull);
  });

  testWidgets('a COMPLETE interpretation mid-parameter keeps spaces intact (EXP LA must not snap to EXPLA)', (tester) async {
    // Regression test: pausing after "EXP L" lets the debounce retain a
    // complete interpretation (token "L") — which used to drop the field
    // out of free-text mode, so the callsign filter rewrote the whole
    // field on the next keystroke and "EXP LA" became "EXPLA".
    Future<Map<String, dynamic>?> fakeExpCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      final match = RegExp(r'^EXP(?:\s+(\S+))?$', caseSensitive: false).firstMatch(input.trim());
      if (match == null) return null;
      final token = match.group(1);
      if (token == null) return {'expectsParams': true};
      return {
        'describe': 'Toggle experiment $token?',
        'commands': [
          {
            'toggleExperiment': {'token': token},
          },
        ],
      };
    }

    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeExpCommand)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP L');
    // The pause: debounce fires and retains the COMPLETE interpretation.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP LA');
    await tester.pump(const Duration(milliseconds: 200));

    expect(field('Their call').controller!.text, 'EXP LA');
  });

  testWidgets('toggleExperiment forwards to onCommandAction (same whitelist trap as reloadDataFiles)', (tester) async {
    final dispatched = <MapEntry<String, Map<String, dynamic>?>>[];
    Future<Map<String, dynamic>?> fakeExpCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      // Like the real EXP hook: bare prefix asks for the parameter (which
      // also switches the field into space-allowed free-text mode).
      if (input.trim().toUpperCase() == 'EXP') return {'expectsParams': true};
      if (input.trim().toUpperCase() != 'EXP LAYOUTS') return null;
      return {
        'describe': 'Toggle experiment LAYOUTS?',
        'commands': [
          {
            'toggleExperiment': {'token': 'LAYOUTS'},
          },
        ],
      };
    }

    await tester.pumpWidget(
      host(
        commands: CommandHooks(
          interpretCommand: fakeExpCommand,
          onCommandAction: (action, [params]) async {
            dispatched.add(MapEntry(action, params));
          },
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'EXP LAYOUTS');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, hasLength(1));
    expect(dispatched.single.key, 'toggleExperiment');
    expect(dispatched.single.value, {'token': 'LAYOUTS'});
  });

  testWidgets('devOnboard forwards to onCommandAction (same whitelist trap as reloadDataFiles)', (tester) async {
    // DEVONBOARD shipped interpreting fine but silently no-oping on
    // execution because _dispatchActions' whitelist lacked its branch —
    // the exact failure mode the test above documents.
    final dispatched = <String>[];
    Future<Map<String, dynamic>?> fakeDevOnboardCommand(
      String input, [
      Map<String, dynamic>? operation,
      Map<String, dynamic>? qso,
      bool execute = false,
    ]) async {
      if (input.trim().toUpperCase() != 'DEVONBOARD') return null;
      return {
        'describe': 'Show the onboarding overlay?',
        'confirm': 'Showing the onboarding overlay',
        'commands': [
          {'devOnboard': <String, dynamic>{}},
        ],
      };
    }

    await tester.pumpWidget(
      host(
        commands: CommandHooks(interpretCommand: fakeDevOnboardCommand, onCommandAction: (action, [params]) async => dispatched.add(action)),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'DEVONBOARD');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(dispatched, ['devOnboard']);
  });
}
