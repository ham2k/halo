// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one field every polling driver collects identically: how often to ask
// a radio that is sitting still for its frequency and mode. Shared here so the
// wording, the bounds and the "blank means the driver's own" rule are the same
// on every radio in the catalogue.

import 'package:halo_i18n/halo_i18n.dart';

import '../adaptive_poller.dart';

/// The config key holding a node's idle poll interval, in milliseconds.
const pollIntervalConfigKey = 'pollInterval';

/// Below this an idle radio is polled about as often as a moving one
/// ([kPollFast]), and the setting would stop meaning "idle".
const _minPollIntervalMillis = 500;

/// The slowest idle poll offered. For most polling drivers the poll is the
/// only thing that proves the radio is still there, and a node silent for
/// `catStaleAfter` (30 s) is shown as not responding — so this stays at a
/// third of that, leaving room for a lost answer or two.
const maxIdlePollInterval = Duration(seconds: 10);

final _maxPollIntervalMillis = maxIdlePollInterval.inMilliseconds;

/// The idle poll field, blank by default. [fallback] is what blank means for
/// this driver, shown in the description so the operator knows the number
/// they would be changing.
Map<String, dynamic> pollConfigElement({Duration fallback = kPollSlow}) => {
  'type': 'field',
  'fieldType': 'number',
  'key': pollIntervalConfigKey,
  'label': t.settings.station.pollInterval,
  'description': t.settings.station.pollIntervalDescription(fallback: fallback.inMilliseconds),
  'placeholder': '${fallback.inMilliseconds}',
  'advanced': true,
};

/// Blank, or a whole number of milliseconds within the offered range.
String? validatePollInterval(dynamic value) {
  if (value == null || (value is String && value.trim().isEmpty)) return null;
  final n = value is num ? value : num.tryParse('$value');
  return (n != null && n >= _minPollIntervalMillis && n <= _maxPollIntervalMillis && n == n.roundToDouble())
      ? null
      : t.settings.station.pollIntervalInvalid(min: _minPollIntervalMillis, max: _maxPollIntervalMillis);
}

/// The idle poll interval [config] asks for, or [fallback] when it asks for
/// none or for something out of range. A node whose stored value is out of
/// range never gets this far through [CatService] — its connect-time
/// validation refuses it with the editor's own message — so the fallback is
/// for a session built without that check, which must still not poll a radio
/// every millisecond.
Duration idlePollIntervalFor(Map<String, dynamic> config, {Duration fallback = kPollSlow}) {
  final raw = config[pollIntervalConfigKey];
  final n = raw is num ? raw : num.tryParse('${raw ?? ''}'.trim());
  if (n == null || !n.isFinite || n < _minPollIntervalMillis || n > _maxPollIntervalMillis) return fallback;
  return Duration(milliseconds: n.round());
}
