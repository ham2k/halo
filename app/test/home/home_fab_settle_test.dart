// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Both of the Home FAB's animations — the scroll-driven extend/collapse and
// the first-run nudge wiggle — can be interrupted and left half-applied, with
// no path back on their own: a stopped RenderAnimatedSize reports a half
// width until layout runs again, and the nudge's controller is one-shot per
// mount, so a burst frozen mid-swing leaves the button visibly tilted forever.
//
// What both fixes promise is the same thing, and it's what these tests pin
// down: once the animation's own duration has elapsed in wall-clock time, the
// FAB is at rest, whatever the animation itself actually managed to do.
//
// TickerMode(enabled: false) is how the stall is reproduced here — it mutes
// the ticker AnimatedSize builds from SingleTickerProviderStateMixin, exactly
// as a backgrounded tab's dead frame pump would, while Timers keep running.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/home_view.dart';

import '../support/halo_test_support.dart';

/// Mirrors home_view.dart's own `_fabTransitionDuration + _fabSettleSlack`.
const _settleDeadline = Duration(milliseconds: 400);

/// Mirrors `_newOperationNudgeDelay`, and `_NewOperationNudgeState._sequence`
/// — three 1200ms bursts with a 3s gap between them.
const _nudgeDelay = Duration(seconds: 5);
const _nudgeSequence = Duration(milliseconds: (1200 * 3) + (3000 * 2));

/// The FAB's collapsed width, per its Container in home_view.dart.
const _collapsedWidth = 56.0;

/// The FAB's outer AnimatedSize — the one that animates between the extended
/// and collapsed widths. The label's inner AnimatedSize is a sibling of the
/// plus icon, not an ancestor of it, so the first match is the outer one.
final _fab = find.ancestor(of: find.byIcon(MdiIcons.plus), matching: find.byType(AnimatedSize)).first;

/// How many Transforms sit above the FAB — the nudge's rotation is the only
/// thing that puts one there, so this is 0 whenever nothing can tilt it.
int _rotationsAboveFab() => find.ancestor(of: _fab, matching: find.byType(Transform)).evaluate().length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a FAB collapse interrupted by a stalled ticker still ends at its resting width', (tester) async {
    final HaLoHarness(:services) = await makeHaLoServices();

    // Enough operations that the list actually scrolls, which is what drives
    // the FAB's extend/collapse.
    for (var i = 0; i < 20; i++) {
      await services.operations.create(stationCall: 'N0DEV');
    }

    // For as long as a collapse is under way the FAB's Row overflows: the
    // Container snaps to its collapsed 56 immediately, while the label's own
    // AnimatedSize is still shrinking towards 0. That predates the settle
    // deadline this test is about — nothing here touches those widths — so
    // swallow it rather than let it mask the assertions below. Counted, not
    // just discarded: the count is asserted at the end, so if that overflow
    // is ever fixed this test fails and takes the workaround down with it
    // rather than quietly going on hiding whatever comes next.
    var swallowedOverflows = 0;
    final priorOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        swallowedOverflows++;
        return;
      }
      priorOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = priorOnError);

    Future<void> pumpTree({required bool ticking}) => tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(home: TickerMode(enabled: ticking, child: HomeView(services: services))),
          ),
        );

    await pumpTree(ticking: true);
    await tester.pumpAndSettle();

    final extendedWidth = tester.getSize(_fab).width;
    expect(extendedWidth, greaterThan(_collapsedWidth), reason: 'the FAB starts extended, with its label showing');

    // Hold the drag rather than releasing it: a released fling would settle
    // ballistically and fire more scroll notifications while we are trying to
    // hold the FAB mid-transition.
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
    // Past the touch slop FIRST, then the rest — a single jump of the whole
    // distance is one move event, and the drag recognizer has to win its arena
    // before it will accept any of it. `tester.drag` splits the move for this
    // reason and cannot be used here: it releases, and a released fling settles
    // ballistically, firing more scroll notifications while we are trying to
    // hold the FAB mid-transition.
    await gesture.moveBy(const Offset(0, kDragSlopDefault));
    await gesture.moveBy(const Offset(0, -200 - kDragSlopDefault));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final midWidth = tester.getSize(_fab).width;
    expect(midWidth, lessThan(extendedWidth), reason: 'the collapse should be under way');
    expect(midWidth, greaterThan(_collapsedWidth), reason: 'but not finished — this is the frame we strand it on');

    // The tab goes away mid-transition and the frame pump dies with it.
    await pumpTree(ticking: false);
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      tester.getSize(_fab).width,
      midWidth,
      reason: 'with the ticker muted the transition itself cannot progress — without a deadline this is where the '
          'FAB stays, stuck at a partial width with its label half-faded',
    );

    // Past the deadline, still with no ticker to run the animation.
    await tester.pump(_settleDeadline);
    await tester.pump();

    expect(
      tester.getSize(_fab).width,
      _collapsedWidth,
      reason: 'once the transition\'s wall-clock time is up the FAB must be at its resting width regardless of what '
          'the animation managed to do',
    );

    expect(
      swallowedOverflows,
      greaterThan(0),
      reason: 'the collapse is expected to overflow the FAB\'s Row today; when that gets fixed, delete the '
          'FlutterError.onError workaround above along with this assertion',
    );

    await gesture.up();
    await pumpTree(ticking: true);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the nudge waits out its delay, then stops rotating the FAB once its bursts are over', (tester) async {
    await pumpHaLo(tester, (services) => HomeView(services: services));
    await tester.pumpAndSettle();

    expect(
      _rotationsAboveFab(),
      0,
      reason: 'the nudge holds off at first — someone still taking the screen in has not reached the point of '
          'needing to be pointed at the button',
    );

    await tester.pump(_nudgeDelay);
    expect(
      _rotationsAboveFab(),
      greaterThan(0),
      reason: 'an untouched screen past the delay is exactly who the nudge is for, and this FAB is under the '
          'onboarding threshold',
    );

    await tester.pump(_nudgeSequence + _settleDeadline);
    await tester.pump();

    expect(
      _rotationsAboveFab(),
      0,
      reason: 'after the bursts\' time is up the FAB must not be rotated by anything — a wiggle whose ticker died '
          'mid-swing would otherwise leave it permanently tilted',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  // Both settle mechanisms replace a widget ABOVE the FAB's button — the
  // epoch key here, the nudge dropping its Transform below. Without a
  // GlobalKey pinning the button itself, that re-inflates the subtree and
  // disposes the InkWell's recognizers under the user's finger, so a press in
  // flight resolves to nothing and the FAB reads as dead. Both of these press
  // the button and hold it across the moment the rebuild lands.
  testWidgets('a press held across the collapse settle still registers as a tap', (tester) async {
    final HaLoHarness(:services, :settings) = await makeHaLoServices();

    for (var i = 0; i < 20; i++) {
      await services.operations.create(stationCall: 'N0DEV');
    }

    final priorOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) return;
      priorOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = priorOnError);

    await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: HomeView(services: services))));
    await tester.pumpAndSettle();

    // Scroll past the threshold: the FAB collapses, arming its deadline.
    final scroll = await tester.startGesture(tester.getCenter(find.byType(ListView)));
    await scroll.moveBy(const Offset(0, -200));
    await tester.pump();
    await scroll.up();
    await tester.pump(const Duration(milliseconds: 200));

    // Finger goes down on the FAB with the deadline still pending...
    final press = await tester.startGesture(tester.getCenter(find.byIcon(MdiIcons.plus)));
    // ...it fires mid-press, rebuilding the animated wrapper...
    await tester.pump(_settleDeadline);
    await tester.pump();
    // ...and only then does the finger come up.
    await press.up();
    await tester.pump();

    expect(
      settings.onboardingShownCount(OnboardingFlows.newOperation),
      1,
      reason: 'the tap must still open a new operation — a settle rebuild landing mid-press must not swallow it',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a press held across the nudge settling still registers as a tap', (tester) async {
    final HaLoHarness(:settings) = await pumpHaLo(tester, (services) => HomeView(services: services));
    await tester.pumpAndSettle();

    // Let the nudge fire and run its bursts out, stopping just short of the
    // moment it settles — which is exactly when a user prompted by that last
    // burst would be reaching for the button.
    await tester.pump(_nudgeDelay);
    await tester.pump(_nudgeSequence);

    final press = await tester.startGesture(tester.getCenter(find.byIcon(MdiIcons.plus)));
    await tester.pump(_settleDeadline);
    await tester.pump();
    await press.up();
    await tester.pump();

    expect(
      _rotationsAboveFab(),
      0,
      reason: 'precondition: the nudge must have settled during that press, or this proves nothing',
    );
    expect(
      settings.onboardingShownCount(OnboardingFlows.newOperation),
      1,
      reason: 'the nudge settling mid-press must not swallow the very tap it was asking for',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a touch during the wait drops the nudge for that visit', (tester) async {
    await pumpHaLo(tester, (services) => HomeView(services: services));
    await tester.pumpAndSettle();

    // Somewhere in the operation list, well clear of the FAB's bottom-right
    // corner — the point is that it doesn't have to be anything in particular.
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(_nudgeDelay + _nudgeSequence);

    expect(
      _rotationsAboveFab(),
      0,
      reason: 'the user engaged on their own before the nudge fired, so it is dropped for this visit rather than '
          'interrupting them once they are already busy',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
