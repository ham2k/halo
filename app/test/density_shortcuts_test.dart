// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ⌘⇧-/⌘⇧=/⌘⇧0 step Layout Density, on the same keys Font Scale uses one
// modifier down. They share those keys deliberately, which is exactly why
// this drives the REAL handler in main.dart through HaLoApp: the two are one
// `if` apart, and an ordering change there would silently hand the shifted
// keys back to the zoom handler. A handler copied into the test could not
// catch that.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/config/tester_notes.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import 'support/halo_test_support.dart';

/// A 900pt-tall window unless [height] says otherwise — the `normal` band,
/// i.e. an ordinary desktop window with rungs available in both directions.
///
/// Set explicitly rather than left to the default test surface, which is 800
/// WIDE by 600 tall: that lands in `dense`, one rung from the bottom, so a
/// walk down the ladder would end after a single press and the test would be
/// asserting the ladder's edge instead of its middle.
Future<HaLoServices> _boot(WidgetTester tester, {double height = 900}) async {
  tester.view.physicalSize = Size(1280, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  setReleaseNotesForTesting(const []);
  setTesterNotesForTesting(const []);
  final HaLoHarness(:services) = await makeHaLoServices(prefs: null);

  await tester.pumpWidget(TranslationProvider(child: HaLoApp(services: services)));
  await tester.pumpAndSettle();
  return services;
}

/// Sends `Cmd (+Shift) + key`, the way the real handler sees it.
///
/// [on] is needed for the logical keys a keyboard only ever produces WITH
/// shift — `_` and `+`. Those have no physical key of their own, so
/// `sendKeyEvent` cannot find one and asserts; the event has to be built
/// naming the unshifted key it actually rides on, exactly as
/// font_scale_test.dart does.
Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
  PhysicalKeyboardKey? on,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  if (on == null) {
    await tester.sendKeyEvent(key);
  } else {
    HardwareKeyboard.instance.handleKeyEvent(
      KeyDownEvent(physicalKey: on, logicalKey: key, timeStamp: Duration.zero),
    );
    HardwareKeyboard.instance.handleKeyEvent(
      KeyUpEvent(physicalKey: on, logicalKey: key, timeStamp: Duration.zero),
    );
  }
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  testWidgets('Cmd+Shift+- and Cmd+Shift+= step the density, Cmd+Shift+0 returns to Auto', (tester) async {
    final services = await _boot(tester);
    final settings = services.settings;

    expect(settings.densityPreference, DensityPreference.auto);
    expect(DensityPreference.auto.resolve(900), LayoutDensity.normal);

    await _chord(tester, LogicalKeyboardKey.minus, shift: true);
    expect(settings.densityPreference, DensityPreference.dense, reason: 'one rung tighter than what was in effect');

    await _chord(tester, LogicalKeyboardKey.minus, shift: true);
    expect(settings.densityPreference, DensityPreference.densest);

    // The far end of the ladder holds rather than wrapping.
    await _chord(tester, LogicalKeyboardKey.minus, shift: true);
    expect(settings.densityPreference, DensityPreference.densest);

    for (final expected in [
      DensityPreference.dense,
      DensityPreference.normal,
      DensityPreference.sparse,
      DensityPreference.sparsest,
    ]) {
      await _chord(tester, LogicalKeyboardKey.equal, shift: true);
      expect(settings.densityPreference, expected, reason: 'one rung per press, all the way up');
    }

    await _chord(tester, LogicalKeyboardKey.equal, shift: true);
    expect(settings.densityPreference, DensityPreference.sparsest, reason: 'and it holds at the top too');

    await _chord(tester, LogicalKeyboardKey.digit0, shift: true);
    expect(settings.densityPreference, DensityPreference.auto, reason: 'reset hands control back, not to Normal');

    await _drain(tester);
  });

  testWidgets('the shifted forms of the zoom keys reach density, not Font Scale', (tester) async {
    final services = await _boot(tester);
    final settings = services.settings;

    // `_` IS shift-minus and `+` IS shift-equal. Before density claimed them
    // these zoomed; the modifier gate is the only thing separating the two
    // features, so assert BOTH sides of it in one go.
    await _chord(tester, LogicalKeyboardKey.underscore, shift: true, on: PhysicalKeyboardKey.minus);
    expect(settings.densityPreference, DensityPreference.dense);
    expect(settings.fontScale, FontScale.normal, reason: 'shifted minus must no longer zoom');

    await _chord(tester, LogicalKeyboardKey.add, shift: true, on: PhysicalKeyboardKey.equal);
    expect(settings.densityPreference, DensityPreference.normal);
    expect(settings.fontScale, FontScale.normal, reason: 'shifted equal must no longer zoom');

    // …and the unshifted keys still zoom, untouched.
    await _chord(tester, LogicalKeyboardKey.equal);
    expect(settings.fontScale, FontScale.larger);
    expect(settings.densityPreference, DensityPreference.normal, reason: 'zooming must not move density');

    await _drain(tester);
  });

  testWidgets('a density change is named in the status bar, and clears itself', (tester) async {
    final services = await _boot(tester);

    await _chord(tester, LogicalKeyboardKey.minus, shift: true);

    final item = services.statusBar.items.where((i) => i.key == 'layoutDensity').firstOrNull;
    expect(item, isNotNull, reason: 'the shortcut has no other visible confirmation');
    // The SETTING, not just the density in force. On Auto, or when a pick is
    // clamped, the two differ and only naming one leaves the operator unable
    // to tell which they moved.
    expect(item!.text, 'Dense');

    // Self-clearing: an item posted here would otherwise sit in the footer
    // for the rest of the session.
    await tester.pump(const Duration(seconds: 4));
    expect(services.statusBar.items.where((i) => i.key == 'layoutDensity'), isEmpty);

    // Auto names both, because on Auto the setting and the density in force
    // are genuinely different facts.
    await _chord(tester, LogicalKeyboardKey.digit0, shift: true);
    final auto = services.statusBar.items.where((i) => i.key == 'layoutDensity').first;
    expect(auto.text, 'Automatic — Normal');

    await _drain(tester);
  });

  testWidgets('every rung is reachable by keyboard on an ordinary window', (tester) async {
    // The regression this replaces: the ceiling clamped a pick to whatever
    // the height ladder had chosen, so on any window below the sparse band
    // every roomier rung resolved back and the shortcut appeared to toggle
    // between two values. A 900pt window is exactly that case.
    final services = await _boot(tester);
    final settings = services.settings;

    final reached = <LayoutDensity>{};
    for (var i = 0; i < LayoutDensity.values.length; i++) {
      await _chord(tester, LogicalKeyboardKey.minus, shift: true);
      reached.add(settings.densityPreference.resolve(900));
    }
    for (var i = 0; i < LayoutDensity.values.length; i++) {
      await _chord(tester, LogicalKeyboardKey.equal, shift: true);
      reached.add(settings.densityPreference.resolve(900));
    }
    expect(
      reached,
      LayoutDensity.values.toSet(),
      reason: 'every rung must be reachable by keyboard on an ordinary window',
    );

    await _drain(tester);
  });

  testWidgets('on a short window the setting keeps advancing, and lands once the window grows', (tester) async {
    // The end of the bug the stepping fix exists for, exercised through the
    // real handler rather than as arithmetic: below the `normal` band the
    // ceiling holds the EFFECTIVE density down, so pressing roomier changes
    // the setting without changing the screen. It has to keep advancing
    // anyway — otherwise the operator is stuck one rung from the bottom —
    // and the rung they picked has to take effect the moment the window can
    // afford it.
    final services = await _boot(tester, height: 500);
    final settings = services.settings;

    for (final expected in [
      DensityPreference.normal,
      DensityPreference.sparse,
      DensityPreference.sparsest,
    ]) {
      await _chord(tester, LogicalKeyboardKey.equal, shift: true);
      expect(settings.densityPreference, expected, reason: 'the setting must keep moving while clamped');
      expect(
        settings.densityPreference.resolve(500),
        LayoutDensity.dense,
        reason: 'while the screen stays put',
      );
    }

    // Grow the window past the clamp: the pick that was stored all along is
    // what takes effect, with no further input.
    expect(settings.densityPreference.resolve(1500), LayoutDensity.sparsest);

    await _drain(tester);
  });

  testWidgets('a pick the window is too short for says so instead of looking dead', (tester) async {
    // 500pt of height puts the ladder in `dense` outright, so `sparse` is
    // stored but clamped. Without the message the key would appear broken —
    // this is the one case where the setting changes and the screen does not.
    final services = await _boot(tester, height: 500);
    final settings = services.settings;

    await _chord(tester, LogicalKeyboardKey.equal, shift: true);
    expect(settings.densityPreference, DensityPreference.normal);
    expect(settings.densityPreference.resolve(500), LayoutDensity.dense, reason: 'the ceiling still applies');

    final item = services.statusBar.items.where((i) => i.key == 'layoutDensity').firstOrNull;
    expect(item, isNotNull);
    expect(
      item!.text,
      contains('too short'),
      reason: 'the operator must be told the pick was stored but not applied',
    );

    await _drain(tester);
  });
}
