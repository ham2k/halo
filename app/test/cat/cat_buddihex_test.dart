// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The BuddiHex mast rotator's UDP format and its session.
//
// What is asserted here comes from its controller's firmware
// (rotatorControllerESP8266 3.0.1): PstRotator's turn and stop, its own
// `GET_BEARING` query, and answers sent back to whichever port the command
// came from. No BuddiHex rotator has been on the bench, so none of it is a
// capture.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/buddihex_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/buddihex_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';

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

  final problems = <String?>[];

  @override
  void reportProblem(String? message) => problems.add(message);
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

extension on BuddihexSession {
  void feed(String text) => handleData(Uint8List.fromList(ascii.encode(text)));
}

void main() {
  final st = t.settings.station;

  group('BuddiHex answers', () {
    test('a bearing, stuck or not, whichever way it is turning', () {
      expect(parseBuddihexReading('GET_BEARING:85'), const BuddihexBearing(85));
      expect(parseBuddihexReading('GET_BEARING:85:CW'), const BuddihexBearing(85));
      expect(parseBuddihexReading('GET_BEARING:85:CCW:Stuck'), const BuddihexBearing(85, stuck: true));
      // The controller stops the motor when it sticks, and the flag stands.
      expect(parseBuddihexReading('GET_BEARING:85:Stuck'), const BuddihexBearing(85, stuck: true));
      // The compass's own 360 is north.
      expect(parseBuddihexReading('GET_BEARING:360'), const BuddihexBearing(0));
    });

    // Its headings run 1 to 360, and 0 is what a read gives when the compass
    // was not ready: drawn as north, it would put the beam somewhere it is not.
    test('a 0 is a compass not ready, never north', () {
      expect(parseBuddihexReading('GET_BEARING:0'), const BuddihexFaulted(BuddihexFault.compassNotReady));
      expect(parseBuddihexReading('GET_BEARING:0:CW'), const BuddihexFaulted(BuddihexFault.compassNotReady));
    });

    test('a negative code with Error! is a compass fault, never a heading', () {
      expect(parseBuddihexReading('GET_BEARING:-1:Error!'), const BuddihexFaulted(BuddihexFault.compassMissing));
      expect(parseBuddihexReading('GET_BEARING:-2:Error!'), const BuddihexFaulted(BuddihexFault.compassNotReady));
      expect(parseBuddihexReading('GET_BEARING:-3:Error!'), const BuddihexFaulted(BuddihexFault.calibrationFailed));
      expect(parseBuddihexReading('GET_BEARING:-9:Error!'), const BuddihexFaulted(BuddihexFault.other));
    });

    test('anything else is not a reading', () {
      expect(parseBuddihexReading('AZ:85.0'), isNull);
      expect(parseBuddihexReading('IDENTIFY:192.168.4.1'), isNull);
      expect(parseBuddihexReading('ERR:BUG:bad command in loop()!'), isNull);
    });

    // The firmware takes the digits after <AZIMUTH> and refuses anything past
    // 360: a bearing sent as given from a turn past north would be dropped.
    test('a turn is PstRotator\'s, in whole degrees from 0 to 359', () {
      expect(buddihexTurnCommand(85.4), '<PST><AZIMUTH>85</AZIMUTH></PST>');
      expect(buddihexTurnCommand(360), '<PST><AZIMUTH>0</AZIMUTH></PST>');
      expect(buddihexTurnCommand(370), '<PST><AZIMUTH>10</AZIMUTH></PST>');
    });
  });

  group('BuddiHex session', () {
    test('polls GET_BEARING every two seconds, and reports each heading', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = BuddihexSession(sink)..startUpdates();
        expect(sink.sent, [buddihexBearingQuery]);
        async.elapse(buddihexPollInterval);
        expect(sink.sent, [buddihexBearingQuery, buddihexBearingQuery]);
        session.feed('GET_BEARING:120:CW');
        expect(sink.positions, [const RotatorPosition(azimuth: 120)]);
        expect(sink.alive, 1);
        session.stopUpdates();
      });
    });

    // A stuck mast is not a lost controller: it keeps answering, and a
    // reconnect would not move it.
    test('a stuck mast is a problem while the controller says so, and its heading still reports', () {
      final sink = _FakeSink();
      BuddihexSession(sink)
        ..feed('GET_BEARING:120:CW:Stuck')
        ..feed('GET_BEARING:120:Stuck')
        ..feed('GET_BEARING:121:CW');
      expect(sink.problems, [st.buddihexStuck, st.buddihexStuck, null]);
      expect(sink.positions.map((p) => p.azimuth), [120, 120, 121]);
    });

    test('a compass fault is a problem, with no heading reported', () {
      final sink = _FakeSink();
      BuddihexSession(sink).feed('GET_BEARING:-1:Error!');
      expect(sink.problems, [st.buddihexCompassMissing]);
      expect(sink.positions, isEmpty);
      expect(sink.alive, 1, reason: 'the controller answered: it is there, its compass is not');
    });

    // The controller drops every turn while its compass reads nothing. One
    // sent anyway would leave a target no reading can ever arrive at, and the
    // map would show a turn in progress until Stop.
    test('a turn while the compass is faulted is refused and not sent, and one after it reads again goes', () {
      final sink = _FakeSink();
      final session = BuddihexSession(sink)..feed('GET_BEARING:0');
      expect(session.rotateTo(azimuth: 90), isNull);
      expect(sink.sent, isEmpty);
      session.feed('GET_BEARING:45');
      expect(session.rotateTo(azimuth: 90), const RotatorPosition(azimuth: 90));
      expect(sink.sent, ['<PST><AZIMUTH>90</AZIMUTH></PST>']);
    });

    test('a turn and a stop are the PstRotator commands the controller takes', () {
      final sink = _FakeSink();
      final session = BuddihexSession(sink);
      expect(session.rotateTo(azimuth: 365), const RotatorPosition(azimuth: 5));
      session.stopRotation();
      expect(sink.sent, ['<PST><AZIMUTH>5</AZIMUTH></PST>', pstStopCommand]);
    });
  });

  group('BuddiHex node', () {
    final type = buddihexModel.variants.single;

    test('is prefilled with where an operator first finds the controller, and offers no offsets or limits', () {
      expect(type.defaultConfig, containsPair('host', '192.168.4.1'));
      expect(type.defaultConfig, containsPair('udpPort', 4210));
      final keys = [for (final element in type.driver.configElements()) element['key']];
      expect(keys, isNot(contains(contains('Offset'))));
      expect(keys, isNot(contains(contains('Min'))));
    });

    // The controller answers to the sender's port. A fixed reply port, as
    // PstRotator's, would also keep a second BuddiHex node from connecting.
    test('listens on a port the system picks, and hears the controller answer the port it was asked from', () async {
      // As a connection does: the target from the node's own type, opened by
      // the registry's one UDP transport.
      final registry = EquipmentRegistry();
      final pairing = registry.typeFor(type.key)!;
      final target = pairing.targetFor({...type.defaultConfig, 'host': '127.0.0.1', 'udpPort': 0});
      expect(target['replyPort'], 0);
      final transport = registry.transportFor(pairing.transportKey)!;

      final controller = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      controller.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = controller.receive();
        if (datagram != null && ascii.decode(datagram.data) == buddihexBearingQuery) {
          controller.send(ascii.encode('GET_BEARING:42'), datagram.address, datagram.port);
        }
      });
      final connection = await transport.connect({...target, 'port': controller.port}, cancel: CatCancelToken());
      final answer = Completer<String>();
      final subscription = connection.data.listen((chunk) {
        if (!answer.isCompleted) answer.complete(ascii.decode(chunk));
      });
      try {
        connection.send(ascii.encode(buddihexBearingQuery));
        expect(await answer.future.timeout(const Duration(seconds: 2)), 'GET_BEARING:42');
      } finally {
        await subscription.cancel();
        await connection.close();
        controller.close();
      }
    });
  });
}
