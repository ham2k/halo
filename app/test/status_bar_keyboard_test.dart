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
      await tester.tap(find.byType(StatusBarFooter));
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
