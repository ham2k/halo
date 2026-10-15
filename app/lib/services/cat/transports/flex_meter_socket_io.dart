// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'mdns_io.dart';

class FlexMeterSocket {
  final RawDatagramSocket _socket;
  late final StreamSubscription<RawSocketEvent> _subscription;
  FlexMeterSocket._(this._socket, InternetAddress peer, void Function(Uint8List) onData, void Function(Object, StackTrace) onError) {
    _subscription = _socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final packet = _socket.receive();
      if (packet != null && packet.address.address == peer.address) onData(packet.data);
    }, onError: onError);
  }
  int get port => _socket.port;
  static Future<FlexMeterSocket?> open(String host, void Function(Uint8List) onData, void Function(Object, StackTrace) onError) async {
    final peer = await lookupHost(host).timeout(const Duration(seconds: 5));
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    return FlexMeterSocket._(socket, peer, onData, onError);
  }

  void close() {
    unawaited(_subscription.cancel());
    _socket.close();
  }
}
