// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A contest's "Contest ADIF" export delegates the actual ADIF build to the core
// `adif` extension inside the runtime. That delegation used to go through
// `hooks.invokeAll`, which fans out to EVERY hook in the `export` category —
// including the calling contest's own `generateExport`, whose only guard was
// `exportType === 'cabrillo'`. So the delegated call re-entered the same hook,
// took the same branch, and delegated again, forever. Being await-based there
// was no stack overflow to stop it: the export simply never returned, the host
// timed out at 30s, and the single-threaded JS runtime spun in the meantime.
//
// Nothing caught it — the unit tests exercise the scorers, and hand-testing had
// only ever exported Cabrillo. It needs the REAL runtime with BOTH bundles
// loaded, because the recursion only exists once `adif` and a contest are
// registered in the same category of the same kernel.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

void main() {
  final assets = Directory('../../app/assets/extensions');
  File bundle(String key) => File('${assets.path}/$key.js');

  // Every contest ships the same delegation, so every contest can recurse.
  const contests = ['simple-contest', 'cqww', 'cqwpx', 'arrl-dx'];

  Map<String, dynamic> operationFor(String key) => {
        'uuid': 'op-1',
        'stationCall': 'N0DEV',
        'refs': [
          {'type': key, 'mode': 'CW', 'exchange': '59 001'},
        ],
      };

  List<Map<String, dynamic>> qsosFor(String key) => [
    for (var i = 0; i < 5; i++)
      {
        'uuid': 'q$i',
        'our': {'call': 'N0DEV'},
        'their': {'call': 'W${i}AW'},
        'band': '20m',
        'mode': 'CW',
        'startAtMillis': DateTime.utc(2026, 3, 28, 12, i).millisecondsSinceEpoch,
        'refs': [
          {'type': key, 'exchange': '59 00$i', 'theirZone': '5', 'theirExchange': 'MA', 'theirSerial': '$i'},
        ],
      },
  ];

  for (final key in contests) {
    test('$key: contest-adif export terminates and produces ADIF', () async {
      if (!bundle('kernel').existsSync() || !bundle(key).existsSync() || !bundle('adif').existsSync()) {
        markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
        return;
      }

      final host = await ExtensionHost.start(
        kernelSource: bundle('kernel').readAsStringSync(),
        extensions: [
          ExtensionBundle(key: 'adif', source: bundle('adif').readAsStringSync()),
          ExtensionBundle(key: key, source: bundle(key).readAsStringSync()),
        ],
      );
      addTearDown(host.dispose);

      // A generous ceiling: the point is that it RETURNS, not how fast. Before
      // the fix this hung until the host's own timeout.
      final result = await host.invokeHook(
        'export',
        key: key,
        method: 'generateExport',
        args: {
          'operation': operationFor(key),
          'qsos': qsosFor(key),
          'exportType': 'contest-adif',
        },
        timeout: const Duration(seconds: 10),
      ) as Map?;

      expect(result, isNotNull, reason: 'the export must return, not spin');
      final content = result!['content'] as String?;
      expect(content, isNotNull);
      expect(content, contains('<CALL:'), reason: 'delegation must reach the core adif exporter');
      expect(result['filename'], endsWith('.adi'));
    }, timeout: const Timeout(Duration(seconds: 60)));
  }

  test('a contest declines an exportType it never offered, rather than delegating', () async {
    if (!bundle('kernel').existsSync() || !bundle('cqwpx').existsSync() || !bundle('adif').existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }

    final host = await ExtensionHost.start(
      kernelSource: bundle('kernel').readAsStringSync(),
      extensions: [
        ExtensionBundle(key: 'adif', source: bundle('adif').readAsStringSync()),
        ExtensionBundle(key: 'cqwpx', source: bundle('cqwpx').readAsStringSync()),
      ],
    );
    addTearDown(host.dispose);

    // 'adif' is what the core exporter answers for — the contest must not treat
    // it as "anything that isn't cabrillo" and delegate, which is the branch
    // the recursion lived in.
    final result = await host.invokeHook(
      'export',
      key: 'cqwpx',
      method: 'generateExport',
      args: {
        'operation': operationFor('cqwpx'),
        'qsos': qsosFor('cqwpx'),
        'exportType': 'adif',
      },
      timeout: const Duration(seconds: 10),
    ) as Map?;

    expect(result, isNotNull);
    expect(result!['content'], isEmpty, reason: 'not an exportType this hook offers');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
