// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:intl/intl.dart';

/// Formats a number with thousands separators according to the active locale.
String formatNumber(num value) {
  return NumberFormat.decimalPattern().format(value);
}
