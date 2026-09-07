// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What knowing the radio is keyed lets the app refuse.
//
// Switching an antenna relay under RF is what destroys one, and the switches
// this layer drives cannot all tell: the Sierra CX-1 has no PTT input and no
// RF sensing at all, so before telemetry there was nothing anywhere in the
// app that knew. The gate lives in CatService rather than in a driver
// because the fact and the equipment are in different places — the RADIO
// knows it is transmitting, and the SWITCH is the thing that must not move.
//
// The other half of what these pin is the shape of "unknown": most drivers
// report no TX state at all, and a shack full of them must go on working
// exactly as it did before any of this existed.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secure_storage.dart';

class _FakeConnection implements EquipmentConnection {
  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();

  @override
  Stream<Uint8List> get data => _data.stream;
  @override
  Future<void> get closed => _closed.future;
  @override
  void send(List<int> bytes) {}
  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
    unawaited(_data.close());
  }
}

class _FakeTransport extends EquipmentTransport {
  @override
  String get key => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async =>
      _FakeConnection();
}

class _RadioSession implements TransceiverSession {
  final EquipmentSink sink;
  _RadioSession(this.sink);

  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}
  @override
  Duration? get expectedUpdateInterval => null;
  @override
  void teardown() {}
}

class _RadioDriver extends EquipmentDriver {
  final sessions = <_RadioSession>[];

  @override
  String get key => 'gate-radio';
  @override
  String get name => 'Gate Radio';
  @override
  bool get hardwareVerified => false;
  @override
  Set<RadioMeter> get telemetryMeters => const {RadioMeter.swr};
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final session = _RadioSession(sink);
    sessions.add(session);
    return session;
  }
}

class _SwitchSession implements AntennaSwitchSession {
  final selections = <String>[];

  @override
  void selectAntenna(String portKey, String antennaKey) => selections.add('$portKey->$antennaKey');

  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  Duration? get expectedUpdateInterval => null;
  @override
  void teardown() {}
}

class _SwitchDriver extends EquipmentDriver {
  final sessions = <_SwitchSession>[];

  @override
  String get key => 'gate-switch';
  @override
  String get name => 'Gate Switch';
  @override
  bool get hardwareVerified => false;
  @override
  int get antennaPortCount => 4;
  @override
  int get devicePortCount => 1;
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final session = _SwitchSession();
    sessions.add(session);
    return session;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RadioService radio;
  late SettingsService settings;
  late CatService cat;
  late _RadioDriver radioDriver;
  late _SwitchDriver switchDriver;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    radio = RadioService(prefs, writeDelay: Duration.zero);
    settings = SettingsService(prefs, secureStorage: FakeSecureStorage());
    radioDriver = _RadioDriver();
    switchDriver = _SwitchDriver();
    final transport = _FakeTransport();
    cat = CatService(
      settings,
      radio: radio,
      // The real window is 30 s. Short enough to wait out on purpose, long
      // enough that nothing here trips it by accident.
      staleAfter: const Duration(milliseconds: 40),
      registry: EquipmentRegistry(
        models: [
          EquipmentModel(
            key: 'gate-radio',
            category: kCategoryTransceiver,
            name: () => 'Gate Radio',
            variants: [EquipmentVariant(key: 'gate-radio-type', driver: radioDriver, transport: transport)],
          ),
          EquipmentModel(
            key: 'gate-switch',
            category: kCategoryAntennaSwitch,
            name: () => 'Gate Switch',
            variants: [EquipmentVariant(key: 'gate-switch-type', driver: switchDriver, transport: transport)],
          ),
        ],
        transports: {'fake': transport},
      ),
    );
  });

  tearDown(() {
    cat.dispose();
    radio.dispose();
  });

  Future<({EquipmentNode radioNode, EquipmentNode switchNode})> connectedStation() async {
    final radioNode = await cat.addNode(typeKey: 'gate-radio-type', config: {'host': 'radio.local'});
    await cat.connect(radioNode.uuid);
    final switchNode = await cat.addNode(typeKey: 'gate-switch-type', config: {'host': 'switch.local'});
    await cat.connect(switchNode.uuid);
    return (radioNode: radioNode, switchNode: switchNode);
  }

  test('a relay may not move while the radio says it is transmitting', () async {
    final station = await connectedStation();
    radioDriver.sessions.single.sink.reportTransmitting(true);

    cat.selectAntenna(station.switchNode.uuid, '1', '3');
    expect(switchDriver.sessions.single.selections, isEmpty);
    // Refused outright rather than queued: a selection made a moment ago is
    // not worth honouring after the over ends, by which time the operator
    // has moved on and the switch would move under their hands.
    radioDriver.sessions.single.sink.reportTransmitting(false);
    expect(switchDriver.sessions.single.selections, isEmpty);
  });

  test('a relay moves once the radio is receiving again', () async {
    final station = await connectedStation();
    final sink = radioDriver.sessions.single.sink;
    sink.reportTransmitting(true);
    sink.reportTransmitting(false);

    cat.selectAntenna(station.switchNode.uuid, '1', '3');
    expect(switchDriver.sessions.single.selections, ['1->3']);
  });

  test('a radio that cannot say is not treated as transmitting', () async {
    // Most drivers report no TX state at all. Reading silence as "keyed"
    // would make the switch unusable in every shack that has one — which is
    // every shack that has one today.
    final station = await connectedStation();
    expect(cat.stateFor(station.radioNode.uuid).telemetry.transmitting, isNull);

    cat.selectAntenna(station.switchNode.uuid, '1', '3');
    expect(switchDriver.sessions.single.selections, ['1->3']);
  });

  test('the TX state belongs to the radio driving the panel, not to the switch', () async {
    // The switch's own node has no telemetry and never will: it is not a
    // transceiver. A gate that read the state of the node being ACTED on
    // would never fire at all, and would look exactly like a gate that
    // worked in a shack where nobody transmits while testing it.
    final station = await connectedStation();
    expect(cat.radio1, LocalRadio(station.radioNode.uuid));
    expect(cat.stateFor(station.switchNode.uuid).telemetry.transmitting, isNull);

    radioDriver.sessions.single.sink.reportTransmitting(true);
    expect(cat.radio1IsTransmitting, isTrue);
    cat.selectAntenna(station.switchNode.uuid, '1', '3');
    expect(switchDriver.sessions.single.selections, isEmpty);
  });

  test('a radio that goes silent mid-over stops holding the switch shut', () async {
    // Nothing in any of these protocols announces an unkey, so a rig
    // unplugged or switched off while keyed leaves its last word standing:
    // "transmitting", for the rest of the session. Left to gate on that, the
    // antenna switch refuses every selection for ever, with nothing on
    // screen to say why. Staleness is what already knows the radio has
    // stopped answering.
    final station = await connectedStation();
    radioDriver.sessions.single.sink.reportTransmitting(true);
    expect(cat.radio1IsTransmitting, isTrue);

    // Let the silence watch trip, the way it does on a radio that has
    // stopped answering — see [staleAfter] on the service built above.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(cat.stateFor(station.radioNode.uuid).stale, isTrue);
    expect(cat.radio1IsTransmitting, isFalse, reason: 'silence is not a transmission');
    cat.selectAntenna(station.switchNode.uuid, '1', '3');
    expect(switchDriver.sessions.single.selections, ['1->3']);
  });

  test('a meter reading that repeats its value does not wake every listener', () async {
    // Three meters on a 200 ms cycle is fifteen notifications a second, and
    // the panel that consumes them is a shared ChangeNotifier: repainting
    // the whole station to redraw an unchanged 1.2 is work nobody can see.
    // The timestamp still has to move, or a steady reading would expire
    // mid-transmission — so this is the one place where "the state changed"
    // and "something is worth repainting" genuinely differ.
    final station = await connectedStation();
    final sink = radioDriver.sessions.single.sink;
    var notifications = 0;
    cat.addListener(() => notifications++);

    sink.reportMeter(RadioMeter.swr, 1.2);
    expect(notifications, 1);
    sink.reportMeter(RadioMeter.swr, 1.2);
    expect(notifications, 1);
    sink.reportMeter(RadioMeter.swr, 2.4);
    expect(notifications, 2);

    // Stored either way: the second reading is what keeps the first from
    // ageing out while the radio is still transmitting.
    expect(cat.stateFor(station.radioNode.uuid).telemetry.meters[RadioMeter.swr]?.value, 2.4);
  });
}
