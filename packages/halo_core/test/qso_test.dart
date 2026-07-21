// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

Qso _qso(Map<String, dynamic> their) => Qso(uuid: 'u', operationUuid: 'op', data: {'their': their});

void main() {
  group('Qso guess coalescing & provenance', () {
    test('an entered value wins over the guess and is not flagged guessed', () {
      final q = _qso({
        'state': 'NY',
        'guess': {'state': 'CA'},
      });
      expect(q.theirState, 'NY');
      expect(q.theirFieldIsGuessed('state'), isFalse);
    });

    test('falls back to the guess and flags it as guessed', () {
      final q = _qso({
        'guess': {'state': 'CA', 'name': 'Bob', 'grid': 'FN20', 'flag': '🇺🇸', 'entityPrefix': 'K'},
      });
      expect(q.theirState, 'CA');
      expect(q.theirName, 'Bob');
      expect(q.theirFieldIsGuessed('state'), isTrue);
      expect(q.theirFieldIsGuessed('name'), isTrue);
      expect(q.theirFieldIsGuessed('flag'), isTrue);
      expect(q.theirFieldIsGuessed('entityPrefix'), isTrue);
    });

    test('no value and no guess is neither shown nor flagged', () {
      final q = _qso({});
      expect(q.theirState, isNull);
      expect(q.theirFieldIsGuessed('state'), isFalse);
    });

    test('an empty-string entered value counts as entered, matching the getter', () {
      // The coalescing getter returns '' (not the guess) for an empty string,
      // so provenance must agree: '' is an entered value, not a guess.
      final q = _qso({
        'state': '',
        'guess': {'state': 'CA'},
      });
      expect(q.theirState, '');
      expect(q.theirFieldIsGuessed('state'), isFalse);
    });
  });
}
