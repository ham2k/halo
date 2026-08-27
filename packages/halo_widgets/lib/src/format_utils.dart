// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:intl/intl.dart';

/// Formats a number with thousands separators, in whatever conventions the
/// operator's Number Formatting setting resolved to ([NumberFormatting]).
///
/// That default is still the DEVICE locale — independent of the app's own
/// Language setting, which only translates the UI into English or Spanish and
/// shouldn't force those locales' number conventions onto every other device
/// locale. The setting exists for the operator whose device gets it wrong,
/// and routing through it here is what keeps this agreeing with `fmtFreq` and
/// with every editable number field.
String formatNumber(num value, {String? locale}) {
  return NumberFormat.decimalPattern(locale ?? NumberFormatting.instance.formattingLocale).format(value);
}
