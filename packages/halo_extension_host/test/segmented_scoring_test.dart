// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The harness hands each QSO its segment-effective operation
// (docs/design/contests.md §5.1.3). Exercised through the REAL runtime because
// the whole point of putting resolution in the harness is that no extension had
// to change — a stub would prove the opposite of what matters.
//
// Two vehicles, for the two halves of it. The `k2hrc-cqww` sample contest shows
// the gate — which QSOs a contest's scorer is handed at all — because its
// multipliers and dupes are per band, so a QSO that reaches it shows up in the
// score. `ham2k-pota` shows WHICH operation each QSO is scored against, because
// its activity scorer reads the activated parks off that operation, per QSO.

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
  const contest = {'type': 'k2hrcCqww', 'mode': 'CW'};
  const park = {'type': 'potaActivation', 'ref': 'US-0001'};
  const otherPark = {'type': 'potaActivation', 'ref': 'US-0002'};

  Future<Map<String, dynamic>?> score(Map<String, dynamic> args) async {
    final host = await sharedHost(['k2hrc-cqww']);
    final result = await host.invokeHook('scoring', key: 'k2hrc-cqww', method: 'scoreQsos', args: args, timeout: const Duration(seconds: 20)) as Map?;
    return result?.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>?> scorePota(Map<String, dynamic> args) async {
    final host = await sharedHost(['ham2k-pota']);
    final result = await host.invokeHook('scoring', key: 'ham2k-pota', method: 'scoreQsos', args: args, timeout: const Duration(seconds: 20)) as Map?;
    return result?.cast<String, dynamic>();
  }

  test('without segments the harness behaves exactly as before', () async {
    final result = await score({
      'operation': {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'refs': [contest],
      },
      'qsos': [qso(0, 'DL1ABC'), qso(1, 'JA1ABC')],
      'ref': contest,
    });

    expect((result!['operationSummary'] as Map)['k2hrcCqww'], isNotNull);
    expect(((result['operationSummary'] as Map)['k2hrcCqww'] as Map)['qsos'], 2);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the OPERATION each QSO is scored against is the segment-effective one, not the base', () async {
    // The harness hands `scoreQso` a whole operation, and a scorer reads what
    // it needs off it: an activity scorer reads which parks are being
    // activated, which is exactly what an activator changes when they pack up
    // and move to the next park.
    //
    // The base operation carries only the FIRST park — which is what an
    // operation looks like after the second one was written into a break
    // override rather than onto the operation itself. A harness handing the
    // BASE operation to every QSO credits both contacts to the first park — no
    // crash, no log, a plausible number that is simply not the one the
    // operator earned.
    final contacts = [qso(0, 'DL1ABC'), qso(10, 'JA1ABC')];
    final movedAt = contacts[1]['startAtMillis'] as int;

    final result = await scorePota({
      'operation': {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'refs': [park],
      },
      'qsos': contacts,
      'ref': park,
      'segments': [
        segment(dawnOfTime, [park]),
        segment(movedAt, [otherPark]),
      ],
    });

    final activation = (result!['operationSummary'] as Map)['activation'] as Map;
    expect(activation['activatedRefs'], {'US-0001': 1, 'US-0002': 1}, reason: 'the second contact was made from the second park');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a single segment is not a timeline', () async {
    // One segment only, so the harness takes its unsegmented path and the
    // base operation stands — even where that lone segment restates it
    // differently.
    final result = await scorePota({
      'operation': {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'refs': [park],
      },
      'qsos': [qso(0, 'DL1ABC'), qso(10, 'JA1ABC')],
      'ref': park,
      'segments': [
        segment(dawnOfTime, [otherPark]),
      ],
    });

    final activation = (result!['operationSummary'] as Map)['activation'] as Map;
    expect(activation['activatedRefs'], {'US-0001': 2});
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a contest that starts at a break does not claim the log before it', () async {
    // Scorer selection spans every segment, so a contest confined to the back
    // half of a log gets invoked over the WHOLE log. Nothing else stops it from
    // counting the casual QSOs that came first — the harness has to, by seeing
    // that their segment carries no contest ref at all.
    final before = [qso(0, 'DL1ABC'), qso(1, 'JA1ABC')];
    final after = [qso(10, 'F1ABC'), qso(11, 'VK1ABC')];
    final breakAt = after.first['startAtMillis'] as int;

    final result = await score({
      // The base operation is a park activation. `scorersFor` never sees the
      // contest here — it finds it in the second segment and hands that ref
      // down.
      'operation': {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'refs': [park],
      },
      'qsos': [...before, ...after],
      'ref': contest,
      'segments': [
        segment(dawnOfTime, [park]),
        segment(breakAt, [contest]),
      ],
    });

    final summary = (result!['operationSummary'] as Map)['k2hrcCqww'] as Map;
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
        'refs': [contest],
      },
      'qsos': [...saturday, ...sunday],
      'ref': contest,
      'segments': [
        segment(dawnOfTime, [contest]),
        segment(breakAt, [park]),
      ],
    });

    final summary = (result!['operationSummary'] as Map)['k2hrcCqww'] as Map;
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
    final result =
        await host.invokeHook(
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
                  segment(DateTime.utc(2026, 3, 28, 12, 10).millisecondsSinceEpoch, [contest]),
                ],
              },
              timeout: const Duration(seconds: 20),
            )
            as Map?;

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
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: 'k2hrc-cqww', source: bundleSource('k2hrc-cqww'))],
        // The log as a host serves it: `getQsoChanges` is what the kernel's
        // copy asks, the whole log once and then from its cursor.
        onHostCall: (method, params) async => switch (method) {
          'getQsos' => log,
          'getQsoChanges' => {
            'cursor': 'test',
            'reset': params['cursor'] != 'test',
            'qsos': params['cursor'] == 'test' ? const [] : log,
            'removed': const <String>[],
          },
          _ => null,
        },
      );
      addTearDown(host.dispose);
      final result =
          await host.invokeHook(
                'scoring',
                key: 'k2hrc-cqww',
                method: 'scoreQso',
                args: {
                  // The CURRENT segment, which is what the host now sends.
                  'operation': {
                    'uuid': 'op',
                    'stationCall': 'N0DEV',
                    'refs': [contest],
                  },
                  'qso': qso(20, 'W1AW'),
                  'ref': contest,
                  'segments': ?segments,
                },
                timeout: const Duration(seconds: 20),
              )
              as Map?;
      return result?.cast<String, dynamic>();
    }

    test('does not call a pre-contest contact a duplicate', () async {
      final result = await live(
        segments: [
          segment(dawnOfTime, [park]),
          segment(breakAt, [contest]),
        ],
      );
      expect(
        (result!['alerts'] as List? ?? const []),
        isNot(contains('duplicate')),
        reason: 'W1AW was worked before the contest, so this is the first contest QSO with them',
      );
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('still sees a duplicate made inside the contest', () async {
      // The same log with the contest running throughout: now the earlier
      // W1AW IS a contest QSO and the candidate is a dupe. Without this the
      // test above would pass on a scorer that had simply stopped working.
      final result = await live(
        segments: [
          segment(dawnOfTime, [contest]),
          segment(breakAt, [contest]),
        ],
      );
      expect((result!['alerts'] as List), contains('duplicate'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('an unsegmented operation is unaffected', () async {
      final result = await live();
      expect((result!['alerts'] as List), contains('duplicate'));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
