// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// HaLo's own drivers, pointed at HaLo's emulations of the same programs.
//
// The rigctld and flrig drivers were written against the real programs, so
// for those a session that follows and tunes the emulation is evidence the
// emulation answers what a real client asks, in the form a real client
// reads. The HRD and N3FJP halves were both written from the same published
// descriptions, with no capture of either program: for those this proves
// only that the two halves agree, and a misreading of the documents shared
// by both would pass.

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/flrig_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/hrd_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/n3fjp_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/rigctld_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat_server/cat_server_protocol.dart';

import 'fake_cat_server_rig.dart';

/// Carries the driver's bytes to the server and keeps what it reports.
class _LoopSink implements EquipmentSink {
  CatServerConnection? server;
  final readings = <VfoReading>[];

  @override
  void send(List<int> bytes) => server!.receive(Uint8List.fromList(bytes));

  @override
  void report(VfoReading reading) => readings.add(reading);

  /// Where the driver last said the radio is. A driver reports frequency
  /// and mode as they arrive, often in separate readings.
  VfoReading get latest => VfoReading(freqKHz: readings.lastWhere((r) => r.freqKHz != null).freqKHz, mode: readings.lastWhere((r) => r.mode != null).mode);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  for (final (protocol, createSession) in [
    (CatServerProtocol.rigctld, (EquipmentSink sink) => RigctldSession(sink) as TransceiverSession),
    (CatServerProtocol.flrig, (EquipmentSink sink) => FlrigSession(sink) as TransceiverSession),
    (CatServerProtocol.hrd, (EquipmentSink sink) => HrdSession(sink) as TransceiverSession),
    (CatServerProtocol.n3fjp, (EquipmentSink sink) => N3fjpSession(sink) as TransceiverSession),
  ]) {
    group('HaLo\'s ${protocol.key} driver against the ${protocol.key} emulation', () {
      test('follows the radio and tunes it', () {
        fakeAsync((async) {
          final rig = FakeCatServerRig(freqKHz: 14074, mode: 'DATA-USB');
          final sink = _LoopSink();
          final session = createSession(sink);
          sink.server = createCatServerConnection(protocol, rig, send: (bytes) => session.handleData(Uint8List.fromList(bytes)), hangUp: () {}, quit: () {});

          session.startUpdates();
          async.elapse(const Duration(seconds: 3));
          expect(sink.latest, const VfoReading(freqKHz: 14074, mode: 'DATA-USB'));

          rig.move(freqKHz: 7030, mode: 'CW');
          // Past the drivers' staleness ceiling (3 × the slow poll), which is
          // the latest either one re-reads a radio that moved on its own.
          async.elapse(const Duration(seconds: 10));
          expect(sink.latest, const VfoReading(freqKHz: 7030, mode: 'CW'));

          session
            ..setFrequency(21074)
            ..setMode('DATA-USB');
          async.flushMicrotasks();
          expect(rig.tunes, [(freqKHz: 21074.0, mode: null), (freqKHz: null, mode: 'DATA-USB')]);

          session.teardown();
        });
      });
    });
  }
}
