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
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart' show ham2kProxyHost;
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_extension_host/src/engine_runtime_io.dart';
import 'package:halo_extension_host/src/fetch_policy.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/bundles.dart';

const probe = r'''
  globalThis.__halo.defineExtension({
    key: 'probe',
    name: 'probe',
    version: '0.0.1',
    onActivation({ registerHook, hostCall }) {
      registerHook('bench', {
        key: 'probe',
        hook: {
          fetch: async (args) => await hostCall('fetch', args),
          fetchStrict: async (args) => await hostCall('fetchStrict', args),
          // The kernel's public surface, where a bundle names any identity it likes.
          fetchStrictAs: async (args) => await globalThis.__halo.hostCall('fetchStrict', { ...args, extensionKey: 'victim' }),
          chatter: async ({ lines }) => {
            for (let i = 0; i < lines; i++) globalThis.__halo.log('line ' + i);
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

  // What the SDK sends a byte body or `redirect` as, so that an app older
  // than both refuses the call. Judged on the same allowlist, which only
  // works if the kernel stamps the caller on it as it does on `fetch`.
  Future<dynamic> fetchStrict(ExtensionHost host, Map<String, dynamic> args) =>
      host.invokeHook('bench', key: 'probe', method: 'fetchStrict', args: args, timeout: const Duration(seconds: 20));

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

    // An upload refusing redirects: a 307 or 308 would send the same signed
    // file to wherever it points, and the first server may already have
    // queued it, so only the extension can decide what to do next.
    test("with redirect 'error', a same-host 307 or an allowed cross-host 308 sends nothing past the first request", () async {
      for (final (status, location) in [(307, '/elsewhere'), (308, 'https://b.example/landing')]) {
        final r = routes({
          'a.example/upload': (_) => redirect(status, location),
          'a.example/elsewhere': (_) => ok('moved'),
          'b.example/landing': (_) => ok('moved'),
        });
        final host = await hostWith(r.client);

        await expectLater(
          fetchStrict(host, {'url': 'https://a.example/upload', 'method': 'POST', 'body': 'signed', 'redirect': 'error'}),
          throwsA(
            isA<ExtensionHostException>()
                .having((e) => e.toString(), 'message', contains('does not follow redirects'))
                // The Location can carry a token; the message reaches logs.
                .having((e) => e.toString(), 'message', isNot(anyOf(contains('elsewhere'), contains('b.example')))),
          ),
          reason: '$status',
        );
        expect(r.sent.map((s) => s.url.toString()), ['https://a.example/upload'], reason: '$status');
      }
    });

    test('a redirect setting other than follow or error is refused before anything is sent', () async {
      final r = routes({'a.example/upload': (_) => ok('sent')});
      final host = await hostWith(r.client);

      await expectLater(fetchStrict(host, {'url': 'https://a.example/upload', 'redirect': 'manual'}), refused("redirect must be 'follow' or 'error'"));
      expect(r.sent, isEmpty);
    });

    test("fetchStrict is refused on the kernel's public surface, as fetch is", () async {
      // Else a bundle could fetch under another extension's identity, and so
      // with that extension's domains.
      final r = routes({'a.example/upload': (_) => ok('sent')});
      final host = await hostWith(r.client);

      await expectLater(
        host.invokeHook('bench', key: 'probe', method: 'fetchStrictAs', args: {'url': 'https://a.example/upload'}, timeout: const Duration(seconds: 20)),
        refused("needs the calling extension's identity"),
      );
      expect(r.sent, isEmpty);
    });

    test("redirect 'error' to a host reached through Ham2K's proxy is refused before anything is sent", () async {
      // The proxy follows redirects itself, so the request would go on to
      // wherever one pointed and come back looking answered. An http-only
      // host goes through it on every build.
      final r = routes({'$ham2kProxyHost/qsopartyhub.com/upload': (_) => ok('sent')});
      final host = await hostWith(r.client, domains: ['qsopartyhub.com']);

      await expectLater(fetchStrict(host, {'url': 'http://qsopartyhub.com/upload', 'method': 'POST', 'redirect': 'error'}), refused("through Ham2K's proxy"));
      expect(r.sent, isEmpty);
      // Without it, the same request goes out through the proxy as before.
      await fetchStrict(host, {'url': 'http://qsopartyhub.com/upload', 'method': 'POST'});
      expect(r.sent.single.url.host, ham2kProxyHost);
    });
  });

  group('request bodies', () {
    // A multipart upload the way LoTW takes one: a gzip file (1f 8b 08 …),
    // with the bytes a text body would mangle (00, 8b, ff) in it.
    final file = Uint8List.fromList([0x1f, 0x8b, 0x08, 0x00, 0x8b, 0xff, 0x00, 0x7f]);
    final multipart = Uint8List.fromList([
      ...'--b\r\nContent-Disposition: form-data; name="upfile"; filename="log.tq8"\r\n\r\n'.codeUnits,
      ...file,
      ...'\r\n--b--\r\n'.codeUnits,
    ]);

    test('bytes reach the server exactly as the extension built them', () async {
      final r = routes({'a.example/upload': (_) => ok('queued')});
      final host = await hostWith(r.client);

      await fetchStrict(host, {
        'url': 'https://a.example/upload',
        'method': 'POST',
        'headers': {'Content-Type': 'multipart/form-data; boundary=b'},
        'bodyBase64': base64Encode(multipart),
      });

      expect(r.sent.single.bodyBytes, multipart);
      expect(r.sent.single.headers['content-type'], 'multipart/form-data; boundary=b');
    });

    test('a 307 or 308 repeats the bytes; a 303 drops them', () async {
      for (final (status, expected) in [(307, multipart), (308, multipart), (303, Uint8List(0))]) {
        final r = routes({'a.example/upload': (_) => redirect(status, '/again'), 'a.example/again': (_) => ok('queued')});
        final host = await hostWith(r.client);

        await fetchStrict(host, {'url': 'https://a.example/upload', 'method': 'POST', 'bodyBase64': base64Encode(multipart)});

        expect(r.sent.last.bodyBytes, expected, reason: '$status');
      }
    });

    test('a malformed, doubled or oversized body never reaches the client', () async {
      final r = routes({'a.example/upload': (_) => ok('queued')});
      final host = await hostWith(r.client);
      Future<void> refusedWith(Map<String, dynamic> body, String fragment) =>
          expectLater(fetchStrict(host, {'url': 'https://a.example/upload', 'method': 'POST', ...body}), refused(fragment));

      await refusedWith({'bodyBase64': 'not*base64'}, 'bodyBase64 is not Base64');
      await refusedWith({'bodyBase64': 'AAAA', 'body': 'text'}, 'not both body and bodyBase64');
      // Measured before decoding: a decode first would call this not Base64.
      await refusedWith({'bodyBase64': '*' * ((kMaxFetchBodyBytes + 2) ~/ 3 * 4 + 1)}, 'more than $kMaxFetchBodyBytes bytes');
      // And after: 2^24 + 1 bytes encode no longer than 2^24 do.
      await refusedWith({'bodyBase64': base64Encode(Uint8List(kMaxFetchBodyBytes + 1))}, 'more than $kMaxFetchBodyBytes bytes');
      // A string by its UTF-8 bytes, not its characters: each é is two.
      await refusedWith({'body': 'é' * (kMaxFetchBodyBytes ~/ 2 + 1)}, 'more than $kMaxFetchBodyBytes bytes');
      expect(r.sent, isEmpty);
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
