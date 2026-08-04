// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The dock prototype's contract: the tree round-trips through JSON (that's
// what SettingsService persists); dragging a tab onto another group's side
// splits that group, onto its center joins it as a tab; the mutated tree is
// reported through onSpecChanged; and a module's State survives being moved
// (the whole point of user-arrangeable panes — a half-typed field must not
// reset because its pane was docked elsewhere).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Widget harness({
    required DockNode spec,
    ValueChanged<DockNode>? onChanged,
    Map<String, Widget>? children,
    Map<String, WidgetBuilder>? tabActions,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: DockLayoutView(
            initialSpec: spec,
            titles: const {'a': 'Alpha', 'b': 'Bravo', 'c': 'Charlie'},
            children: children ??
                const {
                  'a': SizedBox.expand(key: Key('pane-a')),
                  'b': SizedBox.expand(key: Key('pane-b')),
                  'c': SizedBox.expand(key: Key('pane-c')),
                },
            tabActions: tabActions,
            onSpecChanged: onChanged,
          ),
        ),
      );

  DockNode twoGroups() => DockSplit(Axis.horizontal, [
    DockGroup(['a']),
    DockGroup(['b', 'c']),
  ], [1, 1]);

  /// Drags the tab labeled [label] to [target], slowly enough for the drop
  /// regions (which only mount once the drag starts) to appear and hit-test.
  Future<void> dragTab(WidgetTester tester, String label, Offset target) async {
    final start = tester.getCenter(find.text(label).first);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  test('spec round-trips through JSON', () {
    final spec = DockSplit(Axis.horizontal, [
      DockGroup(['a']),
      DockSplit(Axis.vertical, [
        DockGroup(['b', 'c'], selected: 1),
        DockGroup(['d']),
      ], [2, 1]),
    ], [3, 2]);
    final revived = DockNode.fromJson(spec.toJson())!;
    expect(revived.toJson(), spec.toJson());
    expect(revived.collectModules(), ['a', 'b', 'c', 'd']);
  });

  test('specMatches guards persisted specs against module drift', () {
    final spec = twoGroups();
    expect(DockLayoutView.specMatches(spec, ['a', 'b', 'c']), isTrue);
    expect(DockLayoutView.specMatches(spec, ['a', 'b']), isFalse, reason: 'extra module in spec');
    expect(DockLayoutView.specMatches(spec, ['a', 'b', 'c', 'd']), isFalse, reason: 'missing module');
    expect(DockLayoutView.specMatches(null, ['a']), isFalse);
  });

  testWidgets('renders a group per spec leaf with all modules mounted', (tester) async {
    await tester.pumpWidget(harness(spec: twoGroups()));
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);
    // Unselected tab content stays MOUNTED (IndexedStack, offstage),
    // preserving state.
    expect(find.byKey(const Key('pane-c'), skipOffstage: false), findsOneWidget);
  });

  testWidgets("a tab-action always shows for a standalone module's own header", (tester) async {
    // Group 'a' has one module — solo modules are always their own group's
    // selected tab, so an action registered for 'a' shows unconditionally.
    await tester.pumpWidget(harness(
      spec: twoGroups(),
      tabActions: {'a': (context) => const Icon(MdiIcons.tune, key: Key('action-a'))},
    ));
    expect(find.byKey(const Key('action-a')), findsOneWidget);
  });

  testWidgets('a tab-action only shows when its module is the selected tab in a combined group', (tester) async {
    // Group ['b', 'c'] starts with 'b' selected (index 0) — 'c's action must
    // stay hidden until 'c' becomes the active tab, since the group's header
    // has no room to show every tab's own action at once.
    await tester.pumpWidget(harness(
      spec: twoGroups(),
      tabActions: {'c': (context) => const Icon(MdiIcons.tune, key: Key('action-c'))},
    ));
    expect(find.byKey(const Key('action-c')), findsNothing);

    await tester.tap(find.text('Charlie'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('action-c')), findsOneWidget);
  });

  testWidgets('an ambient device inset reaches only the group whose edge is at that physical edge (issue #205)',
      (tester) async {
    final areas = <String, PaneSafeArea>{};
    Widget capture(String id) => Builder(
      builder: (context) {
        areas[id] = PaneSafeArea.maybeOf(context)!;
        return SizedBox.expand(key: Key('pane-$id'));
      },
    );

    final spec = DockSplit(Axis.horizontal, [
      DockGroup(['a']),
      DockGroup(['b']),
      DockGroup(['c']),
    ], [1, 1, 1]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaneSafeArea(
            // Simulates a root view's real device insets.
            left: 10,
            top: 20,
            right: 30,
            bottom: 40,
            child: DockLayoutView(
              initialSpec: spec,
              titles: const {'a': 'Alpha', 'b': 'Bravo', 'c': 'Charlie'},
              children: {'a': capture('a'), 'b': capture('b'), 'c': capture('c')},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Leading child: owns the split's left edge, not its right (which
    // borders the middle child, not the device).
    expect(areas['a']!.left, 10, reason: 'leading child sits at the left device edge');
    expect(areas['a']!.right, 0, reason: 'leading child borders the middle child, not a device edge');
    // Cross-axis (top/bottom) isn't divided by a horizontal split — every
    // child keeps it unchanged.
    expect(areas['a']!.top, 20);
    expect(areas['a']!.bottom, 40);

    // Middle child: touches no device edge on the split's own axis.
    expect(areas['b']!.left, 0, reason: 'middle child touches no device edge on the split axis');
    expect(areas['b']!.right, 0, reason: 'middle child touches no device edge on the split axis');
    expect(areas['b']!.top, 20);
    expect(areas['b']!.bottom, 40);

    // Trailing child: owns the split's right edge, not its left.
    expect(areas['c']!.left, 0, reason: 'trailing child borders the middle child, not a device edge');
    expect(areas['c']!.right, 30, reason: 'trailing child sits at the right device edge');
    expect(areas['c']!.top, 20);
    expect(areas['c']!.bottom, 40);
  });

  testWidgets("a group's own tab strip clears the real device inset only at its own edge, not the outer ambient "
      '(issue #205)', (tester) async {
    // _buildGroup is a plain Dart call from _buildSplit, not a fresh Element
    // — it must use a position-correct Builder context for its tab strip's
    // padding, not DockLayoutView's own outer `State.context` (which would
    // give every group in the tree the SAME padding regardless of position).
    final spec = DockSplit(Axis.horizontal, [
      DockGroup(['a']),
      DockGroup(['b']),
    ], [1, 1]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaneSafeArea(
            left: 10,
            right: 20,
            child: DockLayoutView(
              initialSpec: spec,
              titles: const {'a': 'Alpha', 'b': 'Bravo'},
              children: const {'a': SizedBox.expand(key: Key('pane-a')), 'b': SizedBox.expand(key: Key('pane-b'))},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The tab strip's own Padding wraps a SingleChildScrollView directly —
    // a structurally unique ancestor, unlike Padding (which _DockTab's own
    // label also uses internally).
    Padding tabStripPaddingFor(String label) => tester.widget<Padding>(
      find.ancestor(
        of: find.ancestor(of: find.text(label), matching: find.byType(SingleChildScrollView)),
        matching: find.byType(Padding),
      ).first,
    );

    final alphaPadding = tabStripPaddingFor('Alpha').padding.resolve(TextDirection.ltr);
    final bravoPadding = tabStripPaddingFor('Bravo').padding.resolve(TextDirection.ltr);

    expect(alphaPadding.left, 10, reason: "leading group's tab strip clears the left device edge");
    expect(alphaPadding.right, 0, reason: "leading group's tab strip borders the trailing group, not a device edge");
    expect(bravoPadding.left, 0, reason: "trailing group's tab strip borders the leading group, not a device edge");
    expect(bravoPadding.right, 20, reason: "trailing group's tab strip clears the right device edge");
  });

  testWidgets('tapping a tab selects it and persists the selection', (tester) async {
    final spec = twoGroups();
    DockNode? reported;
    await tester.pumpWidget(harness(spec: spec, onChanged: (s) => reported = s));
    await tester.tap(find.text('Charlie'));
    await tester.pump();
    expect(((spec as DockSplit).children[1] as DockGroup).selected, 1);
    // Selection is serialized in the spec, so a tap must reach the
    // persistence callback — otherwise the layout reopens on a stale tab.
    expect(reported, isNotNull);
  });

  testWidgets('revealModule surfaces a hidden module without persisting', (tester) async {
    final spec = twoGroups();
    final key = GlobalKey<DockLayoutViewState>();
    DockNode? reported;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DockLayoutView(
          key: key,
          initialSpec: spec,
          titles: const {'a': 'Alpha', 'b': 'Bravo', 'c': 'Charlie'},
          children: const {
            'a': SizedBox.expand(key: Key('pane-a')),
            'b': SizedBox.expand(key: Key('pane-b')),
            'c': SizedBox.expand(key: Key('pane-c')),
          },
          onSpecChanged: (s) => reported = s,
        ),
      ),
    ));
    key.currentState!.revealModule('c');
    await tester.pump();
    expect(((spec as DockSplit).children[1] as DockGroup).selected, 1);
    expect(reported, isNull, reason: 'a programmatic reveal is not a user arrangement choice');
  });

  testWidgets('divider drag on panes already below the minimum does not throw', (tester) async {
    // Two panes at ~96px each — both below the 120px minimum, the state a
    // persisted spec produces in a smaller window. clamp() with inverted
    // bounds would throw here on every drag frame.
    tester.view.physicalSize = const Size(200, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final spec = twoGroups();
    await tester.pumpWidget(harness(spec: spec));
    final divider = find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeLeftRight,
    );
    await tester.drag(divider, const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('dropping a tab on a group side splits it', (tester) async {
    DockNode? reported;
    await tester.pumpWidget(harness(spec: twoGroups(), onChanged: (s) => reported = s));
    // Drag Charlie onto the BOTTOM region of the left (Alpha) group — but
    // clear of the dock's own 20px bottom edge strip, which wins there.
    final alphaPane = tester.getRect(find.byKey(const Key('pane-a')));
    await dragTab(tester, 'Charlie', Offset(alphaPane.center.dx, alphaPane.bottom - 40));
    expect(reported, isNotNull);
    final root = reported! as DockSplit;
    expect(root.axis, Axis.horizontal);
    final left = root.children[0] as DockSplit;
    expect(left.axis, Axis.vertical);
    expect((left.children[0] as DockGroup).modules, ['a']);
    expect((left.children[1] as DockGroup).modules, ['c']);
    expect((root.children[1] as DockGroup).modules, ['b']);
  });

  testWidgets('dropping a tab on a group center joins it as a tab', (tester) async {
    DockNode? reported;
    await tester.pumpWidget(harness(spec: twoGroups(), onChanged: (s) => reported = s));
    final alphaPane = tester.getRect(find.byKey(const Key('pane-a')));
    await dragTab(tester, 'Bravo', alphaPane.center);
    final root = reported! as DockSplit;
    expect((root.children[0] as DockGroup).modules, ['a', 'b']);
    expect((root.children[0] as DockGroup).selected, 1, reason: 'the dropped module becomes the selected tab');
    expect((root.children[1] as DockGroup).modules, ['c']);
  });

  testWidgets('moving the last module out of a group collapses the empty group', (tester) async {
    DockNode? reported;
    await tester.pumpWidget(harness(spec: twoGroups(), onChanged: (s) => reported = s));
    final bravoPane = tester.getRect(find.byKey(const Key('pane-b')));
    await dragTab(tester, 'Alpha', bravoPane.center);
    // The left group emptied out; the single-child root split collapsed.
    final root = reported! as DockGroup;
    expect(root.modules, ['b', 'c', 'a']);
  });

  testWidgets('dragging a divider shifts the sibling weights and reports on drag end', (tester) async {
    final spec = twoGroups() as DockSplit;
    DockNode? reported;
    await tester.pumpWidget(harness(spec: spec, onChanged: (s) => reported = s));
    final divider = find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeLeftRight,
    );
    await tester.drag(divider, const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(spec.weights[0], lessThan(spec.weights[1]));
    expect(reported, isNotNull, reason: 'resize persists via onSpecChanged at drag end');
  });

  testWidgets('module State survives being moved to another group', (tester) async {
    final spec = twoGroups();
    await tester.pumpWidget(harness(
      spec: spec,
      children: {
        // GlobalKey'd like the real panes in OperationView.
        'a': _Counter(key: GlobalKey(), label: 'count-a'),
        'b': const SizedBox.expand(key: Key('pane-b')),
        'c': const SizedBox.expand(key: Key('pane-c')),
      },
    ));
    await tester.tap(find.text('count-a: 0'));
    await tester.pump();
    expect(find.text('count-a: 1'), findsOneWidget);
    final bravoPane = tester.getRect(find.byKey(const Key('pane-b')));
    await dragTab(tester, 'Alpha', bravoPane.center);
    expect(find.text('count-a: 1'), findsOneWidget, reason: 'moving a pane must not reset its State');
  });

  testWidgets('pane boundaries land on whole device pixels and tile the run', (tester) async {
    // Weight-derived extents are fractional, and a boundary that falls
    // between device pixels antialiases into both — the neighboring panes
    // blend there and it reads as a hairline gap along the divider. Every
    // edge must snap to the device grid AND the panes plus dividers must
    // still cover the run exactly, with nothing left over at the end.
    tester.view.physicalSize = const Size(2500, 1500);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(
        spec: DockSplit(Axis.horizontal, [
          DockGroup(['a']),
          DockGroup(['b']),
          DockGroup(['c']),
        ], [1, 2, 3]),
      ),
    );
    await tester.pumpAndSettle();

    final panes = [
      for (final key in ['pane-a', 'pane-b', 'pane-c']) tester.getRect(find.byKey(Key(key))),
    ];
    for (final pane in panes) {
      for (final edge in [pane.left, pane.right]) {
        expect(edge * 2.5, moreOrLessEquals((edge * 2.5).roundToDouble()), reason: 'edge $edge is off the device grid');
      }
    }
    // Weights still respected (within one device pixel of the ideal share),
    // and the run is covered end to end.
    expect(panes.first.left, 0);
    expect(panes.last.right, moreOrLessEquals(1000));
    final available = 1000 - paneDividerWidth * 2;
    expect(panes[0].width, moreOrLessEquals(available / 6, epsilon: 0.4));
    expect(panes[1].width, moreOrLessEquals(available * 2 / 6, epsilon: 0.4));
  });

  testWidgets('snapping never pushes the panes past the end of the run', (tester) async {
    // Snapping rounds to the NEAREST device pixel, so an intermediate
    // boundary can round past a run whose own end is off-grid — and then the
    // children overflow it. Both halves are reachable: a vertical split's
    // height is the window minus the AppBar (off-grid at several scales), and
    // fromJson accepts any finite positive weights, so a degenerate persisted
    // spec gives the last pane less than a device pixel to round away.
    tester.view.physicalSize = const Size(2500, 1500);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    // 500.3 × 2.5 = 1250.75 device px: the grid point above the run's end is
    // within rounding reach of the boundary before it.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500.3,
            height: 600,
            child: DockLayoutView(
              initialSpec: DockNode.fromJson({
                'type': 'split',
                'axis': 'h',
                'children': [
                  {'type': 'group', 'modules': ['a']},
                  {'type': 'group', 'modules': ['b']},
                ],
                'weights': [1, 0.000001],
              })!,
              titles: const {'a': 'Alpha', 'b': 'Bravo'},
              children: const {
                'a': SizedBox.expand(key: Key('pane-a')),
                'b': SizedBox.expand(key: Key('pane-b')),
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'the panes must not overflow the run');
    expect(tester.getRect(find.byKey(const Key('pane-b'))).right, moreOrLessEquals(500.3));
  });
}

class _Counter extends StatefulWidget {
  final String label;

  const _Counter({super.key, required this.label});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => _count++),
      child: Text('${widget.label}: $_count'),
    );
  }
}
