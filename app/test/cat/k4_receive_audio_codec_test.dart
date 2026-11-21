// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_remote_codec.dart';

Uint8List _envelope(List<int> payload) {
  final bytes = Uint8List(payload.length + 12);
  bytes.setRange(0, 4, [0xfe, 0xfd, 0xfc, 0xfb]);
  ByteData.sublistView(bytes).setUint32(4, payload.length, Endian.big);
  bytes.setRange(8, bytes.length - 4, payload);
  bytes.setRange(bytes.length - 4, bytes.length, [0xfb, 0xfc, 0xfd, 0xfe]);
  return bytes;
}

// The receive layout is assembled independently of the transmit writer.
Uint8List _audio(List<int> samples, {int encoding = 1, int version = 1, int rate = 0, int sequence = 7, int? frames}) {
  final bytesPerSample = encoding == 0 ? 4 : 2;
  final payload = Uint8List(7 + samples.length * bytesPerSample);
  payload.setRange(0, 4, [1, version, sequence, encoding]);
  final data = ByteData.sublistView(payload);
  data.setUint16(4, frames ?? samples.length ~/ 2, Endian.little);
  payload[6] = rate;
  for (var i = 0; i < samples.length; i++) {
    if (bytesPerSample == 2) {
      data.setInt16(7 + i * bytesPerSample, samples[i], Endian.little);
    } else {
      data.setInt32(7 + i * bytesPerSample, samples[i], Endian.little);
    }
  }
  return _envelope(payload);
}

void main() {
  test('raw16 preserves signed stereo samples and exposes no audio capture envelope', () {
    final decoder = K4RemoteDecoder()..decodeAudio = true;
    final wire = _audio([-32768, 32767, 1024, -2048], sequence: 255);
    final packet = decoder.add(wire).single as K4RemoteAudioPacket;
    expect((packet.version, packet.sequence, packet.encoding, packet.frames, packet.sampleRateHz), (1, 255, 1, 2, 12000));
    expect(packet.samples, [-1, 32767 / 32768, 1 / 32, -1 / 16]);
    expect(packet.rawFrame, isEmpty);
    expect(() => packet.samples[0] = 0, throwsUnsupportedError);
    wire.fillRange(0, wire.length, 0);
    decoder.add(_audio([0, 0]));
    expect(packet.samples.first, -1, reason: 'the next socket read must not overwrite a delivered block');
  });

  test('raw32 carries signed 24-bit integers at 256 times the raw16 scale', () {
    final decoder = K4RemoteDecoder()..decodeAudio = true;
    final raw16 = decoder.add(_audio([-32768, 32767, -123, 456])).single as K4RemoteAudioPacket;
    final raw32 = decoder.add(_audio([-8388608, 8388352, -31488, 116736], encoding: 0)).single as K4RemoteAudioPacket;
    expect(raw32.encoding, 0);
    expect(raw32.samples, raw16.samples);
    final precise = decoder.add(_audio([1, -1], encoding: 0)).single as K4RemoteAudioPacket;
    expect(precise.samples, [1 / 8388608, -1 / 8388608], reason: 'EM0 preserves the low bits of its integer container');
  });

  test('unwatched audio is counted and consumed without retaining or decoding its samples', () {
    final decoder = K4RemoteDecoder();
    expect(decoder.add(_audio([123, -123])), isEmpty);
    expect(decoder.diagnostics.audioPackets, 1);
    decoder.decodeAudio = true;
    expect(decoder.add(_audio([456, -456])).single, isA<K4RemoteAudioPacket>());
    decoder.decodeAudio = false;
    expect(decoder.add(_audio([789, -789])), isEmpty);
    expect(decoder.diagnostics.audioPackets, 3);
  });

  test('malformed and unsupported audio cannot leak nested CAT or poison the next block', () {
    final decoder = K4RemoteDecoder()..decodeAudio = true;
    final nested = _envelope([0, 0, 0, ...'TX;'.codeUnits]);
    final wire = Uint8List.fromList([
      ..._envelope([1, 1, 0]),
      ..._audio([1, 2], frames: 2),
      ..._audio([1, 2], frames: 0),
      ..._audio([1, 2], rate: 1),
      ..._audio([1, 2], version: 255),
      ..._envelope([1, 1, 0, 3, 1, 0, 0, ...nested]),
      ..._envelope([0, 0, 0, ...'RX;'.codeUnits]),
      ..._audio([32767, -32768]),
    ]);
    final packets = decoder.add(wire);
    expect(packets, hasLength(2));
    expect(String.fromCharCodes((packets.first as K4RemoteCatPacket).data), 'RX;');
    expect((packets.last as K4RemoteAudioPacket).samples, [32767 / 32768, -1]);
    expect(decoder.diagnostics.invalidPayloads, 4);
    expect(decoder.diagnostics.unsupportedVersions, 1);
    expect(decoder.pendingBytes, 0);
  });

  test('fragmented audio packets retain channel order across a coalesced CAT response', () {
    final decoder = K4RemoteDecoder()..decodeAudio = true;
    final wire = Uint8List.fromList([
      ..._audio([256, -256]),
      ..._envelope([0, 0, 0, ...'PONG;'.codeUnits]),
      ..._audio([-512, 512]),
    ]);
    final packets = <K4RemotePacket>[];
    for (var offset = 0; offset < wire.length; offset += 5) {
      packets.addAll(decoder.add(Uint8List.sublistView(wire, offset, (offset + 5).clamp(0, wire.length))));
    }
    expect(packets.map((packet) => packet.runtimeType), [K4RemoteAudioPacket, K4RemoteCatPacket, K4RemoteAudioPacket]);
    expect((packets.first as K4RemoteAudioPacket).samples, [1 / 128, -1 / 128]);
    expect((packets.last as K4RemoteAudioPacket).samples, [-1 / 64, 1 / 64]);
  });
}
