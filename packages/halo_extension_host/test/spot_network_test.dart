// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Spot fetching across sources, over a stubbed transport: what the host's
// fan-out and its fetch timeouts do when one source stalls or fails, driven
// through `ham2k-pota` and `ham2k-sota`, the two spot sources the app pre-loads.
//
// The seam sits BELOW the interesting code on purpose — the manifest allowlist,
// the https requirement and the canonical User-Agent all still run, so this
// exercises the real path and not a mock of it.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  requireBundles();

  group('one stalled source', () {
    const potaSpots =
        '[{"spotId":1,"activator":"KI2D","frequency":"14285","mode":"SSB",'
        '"reference":"US-1234","name":"Somewhere","locationDesc":"US-CA",'
        '"spotTime":"2026-08-05T21:46:18","spotter":"N0SPOT","comments":"","source":"Web","count":1}]';

    /// POTA answers at once; SOTA's spots request never completes, the way a
    /// server that accepted the connection and then went quiet behaves. Its
    /// epoch probe still answers, so the stall lands on the request that
    /// matters rather than being absorbed by the probe's own timeout.
    ({MockClient client}) potaFastSotaStalled() => (
      client: MockClient((request) async {
        if (request.url.host == 'api.pota.app') {
          return http.Response(potaSpots, 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.endsWith('/epoch')) {
          return http.Response('ed0601ac-a1f9-4666-98ba-2b0e52c07f5e', 200, headers: {'content-type': 'text/plain'});
        }
        return Completer<http.Response>().future; // never settles
      }),
    );

    Future<ExtensionHost> hostWithBoth(http.Client client) async {
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [
          ExtensionBundle(key: 'ham2k-pota', source: bundleSource('ham2k-pota')),
          ExtensionBundle(key: 'ham2k-sota', source: bundleSource('ham2k-sota')),
        ],
        fetchAllowlists: const {
          'ham2k-pota': ['api.pota.app'],
          'ham2k-sota': ['api-db2.sota.org.uk'],
        },
        httpClient: client,
        userAgent: 'Ham2K-Test/1.0',
        onHostCall: nullHostCall,
      );
      addTearDown(host.dispose);
      return host;
    }

    test('costs only its own spots, not everybody elses', () async {
      // The runtime answers a fan-out with ONE message, so without the
      // narration a host that stops waiting discards POTA's spots — finished
      // and sitting there — because SOTA never replied.
      final host = await hostWithBoth(potaFastSotaStalled().client);

      final entries = await host.invokeHookAll(
        'spots',
        method: 'fetchSpots',
        args: {'online': true},
        timeout: const Duration(seconds: 3),
        partialOnTimeout: true,
      );

      final byKey = {for (final e in entries) e['key']: e};
      expect(byKey.keys, containsAll(['ham2k-pota', 'ham2k-sota']));
      expect(byKey['ham2k-pota']!['ok'], true, reason: 'POTA answered and must survive SOTA stalling');
      expect((byKey['ham2k-pota']!['value'] as List), hasLength(1));
      expect(byKey['ham2k-sota']!['ok'], false);
      expect(byKey['ham2k-sota']!['timedOut'], true, reason: 'a source that never answered must be distinguishable from one that answered with an error');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a feed answering 503 is an error entry, not a timeout', () async {
      // The wire contract the operator-facing distinction rests on: an
      // unhappy server is `ok:false` with no `timedOut`, which is what lets
      // the app say "returned an error" rather than "did not respond" — the
      // second would have the operator waiting out a server that is up and
      // will still be refusing in ten minutes. A feed that swallowed its own
      // HTTP status and answered with an empty list would look identical to a
      // quiet band here, and nothing downstream could recover the difference.
      final host = await hostWithBoth(
        MockClient((request) async {
          if (request.url.host.contains('pota')) {
            return http.Response(potaSpots, 200, headers: {'content-type': 'application/json'});
          }
          return http.Response('<html>down</html>', 503);
        }),
      );

      final entries = await host.invokeHookAll('spots', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20));

      final byKey = {for (final e in entries) e['key']: e};
      expect(byKey['ham2k-sota']!['ok'], false);
      expect(byKey['ham2k-sota']!['timedOut'], isNot(true), reason: 'answering badly is not failing to answer');
      expect(byKey['ham2k-sota']!['error'], contains('503'));
      expect(byKey['ham2k-pota']!['ok'], true, reason: "the healthy feed's spots must survive");
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('still throws when the caller did not ask for partial results', () async {
      // Partial results are wrong for most categories — half an ADIF field
      // set writes a silently incomplete export — so they stay opt-in.
      final host = await hostWithBoth(potaFastSotaStalled().client);

      await expectLater(
        host.invokeHookAll('spots', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 3)),
        throwsA(isA<HookTimeoutException>()),
      );
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('FetchOptions.timeout', () {
    test('an extension can give up on its own request before the host would', () async {
      // SOTA's epoch probe asks for 3s. Against a server that never answers
      // it, the probe is abandoned and the spots fetch still happens — where
      // the host's own 15s allowance would have spent the whole fan-out
      // budget on an optimisation.
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/epoch')) return Completer<http.Response>().future;
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      });
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: [ExtensionBundle(key: 'ham2k-sota', source: bundleSource('ham2k-sota'))],
        fetchAllowlists: const {
          'ham2k-sota': ['api-db2.sota.org.uk'],
        },
        httpClient: client,
        userAgent: 'Ham2K-Test/1.0',
        onHostCall: nullHostCall,
      );
      addTearDown(host.dispose);

      final spots =
          await host.invokeHook('spots', key: 'ham2k-sota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 12)) as List;

      expect(spots, isEmpty);
      expect(paths.where((p) => !p.endsWith('/epoch')), hasLength(1), reason: 'the spots request must still be made after the probe is abandoned');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
