// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Subsequence ("fuzzy") matching, the style VS Code's Ctrl+P filename search
// made familiar: every character typed must appear in the target IN ORDER, but
// not next to each other — so `zrbt` finds "Avoid Zero Beat" and `dfrcw` finds
// `defaultReportCW`.
//
// Each typed WORD is anchored, though: its first character must land on the
// start of a word in the target (see [fuzzyQueryWordStarts]). Without that,
// `and` finds "Bands" by the run buried in its middle, which is never what anyone
// typing a word means.
//
// Being a subsequence is cheap to satisfy, so the SCORE is what does the real
// work. Four things earn points, and they are what makes the results feel
// right rather than merely correct:
//
//   - characters matched next to each other, so a typed run beats the same
//     letters scattered across the name;
//   - a match at a word boundary — a camelCase hump, or the start of a word
//     after a space/underscore/dash — since that is where people aim;
//   - a match at the very start of the name;
//   - a short target, all else equal, so `report` outranks `reportFT8` for
//     the query "report".
//
// Gaps cost points. That, plus the boundary bonus, is what keeps `set` from
// ranking "Show Deleted QSOs" (s…e…t scattered) anywhere near "Sent".
//
// Deliberately NOT used on descriptions (see settings_catalog.dart): a
// subsequence of a whole English sentence matches almost anything, which is
// why VS Code fuzzy-matches file NAMES and not file contents.

/// Points for each matched character — the floor under every match, so a
/// longer query always outscores a shorter one that matched equally well.
const _scoreMatch = 16;

/// Added when a character matches immediately after the previous one did.
const _bonusConsecutive = 8;

/// Added for a match at the start of a word: index 0, or after any
/// non-alphanumeric.
const _bonusBoundary = 10;

/// Added for a match on a camelCase hump, or on the first digit of a run.
/// Lower than [_bonusBoundary] — a hump is a weaker signal than a real
/// separator, but still where a name's parts begin.
const _bonusCamel = 8;

/// Charged for every target character skipped between matches. Small, so a
/// well-placed match can still outweigh a long name.
const _penaltyGap = -2;

/// Charged per target character skipped BEFORE the first match, capped by
/// [_maxLeadingPenalty].
///
/// Without it, where a match starts costs nothing, and a query is drawn to
/// whichever name happens to contain it most tightly rather than to the name
/// it begins: without it `lt` ranks "defau**lt**Report" (a consecutive run
/// buried five characters in) above "**L**ef**t**ie Mode", which is the
/// setting anyone typing `lt` actually means.
const _penaltyLeadingGap = -3;

/// The ceiling on [_penaltyLeadingGap]'s total. A long label should not be
/// unreachable by a word near its end — `name` still has to find
/// "Use Compact File Names" — so the penalty distinguishes early matches from
/// late ones without ruling the late ones out.
const _maxLeadingPenalty = -24;

/// Every real score is multiplied by this before the target's length is
/// subtracted, so length decides between otherwise-equal matches without ever
/// competing with a bonus. Any value comfortably above the longest name the
/// app declares would do.
const _lengthTieBreakerScale = 64;

/// Whether two scores represent the SAME quality of match, differing only by
/// the length tie-breaker.
///
/// Exact equality is almost unreachable: the final score subtracts the
/// target's length, so two settings tie only if their names are the same
/// length as well as matched the same way. A caller that needs to know "did
/// this query really pick one setting out?" — as the commands do before
/// writing a value — has to ask this instead, or it treats a one-point
/// accident as a decision.
bool fuzzyScoresTie(int a, int b) => (a - b).abs() < _lengthTieBreakerScale;

/// "Worse than any real score", used to mark cells no match can reach.
///
/// A plain literal, NEVER a shift. On the web `int` is a JS double and `<<`
/// yields an unsigned 32-bit result, so `-1 << 30` is +3221225472 there rather
/// than the negative sentinel it is natively — every real score then compares
/// as smaller than "negative infinity", every lookup returns no match, and the
/// settings search silently answers "nothing matches" for everything. Native
/// tests cannot see it, which is why `scripts/test.sh` re-runs this file's
/// tests under `flutter test --platform chrome`. (CI shards `flutter test`
/// itself and does not invoke that script, so the browser pass is part of the
/// local pre-merge gate only.)
///
/// Real scores are in the low thousands, so this only has to be comfortably
/// below them.
const _negInf = -1073741824;

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
bool _isUpper(int c) => c >= 0x41 && c <= 0x5a;
bool _isLower(int c) => c >= 0x61 && c <= 0x7a;
bool _isAlnum(int c) => _isDigit(c) || _isUpper(c) || _isLower(c);

/// [text] reduced to the characters a query is compared against: lowercase
/// letters and digits, everything else dropped. Applied to the QUERY only —
/// targets keep their punctuation, because that is where the word boundaries
/// this scores by actually live.
String normalizeFuzzyQuery(String text) => text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// The positions in [normalizeFuzzyQuery]'s result for [text] where a typed
/// word begins — the characters [fuzzyMatchScore] anchors to word starts in
/// the target. Must drop exactly the characters [normalizeFuzzyQuery] drops,
/// or the positions point at the wrong letters.
Set<int> fuzzyQueryWordStarts(String text) {
  final starts = <int>{};
  var index = 0;
  var inWord = false;
  for (final c in text.toLowerCase().codeUnits) {
    if (_isDigit(c) || _isLower(c)) {
      if (!inWord) starts.add(index);
      index++;
      inWord = true;
    } else {
      inWord = false;
    }
  }
  return starts;
}

/// How well [target] answers [query], or null when [query] isn't a
/// subsequence of it at all. Higher is better; scores are only comparable
/// between candidates for the SAME query.
///
/// [query] must already be normalized by [normalizeFuzzyQuery]. An empty
/// query scores 0 against everything — "no filter", not "no match".
///
/// The query characters at [wordStarts] (from [fuzzyQueryWordStarts]) only
/// match at the start of a word in [target] — index 0, after a separator, or
/// on a camelCase hump. The first character is always anchored.
int? fuzzyMatchScore(String query, String target, {Set<int> wordStarts = const {0}}) {
  if (query.isEmpty) return 0;
  final n = target.length;
  final m = query.length;
  if (m > n) return null;

  final lower = target.toLowerCase();

  // Cheap reject before building the table: most candidates fail here, and a
  // greedy left-to-right walk is enough to prove no subsequence exists.
  var q = 0;
  for (var j = 0; j < n && q < m; j++) {
    if (lower.codeUnitAt(j) == query.codeUnitAt(q)) q++;
  }
  if (q < m) return null;

  final bonus = List<int>.filled(n, 0);
  for (var j = 0; j < n; j++) {
    final c = target.codeUnitAt(j);
    if (!_isAlnum(c)) continue;
    final prev = j == 0 ? null : target.codeUnitAt(j - 1);
    if (prev == null || !_isAlnum(prev)) {
      bonus[j] = _bonusBoundary;
    } else if ((_isUpper(c) && _isLower(prev)) || (_isDigit(c) && !_isDigit(prev))) {
      bonus[j] = _bonusCamel;
    }
  }

  // Two rows per query character, in the shape fzy uses:
  //   ending[j] — best score for query[0..i] whose LAST match is at target[j],
  //               which is what a consecutive run has to build on;
  //   best[j]   — best score for query[0..i] anywhere within target[0..j].
  // Keeping them apart is the whole trick: without `ending`, there is no way
  // to know whether extending a match continues a run or starts a new one.
  var prevEnding = List<int>.filled(n, _negInf);
  var prevBest = List<int>.filled(n, _negInf);

  for (var i = 0; i < m; i++) {
    final ending = List<int>.filled(n, _negInf);
    final best = List<int>.filled(n, _negInf);
    var runningBest = _negInf;
    for (var j = 0; j < n; j++) {
      if (lower.codeUnitAt(j) == query.codeUnitAt(i) && (bonus[j] > 0 || (i != 0 && !wordStarts.contains(i)))) {
        if (i == 0) {
          final leading = j * _penaltyLeadingGap;
          ending[j] = _scoreMatch + bonus[j] + (leading < _maxLeadingPenalty ? _maxLeadingPenalty : leading);
        } else if (j > 0) {
          final startingRun = prevBest[j - 1] == _negInf ? _negInf : prevBest[j - 1] + _scoreMatch + bonus[j];
          final continuingRun = prevEnding[j - 1] == _negInf ? _negInf : prevEnding[j - 1] + _scoreMatch + _bonusConsecutive;
          ending[j] = startingRun > continuingRun ? startingRun : continuingRun;
        }
      }
      // Either the best match ends here, or it ended earlier and this
      // character was skipped over.
      final skipped = runningBest == _negInf ? _negInf : runningBest + _penaltyGap;
      best[j] = ending[j] > skipped ? ending[j] : skipped;
      runningBest = best[j];
    }
    prevEnding = ending;
    prevBest = best;
  }

  // The best score among the places the LAST query character could land —
  // deliberately not `prevBest[n - 1]`, which carries a gap penalty for every
  // target character after the match ends. Charging for the tail would score
  // `name` worse against "Named Thing" than against "Use Compact File Names",
  // since the better match has more name left over after it. Length is
  // already accounted for, once, below.
  var score = _negInf;
  for (var j = 0; j < n; j++) {
    if (prevEnding[j] > score) score = prevEnding[j];
  }
  if (score == _negInf) return null;
  // Shorter targets win TIES: with the same characters matched the same way,
  // the name with less left over is the more likely one meant.
  //
  // Scaled up first so length only ever breaks a near-tie. Subtracting the
  // raw length would let it outweigh a word-boundary bonus outright — a short
  // name with the query buried mid-word would beat a long one matched right on
  // its camelCase humps, which is backwards.
  return score * _lengthTieBreakerScale - n;
}
