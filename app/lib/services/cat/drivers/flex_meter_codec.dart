// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'dart:math' as math;
import 'dart:typed_data';

/// SmartSDR Metering Protocol: metadata identifies transient meters — the
/// slice's LEVEL, the transmitter's FWDPWR and SWR — and VITA-49 packets carry
/// signed values with seven fraction bits.
/// https://github.com/flexradio/smartsdr-api-docs/wiki/Metering-Protocol
class FlexMeterCodec {
  final int slice;
  final _metadata = <int, Map<String, String>>{};
  FlexMeterCodec(this.slice);

  void metadata(String text) {
    final removed = RegExp(r'^(\d+) removed$').firstMatch(text.trim());
    if (removed != null) {
      _metadata.remove(int.parse(removed[1]!));
      return;
    }
    for (final field in text.split('#')) {
      final match = RegExp(r'^\s*(\d+)\.(\w+)=(.*)$').firstMatch(field);
      if (match == null) continue;
      final id = int.parse(match[1]!);
      if (!_metadata.containsKey(id) && _metadata.length >= 1024) continue;
      (_metadata[id] ??= {})[match[2]!] = match[3]!.trim();
    }
  }

  double? signal(Uint8List packet) {
    double? result;
    for (final (m, value) in _readings(packet)) {
      if (m['src'] == 'SLC' && m['num'] == '$slice' && m['nam'] == 'LEVEL' && m['unit']?.toLowerCase() == 'dbm') result = value;
    }
    return result;
  }

  /// RF out in watts and SWR, from the transmitter's FWDPWR (dBm) and SWR
  /// meters — each null where [packet] carries no reading of it.
  ({double? watts, double? swr}) transmit(Uint8List packet) {
    double? watts, swr;
    for (final (m, value) in _readings(packet)) {
      if (m['src'] != 'TX-') continue;
      if (m['nam'] == 'FWDPWR' && m['unit']?.toLowerCase() == 'dbm') watts = math.pow(10, (value - 30) / 10).toDouble();
      if (m['nam'] == 'SWR' && m['unit']?.toUpperCase() == 'SWR') swr = value;
    }
    return (watts: watts, swr: swr);
  }

  /// Every reading in [packet] of a meter whose metadata is known.
  List<(Map<String, String>, double)> _readings(Uint8List packet) {
    if (packet.length < 16) return const [];
    final data = ByteData.sublistView(packet), header = ByteData.sublistView(packet).getUint32(0);
    final length = (header & 0xffff) * 4;
    // Extension-data packet, stream ID and class ID, Flex OUI, meter class.
    if (header >> 28 != 3 ||
        header & 0x08000000 == 0 ||
        length > packet.length ||
        length < 16 ||
        data.getUint32(8) & 0xffffff != 0x001c2d ||
        data.getUint16(14) != 0x8002) {
      return const [];
    }
    var offset = 16;
    if ((header >> 22) & 3 != 0) offset += 4;
    if ((header >> 20) & 3 != 0) offset += 8;
    final end = length - (header & 0x04000000 != 0 ? 4 : 0);
    if (offset > end || (end - offset) % 4 != 0) return const [];
    return [
      for (; offset + 4 <= end; offset += 4)
        if (_metadata[data.getUint16(offset)] case final m?) (m, data.getInt16(offset + 2) / 128),
    ];
  }
}

/// What of the LEVEL stream is worth reporting.
///
/// The radio pushes LEVEL many times a second at 1/128 dB, so nearly every
/// packet differs from the last — and a CHANGED meter notifies every
/// CatService listener, for as long as the radio is connected. Whole dB a few
/// times a second is all a display resolves, and lets a steady signal be the
/// unchanged reading CatService does not notify for.
///
/// Still reported while unchanged: the reading's timestamp is what keeps it
/// from expiring.
///
/// [decimals] is the resolution reported: whole dB for LEVEL, tenths for the
/// transmitter's watts and SWR.
class FlexSignalThrottle {
  FlexSignalThrottle({this.decimals = 0});
  final int decimals;
  static const intervalMillis = 250;
  int? _lastMillis;

  /// The reading to report for [dbm] arriving at [nowMillis], or null while
  /// the last report is under [intervalMillis] old.
  num? accept(double dbm, int nowMillis) {
    final last = _lastMillis;
    // `< 0` lets a clock that stepped backwards report at once rather than
    // stay silent until it catches up.
    if (last != null && nowMillis - last >= 0 && nowMillis - last < intervalMillis) return null;
    _lastMillis = nowMillis;
    if (decimals == 0) return dbm.round();
    final scale = math.pow(10, decimals);
    return (dbm * scale).round() / scale;
  }
}
