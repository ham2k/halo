// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `ExtensionRelevance` decides whether an extension is relevant to the
// operator's own callsign. Its geographic half is the twin of the notice
// engine's geo filters, and the traps are the same ones: a list that gates
// when it should not, a key that widens the audience when it should narrow
// it, and an unknown operator that slips through a gate meant to fail closed.
//
// `dates` and `interests` bring a trap of their own: they are hints, so
// folding either into the match would turn ranking into hiding.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extension_relevance.dart';
import 'package:ham2k_logger/services/extension_service.dart';

void main() {
  group('validate', () {
    test('every valid shape passes, in either case', () {
      for (final relevance in [
        <String, Object?>{},
        {
          'entities': ['K', 'VE', '*4U1U', 'ce'],
        },
        {
          'countries': ['us', 'CL'],
        },
        {
          'continents': ['NA', 'sa'],
        },
        {
          'ituRegions': [1, 2, 3],
        },
        {
          'ituRegions': [2.0],
        },
        {
          'dates': ['2026-09-19', '2028-02-29'],
        },
        {
          'interests': ['cw', 'vhf', 'satellite'],
        },
        {'entities': [], 'countries': [], 'continents': [], 'ituRegions': [], 'dates': [], 'interests': []},
      ]) {
        expect(ExtensionRelevance.validate(relevance), isEmpty, reason: '$relevance');
      }
    });

    test('a shape the reader would misread, and a value nobody can match, are each named', () {
      // Shape: the reader takes what it cannot parse as "does not gate", so
      // a misspelt key is a Chilean extension for the whole world.
      // Vocabulary: "North America", region 7 or an interest spelled `CW`
      // match no operator, so the extension ranks last for everyone and
      // nothing says why.
      final bad = <(Object?, Pattern)>[
        ('CE', "'relevance' must be an object"),
        ([], "'relevance' must be an object"),
        (
          {
            'entity': ['CE'],
          },
          "unknown key 'entity'",
        ),
        ({'geo': {}}, "unknown key 'geo'"),
        ({'entities': 'CE'}, "'relevance.entities' must be a list"),
        // JSON null is a value the author wrote. Read as an absent key it
        // passes here and is refused by the packer, and the extension
        // installs as worldwide — the one input the twins would disagree on.
        ({'entities': null}, "'relevance.entities' must be a list"),
        ({'dates': null}, "'relevance.dates' must be a list"),
        (
          {
            'entities': [''],
          },
          'not a non-empty string',
        ),
        (
          {
            'entities': [7],
          },
          'not a non-empty string',
        ),
        (
          {
            'entities': ['C E'],
          },
          'not a DXCC entity prefix',
        ),
        (
          {
            'countries': ['USA'],
          },
          'not a two-letter ISO country code',
        ),
        (
          {
            'continents': ['North America'],
          },
          'not a continent (AF AS EU NA OC SA AN)',
        ),
        (
          {
            'continents': ['EUR'],
          },
          'not a continent',
        ),
        (
          {
            'ituRegions': ['2'],
          },
          'not an ITU region (1, 2, 3)',
        ),
        (
          {
            'ituRegions': [7],
          },
          'not an ITU region',
        ),
        (
          {
            'ituRegions': [2.5],
          },
          'not an ITU region',
        ),
        (
          {
            'dates': ['19 September 2026'],
          },
          'not a YYYY-MM-DD date',
        ),
        (
          {
            'dates': ['2026-9-19'],
          },
          'not a YYYY-MM-DD date',
        ),
        (
          {
            'dates': [20260919],
          },
          'not a non-empty string',
        ),
        (
          {
            'interests': ['CW'],
          },
          'not an interest',
        ),
        (
          {
            'interests': ['morse'],
          },
          'not an interest (cw phone digital hf vhf uhf microwave satellite portable qrp)',
        ),
      ];
      for (final (relevance, message) in bad) {
        final problems = ExtensionRelevance.validate(relevance);
        expect(problems, isNotEmpty, reason: '$relevance');
        expect(problems.join(' | '), contains(message), reason: '$relevance');
      }
      // Every problem, not the first: an author fixes the manifest once.
      expect(
        ExtensionRelevance.validate({
          'entities': [''],
          'continents': ['EUR'],
          'bogus': [],
        }),
        hasLength(3),
      );
    });

    test('a date that only exists once the calendar rolls it over is refused', () {
      // `DateTime.utc(2026, 2, 31)` is 3 March, so a pattern check alone
      // accepts the manifest and then silently means a different day. Every
      // one of these is a plausible typo for a real event date.
      for (final date in ['2026-02-31', '2026-13-01', '2026-00-10', '2026-04-31', '2026-09-00']) {
        expect(
          ExtensionRelevance.validate({
            'dates': [date],
          }).join(' | '),
          contains('not a day that exists'),
          reason: date,
        );
      }
      // The leap day itself is a real date, and 2027 has none.
      expect(
        ExtensionRelevance.validate({
          'dates': ['2028-02-29'],
        }),
        isEmpty,
      );
      expect(
        ExtensionRelevance.validate({
          'dates': ['2027-02-29'],
        }).join(' | '),
        contains('not a day that exists'),
      );
    });

    test('a year under four figures is refused, because the packer cannot represent it', () {
      // `\d{4}` admits `0050-01-01`. The packer builds its date with
      // `Date.UTC`, which reads a year under 100 as 19xx, so it would refuse
      // that while this accepted it. Neither answer is worth having, and the
      // rule that keeps the twins equal is the one both can state.
      for (final date in ['0050-01-01', '0099-12-31', '0000-01-01']) {
        expect(
          ExtensionRelevance.validate({
            'dates': [date],
          }).join(' | '),
          contains('not a year an event could fall in'),
          reason: date,
        );
      }
      expect(
        ExtensionRelevance.validate({
          'dates': ['1000-01-01'],
        }),
        isEmpty,
      );
    });

    test('the keys and the vocabulary are the packer\'s, literal for literal', () {
      // Two authorities, one format: extensions/tools/h2kext.mjs refuses a
      // manifest at pack time and ExtensionRelevance.validate refuses it at
      // the door. A seventh key or a new interest added to one of them makes
      // a bundle the packer accepts and the app refuses (or the reverse),
      // which nothing else would catch — so this reads the packer's source
      // and holds the two literal lists equal until the other follows.
      //
      // The VOCABULARY is all this pins. The rules around it — an explicit
      // null, a rolled-over calendar day, a year the packer cannot represent
      // — are held by the case tables above, which the JS suite mirrors row
      // for row.
      final source = File('../extensions/tools/h2kext.mjs').readAsStringSync();
      List<String> literal(String name) {
        final match = RegExp('$name = \\[([^\\]]*)\\]').firstMatch(source);
        expect(match, isNotNull, reason: '$name not found in h2kext.mjs');
        return [for (final m in RegExp(r'''['"]([^'"]*)['"]|(\d+)''').allMatches(match!.group(1)!)) m.group(1) ?? m.group(2)!];
      }

      expect(literal('RELEVANCE_KEYS'), ExtensionRelevance.relevanceKeys);
      expect(literal('GEO_CONTINENTS'), ExtensionRelevance.continentCodes);
      expect(literal('GEO_ITU_REGIONS'), ExtensionRelevance.ituRegionCodes.map((r) => '$r').toList());
      expect(literal('RELEVANCE_INTERESTS'), ExtensionRelevance.interestCodes);
    });
  });

  group('matches', () {
    test('no list at all is worldwide: every operator, known or not', () {
      const relevance = ExtensionRelevance();
      expect(relevance.isWorldwide, isTrue);
      expect(relevance.matches(entityPrefix: 'K', countryCode: 'us', continent: 'NA', ituRegion: 2), isTrue);
      // Fail-closed applies to a GATED list only: a worldwide extension must
      // not vanish for an operator whose callsign is not yet known.
      expect(relevance.matches(), isTrue);
    });

    test('one list gates on its own value alone', () {
      const relevance = ExtensionRelevance(entities: ['K', 'VE']);
      expect(relevance.matches(entityPrefix: 'VE'), isTrue);
      expect(relevance.matches(entityPrefix: 'G'), isFalse);
      // The values no list gates on are not consulted, unknown or not.
      expect(relevance.matches(entityPrefix: 'K', countryCode: null, continent: null, ituRegion: null), isTrue);
    });

    test('lists AND across keys — mutated to OR, half the world would qualify', () {
      const relevance = ExtensionRelevance(entities: ['K'], continents: ['EU']);
      expect(relevance.matches(entityPrefix: 'K', continent: 'NA'), isFalse);
      expect(relevance.matches(entityPrefix: 'G', continent: 'EU'), isFalse);
      expect(relevance.matches(entityPrefix: 'K', continent: 'EU'), isTrue);
    });

    test('dates and interests rank, they do not gate', () {
      // The whole reason they sit outside the match: a QSO party held on two
      // days a year is still a Texan's extension in March, and an operator
      // the app knows no interests for is not one to hide a CW event from.
      // Fold either in and a hint becomes a filter, silently.
      const dated = ExtensionRelevance(dates: ['2026-09-19'], interests: ['cw']);
      expect(dated.isWorldwide, isTrue);
      expect(dated.matches(), isTrue);
      expect(dated.matches(entityPrefix: 'K', countryCode: 'us', continent: 'NA', ituRegion: 2), isTrue);

      const gated = ExtensionRelevance(countries: ['us'], dates: ['2026-09-19'], interests: ['cw']);
      expect(gated.isWorldwide, isFalse);
      expect(gated.matches(countryCode: 'us'), isTrue, reason: 'the geography decides it alone');
      expect(gated.matches(countryCode: 'cl'), isFalse);
    });

    test('case is the matcher\'s job, folded the way notices fold it', () {
      // Entities and continents compare uppercased, countries lowercased —
      // the forms FlagsService derives. An author who wrote `ce` or `Na` must
      // still reach their operators; the operator's form never changes.
      const relevance = ExtensionRelevance(entities: ['ce'], countries: ['CL'], continents: ['sa']);
      expect(relevance.matches(entityPrefix: 'CE', countryCode: 'cl', continent: 'SA'), isTrue);
      expect(relevance.matches(entityPrefix: 'ce', countryCode: 'cl', continent: 'SA'), isFalse);
    });

    test('a gated list fails closed when the operator\'s own value is unknown', () {
      // The notices rule: an operator nothing is known about is not one the
      // author addressed. Countries and ITU regions are the two that go
      // unknown in practice — a dev-fixture guess carries neither.
      expect(const ExtensionRelevance(countries: ['us']).matches(countryCode: null), isFalse);
      expect(const ExtensionRelevance(ituRegions: [2]).matches(ituRegion: null), isFalse);
      expect(const ExtensionRelevance(entities: ['K']).matches(), isFalse);
      expect(const ExtensionRelevance(continents: ['NA']).matches(), isFalse);
    });

    test('ituRegions match by number, whatever the JSON encoder made of them', () {
      // A manifest written by hand carries `2`; one that went through a
      // number-typed encoder can carry `2.0`. Both are region 2.
      final relevance = ExtensionRelevance.fromJson({
        'ituRegions': [2.0, 3],
      });
      expect(relevance.ituRegions, [2, 3]);
      expect(relevance.matches(ituRegion: 2), isTrue);
      expect(relevance.matches(ituRegion: 1), isFalse);
    });
  });

  group('fromJson / toJson', () {
    test('reads the six lists and drops what it cannot read, like notices', () {
      // Shape is refused upstream (packer, build, install); what arrives here
      // has passed, so an unreadable key degrades to "does not gate" rather
      // than throwing out of the Extensions panel over a relevance hint.
      final relevance = ExtensionRelevance.fromJson({
        'entities': ['K', 7],
        'countries': 'us',
        'continents': ['NA'],
        'dates': ['2026-09-19', 20270918],
        'interests': 'cw',
      });
      expect(relevance.entities, ['K']);
      expect(relevance.countries, isEmpty);
      expect(relevance.continents, ['NA']);
      expect(relevance.ituRegions, isEmpty);
      expect(relevance.dates, ['2026-09-19']);
      expect(relevance.interests, isEmpty);
    });

    test('an empty object is worldwide, and round-trips as one', () {
      final relevance = ExtensionRelevance.fromJson(const {});
      expect(relevance.isWorldwide, isTrue);
      expect(relevance.toJson(), isEmpty);
    });

    test('toJson emits only the lists that carry something', () {
      // A round trip of a two-list relevance must not grow four empty
      // siblings: `{"countries": []}` is not what the author wrote.
      final json = const ExtensionRelevance(countries: ['us'], dates: ['2026-09-19'], interests: ['cw']).toJson();
      expect(json, {
        'countries': ['us'],
        'dates': ['2026-09-19'],
        'interests': ['cw'],
      });
      final round = ExtensionRelevance.fromJson(json);
      expect(round.matches(countryCode: 'us'), isTrue);
      expect(round.dates, ['2026-09-19']);
      expect(round.interests, ['cw']);
    });
  });

  group('ExtensionInfo.fromJson', () {
    test('carries version and relevance off the index entry', () {
      // Both are read for an extension that may be DISABLED, whose bundle
      // never runs: the version for an update check, the relevance for
      // ranking.
      final info = ExtensionInfo.fromJson({
        'key': 'ce1vk-llota',
        'file': 'index.js',
        'core': false,
        'name': 'LLOTA',
        'category': 'activity',
        'version': '1.2.0',
        'relevance': {
          'entities': ['CE'],
          'dates': ['2026-09-19'],
        },
      });
      expect(info.version, '1.2.0');
      expect(info.relevance!.entities, ['CE']);
      expect(info.relevance!.dates, ['2026-09-19']);
      expect(info.relevance!.matches(entityPrefix: 'CE'), isTrue);
    });

    test('an entry without them is worldwide and unversioned, not a crash', () {
      // A stale index, or an installed manifest from before either field.
      final info = ExtensionInfo.fromJson(const {'key': 'pota', 'file': 'pota.js', 'core': false, 'name': 'POTA'});
      expect(info.version, isNull);
      expect(info.relevance, isNull);
    });
  });

  group('relevanceBand', () {
    // The one order the Extensions panel ranks by, for what is installed and
    // what the catalog offers alike. The claim is the ORDER between the three
    // bands, so each test below is about which of two things comes first.
    final now = DateTime.utc(2026, 9, 9);
    const kilo = OperatorGeo(entityPrefix: 'K', countryCode: 'us', continent: 'NA', ituRegion: 2);
    String day(int inDays) {
      final at = now.add(Duration(days: inDays));
      return '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
    }

    int bandOf(ExtensionRelevance? r, {OperatorGeo? operator = kilo}) => relevanceBand(r, operator: operator, now: now);

    test('a date inside the window outranks a place, which outranks neither', () {
      // The whole point of the ordering: a date expires and a place does not.
      // A QSO party three days out is worth surfacing to somebody who has not
      // decided yet; the state it runs in is true all year and says nothing
      // about now.
      expect(bandOf(ExtensionRelevance(dates: [day(3)])), 0);
      expect(bandOf(const ExtensionRelevance(entities: ['K'])), 1);
      expect(bandOf(const ExtensionRelevance()), 2);
      expect(bandOf(null), 2);
    });

    test('a date beats a place even when the date is somebody else\'s', () {
      // Ranked 0 on the date alone: an operator who searched out a contest in
      // another country still wants to know it is this weekend.
      expect(bandOf(ExtensionRelevance(entities: ['CE'], dates: [day(2)])), 0);
    });

    test('the window reaches three days back, because a date is when an event STARTS', () {
      // Most of these run longer than the day they begin, and the weekend is
      // where they land: the operator logging on Monday what they worked on
      // Saturday wants the same extension as the one who installed it on
      // Friday, and a forward-only window drops it exactly then.
      expect(bandOf(ExtensionRelevance(dates: [day(-3)])), 0);
      expect(bandOf(ExtensionRelevance(dates: [day(-4)])), 2, reason: 'over');
      expect(bandOf(ExtensionRelevance(dates: [day(0)])), 0, reason: 'today');
    });

    test('fourteen days is inside the window and fifteen is not', () {
      expect(bandOf(ExtensionRelevance(dates: [day(14)])), 0);
      expect(bandOf(ExtensionRelevance(dates: [day(15)])), 2);
    });

    test('any one of several dates is enough', () {
      // A yearly event lists the occurrences it knows about, most of them far
      // away. It is soon if ANY of them is.
      expect(bandOf(ExtensionRelevance(dates: [day(400), day(5), day(800)])), 0);
    });

    test('worldwide is not "here"', () {
      // It gates on nothing, so it says nothing about this operator. Ranked
      // with a genuine match it would bury the matches under everything —
      // most of the catalog is worldwide.
      expect(bandOf(const ExtensionRelevance(interests: ['cw'])), 2);
      expect(bandOf(const ExtensionRelevance(countries: ['us'])), 1);
    });

    test('an operator nothing is known about matches no place', () {
      // The same fail-closed rule the notices use. Only a date can rank
      // anything before a callsign is known.
      expect(bandOf(const ExtensionRelevance(entities: ['K']), operator: null), 2);
      expect(bandOf(ExtensionRelevance(dates: [day(1)]), operator: null), 0);
    });

    test('a date nobody can read is not soon', () {
      // Shape is refused upstream, so anything unreadable here came from a
      // stale index rather than an author — and ranking an extension by a
      // typo is worse than not ranking it.
      expect(
        bandOf(
          ExtensionRelevance.fromJson(const {
            'dates': ['whenever'],
          }),
        ),
        2,
      );
    });
  });
}
