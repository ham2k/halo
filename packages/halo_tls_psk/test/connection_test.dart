// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_tls_psk/halo_tls_psk.dart';
import 'support/openssl_peer.dart';

// These tests await socket/protocol events. Timeouts only guard hangs; there
// are no fixed sleeps or assertions about how quickly the machine executes.
void main() {
  for (final cipher in ['ECDHE-PSK-CHACHA20-POLY1305', 'ECDHE-PSK-AES256-CBC-SHA384']) {
    test('exchanges data with an independent TLS 1.2 peer using $cipher', () async {
      final peer = await OpenSslPeer.start(cipher: cipher);
      addTearDown(peer.dispose);
      final connection = await PskTlsConnection.connect(host: '127.0.0.1', port: peer.port, psk: testPsk, identity: 'Client_identity');
      addTearDown(connection.close);
      final data = StreamIterator(connection.data);
      addTearDown(data.cancel);
      connection.send(utf8.encode('client-to-server\n'));
      await peer.received('client-to-server');
      await peer.send('server-to-client\n');
      expect(await data.moveNext().timeout(const Duration(seconds: 15)), isTrue);
      expect(utf8.decode(data.current), 'server-to-client\n');
      await connection.close();
      await connection.closed;
      connection.send([1, 2, 3]);
      await connection.close();
    });
  }

  test('empty identity and fragmented TLS records preserve plaintext order', () async {
    final peer = await OpenSslPeer.start(identity: '');
    addTearDown(peer.dispose);
    final proxy = await FragmentingProxy.start(peer.port);
    addTearDown(proxy.dispose);
    final connection = await PskTlsConnection.connect(host: '127.0.0.1', port: proxy.port, psk: testPsk, identity: '');
    addTearDown(connection.close);
    final expected = '${List.filled(2000, 'some bytes ').join()}end\n';
    final received = StringBuffer();
    final done = Completer<void>();
    final subscription = connection.data.listen((bytes) {
      received.write(utf8.decode(bytes));
      if (received.length >= expected.length && !done.isCompleted) done.complete();
    }, onError: (Object error, StackTrace stack) => done.completeError(error, stack));
    addTearDown(subscription.cancel);
    connection.send(utf8.encode('fragmented client request\n'));
    await peer.received('fragmented client request');
    await peer.send(expected);
    await done.future.timeout(const Duration(seconds: 15));
    expect(received.toString(), expected);
    expect(proxy.fragments, greaterThan(100));
  });

  test('a wrong PSK fails authentication without returning a connection or secrets', () async {
    final peer = await OpenSslPeer.start();
    addTearDown(peer.dispose);
    final wrongKey = Uint8List.fromList(List.filled(16, 42));
    await expectLater(
      PskTlsConnection.connect(host: '127.0.0.1', port: peer.port, psk: wrongKey, identity: 'Client_identity'),
      throwsA(isA<PskTlsException>().having((e) => e.code, 'code', 'handshakeFailed').having((e) => e.toString(), 'safe message', 'TLS-PSK: handshakeFailed')),
    );
  });

  test('does not fall back to a PSK cipher outside the allowlist', () async {
    final peer = await OpenSslPeer.start(cipher: 'PSK-AES256-CBC-SHA');
    addTearDown(peer.dispose);
    await expectLater(
      PskTlsConnection.connect(host: '127.0.0.1', port: peer.port, psk: testPsk, identity: 'Client_identity'),
      throwsA(isA<PskTlsException>().having((e) => e.code, 'code', 'handshakeFailed')),
    );
  });

  test('peer close_notify closes the stream normally', () async {
    final peer = await OpenSslPeer.start(http: true);
    addTearDown(peer.dispose);
    final connection = await PskTlsConnection.connect(host: '127.0.0.1', port: peer.port, psk: testPsk, identity: 'Client_identity');
    addTearDown(connection.close);
    final response = connection.data.map(utf8.decode).join();
    connection.send(utf8.encode('GET / HTTP/1.0\r\n\r\n'));
    expect(await response.timeout(const Duration(seconds: 15)), startsWith('HTTP/1.0 200 ok'));
    await connection.closed;
  });

  test('TCP EOF without close_notify reports truncation', () async {
    final peer = await OpenSslPeer.start();
    addTearDown(peer.dispose);
    final connection = await PskTlsConnection.connect(host: '127.0.0.1', port: peer.port, psk: testPsk, identity: 'Client_identity');
    addTearDown(connection.close);
    final failed = expectLater(connection.data, emitsError(isA<PskTlsException>().having((e) => e.code, 'code', 'connectionFailed')));
    // s_server's interactive q command closes TCP before TLS shutdown.
    await peer.send('q\n');
    await failed;
    await connection.closed;
  });

  test('closing from a synchronous data callback is safe', () async {
    final peer = await OpenSslPeer.start();
    addTearDown(peer.dispose);
    final connection = await PskTlsConnection.connect(host: '127.0.0.1', port: peer.port, psk: testPsk, identity: 'Client_identity');
    addTearDown(connection.close);
    final subscription = connection.data.listen((_) => unawaited(connection.close()));
    addTearDown(subscription.cancel);
    await peer.send('trigger close\n');
    await connection.closed.timeout(const Duration(seconds: 15));
  });

  test('input arriving before a listener is retained until it listens', () async {
    final peer = await OpenSslPeer.start();
    addTearDown(peer.dispose);
    final connection = await PskTlsConnection.connect(host: '127.0.0.1', port: peer.port, psk: testPsk, identity: 'Client_identity');
    addTearDown(connection.close);
    await peer.send('before-listener\n');
    expect(utf8.decode(await connection.data.first.timeout(const Duration(seconds: 15))), 'before-listener\n');
    await connection.closed;
  });

  test('oversize queued writes fail with a bounded error and safe repeated close', () async {
    final peer = await OpenSslPeer.start();
    addTearDown(peer.dispose);
    final connection = await PskTlsConnection.connect(host: '127.0.0.1', port: peer.port, psk: testPsk, identity: 'Client_identity');
    final failed = expectLater(connection.data, emitsError(isA<PskTlsException>().having((e) => e.code, 'code', 'bufferLimit')));
    connection.send(Uint8List(1024 * 1024 + 1));
    await failed;
    await connection.closed;
    await connection.close();
    connection.send([1]);
  });

  test('slow wire flush pauses socket input and resumes without losing a large response', () async {
    final peer = await OpenSslPeer.start();
    addTearDown(peer.dispose);
    final socket = _GatedSocket(await Socket.connect('127.0.0.1', peer.port));
    addTearDown(socket.destroy);
    final connection = await IOOverrides.runZoned(
      () => PskTlsConnection.connect(host: '127.0.0.1', port: peer.port, psk: testPsk, identity: 'Client_identity'),
      socketStartConnect: (dynamic host, int port, {dynamic sourceAddress, int sourcePort = 0}) async =>
          ConnectionTask.fromSocket(Future<Socket>.value(socket), socket.destroy),
    );
    addTearDown(connection.close);
    final expected = '${List.filled(512 * 1024, 'x').join()}\n';
    final received = BytesBuilder();
    final complete = Completer<void>();
    final subscription = connection.data.listen(
      (bytes) {
        received.add(bytes);
        if (received.length >= expected.length && !complete.isCompleted) complete.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (!complete.isCompleted) complete.completeError(error, stack);
      },
    );
    addTearDown(subscription.cancel);
    // Gate only after authentication; the peer and all socket I/O remain real.
    socket.blockFlush();
    addTearDown(socket.releaseFlush);
    connection.send(utf8.encode('request-large-response\n'));
    await socket.flushStarted.future.timeout(const Duration(seconds: 15));
    await peer.received('request-large-response');
    final sent = peer.send(expected);
    await socket.inputPaused.future.timeout(const Duration(seconds: 15));
    socket.releaseFlush();
    await sent.timeout(const Duration(seconds: 15));
    await complete.future.timeout(const Duration(seconds: 15));
    expect(utf8.decode(received.takeBytes()), expected);
    connection.send(utf8.encode('still-connected-after-backpressure\n'));
    await peer.received('still-connected-after-backpressure');
  });

  for (final synchronous in [true, false]) {
    test('a ${synchronous ? 'synchronous' : 'future'} non-socket connect error fails promptly and safely', () async {
      await IOOverrides.runZoned(
        () async {
          await expectLater(
            PskTlsConnection.connect(host: 'private-host', port: 9204, psk: testPsk, identity: '').timeout(const Duration(seconds: 2)),
            throwsA(
              isA<PskTlsException>()
                  .having((error) => error.code, 'code', 'connectFailed')
                  .having((error) => error.toString(), 'sanitized error', 'TLS-PSK: connectFailed'),
            ),
          );
        },
        socketStartConnect: (dynamic host, int port, {dynamic sourceAddress, int sourcePort = 0}) {
          if (synchronous) throw StateError('private platform diagnostic');
          return Future<ConnectionTask<Socket>>.error(StateError('private platform diagnostic'));
        },
      );
    });
  }

  test('cancels a pending handshake and releases the accepted socket', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final accepted = Completer<Socket>();
    server.listen(accepted.complete);
    final cancelled = Completer<void>();
    final pending = PskTlsConnection.connect(host: '127.0.0.1', port: server.port, psk: testPsk, identity: 'Client_identity', cancelled: cancelled.future);
    final failed = expectLater(pending, throwsA(isA<PskTlsCancelledException>()));
    final socket = await accepted.future;
    addTearDown(socket.destroy);
    final disconnected = socket.drain<void>();
    cancelled.complete();
    await failed;
    await disconnected.timeout(const Duration(seconds: 15));
  });

  test('connect cancellation after authentication leaves the live connection usable', () async {
    final peer = await OpenSslPeer.start();
    addTearDown(peer.dispose);
    final cancelled = Completer<void>();
    final connection = await PskTlsConnection.connect(
      host: '127.0.0.1',
      port: peer.port,
      psk: testPsk,
      identity: 'Client_identity',
      cancelled: cancelled.future,
    );
    addTearDown(connection.close);
    final subscription = connection.data.listen((_) {});
    addTearDown(subscription.cancel);
    cancelled.complete();
    connection.send(utf8.encode('still-connected\n'));
    await peer.received('still-connected');
    await connection.close();
  });

  test('normal close flushes commands queued behind an in-flight TLS write', () async {
    final peer = await OpenSslPeer.start();
    addTearDown(peer.dispose);
    final connection = await PskTlsConnection.connect(host: '127.0.0.1', port: peer.port, psk: testPsk, identity: 'Client_identity');
    addTearDown(connection.close);
    final subscription = connection.data.listen((_) {});
    addTearDown(subscription.cancel);
    connection.send(utf8.encode('${List.filled(32768, 'a').join()}\n'));
    connection.send(utf8.encode('final-command\n'));
    await connection.close();
    await peer.received('final-command');
  });

  test('a stalled handshake expires with a safe timeout error', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((socket) {
      addTearDown(socket.destroy);
      unawaited(socket.drain<void>());
    });
    await expectLater(
      PskTlsConnection.connect(host: '127.0.0.1', port: server.port, psk: testPsk, identity: 'Client_identity', timeout: const Duration(milliseconds: 25)),
      throwsA(isA<PskTlsException>().having((e) => e.code, 'code', 'timeout')),
    );
  });
}

/// Controls only completion of a real socket's flush. Input pause/resume is
/// observed on the real subscription rather than buffered in a fake stream.
class _GatedSocket implements Socket {
  final Socket _socket;
  Completer<void>? _flushGate;
  final flushStarted = Completer<void>();
  final inputPaused = Completer<void>();
  _GatedSocket(this._socket);

  void blockFlush() => _flushGate = Completer<void>();
  void releaseFlush() {
    final gate = _flushGate;
    _flushGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  void add(List<int> bytes) => _socket.add(bytes);
  @override
  Future<void> flush() async {
    final gate = _flushGate;
    if (gate != null) {
      if (!flushStarted.isCompleted) flushStarted.complete();
      await gate.future;
    }
    await _socket.flush();
  }

  @override
  Future<dynamic> get done => _socket.done;
  @override
  void destroy() {
    releaseFlush();
    _socket.destroy();
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List)? onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      _ObservedSubscription(_socket.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError), () {
        if (_flushGate != null && !inputPaused.isCompleted) inputPaused.complete();
      });
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ObservedSubscription implements StreamSubscription<Uint8List> {
  final StreamSubscription<Uint8List> _subscription;
  final void Function() _onPause;
  _ObservedSubscription(this._subscription, this._onPause);
  @override
  void pause([Future<void>? resumeSignal]) {
    _subscription.pause(resumeSignal);
    _onPause();
  }

  @override
  void resume() => _subscription.resume();
  @override
  bool get isPaused => _subscription.isPaused;
  @override
  Future<void> cancel() => _subscription.cancel();
  @override
  void onData(void Function(Uint8List)? handleData) => _subscription.onData(handleData);
  @override
  void onError(Function? handleError) => _subscription.onError(handleError);
  @override
  void onDone(void Function()? handleDone) => _subscription.onDone(handleDone);
  @override
  Future<E> asFuture<E>([E? futureValue]) => _subscription.asFuture<E>(futureValue);
}
