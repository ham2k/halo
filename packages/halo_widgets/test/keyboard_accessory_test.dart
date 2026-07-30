// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The publish/withdraw protocol behind the mobile numbers row. The row is
// drawn one level above the field that owns it, so every way of getting rid
// of that field has to take the row with it — a stale row hangs over whatever
// replaced the field and types into something the operator cannot see.
//
// These pin the protocol itself. The rows-in-context behaviour lives in
// logging_controls_test.dart and home_quick_lookup_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

KeyboardAccessorySpec spec(String? extraKey) => KeyboardAccessorySpec(
      onKey: (_) {},
      vibrate: true,
      backgroundColor: 0xFF000000,
      foregroundColor: 0xFFFFFFFF,
      extraKey: extraKey,
    );

void main() {
  test('a publisher withdraws its own row', () {
    final controller = KeyboardAccessoryController();
    final owner = Object();
    controller.publish(owner, spec('.'));
    expect(controller.value, isNotNull);

    controller.clearIfOwner(owner);
    expect(controller.value, isNull);
  });

  test('a non-owner cannot withdraw someone else\'s row', () {
    final controller = KeyboardAccessoryController();
    final a = Object();
    final b = Object();
    controller.publish(a, spec('.'));

    controller.clearIfOwner(b);
    expect(controller.value, isNotNull, reason: 'b never owned it and must not blank it');
  });

  // The hand-off order that actually happens: the field gaining focus publishes
  // during its build, and the field losing focus is disposed afterwards. If the
  // loser could clear unconditionally, the winner's row would vanish.
  test('a field disposed after another has taken over does not blank the new row', () {
    final controller = KeyboardAccessoryController();
    final leaving = Object();
    final arriving = Object();

    controller.publish(leaving, spec('.'));
    controller.publish(arriving, spec('/'));
    controller.clearIfOwner(leaving);

    expect(controller.value, isNotNull);
    expect(controller.value!.extraKey, '/', reason: 'the arriving field still owns the row');

    controller.clearIfOwner(arriving);
    expect(controller.value, isNull, reason: 'and the owner can still take it back');
  });

  // Equality is what stops a notify storm: LoggingControls rebuilds on every
  // keystroke and every QSO-stream tick, and the listener is above the whole app.
  test('republishing an unchanged spec does not notify', () {
    final controller = KeyboardAccessoryController();
    final owner = Object();
    var notifications = 0;
    controller.addListener(() => notifications++);

    void onKey(String _) {}
    KeyboardAccessorySpec same() => KeyboardAccessorySpec(
          onKey: onKey,
          vibrate: true,
          backgroundColor: 0xFF102030,
          foregroundColor: 0xFFFFFFFF,
          extraKey: '.',
        );

    for (var i = 0; i < 10; i++) {
      controller.publish(owner, same());
    }
    expect(notifications, 1, reason: 'ten identical publishes are one change');

    controller.publish(owner, spec('/'));
    expect(notifications, 2, reason: 'but a real change still gets through');
  });

  // The hand-off as it actually happens in a frame, which the plain-Dart test
  // above cannot reproduce: the ARRIVING field publishes from a post-frame
  // callback scheduled during build, while the LEAVING field withdraws from
  // `dispose`, in the same frame's `finalizeTree`. The withdrawal is therefore
  // queued after the publish. If it landed anyway it would blank the row of a
  // field that is focused and on screen.
  testWidgets('a withdrawal deferred past a later publish does not blank it', (tester) async {
    final controller = KeyboardAccessoryController();

    await tester.pumpWidget(_Publisher(key: const ValueKey('a'), controller: controller, tag: 'A'));
    await tester.pump();
    expect(controller.value?.extraKey, 'A');

    // One pumpWidget: B builds (scheduling its publish) and A is disposed in
    // the same frame.
    await tester.pumpWidget(_Publisher(key: const ValueKey('b'), controller: controller, tag: 'B'));
    await tester.pump();
    await tester.pump();

    expect(controller.value?.extraKey, 'B', reason: "A's withdrawal must not overwrite B's row");
  });

  testWidgets('absent visibility means visible, so single-pane hosts need no wiring', (tester) async {
    late bool seen;
    await tester.pumpWidget(Builder(builder: (context) {
      seen = KeyboardAccessoryVisibility.of(context);
      return const SizedBox.shrink();
    }));
    expect(seen, isTrue);
  });

  testWidgets('a hidden pane reports invisible, and flipping it notifies dependents', (tester) async {
    final seen = <bool>[];
    Widget build(bool visible) => KeyboardAccessoryVisibility(
          visible: visible,
          child: Builder(builder: (context) {
            seen.add(KeyboardAccessoryVisibility.of(context));
            return const SizedBox.shrink();
          }),
        );

    await tester.pumpWidget(build(true));
    await tester.pumpWidget(build(false));
    expect(seen, [true, false]);
  });

  // Separate from the widget test above, because `pumpWidget` rebuilds the
  // whole tree either way and so cannot measure this. It matters: the flag
  // hangs off a TabController, which notifies on every animation tick rather
  // than only on a tab change.
  test('an unchanged value does not notify dependents', () {
    const stable = KeyboardAccessoryVisibility(visible: true, child: SizedBox.shrink());
    expect(
      stable.updateShouldNotify(const KeyboardAccessoryVisibility(visible: true, child: SizedBox.shrink())),
      isFalse,
    );
    expect(
      stable.updateShouldNotify(const KeyboardAccessoryVisibility(visible: false, child: SizedBox.shrink())),
      isTrue,
    );
  });
}

/// Publishes from a post-frame callback scheduled during build, and withdraws
/// from `dispose` — the shape both real publishers use.
class _Publisher extends StatefulWidget {
  final KeyboardAccessoryController controller;
  final String tag;
  const _Publisher({super.key, required this.controller, required this.tag});
  @override
  State<_Publisher> createState() => _PublisherState();
}

class _PublisherState extends State<_Publisher> {
  @override
  void dispose() {
    widget.controller.clearIfOwner(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.publish(this, spec(widget.tag));
    });
    return const SizedBox.shrink();
  }
}
