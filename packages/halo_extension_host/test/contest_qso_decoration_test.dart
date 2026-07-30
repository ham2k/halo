// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A contest keeps the received exchange on its own ref — `theirZone`,
// `theirSerial`, `theirExchange` — which nothing generic knows how to read.
// The QSO row's exchange column and a plain (non-contest) ADIF export both read
// `their.exchange`, so without `processQsoBeforeSave` mirroring it across, a
// contest log shows an empty exchange column everywhere.
//
// Exercised through the REAL runtime rather than a stub, because the value of
// this hook is that four separately-written extensions agree on the projection.

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  /// Each contest, the ref field it stores the received exchange in, what
  /// should end up in `their.exchange`, and whether it also writes back to its
  /// OWN ref. `opFields` carries anything a contest needs on the OPERATION's ref
  /// to be running at all — which of several events, for the ones that have them.
  ///
  /// Only the contests whose exchange can be GUESSED write back: they stamp the
  /// country file's zone when the operator typed nothing, so the ref records
  /// what was actually sent rather than leaving the scorer and the export to
  /// re-derive it separately and disagree (docs/design/contests.md §8). Nothing
  /// can guess a state, a serial or a free-form exchange, so those three stay
  /// pure projections.
  const cases = [
    (key: 'cqww', refFields: {'theirZone': '05'}, expected: '5', writesBack: true, opFields: <String, Object>{}),
    (key: 'arrl-dx', refFields: {'theirExchange': 'MA'}, expected: 'MA', writesBack: false, opFields: <String, Object>{}),
    (key: 'simple-contest', refFields: {'exchange': '59 042'}, expected: '59 042', writesBack: false, opFields: <String, Object>{}),
    (key: 'cqwpx', refFields: {'theirSerial': '0012'}, expected: '12', writesBack: false, opFields: <String, Object>{}),
    (key: 'iaru-hf', refFields: {'theirExchange': 'ARRL'}, expected: 'ARRL', writesBack: true, opFields: <String, Object>{}),
    // Both halves of NAQP's exchange are guessable, so both are recorded — and
    // the projection joins them the way the QSO row and a plain ADIF read it.
    (key: 'naqp', refFields: {'name': 'BOB', 'location': 'ct'}, expected: 'BOB CT', writesBack: true, opFields: <String, Object>{}),
    // A state park event's exchange is a park abbreviation, and it IS guessable
    // — from a POTA reference already hunted on the QSO — so it is recorded on
    // the ref as well as projected. `ref` says which event: without it the
    // extension is running none of them.
    (key: 'stateparks', refFields: {'park': 'ada'}, expected: 'ADA', writesBack: true, opFields: <String, Object>{'ref': 'OHSP'}),
  ];

  for (final c in cases) {
    test('${c.key}: the received exchange reaches their.exchange', () async {
      final host = await sharedHost([c.key]);
      final entries = await host.invokeHookAll(
        'activity',
        method: 'processQsoBeforeSave',
        args: {
          'operation': {
            'stationCall': 'N0DEV',
            'refs': [
              {'type': c.key, 'mode': 'CW', 'exchange': '59 001', ...c.opFields},
            ],
          },
          'qso': {
            'band': '20m',
            'mode': 'CW',
            'their': {'call': 'W1AW'},
            'refs': [
              {'type': c.key, ...c.refFields},
            ],
          },
        },
      );

      final patch = entries.firstWhere((e) => e['ok'] == true && e['value'] is Map)['value'] as Map;
      expect((patch['their'] as Map)['exchange'], c.expected);
      // Narrow either way: the patch never touches the callsign it read past.
      expect((patch['their'] as Map).containsKey('call'), isFalse);

      if (c.writesBack) {
        // One ref, its own type — the core ignores any other, but a contest
        // naming someone else's would still be a bug worth failing on here.
        final refs = (patch['refs'] as List).cast<Map>();
        expect(refs, hasLength(1));
        expect(refs.single['type'], c.key);
      } else {
        expect(patch.containsKey('refs'), isFalse, reason: 'a pure projection rewrites nothing');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  }

  test('an operation not running the contest is left alone', () async {
    final host = await sharedHost(['cqww']);
    final entries = await host.invokeHookAll(
      'activity',
      method: 'processQsoBeforeSave',
      args: {
        // A POTA operation, and a QSO that happens to carry a stale cqww ref.
        'operation': {
          'stationCall': 'N0DEV',
          'refs': [
            {'type': 'pota', 'ref': 'US-1234'},
          ],
        },
        'qso': {
          'their': {'call': 'W1AW'},
          'refs': [
            {'type': 'cqww', 'theirZone': '5'},
          ],
        },
      },
    );

    // Without this the test passes when the fan-out returns NOTHING, which is
    // indistinguishable from the pass condition it is checking: a renamed hook
    // or category would go green here while every other test in the file fails.
    expect(entries, isNotEmpty, reason: 'the fan-out must have reached the hook at all');
    for (final entry in entries) {
      expect(entry['value'], isNull, reason: 'no contest running, nothing to project');
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  group('an exchange nobody typed', () {
    // The inconsistency this settles: the scorer already falls back to the
    // country file's zone, so a QSO logged with an empty exchange EARNED a zone
    // multiplier while Cabrillo printed a dash for it. Stamping the ref at save
    // makes the log, the score and the submission the same claim.
    Future<Map?> patchFor(Map<String, dynamic> qso) async {
      final host = await sharedHost(['cqww']);
      final entries = await host.invokeHookAll(
        'activity',
        method: 'processQsoBeforeSave',
        args: {
          'operation': {
            'stationCall': 'N0DEV',
            'refs': [
              {'type': 'cqww', 'mode': 'CW'},
            ],
          },
          'qso': qso,
        },
      );
      final hit = entries.where((e) => e['ok'] == true && e['value'] is Map).toList();
      return hit.isEmpty ? null : hit.first['value'] as Map;
    }

    test('is filled from the country file and recorded on the ref', () async {
      // W1AW is CQ zone 5, and the operator typed nothing.
      final patch = await patchFor({
        'band': '20m',
        'mode': 'CW',
        'their': {'call': 'W1AW'},
      });

      expect(((patch!['refs'] as List).single as Map)['theirZone'], '5');
      expect((patch['their'] as Map)['exchange'], '5');
    });

    test('never overwrites what the operator did type', () async {
      // A station operating away from its callsign's zone is exactly why the
      // field is editable; the guess must never win over it.
      final patch = await patchFor({
        'band': '20m',
        'mode': 'CW',
        'their': {'call': 'W1AW'},
        'refs': [
          {'type': 'cqww', 'theirZone': '14'},
        ],
      });

      expect(((patch!['refs'] as List).single as Map)['theirZone'], '14');
      expect((patch['their'] as Map)['exchange'], '14');
    });

    test('a call the country file cannot place is left empty, not invented', () async {
      final patch = await patchFor({'band': '20m', 'mode': 'CW', 'their': {'call': ''}});
      expect(patch, isNull, reason: 'nothing typed and nothing to guess');
    });

    test('an exchange the operator deliberately emptied stays empty', () async {
      // The core writes `theirZone: ''` for a field the operator cleared, and
      // drops the key entirely for one never filled in. That difference is the
      // only thing distinguishing "nothing was received" from "nothing was
      // entered yet", and guessing over the first would make the field
      // impossible to clear — every edit would put the zone straight back.
      final patch = await patchFor({
        'band': '20m',
        'mode': 'CW',
        'their': {'call': 'W1AW'},
        'refs': [
          {'type': 'cqww', 'theirZone': ''},
        ],
      });

      expect(patch, isNotNull, reason: 'it still projects, to clear the QSO row');
      expect(patch!.containsKey('refs'), isFalse, reason: 'nothing to record');
      expect((patch['their'] as Map)['exchange'], '');
    });
  });

  group('a deliberately emptied exchange, across every contest', () {
    // Same rule everywhere, whether or not the contest guesses: clearing a
    // field must clear the projection too, or the QSO row and a plain ADIF
    // export keep showing the exchange from the previous save.
    const cases = [
      (key: 'cqww', cleared: {'theirZone': ''}, call: 'W1AW', opFields: <String, Object>{}),
      (key: 'iaru-hf', cleared: {'theirExchange': ''}, call: 'W1AW', opFields: <String, Object>{}),
      (key: 'naqp', cleared: {'name': '', 'location': ''}, call: 'W1AW', opFields: <String, Object>{}),
      // These three never guess, so nothing put the value back — but a stale
      // `their.exchange` outliving the field is its own bug.
      (key: 'arrl-dx', cleared: {'theirExchange': ''}, call: 'W1AW', opFields: <String, Object>{}),
      (key: 'simple-contest', cleared: {'exchange': ''}, call: 'W1AW', opFields: <String, Object>{}),
      (key: 'cqwpx', cleared: {'theirSerial': ''}, call: 'W1AW', opFields: <String, Object>{}),
      (key: 'stateparks', cleared: {'park': ''}, call: 'W1AW', opFields: <String, Object>{'ref': 'OHSP'}),
    ];

    for (final c in cases) {
      test('${c.key} does not put the guess back', () async {
        final host = await sharedHost([c.key]);
        final entries = await host.invokeHookAll(
          'activity',
          method: 'processQsoBeforeSave',
          args: {
            'operation': {
              'stationCall': 'N0DEV',
              'refs': [
                {'type': c.key, 'mode': 'CW', ...c.opFields},
              ],
            },
            'qso': {
              'band': '20m',
              'mode': 'CW',
              'their': {'call': c.call},
              'refs': [
                {'type': c.key, ...c.cleared},
              ],
            },
          },
        );

        final hit = entries.where((e) => e['ok'] == true && e['value'] is Map).toList();
        expect(hit, isNotEmpty);
        final patch = hit.first['value'] as Map;
        expect(patch.containsKey('refs'), isFalse, reason: 'a blank is not worth recording');
        expect((patch['their'] as Map)['exchange'], '');
      });
    }

    test('naqp does not stamp a blank on the half it simply could not guess', () async {
      // The trap in writing a ref as an object literal: it puts BOTH keys on
      // every save, so a location that just wasn't known yet gets stamped ''
      // and is read back forever as "the operator emptied this" — the guess
      // never fires again and the state multiplier is lost for good.
      //
      // Offline, nothing resolves a US station's state, so this is the ordinary
      // case rather than a corner.
      final host = await sharedHost(['naqp']);
      Future<Map> patchFor(Map<String, dynamic> their) async {
        final entries = await host.invokeHookAll(
          'activity',
          method: 'processQsoBeforeSave',
          args: {
            'operation': {
              'stationCall': 'N0DEV',
              'refs': [
                {'type': 'naqp', 'mode': 'CW'},
              ],
            },
            'qso': {
              'band': '20m',
              'mode': 'CW',
              'their': their,
              'refs': [
                {'type': 'naqp', 'name': 'BOB'},
              ],
            },
          },
        );
        return entries.firstWhere((e) => e['ok'] == true && e['value'] is Map)['value'] as Map;
      }

      // Logged offline: name typed, nothing known about where they are.
      final offline = await patchFor({'call': 'W1AW'});
      final offlineRef = (offline['refs'] as List).single as Map;
      expect(offlineRef['name'], 'BOB');
      expect(
        offlineRef.containsKey('location'),
        isFalse,
        reason: 'unknown is not a decision — stamping it would freeze the blank forever',
      );

      // Later the lookup resolves their state and the QSO is saved again: the
      // multiplier is picked up, which only works because nothing was stamped.
      final enriched = await patchFor({'call': 'W1AW', 'guess': {'state': 'CT'}});
      expect(((enriched['refs'] as List).single as Map)['location'], 'CT');
      expect((enriched['their'] as Map)['exchange'], 'BOB CT');
    });

    test('stateparks does not put a park back from the POTA ref the QSO carries', () async {
      // The stateparks-shaped version of the same trap, and the one a hunted
      // reference makes easy to get wrong: the operator clears the park field
      // BECAUSE the station wasn't in a park this time, while the hunter chip
      // from the previous QSO is still on the row. Deriving over a cleared field
      // would submit a park they explicitly said no to.
      final host = await sharedHost(['stateparks']);
      Future<Map?> patchFor(List<Map<String, Object>> refs) async {
        final entries = await host.invokeHookAll(
          'activity',
          method: 'processQsoBeforeSave',
          args: {
            'operation': {
              'stationCall': 'N0DEV',
              'refs': [
                {'type': 'stateparks', 'ref': 'OHSP'},
              ],
            },
            'qso': {'band': '40m', 'mode': 'CW', 'their': {'call': 'W1AW'}, 'refs': refs},
          },
        );
        final hit = entries.where((e) => e['ok'] == true && e['value'] is Map).toList();
        return hit.isEmpty ? null : hit.first['value'] as Map;
      }

      // US-1932 is Ohio's ADA. Untouched, it fills the exchange in.
      final derived = await patchFor([
        {'type': 'pota', 'ref': 'US-1932'},
      ]);
      expect(((derived!['refs'] as List).single as Map)['park'], 'ADA');
      expect((derived['their'] as Map)['exchange'], 'ADA');

      // Cleared on purpose, with the same reference still there: it stays clear.
      final cleared = await patchFor([
        {'type': 'pota', 'ref': 'US-1932'},
        {'type': 'stateparks', 'park': ''},
      ]);
      expect(cleared!.containsKey('refs'), isFalse, reason: 'a blank is not worth recording');
      expect((cleared['their'] as Map)['exchange'], '');
    });

    test('naqp decides its two halves independently', () async {
      // Clearing the name must not also throw away a location that was never
      // touched — that one still gets its guess.
      final host = await sharedHost(['naqp']);
      final entries = await host.invokeHookAll(
        'activity',
        method: 'processQsoBeforeSave',
        args: {
          'operation': {
            'stationCall': 'N0DEV',
            'refs': [
              {'type': 'naqp', 'mode': 'CW'},
            ],
          },
          'qso': {
            'band': '20m',
            'mode': 'CW',
            'their': {'call': 'W1AW', 'state': 'CT', 'guess': {'name': 'Hiram'}},
            'refs': [
              {'type': 'naqp', 'name': ''},
            ],
          },
        },
      );

      final patch = entries.firstWhere((e) => e['ok'] == true && e['value'] is Map)['value'] as Map;
      final ref = (patch['refs'] as List).single as Map;
      expect(ref['name'], '', reason: 'cleared on purpose');
      expect(ref['location'], 'CT', reason: 'never touched, so still guessed');
      expect((patch['their'] as Map)['exchange'], 'CT');
    });
  });
}
