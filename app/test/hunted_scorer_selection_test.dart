// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which scorers an operation gets. The case these exist for is the ordinary
// POTA chaser: an operation that ACTIVATES nothing names no activity on its
// own refs, so before this it selected only the core scorer — and core's rule
// is call+band+mode, which knows nothing about references. A station worked at
// one park then read as a duplicate when spotted at another, in the spot list
// and in the call-info pills alike.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/extension_service.dart';

/// The scopes a runtime reports: core applies to everything, POTA and SOTA are
/// gated on their own activation and hunting ref types.
/// The scopes a runtime reports. Activities name a hunting type; a contest
/// names none, because its ref type rides its QSOs as exchange data rather
/// than as something the contact hunted.
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

Set<String> _keys(List<({String key, Map<String, dynamic>? ref})> scorers) =>
    scorers.map((s) => s.key).toSet();

Qso _qso({List<Map<String, dynamic>> refs = const []}) =>
    Qso(uuid: 'q', operationUuid: 'op-1', data: {'refs': refs});

void main() {
  group('scorersFor', () {
    test('an operation that activates a park selects that scorer, as before', () {
      final scorers = ExtensionService.scorersFor(
        {
          'refs': [
            {'type': 'potaActivation', 'ref': 'US-0001'},
          ],
        },
        _scopes,
      );
      expect(_keys(scorers), {'core', 'pota'});
      // Paired with the ref that named it — the activation's own reference,
      // which is what earns activation credit.
      expect(scorers.firstWhere((s) => s.key == 'pota').ref?['ref'], 'US-0001');
    });

    // The whole point. A chaser's operation carries no refs at all.
    test('a hunted ref type selects the scorer the operation never names', () {
      final scorers = ExtensionService.scorersFor(
        const {'refs': []},
        _scopes,
        alsoRefTypes: const {'pota'},
      );
      expect(_keys(scorers), {'core', 'pota'});
    });

    // Null, not a synthetic {'type': 'pota'}: an activity reads the references
    // it is ACTIVATING off the operation, not off this ref, so inventing one
    // here would not grant activation credit anyway — but it would misreport
    // what selected the scorer.
    test('a hunt-only selection carries no ref', () {
      final scorers = ExtensionService.scorersFor(
        const {'refs': []},
        _scopes,
        alsoRefTypes: const {'pota'},
      );
      expect(scorers.firstWhere((s) => s.key == 'pota').ref, isNull);
    });

    // An operation that activates AND hunts the same program must not select
    // its scorer twice — the second selection would carry a null ref and could
    // shadow the activation's own.
    test('activating and hunting the same program selects it once, with its ref', () {
      final scorers = ExtensionService.scorersFor(
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

    // Precision is what makes this affordable: each scorer is a bridge crossing
    // carrying the log, so selecting every installed activity — app-polo's
    // `generalHuntingType` — is what this deliberately does NOT do.
    test('only the programs actually hunted are selected', () {
      final scorers = ExtensionService.scorersFor(
        const {'refs': []},
        _scopes,
        alsoRefTypes: const {'sota'},
      );
      expect(_keys(scorers), {'core', 'sota'});
    });

    // The trap this whole `huntingRefTypes` split exists for. A contest writes
    // its ref type onto every QSO it scores — `{type: 'cqww', theirZone}` is
    // exchange data, not something the contact hunted. Matching a scorer's
    // plain `refTypes` against the log would therefore resurrect a contest the
    // operator has ENDED at a break: the entry-row pills and the spot list
    // would go on applying contest rules all the next day, which is exactly
    // what segments exist to prevent. StateParks is louder still — with no ref
    // to name its event, every spot and every pill would carry
    // `alerts: ['unknownEvent']`.
    test('a contest is never resurrected by its ref type in the log', () {
      final scorers = ExtensionService.scorersFor(
        const {'refs': []},
        _scopes,
        alsoRefTypes: const {'cqww'},
      );
      expect(_keys(scorers), {'core'});
    });

    test('an unrelated hunted type selects nothing extra', () {
      final scorers = ExtensionService.scorersFor(
        const {'refs': []},
        _scopes,
        alsoRefTypes: const {'wwff'},
      );
      expect(_keys(scorers), {'core'});
    });
  });

  group('huntedRefTypesOf', () {
    test('collects every reference type across the log', () {
      final types = ExtensionService.huntedRefTypesOf([
        _qso(refs: [
          {'type': 'pota', 'ref': 'US-0001'},
        ]),
        _qso(refs: [
          {'type': 'sota', 'ref': 'W1/AM-001'},
          {'type': 'pota', 'ref': 'US-0002'},
        ]),
        _qso(),
      ]);
      expect(types, {'pota', 'sota'});
    });

    test('a log with no references yields nothing', () {
      expect(ExtensionService.huntedRefTypesOf([_qso(), _qso()]), isEmpty);
    });
  });

  group('refTypesOf', () {
    // The candidate's own refs matter on their own: a station worked BARE who
    // is now spotted at a park is a new reference, and nothing in the log would
    // have selected POTA to say so.
    test('reads the types off a candidate that is not a logged QSO yet', () {
      expect(
        ExtensionService.refTypesOf({
          'their': {'call': 'K1ABC'},
          'refs': [
            {'type': 'pota', 'ref': 'US-0001'},
          ],
        }),
        {'pota'},
      );
    });

    test('a candidate with no refs, or malformed ones, yields nothing', () {
      expect(ExtensionService.refTypesOf(const {'their': {'call': 'K1ABC'}}), isEmpty);
      expect(ExtensionService.refTypesOf(const {'refs': ['not-a-map']}), isEmpty);
      expect(ExtensionService.refTypesOf(const {'refs': [{'ref': 'US-0001'}]}), isEmpty);
    });
  });
}
