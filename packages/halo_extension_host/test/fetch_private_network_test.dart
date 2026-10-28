// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where `host.fetch` may not go on a wildcard grant: the local network, which
// a `*` entry never means, and which an extension reaches only by naming the
// host itself or under developer mode. Driven through the REAL kernel by a
// probe bundle, with the network stubbed below the host's own checks.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_extension_host/src/fetch_policy.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/bundles.dart';

// Two extensions from one bundle: `probe-sub` is `probe`'s sub-extension, on
// its grant and, since a grant is a bundle's, on its fetch slots.
const probe = r'''
  for (const key of ['probe', 'probe-sub']) {
    globalThis.__polo.defineExtension({
      key,
      name: key,
      version: '0.0.1',
      onActivation({ registerHook, hostCall }) {
        registerHook('bench', {
          key,
          hook: {
            fetch: async (args) => await hostCall('fetch', args),
          },
        });
      },
    });
  }
''';

void main() {
  requireBundles();

  Future<ExtensionHost> hostWith(http.Client client, {List<String> domains = const ['*'], bool developerMode = false}) async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: [ExtensionBundle(key: 'probe', source: probe)],
      fetchAllowlists: {'probe': domains},
      httpClient: client,
      userAgent: 'Ham2K-Test/1.0',
      onHostCall: nullHostCall,
      developerMode: developerMode,
    );
    addTearDown(host.dispose);
    return host;
  }

  Future<dynamic> fetch(ExtensionHost host, String url, {String key = 'probe'}) =>
      host.invokeHook('bench', key: key, method: 'fetch', args: {'url': url}, timeout: const Duration(seconds: 20));

  Matcher refused(String fragment) => throwsA(isA<ExtensionHostException>().having((e) => e.toString(), 'message', contains(fragment)));

  /// A client that answers everything, recording what reached it.
  ({List<Uri> sent, MockClient client}) recording() {
    final sent = <Uri>[];
    return (
      sent: sent,
      client: MockClient((request) async {
        sent.add(request.url);
        return http.Response('reached', 200);
      }),
    );
  }

  group('a wildcard grant never reaches the local network', () {
    for (final host in [
      '192.168.1.10',
      '10.0.0.1',
      '172.16.5.5',
      '127.0.0.1',
      '169.254.1.1',
      '0.0.0.0',
      '[::1]',
      '[fd00::1]',
      '[::ffff:10.0.0.1]',
      '[fe80::1%25en0]',
      'localhost',
      'radio.local',
      'shack.localhost',
    ]) {
      test('https://$host/ is refused before anything is sent', () async {
        final r = recording();
        final h = await hostWith(r.client);
        await expectLater(fetch(h, 'https://$host/status'), refused('is on the local network'));
        expect(r.sent, isEmpty);
      });
    }

    test('the public internet is what the wildcard grants', () async {
      final r = recording();
      final h = await hostWith(r.client);
      expect(((await fetch(h, 'https://api.example/x')) as Map)['body'], 'reached');
      expect(r.sent.map((u) => u.host), ['api.example']);
    });

    test('a wildcard that would match a local name grants nothing local', () async {
      final r = recording();
      final h = await hostWith(r.client, domains: ['*.local']);
      await expectLater(fetch(h, 'https://radio.local/'), refused('is on the local network'));
      expect(r.sent, isEmpty);
    });

    test('a public host redirecting to a local address is stopped on that hop', () async {
      final sent = <Uri>[];
      final client = MockClient((request) async {
        sent.add(request.url);
        return request.url.host == 'api.example' ? http.Response('', 302, headers: {'location': 'https://192.168.1.1/admin'}) : http.Response('reached', 200);
      });
      final h = await hostWith(client);
      await expectLater(fetch(h, 'https://api.example/start'), refused("'192.168.1.1' is on the local network"));
      expect(sent.map((u) => u.host), ['api.example']);
    });
  });

  group('what admits a local host', () {
    test('an entry naming it, and only that one', () async {
      final r = recording();
      final h = await hostWith(r.client, domains: ['192.168.1.10', 'radio.local']);
      expect(((await fetch(h, 'https://192.168.1.10/status')) as Map)['body'], 'reached');
      expect(((await fetch(h, 'https://radio.local/status')) as Map)['body'], 'reached');
      await expectLater(fetch(h, 'https://192.168.1.11/status'), refused('is not in extension'));
      expect(r.sent.map((u) => u.host), ['192.168.1.10', 'radio.local']);
    });

    test('developer mode, for as long as it is on', () async {
      final r = recording();
      final h = await hostWith(r.client, developerMode: true);
      expect(((await fetch(h, 'https://localhost/dev')) as Map)['status'], 200);
      h.setDeveloperMode(false);
      await expectLater(fetch(h, 'https://localhost/dev'), refused('or in developer mode'));
      h.setDeveloperMode(true);
      expect(((await fetch(h, 'https://localhost/dev')) as Map)['status'], 200);
      expect(r.sent, hasLength(2));
    });
  });

  group('which transport a hop takes', () {
    test('guarded unless developer mode, or a host the extension named itself', () {
      // The guarded transport refuses a local answer at the socket, so the
      // plain one must carry exactly what the rule consents to: a host named
      // in `domains` is consent to that name wherever it resolves — a server
      // behind split DNS is what naming it is for — and a wildcard match is
      // consent to nothing in particular.
      bool guarded({bool dev = false, bool named = false}) => fetchHopGuarded(developerMode: dev, namedHost: named);
      expect(guarded(), isTrue, reason: 'a wildcard match');
      expect(guarded(named: true), isFalse, reason: 'a host named in domains, public or local');
      expect(guarded(dev: true), isFalse);
      expect(guarded(dev: true, named: true), isFalse);
    });
  });

  group('in flight', () {
    test('the ninth concurrent fetch from one extension is refused, and a finished one frees its slot', () async {
      final pending = <Completer<http.Response>>[];
      final client = MockClient((request) {
        final answer = Completer<http.Response>();
        pending.add(answer);
        return answer.future;
      });
      final h = await hostWith(client);
      Future<void> reached(int count) async {
        while (pending.length < count) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      final first = fetch(h, 'https://api.example/0');
      final rest = [for (var i = 1; i < kMaxFetchesInFlight; i++) fetch(h, 'https://api.example/$i')];
      await reached(kMaxFetchesInFlight);
      await expectLater(fetch(h, 'https://api.example/ninth'), refused('already has $kMaxFetchesInFlight requests in flight'));
      expect(pending, hasLength(kMaxFetchesInFlight), reason: 'the refused one never reached the client');

      pending.first.complete(http.Response('done', 200));
      expect(((await first) as Map)['body'], 'done');
      final tenth = fetch(h, 'https://api.example/tenth');
      await reached(kMaxFetchesInFlight + 1);
      pending.last.complete(http.Response('tenth', 200));
      expect(((await tenth) as Map)['body'], 'tenth');

      for (final answer in pending) {
        if (!answer.isCompleted) answer.complete(http.Response('late', 200));
      }
      await Future.wait(rest);
    });

    test("a bundle's sub-extensions draw on its slots, not on eight of their own", () async {
      final pending = <Completer<http.Response>>[];
      final client = MockClient((request) {
        final answer = Completer<http.Response>();
        pending.add(answer);
        return answer.future;
      });
      final h = await hostWith(client);
      final held = [for (var i = 0; i < kMaxFetchesInFlight; i++) fetch(h, 'https://api.example/$i')];
      while (pending.length < kMaxFetchesInFlight) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await expectLater(fetch(h, 'https://api.example/sub', key: 'probe-sub'), refused("'probe' already has $kMaxFetchesInFlight requests in flight"));
      for (final answer in pending) {
        answer.complete(http.Response('done', 200));
      }
      await Future.wait(held);
    });
  });
}
