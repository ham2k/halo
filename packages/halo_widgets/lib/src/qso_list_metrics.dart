// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO list's list-wide pass: the Number column's values and every
// column's width, worked out once over the whole log and cached between
// rebuilds.

part of 'qso_list.dart';

/// The RST column's guaranteed minimum — CW/RTTY's 3-digit RS(T) on both
/// sides.
const String _rstMinSample = '599 599';

/// The list-wide numbering, column widths and day-grouping [_QsoListState]
/// computes with an O(qsos) pass — walking every QSO plus a handful of real
/// text-layout measurements. Cached against [_QsoListMetricsKey] so an
/// unrelated rebuild (a keystroke elsewhere in the operation view, a focus
/// change) reuses the last pass instead of redoing it: on a long log this is
/// the difference between a rebuild that's free and one that stutters.
class _QsoListMetrics {
  final List<int> numbers;
  final double numberWidth;
  final double callsignWidth;
  final double dxStateWidth;
  final double freqWidth;
  final double rstWidth;
  final double exchangeWidth;
  final double refsWidth;

  /// Whether notes markers are all the refs column holds — what lets the
  /// column plan rank it below the exchange.
  final bool refsAreNotesOnly;
  final int hzDigits;
  final bool usesMultipleModes;
  final List<int> dayKeys;
  final List<List<int>> dayGroups;

  const _QsoListMetrics({
    required this.numbers,
    required this.numberWidth,
    required this.callsignWidth,
    required this.dxStateWidth,
    required this.freqWidth,
    required this.rstWidth,
    required this.exchangeWidth,
    required this.refsWidth,
    required this.refsAreNotesOnly,
    required this.hzDigits,
    required this.usesMultipleModes,
    required this.dayKeys,
    required this.dayGroups,
  });
}

/// Everything [_QsoListMetrics] is derived from, besides `context`'s own
/// widget-tree dependencies (folded in separately as `theme`/`textScaler`
/// below since `Theme.of`/`MediaQuery.textScalerOf` aren't valid outside
/// build). Two keys are equal exactly when a recompute would produce the
/// same metrics, so `qsos`/`activityControls` compare by identity — the
/// list-wide passes only ever care about the actual objects a rebuild reused,
/// not about deep content equality, which would cost as much as the pass
/// it's meant to skip.
class _QsoListMetricsKey {
  final List<Qso> qsos;
  final List<Qso>? log;
  final List<Map<String, dynamic>> activityControls;
  final String? ourEntityPrefix;
  final DxFlags dxFlags;
  final bool showQsoNumbers;
  final ThemeData theme;
  final TextScaler textScaler;

  const _QsoListMetricsKey({
    required this.qsos,
    required this.log,
    required this.activityControls,
    required this.ourEntityPrefix,
    required this.dxFlags,
    required this.showQsoNumbers,
    required this.theme,
    required this.textScaler,
  });

  bool matches(_QsoListMetricsKey other) =>
      identical(qsos, other.qsos) &&
      identical(log, other.log) &&
      identical(activityControls, other.activityControls) &&
      ourEntityPrefix == other.ourEntityPrefix &&
      dxFlags == other.dxFlags &&
      showQsoNumbers == other.showQsoNumbers &&
      identical(theme, other.theme) &&
      textScaler == other.textScaler;
}

/// The Number column's value for each of [qsos]: a running count of real
/// contacts, so an event marker interspersed in the timeline, or a deleted
/// contact, doesn't consume a number — it repeats the one before it.
List<int> qsoListNumbers(List<Qso> qsos) {
  final numbers = List<int>.filled(qsos.length, 0);
  var runningNumber = 0;
  for (var i = 0; i < qsos.length; i++) {
    if (qsos[i].isRealContact) runningNumber++;
    numbers[i] = runningNumber;
  }
  return numbers;
}

/// The O(qsos) numbering/column-width/day-grouping pass — real text-layout
/// measurements, expensive enough on a long log to stutter if redone on
/// every rebuild. Called only on a cache miss; see `_QsoListState.build`'s
/// `_cachedMetrics`/`_cachedMetricsKey`.
_QsoListMetrics _computeMetrics({
  required BuildContext context,
  required List<Qso> qsos,
  required List<Qso>? log,
  required List<Map<String, dynamic>> activityControls,
  required String? ourEntityPrefix,
  required DxFlags dxFlags,
  required bool showQsoNumbers,
  required TextStyle mono,
  required TextStyle monoDim,
  required TextStyle callStyle,
}) {
  // Numbered, and below sized, over the whole log; only the day grouping
  // at the end is of the rows actually shown.
  final whole = log ?? qsos;
  final wholeNumbers = qsoListNumbers(whole);
  final List<int> numbers;
  if (log == null) {
    numbers = wholeNumbers;
  } else {
    final numberOf = {for (var i = 0; i < log.length; i++) log[i].uuid: wholeNumbers[i]};
    numbers = [for (final qso in qsos) numberOf[qso.uuid] ?? 0];
  }
  // `wholeNumbers` only ever increases, so its last value is its max — no
  // need to fold over it separately.
  final maxNumber = wholeNumbers.isEmpty ? 0 : wholeNumbers.last;

  // Column-sizing must cover every QSO that can actually render a row —
  // including deleted ones, which still show (struck-through) whenever the
  // "show deleted QSOs" menu toggle is on — not just `isRealContact` ones,
  // or a deleted QSO's callsign/frequency/mode can exceed what the columns
  // were sized for and wrap/truncate. One pass instead of separate
  // fold/map/toSet passes per column — cheap on its own (int/string
  // comparisons, not text layout), but there's no reason to walk the list
  // four times when once covers every column that needs a list-wide value.
  var longestCall = '';
  final freqsInKHz = <double?>[];
  final modesUsed = <String>{};
  var anyUnexpectedSideband = false;
  // Widest band shown in the freq/band column (only null-freq rows fall back
  // to the band) and widest exchange pair, so both columns reserve a
  // list-wide width and stay aligned even on rows that lack them (#354).
  var longestBand = '';
  var longestExchange = '';
  // Seeded at the floor, then widened for anything longer a QSO actually holds.
  var longestRst = _rstMinSample;
  // Only the single longest flag and longest state ever matter for
  // dxStateWidth below — tracking them here costs the same cheap
  // length comparison as longestCall, deferring the two (not N) actual
  // text-layout measurements to after this loop.
  var longestFlag = '';
  var longestState = '';
  // The refs column is per-row content, so what it reserves is the widest
  // any ONE row needs: per distinct type an icon plus its gap, and the "×N"
  // on the types that repeat. Tracked as a count of icons and the largest
  // repeat-count seen, so the two text measurements happen once after the
  // loop rather than per row.
  var mostRefIcons = 0;
  var largestRefCount = 0;
  // The duplicate-serial mark (docs/design/contests.md §5.8.1) and the notes
  // marker are badges in the same column, so they count toward the same
  // widest-row total instead of each holding a slot of its own list-wide.
  var mostBadges = 0;
  var anyRefOrConflict = false;
  for (final q in whole) {
    if (q.isEvent) continue;
    final refCounts = qsoRefCountsByType(q, activityControls);
    if (refCounts.length > mostRefIcons) mostRefIcons = refCounts.length;
    final badges = refCounts.length + (q.serialConflict ? 1 : 0) + (q.hasNotes ? 1 : 0);
    if (badges > mostBadges) mostBadges = badges;
    if (refCounts.isNotEmpty || q.serialConflict) anyRefOrConflict = true;
    for (final entry in refCounts.values) {
      if (entry.count > largestRefCount) largestRefCount = entry.count;
    }
    if (q.theirCall.length > longestCall.length) longestCall = q.theirCall;
    freqsInKHz.add(q.freq);
    // Band only renders when the QSO has no frequency (freqField below), and
    // a QSO with neither shows [_noBandLabel] there — which still has to be
    // measured, or the column collapses on a list made only of those.
    if (q.freq == null) {
      final label = q.band ?? _noBandLabel;
      if (label.length > longestBand.length) longestBand = label;
    }
    final exchange = _exchangePair(q, switchSentRcvd: false);
    if (exchange.length > longestExchange.length) longestExchange = exchange;
    final rstPair = '${q.sentRST ?? ''} ${q.receivedRST ?? ''}';
    if (rstPair.length > longestRst.length) longestRst = rstPair;
    // The DISPLAYED mode, so an operation that worked USB on 20m and LSB on
    // 40m counts as one mode and doesn't grow a Mode column repeating "SSB".
    final mode = displayMode(q.mode, freqKHz: q.freq, band: q.band);
    if (mode != null) modesUsed.add(mode);
    if (isUnexpectedSideband(q.mode, freqKHz: q.freq, band: q.band)) anyUnexpectedSideband = true;
    final dxState = _dxStateContentFor(q, ourEntityPrefix, dxFlags);
    if (dxState == null) {
      // no-op — nothing to measure for this row
    } else if (dxState.isFlag) {
      if (dxState.text.length > longestFlag.length) longestFlag = dxState.text;
    } else if (dxState.text.length > longestState.length) {
      longestState = dxState.text;
    }
  }

  // Column widths are computed once for the whole list so every row lines
  // up, per the issue: "wide enough to fit the largest number"/"longest
  // callsign in all qsos" — DX/State and the Name column right after it
  // are no exception (ham2k/halo-dist#186): a QSO with neither a flag
  // nor a state must still reserve that column's width, or Name starts at
  // a different x position on every row depending on its neighbors.
  // `formatNumber` adds locale thousands separators ("1,252"), wider
  // than the bare digits — measuring those instead of the string that
  // actually renders is what let a 4-digit count wrap onto a second
  // line (HALO-258).
  final numberWidth = showQsoNumbers ? textWidth(context, formatNumber(maxNumber), mono) : 0.0;
  final callsignWidth = longestCall.isEmpty ? 0.0 : textWidth(context, longestCall, callStyle);
  // Names the size the glyph actually paints at — qso_list's flagGlyph call
  // takes the default, so measuring emojiStyle()'s own default instead would
  // agree only by coincidence.
  final flagWidth = longestFlag.isEmpty ? 0.0 : textWidth(context, longestFlag, emojiStyle(fontSize: flagGlyphDefaultFontSize));
  final stateWidth = longestState.isEmpty ? 0.0 : textWidth(context, longestState, monoDim);
  final dxStateWidth = flagWidth > stateWidth ? flagWidth : stateWidth;

  // "decide how many digits to display based on all the qsos in the
  // operation" — one Hz precision for the whole list, not per row.
  final hzDigits = hzDigitsNeeded(freqsInKHz);
  // The Mode column only earns its place when the operation actually mixes
  // modes — otherwise every row would repeat the same value.
  //
  // A sideband this place does not run earns it on its own, whatever the count.
  // The whole-operation case is the one worth catching — a rig left in LSB on
  // 20m, or an import that put USB on every 40m contact — and it is exactly
  // the case a count cannot see: every row displays that one sideband, so the
  // column would be dropped and the warning with it.
  final usesMultipleModes = modesUsed.length > 1 || anyUnexpectedSideband;

  // Reserve the freq/band column at a fixed list-wide width so a QSO with
  // neither still holds it open and Mode/Callsign line up on every row
  // (#354). Freq strings depend on hzDigits, so measure after it's known;
  // mono means string length tracks width, and measuring the full string in
  // regular `mono` (the Hz part actually renders smaller) only over-reserves
  // a hair, which is safe. Bands (null-freq rows) compete for the same width.
  var longestFreqOrBand = longestBand;
  for (final f in freqsInKHz) {
    if (f == null) continue;
    final parts = freqDisplayParts(f, hzDigits: hzDigits);
    // Exactly what the row draws, grouping and the sub-MHz case included —
    // this measures the column, so anything narrower here under-reserves it.
    final decimal = NumberFormatting.instance.decimalSeparator;
    final mhzValue = int.parse(parts.mhz);
    final whole = mhzValue > 0 ? '${groupDigits(parts.mhz)}${NumberFormatting.instance.groupingSeparator}${parts.khz}' : int.parse(parts.khz).toString();
    final s = parts.hz != null ? '$whole$decimal${parts.hz}' : whole;
    if (s.length > longestFreqOrBand.length) longestFreqOrBand = s;
  }
  final freqWidth = longestFreqOrBand.isEmpty ? 0.0 : textWidth(context, longestFreqOrBand, mono);
  final rstWidth = textWidth(context, longestRst, monoDim);
  // The exchange column (after the signal reports) reserves width only
  // when some QSO actually carries an exchange, like DX/State above (#354).
  final exchangeWidth = longestExchange.isEmpty ? 0.0 : textWidth(context, longestExchange, monoDim);
  // Measured from the largest count actually present, so a three-figure
  // repeat is budgeted at its real width rather than a two-digit sample.
  // Reserved for EVERY icon on the widest row rather than only the ones
  // that repeat: over-reserving costs the exchange column a few pixels,
  // under-reserving costs a row that overflows.
  final refCountWidth = largestRefCount > 1 ? textWidth(context, '×$largestRefCount', mono.copyWith(fontSize: 11)) : 0.0;
  // The "×N" is reserved per REF icon on the row with the most of those,
  // which need not be the row with the most badges: the sum bounds both.
  final refsWidth = mostBadges == 0 ? 0.0 : _columnGap + mostBadges * (qsoRefIconWidth + qsoRefIconGap) + mostRefIcons * refCountWidth;

  // `qsos` arrives oldest-first (QsosRepository.watchForOperation orders
  // by startAtMillis) — bucket it into consecutive UTC-day runs so each
  // bucket becomes one pinned header + its own sliver of rows. A plain
  // linear scan works because same-day QSOs are already contiguous; no
  // need to build then sort a day->indices map.
  final dayKeys = <int>[];
  final dayGroups = <List<int>>[];
  for (var i = 0; i < qsos.length; i++) {
    final millis = qsos[i].startAtMillis ?? 0;
    final dayKey = millis - (millis % _dayInMillis);
    if (dayKeys.isEmpty || dayKeys.last != dayKey) {
      dayKeys.add(dayKey);
      dayGroups.add([]);
    }
    dayGroups.last.add(i);
  }

  return _QsoListMetrics(
    numbers: numbers,
    numberWidth: numberWidth,
    callsignWidth: callsignWidth,
    dxStateWidth: dxStateWidth,
    freqWidth: freqWidth,
    rstWidth: rstWidth,
    exchangeWidth: exchangeWidth,
    refsWidth: refsWidth,
    refsAreNotesOnly: !anyRefOrConflict,
    hzDigits: hzDigits,
    usesMultipleModes: usesMultipleModes,
    dayKeys: dayKeys,
    dayGroups: dayGroups,
  );
}
