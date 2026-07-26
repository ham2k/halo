// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The search behind a `kind: 'options'` exchange field. An operator hits this
// on every QSO of a contest, at speed, so the ranking is the feature — a set
// that merely CONTAINS the right answer is not good enough if it isn't first.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// A few Ohio counties, in the shape a contest would declare them.
final _counties = [
  const ExchangeOption(code: 'ASD', name: 'Ashland'),
  const ExchangeOption(code: 'ASE', name: 'Ashtabula'),
  const ExchangeOption(code: 'ATH', name: 'Athens'),
  const ExchangeOption(code: 'CUY', name: 'Cuyahoga'),
  const ExchangeOption(code: 'HAS', name: 'Harrison'),
  const ExchangeOption(code: 'WAS', name: 'Washington'),
];

List<String> _codes(List<ExchangeOption> matched) => [for (final o in matched) o.code];

void main() {
  test('an exact code beats every other kind of match', () {
    // "HAS" is also a substring of Washington and a prefix of nothing else, but
    // the operator who typed three letters exactly meant the county with that
    // code.
    expect(_codes(matchExchangeOptions('HAS', _counties)).first, 'HAS');
  });

  test('a code prefix outranks a name prefix, which outranks any substring', () {
    // AS: code-prefix ASD/ASE, name-prefix Ashland/Ashtabula (same two), then
    // WAS and HAS by code substring, then Washington by name substring.
    expect(_codes(matchExchangeOptions('AS', _counties)), ['ASD', 'ASE', 'HAS', 'WAS']);
  });

  test('a name PREFIX outranks a code substring', () {
    // The half of the tier order the fixture above cannot actually distinguish:
    // 'WASH' must reach Washington by name prefix ahead of a county whose CODE
    // merely contains those letters.
    final withCodeSubstring = [const ExchangeOption(code: 'XWASH', name: 'Xenia'), ..._counties];
    expect(_codes(matchExchangeOptions('WASH', withCodeSubstring)), ['WAS', 'XWASH']);
  });

  test('SPACE accepts only a match the typed text STARTS', () {
    // Showing a substring hit is how an operator finds "Alum Creek" from "creek".
    // ACCEPTING one swaps in a code their text isn't even a prefix of: in the
    // shipped Ohio park set, 'CR' — someone heading for "Crane Creek" — substring
    // matches "Alum Creek" and used to log ALU on a Space they only meant as
    // "next field".
    const alum = ExchangeOption(code: 'ALU', name: 'Alum Creek SP');
    const crane = ExchangeOption(code: 'CRA', name: 'Crane Creek SP');
    expect(matchExchangeOptions('CR', const [alum, crane]).first.code, 'CRA',
        reason: 'the ranking itself is unchanged');
    expect(isAcceptableExchangeMatch('CR', crane), isTrue);
    expect(isAcceptableExchangeMatch('CR', alum), isFalse);

    // An exact code, a code prefix and a name prefix are all safe to swap in.
    expect(isAcceptableExchangeMatch('ALU', alum), isTrue);
    expect(isAcceptableExchangeMatch('AL', alum), isTrue);
    expect(isAcceptableExchangeMatch('ALUM', alum), isTrue);
    // Nothing typed accepts nothing, whatever the list happens to offer.
    expect(isAcceptableExchangeMatch('', alum), isFalse);
    expect(isAcceptableExchangeMatch('   ', alum), isFalse);
    // And restricting the search to codes doesn't let a name in by the back door.
    expect(isAcceptableExchangeMatch('ALUM', alum, matchOn: const {'code'}), isFalse);
  });

  test('a name is matched as well as a code, because names are easier to recall', () {
    expect(_codes(matchExchangeOptions('WASH', _counties)), ['WAS']);
    expect(_codes(matchExchangeOptions('CUYA', _counties)), ['CUY']);
  });

  test('matching ignores case on both sides', () {
    expect(_codes(matchExchangeOptions('cuy', _counties)), ['CUY']);
    expect(
      _codes(matchExchangeOptions('ash', [const ExchangeOption(code: 'x1', name: 'ASHLAND')])),
      ['x1'],
    );
  });

  test('preferred codes float up WITHIN a tier, never above a better match', () {
    // A QSO party surfaces the caller's likely state first — but an exact code
    // the operator typed in full still wins, or the preference would be
    // actively fighting them.
    expect(
      _codes(matchExchangeOptions('AS', _counties, preferred: ['WAS'])),
      ['ASD', 'ASE', 'WAS', 'HAS'],
      reason: 'WAS is preferred, so it leads its own substring tier — but not the prefix tier',
    );
    expect(
      _codes(matchExchangeOptions('ASD', _counties, preferred: ['WAS'])).first,
      'ASD',
      reason: 'an exact match is never displaced by a preference',
    );
  });

  test('an empty query offers the preferred codes first', () {
    // A freshly focused field should show something useful rather than nothing.
    expect(
      _codes(matchExchangeOptions('', _counties, preferred: ['CUY'])).first,
      'CUY',
    );
    expect(
      _codes(matchExchangeOptions('', _counties)),
      ['ASD', 'ASE', 'ATH', 'CUY', 'HAS', 'WAS'],
      reason: 'with no preference, declaration order',
    );
  });

  test('matchOn can restrict the search to codes alone', () {
    // A set whose names are noise, or whose codes are the only thing sent.
    expect(_codes(matchExchangeOptions('WASH', _counties, matchOn: {'code'})), isEmpty);
    expect(_codes(matchExchangeOptions('WAS', _counties, matchOn: {'code'})), ['WAS']);
  });

  test('ties keep declaration order, so a well-ordered set stays well ordered', () {
    final many = [
      for (var i = 0; i < 40; i++) ExchangeOption(code: 'C$i', name: 'County $i'),
    ];
    // Every one of these is a code-prefix match on "C".
    expect(_codes(matchExchangeOptions('C', many, limit: 5)), ['C0', 'C1', 'C2', 'C3', 'C4']);
  });

  test('the result is capped, because this feeds a line not a browsable list', () {
    expect(matchExchangeOptions('C', [
      for (var i = 0; i < 40; i++) ExchangeOption(code: 'C$i'),
    ]), hasLength(8));
  });

  test('no match returns empty rather than everything', () {
    expect(matchExchangeOptions('ZZZZ', _counties), isEmpty);
  });

  test('a known code is recognized whatever its case', () {
    expect(isKnownExchangeOption('cuy', _counties), isTrue);
    expect(isKnownExchangeOption(' WAS ', _counties), isTrue);
    expect(isKnownExchangeOption('ZZ', _counties), isFalse);
    expect(isKnownExchangeOption('', _counties), isFalse, reason: 'empty is not a value');
  });

  test('a malformed option map is dropped rather than crashing the field', () {
    // Options cross the bridge from third-party code.
    expect(ExchangeOption.fromMap({'code': 'OK', 'name': 'Fine'})?.code, 'OK');
    expect(ExchangeOption.fromMap({'code': 'OK'})?.name, isNull);
    expect(ExchangeOption.fromMap({'code': ''}), isNull);
    expect(ExchangeOption.fromMap({'name': 'no code'}), isNull);
    expect(ExchangeOption.fromMap({'code': 42}), isNull);
  });
}
