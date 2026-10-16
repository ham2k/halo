// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The scorer selection and priority rules, in the package the app and the CLI
// share (docs/design/contests.md §5.1). They live here rather than beside
// either caller because the two have to agree: `halo ext score` is the tool an
// operator is pointed at when the app's scoring looks wrong, and a CLI that
// selected or merged differently would describe a program that isn't running.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

const _scopes = {
  'core': 'always',
  'pota': {
    'refTypes': ['potaActivation', 'pota'],
    'huntingRefTypes': ['pota'],
  },
  'sota': {
    'refTypes': ['sotaActivation', 'sota'],
    'huntingRefTypes': ['sota'],
  },
  'cqww': {
    'refTypes': ['cqww'],
  },
};

void main() {
  group('scorersFor', () {
    test('the always scorer comes last and is flagged the fallback', () {
      final scorers = scorersFor({
        'refs': [
          {'type': 'potaActivation', 'ref': 'US-0001'},
          {'type': 'cqww'},
        ],
      }, _scopes);
      expect(scorers.map((s) => s.key), ['pota', 'cqww', 'core']);
      expect(scorers.where((s) => s.fallback), hasLength(1));
      expect(scorers.last.fallback, isTrue);
      expect(scorers.first.ref?['ref'], 'US-0001');
    });

    // Selection spans every segment: a contest confined to the back half of a
    // log would never be invoked if this read the base operation alone.
    test('a scorer named only by a later segment is still selected', () {
      final scorers = scorersFor(
        const {'refs': []},
        _scopes,
        segmentRefs: [
          const [],
          const [
            {'type': 'cqww'},
          ],
        ],
      );
      expect(scorers.map((s) => s.key), ['cqww', 'core']);
    });

    test('a hunted ref type selects the scorer the operation never names', () {
      final scorers = scorersFor(const {'refs': []}, _scopes, alsoRefTypes: const {'pota'});
      expect(scorers.map((s) => s.key), ['pota', 'core']);
      // No operation ref to hand it, and none is invented — an activity reads
      // what it ACTIVATES off the operation, so a hunt-only pass earns no
      // activation credit.
      expect(scorers.first.ref, isNull);
    });

    // A contest's ref type rides its QSOs as exchange data, so matching the
    // log against `refTypes` would resurrect a contest a break has ended.
    test('a contest is never resurrected by its ref type in the log', () {
      final scorers = scorersFor(const {'refs': []}, _scopes, alsoRefTypes: const {'cqww'});
      expect(scorers.map((s) => s.key), ['core']);
    });

    test('activating and hunting the same program selects it once, with its ref', () {
      final scorers = scorersFor(
        {
          'refs': [
            {'type': 'potaActivation', 'ref': 'US-0001'},
          ],
        },
        _scopes,
        alsoRefTypes: const {'pota'},
      );
      expect(scorers.where((s) => s.key == 'pota').length, 1);
      expect(scorers.firstWhere((s) => s.key == 'pota').ref?['ref'], 'US-0001');
    });

    test('only the programs actually hunted are selected', () {
      final scorers = scorersFor(const {'refs': []}, _scopes, alsoRefTypes: const {'sota'});
      expect(scorers.map((s) => s.key).toSet(), {'core', 'sota'});
    });

    test('an unrelated hunted type selects nothing extra', () {
      final scorers = scorersFor(const {'refs': []}, _scopes, alsoRefTypes: const {'wwff'});
      expect(scorers.map((s) => s.key).toSet(), {'core'});
    });
  });

  group('judgesCandidate', () {
    const partySpot = {
      'refs': [
        {'type': 'pa-qso-party', 'ref': 'CHE'},
      ],
    };
    const parkSpot = {
      'refs': [
        {'type': 'pota', 'ref': 'US-0001'},
      ],
    };
    const bareSpot = {'refs': <Map<String, dynamic>>[]};

    // One park spot on the board selects POTA hunt-only. Asked about a QSO
    // Party spot too, its per-day rule calls a station worked yesterday
    // `newDay`, and that notice un-strikes what the party scorer called a
    // duplicate.
    test('a hunt-only scorer judges only candidates hunting its references', () {
      final pota = scorersFor(const {'refs': []}, _scopes, alsoRefTypes: const {'pota'}).first;
      expect(judgesCandidate(pota, _scopes['pota'], parkSpot), isTrue);
      expect(judgesCandidate(pota, _scopes['pota'], partySpot), isFalse);
      expect(judgesCandidate(pota, _scopes['pota'], bareSpot), isFalse);
    });

    // An activation credits every contact, park or not, so narrowing it would
    // cost the activator their dupe marking on every non-park spot.
    test('a scorer the operation names judges every candidate', () {
      final pota = scorersFor({
        'refs': [
          {'type': 'potaActivation', 'ref': 'US-0001'},
        ],
      }, _scopes).first;
      expect(judgesCandidate(pota, _scopes['pota'], bareSpot), isTrue);
      expect(judgesCandidate(pota, _scopes['pota'], partySpot), isTrue);
    });

    // `halo ext` reads contacts straight from a file. One hand-written `refs`
    // that is not a list must read as hunting nothing, not throw out of the
    // merge and cost every scorer's output.
    test('a malformed refs value hunts nothing', () {
      final pota = scorersFor(const {'refs': []}, _scopes, alsoRefTypes: const {'pota'}).first;
      expect(judgesCandidate(pota, _scopes['pota'], const {'refs': 'US-0001'}), isFalse);
      expect(
        refTypesOf(const {
          'refs': {'type': 'pota'},
        }),
        isEmpty,
      );
    });

    test('the fallback judges every candidate', () {
      final core = scorersFor(const {'refs': []}, _scopes).single;
      expect(judgesCandidate(core, _scopes['core'], bareSpot), isTrue);
    });
  });

  group('judgedVerdicts', () {
    const verdicts = {
      'park': {
        'notices': ['newDay'],
      },
      'party': {
        'notices': ['newDay'],
      },
    };
    const qsos = {
      'park': {
        'refs': [
          {'type': 'pota', 'ref': 'US-0001'},
        ],
      },
      'party': {
        'refs': [
          {'type': 'pa-qso-party', 'ref': 'CHE'},
        ],
      },
    };

    // A whole-log pass hands the scorer every contact. Kept, POTA's `newDay` on
    // a party contact takes the party's duplicate off it in the stored log.
    test('a hunt-only scorer keeps its verdicts only on contacts hunting its references', () {
      final pota = scorersFor(const {'refs': []}, _scopes, alsoRefTypes: const {'pota'}).first;
      expect(judgedVerdicts(pota, _scopes['pota'], verdicts, (uuid) => qsos[uuid]).keys, ['park']);
      expect(judgedVerdicts(pota, _scopes['pota'], verdicts, (uuid) => null), isEmpty, reason: 'an unknown contact hunts nothing');
    });

    test('every other scorer keeps all its verdicts, without reading a contact', () {
      final scorers = scorersFor(const {
        'refs': [
          {'type': 'potaActivation', 'ref': 'US-0001'},
        ],
      }, _scopes);
      for (final scorer in scorers) {
        expect(judgedVerdicts(scorer, _scopes[scorer.key], verdicts, (uuid) => fail('read $uuid for ${scorer.key}')), same(verdicts));
      }
    });
  });

  group('judgesWorkedBefore', () {
    test('a dupe flag is a ruling, either way it reads', () {
      expect(judgesWorkedBefore(const {'dupe': true}), isTrue);
      // The scorer ran its test and cleared the contact — which is exactly what
      // core must not then overrule with its own coarser dupe rule.
      expect(judgesWorkedBefore(const {'dupe': false}), isTrue);
    });

    test('the worked-before vocabulary is a ruling', () {
      expect(
        judgesWorkedBefore(const {
          'alerts': ['duplicate'],
        }),
        isTrue,
      );
      for (final notice in kWorkedBeforeNotices) {
        expect(
          judgesWorkedBefore({
            'notices': [notice],
          }),
          isTrue,
          reason: notice,
        );
      }
    });

    // The distinction the whole rule turns on. A validity check that returned
    // above the scorer's dupe test has ruled on nothing.
    test('answering without ruling is not a ruling', () {
      expect(
        judgesWorkedBefore(const {
          'value': 0,
          'alerts': ['invalidBand'],
        }),
        isFalse,
      );
      expect(
        judgesWorkedBefore(const {
          'value': 0,
          'alerts': ['missingExchange'],
        }),
        isFalse,
      );
      expect(
        judgesWorkedBefore(const {
          'notices': ['newDXCC'],
        }),
        isFalse,
      );
      expect(judgesWorkedBefore(const {'value': 1}), isFalse);
      expect(judgesWorkedBefore(const {}), isFalse);
    });

    test('a malformed notices list cannot throw', () {
      expect(judgesWorkedBefore(const {'notices': 'newRef', 'alerts': 42}), isFalse);
    });
  });

  group('withoutWorkedBefore', () {
    test('takes the dupe judgement out and leaves everything else', () {
      expect(
        withoutWorkedBefore(const {
          'value': 1,
          'dupe': false,
          'notices': ['newBand', 'newDXCC'],
          'alerts': ['duplicate'],
        }),
        {
          'value': 1,
          'notices': ['newDXCC'],
        },
      );
    });

    // The verdict shape is open: a scorer's own extra keys are its bookkeeping,
    // not a claim about a prior contact, so they travel through.
    test('an unknown key is not swallowed', () {
      expect(
        withoutWorkedBefore(const {
          'value': 3,
          'mult': 'K',
          'alerts': ['duplicate'],
        }),
        {'value': 3, 'mult': 'K'},
      );
    });

    test('nothing left means no entry at all, rather than an empty one', () {
      expect(
        withoutWorkedBefore(const {
          'dupe': true,
          'alerts': ['duplicate'],
        }),
        isNull,
      );
      expect(
        withoutWorkedBefore(const {
          'notices': ['newRef'],
        }),
        isNull,
      );
    });
  });
}
