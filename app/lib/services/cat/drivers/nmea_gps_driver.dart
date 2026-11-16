// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Any GPS receiver that speaks NMEA 0183 — nearly every USB dongle and
// serial puck (docs/design/cat.md § GPS receivers). The wire format is
// nmea_codec.dart's.
//
// The session only listens: a receiver streams its sentences once a second
// from the moment the port opens, and nothing here needs saying to it.

import 'dart:typed_data';

import '../driver.dart';
import 'line_framer.dart';
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
  final EquipmentSink _sink;

  NmeaGpsSession(this._sink);

  final _framer = LineFramer();

  /// Whether this receiver sends GGA. One that does is read from GGA alone:
  /// it carries the precision fields RMC lacks, and reading both would
  /// report twice a second, the RMC with the PREVIOUS second's satellites
  /// (u-blox sends RMC first) — and, where the two disagree about the fix,
  /// flip between fix and none within each second. RMC answers only for a
  /// receiver set to send nothing else.
  bool _sendsGga = false;

  @override
  void handleData(Uint8List chunk) {
    for (final line in _framer.add(chunk)) {
      final sentence = parseNmea(line);
      if (sentence == null) continue;
      // Any sentence is the receiver still there, including the GSV and GSA
      // a receiver without a fix fills its second with.
      _sink.reportAlive();
      final reading = sentence.reading;
      if (reading == null) continue;
      if (sentence.type == 'GGA') _sendsGga = true;
      if (sentence.type == 'RMC' && _sendsGga) continue;
      if (_sink case final GpsSink gps) gps.reportGps(reading);
    }
  }

  @override
  void startUpdates() {}

  @override
  void stopUpdates() {}

  @override
  void teardown() {
    _framer.reset();
    _sendsGga = false;
  }

  /// A receiver pushes, once a second, unasked.
  @override
  Duration? get expectedUpdateInterval => null;

  @override
  String toString() => 'NmeaGpsSession(${_sendsGga ? 'GGA' : 'RMC'})';
}
