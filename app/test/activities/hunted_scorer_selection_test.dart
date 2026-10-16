// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app adapts its segments and Qso models to the shared scorer selector.
// The selection matrix lives in halo_extension_host's scoring_priority_test;
// these checks hold the app's argument forwarding and model conversion to it.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show Scorer;
import 'package:ham2k_logger/services/extensions/extension_service.dart';

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

Set<String> _keys(List<Scorer> scorers) => scorers.map((s) => s.key).toSet();

Qso _qso({List<Map<String, dynamic>> refs = const []}) => Qso(uuid: 'q', operationUuid: 'op-1', data: {'refs': refs});

void main() {
  group('scorersFor', () {
    test('forwards the operation, scopes and hunted types to the shared selector', () {
      final scorers = ExtensionService.scorersFor(
        {
          'refs': [
            {'type': 'customActivation', 'ref': 'A-1'},
          ],
        },
        const {
          'fallback': 'always',
          'activation': {
            'refTypes': ['customActivation'],
          },
          'hunting': {
            'refTypes': ['customHunt'],
            'huntingRefTypes': ['customHunt'],
          },
        },
        alsoRefTypes: const {'customHunt'},
      );
      expect(_keys(scorers), {'activation', 'hunting', 'fallback'});
      expect(scorers.firstWhere((s) => s.key == 'activation').ref?['ref'], 'A-1');
    });

    test('converts every segment to refs while retaining hunted types', () {
      const operation = {
        'refs': [
          {'type': 'potaActivation', 'ref': 'US-0001'},
        ],
      };
      final segments = SegmentedOperation.from(
        operation: operation,
        qsos: [
          Qso(
            uuid: 'break',
            operationUuid: 'op-1',
            data: {
              'band': 'event',
              'startAtMillis': 1000,
              'event': {
                'event': 'break',
                'operation': {
                  'refs': [
                    {'type': 'cqww'},
                  ],
                },
              },
            },
          ),
        ],
      );
      final scorers = ExtensionService.scorersFor(operation, _scopes, segments: segments, alsoRefTypes: const {'sota'});
      expect(_keys(scorers), {'core', 'pota', 'cqww', 'sota'});
      expect(scorers.firstWhere((s) => s.key == 'pota').ref?['ref'], 'US-0001');
    });
  });

  group('huntedRefTypesOf', () {
    test('collects every reference type across the log', () {
      final types = ExtensionService.huntedRefTypesOf([
        _qso(
          refs: [
            {'type': 'pota', 'ref': 'US-0001'},
          ],
        ),
        _qso(
          refs: [
            {'type': 'sota', 'ref': 'W1/AM-001'},
            {'type': 'pota', 'ref': 'US-0002'},
          ],
        ),
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
      expect(
        ExtensionService.refTypesOf(const {
          'their': {'call': 'K1ABC'},
        }),
        isEmpty,
      );
      expect(
        ExtensionService.refTypesOf(const {
          'refs': ['not-a-map'],
        }),
        isEmpty,
      );
      expect(
        ExtensionService.refTypesOf(const {
          'refs': [
            {'ref': 'US-0001'},
          ],
        }),
        isEmpty,
      );
    });
  });
}
