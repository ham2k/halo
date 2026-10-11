// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What sliding a spot row left says about it being worked, over what scoring
// says — and, for a spot that merged several operators, that the verdict
// belongs to the row rather than being written over each member's own.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/spot_board.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';

Map<String, dynamic> _spot(String call, {double freq = 14250}) => {
  'their': {'call': call},
  'freq': freq,
};

void main() {
  late SpotWorkedOverrides overrides;

  setUp(() => overrides = SpotWorkedOverrides());

  test('sliding a row flips what it says, whatever scoring says', () {
    final spot = _spot('K1ABC');
    expect(overrides.isWorked(spot, scored: false), isFalse);

    overrides.toggle(spot, worked: false);
    expect(overrides.isWorked(spot, scored: false), isTrue);

    overrides.toggle(spot, worked: true);
    expect(overrides.isWorked(spot, scored: true), isFalse, reason: 'a genuine duplicate put back on the board');
  });

  // The case the gesture exists for: set aside once, not again on every
  // band the station turns up on.
  test('the same operator re-spotted elsewhere keeps the verdict', () {
    overrides.toggle(_spot('K1ABC'), worked: false);
    expect(overrides.isWorked(_spot('K1ABC', freq: 7200), scored: false), isTrue);
  });

  group('a merged row', () {
    test('reads as a verdict only when every operator on it carries the same one', () {
      overrides.toggle(_spot('K1ABC'), worked: false);
      expect(overrides.isWorked(_spot('K1ABC,W2XYZ'), scored: false), isFalse, reason: 'W2XYZ may still be worth working');

      overrides.toggle(_spot('W2XYZ'), worked: false);
      expect(overrides.isWorked(_spot('K1ABC,W2XYZ'), scored: false), isTrue);
    });

    // A merge the operator did not cause must not reverse a verdict they did
    // give.
    test("sliding it back and forth leaves each member's own verdict alone", () {
      overrides.toggle(_spot('K1ABC'), worked: false);
      final merged = _spot('K1ABC,W2XYZ');

      overrides.toggle(merged, worked: false);
      expect(overrides.isWorked(merged, scored: false), isTrue);
      overrides.toggle(merged, worked: true);
      expect(overrides.isWorked(merged, scored: false), isFalse);

      expect(overrides.isWorked(_spot('K1ABC'), scored: false), isTrue);
      expect(overrides.isWorked(_spot('W2XYZ'), scored: false), isFalse);
    });

    test("its verdict is the row's whichever order its calls merged in", () {
      overrides.toggle(_spot('K1ABC,W2XYZ'), worked: false);
      expect(overrides.isWorked(_spot('W2XYZ,K1ABC', freq: 7200), scored: false), isTrue);
    });
  });

  test('a spot with no call reads as scoring says, slid or not', () {
    final callless = <String, dynamic>{'freq': 14250.0};
    overrides.toggle(callless, worked: false);
    expect(overrides.isWorked(callless, scored: false), isFalse);
    expect(overrides.isWorked(callless, scored: true), isTrue);
  });

  // One reading of `their.call` for everything keyed per call: a verdict, a
  // note or a score set under one spelling must be found under the other.
  test('an operator is the same operator however a source spells the call', () {
    expect(spotCallsIn(' k1abc ,W2XYZ,,'), ['K1ABC', 'W2XYZ']);
    overrides.toggle(_spot('k1abc'), worked: false);
    expect(overrides.isWorked(_spot('K1ABC '), scored: false), isTrue);
  });
}
