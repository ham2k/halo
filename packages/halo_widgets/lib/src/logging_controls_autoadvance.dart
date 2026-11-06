// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging row's fields moving focus on by themselves, under the operator's
// Auto-advance Fields setting: an exchange control's `autoadvanceWhen` and
// `autoadvanceBefore`, and the reports' rule (docs/design/logging-fields.md).
// [AutoadvanceFormatter] hands the keystrokes that move on to
// [ExchangeFieldsModel.typeAcross]; [AdvanceWhenFormatter] moves focus on once
// an edit completes a value.

import 'dart:async';

import 'package:flutter/services.dart';

import 'logging_controls_exchange.dart';
import 'ref_text_input.dart';

/// [input]'s `autoadvanceWhen` / `autoadvanceBefore`, compiled the way every
/// exchange pattern is (anchored, case-insensitive); null when absent,
/// malformed, or the field takes spaces ([_takesSpaces]).
RegExp? autoadvanceWhen(Map<dynamic, dynamic> input) => _pattern(input, 'autoadvanceWhen');
RegExp? autoadvanceBefore(Map<dynamic, dynamic> input) => _pattern(input, 'autoadvanceBefore');

/// A rule an extension wrote as anything but a string is no rule: this runs
/// on every keystroke, where a throw would eat the keystroke too.
RegExp? _pattern(Map<dynamic, dynamic> input, String name) => switch (input[name]) {
  final String source when !_takesSpaces(input) => compileRefPattern(source),
  _ => null,
};

/// Whether [input]'s field holds spaces as part of its value — an `options`
/// list whose values a space separates. Its autoadvance rules are ignored:
/// a value that is several entries has no point at which it is complete,
/// and moving on mid-list would split it across fields.
bool _takesSpaces(Map<dynamic, dynamic> input) {
  final separator = (input['multiValue'] as Map?)?['separator'];
  return separator is String && separator.contains(RegExp(r'\s'));
}

/// Hands an edit to [ExchangeFieldsModel.typeAcross] when the placing
/// decides it: a keystroke whose value matches the field's
/// `autoadvanceBefore`, the first keystroke in a field still showing only a
/// guess, or a paste. Only on a field with autoadvance rules or in a `group`,
/// and only an insertion at the end of the value — an edit inside it is a
/// correction, and splitting it across fields would scatter it. Anything
/// else passes through to the field's own formatters, and an
/// `autoadvanceWhen` there is [AdvanceWhenFormatter]'s.
///
/// A paste holding a space is placed by its spaces alone, as if Auto-advance
/// Fields were off: text that already says where each value ends is not
/// split again by the rules.
///
/// Installed after the serial step (whose "." and "," are no characters to
/// pass on) and ahead of the other formatters — a numeric filter would
/// otherwise swallow the very letter that is meant for the next field.
class AutoadvanceFormatter extends TextInputFormatter {
  AutoadvanceFormatter(this.model, this.key, this.control);

  final ExchangeFieldsModel model;
  final String key;
  final Map<dynamic, dynamic> control;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final input = control['input'] as Map;
    // A field that takes spaces keeps its own keystrokes, pastes included:
    // placed by its spaces, a list would be split across the fields.
    if (_takesSpaces(input)) return newValue;
    final autoAdvance = model.config().autoAdvance;
    final before = autoAdvance ? autoadvanceBefore(input) : null;
    final when = autoAdvance ? autoadvanceWhen(input) : null;
    final grouped = control['group'] is String && (control['group'] as String).isNotEmpty;
    if (before == null && when == null && !grouped) return newValue;
    if (!model.typesAcross(key)) return newValue;
    final selection = oldValue.selection.isValid ? oldValue.selection : TextSelection.collapsed(offset: oldValue.text.length);
    if (selection.end != oldValue.text.length) return newValue;
    final insertedLength = newValue.text.length - selection.start;
    if (insertedLength <= 0 || !newValue.text.startsWith(oldValue.text.substring(0, selection.start))) return newValue;
    final prefix = oldValue.text.substring(0, selection.start);
    final inserted = newValue.text.substring(selection.start);
    // A field still showing only a guess is replaced by the first keystroke,
    // not appended to — see [ExchangeFieldsModel.typeAcross].
    final replacesGuess = !model.isTouched(key) && oldValue.text.isNotEmpty;
    if (insertedLength == 1 && !replacesGuess && !(before?.hasMatch(newValue.text) ?? false)) return newValue;
    final spaced = inserted.contains(RegExp(r'\s'));
    scheduleMicrotask(() => model.typeAcross(key, prefix, inserted, rules: !spaced));
    return oldValue;
  }
}

/// Moves focus on when an edit changes a field's value to one matching
/// [when] — `autoadvanceWhen`, for the reports and for an exchange field's
/// keystrokes that [AutoadvanceFormatter] lets through. Any change that
/// types something counts, wherever the caret is; arriving in a field that
/// already matches is no change, so tapping into a complete value stays put.
/// A deletion never moves on: Backspace is a correction under way, and a
/// `599` shortened to a complete phone `59` must not throw the operator out
/// of the field mid-edit.
///
/// Installed last, so it reads the value the filters leave.
class AdvanceWhenFormatter extends TextInputFormatter {
  const AdvanceWhenFormatter(this.when, this.advance);

  final RegExp when;
  final VoidCallback advance;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text != oldValue.text && _typesSomething(oldValue.text, newValue.text) && when.hasMatch(newValue.text)) {
      scheduleMicrotask(advance);
    }
    return newValue;
  }

  /// Whether [after] holds a character [before] did not — false when the
  /// edit only took characters out.
  static bool _typesSomething(String before, String after) {
    var start = 0;
    while (start < before.length && start < after.length && before[start] == after[start]) {
      start++;
    }
    var end = 0;
    while (end < before.length - start && end < after.length - start && before[before.length - 1 - end] == after[after.length - 1 - end]) {
      end++;
    }
    return after.length - start - end > 0;
  }
}
