// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';

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
