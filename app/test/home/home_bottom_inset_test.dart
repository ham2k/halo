// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The status footer holds the bottom safe area with a `SafeArea` of its own,
// and it spans the window below every route — so the home layer's own chrome
// must NOT hold the same strip a second time. Without that, Quick Lookup
// reserves the indicator below its field and the rail's Settings cap reserves
// it below the cog: ~34pt of teal on an iPhone, stacked on top of the ~34pt
// the footer is already holding.
//
// Measured against the SAME window with no device inset at all rather than
// against a hard-coded number: with the footer up the two must lay out
// identically, which is the property, and a reserve creeping back into either
// one shows up as a difference. Everything is read RELATIVE to the footer's
// top edge, since the footer itself is legitimately taller when there is an
// indicator to clear.

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/home_navigation_rail.dart';
import 'package:ham2k_logger/views/home_quick_lookup.dart';
import 'package:ham2k_logger/views/home_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The home indicator, as a device reports it: `padding` AND `viewPadding`,
  /// which the engine derives from each other but a TestFlutterView holds
  /// independently — a fake that sets only one of them measures a window the
  /// widgets disagree about.
  const indicator = 34.0;

  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices();
    services = harness.services;
  });

  /// The home layer's bottom chrome, measured from the footer's top edge: how
  /// tall Quick Lookup is, and how far the Settings glyph sits above the band —
  /// plus the footer's own height, which is what pins the strip on SOMEBODY.
  Future<({double lookupHeight, double settingsGap, double footerHeight, bool drawn})> measure(WidgetTester tester, {required double inset}) async {
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = Size(390 * dpr, 844 * dpr);
    tester.view.padding = FakeViewPadding(bottom: inset * dpr);
    tester.view.viewPadding = FakeViewPadding(bottom: inset * dpr);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });

    // The overlay in the position `MaterialApp.builder` gives it — above the
    // routes, wrapping the navigator the home view lives in, which is what
    // puts the rail and Quick Lookup inside its reach.
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          builder: (context, child) => StatusBarOverlay(services: services, child: child!),
          home: HomeView(services: services),
        ),
      ),
    );
    // Fixed pumps rather than `pumpAndSettle`: the chrome carries a
    // once-a-second clock, so a settle here waits for a tree that never goes
    // quiet. Two frames plus the footer's own grow/switch animations is what
    // the geometry needs.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final footerTop = tester.getTopLeft(find.byType(StatusBarFooter)).dy;
    final result = (
      lookupHeight: tester.getSize(find.byType(HomeQuickLookup)).height,
      // The rail's cog, not Home's own header one — both are on screen.
      settingsGap: footerTop - tester.getBottomLeft(find.descendant(of: find.byType(HomeNavigationRail), matching: find.byIcon(MdiIcons.cogOutline))).dy,
      footerHeight: tester.getSize(find.byType(StatusBarFooter)).height,
      drawn: footerTop < tester.getSize(find.byType(StatusBarOverlay)).height,
    );

    // Tear the tree down here rather than leaving it to the next pump: the
    // home view's drift subscriptions close on a timer, and a second
    // `pumpWidget` over a live one leaves that timer pending into the
    // framework's end-of-test check.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    return result;
  }

  testWidgets('with the footer drawn, neither Quick Lookup nor the Settings cap holds the home indicator', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final withIndicator = await measure(tester, inset: indicator);
      final without = await measure(tester, inset: 0);

      // Asserted out here rather than inside `measure`: a failure there would
      // skip the teardown below it and bury the real cause under a pending
      // drift timer.
      expect(withIndicator.drawn && without.drawn, isTrue, reason: 'the footer must be drawn, or none of these reserves is under test');
      // The other half of the invariant, and the half the relative
      // measurements below cannot see: SOMETHING still holds the indicator.
      // Drop the footer's own `SafeArea` and every assertion after this one
      // stays green while its rows sit in the indicator.
      expect(
        withIndicator.footerHeight - without.footerHeight,
        moreOrLessEquals(indicator, epsilon: 0.5),
        reason: 'the footer is the one holding the strip now, so it is the one that grows by it',
      );
      expect(
        withIndicator.lookupHeight,
        moreOrLessEquals(without.lookupHeight, epsilon: 0.5),
        reason: 'Quick Lookup must not grow by the indicator the footer below it is already holding',
      );
      expect(
        withIndicator.settingsGap,
        moreOrLessEquals(without.settingsGap, epsilon: 0.5),
        reason: 'the rail\'s Settings cap must not lift its glyph by that same indicator',
      );
      // Not a pair of zeroes agreeing with each other: the icon really is
      // above the band and the bar really has a height.
      expect(without.lookupHeight, greaterThan(0));
      expect(without.settingsGap, greaterThan(0));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
