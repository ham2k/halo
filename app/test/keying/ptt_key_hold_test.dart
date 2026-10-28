// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Hold PTT (docs/design/cat.md § PTT): the key transmits from its press to
// its release. The traps are the toggle's habits leaking in — a press that
// drops a key someone else holds, a repeat that toggles — and a release that
// never arrives, which would leave the transmitter on until the timeout.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_ptt.dart';

void main() {
  final apostrophe = LogicalKeyboardKey.findKeyByKeyId("'".codeUnitAt(0))!;

  Future<void> down(WidgetTester tester) => tester.sendKeyDownEvent(apostrophe, platform: 'web', physicalKey: PhysicalKeyboardKey.quote, character: "'");
  Future<void> repeat(WidgetTester tester) => tester.sendKeyRepeatEvent(apostrophe, platform: 'web', physicalKey: PhysicalKeyboardKey.quote, character: "'");
  Future<void> up(WidgetTester tester) => tester.sendKeyUpEvent(apostrophe, platform: 'web', physicalKey: PhysicalKeyboardKey.quote);

  /// The keyboard over a key that keys on toggle and drops on release, as
  /// CatPtt does for the operator; [releases] counts the drops asked for.
  ({PttKeyboard ptt, ValueNotifier<bool> held, List<String> releases}) keyboard(WidgetTester tester, {bool hold = true}) {
    final held = ValueNotifier(false);
    final releases = <String>[];
    final ptt = PttKeyboard(
      held: held,
      release: () {
        releases.add('release');
        final was = held.value;
        held.value = false;
        return was;
      },
      escape: () => false,
      toggle: (_) => held.value = !held.value,
      hold: () => hold,
    );
    addTearDown(() {
      ptt.dispose();
      held.dispose();
    });
    ptt.addTarget(() => 'radio1');
    return (ptt: ptt, held: held, releases: releases);
  }

  testWidgets('held, the key transmits from its press to its release, through its repeats', (tester) async {
    final (:ptt, :held, :releases) = keyboard(tester);
    await down(tester);
    expect(held.value, isTrue);
    await repeat(tester);
    await repeat(tester);
    expect(held.value, isTrue, reason: 'a repeat is the same press, not a second toggle');
    await up(tester);
    expect(held.value, isFalse);
  });

  // A CAT server client's key (FT8) is on the air half of every minute: a
  // press must not end it, and its release must not either.
  testWidgets('held, a press over a key someone else holds takes nothing and drops nothing', (tester) async {
    final (:ptt, :held, :releases) = keyboard(tester);
    held.value = true;
    await down(tester);
    await up(tester);
    expect(held.value, isTrue);
    expect(releases, isEmpty);
    // Nor is the press swallowed: rebound to a key another command shares,
    // that command would stop working whenever a client transmits.
    expect(ptt.handle(KeyDownEvent(physicalKey: PhysicalKeyboardKey.quote, logicalKey: apostrophe, character: "'", timeStamp: Duration.zero)), isFalse);
  });

  // The app losing focus with the key down never hears the key come up.
  testWidgets('held, the key drops when the app stops being in front, and its late release does nothing more', (tester) async {
    final (:ptt, :held, :releases) = keyboard(tester);
    await down(tester);
    expect(held.value, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(held.value, isFalse);
    expect(releases, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await up(tester);
    expect(releases, hasLength(1));
  });

  testWidgets('toggled, the release leaves the key on', (tester) async {
    final (:ptt, :held, :releases) = keyboard(tester, hold: false);
    await down(tester);
    await up(tester);
    expect(held.value, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(held.value, isTrue, reason: 'a toggled key was meant to stay on; the timeout is what ends a forgotten one');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
