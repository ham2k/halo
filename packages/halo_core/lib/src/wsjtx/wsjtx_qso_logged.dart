// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Parses WSJT-X's own UDP protocol (magic 0xadbccbda, Qt QDataStream
// big-endian binary framing) — specifically the "QSO Logged" message (type
// 5), sent once when the operator accepts the Log QSO dialog. Every other
// message type (Heartbeat, Status, Decode, ...) is ignored, the same way
// `n1mm_contact_info.dart` ignores every N1MM datagram but `<contactinfo>`.
//
// Field order confirmed against NetworkMessage.hpp's header comment
// (WSJT-X's own protocol spec) — see "Listen for other apps"
// (HALO-306). This is a DIFFERENT protocol from N1MM's XML broadcast, not a
// variant of it: multicast rather than plain broadcast, and binary rather
// than XML.

import 'dart:convert';
import 'dart:typed_data';

import '../ham/radio.dart';

const _magicNumber = 0xadbccbda;
const _qsoLoggedMessageType = 5;

/// A WSJT-X "QSO Logged" message, decoded into QSON.
class WsjtxQsoLogged {
  /// QSON: same shape `Qso.data` uses.
  final Map<String, dynamic> qso;

  /// The `Id` field WSJT-X's common message header carries — its CLIENT
  /// instance name (`"WSJT-X"` by default, or `--rig-name`), byte-identical
  /// across every message type that instance sends: Heartbeat, Status,
  /// Decode, and every QSO Logged alike. NOT a per-QSO identifier, despite
  /// the field's own name — see [wsjtxDedupeKey], which does not use this
  /// alone for exactly that reason.
  final String clientId;

  const WsjtxQsoLogged({required this.qso, required this.clientId});
}

/// Parses [bytes] as a WSJT-X UDP datagram. Returns null for anything that
/// isn't a "QSO Logged" message: wrong magic number, a Heartbeat/Status/
/// Decode/... message, or a truncated/malformed read — nothing capturable
/// either way.
WsjtxQsoLogged? parseWsjtxQsoLogged(Uint8List bytes) {
  final r = _ByteReader(bytes);
  try {
    if (r.readUint32() != _magicNumber) return null;
    r.readUint32(); // schema version — nothing here depends on it
    if (r.readUint32() != _qsoLoggedMessageType) return null;

    final clientId = r.readUtf8();
    final dateTimeOff = r.readQDateTime();
    final dxCall = r.readUtf8();
    final dxGrid = r.readUtf8();
    final txFrequencyHz = r.readUint64();
    final mode = r.readUtf8();
    final reportSent = r.readUtf8();
    final reportReceived = r.readUtf8();
    final txPower = r.readUtf8();
    final comments = r.readUtf8();
    final name = r.readUtf8();
    final dateTimeOn = r.readQDateTime();
    final operatorCall = r.readUtf8();
    final myCall = r.readUtf8();
    final myGrid = r.readUtf8();
    final exchangeSent = r.readUtf8();
    final exchangeReceived = r.readUtf8();

    if (dxCall.isEmpty || dateTimeOn == null) return null;

    final our = <String, dynamic>{if (myCall.isNotEmpty) 'call': myCall};
    // Only a call DIFFERENT from the station's says something the station
    // call did not — and case-insensitively, since neither value is
    // normalized on its way off the wire.
    _put(our, 'operatorCall', operatorCall.toUpperCase() != myCall.toUpperCase() ? operatorCall : null);
    _put(our, 'grid', myGrid);
    _put(our, 'sent', reportSent);

    final their = <String, dynamic>{'call': dxCall};
    _put(their, 'grid', dxGrid);
    _put(their, 'sent', reportReceived);
    _put(their, 'name', name);

    final qso = <String, dynamic>{'our': our, 'their': their, 'startAtMillis': dateTimeOn};
    if (dateTimeOff != null && dateTimeOff != dateTimeOn) qso['endAtMillis'] = dateTimeOff;
    if (mode.isNotEmpty) qso['mode'] = mode;

    if (txFrequencyHz > 0) {
      final freqKHz = txFrequencyHz / 1000;
      qso['freq'] = freqKHz;
      final band = bandForFrequency(freqKHz);
      if (band != null) qso['band'] = band;
    }

    final power = num.tryParse(txPower);
    if (power != null) qso['power'] = power;

    final notes = _notesFor(comments: comments, exchangeSent: exchangeSent, exchangeReceived: exchangeReceived);
    if (notes != null) qso['notes'] = notes;

    return WsjtxQsoLogged(qso: qso, clientId: clientId);
  } on _TruncatedException {
    return null;
  }
}

/// The dedupe key for a capture: same client, same station worked on the
/// same band/mode at the same second is the same QSO. [WsjtxQsoLogged.clientId]
/// alone can't serve this — it's the same value for every message a WSJT-X
/// instance sends — so it's one ingredient among the QSO's own identifying
/// fields, the same role N1MM's `<mycall>` plays in `n1mmDedupeKey`.
String wsjtxDedupeKey(WsjtxQsoLogged info) {
  final their = info.qso['their'] as Map<String, dynamic>;
  return [info.clientId, their['call'], info.qso['band'], info.qso['mode'], info.qso['startAtMillis']].join('|');
}

/// Free-text comment plus the contest exchange, same reasoning as
/// `n1mm_contact_info.dart`'s `_notesFor`: QSON has no structured field for
/// a contest exchange, so it's preserved as text.
String? _notesFor({required String comments, required String exchangeSent, required String exchangeReceived}) {
  final parts = <String>[];
  if (comments.isNotEmpty) parts.add(comments);
  final exchangeParts = <String>[if (exchangeSent.isNotEmpty) 'Sent: $exchangeSent', if (exchangeReceived.isNotEmpty) 'Rcvd: $exchangeReceived'];
  if (exchangeParts.isNotEmpty) parts.add('WSJT-X exchange — ${exchangeParts.join(', ')}');
  return parts.isEmpty ? null : parts.join('\n');
}

void _put(Map<String, dynamic> dest, String key, String? value) {
  if (value != null && value.isNotEmpty) dest[key] = value;
}

class _TruncatedException implements Exception {}

/// A big-endian reader over Qt's QDataStream wire format, as WSJT-X writes
/// it.
class _ByteReader {
  final ByteData _data;
  int _offset = 0;

  _ByteReader(Uint8List bytes) : _data = ByteData.sublistView(bytes);

  int readUint32() {
    _require(4);
    final value = _data.getUint32(_offset, Endian.big);
    _offset += 4;
    return value;
  }

  int readUint64() {
    _require(8);
    final value = _data.getUint64(_offset, Endian.big);
    _offset += 8;
    return value;
  }

  int readUint8() {
    _require(1);
    final value = _data.getUint8(_offset);
    _offset += 1;
    return value;
  }

  /// A QString-as-QByteArray: quint32 byte length, then that many UTF-8
  /// bytes, no terminator. `0xffffffff` marks a null string — read back as
  /// `''`, same as WSJT-X's own empty string, since QSON draws no
  /// distinction between "absent" and "explicitly null" for these fields.
  String readUtf8() {
    final length = readUint32();
    if (length == 0xffffffff) return '';
    _require(length);
    final bytes = Uint8List.sublistView(_data, _offset, _offset + length);
    _offset += length;
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// QDate as a Julian day number (qint64), QTime as milliseconds since
  /// midnight (quint32), then a quint8 timespec. WSJT-X always sends UTC
  /// (timespec 1); `OffsetFromUTC` (2) carries a trailing qint32 offset,
  /// read and discarded since every field WSJT-X sends is already
  /// UTC-normalized. `TimeZone` (3) is never emitted by WSJT-X and isn't
  /// handled — failing the read is safer than silently misaligning every
  /// field that follows.
  int? readQDateTime() {
    _require(8);
    final julianDay = _data.getInt64(_offset, Endian.big);
    _offset += 8;
    final msSinceMidnight = readUint32();
    final timespec = readUint8();
    if (timespec == 2) readUint32(); // UTC offset seconds, unused
    if (timespec == 3) throw _TruncatedException();

    // Qt represents an invalid/null QDate as Julian day 0 — read back as no
    // date at all, rather than decoding to a real-looking timestamp around
    // 4713 BC.
    if (julianDay <= 0) return null;

    // Julian day 2440588 is 1970-01-01 — the Unix epoch.
    final epochDay = julianDay - 2440588;
    return epochDay * Duration.millisecondsPerDay + msSinceMidnight;
  }

  void _require(int count) {
    if (_offset + count > _data.lengthInBytes) throw _TruncatedException();
  }
}
