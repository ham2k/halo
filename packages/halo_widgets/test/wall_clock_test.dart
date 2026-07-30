// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// WallClock/OncePerSecond exist so per-second UI (the Time chip, rate lines)
// rebuilds only its own leaf instead of whatever State owns a timer — the
// panel-level ticker they replaced rebuilt all of LoggingControls once per
// second (measured at roughly double the idle CPU of the logging view on
// web). These tests pin the two properties that matter: ticks reach the
// leaf, and they do NOT reach the surrounding widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  testWidgets('OncePerSecond re-runs its builder as wall-clock seconds pass', (tester) async {
    var builds = 0;
    await tester.pumpWidget(MaterialApp(
      home: OncePerSecond(builder: (context, _) {
        builds++;
        return const SizedBox();
      }),
    ));

    expect(builds, 1);
    // Each armed timer waits at most 1s (aimed at the next second boundary,
    // re-aimed after every tick), so 3s of pumped time guarantees at least
    // one tick has fired and rebuilt the leaf.
    await tester.pump(const Duration(seconds: 3));
    expect(builds, greaterThan(1));
  });

  testWidgets('ticks rebuild only the leaf, not the widget that owns the spec', (tester) async {
    var parentBuilds = 0;
    var leafBuilds = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        parentBuilds++;
        return OncePerSecond(builder: (context, _) {
          leafBuilds++;
          return const SizedBox();
        });
      }),
    ));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));

    expect(leafBuilds, greaterThan(1));
    // The whole point of the shared clock: the enclosing widget never
    // rebuilds — the old panel-level ticker rebuilt it once per second.
    expect(parentBuilds, 1);
  });

  testWidgets('the shared timer disarms once the last listener is gone', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OncePerSecond(builder: (context, _) => const SizedBox()),
    ));
    await tester.pump(const Duration(seconds: 2));

    // Removing the subtree removes the last listener; if the timer kept
    // running, the test framework itself would fail this test on teardown
    // with "A Timer is still pending".
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });
}
