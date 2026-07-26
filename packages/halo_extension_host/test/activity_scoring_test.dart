// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Activity scoring through the REAL runtime and the REAL POTA bundle
// (docs/design/activities.md §4). The node tests in
// extensions/sdk/src/activityScoring.test.ts pin the award rules; this pins
// that they survive the trip — QuickJS is not node, the rules literal reaches
// the scorer through the kernel's hook registration rather than a direct call,
// and the summary strings the operator actually reads are built inside the
// runtime.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

void main() {
  final assets = Directory('../../app/assets/extensions');
  File bundle(String key) => File('${assets.path}/$key.js');

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
        'refs': [for (final park in parks) {'type': 'potaActivation', 'ref': park}],
      };

  Future<Map<String, dynamic>?> score(
    Map<String, dynamic> operation,
    List<Map<String, dynamic>> qsos,
  ) async {
    final host = await ExtensionHost.start(
      kernelSource: bundle('kernel').readAsStringSync(),
      extensions: [ExtensionBundle(key: 'pota', source: bundle('pota').readAsStringSync())],
    );
    addTearDown(host.dispose);
    final result = await host.invokeHook(
      'scoring',
      key: 'pota',
      method: 'scoreQsos',
      args: {
        'operation': operation,
        'qsos': qsos,
        'ref': (operation['refs'] as List).isEmpty ? null : (operation['refs'] as List).first,
      },
      timeout: const Duration(seconds: 20),
    ) as Map?;
    return result?.cast<String, dynamic>();
  }

  bool bundlesMissing() => !bundle('kernel').existsSync() || !bundle('pota').existsSync();

  test('an activation short of ten contacts reports the gap', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }
    final result = await score(activating(['US-0001']), contacts(7));
    final activation = ((result!['operationSummary'] as Map)['activation'] as Map);
    expect(activation['summary'], '7/10');
    expect(activation['activated'], false);
    expect(activation['activatedRefs'], {'US-0001': 7});
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('ten contacts activate the park', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built');
      return;
    }
    final result = await score(activating(['US-0001']), contacts(10));
    final activation = ((result!['operationSummary'] as Map)['activation'] as Map);
    expect(activation['summary'], '10 ✓');
    expect(activation['activated'], true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a two-park n-fer credits both parks and needs both to clear', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built');
      return;
    }
    final result = await score(activating(['US-0001', 'US-0002']), contacts(10));
    final activation = ((result!['operationSummary'] as Map)['activation'] as Map);
    expect(activation['activatedRefs'], {'US-0001': 10, 'US-0002': 10});
    expect(activation['summary'], '10 ✓✓');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a repeat contact on the same band and day is a duplicate that does not count', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built');
      return;
    }
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
    if (bundlesMissing()) {
      markTestSkipped('bundles not built');
      return;
    }
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
    if (bundlesMissing()) {
      markTestSkipped('bundles not built');
      return;
    }
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
    // ...and two references are hunted.
    expect((summary['hunting'] as Map)['huntedRefs'], {'US-9001': 1, 'US-9002': 1});
  }, timeout: const Timeout(Duration(seconds: 60)));
}
