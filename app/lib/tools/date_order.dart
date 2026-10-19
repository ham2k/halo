// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The order a locale writes a numeric date in, for the extensions that parse
// one an operator typed (`HookContext.dateOrder`).

import 'dart:ui' as dart_ui;

import 'package:intl/date_time_patterns.dart';

/// `'mdy'`, `'dmy'` or `'ymd'` for [localeTag] (`en_US`; the device's when
/// null), read from its short numeric date pattern. A locale intl has no
/// pattern for falls back to its language's, and then to `'mdy'` — except
/// English, whose base pattern is the US one: intl has only a handful of
/// `en_*` regions, and English with any other region (`en_NL`, `en_DE`)
/// writes the day first, as CLDR's `en_001` does.
///
/// `'ymd'` promises the month before the day; a year-first pattern with the
/// day before the month (Kyrgyz `y-dd-MM`) is `'dmy'`, which is all a
/// two-part date needs.
///
/// The pattern map rather than `DateFormat`: that needs the locale's date
/// symbols initialized first, and throws for one that never was.
String dateOrderFor([String? localeTag]) {
  final tag = localeTag ?? dart_ui.PlatformDispatcher.instance.locale.toString();
  final patterns = dateTimePatternMap();
  final [language, ...rest] = tag.split(RegExp('[_-]'));
  final region = rest.where((part) => part.length == 2 || int.tryParse(part) != null).firstOrNull;
  if (patterns[tag] == null && language == 'en' && region != null) return _usStyleRegions.contains(region) ? 'mdy' : 'dmy';
  final pattern = (patterns[tag] ?? patterns[language])?['yMd'];
  if (pattern == null) return 'mdy';
  final year = pattern.indexOf('y');
  final month = pattern.indexOf('M');
  final day = pattern.indexOf('d');
  if (month < 0 || day < 0) return 'mdy';
  if (day < month) return 'dmy';
  return year >= 0 && year < month ? 'ymd' : 'mdy';
}

/// The regions whose English writes the month first: the US and the
/// territories that follow it, which CLDR gives the plain `en` pattern.
const _usStyleRegions = {'US', 'AS', 'GU', 'MP', 'PR', 'UM', 'VI', 'PH'};
