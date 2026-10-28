// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The guarded connection factory: a name is resolved by the factory, every
// answer is judged, and the socket goes to an address that was judged — the
// spelling check in fetch_policy never sees what a name resolves to.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/src/fetch_client_io.dart';

void main() {
  InternetAddress ip(String address) => InternetAddress(address);

  // A loopback server, so a "connection" the fake opener returns is a real socket.
  late ServerSocket server;
  final connected = <(InternetAddress, int, bool)>[];
  setUp(() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    connected.clear();
  });
  tearDown(() => server.close());

  Future<Socket> connect(InternetAddress address, int port, {required bool secure}) {
    connected.add((address, port, secure));
    return Socket.connect(InternetAddress.loopbackIPv4, server.port);
  }

  /// The socket a guarded connection ends in, or the error it ends in.
  Future<Socket> socketOf(Future<ConnectionTask<Socket>> task) async => (await task).socket;

  Future<Socket> open(String url, List<String> answers) =>
      socketOf(guardedConnectionWith(Uri.parse(url), lookup: (_) async => [for (final a in answers) ip(a)], connect: connect));

  Matcher refusedAsLocal() => throwsA(isA<SocketException>().having((e) => e.message, 'message', contains('resolves to the local network')));
  Matcher cancelled() => throwsA(isA<SocketException>().having((e) => e.message, 'message', 'connection cancelled'));

  test('a name resolving to a local address is refused, whichever of its answers that is', () async {
    for (final answers in [
      ['10.0.0.1'],
      ['93.184.216.34', '10.0.0.1'],
      ['::ffff:127.0.0.1'],
      ['::1'],
      ['0.0.0.0'],
      ['fe80::1%en0'],
      ['100.100.1.1'],
      // Multicast is nothing a fetch reaches; the platform's own reading of the
      // address refuses it where the spelling rule has no range for it.
      ['224.0.0.1'],
      ['ff02::1'],
    ]) {
      await expectLater(open('https://api.example/', answers), refusedAsLocal(), reason: '$answers');
    }
    expect(connected, isEmpty);
  });

  test('a public answer is connected to by the address that was judged, secured for https', () async {
    (await open('https://api.example/path', ['93.184.216.34'])).destroy();
    expect(connected, [(ip('93.184.216.34'), 443, true)]);
  });

  test('a literal is judged as a literal, and a form the spelling check cannot read is looked up and judged', () async {
    Future<List<InternetAddress>> noLookup(String host) => throw StateError('looked up $host');
    await expectLater(socketOf(guardedConnectionWith(Uri.parse('https://127.0.0.1/'), lookup: noLookup, connect: connect)), refusedAsLocal());
    // `2130706433` is 127.0.0.1 to a resolver and nothing to tryParse.
    await expectLater(
      socketOf(guardedConnectionWith(Uri.parse('https://2130706433/'), lookup: (_) async => [ip('127.0.0.1')], connect: connect)),
      refusedAsLocal(),
    );
    final task = await guardedConnectionWith(Uri.parse('http://93.184.216.34:8080/'), lookup: noLookup, connect: connect);
    (await task.socket).destroy();
    expect(connected, [(ip('93.184.216.34'), 8080, false)]);
  });

  test('an address that does not answer does not hold the next one past the stagger', () async {
    // The first attempt never completes; without the stagger nothing would.
    Future<Socket> blackhole(InternetAddress address, int port, {required bool secure}) =>
        address.address == '2001:db8::1' ? Completer<Socket>().future : connect(address, port, secure: secure);
    final task = await guardedConnectionWith(
      Uri.parse('https://api.example/'),
      lookup: (_) async => [ip('2001:db8::1'), ip('93.184.216.34')],
      connect: blackhole,
      stagger: const Duration(milliseconds: 50),
    );
    (await task.socket).destroy();
    expect(connected.single.$1, ip('93.184.216.34'));
  });

  test('a refusal starts the next address at once, not at the stagger', () async {
    // A stagger the test would never outlive: only an immediate next attempt
    // lets this finish.
    var attempts = 0;
    Future<Socket> flaky(InternetAddress address, int port, {required bool secure}) {
      if (++attempts == 1) throw const SocketException('unreachable');
      return connect(address, port, secure: secure);
    }

    final task = await guardedConnectionWith(
      Uri.parse('https://api.example/'),
      lookup: (_) async => [ip('2001:db8::1'), ip('93.184.216.34')],
      connect: flaky,
      stagger: const Duration(hours: 1),
    );
    (await task.socket).destroy();
    expect(connected.single.$1, ip('93.184.216.34'));
  });

  test('every address failing surfaces the last failure', () async {
    Future<Socket> never(InternetAddress address, int port, {required bool secure}) => throw SocketException('no route to ${address.address}');
    final task = await guardedConnectionWith(Uri.parse('https://api.example/'), lookup: (_) async => [ip('2001:db8::1'), ip('93.184.216.34')], connect: never);
    await expectLater(task.socket, throwsA(isA<SocketException>().having((e) => e.message, 'message', 'no route to 93.184.216.34')));
  });

  test('a cancel landing while a connect is in flight closes the socket it would have returned', () async {
    final pending = Completer<Socket>();
    Future<Socket> slow(InternetAddress address, int port, {required bool secure}) => pending.future;
    final task = await guardedConnectionWith(Uri.parse('https://api.example/'), lookup: (_) async => [ip('93.184.216.34')], connect: slow);
    final accepted = server.first;
    task.cancel();
    pending.complete(await Socket.connect(InternetAddress.loopbackIPv4, server.port));
    await expectLater(task.socket, cancelled());
    // The server sees the client's side go away, which a leaked socket never does.
    await (await accepted).drain<void>().timeout(const Duration(seconds: 5));
  });

  test('a cancel landing while the resolver is out connects nothing', () async {
    final resolving = Completer<List<InternetAddress>>();
    final task = await guardedConnectionWith(Uri.parse('https://api.example/'), lookup: (_) => resolving.future, connect: connect);
    task.cancel();
    resolving.complete([ip('93.184.216.34')]);
    await expectLater(task.socket, cancelled());
    expect(connected, isEmpty);
  });

  test('through a proxy the connection goes to the proxy, plain, and the proxy is not judged', () async {
    final looked = <String>[];
    final task = await guardedConnectionWith(
      Uri.parse('https://api.example/'),
      proxyHost: 'proxy.example',
      proxyPort: 3128,
      lookup: (host) async {
        looked.add(host);
        return [ip('192.168.1.1')];
      },
      connect: connect,
    );
    (await task.socket).destroy();
    expect(looked, ['proxy.example'], reason: 'the proxy resolves the target; a LAN proxy is the operator\'s own');
    expect(connected, [(ip('192.168.1.1'), 3128, false)]);
  });
}
