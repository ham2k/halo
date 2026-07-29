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
  // Named '2190m' (not the more common '2200m') to match the extension
  // runtime's own band table (@ham2k/lib-operation-data's bandForFrequency)
  // — spot/QSO band strings are compared for exact equality against this
  // list, so the two must agree.
  BandInfo('2190m', 135.7, 137.8),
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

// The full band/mode vocabularies, snapshotted from
// @ham2k/lib-operation-data v1.1.0 (EXTENDED_BANDS / POPULAR_BANDS /
// MAIN_MODES / ADIF_MODES_AND_SUBMODES) — regenerate from the lib when it
// changes. Band names must agree with [bands] above for the frequencies
// that table covers (the '2190m' note), and with the extension runtime,
// which uses the lib directly. These back the `$core.bands`/`$core.modes`
// system lists (app/lib/settings/system_lists.dart).

const List<String> extendedBands = [
  '2190m', '630m', '560m', '160m', '80m', '60m', '40m', '30m', '20m', '17m', '15m', '12m', '11m', '10m', '6m', '5m',
  '4m', '2m', '1.25m', '70cm', '33cm', '23cm', '13cm', '9cm', '6cm', '3cm', '1.25cm', '6mm', '4mm', '2.5mm', '2mm',
  '1mm', 'submm', 'other',
];

const List<String> popularBands = [
  '160m', '80m', '60m', '40m', '30m', '20m', '17m', '15m', '12m', '10m', '6m', '2m', '70cm',
];

const List<String> mainModes = [
  'CW', 'SSB', 'AM', 'FM', 'FT8', 'FT4', 'RTTY',
];

const List<String> popularModes = [
  'CW', 'SSB', 'USB', 'LSB', 'FM', 'AM', 'FT8', 'FT4', 'FT2', 'RTTY', 'DIGITALVOICE', 'C4FM', 'DMR', 'DSTAR',
  'FREEDV', 'M17', 'DYNAMIC', 'HELL', 'JT9', 'MFSK', 'MSK144', 'OLIVIA', 'PKT', 'PSK', 'SSTV', 'WSPR',
];

const List<String> adifModes = [
  '8PSK1000', '8PSK1000F', '8PSK1200F', '8PSK125', '8PSK125F', '8PSK125FL', '8PSK250', '8PSK250F', '8PSK250FL',
  '8PSK500', '8PSK500F', 'AM', 'AMTORFEC', 'ARDOP', 'ASCI', 'ATV', 'C4FM', 'CHIP', 'CHIP128', 'CHIP64', 'CLO',
  'CONTESTI', 'CW', 'DIGITALVOICE', 'DMR', 'DOM-M', 'DOM11', 'DOM16', 'DOM22', 'DOM4', 'DOM44', 'DOM5', 'DOM8',
  'DOM88', 'DOMINO', 'DOMINOEX', 'DOMINOF', 'DSTAR', 'DYNAMIC', 'FAX', 'FM', 'FMHELL', 'FREEDATA', 'FREEDV', 'FSK',
  'FSK31', 'FSK441', 'FSKH105', 'FSKH245', 'FSKHELL', 'FSQCALL', 'FST4', 'FST4W', 'FT2', 'FT4', 'FT8', 'GTOR', 'HELL',
  'HELL80', 'HELLX5', 'HELLX9', 'HFSK', 'ISCAT', 'ISCAT-A', 'ISCAT-B', 'JS8', 'JT4', 'JT44', 'JT4A', 'JT4B', 'JT4C',
  'JT4D', 'JT4E', 'JT4F', 'JT4G', 'JT65', 'JT65A', 'JT65B', 'JT65B2', 'JT65C', 'JT65C2', 'JT6M', 'JT9', 'JT9-1',
  'JT9-10', 'JT9-2', 'JT9-30', 'JT9-5', 'JT9A', 'JT9B', 'JT9C', 'JT9D', 'JT9E', 'JT9E FAST', 'JT9F', 'JT9F FAST',
  'JT9G', 'JT9G FAST', 'JT9H', 'JT9H FAST', 'JTMS', 'LSB', 'M17', 'MFSK', 'MFSK11', 'MFSK128 MFSK128L', 'MFSK16',
  'MFSK22', 'MFSK31', 'MFSK32', 'MFSK4', 'MFSK64', 'MFSK64L', 'MFSK8', 'MSK144', 'MT63', 'MTONE', 'NAVTEX', 'ODFM',
  'OLIVIA', 'OLIVIA 16/1000', 'OLIVIA 16/500', 'OLIVIA 32/1000', 'OLIVIA 4/125', 'OLIVIA 4/250', 'OLIVIA 8/250',
  'OLIVIA 8/500', 'OPERA', 'OPERA-BEACON', 'OPERA-QSO', 'PAC', 'PAC2', 'PAC3', 'PAC4', 'PAX', 'PAX2', 'PCW', 'PKT',
  'PSK', 'PSK10', 'PSK1000', 'PSK1000C2', 'PSK1000R', 'PSK1000RC2', 'PSK125', 'PSK125C12', 'PSK125R', 'PSK125RC10',
  'PSK125RC12', 'PSK125RC16', 'PSK125RC4', 'PSK125RC5', 'PSK250', 'PSK250C6', 'PSK250R', 'PSK250RC2', 'PSK250RC3',
  'PSK250RC5', 'PSK250RC6', 'PSK250RC7', 'PSK2K', 'PSK31', 'PSK500', 'PSK500C2', 'PSK500C4', 'PSK500R', 'PSK500RC2',
  'PSK500RC3', 'PSK500RC4', 'PSK63', 'PSK63F', 'PSK63RC10', 'PSK63RC20', 'PSK63RC32', 'PSK63RC4', 'PSK63RC5',
  'PSK800C2', 'PSK800RC2', 'PSKAM10', 'PSKAM31', 'PSKAM50', 'PSKFEC31', 'PSKHELL', 'Q15', 'Q65', 'QPSK125', 'QPSK250',
  'QPSK31', 'QPSK500', 'QPSK63', 'QRA64', 'QRA64A', 'QRA64B', 'QRA64C', 'QRA64D', 'QRA64E', 'RIBBIT_PIX',
  'RIBBIT_SMS', 'ROS', 'ROS-EME', 'ROS-HF', 'ROS-MF', 'RTTY', 'RTTYM', 'SCAMP_FAST', 'SCAMP_OO', 'SCAMP_OO_SLW',
  'SCAMP_SLOW', 'SCAMP_VSLOW', 'SIM31', 'SITORB', 'SLOWHELL', 'SSB', 'SSTV', 'T10', 'THOR', 'THOR-M', 'THOR100',
  'THOR11', 'THOR16', 'THOR22', 'THOR25X4', 'THOR4', 'THOR5', 'THOR50X1', 'THOR50X2', 'THOR8', 'THRB', 'THRBX',
  'THRBX1', 'THRBX2', 'THRBX4', 'THROB1', 'THROB2', 'THROB4', 'TOR', 'USB', 'V4', 'VARA FM 1200', 'VARA FM 9600',
  'VARA HF', 'VARA SATELLITE', 'VOI', 'WINMOR', 'WSPR',
];

const Set<String> _phoneModes = {'SSB', 'FM', 'AM'};

String defaultRSTFor(String mode) => _phoneModes.contains(mode) ? '59' : '599';

/// Voice modes for [superModeForMode] — mirrors @ham2k/lib-operation-data's
/// PHONE_MODES. Broader than [_phoneModes] (which is only the RST-default set),
/// since super-mode grouping also treats the digital-voice modes as phone.
const Set<String> _superPhoneModes = {
  'SSB', 'USB', 'LSB', 'FM', 'AM', 'DIGITALVOICE', 'C4FM', 'DMR', 'DSTAR', 'FREEDV', 'M17',
};

/// The "super mode" of [mode] — `'Phone'`, `'CW'`, or `'Digital'` — mirroring
/// @ham2k/lib-operation-data's `superModeForMode` (which groups modes into
/// CW / PHONE / DATA), or null for a null mode. Classifies main modes without
/// that lib's ADIF submode resolution: anything that isn't CW or a phone mode
/// is Digital.
String? superModeForMode(String? mode) {
  if (mode == null) return null;
  final m = mode.toUpperCase();
  if (m == 'CW') return 'CW';
  if (_superPhoneModes.contains(m)) return 'Phone';
  return 'Digital';
}

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

  /// Value equality so a store can tell a real change from a restatement.
  /// A CAT-connected radio re-reports its state constantly — every status
  /// push, every periodic resync — and without this each one looks like a
  /// change worth notifying every listener and rewriting the prefs for.
  @override
  bool operator ==(Object other) =>
      other is Vfo && other.freq == freq && other.band == band && other.mode == mode;

  @override
  int get hashCode => Object.hash(freq, band, mode);

  @override
  String toString() => 'Vfo(freq: $freq, band: $band, mode: $mode)';
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
