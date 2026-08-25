// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Modal Pane contract (docs/design/layouts.md): one route, two
// presentations. It must re-present in place when the window crosses the
// S/L boundary while open (not pop-and-reshow), and `Navigator.pop(result)`
// must resolve the caller's `await` identically from either presentation.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// The card the dialog presentation draws — the Material holding the header.
  Finder card() =>
      find.ancestor(of: find.byType(HaloDialogHeader), matching: find.byType(Material)).first;

  double maxPaneHeightOf(WidgetTester tester) =>
      haloDialogConstraints(tester.element(find.byType(HaloDialogHeader))).maxHeight;

  Map<String, dynamic> formOf(int fields) => {
        'title': 'Edit',
        'elements': [
          for (var i = 0; i < fields; i++)
            {'type': 'field', 'key': 'f$i', 'fieldType': 'text', 'label': 'Field $i'},
        ],
      };

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
    expect(find.byIcon(MdiIcons.close), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);

    // Now the same open route at phone width: full-screen with an AppBar
    // back button, no close icon.
    setWidth(tester, 400);
    await tester.pumpAndSettle();
    expect(find.text('pane body'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byIcon(MdiIcons.close), findsNothing);

    // And back again.
    setWidth(tester, 900);
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(find.byIcon(MdiIcons.close), findsOneWidget);
  });

  testWidgets('a pane can decline the header close button, and keeps the back button on a phone', (tester) async {
    setWidth(tester, 900);
    addTearDown(tester.view.reset);
    final context = await pumpHost(tester);

    // For a pane whose own footer carries Done. The X going away is the point;
    // what must NOT go away with it is the phone presentation's back button,
    // which is the platform's dismissal rather than this flag's.
    showModalPane<void>(
      context,
      title: 'Exports',
      closeButton: false,
      builder: (context) => const Text('pane body'),
    );
    await tester.pumpAndSettle();
    expect(find.text('pane body'), findsOneWidget);
    expect(find.byIcon(MdiIcons.close), findsNothing);

    setWidth(tester, 400);
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
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
    // Bounded is not enough — the mode exists so a body with Expanded
    // sections gets the pane's FULL height to divide. Nothing else stops a
    // filling body from silently shrink-wrapping now that the card may.
    expect(tester.getSize(card()).height, maxPaneHeightOf(tester));

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

  testWidgets('Escape still dismisses even with barrierDismissible: false', (tester) async {
    // barrierDismissible: false exists to stop a STRAY TAP outside from
    // discarding in-progress edits — it must not also take Escape with it.
    // Flutter's own DismissIntent action reads ModalRoute.barrierDismissible
    // as the single flag for both, so ModalPaneRoute has to decouple them:
    // that getter always returns true now, and the tap-outside handler is
    // gated by its own separate field instead.
    setWidth(tester, 900);
    addTearDown(tester.view.reset);
    final context = await pumpHost(tester);

    showModalPane<void>(context, barrierDismissible: false, builder: (context) => const Text('pane body'));
    await tester.pumpAndSettle();
    expect(find.text('pane body'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('pane body'), findsNothing);
  });

  group('showTopModalPane', () {
    // Same barrierDismissible/Escape split as ModalPaneRoute above —
    // TopModalPaneRoute is a separate class with no shared base, so the fix
    // had to be applied here independently rather than inherited.
    testWidgets('barrier tap dismisses unless disabled', (tester) async {
      final context = await pumpHost(tester);

      unawaited(showTopModalPane<void>(context, builder: (context) => const Text('top pane body')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 400));
      await tester.pumpAndSettle();
      expect(find.text('top pane body'), findsNothing);

      unawaited(showTopModalPane<void>(
        context,
        barrierDismissible: false,
        builder: (context) => const Text('top pane body'),
      ));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 400));
      await tester.pumpAndSettle();
      expect(find.text('top pane body'), findsOneWidget);
    });

    testWidgets('Escape still dismisses even with barrierDismissible: false', (tester) async {
      final context = await pumpHost(tester);

      unawaited(showTopModalPane<void>(
        context,
        barrierDismissible: false,
        builder: (context) => const Text('top pane body'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('top pane body'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('top pane body'), findsNothing);
    });

    testWidgets('an inset measured off the left of the window still opens the pane', (tester) async {
      setWidth(tester, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      final context = await pumpHost(tester);

      // Callers pass the measured position of the control the sheet aligns to.
      // Measured while that control's own route is still animating in, it
      // reads off the left of the window — and modal_pane then subtracts a
      // further nudge from it. Unfloored, that reaches Padding as a negative
      // inset and the pane never mounts.
      unawaited(showTopModalPane<void>(
        context,
        leftInset: -400,
        builder: (context) => const Text('top pane body'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('top pane body'), findsOneWidget, reason: 'a nonsense inset must not take the pane down with it');
      expect(tester.takeException(), isNull);
    });
  });

  group('showFormPane', () {
    testWidgets('close button cannot dismiss the pane while a submit is in flight', (tester) async {
      // The old showFormDialog guaranteed a form could never be dismissed
      // mid-save (barrierDismissible: false + disabled Cancel). The pane's
      // title-bar X goes through Navigator.maybePop, so the PopScope
      // showFormPane installs while submitting must block it — otherwise a
      // tap on X while an async validator runs pops null and edits the
      // user explicitly saved are silently discarded.
      setWidth(tester, 900);
      addTearDown(tester.view.reset);
      final context = await pumpHost(tester);

      final validatorGate = Completer<String?>();
      final result = showFormPane(
        context,
        formDefinition: {
          'title': 'Edit QSO',
          'elements': [
            {'type': 'field', 'key': 'theirName', 'fieldType': 'text', 'label': 'Name'},
          ],
        },
        initialState: {'theirName': 'Hiram'},
        validator: (key, value, state) => validatorGate.future,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();

      // Submit is now awaiting the validator: X must not dismiss. Fixed
      // pumps, not pumpAndSettle — the submitting spinner animates forever.
      await tester.tap(find.byIcon(MdiIcons.close));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Edit QSO'), findsOneWidget);

      // Validator resolves clean → the submit completes with the values.
      validatorGate.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Edit QSO'), findsNothing);
      expect((await result)?['theirName'], 'Hiram');
    });

    testWidgets('Escape closes the pane, same as the close button', (tester) async {
      setWidth(tester, 900);
      addTearDown(tester.view.reset);
      final context = await pumpHost(tester);

      final result = showFormPane(
        context,
        formDefinition: {
          'title': 'Edit QSO',
          'elements': [
            {'type': 'field', 'key': 'theirName', 'fieldType': 'text', 'label': 'Name'},
          ],
        },
        initialState: {'theirName': 'Hiram'},
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Edit QSO'), findsNothing);
      expect(await result, isNull, reason: 'Escape cancels, same as the close button — it does not save');
    });

    testWidgets('Escape cannot dismiss the pane while a submit is in flight', (tester) async {
      // Same guarantee as the close button above, for the same reason —
      // Escape goes through the identical Navigator.maybePop path.
      setWidth(tester, 900);
      addTearDown(tester.view.reset);
      final context = await pumpHost(tester);

      final validatorGate = Completer<String?>();
      final result = showFormPane(
        context,
        formDefinition: {
          'title': 'Edit QSO',
          'elements': [
            {'type': 'field', 'key': 'theirName', 'fieldType': 'text', 'label': 'Name'},
          ],
        },
        initialState: {'theirName': 'Hiram'},
        validator: (key, value, state) => validatorGate.future,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Edit QSO'), findsOneWidget);

      validatorGate.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Edit QSO'), findsNothing);
      expect((await result)?['theirName'], 'Hiram');
    });

    testWidgets("the 'uppercase' flag works on every text-like field type, not just 'text'", (tester) async {
      // The SDK doc promises the flag works on the text-like types; the
      // icon-row compact path always honored it, so the standard form path
      // must too or the same definition would case data differently by
      // layout.
      setWidth(tester, 900);
      addTearDown(tester.view.reset);
      final context = await pumpHost(tester);

      showFormPane(
        context,
        formDefinition: {
          'title': 'Casing',
          'elements': [
            {'type': 'field', 'key': 'exchange', 'fieldType': 'multiline', 'label': 'Exchange', 'uppercase': true},
            {'type': 'field', 'key': 'notes', 'fieldType': 'multiline', 'label': 'Notes'},
          ],
        },
        initialState: const {},
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Exchange'), 'br from fl');
      await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'mixed Case stays');
      await tester.pump();

      TextField field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label));
      expect(field('Exchange').controller!.text, 'BR FROM FL');
      expect(field('Notes').controller!.text, 'mixed Case stays');
    });
  });

  testWidgets('a short form pane fits its content, and still pins Save to the bottom full screen',
      (tester) async {
    // Two halves of one contract, together because they pull against each
    // other: a four-field form must not reserve a full-height card (it left
    // ~300px of dead space between the fields and the footer), while the
    // full-screen presentation must still fill the screen — layouts.md
    // promises actions pinned at the bottom there, and a body free to
    // shrink-wrap would float them up under the last field.
    setWidth(tester, 900);
    addTearDown(tester.view.reset);
    final context = await pumpHost(tester);

    showFormPane(context, formDefinition: formOf(4), initialState: const {});
    await tester.pumpAndSettle();

    expect(tester.getSize(card()).height, lessThan(maxPaneHeightOf(tester) * 0.75));
    // ...and the footer sits just under the fields, not a card away.
    expect(tester.getRect(find.widgetWithText(FilledButton, 'Save')).bottom,
        closeTo(tester.getRect(card()).bottom, 24));

    // The same open route at phone width: the pane IS the screen, so Save
    // belongs on the bottom edge however short the form is.
    setWidth(tester, 400);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.widgetWithText(FilledButton, 'Save')).bottom, closeTo(800, 24));
  });

  testWidgets('a form taller than the pane stops at the max and keeps Save pinned', (tester) async {
    // The other direction: shrink-wrapping must not cost the form its pinned
    // footer — the reason showFormPane builds its own action row instead of
    // FormRenderer's, which would scroll out of reach.
    setWidth(tester, 900);
    addTearDown(tester.view.reset);
    final context = await pumpHost(tester);

    showFormPane(context, formDefinition: formOf(20), initialState: const {});
    await tester.pumpAndSettle();

    expect(tester.getSize(card()).height, maxPaneHeightOf(tester));
    expect(tester.getRect(find.widgetWithText(FilledButton, 'Save')).bottom,
        lessThanOrEqualTo(tester.getRect(card()).bottom));
    // The fields scroll under it — the last one is off the bottom of the card.
    expect(tester.getRect(find.text('Field 19')).top, greaterThan(tester.getRect(card()).bottom));
  });
}
