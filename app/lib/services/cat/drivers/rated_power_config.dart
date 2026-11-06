// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rated-output field for a radio whose program sets power as a share of
// full drive — Thetis's `ZZPC` and TCI's `DRIVE`, both 0–100. One entry
// serves every radio such a program runs, so the operator says what full
// drive puts out; the drivers turn watts into a share of it and back.

import 'package:halo_i18n/halo_i18n.dart';

/// The config key the CI-V and Kenwood entries pin per model; a field here.
const ratedWattsConfigKey = 'maxWatts';

/// What full drive is taken to put out when a node states nothing: the
/// 100 W of most of these radios. A wrong value lands the drive elsewhere on
/// the slider, never past it — the share is clamped to 100.
const assumedRatedWatts = 100;

/// The most the field accepts: the 200 W of the largest ANAN. Past that is
/// an amplifier's output, which a drive setting does not describe, and
/// entering it would shrink every share sent.
const _maxRatedWatts = 200;

Map<String, dynamic> ratedPowerConfigElement() => {
  'type': 'field',
  'fieldType': 'number',
  'key': ratedWattsConfigKey,
  'label': t.settings.station.ratedPower,
  'description': t.settings.station.ratedPowerDescription,
  'placeholder': '$assumedRatedWatts',
};

/// Blank, or a whole number of watts from 1 up.
String? validateRatedWatts(dynamic value) {
  if (value == null || (value is String && value.trim().isEmpty)) return null;
  final n = value is num ? value : num.tryParse('$value'.trim());
  return n != null && n >= 1 && n <= _maxRatedWatts && n == n.roundToDouble() ? null : t.settings.station.ratedPowerInvalid(max: _maxRatedWatts);
}

/// The node's rated output however stored JSON spells it — a number typed
/// into a field may come back a string. Zero, negatives and blanks fall
/// back: a drive is divided by this.
num ratedWattsFrom(Map<String, dynamic> config) {
  final raw = config[ratedWattsConfigKey];
  final value = raw is num ? raw : (raw is String ? num.tryParse(raw.trim()) : null);
  return value != null && value > 0 ? value : assumedRatedWatts;
}

/// [watts] as a 0–100 share of [ratedWatts], rounded and clamped.
int driveShareFor(num watts, {required num ratedWatts}) => (watts / ratedWatts * 100).round().clamp(0, 100);

/// A 0–100 [share] as watts of [ratedWatts], to a tenth of a watt.
num wattsForDriveShare(int share, {required num ratedWatts}) => (share * ratedWatts / 10).round() / 10;
