// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The split's contract (docs/design/layouts.md): the preferred width is a
// caller-owned preference — clamped for layout when it doesn't fit, never
// written back; the persistence callback fires on drag END with what the
// user actually dragged to; and a null secondary keeps the primary subtree
// mounted at full width so state survives shirt-size flips.

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Widget harness({required Widget child, double width = 1000, double devicePixelRatio = 1.0}) => MediaQuery(
    data: MediaQueryData(size: Size(width, 600), devicePixelRatio: devicePixelRatio),
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(width: width, height: 600, child: child),
      ),
    ),
  );

  double primaryWidth(WidgetTester tester) => tester.getSize(find.byKey(const Key('primary'))).width;

  // The divider handle, found by its one distinguishing trait (the resize
  // cursor) rather than its visuals, which are free to change.
  final dividerHandle = find.byWidgetPredicate(
    (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeLeftRight,
  );

  const primary = SizedBox(key: Key('primary'), child: Text('primary'));
  const secondary = SizedBox(key: Key('secondary'), child: Text('secondary'));

  testWidgets('lays out primary at the preferred width', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(
        child: const ResizableSplitView(primary: primary, secondary: secondary, preferredPrimaryWidth: 500),
      ),
    );
    await tester.pumpAndSettle();

    expect(primaryWidth(tester), 500);
    // The default (solid) divider owns its own layout space between the
    // panes — the secondary starts after it, no overlay.
    expect(tester.getSize(find.byKey(const Key('secondary'))).width, 1000 - 500 - paneDividerWidth);
  });

  testWidgets('surfaces style: the secondary stretches to the primary edge (overlay divider)', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(
        child: const ResizableSplitView(
          primary: primary,
          secondary: secondary,
          preferredPrimaryWidth: 500,
          dividerStyle: SplitDividerStyle.surfaces,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(primaryWidth(tester), 500);
    expect(tester.getSize(find.byKey(const Key('secondary'))).width, 1000 - 500);
  });

  testWidgets('solid style: the divider bar is header-colored', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(
        child: const ResizableSplitView(primary: primary, secondary: secondary, preferredPrimaryWidth: 500),
      ),
    );
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(dividerHandle));
    final headerColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final bar = tester.widget<Container>(
      find.descendant(
        of: dividerHandle,
        matching: find.byWidgetPredicate((w) => w is Container && w.color == headerColor),
      ),
    );
    expect(bar.color, headerColor, reason: 'the solid divider reads as chrome: same surface as the header');
  });

  testWidgets('no preference defaults primary to 2/3 of the width, capped at sMax', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 900 * 2/3 = 600.
    await tester.pumpWidget(
      harness(
        width: 900,
        child: const ResizableSplitView(primary: primary, secondary: secondary),
      ),
    );
    await tester.pumpAndSettle();
    expect(primaryWidth(tester), 600);

    // 1200 * 2/3 = 800 → capped at sMax (720).
    tester.view.physicalSize = const Size(1200, 600);
    await tester.pumpWidget(
      harness(
        width: 1200,
        child: const ResizableSplitView(primary: primary, secondary: secondary),
      ),
    );
    await tester.pumpAndSettle();
    expect(primaryWidth(tester), ShirtSize.sMax);
  });

  testWidgets('resizable: false with primaryFraction sizes the primary as a fixed fraction and hides the drag handle',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(
        child: const ResizableSplitView(
          primary: primary,
          secondary: secondary,
          dividerStyle: SplitDividerStyle.surfaces,
          resizable: false,
          primaryFraction: 0.4,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1000 * 0.4 = 400 — tracks the window width, not a persisted preference.
    expect(primaryWidth(tester), 400);
    expect(dividerHandle, findsNothing, reason: 'a fixed split has nothing to drag');

    // Widening the window keeps the primary at 40%, unlike a resizable
    // split which would hold its preferred width steady.
    tester.view.physicalSize = const Size(1200, 600);
    await tester.pumpWidget(
      harness(
        width: 1200,
        child: const ResizableSplitView(
          primary: primary,
          secondary: secondary,
          dividerStyle: SplitDividerStyle.surfaces,
          resizable: false,
          primaryFraction: 0.4,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(primaryWidth(tester), 480);
  });

  testWidgets('a drag from the default seeds the preference at the shown width', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final reported = <double>[];
    await tester.pumpWidget(
      harness(
        width: 900,
        child: ResizableSplitView(primary: primary, secondary: secondary, onPreferredPrimaryWidthChanged: reported.add),
      ),
    );
    await tester.pumpAndSettle();

    // Default is 600 (2/3 of 900); a -50 drag lands at 550, i.e. relative
    // to the width the user actually saw, not to some hidden constant.
    // (Dragging outward would clamp: the default sits near the upper bound
    // 900 - minSecondary - grab strip = 609.)
    final gesture = await tester.startGesture(tester.getCenter(dividerHandle));
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump();
    expect(primaryWidth(tester), 550);

    await gesture.up();
    await tester.pump();
    expect(reported, [550]);
  });

  testWidgets('a mere click on the divider neither persists nor freezes the adaptive default', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final reported = <double>[];
    Widget build(double width) => harness(
      width: width,
      child: ResizableSplitView(primary: primary, secondary: secondary, onPreferredPrimaryWidthChanged: reported.add),
    );

    await tester.pumpWidget(build(900));
    await tester.pumpAndSettle();
    expect(primaryWidth(tester), 600); // 2/3 default

    // A tap (down + up, no movement) is not a resize.
    await tester.tap(dividerHandle, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(reported, isEmpty, reason: 'a click must not persist a preference');

    // And the default must still adapt to the window afterwards.
    tester.view.physicalSize = const Size(1050, 600);
    await tester.pumpWidget(build(1050));
    await tester.pumpAndSettle();
    expect(primaryWidth(tester), 700, reason: 'still 2/3-adaptive: a click must not freeze the width');
  });

  testWidgets('PaneSafeArea advises the secondary of the clearance in both styles', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    double? secondaryLeft;
    double? primaryLeft;
    Widget build(SplitDividerStyle style) => harness(
      child: ResizableSplitView(
        dividerStyle: style,
        primary: Builder(
          builder: (context) {
            primaryLeft = PaneSafeArea.leftOf(context);
            return primary;
          },
        ),
        secondary: Builder(
          builder: (context) {
            secondaryLeft = PaneSafeArea.leftOf(context);
            return secondary;
          },
        ),
        preferredPrimaryWidth: 500,
      ),
    );

    await tester.pumpWidget(build(SplitDividerStyle.surfaces));
    await tester.pumpAndSettle();
    expect(
      secondaryLeft,
      ResizableSplitView.dividerWidth,
      reason: 'surfaces: secondary content insets by the grab strip when it needs interactivity at the edge',
    );
    expect(primaryLeft, 0, reason: 'nothing overlays the primary');

    await tester.pumpWidget(build(SplitDividerStyle.solid));
    await tester.pumpAndSettle();
    // Zero clearance (the solid divider owns its own space), but the
    // MECHANISM must stay present — it's the insertion point for device
    // safe-area insets later.
    expect(secondaryLeft, 0, reason: 'solid: no overlay, no clearance needed');
    expect(
      PaneSafeArea.maybeOf(tester.element(find.byKey(const Key('secondary')))),
      isNotNull,
      reason: 'the PaneSafeArea wrapper itself must remain in the tree in solid style',
    );
  });

  testWidgets('an ambient device inset reaches only the pane whose edge is at that physical edge (issue #205)',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late PaneSafeArea primaryArea;
    late PaneSafeArea secondaryArea;
    Widget build({required bool twoPane}) => harness(
      child: PaneSafeArea(
        // Simulates a root view's real device insets (a notch top, a home
        // indicator bottom, a landscape cutout right).
        top: 10,
        right: 20,
        bottom: 30,
        child: ResizableSplitView(
          primary: Builder(
            builder: (context) {
              primaryArea = PaneSafeArea.maybeOf(context)!;
              return primary;
            },
          ),
          secondary: twoPane
              ? Builder(
                  builder: (context) {
                    secondaryArea = PaneSafeArea.maybeOf(context)!;
                    return secondary;
                  },
                )
              : null,
          preferredPrimaryWidth: 500,
        ),
      ),
    );

    await tester.pumpWidget(build(twoPane: true));
    await tester.pumpAndSettle();
    // Primary is at the split's left edge (a device edge) and top/bottom,
    // but its right edge borders secondary, not the device — so it must
    // NOT double-apply the device's right inset there.
    expect(primaryArea.top, 10, reason: 'primary sits at the top device edge');
    expect(primaryArea.right, 0, reason: 'primary borders secondary, not a device edge, on the right');
    expect(primaryArea.bottom, 30, reason: 'primary sits at the bottom device edge');
    // Secondary is at the split's right edge (a device edge) and top/bottom,
    // but its left edge borders the divider, not the device.
    expect(secondaryArea.top, 10, reason: 'secondary sits at the top device edge');
    expect(secondaryArea.right, 20, reason: 'secondary sits at the right device edge');
    expect(secondaryArea.bottom, 30, reason: 'secondary sits at the bottom device edge');

    await tester.pumpWidget(build(twoPane: false));
    await tester.pumpAndSettle();
    // Single-pane: primary occupies the whole width, so it owns BOTH the
    // left and right device edges.
    expect(primaryArea.right, 20, reason: 'single-pane: primary spans the full width, so it owns the right edge too');
  });

  testWidgets('the grab dots rest at half opacity and brighten on hover', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(
        child: const ResizableSplitView(primary: primary, secondary: secondary, preferredPrimaryWidth: 500),
      ),
    );
    await tester.pumpAndSettle();

    AnimatedOpacity dots() =>
        tester.widget<AnimatedOpacity>(find.descendant(of: dividerHandle, matching: find.byType(AnimatedOpacity)));
    expect(dots().opacity, 0.5, reason: 'resting: an invitation, not furniture');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(dividerHandle));
    await tester.pumpAndSettle();
    expect(dots().opacity, 1.0, reason: 'hover brightens the dots');

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(dots().opacity, 0.5, reason: 'leaving the strip dims them again');
  });

  testWidgets('the divider shadow is dark in light mode and light in dark mode', (tester) async {
    // A black shadow disappears into dark-mode pane surfaces; the boundary
    // needs a light "shadow" (glow) there instead.
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget build(ThemeData theme) => MediaQuery(
      data: const MediaQueryData(size: Size(1000, 600)),
      child: MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: ResizableSplitView(
            primary: primary,
            secondary: secondary,
            preferredPrimaryWidth: 500,
            dividerStyle: SplitDividerStyle.surfaces,
          ),
        ),
      ),
    );

    Color shadowEdgeColor() {
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(IgnorePointer),
          matching: find.byWidgetPredicate(
            (w) => w is DecoratedBox && (w.decoration as BoxDecoration).gradient != null,
          ),
        ),
      );
      return ((box.decoration as BoxDecoration).gradient! as LinearGradient).colors.first;
    }

    await tester.pumpWidget(build(ThemeData(brightness: Brightness.light)));
    await tester.pumpAndSettle();
    final light = shadowEdgeColor();
    expect(light.computeLuminance(), lessThan(0.5), reason: 'light mode: a dark shadow');

    await tester.pumpWidget(build(ThemeData(brightness: Brightness.dark)));
    await tester.pumpAndSettle();
    final dark = shadowEdgeColor();
    expect(dark.computeLuminance(), greaterThan(0.5), reason: 'dark mode: a light glow');
  });

  testWidgets('the divider shadow never blocks clicks on controls beneath it', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A full-pane button as the secondary; the shadow band extends one
    // pixel past the grab strip (shadowWidth 12 vs strip 11) — a tap in
    // that shadow-only sliver must reach the button (the shadow is
    // paint-only; ONLY the strip intercepts).
    var taps = 0;
    await tester.pumpWidget(
      harness(
        child: ResizableSplitView(
          dividerStyle: SplitDividerStyle.surfaces,
          primary: primary,
          secondary: GestureDetector(
            key: const Key('pane-button'),
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
          ),
          preferredPrimaryWidth: 500,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // x = 500 (primary) + 11.5: inside the shadow band, outside the strip.
    await tester.tapAt(const Offset(500 + 11.5, 300));
    expect(taps, 1, reason: 'the shadow overlay must be paint-only');
  });

  testWidgets('null secondary gives primary the full width and keeps its state', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A stateful child whose State identity we can track across the flip.
    final fieldKey = GlobalKey<FormFieldState<String>>();
    final statefulPrimary = TextFormField(key: fieldKey, initialValue: '');

    Widget build({required bool twoPane}) => harness(
      child: ResizableSplitView(
        primary: statefulPrimary,
        secondary: twoPane ? secondary : null,
        preferredPrimaryWidth: 500,
      ),
    );

    await tester.pumpWidget(build(twoPane: false));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(TextFormField)).width, 1000);
    expect(find.byKey(const Key('secondary')), findsNothing);

    fieldKey.currentState!.didChange('in-progress input');

    // Flip to two-pane: the secondary appears, the primary animates down to
    // its preferred width, and the primary's State survives.
    await tester.pumpWidget(build(twoPane: true));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(TextFormField)).width, 500);
    expect(find.byKey(const Key('secondary')), findsOneWidget);
    expect(fieldKey.currentState!.value, 'in-progress input');
  });

  testWidgets('clamps an oversized preference for layout without writing it back', (tester) async {
    tester.view.physicalSize = const Size(700, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final reported = <double>[];
    await tester.pumpWidget(
      harness(
        width: 700,
        child: ResizableSplitView(
          primary: primary,
          secondary: secondary,
          preferredPrimaryWidth: 600, // doesn't fit: 700 - minSecondary(280) - divider
          onPreferredPrimaryWidthChanged: reported.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(primaryWidth(tester), 700 - 280 - paneDividerWidth);
    expect(reported, isEmpty, reason: 'clamping must never write back the preference');
  });

  testWidgets('respects minPrimaryWidth and maxPrimaryWidth', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(
        child: const ResizableSplitView(
          primary: primary,
          secondary: secondary,
          preferredPrimaryWidth: 100,
          minPrimaryWidth: 300,
          maxPrimaryWidth: 450,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(primaryWidth(tester), 300);

    await tester.pumpWidget(
      harness(
        child: const ResizableSplitView(
          primary: primary,
          secondary: secondary,
          preferredPrimaryWidth: 800,
          minPrimaryWidth: 300,
          maxPrimaryWidth: 450,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(primaryWidth(tester), 450);
  });

  testWidgets('dragging the divider resizes live and reports once on drag end', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final reported = <double>[];
    await tester.pumpWidget(
      harness(
        child: ResizableSplitView(
          primary: primary,
          secondary: secondary,
          preferredPrimaryWidth: 500,
          onPreferredPrimaryWidthChanged: reported.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final divider = dividerHandle;
    final gesture = await tester.startGesture(tester.getCenter(divider));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();

    // Live during the drag (no settle needed — drag snaps, no animation).
    expect(primaryWidth(tester), 600);
    expect(reported, isEmpty, reason: 'callback fires on drag end, not per frame');

    await gesture.moveBy(const Offset(-250, 0));
    await tester.pump();
    expect(primaryWidth(tester), 350);

    await gesture.up();
    await tester.pump();
    expect(reported, [350]);
  });

  testWidgets('fractional drag deltas land on whole-pixel widths', (tester) async {
    // Real mouse deltas are fractional; a pane edge that lands between
    // device pixels antialiases against its neighbor and reads as a
    // hairline seam along the divider. At 1x, the device grid is whole
    // logical pixels.
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final reported = <double>[];
    await tester.pumpWidget(
      harness(
        child: ResizableSplitView(
          primary: primary,
          secondary: secondary,
          preferredPrimaryWidth: 500,
          onPreferredPrimaryWidthChanged: reported.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(dividerHandle));
    await gesture.moveBy(const Offset(50.4, 0));
    await tester.pump();
    expect(primaryWidth(tester), 550);

    await gesture.up();
    await tester.pump();
    expect(reported, [550]);
  });

  testWidgets('pane edges snap to the DEVICE pixel grid, not whole logical pixels', (tester) async {
    // At 2x, half logical pixels are exact device pixels — snapping must use
    // that grid (÷ UiScale × devicePixelRatio), or a non-1.0 font scale
    // would put whole-logical-pixel edges between device pixels again.
    tester.view.physicalSize = const Size(2000, 1200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(
        devicePixelRatio: 2.0,
        child: const ResizableSplitView(primary: primary, secondary: secondary, preferredPrimaryWidth: 500),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(dividerHandle));
    await gesture.moveBy(const Offset(50.3, 0));
    await tester.pump();

    // 550.3 logical → 1100.6 device px → snaps to 1101 → 550.5 logical.
    expect(primaryWidth(tester), 550.5);
    expect(primaryWidth(tester) * 2, isA<double>().having((w) => w == w.roundToDouble(), 'integral device px', isTrue));

    await gesture.up();
    await tester.pump();
  });

  testWidgets('drag cannot push the width outside what fits', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final reported = <double>[];
    await tester.pumpWidget(
      harness(
        child: ResizableSplitView(
          primary: primary,
          secondary: secondary,
          preferredPrimaryWidth: 500,
          onPreferredPrimaryWidthChanged: reported.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Overshoot far past the right edge: the width pins at
    // total - minSecondary - divider while the VIRTUAL drag position keeps
    // tracking the pointer — so a reversal is ignored until the pointer
    // has traveled all the way back to the divider (otherwise the divider
    // would start moving far away from the cursor).
    final divider = dividerHandle;
    final gesture = await tester.startGesture(tester.getCenter(divider));
    const overshootTo = 500.0 + 5000.0; // virtual position after the move
    await gesture.moveBy(const Offset(5000, 0));
    await tester.pump();
    final pinned = 1000 - 280 - paneDividerWidth;
    expect(primaryWidth(tester), pinned);

    // Reversing while the cursor is still far past the limit: no movement.
    await gesture.moveBy(const Offset(-1000, 0));
    await tester.pump();
    expect(primaryWidth(tester), pinned, reason: 'reversal is ignored until the pointer is back at the divider');

    // Travel the rest of the way back to the divider, then 10 more: now it
    // follows the cursor again.
    await gesture.moveBy(Offset(-(overshootTo - 1000 - pinned) - 10, 0));
    await tester.pump();
    expect(primaryWidth(tester), pinned - 10, reason: 'movement resumes once the pointer reaches the divider');

    await gesture.up();
    await tester.pump();
    expect(reported, [pinned - 10]);
  });

  testWidgets('mid-animation frames never overflow the Row', (tester) async {
    // Regression: flipping two-pane → single-pane let the primary claim the
    // full width while the divider was still animating out, overflowing the
    // Row by up to dividerWidth for the animation's duration.
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget build({required bool twoPane}) => harness(
      child: ResizableSplitView(primary: primary, secondary: twoPane ? secondary : null, preferredPrimaryWidth: 500),
    );

    await tester.pumpWidget(build(twoPane: true));
    await tester.pumpAndSettle();

    await tester.pumpWidget(build(twoPane: false));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull, reason: 'frame $i of the flip-out must not overflow');
    }
    expect(primaryWidth(tester), 1000);

    // And back in.
    await tester.pumpWidget(build(twoPane: true));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull, reason: 'frame $i of the flip-in must not overflow');
    }
    expect(primaryWidth(tester), 500);
  });

  testWidgets('an external preference change is adopted (and animates)', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget build(double preferred) => harness(
      child: ResizableSplitView(primary: primary, secondary: secondary, preferredPrimaryWidth: preferred),
    );

    await tester.pumpWidget(build(400));
    await tester.pumpAndSettle();
    expect(primaryWidth(tester), 400);

    await tester.pumpWidget(build(550));
    await tester.pump(const Duration(milliseconds: 100));
    final midway = primaryWidth(tester);
    expect(midway, greaterThan(400));
    expect(midway, lessThan(550));

    await tester.pumpAndSettle();
    expect(primaryWidth(tester), 550);
  });
}
