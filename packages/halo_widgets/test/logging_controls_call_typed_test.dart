// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// [LoggingSession.onCallTyped]: what the keyer stops a CQ on. It must hear
// every way the operator enters a call and none of the panel's own writes —
// the wipe after an Enter above all, which the controller's own listener
// hears exactly like typing: a callback hung there would stop a CQ on every
// contact logged.

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  final callField = find.widgetWithText(TextField, 'Their call');

  testWidgets('typing fires it, and so does clearing the field by hand', (tester) async {
    var typed = 0;
    await tester.pumpWidget(host(session: LoggingSession(onCallTyped: () => typed++)));
    await tester.pump();

    await tester.enterText(callField, 'K1');
    await tester.pump();
    expect(typed, 1);

    // Correcting a call is working the contact too.
    await tester.enterText(callField, '');
    await tester.pump();
    expect(typed, 2);
  });

  testWidgets('the wipe after logging does not', (tester) async {
    var typed = 0;
    await tester.pumpWidget(host(session: LoggingSession(onCallTyped: () => typed++)));
    await tester.pump();
    await tester.enterText(callField, 'K1ABC');
    await tester.pump(const Duration(milliseconds: 200));
    expect(typed, 1);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(callField).controller!.text, isEmpty, reason: 'the QSO was logged and wiped');
    expect(typed, 1, reason: 'the wipe is the panel writing, not the operator');
  });

  testWidgets('a spot filling the call does not', (tester) async {
    var typed = 0;
    await tester.pumpWidget(host(session: LoggingSession(onCallTyped: () => typed++)));
    await tester.pump();
    await tester.pumpWidget(
      host(
        session: LoggingSession(
          onCallTyped: () => typed++,
          suggestedQso: {
            'their': {'call': 'W9XYZ'},
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(callField).controller!.text, 'W9XYZ');
    expect(typed, 0);
  });

  testWidgets('the mobile numbers row fires it, though it never reaches onChanged', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      var typed = 0;
      raiseKeyboard(tester);
      await tester.pumpWidget(
        host(
          prefs: LoggingPreferences(showNumbersRow: true),
          session: LoggingSession(onCallTyped: () => typed++),
        ),
      );
      await tester.tap(callField); // mobile starts unfocused
      await tester.pump();
      await tester.pump();

      await tester.tap(find.descendant(of: find.byType(NumberKeys), matching: find.text('5')));
      await tester.pump();
      expect(tester.widget<TextField>(callField).controller!.text, '5');
      expect(typed, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
