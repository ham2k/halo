// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'radio.dart';

/// Where each mode starts on the HF bands a US General licence is held back
/// on. The band plan's US segments are the Extra class's, and an operator
/// landed there by default would be transmitting outside their privileges —
/// General is the licence a US callsign most likely holds.
const _usGeneralStarts = <String, ({double cw, double phone})>{
  '80m': (cw: 3525, phone: 3800),
  '40m': (cw: 7025, phone: 7175),
  '20m': (cw: 14025, phone: 14225),
  '17m': (cw: 18068, phone: 18110),
  '15m': (cw: 21025, phone: 21275),
};

/// The places a US licence is held in under FCC rules, apart from `us` itself
/// (Alaska, Hawaii and most of the islands): Puerto Rico, the US Virgin
/// Islands, Guam, American Samoa, the Northern Marianas and the minor
/// outlying islands. Their band plan is the US one.
const _usTerritories = {'pr', 'vi', 'gu', 'as', 'mp', 'um'};

/// Where people listen on 60 m and from 6 m up, by band and then by IARU
/// region (`0` for every region a band names no entry of its own for): its
/// channels or calling frequencies, used as they are, because there the start
/// of a segment is where nobody is. `narrow` is for sideband, and for CW too
/// unless `cw` names its own.
const _callingByRegion = <String, Map<int, ({double narrow, double? cw})>>{
  // The US and Canadian channels, then the WRC-15 allocation most of Regions
  // 1 and 3 have instead, which those channels lie outside.
  '60m': {0: (narrow: 5330.5, cw: 5332), 1: (narrow: 5354, cw: 5351.6), 3: (narrow: 5354, cw: 5351.6)},
  '11m': {0: (narrow: 26965, cw: null)},
  '6m': {0: (narrow: 50125, cw: 50090), 1: (narrow: 50150, cw: 50090)},
  '4m': {0: (narrow: 70200, cw: null)},
  '2m': {0: (narrow: 144200, cw: 144050), 1: (narrow: 144300, cw: 144050)},
  '1.25m': {0: (narrow: 222100, cw: null)},
  '70cm': {0: (narrow: 432100, cw: null), 1: (narrow: 432200, cw: null)},
  '33cm': {0: (narrow: 903100, cw: null)},
  '23cm': {0: (narrow: 1296100, cw: null), 1: (narrow: 1296200, cw: null)},
  '13cm': {0: (narrow: 2304100, cw: null), 1: (narrow: 2320200, cw: null)},
  '9cm': {0: (narrow: 3400100, cw: null)},
  '6cm': {0: (narrow: 5760100, cw: null)},
  '3cm': {0: (narrow: 10368100, cw: null)},
  '1.25cm': {0: (narrow: 24192100, cw: null), 1: (narrow: 24048200, cw: null)},
  '6mm': {0: (narrow: 47088100, cw: null)},
};

/// The FM simplex calling frequency, by band and then by IARU region as
/// [_callingByRegion] is. The band plan's FM segments start where nobody
/// listens (70 cm's at 420 MHz), and Region 2's calling frequencies are out
/// of band in Region 1.
const _fmCallingByRegion = <String, Map<int, double>>{
  '11m': {0: 26965},
  '10m': {0: 29600},
  '6m': {0: 52525, 1: 51510},
  '4m': {0: 70450},
  // Region 3's 2 m ends at 146 MHz in Japan, India and much of Asia.
  '2m': {0: 146520, 1: 145500, 3: 145000},
  '1.25m': {0: 223500},
  '70cm': {0: 446000, 1: 433500, 3: 433500},
  '23cm': {0: 1294500, 1: 1297500},
};

/// The family a band's memory and defaults are kept by: `CW`, `RTTY`, `DATA`
/// (every other digital mode, and the radio's data sidebands), `FM`, or
/// `PHONE` (any sideband, AM, or no mode at all).
String bandModeFamily(String? mode) {
  final upper = mode?.toUpperCase();
  if (upper == 'CW' || upper == 'CW-R') return 'CW';
  // The radios' own spellings too: a Yaesu reports RTTY-LSB and FM-N, an
  // Icom RTTY-R, and the app's mode keeps what the radio said.
  if (upper == 'FM' || upper == 'FM-N' || upper == 'NFM') return 'FM';
  if (upper != null && (upper.startsWith('RTTY') || upper == 'FSK')) return 'RTTY';
  if (upper != null && (upper.startsWith('DATA') || radioModeForAppMode(upper, null) == 'DATA-USB')) return 'DATA';
  return 'PHONE';
}

/// A frequency in kHz to put a radio on when [band] is picked under [mode]
/// and nothing better is known, or null for a band not in [bands].
///
/// For the operator's IARU region ([ituRegion]; [countryCode] as
/// [modeForFrequency] takes it), and in the US and its territories for a
/// General licence:
///
/// - A digital mode goes to its dial frequency (FT4 to FT4's, everything else
///   to FT8's), and RTTY to the start of its segment, or FT8's where the band
///   plan has none: anywhere else on the band nobody is watching. FM goes to
///   the calling frequency.
/// - 60 m, and every band from 6 m up, goes to where people listen
///   ([_callingByRegion]).
/// - Otherwise the start of the mode's segment. CW starts 100 Hz in, so the
///   signal does not straddle the segment's edge; phone on a lower-sideband
///   band starts 3 kHz in, so the sideband below the carrier is inside the
///   segment too. A band with no phone segment starts phone at CW's start,
///   and one with no segment for either at its own lower edge — 3 kHz in
///   on a lower-sideband band, where the band is that wide.
double? defaultFrequencyForBand(String band, String? mode, {int? ituRegion, String? countryCode}) {
  final info = bands.where((b) => b.name == band).firstOrNull;
  if (info == null) return null;
  if (_usTerritories.contains(countryCode)) countryCode = 'us';
  final family = bandModeFamily(mode);
  final placed = switch (family) {
    'DATA' => _dialFrequency(band, mode?.toUpperCase() == 'FT4' ? 'FT4' : 'FT8'),
    'RTTY' => _rttyStart(band, ituRegion, countryCode) ?? _dialFrequency(band, 'FT8'),
    'FM' => _forRegion(_fmCallingByRegion[band], ituRegion),
    _ => null,
  };
  if (placed != null) return placed;

  if (_forRegion(_callingByRegion[band], ituRegion) case final calling?) {
    return family == 'CW' ? calling.cw ?? calling.narrow : calling.narrow;
  }

  final usGeneral = countryCode == 'us' ? _usGeneralStarts[band] : null;
  final cwStart = usGeneral?.cw ?? _segmentStart(band, 'CW', ituRegion, countryCode);
  if (family == 'CW') return _toHz((cwStart ?? info.minKHz) + 0.1);
  final phoneStart = usGeneral?.phone ?? _segmentStart(band, 'SSB', ituRegion, countryCode);
  final start = phoneStart ?? cwStart ?? info.minKHz;
  return _lsbBands.contains(band) && start + 3 <= info.maxKHz ? start + 3 : start;
}

/// The start of [band]'s RTTY segment, unless that is outside the operator's
/// allocation: 160 m's is worldwide in the band plan, and 1800 is out of band
/// in Region 1. Tested 1 kHz in, because a frequency on a segment's edge
/// belongs to both sides.
double? _rttyStart(String band, int? ituRegion, String? countryCode) {
  final start = _segmentStart(band, 'RTTY', ituRegion, countryCode);
  if (start == null || isOutOfBandFrequency(start + 1, ituRegion: ituRegion, countryCode: countryCode)) return null;
  return start;
}

T? _forRegion<T>(Map<int, T>? byRegion, int? ituRegion) => byRegion == null ? null : byRegion[ituRegion] ?? byRegion[0];

/// [khz] to the nearest Hz: 135.7 + 0.1 is not 135.8 in floating point.
double _toHz(double khz) => (khz * 1000).round() / 1000;

/// The low edge of the [mode] segment on [band] that best fits the operator —
/// scoped as [modeForFrequency] scopes, and the lowest of equally fitting ones.
double? _segmentStart(String band, String mode, int? ituRegion, String? countryCode) {
  final country = ituRegion == null ? null : countryCode;
  _BandPlanSegment? best;
  for (final segment in bandPlanModeSegments) {
    if (segment.mode != mode || bandForFrequency(segment.loKHz) != band) continue;
    if (_isScopedElsewhere(segment, ituRegion, country)) continue;
    if (best == null) {
      best = segment;
      continue;
    }
    final rank = _scopeRank(segment, ituRegion: ituRegion, countryCode: country);
    final bestRank = _scopeRank(best, ituRegion: ituRegion, countryCode: country);
    if (rank > bestRank || (rank == bestRank && segment.loKHz < best.loKHz)) best = segment;
  }
  return best?.loKHz;
}

/// The low edge of [band]'s worldwide [mode] carve-out — the dial frequency,
/// for FT8 and FT4.
double? _dialFrequency(String band, String mode) {
  for (final segment in bandPlanModeSegments) {
    if (segment.mode != mode || _isScoped(segment)) continue;
    if (bandForFrequency(segment.loKHz) == band) return segment.loKHz;
  }
  return null;
}
