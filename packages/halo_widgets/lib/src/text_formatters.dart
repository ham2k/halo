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
