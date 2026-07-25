// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A contest keeps the received exchange on its own ref — `theirZone`,
// `theirSerial`, `theirExchange` — which nothing generic knows how to read.
// The QSO row's exchange column and a plain (non-contest) ADIF export both read
// `their.exchange`, so without `processQsoBeforeSave` mirroring it across, a
// contest log shows an empty exchange column everywhere.
//
// Exercised through the REAL runtime rather than a stub, because the value of
// this hook is that four separately-written extensions agree on the projection.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

void main() {
  final assets = Directory('../../app/assets/extensions');
  File bundle(String key) => File('${assets.path}/$key.js');

  /// Each contest, the ref field it stores the received exchange in, and what
  /// should end up in `their.exchange`.
  const cases = [
    (key: 'cqww', refFields: {'theirZone': '05'}, expected: '5'),
    (key: 'arrl-dx', refFields: {'theirExchange': 'MA'}, expected: 'MA'),
    (key: 'simple-contest', refFields: {'exchange': '59 042'}, expected: '59 042'),
    (key: 'cqwpx', refFields: {'theirSerial': '0012'}, expected: '12'),
  ];

  for (final c in cases) {
    test('${c.key}: the received exchange reaches their.exchange', () async {
      if (!bundle('kernel').existsSync() || !bundle(c.key).existsSync()) {
        markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
        return;
      }
      final host = await ExtensionHost.start(
        kernelSource: bundle('kernel').readAsStringSync(),
        extensions: [ExtensionBundle(key: c.key, source: bundle(c.key).readAsStringSync())],
      );
      addTearDown(host.dispose);

      final entries = await host.invokeHookAll(
        'activity',
        method: 'processQsoBeforeSave',
        args: {
          'operation': {
            'stationCall': 'N0DEV',
            'refs': [
              {'type': c.key, 'mode': 'CW', 'exchange': '59 001'},
            ],
          },
          'qso': {
            'band': '20m',
            'mode': 'CW',
            'their': {'call': 'W1AW'},
            'refs': [
              {'type': c.key, ...c.refFields},
            ],
          },
        },
      );

      final patch = entries.firstWhere((e) => e['ok'] == true && e['value'] is Map)['value'] as Map;
      expect((patch['their'] as Map)['exchange'], c.expected);
      // A projection, not a rewrite: the patch says nothing about the ref it
      // read from, nor about the callsign.
      expect(patch.containsKey('refs'), isFalse);
      expect((patch['their'] as Map).containsKey('call'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 60)));
  }

  test('an operation not running the contest is left alone', () async {
    if (!bundle('kernel').existsSync() || !bundle('cqww').existsSync()) {
      markTestSkipped('bundles not built — run `npm run build` in extensions/ first');
      return;
    }
    final host = await ExtensionHost.start(
      kernelSource: bundle('kernel').readAsStringSync(),
      extensions: [ExtensionBundle(key: 'cqww', source: bundle('cqww').readAsStringSync())],
    );
    addTearDown(host.dispose);

    final entries = await host.invokeHookAll(
      'activity',
      method: 'processQsoBeforeSave',
      args: {
        // A POTA operation, and a QSO that happens to carry a stale cqww ref.
        'operation': {
          'stationCall': 'N0DEV',
          'refs': [
            {'type': 'pota', 'ref': 'US-1234'},
          ],
        },
        'qso': {
          'their': {'call': 'W1AW'},
          'refs': [
            {'type': 'cqww', 'theirZone': '5'},
          ],
        },
      },
    );

    for (final entry in entries) {
      expect(entry['value'], isNull, reason: 'no contest running, nothing to project');
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
