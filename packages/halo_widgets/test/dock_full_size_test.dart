// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  DockNode twoGroups() => DockSplit(
    Axis.horizontal,
    [
      DockGroup(['a']),
      DockGroup(['b', 'c']),
    ],
    [1, 1],
  );

  Widget harness({Map<String, Widget>? children, Set<String> unexpandableModules = const {}, bool editing = false, Map<String, WidgetBuilder>? tabActions}) =>
      MaterialApp(
        home: Scaffold(
          body: DockLayoutView(
            initialSpec: twoGroups(),
            titles: const {'a': 'Alpha', 'b': 'Bravo', 'c': 'Charlie'},
            children: children ?? {'a': const _Counter(label: 'count-a'), 'b': const _Counter(label: 'count-b'), 'c': const _Counter(label: 'count-c')},
            tabActions: tabActions,
            unexpandableModules: unexpandableModules,
            editing: editing,
            fullSizeCloseLabel: 'Close',
          ),
        ),
      );

  void wide(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> doubleTap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  DockLayoutViewState dock(WidgetTester tester) => tester.state<DockLayoutViewState>(find.byType(DockLayoutView));

  testWidgets('a double tap on a pane title shows that pane full size, with its state, and the X puts it back with its state', (tester) async {
    // The pane MOVES rather than being copied: a copy would arrive with a
    // count of 0 — a map back at its default zoom, a field emptied — and
    // coming back would reset it again.
    wide(tester);
    await tester.pumpWidget(harness());
    await tester.tap(find.text('count-a: 0'));
    await tester.pump();

    await doubleTap(tester, find.text('Alpha'));
    expect(dock(tester).fullSizeModule, 'a');
    expect(find.text('count-a: 1'), findsOneWidget);
    // The card is most of the window, not a dialog's 650pt.
    final card = tester.getRect(find.ancestor(of: find.text('count-a: 1'), matching: find.byType(Material)).first);
    expect(card.width, greaterThan(1000));

    await tester.tap(find.text('count-a: 1'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(dock(tester).fullSizeModule, isNull);
    expect(find.text('count-a: 2'), findsOneWidget);
  });

  testWidgets('a single tap on a tab selects it at once: the double tap does not hold the gesture arena', (tester) async {
    // With GestureDetector.onDoubleTap on the tab, the tap would wait out
    // kDoubleTapTimeout before selecting, and this pump would still show Bravo.
    wide(tester);
    await tester.pumpWidget(harness());
    expect(find.text('count-c: 0').hitTestable(), findsNothing);
    await tester.tap(find.text('Charlie'));
    await tester.pump();
    expect(find.text('count-c: 0').hitTestable(), findsOneWidget);
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('a double tap on a tab shows THAT tab full size, not the one that was showing', (tester) async {
    wide(tester);
    await tester.pumpWidget(harness());
    await doubleTap(tester, find.text('Charlie'));
    expect(dock(tester).fullSizeModule, 'c');
  });

  testWidgets('a tab double-tapped through the accessibility tree goes full size too', (tester) async {
    // With the web's accessibility DOM on, a click on a tab reaches the app
    // as a semantics tap and no pointer events at all — so a double tap
    // watched only from pointers never fires there, in every dev web build.
    wide(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(harness());
    tester.semantics.tap(find.semantics.byLabel(RegExp('Charlie')));
    await tester.pump(const Duration(milliseconds: 50));
    tester.semantics.tap(find.semantics.byLabel(RegExp('Charlie')));
    await tester.pumpAndSettle();
    expect(dock(tester).fullSizeModule, 'c');
    semantics.dispose();
  });

  testWidgets('a layout edit that begins while a pane is full size puts it back with its state', (tester) async {
    // The card closing on its own must hand the pane back in the same build.
    // A card torn down first disposes the pane, and the slot then builds a
    // fresh one: the count back at 0, a half-typed call gone.
    wide(tester);
    var editing = false;
    late StateSetter setHost;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHost = setState;
              return DockLayoutView(
                initialSpec: twoGroups(),
                titles: const {'a': 'Alpha', 'b': 'Bravo', 'c': 'Charlie'},
                children: const {
                  'a': _Counter(label: 'count-a'),
                  'b': SizedBox(),
                  'c': SizedBox(),
                },
                editing: editing,
              );
            },
          ),
        ),
      ),
    );
    await doubleTap(tester, find.text('Alpha'));
    await tester.tap(find.text('count-a: 0'));
    await tester.pump();
    setHost(() => editing = true);
    await tester.pumpAndSettle();
    expect(dock(tester).fullSizeModule, isNull);
    expect(find.text('count-a: 1'), findsOneWidget);
  });

  testWidgets('a double click on a title\'s action runs the action, and does not enlarge the pane', (tester) async {
    wide(tester);
    var pressed = 0;
    await tester.pumpWidget(
      harness(
        tabActions: {'a': (_) => IconButton(key: const Key('tune-a'), icon: const Icon(Icons.tune), onPressed: () => pressed++)},
      ),
    );
    await doubleTap(tester, find.byKey(const Key('tune-a')));
    expect(pressed, 2);
    expect(dock(tester).fullSizeModule, isNull);
  });

  testWidgets('revealing another pane puts the full-size one back first', (tester) async {
    // A reveal surfaces a pane to put something in it — a spot's call into
    // the logging pane. Under the card, that lands where nobody can see it.
    wide(tester);
    await tester.pumpWidget(harness());
    await doubleTap(tester, find.text('Alpha'));
    dock(tester).revealModule('c');
    await tester.pumpAndSettle();
    expect(dock(tester).fullSizeModule, isNull);
    expect(find.text('count-c: 0').hitTestable(), findsOneWidget);
  });

  testWidgets('closing the card leaves the keyboard where the operator moved it inside the pane', (tester) async {
    // Focus goes back to what had it before the card opened only when it is
    // on the card itself. Moved to another field of the pane, it stays: the
    // next keystrokes belong in the field the operator chose.
    wide(tester);
    final first = FocusNode(), second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(
      harness(
        children: {
          'a': Column(
            children: [
              TextField(focusNode: first),
              TextField(focusNode: second),
            ],
          ),
          'b': const SizedBox(),
          'c': const SizedBox(),
        },
      ),
    );
    first.requestFocus();
    await tester.pump();
    await doubleTap(tester, find.text('Alpha'));
    expect(first.hasFocus, isTrue, reason: 'focus already in the pane that moved stays there');
    second.requestFocus();
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(second.hasFocus, isTrue);
  });

  testWidgets('the card covers the dock, not the view around it', (tester) async {
    wide(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Header')),
          body: DockLayoutView(
            initialSpec: twoGroups(),
            titles: const {'a': 'Alpha', 'b': 'Bravo', 'c': 'Charlie'},
            children: const {
              'a': SizedBox.expand(key: Key('pane-a')),
              'b': SizedBox(),
              'c': SizedBox(),
            },
          ),
        ),
      ),
    );
    final dockRect = tester.getRect(find.byType(DockLayoutView));
    await doubleTap(tester, find.text('Alpha'));
    final pane = tester.getRect(find.byKey(const Key('pane-a')));
    expect(dockRect.contains(pane.topLeft) && dockRect.contains(pane.bottomRight - const Offset(1, 1)), isTrue);
    expect(pane.width, greaterThan(dockRect.width * 0.85), reason: 'most of the dock: a dialog\'s margins, no width cap');
    // The header is still the view's, under no barrier.
    expect(find.text('Header').hitTestable(), findsOneWidget);
  });

  testWidgets('Escape closes the card even when a field behind the barrier had the keyboard', (tester) async {
    // `autofocus` defers to whatever already holds focus around it, so the
    // card would leave the keyboard in the dock's field behind the barrier:
    // Escape, and every keystroke, going to a pane nobody can see.
    wide(tester);
    await tester.pumpWidget(
      harness(
        children: {
          'a': const SizedBox(),
          'b': const TextField(key: Key('field-b')),
          'c': const SizedBox(),
        },
      ),
    );
    await tester.tap(find.byKey(const Key('field-b')));
    await tester.pump();
    await doubleTap(tester, find.text('Alpha'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dock(tester).fullSizeModule, isNull);
  });

  testWidgets('Escape inside the pane goes to the pane first, and closes the card only once nothing there takes it', (tester) async {
    // The logger's ladder: a menu, then an open control, each takes one
    // Escape; the card closes on the one that finds nothing left to do.
    wide(tester);
    var layers = 1;
    final pane = Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape || layers == 0) return KeyEventResult.ignored;
        layers--;
        return KeyEventResult.handled;
      },
      child: const SizedBox.expand(),
    );
    await tester.pumpWidget(harness(children: {'a': pane, 'b': const SizedBox(), 'c': const SizedBox()}));
    await doubleTap(tester, find.text('Alpha'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(dock(tester).fullSizeModule, 'a', reason: 'the pane took the first Escape');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dock(tester).fullSizeModule, isNull);
  });

  testWidgets('an Escape that stopped a transmission does only that', (tester) async {
    wide(tester);
    var claimed = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DockLayoutView(
            initialSpec: twoGroups(),
            titles: const {'a': 'Alpha', 'b': 'Bravo', 'c': 'Charlie'},
            children: const {'a': SizedBox(), 'b': SizedBox(), 'c': SizedBox()},
            fullSizeEscapeClaimed: () => claimed,
          ),
        ),
      ),
    );
    await doubleTap(tester, find.text('Alpha'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(dock(tester).fullSizeModule, 'a');
    claimed = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dock(tester).fullSizeModule, isNull);
  });

  testWidgets('a dock that goes away with a pane full size says so', (tester) async {
    // The app's hosts swap docks at the two-pane boundary. Unheard, the old
    // dock's card leaves the host's header dimmed and dead for good.
    wide(tester);
    final changes = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DockLayoutView(
            initialSpec: twoGroups(),
            titles: const {'a': 'Alpha', 'b': 'Bravo', 'c': 'Charlie'},
            children: const {'a': SizedBox(), 'b': SizedBox(), 'c': SizedBox()},
            onFullSizeChanged: changes.add,
          ),
        ),
      ),
    );
    await doubleTap(tester, find.text('Alpha'));
    expect(changes, ['a']);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(changes, ['a', null]);
  });

  testWidgets('a dock that is put away (TickerMode off) puts its full-size pane back', (tester) async {
    // A Home destination the operator has left: its card, out of sight, would
    // go on taking the back press and keeping the host's header quiet.
    wide(tester);
    var showing = true;
    late StateSetter setHost;
    final changes = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHost = setState;
              return TickerMode(
                enabled: showing,
                child: DockLayoutView(
                  initialSpec: twoGroups(),
                  titles: const {'a': 'Alpha', 'b': 'Bravo', 'c': 'Charlie'},
                  children: const {'a': SizedBox(), 'b': SizedBox(), 'c': SizedBox()},
                  onFullSizeChanged: changes.add,
                ),
              );
            },
          ),
        ),
      ),
    );
    await doubleTap(tester, find.text('Alpha'));
    setHost(() => showing = false);
    await tester.pump();
    await tester.pump();
    expect(dock(tester).fullSizeModule, isNull);
    expect(changes, ['a', null]);
  });

  testWidgets('two taps further apart than the double-tap timeout are two taps', (tester) async {
    wide(tester);
    await tester.pumpWidget(harness());
    await tester.tap(find.text('Alpha'));
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(dock(tester).fullSizeModule, isNull);
  });

  testWidgets('a tap outside the card, Escape, and a double tap on its title bar each put the pane back', (tester) async {
    wide(tester);
    await tester.pumpWidget(harness());

    await doubleTap(tester, find.text('Alpha'));
    await tester.tapAt(const Offset(5, 400));
    await tester.pumpAndSettle();
    expect(dock(tester).fullSizeModule, isNull, reason: 'tap outside');

    await doubleTap(tester, find.text('Alpha'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dock(tester).fullSizeModule, isNull, reason: 'Escape');

    await doubleTap(tester, find.text('Alpha'));
    // The title bar's own Alpha, over the barrier; the dock's is under it.
    await doubleTap(tester, find.text('Alpha').hitTestable());
    expect(dock(tester).fullSizeModule, isNull, reason: 'double tap on the title bar');
    expect(find.text('count-a: 0').hitTestable(), findsOneWidget);
  });

  testWidgets('the full-size title bar carries the pane\'s own action', (tester) async {
    wide(tester);
    await tester.pumpWidget(harness(tabActions: {'a': (_) => const Icon(Icons.tune, key: Key('tune-a'))}));
    await doubleTap(tester, find.text('Alpha'));
    expect(find.byKey(const Key('tune-a')).hitTestable(), findsOneWidget);
  });

  testWidgets('a panel that declines, and any pane while editing, do not go full size', (tester) async {
    wide(tester);
    await tester.pumpWidget(harness(unexpandableModules: {'a'}));
    await doubleTap(tester, find.text('Alpha'));
    expect(dock(tester).fullSizeModule, isNull);

    await tester.pumpWidget(harness(editing: true));
    await doubleTap(tester, find.text('Bravo'));
    expect(dock(tester).fullSizeModule, isNull);
  });

  testWidgets('the full-size pane gets the host\'s latest widget', (tester) async {
    // In the same frame, not one later: the card is built in the dock's own
    // build. A card that only caught up after the frame would show the last
    // QSO count, the last spot list, beside a slot that already had the new
    // ones. The host rebuilds BELOW the app, as a view does: re-pumping the
    // whole app rebuilds everything and would hide a card that is not fed.
    wide(tester);
    var label = 'first';
    late StateSetter setHost;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHost = setState;
              return DockLayoutView(
                initialSpec: twoGroups(),
                titles: const {'a': 'Alpha', 'b': 'Bravo', 'c': 'Charlie'},
                children: {'a': Text(label), 'b': const SizedBox(), 'c': const SizedBox()},
              );
            },
          ),
        ),
      ),
    );
    await doubleTap(tester, find.text('Alpha'));
    setHost(() => label = 'second');
    await tester.pump();
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });

  testWidgets('on a phone-sized window the pane is full screen, and its X still puts it back', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DockLayoutView(
            initialSpec: DockGroup(['a']),
            titles: const {'a': 'Alpha'},
            children: const {'a': SizedBox.expand(key: Key('pane-a'))},
          ),
        ),
      ),
    );
    await doubleTap(tester, find.text('Alpha'));
    final pane = tester.getRect(find.byKey(const Key('pane-a')));
    expect(pane.width, 400);
    expect(pane.bottom, 800);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pane-a')), findsOneWidget);
    expect(dock(tester).fullSizeModule, isNull);
    expect(tester.getRect(find.byKey(const Key('pane-a'))).top, greaterThan(0), reason: 'back under its own title');
  });
}

class _Counter extends StatefulWidget {
  final String label;

  const _Counter({required this.label});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => setState(() => _count++), child: Text('${widget.label}: $_count'));
}
