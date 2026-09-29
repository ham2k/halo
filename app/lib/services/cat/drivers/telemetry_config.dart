// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one field every meter-reading driver collects identically: how often
// to read the radio's meters while it is transmitting. Shared here so the
// wording, the validation and the "blank means work it out" rule are the
// same on every radio in the catalogue.

import 'package:halo_i18n/halo_i18n.dart';
import '../telemetry_poller.dart';

/// The slowest cadence worth offering. Past this the strip is a slideshow
/// and an operator would be better served turning the pane off; the number
/// is a sanity bound on a typo, not a considered maximum.
const _maxTelemetryIntervalMillis = 10000;

/// The meter cadence field.
///
/// Left BLANK by default rather than prefilled with 200, and that is the
/// whole point of the field's shape: the usable floor depends on the link's
/// speed, which the operator has already told us in the baud field beside
/// it. A prefilled 200 on a 4800-baud radio would be a number the app
/// silently disregards, and an operator who set it would have every right to
/// believe it took.
Map<String, dynamic> telemetryConfigElement() => {
  'type': 'field',
  'fieldType': 'number',
  'key': telemetryIntervalConfigKey,
  'label': t.settings.station.telemetryInterval,
  'description': t.settings.station.telemetryIntervalDescription,
  'advanced': true,
};

/// Blank, or a whole number of milliseconds within the offered range.
///
/// Deliberately does NOT refuse a value below what the link can carry: the
/// floor moves with the baud field, which a hidden-but-still-validated
/// FormRenderer field may hold a value for on a pairing that has no serial
/// port at all (see docs/design/cat.md § Layering). Refusing here would
/// reject a perfectly good network radio over a baud rate belonging to the
/// transport beside it — so the clamp lives at [telemetryIntervalFor], where
/// the pairing is known.
String? validateTelemetryInterval(dynamic value) {
  if (value == null || (value is String && value.trim().isEmpty)) return null;
  final n = value is num ? value : num.tryParse('$value');
  return (n != null && n >= kTelemetryFloorFast.inMilliseconds && n <= _maxTelemetryIntervalMillis && n == n.roundToDouble())
      ? null
      : t.settings.station.telemetryIntervalInvalid(min: kTelemetryFloorFast.inMilliseconds, max: _maxTelemetryIntervalMillis);
}
