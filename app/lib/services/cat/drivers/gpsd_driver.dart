// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// gpsd, the GPS daemon most Linux machines run for a receiver plugged into
// them — and which then holds the device, so nothing else can open its port
// (docs/design/cat.md § GPS receivers). Asked over its TCP port for the
// receiver's NMEA, which gpsd writes for a receiver speaking a binary
// protocol of its own too, and read by the NMEA session unchanged.

import 'dart:convert';

import 'package:halo_i18n/halo_i18n.dart';

import '../driver.dart';
import 'nmea_codec.dart';
import 'nmea_gps_driver.dart';

/// gpsd's own port.
const gpsdDefaultPort = 2947;

/// What gpsd is told on connect: report, and as NMEA. Without it gpsd says
/// only its banner and waits.
const gpsdWatchCommand = '?WATCH={"enable":true,"nmea":true};\n';

/// Asks gpsd which receivers it has, answered with DEVICES.
const gpsdDevicesCommand = '?DEVICES;\n';

class GpsdDriver extends EquipmentDriver {
  const GpsdDriver();

  @override
  String get key => 'gpsd';

  @override
  String get name => 'gpsd';

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => GpsdSession(sink);
}

class GpsdSession extends NmeaGpsSession {
  GpsdSession(super.sink);

  /// What this session last told the operator was wrong with gpsd, so that
  /// only a change says anything.
  String? _problem;

  void _say(String? problem) {
    if (problem == _problem) return;
    _problem = problem;
    sink.reportProblem(problem);
  }

  @override
  void startUpdates() => sink.send(utf8.encode(gpsdWatchCommand));

  /// gpsd's own JSON lines, beside the NMEA it relays, for what the NMEA
  /// cannot say: that gpsd has no receiver, or refused what it was asked.
  /// Otherwise either reads as a receiver gone quiet, and the operator goes
  /// looking at the network.
  ///
  /// DEVICES lists the receivers, and gpsd sends it only when asked — on
  /// the WATCH, or on `?DEVICES` — so a DEVICE (one plugged in or pulled
  /// out later) asks again. And NMEA arriving at all is a receiver there:
  /// it clears "no receiver" whatever gpsd announced, since gpsd relays
  /// nothing else.
  @override
  void handleLine(String line) {
    if (!line.startsWith('{')) {
      if (_problem != null && parseNmea(line) != null) _say(null);
      return super.handleLine(line);
    }
    final Object? report;
    try {
      report = jsonDecode(line);
    } on FormatException {
      return;
    }
    // gpsd answering is gpsd there, receiver or none.
    sink.reportAlive();
    if (report is! Map) return;
    switch (report['class']) {
      case 'DEVICES':
        final devices = report['devices'];
        _say(devices is List && devices.isEmpty ? t.settings.station.gpsdNoDevice : null);
      case 'DEVICE':
        sink.send(utf8.encode(gpsdDevicesCommand));
      case 'ERROR':
        _say(t.settings.station.gpsdSaid(message: '${report['message'] ?? ''}'));
    }
  }

  @override
  void teardown() {
    super.teardown();
    _problem = null;
  }
}
