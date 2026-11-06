// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A `ws://` WebSocket on every platform with sockets. Plain `ws`, not `wss`:
// the TCI servers this is for listen unencrypted, on the operator's own
// machine or LAN, and offer nothing else.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../os_error_detail_io.dart';
import '../transport.dart';
import 'mdns_io.dart';
import 'tcp_transport_config.dart';

class WebSocketTransport extends EquipmentTransport with TcpTransportConfig {
  const WebSocketTransport({this.portConfigKey = 'port', this.connectTimeout = const Duration(seconds: 5)});

  @override
  final String portConfigKey;

  /// How long the TCP connect, and then the upgrade, may each take.
  final Duration connectTimeout;

  static const transportKey = 'websocket';

  @override
  String get key => transportKey;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    if (cancel.isCancelled) throw const CatCancelledException();

    final host = target['host'] as String? ?? '';
    final port = (target['port'] as num?)?.toInt() ?? 0;

    // Raced against the token, as tcp_transport_io.dart races its socket: a
    // handshake that lands after a cancel or a timeout is closed, not adopted.
    final completer = Completer<WebSocket>();
    final client = HttpClient()..connectionTimeout = connectTimeout;
    Timer? upgradeTimer;
    unawaited(
      connectTarget(host)
          .then((resolved) {
            if (completer.isCompleted) throw const CatCancelledException();
            final address = resolved is InternetAddress ? resolved.address : '$resolved';
            final uri = Uri(scheme: 'ws', host: address, port: port, path: '/');
            // The client's own timeout covers the TCP connect alone. A server
            // that accepts TCP and never answers the upgrade — Thetis's CAT
            // port typed into the TCI field — would hold the dial open.
            upgradeTimer = Timer(connectTimeout, () {
              if (!completer.isCompleted) completer.completeError(TimeoutException('no WebSocket upgrade from $uri', connectTimeout));
            });
            return WebSocket.connect('$uri', customClient: client);
          })
          .then(
            (socket) {
              if (completer.isCompleted) {
                unawaited(socket.close());
              } else {
                completer.complete(socket);
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!completer.isCompleted) completer.completeError(error, stackTrace);
            },
          ),
    );

    unawaited(
      cancel.whenCancelled.then((_) {
        if (!completer.isCompleted) completer.completeError(const CatCancelledException());
      }),
    );

    final WebSocket socket;
    try {
      socket = await completer.future;
    } catch (_) {
      upgradeTimer?.cancel();
      // Forced: an unforced close lets an unanswered upgrade keep its socket,
      // and every retry would leave the server one more.
      client.close(force: true);
      rethrow;
    }
    upgradeTimer?.cancel();
    client.close();
    if (cancel.isCancelled) {
      unawaited(socket.close());
      throw const CatCancelledException();
    }
    return WebSocketConnection(socket);
  }
}

/// Text frames up [data] as UTF-8, binary frames up [binaryFrames].
class WebSocketConnection implements EquipmentConnection, BinaryFramesConnection, ExplainsClose {
  final WebSocket _socket;
  final _dataController = StreamController<Uint8List>();
  final _binaryController = StreamController<Uint8List>.broadcast();
  final _closedCompleter = Completer<void>();
  bool _open = true;

  @override
  String? closeReason;

  WebSocketConnection(this._socket) {
    _socket.listen(
      (frame) {
        if (frame is String) {
          _dataController.add(utf8.encode(frame));
        } else if (frame is List<int>) {
          _binaryController.add(frame is Uint8List ? frame : Uint8List.fromList(frame));
        }
      },
      onError: (Object e) => _markClosed('socket error: ${osErrorDetail(e) ?? e.runtimeType}'),
      onDone: () => _markClosed('the other end closed the connection'),
      cancelOnError: true,
    );
    // A failed write surfaces here rather than at the `add` call, and an
    // unhandled error on `done` would escape into the zone. When the read
    // side has already said why, that reason stands.
    unawaited(_socket.done.then((_) {}, onError: (Object e) => _markClosed('write error: ${osErrorDetail(e) ?? e.runtimeType}')));
  }

  void _markClosed([String? reason]) {
    if (!_open) return;
    _open = false;
    closeReason = reason;
    if (!_closedCompleter.isCompleted) _closedCompleter.complete();
    unawaited(_dataController.close());
    unawaited(_binaryController.close());
  }

  @override
  Stream<Uint8List> get data => _dataController.stream;

  @override
  Stream<Uint8List> get binaryFrames => _binaryController.stream;

  @override
  Future<void> get closed => _closedCompleter.future;

  /// Sent as one text frame: a WebSocket server reads each frame as a
  /// message, and the protocols on this transport speak text.
  @override
  void send(List<int> bytes) {
    if (!_open) return;
    try {
      _socket.add(utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      // Already torn down; [closed] says so.
    }
  }

  @override
  Future<void> close() async {
    _markClosed();
    // Not awaited: the close handshake waits on a server that may already
    // be gone, and a disconnect must not hang on it.
    unawaited(_socket.close().then((_) {}, onError: (_) {}));
  }
}
