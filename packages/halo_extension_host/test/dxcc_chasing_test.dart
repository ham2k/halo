// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The DXCC chasing program through the REAL runtime and the built `dxcc`
// bundle (docs/design/claims.md). The node tests in extensions/core/dxcc pin
// the rules; this pins that they survive the trip: `program` is a data member
// read by a fan-out, never invoked, and a claim's `null` band and mode — "any"
// — must arrive as null rather than vanish.

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  test('the program is read as data across extensions', () async {
    final host = await sharedHost(['dxcc']);
    final entries = await host.invokeHookAll('chasing', method: 'program', timeout: const Duration(seconds: 20));
    final dxcc = entries.singleWhere((entry) => entry['key'] == 'dxcc');
    expect(dxcc['ok'], isTrue);
    expect(dxcc['value'], {'label': 'DXCC', 'icon': 'earth', 'version': 1, 'editions': 'lifetime'});
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a contact comes back as its Mixed, band and mode claims', () async {
    final host = await sharedHost(['dxcc']);
    final result =
        await host.invokeHook(
              'chasing',
              key: 'dxcc',
              method: 'claimsForQsos',
              args: {
                'qsos': [
                  {
                    'uuid': 'q1',
                    'our': {'call': 'KI2D'},
                    'their': {'call': 'DL1ABC'},
                    'band': '20m',
                    'mode': 'CW',
                    'qsl': {
                      'received': true,
                      'lotw': {'received': true},
                    },
                  },
                ],
              },
              timeout: const Duration(seconds: 20),
            )
            as Map;
    final claims = (result['q1'] as List).cast<Map>();
    expect([for (final claim in claims) (claim['band'], claim['mode'])], [(null, null), ('20m', null), (null, 'CW')]);
    expect(claims.first.containsKey('band'), isTrue, reason: 'null is "any band"; a dropped key would read the same only by accident');
    expect(claims.first, containsPair('holder', 'KI2D@291'));
    expect(claims.first, containsPair('ref', '230'));
    expect(claims.first, containsPair('level', 'confirmed'));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
