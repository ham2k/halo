// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'package:flutter_test/flutter_test.dart';
import 'support/bundles.dart';

void main() {
  requireBundles();
  final operation = {
    'stationCall': 'N0CALL',
    'refs': [
      {'type': 'potaActivation', 'ref': 'US-1234'},
    ],
  };
  final qsos = [
    {
      'uuid': 'q1',
      'startAtMillis': DateTime.utc(2026, 7, 15).millisecondsSinceEpoch,
      'band': '20m',
      'mode': 'SSB',
      'notes': 'Private note',
      'their': {
        'call': 'W1AW',
        'name': 'Entered',
        'guess': {'name': 'Lookup', 'country': 'Lookup country'},
      },
      'our': {'call': 'N0CALL', 'sent': '59'},
    },
  ];

  test('POTA registers its shared activity type without needing a log', () async {
    final host = await sharedHost(['pota']);
    final types = await host.invokeHook('export', key: 'pota', method: 'getExportTypes', args: {}) as List;
    expect((types.single as Map)['exportType'], 'potaActivation-adif');
    expect((types.single as Map)['activationType'], 'potaActivation');
    expect((types.single as Map)['templateCategory'], 'reference');
  });

  test('per-type text and lookup settings survive POTA delegation to ADIF', () async {
    final host = await sharedHost(['adif', 'pota']);
    final result =
        await host.invokeHook(
              'export',
              key: 'pota',
              method: 'generateExport',
              args: {
                'operation': operation,
                'qsos': qsos,
                'exportType': 'potaActivation-adif',
                'exportKey': 'pota-adif:US-1234',
                'includePrivateData': true,
                'includeLookupData': false,
                'exportData': {'ref': 'US-1234', 'activity': 'POTA'},
                'exportTitle': 'My POTA log',
                'exportSettings': {
                  'adifNotesTemplate': '',
                  'adifCommentTemplate': '{{ qso.their.name }} at {{ log.ref }}',
                  'adifQslMessageTemplate': 'Worked {{ qso.call }} on {{ qso.band }}',
                },
              },
            )
            as Map;
    final content = result['content'] as String;
    expect(content, contains('My POTA log'));
    expect(content, contains('Entered at US-1234'));
    expect(content, contains('Worked W1AW on 20m'));
    expect(content, isNot(contains('<NOTES:')));
    expect(content, isNot(contains('Lookup country')));
    expect(content, isNot(contains('Private note')));
  });

  test('custom public ADIF templates cannot read withheld private or lookup values', () async {
    final host = await sharedHost(['adif']);
    final result =
        await host.invokeHook(
              'export',
              key: 'adif',
              method: 'generateExport',
              args: {
                'operation': {...operation, 'userTitle': 'Private title'},
                'qsos': qsos,
                'includePrivateData': false,
                'includeLookupData': false,
                'exportSettings': {'adifQslMessageTemplate': '{{ qso.notes }}{{ qso.their.name }}{{ qso.their.guess.country }}{{ op.userTitle }}'},
              },
            )
            as Map;
    final content = result['content'] as String;
    for (final private in ['Private note', 'Entered', 'Lookup country', 'Private title']) {
      expect(content, isNot(contains(private)));
    }
  });
  test('public custom templates cap operation grids and hide internal positions', () async {
    final host = await sharedHost(['adif']);
    final result =
        await host.invokeHook(
              'export',
              key: 'adif',
              method: 'generateExport',
              args: {
                'operation': {...operation, 'grid': 'FN31pr12'},
                'qsos': [
                  {
                    ...qsos.single,
                    'our': {'call': 'N0CALL', 'multiIdentifier': 'Private desk'},
                  },
                ],
                'includePrivateData': false,
                'exportSettings': {'adifQslMessageTemplate': '{{ op.grid }} {{ qso.our.multiIdentifier }}'},
              },
            )
            as Map;
    final content = result['content'] as String;
    expect(content, contains('<QSLMSG:6>FN31pr'));
    expect(content, isNot(contains('FN31pr12')));
    expect(content, isNot(contains('Private desk')));
  });
}
