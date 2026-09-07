// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the webview map's two ready horizons are allowed to conclude.
//
// The trap they exist for: MapLibre's `load` waits for the FIRST RENDER, not
// just the style, and a dock group lays out every pane in it while painting
// only one. So a map behind another tab is never given a frame, `load` cannot
// fire, and a clock started from `initState` reports a failure against a map
// nobody has looked at.
//
// The second horizon separates two findings that a single timer conflates: a
// map that arrives at 20s was SLOW, and one that never arrives is BROKEN.
// Reporting the first as the second is what makes the rate unreadable.
//
// These pump the real widget, whose `InAppWebView` has no platform view in a
// test and throws on build — hence `tester.takeException()` after every pump
// that builds one. The State, its dependencies and its timers are all live
// regardless, which is the whole of what is under test here.
//
// Those widget cases run the watchdog on its DEFAULT clock while `pump`
// advances fake timers — the mixed-clock shape time.md §7 warns about. Sound
// only because none of them turns on visible-time arithmetic: the widget
// exposes no `now` seam, so anything here that did would pass vacuously.
// Accumulation is driven through the watchdog directly, below.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_core/halo_core.dart' show AppClock, realNowMillis;

import 'package:ham2k_logger/services/connectivity_service.dart';
import 'package:ham2k_logger/services/error_reporting_backend.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/map_error_reporter.dart';
import 'package:ham2k_logger/views/map/map_gl_script.dart' show mapDefaultStyleUrl, mapDefaultStyleUrlDark;
import 'package:ham2k_logger/views/map/map_marker_data.dart' show MapProjection;
import 'package:ham2k_logger/views/map/map_ready_watchdog.dart';
import 'package:ham2k_logger/views/map/mapbox_webview_map_view.dart';

class _RecordingBackend implements ErrorReportingBackend {
  final exceptions = <Object>[];

  @override
  Future<bool> run(FutureOr<void> Function() startBody) async {
    await startBody();
    return true;
  }

  @override
  void captureException(Object error, StackTrace? stackTrace, {String? context}) => exceptions.add(error);

  @override
  void updateUserContext({String? callsign, String? accountId}) {}

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void captureDiagnostic({required String title, required String body}) {}
}

void main() {
  late _RecordingBackend backend;

  setUp(() async {
    ErrorReportingService.resetForTesting();
    MapErrorReporter.resetForTesting();
    ConnectivityService.resetForTesting();
    backend = _RecordingBackend();
    await ErrorReportingService.run(() {}, backend: backend);
  });

  tearDown(() {
    ErrorReportingService.resetForTesting();
    MapErrorReporter.resetForTesting();
    ConnectivityService.resetForTesting();
  });

  Future<void> pumpMap(WidgetTester tester, {required bool visible}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DockPaneVisibility(
            visible: visible,
            child: const MapboxWebviewMapView(
              markers: [],
              projection: MapProjection.mercator,
              isDark: false,
              styleUrl: mapDefaultStyleUrl,
              styleUrlDark: mapDefaultStyleUrlDark,
            ),
          ),
        ),
      ),
    );
    tester.takeException();
  }

  /// Every message the map reporter sent to the backend.
  List<String> reported() => backend.exceptions.map((e) => '$e').toList();

  group('the horizons themselves', () {
    // Driven directly, because the arrival they turn on — `poloMapReady` —
    // comes from a JavaScript handler registered in `onWebViewCreated`, which
    // never fires without a platform view. Reached only through the widget,
    // the 'ready-late' path could not be exercised at all.
    late int unavailableCalls;
    late MapReadyWatchdog watchdog;

    setUp(() {
      unavailableCalls = 0;
      // The visible-time arithmetic and the timers have to come off ONE
      // clock: fakeAsync replaces Timer and `clock` but not `DateTime.now()`,
      // so leaving the default here would measure the wall clock while the
      // timers ran on fake time — every elapsed span would compute as zero
      // and the accumulation tests would pass without exercising anything
      // (docs/design/time.md §7).
      watchdog = MapReadyWatchdog(
        onUnavailable: () => unavailableCalls++,
        now: () => clock.now().millisecondsSinceEpoch,
      );
    });

    tearDown(() => watchdog.dispose());

    test('a map that arrives late is reported as late, never as never-ready', () {
      fakeAsync((async) {
        watchdog.setVisible(true);
        async.elapse(MapReadyWatchdog.grace + const Duration(seconds: 5));

        // The operator has been told, and nothing has been reported yet.
        expect(unavailableCalls, 1);
        expect(reported(), isEmpty);

        watchdog.markReady();
        async.elapse(const Duration(minutes: 5));

        expect(reported(), hasLength(1));
        expect(reported().single, contains('ready-late'));
        expect(reported().single, isNot(contains('never-ready')),
            reason: 'a map that did load must not land in the issue counting maps that never did');
      });
    });

    test('a map that arrives inside the grace horizon says nothing at all', () {
      fakeAsync((async) {
        watchdog.setVisible(true);
        async.elapse(MapReadyWatchdog.grace - const Duration(seconds: 1));
        watchdog.markReady();
        async.elapse(const Duration(minutes: 5));

        expect(unavailableCalls, isZero);
        expect(reported(), isEmpty);
      });
    });

    test('a map that never arrives is reported once, at the give-up horizon', () {
      fakeAsync((async) {
        watchdog.setVisible(true);
        async.elapse(MapReadyWatchdog.giveUp - const Duration(seconds: 1));
        expect(reported(), isEmpty, reason: 'the give-up horizon is the whole point of the second timer');

        async.elapse(const Duration(seconds: 2));
        expect(reported(), hasLength(1));
        expect(reported().single, contains('never-ready'));
      });
    });

    test('the clock only counts time the pane was on screen', () {
      fakeAsync((async) {
        // Nearly out of grace, then the operator switches tabs. The page
        // renders nothing behind an unpainted pane, so those seconds measured
        // nothing and must not be carried over.
        watchdog.setVisible(true);
        async.elapse(MapReadyWatchdog.grace - const Duration(seconds: 1));
        watchdog.setVisible(false);
        async.elapse(const Duration(hours: 1));

        expect(unavailableCalls, isZero);
        expect(reported(), isEmpty);

        // Back on screen: a full grace period, not the one second left over.
        watchdog.setVisible(true);
        async.elapse(MapReadyWatchdog.grace - const Duration(seconds: 1));
        expect(unavailableCalls, isZero, reason: 'the horizon restarts, it does not resume');

        async.elapse(const Duration(seconds: 2));
        expect(unavailableCalls, 1);
      });
    });

    test('a map that arrives past the give-up horizon is counted once, not twice', () {
      fakeAsync((async) {
        // The invariant the two kinds exist for: one session, one finding.
        // Reporting the give-up AND then the late arrival would put the same
        // map in both populations, which is exactly the mixing that made the
        // original rate unreadable.
        watchdog.setVisible(true);
        async.elapse(MapReadyWatchdog.giveUp + const Duration(seconds: 5));
        expect(reported(), hasLength(1));
        expect(reported().single, contains('never-ready'));

        watchdog.markReady();
        async.elapse(const Duration(minutes: 5));

        expect(reported(), hasLength(1), reason: 'a session already counted as never-ready is not also counted late');
      });
    });

    test('the give-up horizon adds up across sittings', () {
      fakeAsync((async) {
        // The empty state at 15s invites the operator to leave, so a broken
        // map is watched in short stretches. If the give-up horizon restarted
        // with each one, three 40-second looks at a permanently broken map
        // would report nothing at all — the map would simply never be seen
        // for 60 uninterrupted seconds by anyone.
        for (var i = 0; i < 2; i++) {
          watchdog.setVisible(true);
          async.elapse(const Duration(seconds: 25));
          watchdog.setVisible(false);
          async.elapse(const Duration(minutes: 10));
        }
        expect(reported(), isEmpty, reason: '50 visible seconds is not yet the horizon');

        watchdog.setVisible(true);
        async.elapse(const Duration(seconds: 11));

        expect(reported(), hasLength(1));
        expect(reported().single, contains('never-ready'));
      });
    });

    test('the operator is told once, not on every return to the tab', () {
      fakeAsync((async) {
        watchdog.setVisible(true);
        async.elapse(MapReadyWatchdog.grace + const Duration(seconds: 1));
        expect(unavailableCalls, 1);

        for (var i = 0; i < 3; i++) {
          watchdog.setVisible(false);
          async.elapse(const Duration(seconds: 1));
          watchdog.setVisible(true);
          async.elapse(MapReadyWatchdog.grace + const Duration(seconds: 1));
        }

        expect(unavailableCalls, 1, reason: 'the empty state is already up; raising it again says nothing new');
      });
    });
  });

  test('the horizons do not follow a travelled clock', () {
    // The seam's DEFAULT is the contract. `realNowMillis` is what keeps a
    // horizon measuring real seconds; swapping it for `nowMillis` would read
    // as an ordinary application of the app-clock rule, and the
    // clock-discipline check greps for `DateTime.now()`, which that still is
    // not — so nothing but this would catch a travelled session expiring
    // every horizon at once. Asserted through behaviour rather than by
    // comparing function references: what matters is that the number does not
    // move (docs/design/time.md §7).
    final watchdog = MapReadyWatchdog(onUnavailable: () {});
    addTearDown(watchdog.dispose);

    // `reset`, never `travel(delta: Duration.zero)` — a delta is CUMULATIVE,
    // so a zero one is a no-op that reads like a reset and leaves this
    // process-wide singleton three days out for every test after it.
    AppClock.instance.travel(delta: const Duration(days: 3));
    addTearDown(AppClock.instance.reset);

    expect((watchdog.now() - realNowMillis()).abs(), lessThan(2000),
        reason: 'three days of travel must not reach a value that becomes a Timer duration');
  });

  testWidgets('a map behind another tab is never reported', (tester) async {
    // The bug in one test: hidden for well past both horizons, and the pane
    // has no grounds to say anything — it was never given a frame to draw in.
    await pumpMap(tester, visible: false);
    await tester.pump(const Duration(minutes: 5));
    tester.takeException();

    expect(reported(), isEmpty);

    // Timers must not be left pending when the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a visible map that never draws is reported once, after the give-up horizon', (tester) async {
    await pumpMap(tester, visible: true);

    // Past the grace horizon: the operator is told, but nothing is reported —
    // at 15s a slow map and a broken one are still indistinguishable.
    await tester.pump(const Duration(seconds: 20));
    tester.takeException();
    expect(reported(), isEmpty, reason: 'the grace horizon is operator feedback, not evidence');

    await tester.pump(const Duration(seconds: 45));
    tester.takeException();

    expect(reported(), hasLength(1));
    expect(reported().single, contains('never-ready'));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('leaving the tab stops the clock', (tester) async {
    // A map switched away from at 14s is not one second from failing: the
    // page does not keep rendering behind a pane that is never painted, so
    // the remaining seconds would measure nothing.
    await pumpMap(tester, visible: true);
    await tester.pump(const Duration(seconds: 14));
    tester.takeException();

    await pumpMap(tester, visible: false);
    await tester.pump(const Duration(minutes: 5));
    tester.takeException();

    expect(reported(), isEmpty);

    await tester.pumpWidget(const SizedBox());
  });
}
