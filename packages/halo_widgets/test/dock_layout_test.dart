// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The dock prototype's contract: the tree round-trips through JSON (that's
// what SettingsService persists); dragging a tab onto another group's TAB
// STRIP joins that group at the position aimed at (which is also how tabs
// are reordered), onto one of its body's four split bands divides it, and
// onto the middle of its body does nothing; the mutated tree is reported
// through onSpecChanged; and a module's State survives being moved (the
// whole point of user-arrangeable panes — a half-typed field must not reset
// because its pane was docked elsewhere).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Widget harness({
    required DockNode spec,
    ValueChanged<DockNode>? onChanged,
    ValueChanged<DockState>? onStateChanged,
    DockState initialState = DockState.empty,
    Map<String, Widget>? children,
    Map<String, WidgetBuilder>? tabActions,
    // Re-pumping with a different spec but no key changes NOTHING: the view
    // copies initialSpec into its State once and owns it from then on. A
    // test that varies the spec across pumps has to vary this too, or it
    // silently measures the first spec twice.
    Key? key,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: DockLayoutView(
            key: key,
            initialSpec: spec,
            initialState: initialState,
            onStateChanged: onStateChanged,
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

  /// The strip a tab sits in: the group header's own Material, the nearest
  /// one above the tab (TabChrome brings no Material of its own).
  Rect stripAround(WidgetTester tester, String label) =>
      tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(Material)).first);

  Rect tabRect(WidgetTester tester, String label) =>
      tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(TabChrome)).first);

  testWidgets('tabs divide the strip evenly and fill its height', (tester) async {
    await tester.pumpWidget(harness(spec: twoGroups()));
    final strip = stripAround(tester, 'Bravo');
    final bravo = tabRect(tester, 'Bravo');
    final charlie = tabRect(tester, 'Charlie');

    // A shrink-wrapped tab paints its bottom-border selection indicator at
    // the label's bottom edge, not the strip's — so indicators in the dock
    // sit higher than the ones in the fixed layouts right beside them.
    expect(bravo.height, strip.height, reason: 'a tab fills the strip so its indicator lands on the strip floor');
    expect(charlie.bottom, strip.bottom);

    expect(bravo.width, moreOrLessEquals(charlie.width),
        reason: 'tabs share the strip like a stock TabBar, not at natural widths');
    expect(bravo.width + charlie.width, moreOrLessEquals(strip.width), reason: 'and between them they fill it');

    // A group of one is still a tab bar of one — it stretches rather than
    // huddling at the header's left edge.
    expect(tabRect(tester, 'Alpha').width, moreOrLessEquals(stripAround(tester, 'Alpha').width));
  });

  testWidgets("a module's action sits inside its own tab, and the label stays centered around it", (tester) async {
    Widget withAction(int selected, Key key) => harness(
          key: key,
          spec: DockGroup(['b', 'c'], selected: selected),
          tabActions: {'b': (context) => IconButton(icon: const Icon(MdiIcons.tune), onPressed: () {})},
        );

    await tester.pumpWidget(withAction(0, const ValueKey(0)));
    final bravoTab = tabRect(tester, 'Bravo');
    final action = tester.getRect(find.byType(IconButton));
    expect(action.right, lessThanOrEqualTo(bravoTab.right), reason: "the action is the TAB's trailing widget");
    expect(action.left, greaterThanOrEqualTo(bravoTab.left));

    // Centered on the tab, not merely on what the handle and the action
    // leave behind: an action reserved on one side only would push every
    // label of a group off-centre against its neighbours.
    expect(tester.getRect(find.text('Bravo')).center.dx, moreOrLessEquals(bravoTab.center.dx));

    // ...and still centered on the same spot once the handle and the action
    // are gone, which is what reserving both slots on both edges buys.
    await tester.pumpWidget(withAction(1, const ValueKey(1)));
    expect(find.byType(IconButton), findsNothing, reason: 'an action shows only while its own tab is selected');
    expect(tabRect(tester, 'Bravo'), bravoTab);
    expect(tester.getRect(find.text('Bravo')).center.dx, moreOrLessEquals(bravoTab.center.dx));
  });

  testWidgets('tab widths hold still while the selection moves', (tester) async {
    // Narrow enough that the tabs' own content sets their width — with room
    // to spare they all take an equal share of the strip instead, which
    // would hide the reservation this test is about.
    tester.view.physicalSize = const Size(200, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(spec: DockGroup(['b', 'c']), key: const ValueKey(0)));
    final withBravoSelected = tabRect(tester, 'Bravo');

    await tester.pumpWidget(harness(spec: DockGroup(['b', 'c'], selected: 1), key: const ValueKey(1)));
    // The grab handle only SHOWS on the selected tab, but it always takes
    // its space: the tabs' shared width is set by the widest tab's content,
    // so a handle that came and went would resize every tab in the group
    // each time the selection moved.
    expect(tabRect(tester, 'Bravo'), withBravoSelected);
  });

  testWidgets('tabs too wide for the strip keep their width and scroll', (tester) async {
    tester.view.physicalSize = const Size(200, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(spec: twoGroups()));
    final strip = stripAround(tester, 'Bravo');
    final bravo = tabRect(tester, 'Bravo');

    // The fallback is a scroll, never a squeeze: a tab narrower than its own
    // label would clip the label instead of the strip clipping the tab.
    expect(bravo.width, greaterThan(strip.width / 2));
    expect(bravo.width + tabRect(tester, 'Charlie').width, greaterThan(strip.width));
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

  testWidgets('tapping a tab reports STATE, never the arrangement', (tester) async {
    final spec = twoGroups();
    DockNode? reportedSpec;
    DockState? reportedState;
    await tester.pumpWidget(harness(
      spec: spec,
      onChanged: (s) => reportedSpec = s,
      onStateChanged: (s) => reportedState = s,
    ));
    await tester.tap(find.text('Charlie'));
    await tester.pump();

    expect(((spec as DockSplit).children[1] as DockGroup).selected, 1);
    expect(reportedState?.selected, contains('c'));
    // The arrangement did not change, so nothing may be written as though it
    // had: while selection lived in the spec, looking at another pane was an
    // edit, and a stand-in arrangement shown for a moment could be persisted
    // over the operator's real one by nothing more than a tab tap.
    expect(reportedSpec, isNull);
  });

  testWidgets('a group opens on its remembered module, and on its first without one', (tester) async {
    final spec = twoGroups();
    await tester.pumpWidget(harness(spec: spec, initialState: const DockState(selected: {'c'})));
    await tester.pump();
    expect(((spec as DockSplit).children[1] as DockGroup).selected, 1);

    // Keyed by module id rather than by index or position, so state survives
    // the dock being rearranged underneath it: the same module stays on top
    // wherever it ends up.
    final moved = DockSplit(Axis.horizontal, [
      DockGroup(['a', 'c']),
      DockGroup(['b']),
    ], [1, 1]);
    await tester.pumpWidget(harness(spec: moved, initialState: const DockState(selected: {'c'}), key: UniqueKey()));
    await tester.pump();
    expect((moved.children[0] as DockGroup).selected, 1, reason: "'c' is on top of whichever group holds it");

    // And a definition carries no selection at all, so an arrangement with
    // nothing remembered opens on its first tab.
    expect((DockNode.fromJson(twoGroups().toJson()) as DockSplit).children[1], isA<DockGroup>()
        .having((g) => g.selected, 'selected', 0));
  });

  testWidgets('removeModule drops a pane, prunes what it empties, and reports', (tester) async {
    DockNode? reported;
    final key = GlobalKey<DockLayoutViewState>();
    await tester.pumpWidget(harness(spec: twoGroups(), onChanged: (n) => reported = n, key: key));

    expect(key.currentState!.removeModule('a'), isTrue);
    await tester.pumpAndSettle();

    expect(key.currentState!.modules, ['b', 'c']);
    // 'a' was its group's only module, so the group AND the split that held
    // it both collapse — a spec left holding an empty group would render a
    // pane-sized nothing with a tab strip on top of it.
    expect(reported, isA<DockGroup>());
    // Removing a pane is a user arrangement choice, not a reveal: it has to
    // survive the relaunch, so it reports like a drop does.
    expect(reported!.collectModules(), ['b', 'c']);
  });

  testWidgets('the last module cannot be removed', (tester) async {
    DockNode? reported;
    final key = GlobalKey<DockLayoutViewState>();
    await tester.pumpWidget(harness(spec: DockGroup(['a']), onChanged: (n) => reported = n, key: key));

    // An empty dock has no tab left to drag anything back with, so the
    // layout would be unrecoverable from inside the view.
    expect(key.currentState!.removeModule('a'), isFalse);
    expect(key.currentState!.modules, ['a']);
    expect(reported, isNull, reason: 'a refused removal must not persist anything either');
  });

  testWidgets('addModule brings a pane back as a selected tab of the last group', (tester) async {
    DockNode? reported;
    final key = GlobalKey<DockLayoutViewState>();
    await tester.pumpWidget(harness(spec: twoGroups(), onChanged: (n) => reported = n, key: key));

    key.currentState!.removeModule('b');
    await tester.pumpAndSettle();
    key.currentState!.addModule('b');
    await tester.pumpAndSettle();

    // The far side of the dock from the primary pane, and showing: a pane
    // added back into a group behind an unselected tab looks like nothing
    // happened.
    expect(key.currentState!.modules, ['a', 'c', 'b']);
    final trailing = (reported! as DockSplit).children.last as DockGroup;
    expect(trailing.modules[trailing.selected], 'b');
  });

  testWidgets('adding a module already in the layout reveals it instead of duplicating it', (tester) async {
    final key = GlobalKey<DockLayoutViewState>();
    await tester.pumpWidget(harness(spec: twoGroups(), key: key));

    key.currentState!.addModule('c');
    await tester.pumpAndSettle();

    // Two tabs for one module would give it two mount points in the
    // IndexedStack — the pane's own State would fork.
    expect(key.currentState!.modules, ['a', 'b', 'c']);
    expect(find.text('Charlie'), findsOneWidget);
  });

  testWidgets('replaceSpec swaps the whole arrangement and reports it', (tester) async {
    DockNode? reported;
    final key = GlobalKey<DockLayoutViewState>();
    await tester.pumpWidget(harness(spec: DockGroup(['a']), onChanged: (n) => reported = n, key: key));

    // What "reset layout" runs on: initialSpec is read once, so a view can
    // only restore its default arrangement through this.
    key.currentState!.replaceSpec(twoGroups());
    await tester.pumpAndSettle();

    expect(key.currentState!.modules, ['a', 'b', 'c']);
    expect(reported?.collectModules(), ['a', 'b', 'c']);
  });

  testWidgets('a group publishes which of its panes is on top', (tester) async {
    final visibility = <String, bool>{};
    Widget probe(String id) => Builder(
          builder: (context) {
            visibility[id] = DockPaneVisibility.of(context);
            return SizedBox.expand(key: Key('pane-$id'));
          },
        );
    await tester.pumpWidget(harness(
      spec: DockGroup(['a', 'b']),
      children: {'a': probe('a'), 'b': probe('b')},
    ));

    // Every pane in a group stays MOUNTED so in-progress input survives a
    // tab switch, which means a pane that costs something to keep current —
    // an extension panel crossing the JS bridge — has no other way to learn
    // that nobody is looking at it.
    expect(visibility['a'], isTrue);
    expect(visibility['b'], isFalse);

    await tester.tap(find.text('Bravo'));
    await tester.pumpAndSettle();
    expect(visibility['a'], isFalse);
    expect(visibility['b'], isTrue);
  });

  testWidgets('a pane outside a dock counts as visible', (tester) async {
    late bool visible;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        visible = DockPaneVisibility.of(context);
        return const SizedBox.shrink();
      }),
    ));
    // The fixed layouts and every test build panes with no dock above them;
    // defaulting to invisible would stop them working.
    expect(visible, isTrue);
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

  testWidgets('a pane dropped on a band takes that band\'s third, and grows into it', (tester) async {
    DockNode? reported;
    await tester.pumpWidget(harness(spec: twoGroups(), onChanged: (s) => reported = s));
    final alphaPane = tester.getRect(find.byKey(const Key('pane-a')));

    // Mid-animation: the newcomer is on its way to its share, not already
    // occupying it — a layout that arrives fully formed is one the operator
    // has to re-read rather than watch happen.
    final gesture = await tester.startGesture(tester.getCenter(find.text('Charlie')));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveTo(Offset(alphaPane.center.dx, alphaPane.bottom - 40));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final growing = tester.getRect(find.byKey(const Key('pane-c'))).height;

    await tester.pumpAndSettle();
    final settled = tester.getRect(find.byKey(const Key('pane-c'))).height;
    expect(growing, lessThan(settled), reason: 'the pane opens up rather than appearing at full size');

    // A third for the newcomer, two for what it was dropped on: the band the
    // operator aimed at IS a third, so the pane arrives at the size they were
    // looking at when they let go.
    final split = (reported! as DockSplit).children[0] as DockSplit;
    expect(split.weights[1] / (split.weights[0] + split.weights[1]), moreOrLessEquals(1 / 3, epsilon: 0.001));
  });

  testWidgets('a pane dropped beside a sibling takes its third out of that sibling alone', (tester) async {
    DockNode? reported;
    // Three panes in a row: dropping beside the middle one must not move the
    // outer two, which are no part of what was dropped on.
    await tester.pumpWidget(harness(
      spec: DockSplit(Axis.horizontal, [DockGroup(['a']), DockGroup(['b']), DockGroup(['c'])], [1, 1, 1]),
      onChanged: (s) => reported = s,
    ));
    final bravoPane = tester.getRect(find.byKey(const Key('pane-b')));
    await dragTab(tester, 'Charlie', Offset(bravoPane.left + 20, bravoPane.center.dy));
    await tester.pumpAndSettle();

    final root = reported! as DockSplit;
    expect(root.children.map((c) => (c as DockGroup).modules.single), ['a', 'c', 'b']);
    expect(root.weights[0], 1, reason: 'the untouched sibling keeps its share');
    expect(root.weights[1] / (root.weights[1] + root.weights[2]), moreOrLessEquals(1 / 3, epsilon: 0.001));
  });

  testWidgets("dropping a tab on another group's TAB joins that group, beside it", (tester) async {
    DockNode? reported;
    await tester.pumpWidget(harness(spec: twoGroups(), onChanged: (s) => reported = s));
    final alphaTab = tester.getRect(find.text('Alpha'));
    // Joining a group happens where its tabs are, not in the middle of its
    // body — and which SIDE of the tab decides where in the group it lands.
    await dragTab(tester, 'Bravo', Offset(alphaTab.right - 2, alphaTab.center.dy));
    final root = reported! as DockSplit;
    expect((root.children[0] as DockGroup).modules, ['a', 'b']);
    expect((root.children[0] as DockGroup).selected, 1, reason: 'the dropped module becomes the selected tab');
    expect((root.children[1] as DockGroup).modules, ['c']);
  });

  testWidgets('dropping on the leading half of a tab lands before it', (tester) async {
    DockNode? reported;
    await tester.pumpWidget(harness(spec: twoGroups(), onChanged: (s) => reported = s));
    final alphaTab = tester.getRect(find.text('Alpha'));
    await dragTab(tester, 'Bravo', Offset(alphaTab.left + 2, alphaTab.center.dy));
    expect(((reported! as DockSplit).children[0] as DockGroup).modules, ['b', 'a']);
  });

  testWidgets("a tab dropped within its own group reorders it", (tester) async {
    DockNode? reported;
    await tester.pumpWidget(harness(spec: DockGroup(['a', 'b', 'c']), onChanged: (s) => reported = s));
    final alphaTab = tester.getRect(find.text('Alpha'));
    // Reordering and joining are the same act seen from two sides, so this
    // goes through the same drop — but the index the operator aimed at
    // counts the module being moved, which is about to leave the list.
    await dragTab(tester, 'Charlie', Offset(alphaTab.left + 2, alphaTab.center.dy));
    expect((reported! as DockGroup).modules, ['c', 'a', 'b']);
    expect((reported as DockGroup).selected, 0, reason: 'a reordered tab stays the one being looked at');
  });

  testWidgets('moving the last module out of a group collapses the empty group', (tester) async {
    DockNode? reported;
    await tester.pumpWidget(harness(spec: twoGroups(), onChanged: (s) => reported = s));
    final bravoTab = tester.getRect(find.text('Bravo'));
    await dragTab(tester, 'Alpha', Offset(bravoTab.left + 2, bravoTab.center.dy));
    // The left group emptied out; the single-child root split collapsed.
    final root = reported! as DockGroup;
    expect(root.modules, ['a', 'b', 'c']);
  });

  testWidgets('a drop in the middle of a body does nothing at all', (tester) async {
    DockNode? reported;
    await tester.pumpWidget(harness(spec: twoGroups(), onChanged: (s) => reported = s));
    final alphaPane = tester.getRect(find.byKey(const Key('pane-a')));
    await dragTab(tester, 'Bravo', alphaPane.center);
    // The middle square belongs to no band: the old center-joins-as-a-tab
    // target moved to the tab strip, and a drop here must be a no-op rather
    // than the nearest guess.
    expect(reported, isNull);
  });

  group('split bands', () {
    const size = Size(300, 300);

    test('a band is a third, and runs the full length of the body', () {
      expect(dockSplitRegionAt(const Offset(150, 10), size), DockRegion.top);
      expect(dockSplitRegionAt(const Offset(150, 290), size), DockRegion.bottom);
      expect(dockSplitRegionAt(const Offset(10, 150), size), DockRegion.left);
      expect(dockSplitRegionAt(const Offset(290, 150), size), DockRegion.right);
      // The middle square is nobody's.
      expect(dockSplitRegionAt(const Offset(150, 150), size), isNull);
    });

    test('entering a corner picks the horizontal band', () {
      // Full-length bands overlap at the corners by design; arriving at one
      // with nothing highlighted has to resolve to a single answer.
      expect(dockSplitRegionAt(const Offset(10, 10), size), DockRegion.top);
      expect(dockSplitRegionAt(const Offset(290, 290), size), DockRegion.bottom);
    });

    test('a highlighted band keeps the pointer as it slides into an overlap', () {
      // Otherwise the highlight flickers between two answers while the
      // operator is still moving.
      expect(dockSplitRegionAt(const Offset(10, 10), size, active: DockRegion.left), DockRegion.left);
      expect(dockSplitRegionAt(const Offset(290, 10), size, active: DockRegion.right), DockRegion.right);
      // A band that isn't one of the two candidates doesn't get to stay.
      expect(dockSplitRegionAt(const Offset(10, 10), size, active: DockRegion.bottom), DockRegion.top);
    });
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
