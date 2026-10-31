// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio's DAX transmit audio, sent by this app itself — docs/design/cat.md
// § The computer's voice keyer.
//
// Captured on a FLEX-6600 (4.2.20): a bound client's `stream create
// type=dax_tx` answers with a stream that client owns (`tx=0`), `stream set
// <id> tx=1` makes it the radio's DAX transmit source, and with `transmit
// dax=1` the radio puts on the air what arrives on it at UDP 4991. The
// payload is what the radio's own DAX audio carries (`dax_rx`, class
// 0x534C03E3: 128 frames of 24 kHz stereo float32, big-endian), but the
// packet is VITA type 1, IF data with a stream id: sent as type 3, the type
// the radio's own audio packets carry, the radio transmits nothing.
//
// Through a GUI client's virtual sound device instead, the audio depends on
// that client's own DAX transmit — AetherSDR's "TX" device does not reach the
// transmitter on that radio — and the operator has one more device to pick.

import 'dart:async';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show realNowMillis;

import 'paced_transmit_audio.dart';

const flexDaxRate = 24000;
const flexDaxChannels = 2;
const flexDaxPort = 4991;
const _framesPerPacket = 128;

/// How far the operator's monitor trails the packets, by ear on a FLEX-6600
/// (4.2.20) heard through SmartSDR's monitor: the radio's DAX buffer and the
/// monitor's way back. Nothing the radio reports says when its audio is on
/// the air, and the words shown ahead of it read as said before they are.
const flexDaxHeardAfter = Duration(milliseconds: 200);

/// How long the radio has to answer `stream create` before the output is
/// given up: unanswered, the keyer would key a radio that never gets its
/// audio.
const flexDaxGrantTimeout = Duration(seconds: 2);

class FlexDaxOutput extends PacedTransmitAudio {
  FlexDaxOutput({required this.send, required this.sendPacket, required super.decode, this.diagnose, super.clockMicros})
    : super(rate: flexDaxRate, channels: flexDaxChannels, framesPerPacket: _framesPerPacket, heardAfter: flexDaxHeardAfter) {
    _create();
  }

  /// A command to the radio; [onReply] gets the answer's code and body.
  final void Function(String command, {void Function(int code, String body)? onReply}) send;

  /// A packet to the radio's [flexDaxPort].
  final void Function(Uint8List packet) sendPacket;

  /// Why the radio would not take the audio, for the CAT recording.
  final void Function(String what)? diagnose;

  int? _streamId;
  Timer? _grant;
  int _count = 0;
  int _frames = 0;

  void _create() {
    _grant = Timer(flexDaxGrantTimeout, () {
      if (closed || _streamId != null) return;
      diagnose?.call('no answer to stream create in ${flexDaxGrantTimeout.inSeconds} s');
      lost();
    });
    send(
      'stream create type=dax_tx',
      onReply: (code, body) {
        _grant?.cancel();
        final id = int.tryParse(body.trim().replaceFirst('0x', ''), radix: 16);
        if (closed) {
          if (code == 0 && id != null) send('stream remove ${_hex(id)}');
          return;
        }
        if (code != 0 || id == null) return _refused('stream create', code, body);
        _streamId = id;
        // Made the radio's source only for a message on its way: claimed
        // while idle, it takes the DAX transmit audio of a digital-mode
        // program on the same radio for as long as the stream stays open.
        if (running) _claim(id);
      },
    );
  }

  /// The stream made the radio's DAX transmit source. Refused, the radio
  /// transmits some other client's audio, or none.
  void _claim(int id) => send(
    'stream set ${_hex(id)} tx=1',
    onReply: (code, body) {
      if (code != 0 && !closed) _refused('stream set tx=1', code, body);
    },
  );

  void _refused(String command, int code, String body) {
    diagnose?.call('$command refused: ${code.toRadixString(16).padLeft(8, '0')} ${body.trim()}'.trim());
    lost();
  }

  /// Nothing is sent before the radio has said which stream is ours.
  @override
  bool get ready => _streamId != null;

  @override
  String get reportContext => 'flex:dax-tx';

  /// Claimed again for each message: another client may have made its own
  /// stream the source since.
  @override
  void starting() {
    if (_streamId case final id?) _claim(id);
  }

  @override
  void lost() {
    _grant?.cancel();
    super.lost();
  }

  @override
  void closing() {
    _grant?.cancel();
    if (_streamId case final id?) send('stream remove ${_hex(id)}');
  }

  /// One VITA-49 packet: type 1 with class id, UTC seconds and a sample
  /// count; silence for null [samples].
  @override
  void sendFrames(Float32List? samples) {
    final data = ByteData(28 + _framesPerPacket * flexDaxChannels * 4);
    data.setUint32(0, (1 << 28) | (1 << 27) | (1 << 22) | (1 << 20) | ((_count & 15) << 16) | data.lengthInBytes ~/ 4);
    data.setUint32(4, _streamId!);
    data.setUint32(8, 0x00001C2D);
    data.setUint32(12, 0x534C03E3);
    data.setUint32(16, realNowMillis() ~/ 1000);
    // Two halves rather than setUint64, which the web build has not got.
    data.setUint32(20, _frames ~/ 0x100000000);
    data.setUint32(24, _frames % 0x100000000);
    if (samples != null) {
      for (var i = 0; i < samples.length; i++) {
        data.setFloat32(28 + i * 4, samples[i]);
      }
    }
    sendPacket(data.buffer.asUint8List());
    _count++;
    _frames += _framesPerPacket;
  }

  static String _hex(int id) => '0x${id.toRadixString(16).padLeft(8, '0')}';
}
