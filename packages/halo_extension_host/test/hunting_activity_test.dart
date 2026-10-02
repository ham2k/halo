// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The HUNTING side of `referenceActivity`, through the real runtime and the
// real `ham2k-wwff` bundle, which the factory builds. A QSO carries the
// references the OTHER station was at, which brings a per-QSO logging control
// and SIG/SIG_INFO on export.
//
// The rule that most needs pinning is how a multi-reference contact is
// submitted: one record per reference, or one naming them all. The programs
// disagree, it is not cosmetic — it decides how many contacts the award sees —
// and WWFF is a joiner.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  Future<ExtensionHost> startHost() => sharedHost(['ham2k-wwff'], onHostCall: nullHostCall);

  test('a hunting program offers a per-QSO control, keyed for search scoping', () async {
    final host = await startHost();
    final controls =
        (await host.invokeHook(
                  'activity',
                  key: 'ham2k-wwff',
                  method: 'loggingControls',
                  args: {
                    'operation': {'uuid': 'op'},
                  },
                )
                as List)
            .cast<Map>();

    expect(controls.length, 1);
    expect(controls.first['key'], 'wwff/hunter');
    // Writes to the QSO's hunting type, not the operation's activation type.
    expect((controls.first['input'] as Map)['refType'], 'wwff');
    expect(controls.first['allowsMultiple'], true);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('hunted references reach the export as SIG/SIG_INFO', () async {
    final host = await startHost();
    final fields =
        (await host.invokeHook(
                  'adifFields',
                  key: 'ham2k-wwff',
                  method: 'fieldsForOneQSO',
                  args: {
                    'qso': {
                      'their': {'call': 'W1AW'},
                      'refs': [
                        {'type': 'wwff', 'ref': 'KFF-0001'},
                      ],
                    },
                    'operation': {
                      'refs': [
                        {'type': 'wwffActivation', 'ref': 'KFF-9999'},
                      ],
                    },
                  },
                )
                as List)
            .cast<Map>();

    expect(fields.map((f) => f['name']), ['SIG', 'SIG_INFO', 'WWFF_REF', 'MY_SIG', 'MY_SIG_INFO', 'MY_WWFF_REF']);
    expect(fields.map((f) => f['value']), ['WWFF', 'KFF-0001', 'KFF-0001', 'WWFF', 'KFF-9999', 'KFF-9999']);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a joiner names several hunted references in one record rather than splitting', () async {
    final host = await startHost();
    // POTA submits one record per reference; WWFF names them all in one.
    // Declaring combinations here would silently double what the award
    // counts, so a joiner must not declare the method at all.
    final combinations = await host.invokeHook(
      'adifFields',
      key: 'ham2k-wwff',
      method: 'fieldCombinationsForOneQSO',
      args: {
        'qso': {
          'their': {'call': 'W1AW'},
          'refs': [
            {'type': 'wwff', 'ref': 'KFF-0001'},
          ],
        },
        'operation': {'refs': <Map>[]},
      },
      timeout: const Duration(seconds: 10),
    );
    expect(combinations, isNull);

    final fields =
        (await host.invokeHook(
                  'adifFields',
                  key: 'ham2k-wwff',
                  method: 'fieldsForOneQSO',
                  args: {
                    'qso': {
                      'their': {'call': 'W1AW'},
                      'refs': [
                        {'type': 'wwff', 'ref': 'KFF-0001'},
                        {'type': 'wwff', 'ref': 'KFF-0002'},
                      ],
                    },
                    'operation': {'refs': <Map>[]},
                  },
                )
                as List)
            .cast<Map>();
    expect(fields.firstWhere((f) => f['name'] == 'SIG_INFO')['value'], 'KFF-0001,KFF-0002');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
