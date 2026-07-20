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
  Widget harness({required DockNode spec, ValueChanged<DockNode>? onChanged, Map<String, Widget>? children}) =>
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
