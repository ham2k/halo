// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';
import 'package:test/test.dart';

/// A hand-rolled encoder mirroring the wire format `wsjtx_qso_logged.dart`
/// decodes — this is what proves the reader's byte accounting (offsets,
/// length prefixes, QDateTime's Julian-day math) is internally consistent,
/// independent of whatever a real WSJT-X install happens to send.
class _Encoder {
  final _bytes = BytesBuilder();

  void uint32(int value) => _bytes.add(_be(value, 4));
  void uint64(int value) => _bytes.add(_be(value, 8));
  void uint8(int value) => _bytes.add([value]);

  void utf8String(String value) {
    final encoded = Uint8List.fromList(value.codeUnits);
    uint32(encoded.length);
    _bytes.add(encoded);
  }

  void qDateTime(int millis, {int timespec = 1}) {
    final epochDay = millis ~/ Duration.millisecondsPerDay;
    final msSinceMidnight = millis % Duration.millisecondsPerDay;
    uint64(epochDay + 2440588); // qint64 Julian day, written via the uint64 helper (same 8 bytes big-endian)
    uint32(msSinceMidnight);
    uint8(timespec);
  }

  Uint8List build() => _bytes.toBytes();

  static Uint8List _be(int value, int byteCount) {
    final out = Uint8List(byteCount);
    for (var i = byteCount - 1; i >= 0; i--) {
      out[i] = value & 0xff;
      value >>= 8;
    }
    return out;
  }
}

Uint8List _qsoLoggedDatagram({
  String clientId = 'WSJT-X',
  int dateTimeOffMillis = 1786999800000,
  String dxCall = 'K3TN',
  String dxGrid = 'FN20',
  int txFrequencyHz = 14200000,
  String mode = 'FT8',
  String reportSent = '-05',
  String reportReceived = '-10',
  String txPower = '',
  String comments = '',
  String name = '',
  int dateTimeOnMillis = 1786999740000,
  String operatorCall = 'KI2D',
  String myCall = 'KI2D',
  String myGrid = 'FN31',
  String exchangeSent = '',
  String exchangeReceived = '',
}) {
  final e = _Encoder()
    ..uint32(0xadbccbda)
    ..uint32(3)
    ..uint32(5)
    ..utf8String(clientId)
    ..qDateTime(dateTimeOffMillis)
    ..utf8String(dxCall)
    ..utf8String(dxGrid)
    ..uint64(txFrequencyHz)
    ..utf8String(mode)
    ..utf8String(reportSent)
    ..utf8String(reportReceived)
    ..utf8String(txPower)
    ..utf8String(comments)
    ..utf8String(name)
    ..qDateTime(dateTimeOnMillis)
    ..utf8String(operatorCall)
    ..utf8String(myCall)
    ..utf8String(myGrid)
    ..utf8String(exchangeSent)
    ..utf8String(exchangeReceived);
  return e.build();
}

void main() {
  test('parses a QSO Logged datagram into QSON', () {
    final info = parseWsjtxQsoLogged(_qsoLoggedDatagram());
    expect(info, isNotNull);
    expect(info!.clientId, 'WSJT-X');
    expect(info.qso['our'], containsPair('call', 'KI2D'));
    expect(info.qso['our'], containsPair('grid', 'FN31'));
    expect(info.qso['their'], containsPair('call', 'K3TN'));
    expect(info.qso['their'], containsPair('grid', 'FN20'));
    expect(info.qso['band'], '20m');
    expect(info.qso['freq'], 14200.0);
    expect(info.qso['mode'], 'FT8');
    expect(info.qso['startAtMillis'], 1786999740000);
    expect(info.qso['endAtMillis'], 1786999800000);
  });

  test('rejects the wrong magic number', () {
    final bytes = _qsoLoggedDatagram();
    bytes[0] = 0; // corrupt the magic number's first byte
    expect(parseWsjtxQsoLogged(bytes), isNull);
  });

  test('ignores every message type other than QSO Logged', () {
    final e = _Encoder()
      ..uint32(0xadbccbda)
      ..uint32(3)
      ..uint32(1) // Status, not QSOLogged (5)
      ..utf8String('some status payload');
    expect(parseWsjtxQsoLogged(e.build()), isNull);
  });

  test('a truncated datagram fails to parse rather than crashing', () {
    final full = _qsoLoggedDatagram();
    expect(parseWsjtxQsoLogged(full.sublist(0, full.length - 5)), isNull);
    expect(parseWsjtxQsoLogged(Uint8List(0)), isNull);
  });

  test('an operator call matching MyCall is not duplicated', () {
    final info = parseWsjtxQsoLogged(_qsoLoggedDatagram(operatorCall: 'KI2D', myCall: 'KI2D'));
    expect(info!.qso['our'], isNot(contains('operatorCall')));

    // Nothing normalizes either value on its way off the wire, and a stored
    // operator blocks the stamp that would otherwise name who was at the key
    // (`qsoWithOperator`) — so a difference in case must not read as a
    // different operator.
    final cased = parseWsjtxQsoLogged(_qsoLoggedDatagram(operatorCall: 'ki2d', myCall: 'KI2D'));
    expect(cased!.qso['our'], isNot(contains('operatorCall')));
  });

  test('a null-string field (0xffffffff length) reads as absent, not a crash', () {
    // WSJT-X marks a null QString with length 0xffffffff rather than 0 —
    // exercised here since the encoder above only ever emits real lengths.
    final e = _Encoder()
      ..uint32(0xadbccbda)
      ..uint32(3)
      ..uint32(5)
      ..utf8String('id')
      ..qDateTime(1786999800000)
      ..utf8String('K3TN')
      ..uint32(0xffffffff) // dxGrid: null string
      ..uint64(14200000)
      ..utf8String('FT8')
      ..utf8String('')
      ..utf8String('')
      ..utf8String('')
      ..utf8String('')
      ..utf8String('')
      ..qDateTime(1786999740000)
      ..utf8String('KI2D')
      ..utf8String('KI2D')
      ..utf8String('FN31')
      ..utf8String('')
      ..utf8String('');
    final info = parseWsjtxQsoLogged(e.build());
    expect(info, isNotNull);
    expect(info!.qso['their'], isNot(contains('grid')));
  });

  test('comments lead the notes, ahead of the contest exchange', () {
    final info = parseWsjtxQsoLogged(_qsoLoggedDatagram(comments: 'Great signal', exchangeSent: '599 05', exchangeReceived: '599 10'));
    expect(info!.qso['notes'], startsWith('Great signal'));
    expect(info.qso['notes'], contains('WSJT-X exchange'));
  });

  test('an invalid QDate (Julian day 0) reads as no timestamp, not 4713 BC', () {
    // Julian day 0 is Qt's own encoding of an invalid/null QDate — the
    // millis value that maps to it via the encoder's epochDay math.
    const julianDayZeroMillis = -2440588 * Duration.millisecondsPerDay;
    final info = parseWsjtxQsoLogged(_qsoLoggedDatagram(dateTimeOnMillis: julianDayZeroMillis));
    expect(info, isNull);
  });

  group('wsjtxDedupeKey', () {
    // The trap this whole group exists to catch: `clientId` is the SAME
    // string in every message a WSJT-X instance sends (it identifies the
    // running program, not the contact), so using it alone as a dedupe key
    // would make every QSO after the first look like a duplicate of it.
    test('two different QSOs from the same client produce different keys', () {
      final first = parseWsjtxQsoLogged(_qsoLoggedDatagram(dxCall: 'K3TN'))!;
      final second = parseWsjtxQsoLogged(_qsoLoggedDatagram(dxCall: 'W1AW'))!;
      expect(first.clientId, second.clientId, reason: 'both from the same WSJT-X instance');
      expect(wsjtxDedupeKey(first), isNot(wsjtxDedupeKey(second)));
    });

    test('the same QSO parsed twice produces the same key', () {
      final a = parseWsjtxQsoLogged(_qsoLoggedDatagram())!;
      final b = parseWsjtxQsoLogged(_qsoLoggedDatagram())!;
      expect(wsjtxDedupeKey(a), wsjtxDedupeKey(b));
    });
  });
}
