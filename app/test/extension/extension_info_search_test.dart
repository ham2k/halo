// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `ExtensionInfo.matchesSearch` decides both what the Extensions panel lists
// and whether the activity search offers "enable this?" for an extension the
// user is clearly looking for. Missing a match there is the costly direction:
// a disabled activity would look like it simply doesn't exist. Hence the
// breadth (key, name, description, keywords, either locale) — and the one
// deliberate non-match, an empty query, which means "show everything" at the
// call site rather than "everything matches".

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extension_service.dart';

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

  test('matches the extension key, which is what a `sota:` scope types', () {
    expect(info.matchesSearch('sota', locale: 'en'), isTrue);
  });

  test('matches on name and description, case-insensitively', () {
    expect(info.matchesSearch('summits on the air', locale: 'en'), isTrue);
    expect(info.matchesSearch('SUMMITS', locale: 'en'), isTrue);
    expect(info.matchesSearch('chase mountain', locale: 'en'), isTrue);
  });

  test('matches declared keywords — the manifest\'s own search terms', () {
    expect(info.matchesSearch('summit', locale: 'en'), isTrue);
  });

  test('matches a partial word, so a half-typed search still finds it', () {
    expect(info.matchesSearch('sum', locale: 'en'), isTrue);
  });

  group('locales', () {
    test('the localized name and keywords match in that locale', () {
      expect(info.matchesSearch('cumbres', locale: 'es'), isTrue);
      expect(info.matchesSearch('montaña', locale: 'es'), isTrue);
    });

    test('English still matches while in another locale — either spelling finds it', () {
      expect(info.matchesSearch('summits', locale: 'es'), isTrue);
    });

    test('a localized term does not match under an unrelated locale', () {
      expect(info.matchesSearch('cumbres', locale: 'en'), isFalse);
    });
  });

  test('an empty query matches nothing — "list everything" is the caller\'s call', () {
    expect(info.matchesSearch('', locale: 'en'), isFalse);
  });

  test('unrelated text does not match', () {
    expect(info.matchesSearch('parks', locale: 'en'), isFalse);
  });
}
