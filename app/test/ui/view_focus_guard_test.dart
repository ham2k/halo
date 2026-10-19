// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:ui' show ViewFocusDirection, ViewFocusEvent, ViewFocusState;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/view_focus_guard.dart';

/// Delivers a view-focus event the way the platform does.
///
/// Through the platform dispatcher's own callback rather than straight to the
/// guard: the parking, and the framework's answer to a `focused` event, are
/// both done by Flutter's `_ViewState`, which only hears about the event if
/// the real dispatch runs. Hand the guard the event directly and these tests
/// pass with it gutted.
void _dispatch(WidgetTester tester, ViewFocusState state, {ViewFocusDirection direction = ViewFocusDirection.undefined}) {
  final dispatch = tester.binding.platformDispatcher.onViewFocusChange;
  expect(dispatch, isNotNull, reason: 'ServicesBinding installs this; without it nothing parks the focus');
  dispatch!(ViewFocusEvent(viewId: tester.view.viewId, state: state, direction: direction));
}

/// What the browser sends when the accessibility DOM blurs the focused input:
/// the whole view reports unfocused, and Flutter parks focus on the root
/// scope, where nothing can receive a keystroke.
void _reportViewUnfocused(WidgetTester tester) => _dispatch(tester, ViewFocusState.unfocused);

/// The echo the engine produces from the guard asking for the view's focus
/// back. `requestViewFocusChange` discards the direction it is given and just
/// DOM-focuses the view root; the resulting `focusin` comes back as a fresh
/// `focused` event carrying `forward`. The test binding does not echo it on
/// its own, so a test that omits this cannot see what the echo costs.
void _reportViewRefocusedByEngine(WidgetTester tester) => _dispatch(tester, ViewFocusState.focused, direction: ViewFocusDirection.forward);

void main() {
  /// Two focusable widgets, with the SECOND one focused — the arrangement the
  /// whole problem hides in. With only one node, focus landing on "the first
  /// focusable" and focus landing on "the node the operator was in" are the
  /// same answer, and the bug is invisible.
  Future<(FocusNode first, FocusNode second)> pumpTwoFields(WidgetTester tester) async {
    final first = FocusNode(debugLabel: 'first');
    final second = FocusNode(debugLabel: 'second');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Focus(focusNode: first, child: const SizedBox(width: 10, height: 10)),
            Focus(focusNode: second, child: const SizedBox(width: 10, height: 10)),
          ],
        ),
      ),
    );
    second.requestFocus();
    await tester.pump();
    expect(second.hasFocus, isTrue, reason: 'the later field has to start focused for the test to mean anything');
    return (first, second);
  }

  /// [pumpTwoFields] plus a third node the app moves focus to — the field a
  /// command opens and focuses.
  Future<(FocusNode first, FocusNode second, FocusNode opened)> pumpWithOpenedField(WidgetTester tester) async {
    final (first, second) = await pumpTwoFields(tester);
    final opened = FocusNode(debugLabel: 'opened');
    addTearDown(opened.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Focus(focusNode: first, child: const SizedBox(width: 10, height: 10)),
            Focus(focusNode: second, child: const SizedBox(width: 10, height: 10)),
            Focus(focusNode: opened, child: const SizedBox(width: 10, height: 10)),
          ],
        ),
      ),
    );
    expect(second.hasFocus, isTrue);
    return (first, second, opened);
  }

  testWidgets('a spurious view-unfocus does not take the field down with it', (tester) async {
    // The page keeps its own focus — which is what marks the report as the
    // accessibility DOM's doing rather than the operator's.
    final guard = ViewFocusGuard.installWith(() => true);
    addTearDown(guard.uninstall);
    final (_, second) = await pumpTwoFields(tester);

    _reportViewUnfocused(tester);
    await tester.pump(); // the parking lands
    await tester.pump(); // the guard's post-frame restore

    expect(second.hasFocus, isTrue);
    // The framework node is only half of it, and the cheaper half. Without a
    // request for the VIEW's focus the browser's active element stays on
    // `<body>`: the caret comes back, reports itself focused, and swallows
    // every keystroke. Deleting that request passes every other assertion in
    // this file, which is why this one is here.
    expect(
      tester.binding.platformDispatcher.testFocusEvents.map((e) => e.state),
      contains(ViewFocusState.focused),
      reason: 'the guard has to ask for the view back, not just move the focus node',
    );
  });

  testWidgets('the view coming back does not drag focus to the first field', (tester) async {
    // The regression this file exists for. Asking for the view's focus back
    // makes the engine DOM-focus the view root, and Flutter answers the echoed
    // event with `findFirstFocus(scope, ignoreCurrentFocus: true)` — the FIRST
    // focusable widget, not the one the operator was in. Unhandled, churn
    // while someone types a note moves the caret into the callsign field.
    final guard = ViewFocusGuard.installWith(() => true);
    addTearDown(guard.uninstall);
    final (first, second) = await pumpTwoFields(tester);

    _reportViewUnfocused(tester);
    await tester.pump();
    await tester.pump();

    _reportViewRefocusedByEngine(tester);
    await tester.pump();
    await tester.pump();

    expect(second.hasFocus, isTrue, reason: 'focus belongs where the operator left it');
    expect(first.hasFocus, isFalse, reason: 'findFirstFocus must not get the last word');
  });

  testWidgets('a field the app focuses in the frame of the report keeps its focus', (tester) async {
    // The guard undoes the report and nothing else. Moving focus to a field
    // built that same frame (FIND opening the log's Find bar) can blur the
    // browser's input itself, so the report, its echo and the app's request
    // all land in one frame. Restoring over the request hands the caret back
    // to the field the app moved away from.
    final guard = ViewFocusGuard.installWith(() => true);
    addTearDown(guard.uninstall);
    final (first, second, opened) = await pumpWithOpenedField(tester);

    WidgetsBinding.instance.addPostFrameCallback((_) => opened.requestFocus());
    _reportViewUnfocused(tester);
    _reportViewRefocusedByEngine(tester);
    await tester.pump();
    await tester.pump();

    expect(opened.hasFocus, isTrue);
    expect(second.hasFocus, isFalse);
    expect(first.hasFocus, isFalse);
  });

  testWidgets('focus left on a scope after the report is still put back on the field', (tester) async {
    // A field letting go hands focus to its enclosing scope — on web, an
    // input closing its connection does exactly that. A scope takes no
    // keystrokes, so read as the app's choice it would leave the operator
    // in a dead field the guard exists to bring back.
    final guard = ViewFocusGuard.installWith(() => true);
    addTearDown(guard.uninstall);
    final scope = FocusScopeNode(debugLabel: 'panel');
    final first = FocusNode(debugLabel: 'first');
    final second = FocusNode(debugLabel: 'second');
    addTearDown(scope.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: FocusScope(
          node: scope,
          child: Column(
            children: [
              Focus(focusNode: first, child: const SizedBox(width: 10, height: 10)),
              Focus(focusNode: second, child: const SizedBox(width: 10, height: 10)),
            ],
          ),
        ),
      ),
    );
    second.requestFocus();
    await tester.pump();

    // `scope.requestFocus()` would not do: a scope that remembers a child
    // focuses the child. Letting go is what leaves the scope itself holding it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      second.requestFocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
      second.unfocus();
    });
    _reportViewUnfocused(tester);
    await tester.pump();
    await tester.pump();

    expect(second.hasPrimaryFocus, isTrue);
  });

  testWidgets('a scope the field is not in, focused after the report, keeps its focus', (tester) async {
    // A dialog opening with nothing to autofocus leaves its own scope
    // holding focus. That is the app's choice, not the field letting go:
    // putting the field back would hand the keyboard to the page under it.
    final guard = ViewFocusGuard.installWith(() => true);
    addTearDown(guard.uninstall);
    final dialog = FocusScopeNode(debugLabel: 'dialog');
    final first = FocusNode(debugLabel: 'first');
    final second = FocusNode(debugLabel: 'second');
    addTearDown(dialog.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Focus(focusNode: first, child: const SizedBox(width: 10, height: 10)),
            Focus(focusNode: second, child: const SizedBox(width: 10, height: 10)),
            FocusScope(node: dialog, child: const SizedBox(width: 10, height: 10)),
          ],
        ),
      ),
    );
    second.requestFocus();
    await tester.pump();

    WidgetsBinding.instance.addPostFrameCallback((_) => dialog.requestFocus());
    _reportViewUnfocused(tester);
    await tester.pump();
    await tester.pump();

    expect(dialog.hasPrimaryFocus, isTrue);
    expect(second.hasFocus, isFalse);
  });

  testWidgets('a field the app focuses before the echo keeps its focus through it', (tester) async {
    // The echo a frame later: its re-assertion has to carry the app's choice,
    // or Flutter's answer to it (the first focusable) wins instead.
    final guard = ViewFocusGuard.installWith(() => true);
    addTearDown(guard.uninstall);
    final (first, second, opened) = await pumpWithOpenedField(tester);

    WidgetsBinding.instance.addPostFrameCallback((_) => opened.requestFocus());
    _reportViewUnfocused(tester);
    await tester.pump();
    await tester.pump();
    _reportViewRefocusedByEngine(tester);
    await tester.pump();
    await tester.pump();

    expect(opened.hasFocus, isTrue);
    expect(first.hasFocus, isFalse);
    expect(second.hasFocus, isFalse);
  });

  testWidgets('a real window switch still takes focus away', (tester) async {
    // The mirror of the cases above, and what keeps them honest: with the
    // page's own focus gone the operator really did leave, and restoring focus
    // here would be the guard overriding a genuine unfocus.
    final guard = ViewFocusGuard.installWith(() => false);
    addTearDown(guard.uninstall);
    final (_, second) = await pumpTwoFields(tester);

    _reportViewUnfocused(tester);
    await tester.pump();
    await tester.pump();

    expect(second.hasFocus, isFalse);
  });

  testWidgets('a view focus the operator caused is left alone', (tester) async {
    // Coming back to the tab with no spurious unfocus before it. Flutter's own
    // handling — move to the first focusable — is correct there, and the guard
    // has no business overriding it just because it remembers an older field.
    final guard = ViewFocusGuard.installWith(() => true);
    addTearDown(guard.uninstall);
    final (first, second) = await pumpTwoFields(tester);

    _reportViewRefocusedByEngine(tester);
    await tester.pump();
    await tester.pump();

    expect(second.hasFocus, isFalse, reason: 'the guard must not re-assert a field nothing asked it to');
    expect(first.hasFocus, isTrue);
  });
}
