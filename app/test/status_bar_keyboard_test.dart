// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The status footer stays visible while the on-screen keyboard is up, riding
// directly above it (docs/design/user-interface.md § "Footer & User Feedback").
// It used to be hidden outright at that moment — which is exactly when a sync's
// progress or a command's output matters most, since the operator is typing.
//
// These pump the REAL `StatusBarOverlay`, not a copy of its layout. That is the
// point: what's under test is a relationship between three children the overlay
// owns, so a Column reproduced in the test would keep passing no matter what
// the real one did. It is `@visibleForTesting` for exactly this.
//
// The load-bearing assertion is geometric, not "is it in the tree" — the bug
// was a footer that existed but sat behind the keyboard, so a presence check
// would have passed against the broken code.
//
// The overlay is mounted the way `MaterialApp.builder` mounts it: ABOVE the
// routes, so nothing has consumed the keyboard inset yet. Putting it inside a
// Scaffold body instead would read an inset of 0 and silently test nothing
// (see keyboard_dismiss.dart's note on the same trap).

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import 'fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const keyboardHeight = 300.0;

  late HaLoServices services;
  late HaLoDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
    db = HaLoDatabase(NativeDatabase.memory());
    services = HaLoServices(db, settings);
  });

  tearDown(() async => db.close());

  /// Runs [body] with the platform overridden.
  ///
  /// `debugDefaultTargetPlatformOverride` must be back to null before the test
  /// body returns — the framework's invariant check runs right after, ahead of
  /// any tearDown/addTearDown callback — hence try/finally rather than a shared
  /// setUp/tearDown (same reasoning as logging_controls_test.dart's mobile
  /// autocorrect group).
  Future<void> on(TargetPlatform platform, Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  void raiseKeyboard(WidgetTester tester) {
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
  }

  double windowHeight(WidgetTester tester) => tester.view.physicalSize.height / tester.view.devicePixelRatio;

  /// The overlay in the position `MaterialApp.builder` gives it — above the
  /// routes, so the keyboard inset is still unconsumed on the way in.
  ///
  /// [child] stands in for the Navigator. It defaults to a Scaffold that opts
  /// out of resizing, like Home and Operation do; pass a plain one to model
  /// every OTHER route, which does not.
  Future<void> pumpOverlay(WidgetTester tester, {Widget? child}) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        builder: (context, _) => StatusBarOverlay(
          services: services,
          child: child ?? const Scaffold(resizeToAvoidBottomInset: false, body: SizedBox.expand()),
        ),
        home: const SizedBox.shrink(),
      ),
    ));
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // the footer's grow/switch animations
  }

  Future<void> postProgress(WidgetTester tester) async {
    services.statusBar.setProgress(key: 'sync', title: 'Syncing', value: 0.4);
    await settle(tester);
  }

  testWidgets('on mobile the footer rides above the keyboard rather than hiding', (tester) async {
    await on(TargetPlatform.iOS, () async {
      raiseKeyboard(tester);
      await pumpOverlay(tester);
      await postProgress(tester);

      final footer = find.byType(StatusBarFooter);
      expect(footer, findsOneWidget, reason: 'the footer must not be hidden while the keyboard is up');

      // The real check: its bottom edge sits at the top of the keyboard, not at
      // the bottom of the window. Before this change it was flush with the
      // window bottom — i.e. behind the keyboard — which made it invisible.
      expect(
        tester.getBottomLeft(footer).dy,
        moreOrLessEquals(windowHeight(tester) - keyboardHeight, epsilon: 1.0),
      );
    });
  });

  testWidgets('with the keyboard down the footer sits at the bottom of the window', (tester) async {
    await on(TargetPlatform.iOS, () async {
      await pumpOverlay(tester);
      await postProgress(tester);

      expect(
        tester.getBottomLeft(find.byType(StatusBarFooter)).dy,
        moreOrLessEquals(windowHeight(tester), epsilon: 1.0),
      );
    });
  });

  testWidgets('a notice also stays visible while the keyboard is up', (tester) async {
    await on(TargetPlatform.iOS, () async {
      raiseKeyboard(tester);
      await pumpOverlay(tester);

      services.statusBar.showNotice(key: 'n', icon: 'bug', title: 'Heads up', text: 'sample');
      await settle(tester);

      final notices = find.byType(NoticeStack);
      expect(notices, findsOneWidget, reason: 'notices were hidden along with the footer and must not be');
      expect(tester.getBottomLeft(notices).dy, lessThan(windowHeight(tester) - keyboardHeight + 1.0));
    });
  });

  // A desktop window reports no bottom inset at all, so the footer sits on the
  // window edge without needing a platform check. (An earlier revision gated
  // the reservation on `isWindowedPlatform`, which also excluded mobile WEB —
  // where the inset IS reported and nothing else holds it back.)
  testWidgets('with no reported inset the footer sits on the window edge', (tester) async {
    await on(TargetPlatform.macOS, () async {
      await pumpOverlay(tester);
      await postProgress(tester);

      expect(
        tester.getBottomLeft(find.byType(StatusBarFooter)).dy,
        moreOrLessEquals(windowHeight(tester), epsilon: 1.0),
      );
    });
  });

  // The overlay must CONSUME the inset, not just reserve it. Only Home and
  // Operation opt out of Scaffold resizing; every other route is a stock
  // Scaffold that shrinks its own body by `viewInsets.bottom`. If the inset
  // survives into the routes, those shrink a second time — measured as a form
  // squeezed into a third of its height with a keyboard-tall blank band above
  // the keyboard.
  testWidgets('a route that resizes for the keyboard is not shrunk twice', (tester) async {
    await on(TargetPlatform.iOS, () async {
      const bodyKey = Key('route-body');
      raiseKeyboard(tester);
      await pumpOverlay(tester, child: const Scaffold(body: SizedBox.expand(key: bodyKey)));
      await postProgress(tester);

      // The body should fill everything the overlay handed the route: the
      // window, less the footer and the keyboard strip — and no less.
      final footerTop = tester.getTopLeft(find.byType(StatusBarFooter)).dy;
      expect(
        tester.getBottomLeft(find.byKey(bodyKey)).dy,
        moreOrLessEquals(footerTop, epsilon: 1.0),
        reason: 'the route reserved the keyboard a second time',
      );
    });
  });

  // A notice must take only what it needs. Making it `Flexible` to stop a
  // landscape overflow looked right and was not: it then competed with the
  // `Expanded` above for the free space and took an equal share, so any visible
  // notice halved the whole app — on every platform, keyboard or not.
  testWidgets('a notice does not steal height from the app', (tester) async {
    await on(TargetPlatform.iOS, () async {
      const bodyKey = Key('route-body');
      await pumpOverlay(tester, child: const Scaffold(resizeToAvoidBottomInset: false, body: SizedBox.expand(key: bodyKey)));

      final before = tester.getSize(find.byKey(bodyKey)).height;
      services.statusBar.showNotice(key: 'n', icon: 'bug', title: 'Heads up', text: 'sample');
      await settle(tester);
      final after = tester.getSize(find.byKey(bodyKey)).height;

      final noticeHeight = tester.getSize(find.byType(NoticeStack)).height;
      expect(before - after, moreOrLessEquals(noticeHeight, epsilon: 1.0),
          reason: 'the app should give up exactly the notice, not share the window with it');
      expect(after, greaterThan(before * 0.75),
          reason: 'an ordinary notice must not take a large fraction of the app');
    });
  });

  // …and it still has to fit above the keyboard, which is what the flexible
  // version was reaching for: NoticeStack sizes a card against the FULL window
  // height, which overflowed the Column in landscape once the strip took the
  // bottom.
  testWidgets('a notice fits above the keyboard in landscape', (tester) async {
    await on(TargetPlatform.iOS, () async {
      tester.view.physicalSize = Size(844 * tester.view.devicePixelRatio, 390 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.viewInsets = FakeViewPadding(bottom: 200 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await pumpOverlay(tester);
      // Everything that competes for the bottom at once: enough status items to
      // make the footer expandable, the footer EXPANDED, and a notice. The
      // footer caps itself the same way the notice does, so capping only one of
      // them still overflowed here — measured at 62px, with the app squeezed to
      // zero height.
      for (var i = 0; i < 6; i++) {
        services.statusBar.setMessage(key: 'm$i', text: 'Item $i');
      }
      await settle(tester);
      // pumpAndSettle, not `settle`: the two frames that suffice for the
      // footer's own grow animation do not carry the InkWell's tap through,
      // and a tap that silently does nothing makes this whole test vacuous —
      // hence the guard below.
      await tester.tap(find.byType(StatusBarFooter));
      await tester.pumpAndSettle();

      services.statusBar.showNotice(
        key: 'n',
        icon: 'bug',
        title: 'Heads up',
        text: 'A notice long enough to want more room than the space above the keyboard can give it, '
            'so its own cap is what decides how tall it ends up being.',
      );
      await settle(tester);

      expect(tester.takeException(), isNull, reason: 'the Column must not overflow');
      // And the app still gets something to draw in, rather than being crushed
      // to nothing by the chrome below it.
      final windowH = windowHeight(tester);
      expect(
        tester.getSize(find.byType(StatusBarFooter)).height,
        lessThan((windowH - 200) * 0.5),
        reason: 'the expanded footer must cap against the space above the keyboard, not the window',
      );
    });
  });

  // Everything that shares the bottom, at once, in the tightest geometry the
  // app can actually reach. Each piece used to size itself against the whole
  // window independently, so their sum could exceed the strip they share.
  //
  // The reachable tight case is a LANDSCAPE phone at a large font scale, not a
  // small window on its own: `UiScale` implements the Font Scale setting by
  // dividing the window and the insets it passes down, while the numbers row's
  // 52 and the collapsed footer's 28 stay fixed — so the fixed chrome grows
  // from 42% of the space above the keyboard to 80% of it. This sets up the
  // divided geometry directly, which is exactly what the overlay is handed.
  //
  // Portrait never reaches this; it is not worth a case of its own here.
  //
  // The last two rows are the ones that matter most: they are not the roundest
  // numbers but the geometries that CAUGHT the band bug, and they bracket it
  // from both sides. 390/200 at 1.90 leaves the notice stack exactly its own
  // band height, so it sat precisely at break-even and passed while the code
  // was wrong; a hair tighter in either direction — a taller keyboard, a
  // shorter phone — and the stack overran the window by 3-5pt.
  for (final (device, keyboard, scale, appKeepsRoom) in const [
    (390.0, 200.0, 1.00, true),
    (390.0, 200.0, 1.40, true),
    (390.0, 200.0, 1.90, true),
    (390.0, 210.0, 1.90, true), // overran by 5.27pt
    (375.0, 215.0, 1.65, true), // iPhone SE on its side: overran by 3.03pt
  ]) {
    testWidgets('the whole bottom chrome fits in landscape, $device/$keyboard at font scale $scale', (tester) async {
      await on(TargetPlatform.iOS, () async {
        const bodyKey = Key('route-body');
        // A phone on its side, as UiScale divides it.
        final dpr = tester.view.devicePixelRatio;
        tester.view.physicalSize = Size(844 / scale * dpr, device / scale * dpr);
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard / scale * dpr);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);

        await pumpOverlay(tester, child: const Scaffold(resizeToAvoidBottomInset: false, body: SizedBox.expand(key: bodyKey)));

        // A numbers row, as a focused logging field publishes one.
        services.keyboardAccessory.publish(
          Object(),
          const KeyboardAccessorySpec(
            onKey: _noop,
            vibrate: false,
            backgroundColor: 0xFF102030,
            foregroundColor: 0xFFFFFFFF,
            extraKey: '/',
          ),
        );
        for (var i = 0; i < 6; i++) {
          services.statusBar.setMessage(key: 'm$i', text: 'Item $i');
        }
        await settle(tester);
        services.statusBar.showNotice(
          key: 'n',
          icon: 'bug',
          title: 'Heads up',
          text: 'A notice long enough to want more room than the space above the keyboard can give it, '
              'so its own cap is what decides how tall it ends up being.',
        );
        await settle(tester);

        expect(tester.takeException(), isNull, reason: 'the Column must not overflow');
        expect(find.byType(NumberKeys), findsOneWidget);
        expect(find.byType(NoticeStack), findsOneWidget, reason: 'the notice is clipped when short of room, never dropped');

        // `takeException` is necessary but not sufficient: an overflow is only
        // reported on the frame it is laid out, and anything that consumed it
        // earlier leaves this green over a broken layout (which is exactly how
        // the band bug survived its first verification). Measure the boxes.
        final window = tester.getSize(find.byType(StatusBarOverlay)).height;
        final chrome = tester.getSize(find.byType(NoticeStack)).height +
            tester.getSize(find.byType(StatusBarFooter)).height +
            tester.getSize(find.byType(NumberKeys)).height +
            keyboard / scale;
        expect(
          chrome,
          lessThanOrEqualTo(window + 0.01),
          reason: 'the chrome below the app must fit the window without it',
        );

        // The app keeps a real share at every reachable scale — not merely a
        // non-negative height, which a box can never fail.
        expect(
          tester.getSize(find.byKey(bodyKey)).height,
          appKeepsRoom ? greaterThan(0) : greaterThanOrEqualTo(0),
          reason: 'the chrome below the app must not overrun it',
        );
        expect(
          tester.getSize(find.byKey(bodyKey)).height,
          moreOrLessEquals(window - chrome, epsilon: 0.01),
          reason: 'the app gets exactly what the chrome left, no more and no less',
        );
      });
    });
  }

  // The expanded footer, which is the whole point of `footerMax` and the one
  // state the geometry cases above never enter. Without this, deleting
  // `collapsedFooter +` from the budget changes nothing any test can see: the
  // footer is 28 either way while collapsed.
  testWidgets('expanding the footer does not push the chrome past the window', (tester) async {
    await on(TargetPlatform.iOS, () async {
      const bodyKey = Key('route-body');
      final dpr = tester.view.devicePixelRatio;
      tester.view.physicalSize = Size(844 / 1.4 * dpr, 390 / 1.4 * dpr);
      tester.view.viewInsets = FakeViewPadding(bottom: 200 / 1.4 * dpr);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);

      await pumpOverlay(tester, child: const Scaffold(resizeToAvoidBottomInset: false, body: SizedBox.expand(key: bodyKey)));
      services.keyboardAccessory.publish(
        Object(),
        const KeyboardAccessorySpec(
          onKey: _noop,
          vibrate: false,
          backgroundColor: 0xFF102030,
          foregroundColor: 0xFFFFFFFF,
          extraKey: '/',
        ),
      );
      // Far more rows than the budget can seat, so the cap is what decides.
      for (var i = 0; i < 20; i++) {
        services.statusBar.setMessage(key: 'm$i', text: 'Item $i');
      }
      await settle(tester);

      final collapsed = tester.getSize(find.byType(StatusBarFooter)).height;
      // pumpAndSettle, not `settle`: the two frames that suffice for the
      // footer's own grow animation do not carry the InkWell's tap through,
      // and a tap that silently does nothing makes this whole test vacuous —
      // hence the guard below.
      await tester.tap(find.byType(StatusBarFooter));
      await tester.pumpAndSettle();
      final expanded = tester.getSize(find.byType(StatusBarFooter)).height;
      expect(expanded, greaterThan(collapsed), reason: 'the tap must actually expand it, or this asserts nothing');

      expect(tester.takeException(), isNull, reason: 'expanding must not overflow the Column');
      final window = tester.getSize(find.byType(StatusBarOverlay)).height;
      expect(
        expanded + tester.getSize(find.byType(NumberKeys)).height + 200 / 1.4,
        lessThanOrEqualTo(window + 0.01),
        reason: 'the expanded footer plus the row and keyboard must still fit',
      );
      expect(tester.getSize(find.byKey(bodyKey)).height, greaterThanOrEqualTo(0));

      // Not just "it fits" — it has to be exactly what the budget allowed.
      // With 20 items the content dwarfs the cap, so the cap is the only thing
      // deciding this height, which makes it a direct read-back of `footerMax`.
      // Merely asserting it fits leaves the budget free to hand over any
      // smaller number without a single test noticing.
      final budget = BottomChromeBudget.of(
        windowHeight: window,
        keyboardInset: 200 / 1.4,
        hasNumbersRow: true,
        hasStatusItems: true,
        numbersRowHeight: NumberKeys.heightFor(LayoutMetrics.normal),
        footerHeight: LayoutMetrics.normal.statusBarCollapsed,
      );
      // Epsilon covers PixelGrid snapping, which rounds the rendered height
      // to the device pixel grid — the budget deals in raw logical pixels and
      // the widget lands on the nearest grid line.
      expect(
        expanded,
        moreOrLessEquals(budget.footerMax, epsilon: 0.5),
        reason: 'the expanded footer must land on its budget, collapsed height included',
      );
    });
  });

  // The arithmetic on its own. The geometry cases above can only catch a bad
  // budget where a widget happens to render at its cap; this pins the contract
  // directly, across the whole reachable range, and is where the band bug was
  // cheapest to find.
  test('BottomChromeBudget never promises more than the window holds', () {
    // Landscape phones get landscape keyboards and portrait gets portrait
    // ones; a 300pt keyboard in a 390pt window is not a configuration iOS
    // produces, and asserting against it only measures the impossible.
    for (final (device, keyboards) in const [
      (390.0, [0.0, 150.0, 200.0, 215.0]),
      (375.0, [0.0, 150.0, 200.0, 215.0]),
      (844.0, [0.0, 250.0, 300.0, 340.0]),
    ]) {
      for (final keyboard in keyboards) {
        for (final scale in [0.7, 1.0, 1.4, 1.65, 1.9]) {
          for (final hasRow in [true, false]) {
            for (final hasItems in [true, false]) {
              final window = device / scale;
              final inset = keyboard / scale;
              // The density axis. Both the numbers row and the footer are
              // density-resolved now, so the invariants have to hold at every
              // density the operator can actually BE in here — which is what
              // resolving each preference against this window gives, rather
              // than all five rungs independently.
              //
              // That distinction is load-bearing, not pedantry: every
              // geometry in this matrix is short enough to sit below the
              // `normal` band, so the ceiling in `DensityPreference.resolve`
              // clamps every pick to what the height allows. Iterating the
              // rungs directly instead asks whether `sparsest`'s 96pt of
              // fixed chrome fits a 197pt window — it does not, and it is
              // also unreachable. The ceiling is what keeps the budget
              // solvable at these sizes.
              for (final preference in DensityPreference.values) {
              final density = preference.resolve(window);
              final numbersRowHeight = NumberKeys.heightFor(density.metrics);
              final footerHeight = density.metrics.statusBarCollapsed;
              final budget = BottomChromeBudget.of(
                windowHeight: window,
                keyboardInset: inset,
                hasNumbersRow: hasRow,
                hasStatusItems: hasItems,
                numbersRowHeight: numbersRowHeight,
                footerHeight: footerHeight,
              );
              final where = '$device/$keyboard @$scale row=$hasRow items=$hasItems pref=$preference d=$density';

              expect(budget.noticeMax, greaterThanOrEqualTo(0), reason: 'negative cap at $where');
              expect(budget.footerMax, greaterThanOrEqualTo(0), reason: 'negative cap at $where');

              // Both caps are TOTALS for their widget, so everything at its
              // limit at once is the worst case the Column can be asked to
              // lay out. It has to fit what is left of the window.
              final worstCase = budget.noticeMax + budget.footerMax + (hasRow ? numbersRowHeight : 0.0) + inset;
              expect(
                worstCase,
                lessThanOrEqualTo(window + 0.01),
                reason: 'chrome at full cap overruns the window at $where',
              );

              // Space is only charged for what is actually drawn. Without
              // items the footer is a zero-height box, so charging its
              // collapsed height anyway would quietly shrink the notice for a
              // widget that is not there.
              if (hasItems) {
                final withoutItems = BottomChromeBudget.of(
                  windowHeight: window,
                  keyboardInset: inset,
                  hasNumbersRow: hasRow,
                  hasStatusItems: false,
                  numbersRowHeight: numbersRowHeight,
                  footerHeight: footerHeight,
                );
                if (budget.noticeMax > 0) {
                  expect(
                    withoutItems.noticeMax,
                    greaterThan(budget.noticeMax),
                    reason: 'an absent footer must free up room at $where',
                  );
                }
              }
              }
            }
          }
        }
      }
    }
  });

  // The strip is painted, and painted in the app-bar colour. Both halves
  // survived mutation before this existed — an unpainted strip flashes the
  // scaffold background full-width across the bottom on every keyboard slide,
  // which is the exact thing the colour is there to prevent.
  testWidgets('the keyboard strip is painted in the app-bar colour', (tester) async {
    await on(TargetPlatform.iOS, () async {
      raiseKeyboard(tester);
      await pumpOverlay(tester);
      await postProgress(tester);

      final strip = find.descendant(
        of: find.byType(StatusBarOverlay),
        matching: find.byType(ColoredBox),
      );
      expect(strip, findsWidgets, reason: 'the strip must actually be painted');
      final painted = tester.widgetList<ColoredBox>(strip).last;
      final theme = Theme.of(tester.element(find.byType(StatusBarFooter)));
      expect(painted.color, theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary);
    });
  });

  // Anything padding by `viewInsets.bottom` below the overlay double-pads for
  // the same reason (`_BrandingPane`, the split-view divider handle).
  testWidgets('a descendant reading viewInsets sees them already consumed', (tester) async {
    await on(TargetPlatform.iOS, () async {
      raiseKeyboard(tester);
      double? seen;
      await pumpOverlay(
        tester,
        child: Builder(builder: (context) {
          seen = MediaQuery.viewInsetsOf(context).bottom;
          return const Scaffold(resizeToAvoidBottomInset: false, body: SizedBox.expand());
        }),
      );
      expect(seen, 0.0, reason: 'the overlay must consume the bottom inset on the way down');
    });
  });
}

void _noop(String _) {}
