// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Any GPS receiver that speaks NMEA 0183 — nearly every USB dongle and
// serial puck (docs/design/cat.md § GPS receivers). The wire format is
// nmea_codec.dart's.
//
// The session only listens: a receiver streams its sentences once a second
// from the moment the port opens, and nothing here needs saying to it. The
// same session reads one over the network — a phone app or a serial server
// on TCP, or pushing datagrams to a port here — and gpsd_driver.dart's.

import 'dart:convert';
import 'dart:typed_data';

import '../driver.dart';
import 'nmea_codec.dart';

class NmeaGpsDriver extends EquipmentDriver {
  const NmeaGpsDriver();

  @override
  String get key => 'nmea-gps';

  @override
  String get name => 'NMEA GPS';

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => NmeaGpsSession(sink);
}

class NmeaGpsSession implements EquipmentSession {
  final EquipmentSink sink;

  NmeaGpsSession(this.sink);

  /// Text received since the last complete sentence.
  String _pending = '';

  /// How long [_pending] may grow without a line ending or a `$`: past it,
  /// what arrived is no NMEA, and holding it would only grow.
  static const _pendingLimit = 4096;

  /// Whether this receiver sends GGA. One that does is read from GGA alone:
  /// it carries the precision fields RMC lacks, and reading both would
  /// report twice a second, the RMC with the PREVIOUS second's satellites
  /// (u-blox sends RMC first) — and, where the two disagree about the fix,
  /// flip between fix and none within each second. RMC answers only for a
  /// receiver set to send nothing else.
  bool _sendsGga = false;

  /// A line ending ends a sentence, and so does the `$` starting the next:
  /// a sender pushing datagrams may end each without a line ending, and the
  /// next sentence would otherwise be glued onto it and fail its checksum.
  /// Such a datagram's last sentence waits for the next `$`, a second away.
  /// Not inside a line that opened with `{`: that is gpsd's JSON, whose
  /// strings may hold a `$` of their own.
  ///
  /// Latin-1, which decodes every byte: NMEA is ASCII, and a corrupt byte
  /// fails its sentence's checksum rather than the whole chunk.
  @override
  void handleData(Uint8List chunk) {
    final text = _pending + latin1.decode(chunk);
    var start = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c == 0x0a || c == 0x0d) {
        _emit(text.substring(start, i));
        start = i + 1;
      } else if (c == 0x24 && i > start && text.codeUnitAt(start) != 0x7b) {
        _emit(text.substring(start, i));
        start = i;
      }
    }
    _pending = text.substring(start);
    if (_pending.length > _pendingLimit) _pending = '';
  }

  void _emit(String line) {
    if (line.trim().isNotEmpty) handleLine(line);
  }

  /// One sentence off the wire — or, from gpsd, one line of its own.
  void handleLine(String line) {
    final sentence = parseNmea(line);
    if (sentence == null) return;
    // Any sentence is the receiver still there, including the GSV and GSA a
    // receiver without a fix fills its second with.
    sink.reportAlive();
    final reading = sentence.reading;
    if (reading == null) return;
    if (sentence.type == 'GGA') _sendsGga = true;
    if (sentence.type == 'RMC' && _sendsGga) return;
    if (sink case final GpsSink gps) gps.reportGps(reading);
  }

  @override
  void startUpdates() {}

  @override
  void stopUpdates() {}

  @override
  void teardown() {
    _pending = '';
    _sendsGga = false;
  }

  /// A receiver pushes, once a second, unasked.
  @override
  Duration? get expectedUpdateInterval => null;

  @override
  String toString() => 'NmeaGpsSession(${_sendsGga ? 'GGA' : 'RMC'})';
}
