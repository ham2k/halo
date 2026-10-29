// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The keyboard path across the secondary controls: stepping out of the
// main fields into the pills, between pills, and back out of an open control.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  // ── The focus ladder: main fields ↔ secondary pills (APP-19) ─────────────
  //
  // The QSO-list rung sits in the app (LoggingPanel owns the list and the
  // selection), so it's exercised in app/test/logging_panel_keyboard_nav_test
  // — these cover everything the panel can answer on its own.
  group('keyboard navigation of the secondary controls', () {
    /// Which pill currently holds the keyboard, by control key — read off the
    /// chips' own focus nodes (`LoggingFocusLadder.pillFocusFor` labels them `pill:<key>`), so
    /// the assertions name a control rather than a widget index.
    String? focusedPill(WidgetTester tester) {
      for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
        final node = chip.focusNode;
        if (node != null && node.hasFocus) return node.debugLabel?.replaceFirst('pill:', '');
      }
      return null;
    }

    testWidgets('Arrow Up steps out of the main fields, opening the pill it lands on', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);

      // First time up, there's no remembered pill — the strip's first one —
      // and it opens immediately: no separate Enter needed, and the keyboard
      // moves straight into its own field rather than parking on the chip.
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)')).focusNode?.hasFocus, isTrue);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus, isFalse);
    });

    testWidgets('the keyboard walks past a disabled pill, both ways', (tester) async {
      // The keyer in a Digital mode sits right after Radio. A disabled chip
      // takes no focus and its control refuses to open, so a walk that
      // stopped there would leave the keyboard stuck in Radio, every Tab and
      // every Right eaten on the same spot.
      await tester.pumpWidget(
        host(
          strip: ControlStripSettings(
            controlOrder: const ['time', 'radio', 'keyer', 'more'],
            hostControls: [
              HostControl(
                key: 'keyer',
                icon: MdiIcons.key,
                label: 'Keyer',
                spec: () =>
                    SecondaryControlSpec(key: 'keyer', icon: MdiIcons.key, summary: 'Keyer', enabled: false, expandedBuilder: (_) => const Text('keyer panel')),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);
      // Time's two fields, then Radio's three (its dropdowns take the
      // keyboard on a desktop only).
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await settleControl(tester);
      }
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).focusNode?.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      expect(focusedPill(tester), 'more', reason: 'Tab off Radio skips the disabled keyer');
      expect(find.widgetWithText(TextField, 'Mode'), findsNothing, reason: 'and Radio closed behind it');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget, reason: 'Left off More skips it the other way');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Tab and Shift-Tab cross between pills, opening whichever one they land on', (tester) async {
      // Tab bypasses Flutter's own default traversal entirely now (it broke
      // once a field could auto-open under it — probed with a real test run,
      // `primaryFocus` came back null instead of the next chip) — this is a
      // panel-owned crossing, symmetric with Left/Right below.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);

      // Tab first walks Time's own second field (Date) — see the dedicated
      // multi-field test below — then crosses. Two Tabs clear Time entirely.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsNothing);
      expect(
        find.widgetWithText(TextField, 'Band'),
        findsOneWidget,
        reason: 'crossing in from Tab lands on the FIRST field, not the one a tap opens into (Frequency)',
      );
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).focusNode?.hasFocus, isTrue);

      // Two more Tabs step through Radio's remaining fields (Frequency,
      // Mode) — plain within-control moves, no control opens or closes —
      // and a third crosses off the end onto More, which pops a dialog
      // rather than expanding, so arriving there leaves the keyboard on its
      // bare chip.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).focusNode?.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      expect(focusedPill(tester), 'more');
      expect(find.widgetWithText(TextField, 'Band'), findsNothing);

      // Shift-Tab reverses: off the front of More (nothing to walk within
      // it) crosses back to Radio, landing on its LAST field (Mode).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Mode'), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).focusNode?.hasFocus, isTrue);
      // Band/Mode only accept keyboard focus on desktop (see the Radio spec's
      // own `typeable` gate) — same restriction every other Band/Mode
      // keyboard test in this file runs under.
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Tab steps through a control\'s own fields before crossing to the next pill', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)')).focusNode?.hasFocus, isTrue);

      // Time has two fields (Time, Date) — Tab walks to the second before
      // it ever considers leaving for Radio.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget, reason: 'still on Time, its own 2nd field');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Date')).focusNode?.hasFocus, isTrue);

      // Off the end of Time's own fields, Tab crosses to Radio — its FIRST
      // field (Band), then walks Band → Frequency → Mode before crossing
      // onward again.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).focusNode?.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).focusNode?.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      expect(focusedPill(tester), 'more', reason: 'off the end of Radio\'s own fields, More has none to walk into');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a cursor key crosses to the next control\'s own canonical field, once at the edge of the value', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      await tester.enterText(find.widgetWithText(TextField, 'Frequency'), '14074');
      await tester.pump();
      final freqController = tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).controller!;

      // Caret in the middle of the typed value: Right is an ordinary caret
      // move, same as any text field — it must not cross to another control.
      freqController.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget, reason: 'still in Frequency, mid-value');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus, isTrue);

      // Caret at the end: Right now crosses out — straight to the next
      // pill, skipping any sibling field within Radio (Mode is Tab's stop,
      // not a cursor key's).
      freqController.selection = TextSelection.collapsed(offset: freqController.text.length);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleControl(tester);
      expect(focusedPill(tester), 'more');
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);

      // Left from the bare chip is unconditional (nothing to be "at the
      // edge" of), wrapping back to Radio's own canonical field — Frequency
      // again, not Mode (which is where Shift-Tab would have landed).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settleControl(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus, isTrue);

      // And Left at the very START of Frequency's value crosses backward
      // past Radio entirely, landing on Time's own canonical field (Time),
      // not its last field (Date), which is where Shift-Tab would land.
      freqController.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settleControl(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Time (UTC)')).focusNode?.hasFocus, isTrue);
    });

    testWidgets('Arrow Up from inside an auto-opened control closes it and selects from the QSO list', (tester) async {
      // Up used to stop at the main field, same as Down/Enter/Escape — now it
      // keeps going, the same direction Up already takes from a bare pill.
      var handedOver = 0;
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            onNavigateToQsoList: () {
              handedOver++;
              return true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);

      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing, reason: 'the control closed');
      expect(handedOver, 1);
      // Landing in the list itself is the host's job (it owns the list and
      // its selection) — this only proves the control closed and asked.
    });

    testWidgets('Arrow Up from inside a control falls back to the main fields when nothing is navigable', (tester) async {
      // A brand-new operation, or a host with no list at all: the callback
      // reports it couldn't hand off, so this control's own field (which
      // just closed) doesn't leave the keyboard stranded on nothing.
      await tester.pumpWidget(host(session: LoggingSession(onNavigateToQsoList: () => false)));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Frequency')).focusNode?.hasFocus,
        isTrue,
        reason: 'precondition: Up has to actually originate from inside the open control',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);

      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing, reason: 'the control still closed');
      expect(
        tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus,
        isTrue,
        reason: 'falls back to a main field instead of leaving focus nowhere',
      );
    });

    testWidgets('Down out of an open control closes it and returns to the main field', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      // Down used to stop at the pill the control opened from; now there's no
      // pill stop on the way out either — Down goes straight back to the main
      // field the operator was in, same as Escape.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
      expect(focusedPill(tester), isNull, reason: 'no pill stop on the way out anymore');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus, isTrue);
    });

    testWidgets('Enter out of an open control closes it too, back to the main field', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      // Enter no longer opens a control from inside its own field — only
      // arriving on the pill does that now — so here it's the other half of
      // the same close gesture Down and Escape are.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus, isTrue);
    });

    testWidgets('Escape in an open control closes it and goes back to the main fields', (tester) async {
      // Where Down and Enter used to stop at the pill, Escape has always been
      // the "out of here entirely" gesture — one press puts the operator back
      // where they were typing. It must not reach the layers below it either:
      // the composed callsign is still there afterwards, not wiped.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Sent'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleControl(tester);

      expect(find.widgetWithText(TextField, 'Frequency'), findsNothing);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).focusNode?.hasFocus, isTrue);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');
    });

    testWidgets('Escape after auto-opening a pill returns to the main fields without wiping the form', (tester) async {
      // Pills only became focusable with the ladder, so Escape had never had
      // to mean anything there — and the panel-wide handler would have read a
      // merely-parked keyboard as a cue to wipe a half-typed contact.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleControl(tester);

      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsNothing);
      expect(focusedPill(tester), isNull);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');
    });

    testWidgets('Enter closes an activity ref control too, and logs nothing (APP-19)', (tester) async {
      // Every secondary control loses Enter-to-log, not just Radio — and the
      // ref controls got there by a different route (no `onSubmitted` of their
      // own; their Enter reached the panel's root shortcut and logged). This
      // is the POTA-shaped case: type a reference, press Enter, and the
      // control closes with the QSO still unlogged in the form.
      const potaControl = {
        'key': 'pota/hunter',
        'label': 'POTA',
        'icon': 'pine-tree',
        'input': {'kind': 'refList', 'refType': 'pota', 'pattern': r'[A-Z0-9]+-[0-9]{4,5}'},
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoggingControls(
              log: baseLog(),
              radio: baseRadio(),
              activities: ActivityHooks(activityControls: const [potaControl]),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Their call'), 'W1AW');
      await tester.pump();
      await openControl(tester, MdiIcons.pineTree);
      await tester.enterText(find.widgetWithText(TextField, 'POTA'), 'US-1234');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'POTA'), findsNothing, reason: 'the control closed');
      expect(
        await tester.runAsync(() => qsos.watchForOperation(operation.uuid).first),
        isEmpty,
        reason: 'Enter on the way out of a control must not log the QSO',
      );
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).controller!.text, 'W1AW');
    });

    testWidgets('a held modifier leaves an open control alone', (tester) async {
      // The ladder claims bare keys only. Cmd/Ctrl/Option combinations are
      // platform gestures (Cmd+Down is "caret to the end of the text" on
      // macOS) and Shift+arrow is a text selection — stealing either would
      // teleport the operator out of the field they are typing in. Same rule
      // the entry row's own handler applies; these two rungs must not differ.
      await tester.pumpWidget(host());
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await openControl(tester, MdiIcons.radio);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      // Inside the open control's own field: Cmd+Down must not close it,
      // and Cmd+Right must not cross fields either.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget, reason: 'Cmd+Down/Right are caret/platform gestures, not a way out of the control');

      // Shift+Down is a selection gesture, and must not close it either.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Frequency'), findsOneWidget);

      // On a bare, fieldless pill (More): Cmd+Left must not walk the strip
      // either. Two Tabs clear Radio's remaining fields (Frequency, Mode).
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleControl(tester);
      expect(focusedPill(tester), 'more');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pump();
      expect(focusedPill(tester), 'more', reason: 'Cmd+Left belongs to the platform');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Arrow Down out of an auto-opened control returns to the field the operator was last in', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      // Sent, not Call — the point is that the ladder remembers where you
      // left, rather than always dropping you back at the start of the row.
      await tester.tap(find.widgetWithText(TextField, 'Sent'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);
      expect(find.widgetWithText(TextField, 'Time (UTC)'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleControl(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sent')).focusNode?.hasFocus, isTrue);
    });

    testWidgets('Arrow Up from a bare pill hands the keyboard on to the QSO list', (tester) async {
      // More is the one pill that stays chip-focused rather than opening —
      // reachable via Tab/cursor-key crossing (see the tests above), and the
      // one place Up still means "leave the strip upward" in a single step,
      // the way it already did before any control could auto-open.
      var handedOver = 0;
      await tester.pumpWidget(
        host(
          session: LoggingSession(
            onNavigateToQsoList: () {
              handedOver++;
              return true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(TextField, 'Their call'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settleControl(tester);
      // Left won't reach More from here: Up landed the caret at the END of
      // Time's value (cursor-at-end-on-focus), not the start, so Left is
      // just an ordinary caret move. Shift-Tab crosses unconditionally,
      // off the front of Time's own fields, wrapping to More.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settleControl(tester);
      expect(focusedPill(tester), 'more');
      expect(handedOver, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(handedOver, 1);
      // The panel doesn't move focus itself — the host owns the list, and
      // decides whether there is anything up there to walk onto at all.
      expect(focusedPill(tester), 'more');
    });
  });
}
