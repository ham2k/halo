// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// A separate TLS implementation is the test oracle. OpenSSL is test-only; the
// shipped package links its own Mbed TLS and never starts an external process.
const testPskHex = '0123456789abcdef0123456789abcdef';
final testPsk = Uint8List.fromList(List.generate(testPskHex.length ~/ 2, (i) => int.parse(testPskHex.substring(i * 2, i * 2 + 2), radix: 16)));

class OpenSslPeer {
  final Process process;
  final _ready = Completer<int>();
  final _changed = StreamController<void>.broadcast(sync: true);
  String output = '';
  String errors = '';
  late final int port;
  OpenSslPeer._(this.process) {
    process.stdout.transform(utf8.decoder).listen((value) {
      output += value;
      if (output.length > 2 * 1024 * 1024) output = output.substring(output.length - 1024 * 1024);
      final address = RegExp(r'ACCEPT 127\.0\.0\.1:(\d+)').firstMatch(output);
      if (address != null && !_ready.isCompleted) _ready.complete(int.parse(address.group(1)!));
      _changed.add(null);
    });
    process.stderr.transform(utf8.decoder).listen((value) {
      errors += value;
      if (errors.length > 8192) errors = errors.substring(errors.length - 8192);
    });
    unawaited(
      process.exitCode.then((code) {
        if (!_ready.isCompleted) _ready.completeError(StateError('OpenSSL exited before listening ($code): $errors'));
      }),
    );
    unawaited(process.stdin.done.then((_) {}, onError: (Object _, StackTrace _) {}));
  }

  static Future<OpenSslPeer> start({String cipher = 'ECDHE-PSK-CHACHA20-POLY1305', String identity = 'Client_identity', bool http = false}) async {
    final configured = Platform.environment['HALO_TLS_TEST_OPENSSL'];
    final candidates = [
      ?configured,
      if (Platform.isMacOS) '/opt/homebrew/opt/openssl@3/bin/openssl',
      if (Platform.isMacOS) '/usr/local/opt/openssl@3/bin/openssl',
      'openssl',
    ];
    String? binary;
    for (final candidate in candidates) {
      try {
        final version = await Process.run(candidate, ['version']);
        if (version.exitCode == 0 && version.stdout.toString().startsWith('OpenSSL 3.')) {
          binary = candidate;
          break;
        }
      } on ProcessException {
        // Try the next installation; a missing peer is a test setup failure.
      }
    }
    if (binary == null) throw StateError('TLS interoperability tests need OpenSSL 3. Set HALO_TLS_TEST_OPENSSL to its executable.');
    final peer = OpenSslPeer._(
      await Process.start(binary, [
        's_server',
        '-accept',
        '127.0.0.1:0',
        '-nocert',
        '-psk',
        testPskHex,
        '-psk_identity',
        identity,
        '-tls1_2',
        '-cipher',
        cipher,
        '-naccept',
        '1',
        if (http) '-www',
      ]),
    );
    try {
      peer.port = await peer._ready.future.timeout(const Duration(seconds: 15));
      return peer;
    } on Object {
      await peer.dispose();
      rethrow;
    }
  }

  Future<void> received(String value) async {
    if (output.contains(value)) return;
    await _changed.stream.firstWhere((_) => output.contains(value)).timeout(const Duration(seconds: 15));
  }

  Future<void> send(String value) async {
    process.stdin.write(value);
    await process.stdin.flush();
  }

  Future<void> dispose() async {
    process.kill();
    await process.exitCode;
    await _changed.close();
  }
}

/// Splits every TLS wire record into small writes in both directions. Async
/// flushes let the OS deliver partial records without sleeps or fixed ports.
class FragmentingProxy {
  final ServerSocket _server;
  final List<Socket> _sockets = [];
  int fragments = 0;
  bool _closed = false;
  FragmentingProxy._(this._server, int peerPort) {
    _server.listen((client) async {
      _sockets.add(client);
      final remote = await Socket.connect(InternetAddress.loopbackIPv4, peerPort);
      _sockets.add(remote);
      if (_closed) {
        remote.destroy();
        return;
      }
      unawaited(_forward(client, remote));
      unawaited(_forward(remote, client));
    });
  }
  int get port => _server.port;
  static Future<FragmentingProxy> start(int peerPort) async => FragmentingProxy._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0), peerPort);

  Future<void> _forward(Socket from, Socket to) async {
    unawaited(to.done.then((_) {}, onError: (Object _, StackTrace _) {}));
    try {
      await for (final bytes in from) {
        for (var offset = 0; offset < bytes.length; offset += 7) {
          if (_closed) return;
          to.add(Uint8List.sublistView(bytes, offset, (offset + 7).clamp(0, bytes.length)));
          fragments++;
          await to.flush();
        }
      }
      await to.close();
    } on SocketException {
      // Closing either test endpoint also closes the proxy.
    }
  }

  Future<void> dispose() async {
    _closed = true;
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _server.close();
  }
}
