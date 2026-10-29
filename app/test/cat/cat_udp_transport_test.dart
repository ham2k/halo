// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The UDP transport PstRotator is reached over. UDP has no handshake, so
// nothing about the far end may end a connection: the silence watch is what
// says a node has stopped hearing, and it can only say so while the reply
// port is still listening.
//
// Imports the io implementation directly: the conditional export resolves
// to the web stub under the analyzer.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/udp_transport_io.dart';

/// A port with nothing on it, as far as a moment ago could tell.
Future<int> _freePort() async {
  final probe = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: false);
  final port = probe.port;
  probe.close();
  // The IO service releases a closed socket's port after `close` returns.
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return port;
}

void main() {
  const transport = UdpTransport(portConfigKey: 'udpPort', replyPortOffset: 1);

  // The SDK closes a datagram socket after any failed send — what a PC
  // asleep (no ARP answer) or a missing Local Network grant produces on
  // every poll. Closed for good, the node drops to "disconnected" with no
  // reason, and nothing reconnects a rotator.
  test('a send the OS refuses leaves the reply port listening', () async {
    final replyPort = await _freePort();
    // A broadcast address on a socket without SO_BROADCAST: refused at
    // `sendto`, on every platform.
    final connection = await transport.connect({'host': '255.255.255.255', 'port': 9, 'replyPort': replyPort}, cancel: CatCancelToken());
    final received = <String>[];
    final subscription = connection.data.listen((chunk) => received.add(ascii.decode(chunk)));
    var closed = false;
    unawaited(connection.closed.then((_) => closed = true));
    try {
      connection.send(ascii.encode('<PST>AZ?</PST>'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(closed, isFalse, reason: (connection as ExplainsClose).closeReason);

      // From an address other than the one dialled, too: a PC with two
      // interfaces on one network answers from whichever it routes by.
      final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      sender.send(ascii.encode('AZ:12.0\r'), InternetAddress.loopbackIPv4, replyPort);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      sender.close();
      expect(received, ['AZ:12.0\r']);
    } finally {
      await subscription.cancel();
      await connection.close();
    }
  });

  test('a reply port held a moment longer is waited for', () async {
    final holder = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: false);
    final replyPort = holder.port;
    Timer(const Duration(milliseconds: 150), holder.close);
    final connection = await transport.connect({'host': '127.0.0.1', 'port': 9, 'replyPort': replyPort}, cancel: CatCancelToken());
    await connection.close();
  });

  // A reply port that stays held is a reason the operator can act on, with
  // the OS's own code kept for the recording — not a network that "cannot
  // find" a host the transport never asked.
  test('a reply port held for good is said to be in use', () async {
    final holder = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: false);
    try {
      await expectLater(
        transport.connect({'host': '127.0.0.1', 'port': 9, 'replyPort': holder.port}, cancel: CatCancelToken()),
        throwsA(isA<UdpReplyPortTaken>().having((e) => e.port, 'port', holder.port).having((e) => e.osError, 'osError', isNotNull)),
      );
    } finally {
      holder.close();
    }
  });

  test('a bind the OS refuses for another reason stays the OS\'s own error', () async {
    // Port 1 needs privileges on Linux and Android; on macOS and Windows it
    // binds, which leaves nothing to assert there.
    if (!(Platform.isLinux || Platform.isAndroid)) return;
    await expectLater(transport.connect({'host': '127.0.0.1', 'port': 0, 'replyPort': 1}, cancel: CatCancelToken()), throwsA(isA<SocketException>()));
  });
}
