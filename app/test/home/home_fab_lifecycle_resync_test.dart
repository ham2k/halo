// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Home FAB's extend/collapse (an AnimatedSize/AnimatedOpacity pair,
// driven by scroll position) has been seen stuck mid-transition, at least on
// web. The leading cause: a backgrounded browser tab stops delivering
// frames, and nothing asks for a fresh one once it's visible again, so
// whatever frame the animation was mid-paint on just never gets redrawn —
// AnimatedSize's own render object is otherwise built to resume correctly
// once reattached (see RenderAnimatedSize in the Flutter SDK), so this
// isn't a broken animation state machine to replace, just a missing nudge.
//
// What's actually testable here: that a resumed lifecycle event (which
// fires for both app-foregrounding on mobile and tab-visibility-regained on
// web) makes HomeView ask for a fresh frame. The underlying browser-level
// frame-pump stall itself can't be reproduced in this test harness —
// tester.pump() always advances frames explicitly regardless of any
// simulated visibility state.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/views/home_view.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a resumed lifecycle event asks for a fresh frame, to recover from a stalled paint',
      (tester) async {
    await pumpHaLo(tester, (services) => HomeView(services: services));
    await tester.pumpAndSettle();

    expect(SchedulerBinding.instance.hasScheduledFrame, isFalse, reason: 'settled — nothing pending beforehand');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(
      SchedulerBinding.instance.hasScheduledFrame,
      isTrue,
      reason: 'HomeView must ask for a fresh frame on resume — if an animation (the FAB extend/collapse) was '
          'mid-transition when a tab/app was last backgrounded, this is what gives it a chance to finish or '
          'repaint at its actual current state instead of a stale one',
    );

    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
