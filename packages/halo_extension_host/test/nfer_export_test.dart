// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One contact can owe several ADIF records: work a station standing in two
// parks and each park is submitted separately, which is the same reason it
// counts twice toward an activation (docs/design/activities.md §4). The scorer
// and the exporter have to agree about that, so this drives BOTH the `adif`
// and `ham2k-pota` bundles through the real runtime — the record-splitting only
// exists once the exporter can see POTA's `fieldCombinationsForOneQSO`.
//
// Only in POTA's own file, though. The full ADIF is the operator's copy of the
// log, and a split there reimports as two contacts.

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  final contactAt = DateTime.utc(2026, 7, 1, 14, 30, 15);

  Map<String, dynamic> qsoHunting(List<String> parks) => {
    'uuid': 'q1',
    'our': {'call': 'N0DEV', 'sent': '59'},
    'their': {'call': 'W1AW', 'sent': '59'},
    'band': '20m',
    'mode': 'SSB',
    'startAtMillis': contactAt.millisecondsSinceEpoch,
    'refs': [
      for (final park in parks) {'type': 'pota', 'ref': park},
    ],
  };

  /// POTA's own file, unless [full] asks for the whole-log export.
  Future<String> exportAdif(List<String> activating, Map<String, dynamic> qso, {bool full = false}) async {
    final host = await sharedHost(['adif', 'ham2k-pota']);
    final result =
        await host.invokeHook(
              'export',
              key: 'adif',
              method: 'generateExport',
              args: {
                'operation': {
                  'uuid': 'op',
                  'stationCall': 'N0DEV',
                  'refs': [
                    for (final park in activating) {'type': 'potaActivation', 'ref': park},
                  ],
                },
                'qsos': [qso],
                'exportType': 'adif',
                if (!full) 'mainHandler': 'ham2k-pota',
              },
              timeout: const Duration(seconds: 20),
            )
            as Map?;
    return (result!['content'] as String);
  }

  /// Record bodies, without the header block.
  List<String> recordsIn(String adif) => adif.split('<EOR>').where((part) => part.contains('<CALL:')).toList();

  test('a two-park P2P is written as two records, one per park', () async {
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

  test('the full ADIF writes a two-park P2P as one record naming both parks', () async {
    final adif = await exportAdif(['US-0001'], qsoHunting(['US-9001', 'US-9002']), full: true);
    final records = recordsIn(adif);

    expect(records.length, 1);
    expect(records[0], contains('<POTA_REF:15>US-9001,US-9002'));
    expect(records[0], contains('<MY_POTA_REF:7>US-0001'));
    expect(records[0], contains('<TIME_ON:6>143015'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the second record is shifted a second so it is not read as a duplicate', () async {
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
    final adif = await exportAdif(['US-0001'], qsoHunting(['US-9001']));
    final records = recordsIn(adif);

    expect(records.length, 1);
    expect(records[0], contains('<TIME_ON:6>143015'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an ordinary hunter, at no park, is one record', () async {
    final adif = await exportAdif(['US-0001'], qsoHunting([]));
    final records = recordsIn(adif);

    expect(records.length, 1);
    expect(records[0], contains('<MY_POTA_REF:7>US-0001'));
    // Nothing was hunted, so no hunted-park fields at all.
    expect(records[0], isNot(contains('<SIG_INFO:')));
  }, timeout: const Timeout(Duration(seconds: 60)));

  // Custom splits its own file per hunted reference too, and answers nothing
  // but that split unless it also gives plain fields — which is all the full
  // export asks for. Without them the operator's backup of a custom
  // activation carries no custom fields at all.
  test('the full ADIF keeps a custom activation\'s fields in its one record', () async {
    final host = await sharedHost(['adif', 'ham2k-custom']);
    final result =
        await host.invokeHook(
              'export',
              key: 'adif',
              method: 'generateExport',
              args: {
                'operation': {
                  'uuid': 'op',
                  'stationCall': 'N0DEV',
                  'refs': [
                    {'type': 'customActivation', 'mySig': 'COTA', 'mySigInfo': 'XY-1234'},
                  ],
                },
                'qsos': [
                  {
                    ...qsoHunting([]),
                    'refs': [
                      {'type': 'custom', 'ref': 'AB-9'},
                      {'type': 'custom', 'ref': 'CD-7'},
                    ],
                  },
                ],
                'exportType': 'adif',
              },
              timeout: const Duration(seconds: 20),
            )
            as Map?;
    final records = recordsIn(result!['content'] as String);

    expect(records.length, 1);
    expect(records[0], contains('<MY_SIG:4>COTA'));
    expect(records[0], contains('<MY_SIG_INFO:7>XY-1234'));
    expect(records[0], contains('<SIG:4>COTA'));
    expect(records[0], contains('<SIG_INFO:4>AB-9'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('POTA declaring both hook methods does not write its fields twice', () async {
    final adif = await exportAdif(['US-0001'], qsoHunting(['US-9001']));
    // `fieldsForOneQSO` and `fieldCombinationsForOneQSO` both answer for POTA;
    // the exporter must take only the combinations.
    expect('<MY_SIG:4>POTA'.allMatches(adif).length, 1);
    expect('<SIG:4>POTA'.allMatches(adif).length, 1);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
