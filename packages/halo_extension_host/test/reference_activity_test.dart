// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `referenceActivity` factory, through the real runtime and the real
// `ham2k-wwff` bundle, which the factory builds. The castle, lighthouse and
// flora-and-fauna awards built on it are the same call with different
// constants, so what breaks here breaks all of them.
//
// The reference database is stubbed through `onHostCall` — these programs have
// no per-reference API, so every name and grid they show comes from the local
// list, and a test with no list would exercise only the "unknown" path.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

void main() {
  requireBundles();

  // Two Belgian areas a few km apart, plus one far away, so distance ranking
  // has something to get wrong.
  final areas = <String, Map<String, dynamic>>{
    'ONFF-0558': {
      'key': 'ONFF-0558',
      'name': 'Hallerbos',
      'lat': 50.766,
      'lon': 4.307,
      'flags': 1,
      'data': {'location': 'Vlaams-Brabant', 'grid': 'JO20eq'},
    },
    'ONFF-0123': {
      'key': 'ONFF-0123',
      'name': 'Domein Gaasbeek',
      'lat': 50.783,
      'lon': 4.208,
      'flags': 1,
      'data': {'location': 'Vlaams-Brabant', 'grid': 'JO20dr'},
    },
    'IFF-0001': {
      'key': 'IFF-0001',
      'name': 'Parco Nord Milano',
      'lat': 45.470,
      'lon': 9.179,
      'flags': 1,
      'data': {'location': 'Lombardia', 'grid': 'JN45pl'},
    },
  };

  // A viewport's worth of areas — more than the 30 a nearby list keeps, so
  // a viewport answer that is still capped shows as a short list.
  final viewportAreas = [
    for (var i = 0; i < 40; i++)
      {
        'key': 'ONFF-${2000 + i}',
        'name': 'Area $i',
        'lat': 50.5 + i / 100,
        'lon': 4.0 + i / 100,
        'flags': 1,
        'data': {'location': 'Vlaams-Brabant'},
      },
  ];
  Map<String, dynamic>? inBoundsParams;

  // Hoisted, not written inline at the call site: `sharedHost` keys on the
  // handler's identity, so a closure rebuilt per call would boot a host per
  // call and defeat the sharing. The table it answers from is `const`, so one
  // host serves every test here.
  Future<dynamic> areaLookups(String method, Map<String, dynamic> params) async {
    switch (method) {
      case 'dbLookupSelectOne':
        return areas[params['key']];
      case 'dbLookupSelectAll':
        final q = (params['query'] as String).toUpperCase();
        return areas.values.where((c) => c['key'].toString().contains(q) || c['name'].toString().toUpperCase().contains(q)).toList();
      case 'dbLookupSelectByLocation':
        // Deliberately returns the FAR area first: the factory has to
        // rank by real distance rather than trusting query order.
        return [areas['IFF-0001'], areas['ONFF-0558'], areas['ONFF-0123']];
      case 'dbLookupSelectInBounds':
        inBoundsParams = params;
        return viewportAreas;
      case 'log':
        return null;
      default:
        return null;
    }
  }

  Future<ExtensionHost> startHost() => sharedHost(['ham2k-wwff'], onHostCall: areaLookups);

  group('reference handling', () {
    test('a well-formed reference validates and is upper-cased', () async {
      final host = await startHost();
      final result = await host.invokeHook(
        'ref:wwffActivation',
        method: 'validateRef',
        args: {
          'ref': {'type': 'wwffActivation', 'ref': 'onff-0558'},
        },
      );
      expect(result['valid'], true);
      expect(result['normalized'], 'ONFF-0558');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a malformed reference is rejected', () async {
      final host = await startHost();
      // WWFF references are prefixFF-NNNN; two digits is not enough.
      final result = await host.invokeHook(
        'ref:wwffActivation',
        method: 'validateRef',
        args: {
          'ref': {'type': 'wwffActivation', 'ref': 'ONFF-05'},
        },
      );
      expect(result['valid'], false);
    }, timeout: const Timeout(Duration(seconds: 60)));

    // The two answers that resolve to nothing must shed the previous
    // reference's decoration, not just the invalid one. `label`/`shortLabel`
    // are what a row renders in preference to the code, so a spread-through
    // pair shows the OLD reference over the new code while the log and the
    // export carry the new one; and a stale `lat`/`lon` outranks a grid
    // wherever a location is read, keeping the operation at an area it no
    // longer references.
    test('re-decorating onto an unresolvable code drops the old one entirely', () async {
      final host = await startHost();
      for (final code in ['ONFF-9999', 'ONFF-05']) {
        final ref = await host.invokeHook(
          'ref:wwffActivation',
          method: 'decorateRef',
          args: {
            'ref': {
              'type': 'wwffActivation',
              'ref': code,
              // Everything a previous, resolved reference would have left behind.
              'name': 'Hallerbos',
              'label': 'WWFF ONFF-0558: Hallerbos',
              'shortLabel': 'WWFF ONFF-0558',
              'grid': 'JO20eq',
              'lat': 50.766,
              'lon': 4.307,
              'location': 'Vlaams-Brabant',
            },
          },
        );
        expect(ref['ref'], code, reason: code);
        for (final stale in ['label', 'shortLabel', 'grid', 'lat', 'lon', 'location']) {
          expect(ref[stale], isNull, reason: '$stale survived onto $code');
        }
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a known reference is decorated from the local list', () async {
      final host = await startHost();
      final ref = await host.invokeHook(
        'ref:wwffActivation',
        method: 'decorateRef',
        args: {
          'ref': {'type': 'wwffActivation', 'ref': 'onff-0558'},
        },
      );
      expect(ref['name'], 'Hallerbos');
      expect(ref['program'], 'WWFF');
      expect(ref['grid'], 'JO20eq');
      expect(ref['location'], 'Vlaams-Brabant');
      expect(ref['shortLabel'], 'WWFF ONFF-0558');
      expect(ref['label'], 'WWFF ONFF-0558: Hallerbos');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a well-formed reference the list has never heard of says so', () async {
      final host = await startHost();
      final ref = await host.invokeHook(
        'ref:wwffActivation',
        method: 'decorateRef',
        args: {
          'ref': {'type': 'wwffActivation', 'ref': 'ONFF-9999'},
        },
      );
      // Distinct from "invalid": the code is plausible, the list is just stale.
      expect(ref['name'], 'Unknown park');
      expect(ref['program'], 'WWFF');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('suggestions', () {
    test('nearby results are ranked by real distance, not query order', () async {
      final host = await startHost();
      final suggestions =
          (await host.invokeHook(
                    'activity',
                    key: 'ham2k-wwff',
                    method: 'suggest',
                    args: {
                      'operation': {'uuid': 'op'},
                      'location': {'lat': 50.77, 'lon': 4.30},
                    },
                  )
                  as List)
              .cast<Map>();

      // The stub hands back Milan first; Hallerbos is 500m away and must win.
      expect(suggestions.first['ref'], 'ONFF-0558');
      expect(suggestions.map((s) => s['ref']), ['ONFF-0558', 'ONFF-0123', 'IFF-0001']);
      expect(suggestions.first['type'], 'wwffActivation');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a map viewport is answered whole, not cut to the nearest few', () async {
      final host = await startHost();
      final suggestions =
          (await host.invokeHook(
                    'activity',
                    key: 'ham2k-wwff',
                    method: 'suggest',
                    args: {
                      'operation': {'uuid': 'op'},
                      'location': {'lat': 50.7, 'lon': 4.2},
                      'bounds': {'south': 50.4, 'west': 3.9, 'north': 51.0, 'east': 4.5},
                    },
                  )
                  as List)
              .cast<Map>();

      // Cut to 30, the corners of every panned view would stay empty.
      expect(suggestions, hasLength(40));
      expect(inBoundsParams, containsPair('south', 50.4));
      expect(inBoundsParams, containsPair('east', 4.5));
      expect(inBoundsParams!['limit'], greaterThan(30));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a name search finds an area and labels it', () async {
      final host = await startHost();
      final suggestions =
          (await host.invokeHook(
                    'activity',
                    key: 'ham2k-wwff',
                    method: 'suggest',
                    args: {
                      'operation': {'uuid': 'op'},
                      'searchTerm': 'Milano',
                    },
                  )
                  as List)
              .cast<Map>();

      expect(suggestions.length, 1);
      expect(suggestions.first['ref'], 'IFF-0001');
      expect(suggestions.first['shortLabel'], 'WWFF IFF-0001');
    }, timeout: const Timeout(Duration(seconds: 60)));

    // A reference the list does not carry is otherwise unreachable: the search
    // is the only way onto the operation, so an answer of "no results" is the
    // operator being told their own area does not exist. Both of these are
    // real — an area added since the last data-file sync, and a code whose
    // shape the program's own regex has wrong.
    test('a scoped search offers the reference the operator typed, even unlisted', () async {
      final host = await startHost();
      final suggestions =
          (await host.invokeHook(
                    'activity',
                    key: 'ham2k-wwff',
                    method: 'suggest',
                    args: {
                      'operation': {'uuid': 'op'},
                      'searchTerm': 'onff-9999',
                      'scoped': true,
                    },
                  )
                  as List)
              .cast<Map>();

      expect(suggestions.first['ref'], 'ONFF-9999');
      expect(suggestions.first['name'], 'Unknown park');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a scoped search offers a code the regex rejects, named as invalid', () async {
      final host = await startHost();
      final suggestions =
          (await host.invokeHook(
                    'activity',
                    key: 'ham2k-wwff',
                    method: 'suggest',
                    args: {
                      'operation': {'uuid': 'op'},
                      'searchTerm': 'ZZ-0055',
                      'scoped': true,
                    },
                  )
                  as List)
              .cast<Map>();

      expect(suggestions.first['ref'], 'ZZ-0055');
      expect(suggestions.first['name'], 'Invalid reference');
    }, timeout: const Timeout(Duration(seconds: 60)));

    // A name search must not double as an offer to activate a reference by that
    // name: `wwff: hallerbos` is looking for an area, and answering it with
    // "HALLERBOS — Invalid reference" at the head of the list is the search
    // arguing with the operator.
    //
    // ONE WORD, deliberately. A multi-word term would pass against a guard that
    // merely rejects whitespace, and a single word is how a castle, park or
    // summit actually gets looked up by name — so the multi-word version of
    // this test would hold while the common case misbehaved.
    test('a scoped search for a NAME invents no reference from it', () async {
      final host = await startHost();
      final suggestions =
          (await host.invokeHook(
                    'activity',
                    key: 'ham2k-wwff',
                    method: 'suggest',
                    args: {
                      'operation': {'uuid': 'op'},
                      'searchTerm': 'Hallerbos',
                      'scoped': true,
                    },
                  )
                  as List)
              .cast<Map>();

      expect(suggestions.map((s) => s['ref']), ['ONFF-0558']);
    }, timeout: const Timeout(Duration(seconds: 60)));

    // Names carry numbers — `route 66`, `camp 4`, `park 3` — so a digit alone
    // cannot be what marks text as a code. Both halves of the heuristic are
    // load-bearing, and a program's own pattern short-circuits ahead of them,
    // which is what keeps a program whose references contain a space working.
    test('a scoped NAME search with a number in it still invents nothing', () async {
      final host = await startHost();
      final suggestions =
          (await host.invokeHook(
                    'activity',
                    key: 'ham2k-wwff',
                    method: 'suggest',
                    args: {
                      'operation': {'uuid': 'op'},
                      'searchTerm': 'park 3',
                      'scoped': true,
                    },
                  )
                  as List)
              .cast<Map>();

      expect(suggestions.map((s) => s['ref']), isNot(contains('PARK 3')));
    }, timeout: const Timeout(Duration(seconds: 60)));

    // The guard that keeps the list usable: with a dozen of these programs
    // switched on, offering every one of them's own reading of any typed text
    // would bury the real matches under a dozen invented references.
    test('an unscoped search invents nothing', () async {
      final host = await startHost();
      final suggestions =
          (await host.invokeHook(
                    'activity',
                    key: 'ham2k-wwff',
                    method: 'suggest',
                    args: {
                      'operation': {'uuid': 'op'},
                      'searchTerm': 'ZZ-0055',
                    },
                  )
                  as List)
              .cast<Map>();

      expect(suggestions, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  test('the operation control is keyed so `wwff:` search scoping works', () async {
    final host = await startHost();
    final controls =
        (await host.invokeHook(
                  'activity',
                  key: 'ham2k-wwff',
                  method: 'operationControls',
                  args: {
                    'operation': {'uuid': 'op'},
                  },
                )
                as List)
            .cast<Map>();

    expect(controls.length, 1);
    // The core derives the search scope from the part before the slash, so a
    // control keyed anything else silently never gets scoped.
    expect(controls.first['key'], 'wwff/activation');
    expect((controls.first['input'] as Map)['refType'], 'wwffActivation');
    expect((controls.first['input'] as Map)['kind'], 'refList');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('an activation contributes only its own fields when nothing was hunted', () async {
    final host = await startHost();
    final fields =
        (await host.invokeHook(
                  'adifFields',
                  key: 'ham2k-wwff',
                  method: 'fieldsForOneQSO',
                  args: {
                    'qso': {
                      'their': {'call': 'W1AW'},
                    },
                    'operation': {
                      'refs': [
                        {'type': 'wwffActivation', 'ref': 'ONFF-0558'},
                      ],
                    },
                  },
                )
                as List)
            .cast<Map>();

    expect(fields.map((f) => f['name']), ['MY_SIG', 'MY_SIG_INFO', 'MY_WWFF_REF']);
    expect(fields.map((f) => f['value']), ['WWFF', 'ONFF-0558', 'ONFF-0558']);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
