// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PaneSafeArea.root wraps Home's body with the device's real safe-area
// insets (ham2k/halo-dist#205) — but a widget built directly inside
// _HomeViewState.build (like the new-operation FAB's Positioned) captures
// that method's own BuildContext, which sits ABOVE the PaneSafeArea it just
// established, not below it. Reading PaneSafeArea.xxxOf(context) with that
// stale context silently resolves to 0 instead of throwing, so a regression
// here has no compile-time or crash signal — only this test would catch it.
//
// Home ALONE, with no status footer below it: assembled, the footer holds the
// bottom safe area for the whole window and the shell takes it out of what the
// routes see, so the FAB there clears 16 and nothing more (see
// home_bottom_inset_test.dart). What this pins is the plumbing — that the FAB
// reads a real inset where there is one to read.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/home_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the new-operation FAB clears a real device inset, not just the fixed 16px (issue #205)',
      (tester) async {
    // Single-pane width: the primary pane (where the FAB lives) spans the
    // whole window and so legitimately owns the real right device inset too
    // — at a two-pane width the right edge belongs to the branding pane
    // instead, and this assertion would (correctly) see 0 there.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    // A device inset MediaQuery wouldn't normally produce on its own — big
    // enough that mistaking it for 0 is unmistakable in the assertion below.
    tester.view.padding = const FakeViewPadding(bottom: 40, right: 30);
    addTearDown(tester.view.reset);
    final HaLoHarness(:services) = await makeHaLoServices();

    await tester.pumpWidget(
      TranslationProvider(child: MaterialApp(home: HomeView(services: services))),
    );
    await tester.pumpAndSettle();

    final positioned = tester.widget<Positioned>(
      find.ancestor(of: find.byIcon(MdiIcons.plus), matching: find.byType(Positioned)),
    );
    expect(positioned.bottom, 16 + 40, reason: 'FAB must clear the real bottom device inset, not just the fixed 16px');
    expect(positioned.right, 16 + 30, reason: 'FAB must clear the real right device inset, not just the fixed 16px');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
