// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The secondary control strip itself — the chips, what expanding one does to
// the cursor, and the Time and Notes controls.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_widgets/src/logging_controls_time.dart' show TimeControlModel, manualTimeChipColor;

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  group('expanding a secondary control moves the cursor into it', () {
    // Expanding a control is a statement of intent — the operator opened it to
    // type into it. Leaving focus back in the callsign field means every
    // expand costs an extra tap, and on a phone the keyboard points at the
    // wrong field. Collapsing hands the cursor back so logging continues.
    const potaControl = {
      'key': 'pota/hunter',
      'label': 'POTA',
      'icon': 'pine-tree',
      'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
    };

    Widget hostWithPota() => MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: baseLog(),
          radio: baseRadio(),
          activities: ActivityHooks(activityControls: const [potaControl]),
        ),
      ),
    );

    testWidgets('an activity ref field takes focus when its chip is tapped', (tester) async {
      await tester.pumpWidget(hostWithPota());
      await openControl(tester, MdiIcons.pineTree);

      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'POTA')).focusNode?.hasFocus,
        isTrue,
        reason: 'the ref field is what the operator opened the control to fill in',
      );
    });

    testWidgets('the Radio control focuses Frequency, not the Band dropdown', (tester) async {
      // Band and Mode are dropdowns — Frequency is the one you type into, and
      // on touch platforms the dropdowns refuse focus outright.
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.radio);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus, isTrue);
    });

    testWidgets('the Time control focuses the time field', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clockOutline);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)')).focusNode?.hasFocus, isTrue);
    });

    testWidgets('collapsing returns the cursor to the primary field it came from', (tester) async {
      await tester.pumpWidget(host());
      TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

      // Land on Rcvd rather than Call, so "went back where it came from" is
      // distinguishable from "always goes to Call".
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'test setup');

      await openControl(tester, MdiIcons.radio);
      expect(field('Frequency').focusNode!.hasFocus, isTrue);

      await openControl(tester, MdiIcons.radio); // same chip again — collapse
      expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'collapsing must resume where logging left off, not jump to Call');
    });

    testWidgets('collapsing returns to the last primary field even if the tap blurred it first', (tester) async {
      // The trap: on desktop and web a TextField's own tap-outside drops focus
      // on any tap outside it, so by the time the chip's handler runs NOTHING
      // is focused — sampling "what has focus now" reads as none and every
      // collapse would fall back to Call. The field the operator was
      // last in is what has to be remembered, not what happens to hold focus
      // at the moment of the tap.
      await tester.pumpWidget(host());
      TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(field('Sent').focusNode!.hasFocus, isTrue, reason: 'test setup');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(field('Sent').focusNode!.hasFocus, isFalse, reason: 'test setup: the tap blurred it');

      await openControl(tester, MdiIcons.radio);
      await openControl(tester, MdiIcons.radio); // collapse

      expect(field('Sent').focusNode!.hasFocus, isTrue, reason: 'must resume at Sent, not Call');
    });

    testWidgets('collapsing falls back to the call field when nothing was focused', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      // Nothing focused yet: the panel is fresh and untouched.
      await openControl(tester, MdiIcons.radio);
      await openControl(tester, MdiIcons.radio);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus, isTrue);
    });

    testWidgets('switching between two activity controls keeps each ref field working', (tester) async {
      // The expanded panel is ONE widget position, so switching chips rebuilds
      // RefTextInput with a different caller-owned focus node against a REUSED
      // State. If the field kept listening to the old node, the cursor-at-end
      // behavior would silently attach to the wrong control — and the stale
      // listener would outlive the controller it touches.
      const controls = [
        {
          'key': 'pota/hunter',
          'label': 'POTA',
          'icon': 'pine-tree',
          'input': {'kind': 'refList', 'refType': 'pota', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
        },
        {
          'key': 'sota/chaser',
          'label': 'SOTA',
          'icon': 'summit',
          'input': {'kind': 'refList', 'refType': 'sota', 'pattern': r'[A-Z0-9/]+-[0-9]{3}'},
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controls),
            ),
          ),
        ),
      );

      await openControl(tester, MdiIcons.pineTree);
      await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
      await tester.pump();

      await openControl(tester, MdiIcons.summit);
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'SOTA')).focusNode?.hasFocus,
        isTrue,
        reason: 'the second control gets focus on its own node',
      );
      await tester.enterText(find.widgetWithText(TextField, 'SOTA'), 'W1/AM-001');
      await tester.pump();

      // Back to the first: its value survived and it takes focus again.
      await openControl(tester, MdiIcons.pineTree);
      final pota = tester.widget<TextField>(find.widgetWithText(TextField, 'POTA'));
      expect(pota.controller?.text, 'US-1234');
      expect(pota.focusNode?.hasFocus, isTrue);
    });

    testWidgets('hopping between controls keeps the ORIGINAL primary field for the way back', (tester) async {
      // The second expand happens while focus is inside the first control's
      // panel — recording "nothing was focused" there would lose Rcvd.
      await tester.pumpWidget(hostWithPota());
      TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'test setup');

      await openControl(tester, MdiIcons.radio);
      await openControl(tester, MdiIcons.pineTree);
      expect(field('POTA').focusNode!.hasFocus, isTrue);

      await openControl(tester, MdiIcons.pineTree); // collapse
      expect(field('Rcvd').focusNode!.hasFocus, isTrue);
    });
  });

  group('Notes control', () {
    // Same "off until asked" rule as Power, and the same trap: a control
    // absent from a saved order is one the operator was never offered, not
    // one they turned down.
    testWidgets('stays out of the row until the saved order names it', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      expect(find.byIcon(MdiIcons.noteOutline), findsNothing);

      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'notes'])));
      await tester.pump();
      expect(find.byIcon(MdiIcons.noteOutline), findsOneWidget);
    });

    testWidgets('a note typed into the control reaches the logged QSO', (tester) async {
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'notes'])));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await openControl(tester, MdiIcons.noteOutline);
      await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'Ran 5W to a wire');
      await tester.pump();
      // Enter inside a secondary control closes it and hands the keyboard
      // back to the main fields; logging is one rung down from there.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleControl(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.data['notes'], 'Ran 5W to a wire');
    });

    testWidgets('Space types a word break instead of moving the keyboard on', (tester) async {
      // The panel binds Space panel-wide to advance the main fields. A note
      // is a sentence, so without an branch of its own here every word break
      // is swallowed and the operator types "Ran5Wtoawire".
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'notes'])));
      await tester.pump();
      await openControl(tester, MdiIcons.noteOutline);

      final notes = find.widgetWithText(TextField, 'Notes');
      await tester.enterText(notes, 'Ran');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.enterText(notes, '${tester.widget<TextField>(notes).controller!.text}5W');
      await tester.pump();

      expect(tester.widget<TextField>(notes).controller!.text, 'Ran 5W');
      expect(find.text('✓ Notes'), findsOneWidget, reason: 'the space went through the same change path as a typed character');
    });

    testWidgets('the first letter is capitalized wherever the note is typed', (tester) async {
      // textCapitalization is only a hint to an on-screen keyboard — nothing
      // on a desktop or in a browser reads it — so a formatter is what
      // actually delivers the capital. Both views of the note apply it.
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'notes'])));
      await tester.pump();
      await openControl(tester, MdiIcons.noteOutline);
      await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'ran 5W to a wire');
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Notes')).controller!.text, 'Ran 5W to a wire');

      await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Notes').last, 'second time this week');
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Notes').last).controller!.text, 'Second time this week');
    });

    testWidgets('the chip says whether this contact carries one', (tester) async {
      // The chip is the only thing on screen while the control is closed, so
      // without this an operator has no way to tell a contact with a note
      // from one without opening every control in turn.
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'notes'])));
      await tester.pump();
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('✓ Notes'), findsNothing);

      await openControl(tester, MdiIcons.noteOutline);
      await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'Old friend');
      await tester.pump();
      expect(find.text('✓ Notes'), findsOneWidget);
    });

    testWidgets("a record's own note fills the field, and wiping takes it away", (tester) async {
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'notes': 'Second time this week',
      });
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: existing),
          strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'notes']),
        ),
      );
      await tester.pump();
      await openControl(tester, MdiIcons.noteOutline);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Notes')).controller!.text, 'Second time this week');

      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'notes'])));
      await tester.pump();
      await openControl(tester, MdiIcons.noteOutline);
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Notes')).controller!.text,
        isEmpty,
        reason: 'a note belongs to the contact it was written about, not to the entry row',
      );
    });

    testWidgets('a note deleted from a logged contact stays deleted', (tester) async {
      // This map is MERGED over the record, so an omitted key leaves the
      // stored value standing — the same trap `refs`/`freq`/`band`/`power`
      // are written unconditionally to avoid. Without an active write the
      // field empties, the chip loses its ✓, the save reports success, and
      // the note is still there the next time the contact is opened.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'notes': 'Ran 5W to a wire',
      });
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: existing),
          strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'notes']),
        ),
      );
      await tester.pump();
      await openControl(tester, MdiIcons.noteOutline);

      await tester.enterText(find.widgetWithText(TextField, 'Notes'), '');
      await tester.pump();
      expect(find.text('✓ Notes'), findsNothing);
      await tester.tap(find.byType(FilledButton));

      var saved = existing;
      for (var i = 0; i < 20 && (saved.data['notes'] as String?) != ''; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        saved = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!.single;
      }
      expect(saved.data['notes'], '', reason: 'the empty string is what a deliberate clear stores — an absent key would be re-filled');
    });

    testWidgets('a contact that never had a note is not rewritten as having an empty one', (tester) async {
      // The other half: `mergeConcurrentEdit` takes what this map writes as
      // an edit, so stamping `notes: ''` on every save would let a contact
      // merely opened and re-saved overwrite a note another device added
      // while the editor sat open.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW', 'sent': '55'},
        'band': '20m',
        'mode': 'SSB',
      });
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: existing),
          strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'notes']),
        ),
      );
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '57');
      await tester.pump();
      await tester.tap(find.byType(FilledButton));

      var saved = existing;
      for (var i = 0; i < 20 && saved.data['their']['sent'] != '57'; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        saved = (await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first))!.single;
      }
      expect(saved.data['their']['sent'], '57', reason: 'the edit really did save');
      expect(saved.data.containsKey('notes'), isFalse);
    });

    testWidgets('the control and the More pane are two views of one note', (tester) async {
      // They write the same key. Without the pane pushing back into the
      // control, the chip would go on showing the old note — and the next
      // keystroke in the control would put it back on the contact.
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'notes'])));
      await tester.pump();
      await openControl(tester, MdiIcons.noteOutline);
      await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'First');
      await tester.pump();

      await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Notes').last).controller!.text, 'First');
      await tester.enterText(find.widgetWithText(TextField, 'Notes').last, 'Second');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Notes')).controller!.text, 'Second');
      expect(find.text('✓ Notes'), findsOneWidget);
    });
  });

  group('secondary control row', () {
    testWidgets('Time and Radio chips show by default; tapping expands, tapping again collapses', (tester) async {
      await tester.pumpWidget(host());

      expect(find.byIcon(MdiIcons.clockOutline), findsOneWidget);
      expect(find.byIcon(MdiIcons.radio), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);

      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
    });

    testWidgets('selecting a different control collapses the previous one', (tester) async {
      await tester.pumpWidget(host());

      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      await openControl(tester, MdiIcons.clockOutline);
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);
    });

    testWidgets('a successful command applies the change without opening the Radio control', (tester) async {
      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeInterpretCommand)));
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), '14285');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      // The command's frequency took effect (reflected in the still-closed
      // chip's summary text)...
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
      expect(find.text('14,285 • SSB'), findsOneWidget);

      // ...but the Radio control itself was not force-opened by it.
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14285');
    });

    // A manual time that can never read as the wall clock: with a hard-coded
    // literal, `isNot(literal)` fails for the one minute a day when real UTC
    // happens to be exactly that, and enterText of the literal is a no-op
    // (no override fires) when the reseeded field already holds it.
    final manualDt = DateTime.now().toUtc().add(const Duration(hours: 6));
    final manualTime = '${manualDt.hour.toString().padLeft(2, '0')}:${manualDt.minute.toString().padLeft(2, '0')}';

    testWidgets('a typed time stamps the contact, and the next one follows it rather than the clock', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clockOutline);

      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), manualTime);
      await tester.enterText(find.widgetWithText(TextField, 'Date'), '2026-01-02');
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      final stamped = DateTime.utc(2026, 1, 2, manualDt.hour, manualDt.minute);
      expect(DateTime.fromMillisecondsSinceEpoch(logged.single.startAtMillis!, isUtc: true), stamped);

      // Still manual after the log, one default increment on.
      await openControl(tester, MdiIcons.pause);
      final next = stamped.add(ManualTimeHooks.defaultIncrement);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)')).controller!.text, TimeControlModel.fmtTime(next));
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Date')).controller!.text, TimeControlModel.fmtDate(next));
    });

    testWidgets('Return to now clears a manual time', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clockOutline);

      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), manualTime);
      await tester.pump();
      expect(find.byIcon(MdiIcons.pause), findsOneWidget, reason: 'the chip says the clock is stopped');

      await tester.tap(find.byKey(const ValueKey('returnToNowButton')));
      await tester.pump();

      final timeField = tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)'));
      expect(timeField.controller!.text, isNot(manualTime));
      expect(find.byIcon(MdiIcons.clockOutline), findsOneWidget);
    });

    testWidgets('Return to now actually restores automatic timestamping — the reseed must not re-freeze it', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clockOutline);

      // A date that can never be "today", so Return to now's reseed always rewrites the
      // field text — which used to re-fire the manual-override listener and
      // silently re-freeze the clock the button had just released.
      await tester.enterText(find.widgetWithText(TextField, 'Date'), '2020-01-02');
      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), '03:15');
      await tester.pump();
      expect(find.byKey(const ValueKey('returnToNowButton')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('returnToNowButton')));
      await tester.pump();

      // Return to now's visibility mirrors the override itself — gone means cleared.
      expect(find.byKey(const ValueKey('returnToNowButton')), findsNothing);
    });

    testWidgets('saving the More pane without editing date/time keeps automatic timestamping', (tester) async {
      await tester.pumpWidget(host());

      await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // The dialog merely displayed the live clock; saving it untouched must
      // not convert that snapshot into a manual override.
      await openControl(tester, MdiIcons.clockOutline);
      expect(find.byKey(const ValueKey('returnToNowButton')), findsNothing);
    });

    ChoiceChip timeChip(WidgetTester tester) =>
        tester.widget<ChoiceChip>(find.ancestor(of: find.byIcon(MdiIcons.clockOutline), matching: find.byType(ChoiceChip)));

    testWidgets('Time chip shows a live clock, not a static "now" label', (tester) async {
      await tester.pumpWidget(host());

      // A live label is wrapped in OncePerSecond (the shared wall-clock
      // heartbeat) instead of being a plain static Text — that wrapper is
      // what makes it a clock rather than a snapshot.
      expect(timeChip(tester).label, isA<OncePerSecond>());

      String summary() => tester.widget<Text>(find.descendant(of: find.byWidget(timeChip(tester).label), matching: find.byType(Text))).data!;

      // HH:MM:SSz — a real clock, matching app-polo's "17:06:49z" reference.
      // (Not asserting the value changes across a pump: DateTime.now() reads
      // the real wall clock, which FakeAsync's virtual time in tests doesn't
      // advance — only Timer scheduling is virtualized. The Timer firing
      // safely, repeatedly, without error is what's actually verifiable
      // here; genuine tick-to-tick change is exercised by hand on-device.)
      expect(summary(), matches(RegExp(r'^\d{2}:\d{2}:\d{2}z$')));
      await tester.pump(const Duration(seconds: 2));
      expect(summary(), matches(RegExp(r'^\d{2}:\d{2}:\d{2}z$')));
    });

    testWidgets('Return to now stays hidden until a manual time override is actually set', (tester) async {
      await tester.pumpWidget(host());
      await openControl(tester, MdiIcons.clockOutline);

      expect(find.byKey(const ValueKey('returnToNowButton')), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), manualTime);
      await tester.pump();

      expect(find.byKey(const ValueKey('returnToNowButton')), findsOneWidget);
    });

    testWidgets('editing an existing QSO shows its recorded time and never offers Return to now', (tester) async {
      final existingQso = Qso(
        uuid: 'existing-uuid',
        operationUuid: operation.uuid,
        data: {
          'their': {'call': 'W1AW'},
          'startAtMillis': DateTime.utc(2020, 3, 4, 12, 30).millisecondsSinceEpoch,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(editingQso: existingQso),
              radio: baseRadio(),
            ),
          ),
        ),
      );

      // Shows the existing QSO's own time — static, not a live clock, with
      // an explicit :00 seconds since the stored value has none.
      expect((timeChip(tester).label as Text).data, '12:30:00z');
      await tester.pump(const Duration(seconds: 2));
      expect((timeChip(tester).label as Text).data, '12:30:00z');

      await openControl(tester, MdiIcons.clockOutline);
      final timeField = tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)'));
      expect(timeField.controller!.text, '12:30');
      expect(find.byKey(const ValueKey('returnToNowButton')), findsNothing);

      // Even after editing away from the original recorded time, Return to now never
      // appears — there's no "automatic" to reset a historical entry to.
      await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), '05:00');
      await tester.pump();
      expect(find.byKey(const ValueKey('returnToNowButton')), findsNothing);
    });

    group('manual time entry', () {
      final pausedAt = DateTime.utc(2024, 5, 6, 7, 8).millisecondsSinceEpoch;
      const minute = 60000;

      /// A panel resumed in manual time entry, recording what it stores.
      Future<List<int?>> hostPaused(WidgetTester tester, {Duration increment = ManualTimeHooks.defaultIncrement, List<Duration>? increments}) async {
        final stored = <int?>[];
        await tester.pumpWidget(
          host(
            manualTime: ManualTimeHooks(startAtMillis: pausedAt, onChanged: stored.add, increment: increment, onIncrementChanged: increments?.add),
          ),
        );
        return stored;
      }

      ChoiceChip pausedChip(WidgetTester tester) =>
          tester.widget<ChoiceChip>(find.ancestor(of: find.byIcon(MdiIcons.pause), matching: find.byType(ChoiceChip)));

      testWidgets('an operation resumed in it stamps its time, shows a stopped clock, and moves on once per Enter', (tester) async {
        final stored = await hostPaused(tester, increment: const Duration(minutes: 5));
        // Static, not a live clock: a ticking label here would say the
        // contact is stamped with the time it is logged.
        expect(pausedChip(tester).label, isA<Text>());
        expect((pausedChip(tester).label as Text).data, '07:08:00z');
        expect(pausedChip(tester).backgroundColor, manualTimeChipColor);

        // A list is one moment: its calls keep their usual spacing, and the
        // clock moves on once, from the first.
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW,K1ABC');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        final logged = [...await waitForQsos(tester, 2)]..sort((a, b) => a.startAtMillis!.compareTo(b.startAtMillis!));
        expect(logged.first.startAtMillis, pausedAt);
        expect(stored, [pausedAt + 5 * minute]);
        expect((pausedChip(tester).label as Text).data, '07:13:00z', reason: 'the wipe after a log is not the operator leaving manual time entry');
      });

      testWidgets('an increment of None stamps the next contact with the same time', (tester) async {
        final stored = await hostPaused(tester, increment: Duration.zero);
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await waitForQsos(tester, 1);
        expect(stored, isEmpty, reason: 'nothing moved, so nothing is stored');
        expect((pausedChip(tester).label as Text).data, '07:08:00z');
      });

      testWidgets('the operator\'s wipe leaves it, and undoing the wipe goes back into it', (tester) async {
        final stored = await hostPaused(tester);
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
        await tester.pump();

        await tester.tap(find.byIcon(MdiIcons.backspaceOutline));
        await tester.pump();
        expect(stored, [null]);
        expect(find.byIcon(MdiIcons.pause), findsNothing);
        expect(find.byIcon(MdiIcons.clockOutline), findsOneWidget);

        await tester.tap(find.byIcon(MdiIcons.undo));
        await tester.pump();
        expect(stored, [null, pausedAt]);
        expect((pausedChip(tester).label as Text).data, '07:08:00z');

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        final logged = await waitForQsos(tester, 1);
        expect(logged.single.startAtMillis, pausedAt);
        expect(stored, [null, pausedAt, pausedAt + minute]);
      });

      testWidgets('editing an existing QSO shows its own time, and coming back resumes manual time entry', (tester) async {
        final existing = Qso(
          uuid: 'existing-uuid',
          operationUuid: operation.uuid,
          data: {
            'their': {'call': 'W1AW'},
            'startAtMillis': DateTime.utc(2020, 3, 4, 12, 30).millisecondsSinceEpoch,
          },
        );
        final stored = <int?>[];
        final manualTime = ManualTimeHooks(startAtMillis: pausedAt, onChanged: stored.add);
        await tester.pumpWidget(
          host(
            manualTime: manualTime,
            session: LoggingSession(editingQso: existing),
          ),
        );
        expect(find.byIcon(MdiIcons.pause), findsNothing);

        // A time typed for an existing contact is that contact's.
        await openControl(tester, MdiIcons.clockOutline);
        await tester.enterText(find.widgetWithText(TextField, 'Time (UTC)'), '05:00');
        await tester.pump();
        expect(stored, isEmpty);

        await tester.pumpWidget(host(manualTime: manualTime));
        expect((pausedChip(tester).label as Text).data, '07:08:00z');
      });

      testWidgets('its settings button opens the increment choices, and a pick is stored at once', (tester) async {
        final increments = <Duration>[];
        await hostPaused(tester, increments: increments);
        await openControl(tester, MdiIcons.pause);
        await tester.tap(find.byKey(const ValueKey('manualTimeSettingsButton')));
        await tester.pumpAndSettle();

        expect(find.text('Increment per QSO'), findsOneWidget);
        for (final label in ['None', '1 minute', '2 minutes', '5 minutes', '10 minutes']) {
          expect(find.widgetWithText(RadioListTile<Duration>, label), findsOneWidget);
        }
        await tester.tap(find.widgetWithText(RadioListTile<Duration>, '5 minutes'));
        await tester.pump();
        expect(increments, [const Duration(minutes: 5)]);
      });

      testWidgets('the settings button is not offered on a live clock', (tester) async {
        await tester.pumpWidget(host(manualTime: ManualTimeHooks(onIncrementChanged: (_) {})));
        await openControl(tester, MdiIcons.clockOutline);
        expect(find.byKey(const ValueKey('manualTimeSettingsButton')), findsNothing);
      });

      testWidgets('a time command typed into the call field sets the time instead of logging', (tester) async {
        final stored = <int?>[];
        Future<Map<String, dynamic>?> interpret(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async =>
            input == '12:33'
            ? {
                'describe': 'Set the time to 12:33z?',
                'commands': [
                  {
                    'setTime': {'hour': 12, 'minute': 33},
                  },
                ],
              }
            : null;
        await tester.pumpWidget(
          host(
            manualTime: ManualTimeHooks(startAtMillis: pausedAt, onChanged: stored.add),
            commands: CommandHooks(interpretCommand: interpret),
          ),
        );
        // The colon has to survive the call field's character filter.
        await tester.enterText(find.widgetWithText(TextField, 'Their call'), '12:33');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(stored, [DateTime.utc(2024, 5, 6, 12, 33).millisecondsSinceEpoch]);
        expect((pausedChip(tester).label as Text).data, '12:33:00z');
        expect(await qsosAfterWaiting(tester), isEmpty);
      });

      testWidgets('a deep link\'s time stamps that one contact without entering manual time entry', (tester) async {
        final stored = <int?>[];
        final linkedAt = DateTime.utc(2024, 1, 1, 1, 1).millisecondsSinceEpoch;
        await tester.pumpWidget(
          host(
            manualTime: ManualTimeHooks(onChanged: stored.add),
            session: LoggingSession(
              suggestedQso: {
                'their': {'call': 'W1AW'},
                'freq': 14285,
                'mode': 'SSB',
                'startAtMillis': linkedAt,
              },
            ),
          ),
        );
        expect(find.byIcon(MdiIcons.pause), findsNothing);
        await tester.showKeyboard(find.widgetWithText(TextField, 'Their call'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        final logged = await waitForQsos(tester, 1);
        expect(logged.single.startAtMillis, linkedAt);
        expect(stored, isEmpty);
      });
    });

    testWidgets('activity control chip has no border, before or after a ref is entered', (tester) async {
      const controls = [
        {
          'key': 'pota/hunter',
          'label': 'POTA',
          'icon': 'pine-tree',
          'input': {'kind': 'refList', 'refType': 'pota', 'placeholder': 'US-1234', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: controls),
            ),
          ),
        ),
      );

      ChoiceChip potaChip() => tester.widget<ChoiceChip>(find.ancestor(of: find.byIcon(MdiIcons.pineTree), matching: find.byType(ChoiceChip)));
      expect(potaChip().side, BorderSide.none);

      await openControl(tester, MdiIcons.pineTree);
      await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(potaChip().side, BorderSide.none);
    });

    testWidgets('chips match app-polo LoggerChip styling: tertiary family, rounded rectangle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHaLoTheme(Brightness.light),
          home: Scaffold(
            body: LoggingControls(log: baseLog(), radio: baseRadio()),
          ),
        ),
      );

      final chip = tester.widget<ChoiceChip>(find.ancestor(of: find.byIcon(MdiIcons.radio), matching: find.byType(ChoiceChip)));
      expect(chip.backgroundColor, HaLoColors.light.tertiaryLight);
      expect(chip.selectedColor, const Color(0xFF964900)); // colorScheme.tertiary
      expect(chip.shape, isA<RoundedRectangleBorder>());
      expect((chip.shape as RoundedRectangleBorder).borderRadius, BorderRadius.circular(8));

      // The whole panel — not just the chips — carries the tertiary tint.
      // (ChoiceChip has its own internal Material for ink effects, so we
      // match by fill color instead of "closest Material ancestor.")
      expect(find.byWidgetPredicate((w) => w is Material && w.color == const Color(0xFFFFDCC6)), findsOneWidget);
    });

    // A pill that looks exactly like every other one is how a contact gets
    // logged with no band at all. The error pair keeps the same
    // closed/open contrast the tertiary pair has, so the alert can't be
    // mistaken for the chip being expanded.
    testWidgets('the Radio chip fills with the error pair when there is no band', (tester) async {
      final untuned = FakeVfoStore()..setVfo('vfoA', mode: 'SSB');
      final theme = buildHaLoTheme(Brightness.light);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: RadioHookup(radioService: untuned),
            ),
          ),
        ),
      );

      final chip = tester.widget<ChoiceChip>(find.ancestor(of: find.byIcon(MdiIcons.radio), matching: find.byType(ChoiceChip)));
      expect(chip.backgroundColor, theme.colorScheme.errorContainer);
      expect(chip.selectedColor, theme.colorScheme.error);
    });

    testWidgets('a frequency outside every ham band alerts the Radio chip too', (tester) async {
      // Tuned, and to a real number — but 5000 kHz is WWV, not an amateur
      // allocation. A chip that only checks "is there a frequency" passes
      // this one straight through.
      expect(bandForFrequency(5000), isNull, reason: 'fixture assumes 5000 kHz is not a ham band');
      final offBand = FakeVfoStore()..setVfo('vfoA', freq: 5000, mode: 'SSB');
      final theme = buildHaLoTheme(Brightness.light);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: RadioHookup(radioService: offBand),
            ),
          ),
        ),
      );

      final chip = tester.widget<ChoiceChip>(find.ancestor(of: find.byIcon(MdiIcons.radio), matching: find.byType(ChoiceChip)));
      expect(chip.backgroundColor, theme.colorScheme.errorContainer);
    });

    testWidgets('a frequency the operator\'s own region does not allocate alerts and reads OOB', (tester) async {
      // 7250 kHz IS a band ('40m'), which is the whole trap: a check that
      // only asks "does this frequency name a band" waves through a Region
      // 1 operator transmitting where they legally cannot.
      expect(bandForFrequency(7250), '40m', reason: 'fixture assumes 7250 kHz names a band');
      final theme = buildHaLoTheme(Brightness.light);
      Widget panel(int ituRegion) => MaterialApp(
        theme: theme,
        home: Scaffold(
          body: LoggingControls(
            log: baseLog(),
            radio: RadioHookup(
              radioService: FakeVfoStore()..setVfo('vfoA', freq: 7250, mode: 'SSB'),
              ourItuRegion: ituRegion,
            ),
          ),
        ),
      );
      ChoiceChip radioChip() => tester.widget<ChoiceChip>(find.ancestor(of: find.byIcon(MdiIcons.radio), matching: find.byType(ChoiceChip)));

      await tester.pumpWidget(panel(1));
      expect(radioChip().backgroundColor, theme.colorScheme.errorContainer);
      expect(find.text('${fmtFreq(7250)} • OOB'), findsOneWidget);

      // The same frequency for a Region 2 operator is an ordinary phone
      // QSO — the alert is about where the operator is, not the number.
      await tester.pumpWidget(panel(2));
      expect(radioChip().backgroundColor, HaLoColors.light.tertiaryLight);
      expect(find.text('${fmtFreq(7250)} • SSB'), findsOneWidget);
    });

    testWidgets('out of band shows in the pill only — never as the mode', (tester) async {
      // The pill's OOB is a warning, not a mode: it must not reach the Mode
      // field (which is what gets logged) nor the Mode menu's options.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: RadioHookup(radioService: FakeVfoStore()..setVfo('vfoA', freq: 14074, mode: 'SSB'), ourItuRegion: 1),
            ),
          ),
        ),
      );
      await openControl(tester, MdiIcons.radio);

      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7250');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text,
        'SSB',
        reason: 'the out-of-band marker is not a mode guess — the mode stays where it was',
      );
      expect(
        find.text('${fmtFreq(7250)} • OOB'),
        findsOneWidget,
        reason:
            'the warning lands on the keystroke — an out-of-band frequency guesses no mode, '
            'so nothing about the mode changes to trigger the rebuild that paints it',
      );

      await tester.tap(find.widgetWithText(TextField, 'Mode'));
      await tester.pumpAndSettle();
      expect(find.text('OOB'), findsNothing, reason: 'the open Mode menu must not offer OOB as an option');
    });
  });
}
