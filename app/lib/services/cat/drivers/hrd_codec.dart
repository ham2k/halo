// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Ham Radio Deluxe's Rig Control IP protocol, both directions: the HRD
// driver's client and the CAT server's emulation read and write the same
// frames and the same mode names.
//
// Each message is a frame, integers little-endian:
//
//   u32 total length, this field included
//   u32 0x1234ABCD
//   u32 0xABCD1234
//   u32 checksum, always 0
//   UTF-16LE text, NUL-terminated
//
// and a reply is framed the same way.
//
// HRD's commands name its own user interface: a mode is an item in a
// dropdown whose items are the radio's own mode names, so the names differ
// from one radio family to the next (`PKT-U` on a Kenwood, `USB-D` on an
// Icom, `DATA-U` on a Yaesu). [appModeForHrdMode] reads every spelling the
// families use.

import 'dart:typed_data';

const _magic1 = 0x1234ABCD;
const _magic2 = 0xABCD1234;

/// The frame's fixed header, before the text.
const hrdHeaderLength = 16;

/// HRD's mode names as a Kenwood-style radio lists them, against the app's:
/// what the CAT server offers, and what the driver sends when it has not
/// learned the radio's own list.
const hrdModesByAppMode = <String, String>{
  'LSB': 'LSB',
  'USB': 'USB',
  'CW': 'CW',
  'CW-R': 'CW-R',
  'AM': 'AM',
  'FM': 'FM',
  'FM-N': 'FMN',
  'RTTY-LSB': 'FSK',
  'RTTY-USB': 'FSK-R',
  'DATA-LSB': 'PKT-L',
  'DATA-USB': 'PKT-U',
  'DATA-FM': 'PKT-FM',
};

/// Every radio family's spelling of a mode the app names differently. Names
/// with no entry are already the app's (`USB`, `CW-R`, `DATA-USB`) or have
/// no app equivalent (`DV`, `WFM`) and pass through.
///
/// A Yaesu's `CW-U` is its normal CW and `CW-L` its reverse; its `RTTY-L`
/// is the conventional RTTY. A Kenwood's `FSK` is LSB and `FSK-R` USB.
const _appModesByHrdSpelling = <String, String>{
  'CWR': 'CW-R',
  'CW-U': 'CW',
  'CW-L': 'CW-R',
  'FMN': 'FM-N',
  'FM-NARROW': 'FM-N',
  'AMN': 'AM-N',
  'AM-NARROW': 'AM-N',
  'FSK': 'RTTY-LSB',
  'FSK-R': 'RTTY-USB',
  'RTTY': 'RTTY-LSB',
  'RTTY-L': 'RTTY-LSB',
  'RTTY-R': 'RTTY-USB',
  'RTTYR': 'RTTY-USB',
  'RTTY-U': 'RTTY-USB',
  'PKT-U': 'DATA-USB',
  'PKT-USB': 'DATA-USB',
  'PKTUSB': 'DATA-USB',
  'USB-D': 'DATA-USB',
  'USB-DATA': 'DATA-USB',
  'DATA-U': 'DATA-USB',
  'DIGU': 'DATA-USB',
  'PKT-L': 'DATA-LSB',
  'PKT-LSB': 'DATA-LSB',
  'PKTLSB': 'DATA-LSB',
  'LSB-D': 'DATA-LSB',
  'LSB-DATA': 'DATA-LSB',
  'DATA-L': 'DATA-LSB',
  'DIGL': 'DATA-LSB',
  'PKT-FM': 'DATA-FM',
  'PKTFM': 'DATA-FM',
  'FM-D': 'DATA-FM',
};

/// The app's name for a mode as an HRD dropdown item names it.
String appModeForHrdMode(String name) {
  final upper = name.trim().toUpperCase();
  return _appModesByHrdSpelling[upper] ?? upper;
}

/// [text] as one HRD frame.
Uint8List encodeHrdFrame(String text) {
  final payload = encodeUtf16le('$text\u0000');
  final frame = ByteData(hrdHeaderLength + payload.length)
    ..setUint32(0, hrdHeaderLength + payload.length, Endian.little)
    ..setUint32(4, _magic1, Endian.little)
    ..setUint32(8, _magic2, Endian.little)
    ..setUint32(12, 0, Endian.little);
  final bytes = frame.buffer.asUint8List();
  bytes.setRange(hrdHeaderLength, bytes.length, payload);
  return bytes;
}

/// Whether [bytes], at least 8 of them, open with a frame header.
bool startsWithHrdFrame(Uint8List bytes) => ByteData.sublistView(bytes).getUint32(4, Endian.little) == _magic1;

/// The first complete frame in [pending] — how many bytes it takes and its
/// text — or null while it is still arriving. A length no frame could have,
/// below the header's or above [maxLength], throws [FormatException]: the
/// peer is not speaking HRD, and nothing after it can be framed.
({int consumed, String text})? takeHrdFrame(Uint8List pending, {required int maxLength}) {
  if (pending.length < 4) return null;
  final length = ByteData.sublistView(pending).getUint32(0, Endian.little);
  if (length < hrdHeaderLength || length > maxLength) {
    throw FormatException('HRD frame length $length');
  }
  if (pending.length < length) return null;
  return (consumed: length, text: decodeUtf16le(pending.sublist(hrdHeaderLength, length)));
}

Uint8List encodeUtf16le(String text) {
  final units = text.codeUnits;
  final bytes = Uint8List(units.length * 2);
  for (var i = 0; i < units.length; i++) {
    bytes[i * 2] = units[i] & 0xff;
    bytes[i * 2 + 1] = units[i] >> 8;
  }
  return bytes;
}

/// UTF-16LE up to the first NUL.
String decodeUtf16le(List<int> bytes) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    final unit = bytes[i] | (bytes[i + 1] << 8);
    if (unit == 0) break;
    units.add(unit);
  }
  return String.fromCharCodes(units);
}
