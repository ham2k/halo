// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../cat_server/cat_server_protocol.dart' show CatServerFailure;
import '../cat_server/cat_server_socket_io.dart' show catServerFailureOf;
import '../error_reporting_service.dart';
import 'agent_link_model.dart';
import 'agent_link_peer.dart';

/// Listens on [port] on `127.0.0.1`, and never on another interface: the
/// link is for programs on this machine. Throws when the port cannot be
/// bound.
///
/// IPv4 only: `halo-mcp` dials `127.0.0.1`, so a `::1` listener would serve
/// nobody, and a port something else holds on `::1` alone would fail a bind
/// the command never needed.
Future<AgentLinkListener> bindAgentLink({required int port, required void Function(AgentLinkPeer peer) onPeer}) async =>
    _IoAgentLinkListener(await ServerSocket.bind(InternetAddress.loopbackIPv4, port), onPeer);

/// Whether [error] is the port being out of reach — held by another program,
/// or reserved by the system (Windows keeps ranges for Hyper-V) — rather
/// than something worth reporting.
bool agentLinkPortUnavailable(Object error) => switch (catServerFailureOf(error)) {
  CatServerFailure.portInUse || CatServerFailure.portDenied => true,
  _ => false,
};

class _IoAgentLinkListener implements AgentLinkListener {
  final ServerSocket _socket;
  final _peers = <_IoAgentLinkPeer>{};
  late final StreamSubscription<Socket> _subscription;

  _IoAgentLinkListener(this._socket, void Function(AgentLinkPeer) onPeer) {
    _subscription = _socket.listen((client) {
      final peer = _IoAgentLinkPeer(client);
      _peers.add(peer);
      unawaited(peer.done.whenComplete(() => _peers.remove(peer)));
      onPeer(peer);
    }, onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'AgentLink:accept'));
  }

  @override
  int get port => _socket.port;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _socket.close();
    for (final peer in [..._peers]) {
      await peer.close();
    }
  }
}

class _IoAgentLinkPeer implements AgentLinkPeer {
  final Socket _socket;
  final _lines = StreamController<String>();
  final _done = Completer<void>();
  final _pending = BytesBuilder(copy: false);
  bool _closed = false;

  _IoAgentLinkPeer(this._socket) {
    _socket.setOption(SocketOption.tcpNoDelay, true);
    _socket.listen(_read, onError: (Object _) => _finish(), onDone: _finish, cancelOnError: true);
    unawaited(_socket.done.then((_) {}, onError: (Object _) {}).whenComplete(_finish));
  }

  void _read(Uint8List data) {
    var start = 0;
    for (var i = 0; i < data.length; i++) {
      if (data[i] != 0x0A) continue;
      _pending.add(Uint8List.sublistView(data, start, i));
      start = i + 1;
      final bytes = _pending.takeBytes();
      final String line;
      try {
        line = utf8.decode(bytes);
      } on FormatException {
        debugPrint('[agent-link] hung up on a peer: a line that is not UTF-8');
        unawaited(close());
        return;
      }
      final trimmed = line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
      if (trimmed.isNotEmpty && !_lines.isClosed) _lines.add(trimmed);
    }
    if (start < data.length) _pending.add(Uint8List.sublistView(data, start));
    if (_pending.length > kAgentLinkMaxFrame) {
      debugPrint('[agent-link] hung up on a peer: a line over $kAgentLinkMaxFrame bytes');
      unawaited(close());
    }
  }

  void _finish() {
    if (!_lines.isClosed) unawaited(_lines.close());
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Stream<String> get lines => _lines.stream;

  @override
  Future<void> get done => _done.future;

  @override
  void send(String line) {
    if (_closed || _done.isCompleted) return;
    _socket.add(utf8.encode('$line\n'));
  }

  @override
  Future<void> close() async {
    if (_closed) return done;
    _closed = true;
    try {
      await _socket.flush();
    } catch (_) {
      // A peer already gone has nothing left to flush to.
    }
    await _socket.close().then((_) {}, onError: (Object _) {});
    _socket.destroy();
    _finish();
  }
}
