// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// PstRotator's UDP Control format and its session.
//
// What is asserted here comes from PstRotator's User's Manual (Rev 7.5,
// "UDP Control"): `<PST>…</PST>` envelopes, several commands to one, and
// position answers `AZ:xxx.x<CR>` / `EL:yy.y<CR>`. No PstRotator has been
// on the bench, so none of it is a capture.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/pstrotator_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/pstrotator_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/transports/udp_transport.dart';

class _FakeSink implements EquipmentSink, RotatorSink {
  final sent = <String>[];
  final positions = <RotatorPosition>[];
  var alive = 0;

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));

  @override
  void reportRotator(RotatorPosition position) => positions.add(position);

  @override
  void reportAlive() => alive++;

  @override
  void reportProblem(String? message) {}
  @override
  void report(VfoReading reading) => fail('a rotator has no VFO to report');
  @override
  void reportPower(num watts) => fail('a rotator has no power to report');
  @override
  void reportTransmitting(bool transmitting) => fail('a rotator does not transmit');
  @override
  void reportMeter(RadioMeter meter, num value) => fail('a rotator has no meters');
  @override
  void reportKeyerSpeed(int wpm) => fail('a rotator has no keyer');
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) => fail('a rotator has no channels');
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) => fail('a rotator routes nothing');
}

extension on PstRotatorSession {
  void feed(String text) => handleData(Uint8List.fromList(ascii.encode(text)));
}

void main() {
  group('PstRotator commands', () {
    test('a turn is one envelope, in whole degrees, with the elevation inside it', () {
      expect(pstTurnCommand(85), '<PST><AZIMUTH>85</AZIMUTH></PST>');
      expect(pstTurnCommand(84.6), '<PST><AZIMUTH>85</AZIMUTH></PST>');
      // Two envelopes would be two datagrams, and one lost leaves the mast
      // turned on one axis only.
      expect(pstTurnCommand(85, elevation: 23), '<PST><AZIMUTH>85</AZIMUTH><ELEVATION>23</ELEVATION></PST>');
      expect(pstTurnCommand(400), '<PST><AZIMUTH>360</AZIMUTH></PST>');
    });

    test('answers read with decimals and signs, and nothing else reads as one', () {
      expect(parsePstReading('AZ:123.4'), (elevation: false, degrees: 123));
      expect(parsePstReading('EL:23.6'), (elevation: true, degrees: 24));
      expect(parsePstReading('EL:-2.0'), (elevation: true, degrees: -2));
      expect(parsePstReading('OK:ACQ:1'), isNull);
      expect(parsePstReading('MODE:1'), isNull);
      expect(parsePstReading(''), isNull);
    });
  });

  group('PstRotatorSession', () {
    test('polls the azimuth, and the elevation too only on an az/el node', () {
      fakeAsync((async) {
        final azOnly = _FakeSink();
        final session = PstRotatorSession(azOnly)..startUpdates();
        expect(azOnly.sent, [pstAzimuthQuery], reason: 'asked at once: the readout is blank until it answers');
        async.elapse(pstRotatorPollInterval * 2);
        expect(azOnly.sent, List.filled(3, pstAzimuthQuery));
        session.teardown();
        async.elapse(pstRotatorPollInterval * 2);
        expect(azOnly.sent, hasLength(3), reason: 'a torn-down session keeps polling a socket it no longer owns');

        final azEl = _FakeSink();
        PstRotatorSession(azEl, elevation: true).startUpdates();
        expect(azEl.sent, [pstAzimuthQuery, pstElevationQuery]);
      });
    });

    // One report per poll, not one per answer: CatService lets a target go
    // after rotatorStalledAfterReadings unchanged reports, and an az/el
    // node reporting twice a poll would give up on a turn in half the time.
    test('an az/el node reports once a poll, when the elevation completes the azimuth', () {
      final sink = _FakeSink();
      PstRotatorSession(sink, elevation: true)
        ..feed('EL:10.0\r')
        ..feed('AZ:123.4\r')
        ..feed('EL:30.0\r');
      expect(sink.positions, [const RotatorPosition(azimuth: 123, elevation: 30)], reason: 'an elevation with no azimuth yet says nothing');
    });

    test('an az-only node reports each azimuth, and ignores an elevation', () {
      final sink = _FakeSink();
      PstRotatorSession(sink)
        ..feed('AZ:90.0\rEL:12.0\r')
        ..feed('AZ:91.0\r');
      expect(sink.positions, [const RotatorPosition(azimuth: 90), const RotatorPosition(azimuth: 91)]);
    });

    // An az/el node pointed at a PstRotator that answers `AZ?` and never
    // `EL?` reports no position, and must not also read "not responding"
    // while it answers every poll.
    test('an azimuth still waiting for its elevation says PstRotator is there', () {
      final sink = _FakeSink();
      PstRotatorSession(sink, elevation: true).feed('AZ:90.0\r');
      expect(sink.positions, isEmpty);
      expect(sink.alive, 1);
    });

    test('an answer that is not a position still says PstRotator is there', () {
      final sink = _FakeSink();
      PstRotatorSession(sink).feed('MODE:0\r');
      expect(sink.alive, 1);
      expect(sink.positions, isEmpty);
    });

    test('a turn sends the elevation only where the node has one, and says where it is going', () {
      final azOnly = _FakeSink();
      expect(PstRotatorSession(azOnly).rotateTo(azimuth: 45.4, elevation: 30), const RotatorPosition(azimuth: 45));
      expect(azOnly.sent, ['<PST><AZIMUTH>45</AZIMUTH></PST>']);

      final azEl = _FakeSink();
      expect(PstRotatorSession(azEl, elevation: true).rotateTo(azimuth: 45, elevation: 30), const RotatorPosition(azimuth: 45, elevation: 30));
      expect(azEl.sent, ['<PST><AZIMUTH>45</AZIMUTH><ELEVATION>30</ELEVATION></PST>']);
    });

    test('stop is PstRotator\'s stop', () {
      final sink = _FakeSink();
      PstRotatorSession(sink).stopRotation();
      expect(sink.sent, [pstStopCommand]);
    });
  });

  group('the node\'s config', () {
    const transport = UdpTransport(portConfigKey: 'udpPort', replyPortOffset: 1);

    test('answers come back on the port after the one commands go to', () {
      expect(transport.targetFor(const {'host': ' 10.0.0.5 ', 'udpPort': 12000}), {'host': '10.0.0.5', 'port': 12000, 'replyPort': 12001});
    });

    // 65535 is a port, and its reply port is not one: refused at Save, it is
    // not a bind that fails at every connect.
    test('a port whose reply port is past the last refuses', () {
      expect(transport.validateField('udpPort', 12000, const {}), isNull);
      expect(transport.validateField('udpPort', 65535, const {}), isNotNull);
      expect(transport.validateField('udpPort', 0, const {}), isNotNull);
    });

    test('a PstRotator node offers no offsets or limits: PstRotator applies its own', () {
      final keys = const PstRotatorDriver().configElements().map((element) => element['key']).toSet();
      expect(keys, containsAll(['rotatorAxes', 'pollInterval']));
      expect(keys.where((key) => '$key'.contains('Offset') || '$key'.endsWith('Min') || '$key'.endsWith('Max')), isEmpty);
    });
  });
}
