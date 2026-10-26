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
// `ham2k-pota` is the vehicle: the app pre-loads it, and it both reads a spot
// feed and posts to one.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_extension_host/src/fetch_policy.dart';

import 'support/bundles.dart';
import 'support/fake_clock.dart';
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
      extensions: [ExtensionBundle(key: 'ham2k-pota', source: bundleSource('ham2k-pota'))],
      fetchAllowlists: {'ham2k-pota': domains},
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

    final spots =
        (await host.invokeHook('spots', key: 'ham2k-pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20)) as List)
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
              key: 'ham2k-pota',
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

  test('the canonical User-Agent is still stamped', () async {
    // Proof the seam is below the host's own behaviour rather than replacing
    // it: an extension cannot become anonymous by being tested.
    final rec = recorder('[]');
    final host = await hostWith(rec.client);
    await host.invokeHook('spots', key: 'ham2k-pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20));

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

    final spots = await host.invokeHook('spots', key: 'ham2k-pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20));

    expect(spots, isEmpty);
    expect(sent, hasLength(2));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test(
    'the retry delay stays within its documented 300-500ms jitter range',
    () => runOnFakeClock((async) async {
      var calls = 0;
      Duration? retriedAfter;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) {
          retriedAfter = async.elapsed;
          throw http.ClientException("Failed host lookup: 'api.pota.app'", request.url);
        }
        retriedAfter = async.elapsed - retriedAfter!;
        return http.Response('[]', 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      final host = await hostWith(client);

      // Many tries, each a fresh draw of the jitter, so a range swapped or
      // stretched is seen rather than landed inside by luck. Measured between
      // the failed request and its retry, on the fake clock the delay runs on.
      for (var i = 0; i < 20; i++) {
        calls = 0;
        await host.invokeHook('spots', key: 'ham2k-pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20));
        expect(calls, 2);
        expect(retriedAfter!.inMilliseconds, inInclusiveRange(300, 500));
      }
    }),
  );

  test('a second consecutive DNS lookup failure is not retried again', () async {
    final sent = <http.Request>[];
    final client = MockClient((request) async {
      sent.add(request);
      throw http.ClientException("Failed host lookup: 'api.pota.app'", request.url);
    });
    final host = await hostWith(client);

    await expectLater(
      host.invokeHook('spots', key: 'ham2k-pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20)),
      throwsA(anything),
    );
    expect(sent, hasLength(2));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a lookup failure naming another host is not retried', () async {
    // The retry exists for a resolver hiccup on THIS hop's host, and only a
    // failure naming it is one. Redirects are followed by hand, a hop at a
    // time, so a failure naming any other host is not this hop's, whatever
    // produced it, and is not retried.
    final sent = <http.Request>[];
    final client = MockClient((request) async {
      sent.add(request);
      throw http.ClientException("Failed host lookup: 'cdn.example.com'", request.url);
    });
    final host = await hostWith(client);

    await expectLater(
      host.invokeHook('spots', key: 'ham2k-pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20)),
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
      host.invokeHook('spots', key: 'ham2k-pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20)),
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
      host.invokeHook('spots', key: 'ham2k-pota', method: 'fetchSpots', args: {'online': true}, timeout: const Duration(seconds: 20)),
      throwsA(anything),
    );
    expect(rec.sent, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 60)));

  group('a plain-http fetch', () {
    // An extension that fetches whatever URL it is handed, so the host's own
    // routing is the only thing under test.
    const fetcherSource = '''
__polo.defineExtension({
  key: 'fetcher',
  name: 'Fetcher',
  version: '0.0.1',
  onActivation: function (api) {
    boundHostCall = api.hostCall
    api.registerHook('bench', { key: 'fetcher', hook: {
      get: async function (args) { return await boundHostCall('fetch', { url: args.url }) },
    }})
  },
})
var boundHostCall = null
''';

    Future<ExtensionHost> fetcherWith(http.Client client, List<String> domains) async {
      final host = await ExtensionHost.start(
        kernelSource: bundleSource('kernel'),
        extensions: const [ExtensionBundle(key: 'fetcher', source: fetcherSource)],
        fetchAllowlists: {'fetcher': domains},
        httpClient: client,
        userAgent: 'Ham2K-Test/1.0',
        onHostCall: nullHostCall,
      );
      addTearDown(host.dispose);
      return host;
    }

    Future<Object?> fetch(ExtensionHost host, String url) =>
        host.invokeHook('bench', key: 'fetcher', method: 'get', args: {'url': url}, timeout: const Duration(seconds: 20));

    test('to an http-only host goes out over https, through the proxy', () async {
      // The QSO Party Hub serves http only. Without the rewrite, the https
      // check refuses it and an extension has to hard-code somebody's proxy.
      final rec = recorder('<table></table>');
      final host = await fetcherWith(rec.client, const ['qsopartyhub.com']);

      final result = await fetch(host, 'http://qsopartyhub.com/txqp-table.php?x=1') as Map;

      expect(result['status'], 200);
      expect(rec.sent.single.url.toString(), 'https://services.ham2k.net/qsopartyhub.com/txqp-table.php?x=1');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('to any other host is still refused, before anything is sent', () async {
      // The proxy relays only what its config names. Rewriting an unknown
      // host would send it a 404 at best; sending it direct would be the
      // plain-http request the https rule exists to prevent.
      final rec = recorder('');
      final host = await fetcherWith(rec.client, const ['example.com']);

      await expectLater(fetch(host, 'http://example.com/'), throwsA(anything));
      expect(rec.sent, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('to a host that serves https is refused, not detoured through the proxy', () async {
      // An `http://` typo for QRZ must fail loudly on native. Proxying it
      // would work, and would quietly put the logbook API key in the body
      // through Ham2K infrastructure on every call.
      final rec = recorder('');
      final host = await fetcherWith(rec.client, const ['logbook.qrz.com']);

      await expectLater(fetch(host, 'http://logbook.qrz.com/api'), throwsA(anything));
      expect(rec.sent, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('is checked against the host the extension named, not the proxy', () async {
      // Declaring services.ham2k.net must not buy access to every host it
      // relays: the manifest says which sources an extension talks to.
      final rec = recorder('');
      final host = await fetcherWith(rec.client, const ['services.ham2k.net']);

      await expectLater(fetch(host, 'http://qsopartyhub.com/txqp-table.php'), throwsA(anything));
      expect(rec.sent, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('extensionFetchUri', () {
    test('leaves an https fetch to a proxied host direct on a native build', () {
      // Native builds have no CORS to get around; sending them through the
      // proxy would put every POTA and QRZ request on Ham2K infrastructure
      // for nothing.
      final uri = Uri.parse('https://api.pota.app/spot/activator');
      expect(extensionFetchUri(uri, onWeb: false), uri);
    });

    test('proxies an https fetch to a proxied host on web, query and all', () {
      expect(
        extensionFetchUri(Uri.parse('https://www.parksnpeaks.org/api/SPOTS?a=b%20c'), onWeb: true).toString(),
        'https://services.ham2k.net/www.parksnpeaks.org/api/SPOTS?a=b%20c',
      );
    });

    test('proxies an http-only host on every build', () {
      for (final onWeb in [false, true]) {
        expect(
          extensionFetchUri(Uri.parse('http://qsopartyhub.com/txqp-spots.php'), onWeb: onWeb).toString(),
          'https://services.ham2k.net/qsopartyhub.com/txqp-spots.php',
        );
      }
    });

    test('leaves plain http to a web-proxied host unchanged on a native build', () {
      // Unchanged means refused by the https check — the web proxy list is
      // not a licence to reach those hosts over http.
      const url = 'http://logbook.qrz.com/api';
      expect(extensionFetchUri(Uri.parse(url), onWeb: false).toString(), url);
    });

    test('leaves a host the proxy does not route unchanged, http or not', () {
      for (final url in ['http://example.com/a', 'https://example.com/a']) {
        expect(extensionFetchUri(Uri.parse(url), onWeb: true).toString(), url);
      }
    });

    test('routes SOTA SSO by path, on web only', () {
      // Only the two endpoints Keycloak gives a browser no CORS for; the
      // rest of the host, and every native call, stays direct so SOTA
      // tokens transit Ham2K infrastructure only where there is no choice.
      const token = 'https://sso.sota.org.uk/auth/realms/SOTA/protocol/openid-connect/token';
      const discovery = 'https://sso.sota.org.uk/auth/realms/SOTA/.well-known/openid-configuration';
      expect(extensionFetchUri(Uri.parse(token), onWeb: true).host, 'services.ham2k.net');
      expect(extensionFetchUri(Uri.parse(token), onWeb: false).toString(), token);
      expect(extensionFetchUri(Uri.parse(discovery), onWeb: true).toString(), discovery);
    });
  });
}
