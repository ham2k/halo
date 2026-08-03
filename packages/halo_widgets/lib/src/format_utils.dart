// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:ui' as ui;

import 'package:intl/intl.dart';

/// Formats a number with thousands separators according to the device's
/// system locale — independent of the app's own Language setting, which only
/// translates the UI into English or Spanish and shouldn't force those
/// locales' number conventions onto every other device locale.
String formatNumber(num value, {String? locale}) {
  return NumberFormat.decimalPattern(locale ?? ui.PlatformDispatcher.instance.locale.toString()).format(value);
}
