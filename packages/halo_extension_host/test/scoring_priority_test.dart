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
        ],
      }, _scopes);
      expect(scorers.map((s) => s.key), ['pota', 'core']);
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
