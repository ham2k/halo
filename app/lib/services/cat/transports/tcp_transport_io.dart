// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// TCP for every platform that has sockets. Needs only the network-client
// entitlement on macOS, which both the Debug and Release entitlement files
// already carry — unlike UDP, which would need `network.server` added to
// Release before any discovery could ship.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../transport.dart';

const _connectTimeout = Duration(seconds: 5);

class TcpTransport implements EquipmentTransport {
  const TcpTransport();

  static const transportKey = 'tcp';

  @override
  String get key => transportKey;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    if (cancel.isCancelled) throw const CatCancelledException();

    final host = target['host'] as String? ?? '';
    final port = (target['port'] as num?)?.toInt() ?? 0;

    // `Socket.connect` can't be cancelled, so the token races it instead:
    // whoever completes first wins, and a socket that shows up after a
    // cancellation is destroyed rather than left dangling. Without this a
    // superseded attempt would keep hammering the radio for the full
    // handshake timeout — which some radios do not tolerate.
    final completer = Completer<Socket>();
    final pending = Socket.connect(host, port, timeout: _connectTimeout);

    pending.then(
      (socket) {
        if (completer.isCompleted) {
          socket.destroy();
        } else {
          completer.complete(socket);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
    );

    unawaited(cancel.whenCancelled.then((_) {
      if (!completer.isCompleted) completer.completeError(const CatCancelledException());
    }));

    final socket = await completer.future;

    // Cancelled in the gap between the connect landing and us getting here.
    if (cancel.isCancelled) {
      socket.destroy();
      throw const CatCancelledException();
    }

    return _TcpConnection(socket);
  }
}

class _TcpConnection implements EquipmentConnection {
  final Socket _socket;
  final _dataController = StreamController<Uint8List>();
  final _closedCompleter = Completer<void>();
  bool _open = true;

  _TcpConnection(this._socket) {
    _socket.listen(
      _dataController.add,
      onError: (Object _) => _markClosed(),
      onDone: _markClosed,
      cancelOnError: true,
    );
    // A failed write surfaces here rather than at the `add` call, and an
    // unhandled error on `done` would escape into the zone.
    unawaited(_socket.done.then((_) {}, onError: (Object _) {}));
  }

  void _markClosed() {
    if (!_open) return;
    _open = false;
    if (!_closedCompleter.isCompleted) _closedCompleter.complete();
    unawaited(_dataController.close());
  }

  @override
  Stream<Uint8List> get data => _dataController.stream;

  @override
  Future<void> get closed => _closedCompleter.future;

  @override
  void send(List<int> bytes) {
    if (!_open) return;
    // Drivers write from unguarded timers; a stale write must not throw
    // into a timer callback. `closed` is what reports the connection gone.
    try {
      _socket.add(bytes);
    } catch (_) {
      // Already torn down.
    }
  }

  @override
  Future<void> close() async {
    _markClosed();
    try {
      _socket.destroy();
    } catch (_) {
      // Already gone.
    }
  }
}
