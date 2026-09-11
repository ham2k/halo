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
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/views/home_navigation_rail.dart';
import 'package:ham2k_logger/views/ham2k_logo.dart';
import 'package:ham2k_logger/views/home_view.dart';
import 'package:ham2k_logger/config/version.dart';
import 'package:ham2k_logger/views/home_branding_pane.dart';
import 'package:ham2k_logger/views/version_label.dart';
import 'package:ham2k_logger/views/release_overlay.dart';

import '../support/halo_test_support.dart';

Future<void> _pumpHome(WidgetTester tester) => _pumpHomeAt(tester, const Size(1200, 800));

Future<void> _pumpHomeAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
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

  testWidgets('the header sets the edition badge on the product name\'s baseline', (tester) async {
    setReleaseNotesForTesting(const []);
    await _pumpHome(tester);

    // Bottom-aligning the two boxes (CrossAxisAlignment.end) instead drops the
    // badge by the whole descent of the name — the mutation this exists to
    // catch. Measured against the name's real baseline rather than a pixel
    // constant, so it still means something at a different title size.
    final name = find.descendant(of: find.byType(AppBar), matching: find.text(ham2kProductName));
    expect(name, findsOneWidget);
    final nameRect = tester.getRect(name);
    // Measured from the title's OWN resolved style (shrinkToFitText hands the
    // Text a complete one), not from the render tree: getDistanceToBaseline is
    // only legal during layout. The baseline sits one descent above the box.
    final painter = TextPainter(
      text: TextSpan(text: ham2kProductName, style: tester.widget<Text>(name).style),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(painter.dispose);
    final descent = painter.height - painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final baselineY = nameRect.bottom - descent;
    expect(descent, greaterThan(1), reason: 'a zero descent would make this test unable to fail');

    final badge = find.descendant(of: find.byType(AppBar), matching: find.byType(Ham2kEditionBadge));
    expect(badge, findsOneWidget, reason: 'Dev and Next builds carry the badge; Regular has none');
    expect(
      tester.getRect(badge).bottom,
      moreOrLessEquals(baselineY + headerEditionBadgeBaselineNudge, epsilon: 0.5),
      reason: "the wordmark's bottom edge IS its baseline, plus its optical nudge",
    );
    await _endOfTest(tester);
  });

  testWidgets('a header too narrow for one line stacks the badge under the name', (tester) async {
    setReleaseNotesForTesting(const []);
    await _pumpHomeAt(tester, const Size(420, 800));

    final name = find.descendant(of: find.byType(AppBar), matching: find.text(ham2kProductName));
    final badge = find.descendant(of: find.byType(AppBar), matching: find.byType(Ham2kEditionBadge));
    expect(name, findsOneWidget);
    expect(badge, findsOneWidget);

    // Stacked means BELOW, not merely shrunk beside: side by side the badge
    // overlaps the name's band vertically and starts to its right, and the
    // one-line layout satisfies neither of these.
    final nameRect = tester.getRect(name);
    final badgeRect = tester.getRect(badge);
    expect(badgeRect.top, greaterThanOrEqualTo(nameRect.bottom - 1));
    expect(badgeRect.left, moreOrLessEquals(nameRect.left, epsilon: 1));

    // Two lines have to fit the toolbar: `shrinkToFitText` buys width, never
    // height, so nothing below rescues a title that outgrows the bar — it
    // overflows, and an AppBar paints that across the header.
    expect(badgeRect.bottom, lessThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom));
    expect(tester.takeException(), isNull);
    await _endOfTest(tester);
  });

  testWidgets('a narrow header at a large text size does not spill out of the toolbar', (tester) async {
    // The AppBar lays its title out with an INFINITE height budget and then
    // clamps its own box to the toolbar and centres what it got, so a title
    // taller than the bar neither overflows nor throws — it just spills over
    // the header, silently, in release too. Nothing but a measurement catches
    // it, and stacking is the layout that can grow tall enough to do it.
    tester.platformDispatcher.textScaleFactorTestValue = 1.34;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    setReleaseNotesForTesting(const []);
    await _pumpHomeAt(tester, const Size(420, 800));

    final appBar = tester.getRect(find.byType(AppBar));
    final name = find.descendant(of: find.byType(AppBar), matching: find.text(ham2kProductName));
    final badge = find.descendant(of: find.byType(AppBar), matching: find.byType(Ham2kEditionBadge));
    // Stacked, or this asserts nothing: the inline row is only ever as tall as
    // its tallest child and could never have spilled.
    expect(tester.getRect(badge).top, greaterThanOrEqualTo(tester.getRect(name).bottom - 1));
    expect(tester.getRect(name).top, greaterThanOrEqualTo(appBar.top - 0.5));
    expect(tester.getRect(badge).bottom, lessThanOrEqualTo(appBar.bottom + 0.5));
    await _endOfTest(tester);
  });

  testWidgets('the version pane never names the last release\'s build number on a Dev build', (tester) async {
    // The version-line contract in docs/design/user-interface.md: on Dev
    // `kBuildNumber` is the LAST RELEASE's, so a pane printing it names a
    // binary nobody is running — and `bareBuildNumber` puts it there INSTEAD
    // of the SHA, which is the one token that does identify the build.
    // Setting that flag on this pane must fail here.
    setReleaseNotesForTesting(const []);
    await _pumpHome(tester);

    expect(kEdition, Edition.dev, reason: 'the rule under test only applies to Dev builds');
    expect(versionBuildLine(bareBuildNumber: true), isNotEmpty,
        reason: 'an empty needle would make find.text below match nothing whatever the pane renders');
    // Presence first, both times: an absence assertion against a pane that
    // isn't there, or that has stopped naming the version at all, passes while
    // checking nothing — and "silent about the version" is the other half of
    // the same failure.
    expect(find.byType(BrandingPane), findsOneWidget);
    expect(
      find.descendant(of: find.byType(BrandingPane), matching: find.text(kVersionMainName)),
      findsOneWidget,
      reason: 'the pane still names the version',
    );
    expect(
      find.descendant(of: find.byType(BrandingPane), matching: find.text(versionBuildLine(bareBuildNumber: true))),
      findsNothing,
      reason: 'that string is the tester overlay\'s notes key, not an identity for this pane',
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
