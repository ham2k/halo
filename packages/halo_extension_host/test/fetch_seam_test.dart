// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `ExtensionHost.start(httpClient: …)` — the seam for testing anything an
// extension fetches.
//
// Before it, `_HostCore` answered `host.fetch` itself in both isolate and
// in-process modes, so nothing could observe an extension's requests or answer
// them: every spot feed and every spot post in the codebase was untestable.
//
// The seam sits deliberately BELOW the interesting code. The manifest
// allowlist, the https requirement, the canonical User-Agent and both timeouts
// all still run, so a test exercises the real path — and a stub cannot become a
// way to route around any of them.
//
// POTA is the vehicle: it ships in the app, and it both reads a spot feed and
// posts to one.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  requireBundles();

  ({List<http.Request> sent, MockClient client}) recorder(String body, {int status = 200}) {
    final sent = <http.Request>[];
    return (
      sent: sent,
      client: MockClient((request) async {
        sent.add(request);
        return http.Response(body, status, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
  }

  Future<ExtensionHost> hostWith(http.Client client, {List<String> domains = const ['api.pota.app', 'pota.app']}) async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: 'pota', source: bundleSource('pota'))],
      fetchAllowlists: {'pota': domains},
      httpClient: client,
      userAgent: 'Ham2K-Test/1.0',
      onHostCall: nullHostCall,
    );
    addTearDown(host.dispose);
    return host;
  }

  test('a stubbed client answers what an extension fetches', () async {
    final rec = recorder(
      '[{"spotId":1,"activator":"W1AW","frequency":"14285","mode":"SSB",'
      '"reference":"US-0001","name":"Acadia","locationDesc":"US-ME",'
      '"spotTime":"2026-07-01T12:00:00","spotter":"K2ABC","comments":"","source":"Web","count":1}]',
    );
    final host = await hostWith(rec.client);

    final spots = (await host.invokeHook('spots', key: 'pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20)) as List)
        .cast<Map>();

    expect(spots.single['freq'], 14285);
    expect((spots.single['their'] as Map)['call'], 'W1AW');
    expect(rec.sent.single.url.host, 'api.pota.app');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the request is observable, so a POST body can be asserted', () async {
    // This is the capability that matters: a wrong payload is otherwise
    // invisible until somebody notices spots not appearing.
    final rec = recorder('{}');
    final host = await hostWith(rec.client);

    final result =
        await host.invokeHook(
              'spots',
              key: 'pota',
              method: 'postSelfSpot',
              args: {
                'operation': {
                  'stationCall': 'W1AW',
                  'refs': [
                    {'type': 'potaActivation', 'ref': 'US-0001'},
                  ],
                },
                'freq': 14285,
                'mode': 'SSB',
              },
              timeout: const Duration(seconds: 20),
            )
            as Map;

    expect(result['ok'], true);
    final body = jsonDecode(rec.sent.single.body) as Map<String, dynamic>;
    expect(body['activator'], 'W1AW');
    expect(body['reference'], 'US-0001');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a multi-station Test Operation still spots the K-TEST sandbox ref, not its real park', () async {
    // The app appends BOTH suffixes before the hook sees the call
    // (`ExtensionService.spotCallForSelfSpot`), so what arrives here is
    // `KI2D/TEST/OP1`. If the extension stops recognizing that as a test
    // call, this posts a live spot to a park nobody is at — the one failure
    // the /TEST rewrite exists to prevent, and one no local check can see.
    final rec = recorder('{}');
    final host = await hostWith(rec.client);

    await host.invokeHook(
      'spots',
      key: 'pota',
      method: 'postSelfSpot',
      args: {
        'operation': {
          'stationCall': 'KI2D/TEST/OP1',
          'refs': [
            {'type': 'potaActivation', 'ref': 'US-0001'},
          ],
        },
        'freq': 14285,
        'mode': 'SSB',
      },
      timeout: const Duration(seconds: 20),
    );

    final body = jsonDecode(rec.sent.single.body) as Map<String, dynamic>;
    expect(body['reference'], 'K-TEST');
    expect(body['activator'], 'KI2D/TEST/OP1');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the canonical User-Agent is still stamped', () async {
    // Proof the seam is below the host's own behaviour rather than replacing
    // it: an extension cannot become anonymous by being tested.
    final rec = recorder('[]');
    final host = await hostWith(rec.client);
    await host.invokeHook('spots', key: 'pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20));

    expect(rec.sent.single.headers['User-Agent'], 'Ham2K-Test/1.0');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a transient DNS lookup failure is retried once and recovers', () async {
    var calls = 0;
    final sent = <http.Request>[];
    final client = MockClient((request) async {
      sent.add(request);
      calls++;
      if (calls == 1) {
        throw http.ClientException("Failed host lookup: 'api.pota.app'", request.url);
      }
      return http.Response('[]', 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final host = await hostWith(client);

    final spots = await host.invokeHook('spots', key: 'pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20));

    expect(spots, isEmpty);
    expect(sent, hasLength(2));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the retry delay stays within its documented 300-500ms jitter range', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) {
        throw http.ClientException("Failed host lookup: 'api.pota.app'", request.url);
      }
      return http.Response('[]', 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final host = await hostWith(client);

    final stopwatch = Stopwatch()..start();
    await host.invokeHook('spots', key: 'pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20));
    stopwatch.stop();

    // Generous slack above the 300-500ms production range for test/CI
    // scheduling noise — this only needs to catch a gross regression (e.g.
    // the base and jitter width getting swapped), not pin the exact bounds.
    expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(250));
    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a second consecutive DNS lookup failure is not retried again', () async {
    final sent = <http.Request>[];
    final client = MockClient((request) async {
      sent.add(request);
      throw http.ClientException("Failed host lookup: 'api.pota.app'", request.url);
    });
    final host = await hostWith(client);

    await expectLater(
      host.invokeHook('spots', key: 'pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20)),
      throwsA(anything),
    );
    expect(sent, hasLength(2));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a lookup failure for a different host (a followed redirect) is not retried', () async {
    // dart:io follows redirects inside a single send() call, so a lookup
    // failure can name a host other than the one this call actually targeted
    // — by which point a POST body may already be sitting on the ORIGINAL
    // server. Retrying then would resend it a second time, so only a failure
    // naming this call's own host may be retried.
    final sent = <http.Request>[];
    final client = MockClient((request) async {
      sent.add(request);
      throw http.ClientException("Failed host lookup: 'cdn.example.com'", request.url);
    });
    final host = await hostWith(client);

    await expectLater(
      host.invokeHook('spots', key: 'pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20)),
      throwsA(anything),
    );
    expect(sent, hasLength(1));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a non-lookup network failure is not retried', () async {
    final sent = <http.Request>[];
    final client = MockClient((request) async {
      sent.add(request);
      throw http.ClientException('Connection refused', request.url);
    });
    final host = await hostWith(client);

    await expectLater(
      host.invokeHook('spots', key: 'pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20)),
      throwsA(anything),
    );
    expect(sent, hasLength(1));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a real DNS failure still matches the message the retry keys on', () async {
    // MockClient above proves the retry's own logic; this proves the exact
    // assumption that logic depends on — that package:http still wraps a
    // real dart:io lookup failure as "Failed host lookup: '<host>'" (the
    // literal condition `_hostFetch`'s catch checks). If a future
    // package:http or Dart SDK release changes that wording, this is the
    // test that goes red instead of the retry silently going dark.
    final client = http.Client();
    addTearDown(client.close);
    const host = 'this-host-does-not-exist.invalid';
    await expectLater(
      client.get(Uri.parse('https://$host/')),
      throwsA(isA<http.ClientException>().having((e) => e.message, 'message', startsWith("Failed host lookup: '$host'"))),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('the manifest allowlist still blocks, stub or no stub', () async {
    final rec = recorder('[]');
    final host = await hostWith(rec.client, domains: const []);

    await expectLater(
      host.invokeHook('spots', key: 'pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20)),
      throwsA(anything),
    );
    expect(rec.sent, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
