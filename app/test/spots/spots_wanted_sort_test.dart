// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Chasing view's "Most wanted" order (docs/design/claims.md §8): what the
// operator works next is whatever is at the top, so a station they already
// have must never sit above one they need.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/spot_board.dart';

Map<String, dynamic> _spot(String call, {required int at}) => {
  'their': {'call': call},
  'band': '20m',
  'mode': 'CW',
  'spot': {'timeInMillis': at, 'source': 'test'},
};

String _call(Map<String, dynamic> spot) => (spot['their'] as Map)['call'] as String;

void main() {
  test('better verdicts first, the earlier goal on a tie, then the newest; unjudged after, worked last', () {
    final ranks = <String, ({int rank, int goal})?>{
      'OLDREF': (rank: 3, goal: 1),
      'NEWREF': (rank: 3, goal: 1),
      'FIRSTGOAL': (rank: 3, goal: 0),
      'BAND': (rank: 2, goal: 0),
      'UNJUDGED': null,
      'DUPE': (rank: 3, goal: 0),
    };
    final spots = [
      _spot('UNJUDGED', at: 6),
      _spot('DUPE', at: 7),
      _spot('BAND', at: 5),
      _spot('OLDREF', at: 1),
      _spot('FIRSTGOAL', at: 2),
      _spot('NEWREF', at: 3),
    ];
    final sorted = sortSpotsByWanted(spots, rankOf: (spot) => ranks[_call(spot)], worked: (spot) => _call(spot) == 'DUPE');
    expect(sorted.map(_call), ['FIRSTGOAL', 'NEWREF', 'OLDREF', 'BAND', 'UNJUDGED', 'DUPE']);
  });
}
