// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pins that a handful of activities' own refNoun/refNounPlural/p2pLabel
// functions (extensions/sdk/src/activityScoring.ts) actually resolve through
// the REAL bundle — activity_scoring_test.dart already proves the mechanism
// against POTA; this is a spot check that the per-activity wiring (each
// program's own i18n key, not just POTA's) survives the trip through esbuild
// and QuickJS too, where a JSON-key typo would silently fall back to the raw
// key string rather than throwing.

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  Map<String, dynamic> activating(String type, String ref) => {
        'uuid': 'op',
        'stationCall': 'N0DEV',
        'refs': [
          {'type': type, 'ref': ref},
        ],
      };

  List<Map<String, dynamic>> contacts(int n, {String huntingType = '', List<String> hunting = const []}) => [
        for (var i = 0; i < n; i++)
          {
            'uuid': 'q$i',
            'startAtMillis': DateTime.utc(2026, 7, 1, 12, i).millisecondsSinceEpoch,
            'band': '20m',
            'mode': 'SSB',
            'our': {'call': 'N0DEV'},
            'their': {'call': 'W${i}ABC'},
            if (hunting.isNotEmpty)
              'refs': [
                for (final ref in hunting) {'type': huntingType, 'ref': ref},
              ],
          },
      ];

  Future<Map<String, dynamic>?> score(
    String extensionKey,
    Map<String, dynamic> operation,
    List<Map<String, dynamic>> qsos,
  ) async {
    final host = await sharedHost([extensionKey]);
    final result = await host.invokeHook(
      'scoring',
      key: extensionKey,
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

  test('SOTA: activation label reads "summit"/S2S, not the raw i18n key', () async {
    final result = await score(
      'sota',
      activating('sotaActivation', 'W1/AM-001'),
      contacts(4, huntingType: 'sota', hunting: ['W1/AM-002']),
    );
    final activation = (result!['operationSummary'] as Map)['activation'] as Map;
    expect(activation['label'], contains('activation QSO'));
    expect(activation['label'], contains('S2S'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('WWBOTA: hunting-only label reads "bunkers hunted"', () async {
    final result = await score(
      'wwbota',
      {'uuid': 'op', 'stationCall': 'N0DEV', 'refs': []},
      contacts(1, huntingType: 'wwbota', hunting: ['B/G-0001']),
    );
    final hunting = (result!['operationSummary'] as Map)['hunting'] as Map;
    expect(hunting['label'], 'WWBOTA: 1 bunker hunted');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('SiOTA: activation label reads S2S too — deliberately shared with SOTA', () async {
    final result = await score(
      'siota',
      activating('siotaActivation', 'G-0001'),
      contacts(10, huntingType: 'siota', hunting: ['G-0002']),
    );
    final activation = (result!['operationSummary'] as Map)['activation'] as Map;
    expect(activation['label'], contains('S2S'));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
