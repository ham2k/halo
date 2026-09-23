// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where focus falls when nothing else claims it: the callsign field as the
// default, the claims it never takes over, and mobile with no hardware
// keyboard.

import 'dart:async';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'support/logging_controls_harness.dart';

void main() {
  installLoggingHarness();

  group('HALO-182: the callsign field is the default focus', () {
    // Every case starts from focus falling to NOTHING — the thing a dialog
    // popping over an idle panel, a menu closing or a stray `unfocus()` leave
    // behind. The reclaim lands a frame later and the manager applies it on a
    // microtask, hence two pumps.
    Future<void> dropFocus(WidgetTester tester) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump();
    }

    bool callHasFocus(WidgetTester tester) => tester.widget<TextField>(find.widgetWithText(TextField, 'Their call')).focusNode!.hasFocus;

    testWidgets('focus that falls to nothing comes back to the callsign field', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(host());
        await tester.pump();
        // Autofocus fired once at mount and never again; without the
        // backstop, this leaves the operator typing into nothing.
        await dropFocus(tester);
        expect(callHasFocus(tester), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a field elsewhere keeps its claim', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final other = FocusNode(debugLabel: 'other');
      addTearDown(other.dispose);
      try {
        await tester.pumpWidget(host(trailing: TextField(focusNode: other)));
        await tester.pump();
        other.requestFocus();
        await tester.pump();
        await tester.pump();
        // Only NOTHING is reclaimed — a leaf node anywhere is somebody
        // typing, and stealing from it would be the bug in reverse.
        expect(other.hasFocus, isTrue);
        expect(callHasFocus(tester), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a button that kept the focus of a click is not a claim', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final button = FocusNode(debugLabel: 'button');
      addTearDown(button.dispose);
      try {
        // Web hands a clicked button its focus, and a dialog closing over it
        // hands the focus straight back to the button — so "any leaf is a
        // claim" leaves the operator typing into a button after every dialog.
        await tester.pumpWidget(
          host(
            trailing: TextButton(focusNode: button, onPressed: () {}, child: const Text('b')),
          ),
        );
        await tester.pump();
        button.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(callHasFocus(tester), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a key-handling surface and a dropdown elsewhere keep theirs', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final list = FocusNode(debugLabel: 'list');
      final dropdown = FocusNode(debugLabel: 'dropdown');
      addTearDown(list.dispose);
      addTearDown(dropdown.dispose);
      try {
        await tester.pumpWidget(
          host(
            trailing: Column(
              children: [
                // The QSO list's shape: a bare Focus steering rows with the keys.
                Focus(focusNode: list, onKeyEvent: (_, _) => KeyEventResult.ignored, child: const SizedBox(height: 10)),
                DropdownButton<String>(
                  focusNode: dropdown,
                  value: 'a',
                  items: const [DropdownMenuItem(value: 'a', child: Text('a'))],
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        list.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(list.hasFocus, isTrue, reason: 'arrow keys are steering the list');
        dropdown.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(dropdown.hasFocus, isTrue, reason: 'a dropdown is a field');
        expect(callHasFocus(tester), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('an overlay with its own scope, on the same route, is never robbed either', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final overlay = FocusScopeNode(debugLabel: 'overlay');
      addTearDown(overlay.dispose);
      try {
        // A menu or in-route overlay takes focus into a scope of its own
        // with no field inside — a scope, but not on the panel's ancestry.
        // The route guard can't tell this apart: the route is still current.
        await tester.pumpWidget(
          host(
            trailing: FocusScope(node: overlay, child: const SizedBox.shrink()),
          ),
        );
        await tester.pump();
        overlay.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(overlay.hasPrimaryFocus, isTrue);
        expect(callHasFocus(tester), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a dialog is never robbed, and its closing hands focus to the callsign', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(host());
        await tester.pump();
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        // The panel had nothing focused when the dialog opened — the case a
        // per-caller assertion never covers, because no caller is involved.
        FocusManager.instance.primaryFocus?.unfocus();
        unawaited(
          navigator.push(
            DialogRoute<void>(
              context: navigator.context,
              builder: (_) => const AlertDialog(content: Text('dialog')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Primary focus is the dialog's own scope: not the panel's ancestry,
        // so not "nothing". Reclaiming here would type behind the dialog.
        expect(find.text('dialog'), findsOneWidget);
        expect(callHasFocus(tester), isFalse);

        navigator.pop();
        await tester.pumpAndSettle();
        await tester.pump();
        expect(callHasFocus(tester), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('switching apps and back leaves focus where it was', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      // The manager decides at construction whether to follow the lifecycle
      // — on the test binding's Android default, it doesn't; this re-asks
      // with the platform above in place, the way the framework's own tests
      // do. Without it the whole scenario is a no-op and proves nothing.
      FocusManager.instance.listenToApplicationLifecycleChangesIfSupported();
      final other = FocusNode(debugLabel: 'other');
      addTearDown(other.dispose);
      try {
        await tester.pumpWidget(host(trailing: TextField(focusNode: other)));
        await tester.pump();
        other.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(other.hasFocus, isTrue, reason: 'test setup');

        // Going inactive parks focus on the root scope — "nothing", by the
        // backstop's lights. Resume restores the parked node only if nothing
        // took focus in between; a reclaim here is that something.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump();
        expect(other.hasFocus, isTrue);
        expect(callHasFocus(tester), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a focus request made earlier in the same post-frame phase wins', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final other = FocusNode(debugLabel: 'other');
      addTearDown(other.dispose);
      try {
        await tester.pumpWidget(host(trailing: TextField(focusNode: other)));
        await tester.pump();
        // The web view-focus guard's shape: focus falls to the root scope,
        // and an observer registered before the panel puts the field back
        // from a post-frame callback of its own — queued ahead of the
        // reclaim's, but applied only on a microtask after both. Read
        // naively, the reclaim sees "still nothing" and overrides it, landing
        // the caret in Callsign while someone is typing a note.
        WidgetsBinding.instance.addPostFrameCallback((_) => other.requestFocus());
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await tester.pump();
        expect(other.hasFocus, isTrue);
        expect(callHasFocus(tester), isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a field disposed while the app was away is replaced on resume', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      FocusManager.instance.listenToApplicationLifecycleChangesIfSupported();
      final other = FocusNode(debugLabel: 'other');
      addTearDown(other.dispose);
      try {
        await tester.pumpWidget(host(trailing: TextField(focusNode: other)));
        await tester.pump();
        other.requestFocus();
        await tester.pump();
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.pump();
        // The pane went away meanwhile: the manager has nothing to restore
        // and says nothing, so without a look on resume focus sits on the
        // root scope for good.
        await tester.pumpWidget(host());
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump();
        expect(callHasFocus(tester), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('editing an event row, the event text field is the default', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final event = Qso(
        uuid: 'event',
        operationUuid: operation.uuid,
        data: {
          'band': 'event',
          'freq': 0,
          'mode': 'note',
          'our': {'call': 'EVENT'},
          'their': {'call': 'NOTE'},
          'event': {'event': 'note', 'note': 'lunch'},
        },
      );
      try {
        await tester.pumpWidget(
          host(
            session: LoggingSession(editingQso: event, onEditCanceled: () {}),
          ),
        );
        await tester.pump();
        expect(find.widgetWithText(TextField, 'Their call'), findsNothing, reason: 'test setup: no callsign field');
        final text = find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'lunch');
        expect(text, findsOneWidget, reason: 'test setup');
        // With no callsign field in the tree there is nothing to reclaim —
        // unless the field standing in for it is the target.
        await dropFocus(tester);
        expect(tester.widget<TextField>(text).focusNode!.hasFocus, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a hardware keyboard on mobile: a dialog closing returns to the callsign', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      hardwareKeyboardAttached.value = true;
      try {
        await tester.pumpWidget(host());
        await tester.pump();
        expect(callHasFocus(tester), isTrue, reason: 'test setup: autofocus with a keyboard');
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        FocusManager.instance.primaryFocus?.unfocus();
        unawaited(
          navigator.push(
            DialogRoute<void>(
              context: navigator.context,
              builder: (_) => const AlertDialog(content: Text('dialog')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
        await tester.pump();
        expect(callHasFocus(tester), isTrue);
      } finally {
        hardwareKeyboardAttached.value = false;
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a hardware keyboard on mobile does not override a dismissal', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      hardwareKeyboardAttached.value = true;
      addTearDown(tester.view.reset);
      try {
        // The simulator reports the Mac's keyboard as attached and shows the
        // on-screen one regardless; an iPad in a keyboard case can do the
        // same. The operator dismissed the keyboard: a dialog closing after
        // that must not bring it back on the strength of the flag.
        await tester.pumpWidget(TapToDismissEmptyField(child: host()));
        await tester.pump();
        expect(callHasFocus(tester), isTrue, reason: 'test setup: autofocus with a keyboard');
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        final gesture = await tester.startGesture(tester.getCenter(find.widgetWithText(TextField, 'Their call')));
        await tester.pump(const Duration(milliseconds: 120));
        await gesture.up(timeStamp: const Duration(milliseconds: 120));
        await tester.pumpAndSettle();
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pump();
        expect(callHasFocus(tester), isFalse, reason: 'test setup: dismissed');

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(
          navigator.push(
            DialogRoute<void>(
              context: navigator.context,
              builder: (_) => const AlertDialog(content: Text('dialog')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
        await tester.pump();
        expect(callHasFocus(tester), isFalse);
      } finally {
        hardwareKeyboardAttached.value = false;
        debugDefaultTargetPlatformOverride = null;
      }
    });

    group('mobile with no hardware keyboard', () {
      void setKeyboard(WidgetTester tester, {required bool up}) {
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = up ? const FakeViewPadding(bottom: 300) : FakeViewPadding.zero;
      }

      Future<void> openAndCloseDialog(WidgetTester tester) async {
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        // The way operation_view opens its sheet: an unfocus first, which
        // also throws away what Navigator would otherwise restore on pop.
        FocusManager.instance.primaryFocus?.unfocus();
        unawaited(
          navigator.push(
            DialogRoute<void>(
              context: navigator.context,
              builder: (_) => const AlertDialog(content: Text('dialog')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('dialog'), findsOneWidget, reason: 'test setup');
        navigator.pop();
        await tester.pumpAndSettle();
        await tester.pump();
      }

      testWidgets('with the keyboard down, nothing is reclaimed', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(tester.view.reset);
        try {
          await tester.pumpWidget(host());
          await tester.pump();
          setKeyboard(tester, up: false);
          // A dialog closing over an idle phone must not pop the keyboard the
          // operator never asked for (HALO-93's reason, one step later).
          await dropFocus(tester);
          expect(callHasFocus(tester), isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('Done in a secondary field closes the keyboard, and it stays closed', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(tester.view.reset);
        try {
          await tester.pumpWidget(host());
          await openControl(tester, MdiIcons.clockOutline);
          final time = find.widgetWithText(TextField, 'Time (UTC)');
          setKeyboard(tester, up: true);
          await tester.pump();
          expect(tester.widget<TextField>(time).focusNode!.hasFocus, isTrue, reason: 'test setup');

          // Secondary fields keep Flutter's default: Done (and Back, and the
          // iOS hide-keyboard key) blurs. Undoing that blur would put the
          // keyboard the operator just closed straight back up, on Callsign.
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(callHasFocus(tester), isFalse);
          // And the memory is gone with it: a dialog after that stays quiet.
          await openAndCloseDialog(tester);
          expect(callHasFocus(tester), isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('a claim taken in another pane ends the panel\'s', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final other = FocusNode(debugLabel: 'other');
        addTearDown(other.dispose);
        addTearDown(tester.view.reset);
        try {
          await tester.pumpWidget(host(trailing: TextField(focusNode: other)));
          await tester.tap(find.widgetWithText(TextField, 'Their call'));
          await tester.pump();
          setKeyboard(tester, up: true);
          await tester.pump();
          expect(callHasFocus(tester), isTrue, reason: 'test setup');
          other.requestFocus();
          await tester.pump();
          await tester.pump();
          expect(other.hasFocus, isTrue, reason: 'test setup');
          // Done in that field blurs it; the operator was last THERE, not in
          // the panel, so the panel has no claim to press.
          other.unfocus();
          await tester.pump();
          await tester.pump();
          expect(callHasFocus(tester), isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('a dialog closing returns to the callsign the operator was in', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(tester.view.reset);
        try {
          await tester.pumpWidget(host());
          await tester.tap(find.widgetWithText(TextField, 'Their call'));
          await tester.pump();
          setKeyboard(tester, up: true);
          await tester.pump();
          expect(callHasFocus(tester), isTrue, reason: 'test setup');

          // The keyboard goes down with the dialog, so keyboard state at the
          // pop says "leave it" — what matters is where the operator was.
          setKeyboard(tester, up: false);
          await openAndCloseDialog(tester);
          expect(callHasFocus(tester), isTrue);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('a dialog closing after tap-to-dismiss leaves the keyboard down', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(tester.view.reset);
        try {
          await tester.pumpWidget(TapToDismissEmptyField(child: host()));
          await tester.tap(find.widgetWithText(TextField, 'Their call'));
          await tester.pump();
          setKeyboard(tester, up: true);
          await tester.pump();
          final gesture = await tester.startGesture(tester.getCenter(find.widgetWithText(TextField, 'Their call')));
          await tester.pump(const Duration(milliseconds: 120));
          await gesture.up(timeStamp: const Duration(milliseconds: 120));
          await tester.pumpAndSettle();
          setKeyboard(tester, up: false);
          await tester.pump();
          expect(callHasFocus(tester), isFalse, reason: 'test setup: dismissed');

          // The operator asked for the keyboard to go; a dialog in between
          // does not un-ask it.
          await openAndCloseDialog(tester);
          expect(callHasFocus(tester), isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('tap-to-dismiss is the operator asking for nothing focused, and gets it', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(tester.view.reset);
        try {
          await tester.pumpWidget(TapToDismissEmptyField(child: host()));
          await tester.tap(find.widgetWithText(TextField, 'Their call'));
          await tester.pump();
          setKeyboard(tester, up: true);
          await tester.pump();
          expect(callHasFocus(tester), isTrue, reason: 'test setup');

          // The gesture, at finger speed (see keyboard_dismiss_test.dart).
          final gesture = await tester.startGesture(tester.getCenter(find.widgetWithText(TextField, 'Their call')));
          await tester.pump(const Duration(milliseconds: 120));
          await gesture.up(timeStamp: const Duration(milliseconds: 120));
          await tester.pumpAndSettle();
          await tester.pump();
          // Indistinguishable from the side effect above by keyboard state
          // alone — the keyboard is still on screen when focus drops — so
          // the dismissal has to say what it is.
          expect(callHasFocus(tester), isFalse);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    });
  });
}
