// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Tallies are rendered by the EXTENSION, not by Dart, so their formatting
// depends on what the JS engine provides. When Phase 3 moved macOS and iOS
// from JavaScriptCore to QuickJS-NG — which has no Intl and whose
// toLocaleString ignores its arguments — a 1500-QSO tally silently became
// "1500 QSOs", and not one test noticed. docs/extensions/README.md documents
// thousands separators as the contract; extensions/sdk/src/number-format.ts
// restores them.
//
// This runs through the real kernel and the real scoring bundle deliberately.
// The unit tests in extensions/sdk/src/number-format.test.ts prove the
// formatter is correct; only this proves it is actually INSTALLED, ahead of
// the code that calls it, in the engine that ships.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

void main() {
  final assets = Directory('../../app/assets/extensions');
  File bundle(String key) => File('${assets.path}/$key.js');

  // Enough QSOs to cross the grouping threshold — the whole point is the comma.
  List<Map<String, dynamic>> qsos(int count) => [
        for (var i = 0; i < count; i++)
          {
            'uuid': 'q$i',
            'startAtMillis': DateTime.utc(2026, 3, 28, 12).millisecondsSinceEpoch + i * 1000,
            'band': '20m',
            'mode': 'CW',
            'our': {'call': 'N0DEV'},
            'their': {'call': 'DL${i}ABC'},
          },
      ];

  test('a four-figure tally is rendered with thousands separators', () async {
    if (!bundle('kernel').existsSync() || !bundle('scoring').existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }
    final host = await ExtensionHost.start(
      kernelSource: bundle('kernel').readAsStringSync(),
      extensions: [ExtensionBundle(key: 'scoring', source: bundle('scoring').readAsStringSync())],
    );
    addTearDown(host.dispose);

    final result = await host.invokeHook(
      'scoring',
      key: 'core',
      method: 'scoreQsos',
      args: {
        'operation': {'uuid': 'op', 'stationCall': 'N0DEV', 'refs': <Map<String, dynamic>>[]},
        'qsos': qsos(1500),
      },
      timeout: const Duration(seconds: 60),
    ) as Map?;

    final qsoCount = (result!['operationSummary'] as Map)['qsoCount'] as Map;
    expect(qsoCount['total'], 1500, reason: 'sanity: the scorer counted them all');

    // The formatted strings are what a user actually reads.
    final rendered = '${qsoCount['label'] ?? ''} ${qsoCount['summary'] ?? ''}';
    expect(rendered, contains('1,500'),
        reason: 'without the toLocaleString polyfill this reads "1500" — the exact '
            'regression the engine swap introduced on macOS and iOS');
    expect(rendered, isNot(contains('1500 ')),
        reason: 'the unseparated form must not survive anywhere in the rendered text');
  }, timeout: const Timeout(Duration(seconds: 120)));
}
