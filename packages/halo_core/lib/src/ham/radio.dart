// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Minimal ham radio domain utilities for the hot path (UI at 60fps, list
// rendering). Deliberately small: the full domain knowledge (callsign
// parsing, country files, contest rules) lives in the TypeScript plugin
// runtime per DESIGN.md §2 — only what the core UI needs per keystroke gets
// a Dart port. Frequencies are in kHz throughout, matching QSON.

import '../models/models.dart';

class BandInfo {
  final String name;
  final double minKHz;
  final double maxKHz;

  const BandInfo(this.name, this.minKHz, this.maxKHz);
}

/// Generous (region-agnostic) band edges; validation against a specific
/// band plan is plugin territory.
const List<BandInfo> bands = [
  BandInfo('2200m', 135.7, 137.8),
  BandInfo('630m', 472, 479),
  BandInfo('160m', 1800, 2000),
  BandInfo('80m', 3500, 4000),
  BandInfo('60m', 5250, 5450),
  BandInfo('40m', 7000, 7300),
  BandInfo('30m', 10100, 10150),
  BandInfo('20m', 14000, 14350),
  BandInfo('17m', 18068, 18168),
  BandInfo('15m', 21000, 21450),
  BandInfo('12m', 24890, 24990),
  BandInfo('10m', 28000, 29700),
  BandInfo('6m', 50000, 54000),
  BandInfo('4m', 70000, 70500),
  BandInfo('2m', 144000, 148000),
  BandInfo('1.25m', 219000, 225000),
  BandInfo('70cm', 420000, 450000),
  BandInfo('33cm', 902000, 928000),
  BandInfo('23cm', 1240000, 1300000),
];

String? bandForFrequency(double khz) {
  for (final band in bands) {
    if (khz >= band.minKHz && khz <= band.maxKHz) return band.name;
  }
  return null;
}

const List<String> modes = ['SSB', 'CW', 'FT8', 'FT4', 'FM', 'AM', 'RTTY', 'DATA'];

const Set<String> _phoneModes = {'SSB', 'FM', 'AM'};

String defaultRSTFor(String mode) => _phoneModes.contains(mode) ? '59' : '599';

/// Parses user frequency input into kHz.
/// Accepts kHz ("14285", "14285.5") and MHz with a decimal point when the
/// value is too small to be an HF kHz reading ("14.285" → 14285).
double? parseFreq(String input) {
  final cleaned = input.trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0) return null;
  if (cleaned.contains('.') && value < 1000) return value * 1000;
  return value;
}

/// Formats kHz for display: "14,285.5".
String fmtFreq(double khz) {
  // Round to one decimal FIRST, then split into whole/fraction — splitting
  // the unrounded value and rounding just the fraction (the previous
  // approach) drops the carry whenever the fraction is >= 0.95, e.g.
  // 14285.96 would format as "14,285.0" instead of "14,286".
  final rounded = (khz * 10).round() / 10;
  final wholePart = rounded.truncate();
  final fractionDigit = ((rounded - wholePart) * 10).round();

  final digits = wholePart.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  if (fractionDigit != 0) {
    return '$grouped.$fractionDigit';
  }
  return grouped.toString();
}

final RegExp _callsignRegex = RegExp(r'^([A-Z0-9]{1,4}/)?[A-Z0-9]{1,3}[0-9][A-Z0-9]*[A-Z](/[A-Z0-9]{1,4})?$');

/// Cheap plausibility check to enable the Log action — real callsign
/// parsing (prefixes, DXCC, modifiers) is plugin territory.
bool looksLikeCallsign(String text) => _callsignRegex.hasMatch(text.toUpperCase());

/// A radio's tuned state — `freq`/`mode`/`band` for one of an operation's
/// up to 4 VFOs (`vfoA`..`vfoD`, see `RadioService`). `band` is only set
/// when `freq` is null (a manually picked band with no specific
/// frequency) — mirrors the `_manualBand` precedence `LoggingControls`
/// already used before this state moved to the operation.
class Vfo {
  final double? freq;
  final String? band;
  final String? mode;

  const Vfo({this.freq, this.band, this.mode});

  factory Vfo.fromJson(Map<String, dynamic> json) => Vfo(
        freq: (json['freq'] as num?)?.toDouble(),
        band: json['band'] as String?,
        mode: json['mode'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (freq != null) 'freq': freq,
        if (band != null) 'band': band,
        if (mode != null) 'mode': mode,
      };
}

/// What `LoggingControls` (halo_widgets) needs for reading and writing an
/// operation's VFO state — implemented by the app's `RadioService`. Kept
/// here, in pure-Dart halo_core, so halo_widgets doesn't need a dependency
/// on the Flutter-only app package.
abstract class VfoStore {
  Vfo get vfoA;
  void loadForOperation(Operation operation);
  void setVfo(String key, {double? freq, String? band, String? mode});
}
