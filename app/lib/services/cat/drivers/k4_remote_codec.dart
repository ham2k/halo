// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
//
// Elecraft K4-Remote Protocol A1 framing. docs/design/k4-remote.md records the
// PAN fields that still need confirmation against a live hardware capture.

import 'dart:typed_data';

/// Resource limits, not claims about the wire's unsigned length field.
const k4RemoteMaxPayloadLength = 65536;
const k4RemoteMaxPanBins = 4096;

const _begin = [0xfe, 0xfd, 0xfc, 0xfb];
const _end = [0xfb, 0xfc, 0xfd, 0xfe];
const _envelopeLength = 12;
const _panHeaderLength = 27;

sealed class K4RemotePacket {
  final int version;
  final int sequence;

  /// A copied, read-only envelope for capture/replay. Audio is never retained.
  final Uint8List rawFrame;

  const K4RemotePacket._({required this.version, required this.sequence, required this.rawFrame});
}

class K4RemoteCatPacket extends K4RemotePacket {
  /// Unwrapped ASCII, which can contain part of a CAT command or several.
  final Uint8List data;

  const K4RemoteCatPacket._({required super.version, required super.sequence, required super.rawFrame, required this.data}) : super._();
}

class K4RemotePanPacket extends K4RemotePacket {
  /// 0 is the main receiver; 1 is the sub receiver.
  final int receiver;
  final int centerHz;
  final int sampleRateHz;
  final double noiseFloorDb;
  final Float32List levels;

  /// Preserved as opaque metadata: A1 does not settle their interpretation.
  final int panType;
  final int declaredDataLength;
  final Uint8List headerBytes;

  const K4RemotePanPacket._({
    required super.version,
    required super.sequence,
    required super.rawFrame,
    required this.receiver,
    required this.centerHz,
    required this.sampleRateHz,
    required this.noiseFloorDb,
    required this.levels,
    required this.panType,
    required this.declaredDataLength,
    required this.headerBytes,
  }) : super._();
}

class K4RemoteDiagnostics {
  /// Complete envelopes, including unsupported and rejected payloads.
  final int framesDecoded;
  final int catPackets;
  final int panPackets;
  final int audioPackets;
  final int miniPanPackets;
  final int unknownPackets;
  final int invalidLengths;
  final int invalidFooters;
  final int invalidPayloads;
  final int unsupportedVersions;
  final int discardedBytes;

  const K4RemoteDiagnostics._({
    required this.framesDecoded,
    required this.catPackets,
    required this.panPackets,
    required this.audioPackets,
    required this.miniPanPackets,
    required this.unknownPackets,
    required this.invalidLengths,
    required this.invalidFooters,
    required this.invalidPayloads,
    required this.unsupportedVersions,
    required this.discardedBytes,
  });
}

/// Bounded framing for the shared CAT, audio and spectrum stream.
///
/// Unsupported types are consumed as complete envelopes, never searched as
/// though their payload bytes were CAT or new packet markers. A bad envelope
/// is resynchronized from its next byte, so a corrupt length cannot swallow a
/// valid packet inside the bytes it claimed.
class K4RemoteDecoder {
  final _buffer = Uint8List(k4RemoteMaxPayloadLength + _envelopeLength);
  int _pending = 0;
  int _framesDecoded = 0;
  int _catPackets = 0;
  int _panPackets = 0;
  int _audioPackets = 0;
  int _miniPanPackets = 0;
  int _unknownPackets = 0;
  int _invalidLengths = 0;
  int _invalidFooters = 0;
  int _invalidPayloads = 0;
  int _unsupportedVersions = 0;
  int _discardedBytes = 0;

  int get pendingBytes => _pending;

  K4RemoteDiagnostics get diagnostics => K4RemoteDiagnostics._(
    framesDecoded: _framesDecoded,
    catPackets: _catPackets,
    panPackets: _panPackets,
    audioPackets: _audioPackets,
    miniPanPackets: _miniPanPackets,
    unknownPackets: _unknownPackets,
    invalidLengths: _invalidLengths,
    invalidFooters: _invalidFooters,
    invalidPayloads: _invalidPayloads,
    unsupportedVersions: _unsupportedVersions,
    discardedBytes: _discardedBytes,
  );

  List<K4RemotePacket> add(Uint8List chunk) {
    final packets = <K4RemotePacket>[];
    var offset = 0;
    while (offset < chunk.length) {
      final room = _buffer.length - _pending;
      final remaining = chunk.length - offset;
      final count = room < remaining ? room : remaining;
      _buffer.setRange(_pending, _pending + count, chunk, offset);
      _pending += count;
      offset += count;
      _drain(packets);
    }
    return packets;
  }

  void _drain(List<K4RemotePacket> packets) {
    while (_pending > 0) {
      final start = _findBegin();
      if (start < 0) {
        var keep = _pending < _begin.length ? _pending : _begin.length - 1;
        while (keep > 0 && !_matches(_begin, _pending - keep, keep)) {
          keep--;
        }
        _consume(_pending - keep, discarded: true);
        return;
      }
      if (start > 0) _consume(start, discarded: true);
      if (_pending < 8) return;
      final length = ByteData.sublistView(_buffer).getUint32(4, Endian.big);
      if (length < 3 || length > k4RemoteMaxPayloadLength) {
        _invalidLengths++;
        _consume(1, discarded: true);
        continue;
      }
      final frameLength = length + _envelopeLength;
      if (_pending < frameLength) return;
      if (!_matches(_end, 8 + length, _end.length)) {
        _invalidFooters++;
        _consume(1, discarded: true);
        continue;
      }
      _framesDecoded++;
      final packet = _payload(length);
      if (packet != null) packets.add(packet);
      _consume(frameLength);
    }
  }

  K4RemotePacket? _payload(int length) {
    final payload = Uint8List.sublistView(_buffer, 8, 8 + length);
    final version = payload[1], sequence = payload[2];
    switch (payload[0]) {
      case 0:
        if (version != 0) {
          _unsupportedVersions++;
          return null;
        }
        if (payload.skip(3).any((byte) => byte > 0x7f)) {
          _invalidPayloads++;
          return null;
        }
        _catPackets++;
        final raw = _copyFrame(length);
        return K4RemoteCatPacket._(version: version, sequence: sequence, rawFrame: raw, data: Uint8List.sublistView(raw, 11, 8 + length).asUnmodifiableView());
      case 1:
        _audioPackets++;
        return null;
      case 2:
        final count = length - _panHeaderLength;
        if (count < 2 || count > k4RemoteMaxPanBins || payload[4] > 1) {
          _invalidPayloads++;
          return null;
        }
        final data = ByteData.sublistView(payload);
        final center = data.getInt64(11, Endian.little);
        final rateKhz = data.getInt32(19, Endian.little);
        if (center < 0 || rateKhz <= 0) {
          _invalidPayloads++;
          return null;
        }
        final levels = Float32List(count);
        for (var i = 0; i < count; i++) {
          // A1 expresses this as tenths: (byte - 160) * 10. The display
          // consumes dB on the wire's scale, without an RF calibration claim.
          levels[i] = payload[_panHeaderLength + i] - 160;
        }
        _panPackets++;
        final raw = _copyFrame(length);
        return K4RemotePanPacket._(
          version: version,
          sequence: sequence,
          rawFrame: raw,
          receiver: payload[4],
          centerHz: center,
          sampleRateHz: rateKhz * 1000,
          noiseFloorDb: data.getInt32(23, Endian.little) / 10,
          levels: levels.asUnmodifiableView(),
          panType: payload[3],
          declaredDataLength: data.getUint16(5, Endian.little),
          headerBytes: Uint8List.sublistView(raw, 8, 8 + _panHeaderLength).asUnmodifiableView(),
        );
      case 3:
        _miniPanPackets++;
        return null;
      default:
        _unknownPackets++;
        return null;
    }
  }

  Uint8List _copyFrame(int length) => Uint8List.fromList(Uint8List.sublistView(_buffer, 0, length + _envelopeLength)).asUnmodifiableView();

  int _findBegin() {
    for (var i = 0; i <= _pending - _begin.length; i++) {
      if (_matches(_begin, i, _begin.length)) return i;
    }
    return -1;
  }

  bool _matches(List<int> marker, int offset, int length) {
    for (var i = 0; i < length; i++) {
      if (_buffer[offset + i] != marker[i]) return false;
    }
    return true;
  }

  void _consume(int count, {bool discarded = false}) {
    if (count == 0) return;
    _pending -= count;
    if (discarded) _discardedBytes += count;
    _buffer.setRange(0, _pending, _buffer, count);
  }

  void reset() {
    _pending = 0;
    _framesDecoded = 0;
    _catPackets = 0;
    _panPackets = 0;
    _audioPackets = 0;
    _miniPanPackets = 0;
    _unknownPackets = 0;
    _invalidLengths = 0;
    _invalidFooters = 0;
    _invalidPayloads = 0;
    _unsupportedVersions = 0;
    _discardedBytes = 0;
  }
}

/// Wraps only ASCII CAT commands. There is deliberately no audio writer.
Uint8List encodeK4RemoteCat(List<int> asciiBytes) {
  if (asciiBytes.length > k4RemoteMaxPayloadLength - 3) throw ArgumentError.value(asciiBytes.length, 'asciiBytes.length', 'CAT packet is too large');
  if (asciiBytes.any((byte) => byte < 0 || byte > 0x7f)) throw ArgumentError('CAT commands must contain only ASCII bytes');
  final length = asciiBytes.length + 3;
  final result = Uint8List(length + _envelopeLength);
  result.setRange(0, _begin.length, _begin);
  ByteData.sublistView(result).setUint32(4, length, Endian.big);
  // TYPE, VER and SEQ are all zero for outbound CAT.
  result.setRange(11, 11 + asciiBytes.length, asciiBytes);
  result.setRange(8 + length, result.length, _end);
  return result;
}
