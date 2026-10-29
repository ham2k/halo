// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The settled guess, through the real runtime and back into the Dart model:
// the lookup pipeline decides which lookup fields still stand
// (extensions/core/lookups/src/resolveGuess.ts), and every reader in the app
// takes `their.guess` as it comes. A contract test for that split — the rule
// cases themselves are covered by resolveGuess.test.ts.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

// A callsign source as QRZ answers: the full call resolves to the license's
// own record, address and all, whatever indicator the call carries.
const _callbookSource = '''
__polo.defineExtension({
  key: 'test-callbook',
  name: 'Test Callbook',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('lookup', { key: 'callbook', priority: 10, hook: {
      lookupCall: async function (args) {
        return [{ source: 'callbook', scope: 'general', call: args.callInfo.call, locationScope: args.callInfo.locationScope,
          name: 'Jim', city: 'Kingston', state: 'RI', grid: 'FN41gk', lat: 41.44783, lon: -71.476222 }]
      },
    } })
  },
})
''';

void main() {
  late ExtensionHost host;

  setUp(() async {
    host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [
        ExtensionBundle(key: 'lookups', source: bundleSource('lookups')),
        const ExtensionBundle(key: 'test-callbook', source: _callbookSource),
      ],
      useIsolate: false,
    );
    addTearDown(host.dispose);
    await host.activated;
  });

  Future<Map<String, dynamic>> lookup(String call, {Map<String, dynamic> their = const {}}) async =>
      ((await host.invokeHook(
                'lookupService',
                key: 'core',
                method: 'lookupCallInfo',
                args: {
                  'callInfo': {'call': call},
                  'qso': {
                    'their': {'call': call, ...their},
                  },
                  'operation': <String, dynamic>{},
                },
              ))
              as Map)
          .cast<String, dynamic>();

  Future<Map<String, dynamic>> resolve(Map<String, dynamic> their) async =>
      ((await host.invokeHook(
                'lookupService',
                key: 'core',
                method: 'resolveCallInfo',
                args: {
                  'qso': {'their': their},
                },
              ))
              as Map)
          .cast<String, dynamic>();

  Qso saved(Map<String, dynamic> their, Map<String, dynamic> result) => Qso(
    uuid: 'u',
    operationUuid: 'op',
    data: {
      'their': {...their, 'guess': result['guess'], 'lookups': result['lookups']},
    },
  );

  // A state corrected after the lookup filed an address in another state.
  // Settling the saved contact again must move it on every reader that takes
  // the guess — no reader re-decides it.
  test('a state entered on a saved contact settles its guess, and the model places it in that state', () async {
    final looked = await lookup('KE1J');
    final their = {'call': 'KE1J', 'state': 'ME', 'guess': looked['guess'], 'lookups': looked['lookups']};
    final qso = saved(their, await resolve(their));

    expect(qso.theirGrid, isNull);
    expect(qso.theirExactLocation, isNull);
    expect(qso.theirLocation, const GridLocation(45.4, -69.2));
    expect(qso.theirName, 'Jim', reason: 'only the location is overruled');
  });

  // A source's own scope bookkeeping lets a /P call's home address through
  // (the full call resolved, so the result inherits `portable`); the pipeline
  // must refuse it whatever the source does.
  test('a portable call keeps the callbook name but not its address', () async {
    final guess = (await lookup('KE1J/P'))['guess'] as Map;
    expect(guess['name'], 'Jim');
    expect(guess['grid'], isNull);
    expect(guess['lat'], isNull);
  });

  // A call corrected in the Logs editor keeps the old station's guess until
  // it is looked up. Replayed under the new call, that station's name and
  // address would be filed as this one's — past the queue's crossed-result
  // check, since the settled guess would carry the new call.
  test('a stored guess for another call is not settled under the corrected one', () async {
    final looked = await lookup('W1AW');
    final result = await host.invokeHook(
      'lookupService',
      key: 'core',
      method: 'resolveCallInfo',
      args: {
        'qso': {
          'their': {'call': 'K1ABC', 'guess': looked['guess'], 'lookups': looked['lookups']},
        },
      },
    );
    expect(result, isNull);
  });

  // A contact logged by app-polo or imported carries a guess and no
  // `lookups[]`. Once overlaid, the guess no longer says what the lookup did,
  // so the settling files it first — or clearing the entry could never bring
  // the lookup's square back.
  test('a contact with no stored lookups has its guess filed as one, so clearing the entry restores it', () async {
    final polo = {'call': 'KE1J', 'name': 'Jim', 'state': 'RI', 'grid': 'FN41gk'};
    final corrected = await resolve({'call': 'KE1J', 'state': 'ME', 'guess': polo});
    expect((corrected['guess'] as Map)['grid'], isNull);
    expect((corrected['lookups'] as List).single, containsPair('source', 'stored-guess'));

    final cleared = await resolve({'call': 'KE1J', 'guess': corrected['guess'], 'lookups': corrected['lookups']});
    expect((cleared['guess'] as Map)['grid'], 'FN41gk');
  });
}
