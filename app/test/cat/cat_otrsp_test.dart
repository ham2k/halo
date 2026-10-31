// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The OTRSP SO2R switcher's session, and the rule deciding what the operator
// hears — docs/design/cat.md § The SO2R switcher.
//
// The wire shapes come from the OTRSP v0.9 specification (K1XM): every
// command, response and event ends in a bare CR, `?` answers `?`, and an
// enabled event answers at once with the current value. No box has been on
// the bench, so none of it is a capture.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/otrsp_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/so2r_audio.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';

class _FakeSink implements EquipmentSink, So2rSwitchSink {
  final sent = <String>[];
  final reported = <So2rAudio>[];
  final diagnostics = <String?>[];
  var alive = 0;

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));
  @override
  void reportSo2rAudio(So2rAudio audio) => reported.add(audio);
  @override
  void reportAlive() => alive++;
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);

  @override
  void report(VfoReading reading) => fail('a switcher has no VFO');
  @override
  void reportPower(num watts) => fail('a switcher has no power');
  @override
  void reportTransmitting(bool transmitting) => fail('a switcher does not transmit');
  @override
  void reportMeter(RadioMeter meter, num value) => fail('a switcher has no meters');
  @override
  void reportKeyerSpeed(int wpm) => fail('a switcher has no keyer');
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) => fail('a switcher has no channels');
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) => fail('a switcher routes no antennas');
}

extension on OtrspSession {
  void feed(String text) => handleData(Uint8List.fromList(ascii.encode(text)));
}

void main() {
  group('OTRSP session', () {
    test('bring-up names the box and turns on its RX events, every command ending in a bare CR', () {
      final sink = _FakeSink();
      OtrspSession(sink).startUpdates();
      // A CRLF would leave the LF to start the next command, which a box
      // reads as part of its keyword.
      expect(sink.sent, ['?NAME\r', '?FW\r', 'ERX1\r']);
    });

    test('each audio is its RX command, stereo carrying its fallback radio', () {
      final sink = _FakeSink();
      final session = OtrspSession(sink);
      for (final audio in So2rAudio.values) {
        session.setSo2rAudio(audio);
      }
      // RX1S and RX2S are the same stereo; which one names what a box with
      // no stereo plays instead — the radio in focus, not always radio 1.
      expect(sink.sent, ['RX1\r', 'RX2\r', 'RX1S\r', 'RX2S\r']);
    });

    test('what the box says it is set to is reported, events and query answers alike', () {
      final sink = _FakeSink();
      final session = OtrspSession(sink);
      // Split across reads, as a serial port delivers it.
      session.feed('\$RX');
      session.feed('2\rRX1S\r\$RX1R\r');
      // Reverse stereo, set by hand on the box, still has both radios on.
      expect(sink.reported, [So2rAudio.b, So2rAudio.stereoA, So2rAudio.stereoA]);
    });

    test('its name and firmware are its diagnostic; a command it lacks reports nothing', () {
      final sink = _FakeSink();
      final session = OtrspSession(sink);
      session.feed('NAMEYCCC SO2R+\rFW1.1.0\r?NAME\r');
      expect(sink.diagnostics.last, 'YCCC SO2R+ · v1.1.0');
      expect(sink.reported, isEmpty);
    });

    test('every line it sends is life, and a quiet box is pinged inside the silence window', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = OtrspSession(sink)..startUpdates();
        sink.sent.clear();
        // A box says nothing between changes: without the ping the manager's
        // 30 s watchdog marks a healthy one Not Responding.
        async.elapse(otrspPingInterval);
        expect(sink.sent, ['?\r']);
        session.feed('?\r');
        expect(sink.alive, 1);
        session.teardown();
        async.elapse(otrspPingInterval * 3);
        expect(sink.sent, ['?\r'], reason: 'a session torn down pings nothing');
      });
    });
  });

  group('the OTRSP catalogue', () {
    test('every serial pairing holds RTS and DTR low, whatever the operator ticks', () {
      // OTRSP keys PTT on RTS and CW on DTR: a line held high is a
      // transmitter keyed for as long as the port is open.
      final types = EquipmentRegistry().types.where((type) => type.category == kCategorySo2rSwitch && type.transport is SerialTransportConfig);
      expect(types, isNotEmpty);
      for (final type in types) {
        final config = type.driverConfig({serialRtsHighConfigKey: true, serialDtrHighConfigKey: true});
        expect(config[serialRtsHighConfigKey], false, reason: type.key);
        expect(config[serialDtrHighConfigKey], false, reason: type.key);
      }
    });
  });

  group('what the operator hears', () {
    So2rAudio hear({String operatorRadio = 'A', bool stereo = false, bool listen = true, bool txA = false, bool txB = false}) =>
        wantedSo2rAudio(operatorRadio: operatorRadio, stereo: stereo, listenWhileTransmitting: listen, transmittingA: txA, transmittingB: txB);

    test('the radio of the set the operator is in, or both in stereo', () {
      expect(hear(), So2rAudio.a);
      expect(hear(operatorRadio: 'B'), So2rAudio.b);
      expect(hear(stereo: true), So2rAudio.stereoA);
      expect(hear(operatorRadio: 'B', stereo: true), So2rAudio.stereoB);
    });

    test('one radio transmitting hands the headphones to the other', () {
      // Sending a CQ on A is listening on B: the reason for a second radio.
      expect(hear(txA: true), So2rAudio.b);
      expect(hear(operatorRadio: 'B', txB: true), So2rAudio.a);
      // In stereo both are heard already; only the fallback focus moves.
      expect(hear(stereo: true, txA: true), So2rAudio.stereoB);
    });

    test('not while both transmit, nor with listening turned off', () {
      expect(hear(txA: true, txB: true), So2rAudio.a);
      expect(hear(listen: false, txA: true), So2rAudio.a);
    });

    test('a radio switching its own audio mutes the one out of focus, and pans each to its ear in stereo', () {
      expect([so2rEarFor(So2rAudio.a, 'A'), so2rEarFor(So2rAudio.a, 'B')], [So2rEar.both, So2rEar.muted]);
      expect([so2rEarFor(So2rAudio.stereoB, 'A'), so2rEarFor(So2rAudio.stereoB, 'B')], [So2rEar.left, So2rEar.right]);
    });
  });
}
