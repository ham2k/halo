// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One contact can owe several ADIF records: work a station standing in two
// parks and each park is submitted separately, which is the same reason it
// counts twice toward an activation (docs/design/activities.md §4). The scorer
// and the exporter have to agree about that, so this drives BOTH the `adif`
// and `pota` bundles through the real runtime — the record-splitting only
// exists once the exporter can see POTA's `fieldCombinationsForOneQSO`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

void main() {
  final assets = Directory('../../app/assets/extensions');
  File bundle(String key) => File('${assets.path}/$key.js');

  bool bundlesMissing() =>
      !bundle('kernel').existsSync() || !bundle('adif').existsSync() || !bundle('pota').existsSync();

  final contactAt = DateTime.utc(2026, 7, 1, 14, 30, 15);

  Map<String, dynamic> qsoHunting(List<String> parks) => {
        'uuid': 'q1',
        'our': {'call': 'N0DEV', 'sent': '59'},
        'their': {'call': 'W1AW', 'sent': '59'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': contactAt.millisecondsSinceEpoch,
        'refs': [for (final park in parks) {'type': 'pota', 'ref': park}],
      };

  Future<String> exportAdif(List<String> activating, Map<String, dynamic> qso) async {
    final host = await ExtensionHost.start(
      kernelSource: bundle('kernel').readAsStringSync(),
      extensions: [
        ExtensionBundle(key: 'adif', source: bundle('adif').readAsStringSync()),
        ExtensionBundle(key: 'pota', source: bundle('pota').readAsStringSync()),
      ],
    );
    addTearDown(host.dispose);
    final result = await host.invokeHook(
      'export',
      key: 'adif',
      method: 'generateExport',
      args: {
        'operation': {
          'uuid': 'op',
          'stationCall': 'N0DEV',
          'refs': [for (final park in activating) {'type': 'potaActivation', 'ref': park}],
        },
        'qsos': [qso],
        'exportType': 'adif',
      },
      timeout: const Duration(seconds: 20),
    ) as Map?;
    return (result!['content'] as String);
  }

  /// Record bodies, without the header block.
  List<String> recordsIn(String adif) =>
      adif.split('<EOR>').where((part) => part.contains('<CALL:')).toList();

  test('a two-park P2P is written as two records, one per park', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }
    final adif = await exportAdif(['US-0001'], qsoHunting(['US-9001', 'US-9002']));
    final records = recordsIn(adif);

    expect(records.length, 2);
    // Each record names ONE hunted park, not the comma-joined pair — that is
    // what makes them separately submittable.
    expect(records[0], contains('<SIG_INFO:7>US-9001'));
    expect(records[0], contains('<POTA_REF:7>US-9001'));
    expect(records[1], contains('<SIG_INFO:7>US-9002'));
    expect(records[1], contains('<POTA_REF:7>US-9002'));
    // Both still carry the contact itself and the park being activated.
    for (final record in records) {
      expect(record, contains('<CALL:4>W1AW'));
      expect(record, contains('<MY_POTA_REF:7>US-0001'));
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the second record is shifted a second so it is not read as a duplicate', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built');
      return;
    }
    final adif = await exportAdif(['US-0001'], qsoHunting(['US-9001', 'US-9002']));
    final records = recordsIn(adif);

    expect(records[0], contains('<TIME_ON:6>143015'));
    expect(records[1], contains('<TIME_ON:6>143016'));
    // Same contact, so the date is unchanged.
    for (final record in records) {
      expect(record, contains('<QSO_DATE:8>20260701'));
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a contact at a single park is still one record, unshifted', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built');
      return;
    }
    final adif = await exportAdif(['US-0001'], qsoHunting(['US-9001']));
    final records = recordsIn(adif);

    expect(records.length, 1);
    expect(records[0], contains('<TIME_ON:6>143015'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an ordinary hunter, at no park, is one record', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built');
      return;
    }
    final adif = await exportAdif(['US-0001'], qsoHunting([]));
    final records = recordsIn(adif);

    expect(records.length, 1);
    expect(records[0], contains('<MY_POTA_REF:7>US-0001'));
    // Nothing was hunted, so no hunted-park fields at all.
    expect(records[0], isNot(contains('<SIG_INFO:')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('POTA declaring both hook methods does not write its fields twice', () async {
    if (bundlesMissing()) {
      markTestSkipped('bundles not built');
      return;
    }
    final adif = await exportAdif(['US-0001'], qsoHunting(['US-9001']));
    // `fieldsForOneQSO` and `fieldCombinationsForOneQSO` both answer for POTA;
    // the exporter must take only the combinations.
    expect('<MY_SIG:4>POTA'.allMatches(adif).length, 1);
    expect('<SIG:4>POTA'.allMatches(adif).length, 1);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
