// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An SO2R switcher speaking OTRSP, the Open Two Radio Switching Protocol —
// docs/design/cat.md § The SO2R switcher. The spec is K1XM's, v0.9:
// https://www.k1xm.org/OTRSP/OTRSP_Protocol.pdf
//
// Plain text, every command, response and event ended by a carriage return,
// over a serial port (9600 8N1) or TCP. Only the receive focus is driven
// here: `RX1`, `RX2`, and the stereo pair `RX1S`/`RX2S`. The box's
// transmit focus, band, mode and auxiliary outputs are left alone.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../driver.dart';
import '../so2r_audio.dart';
import 'line_framer.dart';

/// How often a quiet box is pinged: OTRSP's bare `?`, which every device
/// answers with `?`. A box says nothing between changes, and the manager's
/// 30 s silence watchdog would otherwise mark a healthy one Not Responding.
const otrspPingInterval = Duration(seconds: 10);

/// The speed the spec names for every OTRSP device. A prefill rather than an
/// override: a box on USB ignores it, and one on a bridge may run another.
const otrspBaudRate = 9600;

/// [audio] as OTRSP's RX command.
String otrspRxCommand(So2rAudio audio) => switch (audio) {
  So2rAudio.a => 'RX1',
  So2rAudio.b => 'RX2',
  So2rAudio.stereoA => 'RX1S',
  So2rAudio.stereoB => 'RX2S',
};

/// The audio an `RX…` response or `$RX…` event reports, or null for a line
/// that is neither. Reverse stereo (`RX1R`, `RX2R`) is stereo here: the app
/// never asks for it, and a box set to it by hand still has both radios on.
So2rAudio? parseOtrspRx(String line) {
  final match = RegExp(r'^\$?RX([12])([SR]?)$').firstMatch(line.trim().toUpperCase());
  if (match == null) return null;
  return So2rAudio.of(focus: match[1] == '2' ? 'B' : 'A', stereo: match[2]!.isNotEmpty);
}

class OtrspDriver extends EquipmentDriver {
  const OtrspDriver();

  @override
  String get key => 'otrsp';

  @override
  String get name => 'OTRSP';

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => OtrspSession(sink);
}

class OtrspSession implements So2rSwitchSession {
  OtrspSession(this._sink);

  final EquipmentSink _sink;
  final _framer = LineFramer(crTerminates: true);
  Timer? _ping;
  String? _name;
  String? _firmware;

  void _send(String command) => _sink.send(utf8.encode('$command\r'));

  @override
  void startUpdates() {
    _send('?NAME');
    _send('?FW');
    // Answered at once with the box's current RX, and then on every change
    // — a front-panel switch included.
    _send('ERX1');
    _ping?.cancel();
    _ping = Timer.periodic(otrspPingInterval, (_) => _send('?'));
  }

  @override
  void stopUpdates() {
    _ping?.cancel();
    _ping = null;
  }

  @override
  void teardown() {
    stopUpdates();
    _framer.reset();
  }

  /// Null: the box pushes its RX events — see [EquipmentSession.expectedUpdateInterval].
  @override
  Duration? get expectedUpdateInterval => null;

  @override
  void setSo2rAudio(So2rAudio audio) => _send(otrspRxCommand(audio));

  @override
  void handleData(Uint8List chunk) {
    for (final raw in _framer.add(chunk)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      // Every line is the box answering on the link the commands go out on.
      _sink.reportAlive();
      if (parseOtrspRx(line) case final audio?) {
        if (_sink case final So2rSwitchSink sink) sink.reportSo2rAudio(audio);
      } else if (line.startsWith('NAME')) {
        _name = line.substring(4).trim();
        _reportInfo();
      } else if (line.startsWith('FW')) {
        _firmware = line.substring(2).trim();
        _reportInfo();
      }
      // `?` answers a ping, and `?KEYWORD` names a command the box does not
      // have; `$AB` asks to abort a transmission the app does not key.
    }
  }

  void _reportInfo() {
    final parts = [if (_name case final name? when name.isNotEmpty) name, if (_firmware case final fw? when fw.isNotEmpty) 'v$fw'];
    if (parts.isNotEmpty) _sink.reportDiagnostic(parts.join(' · '));
  }

  @override
  String toString() => 'OtrspSession(${_name ?? '?'})';
}
