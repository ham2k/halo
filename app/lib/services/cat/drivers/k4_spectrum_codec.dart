// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0
//
// K4 LAN spectrum byte format; hardware fixtures live in
// test/cat/fixtures/k4-spectrum/. Decoding makes no claim about the display's
// calibration or frequency window. Uninterpreted header bytes remain
// available to the capture tool.

import 'dart:typed_data';

const k4SpectrumHeaderLength = 64;
const k4SpectrumBinCount = 2048;
const k4SpectrumPacketLength = k4SpectrumHeaderLength + k4SpectrumBinCount * 2 + 2;
const k4SpectrumVersion = 2;

const _sync = [0xff, 0xfe, 0x01, 0x00];
const _panIds = {0x41, 0x42, 0x59, 0x5a}; // A, B, Y, Z.
final _integerField = RegExp(r'^ *[+-]?[0-9]+ *$');

/// One checksum-verified packet. Levels and noise floor are the wire's signed
/// tenths converted to dB; no calibration offset or display scale is applied.
class K4SpectrumPacket {
  final int sequence;
  final String panId;
  final int sampleRateHz;
  final int centerHz;
  final double noiseFloorDb;
  final Float32List levels;

  /// A copied, read-only header, including fields whose meaning is not known.
  final Uint8List headerBytes;

  const K4SpectrumPacket._({
    required this.sequence,
    required this.panId,
    required this.sampleRateHz,
    required this.centerHz,
    required this.noiseFloorDb,
    required this.levels,
    required this.headerBytes,
  });
}

/// A snapshot of framing results since the decoder was created or reset.
/// Rejections count candidate headers, not presumed lost radio sweeps.
class K4SpectrumDiagnostics {
  final int framesDecoded;
  final int discardedBytes;
  final int invalidHeaders;
  final int invalidPayloadChecksums;
  final int unsupportedVersions;
  final int unsupportedPanIds;

  const K4SpectrumDiagnostics._({
    required this.framesDecoded,
    required this.discardedBytes,
    required this.invalidHeaders,
    required this.invalidPayloadChecksums,
    required this.unsupportedVersions,
    required this.unsupportedPanIds,
  });
}

typedef _Header = ({int sequence, String panId, int sampleRateHz, int centerHz, double noiseFloorDb});

/// Incremental framing for the K4's separate LAN spectrum byte stream.
///
/// The retained buffer is one packet, regardless of input chunk size. A bad
/// candidate advances only one byte before searching again: a real packet's
/// sync can occur inside the bytes a damaged header claimed as its payload.
class K4SpectrumDecoder {
  final _buffer = Uint8List(k4SpectrumPacketLength);
  int _pending = 0;
  _Header? _header;
  int _framesDecoded = 0;
  int _discardedBytes = 0;
  int _invalidHeaders = 0;
  int _invalidPayloadChecksums = 0;
  int _unsupportedVersions = 0;
  int _unsupportedPanIds = 0;

  int get pendingBytes => _pending;

  K4SpectrumDiagnostics get diagnostics => K4SpectrumDiagnostics._(
    framesDecoded: _framesDecoded,
    discardedBytes: _discardedBytes,
    invalidHeaders: _invalidHeaders,
    invalidPayloadChecksums: _invalidPayloadChecksums,
    unsupportedVersions: _unsupportedVersions,
    unsupportedPanIds: _unsupportedPanIds,
  );

  /// Returns complete valid packets in arrival order. Sequence bytes are
  /// preserved, including repeats and wraparound; they imply no drop policy.
  List<K4SpectrumPacket> add(Uint8List chunk) {
    final packets = <K4SpectrumPacket>[];
    var offset = 0;
    while (offset < chunk.length) {
      final remaining = chunk.length - offset;
      final available = _buffer.length - _pending;
      final take = remaining < available ? remaining : available;
      _buffer.setRange(_pending, _pending + take, chunk, offset);
      _pending += take;
      offset += take;
      _drain(packets);
    }
    return packets;
  }

  void _drain(List<K4SpectrumPacket> packets) {
    while (_pending > 0) {
      if (_header == null) {
        final start = _findSync();
        if (start < 0) {
          // Only a suffix matching the next packet's sync can be useful.
          var keep = _pending < _sync.length ? _pending : _sync.length - 1;
          while (keep > 0 && !_matchesSync(_pending - keep, keep)) {
            keep--;
          }
          _discard(_pending - keep);
          return;
        }
        if (start > 0) _discard(start);
        if (_pending < k4SpectrumHeaderLength) return;
        _header = _readHeader();
        if (_header == null) {
          _discard(1);
          continue;
        }
      }
      if (_pending < k4SpectrumPacketLength) return;
      final data = ByteData.sublistView(_buffer);
      final payloadEnd = k4SpectrumPacketLength - 2;
      if (k4SpectrumCrc16(Uint8List.sublistView(_buffer, 0, payloadEnd)) != data.getUint16(payloadEnd, Endian.big)) {
        _invalidPayloadChecksums++;
        _discard(1);
        continue;
      }
      final header = _header!;
      final levels = Float32List(k4SpectrumBinCount);
      for (var i = 0; i < levels.length; i++) {
        levels[i] = data.getInt16(k4SpectrumHeaderLength + i * 2, Endian.big) / 10;
      }
      packets.add(
        K4SpectrumPacket._(
          sequence: header.sequence,
          panId: header.panId,
          sampleRateHz: header.sampleRateHz,
          centerHz: header.centerHz,
          noiseFloorDb: header.noiseFloorDb,
          levels: levels.asUnmodifiableView(),
          headerBytes: Uint8List.fromList(_buffer.sublist(0, k4SpectrumHeaderLength)).asUnmodifiableView(),
        ),
      );
      _framesDecoded++;
      _pending = 0;
      _header = null;
    }
  }

  _Header? _readHeader() {
    var sum = 0;
    for (var i = 0; i < k4SpectrumHeaderLength; i++) {
      sum += _buffer[i];
    }
    if (sum & 0xff != 0) {
      _invalidHeaders++;
      return null;
    }
    if (_buffer[4] != k4SpectrumVersion) {
      _unsupportedVersions++;
      return null;
    }
    if (!_panIds.contains(_buffer[6])) {
      _unsupportedPanIds++;
      return null;
    }
    final rate = _readInteger(7, 13);
    final center = _readInteger(13, 24);
    final noise = _readInteger(24, 29);
    if (rate == null || rate <= 0 || center == null || center < 0 || noise == null) {
      _invalidHeaders++;
      return null;
    }
    return (sequence: _buffer[5], panId: String.fromCharCode(_buffer[6]), sampleRateHz: rate, centerHz: center, noiseFloorDb: noise / 10);
  }

  int? _readInteger(int start, int end) {
    final field = String.fromCharCodes(_buffer.sublist(start, end));
    final match = _integerField.firstMatch(field);
    return match != null && match.end == field.length ? int.tryParse(field.trim()) : null;
  }

  int _findSync() {
    for (var i = 0; i <= _pending - _sync.length; i++) {
      if (_matchesSync(i, _sync.length)) return i;
    }
    return -1;
  }

  bool _matchesSync(int offset, int length) {
    for (var i = 0; i < length; i++) {
      if (_buffer[offset + i] != _sync[i]) return false;
    }
    return true;
  }

  void _discard(int count) {
    if (count == 0) return;
    _pending -= count;
    _discardedBytes += count;
    _buffer.setRange(0, _pending, _buffer, count);
    _header = null;
  }

  /// Starts a fresh stream, discarding any partial packet and diagnostics.
  void reset() {
    _pending = 0;
    _header = null;
    _framesDecoded = 0;
    _discardedBytes = 0;
    _invalidHeaders = 0;
    _invalidPayloadChecksums = 0;
    _unsupportedVersions = 0;
    _unsupportedPanIds = 0;
  }
}

/// CRC-16/IBM-SDLC (X-25): reflected polynomial 0x8408, initial value 0xffff,
/// final XOR 0xffff. The packet footer stores this result most significant
/// byte first, independently of the bit order used to compute it.
int k4SpectrumCrc16(Uint8List bytes) {
  var crc = 0xffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = crc & 1 != 0 ? (crc >> 1) ^ 0x8408 : crc >> 1;
    }
  }
  return crc ^ 0xffff;
}
