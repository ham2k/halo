// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The HUNTING side of `referenceActivity`, through the real runtime and the
// real GMA bundle. A1's six awards only recognise activations; GMA is the first
// ported program where a QSO carries the references the OTHER station was at,
// which brings a per-QSO logging control, SIG/SIG_INFO on export, and
// other-spotting.
//
// The rule that most needs pinning is how a multi-reference contact is
// submitted: one record per reference, or one naming them all. The programs
// disagree, it is not cosmetic — it decides how many contacts the award sees —
// and GMA is a joiner.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  Future<ExtensionHost> startHost({List<String> extra = const []}) async =>
      sharedHost(['gma', ...extra], onHostCall: nullHostCall);

  test('a hunting program offers a per-QSO control, keyed for search scoping', () async {
    final host = await startHost();
    final controls = (await host.invokeHook('activity', key: 'gma', method: 'loggingControls',
        args: {'operation': {'uuid': 'op'}}) as List).cast<Map>();

    expect(controls.length, 1);
    expect(controls.first['key'], 'gma/hunter');
    // Writes to the QSO's hunting type, not the operation's activation type.
    expect((controls.first['input'] as Map)['refType'], 'gma');
    expect(controls.first['allowsMultiple'], true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an activation-only award offers no logging control at all', () async {
    final host = await startHost(extra: ['wca']);
    // WCA has no hunting side, so there is nothing to record per QSO — the
    // factory must not invent a control for it. The method is simply absent,
    // which the core's fan-out (`invokeHookAll`) skips; asked directly like
    // this the kernel hands back the missing member rather than throwing.
    final controls = await host.invokeHook('activity', key: 'wca', method: 'loggingControls',
        args: {'operation': {'uuid': 'op'}}, timeout: const Duration(seconds: 10));
    expect(controls, isNull);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('hunted summits reach the export as SIG/SIG_INFO', () async {
    final host = await startHost();
    final fields = (await host.invokeHook('adifFields', key: 'gma', method: 'fieldsForOneQSO', args: {
      'qso': {'their': {'call': 'W1AW'}, 'refs': [{'type': 'gma', 'ref': 'DL/AL-001'}]},
      'operation': {'refs': [{'type': 'gmaActivation', 'ref': 'DL/AL-999'}]},
    }) as List).cast<Map>();

    expect(fields.map((f) => f['name']), ['SIG', 'SIG_INFO', 'MY_SIG', 'MY_SIG_INFO']);
    expect(fields.map((f) => f['value']), ['GMA', 'DL/AL-001', 'GMA', 'DL/AL-999']);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('GMA joins several hunted summits into one record rather than splitting', () async {
    final host = await startHost();
    // POTA and MOTA submit one record per reference; GMA, SiOTA, WWBOTA and
    // ZLOTA name them all in one. Declaring combinations here would silently
    // double what the award counts, so GMA must not declare the method at all.
    final combinations = await host.invokeHook('adifFields', key: 'gma',
        method: 'fieldCombinationsForOneQSO', args: {
      'qso': {'their': {'call': 'W1AW'}, 'refs': [{'type': 'gma', 'ref': 'DL/AL-001'}]},
      'operation': {'refs': <Map>[]},
    }, timeout: const Duration(seconds: 10));
    expect(combinations, isNull);

    final fields = (await host.invokeHook('adifFields', key: 'gma', method: 'fieldsForOneQSO', args: {
      'qso': {
        'their': {'call': 'W1AW'},
        'refs': [
          {'type': 'gma', 'ref': 'DL/AL-001'},
          {'type': 'gma', 'ref': 'DL/AL-002'},
        ],
      },
      'operation': {'refs': <Map>[]},
    }) as List).cast<Map>();
    expect(fields.firstWhere((f) => f['name'] == 'SIG_INFO')['value'], 'DL/AL-001,DL/AL-002');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('other-spotting is offered for a QSO carrying a summit, not otherwise', () async {
    final host = await startHost();

    final withRef = await host.invokeHook('spots', key: 'gma', method: 'isOtherSpotEnabled',
        args: {'qso': {'refs': [{'type': 'gma', 'ref': 'DL/AL-001'}]}}) as Map;
    expect(withRef['enabled'], true);

    final without = await host.invokeHook('spots', key: 'gma', method: 'isOtherSpotEnabled',
        args: {'qso': {'refs': <Map>[]}}) as Map;
    expect(without['enabled'], false);
  }, timeout: const Timeout(Duration(seconds: 60)));

  group('data file', () {
    Future<List<Map<String, dynamic>>> mapRows(List<dynamic> rows) async {
      final host = await startHost();
      final result = await host.invokeHook('dataFile', key: 'gma-all-summits',
          method: 'mapCsvBatch', args: {'rows': rows}, timeout: const Duration(seconds: 20)) as List;
      return result.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }

    test('keeps live summits and lower-cases the locator tail', () async {
      final entries = await mapRows([
        {
          'Reference': 'DL/AL-001',
          'Name': 'Zugspitze',
          'Latitude': '47.4211',
          'Longitude': '10.9853',
          'Maidenhead Locator': 'JN57AK',
          'Height (m)': '2962',
          'deleted': '0',
        },
      ]);

      expect(entries.length, 1);
      expect(entries.first['key'], 'DL/AL-001');
      // The association prefix, so an operator can narrow to their own country.
      expect(entries.first['subCategory'], 'DL');
      // Published upper-case; the tail is conventionally lower and the rest of
      // HaLo compares grids as plain strings.
      expect(entries.first['data']['grid'], 'JN57ak');
      expect(entries.first['data']['altitude'], 2962);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('drops summits the list has retired', () async {
      final entries = await mapRows([
        {'Reference': 'DL/AL-001', 'Name': 'Live', 'Latitude': '47.4', 'Longitude': '10.9', 'deleted': '0'},
        {'Reference': 'DL/AL-002', 'Name': 'Retired', 'Latitude': '47.4', 'Longitude': '10.9', 'deleted': '1'},
      ]);
      expect(entries.map((e) => e['key']), ['DL/AL-001']);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('derives a grid when the list publishes none', () async {
      final entries = await mapRows([
        {
          'Reference': 'UNM-SH001',
          'Name': 'No locator',
          'Latitude': '47.4211',
          'Longitude': '10.9853',
          'Maidenhead Locator': '',
          'deleted': '0',
        },
      ]);
      expect(entries.first['data']['grid'], startsWith('JN57'));
      // The UNM series follows no prefix rule, so there is no association to
      // split off — the whole reference is its own scope.
      expect(entries.first['subCategory'], 'UNM-SH001');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
