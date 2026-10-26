// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The ceilings the host holds an extension to. `host.fetch` judged its
// allowlist on the host asked for while the client followed redirects inside
// one send(), so an allowed host could hand the request to any other, or to
// plain http, and the body came back whole whatever its size. The log buffer
// grew for the whole session, and the engine's heap had a ceiling on Android
// alone. Driven through the REAL kernel by a probe bundle, with the network
// stubbed below the host's own checks (the fetch seam).

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_extension_host/src/engine_runtime_io.dart';
import 'package:halo_extension_host/src/fetch_policy.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/bundles.dart';

const probe = r'''
  globalThis.__polo.defineExtension({
    key: 'probe',
    name: 'probe',
    version: '0.0.1',
    onActivation({ registerHook, hostCall }) {
      registerHook('bench', {
        key: 'probe',
        hook: {
          fetch: async (args) => await hostCall('fetch', args),
          chatter: async ({ lines }) => {
            for (let i = 0; i < lines; i++) globalThis.__polo.log('line ' + i);
            return lines;
          },
          hog: async () => {
            const a = [];
            while (true) a.push(new Array(10000).fill(1));
          },
          hello: async () => 'hi',
        },
      });
    },
  });
''';

void main() {
  requireBundles();

  Future<ExtensionHost> hostWith(http.Client client, {List<String> domains = const ['a.example', 'b.example']}) async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: 'probe', source: probe)],
      fetchAllowlists: {'probe': domains},
      httpClient: client,
      userAgent: 'Ham2K-Test/1.0',
      onHostCall: nullHostCall,
    );
    addTearDown(host.dispose);
    return host;
  }

  Future<dynamic> fetch(ExtensionHost host, Map<String, dynamic> args) =>
      host.invokeHook('bench', key: 'probe', method: 'fetch', args: args, timeout: const Duration(seconds: 20));

  Matcher refused(String fragment) => throwsA(isA<ExtensionHostException>().having((e) => e.toString(), 'message', contains(fragment)));

  /// A client answering each path as [answers] says, recording what was sent.
  ({List<http.Request> sent, MockClient client}) routes(Map<String, http.Response Function(http.Request)> answers) {
    final sent = <http.Request>[];
    return (
      sent: sent,
      client: MockClient((request) async {
        sent.add(request);
        final answer = answers['${request.url.host}${request.url.path}'];
        return answer == null ? http.Response('no route', 404) : answer(request);
      }),
    );
  }

  http.Response redirect(int status, String location) => http.Response('', status, headers: {'location': location});
  http.Response ok(String body) => http.Response(body, 200, headers: {'content-type': 'text/plain; charset=utf-8'});

  group('redirects', () {
    test('one inside the allowlist is followed, and the body is the target\'s', () async {
      final r = routes({'a.example/start': (_) => redirect(302, 'https://b.example/landing'), 'b.example/landing': (_) => ok('landed')});
      final host = await hostWith(r.client);

      final result = await fetch(host, {'url': 'https://a.example/start'}) as Map;

      expect(result['status'], 200);
      expect(result['body'], 'landed');
      expect(r.sent.map((s) => s.url.toString()), ['https://a.example/start', 'https://b.example/landing']);
    });

    test('one to a host outside the allowlist is refused before anything reaches it', () async {
      final r = routes({'a.example/start': (_) => redirect(302, 'https://evil.example/collect'), 'evil.example/collect': (_) => ok('got it')});
      final host = await hostWith(r.client);

      await expectLater(fetch(host, {'url': 'https://a.example/start'}), refused("'evil.example' is not in extension 'probe'"));
      expect(r.sent.map((s) => s.url.host), ['a.example']);
    });

    test('one to plain http is refused, allowed host or not', () async {
      final r = routes({'a.example/start': (_) => redirect(302, 'http://b.example/landing')});
      final host = await hostWith(r.client);

      await expectLater(fetch(host, {'url': 'https://a.example/start'}), refused('is not https'));
      expect(r.sent, hasLength(1));
    });

    test('a relative Location resolves against the URL the extension named', () async {
      final r = routes({'a.example/start': (_) => redirect(302, '/next'), 'a.example/next': (_) => ok('next')});
      final host = await hostWith(r.client);

      expect((await fetch(host, {'url': 'https://a.example/start'}) as Map)['body'], 'next');
      expect(r.sent.last.url.toString(), 'https://a.example/next');
    });

    test('a 303, or a 302 after a POST, continues as a GET with no body; a 307 repeats the POST', () async {
      for (final (status, expectedMethod, expectedBody) in [(303, 'GET', ''), (302, 'GET', ''), (307, 'POST', 'payload')]) {
        final r = routes({'a.example/start': (_) => redirect(status, 'https://b.example/landing'), 'b.example/landing': (_) => ok('landed')});
        final host = await hostWith(r.client);

        await fetch(host, {'url': 'https://a.example/start', 'method': 'POST', 'body': 'payload'});

        expect(r.sent.last.method, expectedMethod, reason: '$status');
        expect(r.sent.last.body, expectedBody, reason: '$status');
      }
    });

    test('credentials go only to the host they were sent to; the rest of the headers travel', () async {
      final r = routes({'a.example/start': (_) => redirect(302, 'https://b.example/landing'), 'b.example/landing': (_) => ok('landed')});
      final host = await hostWith(r.client);

      await fetch(host, {
        'url': 'https://a.example/start',
        'headers': {'Authorization': 'Bearer for-a', 'Cookie': 'session=1', 'X-Request-Id': 'kept'},
      });

      expect(r.sent.first.headers['authorization'], 'Bearer for-a');
      expect(r.sent.last.headers.keys.map((k) => k.toLowerCase()), isNot(anyOf(contains('authorization'), contains('cookie'))));
      expect(r.sent.last.headers['x-request-id'], 'kept');
    });

    test('credentials stay on a hop within the same host', () async {
      final r = routes({'a.example/start': (_) => redirect(302, '/next'), 'a.example/next': (_) => ok('next')});
      final host = await hostWith(r.client);

      await fetch(host, {
        'url': 'https://a.example/start',
        'headers': {'Authorization': 'Bearer for-a'},
      });

      expect(r.sent.last.headers['authorization'], 'Bearer for-a');
    });

    test('a converted GET carries no content headers', () async {
      final r = routes({'a.example/start': (_) => redirect(303, 'https://b.example/landing'), 'b.example/landing': (_) => ok('landed')});
      final host = await hostWith(r.client);

      await fetch(host, {
        'url': 'https://a.example/start',
        'method': 'POST',
        'body': '{"a":1}',
        'headers': {'Content-Type': 'application/json', 'Accept': 'text/plain'},
      });

      expect(r.sent.last.method, 'GET');
      expect(r.sent.last.headers.keys.map((k) => k.toLowerCase()), isNot(contains('content-type')));
      expect(r.sent.last.headers['accept'], 'text/plain');
    });

    test('a 304 carrying a Location is an answer, not a redirect', () async {
      final r = routes({
        'a.example/start': (_) => http.Response('', 304, headers: {'location': 'https://b.example/x'}),
      });
      final host = await hostWith(r.client);

      expect((await fetch(host, {'url': 'https://a.example/start'}) as Map)['status'], 304);
      expect(r.sent, hasLength(1));
    });

    test('more than five is a refusal', () async {
      final r = routes({'a.example/loop': (_) => redirect(302, '/loop')});
      final host = await hostWith(r.client);

      await expectLater(fetch(host, {'url': 'https://a.example/loop'}), refused('redirected more than $kMaxFetchRedirects times'));
      expect(r.sent, hasLength(kMaxFetchRedirects + 1));
    });
  });

  test('a body past the cap is refused as it arrives, not after it has all come in', () async {
    var pulled = 0;
    Stream<List<int>> chunks(int count) async* {
      for (var i = 0; i < count; i++) {
        pulled++;
        yield Uint8List(1024 * 1024);
      }
    }

    final client = MockClient.streaming((request, _) async => http.StreamedResponse(chunks(64), 200, headers: {'content-type': 'text/plain'}));
    final host = await hostWith(client);

    await expectLater(fetch(host, {'url': 'https://a.example/big'}), refused('more than $kMaxFetchBodyBytes bytes'));
    // One chunk past the cap is what tripped it; the rest never came in.
    expect(pulled, kMaxFetchBodyBytes ~/ (1024 * 1024) + 1);
  });

  test('the log buffer holds the last two thousand lines, and no more', () async {
    final host = await hostWith(MockClient((_) async => http.Response('', 404)));

    await host.invokeHook('bench', key: 'probe', method: 'chatter', args: {'lines': 2500}, timeout: const Duration(seconds: 20));

    expect(host.logLines, hasLength(2000));
    expect(host.logLines.last, 'line 2499');
    expect(host.logLines.first, 'line 500');
  });

  group('the memory ceiling', () {
    test('is set on every platform, tighter on a phone', () {
      expect(memoryCeilingBytes(mobile: true), 256 * 1024 * 1024);
      expect(memoryCeilingBytes(mobile: false), 512 * 1024 * 1024);
    });

    test('trips inside the engine, and the runtime answers afterwards', () async {
      debugMemoryLimitOverride = 48 * 1024 * 1024;
      addTearDown(() => debugMemoryLimitOverride = null);
      final host = await hostWith(MockClient((_) async => http.Response('', 404)));

      await expectLater(
        host.invokeHook('bench', key: 'probe', method: 'hog', args: const {}, timeout: const Duration(seconds: 20)),
        throwsA(isA<ExtensionHostException>().having((e) => e.toString().toLowerCase(), 'message', contains('memory'))),
      );
      expect(await host.invokeHook('bench', key: 'probe', method: 'hello', args: const {}, timeout: const Duration(seconds: 10)), 'hi');
    });
  });
}
