// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The panel's Radio control and everything the rig drives: seeding from the
// VFO, following a connected radio, the Station Configuration button, and
// the sideband a frequency resolves to. The Band and Mode menus, the reports
// a mode implies, and Power are beside this file.

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

  testWidgets('tapping the radio name opens Station Configuration too, unless there is none to show', (tester) async {
    await tester.pumpWidget(host());
    await openControl(tester, MdiIcons.radio);
    expect(find.text('Icom IC-705'), findsNothing);

    var opened = false;
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(hasConfiguredRadio: true, radioName: 'Icom IC-705', onOpenStationConfig: () => opened = true),
      ),
    );
    expect(find.text('Icom IC-705'), findsOneWidget);
    await tester.tap(find.text('Icom IC-705'));
    expect(opened, isTrue);
  });

  testWidgets('a long radio name takes the room the row has, on one line, ellipsized past it', (tester) async {
    // The trap: a name held to a few icons' width reads "A Radio W…" in a
    // panel with room for all of it. It may grow — but only into the row
    // it is given, never wrapping and never pushing past the panel.
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(hasConfiguredRadio: true, radioName: 'A Radio With A Genuinely Absurd Amount Of Name', onOpenStationConfig: () {}),
      ),
    );
    await openControl(tester, MdiIcons.cat);

    final button = find.byKey(const ValueKey('stationConfigButton'));
    final icon = tester.widget<Icon>(find.descendant(of: button, matching: find.byIcon(MdiIcons.cat)));
    final name = find.descendant(of: button, matching: find.byType(Text));
    expect(tester.getSize(name).width, greaterThan(icon.size! * 3), reason: 'the name is not held to three icons when the row has room');

    final text = tester.widget<Text>(name);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
    expect(tester.takeException(), isNull, reason: 'growing must stay inside the row, never overflow it');
  });

  testWidgets('the plug beside the cat connects the radio, and only when there is one to connect', (tester) async {
    var connects = 0;
    var opens = 0;
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(hasConfiguredRadio: true, onOpenStationConfig: () => opens++, onConnectRadio: () => connects++),
      ),
    );
    await openControl(tester, MdiIcons.cat);

    final plug = find.byKey(const ValueKey('connectRadioButton'));
    expect(plug, findsOneWidget);
    // Inside the Station Configuration button, so its own tap must win:
    // a plug that opened the dialog would do the one thing the cat does.
    await tester.tap(plug);
    await tester.pump();
    expect(connects, 1);
    expect(opens, 0);
    // Not one of Radio's fields, same as the cat around it.
    expect(tester.widget<InkWell>(plug).canRequestFocus, isFalse);
  });

  testWidgets('no plug without a way to connect — connected, or a radio this device cannot reach', (tester) async {
    await tester.pumpWidget(host(radio: baseRadio().copyWith(hasConfiguredRadio: true, onOpenStationConfig: () {})));
    await openControl(tester, MdiIcons.cat);
    expect(find.byKey(const ValueKey('connectRadioButton')), findsNothing);
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
    final icon = tester.widget<Icon>(find.descendant(of: find.byKey(const ValueKey('stationConfigButton')), matching: find.byIcon(MdiIcons.cat)));
    return icon.color!;
  }

  testWidgets('Station Configuration button colors: unconfigured, configured, connected', (tester) async {
    final theme = ThemeData(useMaterial3: true);

    // No radio configured — a lighter tint of the row's own background,
    // barely there. The button still opens the dialog (that's where an
    // operator with nothing configured yet would go to add one).
    var opened = false;
    await tester.pumpWidget(
      host(
        appTheme: theme,
        radio: baseRadio().copyWith(onOpenStationConfig: () => opened = true),
      ),
    );
    await openControl(tester, MdiIcons.radio);
    expect(stationConfigButtonColor(tester), Color.lerp(theme.colorScheme.tertiary, Colors.white, 0.4));
    await tester.tap(find.byKey(const ValueKey('stationConfigButton')));
    expect(opened, isTrue);

    // Still expanded — State survives a same-shaped pumpWidget. Configured
    // but not connected now reads red — lighter than the scheme's own error
    // color, which reads under 3:1 against this row's dark amber `tertiary`
    // fill (the accent color, not a pastel container).
    await tester.pumpWidget(
      host(
        appTheme: theme,
        radio: baseRadio().copyWith(hasConfiguredRadio: true, onOpenStationConfig: () {}),
      ),
    );
    expect(stationConfigButtonColor(tester), const Color(0xFFFF8A80));

    // Connected — a lighter green than _noticePill's, same contrast reasoning.
    await tester.pumpWidget(
      host(
        appTheme: theme,
        radio: baseRadio().copyWith(hasConfiguredRadio: true, radioConnected: true, onOpenStationConfig: () {}),
      ),
    );
    expect(stationConfigButtonColor(tester), const Color(0xFF81C784));
  });

  // The same `iconColor` renders on two different fills (colorScheme
  // .tertiary when selected/expanded, the lighter HaLoColors.tertiaryLight
  // otherwise) — which one is actually darker flips between light and dark
  // mode, so the color has to flip with `selected`, not just with the theme.
  Color pillIconColor(WidgetTester tester) =>
      (tester.widget<ChoiceChip>(find.ancestor(of: find.byIcon(MdiIcons.cat), matching: find.byType(ChoiceChip))).avatar as Icon).color!;

  testWidgets('the Radio pill icon color flips between selected and unselected: light mode', (tester) async {
    final theme = ThemeData(useMaterial3: true);
    await tester.pumpWidget(
      host(
        appTheme: theme,
        radio: baseRadio().copyWith(hasConfiguredRadio: true, onOpenStationConfig: () {}),
      ),
    );
    expect(pillIconColor(tester), const Color(0xFFB71C1C)); // unselected: on the bright tan fill
    await openControl(tester, MdiIcons.cat);
    expect(pillIconColor(tester), const Color(0xFFFF8A80)); // selected: on the dark tertiary fill
  });

  testWidgets('the Radio pill icon color flips between selected and unselected: dark mode', (tester) async {
    final theme = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    await tester.pumpWidget(
      host(
        appTheme: theme,
        radio: baseRadio().copyWith(hasConfiguredRadio: true, onOpenStationConfig: () {}),
      ),
    );
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
      ),
    );
    await openControl(tester, MdiIcons.cat);
    // The cell an operator actually sits in — rig connected, Radio control
    // open — and the one that reaches for a SHARED constant most naturally.
    // [positiveGreen] is tuned for its own dark fills and reads 1.97:1 on the
    // amber this cell paints on, so taking it here would be invisible and
    // would look like reuse rather than a mistake.
    expect(pillIconColor(tester), const Color(0xFF005A00));
  });

  testWidgets('the Station Configuration button is disabled while editing an existing QSO', (tester) async {
    final existingQso = (await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'startAtMillis': 1000000,
        'freq': 7100,
        'mode': 'SSB',
      }),
    ))!;
    await tester.pumpWidget(
      host(
        session: LoggingSession(editingQso: existingQso),
        radio: baseRadio().copyWith(hasConfiguredRadio: true, radioConnected: true, onOpenStationConfig: () {}),
      ),
    );
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
      expect(find.widgetWithText(TextField, t.loggingControls.frequency), findsOneWidget, reason: 'an unset VFO should have opened the Radio control on mount');
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

      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing, reason: 'nothing is missing, so nothing should pop open');
    });

    testWidgets('the refusal speaks the operator\'s language', (tester) async {
      // Every other assertion on this message is English, which a hardcoded
      // literal would satisfy — this one is what fails if the refusal stops
      // reading the strings package.
      await useSpanish(tester);
      final messages = <String?>[];
      await tester.pumpWidget(
        host(
          radio: baseRadio().copyWith(radioService: fakeRadio),
          commands: CommandHooks(onCommandMessageChanged: messages.add),
        ),
      );
      await dismissRadioControl(tester);
      await tester.enterText(find.widgetWithText(TextField, t.loggingControls.theirCall), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 300));
      expect(messages.last, t.loggingControls.bandOrFreqRequired);
    });

    testWidgets('refuses the contact, says so, and opens the Radio control to ask', (tester) async {
      final messages = <String?>[];
      await tester.pumpWidget(
        host(
          radio: baseRadio().copyWith(radioService: fakeRadio),
          commands: CommandHooks(onCommandMessageChanged: messages.add),
        ),
      );
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
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus, isTrue);
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
      final existingQso = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW'},
          'startAtMillis': 1000000,
        }),
      ))!;
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: existingQso),
          radio: baseRadio().copyWith(radioService: fakeRadio),
        ),
      );
      await tester.pump();

      await submit(tester, 'W1AWX');

      // An edit never adds a row, so this runs the whole budget — the time a
      // save that was not refused would take to show up.
      final logged = await qsosAfterWaiting(tester, watchFor: 2);
      expect(logged, hasLength(1), reason: 'still just the original record');
      expect(logged.single.theirCall, 'W1AW', reason: 'the edit must not be saved while the contact has neither band nor frequency');
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
    });

    // Being asked for a band must not trap a contact that the operator is
    // trying to get rid of — the guard sits below the delete branch.
    testWidgets('a bandless contact can still be deleted without first being repaired', (tester) async {
      // Shaped like the records the wipe/delete group uses: the second button
      // only offers *delete* while the loaded QSO still matches the fields, so
      // the fixture has to carry what the controls populate from it.
      final existingQso = (await tester.runAsync(
        () => qsos.add(operation.uuid, {
          'their': {'call': 'W1AW', 'sent': ''},
          'our': {'call': 'KI2D', 'sent': '59'},
          'mode': 'SSB',
          'startAtMillis': 1000000,
        }),
      ))!;
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: existingQso, onEditCanceled: () {}),
          radio: baseRadio().copyWith(radioService: fakeRadio),
        ),
      );
      await tester.pump();

      // Stage the delete (the second button becomes "delete" for an
      // unmodified QSO), then confirm it with the submit button, which turns
      // into a solid trash can while a delete is staged. The button rather
      // than Enter: tapping the staging button took the text field's input
      // connection with it, and this test is about the guard's placement.
      await tester.tap(find.byIcon(MdiIcons.trashCanOutline));
      await tester.pump();
      expect(find.textContaining('one more time to delete'), findsOneWidget, reason: 'the delete is staged');
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
      Future<Map<String, dynamic>?> clearsTheMode(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async =>
          input.toUpperCase() == 'NOMODE'
          ? {
              'describe': 'Clear the mode?',
              'confirm': 'Mode cleared',
              'commands': [
                {
                  'setVfo': {'mode': ''},
                },
              ],
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
      Future<Map<String, dynamic>?> clearsTheMode(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async =>
          input.toUpperCase() == 'NOMODE'
          ? {
              'describe': 'Clear the mode?',
              'confirm': 'Mode cleared',
              'commands': [
                {
                  'setVfo': {'mode': ''},
                },
              ],
            }
          : null;

      // Below this the entry row itself overflows, which would mask what this
      // test is watching rather than sharpen it.
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Spanish spells both pills long — the case the Wrap exists for.
      await useSpanish(tester);
      await tester.pumpWidget(
        host(
          radio: baseRadio().copyWith(radioService: fakeRadio),
          commands: CommandHooks(interpretCommand: clearsTheMode),
        ),
      );
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

    // The pill rides above whatever the area shows and is part of the same
    // tap target: the panel's wiring decides which host callback a press
    // reaches by what is in hand, so a wiring that gated the gesture on the
    // content would leave the pill dead.
    testWidgets('tapping the pill opens the operation info with no call, the station\'s detail with one', (tester) async {
      var callOpened = 0, operationOpened = 0;
      await tester.pumpWidget(
        host(
          radio: baseRadio().copyWith(radioService: fakeRadio),
          lookups: LookupHooks(onCallInfoTap: () => callOpened++, onOperationInfoTap: () => operationOpened++),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('No Band'));
      await tester.pump();
      expect((callOpened, operationOpened), (0, 1), reason: 'nothing in the field: the operation is what there is');

      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('No Band'));
      await tester.pump();
      expect((callOpened, operationOpened), (1, 1));

      await tester.tap(find.byIcon(MdiIcons.account));
      await tester.pump();
      expect((callOpened, operationOpened), (2, 1), reason: 'the call-info content is the same target');
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
      await tester.pumpWidget(
        host(
          session: LoggingSession(editingQso: note, onEditCanceled: () {}),
          radio: baseRadio().copyWith(radioService: fakeRadio),
        ),
      );
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

  testWidgets('HALO-32: a radio-driven frequency-only update (no mode of its own) never runs the band-plan mode guess', (tester) async {
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

  testWidgets('a radio update does not overwrite a frequency the operator is part-way through typing', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(host(radio: baseRadio().copyWith(radioService: fakeRadio)));
    await openControl(tester, MdiIcons.radio);

    // Two digits: too short to arm the push debounce, so the debounce alone
    // is not what protects this — the dirty flag is.
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '71');
    await tester.pump();

    fakeRadio.setVfo('vfoA', freq: 21000, mode: 'CW');
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text,
      '71',
      reason: 'the operator was mid-entry — their intent is newer than the radio',
    );
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

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '71', reason: 'their entry is newer');
    // The whole seed used to be suppressed, so the mode was dropped — and
    // the pending push then sent the panel's stale SSB back at the rig,
    // taking it out of CW and logging the QSO as USB at 59.
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).decoration!.hintText, '599');

    await tester.pump(const Duration(seconds: 6));
    expect(fakeRadio.vfoA.mode, 'CW', reason: 'the push must not undo the mode change');
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
          session: LoggingSession(editingQso: editing),
          radio: RadioHookup(radioService: fakeRadio, radioUpdates: updates),
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
    await tester.pumpWidget(
      host(
        session: LoggingSession(editingQso: existingQso),
        radio: baseRadio().copyWith(radioService: fakeRadio),
      ),
    );
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '7040');

    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpAndSettle();

    // A logged QSO records where it actually happened; ambient radio state
    // must not rewrite it.
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '7040');
  });

  testWidgets('a brand new operation sees the same vfoA as any other — it is not per-operation', (tester) async {
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'CW');
    final freshOperation = await operations.create(stationCall: 'KI2D');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoggingControls(
            log: LogHooks(operation: freshOperation, qsosRepository: qsos),
            radio: RadioHookup(radioService: fakeRadio),
          ),
        ),
      ),
    );
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
    await tester.pumpWidget(
      host(
        session: LoggingSession(editingQso: existingQso),
        radio: baseRadio().copyWith(radioService: fakeRadio),
      ),
    );
    await openControl(tester, MdiIcons.radio);

    final freqField = tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency'));
    expect(freqField.controller!.text, '7100');
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
    await tester.pumpWidget(
      host(
        session: LoggingSession(editingQso: existingQso),
        radio: baseRadio().copyWith(radioService: fakeRadio),
      ),
    );
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
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio),
        commands: CommandHooks(interpretCommand: fakeInterpretCommand),
      ),
    );

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

  testWidgets('an open Radio control on an untuned station shows no band once an edit ends', (tester) async {
    // The Band dropdown's text follows the model only when it is rewritten
    // wholesale. Left showing the edited contact's band over an entry that
    // has none, the control says the next contact will log on 40m when the
    // log is about to be refused for having no band at all.
    final existingQso = Qso(
      uuid: 'existing-uuid',
      operationUuid: operation.uuid,
      data: {
        'their': {'call': 'W1AW'},
        'band': '40m',
        'mode': 'CW',
      },
    );
    final editing = ValueNotifier<Qso?>(existingQso);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<Qso?>(
            valueListenable: editing,
            builder: (context, editingQso, _) => LoggingControls(
              log: baseLog(),
              session: LoggingSession(editingQso: editingQso, onEditCanceled: () => editing.value = null),
              radio: RadioHookup(radioService: fakeRadio),
            ),
          ),
        ),
      ),
    );
    String band() => tester.widget<TextField>(find.widgetWithText(TextField, 'Band').first).controller!.text;
    await openControl(tester, MdiIcons.radio);
    expect(band(), '40m');

    editing.value = null;
    await settleControl(tester);
    expect(band(), isEmpty);
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<Qso?>(
            valueListenable: editing,
            builder: (context, editingQso, _) => LoggingControls(
              log: baseLog(),
              session: LoggingSession(editingQso: editingQso, onEditCanceled: () => editing.value = null),
              radio: RadioHookup(radioService: fakeRadio),
            ),
          ),
        ),
      ),
    );
    await openControl(tester, MdiIcons.radio);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '7100');

    // The control stays open across the edit's end, so the field on screen
    // is the one that has to follow the VFO.
    editing.value = null;
    await settleControl(tester);

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!.text, '14285');
  });

  // The pane is seeded with the mode as the panel SHOWS it, not as the contact
  // stores it, and it can move the frequency underneath that. An untouched
  // `SSB` select therefore has to re-derive against where the contact now is:
  // skipping the write because the select "did not change" would keep 40m's
  // lower sideband on a contact the same save just moved to 20m, and the row
  // would then spell it out in red — correctly.
  testWidgets('a frequency changed in the More pane re-derives the sideband', (tester) async {
    final existingQso = (await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'startAtMillis': 1000000,
        'freq': 7185,
        'mode': 'LSB',
      }),
    ))!;
    await tester.pumpWidget(host(session: LoggingSession(editingQso: existingQso)));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14250');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsosWhere(tester, 'the edited frequency', (logged) => logged.single.freq == 14250);

    expect(logged.single.freq, 14250);
    expect(logged.single.mode, 'USB');
  });

  // The mirror of the above: a sideband the operator chose deliberately, on a
  // band that does not run it, survives a save that touches nothing else. The
  // display spells that one out rather than collapsing it, which is exactly
  // what makes the round trip through the pane lossless.
  testWidgets('a deliberate far sideband survives an untouched save', (tester) async {
    final existingQso = (await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'startAtMillis': 1000000,
        'freq': 7185,
        'mode': 'USB',
      }),
    ))!;
    await tester.pumpWidget(host(session: LoggingSession(editingQso: existingQso)));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Hiram');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final logged = await waitForQsosWhere(tester, 'the edited name', (logged) => logged.single.theirName == 'Hiram');

    expect(logged.single.mode, 'USB');
  });

  group('a band pick and the sideband', () {
    TextField modeField(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Mode'));

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
    Future<Map<String, dynamic>?> interpret(String input, [Map<String, dynamic>? a, Map<String, dynamic>? b, bool c = false]) async {
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
    final existingQso = (await tester.runAsync(
      () => qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'startAtMillis': 1000000,
        'mode': 'LSB',
      }),
    ))!;
    await tester.pumpWidget(host(session: LoggingSession(editingQso: existingQso)));

    await tester.tap(find.byIcon(MdiIcons.pencil), warnIfMissed: false);
    await tester.pumpAndSettle();

    // The pane's Mode field is a select, so what it OFFERS is what shows.
    expect(find.text('LSB'), findsWidgets);
    expect(find.text('SSB'), findsNothing);
  });
}
