// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `referenceActivity` factory, through the real runtime and the real WCA
// bundle. WCA is the vehicle because it is the first program built on the
// factory and the only one with `otherActivationTypes`; five more castle and
// lighthouse awards are the same call with different constants, so what breaks
// here breaks all of them.
//
// The reference database is stubbed through `onHostCall` — these programs have
// no per-reference API, so every name and grid they show comes from the local
// list, and a test with no list would exercise only the "unknown" path.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  // Two Belgian castles a few km apart, plus one far away, so distance ranking
  // has something to get wrong.
  final castles = <String, Map<String, dynamic>>{
    'ON-00558': {
      'key': 'ON-00558',
      'name': 'Kasteel van Beersel',
      'lat': 50.766,
      'lon': 4.307,
      'flags': 1,
      'data': {'location': 'Vlaams-Brabant', 'grid': 'JO20eq'},
    },
    'ON-00123': {
      'key': 'ON-00123',
      'name': 'Kasteel van Gaasbeek',
      'lat': 50.783,
      'lon': 4.208,
      'flags': 1,
      'data': {'location': 'Vlaams-Brabant', 'grid': 'JO20dr'},
    },
    'I-00001': {
      'key': 'I-00001',
      'name': 'Castello Sforzesco',
      'lat': 45.470,
      'lon': 9.179,
      'flags': 1,
      'data': {'location': 'Lombardia', 'grid': 'JN45pl'},
    },
  };

  // Hoisted, not written inline at the call site: `sharedHost` keys on the
  // handler's identity, so a closure rebuilt per call would boot a host per
  // call and defeat the sharing. The table it answers from is `const`, so one
  // host serves every test here.
  Future<dynamic> castleLookups(String method, Map<String, dynamic> params) async {
        switch (method) {
          case 'dbLookupSelectOne':
            return castles[params['key']];
          case 'dbLookupSelectAll':
            final q = (params['query'] as String).toUpperCase();
            return castles.values
                .where((c) => c['key'].toString().contains(q) || c['name'].toString().toUpperCase().contains(q))
                .toList();
          case 'dbLookupSelectByLocation':
            // Deliberately returns the FAR castle first: the factory has to
            // rank by real distance rather than trusting query order.
            return [castles['I-00001'], castles['ON-00558'], castles['ON-00123']];
          case 'log':
            return null;
          default:
            return null;
        }
      }

  Future<ExtensionHost> startHost() => sharedHost(['wca'], onHostCall: castleLookups);

  group('reference handling', () {
    test('a well-formed reference validates and is upper-cased', () async {
      final host = await startHost();
      final result = await host.invokeHook('ref:wcaActivation',
          method: 'validateRef', args: {'ref': {'type': 'wcaActivation', 'ref': 'on-00558'}});
      expect(result['valid'], true);
      expect(result['normalized'], 'ON-00558');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a malformed reference is rejected', () async {
      final host = await startHost();
      // WCA references are prefix-NNNNN; four digits is not enough.
      final result = await host.invokeHook('ref:wcaActivation',
          method: 'validateRef', args: {'ref': {'type': 'wcaActivation', 'ref': 'ON-0055'}});
      expect(result['valid'], false);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a known reference is decorated from the local list', () async {
      final host = await startHost();
      final ref = await host.invokeHook('ref:wcaActivation',
          method: 'decorateRef', args: {'ref': {'type': 'wcaActivation', 'ref': 'on-00558'}});
      expect(ref['name'], 'Kasteel van Beersel');
      expect(ref['program'], 'WCA');
      expect(ref['grid'], 'JO20eq');
      expect(ref['location'], 'Vlaams-Brabant');
      expect(ref['shortLabel'], 'WCA ON-00558');
      expect(ref['label'], 'WCA ON-00558: Kasteel van Beersel');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a well-formed reference the list has never heard of says so', () async {
      final host = await startHost();
      final ref = await host.invokeHook('ref:wcaActivation',
          method: 'decorateRef', args: {'ref': {'type': 'wcaActivation', 'ref': 'ON-99999'}});
      // Distinct from "invalid": the code is plausible, the list is just stale.
      expect(ref['name'], 'Unknown castle');
      expect(ref['program'], 'WCA');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('English and Belgian castle references resolve through WCA too', () async {
      final host = await startHost();
      // ECA/BCA references ARE WCA references; WCA answers for them so one
      // typed while those extensions are disabled still resolves.
      for (final type in ['ecaActivation', 'bcaActivation']) {
        final ref = await host.invokeHook('ref:$type',
            method: 'decorateRef', args: {'ref': {'type': type, 'ref': 'ON-00558'}});
        expect(ref['name'], 'Kasteel van Beersel', reason: 'via $type');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('...and get an operation title, not just a decoration', () async {
      final host = await startHost();
      // Title dispatch resolves to a SINGLE hook and WCA wins it by
      // registration order, so a handler that titled only its own
      // `activationType` would quietly cost ECA and BCA their "at ON-00558"
      // whenever WCA is enabled alongside them — while still decorating the
      // ref, which makes the loss look like a rendering bug rather than this.
      for (final type in ['wcaActivation', 'ecaActivation', 'bcaActivation']) {
        final title = await host.invokeHook('ref:$type', method: 'suggestOperationTitle',
            args: {'ref': {'type': type, 'ref': 'ON-00558', 'name': 'Kasteel van Beersel'}});
        expect(title, isNotNull, reason: 'via $type');
        expect((title as Map)['at'], 'ON-00558', reason: 'via $type');
        expect(title['subtitle'], 'Kasteel van Beersel', reason: 'via $type');
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('suggestions', () {
    test('nearby results are ranked by real distance, not query order', () async {
      final host = await startHost();
      final suggestions = (await host.invokeHook('activity', key: 'wca', method: 'suggest', args: {
        'operation': {'uuid': 'op'},
        'location': {'lat': 50.77, 'lon': 4.30},
      }) as List).cast<Map>();

      // The stub hands back Milan first; Beersel is 500m away and must win.
      expect(suggestions.first['ref'], 'ON-00558');
      expect(suggestions.map((s) => s['ref']), ['ON-00558', 'ON-00123', 'I-00001']);
      expect(suggestions.first['type'], 'wcaActivation');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a name search finds a castle and labels it', () async {
      final host = await startHost();
      final suggestions = (await host.invokeHook('activity', key: 'wca', method: 'suggest', args: {
        'operation': {'uuid': 'op'},
        'searchTerm': 'Sforzesco',
      }) as List).cast<Map>();

      expect(suggestions.length, 1);
      expect(suggestions.first['ref'], 'I-00001');
      expect(suggestions.first['shortLabel'], 'WCA I-00001');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  test('the operation control is keyed so `wca:` search scoping works', () async {
    final host = await startHost();
    final controls = (await host.invokeHook('activity', key: 'wca', method: 'operationControls', args: {
      'operation': {'uuid': 'op'},
    }) as List).cast<Map>();

    expect(controls.length, 1);
    // The core derives the search scope from the part before the slash, so a
    // control keyed anything else silently never gets scoped.
    expect(controls.first['key'], 'wca/activation');
    expect((controls.first['input'] as Map)['refType'], 'wcaActivation');
    expect((controls.first['input'] as Map)['kind'], 'refList');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an activation contributes MY_SIG/MY_SIG_INFO and nothing else', () async {
    final host = await startHost();
    final fields = (await host.invokeHook('adifFields', key: 'wca', method: 'fieldsForOneQSO', args: {
      'qso': {'their': {'call': 'W1AW'}},
      'operation': {'refs': [{'type': 'wcaActivation', 'ref': 'ON-00558'}]},
    }) as List).cast<Map>();

    expect(fields.map((f) => f['name']), ['MY_SIG', 'MY_SIG_INFO']);
    expect(fields.map((f) => f['value']), ['WCA', 'ON-00558']);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('fifty contacts activate a castle', () async {
    final host = await startHost();
    final result = await host.invokeHook('scoring', key: 'wca', method: 'scoreQsos', args: {
      'operation': {
        'uuid': 'op',
        'refs': [{'type': 'wcaActivation', 'ref': 'ON-00558'}],
      },
      'qsos': [
        for (var i = 0; i < 50; i++)
          {
            'uuid': 'q$i',
            'their': {'call': 'W${i}ABC'},
            'band': '20m',
            'mode': 'SSB',
            'startAtMillis': DateTime.utc(2026, 7, 1, 12, i).millisecondsSinceEpoch,
          },
      ],
      'ref': {'type': 'wcaActivation', 'ref': 'ON-00558'},
    }, timeout: const Duration(seconds: 20)) as Map;

    final activation = ((result['operationSummary'] as Map)['activation'] as Map);
    expect(activation['summary'], '50 ✓');
    expect(activation['activated'], true);
    // No hunting side to this award, so no hunting tally at all.
    expect((result['operationSummary'] as Map)['hunting'], isNull);
  }, timeout: const Timeout(Duration(seconds: 120)));
}
