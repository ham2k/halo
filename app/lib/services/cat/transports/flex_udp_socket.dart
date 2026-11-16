// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The UDP socket a FlexRadio session's `client udpport` names: the radio
// sends it the meters, the panadapter and the DAX audio, and the session
// sends its DAX transmit audio from it.

import 'dart:typed_data';

import 'package:halo_audio/halo_audio.dart' show AudioSocket;

abstract interface class FlexUdpSocket {
  int get port;

  /// Sends [data] to the radio's UDP [toPort].
  void send(List<int> data, int toPort);

  void close();

  /// The audio engine's socket underneath, for a stream the engine claims
  /// (a slice's `dax_rx`); null for a socket the engine does not own.
  AudioSocket? get audioSocket;

  /// The radio's numeric address, which the engine sends a stream to.
  String get radioAddress;
}

/// The audio engine binds IPv4 only, and the radio's address is not one:
/// the meters and the spectrum still work, on a socket of their own, and
/// the audio cannot.
class FlexAudioNeedsIpv4 implements Exception {
  final String address;
  const FlexAudioNeedsIpv4(this.address);

  @override
  String toString() => 'FlexAudioNeedsIpv4: the audio engine binds IPv4 only, and the radio is at $address';
}

/// Opens a [FlexUdpSocket] to [host]: [onData] gets every datagram the radio
/// sends it that nothing else claims.
typedef FlexUdpSocketOpener =
    Future<FlexUdpSocket?> Function(String host, void Function(Uint8List data) onData, void Function(Object error, StackTrace stack) onError);
