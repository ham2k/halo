// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The TCP transport against a real loopback ServerSocket. This is the tier
// that catches what a fake transport can't: bytes actually crossing a
// socket, a peer disappearing, and writes to a dead socket — which drivers
// make from unguarded timers, so they must never throw.
//
// Cancellation is covered here only for the deterministic case (a token
// already cancelled). Cancelling a connect mid-flight has no reliable
// timing over loopback, so that path is tested at the service level in
// gato_service_test.dart, where the transport is a fake and the timing is
// controlled.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/gato/transport.dart';
import 'package:ham2k_logger/services/gato/transports/tcp_transport.dart';

void main() {
  late ServerSocket server;
  late Map<String, dynamic> target;
  final serverSockets = <Socket>[];

  setUp(() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(serverSockets.add);
    target = {'host': server.address.address, 'port': server.port};
  });

  tearDown(() async {
    for (final socket in serverSockets) {
      socket.destroy();
    }
    serverSockets.clear();
    await server.close();
  });

  /// The server end of the connection the client just made.
  Future<Socket> acceptedSocket() async {
    for (var i = 0; i < 100 && serverSockets.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(serverSockets, isNotEmpty, reason: 'the server never saw the connection');
    return serverSockets.last;
  }

  test('carries bytes in both directions', () async {
    final connection = await const TcpTransport().connect(target, cancel: CatCancelToken());
    addTearDown(connection.close);

    final received = <String>[];
    connection.data.listen((chunk) => received.add(utf8.decode(chunk)));

    final peer = await acceptedSocket();
    final fromClient = <String>[];
    peer.listen((chunk) => fromClient.add(utf8.decode(chunk)));

    connection.send(utf8.encode('C1|sub slice all\n'));
    peer.add(utf8.encode('S5AC2F980|slice 0 RF_frequency=14.074000 mode=USB\n'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(fromClient.join(), contains('sub slice all'));
    expect(received.join(), contains('RF_frequency=14.074000'));
  });

  test('the peer going away completes `closed`', () async {
    final connection = await const TcpTransport().connect(target, cancel: CatCancelToken());
    final peer = await acceptedSocket();

    var closed = false;
    unawaited(connection.closed.then((_) => closed = true));
    expect(closed, isFalse);

    peer.destroy();
    await connection.closed.timeout(const Duration(seconds: 2));
    expect(closed, isTrue);
  });

  test('close() completes `closed`, and writing afterwards is a no-op', () async {
    final connection = await const TcpTransport().connect(target, cancel: CatCancelToken());
    await acceptedSocket();

    await connection.close();
    await connection.closed.timeout(const Duration(seconds: 2));

    // Drivers write from timers they don't guard; a stale write must not
    // throw into a timer callback.
    expect(() => connection.send(utf8.encode('C2|ping\n')), returnsNormally);
  });

  test('an already-cancelled token is refused without opening anything', () async {
    final cancel = CatCancelToken()..cancel();
    await expectLater(
      const TcpTransport().connect(target, cancel: cancel),
      throwsA(isA<CatCancelledException>()),
    );
    expect(serverSockets, isEmpty);
  });

  test('a refused connection reports an error rather than hanging', () async {
    // Bind and immediately release a port, so nothing is listening on it.
    final vacant = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = vacant.port;
    await vacant.close();

    await expectLater(
      const TcpTransport().connect({'host': InternetAddress.loopbackIPv4.address, 'port': port},
          cancel: CatCancelToken()),
      throwsA(isA<SocketException>()),
    );
  });
}
