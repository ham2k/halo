// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The app end of the extension dev loop (HALO-118, docs/extensions/development.md):
// what it accepts as a dev server, what it does with what the server says, and
// the one property that has to hold whatever the server claims — a dev-served
// extension never receives a build secret.
//
// Driven through a stubbed http.Client rather than a real server, so the
// request sequence itself is observable: it is the contract with dev-server.mjs,
// and the two are only kept honest by being asserted somewhere.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extensions/extension_dev_client.dart';
import 'package:ham2k_logger/services/extensions/extension_secrets.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Records what the client asked the service to do, and boots nothing: the
/// runtime is exercised in packages/halo_extension_host, and what matters here
/// is which bundles the client hands over.
class _SpyExtensionService extends ExtensionService {
  final List<Map<String, ({String source, ExtensionInfo info})>> devBundleSets = [];
  final List<({String key, String source, ExtensionInfo info})> applied = [];

  @override
  Future<void> setDevBundles(Map<String, ({String source, ExtensionInfo info})> bundles) async {
    devBundleSets.add({...bundles});
  }

  @override
  Future<void> applyDevBundle(String key, {required String source, required ExtensionInfo info}) async {
    applied.add((key: key, source: source, info: info));
  }
}

/// Fails the first `setDevBundles` and succeeds afterwards — the shape of a
/// runtime restart that throws once.
class _FailingOnceExtensionService extends _SpyExtensionService {
  bool _failed = false;

  @override
  Future<void> setDevBundles(Map<String, ({String source, ExtensionInfo info})> bundles) async {
    if (!_failed) {
      _failed = true;
      throw StateError('runtime restart failed');
    }
    await super.setDevBundles(bundles);
  }
}

void main() {
  /// A stub dev server. [onRequest] lets a test override any single response.
  ({List<Uri> requested, MockClient client}) devServer({
    int protocol = 1,
    String server = 'halo-ext-dev',
    List<Map<String, dynamic>> extensions = const [
      {
        'key': 'pota',
        'file': 'pota.js',
        'core': false,
        'name': 'Parks on the Air',
        'domains': ['api.pota.app'],
      },
    ],
    String bundleSource = '/* pota bundle */',
  }) {
    final requested = <Uri>[];
    return (
      requested: requested,
      client: MockClient((request) async {
        requested.add(request.url);
        final path = request.url.path;
        if (path.endsWith('/ping')) {
          return http.Response(
            jsonEncode({
              'server': server,
              'protocol': protocol,
              'extensions': ['pota'],
            }),
            200,
          );
        }
        if (path.endsWith('/index.json')) {
          return http.Response(jsonEncode({'extensions': extensions}), 200);
        }
        if (path.endsWith('.js')) return http.Response(bundleSource, 200);
        if (path.endsWith('/events')) return http.Response('', 200); // no stream in these tests
        return http.Response('not found', 404);
      }),
    );
  }

  test('connecting takes the dev server\'s extensions over the app\'s own', () async {
    final stub = devServer();
    final service = _SpyExtensionService();
    final client = ExtensionDevClient(extensions: service, httpClient: stub.client);
    addTearDown(client.dispose);

    await client.connect('http://192.168.1.20:8787');

    expect(client.state, DevServerState.connected, reason: client.lastError);
    expect(client.servedKeys, ['pota']);
    expect(service.devBundleSets, hasLength(1));
    final handed = service.devBundleSets.single['pota']!;
    expect(handed.source, '/* pota bundle */');
    expect(handed.info.domains, ['api.pota.app'], reason: 'the manifest travels with the bundle, so the fetch allowlist follows the code');
  });

  test('a dev-served extension is marked as such, which is what withholds build secrets', () async {
    final stub = devServer();
    final service = _SpyExtensionService();
    final client = ExtensionDevClient(extensions: service, httpClient: stub.client);
    addTearDown(client.dispose);

    await client.connect('192.168.1.20:8787');

    // HALO-425: secret visibility follows PROVENANCE, not the key. This flag is
    // the whole of that provenance — an extension calling itself 'sota' off a
    // dev server must not inherit SOTA_*, and ExtensionService reads exactly
    // this to decide. A dev bundle arriving unflagged would silently hand a
    // credential to whatever the operator pointed the app at.
    expect(service.devBundleSets.single['pota']!.info.source, ExtensionSource.dev);
  });

  test('the request sequence is ping, index, then each bundle', () async {
    final stub = devServer();
    final service = _SpyExtensionService();
    final client = ExtensionDevClient(extensions: service, httpClient: stub.client);
    addTearDown(client.dispose);

    await client.connect('http://host:8787');

    // Identity before content: the app must know it is talking to a dev server
    // (and to a protocol it speaks) before it fetches code it will execute.
    final paths = [for (final uri in stub.requested) uri.path];
    expect(paths.take(3).toList(), ['/ping', '/index.json', '/pota.js']);
  });

  group('what it refuses', () {
    Future<ExtensionDevClient> attempt(MockClient client, [String url = 'http://host:8787']) async {
      final dev = ExtensionDevClient(extensions: _SpyExtensionService(), httpClient: client);
      addTearDown(dev.dispose);
      await dev.connect(url);
      return dev;
    }

    test('something that is not a dev server', () async {
      // The likeliest wrong address is a real web server on the same LAN,
      // which answers 200 with something that is not this. Executing whatever
      // it served would be the worst possible reading of that.
      final client = await attempt(MockClient((_) async => http.Response('<html>hello</html>', 200)));
      expect(client.state, DevServerState.failed);
      expect(client.lastError, isNotNull);
    });

    test('a server speaking a different protocol', () async {
      final client = await attempt(devServer(protocol: 99).client);
      expect(client.state, DevServerState.failed);
      // Both numbers named: whichever side is behind, the person reading this
      // is the one who can update it.
      expect(client.lastError, allOf(contains('99'), contains('1')));
    });

    test('an unreachable host', () async {
      final client = await attempt(MockClient((_) async => throw http.ClientException('connection refused')));
      expect(client.state, DevServerState.failed);
      expect(client.lastError, contains('connection refused'));
    });

    test('an empty address', () async {
      final client = await attempt(devServer().client, '   ');
      expect(client.state, DevServerState.failed);
    });
  });

  group('addresses people actually type', () {
    for (final input in ['192.168.1.20:8787', 'http://192.168.1.20:8787', 'http://192.168.1.20:8787/']) {
      test('"$input" resolves to the same endpoints', () async {
        final stub = devServer();
        final client = ExtensionDevClient(extensions: _SpyExtensionService(), httpClient: stub.client);
        addTearDown(client.dispose);

        await client.connect(input);

        expect(client.state, DevServerState.connected, reason: client.lastError);
        // The trailing slash is the trap: `Uri.resolve` against a path-less
        // base drops the last segment, so a bare host would request `/ping`
        // from one form and something else from another.
        expect(stub.requested.first.path, '/ping');
        expect(stub.requested.first.port, 8787);
      });
    }
  });

  test('disconnecting hands back an empty set, restoring the app\'s own extensions', () async {
    final stub = devServer();
    final service = _SpyExtensionService();
    final client = ExtensionDevClient(extensions: service, httpClient: stub.client);
    addTearDown(client.dispose);

    await client.connect('http://host:8787');
    await client.disconnect();

    expect(client.state, DevServerState.disconnected);
    expect(client.servedKeys, isEmpty);
    expect(service.devBundleSets.last, isEmpty, reason: 'an empty set is what returns the app to its built-in extensions');
  });

  group('canHotSwapDevBundle — when a reload needs a full restart', () {
    test('a key already served by the dev server swaps in place', () {
      expect(canHotSwapDevBundle(runtimeAlive: true, alreadyLoaded: true, alreadyDevServed: true, capabilitiesUnchanged: true), isTrue);
    });

    test('a key currently loaded FROM ASSETS restarts instead', () {
      // The security case, and it is reachable without anything exotic: an
      // extension that fails its first build is left out of the dev server's
      // index, so the app loads that key from its own assets — and the host
      // resolved that slot's build secrets at start and does not re-resolve
      // them on reload. Swapping dev code in there would hand real credentials
      // to code fetched over plain HTTP (HALO-425). Restarting re-resolves
      // them against the dev provenance, which is what makes them absent.
      expect(canHotSwapDevBundle(runtimeAlive: true, alreadyLoaded: true, alreadyDevServed: false, capabilitiesUnchanged: true), isFalse);
    });

    test('a key the runtime has never loaded restarts', () {
      // Its very existence changes what the app offers — an activity in
      // Operation Setup, a settings panel — and only a boot re-reads that.
      expect(canHotSwapDevBundle(runtimeAlive: true, alreadyLoaded: false, alreadyDevServed: true, capabilitiesUnchanged: true), isFalse);
    });

    test('a changed start-time capability restarts', () {
      // `domains` travels with the bundle, but requiresLocation and
      // allowUserAgentOverride are allowlists the host builds at start.
      expect(canHotSwapDevBundle(runtimeAlive: true, alreadyLoaded: true, alreadyDevServed: true, capabilitiesUnchanged: false), isFalse);
    });

    test('a dead runtime restarts', () {
      expect(canHotSwapDevBundle(runtimeAlive: false, alreadyLoaded: true, alreadyDevServed: true, capabilitiesUnchanged: true), isFalse);
    });

    test('a changed webSockets list counts as a changed start-time capability', () {
      // Unlike `domains`, the socket allowlist does not travel with a reload:
      // swapped in place, the host would go on enforcing the list the runtime
      // started with, refusing a host the author just added.
      const before = ExtensionInfo(key: 'feed', file: 'feed.js', core: false, name: 'Feed', webSockets: ['a.example.com']);
      const after = ExtensionInfo(key: 'feed', file: 'feed.js', core: false, name: 'Feed', webSockets: ['a.example.com', 'b.example.com']);
      expect(before.sameStartTimeCapabilities(after), isFalse);
      expect(before.sameStartTimeCapabilities(before), isTrue);
    });
  });

  group('visibleSecretsFor — provenance decides, not the key (HALO-425)', () {
    const secrets = {'SOTA_OAUTH_CLIENT_ID_PROD': 'real-client-id', 'POTA_API_KEY': 'real-key'};

    test('an extension baked into the app reads the secrets its name prefixes', () {
      const shipped = ExtensionInfo(key: 'sota', file: 'sota.js', core: false, name: 'SOTA');

      expect(visibleSecretsFor(shipped, secrets), {'SOTA_OAUTH_CLIENT_ID_PROD': 'real-client-id'});
    });

    test('a dev-served extension claiming that same key reads NOTHING', () {
      const impostor = ExtensionInfo(key: 'sota', file: 'sota.js', core: false, name: 'SOTA', source: ExtensionSource.dev);

      // The whole point of the rule. Without it, pointing the app at any dev
      // server on the network — yours, or one you mistyped your way onto —
      // hands over every credential whose name its extensions' keys prefix,
      // and nothing about the app's behaviour would show that it happened.
      expect(visibleSecretsFor(impostor, secrets), isEmpty);
    });

    test('an INSTALLED extension claiming that key reads nothing either', () {
      const sideloaded = ExtensionInfo(key: 'sota', file: 'sota.js', core: false, name: 'SOTA', source: ExtensionSource.installed);

      // The same rule, and it has to reach the second non-shipped source or
      // HALO-425 holds only for the dev loop: a .h2kext is a file from anyone,
      // and a key is a claim, not a credential (HALO-422).
      expect(visibleSecretsFor(sideloaded, secrets), isEmpty);
    });

    test('only what the app shipped may see a secret', () {
      // Stated as the rule rather than case by case, so a fourth source added
      // later has to opt IN rather than inherit access by forgetting to opt
      // out.
      expect(ExtensionSource.asset.maySeeBuildSecrets, isTrue);
      expect(ExtensionSource.dev.maySeeBuildSecrets, isFalse);
      expect(ExtensionSource.installed.maySeeBuildSecrets, isFalse);
    });

    test('an empty value is withheld like an absent one', () {
      const shipped = ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'POTA');

      // A build without the value configured must be indistinguishable from a
      // build that never had it, so the extension takes its degrade path
      // rather than sending an empty key to somebody's API.
      expect(visibleSecretsFor(shipped, const {'POTA_API_KEY': ''}), isEmpty);
    });

    test('the catalog\'s copy of a built-in reads nothing either', () {
      // The reserved prefix is what lets a bundle CLAIM a `ham2k-` key at the
      // store's door; it grants nothing here. An opening used to sit on it so
      // a twin could read what its built-in namesake did — and every value it
      // carried has since moved into the extension as a constant, because the
      // catalog serves these bundles to anyone and a `.h2kext` is a zip.
      // Reinstating it silently is the regression this catches.
      const preloaded = ExtensionInfo(key: 'ham2k-sota', file: 'index.js', core: false, name: 'SOTA', source: ExtensionSource.installed);
      expect(visibleSecretsFor(preloaded, const {'SOTA_OAUTH_CLIENT_ID_PROD': 'real-client-id'}), isEmpty);
    });
  });

  test('a failed connect stops running the previous server\'s extensions', () async {
    final service = _SpyExtensionService();
    final good = devServer();
    final client = ExtensionDevClient(extensions: service, httpClient: good.client);
    addTearDown(client.dispose);
    await client.connect('http://host:8787');
    expect(service.devBundleSets.last, isNotEmpty);

    // Retype the address wrong and reconnect. The pane will say "not
    // connected"; the app must not still be executing the previous server's
    // bundles behind that, with no server anywhere to reload them.
    final broken = ExtensionDevClient(extensions: service, httpClient: MockClient((_) async => throw http.ClientException('no route')));
    addTearDown(broken.dispose);
    await broken.connect('http://elsewhere:8787');

    expect(broken.state, DevServerState.failed);
    expect(service.devBundleSets.last, isEmpty);
  });

  test('a failed operation does not poison every later connect', () async {
    final service = _FailingOnceExtensionService();
    final stub = devServer();
    final client = ExtensionDevClient(extensions: service, httpClient: stub.client);
    addTearDown(client.dispose);

    // The queue chains each call onto the last. Chained plainly, one error
    // future would sit at the head of it and every connect and disconnect for
    // the rest of the session would propagate that error without ever running.
    await client.disconnect();
    await client.connect('http://host:8787');

    expect(client.state, DevServerState.connected, reason: client.lastError);
  });

  test('the build-error backlog arrives with the connection', () async {
    // An extension failing its FIRST build is absent from the server's index,
    // so the app runs the version it shipped with. Nothing else would say so —
    // the author would just see their saves having no effect.
    final service = _SpyExtensionService();
    final client = ExtensionDevClient(extensions: service, httpClient: devServer().client);
    addTearDown(client.dispose);
    await client.connect('http://host:8787');

    client.debugHandleEventLine(
      'data: ${jsonEncode({
        'type': 'hello',
        'protocol': 1,
        'buildErrors': {'sota': 'sota/src/index.ts:12: Unexpected token'},
      })}',
    );

    expect(client.buildErrors['sota'], contains('Unexpected token'));
  });

  group('mergeDevExtensions', () {
    const asset = ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'Parks on the Air');
    const other = ExtensionInfo(key: 'sota', file: 'sota.js', core: false, name: 'Summits on the Air');

    test('a dev extension replaces the shipped one of the same key', () {
      const dev = ExtensionInfo(key: 'pota', file: 'pota.js', core: false, name: 'POTA (dev)', source: ExtensionSource.dev);

      final merged = mergeDevExtensions([asset, other], [dev]);

      // Replacing rather than appending is what lets an author iterate on an
      // extension that already ships. Appending would leave two 'pota' entries
      // and the runtime would refuse the second as a duplicate key — the dev
      // one would never load, and nothing would say why.
      expect(merged.map((i) => i.name), ['POTA (dev)', 'Summits on the Air']);
    });

    test('a dev extension with a new key is appended', () {
      const fresh = ExtensionInfo(key: 'newthing', file: 'newthing.js', core: false, name: 'New Thing', source: ExtensionSource.dev);

      expect(mergeDevExtensions([asset], [fresh]).map((i) => i.key), ['pota', 'newthing']);
    });

    test('asset order survives, so the panel does not reshuffle', () {
      const dev = ExtensionInfo(key: 'sota', file: 'sota.js', core: false, name: 'SOTA (dev)', source: ExtensionSource.dev);

      expect(mergeDevExtensions([asset, other], [dev]).map((i) => i.key), ['pota', 'sota']);
    });

    test('no dev extensions leaves the list exactly as it was', () {
      expect(mergeDevExtensions([asset, other], const []), [asset, other]);
    });
  });
}
