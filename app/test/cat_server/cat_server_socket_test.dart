// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_protocol.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_socket.dart';
import 'package:ham2k_logger/services/cat_server/hrd_server.dart';

import 'fake_cat_server_rig.dart';

void main() {
  late FakeCatServerRig rig;
  late CatServerListener listener;
  var clientChanges = 0;

  setUp(() async {
    rig = FakeCatServerRig();
    clientChanges = 0;
  });

  Future<CatServerListener> bind(CatServerProtocol protocol, {bool lan = false}) async {
    listener = await bindCatServer(protocol, rig, port: 0, lan: lan, onClientsChanged: () => clientChanges++);
    addTearDown(listener.close);
    return listener;
  }

  /// The first reply on [socket], as text.
  Future<String> firstReply(Stream<List<int>> replies) => replies.first.timeout(const Duration(seconds: 5)).then(utf8.decode);

  test('a local-only server answers on 127.0.0.1', () async {
    await bind(CatServerProtocol.rigctld);
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
    addTearDown(socket.destroy);
    socket.write('+f\n');
    expect(await firstReply(socket), 'get_freq:\nFrequency: 14074000\nRPRT 0\n');
  });

  test('a local-only server also answers on ::1, where "localhost" may resolve first', () async {
    await bind(CatServerProtocol.rigctld);
    final Socket socket;
    try {
      socket = await Socket.connect(InternetAddress.loopbackIPv6, listener.port);
    } on SocketException {
      markTestSkipped('no IPv6 loopback on this machine');
      return;
    }
    addTearDown(socket.destroy);
    socket.write('f\n');
    expect(await firstReply(socket), '14074000\n');
  });

  test('a network server answers on the loopback too — this computer is on the network', () async {
    await bind(CatServerProtocol.rigctld, lan: true);
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
    addTearDown(socket.destroy);
    socket.write('f\n');
    expect(await firstReply(socket), '14074000\n');
  });

  test('a port another program holds on ::1 fails the bind, rather than sharing localhost with it', () async {
    // The program being replaced still running is the usual case. Serving
    // 127.0.0.1 alone would say "listening" while every client that resolves
    // `localhost` to ::1 went on talking to the other program.
    final ServerSocket other;
    try {
      other = await ServerSocket.bind(InternetAddress.loopbackIPv6, 0, v6Only: true);
    } on SocketException {
      markTestSkipped('no IPv6 loopback on this machine');
      return;
    }
    addTearDown(other.close);
    await expectLater(bindCatServer(CatServerProtocol.rigctld, rig, port: other.port, lan: false), throwsA(isA<SocketException>()));
    // And the half it did bind is let go, so the operator's next try can have it.
    final v4 = await ServerSocket.bind(InternetAddress.loopbackIPv4, other.port);
    await v4.close();
  });

  test('a client that resets while being written to is a disconnect, not an app error', () async {
    // N3FJP pushes a report whenever the radio moves, so a write racing a
    // client that just went away is routine. The failed write lands on the
    // socket's `done`; unhandled, it escapes as an uncaught error.
    await bind(CatServerProtocol.n3fjp);
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
    await Future.doWhile(() => Future.delayed(const Duration(milliseconds: 5), () => listener.clientCount == 0));
    // SO_LINGER with a zero timeout: the close is a reset, not a goodbye.
    if (!Platform.isMacOS && !Platform.isLinux) {
      markTestSkipped('SO_LINGER layout differs here');
      return;
    }
    final linger = Uint8List(8)..buffer.asByteData().setInt32(0, 1, Endian.host);
    socket.setRawOption(RawSocketOption(RawSocketOption.levelSocket, Platform.isMacOS ? 0x80 : 13, linger));
    socket.destroy();
    for (var i = 0; i < 200 && listener.clientCount > 0; i++) {
      rig.move(freqKHz: 14000.0 + i);
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(listener.clientCount, 0);
  });

  test('a client that sends and then closes its side still gets the answer', () async {
    // `echo f | nc -N localhost 4532` is a whole session: the reply is queued
    // when the client's end of the stream arrives, and must still go out.
    await bind(CatServerProtocol.rigctld);
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
    addTearDown(socket.destroy);
    final reply = socket.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    // Enough commands that their replies are still queued when the client's
    // end arrives — one short reply is flushed before anything could drop it.
    socket.write('\\dump_state\n' * 1000);
    await socket.close();
    final replies = utf8.decode(await reply.timeout(const Duration(seconds: 10)));
    expect('\ndone\n'.allMatches(replies), hasLength(1000));
  });

  test('connections reset as soon as they open leave nothing behind', () async {
    // A port scan, with the network open: each connection is gone by the
    // time it is accepted, and looking at it throws.
    if (!Platform.isMacOS && !Platform.isLinux) {
      markTestSkipped('SO_LINGER layout differs here');
      return;
    }
    await bind(CatServerProtocol.rigctld);
    final linger = Uint8List(8)..buffer.asByteData().setInt32(0, 1, Endian.host);
    for (var i = 0; i < 50; i++) {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
      socket.setRawOption(RawSocketOption(RawSocketOption.levelSocket, Platform.isMacOS ? 0x80 : 13, linger));
      socket.destroy();
    }
    await Future.doWhile(() => Future.delayed(const Duration(milliseconds: 10), () => listener.clientCount != 0)).timeout(const Duration(seconds: 5));
    final after = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
    addTearDown(after.destroy);
    after.write('f\n');
    expect(await firstReply(after), '14074000\n', reason: 'still serving');
  });

  test('a client that asks without ever reading is hung up on, rather than queued for without limit', () async {
    // Replies wait in memory until the client reads them; twelve bytes in
    // for seven hundred out is enough to run the app out of memory.
    await bind(CatServerProtocol.rigctld);
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
    addTearDown(socket.destroy);
    final reading = socket.listen((_) {}, onError: (Object _) {});
    addTearDown(reading.cancel);
    reading.pause(); // never reads
    await Future.doWhile(() => Future.delayed(const Duration(milliseconds: 5), () => listener.clientCount == 0)).timeout(const Duration(seconds: 5));
    final flood = utf8.encode('\\dump_state\n' * 1000);
    for (var i = 0; i < 200 && listener.clientCount > 0; i++) {
      socket.add(flood);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future.doWhile(() => Future.delayed(const Duration(milliseconds: 20), () => listener.clientCount != 0)).timeout(const Duration(seconds: 10));
    expect(listener.clientCount, 0);
  });

  test('q still delivers what was asked before it', () async {
    await bind(CatServerProtocol.rigctld);
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
    addTearDown(socket.destroy);
    final reply = socket.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    socket.write('\\dump_state\n' * 200 + 'q\n');
    expect('\ndone\n'.allMatches(utf8.decode(await reply.timeout(const Duration(seconds: 10)))), hasLength(200));
  });

  test('a port another program holds is an error the caller sees, not a silent no-op', () async {
    final held = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(held.close);
    await expectLater(bindCatServer(CatServerProtocol.rigctld, rig, port: held.port, lan: false), throwsA(isA<SocketException>()));
  });

  test('clients are counted in and out', () async {
    await bind(CatServerProtocol.rigctld);
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
    socket.write('f\n');
    await firstReply(socket);
    expect(listener.clientCount, 1);
    await socket.close();
    await Future.doWhile(() => Future.delayed(const Duration(milliseconds: 10), () => listener.clientCount != 0));
    expect(clientChanges, 2);
  });

  test('a client whose input breaks the codec is dropped, and the others keep being served', () async {
    await bind(CatServerProtocol.hrd);
    final good = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
    final bad = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
    addTearDown(good.destroy);
    addTearDown(bad.destroy);

    final bogus = encodeHrdFrame('get frequency');
    bogus.buffer.asByteData().setUint32(0, 0x7fffffff, Endian.little);
    final badClosed = bad.drain<void>().timeout(const Duration(seconds: 5));
    bad.add(bogus);
    await badClosed;

    final goodReplies = good.asBroadcastStream();
    good.add(encodeHrdFrame('get frequency'));
    final reply = await goodReplies.first.timeout(const Duration(seconds: 5));
    expect(decodeUtf16le(reply.sublist(16)), '14074000');
  });

  test('closing the server hangs up on its clients', () async {
    await bind(CatServerProtocol.rigctld);
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, listener.port);
    // A reset is as much a hang-up as a clean close; only silence is not.
    final hungUp = socket.drain<void>().timeout(const Duration(seconds: 5)).then((_) => true, onError: (Object e) => e is SocketException);
    await listener.close();
    expect(await hungUp, isTrue);
  });
}
