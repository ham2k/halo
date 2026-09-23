// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
//
// Elecraft K4 Programmer's Reference, rev. D12:
// https://ftp.elecraft.com/K4/Manuals%20Downloads/K4ProgrammersReferencerev.D12.html
// K40;K31; selects the documented K3-compatible IF with DATA submode.

import 'package:halo_core/halo_core.dart';

import 'kenwood_cat_codec.dart';

/// BN selects the radio's band, including the coupled receiver transition.
/// General coverage and configured transverter bands have no fixed mapping.
int? k4BandNumber(double freqKHz) => switch (bandForFrequency(freqKHz)) {
  '160m' => 0,
  '80m' => 1,
  '60m' => 2,
  '40m' => 3,
  '30m' => 4,
  '20m' => 5,
  '17m' => 6,
  '15m' => 7,
  '12m' => 8,
  '10m' => 9,
  '6m' => 10,
  _ => null,
};

/// The K31 status contains mode and DATA submode in the same snapshot.
/// Separate MD/DT replies can straddle a front-panel change and mislabel it.
final _info = RegExp(r'^(\d{11}) {5}[+-]\d{4}[01][01] 00([01])([1-79])0[01][01][01]([0-3])1 $');

({int freqHz, String mode, bool transmitting})? parseK4Info(String params) {
  final match = _info.firstMatch(params);
  if (match == null) return null;
  final mode = k4ModeForCodes(match[3]!, match[4]!);
  if (mode == null) return null;
  return (freqHz: int.parse(match[1]!), mode: mode, transmitting: match[2] == '1');
}

String? k4ModeForCodes(String mode, String data) {
  if (mode != '6' && mode != '9') return kenwoodModeForCode(mode);
  final reverse = mode == '9';
  return switch (data) {
    '0' => reverse ? 'DATA-LSB' : 'DATA-USB',
    '1' || '2' => reverse ? 'RTTY-R' : 'RTTY',
    // PSK31/63 share a submode; the DR command, not DT, selects their rate.
    '3' => 'PSK',
    _ => null,
  };
}

/// DATA means audio data, not FSK. RTTY deliberately selects FSK-D; AFSK-A
/// can still be selected on the radio and is correctly reported as RTTY.
/// FT8 and FT4 select DATA A: sending nothing for them would leave the mode
/// that a band change's `BN` recalls, and the app would then log that mode.
String? buildK4SetModeCommand(String mode) => switch (mode.toUpperCase()) {
  'DATA' || 'DATA-USB' || 'FT8' || 'FT4' => 'MD6;DT0;',
  'DATA-LSB' => 'MD9;DT0;',
  'RTTY' || 'RTTY-LSB' => 'MD6;DT2;',
  'RTTY-R' || 'RTTY-USB' => 'MD9;DT2;',
  'PSK' => 'MD6;DT3;',
  _ => buildKenwoodSetModeCommand(mode),
};

/// Only explicit ranges are accepted: PCX queries them even in legacy mode.
/// A bare legacy PC reply must never satisfy a pending range-aware write.
({num watts, bool transverter})? parseK4Power(String params) {
  final match = RegExp(r'^(\d{3})([LHX])$').firstMatch(params);
  if (match == null) return null;
  final level = int.parse(match[1]!);
  final range = match[2]!;
  if (level < 1 || level > (range == 'H' ? 110 : 100)) return null;
  return (
    watts: switch (range) {
      'L' => level / 10,
      'X' => level / 10000,
      _ => level,
    },
    transverter: range == 'X',
  );
}

/// Never promote a transverter's milliwatt output into a watt-range command.
/// The range must come from a fresh PCX response before each write.
String? buildK4SetPowerCommand(num watts, {required bool transverter}) {
  if (!watts.isFinite) return null;
  final min = transverter ? 0.0001 : 0.1;
  final max = transverter ? 0.01 : 110;
  if (watts < min || watts > max) return null;
  final range = transverter ? 'X' : (watts <= 10 ? 'L' : 'H');
  final level = (watts * (transverter ? 10000 : (range == 'L' ? 10 : 1))).round();
  return 'PC${level.toString().padLeft(3, '0')}$range;';
}

String buildK4SetKeyerSpeedCommand(int wpm) => 'KS${wpm.clamp(8, 100).toString().padLeft(3, '0')};';
