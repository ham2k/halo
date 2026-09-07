// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `ExtensionGeo` decides whether an extension is relevant to the operator's
// own callsign. It is the twin of the notice engine's geo filters, and the
// traps are the same ones: a list that gates when it should not, a key that
// widens the audience when it should narrow it, and an unknown operator that
// slips through a gate meant to fail closed.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extension_geo.dart';
import 'package:ham2k_logger/services/extension_service.dart';

void main() {
  group('validate', () {
    test('every valid shape passes, in either case', () {
      for (final geo in [
        <String, Object?>{},
        {'entities': ['K', 'VE', '*4U1U', 'ce']},
        {'countries': ['us', 'CL']},
        {'continents': ['NA', 'sa']},
        {'ituRegions': [1, 2, 3]},
        {'ituRegions': [2.0]},
        {'entities': [], 'countries': [], 'continents': [], 'ituRegions': []},
      ]) {
        expect(ExtensionGeo.validate(geo), isEmpty, reason: '$geo');
      }
    });

    test('a shape the reader would misread, and a value nobody can match, are each named', () {
      // Shape: the reader takes what it cannot parse as "does not gate", so
      // a misspelt key is a Chilean extension for the whole world.
      // Vocabulary: "North America" or region 7 match no operator, so the
      // extension ranks last for everyone and nothing says why.
      final bad = <(Object?, Pattern)>[
        ('CE', "'geo' must be an object"),
        ([], "'geo' must be an object"),
        ({'entity': ['CE']}, "unknown key 'entity'"),
        ({'entities': 'CE'}, "'geo.entities' must be a list"),
        ({'entities': ['']}, 'not a non-empty string'),
        ({'entities': [7]}, 'not a non-empty string'),
        ({'entities': ['C E']}, 'not a DXCC entity prefix'),
        ({'countries': ['USA']}, 'not a two-letter ISO country code'),
        ({'continents': ['North America']}, 'not a continent (AF AS EU NA OC SA AN)'),
        ({'continents': ['EUR']}, 'not a continent'),
        ({'ituRegions': ['2']}, 'not an ITU region (1, 2, 3)'),
        ({'ituRegions': [7]}, 'not an ITU region'),
        ({'ituRegions': [2.5]}, 'not an ITU region'),
      ];
      for (final (geo, message) in bad) {
        final problems = ExtensionGeo.validate(geo);
        expect(problems, isNotEmpty, reason: '$geo');
        expect(problems.join(' | '), contains(message), reason: '$geo');
      }
      // Every problem, not the first: an author fixes the manifest once.
      expect(ExtensionGeo.validate({'entities': [''], 'continents': ['EUR'], 'bogus': []}), hasLength(3));
    });

    test('the keys and the vocabulary are the packer\'s, literal for literal', () {
      // Two authorities, one format: extensions/tools/h2kext.mjs refuses a
      // manifest at pack time and ExtensionGeo.validate refuses it at the
      // door. A fifth key or a new continent added to one of them makes a
      // bundle the packer accepts and the app refuses (or the reverse),
      // which nothing else would catch — so this reads the packer's source
      // and holds the two literal lists equal until the other follows.
      final source = File('../extensions/tools/h2kext.mjs').readAsStringSync();
      List<String> literal(String name) {
        final match = RegExp('$name = \\[([^\\]]*)\\]').firstMatch(source);
        expect(match, isNotNull, reason: '$name not found in h2kext.mjs');
        return [for (final m in RegExp(r"'([^']*)'|(\d+)").allMatches(match!.group(1)!)) m.group(1) ?? m.group(2)!];
      }

      expect(literal('GEO_KEYS'), ExtensionGeo.geoKeys);
      expect(literal('GEO_CONTINENTS'), ExtensionGeo.continentCodes);
      expect(literal('GEO_ITU_REGIONS'), ExtensionGeo.ituRegionCodes.map((r) => '$r').toList());
    });
  });

  group('matches', () {
    test('no list at all is worldwide: every operator, known or not', () {
      const geo = ExtensionGeo();
      expect(geo.isWorldwide, isTrue);
      expect(geo.matches(entityPrefix: 'K', countryCode: 'us', continent: 'NA', ituRegion: 2), isTrue);
      // Fail-closed applies to a GATED list only: a worldwide extension must
      // not vanish for an operator whose callsign is not yet known.
      expect(geo.matches(), isTrue);
    });

    test('one list gates on its own value alone', () {
      const geo = ExtensionGeo(entities: ['K', 'VE']);
      expect(geo.matches(entityPrefix: 'VE'), isTrue);
      expect(geo.matches(entityPrefix: 'G'), isFalse);
      // The values no list gates on are not consulted, unknown or not.
      expect(geo.matches(entityPrefix: 'K', countryCode: null, continent: null, ituRegion: null), isTrue);
    });

    test('lists AND across keys — mutated to OR, half the world would qualify', () {
      const geo = ExtensionGeo(entities: ['K'], continents: ['EU']);
      expect(geo.matches(entityPrefix: 'K', continent: 'NA'), isFalse);
      expect(geo.matches(entityPrefix: 'G', continent: 'EU'), isFalse);
      expect(geo.matches(entityPrefix: 'K', continent: 'EU'), isTrue);
    });

    test('case is the matcher\'s job, folded the way notices fold it', () {
      // Entities and continents compare uppercased, countries lowercased —
      // the forms FlagsService derives. An author who wrote `ce` or `Na` must
      // still reach their operators; the operator's form never changes.
      const geo = ExtensionGeo(entities: ['ce'], countries: ['CL'], continents: ['sa']);
      expect(geo.matches(entityPrefix: 'CE', countryCode: 'cl', continent: 'SA'), isTrue);
      expect(geo.matches(entityPrefix: 'ce', countryCode: 'cl', continent: 'SA'), isFalse);
    });

    test('a gated list fails closed when the operator\'s own value is unknown', () {
      // The notices rule: an operator nothing is known about is not one the
      // author addressed. Countries and ITU regions are the two that go
      // unknown in practice — a dev-fixture guess carries neither.
      expect(const ExtensionGeo(countries: ['us']).matches(countryCode: null), isFalse);
      expect(const ExtensionGeo(ituRegions: [2]).matches(ituRegion: null), isFalse);
      expect(const ExtensionGeo(entities: ['K']).matches(), isFalse);
      expect(const ExtensionGeo(continents: ['NA']).matches(), isFalse);
    });

    test('ituRegions match by number, whatever the JSON encoder made of them', () {
      // A manifest written by hand carries `2`; one that went through a
      // number-typed encoder can carry `2.0`. Both are region 2.
      final geo = ExtensionGeo.fromJson({
        'ituRegions': [2.0, 3],
      });
      expect(geo.ituRegions, [2, 3]);
      expect(geo.matches(ituRegion: 2), isTrue);
      expect(geo.matches(ituRegion: 1), isFalse);
    });
  });

  group('fromJson / toJson', () {
    test('reads the four lists and drops what it cannot read, like notices', () {
      // Shape is refused upstream (packer, build, install); what arrives here
      // has passed, so an unreadable key degrades to "does not gate" rather
      // than throwing out of the Extensions panel over a relevance hint.
      final geo = ExtensionGeo.fromJson({
        'entities': ['K', 7],
        'countries': 'us',
        'continents': ['NA'],
      });
      expect(geo.entities, ['K']);
      expect(geo.countries, isEmpty);
      expect(geo.continents, ['NA']);
      expect(geo.ituRegions, isEmpty);
    });

    test('an empty object is worldwide, and round-trips as one', () {
      final geo = ExtensionGeo.fromJson(const {});
      expect(geo.isWorldwide, isTrue);
      expect(geo.toJson(), isEmpty);
    });

    test('toJson emits only the lists that gate', () {
      // A round trip of a one-list geo must not grow three empty siblings:
      // `{"countries": []}` is not what the author wrote.
      final json = const ExtensionGeo(countries: ['us'], ituRegions: [2]).toJson();
      expect(json, {
        'countries': ['us'],
        'ituRegions': [2],
      });
      expect(ExtensionGeo.fromJson(json).matches(countryCode: 'us', ituRegion: 2), isTrue);
    });
  });

  group('ExtensionInfo.fromJson', () {
    test('carries version and geo off the index entry', () {
      // Both are read for an extension that may be DISABLED, whose bundle
      // never runs: the version for an update check, the geo for ranking.
      final info = ExtensionInfo.fromJson({
        'key': 'ce1vk-llota',
        'file': 'index.js',
        'core': false,
        'name': 'LLOTA',
        'category': 'activity',
        'version': '1.2.0',
        'geo': {
          'entities': ['CE'],
        },
      });
      expect(info.version, '1.2.0');
      expect(info.geo!.entities, ['CE']);
      expect(info.geo!.matches(entityPrefix: 'CE'), isTrue);
    });

    test('an entry without them is worldwide and unversioned, not a crash', () {
      // A stale index, or an installed manifest from before either field.
      final info = ExtensionInfo.fromJson(const {'key': 'pota', 'file': 'pota.js', 'core': false, 'name': 'POTA'});
      expect(info.version, isNull);
      expect(info.geo, isNull);
    });
  });
}
