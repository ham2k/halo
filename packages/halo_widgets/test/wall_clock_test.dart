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
import 'package:halo_core/halo_core.dart';
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

  group('time travel (docs/design/time.md)', () {
    tearDown(AppClock.instance.reset);

    testWidgets('the builder is handed the travelled time', (tester) async {
      AppClock.instance.travel(delta: const Duration(days: 30));
      DateTime? seen;
      await tester.pumpWidget(MaterialApp(
        home: OncePerSecond(builder: (context, nowUtc) {
          seen = nowUtc;
          return const SizedBox();
        }),
      ));

      expect(seen, isNotNull);
      expect(seen!.difference(nowUtc()).abs(), lessThan(const Duration(seconds: 2)));
    });

    testWidgets('travelling repaints immediately instead of at the next tick', (tester) async {
      var builds = 0;
      await tester.pumpWidget(MaterialApp(
        home: OncePerSecond(builder: (context, _) {
          builds++;
          return const SizedBox();
        }),
      ));
      expect(builds, 1);

      // No pumped time at all: without the AppClock listener the leaf would sit
      // on the old time until whatever timer was already armed happened to
      // fire, so a DEVTT jump would take up to a second to show.
      AppClock.instance.travel(delta: const Duration(hours: 5));
      await tester.pump();
      expect(builds, 2);
    });

    // The cadence is checked on the arithmetic, not by counting ticks: the
    // boundary is read from the REAL clock while a widget test's timers run on
    // fake time, so a pumped second yields a number of ticks that depends on
    // where the real clock happened to sit — flaky in one direction and,
    // worse, able to pass for the wrong reason in the other (just before a
    // boundary, even 1x re-arms at the floor).
    test('the wait to the next boundary shrinks with the speed', () {
      // Half a second into a second, at 1x: the rest of that second.
      expect(WallClock.delayToBoundary(periodMs: 1000, nowMillis: 1500, speed: 1), 500);
      // At 2x a displayed second lasts half a real one, which is the point.
      expect(WallClock.delayToBoundary(periodMs: 1000, nowMillis: 1500, speed: 2), 250);
      // And a slow clock waits longer, rather than being clamped to the period.
      expect(WallClock.delayToBoundary(periodMs: 1000, nowMillis: 1500, speed: 0.5), 1000);
    });

    test('and never goes below the floor, however fast the clock', () {
      // Without the floor this is 1ms, re-arming ~1000 times a second and
      // rebuilding every subscriber each time — with the only way out being to
      // type DEVTT into a UI that has stopped responding.
      expect(WallClock.delayToBoundary(periodMs: 1000, nowMillis: 0, speed: AppClock.maxSpeed), 100);
      // Also reached at an ordinary speed near a boundary, which is why the
      // floor is not simply a consequence of the speed cap.
      expect(WallClock.delayToBoundary(periodMs: 1000, nowMillis: 1999, speed: 1), 100);
    });

    testWidgets('the clock listener is dropped with the last subscriber', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: OncePerSecond(builder: (context, _) => const SizedBox()),
      ));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // A leaked listener would re-arm the timer from a disposed subtree, and
      // the pending-Timer teardown check would fail this test.
      AppClock.instance.travel(delta: const Duration(hours: 1));
      await tester.pump();
    });
  });
}
