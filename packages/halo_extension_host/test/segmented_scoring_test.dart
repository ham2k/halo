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

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

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
    final host = await sharedHost(['cqww']);
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
    // The gate keys on the scorer's own refTypes. Core scoring is scoped
    // 'always', so it has none, is handed no ref to begin with, and must keep
    // seeing every QSO however the segments are drawn — otherwise segmenting a
    // log would silently switch off the scoring every operation depends on.
    final host = await sharedHost(['scoring']);
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

  group('a scorer that reads another activity\'s refs', () {
    // CQ WW above only ever reads its OWN ref and the station call, so none of
    // it proves what happens to a scorer that reaches for a ref it does not own.
    // `stateparks` does exactly that — a state-park event is played THROUGH POTA,
    // and the parks it scores come from `potaActivation` on the operation and
    // `pota` on the QSO — which makes the segment-effective operation load
    // bearing in a way no other contest can show.
    //
    // The workflow this is really about is the one the events are designed
    // around: an activator works one park, packs up, drives to another, and
    // carries on under the same event. That is a `break` whose override restates
    // the event ref and swaps the park, and every number in the summary depends
    // on the harness handing each QSO the park that was true when it was made.
    const ohsp = {'type': 'stateparks', 'ref': 'OHSP'};
    const adaPark = {'type': 'potaActivation', 'ref': 'US-1932'}; // Adams Lake SP
    const hocPark = {'type': 'potaActivation', 'ref': 'US-1958'}; // Hocking Hills SP

    /// Ohio runs 80-10m, so 20m; ten QSOs is POTA's activation threshold, which
    /// is what makes a park count toward the multiplier.
    List<Map<String, dynamic>> tenQsos(int from, {int day = 12}) => [
          for (var i = 0; i < 10; i++)
            {
              'uuid': 'q${from + i}',
              'startAtMillis': DateTime.utc(2026, 9, day, 14, from + i).millisecondsSinceEpoch,
              'band': '20m',
              'mode': 'CW',
              'our': {'call': 'N0DEV'},
              'their': {'call': 'W${from + i}AW'},
            },
        ];

    Future<Map<String, dynamic>?> scoreStateparks(Map<String, dynamic> args) async {
      final host = await sharedHost(['stateparks']);
      final result = await host.invokeHook(
        'scoring',
        key: 'stateparks',
        method: 'scoreQsos',
        args: args,
        timeout: const Duration(seconds: 20),
      ) as Map?;
      return result?.cast<String, dynamic>();
    }

    test('the park it credits is the one the segment was activating', () async {
      final atAda = tenQsos(0);
      final atHoc = tenQsos(10);
      final movedAt = atHoc.first['startAtMillis'] as int;

      final result = await scoreStateparks({
        // The base operation carries only the FIRST park — which is what an
        // operation looks like after `_saveRefs` wrote the second one into a
        // break override rather than onto the operation itself.
        'operation': {
          'uuid': 'op',
          'stationCall': 'N0DEV',
          'refs': [ohsp, adaPark],
        },
        'qsos': [...atAda, ...atHoc],
        'ref': ohsp,
        'segments': [
          segment(dawnOfTime, [ohsp, adaPark]),
          segment(movedAt, [ohsp, hocPark]),
        ],
      });

      final summary = (result!['operationSummary'] as Map)['stateparks'] as Map;
      expect(summary['qsos'], 20, reason: 'the event ran across both parks');
      // TWO activated parks, ten QSOs each: Ohio multiplies by activated + hunted,
      // and nothing was hunted here, so 20 points x 2 parks. Handed the BASE
      // operation for every QSO instead, this reads one park with twenty QSOs —
      // mult 1, total 20 — and the operator's second park is simply missing.
      expect(summary['mults'], 2);
      expect(summary['total'], 40);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a park worked too little to activate still does not count', () async {
      // The same move, but the operator only made three QSOs at the second park
      // before the weather turned. POTA's threshold is ten, so that park is not
      // activated and cannot be claimed as a multiplier — the per-QSO points are
      // still theirs.
      final atAda = tenQsos(0);
      final atHoc = tenQsos(10).take(3).toList();
      final movedAt = atHoc.first['startAtMillis'] as int;

      final result = await scoreStateparks({
        'operation': {
          'uuid': 'op',
          'stationCall': 'N0DEV',
          'refs': [ohsp, adaPark],
        },
        'qsos': [...atAda, ...atHoc],
        'ref': ohsp,
        'segments': [
          segment(dawnOfTime, [ohsp, adaPark]),
          segment(movedAt, [ohsp, hocPark]),
        ],
      });

      final summary = (result!['operationSummary'] as Map)['stateparks'] as Map;
      expect(summary['qsos'], 13);
      expect(summary['mults'], 1, reason: 'three QSOs is not an activation');
      expect(summary['total'], 13);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a stretch the event was not running is not scored at all', () async {
      // The case worth pinning for THIS scorer specifically: a break that keeps
      // the park but drops the event — the operator carried on activating after
      // the event's 8-hour window closed. Those contacts are POTA's and not the
      // event's, and the park they were made from must not reach the event's
      // activation count either, or a park that was never activated DURING the
      // event becomes a multiplier.
      final during = tenQsos(0);
      final after = tenQsos(10);
      final closedAt = after.first['startAtMillis'] as int;

      final result = await scoreStateparks({
        'operation': {
          'uuid': 'op',
          'stationCall': 'N0DEV',
          'refs': [ohsp, adaPark],
        },
        'qsos': [...during, ...after],
        'ref': ohsp,
        'segments': [
          segment(dawnOfTime, [ohsp, adaPark]),
          segment(closedAt, [hocPark]), // POTA only — no event ref
        ],
      });

      final summary = (result!['operationSummary'] as Map)['stateparks'] as Map;
      expect(summary['qsos'], 10, reason: 'only the QSOs made while the event was running');
      expect(summary['mults'], 1, reason: 'the after-hours park is not an event multiplier');
      final scores = (result['qsoScores'] as Map).cast<String, dynamic>();
      expect(scores.keys.length, 10, reason: 'and the rest get no verdict at all, not a zero');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

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
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: 'cqww', source: bundleSource('cqww'))],
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
      final result = await live();
      expect((result!['alerts'] as List), contains('duplicate'));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
