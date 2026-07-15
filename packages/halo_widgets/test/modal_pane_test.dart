// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Modal Pane contract (docs/design/layouts.md): one route, two
// presentations. It must re-present in place when the window crosses the
// S/L boundary while open (not pop-and-reshow), and `Navigator.pop(result)`
// must resolve the caller's `await` identically from either presentation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          key: const Key('host-scaffold'),
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const Text('underneath');
            },
          ),
        ),
      ),
    );
    return hostContext;
  }

  void setWidth(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets('presents as a dialog on L, full screen on S', (tester) async {
    setWidth(tester, 900);
    addTearDown(tester.view.reset);
    final context = await pumpHost(tester);

    showModalPane<void>(context, title: 'Account', builder: (context) => const Text('pane body'));
    await tester.pumpAndSettle();

    // Dialog presentation: close button, no AppBar, content underneath
    // still in the tree (barrier over it).
    expect(find.text('pane body'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    // Now the same open route at phone width: full-screen with an AppBar
    // back button, no close icon.
    setWidth(tester, 400);
    await tester.pumpAndSettle();
    expect(find.text('pane body'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);

    // And back again.
    setWidth(tester, 900);
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('pops with a result from the dialog presentation', (tester) async {
    setWidth(tester, 900);
    addTearDown(tester.view.reset);
    final context = await pumpHost(tester);

    final result = showModalPane<String>(
      context,
      // Action rows are the pane's own content (see showModalPane's doc).
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('pane body'),
          TextButton(onPressed: () => Navigator.of(context).pop('saved'), child: const Text('Save')),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await result, 'saved');
    expect(find.text('pane body'), findsNothing);
  });

  testWidgets('back button pops with null from the full-screen presentation', (tester) async {
    setWidth(tester, 400);
    addTearDown(tester.view.reset);
    final context = await pumpHost(tester);

    final result = showModalPane<String>(context, builder: (context) => const Text('pane body'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(find.text('pane body'), findsNothing);
    expect(find.text('underneath'), findsOneWidget);
  });

  testWidgets('pane State (in-progress input) survives a mid-open presentation flip', (tester) async {
    // The two presentations have different widget trees; the route's body
    // GlobalKey must reparent the pane's Element so typed-but-unsaved input
    // is not destroyed by a resize across the S/L boundary.
    setWidth(tester, 900);
    addTearDown(tester.view.reset);
    final context = await pumpHost(tester);

    showModalPane<void>(context, title: 'Account', builder: (context) => const TextField());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'draft input');
    await tester.pump();

    setWidth(tester, 400);
    await tester.pumpAndSettle();
    expect(find.text('draft input'), findsOneWidget, reason: 'flip to full screen must keep the typed text');

    setWidth(tester, 900);
    await tester.pumpAndSettle();
    expect(find.text('draft input'), findsOneWidget, reason: 'flip back to dialog must keep the typed text');
  });

  testWidgets('SnackBars from pane content are shown by the route, not behind its barrier', (tester) async {
    // The dialog presentation has no Scaffold of its own content's making —
    // the route must scope a ScaffoldMessenger so validation feedback is
    // visible above the barrier instead of on the underlying route.
    setWidth(tester, 900);
    addTearDown(tester.view.reset);
    final context = await pumpHost(tester);

    showModalPane<void>(
      context,
      builder: (context) => TextButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('invalid reference'))),
        child: const Text('validate'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('validate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('invalid reference'), findsOneWidget);
    // It must be hosted by the route's own Scaffold (above the barrier),
    // not by the host Scaffold underneath the route.
    final snackBarScaffold = tester.element(find.byType(SnackBar)).findAncestorWidgetOfExactType<Scaffold>();
    final hostScaffold = tester.widget<Scaffold>(find.byKey(const Key('host-scaffold')));
    expect(
      identical(snackBarScaffold, hostScaffold),
      isFalse,
      reason: 'SnackBar must not render on the Scaffold beneath the barrier',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('a result survives a mid-open presentation flip', (tester) async {
    // Open as a dialog, resize to phone width, dismiss from the full-screen
    // presentation — the ORIGINAL awaited future completes.
    setWidth(tester, 900);
    addTearDown(tester.view.reset);
    final context = await pumpHost(tester);

    final result = showModalPane<String>(
      context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('pane body'),
          TextButton(onPressed: () => Navigator.of(context).pop('flipped'), child: const Text('Done')),
        ],
      ),
    );
    await tester.pumpAndSettle();

    setWidth(tester, 400);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(await result, 'flipped');
  });

  testWidgets('scrollable: false gives the body bounded height in both presentations', (tester) async {
    // A body built around Expanded sections (the Activities pane's
    // accordion) cannot live inside the default scroll view's unbounded
    // height — the non-scrollable mode must hand it the pane's full height.
    setWidth(tester, 900);
    addTearDown(tester.view.reset);
    final context = await pumpHost(tester);

    showModalPane<void>(
      context,
      title: 'Activities',
      scrollable: false,
      builder: (context) => Column(
        children: [
          const Text('header row'),
          Expanded(child: ListView(children: const [Text('filling section')])),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('filling section'), findsOneWidget);

    // Same body, full-screen presentation.
    setWidth(tester, 400);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('filling section'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('barrier tap dismisses the dialog presentation unless disabled', (tester) async {
    setWidth(tester, 900);
    addTearDown(tester.view.reset);
    final context = await pumpHost(tester);

    showModalPane<void>(context, builder: (context) => const Text('pane body'));
    await tester.pumpAndSettle();
    // Tap outside the ideal-width card (near the left edge).
    await tester.tapAt(const Offset(10, 400));
    await tester.pumpAndSettle();
    expect(find.text('pane body'), findsNothing);

    showModalPane<void>(context, barrierDismissible: false, builder: (context) => const Text('pane body'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 400));
    await tester.pumpAndSettle();
    expect(find.text('pane body'), findsOneWidget);
  });
}
