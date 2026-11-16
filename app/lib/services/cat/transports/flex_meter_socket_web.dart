// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:typed_data';

import 'package:halo_audio/halo_audio.dart' show AudioEngine, AudioSocket;

import 'flex_udp_socket.dart';

export 'flex_udp_socket.dart';

/// Browsers have no UDP sockets; a missing receive meter remains unavailable.
class FlexMeterSocket implements FlexUdpSocket {
  @override
  int get port => 0;
  @override
  AudioSocket? get audioSocket => null;
  @override
  String get radioAddress => '';
  static Future<FlexMeterSocket?> open(String host, void Function(Uint8List) onData, void Function(Object, StackTrace) onError) async => null;
  @override
  void send(List<int> data, int toPort) {}
  @override
  void close() {}
}

/// The web has no UDP and no audio engine.
Future<FlexUdpSocket?> openFlexEngineSocket(
  AudioEngine engine,
  String host,
  void Function(Uint8List) onData,
  void Function(Object, StackTrace) onError,
) async => null;
