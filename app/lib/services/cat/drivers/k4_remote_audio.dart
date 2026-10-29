// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A K4's transmit audio over the secure remote connection, sent by this app
// itself — docs/design/cat.md § The computer's voice keyer, and
// docs/design/k4-remote.md § Transmit audio. The recording goes as raw
// 16-bit packets at 12 kHz, mono copied to both channels, while the
// connection's EM is set to that format for the message.
//
// Every packet keys the radio, so nothing goes out but the message: no
// silence ahead of the key or after the unkey.
//
// Not yet met on hardware: the packet layout is from QK4's source (GPL-3.0,
// read for the facts of the format; none of its code is copied).

import 'dart:typed_data';

import 'k4_remote_codec.dart';
import 'paced_transmit_audio.dart';

/// Frames a packet: 60 ms, what the K4 bundles at its default streaming
/// latency (SL3).
const k4RemoteAudioFrames = 720;

class K4RemoteAudioOutput extends PacedTransmitAudio {
  K4RemoteAudioOutput({required this.send, required super.decode, super.clockMicros})
    // One packet ahead of the one playing, not three: at 60 ms a packet the
    // radio would have a quarter of a second left to play when the end is
    // reported, longer than the keyer's unkey delay, and `RX;` follows the
    // audio down the same stream.
    : super(rate: k4RemoteAudioRate, channels: 1, framesPerPacket: k4RemoteAudioFrames, ahead: 2, feedsSilence: false);

  final void Function(Uint8List envelope) send;

  int _sequence = 0;

  /// A new transmission: its packets are numbered from 0.
  void keyed() => _sequence = 0;

  @override
  bool get ready => true;

  @override
  String get reportContext => 'k4:remote-audio';

  @override
  void sendFrames(Float32List? samples) {
    final stereo = Int16List(k4RemoteAudioFrames * 2);
    if (samples != null) {
      for (var i = 0; i < samples.length; i++) {
        final sample = samples[i];
        // A NaN would throw from round() inside the pacing timer, every tick.
        if (sample.isNaN) continue;
        final value = (sample.clamp(-1.0, 1.0) * 32767).round();
        stereo[i * 2] = value;
        stereo[i * 2 + 1] = value;
      }
    }
    send(encodeK4RemoteAudio(sequence: _sequence++, frames: k4RemoteAudioFrames, samples: stereo));
  }
}
