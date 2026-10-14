// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Show idle metrics puts the extension engine's idle share in the status bar,
// on the REAL `StatusBarOverlay` (see status_bar_keyboard_test.dart for why).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the readout shows only while developer mode is on, and opens to every window when tapped', (tester) async {
    // The switch lives in the developer panel. Shown on the setting alone,
    // leaving developer mode would strand the readout on screen with its
    // switch gone.
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          builder: (context, _) => StatusBarOverlay(
            services: services,
            child: const Scaffold(body: SizedBox.expand()),
          ),
          home: const SizedBox.shrink(),
        ),
      ),
    );
    final readout = find.textContaining('% idle');

    await settings.setShowIdleMetrics(true);
    await tester.pump();
    expect(readout, findsNothing);

    await settings.setDeveloperMode(true);
    await tester.pump();
    expect(readout, findsOneWidget);

    await tester.tap(readout);
    await tester.pump();
    expect(find.textContaining('Idle avg: 1s '), findsOneWidget, reason: 'a tap opens the readout to every window');
    expect(find.textContaining('· 10s '), findsOneWidget);
    expect(find.textContaining('· 60s '), findsOneWidget);

    await tester.tap(find.textContaining('Idle avg:'));
    await tester.pump();
    expect(readout, findsOneWidget, reason: 'and a second tap closes it again');

    await settings.setDeveloperMode(false);
    await tester.pump();
    expect(readout, findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
