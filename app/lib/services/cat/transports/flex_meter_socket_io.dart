// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:halo_audio/halo_audio.dart' show AudioEngine, AudioSocket;

import 'flex_udp_socket.dart';
import 'mdns_io.dart';

export 'flex_udp_socket.dart';

class FlexMeterSocket implements FlexUdpSocket {
  final RawDatagramSocket _socket;
  late final StreamSubscription<RawSocketEvent> _subscription;
  final InternetAddress _peer;
  FlexMeterSocket._(this._socket, InternetAddress peer, void Function(Uint8List) onData, void Function(Object, StackTrace) onError) : _peer = peer {
    _subscription = _socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final packet = _socket.receive();
      if (packet != null && packet.address.address == peer.address) onData(packet.data);
    }, onError: onError);
  }
  @override
  int get port => _socket.port;

  @override
  AudioSocket? get audioSocket => null;
  @override
  String get radioAddress => _peer.address;

  @override
  void send(List<int> data, int toPort) => _socket.send(data, _peer, toPort);
  static Future<FlexMeterSocket?> open(String host, void Function(Uint8List) onData, void Function(Object, StackTrace) onError) async {
    final peer = await lookupHost(host).timeout(const Duration(seconds: 5));
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    return FlexMeterSocket._(socket, peer, onData, onError);
  }

  @override
  void close() {
    unawaited(_subscription.cancel());
    _socket.close();
  }
}

/// A [FlexUdpSocket] that is one of [engine]'s, so the streams it claims (a
/// slice's `dax_rx`) never pass through Dart; everything else comes to
/// [onData] as [FlexMeterSocket]'s datagrams do — only the radio's.
Future<FlexUdpSocket?> openFlexEngineSocket(AudioEngine engine, String host, void Function(Uint8List) onData, void Function(Object, StackTrace) onError) async {
  final peer = await lookupHost(host).timeout(const Duration(seconds: 5));
  if (peer.type != InternetAddressType.IPv4) throw FlexAudioNeedsIpv4(peer.address);
  return _EngineFlexSocket(engine.openSocket(), peer.address, onData, onError);
}

class _EngineFlexSocket implements FlexUdpSocket {
  _EngineFlexSocket(this.audioSocket, this._peer, void Function(Uint8List) onData, void Function(Object, StackTrace) onError) {
    _subscription = audioSocket.datagrams.listen((d) {
      if (d.host == _peer) onData(d.data);
    }, onError: onError);
  }

  @override
  final AudioSocket audioSocket;
  final String _peer;

  @override
  String get radioAddress => _peer;
  late final StreamSubscription<Object?> _subscription;

  @override
  int get port => audioSocket.port;

  @override
  void send(List<int> data, int toPort) => audioSocket.send(_peer, toPort, Uint8List.fromList(data));

  @override
  void close() {
    unawaited(_subscription.cancel());
    audioSocket.close();
  }
}
