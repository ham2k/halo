// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/panel_radio_service.dart';
import 'package:ham2k_logger/services/radio_service.dart';

class TestRadioType extends Fake implements EquipmentType {
  @override
  String get category => kCategoryTransceiver;
}

class TestSwitchType extends Fake implements EquipmentType {
  @override
  String get category => kCategoryAntennaSwitch;
}

class TestCat extends Fake implements CatService {
  MainVfo? selected = const LocalRadio('a');
  EquipmentState state = const EquipmentState(
    status: EquipmentStatus.connected,
    vfo: VfoReading(freqKHz: 14074, mode: 'USB'),
  );
  @override
  MainVfo? get radio1 => selected;
  @override
  EquipmentNode? nodeFor(String uuid) => ['a', 'b', 'switch'].contains(uuid) ? EquipmentNode(uuid: uuid, typeKey: 'test') : null;
  @override
  List<EquipmentNode> get nodes => [nodeFor('a')!, nodeFor('b')!, nodeFor('switch')!];
  @override
  EquipmentType? typeFor(EquipmentNode node) => node.uuid == 'switch' ? TestSwitchType() : TestRadioType();
  @override
  bool isRadio1(String uuid) => selected == LocalRadio(uuid);
  final connections = <String>[];
  @override
  Future<void> connect(String uuid) async {
    connections.add('connect:$uuid');
  }

  @override
  Future<void> disconnect(String uuid) async {
    connections.add('disconnect:$uuid');
  }

  final tuned = <String, VfoReading>{};
  @override
  void tuneNode(String uuid, VfoReading wanted) {
    tuned[uuid] = wanted;
  }

  @override
  EquipmentState stateFor(String uuid) => state;
  @override
  String displayNameFor(EquipmentNode node) => 'Test radio';
}

class TestRadio extends Fake implements RadioService {
  final calls = <({double? freq, String? mode, int time})>[];
  @override
  void setVfo(
    String key, {
    double? freq,
    String? band,
    String? mode,
    num? power,
    bool clearFreq = false,
    bool clearPower = false,
    VfoOrigin origin = VfoOrigin.user,
  }) {
    calls.add((freq: freq, mode: mode, time: realNowMillis()));
  }
}

void main() {
  test('connection requests honor placement selection and reject stale identities', () {
    final cat = TestCat(), bridge = PanelRadioService(TestCat(), TestRadio());
    final local = PanelRadioService(cat, TestRadio());
    expect(local.setConnection({'id': 'b', 'connected': false})['reason'], 'changed');
    expect(cat.connections, isEmpty);
    expect(local.setConnection({'id': 'b', 'selection': 'b', 'connected': false})['accepted'], true);
    expect(local.setConnection({'id': 'a', 'connected': true})['accepted'], true);
    expect(cat.connections, ['disconnect:b', 'connect:a']);
    expect(bridge.setConnection({'id': 'a', 'connected': 'yes'})['reason'], 'invalid');
  });

  test('CAT reports remain distinct from requested VFO writes and units cross correctly', () async {
    final cat = TestCat(), radio = TestRadio(), bridge = PanelRadioService(cat, radio);
    expect(bridge.read()['frequencyHz'], 14074000);
    final result = await bridge.tune({'id': 'a', 'frequencyHz': 14075000, 'mode': 'CW'});
    expect(result['accepted'], true);
    expect(radio.calls.single.freq, 14075);
    expect(radio.calls.single.mode, 'CW');
    expect((result['state'] as Map)['frequencyHz'], 14074000);
  });
  test('changed selection, stale state, TX and invalid commands never reach CAT', () async {
    final cat = TestCat(), radio = TestRadio(), bridge = PanelRadioService(cat, radio);
    expect((await bridge.tune({'id': 'b', 'frequencyHz': 14075000}))['reason'], 'changed');
    cat.state = cat.state.copyWith(stale: true);
    expect((await bridge.tune({'id': 'a', 'frequencyHz': 14075000}))['reason'], 'disconnected');
    cat.state = cat.state.copyWith(stale: false, telemetry: const RadioTelemetry(transmitting: true));
    expect((await bridge.tune({'id': 'a', 'mode': 'CW'}))['reason'], 'transmitting');
    cat.state = cat.state.copyWith(telemetry: const RadioTelemetry(transmitting: false));
    expect((await bridge.tune({'id': 'a', 'frequencyHz': double.nan}))['reason'], 'invalid');
    expect(radio.calls, isEmpty);
  });
  test('command pacing preserves the final value and rechecks selection after waiting', () async {
    final cat = TestCat(), radio = TestRadio(), bridge = PanelRadioService(cat, radio);
    await bridge.tune({'id': 'a', 'frequencyHz': 14075000});
    await bridge.tune({'id': 'a', 'frequencyHz': 14076000});
    expect(radio.calls.last.time - radio.calls.first.time, greaterThanOrEqualTo(250));
    expect(radio.calls.last.freq, 14076);
    final waiting = bridge.tune({'id': 'a', 'frequencyHz': 14077000});
    cat.selected = const LocalRadio('b');
    expect((await waiting)['reason'], 'changed');
    expect(radio.calls, hasLength(2));
  });
  test('pinned panels read and tune their radio without changing the logging designation', () async {
    final cat = TestCat(), radio = TestRadio(), bridge = PanelRadioService(cat, radio);
    expect(bridge.list().map((r) => r['id']), ['a', 'b']);
    expect(bridge.read('b')['id'], 'b');
    final result = await bridge.tune({'selection': 'b', 'id': 'b', 'frequencyHz': 7100000});
    expect(result['accepted'], true);
    expect(cat.tuned['b']?.freqKHz, 7100);
    expect(radio.calls, isEmpty);
    expect(cat.radio1, const LocalRadio('a'));
    expect((await bridge.tune({'selection': 'gone', 'id': 'gone', 'frequencyHz': 7100000}))['reason'], 'changed');
  });
  test('expired telemetry is omitted instead of looking like fresh RF output', () {
    final cat = TestCat();
    cat.state = cat.state.copyWith(
      telemetry: RadioTelemetry(meters: {RadioMeter.powerOut: MeterReading(5, nowMillis() - 60000), RadioMeter.supplyVolts: MeterReading(13.8, nowMillis())}),
    );
    final meters = PanelRadioService(cat, TestRadio()).read()['meters'] as Map;
    expect(meters.containsKey('powerOut'), false);
    expect(meters['supplyVolts'], 13.8);
  });

  // The capability reads RADIOS. Naming another device's uuid must not answer
  // with that device's status, problem text or frequency under a blank id.
  test('a selection naming equipment that is not a radio reads as no radio at all', () {
    final cat = TestCat();
    cat.state = cat.state.copyWith(problem: 'relay 3 stuck');
    final read = PanelRadioService(cat, TestRadio()).read('switch');
    expect(read['id'], isNull);
    expect(read['status'], const EquipmentState().status.name);
    expect(read['frequencyHz'], isNull);
    expect(read.values, isNot(contains('relay 3 stuck')));
  });
}
