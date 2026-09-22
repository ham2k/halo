// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:ui' as ui;

import 'package:halo_core/halo_core.dart';
import 'package:intl/intl.dart';

import 'package:halo_i18n/halo_i18n.dart';

/// "3.3 km" / "1,042 mi", with separators from the device's system locale
/// (independent of the app's own Language setting — see [fmtDistance]'s
/// sibling `formatNumber` in halo_widgets). Shared by the Map tab
/// (`map_panel.dart`) and the logging panel's call-info line — the unit label
/// comes from i18n, so this lives in the app layer, not halo_core.
String fmtDistance(double km, {required bool miles}) {
  final value = miles ? km / kmPerMile : km;
  final formatted = NumberFormat(value <= 5 ? '#,##0.0' : '#,##0', ui.PlatformDispatcher.instance.locale.toString()).format(value);
  return miles ? t.map.distanceMiles(distance: formatted) : t.map.distanceKm(distance: formatted);
}

/// DXCC entities big enough that their centroid is a poor position estimate —
/// a distance for these is shown only once a state is known (see the call-info
/// panels): US, Canada, Australia, Russia (all three), China, India, Mexico,
/// Brazil.
const kLargeEntities = {'K', 'VE', 'VK', 'UA', 'UA2', 'UA9', 'BY', 'VU', 'XE', 'PY'};

/// Rounds an approximate (centroid-based) distance for display — to the nearest
/// 50 under 250, 100 under 2500, else 1000, in the display unit — and returns
/// the km equivalent for [fmtDistance]. Shared by the compact call-info line
/// and the call-info detail panel.
double approxRoundedKm(double km, {required bool miles}) {
  final value = miles ? km / kmPerMile : km;
  final double bucket = value < 250 ? 50 : (value < 2500 ? 100 : 1000);
  final rounded = (value / bucket).round() * bucket;
  final display = rounded < bucket ? bucket : rounded.toDouble(); // avoid "~0"
  return miles ? display * kmPerMile : display;
}
