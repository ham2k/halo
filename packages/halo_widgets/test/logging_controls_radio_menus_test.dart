// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Radio control's Band and Mode menus: what they offer, how they size
// against the fields beside them, typing to filter, the arrow keys, Enter
// and blur committing a pick, and a mouse click on an entry.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();
  mousePickTests();

  testWidgets('Radio dropdowns offer the settings-enabled bands/modes, uncolored, plus the current value', (tester) async {
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(enabledBands: ['40m', '20m'], enabledModes: ['CW', 'FT8']),
      ),
    );
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

  testWidgets('empty enabled lists fall back to the common tier — deselecting every band must not empty the dropdown', (tester) async {
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(enabledBands: [], enabledModes: []),
      ),
    );
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
        expect(contrastRatio(side!.color, theme.colorScheme.surface), greaterThanOrEqualTo(3.0), reason: '$brightness');
        // The same underline poloFieldDecoration gives the Frequency field
        // beside it — these must not diverge into two focus cues in one row.
        // (Both sides move together if the helper changes; what this catches is
        // the dropdowns drifting away from it, not the helper going wrong.)
        expect(side.color, haloFocusedInputBorder(brightness == Brightness.dark).borderSide.color, reason: '$brightness');
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
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m', '17m']),
      ),
    );
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
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m']),
      ),
    );
    await openControl(tester, MdiIcons.radio);

    // Band is deliberately out of the panel's own Tab/cursor-key cycle (it's
    // a mouse/type-to-filter control, not a keyboard-traversal stop), so
    // this focuses it directly rather than tabbing in — a tap would open
    // the menu, which the closed-menu arrow path here needs to avoid.
    tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).focusNode!.requestFocus();
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).focusNode!.hasFocus, isTrue);
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
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8']),
      ),
    );
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
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m', '2m']),
      ),
    );
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
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m']),
      ),
    );
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
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode?.hasFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('arrow keys keep a typed filter while walking the open menu', (tester) async {
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']),
      ),
    );
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
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8']),
      ),
    );
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
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']),
      ),
    );
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
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledBands: ['80m', '40m', '20m']),
      ),
    );
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
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']),
      ),
    );
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
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']),
      ),
    );
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

    await tester.pumpWidget(
      host(
        session: LoggingSession(
          suggestedQso: const {
            'their': {'call': 'W1AW'},
            'freq': 14074.0,
            'mode': 'FT8',
          },
        ),
        radio: baseRadio().copyWith(enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']),
      ),
    );
    await tester.pump();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a rig restating the mode it is already on leaves the operator typing alone', (tester) async {
    // The other half of the contract, and the one a blunter fix breaks: a
    // connected radio notifies constantly. Only a mode that actually MOVED
    // may take the field back — a VFO update that changes nothing else must
    // not wipe a filter mid-word.
    fakeRadio.setVfo('vfoA', freq: 14285, mode: 'SSB');
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8', 'FT4', 'FM']),
      ),
    );
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

    final menuScrollable = find.ancestor(of: find.widgetWithText(MenuItemButton, '2190m').last, matching: find.byType(Scrollable));
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
}

// A mouse click is a pointer down, frames, then a pointer up. On desktop
// the pointer DOWN on a menu entry is a tap outside the text field, which
// unfocuses it; a blur that closes the menu then removes the entry before
// the pointer UP can select it. `tester.tap` sends both events with no frame
// between, so only a gesture with a pump in the middle can catch this.
Future<void> clickAcrossAFrame(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder), kind: PointerDeviceKind.mouse);
  await tester.pump();
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}

void mousePickTests() {
  testWidgets('a mouse click on a Mode entry selects it when the field was focused by a click on its text', (tester) async {
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8']),
      ),
    );
    await openControl(tester, MdiIcons.radio);

    // A click on the field's text, not its arrow: this is the path that
    // leaves the text field itself focused while the menu is open.
    await clickAcrossAFrame(tester, find.widgetWithText(TextField, 'Mode'));
    expect(find.widgetWithText(MenuItemButton, 'CW').hitTestable(), findsOneWidget);

    await clickAcrossAFrame(tester, find.widgetWithText(MenuItemButton, 'CW').hitTestable());
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');
    expect(fakeRadio.vfoA.mode, 'CW');
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a mouse click on a Band entry selects it when the field was focused by a click on its text', (tester) async {
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledBands: ['40m', '20m', '15m']),
      ),
    );
    await openControl(tester, MdiIcons.radio);

    await clickAcrossAFrame(tester, find.widgetWithText(TextField, 'Band'));
    expect(find.widgetWithText(MenuItemButton, '40m').hitTestable(), findsOneWidget);

    await clickAcrossAFrame(tester, find.widgetWithText(MenuItemButton, '40m').hitTestable());
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Band')).controller!.text, '40m');
    expect(fakeRadio.vfoA.band, '40m');
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a mouse click on the entry a typed filter left showing selects that entry', (tester) async {
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8']),
      ),
    );
    await openControl(tester, MdiIcons.radio);

    await clickAcrossAFrame(tester, find.widgetWithText(TextField, 'Mode'));
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'F');
    await tester.pump();
    expect(find.widgetWithText(MenuItemButton, 'FT8').hitTestable(), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'SSB').hitTestable(), findsNothing);

    // The pointer down blurs the field. A commit that clears the filter
    // there re-expands the menu under the still-pressed pointer, and the
    // release then lands on whichever entry now sits at that spot.
    await clickAcrossAFrame(tester, find.widgetWithText(MenuItemButton, 'FT8').hitTestable());
    expect(fakeRadio.vfoA.mode, 'FT8');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'FT8');
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('typed Mode text a press released off the entry left behind commits on the next click elsewhere', (tester) async {
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8']),
      ),
    );
    await openControl(tester, MdiIcons.radio);

    await clickAcrossAFrame(tester, find.widgetWithText(TextField, 'Mode'));
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'C');
    await tester.pump();

    // The press blurs the field; sliding off the entry before releasing
    // picks nothing, and the blur held its commit back for a pick that
    // never came. The field is unfocused with 'C' in it and the menu up.
    final entry = find.widgetWithText(MenuItemButton, 'CW').hitTestable();
    final gesture = await tester.startGesture(tester.getCenter(entry), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(fakeRadio.vfoA.mode, isNot('CW'), reason: 'test setup: nothing picked and nothing committed yet');

    // The click that closes the menu is the last event this text will ever
    // get — without a commit riding on it, the field reads 'C' and the QSO
    // logs the old mode.
    await clickAcrossAFrame(tester, find.widgetWithText(TextField, 'Frequency'));
    expect(fakeRadio.vfoA.mode, 'CW');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the arrow opens the Mode menu while the field itself holds focus', (tester) async {
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8']),
      ),
    );
    await openControl(tester, MdiIcons.radio);

    // A click on the text opens the menu with the field focused; Escape
    // closes the menu and leaves the focus where it was.
    await clickAcrossAFrame(tester, find.widgetWithText(TextField, 'Mode'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).focusNode!.hasFocus, isTrue, reason: 'test setup: Escape keeps the field focused');

    // Opening by the arrow hands focus to a node of the dropdown's own.
    // Read as focus LEAVING the field, that blur closes the menu the same
    // click just opened.
    final arrow = find.descendant(of: find.widgetWithText(DropdownMenu<String>, 'Mode'), matching: find.byType(IconButton)).hitTestable();
    await clickAcrossAFrame(tester, arrow);
    expect(find.widgetWithText(MenuItemButton, 'CW').hitTestable(), findsOneWidget);

    await clickAcrossAFrame(tester, find.widgetWithText(MenuItemButton, 'CW').hitTestable());
    expect(fakeRadio.vfoA.mode, 'CW');
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Tab out of an arrow-opened Mode menu takes it down and commits the typed text', (tester) async {
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8']),
      ),
    );
    await openControl(tester, MdiIcons.radio);

    await clickAcrossAFrame(tester, find.widgetWithText(TextField, 'Mode'));
    await tester.enterText(find.widgetWithText(TextField, 'Mode'), 'C');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    final arrow = find.descendant(of: find.widgetWithText(DropdownMenu<String>, 'Mode'), matching: find.byType(IconButton)).hitTestable();
    await clickAcrossAFrame(tester, arrow);
    expect(find.widgetWithText(MenuItemButton, 'CW').hitTestable(), findsOneWidget, reason: 'test setup');
    expect(fakeRadio.vfoA.mode, isNot('CW'), reason: 'test setup: nothing committed yet');

    // The arrow left focus on a node of the dropdown's own, not on the
    // field. A departure watched only from the field never sees this Tab:
    // the menu stays up over the field Tab moved on to, and the field keeps
    // showing 'C' for a mode the VFO never received.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
    expect(fakeRadio.vfoA.mode, 'CW');
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).controller!.text, 'CW');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Tab out of a focused Mode field takes its open menu down', (tester) async {
    await tester.pumpWidget(
      host(
        radio: baseRadio().copyWith(radioService: fakeRadio, enabledModes: ['SSB', 'CW', 'FT8']),
      ),
    );
    await openControl(tester, MdiIcons.radio);

    await clickAcrossAFrame(tester, find.widgetWithText(TextField, 'Mode'));
    expect(find.widgetWithText(MenuItemButton, 'CW').hitTestable(), findsOneWidget);

    // No pointer is involved, so the menu's own tap region never fires: the
    // blur is the only thing left that can close the overlay. Without it,
    // the menu stays up over whatever field Tab moved on to.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.byType(MenuItemButton).hitTestable(), findsNothing);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Mode')).focusNode!.hasFocus, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
