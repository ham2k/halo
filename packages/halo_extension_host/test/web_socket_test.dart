// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `host.webSocket` — a live connection an extension holds open to a host its
// manifest's `webSockets` declares.
//
// Every test here talks to a REAL server on loopback, through the host's real
// path: the allowlist, the scheme rule, the kernel's identity stamp and the
// bridge that carries frames back into the sandbox outside any hook call.
// Loopback is what makes that possible without a certificate — plain `ws://`
// to a local-network address is exactly the case the rule admits.
//
// The extension below drives the kernel's socket surface directly, the way
// the SDK's `host.webSocket` does, so the refusals are the host's and not the
// SDK's (sdk/src/webSocket.test.ts covers the wrapper).

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import 'support/bundles.dart';

/// An extension that opens named sockets and records every event they get.
///
/// Wrapped in its own closure as a built bundle is: two of these sharing
/// top-level `var`s would share one `call`, and whichever activated last would
/// send every socket request under its own identity.
String _socketExtension(String key) =>
    '''
(function () {
var call = null
var sockets = {}
var events = []
__polo.defineExtension({
  key: '$key',
  name: 'Sockets',
  version: '0.0.1',
  onActivation: function (api) {
    call = api.hostCall
    api.registerHook('bench', { key: '$key', hook: {
      open: async function (args) {
        var id = __polo.registerSocket(function (e) {
          var copy = { socket: args.name }
          for (var k in e) copy[k] = e[k]
          events.push(copy)
        })
        sockets[args.name] = id
        try {
          var opening = call('webSocketOpen', { socketId: id, url: args.url })
          if (args.closeAtOnce) await call('webSocketClose', { socketId: id })
          await opening
          return 'accepted'
        } catch (e) {
          return 'refused: ' + e.message
        }
      },
      send: async function (args) {
        var id = args.socketId !== undefined ? args.socketId : sockets[args.name]
        try {
          await call('webSocketSend', args.binary !== undefined ? { socketId: id, binary: args.binary } : { socketId: id, data: args.data })
          return 'sent'
        } catch (e) {
          return 'refused: ' + e.message
        }
      },
      close: async function (args) { await call('webSocketClose', { socketId: sockets[args.name], code: 1000 }) },
      socketId: async function (args) { return sockets[args.name] },
      events: async function () { return events },
    }})
  },
})
})()
''';

/// An extension that opens a socket under an id it did not register.
const _intruderExtension = '''
(function () {
__polo.defineExtension({
  key: 'intruder',
  name: 'Intruder',
  version: '0.0.1',
  onActivation: function (api) {
    api.registerHook('bench', { key: 'intruder', hook: {
      claim: async function (args) {
        try {
          await api.hostCall('webSocketOpen', { socketId: args.socketId, url: args.url })
          return 'accepted'
        } catch (e) {
          return 'refused: ' + e.message
        }
      },
    }})
  },
})
})()
''';

/// A loopback server that records what reaches it and echoes it back, text
/// as text and bytes as bytes.
class _Server {
  final HttpServer _http;
  final connections = <WebSocket>[];
  final userAgents = <String?>[];
  final received = <Object?>[];
  final closed = <int?>[];

  _Server(this._http) {
    _http.listen((request) async {
      userAgents.add(request.headers.value('user-agent'));
      // Holds the handshake open, so a test can act while the client is
      // still connecting.
      if (request.uri.path == '/slow') await Future<void>.delayed(const Duration(milliseconds: 200));
      final socket = await WebSocketTransformer.upgrade(request);
      connections.add(socket);
      socket.listen(
        (data) {
          received.add(data);
          if (data == 'big please') {
            socket.add('x' * (maxWebSocketFrameSize + 1));
          } else if (data is String) {
            socket.add('echo:$data');
          } else {
            socket.add(data);
          }
        },
        onDone: () {
          closed.add(socket.closeCode);
          // Completes the closing handshake: without the echo the client sees
          // the connection drop, not close.
          socket.close(socket.closeCode);
        },
      );
    });
  }

  static Future<_Server> start() async => _Server(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  String get url => 'ws://127.0.0.1:${_http.port}/feed';

  Future<void> stop() => _http.close(force: true);
}

void main() {
  requireBundles();

  late _Server server;
  setUp(() async {
    server = await _Server.start();
    addTearDown(server.stop);
  });

  Future<ExtensionHost> hostWith(
    List<ExtensionBundle> extensions, {
    Map<String, List<String>> webSockets = const {},
    Map<String, List<String>> domains = const {},
    String? userAgent,
  }) async {
    final host = await ExtensionHost.start(
      kernelSource: bundleSource('kernel'),
      extensions: extensions,
      fetchAllowlists: domains,
      webSocketAllowlists: webSockets,
      userAgent: userAgent,
      useIsolate: false,
    );
    addTearDown(host.dispose);
    await host.activated;
    return host;
  }

  Future<Object?> call(ExtensionHost host, String key, String method, [Map<String, Object?> args = const {}]) =>
      host.invokeHook('bench', key: key, method: method, args: args);

  Future<List<Map>> events(ExtensionHost host, String key) async => ((await call(host, key, 'events')) as List).cast<Map>();

  /// Polls until [condition] holds. Socket events arrive on the network's
  /// schedule, not the test's, so a fixed wait would either flake or waste time.
  Future<void> until(FutureOr<bool> Function() condition, {String reason = 'condition'}) async {
    final waited = Stopwatch()..start();
    while (!await condition()) {
      if (waited.elapsed > const Duration(seconds: 5)) fail('timed out waiting for $reason');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<bool> sawEvent(ExtensionHost host, String key, String type) async => (await events(host, key)).any((e) => e['type'] == type);

  test('a declared local socket opens, carries frames both ways, and closes', () async {
    final host = await hostWith(
      [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
      webSockets: {
        'socks': ['127.0.0.1'],
      },
    );

    expect(await call(host, 'socks', 'open', {'name': 'a', 'url': server.url}), 'accepted');
    await until(() => sawEvent(host, 'socks', 'open'), reason: 'open');

    expect(await call(host, 'socks', 'send', {'name': 'a', 'data': 'hello'}), 'sent');
    // The echo reaches the extension's listener with no hook call in flight to
    // carry it: that is the bridge this feature adds, and the thing a
    // request/response-only host could not do.
    await until(() async => (await events(host, 'socks')).any((e) => e['type'] == 'message' && e['data'] == 'echo:hello'), reason: 'echo');
    expect(server.received, ['hello']);

    await call(host, 'socks', 'close', {'name': 'a'});
    await until(() => sawEvent(host, 'socks', 'close'), reason: 'close');
    final close = (await events(host, 'socks')).last;
    expect(close['type'], 'close', reason: 'close is always the last event');
    expect(close['code'], 1000);
    expect(close['wasClean'], true);
  });

  test('a host the manifest does not list is refused before any connection', () async {
    final host = await hostWith(
      [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
      webSockets: {
        'socks': ['stream.example.com'],
      },
    );

    final answer = await call(host, 'socks', 'open', {'name': 'a', 'url': server.url});

    expect(answer, contains("'127.0.0.1' is not in extension 'socks's declared webSockets"));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.connections, isEmpty, reason: 'a refusal that still connects has refused nothing');
  });

  test('declaring a host under domains grants fetch, not a socket', () async {
    // The mutation this catches: the socket check reading `fetchAllowlists`.
    // Consent to requests is not consent to a standing connection.
    final host = await hostWith(
      [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
      domains: {
        'socks': ['127.0.0.1'],
      },
    );

    expect(await call(host, 'socks', 'open', {'name': 'a', 'url': server.url}), startsWith('refused'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.connections, isEmpty);
  });

  test('plain ws:// is refused to a host off the local network, even a declared one', () async {
    final host = await hostWith(
      [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
      webSockets: {
        'socks': ['stream.example.com'],
      },
    );

    final answer = await call(host, 'socks', 'open', {'name': 'a', 'url': 'ws://stream.example.com/feed'});

    expect(answer, contains('plain ws:// is only allowed to a local-network address'));
  });

  test('one extension cannot send on a socket another opened', () async {
    // Socket ids come from one shared kernel counter, so they are trivially
    // guessable. Only the kernel-stamped caller identity keeps them apart.
    final host = await hostWith(
      [ExtensionBundle(key: 'owner', source: _socketExtension('owner')), ExtensionBundle(key: 'intruder', source: _socketExtension('intruder'))],
      webSockets: {
        'owner': ['127.0.0.1'],
        'intruder': ['127.0.0.1'],
      },
    );
    await call(host, 'owner', 'open', {'name': 'a', 'url': server.url});
    await until(() => sawEvent(host, 'owner', 'open'), reason: 'open');
    final ownersId = await call(host, 'owner', 'socketId', {'name': 'a'});

    final answer = await call(host, 'intruder', 'send', {'socketId': ownersId, 'data': 'forged'});

    expect(answer, contains('is not open'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.received, isEmpty);
  });

  test('an extension may hold only so many sockets at once', () async {
    final host = await hostWith(
      [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
      webSockets: {
        'socks': ['127.0.0.1'],
      },
    );
    for (var i = 0; i < maxWebSocketsPerExtension; i++) {
      expect(await call(host, 'socks', 'open', {'name': 's$i', 'url': server.url}), 'accepted');
    }

    expect(await call(host, 'socks', 'open', {'name': 'extra', 'url': server.url}), contains('already has $maxWebSocketsPerExtension sockets open'));
  });

  test('binary frames cross both ways as bytes', () async {
    final host = await hostWith(
      [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
      webSockets: {
        'socks': ['127.0.0.1'],
      },
    );
    await call(host, 'socks', 'open', {'name': 'a', 'url': server.url});
    await until(() => sawEvent(host, 'socks', 'open'), reason: 'open');

    expect(await call(host, 'socks', 'send', {'name': 'a', 'binary': 'AQID'}), 'sent');

    await until(() => sawEvent(host, 'socks', 'message'), reason: 'the echo');
    // The server must see BYTES: a host that sent the base64 text instead
    // would pass a round trip through an echo server just as well.
    expect(server.received.single, [1, 2, 3]);
    expect((await events(host, 'socks')).firstWhere((e) => e['type'] == 'message')['binary'], 'AQID');
  });

  test('an oversized frame closes the socket with 1009 rather than arriving cut short', () async {
    final host = await hostWith(
      [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
      webSockets: {
        'socks': ['127.0.0.1'],
      },
    );
    await call(host, 'socks', 'open', {'name': 'a', 'url': server.url});
    await until(() => sawEvent(host, 'socks', 'open'), reason: 'open');

    await call(host, 'socks', 'send', {'name': 'a', 'data': 'big please'});

    await until(() => sawEvent(host, 'socks', 'close'), reason: 'close');
    final seen = await events(host, 'socks');
    expect(seen.where((e) => e['type'] == 'message'), isEmpty);
    expect(seen.last['code'], 1009);
  });

  test('a socket closed while still connecting never reports open', () async {
    // The handshake can complete after the extension has already let go; an
    // `open` then would put a closing socket back to open.
    final host = await hostWith(
      [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
      webSockets: {
        'socks': ['127.0.0.1'],
      },
    );

    await call(host, 'socks', 'open', {'name': 'a', 'url': server.url.replaceFirst('/feed', '/slow'), 'closeAtOnce': true});

    await until(() => sawEvent(host, 'socks', 'close'), reason: 'close');
    expect((await events(host, 'socks')).map((e) => e['type']), isNot(contains('open')));
  });

  test('the handshake carries the canonical User-Agent', () async {
    // docs/design/network.md: a call that can carry the header must. A
    // browser cannot set it, which socket_connect.dart accounts for; every
    // native build can.
    final host = await hostWith(
      [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
      webSockets: {
        'socks': ['127.0.0.1'],
      },
      userAgent: 'Ham2K-Test/1.0',
    );

    await call(host, 'socks', 'open', {'name': 'a', 'url': server.url});

    await until(() => server.userAgents.isNotEmpty, reason: 'the handshake');
    expect(server.userAgents, ['Ham2K-Test/1.0']);
  });

  group('the local entry', () {
    test('admits a local address the manifest never names', () async {
      final host = await hostWith(
        [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
        webSockets: {
          'socks': [localNetworkEntry],
        },
      );

      expect(await call(host, 'socks', 'open', {'name': 'a', 'url': server.url}), 'accepted');
      await until(() => sawEvent(host, 'socks', 'open'), reason: 'open');
    });

    test('admits nothing past the local network, even over wss://', () async {
      final host = await hostWith(
        [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
        webSockets: {
          'socks': [localNetworkEntry],
        },
      );

      expect(await call(host, 'socks', 'open', {'name': 'a', 'url': 'wss://stream.example.com/feed'}), contains('is not in extension'));
    });
  });

  test('reloading an extension closes the sockets its old code held', () async {
    final host = await hostWith(
      [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
      webSockets: {
        'socks': ['127.0.0.1'],
      },
    );
    await call(host, 'socks', 'open', {'name': 'a', 'url': server.url});
    await until(() => sawEvent(host, 'socks', 'open'), reason: 'open');

    await host.reloadBundle(ExtensionBundle(key: 'socks', source: _socketExtension('socks')));

    // Nothing in the new code can reach the old socket, so left open it would
    // hold a connection, and a place against the cap, for the whole session.
    await until(() => server.closed.isNotEmpty, reason: 'the server to see the close');
    expect(server.closed, [1000]);
  });

  test('reloading a bundle leaves alone a separate bundle named after it', () async {
    // `foo-bar` is its own bundle, not one `foo` defined. The kernel knows
    // that; a host matching owners by key prefix would not, and would close
    // foo-bar's socket without its listener ever hearing.
    final host = await hostWith(
      [ExtensionBundle(key: 'foo', source: _socketExtension('foo')), ExtensionBundle(key: 'foo-bar', source: _socketExtension('foo-bar'))],
      webSockets: {
        'foo': ['127.0.0.1'],
        'foo-bar': ['127.0.0.1'],
      },
    );
    await call(host, 'foo', 'open', {'name': 'a', 'url': server.url});
    await call(host, 'foo-bar', 'open', {'name': 'a', 'url': server.url});
    await until(() async => await sawEvent(host, 'foo', 'open') && await sawEvent(host, 'foo-bar', 'open'), reason: 'both open');

    await host.reloadBundle(ExtensionBundle(key: 'foo', source: _socketExtension('foo')));
    await until(() => server.closed.isNotEmpty, reason: "foo's socket to close");

    expect(server.closed, hasLength(1));
    expect(await call(host, 'foo-bar', 'send', {'name': 'a', 'data': 'still here'}), 'sent');
  });

  test('another extension naming a socket id does not take over its listener', () async {
    // The intruder's open is refused by the host (the id is in use), but the
    // kernel must not have recorded it as the owner first — or reloading the
    // intruder would drop the real owner's listener and close its socket.
    final host = await hostWith(
      [ExtensionBundle(key: 'owner', source: _socketExtension('owner')), const ExtensionBundle(key: 'intruder', source: _intruderExtension)],
      webSockets: {
        'owner': ['127.0.0.1'],
        'intruder': ['127.0.0.1'],
      },
    );
    await call(host, 'owner', 'open', {'name': 'a', 'url': server.url});
    await until(() => sawEvent(host, 'owner', 'open'), reason: 'open');
    final ownersId = await call(host, 'owner', 'socketId', {'name': 'a'});
    expect(await call(host, 'intruder', 'claim', {'socketId': ownersId, 'url': server.url}), contains('already in use'));

    await host.reloadBundle(const ExtensionBundle(key: 'intruder', source: _intruderExtension));

    expect(await call(host, 'owner', 'send', {'name': 'a', 'data': 'mine'}), 'sent');
    await until(() async => (await events(host, 'owner')).any((e) => e['data'] == 'echo:mine'), reason: 'the echo');
  });

  test('an id not yet handed out cannot be claimed ahead of its owner', () async {
    // Ids come from one counter, so the next few are predictable. Opening one
    // early would make the real owner's open fail as "already open", and the
    // squatter's socket would have no kernel owner, so its own reload would
    // never close it.
    final host = await hostWith(
      [ExtensionBundle(key: 'owner', source: _socketExtension('owner')), const ExtensionBundle(key: 'intruder', source: _intruderExtension)],
      webSockets: {
        'owner': ['127.0.0.1'],
        'intruder': ['127.0.0.1'],
      },
    );

    expect(await call(host, 'intruder', 'claim', {'socketId': 1, 'url': server.url}), contains('is not reserved'));

    expect(await call(host, 'owner', 'open', {'name': 'a', 'url': server.url}), 'accepted');
    await until(() => sawEvent(host, 'owner', 'open'), reason: 'open');
    expect(server.connections, hasLength(1), reason: "only the owner's socket may have connected");
  });

  test('disposing the host closes every socket', () async {
    final host = await hostWith(
      [ExtensionBundle(key: 'socks', source: _socketExtension('socks'))],
      webSockets: {
        'socks': ['127.0.0.1'],
      },
    );
    await call(host, 'socks', 'open', {'name': 'a', 'url': server.url});
    await until(() => sawEvent(host, 'socks', 'open'), reason: 'open');

    await host.dispose();

    await until(() => server.closed.isNotEmpty, reason: 'the server to see the close');
  });

  group('isLocalNetworkHost', () {
    test('admits loopback, private ranges and local names', () {
      for (final host in [
        'localhost',
        'shack.local',
        '127.0.0.1',
        '10.1.2.3',
        '172.16.0.1',
        '172.31.255.255',
        '192.168.1.20',
        '169.254.1.1',
        '::1',
        'fd00::1',
        'fe80::1',
      ]) {
        expect(isLocalNetworkHost(host), isTrue, reason: host);
      }
    });

    test('refuses public addresses and names, including near misses', () {
      // 172.15 and 172.32 sit either side of RFC 1918's /12; a prefix test on
      // "172." would admit both. `local.example.com` ends in neither suffix.
      for (final host in ['example.com', 'local.example.com', '8.8.8.8', '172.15.0.1', '172.32.0.1', '192.169.1.1', '2001:db8::1', '::']) {
        expect(isLocalNetworkHost(host), isFalse, reason: host);
      }
    });
  });
}
