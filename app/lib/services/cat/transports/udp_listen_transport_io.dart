// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Listening for datagrams, for every platform that has sockets. A LISTENING
// socket, so on macOS it needs `com.apple.security.network.server`, which
// both entitlement files carry for udp_broadcast_io.dart.
//
// "Connected" means the port is bound: nothing is dialled, so whether
// anything is sending is for the session's first sentence — and the silence
// watch — to say.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';

import '../os_error_detail_io.dart';
import '../transport.dart';
import 'udp_listen_transport_config.dart';

/// EADDRINUSE on macOS and iOS, on Linux and Android, and on Windows.
const _addressInUse = {48, 98, 10048};

/// How long a port that is in use is waited for: this node's own socket,
/// closed a moment ago on a reconnect, is released by the IO service only
/// after `close` returns — udp_transport_io.dart's reply port, for the same
/// reason.
const _bindAttempts = 5;
const _bindRetryDelay = Duration(milliseconds: 100);

class UdpListenTransport extends EquipmentTransport with UdpListenTransportConfig {
  const UdpListenTransport();

  static const transportKey = 'udpListen';

  @override
  String get key => transportKey;

  /// Every sender is taken: the phone pushing its GPS is whatever address
  /// the network gave it today, and the operator has no host to name.
  ///
  /// Not shared (`reuseAddress: false`, which Dart otherwise defaults on):
  /// a datagram sent to one address and port reaches ONE of the sockets
  /// sharing it, so a chart plotter listening beside this would take some of
  /// the fixes, and the receiver would read as stalling. Held, the bind fails
  /// and says so instead. One way round it this cannot stop: on Windows a
  /// program binding AFTER this one with `SO_REUSEADDR` takes the port over,
  /// since Dart has no exclusive bind, and the receiver then reads as gone
  /// quiet.
  ///
  /// A port outside 1–65535 is refused rather than bound: `0` asks the OS for
  /// any port, which would bind, report connected, and receive nothing ever.
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    if (cancel.isCancelled) throw const CatCancelledException();
    final port = (target['port'] as num?)?.toInt() ?? 0;
    if (port < 1 || port > 65535) throw UdpListenFailed(port);
    final socket = await _bind(port);
    if (cancel.isCancelled) {
      socket.close();
      throw const CatCancelledException();
    }
    return _UdpListenConnection(socket);
  }
}

Future<RawDatagramSocket> _bind(int port) async {
  for (var attempt = 1; ; attempt++) {
    try {
      return await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: false);
    } on SocketException catch (e) {
      if (!_addressInUse.contains(e.osError?.errorCode)) throw UdpListenFailed(port, e.osError);
      if (attempt >= _bindAttempts) throw UdpListenPortTaken(port, e.osError);
      await Future<void>.delayed(_bindRetryDelay);
    }
  }
}

/// The listening port is in use — by another program, or another node here.
/// Not a SocketException, which the equipment row words as a network that
/// cannot reach the host: there is no host, and what to do is free the port.
class UdpListenPortTaken implements CatUnreachable, CarriesOsError {
  final int port;
  @override
  final OSError? osError;

  const UdpListenPortTaken(this.port, [this.osError]);

  @override
  String toString() => t.settings.station.connectFailedListenPort(port: port);
}

/// The port could not be listened on for any other reason — one the OS
/// keeps for itself (below 1024 on Linux and Android), or one that is no
/// port at all. Worded as the port, with the OS's own detail: a plain
/// SocketException reads on the row as a radio the network cannot reach,
/// and here there is no radio and no network to check.
class UdpListenFailed implements CatUnreachable, CarriesOsError {
  final int port;
  @override
  final OSError? osError;

  const UdpListenFailed(this.port, [this.osError]);

  @override
  String toString() => switch (osError == null ? null : osErrorDetail(osError!)) {
    final detail? => t.settings.station.connectFailedListenDetail(port: port, detail: detail),
    null => t.settings.station.connectFailedListen(port: port),
  };
}

class _UdpListenConnection implements EquipmentConnection, ExplainsClose {
  final RawDatagramSocket _socket;
  final _dataController = StreamController<Uint8List>();
  final _closedCompleter = Completer<void>();
  bool _open = true;

  @override
  String? closeReason;

  _UdpListenConnection(this._socket) {
    _socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _socket.receive();
        if (datagram == null || _dataController.isClosed) return;
        _dataController.add(datagram.data);
      },
      // Nothing is sent, so nothing here is a send the OS refused: an error
      // is the socket itself failing, and the node's reconnect binds again.
      onError: (Object error) => _markClosed('socket error: ${osErrorDetail(error) ?? error.runtimeType}'),
      onDone: () => _markClosed('the socket closed'),
    );
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

  /// Nowhere to send to: a sender that pushes is not one that listens.
  @override
  void send(List<int> bytes) {}

  @override
  Future<void> close() async {
    _markClosed();
    _socket.close();
  }
}
