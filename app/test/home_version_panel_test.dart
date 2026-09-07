// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Current Version pane paints the release photo behind its branding. Every
// way that can fail is silent — a release with no photo committed, an asset
// that will not decode, notes that will not parse — because each of those
// deliberately paints nothing rather than an error. So "the photo is in the
// tree at all" has no signal of its own, and only an assertion catches its
// absence.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/views/home_navigation_rail.dart';
import 'package:ham2k_logger/views/home_view.dart';
import 'package:ham2k_logger/views/release_overlay.dart';

import 'support/halo_test_support.dart';

Future<void> _pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final HaLoHarness(:services) = await makeHaLoServices();
  // Through the shell the ROOT uses, not HomeView bare: the rail is a sibling
  // of the window's chrome now, so a test that pumped the view alone would be
  // exercising a composition that does not ship.
  await tester.pumpWidget(TranslationProvider(
    child: MaterialApp(home: HomeRailShell(
      services: services,
      routes: HomeView(services: services),
      // The same slot the root fills: Quick Lookup is window chrome now,
      // not a pane inside the arrangement.
    )),
  ));

  // Home is `MaterialApp.home` and arms two timers on mount — the FAB's
  // settle deadline and the first-run nudge's wait. A test that simply ends
  // leaves them pending, and the binding asserts "a Timer is still pending
  // even after the widget tree was disposed", which reads as the test hanging
  // rather than as the teardown it actually is. Unmount, then let their
  // wall-clock run out.
  addTearDown(() async {
    await _endOfTest(tester);
  });
  await settleFrames(tester);
}

/// Unmounts the tree and lets Home's timers run out.
///
/// Called at the END OF EACH TEST BODY, never from `addTearDown`: flutter_test
/// asserts "a Timer is still pending even after the widget tree was disposed"
/// as part of running the body, which is BEFORE any tearDown callback gets a
/// turn — so a drain registered there is too late to prevent the very thing it
/// is for.
///
/// Stepped, because the timers CHAIN: Home's nudge wait fires at 5s and only
/// then mounts the widget that arms its own ~9.7s settle, so one long advance
/// past the first deadline still leaves the second pending.
Future<void> _endOfTest(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 6));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the version pane paints the newest release photo behind the branding', (tester) async {
    setReleaseNotesForTesting(const [
      ReleaseNotesEntry(version: '26.8.0', name: "August '26", photoCaption: 'x', changes: []),
    ]);
    await _pumpHome(tester);

    final photo = find.byType(ReleasePhoto);
    expect(photo, findsOneWidget, reason: 'the pane background is the release photo');
    expect(
      tester.widget<ReleasePhoto>(photo).imageAssetPath,
      'assets/images/releases/26.8-photo.jpg',
      reason: 'the NEWEST entry decides, via its MAJOR.MINOR prefix',
    );
    await _endOfTest(tester);
  });

  testWidgets('no release notes means no photo, and the pane still says the version', (tester) async {
    setReleaseNotesForTesting(const []);
    await _pumpHome(tester);

    expect(find.byType(ReleasePhoto), findsNothing);
    // The pane's whole job. A missing photo must cost the decoration, nothing
    // else — this is what the silent-failure path is FOR.
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.text(ham2kProductName), findsWidgets);
    await _endOfTest(tester);
  });
}
