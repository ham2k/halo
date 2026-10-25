// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Minimal ham radio domain utilities for the hot path (UI at 60fps, list
// rendering). Deliberately small: the full domain knowledge (callsign
// parsing, country files, contest rules) lives in the TypeScript plugin
// runtime per DESIGN.md §2 — only what the core UI needs per keystroke gets
// a Dart port. Frequencies are in kHz throughout, matching QSON.

import 'dart:async';

import 'band_plan_segments.dart';

part 'band_defaults.dart';

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
  BandInfo('560m', 500, 505),
  BandInfo('160m', 1800, 2000),
  BandInfo('80m', 3500, 4000),
  BandInfo('60m', 5250, 5450),
  BandInfo('40m', 7000, 7300),
  BandInfo('30m', 10100, 10150),
  BandInfo('20m', 14000, 14350),
  BandInfo('17m', 18068, 18168),
  BandInfo('15m', 21000, 21450),
  BandInfo('12m', 24890, 24990),
  BandInfo('11m', 26965, 27405),
  BandInfo('10m', 28000, 29700),
  BandInfo('6m', 50000, 54000),
  BandInfo('5m', 54001, 69999),
  BandInfo('4m', 70000, 70500),
  BandInfo('2m', 144000, 148000),
  BandInfo('1.25m', 219000, 225000),
  BandInfo('70cm', 420000, 450000),
  BandInfo('33cm', 902000, 928000),
  BandInfo('23cm', 1240000, 1300000),
  // Past 23cm, the extension runtime's own edges.
  BandInfo('13cm', 2300000, 2450000),
  BandInfo('9cm', 3300000, 3500000),
  BandInfo('6cm', 5650000, 5925000),
  BandInfo('3cm', 10000000, 10500000),
  BandInfo('1.25cm', 24000000, 24250000),
  BandInfo('6mm', 47000000, 47200000),
  BandInfo('4mm', 75500000, 81000000),
  BandInfo('2.5mm', 122250000, 123000000),
  BandInfo('2mm', 134000000, 141000000),
  BandInfo('1mm', 241000000, 250000000),
  BandInfo('submm', 300000000, 7500000000),
];

String? bandForFrequency(double khz) {
  for (final band in bands) {
    if (khz >= band.minKHz && khz <= band.maxKHz) return band.name;
  }
  return null;
}

/// Bands whose voice sits on the lower sideband, for when a contact records a
/// band and no frequency. Every other band name is upper.
///
/// Both spellings of the two bands that have two: the band table names
/// `2190m`, and `75m` is what many loggers call the phone half of 80 m — a
/// contact carrying either arrives from an import or a spot feed, and getting
/// it wrong puts the wrong sideband on the air.
const _lsbBands = {'2190m', '2200m', '630m', '560m', '160m', '80m', '75m', '40m'};

/// Below this, voice is lower sideband; at or above it, upper.
///
/// Not a band edge — a plain split through the HF spectrum, which is all the
/// convention has ever been. Every amateur band lands on the correct side of
/// it, so nothing has to agree with a band table for this to be right, and a
/// frequency in a gap between bands still gets a usable answer instead of a
/// shrug.
const _upperSidebandFloorKHz = 9000.0;

/// The one stretch below [_upperSidebandFloorKHz] that runs upper: 60 m is
/// channelized USB by international agreement. Written as a round span rather
/// than the band's own edges so a frequency near it, or a 60 m allocation this
/// table does not carry, still answers upper.
const _sixtyMetreLoKHz = 5000.0;
const _sixtyMetreHiKHz = 6000.0;

/// Whether [mode] is voice SSB — the generic mode or either sideband.
///
/// What it is for: a sideband already resolved is still a DERIVED value, and
/// moving band has to re-derive it (`RadioService.setVfo`). Which sideband a
/// band runs is a property of where you are, not a preference to carry across
/// a move.
bool isSidebandMode(String? mode) => mode != null && const {'SSB', 'USB', 'LSB'}.contains(mode.toUpperCase());

/// The sideband voice conventionally runs on, from [freqKHz] if there is one
/// and from [band] otherwise, or **null** only when there is neither.
///
/// A frequency answers on its own — see [_upperSidebandFloorKHz] — so it needs
/// no band table and no allocation to fall inside; a frequency between bands,
/// or on one nothing here names, still gets the answer an operator would give.
/// A band name answers from [_lsbBands], and anything not in it is upper.
///
/// The null is load-bearing, and it now means exactly one thing: nothing was
/// stated at all. [resolveSideband] must answer with a sideband whatever it is
/// handed, so it falls back to upper; a caller that must not guess — the
/// display deciding whether to accuse a sideband, a writer deciding whether to
/// rewrite a stored one — checks here first.
String? expectedSideband({double? freqKHz, String? band}) {
  if (freqKHz != null) {
    if (freqKHz >= _upperSidebandFloorKHz) return 'USB';
    return (freqKHz >= _sixtyMetreLoKHz && freqKHz < _sixtyMetreHiKHz) ? 'USB' : 'LSB';
  }
  if (band == null || band.isEmpty) return null;
  return _lsbBands.contains(band) ? 'LSB' : 'USB';
}

/// [mode] with a generic `SSB` turned into the sideband that band actually
/// uses. Anything else — including a mode already naming its sideband — is
/// returned untouched.
///
/// "SSB" is what a spot, a command or a mode picker says; it is not a mode a
/// radio can be put in, and it is not what an operator on 40 m is running. The
/// resolution happens where a mode is REQUESTED (`RadioService.setVfo`), so the
/// panel, the log and the rig all name the same sideband, and again at the CAT
/// boundary for the modes that reach a driver without passing through the VFO —
/// a peer driving a rig this device offers.
///
/// [band] is the fallback when there is no frequency to derive one from —
/// which is exactly what a manual band pick leaves behind. Without it a
/// picked 40m plus SSB resolved to USB.
String? resolveSideband(String? mode, double? freqKHz, {String? band}) {
  if (mode == null || mode.toUpperCase() != 'SSB') return mode;
  return expectedSideband(freqKHz: freqKHz, band: band) ?? 'USB';
}

/// The app modes that name a digital mode rather than a way of setting the
/// radio. A rig running any of them sits in its data sideband.
const _digitalModes = {'FT8', 'FT4', 'FT2', 'JS8', 'DATA', 'PSK', 'PSK31', 'OLIVIA', 'MFSK', 'JT65', 'JT9', 'WSPR', 'Q65', 'MSK144', 'FST4', 'VARA'};

/// [mode] as a radio would state it: a digital mode becomes `DATA-USB`, a
/// generic `SSB` the sideband its frequency (or [band]) implies, anything else
/// itself.
///
/// No radio has an FT8 mode. Handing a driver `FT8` sends nothing, and the rig
/// keeps — or, crossing a band, recalls — whatever mode it was in; the rig's
/// report of THAT then replaces the operator's mode in the log. This is the
/// one translation between the app's names and a rig's, for the CAT drivers
/// and the CAT server alike.
String? radioModeForAppMode(String? mode, double? freqKHz, {String? band}) {
  if (mode == null) return null;
  final upper = mode.toUpperCase();
  if (_digitalModes.contains(upper)) return 'DATA-USB';
  return resolveSideband(upper, freqKHz, band: band);
}

/// What a VFO holding [current] should hold once a radio reports [reported]:
/// [current] when the report is exactly what [radioModeForAppMode] would have
/// put the radio in for it, [reported] otherwise.
///
/// A rig in DATA-USB is running the FT8 the operator chose, and the log must
/// still say FT8; any other report — CW, LSB, plain USB — is the operator
/// changing the rig. Every writer of a VFO from a radio's report goes through
/// this, a peer's radio included.
String? appModeForRadioReport({required String? current, required String? reported, double? freqKHz}) {
  if (current == null || reported == null) return reported;
  return radioModeForAppMode(current, freqKHz) == reported ? current : reported;
}

/// The app's data modes and the base mode each one rides on, for a protocol
/// whose DATA is a submode switched on beside the base mode (CI-V's
/// `0x1A 0x06`, a Kenwood's `DA`) rather than a mode code of its own.
const dataModeBases = <String, String>{'DATA-USB': 'USB', 'DATA-LSB': 'LSB', 'DATA-FM': 'FM'};

/// The app's name for [baseMode] with the DATA submode on, or [baseMode]
/// itself when off or when that mode has no data submode.
String modeNameWithData(String baseMode, {required bool data}) {
  if (!data) return baseMode;
  for (final entry in dataModeBases.entries) {
    if (entry.value == baseMode) return entry.key;
  }
  return baseMode;
}

/// Whether [mode] names the sideband the band does NOT run — the one thing
/// about a sideband worth an operator's attention, and the only reason a
/// display ever spells one out.
///
/// False wherever there is nothing to contradict: a generic `SSB`, a
/// non-voice mode, and a contact stating neither a frequency nor a band
/// ([expectedSideband] returning null).
bool isUnexpectedSideband(String? mode, {double? freqKHz, String? band}) {
  final m = mode?.toUpperCase();
  if (m != 'USB' && m != 'LSB') return false;
  final expected = expectedSideband(freqKHz: freqKHz, band: band);
  return expected != null && m != expected;
}

/// [mode] as a pill, a log row or a spot row shows it: `SSB`, unless the
/// stored sideband is the one that band does not run, in which case it is
/// spelled out so the operator can see it.
///
/// The sideband is where-you-are's business, not the operator's: `USB` on 20 m
/// and `LSB` on 40 m are both just "SSB", and a log that spells them out reads as
/// two modes where one was worked — enough to make the QSO list grow a Mode
/// column for a single-mode operation. What the log STORES is untouched; ADIF
/// and every scorer still see the sideband.
///
/// Pair it with [isUnexpectedSideband] to paint what comes back: a spelled-out
/// sideband is exactly the case that wants an error color.
String? displayMode(String? mode, {double? freqKHz, String? band}) {
  if (!isSidebandMode(mode)) return mode;
  return isUnexpectedSideband(mode, freqKHz: freqKHz, band: band) ? mode!.toUpperCase() : 'SSB';
}

typedef _BandPlanSegment = ({double loKHz, double hiKHz, String? mode, int priority, List<int> regions, List<String> countries});

/// Guesses the mode for [khz] from the amateur radio band plan —
/// the generous, worldwide segments (CW/Phone/Data sub-bands) where a
/// specific mode is conventionally used, not a regulatory boundary (that's
/// [bandForFrequency]'s job). Returns null where the band plan doesn't settle
/// on one mode for [khz] (e.g. a repeater/beacon segment, no segment covers
/// it at all, or the winning segment marks [khz] out of band — see
/// [isOutOfBandFrequency]) — callers should fall back to the current/default
/// mode.
///
/// [ituRegion]/[countryCode] are the operator's own — from the
/// callsign-annotation guess, e.g. `guess['ituRegion']`/`guess['countryCode']`
/// — when the caller has them. [countryCode] is only honoured alongside an
/// [ituRegion] (see [_bestSegmentFor]); on its own it is ignored. Only
/// [bandPlanModeSegments] entries scoped to a *different* region/country are
/// affected: with the region null (the default), scope can't be checked at
/// all and every segment stays a candidate.
///
/// Priority always wins first, matching the source library: a narrowband
/// digital carve-out (FT8/FT4, priority 100) beats the wider CW/Phone/Data
/// segment it sits inside even when the carve-out is region/country-scoped
/// to somewhere else (e.g. a US operator still gets FT8 at 80m's globally
/// unscoped 3573-3576 kHz window, not the Region-3-only one at 3568-3571).
/// Only among same-priority candidates does scope break the tie:
///
///  - Operator region unknown: prefer an unscoped segment over a
///    scoped one, since there's no way to tell whether a scoped one actually
///    applies — letting it win anyway risks e.g. a blanket "unrestricted"
///    marker scoped to one specific country winning a narrowest-segment
///    tie-break and returning a null guess for a frequency that's plainly
///    SSB everywhere else.
///  - Operator region known: a segment scoped to somewhere else is
///    excluded outright, before priority is even compared — it plainly
///    doesn't apply. Among what's left, the most specific rule that
///    actually applies wins: a country match, then a region match, then an
///    unscoped segment (see [_scopeRank]) — the opposite preference from
///    the unknown case above, now that a restriction list here only ever
///    means "restricted to the operator".
///
/// A final tie among same-priority, same-scope-preference candidates goes to
/// the narrowest segment, and then — deliberately, not by accident — to
/// whichever [bandPlanModeSegments] lists first: this is a single forward
/// pass keeping the first candidate that isn't strictly beaten, not a sort,
/// so an exact tie has one well-defined, reproducible answer instead of
/// depending on `List.sort`'s documented-unstable ordering for equal
/// elements.
String? modeForFrequency(double khz, {int? ituRegion, String? countryCode}) {
  final mode = _bestSegmentFor(khz, ituRegion, countryCode)?.mode;
  // Out of band is not a mode: callers guessing what to log get the same
  // null they get for a segment with no single mode, so nothing can end up
  // logged — or offered in the Mode dropdown — as [outOfBandMode]. Use
  // [isOutOfBandFrequency] to ask the question this hides.
  return mode == outOfBandMode ? null : mode;
}

/// The band plan's own marker for "amateurs are not allocated [khz] here"
/// — the source data's `mode: false` segments (e.g. 40m's 7200-7300 in ITU
/// Region 1), carried through the generated table as this sentinel to keep
/// them apart from its `mode: null` ones ("no single mode conventionally
/// used here"). Not a mode, and deliberately not a member of [modes] or any
/// of the other vocabularies below: it is a display/alert value only.
const String outOfBandMode = 'OOB';

/// Whether the band plan says [khz] is outside the operator's own amateur
/// allocation. Scoped exactly like [modeForFrequency], and answers false
/// outright without an [ituRegion] ([countryCode] alone places nobody, see
/// [_bestSegmentFor]): telling an operator whose location we don't know
/// that they are transmitting illegally is worse than saying nothing.
///
/// That refusal is structural rather than a property of the data. Ranking
/// alone would not deliver it: an unscoped segment merely OUTRANKS a scoped
/// one when the operator can't be placed, so a scoped out-of-band segment
/// still wins by default over no candidate at all. It only looks safe today
/// because some unscoped segment happens to overlap all five out-of-band
/// spans — nothing enforces that, and a `mode: false` arriving on 4m, which
/// has no unscoped segment whatsoever, would start accusing every caller
/// who passed no region.
bool isOutOfBandFrequency(double khz, {int? ituRegion, String? countryCode}) {
  if (ituRegion == null) return false;
  final best = _bestSegmentFor(khz, ituRegion, countryCode);
  if (best?.mode != outOfBandMode) return false;
  // Strictly INSIDE the segment, where [modeForFrequency] treats both edges
  // as covered. An out-of-band span abuts an allocation rather than
  // overlapping it — 160m Region 1 runs 1800-1810 against a band that opens
  // at 1810 — and a segment's edge frequency is therefore the first or last
  // one the operator may legally use. A mode guess that lands on the wrong
  // side of that shared edge costs a keystroke to correct; an accusation
  // costs the operator's confidence in every other time this fires. The
  // deliberate cost is the exact top edge of a span (7300.000 kHz for
  // Region 1's 40m) going unwarned.
  return best!.loKHz < khz && khz < best.hiKHz;
}

/// The single band-plan segment that wins for [khz] — see
/// [modeForFrequency]'s doc comment for the whole tie-break order. Shared so
/// that [isOutOfBandFrequency] answers about the very segment
/// [modeForFrequency] read, rather than re-deriving the winner with a scan
/// that could drift from it.
_BandPlanSegment? _bestSegmentFor(double khz, int? ituRegion, String? countryCode) {
  // A country code on its own is ignored: knowing the country says nothing
  // checkable about a REGION-scoped segment, so honouring it would exclude
  // every one of those on a dimension the caller never supplied — a US
  // operator would lose the (globally unscoped-in-practice) Region 3 FT8
  // window at 3568 kHz. The two always travel together in the app anyway:
  // both come from one DXCC entity via `regionAndCountryForDxccCode`, and
  // no entity in that table carries a country code without a region.
  final country = ituRegion == null ? null : countryCode;
  _BandPlanSegment? best;
  for (final segment in bandPlanModeSegments) {
    if (segment.loKHz > khz || segment.hiKHz < khz) continue;
    if (_isScopedElsewhere(segment, ituRegion, country)) continue;
    if (best == null || _isBetterModeMatch(segment, best, ituRegion: ituRegion, countryCode: country)) {
      best = segment;
    }
  }
  return best;
}

/// Whether [segment] restricts to at least one region or country — the
/// single definition [_isScopedElsewhere] and [_isBetterModeMatch] both
/// build on, so there's one place to update if a third scope dimension
/// (e.g. `entities`, see generate_band_plan_segments.mjs) is ever added.
bool _isScoped(_BandPlanSegment segment) => segment.regions.isNotEmpty || segment.countries.isNotEmpty;

/// Whether [segment] is scoped to somewhere other than the operator's own
/// [ituRegion]/[countryCode] — an unscoped segment is never "elsewhere", and
/// neither is a segment scoped to the operator's actual region or country
/// (either list matching is enough; the source data never sets both on the
/// same segment, but nothing here depends on that). Self-contained: unlike
/// [modeForFrequency]'s own `knowsOperatorScope` check, this returns `false`
/// outright when both [ituRegion] and [countryCode] are null, so a caller
/// can never mistake "operator's scope unknown" for "excluded" by forgetting
/// to gate the call — the precondition lives here, not in the caller.
bool _isScopedElsewhere(_BandPlanSegment segment, int? ituRegion, String? countryCode) {
  if (ituRegion == null && countryCode == null) return false;
  if (!_isScoped(segment)) return false;
  if (ituRegion != null && segment.regions.contains(ituRegion)) return false;
  if (countryCode != null && segment.countries.contains(countryCode)) return false;
  return true;
}

/// How specific [segment] is to the operator, for [_isBetterModeMatch]'s
/// same-priority tie-break — higher wins.
///
/// With the operator's region known, the most specific rule that actually
/// applies wins: a country match, then a region match, then an unscoped
/// segment. Matching the source library, which breaks the same tie in the
/// same order (entity, then country, then region) before it ever reaches
/// width — without this a wide country-specific marker loses to a narrow
/// region-scoped segment, and e.g. 30m's "Africa south of the Equator"
/// entry never applies to the Kenyan operator it names.
///
/// Ranked on the list that MATCHED, not on which lists the segment carries.
/// [_isScopedElsewhere] keeps a segment when EITHER list matches, so a
/// segment restricted by region and country at once survives for an
/// operator only its region matches — and scoring that as a country match
/// would beat a segment genuinely scoped to where they are.
///
/// With the region unknown, no restriction list can be checked at all, so
/// the ranking collapses to "prefer the unscoped one" — see
/// [modeForFrequency]'s doc comment for why that direction is the safe one.
int _scopeRank(_BandPlanSegment segment, {required int? ituRegion, required String? countryCode}) {
  if (ituRegion == null) return _isScoped(segment) ? 0 : 1;
  if (countryCode != null && segment.countries.contains(countryCode)) return 3;
  if (segment.regions.contains(ituRegion)) return 2;
  return 1;
}

/// Whether [candidate] should replace [current] as the best match in
/// [modeForFrequency]'s scan — see that function's doc comment for the
/// tie-break order, and [_scopeRank] for how a same-priority scope tie is
/// settled. Strict comparisons throughout (`<`, not `<=`) so an exact tie
/// leaves [current] in place, making the scan's result depend only on
/// [bandPlanModeSegments]' fixed order, never on comparator left/right
/// argument order the way a sort comparator would.
bool _isBetterModeMatch(_BandPlanSegment candidate, _BandPlanSegment current, {required int? ituRegion, required String? countryCode}) {
  if (candidate.priority != current.priority) return candidate.priority > current.priority;
  final candidateRank = _scopeRank(candidate, ituRegion: ituRegion, countryCode: countryCode);
  final currentRank = _scopeRank(current, ituRegion: ituRegion, countryCode: countryCode);
  if (candidateRank != currentRank) return candidateRank > currentRank;
  final candidateWidth = candidate.hiKHz - candidate.loKHz;
  final currentWidth = current.hiKHz - current.loKHz;
  return candidateWidth < currentWidth;
}

/// MHz/kHz/Hz split for QSO-row display: MHz bold, kHz regular, Hz (if any)
/// regular at a smaller size.
///
/// The row reads as kHz, like the spots panel and the radio controls — the
/// caller joins all three with [frequencyMark] (`7.200.5`). The split is for
/// styling and for column alignment across an operation, not a claim that
/// these are three numbers.
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
/// separately can round a remainder up to exactly
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

  return FreqParts(mhz: mhzWhole.toString(), khz: khzWhole.toString().padLeft(3, '0'), hz: hzDigits > 0 ? hzString.substring(0, hzDigits) : null);
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
// @ham2k/lib-operation-data v1.1.3 (EXTENDED_BANDS / POPULAR_BANDS /
// MAIN_MODES / ADIF_MODES_AND_SUBMODES) — regenerate from the lib when it
// changes. Band names must agree with [bands] above for the frequencies
// that table covers (the '2190m' note), and with the extension runtime,
// which uses the lib directly. These back the `$core.bands`/`$core.modes`
// system lists (app/lib/settings/system_lists.dart).

const List<String> extendedBands = [
  '2190m',
  '630m',
  '560m',
  '160m',
  '80m',
  '60m',
  '40m',
  '30m',
  '20m',
  '17m',
  '15m',
  '12m',
  '11m',
  '10m',
  '6m',
  '5m',
  '4m',
  '2m',
  '1.25m',
  '70cm',
  '33cm',
  '23cm',
  '13cm',
  '9cm',
  '6cm',
  '3cm',
  '1.25cm',
  '6mm',
  '4mm',
  '2.5mm',
  '2mm',
  '1mm',
  'submm',
  'other',
];

/// Band names in wide use that are not what the band is called here. '75m' is
/// the phone end of 80m, and '2200m' is the common name for the band the band
/// table calls '2190m' — typed either way, the operator means the same band.
/// Mirrored by the radio-commands extension's own `parseBandCommand`, which
/// reads the band list from the published lib rather than this snapshot.
const Map<String, String> bandAliases = {'75m': '80m', '2200m': '2190m'};

const List<String> popularBands = ['160m', '80m', '60m', '40m', '30m', '20m', '17m', '15m', '12m', '10m', '6m', '2m', '70cm'];

const List<String> mainModes = ['CW', 'SSB', 'AM', 'FM', 'FT8', 'FT4', 'RTTY'];

const List<String> popularModes = [
  'CW',
  'SSB',
  'USB',
  'LSB',
  'FM',
  'AM',
  'FT8',
  'FT4',
  'FT2',
  'RTTY',
  'DIGITALVOICE',
  'C4FM',
  'DMR',
  'DSTAR',
  'FREEDV',
  'M17',
  'DYNAMIC',
  'HELL',
  'JT9',
  'MFSK',
  'MSK144',
  'OLIVIA',
  'PKT',
  'PSK',
  'SSTV',
  'WSPR',
];

const List<String> adifModes = [
  '8PSK1000',
  '8PSK1000F',
  '8PSK1200F',
  '8PSK125',
  '8PSK125F',
  '8PSK125FL',
  '8PSK250',
  '8PSK250F',
  '8PSK250FL',
  '8PSK500',
  '8PSK500F',
  'AM',
  'AMTORFEC',
  'ARDOP',
  'ASCI',
  'ATV',
  'C4FM',
  'CHIP',
  'CHIP128',
  'CHIP64',
  'CLO',
  'CONTESTI',
  'CW',
  'DIGITALVOICE',
  'DMR',
  'DOM-M',
  'DOM11',
  'DOM16',
  'DOM22',
  'DOM4',
  'DOM44',
  'DOM5',
  'DOM8',
  'DOM88',
  'DOMINO',
  'DOMINOEX',
  'DOMINOF',
  'DSTAR',
  'DYNAMIC',
  'FAX',
  'FM',
  'FMHELL',
  'FREEDATA',
  'FREEDV',
  'FSK',
  'FSK31',
  'FSK441',
  'FSKH105',
  'FSKH245',
  'FSKHELL',
  'FSQCALL',
  'FST4',
  'FST4W',
  'FT2',
  'FT4',
  'FT8',
  'GTOR',
  'HELL',
  'HELL80',
  'HELLX5',
  'HELLX9',
  'HFSK',
  'ISCAT',
  'ISCAT-A',
  'ISCAT-B',
  'JS8',
  'JT4',
  'JT44',
  'JT4A',
  'JT4B',
  'JT4C',
  'JT4D',
  'JT4E',
  'JT4F',
  'JT4G',
  'JT65',
  'JT65A',
  'JT65B',
  'JT65B2',
  'JT65C',
  'JT65C2',
  'JT6M',
  'JT9',
  'JT9-1',
  'JT9-10',
  'JT9-2',
  'JT9-30',
  'JT9-5',
  'JT9A',
  'JT9B',
  'JT9C',
  'JT9D',
  'JT9E',
  'JT9E FAST',
  'JT9F',
  'JT9F FAST',
  'JT9G',
  'JT9G FAST',
  'JT9H',
  'JT9H FAST',
  'JTMS',
  'LSB',
  'M17',
  'MFSK',
  'MFSK11',
  'MFSK128 MFSK128L',
  'MFSK16',
  'MFSK22',
  'MFSK31',
  'MFSK32',
  'MFSK4',
  'MFSK64',
  'MFSK64L',
  'MFSK8',
  'MSK144',
  'MT63',
  'MTONE',
  'NAVTEX',
  'ODFM',
  'OLIVIA',
  'OLIVIA 16/1000',
  'OLIVIA 16/500',
  'OLIVIA 32/1000',
  'OLIVIA 4/125',
  'OLIVIA 4/250',
  'OLIVIA 8/250',
  'OLIVIA 8/500',
  'OPERA',
  'OPERA-BEACON',
  'OPERA-QSO',
  'PAC',
  'PAC2',
  'PAC3',
  'PAC4',
  'PAX',
  'PAX2',
  'PCW',
  'PKT',
  'PSK',
  'PSK10',
  'PSK1000',
  'PSK1000C2',
  'PSK1000R',
  'PSK1000RC2',
  'PSK125',
  'PSK125C12',
  'PSK125R',
  'PSK125RC10',
  'PSK125RC12',
  'PSK125RC16',
  'PSK125RC4',
  'PSK125RC5',
  'PSK250',
  'PSK250C6',
  'PSK250R',
  'PSK250RC2',
  'PSK250RC3',
  'PSK250RC5',
  'PSK250RC6',
  'PSK250RC7',
  'PSK2K',
  'PSK31',
  'PSK500',
  'PSK500C2',
  'PSK500C4',
  'PSK500R',
  'PSK500RC2',
  'PSK500RC3',
  'PSK500RC4',
  'PSK63',
  'PSK63F',
  'PSK63RC10',
  'PSK63RC20',
  'PSK63RC32',
  'PSK63RC4',
  'PSK63RC5',
  'PSK800C2',
  'PSK800RC2',
  'PSKAM10',
  'PSKAM31',
  'PSKAM50',
  'PSKFEC31',
  'PSKHELL',
  'Q15',
  'Q65',
  'QPSK125',
  'QPSK250',
  'QPSK31',
  'QPSK500',
  'QPSK63',
  'QRA64',
  'QRA64A',
  'QRA64B',
  'QRA64C',
  'QRA64D',
  'QRA64E',
  'RIBBIT_PIX',
  'RIBBIT_SMS',
  'ROS',
  'ROS-EME',
  'ROS-HF',
  'ROS-MF',
  'RTTY',
  'RTTYM',
  'SCAMP_FAST',
  'SCAMP_OO',
  'SCAMP_OO_SLW',
  'SCAMP_SLOW',
  'SCAMP_VSLOW',
  'SIM31',
  'SITORB',
  'SLOWHELL',
  'SSB',
  'SSTV',
  'T10',
  'THOR',
  'THOR-M',
  'THOR100',
  'THOR11',
  'THOR16',
  'THOR22',
  'THOR25X4',
  'THOR4',
  'THOR5',
  'THOR50X1',
  'THOR50X2',
  'THOR8',
  'THRB',
  'THRBX',
  'THRBX1',
  'THRBX2',
  'THRBX4',
  'THROB1',
  'THROB2',
  'THROB4',
  'TOR',
  'USB',
  'V4',
  'VARA FM 1200',
  'VARA FM 9600',
  'VARA HF',
  'VARA SATELLITE',
  'VOI',
  'WINMOR',
  'WSPR',
];

/// Modes whose report is two digits (`59`) rather than three.
///
/// `USB` and `LSB` belong here alongside the generic `SSB`: no CAT protocol
/// has an "SSB" mode, so a connected rig reports the concrete sideband and
/// nothing maps it back — `CatService` pushes it straight to the VFO, and the
/// logging panel copies it into its own mode. Leave them out and an operator
/// with a rig attached gets a three-digit report on phone while one who picked
/// SSB by hand gets two.
const Set<String> _phoneModes = {'SSB', 'USB', 'LSB', 'FM', 'AM'};

/// Modes whose report is a signal-to-noise figure in dB, not an RST at all —
/// so neither the default nor [expandRST] has any business rewriting one.
const Set<String> _snrModes = {'FT8', 'FT4', 'FT2'};

/// Modes carrying the third, tone digit of a full R-S-T report. Phone drops
/// it because a voice signal has no tone; the other digital modes are left
/// with the three-digit default they have always had.
const Set<String> _toneModes = {'CW', 'RTTY'};

/// How many characters a complete report runs to — two on phone (`59`), three
/// on CW and the data modes (`599`) — or **null** for the FT modes, whose
/// report has no fixed length at all: `-9`, `+05` and `-12` are equally real,
/// so nothing can tell when the operator has finished one. The same reason
/// [expandRST] leaves them alone.
///
/// This is what "the operator has finished typing a report" means for the
/// jump-after-RST setting, and it is deliberately the FULL length rather than
/// the length of the significant part [expandRST] completes from: a `44` on CW
/// is two characters and still owes its `A` or its tone, so jumping at two
/// would put the aurora reports and `5NN` out of reach entirely.
int? rstLengthFor(String mode) {
  if (_snrModes.contains(mode)) return null;
  return _phoneModes.contains(mode) ? 2 : 3;
}

/// What an untouched report field stands for, in three bands the operator can
/// each override in Logging settings ([phone] for SSB/FM/AM, [snr] for the FT
/// modes, [cw] for CW/RTTY and every other digital mode).
///
/// The overrides only change the VALUE — which modes fall in which band, and
/// what [expandRST] does with a partial report, are properties of the mode and
/// stay fixed. A blank or missing override is not one: an operator who clears
/// the field gets the standard report back rather than an empty default.
String defaultRSTFor(String mode, {String? phone, String? cw, String? snr}) {
  String pick(String? override, String standard) {
    final value = override?.trim();
    return (value == null || value.isEmpty) ? standard : value;
  }

  if (_snrModes.contains(mode)) return pick(snr, '+0');
  return _phoneModes.contains(mode) ? pick(phone, '59') : pick(cw, '599');
}

/// Completes a report the operator only typed the significant part of: `5`
/// becomes `55` on phone and `559` on CW, `57` becomes `579` on CW, and the
/// aurora shorthand `A` becomes `59A`. Anything already three characters or
/// more is theirs and comes back untouched.
///
/// Readability tracks strength because the two move together in practice: a
/// signal at S1-S3 isn't fully readable, so a bare `2` means `32`, not `52`.
///
/// [_snrModes] opt out entirely — `-12` is a real report on FT8 and every
/// rule below would mangle it.
///
/// Empty in, empty out: this completes what was typed and never invents a
/// report, so a caller that wants the default asks [defaultRSTFor] for it.
String expandRST(String text, String mode) {
  text = text.trim();
  if (text.isEmpty || _snrModes.contains(mode)) return text;

  final tone = _toneModes.contains(mode);
  if (text.length == 1) {
    if (text == 'A') return '59A';
    if (!_isDigit(text)) return text;
    final strength = text;
    final readability = switch (strength) {
      '1' || '2' || '3' => '3',
      '4' => '4',
      _ => '5',
    };
    return tone ? '$readability${strength}9' : '$readability$strength';
  }
  if (text.length == 2 && tone) {
    // "4A" is an aurora report missing its readability, not a report missing
    // its tone — the A IS the tone, so the digit doubles instead.
    if (text[1] == 'A') return '${text[0]}$text';
    if (_isDigit(text[0]) && _isDigit(text[1])) return '${text}9';
  }
  return text;
}

bool _isDigit(String s) => s.codeUnitAt(0) >= 0x30 && s.codeUnitAt(0) <= 0x39;

/// Voice modes for [superModeForMode] — mirrors @ham2k/lib-operation-data's
/// PHONE_MODES. Broader than [_phoneModes] (which is only the RST-default set),
/// since super-mode grouping also treats the digital-voice modes as phone.
const Set<String> superPhoneModes = {'SSB', 'USB', 'LSB', 'FM', 'AM', 'DIGITALVOICE', 'C4FM', 'DMR', 'DSTAR', 'FREEDV', 'M17'};

/// The "super mode" of [mode] — `'Phone'`, `'CW'`, or `'Digital'` — mirroring
/// @ham2k/lib-operation-data's `superModeForMode` (which groups modes into
/// CW / PHONE / DATA), or null for a null mode. Classifies main modes without
/// that lib's ADIF submode resolution: anything that isn't CW or a phone mode
/// is Digital.
String? superModeForMode(String? mode) {
  if (mode == null) return null;
  final m = mode.toUpperCase();
  if (m == 'CW') return 'CW';
  if (superPhoneModes.contains(m)) return 'Phone';
  return 'Digital';
}

final _freqSpaces = RegExp(r'[\s\u00a0\u202f]');
final _freqChars = RegExp(r'^[0-9.]+$');

/// The microwave bands [parseFreq] reads a number a thousandfold up into, in
/// kHz — the same short table as `@ham2k/lib-format-tools` `parseFreq`, so
/// the Freq field and a call-field command agree. Not [bands]: only these
/// decide between readings, so a band whose digits mean something else as
/// MHz leaves them out — 30m read as MHz sits inside 3cm
/// read as GHz, and 3.5 is 80m.
const _microwaveRescues = [
  (1240000, 1300000), // 23cm
  (2300000, 2450000), // 13cm
  (3300000, 3450000), // 9cm
  (5650000, 5925000), // 6cm
  (10000000, 10099999), (10150001, 10500000), // 3cm, around 30m
  (24000000, 24250000), // 1.25cm
];

bool _isMicrowave(double khz) => _microwaveRescues.any((range) => khz >= range.$1 && khz <= range.$2);

/// Parses user frequency input into kHz.
///
/// Frequencies are written with periods whatever the device's number
/// conventions, for grouping and decimals alike — `14.285`, `14.285.5`,
/// `1296.000` — and context says which mark is which. A comma reads as a
/// period: it is the only mark a comma-decimal phone keypad offers, and
/// `14,285.5` typed out of US habit names the same frequency.
///
/// - No mark: kHz.
/// - One mark under 1000: MHz ("14.285" → 14285), or kHz for 2190m and 630m
///   ("472.5"), or GHz for a microwave band ("1.296").
/// - One mark from 1000: kHz ("14285.5"), or MHz for a microwave band —
///   "1296.000", which is how [fmtFreq] writes 23cm.
/// - Two or more: the last mark is the decimal ("14.200.5" → 14200.5), unless
///   only reading every mark as grouping names a band ("1.296.000"). Every
///   group between the first and the last is exactly three digits, and a
///   first group past three is whole MHz only where that lands in a microwave
///   band ("10368.100.5"); anything else is refused rather than guessed at
///   ("14285.200.5" is a stray mark, not 14 GHz).
///
/// Extensions read the same notation through `@ham2k/lib-format-tools`
/// `parseFreq` (1.3.1 on).
double? parseFreq(String input) {
  final cleaned = input.trim().replaceAll(_freqSpaces, '').replaceAll(',', '.');
  if (!_freqChars.hasMatch(cleaned)) return null;
  final groups = cleaned.split('.');
  if (groups.length > 2) return _parseGroupedFreq(groups);
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0) return null;
  if (groups.length == 2 && value < 1000) {
    // "14.285" is 14.285 MHz — but "472.5" is 630m, in kHz, and "1.296" is
    // 23cm, in GHz. Each reading is tried in that order and the first that
    // names a band wins. MHz goes first because it is what someone typing a
    // decimal into a frequency box means.
    //
    // When NO reading names a band ("5.0" — WWV, or a typo) the MHz reading
    // still wins. The other two only rescue the cases where they are
    // unambiguously right — 2200m and 630m, which is why `fmtFreqInput` can
    // round-trip them at all, and the microwave bands.
    final asMHz = value * 1000;
    if (bandForFrequency(asMHz) != null) return asMHz;
    if (bandForFrequency(value) != null) return value;
    // A bare band name outranks the GHz reading: "1.25" is 1.25 GHz, inside
    // 23cm, but it is also how an iOS numeric keypad, which has no "m",
    // names the 1.25m band through [parseBandInput].
    final asGHz = value * 1000000;
    if (_isMicrowave(asGHz) && parseBandInput(cleaned) == null) return asGHz;
    return asMHz;
  }
  if (groups.length == 2 && bandForFrequency(value) == null && _isMicrowave(value * 1000)) return value * 1000;
  return value;
}

/// [parseFreq] for input with two or more marks, split at them.
double? _parseGroupedFreq(List<String> groups) {
  final first = groups.first;
  final last = groups.last;
  if (first.isEmpty || last.isEmpty) return null;
  if (groups.sublist(1, groups.length - 1).any((group) => group.length != 3)) return null;
  final withDecimal = double.parse('${groups.sublist(0, groups.length - 1).join()}.$last');
  if (withDecimal <= 0) return null;
  if (first.length > 3) return _isMicrowave(withDecimal) ? withDecimal : null;
  // Every mark as grouping instead, which the decimal reading turns into
  // 1296 kHz — no band.
  if (last.length == 3) {
    final allGrouped = double.parse(groups.join());
    if (bandForFrequency(withDecimal) == null && _isMicrowave(allGrouped)) return allGrouped;
  }
  return withDecimal;
}

/// Reads user input naming a band — "20m", "20 M", "70cm", or the bare
/// number "20" — as a name from [bands], or null for anything else.
///
/// The bare-number form is safe because no band's wavelength in meters is
/// also a frequency inside a band: everything below 160 is under the 135.7 kHz
/// floor of the lowest band, and the three above it (160, 630, 2190 kHz) all
/// land in gaps between bands. That property is what callers rely on, so try
/// [parseFreq] first and fall back to this only when the number names no band
/// — resolving a band first would shadow real frequencies if [bands] ever
/// grew an entry that broke it.
///
/// It has to exist because the field is numeric on iOS — the
/// numbers-and-punctuation keyboard carries no letters, so a suffixed form
/// alone would make this a desktop-only feature.
String? parseBandInput(String input) {
  final spaced = input.trim().toLowerCase().replaceAll(' ', '');
  // A comma is either a period, as in [parseFreq] — "1,25" from a
  // comma-decimal keypad is the 1.25m band — or grouping, "2,190m".
  return _bandNamed(spaced.replaceAll(',', '.')) ?? _bandNamed(spaced.replaceAll(',', ''));
}

/// [parseBandInput] for input already free of spaces, each comma resolved to
/// a period or dropped.
String? _bandNamed(String input) {
  var cleaned = input;
  if (cleaned.isEmpty) return null;
  // A unit the operator typed pins which of the candidates to try; with none,
  // "70" means 70cm because there is no 70m band to prefer. Millimetres are
  // deliberately outside that fallback: "1" means 1mm to nobody, and a bare
  // number should name no band rather than the wrong one.
  final unitMatch = RegExp(r'(mm|cm|m)$').firstMatch(cleaned);
  final units = unitMatch == null ? const ['m', 'cm'] : [unitMatch.group(1)!];
  if (unitMatch != null) cleaned = cleaned.substring(0, cleaned.length - unitMatch.group(1)!.length);
  // Reject "20.0" and "1.250": a band is named by an exact string, and
  // matching on the parsed number instead would accept spellings the Band
  // dropdown never shows.
  //
  // Matched against [extendedBands], the whole vocabulary of bands the app
  // knows — not [bands], which stops at 23cm and would answer "2m" for the
  // "2mm" a microwave operator typed. Deliberately wider than the Band
  // dropdown, which offers only the bands enabled in Settings: naming a band
  // is how an operator reaches one they work rarely enough not to have
  // enabled, and the dropdown appends whatever is current so it still shows.
  for (final unit in units) {
    final name = '$cleaned$unit';
    if (extendedBands.contains(name)) return name;
    final alias = bandAliases[name];
    if (alias != null) return alias;
  }
  return null;
}

/// Formats kHz for display at up to Hz precision, with trailing zeros
/// trimmed: "14.285.5", "14.074.25", "14.285", and whole MHz past a GHz with
/// no mark of its own, "1296.000". [minDecimals]
/// (0–3) keeps that many decimals even when they are zeros — "14.074.20" —
/// for a label that must hold its width while a reading moves.
///
/// Periods for grouping and decimal alike, whatever the operator's number
/// conventions — see [frequencyMark].
///
/// Carried in whole Hz rather than by splitting the double: 14285.9996 taken
/// apart directly yields a fraction of 1000 and formats as "14.285.1000".
String fmtFreq(double khz, {int minDecimals = 0}) {
  final totalHz = (khz * 1000).round();
  final mhz = totalHz ~/ 1000000;
  final khzPart = (totalHz ~/ 1000 % 1000).toString();
  final whole = mhz == 0 ? khzPart : '$mhz$frequencyMark${khzPart.padLeft(3, '0')}';
  final fraction = (totalHz % 1000).toString().padLeft(3, '0');
  var digits = 3;
  while (digits > minDecimals && fraction[digits - 1] == '0') {
    digits--;
  }
  return digits == 0 ? whole : '$whole$frequencyMark${fraction.substring(0, digits)}';
}

/// The decimals a frequency label that follows a moving reading holds: the
/// most any value has needed since the reading last sat still for
/// [settleDelay], passed to [fmtFreq] as `minDecimals`. A dial spun in 100 Hz
/// steps reads "14.074.9", "14.075.0", "14.075.1" at one width instead of
/// the label jumping at every whole kHz; once settled, trailing zeros go.
class FreqDecimalsHold {
  FreqDecimalsHold({required this.onSettle});

  static const settleDelay = Duration(seconds: 5);

  /// Called when the floor drops back to 0, for the owner to repaint.
  final void Function() onSettle;

  int _decimals = 0;
  double? _last;
  Timer? _settle;

  int get decimals => _decimals;

  /// Takes a new reading. The same value again is not movement, and does
  /// not restart the wait.
  void note(double khz) {
    if (khz == _last) return;
    _last = khz;
    final needed = hzDigitsNeeded([khz]);
    if (needed > _decimals) _decimals = needed;
    if (_decimals == 0) return;
    _settle?.cancel();
    _settle = Timer(settleDelay, () {
      _decimals = 0;
      onSettle();
    });
  }

  void dispose() => _settle?.cancel();
}

/// The one mark a frequency is written with, between MHz and kHz and before
/// the Hz alike: "14.285.5".
///
/// Not the operator's number conventions, which govern every OTHER number:
/// a frequency is read from context, and one fixed mark keeps every surface
/// showing the same string for the same frequency. [parseFreq] reads it back.
const frequencyMark = '.';

/// Formats kHz for display at Hz precision, always three decimals:
/// "14.285.400".
///
/// For the surfaces that show where a radio actually IS, rather than where a
/// QSO was logged. Trailing zeros are kept, so the reading doesn't change
/// width as the last digits settle.
String fmtFreqToTheHz(double khz) => fmtFreq(khz, minDecimals: 3);

/// Formats kHz for an editable frequency field, at full stored precision
/// (down to 1 Hz — three decimals in kHz) and without thousands grouping,
/// so a value round-trips through [parseFreq] unchanged and edits as plain
/// digits. Trailing zeros are trimmed, so whole frequencies show plainly ("7025", not
/// "7025.000").
String fmtFreqInput(double khz) {
  var s = khz.toStringAsFixed(3);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

// `CALLSIGN_REGEXP` from `@ham2k/lib-callsigns`' `parseCallsign` — the same
// parser the extensions (and app-polo) use — so this gate agrees with what
// actually parses as a callsign downstream:
//
//   ([A-Z0-9]+/)?  an optional preindicator, e.g. the "EA4/" of "EA4/KI2D"
//   then a prefix, one of:
//     [45]U[A-Z]*             4U/5U, whose prefixes carry no separating digit
//     [0-9][A-Z]{1,2}[0-9]    digit-letters-digit, e.g. the "9A1" of "9A1A"
//     [ACDEHJLOPQSTUVXYZ][0-9]
//     [A-Z]{1,2}[0-9]         the usual letters-digit, e.g. "W1", "KI2"
//   [A-Z0-9]+      the suffix, at least one character
//   (/[A-Z0-9]+)*  any number of postindicators, e.g. "/P", "/1/QRP/P"
//
// Every prefix form here needs a letter before the separating digit, so a
// band token like "20M" can never parse as a callsign and fire a full
// offline+online lookup for a station called 20M.
//
// One deliberate departure from the library's `(\/[A-Z0-9/]+){0,1}` tail:
// each postindicator must be non-empty, so halo's call-stack separator
// ("K1ABC//W1AW") isn't read as one callsign. The library's
// SSID handling (`N0CALL-1`) is left out too — halo has no notion of one.
final RegExp _callsignRegex = RegExp(
  r'^([A-Z0-9]+/)?'
  r'([45]U[A-Z]*|[0-9][A-Z]{1,2}[0-9]|[ACDEHJLOPQSTUVXYZ][0-9]|[A-Z]{1,2}[0-9])'
  r'[A-Z0-9]+'
  r'(/[A-Z0-9]+)*$',
);

/// Cheap plausibility check to enable the Log action — real callsign
/// parsing (prefixes, DXCC, modifiers) is plugin territory.
bool looksLikeCallsign(String text) => _callsignRegex.hasMatch(text.trim().toUpperCase());

/// Whether [call] is one the operator marked as not fully copied — any `?`
/// in it, a lone `?` included ("worked someone, didn't get the call"), as
/// app-polo accepts. Such a call logs, but is never looked up, scored or
/// spotted: every one of those would act on letters nobody heard. It stays
/// that way until the operator edits the `?` out.
bool isIncompleteCall(String call) => call.contains('?');

/// Whether [call] is enough to log a contact with: a plausible callsign, or
/// an [isIncompleteCall] one.
bool isLoggableCall(String call) => looksLikeCallsign(call) || isIncompleteCall(call);

/// [call] uppercased with its pre- and postindicators dropped — `KI2D` for
/// `EA4/KI2D`, `KI2D/P` and `KI2D/1/QRP` — matching `@ham2k/lib-callsigns`'
/// `baseCall`. Synchronous, for the places that compare calls on every build
/// and cannot await the extensions' parser. Text that does not parse as a
/// callsign comes back only trimmed and uppercased.
///
/// A postindicator that itself parses as a whole callsign reads as the base
/// instead — `C6A` for `W1AW/C6A` — as it does in the regex this mirrors.
String baseCallOf(String call) {
  final upper = call.trim().toUpperCase();
  final match = _callsignRegex.firstMatch(upper);
  if (match == null) return upper;
  final core = upper.substring(match.group(1)?.length ?? 0);
  final slash = core.indexOf('/');
  return slash < 0 ? core : core.substring(0, slash);
}

/// A radio's tuned state — `freq`/`mode`/`band`/`power` for one of up to 4
/// VFOs (`vfoA`..`vfoD`, see `RadioService`). Device-global, not tied to any
/// one operation: a physical radio is tuned to one frequency regardless of
/// which operation you're logging into. `band` is only set when `freq` is
/// null (a manually picked band with no specific frequency).
///
/// `power` is transmit power in watts. It rides here rather than in a
/// concept of its own because it travels with the radio exactly as the
/// other three do — the operator states it, CAT reports it, and every
/// surface that shows or logs it (Station Configuration's Power field, the
/// Power logging control, the power stamped on a QSO) has to agree on one
/// value.
class Vfo {
  final double? freq;
  final String? band;
  final String? mode;
  final num? power;

  const Vfo({this.freq, this.band, this.mode, this.power});

  factory Vfo.fromJson(Map<String, dynamic> json) =>
      Vfo(freq: (json['freq'] as num?)?.toDouble(), band: json['band'] as String?, mode: json['mode'] as String?, power: json['power'] as num?);

  Map<String, dynamic> toJson() => {
    if (freq != null) 'freq': freq,
    if (band != null) 'band': band,
    if (mode != null) 'mode': mode,
    if (power != null) 'power': power,
  };

  /// Value equality so a store can tell a real change from a restatement.
  /// A CAT-connected radio re-reports its state constantly — every status
  /// push, every periodic resync — and without this each one looks like a
  /// change worth notifying every listener and rewriting the prefs for.
  @override
  bool operator ==(Object other) => other is Vfo && other.freq == freq && other.band == band && other.mode == mode && other.power == power;

  @override
  int get hashCode => Object.hash(freq, band, mode, power);

  @override
  String toString() => 'Vfo(freq: $freq, band: $band, mode: $mode, power: $power)';
}

/// What `LoggingControls` (halo_widgets) needs for reading and writing the
/// device's (not any one operation's) VFO state — implemented by the app's
/// `RadioService`. Kept here, in pure-Dart halo_core, so halo_widgets
/// doesn't need a dependency on the Flutter-only app package.
abstract class VfoStore {
  Vfo get vfoA;

  /// `freq`/`band`/`mode`/`power` omitted leave that part unchanged.
  /// `clearFreq` explicitly clears the frequency (keeping the current band,
  /// or `band` if also given) — distinct from simply omitting `freq`, which
  /// is a no-op for it rather than a clear. `clearPower` is the same
  /// distinction for [Vfo.power]: an operator who empties the Power field is
  /// saying they don't know it, which is not the same as not mentioning it.
  void setVfo(String key, {double? freq, String? band, String? mode, num? power, bool clearFreq = false, bool clearPower = false});
}
