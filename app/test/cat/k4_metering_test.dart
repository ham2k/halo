// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_shared_session.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';

import '../support/fake_clock.dart';

class _Sink implements EquipmentSink {
  final sent = <String>[];
  final meters = <(RadioMeter, num)>[];
  final power = <num>[];
  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));
  @override
  void reportMeter(RadioMeter meter, num value) => meters.add((meter, value));
  @override
  void reportPower(num watts) => power.add(watts);
  @override
  void report(VfoReading reading) {}
  @override
  void reportTransmitting(bool transmitting) {}
  @override
  void reportAlive() {}
  @override
  void reportKeyerSpeed(int wpm) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
}

String _info({required bool tx}) => 'IF00014074000     +000000 00${tx ? 1 : 0}2000001 ;';

void _receive(void Function(Uint8List) handleData, String text) => handleData(Uint8List.fromList(ascii.encode(text)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(followFakeClock);

  test('local K4 reads signed Main dBm within its serial byte budget and stops at disconnect', () {
    fakeAsync((async) {
      final sink = _Sink();
      const driver = KenwoodDriver.k4();
      final session = driver.createSession(sink, const {'baudRate': 4800}) as KenwoodSession;
      final cadence = driver.defaultTelemetryInterval(const {'baudRate': 4800});
      expect(cadence, const Duration(milliseconds: 442), reason: 'budget for the IF and SMH exchanges');
      session.startUpdates();
      expect(sink.sent.where((command) => command == 'TM1;'), hasLength(1));
      expect(sink.sent.where((command) => command == 'SMH;'), hasLength(1));

      _receive(session.handleData, r'SM0032;SMH1;SMH$-083;');
      expect(sink.meters, isEmpty);
      async.elapse(cadence * 6);
      expect(sink.sent.where((command) => command == 'SMH;'), hasLength(1), reason: 'do not poll unsupported SMH at the watch cadence');
      async.elapse(cadence);
      expect(sink.sent.where((command) => command == 'SMH;'), hasLength(2), reason: 'retry a missed signed reply on a slower cadence');
      _receive(session.handleData, 'SMH-106;');
      expect(sink.meters, [(RadioMeter.signalDbm, -106)]);
      async.elapse(cadence - const Duration(milliseconds: 1));
      expect(sink.sent.where((command) => command == 'SMH;'), hasLength(2));
      async.elapse(const Duration(milliseconds: 1));
      expect(sink.sent.where((command) => command == 'SMH;'), hasLength(3));

      session.stopUpdates();
      expect(sink.sent.sublist(sink.sent.length - 2), ['AI0;', 'TM0;']);
      _receive(session.handleData, 'SMH-098;');
      expect(sink.meters, [(RadioMeter.signalDbm, -106)]);
      final sent = sink.sent.length;
      async.elapse(const Duration(seconds: 5));
      session.teardown();
      expect(sink.sent, hasLength(sent));
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('K4 TX watts use the range for the current transmission, and valid SWR follows watts', () {
    fakeAsync((async) {
      final sink = _Sink();
      final session = const KenwoodDriver.k4(lanSpectrum: true).createSession(sink, const {'host': '192.0.2.4'}) as KenwoodSession;
      session.startUpdates();
      _receive(session.handleData, 'PC050H;TM001002050025;');
      expect(sink.meters, isEmpty, reason: 'receive-side or stale TM does not start a transmission');
      _receive(session.handleData, _info(tx: true));
      sink.sent.clear();
      _receive(session.handleData, 'TM001002040025;TM001002050025;');
      expect(sink.sent, ['PCX;'], reason: 'one outstanding range request for all pending samples');
      expect(sink.meters, isEmpty);
      async.elapse(const Duration(seconds: 1));
      _receive(session.handleData, 'TM001002053018;');
      expect(sink.sent.where((command) => command == 'PCX;'), hasLength(2), reason: 'retry a lost readback at a bounded rate');
      _receive(session.handleData, 'PC053L;TM001002052020;TM001002000010;TM001002001000;');
      expect(sink.meters, [
        (RadioMeter.powerOut, 5.3),
        (RadioMeter.swr, 1.8),
        (RadioMeter.powerOut, 5.2),
        (RadioMeter.swr, 2),
        (RadioMeter.powerOut, 0),
        (RadioMeter.powerOut, 0.1),
      ]);
      expect(sink.power, [50, 5.3], reason: 'actual power must not alter the configured power');
      _receive(session.handleData, '${_info(tx: false)}TM001002099055;${_info(tx: true)}TM001002050025;PC050X;');
      expect(sink.meters, hasLength(6), reason: 'old range and unspecified transverter units cannot be used');
      _receive(session.handleData, '${_info(tx: false)}${_info(tx: true)}TM001002050025;PC050H;');
      expect(sink.meters.skip(6), [(RadioMeter.powerOut, 50), (RadioMeter.swr, 2.5)]);
      session.teardown();
    });
  });

  test('secure K4 requests receive levels by receiver and reports one TX stream to both', () {
    fakeAsync((async) {
      final wire = _Sink(), main = _Sink(), sub = _Sink();
      final owner = K4SharedSession(send: wire.send, pan: const Stream.empty(), config: const {});
      final mainSession = owner.attach(main, receiver: 'main');
      final subSession = owner.attach(sub, receiver: 'sub');
      mainSession.startUpdates();
      subSession.startUpdates();
      expect(wire.sent.where((command) => command == 'TM1;'), hasLength(1));
      expect(wire.sent, contains('SMH;'));
      expect(wire.sent, isNot(contains(r'SMH$;')), reason: 'wait until Sub is known to be enabled');
      _receive(owner.handleData, r'SB1;SMH-115;SMH$-091;TX;TM001002065016;');
      expect(wire.sent, contains(r'SMH$;'));
      expect(main.meters, [(RadioMeter.signalDbm, -115)]);
      expect(sub.meters, [(RadioMeter.signalDbm, -91)]);
      _receive(owner.handleData, 'PC065H;');
      expect(main.meters.skip(1), [(RadioMeter.powerOut, 65), (RadioMeter.swr, 1.6)]);
      expect(sub.meters.skip(1), main.meters.skip(1));
      subSession.teardown();
      _receive(owner.handleData, 'TM001002067014;');
      expect(main.meters.last, (RadioMeter.swr, 1.4));
      expect(sub.meters, hasLength(3));
      expect(wire.sent, isNot(contains('TM0;')));
      owner.teardown();
      expect(wire.sent.where((command) => command == 'TM0;'), hasLength(1));
      expect(async.pendingTimers, isEmpty);
    });
  });
}
