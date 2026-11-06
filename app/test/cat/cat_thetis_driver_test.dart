// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Thetis session (an ANAN, through the program that runs it), with no
// radio and no Thetis. Built from Thetis's CAT reference alone; what these
// pin is that reading, so a change that drifts from the document fails here
// rather than on the air.
//
// The traps: the shared framer reads every answer as command `ZZ`, so a
// session that switched on the frame's command would hear nothing; Thetis's
// drive is a percentage, so watts sent raw would put a 200 W radio at half
// the power asked for; and a mode code the app has no name for must not be
// reported as some other mode.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/rated_power_config.dart';
import 'package:ham2k_logger/services/cat/telemetry_poller.dart';
import 'package:ham2k_logger/services/cat/drivers/thetis_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/thetis_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

class _FakeSink implements EquipmentSink {
  final sent = <String>[];
  final readings = <VfoReading>[];
  final power = <num>[];
  final txReports = <bool>[];
  final keyerSpeeds = <int>[];
  final diagnostics = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(ascii.decode(bytes));
  @override
  void report(VfoReading reading) => readings.add(reading);
  @override
  void reportPower(num watts) => power.add(watts);
  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);
  @override
  void reportMeter(RadioMeter meter, num value) {}
  @override
  void reportKeyerSpeed(int wpm) => keyerSpeeds.add(wpm);
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportVoiceActivity(VoiceActivity? activity) {}
  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) {}
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}

extension on ThetisSession {
  void feed(String text) => handleData(Uint8List.fromList(ascii.encode(text)));
}

void main() {
  late _FakeSink sink;
  late ThetisSession session;

  setUp(() {
    sink = _FakeSink();
    session = ThetisSession(sink);
  });

  tearDown(() => session.teardown());

  test('the telemetry field sets how often Thetis is asked whether it is on air', () {
    // The driver offers the field; a poller built without it would keep
    // asking every 200 ms whatever the operator typed.
    fakeAsync((async) {
      final quiet = _FakeSink();
      final slow = ThetisSession(quiet, config: const {telemetryIntervalConfigKey: 1000});
      slow.startUpdates();
      quiet.sent.clear();
      async.elapse(const Duration(milliseconds: 2500));
      expect(quiet.sent.where((c) => c.startsWith('ZZXV')), hasLength(2));
      slow.teardown();
    });
  });

  group('reading', () {
    test('a ZZFA answer is a frequency, even split across reads', () {
      session.feed('ZZFA0001407');
      session.feed('4150;');
      expect(sink.readings, [const VfoReading(freqKHz: 14074.15)]);
    });

    test('data sidebands read as the app names them, not as RTTY', () {
      session.feed('ZZMD07;ZZMD09;');
      expect(sink.readings.map((r) => r.mode), ['DATA-USB', 'DATA-LSB']);
    });

    test('CWU is CW and CWL is CW-R, the pairing Thetis makes for TS-2000', () {
      session.feed('ZZMD04;ZZMD03;');
      expect(sink.readings.map((r) => r.mode), ['CW', 'CW-R']);
    });

    test('a mode the app has no name for is not reported as another one', () {
      // DSB, SPEC, DRM: reporting any of them as USB or AM would overwrite a
      // logged mode with one the radio is not in.
      session.feed('ZZMD02;ZZMD08;ZZMD11;');
      expect(sink.readings, isEmpty);
      session.feed('ZZMD10;');
      expect(sink.readings.single.mode, 'AM', reason: 'SAM is AM in a log');
    });

    test('a truncated frequency is not read as a frequency', () {
      session.feed('ZZFA14074000;');
      expect(sink.readings, isEmpty);
    });
  });

  group('power is a share of the rated output', () {
    test('drive reads back as watts of the configured rating', () {
      session = ThetisSession(sink, config: {ratedWattsConfigKey: 200});
      session.feed('ZZPC050;');
      expect(sink.power, [100]);
    });

    test('a set sends the percentage, not the watts', () {
      session = ThetisSession(sink, config: {ratedWattsConfigKey: 200});
      session.setPower(50);
      // ZZPC050 would put a 200 W ANAN at 100 W.
      expect(sink.sent, ['ZZPC025;', 'ZZPC;']);
    });

    test('a stored rating that came back from JSON as a string still counts', () {
      session = ThetisSession(sink, config: {ratedWattsConfigKey: '10'});
      session.setPower(5);
      expect(sink.sent.first, 'ZZPC050;');
    });

    test('no rating, or a nonsense one, is the 100 W of most ANANs', () {
      for (final rated in [null, 0, -5, 'lots']) {
        sink.sent.clear();
        session = ThetisSession(sink, config: {ratedWattsConfigKey: rated});
        session.setPower(30);
        expect(sink.sent.first, 'ZZPC030;', reason: 'rated $rated');
      }
    });
  });

  group('transmit state', () {
    test('MOX and TUNE are both on the air; split alone is not', () {
      session.feed('ZZXV0064;'); // MOX
      session.feed('ZZXV0008;'); // split only
      session.feed('ZZXV0128;'); // TUNE: a carrier, nothing may switch under it
      expect(sink.txReports, [true, false, true]);
    });

    test('the three-digit width the reference draws is read too', () {
      session.feed('ZZXV064;');
      expect(sink.txReports, [true]);
    });

    test('a teardown while keyed unkeys first', () {
      session.setPtt(true);
      expect(sink.sent, ['ZZTX1;']);
      session.teardown();
      expect(sink.sent[1], 'ZZTX0;');
    });

    test('a teardown after an unkey sends no second unkey', () {
      session.setPtt(true);
      session.setPtt(false);
      sink.sent.clear();
      session.teardown();
      expect(sink.sent, isEmpty);
    });
  });

  group('commands', () {
    test('a retune is eleven digits of Hz on VFO A', () {
      session.setFrequency(7074.5);
      expect(sink.sent, ['ZZFA00007074500;']);
    });

    test('a mode Thetis has no code for sends nothing', () {
      session.setMode('DATA-USB');
      session.setMode('PSK');
      expect(sink.sent, ['ZZMD07;']);
    });

    test('settable modes are exactly the ones a set can send', () {
      final modes = const ThetisDriver().settableModes(const {});
      for (final mode in modes) {
        expect(buildThetisSetModeCommand(mode), isNotNull, reason: mode);
      }
      expect(modes, containsAll(['LSB', 'USB', 'CW', 'AM', 'FM', 'DATA-USB', 'DATA-LSB']));
    });
  });

  group('CW through CWX', () {
    test('text goes out padded to 24, and a stop is ZZSS', () {
      session.sendCw('CQ');
      expect(sink.sent.single, 'ZZKY CQ${' ' * 22};');
      session.stopCw();
      expect(sink.sent.last, 'ZZSS;');
    });

    test('a speed set reads back, and the answer is reported', () {
      session.setKeyerSpeed(150);
      expect(sink.sent, ['ZZKS099;', 'ZZKS;'], reason: 'clamped to CWX range');
      session.feed('ZZKS025;');
      expect(sink.keyerSpeeds, [25]);
    });
  });

  test('connecting asks for the version, the state and the keyer speed', () {
    session.startUpdates();
    expect(sink.sent, ['ZZVN;', 'ZZFA;', 'ZZMD;', 'ZZPC;', 'ZZKS;']);
    session.feed('ZZVN2.10.3.9;');
    session.feed('ZZVN2.10.3.9;');
    expect(sink.diagnostics, ['Thetis 2.10.3.9'], reason: 'said once a connection');
  });

  test('the rated power field refuses what is not a rating', () {
    const driver = ThetisDriver();
    expect(driver.validateField(ratedWattsConfigKey, '', const {}), isNull);
    expect(driver.validateField(ratedWattsConfigKey, '200', const {}), isNull);
    expect(driver.validateField(ratedWattsConfigKey, '0', const {}), isNotNull);
    expect(driver.validateField(ratedWattsConfigKey, '12.5', const {}), isNotNull);
    expect(driver.validateField(ratedWattsConfigKey, '1000', const {}), isNotNull, reason: "an amplifier's output would shrink every drive share fivefold");
  });

  test('the ANAN entry connects to Thetis on its own default port', () {
    final type = EquipmentRegistry().typeFor('anan-thetis-tcp');
    expect(type, isNotNull);
    expect(type!.driver, isA<ThetisDriver>());
    expect(type.defaultConfig['port'], 13013);
  });
}
