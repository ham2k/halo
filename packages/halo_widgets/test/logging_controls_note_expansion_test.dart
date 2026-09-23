// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Note expansion: a key typed into the call field that stands for a note,
// alone and inside a call stack.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  testWidgets('note expansion: a setCallField command replaces the call field, and the result logs as a comma list', (tester) async {
    // `//KEY` (issue #17): the call-notes extension interprets "//DAN" into
    // a setCallField action carrying that entry's comma list of calls. The
    // replaced text must then behave exactly as if typed — Enter logs one
    // QSO per call (issue #7) — because expansion's entire purpose is
    // feeding the ordinary call-list path, not a parallel one.
    Future<Map<String, dynamic>?> fakeExpandCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() != '//DAN') return null;
      return {
        'describe': 'Expand to WD4DAN,WD4JMM?',
        'commands': [
          {
            'setCallField': {'text': 'WD4DAN,WD4JMM'},
          },
        ],
      };
    }

    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeExpandCommand)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    // A leading "//" IS a stack (first segment empty), so the only thing
    // keeping this from logging DAN as a callsign is _log reaching command
    // interpretation first.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//DAN');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(field('Their call').controller!.text, 'WD4DAN,WD4JMM');
    expect(field('Their call').controller!.selection.baseOffset, 'WD4DAN,WD4JMM'.length);
    expect(field('Their call').focusNode!.hasFocus, isTrue);
    expect(await qsosAfterWaiting(tester), isEmpty, reason: 'expanding the key is not logging the contact');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 2);
    expect(logged.map((q) => q.theirCall).toSet(), {'WD4DAN', 'WD4JMM'});
  });

  group('note expansion inside a call stack', () {
    // A note key stacked alongside other calls ("KI2D//DAN") never reaches
    // command interpretation as a whole-field command — the field isn't
    // "//DAN", it's a stack. The panel asks the same hook about just the
    // segment under the cursor and splices the answer back into it, so
    // Enter expands and the NEXT Enter logs.
    Future<Map<String, dynamic>?> fakeExpandCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
      if (input.trim().toUpperCase() != '//DAN') return null;
      return {
        'describe': 'Expand to WD4DAN,WD4JMM?',
        'commands': [
          {
            'setCallField': {'text': 'WD4DAN,WD4JMM'},
          },
        ],
      };
    }

    TextField callField(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Their call'));

    testWidgets('Enter expands the segment under the cursor and logs nothing', (tester) async {
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeExpandCommand)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//DAN');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      // Only the one segment is replaced — the call already stacked ahead of
      // it survives untouched, which a whole-field setCallField would wipe.
      expect(callField(tester).controller!.text, 'KI2D//WD4DAN,WD4JMM');
      expect(await qsosAfterWaiting(tester), isEmpty, reason: 'the Enter that expanded the segment logs nothing');

      // The cursor has to land back on the expanded segment: stacking picks
      // the segment the cursor is in, so anywhere else and the next Enter
      // would log KI2D instead of what was just expanded.
      expect(callField(tester).controller!.selection.baseOffset, 'KI2D//WD4DAN,WD4JMM'.length);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 2);
      expect(logged.map((q) => q.theirCall).toList(), ['WD4DAN', 'WD4JMM']);
      expect(callField(tester).controller!.text, 'KI2D');
    });

    testWidgets('a key LEADING the stack expands too, then the rest logs', (tester) async {
      // A leading key is a stack whose first segment is empty, so it takes
      // the same mid-stack path as any other. Disqualify a leading "//" from
      // stacking and this field is neither syntax — the whole-field key reads
      // as "DAN//W1AW" and matches nothing — so Enter does nothing at all.
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeExpandCommand)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//DAN//W1AW');
      // Cursor on the key, at the end of "//DAN".
      callField(tester).controller!.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      // The empty first segment survives the splice, so the call stacked
      // behind the key is untouched and the key's own "//" is still there.
      expect(callField(tester).controller!.text, '//WD4DAN,WD4JMM//W1AW');
      expect(await qsosAfterWaiting(tester), isEmpty, reason: 'the Enter that expanded the segment logs nothing');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect((await waitForQsos(tester, 2)).map((q) => q.theirCall).toList(), ['WD4DAN', 'WD4JMM']);
      expect(callField(tester).controller!.text, '//W1AW');

      // And what is left is a bare "//W1AW" the hook declines — so it logs
      // as the callsign it looks like rather than stranding the operator.
      // Compared as a set: the comma list's own +5s stagger puts W1AW
      // between its two entries by start time, which says nothing here.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect((await waitForQsos(tester, 3)).map((q) => q.theirCall).toSet(), {'WD4DAN', 'WD4JMM', 'W1AW'});
      expect(callField(tester).controller!.text, '');
    });

    testWidgets('a whole-field key that is itself a valid callsign expands, and logs nothing', (tester) async {
      // What stops "//W1AW" being logged as the callsign it looks like is
      // ORDER — _log interprets the whole field before stacking ever runs.
      // Nothing else guards it, so move the stacking path above the command
      // path and this logs a stray QSO for a station never worked. "//DAN"
      // cannot catch that: DAN has no digit, so looksLikeCallsign rejects it
      // and stacking would decline the segment anyway.
      Future<Map<String, dynamic>?> expandsW1AW(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
        if (input.trim().toUpperCase() != '//W1AW') return null;
        return {
          'commands': [
            {
              'setCallField': {'text': 'W1AW,W1AX'},
            },
          ],
        };
      }

      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: expandsW1AW)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      expect(callField(tester).controller!.text, 'W1AW,W1AX');
      expect(await qsosAfterWaiting(tester), isEmpty, reason: 'the Enter that expanded the key logs nothing');
    });

    testWidgets('a cursor at the very start still expands the key it precedes', (tester) async {
      // Offset 0 lands on the stack's empty first segment, which has nothing
      // to expand — so unless the leading "//" is treated as a separator
      // rather than a segment, Enter here does nothing while the same Enter
      // one character right expands normally.
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeExpandCommand)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), '//DAN//W1AW');
      callField(tester).controller!.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      expect(callField(tester).controller!.text, '//WD4DAN,WD4JMM//W1AW');
      expect(await qsosAfterWaiting(tester), isEmpty, reason: 'the Enter that expanded the key logs nothing');
    });

    testWidgets('a stacked segment with no note of its own logs the ordinary way', (tester) async {
      // The expansion probe runs on every stacked Enter; when the hook
      // declines, stacking has to proceed exactly as before rather than
      // swallowing the keypress.
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeExpandCommand)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.map((q) => q.theirCall).toList(), ['W1AW']);
      expect(callField(tester).controller!.text, 'KI2D');
    });

    testWidgets('the expansion is previewed while typing, before Enter', (tester) async {
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeExpandCommand)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//DAN');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.textContaining('Expand to WD4DAN,WD4JMM?'), findsOneWidget);
    });

    testWidgets('the expanded field keeps focus, so the next Enter still knows which segment', (tester) async {
      // An unfocused field reports NO selection, and the no-selection
      // fallback is the last segment — in a three-segment stack that is a
      // different call than the one just expanded, so the second Enter would
      // log the wrong QSO entirely.
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeExpandCommand)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//DAN//W1AW');
      // Put the cursor in the middle segment, the one holding the key.
      callField(tester).controller!.selection = const TextSelection.collapsed(offset: 9);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      expect(callField(tester).controller!.text, 'KI2D//WD4DAN,WD4JMM//W1AW');
      expect(callField(tester).focusNode!.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 2);
      expect(logged.map((q) => q.theirCall).toList(), ['WD4DAN', 'WD4JMM']);
      expect(callField(tester).controller!.text, 'KI2D//W1AW');
    });

    testWidgets('nothing is asked to EXECUTE for a stacked call that expands to nothing', (tester) async {
      // The probe runs on every stacked Enter, ordinary calls included. An
      // execute-time interpretation is allowed side effects of its own (a
      // network fetch, a batch of generated QSOs), so a speculative one whose
      // answer is then thrown away is a real action nobody asked for.
      final executed = <String>[];
      Future<Map<String, dynamic>?> recording(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
        if (execute) executed.add(input.trim().toUpperCase());
        return fakeExpandCommand(input, operation, qso, execute);
      }

      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: recording)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await waitForQsos(tester, 1);
      expect(executed, isEmpty);

      // ...but a segment that DOES expand still gets the executable
      // interpretation, whose `commands` are the real ones — a hook is free
      // to leave the preview's cheap.
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//DAN');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));
      expect(executed, ['//DAN']);
    });

    testWidgets('a cursor moved while the hook answers cannot make the splice land on another segment', (tester) async {
      // The probe is a JS runtime round trip; a click or arrow key during it
      // moves the cursor without touching the text, so a staleness guard that
      // only compares text would let the answer for one segment overwrite a
      // completely different call.
      final gate = Completer<void>();
      Future<Map<String, dynamic>?> slowExpand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
        if (input.trim().toUpperCase() == '//DAN') await gate.future;
        return fakeExpandCommand(input, operation, qso, execute);
      }

      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: slowExpand)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'DAN//W1AW');
      callField(tester).controller!.selection = const TextSelection.collapsed(offset: 3); // in "DAN"
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // The operator clicks into the other segment while the hook is thinking.
      callField(tester).controller!.selection = const TextSelection.collapsed(offset: 9);
      await tester.pump();
      gate.complete();
      await tester.pump(const Duration(milliseconds: 200));

      expect(callField(tester).controller!.text, 'WD4DAN,WD4JMM//W1AW');
    });

    group('a key that is also a real callsign', () {
      // The escape hatch. A stacked segment's "//" is a separator, not the
      // operator asking to expand — so a note keyed on a real callsign would
      // otherwise capture that station forever: Enter expands, deleting what
      // the expansion added and pressing Enter expands again, and the call
      // can never be logged on its own.
      Future<Map<String, dynamic>?> expandsW1AW(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
        if (input.trim().toUpperCase() != '//W1AW') return null;
        return {
          'describe': 'Expand to W1AW,W1AX?',
          'commands': [
            {
              'setCallField': {'text': 'W1AW,W1AX'},
            },
          ],
        };
      }

      testWidgets('taking the expansion back and pressing Enter again logs the call itself', (tester) async {
        await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: expandsW1AW)));

        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 200));
        expect(callField(tester).controller!.text, 'K1ABC//W1AW,W1AX');

        // The operator deletes what the expansion added, putting the segment
        // back exactly as typed, and submits again.
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        // ...and is not offered the same expansion a second time, which
        // would contradict what Enter is now about to do.
        expect(find.textContaining('Expand to'), findsNothing);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        final logged = await qsosAfterWaiting(tester, watchFor: 2);
        expect(logged.map((q) => q.theirCall).toList(), ['W1AW'], reason: 'the second Enter logs the call itself, once');
        expect(callField(tester).controller!.text, 'K1ABC');
      });

      testWidgets('the hatch lasts only for the entry it was used on', (tester) async {
        // Spent state belongs to the draft, not the session — the next
        // contact typing the same key must get its expansion.
        await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: expandsW1AW)));

        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC//W1AW');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await waitForQsos(tester, 1);

        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'N2XYZ//W1AW');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 200));

        expect(callField(tester).controller!.text, 'N2XYZ//W1AW,W1AX');
      });
    });

    testWidgets('a repeated Enter racing the probe logs one QSO, not two', (tester) async {
      // Key auto-repeat fires well inside an extension round trip, and the
      // probe now sits between _log's entry guard and the point it commits to
      // logging — so both presses can be inside that window at once.
      final gate = Completer<void>();
      Future<Map<String, dynamic>?> slowExpand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
        if (input.trim().startsWith('//')) await gate.future;
        return null; // nothing expands — this Enter is an ordinary stacked log
      }

      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: slowExpand)));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'KI2D//W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      gate.complete();
      await tester.pump(const Duration(milliseconds: 200));

      final logged = await qsosAfterWaiting(tester, watchFor: 2);
      expect(logged.map((q) => q.theirCall).toList(), ['W1AW'], reason: 'the racing Enter must not log a second contact');
    });
  });
}
