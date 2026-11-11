// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The simulated rotator and antenna switch: development tools that stand in
// for equipment nobody has on the bench, so what they must get right is
// behaving the way the panels above them expect a real one to.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/simulated_rotator_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/simulated_switch_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

class _FakeSink implements EquipmentSink, RotatorSink {
  final positions = <int>[];
  final switchStates = <(List<SwitchAntenna>, List<SwitchPort>)>[];

  @override
  void send(List<int> bytes) => fail('a simulator must not put bytes on a wire');

  @override
  void reportRotator(RotatorPosition position) => positions.add(position.azimuth);

  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) => switchStates.add((antennas, ports));

  @override
  void reportProblem(String? message) {}
  @override
  void reportAlive() {}
  @override
  void report(VfoReading reading) => fail('no VFO to report');
  @override
  void reportPower(num watts) => fail('no power to report');
  @override
  void reportTransmitting(bool transmitting) => fail('nothing transmits');
  @override
  void reportMeter(RadioMeter meter, num value) => fail('no meters');
  @override
  void reportKeyerSpeed(int wpm) => fail('no keyer');
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) => fail('no channels');
}

void main() {
  final registry = EquipmentRegistry();

  // The placeholder transport rejects a blank number, so a default left out
  // is a node the Add dialog saves and that then refuses to connect.
  test('each connects as added, on its defaults alone', () {
    for (final key in ['simulated-rotator', 'simulated-switch']) {
      final type = registry.typeFor(key)!;
      expect(type.validate(type.variant.defaultConfig), isNull, reason: key);
    }
  });

  group('the simulated rotator', () {
    test('turns at its own pace, the shorter way, and stops where it was sent', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = SimulatedRotatorSession(sink)..startUpdates();
        expect(sink.positions, [0]);
        // Across north, as an operator turning from 10° to 350° expects:
        // the long way round would be a minute of watching the wrong turn.
        expect(session.rotateTo(azimuth: 350).azimuth, 350);
        async.elapse(const Duration(seconds: 1));
        expect(sink.positions.last, 354);
        async.elapse(const Duration(seconds: 2));
        expect(sink.positions.last, 350);
        // Arrived: no more steps, only the restatement every ten seconds that
        // keeps it from reading as gone.
        final reported = sink.positions.length;
        async.elapse(const Duration(seconds: 10));
        expect(sink.positions.sublist(reported), [350]);
        session.teardown();
      });
    });

    // A stop that let it coast on would leave the target the operator just
    // abandoned still being chased.
    test('a stop holds it where it has got to', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = SimulatedRotatorSession(sink)..startUpdates();
        session.rotateTo(azimuth: 90);
        async.elapse(const Duration(seconds: 2));
        session.stopRotation();
        final at = sink.positions.last;
        async.elapse(const Duration(seconds: 5));
        expect(at, 12);
        expect(sink.positions.last, at);
        session.teardown();
      });
    });

    test('a torn-down session reports nothing more', () {
      fakeAsync((async) {
        final sink = _FakeSink();
        final session = SimulatedRotatorSession(sink)..startUpdates();
        session.rotateTo(azimuth: 90);
        session.teardown();
        final reported = sink.positions.length;
        async.elapse(const Duration(minutes: 1));
        expect(sink.positions.length, reported);
      });
    });
  });

  group('the simulated antenna switch', () {
    test('comes up as configured, each radio port on an antenna of its own', () {
      final sink = _FakeSink();
      const SimulatedSwitchDriver().createSession(sink, const {simulatedSwitchAntennasConfigKey: 3, simulatedSwitchRadiosConfigKey: 2}).startUpdates();
      final (antennas, ports) = sink.switchStates.single;
      expect([for (final a in antennas) a.key], ['1', '2', '3']);
      expect([for (final p in ports) (p.label, p.selectedAntennaKey)], [('A', '1'), ('B', '2')]);
    });

    test('takes a selection at once, and ignores one for an antenna it does not have', () {
      final sink = _FakeSink();
      final session = const SimulatedSwitchDriver().createSession(sink, const {}) as SimulatedSwitchSession..startUpdates();
      session.selectAntenna('2', '7');
      expect([for (final p in sink.switchStates.last.$2) p.selectedAntennaKey], ['1', '7']);
      session.selectAntenna('2', '9');
      session.selectAntenna('3', '1');
      expect(sink.switchStates, hasLength(2));
    });

    test('refuses a count it cannot lay out', () {
      const driver = SimulatedSwitchDriver();
      expect(driver.validateField(simulatedSwitchAntennasConfigKey, 0, const {}), isNotNull);
      expect(driver.validateField(simulatedSwitchAntennasConfigKey, simulatedSwitchMaxAntennas + 1, const {}), isNotNull);
      expect(driver.validateField(simulatedSwitchRadiosConfigKey, 4, const {}), isNull);
    });
  });
}
