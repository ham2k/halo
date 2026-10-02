// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Activity scoring through the REAL runtime and the REAL `ham2k-pota` bundle
// (docs/design/activities.md §4). The node tests in
// extensions/sdk/src/activityScoring.test.ts pin the award rules; this pins
// that they survive the trip — QuickJS is not node, the rules literal reaches
// the scorer through the kernel's hook registration rather than a direct call,
// and the summary strings the operator actually reads are built inside the
// runtime.

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  /// Distinct callsigns, one minute apart, so nothing here trips the duplicate
  /// rules by accident.
  List<Map<String, dynamic>> contacts(int n, {int day = 1, String band = '20m'}) => [
    for (var i = 0; i < n; i++)
      {
        'uuid': 'q$day-$i',
        'startAtMillis': DateTime.utc(2026, 7, day, 12, i).millisecondsSinceEpoch,
        'band': band,
        'mode': 'SSB',
        'our': {'call': 'N0DEV'},
        'their': {'call': 'W${i}ABC'},
      },
  ];

  Map<String, dynamic> activating(List<String> parks) => {
    'uuid': 'op',
    'stationCall': 'N0DEV',
    'refs': [
      for (final park in parks) {'type': 'potaActivation', 'ref': park},
    ],
  };

  Future<Map<String, dynamic>?> score(Map<String, dynamic> operation, List<Map<String, dynamic>> qsos) async {
    final host = await sharedHost(['ham2k-pota']);
    final result =
        await host.invokeHook(
              'scoring',
              key: 'ham2k-pota',
              method: 'scoreQsos',
              args: {'operation': operation, 'qsos': qsos, 'ref': (operation['refs'] as List).isEmpty ? null : (operation['refs'] as List).first},
              timeout: const Duration(seconds: 20),
            )
            as Map?;
    return result?.cast<String, dynamic>();
  }

  test('an activation short of ten contacts reports the gap', () async {
    final result = await score(activating(['US-0001']), contacts(7));
    final activation = ((result!['operationSummary'] as Map)['activation'] as Map);
    expect(activation['summary'], '7/10');
    expect(activation['activated'], false);
    expect(activation['activatedRefs'], {'US-0001': 7});
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('ten contacts activate the park', () async {
    final result = await score(activating(['US-0001']), contacts(10));
    final activation = ((result!['operationSummary'] as Map)['activation'] as Map);
    expect(activation['summary'], '10 ✓');
    expect(activation['activated'], true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a two-park n-fer credits both parks and needs both to clear', () async {
    final result = await score(activating(['US-0001', 'US-0002']), contacts(10));
    final activation = ((result!['operationSummary'] as Map)['activation'] as Map);
    expect(activation['activatedRefs'], {'US-0001': 10, 'US-0002': 10});
    expect(activation['summary'], '10 ✓✓');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a repeat contact on the same band and day is a duplicate that does not count', () async {
    final qsos = contacts(3);
    // A fourth contact with the same station as the first, same band and day.
    qsos.add({...contacts(1)[0], 'uuid': 'dupe', 'startAtMillis': DateTime.utc(2026, 7, 1, 13).millisecondsSinceEpoch});

    final result = await score(activating(['US-0001']), qsos);
    final verdict = ((result!['qsoScores'] as Map)['dupe'] as Map);
    expect(verdict['alerts'], contains('duplicate'));
    // Three contacts counted, not four — the point of detecting it.
    expect(((result['operationSummary'] as Map)['activation'] as Map)['activatedRefs'], {'US-0001': 3});
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the next UTC day starts the park over, and says so', () async {
    final qsos = [...contacts(2, day: 1), ...contacts(1, day: 2)];
    final result = await score(activating(['US-0001']), qsos);

    // Same callsign as day 1's first contact, a day later: not a dupe.
    expect(((result!['qsoScores'] as Map)['q2-0'] as Map)['notices'], contains('newDay'));

    final days = (result['daySections'] as List).cast<Map>();
    expect(days.length, 2);
    expect(((days[0]['scores'] as Map)['activation'] as Map)['summary'], '2/10');
    // POTA activates per day, so day two counts from zero rather than from two.
    expect(((days[1]['scores'] as Map)['activation'] as Map)['summary'], '1/10');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('hunting a park while activating another credits both sides', () async {
    final qsos = contacts(1);
    qsos[0]['refs'] = [
      {'type': 'pota', 'ref': 'US-9001'},
      {'type': 'pota', 'ref': 'US-9002'},
    ];

    final result = await score(activating(['US-0001']), qsos);
    final summary = result!['operationSummary'] as Map;
    // One on-air contact, but counted per reference on both sides: it is
    // submitted as two records, so my own park advances by two...
    expect((summary['activation'] as Map)['activatedRefs'], {'US-0001': 2});
    // ...and the P2P credit folds into the activation tally's own label
    // rather than a separate 'hunting' one.
    expect(summary['hunting'], isNull);
    expect((summary['activation'] as Map)['label'], 'POTA: 2 activation QSOs, 2 P2P QSOs');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('hunting parks with no activation of its own reads as parks hunted', () async {
    final qsos = contacts(1);
    qsos[0]['refs'] = [
      {'type': 'pota', 'ref': 'US-9001'},
      {'type': 'pota', 'ref': 'US-9002'},
    ];

    final result = await score({'uuid': 'op', 'stationCall': 'N0DEV', 'refs': []}, qsos);
    final summary = result!['operationSummary'] as Map;
    expect(summary['activation'], isNull);
    final hunting = summary['hunting'] as Map;
    expect(hunting['huntedRefs'], {'US-9001': 1, 'US-9002': 1});
    expect(hunting['label'], 'POTA: 2 parks hunted');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
