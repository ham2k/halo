// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PTT moved off ['] (`radio.ptt`, docs/design/keyboard-shortcuts.md): what the
// surfaces are asked, and what keys the radio.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/cat_ptt.dart';

void main() {
  // A ⌘ or Ctrl chord's event still carries its letter. Asked whether the
  // call field — which would take a "p" — keeps it, the press does nothing
  // where the operator works.
  testWidgets('a ⌘ or Ctrl PTT chord keys the radio, whatever letter it carries', (tester) async {
    keyBindings.value = const KeyBindingOverrides().withCommand(pttCommandId, [KeyChord.parse('ctrl+P')!]).resolve();
    addTearDown(() => keyBindings.value = LegacyKeyBindings());
    final held = ValueNotifier(false);
    addTearDown(held.dispose);
    final keyed = <String>[];
    final ptt = PttKeyboard(held: held, release: () => false, escape: () => false, toggle: keyed.add, hold: () => false);
    addTearDown(ptt.dispose);
    ptt.addTarget(() => 'radio1');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyP, character: 'p');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(keyed, ['radio1']);
  });

  testWidgets('the bound key alone keys nothing, and the old one is free again', (tester) async {
    keyBindings.value = const KeyBindingOverrides().withCommand(pttCommandId, [KeyChord.parse('F9')!]).resolve();
    addTearDown(() => keyBindings.value = LegacyKeyBindings());
    final held = ValueNotifier(false);
    addTearDown(held.dispose);
    final keyed = <String>[];
    final ptt = PttKeyboard(held: held, release: () => false, escape: () => false, toggle: keyed.add, hold: () => false);
    addTearDown(ptt.dispose);
    ptt.addTarget(() => 'radio1');

    final apostrophe = LogicalKeyboardKey.findKeyByKeyId("'".codeUnitAt(0))!;
    await tester.sendKeyEvent(apostrophe, platform: 'web', physicalKey: PhysicalKeyboardKey.quote, character: "'");
    expect(keyed, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    expect(keyed, ['radio1']);
  });
}
