// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/config/tester_notes.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import 'support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FontScale Settings & Logic', () {
    test('FontScale factors are correct', () {
      expect(FontScale.smallest.scaleFactor, 0.70);
      expect(FontScale.smaller.scaleFactor, 0.85);
      expect(FontScale.normal.scaleFactor, 1.00);
      expect(FontScale.larger.scaleFactor, 1.20);
      expect(FontScale.largest.scaleFactor, 1.40);
    });

    test('SettingsService: default scale, updates, and persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();

      expect(settings.fontScale, FontScale.normal);

      int listenerCalls = 0;
      settings.addListener(() {
        listenerCalls++;
      });

      await settings.setFontScale(FontScale.larger);
      expect(settings.fontScale, FontScale.larger);
      expect(listenerCalls, 1);

      // Verify it persists in shared preferences
      final settingsReloaded = await SettingsService.load();
      expect(settingsReloaded.fontScale, FontScale.larger);
    });

    test('SettingsService: step-by-step increase/decrease helpers', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();

      expect(settings.fontScale, FontScale.normal); // index 2

      await settings.increaseFontScale();
      expect(settings.fontScale, FontScale.larger); // index 3

      await settings.increaseFontScale();
      expect(settings.fontScale, FontScale.largest);

      // Past Largest the shortcuts keep going into the two shortcut-only
      // levels — that extra range is the whole point of them being reachable
      // here but not from the Settings picker.
      await settings.increaseFontScale();
      expect(settings.fontScale, FontScale.largestPlus);

      await settings.increaseFontScale();
      expect(settings.fontScale, FontScale.largestPlusPlus);

      // ...and stop at the top.
      await settings.increaseFontScale();
      expect(settings.fontScale, FontScale.largestPlusPlus);

      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.largestPlus);

      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.largest);

      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.larger);

      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.normal);

      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.smaller);

      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.smallest);

      // Symmetrically, two shortcut-only levels below Smallest.
      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.smallestMinus);

      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.smallestMinusMinus);

      // ...and stop at the bottom.
      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.smallestMinusMinus);
    });

    test('only the middle five are selectable; the extremes are shortcut-only', () {
      expect(
        FontScale.selectableValues,
        [FontScale.smallest, FontScale.smaller, FontScale.normal, FontScale.larger, FontScale.largest],
      );
      // Ascending order is load-bearing: increase/decrease step by index.
      final factors = FontScale.values.map((s) => s.scaleFactor).toList();
      expect(factors, orderedEquals([...factors]..sort()), reason: 'enum must stay in ascending scale order');
    });

    test('an extended scale annotates the nearest selectable level, not its own row', () {
      expect(FontScale.largestPlusPlus.nearestSelectable, FontScale.largest);
      expect(FontScale.largestPlus.nearestSelectable, FontScale.largest);
      expect(FontScale.smallestMinusMinus.nearestSelectable, FontScale.smallest);
      expect(FontScale.smallestMinus.nearestSelectable, FontScale.smallest);
      // A selectable level anchors to itself, so the picker shows it plainly.
      expect(FontScale.normal.nearestSelectable, FontScale.normal);
      expect(FontScale.largest.nearestSelectable, FontScale.largest);
    });

    testWidgets('UiScale scales the whole subtree: children lay out in size/scale and paint scaled up', (tester) async {
      // The font-scale mechanism: everything under UiScale sees a MediaQuery
      // whose size is divided by the scale, and a fixed-size child paints back
      // up by the scale. A 400x400 box at scale 2.0 fills an 800x800 window.
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late Size innerSize;
      late double reportedScale;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: UiScale(
              scale: 2.0,
              child: Builder(builder: (context) {
                innerSize = MediaQuery.sizeOf(context);
                reportedScale = UiScale.of(context);
                return const SizedBox(key: Key('box'), width: 400, height: 400);
              }),
            ),
          ),
        ),
      );

      // The subtree believes the screen is half the real size...
      expect(innerSize, const Size(400, 400));
      expect(reportedScale, 2.0);
      // ...and the 400-logical box paints at 800 physical (fills the window).
      expect(tester.getSize(find.byKey(const Key('box'))), const Size(400, 400));
      final rect = tester.getRect(find.byKey(const Key('box')));
      expect(rect.width, 800); // scaled up by 2.0 on screen
      expect(rect.height, 800);
    });

    testWidgets('UiScale magnifies under LOOSE constraints, not just tight ones', (tester) async {
      // The regression that broke every scale above Normal: the app root is a
      // Stack, and a Stack hands non-positioned children LOOSE constraints.
      // FittedBox only scales up to the constraints it is given, so it
      // shrink-wrapped instead — the subtree still laid out in the divided
      // space (the UI reflowed) but was never magnified.
      //
      // The asymmetry is why it hid, and why this test checks BOTH directions:
      // below 1.0 the child is larger than the window and gets clamped, which
      // looks perfectly correct.
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Future<double> paintedHeightAt(double scale) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(800, 800)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              // A deliberately loose parent, standing in for the root Stack.
              child: Align(
                alignment: Alignment.topLeft,
                child: UiScale(
                  scale: scale,
                  // Aligned, so the box keeps its natural 100pt size instead
                  // of being stretched to the (divided) viewport by UiScale's
                  // own sizing SizedBox — otherwise this measures the viewport
                  // rather than the magnification.
                  child: const Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(key: Key('box'), width: 100, height: 100),
                  ),
                ),
              ),
            ),
          ),
        );
        return tester.getRect(find.byKey(const Key('box'))).height;
      }

      // A 100pt box paints at 100 * scale regardless of how it was constrained.
      expect(await paintedHeightAt(0.5), closeTo(50, 0.01), reason: 'scaling down already worked');
      expect(await paintedHeightAt(2.0), closeTo(200, 0.01), reason: 'scaling UP is what was broken');
    });

    testWidgets('UiScale at 1.0 is a pass-through', (tester) async {
      late double reportedScale;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UiScale(
            scale: 1.0,
            child: Builder(builder: (context) {
              reportedScale = UiScale.of(context);
              return const SizedBox();
            }),
          ),
        ),
      );
      expect(reportedScale, 1.0);
      expect(find.byType(Transform), findsNothing); // no transform inserted
    });

    testWidgets('SubtreeUiScale scales a pane UNIFORMLY, whatever shape the pane is', (tester) async {
      // The bug this exists to prevent: UiScale sizes its inner box to the
      // ambient MediaQuery — the WINDOW — and lets BoxFit.fill stretch it to
      // the constraints it is given. At the root those agree. Nested in a
      // pane they do not, so the two axes stretch by different factors and a
      // square comes out a rectangle: on screen, text that went NARROWER
      // instead of larger. Nothing throws.
      //
      // A tall, narrow pane in a wide window makes the two disagree as much
      // as possible.
      tester.view.physicalSize = const Size(1000, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late double reportedScale;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1000, 500)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                height: 400,
                child: SubtreeUiScale(
                  scale: 2.0,
                  child: Builder(builder: (context) {
                    reportedScale = UiScale.of(context);
                    return const Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(key: Key('square'), width: 50, height: 50),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      );

      final painted = tester.getRect(find.byKey(const Key('square')));
      expect(painted.width, painted.height, reason: 'a square must stay square — this is the whole defect');
      // And at the factor asked for, not merely uniformly wrong.
      expect(painted.width, 100);
      // The ABSOLUTE scale, which is what PixelGrid snaps against.
      expect(reportedScale, 2.0);
    });

    testWidgets('SubtreeUiScale magnifies under LOOSE constraints too', (tester) async {
      // The same trap the root UiScale hit, in the same way: FittedBox only
      // scales up to the constraints it is GIVEN, and a LayoutBuilder passes
      // its incoming ones straight through — so measuring them is not the
      // same as tightening them. Handed loose ones the box shrink-wraps and
      // the mechanism degrades silently: the subtree lays out in the divided
      // space (so MORE fits on screen, and the pane looks like it shrank) but
      // is never magnified.
      tester.view.physicalSize = const Size(600, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(600, 600)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            // A Stack hands its non-positioned children loose constraints —
            // which is exactly what sits above this in the real view.
            child: Stack(
              children: [
                SubtreeUiScale(
                  scale: 2.0,
                  child: Builder(
                    builder: (context) => const Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(key: Key('square'), width: 50, height: 50),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.getRect(find.byKey(const Key('square'))).width, 100);
    });

    testWidgets('SubtreeUiScale at the scale already in force draws the same and keeps its shape', (tester) async {
      late Size innerSize;
      Future<void> pumpAt(double subtree) => tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(size: Size(800, 800)),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: UiScale(
                  scale: 1.4,
                  child: SizedBox(
                    width: 400,
                    height: 400,
                    child: SubtreeUiScale(
                      scale: subtree,
                      child: Builder(builder: (context) {
                        innerSize = MediaQuery.sizeOf(context);
                        return const SizedBox(key: Key('box'), width: 100, height: 100);
                      }),
                    ),
                  ),
                ),
              ),
            ),
          );

      // Asking for the level already in effect is a no-op in what it DRAWS —
      // the relative factor is 1.0, so nothing below is divided or magnified.
      await pumpAt(1.4);
      final identitySize = innerSize;
      final identityBox = tester.getRect(find.byKey(const Key('box')));
      final atIdentity = find.byType(FittedBox).evaluate().length;

      // But it must not be a no-op in the TREE. Returning the child unwrapped
      // at 1.0 makes the widget chain a function of the value, so dialling a
      // pane's override past whatever the app is already at unmounts the
      // pane's whole subtree on the way through — a map reloading its tiles,
      // a half-typed field cleared.
      await pumpAt(1.9);
      expect(find.byType(FittedBox).evaluate().length, atIdentity);
      // And it still scales: a level ABOVE the ambient one divides the space
      // the subtree lays out in, while painting to the same box on screen.
      expect(innerSize.width, moreOrLessEquals(identitySize.width * 1.4 / 1.9, epsilon: 0.01));
      expect(tester.getRect(find.byKey(const Key('box'))).width, moreOrLessEquals(identityBox.width, epsilon: 0.01));
    });
  });

  group('Keyboard Shortcuts', () {
    // Drives the REAL key handler in main.dart through HaLoApp, so a change
    // to the production key mapping (dropping a key, changing the modifier
    // gate) fails here — a handler copied into the test could not.
    testWidgets('Cmd+=/-/_/0 drive the app-wide font scale handler', (tester) async {
      SharedPreferences.setMockInitialValues({});
      setReleaseNotesForTesting(const []);
      setTesterNotesForTesting(const []);
      final HaLoHarness(:services, :settings) = await makeHaLoServices(prefs: null);

      await tester.pumpWidget(TranslationProvider(child: HaLoApp(services: services)));
      await tester.pumpAndSettle();

      expect(settings.fontScale, FontScale.normal);

      // Simulate Cmd + =
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(settings.fontScale, FontScale.larger);

      // Reset with Cmd + 0
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(settings.fontScale, FontScale.normal);

      // Decrease with Cmd + -
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(settings.fontScale, FontScale.smaller);

      // Cmd + _ with no shift actually held. Layouts that put `_` on an
      // unshifted key still zoom; the SHIFTED forms belong to Layout Density
      // now (density_shortcuts_test.dart), and this asserts the modifier gate
      // is what separates them rather than the logical key alone.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.minus,
          logicalKey: LogicalKeyboardKey.underscore,
          timeStamp: Duration.zero,
        ),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(settings.fontScale, FontScale.smallest);
      expect(settings.densityPreference, DensityPreference.auto, reason: 'no shift held, so density is untouched');

      // Without the modifier nothing changes.
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      expect(settings.fontScale, FontScale.smallest);

      // Drain pending timers to avoid test errors.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('Device pixel grid', () {
    testWidgets('the header height lands on whole device pixels at every font scale', (tester) async {
      // The header's bottom edge is a color boundary against the body, so an
      // off-grid height antialiases into the content below as a hairline
      // seam. The base 48 is fine at 1.0 but not at 0.85 (48 × 0.85 × 2.0 =
      // 81.6 device px), so main.dart snaps it into the theme once for the
      // whole app — this drives the real HaLoApp so that wiring is what's
      // under test, not a copy of the arithmetic.
      tester.view.physicalSize = const Size(2400, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      setReleaseNotesForTesting(const []);
      setTesterNotesForTesting(const []);
      final HaLoHarness(:services, :settings) = await makeHaLoServices(prefs: null);
      await settings.setFontScale(FontScale.smaller);

      await tester.pumpWidget(TranslationProvider(child: HaLoApp(services: services)));
      await tester.pumpAndSettle();

      final height = tester.getSize(find.byType(AppBar).first).height;
      final devicePixels = height * FontScale.smaller.scaleFactor * 2.0;
      expect(
        devicePixels,
        moreOrLessEquals(devicePixels.roundToDouble()),
        reason: 'header height $height is off the device grid',
      );
      // Snapping moves it by less than a device pixel, not to some other size.
      expect(height, moreOrLessEquals(48.0, epsilon: 1.0));

      // Drain pending timers to avoid test errors.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
