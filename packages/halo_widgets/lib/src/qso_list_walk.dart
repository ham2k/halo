// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The keys that walk a QSO list from a text field — the logging fields, the
// Find bar — while the keyboard stays in the field
// (docs/design/logging-fields.md, "The QSO list" under the focus ladder).

import 'package:flutter/services.dart';

/// A step through the list, in screen terms: [up] is the row drawn above,
/// whichever way up the list runs. The host turns it into older or newer.
enum QsoListWalk { up, down, pageUp, pageDown, top, bottom }

/// The walk [event] asks for, or null for a key that is the field's own.
///
/// Up and Down step a row; Page Up and Page Down, and Option+Up/Down, a
/// screenful; Cmd+Up/Down go to the ends, as macOS spells them. In a
/// single-line field those chords only ever park the caret at an end of the
/// text, which Left and Right reach as well. Home and End are not taken:
/// there they are the caret's. Shift and Ctrl leave every key to the field
/// — Shift+arrow is a selection, and Ctrl belongs to the platform.
QsoListWalk? qsoListWalkFor(KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
  final keyboard = HardwareKeyboard.instance;
  if (keyboard.isShiftPressed || keyboard.isControlPressed) return null;
  final meta = keyboard.isMetaPressed;
  final alt = keyboard.isAltPressed;
  final key = event.logicalKey;
  if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
    final up = key == LogicalKeyboardKey.arrowUp;
    if (meta && alt) return null;
    if (meta) return up ? QsoListWalk.top : QsoListWalk.bottom;
    if (alt) return up ? QsoListWalk.pageUp : QsoListWalk.pageDown;
    return up ? QsoListWalk.up : QsoListWalk.down;
  }
  if (meta || alt) return null;
  if (key == LogicalKeyboardKey.pageUp) return QsoListWalk.pageUp;
  if (key == LogicalKeyboardKey.pageDown) return QsoListWalk.pageDown;
  return null;
}
