// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_remote_codec.dart';

// Synthetic packet builders exercise the documented envelope and PAN layout.
// The physical-capture test loads its original radio bytes separately.
Uint8List _frame(List<int> payload) => Uint8List.fromList([
  0xfe,
  0xfd,
  0xfc,
  0xfb,
  (payload.length >> 24) & 255,
  (payload.length >> 16) & 255,
  (payload.length >> 8) & 255,
  payload.length & 255,
  ...payload,
  0xfb,
  0xfc,
  0xfd,
  0xfe,
]);

Uint8List _pan({
  int count = 1024,
  int version = 0,
  int sequence = 17,
  int receiver = 0,
  int center = 14045000,
  int rateKhz = 96,
  int noiseTenths = -1316,
  int panType = 9,
  int declaredLength = 42,
}) {
  final bytes = Uint8List(27 + count);
  bytes.setRange(0, 5, [2, version, sequence, panType, receiver]);
  final data = ByteData.sublistView(bytes);
  data.setUint16(5, declaredLength, Endian.little);
  data.setInt64(11, center, Endian.little);
  data.setInt32(19, rateKhz, Endian.little);
  data.setInt32(23, noiseTenths, Endian.little);
  for (var i = 0; i < count; i++) {
    bytes[27 + i] = i & 255;
  }
  return _frame(bytes);
}

Uint8List _join(List<List<int>> parts) => Uint8List.fromList([for (final part in parts) ...part]);

void main() {
  test('physical K4 remote capture preserves both receivers and independently decoded PAN values', () {
    // Original radio bytes; expected values came from Python struct/hashlib,
    // not this decoder or the synthetic packet builder. See fixture README.
    final bytes = File('test/cat/fixtures/k4-remote/k4-remote-9204-main-sub.bin').readAsBytesSync();
    expect(bytes, hasLength(4252));
    final expected = [
      (
        receiver: 0,
        sequence: 133,
        center: 14234000,
        rate: 24000,
        noise: -139.7,
        min: -160,
        max: -96,
        header: '02008500000004000000009031d90000000000180000008bfaffff',
        bins: [-159, -144, -142, -141, -145, -159, -148],
      ),
      (
        receiver: 1,
        sequence: 134,
        center: 14045000,
        rate: 96000,
        noise: -113.4,
        min: -154,
        max: -75,
        header: '0200860001000400000000484fd600000000006000000092fbffff',
        bins: [-153, -154, -120, -101, -116, -154, -154],
      ),
      (
        receiver: 0,
        sequence: 135,
        center: 14234000,
        rate: 24000,
        noise: -139.3,
        min: -160,
        max: -102,
        header: '02008700000004000000009031d90000000000180000008ffaffff',
        bins: [-159, -156, -142, -140, -137, -151, -147],
      ),
      (
        receiver: 1,
        sequence: 136,
        center: 14045000,
        rate: 96000,
        noise: -113.4,
        min: -154,
        max: -74,
        header: '0200880001000400000000484fd600000000006000000092fbffff',
        bins: [-153, -154, -119, -98, -117, -153, -154],
      ),
    ];
    for (final width in [1, 7, 1059, 1063, bytes.length]) {
      final decoder = K4RemoteDecoder();
      final packets = <K4RemotePacket>[];
      for (var offset = 0; offset < bytes.length; offset += width) {
        final end = offset + width < bytes.length ? offset + width : bytes.length;
        packets.addAll(decoder.add(Uint8List.sublistView(bytes, offset, end)));
      }
      expect(packets, hasLength(4), reason: 'chunk width $width');
      for (var i = 0; i < expected.length; i++) {
        final packet = packets[i] as K4RemotePanPacket;
        final value = expected[i];
        expect(packet.receiver, value.receiver);
        expect(packet.sequence, value.sequence);
        expect(packet.version, 0);
        expect(packet.panType, 0);
        expect(packet.declaredDataLength, 1024);
        expect(packet.centerHz, value.center);
        expect(packet.sampleRateHz, value.rate);
        expect(packet.noiseFloorDb, value.noise);
        expect(packet.levels, hasLength(1024));
        expect([
          for (final index in [0, 1, 256, 512, 768, 1022, 1023]) packet.levels[index],
        ], value.bins);
        expect(packet.levels.reduce((a, b) => a < b ? a : b), value.min);
        expect(packet.levels.reduce((a, b) => a > b ? a : b), value.max);
        expect(packet.headerBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(), value.header);
        expect(packet.rawFrame, bytes.sublist(i * 1063, (i + 1) * 1063));
      }
      expect(decoder.pendingBytes, 0);
      expect(decoder.diagnostics.framesDecoded, 4);
      expect(decoder.diagnostics.panPackets, 4);
      expect(decoder.diagnostics.invalidLengths, 0);
      expect(decoder.diagnostics.invalidFooters, 0);
      expect(decoder.diagnostics.invalidPayloads, 0);
      expect(decoder.diagnostics.unsupportedVersions, 0);
      expect(decoder.diagnostics.discardedBytes, 0);
    }
  });

  test('the CAT writer matches the literal wire envelope and never accepts non-ASCII', () {
    expect(encodeK4RemoteCat('RDY;'.codeUnits), [0xfe, 0xfd, 0xfc, 0xfb, 0, 0, 0, 7, 0, 0, 0, 82, 68, 89, 59, 0xfb, 0xfc, 0xfd, 0xfe]);
    expect(() => encodeK4RemoteCat([0x80]), throwsArgumentError);
    expect(() => encodeK4RemoteCat([-1]), throwsArgumentError);
    expect(() => encodeK4RemoteCat(List.filled(k4RemoteMaxPayloadLength - 2, 65)), throwsArgumentError);
  });

  test('arbitrary fragmentation and concatenation preserve CAT command fragments and PAN packets', () {
    final frames = [
      _frame([0, 0, 0, ...'FA00014'.codeUnits]),
      _pan(),
      _frame([0, 0, 0, ...'045000;MD1;'.codeUnits]),
      _pan(count: 2048, receiver: 1),
    ];
    final bytes = _join(frames);
    for (final width in [1, 2, 3, 4, 5, 7, 8, 11, 257, bytes.length]) {
      final decoder = K4RemoteDecoder();
      final packets = <K4RemotePacket>[];
      for (var offset = 0; offset < bytes.length; offset += width) {
        final end = offset + width < bytes.length ? offset + width : bytes.length;
        packets.addAll(decoder.add(Uint8List.sublistView(bytes, offset, end)));
      }
      expect(packets, hasLength(4), reason: 'chunk width $width');
      expect(String.fromCharCodes((packets[0] as K4RemoteCatPacket).data), 'FA00014');
      expect(String.fromCharCodes((packets[2] as K4RemoteCatPacket).data), '045000;MD1;');
      expect((packets[1] as K4RemotePanPacket).levels, hasLength(1024));
      expect((packets[3] as K4RemotePanPacket).levels, hasLength(2048));
      for (var i = 0; i < packets.length; i++) {
        expect(packets[i].rawFrame, frames[i]);
      }
      expect(decoder.pendingBytes, 0);
      expect(decoder.diagnostics.framesDecoded, 4);
      expect(decoder.diagnostics.discardedBytes, 0);
    }
  });

  test('PAN integer byte order, kHz units and unsigned compressed levels are decoded independently', () {
    final decoder = K4RemoteDecoder();
    final packet = decoder.add(_pan(center: 14047440, rateKhz: 384, noiseTenths: -1234)).single as K4RemotePanPacket;
    expect(packet.centerHz, 14047440);
    expect(packet.sampleRateHz, 384000);
    expect(packet.noiseFloorDb, -123.4);
    expect(packet.receiver, 0);
    expect(packet.sequence, 17);
    expect(packet.levels[0], -160);
    expect(packet.levels[127], -33);
    expect(packet.levels[128], -32);
    expect(packet.levels[160], 0);
    expect(packet.levels[255], 95);
    expect(packet.headerBytes, hasLength(27));
    expect(packet.headerBytes.sublist(19, 23), [0x80, 1, 0, 0]);
  });

  test('opaque PAN header fields survive for capture validation instead of guessed rejection', () {
    final packet = K4RemoteDecoder().add(_pan(version: 255, panType: 23, declaredLength: 65535)).single as K4RemotePanPacket;
    expect(packet.version, 255);
    expect(packet.panType, 23);
    expect(packet.declaredDataLength, 65535);
    expect(packet.levels, hasLength(1024));
  });

  test('discarded audio, mini-pan and future types cannot leak embedded CAT into the command stream', () {
    final nested = _frame([0, 0, 0, ...'TX;'.codeUnits]);
    final decoder = K4RemoteDecoder();
    final packets = decoder.add(
      _join([
        _frame([1, 1, 6, ...nested]),
        _frame([3, 0, 7, ...nested]),
        _frame([99, 0, 8, ...nested]),
        _frame([0, 0, 0, ...'FA00014045000;'.codeUnits]),
      ]),
    );
    expect(packets, hasLength(1));
    expect(String.fromCharCodes((packets.single as K4RemoteCatPacket).data), 'FA00014045000;');
    expect(decoder.diagnostics.framesDecoded, 4);
    expect(decoder.diagnostics.audioPackets, 1);
    expect(decoder.diagnostics.miniPanPackets, 1);
    expect(decoder.diagnostics.unknownPackets, 1);
    expect(decoder.diagnostics.catPackets, 1);
  });

  test('malformed lengths and footer recover to a valid packet inside the rejected candidate', () {
    final good = _frame([0, 0, 0, ...'PING;'.codeUnits]);
    final badFooter = _frame([99, 0, 0, ...good])..last = 0;
    final decoder = K4RemoteDecoder();
    final packets = decoder.add(
      _join([
        [0, 1, 2, 0xfe, 0xfd],
        [0xfe, 0xfd, 0xfc, 0xfb, 0xff, 0xff, 0xff, 0xff],
        [0xfe, 0xfd, 0xfc, 0xfb, 0, 0, 0, 2],
        badFooter,
      ]),
    );
    expect(packets, hasLength(1));
    expect((packets.single as K4RemoteCatPacket).data, 'PING;'.codeUnits);
    expect(decoder.diagnostics.invalidLengths, 2);
    expect(decoder.diagnostics.invalidFooters, 1);
    expect(decoder.pendingBytes, 0);
  });

  test('unsupported CAT versions and non-ASCII are rejected without losing the next frame', () {
    final decoder = K4RemoteDecoder();
    final packets = decoder.add(
      _join([
        _frame([0, 1, 0, 65]),
        _frame([0, 0, 0, 255]),
        _frame([0, 0, 255, ...'RX;'.codeUnits]),
      ]),
    );
    expect(packets, hasLength(1));
    expect(packets.single.sequence, 255, reason: 'the incoming sequence is retained, not treated as a loss counter');
    expect(decoder.diagnostics.unsupportedVersions, 1);
    expect(decoder.diagnostics.invalidPayloads, 1);
  });

  test('PAN sanity checks reject incomplete, unbounded, and nonsensical metadata', () {
    final bad = [
      _frame([2, 0, 0]),
      _pan(count: 1),
      _pan(count: k4RemoteMaxPanBins + 1),
      _pan(receiver: 2),
      _pan(center: -1),
      _pan(rateKhz: 0),
      _pan(rateKhz: -1),
    ];
    final decoder = K4RemoteDecoder();
    final packets = decoder.add(_join([...bad, _pan(count: k4RemoteMaxPanBins)]));
    expect(packets, hasLength(1));
    expect((packets.single as K4RemotePanPacket).levels, hasLength(k4RemoteMaxPanBins));
    expect(decoder.diagnostics.invalidPayloads, bad.length);
  });

  test('the maximum permitted frame is bounded and a marker prefix survives long garbage', () {
    final decoder = K4RemoteDecoder();
    final maxAudio = _frame([1, 0, 0, ...List.filled(k4RemoteMaxPayloadLength - 3, 42)]);
    expect(decoder.add(Uint8List.sublistView(maxAudio, 0, maxAudio.length - 1)), isEmpty);
    expect(decoder.pendingBytes, maxAudio.length - 1);
    expect(decoder.add(Uint8List.sublistView(maxAudio, maxAudio.length - 1)), isEmpty);
    expect(decoder.pendingBytes, 0);
    expect(decoder.diagnostics.audioPackets, 1);
    final cat = _frame([0, 0, 0, 65]);
    decoder.add(Uint8List.fromList([...List.filled(k4RemoteMaxPayloadLength * 3, 0), ...cat.take(3)]));
    expect(decoder.pendingBytes, 3);
    expect(decoder.add(Uint8List.sublistView(cat, 3)), hasLength(1));
    expect(decoder.pendingBytes, 0);
  });

  test('packet snapshots survive later input and reset drops partial frames and diagnostics', () {
    final bytes = _pan();
    final decoder = K4RemoteDecoder();
    final packet = decoder.add(bytes).single as K4RemotePanPacket;
    final original = Uint8List.fromList(packet.rawFrame);
    bytes.fillRange(0, bytes.length, 0);
    decoder.add(_pan(receiver: 1));
    expect(packet.rawFrame, original);
    expect(packet.receiver, 0);
    expect(() => packet.rawFrame[0] = 0, throwsUnsupportedError);
    expect(() => packet.levels[0] = 0, throwsUnsupportedError);
    expect(() => packet.headerBytes[0] = 0, throwsUnsupportedError);
    final next = _pan();
    decoder.add(Uint8List.sublistView(next, 0, 100));
    expect(decoder.pendingBytes, 100);
    decoder.reset();
    expect(decoder.pendingBytes, 0);
    expect(decoder.diagnostics.framesDecoded, 0);
    expect(decoder.diagnostics.panPackets, 0);
    expect(decoder.add(Uint8List.sublistView(next, 100)), isEmpty);
    expect(decoder.add(next), hasLength(1));
  });
}
