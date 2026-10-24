// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:intl/intl.dart';

/// Formats a number with thousands separators, in the device's own
/// conventions ([NumberFormatting]). Not for frequencies — see `fmtFreq`.
///
/// The DEVICE locale, independent of the app's own Language setting, which
/// translates the UI and shouldn't force that language's number conventions
/// onto every device. Routing through [NumberFormatting] is what keeps this
/// agreeing with every editable number field.
String formatNumber(num value, {String? locale}) {
  return NumberFormat.decimalPattern(locale ?? NumberFormatting.instance.formattingLocale).format(value);
}
