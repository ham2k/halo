// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Minimal ham radio domain utilities for the hot path (UI at 60fps, list
// rendering). Deliberately small: the full domain knowledge (callsign
// parsing, country files, contest rules) lives in the TypeScript plugin
// runtime per DESIGN.md §2 — only what the core UI needs per keystroke gets
// a Dart port. Frequencies are in kHz throughout, matching QSON.

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

/// MHz/kHz/Hz split for QSO-row display (issue ham2k/app-halo-dist#2): MHz
/// bold, kHz regular, Hz (if any) regular at a smaller size, dot-separated.
/// [hz] is null when the operation has no QSO needing sub-kHz precision —
/// see [hzDigitsNeeded].
class FreqParts {
  final String mhz;
  final String khz;
  final String? hz;

  const FreqParts({required this.mhz, required this.khz, this.hz});
}

/// Rounds a kHz value to the nearest Hz as a single integer, then splits by
/// integer division/modulo — the shared source of truth for [freqDisplayParts]
/// and [hzDigitsNeeded]. Flooring/subtracting the kHz-as-double pieces
/// separately (the previous approach) can round a remainder up to exactly
/// 1000 Hz on IEEE-754 boundary values (e.g. 8.158 MHz parses to the double
/// 8157.999999999999 kHz) and then clamp it back down to 999 instead of
/// carrying into kHz/MHz — rounding to a single integer up front sidesteps
/// that: 8157.999999999999 * 1000 rounds to exactly 8158000 Hz.
int _totalHzFor(double khz) => (khz * 1000).round();

/// Splits a frequency in kHz into MHz/kHz/Hz display parts. [hzDigits] —
/// normally the operation-wide value from [hzDigitsNeeded] — is how many Hz
/// digits to show; 0 omits the Hz segment entirely.
FreqParts freqDisplayParts(double khz, {required int hzDigits}) {
  final totalHz = _totalHzFor(khz);
  final mhzWhole = totalHz ~/ 1000000;
  final khzWhole = (totalHz ~/ 1000) % 1000;
  final hzValue = totalHz % 1000;
  final hzString = hzValue.toString().padLeft(3, '0');

  return FreqParts(
    mhz: mhzWhole.toString(),
    khz: khzWhole.toString().padLeft(3, '0'),
    hz: hzDigits > 0 ? hzString.substring(0, hzDigits) : null,
  );
}

/// How many Hz digits are needed to represent every QSO's frequency in the
/// operation without losing precision, e.g. a lone frequency ending in
/// "...074.5" kHz (500 Hz) needs 1 digit, "...074.05" (50 Hz) needs 2. 0
/// means every QSO lands on an exact kHz, so no row needs an Hz segment.
int hzDigitsNeeded(Iterable<double?> freqsInKHz) {
  var maxDigits = 0;
  for (final khz in freqsInKHz) {
    if (khz == null) continue;
    final hzValue = _totalHzFor(khz) % 1000;
    if (hzValue == 0) continue;
    final hzString = hzValue.toString().padLeft(3, '0');
    var digits = 3;
    while (digits > 0 && hzString[digits - 1] == '0') {
      digits--;
    }
    if (digits > maxDigits) maxDigits = digits;
  }
  return maxDigits;
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

/// Formats kHz for an editable frequency field, at full stored precision
/// (down to 1 Hz — three decimals in kHz) and without thousands grouping,
/// so a value round-trips through [parseFreq] unchanged. Unlike [fmtFreq]
/// (a display formatter that rounds to 100 Hz), this never degrades a
/// QSO's frequency just by selecting it for editing: 14074.25 stays
/// "14074.25", not "14074.3". Trailing zeros are trimmed, so whole
/// frequencies show plainly ("7025", not "7025.000").
String fmtFreqInput(double khz) {
  var s = khz.toStringAsFixed(3);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

final RegExp _callsignRegex = RegExp(r'^([A-Z0-9]{1,4}/)?[A-Z0-9]{1,3}[0-9][A-Z0-9]*[A-Z](/[A-Z0-9]{1,4})?$');

/// Cheap plausibility check to enable the Log action — real callsign
/// parsing (prefixes, DXCC, modifiers) is plugin territory.
bool looksLikeCallsign(String text) => _callsignRegex.hasMatch(text.toUpperCase());

/// A radio's tuned state — `freq`/`mode`/`band` for one of up to 4 VFOs
/// (`vfoA`..`vfoD`, see `RadioService`). Device-global, not tied to any
/// one operation: a physical radio is tuned to one frequency regardless of
/// which operation you're logging into. `band` is only set when `freq` is
/// null (a manually picked band with no specific frequency) — mirrors the
/// `_manualBand` precedence `LoggingControls` already used before this
/// state existed.
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

/// What `LoggingControls` (halo_widgets) needs for reading and writing the
/// device's (not any one operation's) VFO state — implemented by the app's
/// `RadioService`. Kept here, in pure-Dart halo_core, so halo_widgets
/// doesn't need a dependency on the Flutter-only app package.
abstract class VfoStore {
  Vfo get vfoA;
  /// `freq`/`band`/`mode` omitted leave that part unchanged. `clearFreq`
  /// explicitly clears the frequency (keeping the current band, or `band`
  /// if also given) — distinct from simply omitting `freq`, which is a
  /// no-op for it rather than a clear.
  void setVfo(String key, {double? freq, String? band, String? mode, bool clearFreq = false});
}
