// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The split's contract (docs/design/layouts.md): the preferred width is a
// caller-owned preference — clamped for layout when it doesn't fit, never
// written back; the persistence callback fires on drag END with what the
// user actually dragged to; and a null secondary keeps the primary subtree
// mounted at full width so state survives shirt-size flips.

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
    expect(tester.getSize(find.byKey(const Key('secondary'))).width, 1000 - 500 - ResizableSplitView.dividerWidth);
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

    expect(primaryWidth(tester), 700 - 280 - ResizableSplitView.dividerWidth);
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
    // total - minSecondary - divider, and the drag doesn't accumulate
    // invisible overshoot the user would have to drag back through.
    final divider = dividerHandle;
    final gesture = await tester.startGesture(tester.getCenter(divider));
    await gesture.moveBy(const Offset(5000, 0));
    await tester.pump();
    final pinned = 1000 - 280 - ResizableSplitView.dividerWidth;
    expect(primaryWidth(tester), pinned);

    await gesture.moveBy(const Offset(-1, 0));
    await tester.pump();
    expect(primaryWidth(tester), pinned - 1, reason: 'reversal takes effect immediately');

    await gesture.up();
    await tester.pump();
    expect(reported, [pinned - 1]);
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
