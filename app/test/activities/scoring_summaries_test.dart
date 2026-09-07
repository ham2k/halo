// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `local_data.scoring` became keyed by scorer when contest scoring landed, and
// the two consumers that read it directly (the Info pane's summary and the QSO
// list's day headers) kept reading the old flat shape — so both silently
// rendered nothing, with no crash and no failing test. These pin the new shape
// so that can't recur: an operation's scores must survive a second scorer
// joining, and a contest's own tallies must actually reach the day header.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/tools/scoring_summaries.dart';

/// What ScoringService writes once core and a contest have both scored.
final _nested = <String, dynamic>{
  'core': {
    'operationSummary': {
      'qsoCount': {'key': 'qsoCount', 'total': 12, 'duplicates': 2},
      'dxcc': {
        'key': 'dxcc',
        'total': 3,
        'entities': {'K': 5, 'DL': 4, 'JA': 3},
      },
    },
    'daySections': [
      {
        'day': 200,
        'scores': {
          'qsoCount': {'key': 'qsoCount', 'icon': 'radio', 'summary': '7'},
          'dxcc': {'key': 'dxcc', 'icon': 'earth', 'summary': '3'},
        },
      },
      {
        'day': 100,
        'scores': {
          'qsoCount': {'key': 'qsoCount', 'icon': 'radio', 'summary': '5'},
        },
      },
    ],
  },
  'simple-contest': {
    'operationSummary': {
      'contest': {'key': 'contest', 'total': 10, 'summary': '10'},
    },
    'daySections': [
      {
        'day': 100,
        'scores': {
          'contest': {'key': 'contest', 'icon': 'flag-checkered', 'summary': '4'},
        },
      },
    ],
  },
};

void main() {
  test('a scorer\'s operation summary is found under its own key', () {
    final core = operationSummaryFor(_nested, 'core');
    expect((core?['qsoCount'] as Map?)?['duplicates'], 2);
    expect(((core?['dxcc'] as Map?)?['entities'] as Map?)?.length, 3);

    expect((operationSummaryFor(_nested, 'simple-contest')?['contest'] as Map?)?['total'], 10);
    expect(operationSummaryFor(_nested, 'nope'), isNull);
  });

  test('day sections merge across scorers, so one header carries both', () {
    final merged = mergedDaySections(_nested);

    // Chronological, regardless of the order each scorer reported them.
    expect(merged.map((s) => s['day']), [100, 200]);

    final day100 = (merged.first['scores'] as Map<String, dynamic>);
    // Core's tally and the contest's both survive into the same day.
    expect(day100['core.qsoCount'], isNotNull);
    expect(day100['simple-contest.contest'], isNotNull);
    expect((day100['simple-contest.contest'] as Map)['summary'], '4');

    // A day only one scorer reported still comes through.
    expect((merged.last['scores'] as Map).keys, containsAll(['core.qsoCount', 'core.dxcc']));
  });

  test('tally keys are namespaced, so two contests using the same key cannot collide', () {
    final twoContests = <String, dynamic>{
      'aaa-contest': {
        'daySections': [
          {'day': 1, 'scores': {'contest': {'key': 'contest', 'summary': 'A'}}},
        ],
      },
      'zzz-contest': {
        'daySections': [
          {'day': 1, 'scores': {'contest': {'key': 'contest', 'summary': 'Z'}}},
        ],
      },
    };

    final scores = mergedDaySections(twoContests).single['scores'] as Map<String, dynamic>;
    expect((scores['aaa-contest.contest'] as Map)['summary'], 'A');
    expect((scores['zzz-contest.contest'] as Map)['summary'], 'Z');
  });

  test('core sorts last so badge order does not drift with hook ordering', () {
    // invokeHookAll gives no ordering guarantee, so the display must impose
    // one: contests first (what the operator is there for), core's own
    // DXCC/states/bands bookkeeping last.
    expect(orderedScorerKeys({'zebra': {}, 'core': {}, 'alpha': {}}), ['alpha', 'zebra', 'core']);
    // An operation with no core scorer (shouldn't happen, but must not throw).
    expect(orderedScorerKeys({'alpha': {}}), ['alpha']);
    expect(orderedScorerKeys(null), isEmpty);
  });

  test('an activity scorer sorts after contests, still before core', () {
    // Detected by its own operationSummary carrying an activation/hunting
    // tally (activityScoring.ts's shape) — no scorer-kind flag crosses the
    // JS/Dart boundary, so this is what tells the two apart.
    final mixed = <String, dynamic>{
      'core': {'operationSummary': {}},
      'pota': {
        'operationSummary': {
          'activation': {'key': 'activation', 'total': 1},
        },
      },
      'cqww': {
        'operationSummary': {
          'contest': {'key': 'contest', 'total': 1},
        },
      },
    };
    expect(orderedScorerKeys(mixed), ['cqww', 'pota', 'core']);
  });

  test('the pre-contest flat shape yields nothing rather than throwing', () {
    // Old cached blobs are regenerable (scoring is never load-bearing), so the
    // right behaviour is to degrade quietly until the next rescore lands.
    final flat = <String, dynamic>{
      'operationSummary': {'qsoCount': {'key': 'qsoCount', 'total': 4}},
      'daySections': [
        {'day': 1, 'scores': {}},
      ],
    };
    expect(mergedDaySections(flat), isEmpty);
    expect(operationSummaryFor(flat, 'core'), isNull);
  });
}
