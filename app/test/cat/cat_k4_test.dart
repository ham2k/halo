// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_serial_ports.dart';

class _Sink implements EquipmentSink {
  final sent = <String>[];
  final readings = <VfoReading>[];
  final powers = <num>[];
  final transmitting = <bool>[];
  final speeds = <int>[];
  final problems = <String?>[];
  final diagnostics = <String?>[];
  final voices = <VoiceActivity?>[];
  void Function(List<int>)? write;
  void Function(VfoReading)? onReading;

  @override
  void send(List<int> bytes) {
    sent.add(ascii.decode(bytes));
    write?.call(bytes);
  }

  @override
  void report(VfoReading reading) {
    readings.add(reading);
    onReading?.call(reading);
  }

  @override
  void reportPower(num watts) => powers.add(watts);
  @override
  void reportTransmitting(bool value) => transmitting.add(value);
  @override
  void reportKeyerSpeed(int wpm) => speeds.add(wpm);
  @override
  void reportProblem(String? message) => problems.add(message);
  @override
  void reportVoiceActivity(VoiceActivity? activity) => voices.add(activity);

  @override
  void reportVoiceMemories(List<VoiceMemory> memories) {}
  @override
  void reportCwProgress(CwSendProgress? progress) {}
  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportChannels(List<EquipmentChannel> channels) {}
  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportMeter(RadioMeter meter, num value) {}
  @override
  void reportAlive() {}
}

// K31 IF layout from the reference: f, five spaces, RIT/XIT offset and
// flags, space, 00, TX, mode, 0, scan, split, band-change, DATA submode, 1, space.
String _info({String mode = '2', String data = '0', bool tx = false}) => 'IF00014074000     +000000 00${tx ? 1 : 0}${mode}0000${data}1 ;';

void _receive(KenwoodSession session, String text) => session.handleData(Uint8List.fromList(ascii.encode(text)));

KenwoodSession _session(_Sink sink, [String key = 'k4-serial']) {
  final type = EquipmentRegistry().typeFor(key)!;
  return type.driver.createSession(sink, type.driverConfig(type.defaultConfig)) as KenwoodSession;
}

void main() {
  setUp(() => useSerialPortsForTest(const []));

  test('one K4 model exposes local and secure remote links with fixed keyer capabilities', () {
    final registry = EquipmentRegistry();
    final model = registry.models.singleWhere((m) => m.key == 'k4');
    expect(model.variants.map((v) => v.key), ['k4-serial', 'k4-tcp', 'k4-remote', 'k4-ble', 'k4-placeholder']);
    final serial = registry.typeFor('k4-serial')!;
    final tcp = registry.typeFor('k4-tcp')!;
    expect(serial.defaultConfig['baudRate'], 38400);
    expect(tcp.defaultConfig, {'tcpPort': 9200});
    expect(tcp.validate({'host': '192.0.2.4', 'tcpPort': 9200}), isNull);
    expect(tcp.validate({'host': '', 'tcpPort': 9200}), isNotNull);
    expect(tcp.validate({'host': '192.0.2.4', 'tcpPort': 0}), isNotNull);
    final both = {'host': '192.0.2.4', 'tcpPort': '9201', 'port': '/dev/cu.usbserial-k4', 'baudRate': 38400};
    expect(serial.targetFor(both)['port'], '/dev/cu.usbserial-k4');
    expect(tcp.targetFor(both), {'host': '192.0.2.4', 'port': 9201});
    expect(tcp.transport.describeTarget(both), '192.0.2.4:9201');
    expect(tcp.validate(both), isNull);
    expect(tcp.transport.validateField('port', both['port'], both), isNull, reason: 'the network variant must not validate the serial path as a number');
    for (final type in [serial, tcp]) {
      expect(type.driver.key, 'elecraft-k4');
      final config = type.driverConfig(type.defaultConfig);
      expect(type.driver.canKeyCwWith(config), isTrue);
      expect(type.driver.voiceMemoryCountWith(config), 8);
      expect(
        type.configElements().where((e) => e['type'] == 'field').map((e) => e['key']),
        isNot(contains(anyOf('cwDialect', 'voiceDialect', 'voiceMemories'))),
      );
    }
  });

  test('K31 status distinguishes audio data, both RTTY inputs, PSK and reverse modes', () {
    final expected = {
      ('6', '0'): 'DATA-USB',
      ('9', '0'): 'DATA-LSB',
      ('6', '1'): 'RTTY',
      ('9', '1'): 'RTTY-R',
      ('6', '2'): 'RTTY',
      ('9', '2'): 'RTTY-R',
      ('6', '3'): 'PSK',
      ('9', '3'): 'PSK',
      ('2', '3'): 'USB',
      ('7', '0'): 'CW-R',
    };
    for (final entry in expected.entries) {
      final wire = _info(mode: entry.key.$1, data: entry.key.$2, tx: true);
      final reading = parseK4Info(wire.substring(2, wire.length - 1));
      expect(reading, (freqHz: 14074000, mode: entry.value, transmitting: true));
    }
    expect(parseK4Info('00014074000'), isNull);
    expect(parseK4Info(_info().substring(2)), isNull, reason: 'framer must remove the terminator');
    expect(buildK4SetModeCommand('DATA'), 'MD6;DT0;');
    expect(buildK4SetModeCommand('DATA-LSB'), 'MD9;DT0;');
    expect(buildK4SetModeCommand('RTTY'), 'MD6;DT2;');
    expect(buildK4SetModeCommand('RTTY-R'), 'MD9;DT2;');
    expect(buildK4SetModeCommand('PSK'), 'MD6;DT3;');
    // Nothing sent for these would let a band change's BN recall stand as the logged mode.
    expect(buildK4SetModeCommand('FT8'), 'MD6;DT0;');
    expect(buildK4SetModeCommand('FT4'), 'MD6;DT0;');
    expect(buildK4SetModeCommand('CW'), 'MD3;');
    expect(buildK4SetModeCommand('unrecognized'), isNull);
  });

  test('power conversion keeps low, high and milliwatt ranges distinct', () {
    expect(parseK4Power('050L'), (watts: 5.0, transverter: false));
    expect(parseK4Power('050H'), (watts: 50, transverter: false));
    expect(parseK4Power('050X'), (watts: 0.005, transverter: true));
    for (final bad in ['050', '050?', '050H?', '101L', '111H', '101X', '000L', '0050H']) {
      expect(parseK4Power(bad), isNull, reason: bad);
    }
    for (final (watts, wire) in [(0.1, 'PC001L;'), (5.3, 'PC053L;'), (10, 'PC100L;'), (11, 'PC011H;'), (50, 'PC050H;'), (110, 'PC110H;')]) {
      expect(buildK4SetPowerCommand(watts, transverter: false), wire);
    }
    expect(buildK4SetPowerCommand(0.005, transverter: true), 'PC050X;');
    expect(buildK4SetPowerCommand(5, transverter: true), isNull);
    for (final bad in [double.nan, double.infinity, -1, 0, 0.01, 111]) {
      expect(buildK4SetPowerCommand(bad, transverter: false), isNull);
    }
  });

  test('K4 band numbers cover HF through 6 m without guessing transverter assignments', () {
    final frequencies = [1900.0, 3700.0, 5357.0, 7100.0, 10120.0, 14250.0, 18100.0, 21200.0, 24920.0, 28500.0, 50100.0];
    expect(frequencies.map(k4BandNumber), List.generate(11, (i) => i));
    for (final frequency in [475.0, 10000.0, 144000.0]) {
      expect(k4BandNumber(frequency), isNull);
    }
  });

  for (final key in ['k4-serial', 'k4-tcp']) {
    test('$key selects a new band once before frequency-mode-frequency tuning', () {
      final sink = _Sink();
      final session = _session(sink, key);
      _receive(session, _info());
      // The first mode reading asks for the passband (cat_kenwood_passband_test.dart).
      sink.sent.clear();
      session.setFrequency(14250);
      expect(sink.sent, ['FA00014250000;'], reason: 'same-band tuning must not recall band settings');
      sink.sent.clear();
      session.setFrequency(7100);
      session.setMode('CW');
      session.setFrequency(7100);
      expect(sink.sent, ['BN03;', 'FA00007100000;', 'MD3;', 'IF;', 'FA00007100000;']);
      sink.sent.clear();
      session.setFrequency(7125);
      expect(sink.sent, ['FA00007125000;'], reason: 'do not repeat BN while the radio has not replied');
      _receive(session, _info());
      sink.sent.clear();
      session.setFrequency(7100);
      expect(sink.sent, ['BN03;', 'FA00007100000;'], reason: 'a front-panel band change replaces the remembered band');
      sink.sent.clear();
      session.setFrequency(14250);
      expect(sink.sent, ['BN05;', 'FA00014250000;']);
      sink.sent.clear();
      session.setFrequency(10000);
      expect(sink.sent, ['FA00010000000;'], reason: 'general coverage has no fixed BN assignment');
      session.stopUpdates();
      sink.sent.clear();
      session.setFrequency(14250);
      expect(sink.sent, ['BN05;', 'FA00014250000;'], reason: 'a new connection must not inherit an old band');
      session.teardown();
    });

    test('$key initializes before reads, frames arbitrary chunks, and follows front-panel changes', () {
      fakeAsync((async) {
        final sink = _Sink();
        final session = _session(sink, key);
        session.startUpdates();
        expect(sink.sent.take(3), ['K40;K31;', 'AI2;', 'IF;PCX;']);
        final snapshot = _info(mode: '6');
        _receive(session, snapshot.substring(0, 14));
        expect(sink.readings, isEmpty);
        _receive(session, '${snapshot.substring(14)}PC053L;KS080;');
        expect(sink.readings.last, const VfoReading(freqKHz: 14074, mode: 'DATA-USB'));
        expect(sink.powers.last, 5.3);
        expect(sink.speeds.last, 80);
        final count = sink.readings.length;
        _receive(session, 'MD9;DT2;');
        expect(sink.readings.length, count, reason: 'separate replies cannot identify one coherent DATA mode');
        expect(sink.sent.last, 'IF;');
        _receive(session, _info(mode: '9', data: '2', tx: true));
        expect(sink.readings.last.mode, 'RTTY-R');
        expect(sink.transmitting.last, isTrue);
        _receive(session, _info(mode: '3'));
        expect(sink.transmitting.last, isFalse);
        final beforeSub = sink.sent.length;
        _receive(session, 'MD\$6;DT\$2;FB00007100000;IFtruncated;PC050H?;');
        expect(sink.sent.length, beforeSub);
        expect(sink.readings.last.mode, 'CW', reason: 'subreceiver and invalid replies must not move the main VFO');
        session.setFrequency(14250);
        expect(sink.sent.last, 'FA00014250000;');
        session.setMode('DATA-LSB');
        expect(sink.sent.sublist(sink.sent.length - 2), ['MD9;DT0;', 'IF;']);
        session.teardown();
        expect(sink.sent.last, 'AI0;');
        final stopped = sink.sent.length;
        async.elapse(const Duration(seconds: 30));
        expect(sink.sent.length, stopped);
      });
    });
  }

  test('power writes require an explicit range and cannot promote a transverter to watts', () {
    fakeAsync((async) {
      final sink = _Sink();
      final session = _session(sink);
      session.setPower(50);
      expect(sink.sent, ['PCX;']);
      _receive(session, 'PC050;PC050H?;');
      expect(sink.sent, ['PCX;']);
      _receive(session, 'PC050L;');
      expect(sink.sent, ['PCX;', 'PC050H;', 'PCX;']);
      _receive(session, 'PC050H;');
      expect(sink.powers.last, 50);
      session.setPower(5);
      _receive(session, 'PC050X;');
      expect(sink.sent.last, 'PCX;', reason: 'a watt request on a milliwatt output is refused');
      expect(sink.problems.last, isNotNull);
      session.setPower(0.005);
      _receive(session, 'PC020X;');
      expect(sink.sent.sublist(sink.sent.length - 2), ['PC050X;', 'PCX;']);
      expect(sink.problems.last, isNull, reason: 'a corrected request clears its refusal');
      session.teardown();
    });
  });

  test('late power replies cannot execute an expired or disconnected request', () {
    fakeAsync((async) {
      final sink = _Sink();
      final session = _session(sink);
      session.setPower(50);
      async.elapse(const Duration(seconds: 3));
      expect(sink.problems.last, isNotNull);
      expect(sink.sent, ['PCX;', 'PCX;'], reason: 'an expired write reads the power back');
      _receive(session, 'PC005H;');
      expect(sink.sent, ['PCX;', 'PCX;']);
      session.setPower(70);
      session.stopUpdates();
      _receive(session, 'PC005H;');
      expect(sink.sent, ['PCX;', 'PCX;', 'PCX;']);
      session.setPower(80);
      session.setPower(double.nan);
      _receive(session, 'PC005H;');
      expect(sink.sent, ['PCX;', 'PCX;', 'PCX;', 'PCX;', 'PCX;'], reason: 'a newer invalid request also cancels the old write');
      session.teardown();
    });
  });

  test('a range answer inside the two-second window still carries out the write', () {
    fakeAsync((async) {
      final sink = _Sink();
      final session = _session(sink);
      session.setPower(20);
      async.elapse(const Duration(milliseconds: 1500));
      _receive(session, 'PC050H;');
      expect(sink.sent, ['PCX;', 'PC020H;', 'PCX;'], reason: 'a slow radio must not be timed out early');
      session.teardown();
    });
  });

  test('a power refusal is shown until the radio answers again, and the app shows the power it really has', () {
    fakeAsync((async) {
      final sink = _Sink();
      final session = _session(sink);
      final refusals = <void Function()>[
        () => session.setPower(150),
        () {
          session.setPower(20);
          async.elapse(const Duration(seconds: 3));
        },
      ];
      for (final refuse in refusals) {
        sink.sent.clear();
        refuse();
        expect(sink.problems.last, isNotNull);
        expect(sink.sent.last, 'PCX;', reason: 'without a read-back the app keeps the power it asked for');
        _receive(session, 'PC050H;');
        expect(sink.powers.last, 50);
        expect(sink.problems.last, isNotNull, reason: 'the read-back must not erase the refusal it was sent with');
        _receive(session, 'PC050H;');
        expect(sink.problems.last, isNull, reason: 'a later answer proves power commands work, so the refusal cannot stay up all session');
      }
      session.teardown();
    });
  });

  test('an unreadable status and a refused command reach the diagnostics, once per connection for status', () {
    fakeAsync((async) {
      final sink = _Sink();
      final session = _session(sink);
      bool layout(String? note) => note != null && note.contains('K31');
      session.startUpdates();
      _receive(session, 'IF00014074000;IFgarbage;ER04;');
      expect(sink.diagnostics.where(layout), hasLength(1), reason: 'every poll would otherwise repeat it');
      expect(sink.diagnostics.last, contains('ER04'));
      session.stopUpdates();
      session.startUpdates();
      _receive(session, 'IFgarbage;');
      expect(sink.diagnostics.where(layout), hasLength(2), reason: 'a new connection reports afresh');
      session.teardown();
    });
  });

  test('K4 keyers support 100 WPM, cancellation and eight recordable voice memories', () {
    fakeAsync((async) {
      final sink = _Sink();
      final session = _session(sink);
      expect(session.keyerSpeedRange, (min: 8, max: 100));
      session.setKeyerSpeed(80);
      expect(sink.sent, ['KS080;', 'KS;']);
      _receive(session, 'KS080;');
      _receive(session, 'KS000;KS101;');
      expect(sink.speeds, [80], reason: 'an invalid speed must not break the CW queue timing');
      session.setKeyerSpeed(200);
      expect(sink.sent.sublist(sink.sent.length - 2), ['KS100;', 'KS;']);
      session.sendCw('CQ TEST');
      expect(sink.sent.last, 'KY CQ TEST;');
      session.stopCw();
      expect(sink.sent.last, 'KY @;');
      expect(session.voiceMemoryCount, 8);
      expect(session.canRecordVoice, isTrue);
      expect(session.voiceMemoryCeiling, const Duration(seconds: 90));
      session.playVoiceMemory(8);
      expect(sink.sent.last, 'PB8;');
      session.stopVoice();
      expect(sink.sent.last, 'DA0;');
      session.recordVoiceMemory(8);
      expect(sink.sent.last, 'DARM;');
      session.stopVoice();
      expect(sink.sent.sublist(sink.sent.length - 2), ['DA0;', 'DAMS8;']);
      session.teardown();
    });
  });

  test('the real CAT service tunes, reads power and reconnects over TCP', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final cat = CatService(SettingsService(await SharedPreferences.getInstance()));
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final peers = <Socket>[];
    final commands = <String>[];
    var frequency = '00014074000';
    var mode = '6';
    var data = '2';
    var power = '050H';
    var subFrequency = 14074000;
    final refused = <String>[];
    server.listen((peer) {
      peers.add(peer);
      unawaited(peer.done.then((_) {}, onError: (Object _) {}));
      var residual = '';
      peer.listen(
        (bytes) {
          final frames = (residual + ascii.decode(bytes)).split(';');
          residual = frames.removeLast();
          for (final command in frames) {
            commands.add('$command;');
            // Model the hardware report: direct tuning below VFO B is
            // refused, while BAND selection moves the coupled receivers.
            if (command == 'BN03') {
              frequency = '00007000000';
              subFrequency = 7000000;
              mode = '2';
            }
            if (command.startsWith('FA') && command.length == 13) {
              if (int.parse(command.substring(2)) < 10000000 && subFrequency >= 14000000) {
                refused.add(command);
                peer.add(ascii.encode('ER04;'));
              } else {
                frequency = command.substring(2);
              }
            }
            if (command.startsWith('MD') && command.length == 3) mode = command.substring(2);
            if (command.startsWith('DT') && command.length == 3) data = command.substring(2);
            if (command.startsWith('PC') && command.length == 6) power = command.substring(2);
            if (command == 'IF') {
              peer.add(ascii.encode(_info(mode: mode, data: data).replaceFirst('00014074000', frequency)));
            }
            if (command == 'PCX') peer.add(ascii.encode('PC$power;'));
          }
        },
        onError: (Object _) {},
        cancelOnError: true,
      );
    });
    addTearDown(() async {
      cat.dispose();
      for (final peer in peers) {
        peer.destroy();
      }
      await server.close();
    });
    final node = await cat.addNode(
      typeKey: 'k4-tcp',
      name: 'K4',
      config: {'host': server.address.address, 'tcpPort': server.port, 'port': '/dev/cu.usbserial-k4', 'baudRate': 38400},
    );
    Future<void> until(bool Function() done) async {
      final reached = Completer<void>();
      void check() {
        if (!reached.isCompleted && done()) reached.complete();
      }

      cat.addListener(check);
      try {
        check();
        await reached.future.timeout(const Duration(seconds: 5));
      } finally {
        cat.removeListener(check);
      }
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      final ready = until(() => cat.stateFor(node.uuid).vfo == const VfoReading(freqKHz: 14074, mode: 'RTTY') && cat.stateFor(node.uuid).power == 50);
      await cat.connect(node.uuid);
      await ready;
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.connected);
      expect(cat.localRadio1, node.uuid);
      final tuned = until(() => cat.stateFor(node.uuid).vfo == const VfoReading(freqKHz: 7100, mode: 'DATA-LSB'));
      cat.tuneNode(node.uuid, const VfoReading(freqKHz: 7100, mode: 'DATA-LSB'));
      await tuned;
      final powered = until(() => cat.stateFor(node.uuid).power == 5.3);
      cat.setPower(5.3);
      await powered;
      expect(power, '053L');
      await cat.disconnect(node.uuid);
      expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);
      frequency = '00014074000';
      mode = '6';
      data = '2';
      power = '050H';
      subFrequency = 14074000;
    }
    expect(refused, isEmpty, reason: 'band selection must precede the frequency that would trigger ER04');
    expect(commands.where((c) => c == 'BN03;').length, 2, reason: 'one band recall per crossing, not per FA');
    expect(commands.where((c) => c == 'K40;').length, 2);
    expect(commands.where((c) => c == 'K31;').length, 2);
    expect(commands.where((c) => c == 'AI2;').length, 2);
  });
}
