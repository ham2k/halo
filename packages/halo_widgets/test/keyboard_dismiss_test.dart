// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The load-bearing guarantee is the NEGATIVE space: a second tap must dismiss
// the keyboard ONLY on an empty field, only on mobile, only with the keyboard
// actually up, and only when the tap lands on the focused field itself. Every
// other tap has to keep focus exactly where it was — a field holding text
// must stay focused so the tap can move the caret, which is what a tap means
// there.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

void main() {
  const keyboardHeight = 300.0; // well past minVirtualKeyboardInset

  /// Two fields so "tapped somewhere else" is a real case, not a tap on
  /// empty background. The FocusNodes are explicit and owned by the harness:
  /// asserting against `TextField.focusNode` instead would read null (the
  /// field makes its own internal node), and `node?.hasFocus ?? false` then
  /// silently reports "not focused" for every case.
  Widget host(_Fields f) => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          TapToDismissEmptyField(
            focusNode: f.first,
            controller: f.firstText,
            child: TextField(key: const Key('first'), controller: f.firstText, focusNode: f.first),
          ),
          TapToDismissEmptyField(
            focusNode: f.second,
            controller: f.secondText,
            child: TextField(key: const Key('second'), controller: f.secondText, focusNode: f.second),
          ),
        ],
      ),
    ),
  );

  /// Raises/lowers the on-screen keyboard. `viewInsets` is in PHYSICAL pixels
  /// (the helper divides by devicePixelRatio), and the helper reads the raw
  /// FlutterView, so this has to be set on the view rather than via MediaQuery.
  void setKeyboard(WidgetTester tester, {required bool up}) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = up ? const FakeViewPadding(bottom: keyboardHeight) : FakeViewPadding.zero;
  }

  /// A tap at real-world speed: `tester.tap` sends down and up with no frame
  /// between, which is not how a finger behaves and hid a real bug once.
  ///
  /// Both clocks have to be advanced by hand. `tester.pump(d)` moves FRAMES
  /// but leaves pointer-event timestamps alone — `TestGesture.up` defaults to
  /// `Duration.zero`, so without the explicit `timeStamp` every synthetic
  /// gesture looks instantaneous to code that measures press duration.
  Future<void> slowTap(WidgetTester tester, Offset at, {Duration hold = const Duration(milliseconds: 120)}) async {
    final gesture = await tester.startGesture(at);
    await tester.pump(hold);
    await gesture.up(timeStamp: hold);
    await tester.pumpAndSettle();
  }

  /// The behavior is mobile-only, so every test runs as Android unless it is
  /// specifically checking the desktop no-op. Reset inside the test body, not
  /// in a tearDown: the framework's platform-override invariant is checked
  /// before tearDowns run.
  Future<void> asPlatform(TargetPlatform platform, Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('tapping a focused EMPTY field again dismisses the keyboard', (tester) async {
    await asPlatform(TargetPlatform.android, () async {
      final f = _Fields();
      addTearDown(f.dispose);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(f));

      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();
      setKeyboard(tester, up: true);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

      // The second tap on the same, still-empty field.
      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();

      expect(f.first.hasFocus, isFalse, reason: 'the empty field should have blurred');
      expect(tester.testTextInput.isVisible, isFalse, reason: 'blurring the only focused field closes the input connection');
    });
  });

  testWidgets('a SLOW tap (finger held across several frames) still dismisses', (tester) async {
    await asPlatform(TargetPlatform.android, () async {
      final f = _Fields();
      addTearDown(f.dispose);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(f));

      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();
      setKeyboard(tester, up: true);
      await tester.pump();

      // `tester.tap` sends down and up back-to-back with no frame between,
      // which is NOT how a real tap behaves: a finger rests on the glass for
      // 50–150ms, i.e. several frames. Acting on pointer-DOWN passes the fast
      // synthetic tap and fails here, because the field's own tap handler
      // runs after the dismissal and re-opens the keyboard.
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('first'))));
      await tester.pump(const Duration(milliseconds: 120));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(f.first.hasFocus, isFalse, reason: 'a normal-speed tap must dismiss too');
      expect(tester.testTextInput.isVisible, isFalse);
    });
  });

  testWidgets('a tap on the field DECORATION (label/padding) dismisses, not just the text line', (tester) async {
    await asPlatform(TargetPlatform.android, () async {
      final f = _Fields();
      addTearDown(f.dispose);
      addTearDown(tester.view.reset);

      // A floating label plus content padding: the editable strip is a
      // fraction of the field's height, and the rest is decoration the field
      // still focuses from — so the dismissal has to hear taps on the whole
      // field, not just its text line.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TapToDismissEmptyField(
              focusNode: f.first,
              controller: f.firstText,
              child: TextField(
                key: const Key('first'),
                controller: f.firstText,
                focusNode: f.first,
                decoration: const InputDecoration(labelText: 'Callsign', contentPadding: EdgeInsets.all(24)),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();
      setKeyboard(tester, up: true);
      await tester.pump();

      final rect = tester.getRect(find.byKey(const Key('first')));
      final editableBox = f.first.context!.findRenderObject()! as RenderBox;
      expect(editableBox.size.height, lessThan(rect.height / 2), reason: 'guard the premise: the editable really is much smaller than the field');

      // 6pt below the field's top edge — inside the decoration, outside the
      // editable.
      await slowTap(tester, Offset(rect.center.dx, rect.top + 6));

      expect(f.first.hasFocus, isFalse, reason: 'the whole field is the tap target, not just its text line');
    });
  });

  testWidgets('a DRAG starting on the field scrolls rather than dismissing', (tester) async {
    await asPlatform(TargetPlatform.android, () async {
      final f = _Fields();
      addTearDown(f.dispose);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(f));
      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();
      setKeyboard(tester, up: true);
      await tester.pump();

      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('first'))));
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveBy(const Offset(0, 220)); // well past kTouchSlop
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(f.first.hasFocus, isTrue, reason: 'dragging from a field is a scroll, not a dismissal');
    });
  });

  testWidgets('a LONG PRESS keeps the keyboard, so the paste toolbar it raises stays usable', (tester) async {
    await asPlatform(TargetPlatform.android, () async {
      final f = _Fields();
      addTearDown(f.dispose);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(f));
      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();
      setKeyboard(tester, up: true);
      await tester.pump();

      await slowTap(tester, tester.getCenter(find.byKey(const Key('first'))), hold: kLongPressTimeout + const Duration(milliseconds: 50));

      expect(f.first.hasFocus, isTrue, reason: 'a long press is not a tap');
    });
  });

  testWidgets('tapping a focused field that HAS TEXT keeps focus, so the tap can move the caret', (tester) async {
    await asPlatform(TargetPlatform.android, () async {
      final f = _Fields(firstValue: 'KI2D');
      addTearDown(f.dispose);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(f));

      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();
      setKeyboard(tester, up: true);
      await tester.pump();

      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isTrue, reason: 'a field with text must keep the keyboard');
    });
  });

  testWidgets('tapping a DIFFERENT field moves focus rather than dismissing', (tester) async {
    await asPlatform(TargetPlatform.android, () async {
      final f = _Fields();
      addTearDown(f.dispose);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(f));

      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();
      setKeyboard(tester, up: true);
      await tester.pump();

      // Both fields are empty and both opted in — only a tap on a field that
      // was ALREADY focused counts, or the first tap on any field would
      // dismiss the keyboard it just raised.
      await tester.tap(find.byKey(const Key('second')));
      await tester.pumpAndSettle();

      expect(f.second.hasFocus, isTrue, reason: 'focus should have moved to the tapped field');
      expect(tester.testTextInput.isVisible, isTrue);
    });
  });

  testWidgets('with the keyboard DOWN the second tap is a no-op', (tester) async {
    await asPlatform(TargetPlatform.android, () async {
      final f = _Fields();
      addTearDown(f.dispose);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(f));
      setKeyboard(tester, up: false);

      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();

      expect(f.first.hasFocus, isTrue, reason: 'nothing to dismiss, so focus stays');
    });
  });

  testWidgets('on DESKTOP the field keeps focus even with a large bottom inset', (tester) async {
    await asPlatform(TargetPlatform.macOS, () async {
      final f = _Fields();
      addTearDown(f.dispose);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(f));

      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();
      setKeyboard(tester, up: true); // e.g. a docked panel, not a keyboard
      await tester.pump();

      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();

      expect(f.first.hasFocus, isTrue, reason: 'desktop has no on-screen keyboard to dismiss');
    });
  });

  testWidgets('a thin iOS hardware-keyboard bar is below the threshold and does not trigger', (tester) async {
    await asPlatform(TargetPlatform.iOS, () async {
      final f = _Fields();
      addTearDown(f.dispose);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(f));

      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();
      // The shortcuts/assistant bar iOS raises with a HARDWARE keyboard
      // attached — real, but nothing the user wants dismissed.
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 50);
      await tester.pump();

      await tester.tap(find.byKey(const Key('first')));
      await tester.pumpAndSettle();

      expect(f.first.hasFocus, isTrue, reason: '50px is under minVirtualKeyboardInset');
    });
  });
}

/// Controllers + focus nodes for the two-field harness, disposed together.
class _Fields {
  final TextEditingController firstText;
  final TextEditingController secondText;
  final FocusNode first = FocusNode(debugLabel: 'first');
  final FocusNode second = FocusNode(debugLabel: 'second');

  _Fields({String firstValue = ''}) : firstText = TextEditingController(text: firstValue), secondText = TextEditingController();

  void dispose() {
    firstText.dispose();
    secondText.dispose();
    first.dispose();
    second.dispose();
  }
}
