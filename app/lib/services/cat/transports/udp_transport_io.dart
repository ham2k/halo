// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// UDP for every platform that has sockets. The reply port is a LISTENING
// socket, so on macOS it needs `com.apple.security.network.server`, which
// both entitlement files carry for udp_broadcast_io.dart.
//
// "Connected" here means the reply port is bound and the host resolved:
// UDP has no handshake, so whether anything answers is for the session's
// first reply — and the silence watch — to say. Nothing about the far end
// ends the connection either; see [_UdpConnection._rebind].

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../os_error_detail_io.dart';
import '../transport.dart';
import 'mdns_io.dart';
import 'udp_transport_config.dart';

/// EADDRINUSE on macOS and iOS, on Linux and Android, and on Windows.
const _addressInUse = {48, 98, 10048};

/// How long a reply port that is in use is waited for: a socket closed a
/// moment ago — this node's own, on a reconnect — is released by the IO
/// service only after `close` returns.
const _bindAttempts = 5;
const _bindRetryDelay = Duration(milliseconds: 100);

class UdpTransport extends EquipmentTransport with UdpTransportConfig {
  const UdpTransport({required this.portConfigKey, required this.replyPortOffset});

  @override
  final String portConfigKey;

  @override
  final int replyPortOffset;

  static const transportKey = 'udp';

  @override
  String get key => transportKey;

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    if (cancel.isCancelled) throw const CatCancelledException();
    final host = target['host'] as String? ?? '';
    final port = (target['port'] as num?)?.toInt() ?? 0;
    final replyPort = (target['replyPort'] as num?)?.toInt() ?? 0;

    final address = await lookupHost(host);
    if (cancel.isCancelled) throw const CatCancelledException();
    final socket = await _bindReplyPort(replyPort);
    if (cancel.isCancelled) {
      socket.close();
      throw const CatCancelledException();
    }
    return _UdpConnection(socket, replyPort, address, port);
  }
}

/// Not shared: two listeners on one reply port each get only some of the
/// answers, and a heading that skips every other poll reads as a stall.
/// Held, the bind fails and says so ([UdpReplyPortTaken]) rather than
/// half-working; any other bind failure is the OS's own.
Future<RawDatagramSocket> _bindReplyPort(int port) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: false);
    } on SocketException catch (e) {
      if (!_addressInUse.contains(e.osError?.errorCode)) rethrow;
      if (attempt >= _bindAttempts) throw UdpReplyPortTaken(port, e.osError);
      await Future<void>.delayed(_bindRetryDelay);
    }
  }
}

/// The reply port is in use — by another program, or by another node here
/// on the same port. Not a SocketException, which the equipment row words
/// as a network that cannot reach the host: the host was never asked, and
/// what to do is free a port on this device.
class UdpReplyPortTaken implements CatUnreachable {
  final int port;
  final OSError? osError;

  const UdpReplyPortTaken(this.port, [this.osError]);

  @override
  String toString() => t.settings.station.connectFailedReplyPort(port: port);
}

class _UdpConnection implements EquipmentConnection, ExplainsClose {
  RawDatagramSocket _socket;
  final int _replyPort;
  final InternetAddress _address;
  final int _port;
  final _dataController = StreamController<Uint8List>();
  final _closedCompleter = Completer<void>();
  bool _open = true;
  bool _rebinding = false;

  @override
  String? closeReason;

  _UdpConnection(this._socket, this._replyPort, this._address, this._port) {
    _listen(_socket);
  }

  void _listen(RawDatagramSocket socket) {
    socket.listen(
      (event) {
        if (event != RawSocketEvent.read || !identical(socket, _socket)) return;
        // From any address: a PC with two interfaces on one network answers
        // from whichever its routing prefers, not necessarily the one
        // dialled. The port is this node's alone, and the session reads
        // nothing but its own protocol's answers.
        final datagram = socket.receive();
        if (datagram == null || _dataController.isClosed) return;
        _dataController.add(datagram.data);
      },
      onError: (Object error) {
        if (identical(socket, _socket)) unawaited(_rebind(error));
      },
      onDone: () {
        if (identical(socket, _socket) && !_rebinding) _markClosed('the reply socket closed');
      },
    );
  }

  /// A failed send arrives at the listener, and the SDK closes the socket
  /// after it. Left closed, one unanswered ARP — the PstRotator PC asleep —
  /// or a Local Network grant not given would end the node for good, since
  /// nothing reconnects a rotator. Bound again instead, the silence watch
  /// says "not responding" and the next answer brings it back; only a
  /// reply port that cannot be bound again ends it.
  Future<void> _rebind(Object error) async {
    if (!_open || _rebinding) return;
    _rebinding = true;
    final why = osErrorDetail(error) ?? '${error.runtimeType}';
    debugPrint('[cat] udp socket error ($why), binding the reply port again');
    _socket.close();
    try {
      final socket = await _bindReplyPort(_replyPort);
      if (!_open) {
        socket.close();
        return;
      }
      _socket = socket;
      _listen(socket);
    } catch (e) {
      _markClosed('socket error: $why; binding the reply port again failed: ${osErrorDetail(e) ?? e.runtimeType}');
    } finally {
      _rebinding = false;
    }
  }

  void _markClosed([String? reason]) {
    if (!_open) return;
    _open = false;
    closeReason = reason;
    if (!_closedCompleter.isCompleted) _closedCompleter.complete();
    unawaited(_dataController.close());
  }

  @override
  Stream<Uint8List> get data => _dataController.stream;

  @override
  Future<void> get closed => _closedCompleter.future;

  /// Uncaught, unlike TCP's: a closed datagram socket returns 0 rather than
  /// throwing, and a send the OS refuses reaches the listener's `onError`.
  /// What could still throw here is a bug.
  @override
  void send(List<int> bytes) {
    if (!_open) return;
    _socket.send(bytes, _address, _port);
  }

  @override
  Future<void> close() async {
    _markClosed();
    _socket.close();
  }
}
