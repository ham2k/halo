// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HALO-151: the subsequence scorer behind both settings searches.
//
// Being a subsequence is easy to satisfy, so almost every assertion here is
// about the ORDERING rather than about what matches — the scorer's job is to
// make the right answer come first, and a scorer that ranked matches
// arbitrarily would still "work" by every yes/no test.

import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/settings/settings_fuzzy.dart';

/// Scores [query] against [target], normalizing and anchoring the query the
/// way callers do.
int? score(String query, String target) => fuzzyMatchScore(normalizeFuzzyQuery(query), target, wordStarts: fuzzyQueryWordStarts(query));

/// Asserts [better] outranks [worse] for [query].
void expectRanksAbove(String query, String better, String worse) {
  final a = score(query, better);
  final b = score(query, worse);
  expect(a, isNotNull, reason: '"$query" should match "$better"');
  expect(b, isNotNull, reason: '"$query" should match "$worse"');
  expect(a!, greaterThan(b!), reason: '"$query" should rank "$better" above "$worse"');
}

void main() {
  group('what matches', () {
    test('characters need only appear in order, not together', () {
      expect(score('zrbt', 'Avoid Zero Beat'), isNotNull);
      expect(score('dfrcw', 'defaultReportCW'), isNotNull);
      expect(score('sgf', 'showGridField'), isNotNull);
    });

    test('order is the whole constraint — the same letters shuffled do not match', () {
      expect(score('tbz', 'Avoid Zero Beat'), isNull);
      expect(score('wcfdr', 'defaultReportCW'), isNull);
    });

    test('a character not present at all fails the match', () {
      expect(score('zebra', 'Avoid Zero Beat'), isNull);
    });

    test('case and punctuation in the query are ignored', () {
      for (final query in ['ZERO BEAT', 'zero-beat', 'Zero Beat']) {
        expect(score(query, 'Avoid Zero Beat'), isNotNull, reason: query);
      }
    });

    test('an empty query matches everything, scoring nothing', () {
      expect(score('', 'anything'), 0);
    });

    test('a query longer than the target cannot match', () {
      expect(score('abcdefghij', 'abc'), isNull);
    });
  });

  // The three targets-of-equal-length comparisons below are deliberately
  // synthetic. A shorter target scores higher all else being equal, so
  // comparing realistic names of different lengths would test the length
  // tie-breaker rather than the property named in the test.
  group('what ranks higher', () {
    test('a contiguous run beats the same letters scattered', () {
      expectRanksAbove('sent', 'sentaaaaaaaa', 'saeanataaaaa');
    });

    test('a typed word buried inside a target word does not match at all', () {
      // The complaint this exists for: SET AND resolved to Preferred Bands.
      expect(score('and', 'Preferred Bands'), isNull);
      expect(score('name', 'xxnameaaaaaa'), isNull);
      expect(score('name', 'name aaaaaaa'), isNotNull);
    });

    test('every typed word is anchored, not just the first', () {
      expect(score('zero beat', 'Avoid Zero Beat'), isNotNull);
      // "eat" is the end of Beat, not a word of its own.
      expect(score('zero eat', 'Avoid Zero Beat'), isNull);
    });

    test('only what starts a word is anchored — the rest may scatter', () {
      // z and b land on word starts; r and t are free to skip ahead.
      expect(score('zrbt', 'Avoid Zero Beat'), isNotNull);
    });

    test('a camelCase hump counts as a word start', () {
      // The same letters in the same positions — only the humps differ, and
      // without them `g` lands mid-word, where a typed word may not start.
      expect(score('gf', 'showGridField'), isNotNull);
      expect(score('gf', 'showgridfield'), isNull);
    });

    test('the shorter of two otherwise equal targets wins', () {
      expectRanksAbove('report', 'Default Report', 'Default Report CW');
    });

    test('a match at the start beats a tighter one buried further in', () {
      // `lt` must reach "Leftie Mode", where the two letters are split,
      // rather than `reportLt`, where they sit together but six characters
      // in. Both start on a word (`reportLt` on its hump), and a CONSECUTIVE
      // run is worth a lot, so only charging for the characters skipped
      // before the first match keeps early matches ahead of tight late ones.
      expectRanksAbove('lt', 'leftieMode', 'reportLt');
    });

    test('the leading-gap charge is capped, so a late word is still reachable', () {
      // "Names" is 15 characters into this label. It must still match — the
      // penalty separates early from late, it does not rule late out.
      expect(score('name', 'Use Compact File Names'), isNotNull);
    });

    test('a full name beats a longer one that merely contains it', () {
      expectRanksAbove('theme', 'theme', 'themeSelectionOverride');
    });

    test('matching more of the query outscores matching less of it', () {
      // Guards the base per-character reward: without it, a one-character
      // query could outscore a five-character one against the same target.
      final short = score('d', 'defaultReport')!;
      final long = score('default', 'defaultReport')!;
      expect(long, greaterThan(short));
    });
  });

  group('scores are only comparable within one query', () {
    test('a longer query scores higher against the same target', () {
      // Documents the trap that made the naive name/value split wrong: raw
      // scores grow with query length, so comparing them ACROSS queries
      // always favours the longer one. settings_command.dart divides by query
      // length for exactly this reason.
      expect(score('zerobeatn', 'Avoid Zero-Beating on Spots')!, greaterThan(score('zerobeat', 'Avoid Zero-Beating on Spots')!));
    });
  });
}
