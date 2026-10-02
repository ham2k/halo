// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter, LogicalKeyboardKey, PhysicalKeyboardKey, TextEditingValue, TextSelection;
import 'package:halo_widgets/halo_widgets.dart' show LoggingControls, LoggingEntryRow;

import '../../services/settings_service.dart';

/// Which CW message (1-based, up to [SettingsService.cwMessageCount]) [key]
/// stands for — F1 is message 1 — or null for any other key.
///
/// Bare function keys, deliberately: they are what every contest logger
/// sends messages on, and nothing else in the app claims them. A modifier
/// held alongside is the caller's to check, so ⌘F1 (a system shortcut on
/// some desktops) is not read as a message.
int? cwMessageIndexForKey(LogicalKeyboardKey key) {
  const keys = [
    LogicalKeyboardKey.f1,
    LogicalKeyboardKey.f2,
    LogicalKeyboardKey.f3,
    LogicalKeyboardKey.f4,
    LogicalKeyboardKey.f5,
    LogicalKeyboardKey.f6,
    LogicalKeyboardKey.f7,
    LogicalKeyboardKey.f8,
  ];
  assert(keys.length == SettingsService.cwMessageCount, 'one key per message, and no more');
  final index = keys.indexOf(key);
  return index < 0 ? null : index + 1;
}

/// Which CW message [key] stands for as the digit of a ⌥1-⌥8 (Alt+1-8)
/// chord — the function keys' stand-in on a keyboard that has none (a
/// laptop's needs Fn, a tablet's has no row at all) — or null. PHYSICAL
/// keys: Option turns the digits into '¡™£¢∞§¶•' on a Mac, and the logical
/// key a browser reports is that character. The modifier is the caller's to
/// check, as with [cwMessageIndexForKey].
int? cwMessageIndexForDigit(PhysicalKeyboardKey key) {
  const keys = [
    PhysicalKeyboardKey.digit1,
    PhysicalKeyboardKey.digit2,
    PhysicalKeyboardKey.digit3,
    PhysicalKeyboardKey.digit4,
    PhysicalKeyboardKey.digit5,
    PhysicalKeyboardKey.digit6,
    PhysicalKeyboardKey.digit7,
    PhysicalKeyboardKey.digit8,
  ];
  assert(keys.length == SettingsService.cwMessageCount, 'one key per message, and no more');
  final index = keys.indexOf(key);
  return index < 0 ? null : index + 1;
}

/// Whether ['] is the operator's PTT (docs/design/cat.md § PTT) with the
/// keyboard at [focused], rather than a character typed into a field.
///
/// The main fields are where the operator works a contact, so there it is
/// PTT whatever the field would accept — a name or a state included — save
/// the call field reading a command that takes free text, as NOTE does. In
/// the secondary controls a field that would take the character keeps it (a
/// note), and one that would filter it out (the frequency) lets it key the
/// radio. Any other text field keeps it whatever it filters: outside the
/// logging fields ['] is never PTT while typing. With no field focused it
/// is PTT.
bool quoteKeysPtt(BuildContext? focused) {
  final field = focused?.findAncestorWidgetOfExactType<EditableText>();
  if (field == null) return true;
  final row = focused!.findAncestorWidgetOfExactType<LoggingEntryRow>();
  if (row != null) return !identical(field.controller, row.call.controller) || !_fieldTakes(field, "'");
  if (focused.findAncestorWidgetOfExactType<LoggingControls>() == null) return false;
  return field.readOnly || !_fieldTakes(field, "'");
}

/// Whether typing [character] into [field] would leave it in the text —
/// asked of the field's own formatters, the same ones the keystroke meets,
/// so a field whose filter changes with its mode (the call field reading a
/// command) answers for the mode it is in.
bool _fieldTakes(EditableText field, String character) {
  final before = field.controller.value;
  final selection = before.selection.isValid ? before.selection : TextSelection.collapsed(offset: before.text.length);
  final kept = before.text.replaceRange(selection.start, selection.end, '');
  final typed = TextEditingValue(
    text: before.text.replaceRange(selection.start, selection.end, character),
    selection: TextSelection.collapsed(offset: selection.start + character.length),
  );
  // Not the length limit: a field that is full right now still takes the
  // character as text, and ['] typed into it must not key the radio instead.
  final formatters = [...?field.inputFormatters].where((formatter) => formatter is! LengthLimitingTextInputFormatter);
  final after = formatters.fold(typed, (value, formatter) => formatter.formatEditUpdate(before, value));
  return character.allMatches(after.text).length > character.allMatches(kept).length;
}
