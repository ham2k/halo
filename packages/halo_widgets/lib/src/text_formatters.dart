// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';

/// The one uppercase input formatter for the whole package — logging input
/// is uppercase unless a field is explicitly mixed-case. Any behavior change
/// (e.g. locale-aware uppercasing, or preserving the composing region when
/// the text changes) belongs here so every field stays in agreement. `const`
/// so call sites share one canonical instance instead of allocating per
/// build.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Live-cases a Maidenhead grid locator as it's typed: the field pair and
/// square digits (positions 0-3) uppercase, the subsquare and everything
/// after (position 4+) lowercase — the same convention `normalizeGrid`
/// (halo_core) restores for a complete, well-formed locator, applied
/// character-by-character instead of gated on the whole string already being
/// valid, so a field mid-entry ("FN31p...") already reads in its final case
/// rather than snapping to it only once four more characters land.
class GridCaseTextFormatter extends TextInputFormatter {
  const GridCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      buffer.write(i < 4 ? text[i].toUpperCase() : text[i].toLowerCase());
    }
    final formatted = buffer.toString();
    if (formatted == text) return newValue;
    return newValue.copyWith(text: formatted);
  }
}

/// Capitalizes only the field's first letter, live — for a free-text field
/// that reads as a proper noun (a state, a county) but otherwise takes
/// whatever mixed case the operator types, unlike [UpperCaseTextFormatter]'s
/// whole-field uppercasing.
class CapitalizeFirstLetterTextFormatter extends TextInputFormatter {
  const CapitalizeFirstLetterTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final capitalized = text[0].toUpperCase() + text.substring(1);
    if (capitalized == text) return newValue;
    return newValue.copyWith(text: capitalized);
  }
}

/// Rewrites whichever decimal mark the keyboard produced into the one the
/// operator's Number Formatting setting is using.
///
/// Which key a numeric keyboard puts under the operator's thumb is not
/// something this app decides: a Spanish or German phone offers a comma
/// whatever the app is set to, and a desktop numpad emits a period regardless
/// of region. So a `number` field admits both marks and normalizes here,
/// rather than filtering to the configured one and silently swallowing the
/// other — the swallow is invisible (`1,5` simply becomes `15`) and lands on
/// exactly the operator the explicit period/comma options exist to help.
///
/// Normalizing on the way IN rather than at parse time is what keeps the
/// value unambiguous: a field that can only contain the configured decimal
/// never leaves anyone guessing whether the mark in `14.285` was a decimal
/// point or a thousands separator.
///
/// Length is preserved (one mark for one mark), so the caret does not move.
class LocalizedDecimalMarkFormatter extends TextInputFormatter {
  const LocalizedDecimalMarkFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final decimal = NumberFormatting.instance.decimalSeparator;
    // Only the two marks a keyboard actually offers as a decimal point.
    final foreign = ['.', ','].where((mark) => mark != decimal);
    var text = newValue.text;
    for (final mark in foreign) {
      if (_readsAsGrouping(text, mark)) continue;
      text = text.replaceAll(mark, decimal);
    }
    return text == newValue.text ? newValue : newValue.copyWith(text: text);
  }

  /// Whether [mark] in [text] is a thousands separator rather than a decimal
  /// point — a single occurrence with exactly three digits after it, and
  /// nothing else following.
  ///
  /// A US operator typing `1,500` watts means fifteen hundred. Rewriting that
  /// comma to a period makes it 1.5 — the same silent thousandfold error this
  /// formatter exists to prevent, in the opposite direction. Left alone, the
  /// mark stays foreign and `parseLocalizedNumber` strips it as the grouping
  /// it is.
  static bool _readsAsGrouping(String text, String mark) {
    final first = text.indexOf(mark);
    if (first < 0 || first != text.lastIndexOf(mark)) return false;
    return RegExp('${RegExp.escape(mark)}[0-9]{3}\$').hasMatch(text);
  }
}
