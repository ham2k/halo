// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The four hunt-and-activate awards beyond GMA, through the real runtime.
// Everything generic about them comes from `referenceActivity` and
// `activityScorer`, which have their own tests; this covers what each program
// alone decides — its list's shape and the two awards whose activation bar
// depends on WHICH reference is being activated. Anything that fetches is in
// spot_network_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  Future<ExtensionHost> hostFor(String key) => sharedHost([key], onHostCall: nullHostCall);

  Future<List<Map<String, dynamic>>> mapCsv(String ext, String dfKey, List<dynamic> rows) async {
    final host = await hostFor(ext);
    final result = await host.invokeHook('dataFile', key: dfKey, method: 'mapCsvBatch',
        args: {'rows': rows}, timeout: const Duration(seconds: 20)) as List;
    return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  // --- data files -----------------------------------------------------------

  test('mota keeps mills with an open validity window and drops retired ones', () async {
    // `21991231` is the list's way of saying "no end date"; anything else has
    // been retired, so a mapper that ignored the column would resurrect mills.
    final entries = await mapCsv('mota', 'mota-all-mills', [
      {'Reference': 'X00001', 'Name': 'De Vlijt', 'District': 'Noord-Holland', 'Function': 'Windmill',
       'Latitude': '52.4', 'Longitude': '4.8', 'Maidenhead Locator': 'JO22HK', 'valid to': '21991231'},
      {'Reference': 'X00002', 'Name': 'Gone', 'District': 'Utrecht',
       'Latitude': '52.1', 'Longitude': '5.1', 'valid to': '20180101'},
    ]);

    expect(entries.map((e) => e['key']), ['X00001']);
    expect(entries.first['subCategory'], 'Noord-Holland');
    expect(entries.first['data']['type'], 'Windmill');
    expect(entries.first['data']['grid'], 'JO22hk');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('siota reads its own column names and keeps the published locator', () async {
    final entries = await mapCsv('siota', 'siota-all-silos', [
      {'SILO_CODE': 'VK-ABC123', 'NAME': 'Wallup', 'LOCALITY': 'Wallup', 'STATE': 'VIC',
       'LOCATOR': 'QF12ab', 'LAT': '-36.4', 'LNG': '142.3'},
    ]);

    expect(entries.length, 1);
    expect(entries.first['key'], 'VK-ABC123');
    // The Australian state, which is how a VK operator narrows a search.
    expect(entries.first['subCategory'], 'VIC');
    expect(entries.first['data']['grid'], 'QF12ab');
    expect(entries.first['lat'], closeTo(-36.4, 0.01));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('wwbota falls back to the reference country when the list omits DXCC', () async {
    final entries = await mapCsv('wwbota', 'wwbota-all-bunkers', [
      {'Reference': 'B/G-0001', 'Name': 'With DXCC', 'Type': 'Pillbox',
       'Lat': '51.5', 'Long': '-0.1', 'Maidenhead': 'IO91WM', 'DXCC': '223'},
      {'Reference': 'B/S5-0001', 'Name': 'No DXCC', 'Type': 'Bunker',
       'Lat': '46.0', 'Long': '14.5', 'Locator': 'JN76AA', 'DXCC': ''},
    ]);

    expect(entries.length, 2);
    // DXCC 223 is England; the code is authoritative when present.
    expect(entries[0]['subCategory'], 'G');
    expect(entries[0]['data']['grid'], 'IO91wm');
    // Without it, the country segment of the reference itself is the fallback,
    // and the column may be `Locator` rather than `Maidenhead`.
    expect(entries[1]['subCategory'], 'S5');
    expect(entries[1]['data']['grid'], 'JN76aa');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('zlota reads x as longitude and y as latitude', () async {
    // The list is drawn from a map layer, so the coordinates are named for
    // screen axes — swapping them would put every reference in the wrong ocean.
    final host = await hostFor('zlota');
    final result = await host.invokeHook('dataFile', key: 'zlota-all-references',
        method: 'mapJsonBatch', args: {
      'entries': [
        {'code': 'ZLH/AA-001', 'name': 'Angelus Hut', 'asset_type': 'hut', 'x': 172.7, 'y': -41.8},
      ],
    }, timeout: const Duration(seconds: 20)) as List;
    final entries = result.map((e) => (e as Map).cast<String, dynamic>()).toList();

    expect(entries.first['key'], 'ZLH/AA-001');
    expect(entries.first['lat'], closeTo(-41.8, 0.01));
    expect(entries.first['lon'], closeTo(172.7, 0.01));
    // The kind of place is both the search scope and what sets the bar.
    expect(entries.first['subCategory'], 'hut');
  }, timeout: const Timeout(Duration(seconds: 60)));

  // --- thresholds that depend on the reference ------------------------------

  Future<Map<String, dynamic>> scoreFor(String ext, String activationType, String ref, int contacts) async {
    final host = await hostFor(ext);
    final result = await host.invokeHook('scoring', key: ext, method: 'scoreQsos', args: {
      'operation': {'uuid': 'op', 'refs': [{'type': activationType, 'ref': ref}]},
      'qsos': [
        for (var i = 0; i < contacts; i++)
          {
            'uuid': 'q$i',
            'their': {'call': 'W${i}ABC'},
            'band': '20m',
            'mode': 'SSB',
            'startAtMillis': DateTime.utc(2026, 7, 1, 12, i).millisecondsSinceEpoch,
          },
      ],
      'ref': {'type': activationType, 'ref': ref},
    }, timeout: const Duration(seconds: 20)) as Map;
    return ((result['operationSummary'] as Map)['activation'] as Map).cast<String, dynamic>();
  }

  test('wwbota asks 10 contacts in Slovenia and 25 elsewhere', () async {
    expect((await scoreFor('wwbota', 'wwbotaActivation', 'B/S5-0001', 3))['summary'], '3/10');
    expect((await scoreFor('wwbota', 'wwbotaActivation', 'B/G-0001', 3))['summary'], '3/25');
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('zlota asks one contact for a hut and four for a lighthouse', () async {
    // The kind of place is the THIRD character of the reference.
    final hut = await scoreFor('zlota', 'zlotaActivation', 'ZLH/AA-001', 1);
    expect(hut['activated'], true);

    final lighthouse = await scoreFor('zlota', 'zlotaActivation', 'ZLB/001', 1);
    expect(lighthouse['summary'], '1/4');
    expect(lighthouse['activated'], false);
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('mota reports no activation tally at all', () async {
    // app-polo's MOTA has duplicate rules but no accumulator — mills are never
    // counted toward anything, and inventing a threshold would be worse than
    // showing none.
    final host = await hostFor('mota');
    final result = await host.invokeHook('scoring', key: 'mota', method: 'scoreQsos', args: {
      'operation': {'uuid': 'op', 'refs': [{'type': 'motaActivation', 'ref': 'X00001'}]},
      'qsos': [
        {'uuid': 'q0', 'their': {'call': 'W1AW'}, 'band': '20m', 'mode': 'SSB',
         'startAtMillis': DateTime.utc(2026, 7, 1, 12).millisecondsSinceEpoch},
      ],
      'ref': {'type': 'motaActivation', 'ref': 'X00001'},
    }, timeout: const Duration(seconds: 20)) as Map;

    expect((result['operationSummary'] as Map)['activation'], isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Spot feeds and posting live in spot_network_test.dart, over the
  // `httpClient` seam.
}
