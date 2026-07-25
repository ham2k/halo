// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The harness hands each QSO its segment-effective operation
// (docs/design/contests.md §5.1.3). Exercised through the REAL runtime because
// the whole point of putting resolution in the harness is that no extension had
// to change — a stub would prove the opposite of what matters.
//
// CQ WW is the vehicle: its zone multipliers are per band and its points depend
// on the operation's station call, so a segment that changes either shows up in
// the score rather than only in an argument.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

void main() {
  final assets = Directory('../../app/assets/extensions');
  File bundle(String key) => File('${assets.path}/$key.js');

  Map<String, dynamic> qso(int i, String call, {String band = '20m', int day = 28}) => {
        'uuid': 'q$i',
        'startAtMillis': DateTime.utc(2026, 3, day, 12, i).millisecondsSinceEpoch,
        'band': band,
        'mode': 'CW',
        'our': {'call': 'N0DEV'},
        'their': {'call': call},
      };

  Map<String, dynamic> segment(int fromMillis, List<Map<String, dynamic>> refs) => {
        'fromMillis': fromMillis,
        'operation': {'uuid': 'op', 'stationCall': 'N0DEV', 'refs': refs},
      };

  const dawnOfTime = -4611686018427387904; // -1 << 62, as SegmentedOperation writes it
  const cqwwCW = {'type': 'cqww', 'mode': 'CW'};
  const park = {'type': 'pota', 'ref': 'US-0001'};

  Future<Map<String, dynamic>?> score(Map<String, dynamic> args) async {
    final host = await ExtensionHost.start(
      kernelSource: bundle('kernel').readAsStringSync(),
      extensions: [ExtensionBundle(key: 'cqww', source: bundle('cqww').readAsStringSync())],
    );
    addTearDown(host.dispose);
    final result = await host.invokeHook(
      'scoring',
      key: 'cqww',
      method: 'scoreQsos',
      args: args,
      timeout: const Duration(seconds: 20),
    ) as Map?;
    return result?.cast<String, dynamic>();
  }

  test('without segments the harness behaves exactly as before', () async {
    if (!bundle('kernel').existsSync() || !bundle('cqww').existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }
    final result = await score({
      'operation': {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'refs': [
          {'type': 'cqww', 'mode': 'CW'},
        ],
      },
      'qsos': [qso(0, 'DL1ABC'), qso(1, 'JA1ABC')],
      'ref': {'type': 'cqww', 'mode': 'CW'},
    });

    expect((result!['operationSummary'] as Map)['cqww'], isNotNull);
    expect(((result['operationSummary'] as Map)['cqww'] as Map)['qsos'], 2);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a segment that changes the contest mode changes what scores', () async {
    if (!bundle('kernel').existsSync() || !bundle('cqww').existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }
    // Two QSOs, both CW. The operation starts as a CW contest and a break
    // switches it to SSB — so the second QSO is now in the wrong mode and must
    // stop counting. If the harness ignored segments, both would score.
    final qsos = [qso(0, 'DL1ABC'), qso(10, 'JA1ABC')];
    final breakAt = qsos[1]['startAtMillis'] as int;

    final result = await score({
      'operation': {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'refs': [
          {'type': 'cqww', 'mode': 'CW'},
        ],
      },
      'qsos': qsos,
      'ref': {'type': 'cqww', 'mode': 'CW'},
      'segments': [
        {
          'fromMillis': -4611686018427387904,
          'operation': {
            'uuid': 'op',
            'stationCall': 'N0DEV',
            'refs': [
              {'type': 'cqww', 'mode': 'CW'},
            ],
          },
        },
        {
          'fromMillis': breakAt,
          'operation': {
            'uuid': 'op',
            'stationCall': 'N0DEV',
            'refs': [
              {'type': 'cqww', 'mode': 'SSB'},
            ],
          },
        },
      ],
    });

    final summary = (result!['operationSummary'] as Map)['cqww'] as Map;
    expect(summary['qsos'], 1, reason: 'the post-break CW QSO is off-mode for an SSB segment');

    final scores = (result['qsoScores'] as Map).cast<String, dynamic>();
    expect((scores['q0'] as Map)['value'], greaterThan(0));
    expect((scores['q10'] as Map)['value'], 0);
    expect(((scores['q10'] as Map)['alerts'] as List), contains('invalidMode'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a scorer sees the ref its own segment restates, not the selection ref', () async {
    if (!bundle('kernel').existsSync() || !bundle('cqww').existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }
    // Same shape, inverted: selection happened on the CW ref, but every QSO
    // falls inside an SSB segment. All of them are SSB, so all must count —
    // which only holds if the harness re-resolved the ref per segment rather
    // than passing the one selection handed it.
    final qsos = [qso(0, 'DL1ABC', band: '20m'), qso(10, 'JA1ABC', band: '20m')]
        .map((q) => {...q, 'mode': 'SSB'})
        .toList();

    final result = await score({
      'operation': {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'refs': [
          {'type': 'cqww', 'mode': 'CW'},
        ],
      },
      'qsos': qsos,
      'ref': {'type': 'cqww', 'mode': 'CW'},
      'segments': [
        {
          'fromMillis': -4611686018427387904,
          'operation': {
            'uuid': 'op',
            'stationCall': 'N0DEV',
            'refs': [
              {'type': 'cqww', 'mode': 'SSB'},
            ],
          },
        },
      ],
    });

    // One segment only, so the harness takes its unsegmented path and the
    // selection ref stands — CW against SSB QSOs scores nothing.
    final summary = (result!['operationSummary'] as Map)['cqww'] as Map;
    expect(summary['qsos'], 0, reason: 'a single segment is not a timeline; the passed ref is used');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a contest that starts at a break does not claim the log before it', () async {
    if (!bundle('kernel').existsSync() || !bundle('cqww').existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }
    // Scorer selection spans every segment, so a contest confined to the back
    // half of a log gets invoked over the WHOLE log. Nothing else stops it from
    // counting the casual QSOs that came first — the harness has to, by seeing
    // that their segment carries no cqww ref at all.
    final before = [qso(0, 'DL1ABC'), qso(1, 'JA1ABC')];
    final after = [qso(10, 'F1ABC'), qso(11, 'VK1ABC')];
    final breakAt = after.first['startAtMillis'] as int;

    final result = await score({
      // The base operation is a park activation. `scorersFor` never sees cqww
      // here — it finds it in the second segment and hands that ref down.
      'operation': {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'refs': [park],
      },
      'qsos': [...before, ...after],
      'ref': cqwwCW,
      'segments': [
        segment(dawnOfTime, [park]),
        segment(breakAt, [cqwwCW]),
      ],
    });

    final summary = (result!['operationSummary'] as Map)['cqww'] as Map;
    expect(summary['qsos'], 2, reason: 'only the two QSOs made inside the contest segment');

    // Not merely zero-valued: the pre-contest QSOs are not this scorer's to
    // judge, so it reports no verdict for them at all. A zero would still put
    // an entry on the row and their zones into the multiplier table.
    final scores = (result['qsoScores'] as Map).cast<String, dynamic>();
    expect(scores.keys.toSet(), {'q10', 'q11'});
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a contest that ends at a break stops scoring there', () async {
    if (!bundle('kernel').existsSync() || !bundle('cqww').existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }
    // The mirror case, and the one an operator actually produces: contest all
    // Saturday, park activation on Sunday. Sunday's QSOs are not contest QSOs
    // and must not reach the day summary either — a Cabrillo built from this
    // would otherwise be a false claim.
    final saturday = [qso(0, 'DL1ABC'), qso(1, 'JA1ABC')];
    final sunday = [qso(10, 'F1ABC', day: 29), qso(11, 'VK1ABC', day: 29)];
    final breakAt = sunday.first['startAtMillis'] as int;

    final result = await score({
      'operation': {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'refs': [cqwwCW],
      },
      'qsos': [...saturday, ...sunday],
      'ref': cqwwCW,
      'segments': [
        segment(dawnOfTime, [cqwwCW]),
        segment(breakAt, [park]),
      ],
    });

    final summary = (result!['operationSummary'] as Map)['cqww'] as Map;
    expect(summary['qsos'], 2, reason: 'Sunday is a park activation, not the contest');

    final days = (result['daySections'] as List).cast<Map>();
    expect(days, hasLength(1), reason: 'a day with no contest QSOs is not a contest day');
    expect(days.single['count'], 2);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an always-scoped scorer is untouched by the gate', () async {
    if (!bundle('kernel').existsSync() || !bundle('scoring').existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }
    // The gate keys on the scorer's own refTypes. Core scoring is scoped
    // 'always', so it has none, is handed no ref to begin with, and must keep
    // seeing every QSO however the segments are drawn — otherwise segmenting a
    // log would silently switch off the scoring every operation depends on.
    final host = await ExtensionHost.start(
      kernelSource: bundle('kernel').readAsStringSync(),
      extensions: [ExtensionBundle(key: 'scoring', source: bundle('scoring').readAsStringSync())],
    );
    addTearDown(host.dispose);

    final result = await host.invokeHook(
      'scoring',
      key: 'core',
      method: 'scoreQsos',
      args: {
        'operation': {
          'uuid': 'op',
          'stationCall': 'N0DEV',
          'refs': [park],
        },
        'qsos': [qso(0, 'DL1ABC'), qso(10, 'JA1ABC')],
        'segments': [
          segment(dawnOfTime, [park]),
          segment(DateTime.utc(2026, 3, 28, 12, 10).millisecondsSinceEpoch, [cqwwCW]),
        ],
      },
      timeout: const Duration(seconds: 20),
    ) as Map?;

    expect((result!['qsoScores'] as Map).keys.toSet(), {'q0', 'q10'});
  }, timeout: const Timeout(Duration(seconds: 60)));

  group('the live single-candidate pass', () {
    // This one runs cold on every debounced keystroke — `ExtensionService`
    // sends no `resumeFrom` — so it rebuilds the scoresheet from the log each
    // time. That rebuild is the same fold, and it needs the same timeline, or
    // the dupe check the operator is watching disagrees with the score they
    // were just shown.
    late List<Map<String, dynamic>> log;
    late int breakAt;

    setUp(() {
      // W1AW worked before the contest started, then a contest QSO.
      log = [qso(0, 'W1AW'), qso(10, 'DL1ABC')];
      breakAt = log[1]['startAtMillis'] as int;
    });

    Future<Map<String, dynamic>?> live({List<Map<String, dynamic>>? segments}) async {
      final host = await ExtensionHost.start(
        kernelSource: bundle('kernel').readAsStringSync(),
        extensions: [ExtensionBundle(key: 'cqww', source: bundle('cqww').readAsStringSync())],
        onHostCall: (method, params) async => method == 'getQsos' ? log : null,
      );
      addTearDown(host.dispose);
      final result = await host.invokeHook(
        'scoring',
        key: 'cqww',
        method: 'scoreQso',
        args: {
          // The CURRENT segment, which is what the host now sends.
          'operation': {
            'uuid': 'op',
            'stationCall': 'N0DEV',
            'refs': [cqwwCW],
          },
          'qso': qso(20, 'W1AW'),
          'ref': cqwwCW,
          'segments': ?segments,
        },
        timeout: const Duration(seconds: 20),
      ) as Map?;
      return result?.cast<String, dynamic>();
    }

    test('does not call a pre-contest contact a duplicate', () async {
      if (!bundle('kernel').existsSync() || !bundle('cqww').existsSync()) {
        markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
        return;
      }
      final result = await live(segments: [
        segment(dawnOfTime, [park]),
        segment(breakAt, [cqwwCW]),
      ]);
      expect(
        (result!['alerts'] as List),
        isNot(contains('duplicate')),
        reason: 'W1AW was worked before the contest, so this is the first contest QSO with them',
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('still sees a duplicate made inside the contest', () async {
      if (!bundle('kernel').existsSync() || !bundle('cqww').existsSync()) {
        markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
        return;
      }
      // The same log with the contest running throughout: now the earlier
      // W1AW IS a contest QSO and the candidate is a dupe. Without this the
      // test above would pass on a scorer that had simply stopped working.
      final result = await live(segments: [
        segment(dawnOfTime, [cqwwCW]),
        segment(breakAt, [cqwwCW]),
      ]);
      expect((result!['alerts'] as List), contains('duplicate'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an unsegmented operation is unaffected', () async {
      if (!bundle('kernel').existsSync() || !bundle('cqww').existsSync()) {
        markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
        return;
      }
      final result = await live();
      expect((result!['alerts'] as List), contains('duplicate'));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
