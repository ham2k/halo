// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `ExtensionInfo.searchRank` decides both what the Extensions panel lists
// and whether the activity search offers "enable this?" for an extension the
// user is clearly looking for. Missing a match there is the costly direction:
// a disabled activity would look like it simply doesn't exist. Hence the
// breadth (key, name, description, keywords, either locale) — and the one
// deliberate non-match, an empty query, which means "show everything" at the
// call site rather than "everything matches".

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_relevance.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';

void main() {
  const info = ExtensionInfo(
    key: 'sota',
    file: 'sota.js',
    core: false,
    name: 'Summits on the Air',
    description: 'Activate and chase mountain summits',
    keywords: ['mountain', 'summit'],
    translations: {
      'es': {
        'name': 'Cumbres en el Aire',
        'description': 'Activa y caza cumbres',
        'keywords': ['montaña'],
      },
    },
  );

  // Whether the search shows it at all; where it ranks is the group below.
  bool matches(String query, {required String locale}) => info.searchRank(query, locale: locale) != null;

  test('matches the extension key, which is what a `sota:` scope types', () {
    expect(matches('sota', locale: 'en'), isTrue);
  });

  test('matches on name and description, case-insensitively', () {
    expect(matches('summits on the air', locale: 'en'), isTrue);
    expect(matches('SUMMITS', locale: 'en'), isTrue);
    expect(matches('chase mountain', locale: 'en'), isTrue);
  });

  test('matches declared keywords — the manifest\'s own search terms', () {
    expect(matches('summit', locale: 'en'), isTrue);
  });

  test('matches a partial word, so a half-typed search still finds it', () {
    expect(matches('sum', locale: 'en'), isTrue);
  });

  group('locales', () {
    test('the localized name and keywords match in that locale', () {
      expect(matches('cumbres', locale: 'es'), isTrue);
      expect(matches('montaña', locale: 'es'), isTrue);
    });

    test('English still matches while in another locale — either spelling finds it', () {
      expect(matches('summits', locale: 'es'), isTrue);
    });

    test('a localized term does not match under an unrelated locale', () {
      expect(matches('cumbres', locale: 'en'), isFalse);
    });
  });

  test('an empty query matches nothing — "list everything" is the caller\'s call', () {
    expect(matches('', locale: 'en'), isFalse);
  });

  test('unrelated text does not match', () {
    expect(matches('parks', locale: 'en'), isFalse);
  });

  group('searchRank', () {
    // Matching decides WHETHER a row shows; the rank decides where, and with
    // every SSB contest mentioning "ssb" in its blurb, the order is what
    // makes "ss" find Sweepstakes at all.
    ExtensionInfo ext(String key, String name, {String? description, List<String> keywords = const [], ExtensionRelevance? relevance}) =>
        ExtensionInfo(key: key, file: '$key.js', core: false, name: name, description: description, keywords: keywords, relevance: relevance);

    final sweepstakes = ext('ham2k-arrl-ss', 'ARRL Sweepstakes', description: 'The November domestic contest', keywords: ['contest', 'sweepstakes', 'ss']);
    final sprint = ext('ki2d-ssb-sprint', 'NA SSB Sprint', description: 'A short phone sprint', keywords: ['sprint', 'ssb']);
    final pwt = ext('ki2d-pwt', 'Phone Weekly Test', description: 'A weekly hour of SSB', keywords: ['pwt', 'ssb', 'phone']);
    final cqww = ext('ham2k-cqww', 'CQ World Wide', description: 'CW, SSB and RTTY weekends', keywords: ['cqww']);

    test('tiers: exact, then keyword, then name, then description', () {
      expect(sweepstakes.searchRank('ss', locale: 'en'), 0, reason: 'its own keyword, typed in full');
      expect(pwt.searchRank('ss', locale: 'en'), 1, reason: 'a keyword starting with it');

      expect(sweepstakes.searchRank('arrl swe', locale: 'en'), 2, reason: 'the name, and nothing above it');
      expect(cqww.searchRank('rtty', locale: 'en'), 3, reason: 'the description alone');
      expect(cqww.searchRank('pota', locale: 'en'), isNull);
    });

    test('a word of the key ranks with the name, never with the keywords', () {
      // Its author never chose it as a search term: "ham" would otherwise
      // lift every ham2k- extension above one actually named "Ham".
      final ham = ext('aa-hamfest', 'Ham Radio Fest');
      expect(sweepstakes.searchRank('arrl', locale: 'en'), 2);
      expect(sweepstakes.searchRank('ham', locale: 'en'), 2);
      expect(ham.searchRank('ham', locale: 'en'), 2);
    });

    test('the whole name, or the whole key, is as exact as a keyword', () {
      expect(cqww.searchRank('cq world wide', locale: 'en'), 0);
      expect(sprint.searchRank('KI2D-SSB-SPRINT', locale: 'en'), 0);
    });

    test('"ss" offers Sweepstakes before everything that merely says SSB', () {
      final ranked = rankSearchHits(
        [cqww, pwt, sprint, sweepstakes],
        (e) => e.searchRank('ss', locale: 'en'),
        operator: null,
        now: DateTime.utc(2026, 11, 8),
        locale: 'en',
      );
      expect(ranked.map((e) => e.key), ['ham2k-arrl-ss', 'ki2d-ssb-sprint', 'ki2d-pwt', 'ham2k-cqww']);
    });

    test('relevance orders the hits of one tier, and never lifts one across tiers', () {
      final now = DateTime.utc(2026, 11, 8);
      const kilo = OperatorGeo(entityPrefix: 'K');
      final texas = ext(
        'tx',
        'Texas QSO Party',
        keywords: ['qso party'],
        relevance: const ExtensionRelevance(entities: ['K']),
      );
      final soon = ext(
        'mi',
        'Michigan QSO Party',
        keywords: ['qso party'],
        relevance: const ExtensionRelevance(entities: ['VE'], dates: ['2026-11-10']),
      );
      final vermont = ext(
        'vt',
        'Vermont QSO Party',
        keywords: ['qso party'],
        relevance: const ExtensionRelevance(entities: ['VE']),
      );
      final blurb = ext(
        'ww',
        'Worldwide',
        description: 'Like a QSO party, but everywhere',
        relevance: const ExtensionRelevance(entities: ['K'], dates: ['2026-11-08']),
      );
      final ranked = rankSearchHits(
        [vermont, blurb, texas, soon],
        (e) => e.searchRank('qso party', locale: 'en'),
        operator: kilo,
        now: now,
        locale: 'en',
      );
      expect(ranked.map((e) => e.key), ['mi', 'tx', 'vt', 'ww']);
    });
  });
}
