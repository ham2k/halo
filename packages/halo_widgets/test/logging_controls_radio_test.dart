// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The panel's Radio control and everything the rig drives: seeding from the
// VFO, following a connected radio, the Band and Mode dropdowns, the reports
// a mode implies, Power, and the sideband a frequency resolves to.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  testWidgets('the Radio control has no Station Configuration button when nothing can open one', (tester) async {
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);
    expect(find.byKey(const ValueKey('stationConfigButton')), findsNothing);
  });

  testWidgets('tapping the radio name opens Station Configuration too, unless there is none to show', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);
    expect(find.text('Icom IC-705'), findsNothing);

    var opened = false;
    await tester.pumpWidget(host(
      radio: baseRadio(
        ).copyWith(hasConfiguredRadio: true,
        radioName: 'Icom IC-705',
        onOpenStationConfig: () => opened = true,
      ),
    ));
    expect(find.text('Icom IC-705'), findsOneWidget);
    await tester.tap(find.text('Icom IC-705'));
    expect(opened, isTrue);
  });

  testWidgets('a long radio name is capped at 3x the icon width and ellipsized, not wrapped', (tester) async {
    await tester.pumpWidget(host(
      radio: baseRadio(
        ).copyWith(hasConfiguredRadio: true,
        radioName: 'A Radio With A Genuinely Absurd Amount Of Name',
        onOpenStationConfig: () {},
      ),
    ));
    await openControl(tester, MdiIcons.cat);

    final icon = tester.widget<Icon>(find.descendant(
      of: find.byKey(const ValueKey('stationConfigButton')),
      matching: find.byIcon(MdiIcons.cat),
    ));
    final constrained = tester.widget<ConstrainedBox>(find.descendant(
      of: find.byKey(const ValueKey('stationConfigButton')),
      matching: find.byType(ConstrainedBox),
    ));
    expect(constrained.constraints.maxWidth, icon.size! * 3);

    final text = tester.widget<Text>(find.descendant(
      of: find.byKey(const ValueKey('stationConfigButton')),
      matching: find.byType(Text),
    ));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
  });

  testWidgets('the Station Configuration button can never become a Tab stop', (tester) async {
    // It's a supplementary action, not one of Radio's Band/Frequency/Mode
    // fields (docs/design/logging-fields.md names exactly those three,
    // the full set _expandedFieldOrderFor('radio') knows about). If this
    // button could take keyboard focus (InkWell's own default), Tab
    // pressed from it would find no match in that list — currentIndex -1
    // — and _stepSecondaryField's `next = -1 + 1 = 0` would jump BACKWARD
    // to Band instead of leaving the control the way Tab is meant to once
    // its own fields are exhausted.
    await tester.pumpWidget(host(radio: baseRadio().copyWith(hasConfiguredRadio: true, onOpenStationConfig: () {})));
    await openControl(tester, MdiIcons.cat);

    final inkWell = tester.widget<InkWell>(find.byKey(const ValueKey('stationConfigButton')));
    expect(inkWell.canRequestFocus, isFalse);
  });

  Color stationConfigButtonColor(WidgetTester tester) {
    final icon = tester.widget<Icon>(find.descendant(
      of: find.byKey(const ValueKey('stationConfigButton')),
      matching: find.byIcon(MdiIcons.cat),
    ));
    return icon.color!;
  }

  testWidgets('Station Configuration button colors: unconfigured, configured, connected', (tester) async {
    final theme = ThemeData(useMaterial3: true);

    // No radio configured — a lighter tint of the row's own background,
    // barely there. The button still opens the dialog (that's where an
    // operator with nothing configured yet would go to add one).
    var opened = false;
    await tester.pumpWidget(host(
      appTheme: theme,
      radio: baseRadio().copyWith(onOpenStationConfig: () => opened = true),
    ));
    await openControl(tester, MdiIcons.radio);
    expect(stationConfigButtonColor(tester), Color.lerp(theme.colorScheme.tertiary, Colors.white, 0.4));
    await tester.tap(find.byKey(const ValueKey('stationConfigButton')));
    expect(opened, isTrue);

    // Still expanded — State survives a same-shaped pumpWidget. Configured
    // but not connected now reads red — lighter than the scheme's own error
    // color, which reads under 3:1 against this row's dark amber `tertiary`
    // fill (the accent color, not a pastel container).
    await tester.pumpWidget(host(
      appTheme: theme,
      radio: baseRadio().copyWith(hasConfiguredRadio: true, onOpenStationConfig: () {}),
    ));
    expect(stationConfigButtonColor(tester), const Color(0xFFFF8A80));

    // Connected — a lighter green than _noticePill's, same contrast reasoning.
    await tester.pumpWidget(
        host(
          appTheme: theme,
          radio: baseRadio().copyWith(hasConfiguredRadio: true, radioConnected: true, onOpenStationConfig: () {}),
        ));
    expect(stationConfigButtonColor(tester), const Color(0xFF81C784));
  });

  // The same `iconColor` renders on two different fills (colorScheme
  // .tertiary when selected/expanded, the lighter HaLoColors.tertiaryLight
  // otherwise) — which one is actually darker flips between light and dark
  // mode, so the color has to flip with `selected`, not just with the theme.
  Color pillIconColor(WidgetTester tester) => (tester
          .widget<ChoiceChip>(find.ancestor(of: find.byIcon(MdiIcons.cat), matching: find.byType(ChoiceChip)))
          .avatar as Icon)
      .color!;

  testWidgets('the Radio pill icon color flips between selected and unselected: light mode', (tester) async {
    final theme = ThemeData(useMaterial3: true);
    await tester.pumpWidget(host(
      appTheme: theme,
      radio: baseRadio().copyWith(hasConfiguredRadio: true, onOpenStationConfig: () {}),
    ));
    expect(pillIconColor(tester), const Color(0xFFB71C1C)); // unselected: on the bright tan fill
    await openControl(tester, MdiIcons.cat);
    expect(pillIconColor(tester), const Color(0xFFFF8A80)); // selected: on the dark tertiary fill
  });

  testWidgets('the Radio pill icon color flips between selected and unselected: dark mode', (tester) async {
    final theme = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    await tester.pumpWidget(host(
      appTheme: theme,
      radio: baseRadio().copyWith(hasConfiguredRadio: true, onOpenStationConfig: () {}),
    ));
    expect(pillIconColor(tester), const Color(0xFFFF8A80)); // unselected: on the near-black fill
    await openControl(tester, MdiIcons.cat);
    // A LITERAL, deliberately, where the sibling states could each name a
    // scheme role: dark mode's own `colorScheme.error` is a pale #F79797 that
    // reads at 1.23:1 on the amber this branch actually paints on in the app,
    // so an assertion phrased as `theme.colorScheme.error` would follow the
    // scheme straight back to the invisible value this pins away from.
    expect(pillIconColor(tester), const Color(0xFFA00000)); // selected: on the light amber fill
  });

  testWidgets('a connected radio is its own color in dark mode, not the shared positiveGreen', (tester) async {
    final theme = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    await tester.pumpWidget(
        host(
          appTheme: theme,
          radio: baseRadio().copyWith(hasConfiguredRadio: true, radioConnected: true, onOpenStationConfig: () {}),
        ));
    await openControl(tester, MdiIcons.cat);
    // The cell an operator actually sits in — rig connected, Radio control
    // open — and the one that reaches for a SHARED constant most naturally.
    // [positiveGreen] is tuned for its own dark fills and reads 1.97:1 on the
    // amber this cell paints on, so taking it here would be invisible and
    // would look like reuse rather than a mistake.
    expect(pillIconColor(tester), const Color(0xFF005A00));
  });

  testWidgets('the Station Configuration button is disabled while editing an existing QSO', (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'startAtMillis': 1000000,
          'freq': 7100,
          'mode': 'SSB',
        })))!;
    await tester.pumpWidget(host(
      session: LoggingSession(editingQso: existingQso),
      radio: baseRadio().copyWith(hasConfiguredRadio: true, radioConnected: true, onOpenStationConfig: () {}),
    ));
    await openControl(tester, MdiIcons.cat);

    final button = tester.widget<InkWell>(find.byKey(const ValueKey('stationConfigButton')));
    expect(button.onTap, isNull);
  });

  testWidgets('seeds the Radio control from radioService.vfoA for a new QSO', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
    final freqField = tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency'));
    expect(freqField.controller!.text, '14285');
    expect(find.text('20m'), findsWidgets);
  });

  // ---- A contact needs a band or a frequency (HALO-24).
  //
  // On a fresh install nothing has ever set either, so the stored VFO is
  // empty — `fakeRadio` here, as opposed to the `tunedRadio` the rest of this
  // file gets by default. Submitting then used to write a QSO with both null,
  // which the ADIF exporter emits carrying neither BAND nor FREQ, and LoTW,
  // QRZ and POTA all reject.
  //
  // Each of these asserts the QSO count, not just the message: an assertion
  // on the message alone passes against the bug, because the bug is that the
  // contact gets *written*.
  group('logging requires a band or a frequency', () {
    /// Types [call] and submits it through the path the engine actually uses
    /// (see the "real submit path" group — `sendKeyEvent` bypasses the
    /// editing session, and here that difference doesn't matter, but staying
    /// on the real path keeps these honest).
    Future<void> submit(WidgetTester tester, String call) async {
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), call);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400));
    }

    /// An unset VFO pops the Radio control open on mount (asserted below), and
    /// Enter inside an open control closes it instead of logging. So every
    /// test of the *log-time* guard has to collapse it first — otherwise the
    /// submit is swallowed by the control, no contact is written for a reason
    /// that has nothing to do with the guard, and the test passes against
    /// code with the guard removed.
    Future<void> dismissRadioControl(WidgetTester tester) async {
      // The auto-open runs in a post-frame callback, so it takes one more
      // frame than `pumpWidget` alone gives it. The label is read through `t`
      // so the helper serves the Spanish-locale tests too.
      await tester.pump();
      expect(find.widgetWithText(TextField, t.loggingControls.frequency), findsOneWidget,
          reason: 'an unset VFO should have opened the Radio control on mount');
      await openControl(tester, MdiIcons.radio); // same chip again — collapse
      expect(find.widgetWithText(TextField, t.loggingControls.frequency), findsNothing);
    }

    // The proactive half: the operator is shown the fields that need
    // answering, rather than finding out at log time.
    testWidgets('an unset VFO opens the Radio control on its own, without being asked', (tester) async {
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
    });

    testWidgets('a VFO that already has a band and mode is left alone', (tester) async {
      fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing,
          reason: 'nothing is missing, so nothing should pop open');
    });

    testWidgets('the refusal speaks the operator\'s language', (tester) async {
      // Every other assertion on this message is English, which a hardcoded
      // literal would satisfy — this one is what fails if the refusal stops
      // reading the strings package.
      await useSpanish(tester);
      final messages = <String?>[];
      await tester.pumpWidget(host(
        radio: baseRadio().copyWith(radioService: fakeRadio),
        commands: CommandHooks(onCommandMessageChanged: messages.add),
      ));
      await dismissRadioControl(tester);
      await tester.enterText(find.widgetWithText(TextField, t.loggingControls.theirCall), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 300));
      expect(messages.last, 'Define una frecuencia o banda antes de registrar');
    });

    testWidgets('refuses the contact, says so, and opens the Radio control to ask', (tester) async {
      final messages = <String?>[];
      await tester.pumpWidget(host(
        radio: baseRadio().copyWith(radioService: fakeRadio),
        commands: CommandHooks(onCommandMessageChanged: messages.add),
      ));
      await dismissRadioControl(tester);

      await submit(tester, 'W1AW');

      expect(await qsosAfterWaiting(tester), isEmpty, reason: 'the contact must not be written');
      expect(messages.last, 'Set a frequency or band before logging');
      // …and it is actually on screen, in the information area where a
      // command's error goes — not merely handed to a callback nobody has to
      // wire up (nothing in the app passes `onCommandMessageChanged` today).
      expect(find.textContaining('Set a frequency or band before logging'), findsOneWidget);
      // The Radio control is open on its frequency field — the operator can
      // answer the question without reaching for the pointer.
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus,
        isTrue,
      );
      // The typed callsign survives, so answering and logging is one step.
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');
    });

    testWidgets('a frequency lets the same contact through', (tester) async {
      fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));

      await submit(tester, 'W1AW');

      final logged = await waitForQsos(tester, 1);
      expect(logged, hasLength(1));
      expect(logged.single.freq, 14285);
      expect(logged.single.band, '20m');
    });

    // Band-OR-frequency, not frequency-only: a band picked by hand (or by a
    // "40M" command, which clears the frequency) is a complete answer.
    testWidgets('a band with no frequency lets it through too', (tester) async {
      fakeRadio.setVfo('vfoA', band: '40m', mode: 'SSB');
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));

      await submit(tester, 'W1AW');

      final logged = await waitForQsos(tester, 1);
      expect(logged, hasLength(1));
      expect(logged.single.band, '40m');
      expect(logged.single.freq, isNull);
    });

    // The guard sits above the stacked-call branch, which commits a QSO of
    // its own without ever reaching the ordinary path below it.
    testWidgets('call stacking is covered too, not just the ordinary path', (tester) async {
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
      await dismissRadioControl(tester);

      await submit(tester, 'K1ABC//W1AW');

      expect(await qsosAfterWaiting(tester), isEmpty, reason: 'a stacked call with no band is refused like any other');
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
    });

    // …and a comma-separated list, which commits several at once.
    testWidgets('a comma-separated list is covered too', (tester) async {
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
      await dismissRadioControl(tester);

      await submit(tester, 'K1ABC, W1AW');

      expect(await qsosAfterWaiting(tester), isEmpty, reason: 'not one call of the list is written without a band');
    });

    testWidgets('saving an edit of a bandless contact is refused as well', (tester) async {
      final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW'},
            'startAtMillis': 1000000,
          })))!;
      await tester.pumpWidget(host(
        session: LoggingSession(editingQso: existingQso),
        radio: baseRadio().copyWith(radioService: fakeRadio),
      ));
      await tester.pump();

      await submit(tester, 'W1AWX');

      final logged = await waitForQsos(tester, 1);
      expect(logged, hasLength(1), reason: 'still just the original record');
      expect(
        logged.single.theirCall,
        'W1AW',
        reason: 'the edit must not be saved while the contact has neither band nor frequency',
      );
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
    });

    // Being asked for a band must not trap a contact that the operator is
    // trying to get rid of — the guard sits below the delete branch.
    testWidgets('a bandless contact can still be deleted without first being repaired', (tester) async {
      // Shaped like the records the wipe/delete group uses: the second button
      // only offers *delete* while the loaded QSO still matches the fields, so
      // the fixture has to carry what the controls populate from it.
      final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
            'their': {'call': 'W1AW', 'sent': ''},
            'our': {'call': 'KI2D', 'sent': '59'},
            'mode': 'SSB',
            'startAtMillis': 1000000,
          })))!;
      await tester.pumpWidget(host(
        session: LoggingSession(editingQso: existingQso, onEditCanceled: () {}),
        radio: baseRadio().copyWith(radioService: fakeRadio),
      ));
      await tester.pump();

      // Stage the delete (the second button becomes "delete" for an
      // unmodified QSO), then confirm it with the submit button, which turns
      // into a solid trash can while a delete is staged. The button rather
      // than Enter: tapping the staging button took the text field's input
      // connection with it, and this test is about the guard's placement.
      await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
      await tester.pump();
      expect(find.textContaining('will be deleted'), findsOneWidget, reason: 'the delete is staged');
      await tester.tap(find.byIcon(MdiIcons.trashCan));
      await tester.pump(const Duration(milliseconds: 400));

      // `watchForOperation` excludes soft-deleted records, so an empty list is
      // the delete having gone through rather than the guard blocking it.
      //
      // Watching for a contact that cannot arrive is what makes this WAIT: the
      // record is still there when the wait starts, so any count the row itself
      // satisfies would return on the first poll and report a delete that is
      // merely slow as one the guard blocked.
      expect(await qsosAfterWaiting(tester, watchFor: 2), isEmpty, reason: 'the delete went through');
    });
  });

  // The standing half of the same rule. The log-time refusal above only
  // speaks once the operator has typed a call and pressed Enter — by then
  // they have worked the station and the answer is late. The pill is on
  // screen from the moment the panel is, in every state the information area
  // takes, so a station that never set a band is told before the first
  // contact rather than after it.
  group('the missing band/mode warning pill', () {
    testWidgets('stands in the information area before anything is typed', (tester) async {
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
      await tester.pump();

      expect(find.text('No Band'), findsOneWidget);
    });

    // The pill is a warning about the RADIO, not about the station in the
    // field, so it must not wait for a callsign — nor vanish once there is
    // one, which is exactly when it matters most.
    testWidgets('stays up beside the call-info line once a call is typed', (tester) async {
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      // The info area cross-fades between its states; a second pump lets the
      // outgoing copy of the pill leave, so `findsOneWidget` measures what is
      // on screen rather than a frame of the transition.
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No Band'), findsOneWidget);
    });

    // The mutation this catches: a pill that is drawn unconditionally still
    // passes every assertion above.
    testWidgets('is absent once the radio has a frequency to derive a band from', (tester) async {
      fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
      await tester.pump();

      expect(find.text('No Band'), findsNothing);
    });

    // A band picked by hand answers the question as completely as a
    // frequency does — the same band-OR-frequency rule the log-time guard
    // applies, and the two must not disagree about what counts.
    testWidgets('a band with no frequency answers it too', (tester) async {
      fakeRadio.setVfo('vfoA', band: '40m', mode: 'SSB');
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
      await tester.pump();

      expect(find.text('No Band'), findsNothing);
    });

    // Band-OR-frequency, exactly as the log-time guard reads it: a frequency
    // in no band at all is still a frequency, and the contact it logs still
    // carries one, so there is nothing to warn about. The mutation this
    // catches is dropping the frequency half of the condition — on every
    // in-band frequency `_band` is derived from it, so nothing else here can
    // tell the two conditions apart.
    testWidgets('a frequency outside every band is still an answer', (tester) async {
      fakeRadio.setVfo('vfoA', freq: 5000, mode: 'SSB');
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
      await tester.pump();

      expect(find.text('No Band'), findsNothing);
    });

    // The mode half. Nothing the operator can do in the panel empties the
    // mode — it starts on a hardcoded 'SSB' and every path that moves it
    // writes a real emission — so a command is the one thing that can, and an
    // extension's command is not the app's code. A QSO with no mode is
    // rejected by LoTW and every award programme, so it is worth the pill.
    testWidgets('a command that leaves the mode empty is called out', (tester) async {
      Future<Map<String, dynamic>?> clearsTheMode(
        String input, [
        Map<String, dynamic>? operation,
        Map<String, dynamic>? qso,
        bool execute = false,
      ]) async =>
          input.toUpperCase() == 'NOMODE'
              ? {
                  'describe': 'Clear the mode?',
                  'confirm': 'Mode cleared',
                  'commands': [
                    {'setVfo': {'mode': ''}}
                  ]
                }
              : null;

      await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: clearsTheMode)));
      expect(find.text('No Mode'), findsNothing, reason: 'the panel starts with a mode');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'NOMODE');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));
      // The command's own confirmation owns the information area while it is
      // up; typing the next callsign clears it and the area goes back to
      // reporting the state the command left behind.
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No Mode'), findsOneWidget);
    });

    // The pills read the strings package directly. Every other test here
    // asserts the English text, which a hardcoded label would also satisfy —
    // this one switches the locale, so a pill that stopped reading `t` and
    // showed a Spanish operator "No Band" fails here and nowhere else.
    testWidgets('the pill speaks the operator\'s language', (tester) async {
      await useSpanish(tester);
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
      await tester.pump();

      expect(find.text('Sin Banda'), findsOneWidget);
      expect(find.text('No Band'), findsNothing);
    });

    // The refusal message OUTLIVES the condition that wrote it — only a
    // call-field keystroke clears it, not the band pick that answers it. So a
    // warning drawn underneath it would go quiet exactly while the operator
    // was doing what they were told, and the area would keep asserting a
    // refusal that no longer applies.
    testWidgets('answering the refusal clears the pill even while its message is still up', (tester) async {
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
      await tester.pump();
      // The unset VFO opens the Radio control on mount; collapse it, or Enter
      // closes it instead of reaching the log path.
      await openControl(tester, MdiIcons.radio);
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 400));
      // The area cross-fades into the message state; let the outgoing copy go.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Set a frequency or band'), findsOneWidget, reason: 'the refusal stands');
      expect(find.text('No Band'), findsOneWidget, reason: 'and so does the warning it is about');

      // The operator does what the refusal asked, in the control it opened.
      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('No Band'), findsNothing);
    });

    // Both at once, in the locale that spells them longest and at the
    // narrowest width the panel itself still lays out at — no other test here
    // renders two pills, so without this one nothing sees them side by side
    // at all. It pins that they fit and that the row does not overflow; the
    // `Wrap` is what keeps that true if a label or a rung grows, and a plain
    // Row still passes at this width, so read it as the floor, not as proof
    // of the Wrap.
    testWidgets('an untuned radio with an emptied mode shows both pills together', (tester) async {
      Future<Map<String, dynamic>?> clearsTheMode(
        String input, [
        Map<String, dynamic>? operation,
        Map<String, dynamic>? qso,
        bool execute = false,
      ]) async =>
          input.toUpperCase() == 'NOMODE'
              ? {
                  'describe': 'Clear the mode?',
                  'confirm': 'Mode cleared',
                  'commands': [
                    {'setVfo': {'mode': ''}}
                  ]
                }
              : null;

      // Below this the entry row itself overflows, which would mask what this
      // test is watching rather than sharpen it.
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Spanish spells both pills long — the case the Wrap exists for.
      await useSpanish(tester);
      await tester.pumpWidget(host(
        radio: baseRadio().copyWith(radioService: fakeRadio),
        commands: CommandHooks(interpretCommand: clearsTheMode),
      ));
      await tester.pump();
      // The unset VFO opens the Radio control on mount; Enter inside an open
      // control closes it rather than running the command.
      await openControl(tester, MdiIcons.radio);
      await tester.enterText(find.widgetWithText(TextField, t.loggingControls.theirCall), 'NOMODE');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.widgetWithText(TextField, t.loggingControls.theirCall), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sin Banda'), findsOneWidget);
      expect(find.text('Sin Modo'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the two pills must not overflow their row');
    });

    // The warning is about OUR radio. Answering a tap on it with the detail
    // panel for the station being worked answers a question nobody asked —
    // and the same pill offers no gesture at all in the stats state.
    testWidgets('tapping the pill does not open the other station\'s detail panel', (tester) async {
      var opened = 0;
      await tester.pumpWidget(host(
        radio: baseRadio().copyWith(radioService: fakeRadio),
        lookups: LookupHooks(onCallInfoTap: () => opened++),
      ));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('No Band'));
      await tester.pump();
      expect(opened, 0);

      // …while the call-info line beside it still opens it.
      await tester.tap(find.byIcon(MdiIcons.account));
      await tester.pump();
      expect(opened, 1, reason: 'the call-info content is still the tap target');
    });

    // An event row is not a contact and needs no band, so it must not be
    // nagged about one — even on the untuned station these warnings are for.
    // The `event` band sentinel does not reach `_band` here (the record's zero
    // frequency drops it), so nothing but the explicit guard stops this.
    testWidgets('an event row is not nagged about a band it will never carry', (tester) async {
      final note = Qso(
        uuid: 'note-uuid',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'check later'},
        },
      );
      await tester.pumpWidget(host(
        session: LoggingSession(editingQso: note, onEditCanceled: () {}),
        radio: baseRadio().copyWith(radioService: fakeRadio),
      ));
      await tester.pump();

      expect(find.text('No Band'), findsNothing);
    });
  });

  // ---- Live follow: a connected radio (CAT) moving the VFO underneath us.
  // The panel only ever read vfoA when it seeded, so a CAT push was
  // invisible; these cover following it without ever overwriting the
  // operator. See docs/design/cat.md.

  testWidgets('follows the VFO when a connected radio is tuned', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14285');

    // The operator turns the knob on the radio.
    fakeRadio.setVfo('vfoA', freq: 7123.45, mode: 'LSB');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '7123.45');
    expect(find.text('40m'), findsWidgets, reason: 'the band follows the frequency');
  });

  testWidgets('HALO-32: a radio-driven frequency change never runs the band-plan mode guess', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 7100, mode: 'CW');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');

    // The operator retunes to 14074 kHz (FT8 territory per the band plan)
    // but leaves the rig on CW — its own reported mode must win, never a
    // band-plan re-guess from the new frequency.
    fakeRadio.setVfo('vfoA', freq: 14074, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14074');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');
  });

  testWidgets(
      'HALO-32: a radio-driven frequency-only update (no mode of its own) never runs the band-plan mode guess',
      (tester) async {
    // The test above can't actually tell a broken populate guard from a
    // working one: `RadioControlModel.seedFromVfo`'s own `if (vfo.mode != null)
    // mode = vfo.mode!` unconditionally overwrites any stray guess right after,
    // as long as the radio reports SOME mode. Here `fakeRadio` never has a
    // mode set (`FakeVfoStore`'s Vfo starts with mode: null, and this test
    // never passes one), so that overwrite never fires — a stray guess, if
    // the guard were broken, would go unmasked. This is the actually
    // guard-sensitive version.
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');

    // The radio reports a frequency-only change — 14074 kHz is FT8
    // territory per the band plan, but nothing here should guess it.
    fakeRadio.setVfo('vfoA', freq: 14074);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14074');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');
  });

  testWidgets('a radio update does not overwrite a frequency the operator is part-way through typing',
      (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    // Two digits: too short to arm the push debounce, so the debounce alone
    // is not what protects this — the dirty flag is.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '71');
    await tester.pump();

    fakeRadio.setVfo('vfoA', freq: 21000, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '71',
        reason: 'the operator was mid-entry — their intent is newer than the radio');
  });

  testWidgets('following resumes once the operator edit has reached the VFO', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7100');
    await tester.pump();
    // The 5s debounce fires and the edit reaches the VFO.
    await tester.pump(const Duration(seconds: 6));
    expect(fakeRadio.vfoA.freq, 7100);

    // Now the panel and the VFO agree again, so a radio move is followed.
    fakeRadio.setVfo('vfoA', freq: 21050, mode: 'CW');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '21050');
  });

  testWidgets('a pending frequency edit holds off the frequency, not the mode', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    // Mid-entry: the operator's frequency is newer than the radio's.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '71');
    await tester.pump();

    // The rig is switched to CW at its own front panel meanwhile.
    fakeRadio.setVfo('vfoA', freq: 14030, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '71',
        reason: 'their entry is newer');
    // The whole seed used to be suppressed, so the mode was dropped — and
    // the pending push then sent the panel's stale SSB back at the rig,
    // taking it out of CW and logging the QSO as USB at 59.
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '599');

    await tester.pump(const Duration(seconds: 6));
    expect(fakeRadio.vfoA.mode, 'CW', reason: 'the push must not undo the mode change');
  });

  testWidgets('a live radio band change rescores the dupe and New Band pills', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    final scoredBands = <String?>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: baseLog(),
          radio: RadioHookup(
            radioService: fakeRadio,
            radioUpdates: fakeRadio,
          ),
          lookups: LookupHooks(
            scoreQso: ({required operation, required qso, excludeUuid, segments}) async {
              scoredBands.add(qso['band'] as String?);
              return {'notices': <String>[], 'alerts': <String>[]};
            },
            scoreNoticeLabel: (key) => key,
          ),
        ),
      ),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump(const Duration(milliseconds: 500));
    expect(scoredBands, ['20m']);

    // The rig moves to another band on its own. The pills are scored
    // against band and mode, and the seed runs under the populate bracket — which
    // suppressed the rescore, leaving them describing a band the operator
    // has left.
    fakeRadio.setVfo('vfoA', freq: 7040, mode: 'CW');
    await tester.pump(const Duration(milliseconds: 500));
    expect(scoredBands.last, '40m');
  });

  testWidgets('a partial frequency entry does not switch live follow off for good', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    // Three characters or fewer arms no debounce, so nothing ever cleared
    // the pending-edit flag: the Radio control stopped following the rig
    // for the rest of the session, and every QSO after it logged the stale
    // frequency.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '145');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // The wipe collapses the Radio control along with everything else.
    await openControl(tester, MdiIcons.radio);
    fakeRadio.setVfo('vfoA', freq: 21050, mode: 'CW');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '21050');
  });

  testWidgets('the VFO notifier can be swapped while a QSO is being edited', (tester) async {
    // `radioService` (the store the fields are seeded FROM) and
    // `radioUpdates` (the Listenable that says when) are separate, so a
    // second store stands in as the notifier here.
    final notifierA = FakeVfoStore();
    final notifierB = FakeVfoStore();
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7040,
        'mode': 'CW',
      },
    );

    Widget hostWith({required Listenable updates, Qso? editing}) => MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              session: LoggingSession(
                editingQso: editing,
              ),
              radio: RadioHookup(
                radioService: fakeRadio,
                radioUpdates: updates,
              ),
            ),
          ),
        );

    await tester.pumpWidget(hostWith(updates: notifierA, editing: existingQso));
    await tester.pumpAndSettle();

    // The swap lands mid-edit. Re-subscribing used to sit below
    // `didUpdateWidget`'s editingQso guards, so it simply never ran here:
    // the listener stayed on A, `dispose` then removed it from B, and A
    // kept this State alive with nothing following it.
    await tester.pumpWidget(hostWith(updates: notifierB, editing: existingQso));
    await tester.pumpAndSettle();

    await tester.pumpWidget(hostWith(updates: notifierB));
    await tester.pumpAndSettle();
    await openControl(tester, MdiIcons.radio);

    fakeRadio.setVfo('vfoA', freq: 21050, mode: 'CW');
    notifierB.setVfo('vfoA', freq: 21050, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '21050');
  });

  testWidgets('a radio update never touches the fields while editing an existing QSO', (tester) async {
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7040,
        'mode': 'CW',
      },
    );
    await tester.pumpWidget(host(
      session: LoggingSession(editingQso: existingQso),
      radio: baseRadio().copyWith(radioService: fakeRadio),
    ));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '7040');

    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpAndSettle();

    // A logged QSO records where it actually happened; ambient radio state
    // must not rewrite it.
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '7040');
  });

  testWidgets('a radio mode change refreshes the default RST placeholder', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '59');

    fakeRadio.setVfo('vfoA', freq: 14030, mode: 'CW');
    await tester.pumpAndSettle();

    // A seed that sets the mode without rebuilding the fields leaves 59
    // standing in for a CW report — and 59 is what then gets logged.
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '599');
  });

  testWidgets('a radio mode change leaves an RST the operator edited alone', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.pump();

    fakeRadio.setVfo('vfoA', freq: 14030, mode: 'CW');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).controller!.text, '57');
  });

  // The default report is a placeholder, never real text: an operator reaching
  // for Sent to give a true 57 must be able to type it, not clear a pre-filled
  // 59 first. What gets LOGGED is unchanged — the default becomes real on the
  // way out, so nothing downstream (export, scoring, LoTW) ever sees a blank
  // report.
  testWidgets('HALO-83: a blank RST shows the mode default as a placeholder and logs it as a real value',
      (tester) async {
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(field('Sent').controller!.text, isEmpty, reason: 'the default must not be pre-filled');
    expect(field('Rcvd').controller!.text, isEmpty);
    expect(field('Sent').decoration!.hintText, '59');
    expect(field('Rcvd').decoration!.hintText, '59');

    // One keystroke replaces the default outright — the thing a pre-filled
    // "59" costs you.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.sentRST, '57', reason: 'a typed report wins over the default');
    expect(logged.single.receivedRST, '59', reason: 'the untouched placeholder is what gets stored');
  });

  testWidgets('HALO-83: a shorthand report is completed when focus leaves the field', (tester) async {
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5');
    await tester.pump();
    expect(field('Sent').controller!.text, '5', reason: 'never mid-keystroke — 5 could still be becoming 57');

    // Space is the ordinary way out of a report field.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5 ');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'test setup');
    expect(field('Sent').controller!.text, '55');
  });

  testWidgets('HALO-83: the report the operator logs from is completed too, though Enter never blurs it',
      (tester) async {
    // The trap: expanding only on blur (which is all PoLo does, where Enter
    // DOES blur) leaves the very field the operator submitted from carrying a
    // bare "5" into the record — and it is the last field they touch, so it is
    // the commonest one.
    await tester.pumpWidget(host());
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '4');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.receivedRST, '44');
  });

  testWidgets('HALO-83: on CW a shorthand report gains its tone digit', (tester) async {
    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: fakeInterpretCommand)));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'CW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '5');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.mode, 'CW', reason: 'test setup');
    expect(logged.single.sentRST, '579');
    expect(logged.single.receivedRST, '559');
  });

  testWidgets('HALO-83: the operator\'s own default report replaces the standard one', (tester) async {
    // A CW operator sending "5NN" wants that in the log, not 599 — and the
    // placeholder has to show what will actually be stored, or the setting is
    // invisible until the QSO is already logged.
    await tester.pumpWidget(host(
      commands: CommandHooks(interpretCommand: fakeInterpretCommand),
      prefs: LoggingPreferences(defaultReportCW: '5NN'),
    ));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(field('Sent').decoration!.hintText, '59', reason: 'test setup: still on phone');

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'CW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));
    expect(field('Sent').decoration!.hintText, '5NN');

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.sentRST, '5NN');
    expect(logged.single.receivedRST, '5NN');
  });

  testWidgets('HALO-83: editing a saved QSO with no RST does not invent one', (tester) async {
    // A blank field on a saved record is stored data, not a stand-in — filling
    // it in would rewrite a QSO the operator only opened to look at, and the
    // hint has to stay away for the same reason (it would promise a value the
    // save never writes).
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'startAtMillis': 1000000,
          'freq': 7100,
          'mode': 'SSB',
        })))!;
    await tester.pumpWidget(host(session: LoggingSession(editingQso: existingQso)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(field('Sent').controller!.text, isEmpty);
    expect(field('Sent').decoration!.hintText, isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);
    expect(logged.single.sentRST, anyOf(isNull, isEmpty));
    expect(logged.single.receivedRST, anyOf(isNull, isEmpty));
  });

  testWidgets('HALO-143: jumpAfterRST moves on once a report is complete, and stays put until then', (tester) async {
    await tester.pumpWidget(host(prefs: LoggingPreferences(jumpAfterRST: true)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();

    // One digit is not a report — jumping here would make a true 57
    // untypeable.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'two characters is a full report on phone');

    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '59');
    await tester.pump();
    expect(field('Their call').focusNode!.hasFocus, isTrue, reason: 'the last report wraps on to the callsign');
  });

  testWidgets('HALO-143: jumpAfterRST waits for the tone digit on CW, so aurora reports stay typeable',
      (tester) async {
    // The trap a two-character threshold would set: on CW a `44` still owes
    // its `A` (or its tone), so jumping at two makes `44A` and `5NN`
    // unreachable — the operator is thrown into the next field mid-report.
    await tester.pumpWidget(host(
      commands: CommandHooks(interpretCommand: fakeInterpretCommand),
      prefs: LoggingPreferences(jumpAfterRST: true),
    ));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'CW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '44');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue, reason: 'two characters is not a full CW report');

    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '44A');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue);
    expect(field('Sent').controller!.text, '44A', reason: 'the aurora report survives intact');
  });

  testWidgets('HALO-143: jumpAfterRST does not fire while correcting an already-complete report', (tester) async {
    // PoLo tests `length >= full` on every keystroke, so editing a field that
    // already holds a full report throws focus away on the first character.
    // Firing on the upward crossing only is what makes a correction possible.
    await tester.pumpWidget(host(prefs: LoggingPreferences(jumpAfterRST: true)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '59');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'test setup: it jumped once');

    // Back to Sent to fix it. Every keystroke from here leaves the field at or
    // above the full length, and none of them may jump.
    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '599');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5991');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: jumpAfterRST off leaves focus alone', (tester) async {
    await tester.pumpWidget(host());
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '59');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: jumpAfterRST does not apply on the FT modes, whose report has no fixed length',
      (tester) async {
    // -9, +05 and -12 are all real SNR reports, so no length means "done".
    // Any threshold here is wrong for some of them; the setting sits out.
    await tester.pumpWidget(host(
      commands: CommandHooks(interpretCommand: fakeInterpretCommand),
      prefs: LoggingPreferences(jumpAfterRST: true),
    ));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'FT8');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '-12');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: switchSentRcvd swaps the row and the keyboard path through it together', (tester) async {
    // The pair that must not drift: the row's own order and the Space cycle's.
    // A swap applied to only one of them leaves Space skipping backwards
    // through fields the operator sees left to right.
    await tester.pumpWidget(host(prefs: LoggingPreferences(switchSentRcvd: true)));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    double left(String label) => tester.getTopLeft(find.widgetWithText(TextField, label)).dx;
    expect(left('Rcvd'), lessThan(left('Sent')), reason: 'Rcvd is drawn first');

    // Space walks Call → Rcvd → Sent, following what is on screen. Entered in
    // two steps because the interceptor only claims a genuine single-space
    // insertion at the end of the value, not a bulk replacement that happens
    // to end in one.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW ');
    await tester.pump();
    expect(field('Rcvd').focusNode!.hasFocus, isTrue, reason: 'Space reaches the leftmost report first');

    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), ' ');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: focusing a complete report on a QSO opened for editing does not jump', (tester) async {
    // A QSO CONSTRUCTED already-editing is populated before the jump
    // listeners exist, so the baseline they compare against has to be seeded
    // from the fields rather than left at zero. Without it this needs no
    // typing at all to go wrong: gaining focus collapses the selection, which
    // is a value change, which reads as "0 -> 3" and jumps — and the next
    // field, equally unseeded, jumps again. Tapping Sent to fix a 599 walks
    // the operator straight past Rcvd and out of the reports entirely.
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'our': {'sent': '599'},
          'their': {'call': 'W1AW', 'sent': '599'},
          'startAtMillis': 1000000,
          'freq': 7020,
          'mode': 'CW',
        })))!;
    await tester.pumpWidget(host(
      session: LoggingSession(editingQso: existingQso),
      prefs: LoggingPreferences(jumpAfterRST: true),
    ));
    TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));

    expect(field('Sent').controller!.text, '599', reason: 'test setup');
    field('Sent').focusNode!.requestFocus();
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue, reason: 'merely arriving in a full field must not move on');

    // And a correcting keystroke on top of it stays put too.
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '5991');
    await tester.pump();
    expect(field('Sent').focusNode!.hasFocus, isTrue);
  });

  testWidgets('HALO-143: switchSentRcvd reaches the More pane, which is a separate order expression',
      (tester) async {
    // The pane round-trips through a Map of field keys, not through the
    // controllers the row shares, so its order is written out a second time —
    // and a second expression is a second chance to get the ternary backwards.
    // A pane contradicting the row that opened it is the whole failure.
    await tester.pumpWidget(host(prefs: LoggingPreferences(switchSentRcvd: true)));
    await openControl(tester, MdiIcons.pencil);
    await tester.pumpAndSettle();

    final sent = find.text('Sent');
    final rcvd = find.text('Rcvd');
    expect(sent, findsWidgets);
    expect(rcvd, findsWidgets);
    expect(
      tester.getTopLeft(rcvd.last).dy,
      lessThan(tester.getTopLeft(sent.last).dy),
      reason: 'the pane stacks its fields, so Rcvd first means Rcvd higher',
    );
  });

  testWidgets('HALO-143: switchSentRcvd keeps each value on its own field, it only moves them', (tester) async {
    // The failure a pure-display swap invites: reversing the widgets without
    // reversing what they are bound to silently logs the reports backwards.
    await tester.pumpWidget(host(prefs: LoggingPreferences(switchSentRcvd: true)));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.enterText(find.widgetWithText(TextField, 'Sent'), '57');
    await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '33');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.sentRST, '57');
    expect(logged.single.receivedRST, '33');
  });

  testWidgets('a brand new operation sees the same vfoA as any other — it is not per-operation', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    final freshOperation = await operations.create(stationCall: 'KI2D');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LoggingControls(
          log: LogHooks(
            operation: freshOperation,
            qsosRepository: qsos,
          ),
          radio: RadioHookup(
            radioService: fakeRadio,
          ),
        ),
      ),
    ));
    await openControl(tester, MdiIcons.radio);

    final freqField = tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency'));
    expect(freqField.controller!.text, '14285');
  });

  testWidgets('does not seed from radioService.vfoA while editing an existing QSO', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7100,
        'mode': 'SSB',
      },
    );
    await tester.pumpWidget(host(
      session: LoggingSession(editingQso: existingQso),
      radio: baseRadio().copyWith(radioService: fakeRadio),
    ));
    await openControl(tester, MdiIcons.radio);

    final freqField = tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency'));
    expect(freqField.controller!.text, '7100');
  });

  testWidgets('Radio dropdowns offer the settings-enabled bands/modes, uncolored, plus the current value', (tester) async {
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(enabledBands: ['40m', '20m'], enabledModes: ['CW', 'FT8']),
    ));
    await openControl(tester, MdiIcons.radio);

    // Band menu: only the enabled bands — no colored entries (issue: band
    // colors made the dropdown hard to read).
    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    // DropdownMenu instantiates each entry twice (one offstage copy for
    // width measurement), so "present" is findsWidgets, not findsOneWidget.
    expect(find.widgetWithText(MenuItemButton, '40m'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, '20m'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, '80m'), findsNothing);
    final bandItem = tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, '40m').first);
    expect(bandItem.style?.foregroundColor, isNull);
    // Selecting an entry closes the menu.
    await tester.tap(find.widgetWithText(MenuItemButton, '40m').last);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    // Mode menu: the enabled modes plus the current mode (SSB, the compose
    // default), which stays pickable even though it's not in the enabled
    // list — same rule keeps a QSO on a since-disabled band/mode editable.
    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    expect(find.widgetWithText(MenuItemButton, 'CW'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, 'FT8'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, 'SSB'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, 'FM'), findsNothing);
  });

  testWidgets('empty enabled lists fall back to the common tier — deselecting every band must not empty the dropdown',
      (tester) async {
    await tester.pumpWidget(host(radio: baseRadio().copyWith(enabledBands: [], enabledModes: [])));
    await openControl(tester, MdiIcons.radio);

    // popularBands, not the full catalog: 160m is common, 630m is not.
    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    expect(find.widgetWithText(MenuItemButton, '80m'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, '160m'), findsWidgets);
    expect(find.widgetWithText(MenuItemButton, '630m'), findsNothing);
  });

  // At EVERY density, not just the default. The dropdowns cannot use
  // poloFieldDecoration — DropdownMenu takes an inputDecorationTheme, not an
  // InputDecoration — so they restate its padding, and a const there froze
  // them at one height while the field beside them moved with the ladder.
  // Running this at `normal` alone is exactly what missed that.
  for (final density in LayoutDensity.values) {
    testWidgets('$density: Radio dropdowns render at the same height as the sibling text fields', (tester) async {
      await tester.pumpWidget(LayoutDensityScope(density: density, child: host()));
      await openControl(tester, MdiIcons.radio);

      // `suffixIconConstraints` in the decoration is what holds these level:
      // without it the trailing arrow's 48px minimum tap target makes the
      // dropdown taller than the Frequency field beside it.
      final freqHeight = tester.getSize(find.widgetWithText(TextField, 'Frequency')).height;
      final dropdowns = find.byType(DropdownMenu<String>);
      expect(dropdowns, findsNWidgets(2));
      expect(tester.getSize(dropdowns.at(0)).height, freqHeight);
      expect(tester.getSize(dropdowns.at(1)).height, freqHeight);
    });
  }

  // A DropdownMenu takes an inputDecorationTheme, and these two BUILD one
  // rather than copyWith-ing the app's — so every slot the app theme carries
  // is silently absent here unless restated. The focus indicator is one of
  // them, and unrestated it lands on `primary`: 2.67:1 on the dark surface,
  // beside a Frequency field focusing white.
  for (final brightness in Brightness.values) {
    testWidgets('$brightness: the Band and Mode dropdowns restate the focus indicator', (tester) async {
      final theme = buildHaLoTheme(brightness);
      await tester.pumpWidget(host(appTheme: theme));
      await openControl(tester, MdiIcons.radio);

      final dropdowns = tester.widgetList<DropdownMenu<String>>(find.byType(DropdownMenu<String>));
      expect(dropdowns.length, 2);
      for (final dropdown in dropdowns) {
        final side = dropdown.inputDecorationTheme?.focusedBorder?.borderSide;
        expect(side, isNotNull, reason: '$brightness');
        // Not just "≠ primary": a fixed Colors.black satisfies that and is
        // black-on-near-black once the pane goes dark. The invariant is the
        // CONTRAST against the surface the field sits on, not the color.
        expect(contrastRatio(side!.color, theme.colorScheme.surface), greaterThanOrEqualTo(3.0),
            reason: '$brightness');
        // The same underline poloFieldDecoration gives the Frequency field
        // beside it — these must not diverge into two focus cues in one row.
        // (Both sides move together if the helper changes; what this catches is
        // the dropdowns drifting away from it, not the helper going wrong.)
        expect(side.color, haloFocusedInputBorder(brightness == Brightness.dark).borderSide.color,
            reason: '$brightness');
        // The focus indicator above is an UNDERLINE, which matches only while
        // these declare no shape of their own and Material's default applies.
        // Declaring an outline here without also reshaping the focused border
        // makes the field collapse to a bare line on focus — the exact trap
        // that keeps this out of the app theme (theme.dart).
        expect(dropdown.inputDecorationTheme?.border, isNull, reason: '$brightness');
        expect(dropdown.inputDecorationTheme?.enabledBorder, isNull, reason: '$brightness');
      }
    });
  }

  testWidgets('the radio row actually changes height across the density ladder', (tester) async {
    // The sibling check above passes trivially if NOTHING moves. This is the
    // other half: the row has to be genuinely shorter when dense.
    double heightAt(WidgetTester t) => t.getSize(find.widgetWithText(TextField, 'Frequency')).height;

    Future<double> measure(LayoutDensity density) async {
      // A full unmount between the two: re-pumping a different scope over the
      // same tree keeps the panel's State, and with it the closed radio
      // control, so the second measurement would find no Frequency field.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(LayoutDensityScope(density: density, child: host()));
      await openControl(tester, MdiIcons.radio);
      return heightAt(tester);
    }

    final densest = await measure(LayoutDensity.densest);
    final sparsest = await measure(LayoutDensity.sparsest);

    expect(sparsest - densest, greaterThanOrEqualTo(15.0));
  });

  testWidgets('typing in the Band dropdown filters the menu; focus-away selects the first match', (tester) async {
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m', '17m']),
    ));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Band'), '4');
    await tester.pump();
    // hitTestable: DropdownMenu keeps an offstage copy of the ORIGINAL
    // entries for width measurement — only the live menu reflects the
    // filter.
    expect(find.widgetWithText(MenuItemButton, '40m').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, '20m').hitTestable(), findsNothing);

    // Moving focus away commits the first match as if it had been picked:
    // the field text resolves, the VFO hears about it, and the menu closes.
    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).controller!.text, '40m');
    expect(fakeRadio.vfoA.band, '40m');
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
    // Type-to-filter is a desktop affordance — on touch platforms the
    // dropdown stays a pick-only button, so run these desktop-only.
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('arrow keys step the Band selection while the menu is closed', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285);
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m']),
    ));
    await openControl(tester, MdiIcons.radio);

    // Band is deliberately out of the panel's own Tab/cursor-key cycle (it's
    // a mouse/type-to-filter control, not a keyboard-traversal stop), so
    // this focuses it directly rather than tabbing in — a tap would open
    // the menu, which the closed-menu arrow path here needs to avoid.
    tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).focusNode!.requestFocus();
    await tester.pump();
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).focusNode!.hasFocus,
      isTrue,
    );
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(fakeRadio.vfoA.band, '40m');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).controller!.text, '40m');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(fakeRadio.vfoA.band, '20m');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('arrow keys walk the open Mode menu and blur commits the highlighted entry', (tester) async {
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8']),
    ));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    // Two downs from the initial SSB: highlight SSB, then CW — walking
    // across a clock tick must not reset the highlight back to the top.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');

    // Blur commits the walked-to entry and hides the menu.
    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pump();
    expect(fakeRadio.vfoA.mode, 'CW');
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('typing a complete short band name narrows the menu instead of showing every band', (tester) async {
    // Regression: the filter used to switch OFF the moment the typed text
    // equalled a full option, so completing "2m" re-expanded the menu to
    // the whole catalog on the last keystroke.
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m', '2m']),
    ));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Band'), '2m');
    await tester.pump();
    // "2m" matches only 2m (20m/80m/40m don't contain "2m"); the menu stays
    // narrowed rather than reverting to the full list.
    expect(find.widgetWithText(MenuItemButton, '2m').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, '20m').hitTestable(), findsNothing);
    expect(find.widgetWithText(MenuItemButton, '80m').hitTestable(), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Enter from a focused Band dropdown commits the band and closes the control (APP-19)', (tester) async {
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m']),
    ));
    await openControl(tester, MdiIcons.radio);
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Band'), '40');
    await tester.pump();
    // Enter commits the typed band and then closes the control. It
    // deliberately does NOT log any more (it used to reach the panel's root
    // log shortcut): under APP-19's ladder Enter is what closes a secondary
    // control, and logging is one rung down, from a main field. The
    // operator's callsign is still sitting in the form, unlogged.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // Same pump shape as `openControl`, for the same reason — the close
    // slide's ticker doesn't start counting until the frame after it's
    // asked to run, so a bare pump(250ms) would leave it at zero elapsed.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(fakeRadio.vfoA.band, '40m');
    expect(find.widgetWithText(TextField, 'Band'), findsNothing);
    expect(await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first), isEmpty);
    // …and the keyboard goes straight back to the main field the operator
    // was in — there's no pill stop on the way out anymore.
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus,
      isTrue,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('arrow keys keep a typed filter while walking the open menu', (tester) async {
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']),
    ));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'F');
    await tester.pump();
    // Filtered to the F-modes; SSB/CW gone.
    expect(find.widgetWithText(MenuItemButton, 'FT8').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'SSB').hitTestable(), findsNothing);

    // Arrows walk WITHIN the filtered set, and the menu stays filtered —
    // the full-label writes the walk produces must not reset the filter,
    // not even across a clock tick. First down highlights FT8, second FT4.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.widgetWithText(MenuItemButton, 'SSB').hitTestable(), findsNothing);
    expect(find.widgetWithText(MenuItemButton, 'FT4').hitTestable(), findsOneWidget);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT4');

    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pump();
    expect(fakeRadio.vfoA.mode, 'FT4');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Enter commits the first matching mode; garbage text reverts', (tester) async {
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8']),
    ));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'f');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
    expect(fakeRadio.vfoA.mode, 'FT8');

    // Text matching nothing must not change the selection — it reverts.
    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'zz');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
    expect(fakeRadio.vfoA.mode, 'FT8');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a mode picked from the menu is a selection, not a filter', (tester) async {
    // The trap: DropdownMenu writes the picked label into the controller
    // before `onSelected` runs, so the pick looks exactly like typed text.
    // Kept as a filter it narrows the menu to the one entry picked, and
    // DropdownMenu then refuses to sync the field to a changed
    // `initialSelection` it can't find among those entries — so the band
    // plan's next guess never reaches the field, and the commit on the way
    // out pushes the stale mode back over it.
    fakeRadio.setVfo('vfoA', freq: 7200, mode: 'SSB');
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']),
    ));
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7050');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT4');

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(MenuItemButton, 'CW').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');
    expect(fakeRadio.vfoA.mode, 'CW');

    // Tuning on: the band plan's guess for 7200 has to reach the field.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7200');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'SSB');

    // …and the menu still offers every enabled mode, not just the one picked.
    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(MenuItemButton, 'FT8').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'SSB').hitTestable(), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a band picked from the menu is a selection, not a filter', (tester) async {
    // Same trap as the Mode dropdown above, on the sibling that shares the
    // filter machinery.
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m']),
    ));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(MenuItemButton, '40m').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fakeRadio.vfoA.band, '40m');

    // A frequency names its own band, and the field has to follow it — which
    // it can't while the entries are narrowed to the band just picked.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).controller!.text, '20m');

    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(MenuItemButton, '80m').hitTestable(), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('on a touch platform, where nothing else clears it, a mode pick still is not a filter', (tester) async {
    // The severe form: a dropdown field can't take focus on iOS/Android, so
    // neither the focus-gain clear nor the blur commit — the two paths that
    // paper over a stray filter on desktop — ever runs. A filter left by the
    // pick would pin the menu to that one entry for the rest of the session.
    fakeRadio.setVfo('vfoA', freq: 7200, mode: 'SSB');
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']),
    ));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(MenuItemButton, 'CW').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '7050');
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT4');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a rig that moves the mode wins over half-typed text in the Mode field', (tester) async {
    // The trap: the operator starts typing a mode, the rig moves underneath
    // them, and the field keeps showing the keystrokes. The model's mode has already
    // followed the rig, so nothing on screen says the two disagree — and the
    // commit on the way out resolves 'F' to FT8 and pushes it, retuning a rig
    // that had just reported CW on the strength of a keystroke older than the
    // report.
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']),
    ));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'F');
    await tester.pump();

    fakeRadio.setVfo('vfoA', freq: 14030, mode: 'CW');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');

    // Leaving the field must not resurrect the abandoned edit.
    await tester.tap(find.widgetWithText(TextField, 'Frequency'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');
    expect(fakeRadio.vfoA.mode, 'CW', reason: 'the rig keeps the mode it reported');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '599');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a spot arriving while the Mode field is being typed in replaces the half-typed text', (tester) async {
    // A spot tapped on another surface repopulates every field. The Mode
    // dropdown is the one field that could hold the operator's own unfinished
    // text at that moment, and it must not survive to commit over the mode
    // the spot brought.
    await tester.pumpWidget(host(radio: baseRadio().copyWith(enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM'])));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'C');
    await tester.pump();

    await tester.pumpWidget(host(
      session: LoggingSession(suggestedQso: const {'their': {'call': 'W1AW'}, 'freq': 14074.0, 'mode': 'FT8'}),
      radio: baseRadio().copyWith(enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']),
    ));
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a rig restating the mode it is already on leaves the operator typing alone', (tester) async {
    // The other half of the contract, and the one a blunter fix breaks: a
    // connected radio notifies constantly. Only a mode that actually MOVED
    // may take the field back — a VFO update that changes nothing else must
    // not wipe a filter mid-word.
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']),
    ));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'F');
    await tester.pump();

    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'F');
    expect(find.widgetWithText(MenuItemButton, 'FT8').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'SSB').hitTestable(), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('an open Band menu holds its scroll position across the clock-tick rebuilds', (tester) async {
    // A selected band matters: the rebuild-time re-scroll only fires when
    // the field text matches an entry. Null enabled lists → the full
    // 19-band catalog, taller than the 10.5-entry menu cap, so it scrolls.
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);
    await tester.tap(find.widgetWithText(TextField, 'Band'));
    await tester.pump();

    final menuScrollable = find.ancestor(
      of: find.widgetWithText(MenuItemButton, '2190m').last,
      matching: find.byType(Scrollable),
    );
    final position = tester.widget<Scrollable>(menuScrollable.first).controller!.position;
    position.jumpTo(200);
    await tester.pump();
    expect(position.pixels, 200);

    // The Time chip's Timer.periodic setState rebuilds this widget every
    // second; with enableSearch on, each rebuild re-scrolled the menu back
    // to the selected entry, so the user could never scroll the list.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(position.pixels, 200);
  });

  testWidgets('editing an existing QSO applies Radio control changes to the QSO, not the VFO', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7100,
        'mode': 'SSB',
      },
    );
    await tester.pumpWidget(host(
      session: LoggingSession(editingQso: existingQso),
      radio: baseRadio().copyWith(radioService: fakeRadio),
    ));
    await openControl(tester, MdiIcons.radio);

    // Typing a frequency, past both the debounce and the blur flush...
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '21200');
    await tester.pump(const Duration(seconds: 6));
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    // ...picking a band...
    await tester.tap(find.widgetWithText(TextField, 'Band').first);
    await tester.pumpAndSettle();
    // DropdownMenu can leave a stale off-screen copy of a prior menu entry
    // around briefly — same harmless artifact as elsewhere in this file.
    await tester.tap(find.text('40m').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    // ...and picking a mode all leave the operation's VFO untouched.
    await tester.tap(find.widgetWithText(TextField, 'Mode').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('FT8').last);
    await tester.pumpAndSettle();

    expect(fakeRadio.vfoA.freq, 14285);
    expect(fakeRadio.vfoA.mode, 'CW');
  });

  testWidgets('a command setVfo pushes to radioService immediately', (tester) async {
    await tester.pumpWidget(host(
      radio: baseRadio().copyWith(radioService: fakeRadio),
      commands: CommandHooks(interpretCommand: fakeInterpretCommand),
    ));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), '14285');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    expect(fakeRadio.vfoA.freq, 14285);
    expect(fakeRadio.vfoA.band, '20m');
  });

  testWidgets('manually typing a frequency pushes to radioService debounced, and flushes on blur', (tester) async {
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
    await tester.pump();
    // Not yet pushed — still within the debounce window.
    expect(fakeRadio.vfoA.freq, isNull);

    // Moving focus elsewhere flushes the pending push immediately, without
    // waiting out the rest of the 5s debounce.
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    expect(fakeRadio.vfoA.freq, 14285);
    expect(fakeRadio.vfoA.band, '20m');
  });

  testWidgets('a 3-digit or shorter frequency is not pushed to radioService', (tester) async {
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '145');
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();

    expect(fakeRadio.vfoA.freq, isNull);
  });

  testWidgets('picking a band from the dropdown pushes to radioService immediately', (tester) async {
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Band').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('40m').last);
    await tester.pump();

    expect(fakeRadio.vfoA.band, '40m');
    expect(fakeRadio.vfoA.freq, isNull);
  });

  testWidgets('picking a mode from the dropdown pushes to radioService immediately', (tester) async {
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    await tester.tap(find.widgetWithText(TextField, 'Mode').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CW').last);
    await tester.pump();

    expect(fakeRadio.vfoA.mode, 'CW');
  });

  testWidgets('a stale-but-unflushed typed frequency still lands on the logged QSO', (tester) async {
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    // Typed, but Enter fires well within the 5s debounce window and
    // without blurring the field first.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14285');
    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    final logged = await waitForQsos(tester, 1);
    expect(logged.single.freq, 14285);
    expect(fakeRadio.vfoA.freq, 14285);
  });

  testWidgets('clearing the frequency field pushes the clear to radioService immediately, not debounced', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14285');

    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '');
    await tester.pump();

    // No 5s debounce wait, no blur — the clear takes effect right away.
    expect(fakeRadio.vfoA.freq, isNull);
  });

  testWidgets('ending an edit session re-seeds the Radio control from the VFO, not the just-edited QSO', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'freq': 7100,
        'mode': 'SSB',
      },
    );

    final editing = ValueNotifier<Qso?>(existingQso);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<Qso?>(
          valueListenable: editing,
          builder: (context, editingQso, _) => LoggingControls(
            log: baseLog(),
            session: LoggingSession(
              editingQso: editingQso,
              onEditCanceled: () => editing.value = null,
            ),
            radio: RadioHookup(
              radioService: fakeRadio,
            ),
          ),
        ),
      ),
    ));
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '7100');

    editing.value = null;
    await tester.pump();
    // Ending the edit collapses the secondary control row back to its
    // default (nothing expanded) — reopen it to read the re-seeded value.
    await openControl(tester, MdiIcons.radio);

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14285');
  });

  group('Power control', () {
    // The whole feature's premise: power is optional, and the operator asks
    // for it. A control that shipped ON would put a watts field in front of
    // every operator who never logs power.
    testWidgets('is not in the row until the operator has asked for it', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();

      expect(find.byIcon(MdiIcons.flash), findsNothing);
    });

    // The saved order is what records the operator's decision — the settings
    // dialog always writes every key it offered — so a control named there
    // and absent from the hidden set is one they kept.
    testWidgets('appears once the saved order names it', (tester) async {
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power'])));
      await tester.pump();

      expect(find.byIcon(MdiIcons.flash), findsOneWidget);
    });

    testWidgets('stays out when the operator turned it off', (tester) async {
      // Named in the order (so the decision was made) AND hidden — the
      // "decided against" state, which must not read as "never asked".
      await tester.pumpWidget(host(
        strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power'], hiddenControlKeys: const {'power'}),
      ));
      await tester.pump();

      expect(find.byIcon(MdiIcons.flash), findsNothing);
    });

    testWidgets('a typed power reaches the VFO when the field loses focus', (tester) async {
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power'])));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);

      await tester.enterText(find.widgetWithText(TextField, 'Power'), '5');
      await tester.pump();
      expect(tunedRadio.vfoA.power, isNull, reason: 'mid-typing, "1" of "100" must not reach the radio');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(tunedRadio.vfoA.power, 5,
          reason: 'the VFO is the one home for power — CAT forwards it to the rig from there');
    });

    testWidgets('the field mirrors a power the VFO already carries', (tester) async {
      final radio = FakeVfoStore()
        ..setVfo('vfoA', freq: 14285, mode: 'SSB')
        ..setVfo('vfoA', power: 100);
      await tester.pumpWidget(host(
        radio: baseRadio().copyWith(radioService: radio),
        strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power']),
      ));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Power')).controller!.text, '100');
    });

    testWidgets('a logged QSO carries the power while the control is shown', (tester) async {
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power'])));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);
      await tester.enterText(find.widgetWithText(TextField, 'Power'), '5');
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.power, 5,
          reason: 'showing the control is the operator asking for the power to be logged');
    });

    testWidgets('a QSO logged without the control carries no power', (tester) async {
      // The other half of the rule. Without it the stamp would be
      // unconditional, and every operator would silently start logging
      // whatever power the app last heard about.
      final radio = FakeVfoStore()
        ..setVfo('vfoA', freq: 14285, mode: 'SSB')
        ..setVfo('vfoA', power: 100);
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: radio)));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.power, isNull);
    });

    testWidgets('the More pane offers a Power field, after Mode', (tester) async {
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power'])));
      await tester.pump();
      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();

      final power = find.text('Power');
      expect(power, findsWidgets);
      // The pane stacks its fields, so "after Mode" is "lower than Mode" —
      // and still inside the QSO section, which is what stops it drifting
      // down among the fields that describe something else. Ours is the one
      // in that section: "Their power" is a different field, further down.
      expect(tester.getTopLeft(power.last).dy, greaterThan(tester.getTopLeft(find.text('Mode').last).dy));
      expect(tester.getTopLeft(power.last).dy, lessThan(tester.getTopLeft(find.text('Their info').last).dy));
    });

    testWidgets('the pane offers it while the app captures power, with the control out of the row', (tester) async {
      // Station Configuration's "Track Station Info" stamps the power on
      // every QSO. A value being logged that the entry cannot show is a value
      // nothing can correct.
      await tester.pumpWidget(host(radio: baseRadio().copyWith(trackingPower: true)));
      await tester.pump();
      expect(find.byIcon(MdiIcons.flash), findsNothing, reason: 'tracking is not the control');

      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();
      expect(find.text('Power'), findsWidgets);
    });

    testWidgets('the pane offers it for a record that carries one, though nothing tracks power', (tester) async {
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'power': 5,
      });
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();
      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();

      expect(find.text('Power'), findsWidgets);
    });

    testWidgets('the pane omits it when nothing tracks power and the QSO has none', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();

      expect(find.text('Power'), findsNothing);
    });

    testWidgets('a power typed into the pane reaches the logged QSO and the VFO', (tester) async {
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power'])));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();

      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Power'), '10');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tunedRadio.vfoA.power, 10, reason: 'a pane Save is a deliberate statement, like its frequency');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      final logged = await waitForQsos(tester, 1);
      expect(logged.single.power, 10);
    });

    testWidgets("a record's power survives a save that only corrected its RST", (tester) async {
      // The round-trip trap: with the control off, the field is the only
      // place the value lives while the record is open, so a gate that only
      // wrote power for a visible control would drop it here.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW', 'sent': '55'},
        'band': '20m',
        'mode': 'SSB',
        'power': 5,
      });
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '59');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.receivedRST, '59', reason: 'the edit was saved at all');
      expect(logged.single.power, 5);
    });

    testWidgets('a power from an edited record does not leak onto the next QSO', (tester) async {
      // Nothing is tracking power here, so the field is never re-seeded — a
      // value left in it after the edit closes would go on stamping every
      // contact logged afterwards, frozen at whatever that one record said.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'power': 5,
      });
      final key = GlobalKey();
      Widget at({Qso? editing}) => KeyedSubtree(key: key, child: host(session: LoggingSession(editingQso: editing)));

      await tester.pumpWidget(at(editing: existing));
      await tester.pump();
      await tester.pumpWidget(at());
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'K1ABC');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 2);
      expect(logged.firstWhere((q) => q.theirCall == 'K1ABC').power, isNull);
    });

    testWidgets('emptying the field clears a power off the record', (tester) async {
      // The map is merged over the stored QSO, so omitting the key when the
      // field is empty would leave the old value standing and a wrong power
      // could never be corrected — only overwritten.
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'power': 100,
      });
      await tester.pumpWidget(host(session: LoggingSession(editingQso: existing)));
      await tester.pump();
      await openControl(tester, MdiIcons.pencil);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Power'), '');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      // A second, visible edit, so the assertion below can't pass on a save
      // that never happened — an emptied field is not a value Enter can see.
      await tester.enterText(find.widgetWithText(TextField, 'Rcvd'), '59');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);

      final logged = await waitForQsos(tester, 1);
      expect(logged.single.receivedRST, '59', reason: 'the edit was saved at all');
      expect(logged.single.power, isNull);
    });

    testWidgets('switching the control on fills the field from the VFO', (tester) async {
      // The field only follows the VFO while power is in play, so the build
      // that turns it on is the one chance to catch up — otherwise the chip
      // reads "—" and a QSO logged before the next VFO change carries none.
      final radio = FakeVfoStore()
        ..setVfo('vfoA', freq: 14285, mode: 'SSB')
        ..setVfo('vfoA', power: 100);
      final key = GlobalKey();
      Widget at(List<String> order) => KeyedSubtree(key: key, child: host(
        radio: baseRadio().copyWith(radioService: radio),
        strip: ControlStripSettings(controlOrder: order),
      ));

      await tester.pumpWidget(at(const []));
      await tester.pump();
      await tester.pumpWidget(at(const ['time', 'radio', 'power']));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Power')).controller!.text, '100');
    });

    testWidgets('is offered beside Radio, not last, to an operator with a saved order', (tester) async {
      // Every operator who has ever saved the settings dialog has a stored
      // order, and a key missing from it used to be appended — so the one
      // control that ships off would arrive at the very end of the row, past
      // More, however deliberately the descriptor list placed it. The dialog
      // is where it's first seen, and where saving records the placement.
      await tester.pumpWidget(host(strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'more'])));
      await tester.pump();
      await tester.tap(find.byIcon(MdiIcons.cog));
      await tester.pumpAndSettle();

      // Inside the dialog's list, where each row is a ListTile — the chip
      // strip behind it carries labels of its own.
      double rowY(String label) =>
          tester.getTopLeft(find.ancestor(of: find.text(label), matching: find.byType(ListTile)).first).dy;
      expect(rowY('Power'), greaterThan(rowY('Radio')));
      expect(rowY('Power'), lessThan(rowY('More')));
    });

    testWidgets("editing a QSO shows its own power, and does not retune the radio", (tester) async {
      final radio = FakeVfoStore()
        ..setVfo('vfoA', freq: 14285, mode: 'SSB')
        ..setVfo('vfoA', power: 100);
      final existing = await qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'power': 5,
      });
      await tester.pumpWidget(host(
        session: LoggingSession(editingQso: existing),
        radio: baseRadio().copyWith(radioService: radio),
        strip: ControlStripSettings(controlOrder: const ['time', 'radio', 'power']),
      ));
      await tester.pump();
      await openControl(tester, MdiIcons.flash);

      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Power')).controller!.text, '5',
          reason: "a record's own power is what it was worked at, not what the rig is set to now");

      await tester.enterText(find.widgetWithText(TextField, 'Power'), '10');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(radio.vfoA.power, 100,
          reason: 'editing an existing QSO applies changes to the QSO, never the VFO');
    });
  });

  // The pane is seeded with the mode as the panel SHOWS it, not as the contact
  // stores it, and it can move the frequency underneath that. An untouched
  // `SSB` select therefore has to re-derive against where the contact now is:
  // skipping the write because the select "did not change" would keep 40m's
  // lower sideband on a contact the same save just moved to 20m, and the row
  // would then spell it out in red — correctly.
  testWidgets('a frequency changed in the More pane re-derives the sideband', (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'startAtMillis': 1000000,
          'freq': 7185,
          'mode': 'LSB',
        })))!;
    await tester.pumpWidget(host(session: LoggingSession(editingQso: existingQso)));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14250');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);

    expect(logged.single.freq, 14250);
    expect(logged.single.mode, 'USB');
  });

  // The mirror of the above: a sideband the operator chose deliberately, on a
  // band that does not run it, survives a save that touches nothing else. The
  // display spells that one out rather than collapsing it, which is exactly
  // what makes the round trip through the pane lossless.
  testWidgets('a deliberate far sideband survives an untouched save', (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'startAtMillis': 1000000,
          'freq': 7185,
          'mode': 'USB',
        })))!;
    await tester.pumpWidget(host(session: LoggingSession(editingQso: existingQso)));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Hiram');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);

    expect(logged.single.theirName, 'Hiram', reason: 'the save has to have happened to mean anything');
    expect(logged.single.mode, 'USB');
  });

  group('a band pick and the sideband', () {
    TextField modeField(WidgetTester tester) =>
        tester.widget<TextField>(find.widgetWithText(TextField, 'Mode'));

    // Picking a band re-derives the sideband, because a stored one was derived
    // from the band being left. The trap is the ORDER: clearing the frequency
    // field notifies `_onFreqChanged` synchronously, and its empty-field
    // branch pushes the VFO on the spot. That push STATES the mode, and
    // `RadioService.setVfo` takes a stated mode as stated — so a re-derive
    // that happens after the clear pins the old band's sideband onto the new
    // band at the rig, while the panel holds the new one. The next wipe
    // reseeds the panel from the rig, and every following contact is logged
    // and transmitted on the wrong sideband.
    testWidgets('the rig is told the same sideband the panel holds', (tester) async {
      final radio = FakeVfoStore()..setVfo('vfoA', freq: 14285, mode: 'SSB');
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: radio)));
      await openControl(tester, MdiIcons.radio);

      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '40m');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(radio.vfoA.band, '40m');
      expect(radio.vfoA.mode, 'LSB', reason: 'the rig kept the sideband of the band being left');
      // And the panel shows the collapsed spelling, not a red LSB.
      expect(modeField(tester).controller!.text, 'SSB');
    });

    // A sideband is derived from the BAND, so nothing about re-picking the
    // band you are already on makes a deliberate far sideband stale — and
    // `RadioControlModel.commitBandTypedIntoFreqField` re-picks unconditionally, by design.
    testWidgets('re-picking the band already selected keeps a deliberate far sideband', (tester) async {
      final radio = FakeVfoStore()..setVfo('vfoA', freq: 7185, mode: 'USB');
      await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: radio)));
      await openControl(tester, MdiIcons.radio);

      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '40m');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(modeField(tester).controller!.text, 'USB', reason: 'spelled out because 40m runs lower');
    });
  });

  // The `setVfo` command action stored whatever it was handed. It is the last
  // path that could put a generic `SSB` into a contact — and while editing an
  // existing QSO `_onRadioVfoChanged` returns early, so nothing downstream
  // would have corrected it before the contact was saved.
  testWidgets('a setVfo command resolves its mode like every other pick', (tester) async {
    Future<Map<String, dynamic>?> interpret(String input,
        [Map<String, dynamic>? a, Map<String, dynamic>? b, bool c = false]) async {
      if (input != 'FORTY') return null;
      return {
        'describe': 'Go to 40m?',
        'confirm': 'Done',
        'commands': [
          {
            'setVfo': {'freq': 7185, 'mode': 'SSB'},
          },
        ],
      };
    }

    await tester.pumpWidget(host(commands: CommandHooks(interpretCommand: interpret)));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'FORTY');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsos(tester, 1);

    expect(logged.single.mode, 'LSB');
  });

  // A contact stating neither a frequency nor a band is the one case with
  // nothing to collapse against — and so the one case where the collapse
  // cannot be undone on the way back in. Seeding the More pane with the
  // displayed `SSB` there would let an untouched save swap the stored
  // sideband for a generic mode the select does not even offer back.
  testWidgets('the More pane offers the stored sideband when nothing can re-derive it', (tester) async {
    final existingQso = (await tester.runAsync(() => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'startAtMillis': 1000000,
          'mode': 'LSB',
        })))!;
    await tester.pumpWidget(host(session: LoggingSession(editingQso: existingQso)));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();

    // The pane's Mode field is a select, so what it OFFERS is what shows.
    expect(find.text('LSB'), findsWidgets);
    expect(find.text('SSB'), findsNothing);
  });
}
