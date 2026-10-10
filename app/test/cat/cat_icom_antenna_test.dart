// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An Icom's own antenna ports (CI-V 0x12), with no radio. The bytes are
// Icom's IC-7610, IC-7760 and IC-7300MK2 CI-V reference guides'.

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/civ_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/icom_civ_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

class _FakeSink implements EquipmentSink, RadioAntennaSink {
  final sent = <List<int>>[];
  final diagnostics = <String?>[];
  final antennas = <RadioAntennas?>[];

  /// The radio's side of the bus: ACKs every command, as a radio does, so
  /// the one-command-at-a-time sending moves on. Null is a radio that
  /// answers only what a test feeds it.
  void Function(Uint8List frame)? answer;

  @override
  void send(List<int> bytes) {
    sent.add(bytes);
    answer?.call(Uint8List.fromList([0xFE, 0xFE, bytes[3], bytes[2], 0xFB, 0xFD]));
  }

  @override
  void reportAntennas(RadioAntennas? report) => antennas.add(report);
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);

  @override
  void report(VfoReading reading) {}
  @override
  void reportPower(num watts) {}
  @override
  void reportTransmitting(bool transmitting) {}
  @override
  void reportMeter(RadioMeter meter, num value) {}
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}

void main() {
  const ic7610 = 0x98;
  const us = civDefaultControllerAddress;
  const readAntenna = [0xFE, 0xFE, ic7610, us, 0x12, 0xFD];
  List<int> fromRadio(List<int> payload) => [0xFE, 0xFE, us, ic7610, ...payload, 0xFD];
  List<int> setFrame(List<int> payload) => [0xFE, 0xFE, ic7610, us, 0x12, ...payload, 0xFD];

  late _FakeSink sink;
  late IcomCivSession session;

  IcomCivSession sessionWith(Map<String, dynamic> config) {
    final s = IcomCivDriver().createSession(sink, {'civAddress': '98', ...config}) as IcomCivSession;
    sink.answer = s.handleData;
    return s;
  }

  void feed(List<int> bytes) => session.handleData(Uint8List.fromList(bytes));

  setUp(() {
    sink = _FakeSink();
    session = sessionWith(const {civAntennaPortsConfigKey: 2});
  });

  group('which radios are asked', () {
    test('an entry that pins no ports never asks, and never reports', () {
      // An IC-705 or IC-9700 has no 0x12 at all: asked anyway it refuses on
      // every poll, and a pill for its one port would offer nothing.
      fakeAsync((async) {
        session = sessionWith(const {});
        session.startUpdates();
        async.elapse(const Duration(seconds: 11));
        feed(fromRadio([0x12, 0x01, 0x00]));
        expect(sink.sent.where((f) => f[4] == 0x12), isEmpty);
        expect(sink.antennas, isEmpty);
        session.setAntenna(tx: 'ANT2');
        expect(sink.sent.where((f) => f[4] == 0x12), isEmpty);
        session.teardown();
      });
    });

    test('a pinned radio is asked on the state poll', () {
      // Nothing says the radio announces an ANT key press, so the poll is
      // what hears it.
      fakeAsync((async) {
        session.startUpdates();
        expect(sink.sent.where((f) => listEquals(f, readAntenna)), hasLength(1));
        async.elapse(const Duration(seconds: 5));
        expect(sink.sent.where((f) => listEquals(f, readAntenna)), hasLength(2));
        session.teardown();
      });
    });
  });

  group('reading the selection', () {
    test('a radio with receive antenna connectors receives on its TX port or on RX-ANT', () {
      // It transmits on ANT1 or ANT2 and receives there unless RX-ANT is on:
      // receiving on ANT2 while transmitting on ANT1 is not a choice it has,
      // so the receive list follows the transmit port.
      feed(fromRadio([0x12, 0x00, 0x00]));
      feed(fromRadio([0x12, 0x01, 0x01]));
      expect(sink.antennas, const [
        RadioAntennas(rxPorts: ['ANT1', 'RX-ANT'], txPorts: ['ANT1', 'ANT2'], rx: 'ANT1', tx: 'ANT1', separate: true),
        RadioAntennas(rxPorts: ['ANT2', 'RX-ANT'], txPorts: ['ANT1', 'ANT2'], rx: 'RX-ANT', tx: 'ANT2', separate: true),
      ]);
    });

    test('a reply without the receive byte is one port for both', () {
      feed(fromRadio([0x12, 0x01]));
      expect(sink.antennas, const [
        RadioAntennas(rxPorts: ['ANT1', 'ANT2'], txPorts: ['ANT1', 'ANT2'], rx: 'ANT2', tx: 'ANT2'),
      ]);
    });

    test('four ports on an entry that pins four', () {
      session = sessionWith(const {civAntennaPortsConfigKey: 4});
      feed(fromRadio([0x12, 0x03, 0x00]));
      expect(sink.antennas.single?.txPorts, ['ANT1', 'ANT2', 'ANT3', 'ANT4']);
      expect(sink.antennas.single?.tx, 'ANT4');
    });

    test("a one-port radio's only choice is its receive antenna connectors", () {
      // The IC-7300MK2: one "ANT", and RX-ANT on or off. Without the receive
      // byte there is nothing to choose, and no selection is reported.
      session = sessionWith(const {civAntennaPortsConfigKey: 1});
      feed(fromRadio([0x12, 0x00, 0x01]));
      expect(sink.antennas, const [
        RadioAntennas(rxPorts: ['ANT', 'RX-ANT'], txPorts: ['ANT'], rx: 'RX-ANT', tx: 'ANT', separate: true),
      ]);

      sink.antennas.clear();
      session = sessionWith(const {civAntennaPortsConfigKey: 1});
      feed(fromRadio([0x12, 0x00]));
      expect(sink.antennas, [null]);
    });

    test('a port past the pinned count is not offered', () {
      // An entry pinned at two ports names two; a reply naming ANT3 is one
      // the entry does not describe, and ANT3 is no port to show.
      feed(fromRadio([0x12, 0x02, 0x00]));
      expect(sink.antennas, isEmpty);
    });

    test('the poll restating the same selection is not reported again', () {
      feed(fromRadio([0x12, 0x00, 0x00]));
      feed(fromRadio([0x12, 0x00, 0x00]));
      expect(sink.antennas, hasLength(1));
    });
  });

  group('selecting', () {
    test('nothing is sent before the radio says what it has', () {
      // The receive byte goes out only where the reply carries one, so a set
      // before the first reply would guess.
      session.setAntenna(tx: 'ANT2');
      expect(sink.sent, isEmpty);
    });

    test('a transmit port keeps receive where it is, and is read back', () {
      // A set is answered with a bare ACK: what is shown is what the radio
      // read back. Dropping the receive byte would leave RX-ANT to the
      // radio's whim when the operator moved only the transmit port.
      feed(fromRadio([0x12, 0x00, 0x01]));
      session.setAntenna(tx: 'ANT2');
      expect(sink.sent, [
        setFrame([0x01, 0x01]),
        readAntenna,
      ]);
    });

    test('receive goes to RX-ANT, or back to the transmit port', () {
      feed(fromRadio([0x12, 0x01, 0x00]));
      session.setAntenna(rx: 'RX-ANT');
      session.setAntenna(rx: 'ANT2');
      expect(sink.sent, [
        setFrame([0x01, 0x01]),
        readAntenna,
        setFrame([0x01, 0x00]),
        readAntenna,
      ]);
    });

    test('both at once: the port and the receive byte in one frame', () {
      feed(fromRadio([0x12, 0x00, 0x00]));
      session.setAntenna(rx: 'RX-ANT', tx: 'ANT2');
      expect(sink.sent, [
        setFrame([0x01, 0x01]),
        readAntenna,
      ]);
    });

    test('receiving on one ANT port while transmitting on another is refused here', () {
      // Sent as a port change it would move the transmit antenna the operator
      // did not touch.
      feed(fromRadio([0x12, 0x00, 0x00]));
      session.setAntenna(rx: 'ANT2');
      session.setAntenna(rx: 'ANT9');
      session.setAntenna(tx: 'RX-ANT');
      expect(sink.sent, isEmpty);
    });

    test('a radio without receive connectors gets the port alone, named either way', () {
      // One port serves both, so a receive pick is a port pick; a receive
      // byte the radio never sent would be a frame it does not take.
      feed(fromRadio([0x12, 0x00]));
      session.setAntenna(rx: 'ANT2');
      session.setAntenna(tx: 'ANT1');
      session.setAntenna(rx: 'RX-ANT');
      expect(sink.sent, [
        setFrame([0x01]),
        readAntenna,
        setFrame([0x00]),
        readAntenna,
      ]);
    });
  });

  group('on a serial radio that answers only when told', () {
    setUp(() {
      session = sessionWith(const {'baudRate': 19200, civAntennaPortsConfigKey: 2});
      sink.answer = null;
    });

    /// ACKs whatever is on the wire until [frame] is.
    void ackUntil(List<int> frame) {
      for (var i = 0; i < 20 && !listEquals(sink.sent.last, frame); i++) {
        feed(fromRadio([0xFB]));
      }
      expect(sink.sent.last, frame);
    }

    void ackUntilAntennaRead() => ackUntil(readAntenna);

    test('a radio that refuses the read twice in a row is not asked again', () {
      // An entry pinned with ports its radio cannot select costs an exchange
      // and a refusal on every poll for the session.
      fakeAsync((async) {
        session.startUpdates();
        ackUntilAntennaRead();
        feed(fromRadio([0xFA]));
        // Once is not enough: a NAK names no command, and one arriving late
        // for a command that timed out lands on whatever went out next.
        expect(sink.antennas, isEmpty);
        async.elapse(const Duration(seconds: 5));
        ackUntilAntennaRead();
        feed(fromRadio([0xFA]));
        expect(sink.antennas, [null]);
        expect(sink.diagnostics.where((d) => d!.contains('0x12')), hasLength(1));

        sink.answer = session.handleData;
        sink.sent.clear();
        async.elapse(const Duration(seconds: 16));
        expect(sink.sent.where((f) => f[4] == 0x12), isEmpty);
        expect(sink.antennas, [null], reason: 'said once');
        session.teardown();
      });
    });

    test('an answer between two refusals keeps the selection', () {
      fakeAsync((async) {
        session.startUpdates();
        ackUntilAntennaRead();
        feed(fromRadio([0xFA]));
        async.elapse(const Duration(seconds: 5));
        ackUntilAntennaRead();
        feed(fromRadio([0x12, 0x00, 0x00]));
        async.elapse(const Duration(seconds: 5));
        ackUntilAntennaRead();
        feed(fromRadio([0xFA]));
        expect(sink.antennas, hasLength(1));
        expect(sink.antennas.single, isNotNull);
        async.elapse(const Duration(seconds: 5));
        ackUntilAntennaRead();
        session.teardown();
      });
    });

    test('a refused set says nothing about the read', () {
      // A radio whose antenna type is RX-I/O may refuse RX-ANT on. Counted
      // against the read, that and one stray NAK would hide the ports of a
      // radio that has them.
      fakeAsync((async) {
        session.startUpdates();
        ackUntilAntennaRead();
        feed(fromRadio([0x12, 0x00, 0x00]));
        session.setAntenna(rx: 'RX-ANT');
        ackUntil(setFrame([0x00, 0x01]));
        feed(fromRadio([0xFA]));
        expect(sink.sent.last, readAntenna);
        feed(fromRadio([0xFA]));
        expect(sink.antennas, hasLength(1));
        expect(sink.antennas.single, isNotNull);
        sink.answer = session.handleData;
        sink.sent.clear();
        async.elapse(const Duration(seconds: 5));
        expect(sink.sent.where((f) => listEquals(f, readAntenna)), hasLength(1), reason: 'still on the state poll');
        session.teardown();
      });
    });
  });
}
