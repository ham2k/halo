// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The station's antenna switches and rotators as an extension sees them
// (`host.listEquipment`, `setAntenna`, `setRotator`, `stopRotator`). The
// service calls behind each command change nothing on a node that cannot
// take one and tell no one, so every refusal an extension is answered with
// has to be decided here, before anything goes out.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/panel_equipment_service.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_secure_storage.dart';

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
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async => _FakeConnection();
}

mixin _Quiet implements EquipmentSession {
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

class _SwitchSession with _Quiet implements AntennaSwitchSession {
  _SwitchSession(this.sink);
  final EquipmentSink sink;
  final selections = <String>[];
  Object? throws;

  /// What the switch says of itself: two antennas wired, a third not, and
  /// one radio port on the first.
  void report({bool transmitting = false, String selected = '1', List<SwitchAntenna> antennas = wired}) =>
      sink.reportSwitchState(antennas, [SwitchPort(key: '1', label: 'A', selectedAntennaKey: selected, transmitting: transmitting)]);

  static const wired = [
    SwitchAntenna(key: '1', name: 'Yagi'),
    SwitchAntenna(key: '2', name: 'Vertical'),
    SwitchAntenna(key: '3', name: 'Antenna_3', configured: false),
  ];

  @override
  void selectAntenna(String portKey, String antennaKey) {
    if (throws case final error?) throw error;
    selections.add('$portKey->$antennaKey');
  }
}

class _RotatorSession with _Quiet implements RotatorSession {
  _RotatorSession(this.sink);
  final EquipmentSink sink;
  final turns = <num>[];

  void heading(int azimuth) => (sink as RotatorSink).reportRotator(RotatorPosition(azimuth: azimuth));

  var stops = 0;
  Object? throws;

  @override
  RotatorPosition rotateTo({required num azimuth, num? elevation}) {
    if (throws case final error?) throw error;
    turns.add(azimuth);
    // A rotator that stops at 300, as the node's limits would have it.
    return RotatorPosition(azimuth: azimuth.round().clamp(0, 300));
  }

  @override
  void stopRotation() {
    if (throws case final error?) throw error;
    stops++;
  }
}

/// A radio that says when it keys: all a switch with no RF sensing of its
/// own has to go on.
class _RadioSession with _Quiet implements TransceiverSession {
  _RadioSession(this.sink);
  final EquipmentSink sink;

  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}
}

class _Driver extends EquipmentDriver {
  _Driver(this.key, this.make);
  @override
  final String key;
  final EquipmentSession Function(EquipmentSink sink) make;
  final sessions = <EquipmentSession>[];

  @override
  String get name => key;
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final session = make(sink);
    sessions.add(session);
    return session;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RadioService radio;
  late CatService cat;
  late PanelEquipmentService equipment;
  late _Driver switchDriver, rotatorDriver, radioDriver;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    radio = RadioService(prefs, writeDelay: Duration.zero);
    final transport = _FakeTransport();
    switchDriver = _Driver('test-switch', _SwitchSession.new);
    rotatorDriver = _Driver('test-rotator', _RotatorSession.new);
    radioDriver = _Driver('test-radio', _RadioSession.new);
    cat = CatService(
      SettingsService(prefs, secureStorage: FakeSecureStorage()),
      radio: radio,
      registry: EquipmentRegistry(
        models: [
          EquipmentModel(
            key: 'test-switch',
            category: kCategoryAntennaSwitch,
            name: () => 'Test Switch',
            variants: [EquipmentVariant(key: 'test-switch-type', driver: switchDriver, transport: transport)],
          ),
          EquipmentModel(
            key: 'test-rotator',
            category: kCategoryRotator,
            name: () => 'Test Rotator',
            variants: [EquipmentVariant(key: 'test-rotator-type', driver: rotatorDriver, transport: transport)],
          ),
          EquipmentModel(
            key: 'test-radio',
            category: kCategoryTransceiver,
            name: () => 'Test Radio',
            variants: [EquipmentVariant(key: 'test-radio-type', driver: radioDriver, transport: transport)],
          ),
        ],
        transports: {'fake': transport},
      ),
    );
    equipment = PanelEquipmentService(cat);
  });

  tearDown(() {
    cat.dispose();
    radio.dispose();
  });

  Future<(EquipmentNode, _SwitchSession)> connectedSwitch() async {
    final node = await cat.addNode(typeKey: 'test-switch-type', config: {'host': 'switch.local'});
    await cat.connect(node.uuid);
    final session = switchDriver.sessions.single as _SwitchSession..report();
    return (node, session);
  }

  test('lists switches with their wired antennas and ports, never a radio or an unwired port', () async {
    final (node, _) = await connectedSwitch();
    final listed = equipment.list().single;
    expect(listed['id'], node.uuid);
    expect(listed['kind'], kCategoryAntennaSwitch);
    expect(listed['connected'], isTrue);
    expect([for (final antenna in listed['antennas'] as List) (antenna as Map)['key']], ['1', '2']);
    expect((listed['ports'] as List).single, containsPair('antenna', '1'));
  });

  test('routes a port to an antenna by the switch’s own keys, and refuses what it does not have', () async {
    final (node, session) = await connectedSwitch();
    expect((await equipment.setAntenna({'id': node.uuid, 'port': '1', 'antenna': '3'}))['reason'], 'invalid', reason: 'nothing is wired to it');
    expect((await equipment.setAntenna({'id': 'no-such', 'port': '1', 'antenna': '2'}))['reason'], 'invalid');
    expect((await equipment.setAntenna({'id': node.uuid, 'port': '1', 'antenna': '2'}))['accepted'], isTrue);
    expect(session.selections, ['1->2']);
  });

  // A relay thrown under RF is a relay destroyed: the port's own report is
  // enough to refuse, whatever the radios say.
  test('refuses to switch a port the switch says is transmitting', () async {
    final (node, session) = await connectedSwitch();
    session.report(transmitting: true);
    expect((await equipment.setAntenna({'id': node.uuid, 'port': '1', 'antenna': '2'}))['reason'], 'transmitting');
    expect(session.selections, isEmpty);
  });

  // A switch with no RF sensing (the CX-1 has no PTT input) reports its
  // ports idle while the radio feeding it is on the air: the radio's word is
  // the only thing between the relay and RF.
  test('refuses to switch while a radio it may be feeding is keyed, and the retry after the unkey goes', () async {
    final radioNode = await cat.addNode(typeKey: 'test-radio-type', config: {'host': 'radio.local'});
    await cat.connect(radioNode.uuid);
    final (node, session) = await connectedSwitch();
    final radioSink = (radioDriver.sessions.single as _RadioSession).sink;

    radioSink.reportTransmitting(true);
    expect((await equipment.setAntenna({'id': node.uuid, 'port': '1', 'antenna': '2'}))['reason'], 'transmitting');
    expect(session.selections, isEmpty);

    radioSink.reportTransmitting(false);
    expect((await equipment.setAntenna({'id': node.uuid, 'port': '1', 'antenna': '2'}))['accepted'], isTrue);
    expect(session.selections, ['1->2']);
  });

  // A switch that has not finished its startup exchanges has published no
  // ports, or ports but no antennas yet: every key would read as one it does
  // not have, and `invalid` tells an extension its key is wrong for good.
  test('a switch that has not yet said what it has is not ready, not invalid', () async {
    final node = await cat.addNode(typeKey: 'test-switch-type', config: {'host': 'switch.local'});
    await cat.connect(node.uuid);
    expect((await equipment.setAntenna({'id': node.uuid, 'port': '1', 'antenna': '2'}))['reason'], 'disconnected', reason: 'no ports yet');
    (switchDriver.sessions.single as _SwitchSession).report(antennas: const []);
    expect((await equipment.setAntenna({'id': node.uuid, 'port': '1', 'antenna': '2'}))['reason'], 'disconnected', reason: 'ports, no antennas yet');
  });

  // `accepted` means sent: a driver that threw sent nothing, whatever the
  // device's status says.
  test('a command the driver could not send is failed, not accepted', () async {
    final (node, session) = await connectedSwitch();
    session.throws = StateError('link down');
    expect((await equipment.setAntenna({'id': node.uuid, 'port': '1', 'antenna': '2'}))['reason'], 'failed');

    final rotator = await cat.addNode(typeKey: 'test-rotator-type', config: {'host': 'rotator.local'});
    await cat.connect(rotator.uuid);
    (rotatorDriver.sessions.single as _RotatorSession).throws = StateError('link down');
    expect(equipment.stopRotator({'id': rotator.uuid})['reason'], 'failed');
    expect((await equipment.setRotator({'id': rotator.uuid, 'azimuth': 90}))['reason'], 'failed');
  });

  // A dragged dial sends a step every few milliseconds, and the last one is
  // where the operator let go: dropped as too soon, it would leave the
  // rotator at a heading they had already passed.
  test('commands to one device go out in order and spaced, and the one right behind is not lost', () async {
    final node = await cat.addNode(typeKey: 'test-rotator-type', config: {'host': 'rotator.local'});
    await cat.connect(node.uuid);
    final session = rotatorDriver.sessions.single as _RotatorSession;

    final first = equipment.setRotator({'id': node.uuid, 'azimuth': 350, 'extensionKey': 'dial'});
    final last = equipment.setRotator({'id': node.uuid, 'azimuth': 175, 'extensionKey': 'dial'});
    final turned = await first;
    expect(((turned['state'] as Map)['target'] as Map)['azimuth'], 300, reason: 'where its limits turn it, not where it was asked');
    expect(session.turns, [350], reason: 'the next waits out the spacing');
    expect((await last)['accepted'], isTrue);
    expect(session.turns, [350, 175]);
  });

  // An extension calling in a loop must not hold the device for long: past
  // four waiting, its commands are refused, and nobody else's are.
  test('a fifth command from one extension while four wait is busy', () async {
    final node = await cat.addNode(typeKey: 'test-rotator-type', config: {'host': 'rotator.local'});
    await cat.connect(node.uuid);
    final waiting = [
      for (var i = 0; i < 4; i++) equipment.setRotator({'id': node.uuid, 'azimuth': 10 * i, 'extensionKey': 'loop'}),
    ];
    expect((await equipment.setRotator({'id': node.uuid, 'azimuth': 90, 'extensionKey': 'loop'}))['reason'], 'busy');
    final other = equipment.setRotator({'id': node.uuid, 'azimuth': 90, 'extensionKey': 'other'});
    expect(equipment.stopRotator({'id': node.uuid})['accepted'], isTrue);
    expect(
      [
        for (final call in [...waiting, other]) (await call)['reason'],
      ],
      [null, 'expired', 'expired', 'expired', 'expired'],
    );
  });

  // A stop is the last word: a turn queued before it, going out after it,
  // would start the rotator again.
  test('a stop goes at once and takes the turns still waiting with it', () async {
    final node = await cat.addNode(typeKey: 'test-rotator-type', config: {'host': 'rotator.local'});
    await cat.connect(node.uuid);
    final session = rotatorDriver.sessions.single as _RotatorSession;
    await equipment.setRotator({'id': node.uuid, 'azimuth': 350});
    final queued = equipment.setRotator({'id': node.uuid, 'azimuth': 90});

    expect(equipment.stopRotator({'id': node.uuid})['accepted'], isTrue);
    expect(session.stops, 1);
    expect((await queued)['reason'], 'expired');
    expect(session.turns, [350]);
  });

  // The drivers disagree outside 0–360: GS-232 and rotctld wrap -10 to 350,
  // PstRotator clamps it to 0 — the wrong side of the compass.
  test('an azimuth is a bearing, taken modulo 360, and an elevation past 180 is invalid', () async {
    final node = await cat.addNode(typeKey: 'test-rotator-type', config: {'host': 'rotator.local'});
    await cat.connect(node.uuid);
    final session = rotatorDriver.sessions.single as _RotatorSession;
    expect((await equipment.setRotator({'id': node.uuid, 'azimuth': -10}))['accepted'], isTrue);
    expect(session.turns, [350]);
    expect((await equipment.setRotator({'id': node.uuid, 'azimuth': 90, 'elevation': 400}))['reason'], 'invalid');
  });

  test('a device not connected is answered disconnected, and sent nothing', () async {
    final node = await cat.addNode(typeKey: 'test-rotator-type', config: {'host': 'rotator.local'});
    expect((await equipment.setRotator({'id': node.uuid, 'azimuth': 90}))['reason'], 'disconnected');
    expect(equipment.stopRotator({'id': node.uuid})['reason'], 'disconnected');
  });

  // The trigger fires on what an extension acts on — a port re-routed, a
  // turn ordered — and must not fire for each heading a turning rotator
  // reports, several a second.
  test('the equipment signature moves with a re-route, a renamed antenna and a turn ordered, not with an over or a heading', () async {
    final (_, session) = await connectedSwitch();
    final before = equipmentSignature(cat);
    session.report(selected: '2');
    expect(equipmentSignature(cat), isNot(before));
    final routed = equipmentSignature(cat);
    session.report(selected: '2', transmitting: true);
    expect(equipmentSignature(cat), routed, reason: 'a port keying for an over is no change');
    // Ports and antennas come in separate exchanges: a panel drawn between
    // them has no antenna names until this fires.
    session.report(
      selected: '2',
      antennas: const [
        SwitchAntenna(key: '1', name: 'Yagi'),
        SwitchAntenna(key: '2', name: 'Loop'),
      ],
    );
    expect(equipmentSignature(cat), isNot(routed), reason: 'an antenna renamed');

    final rotator = await cat.addNode(typeKey: 'test-rotator-type', config: {'host': 'rotator.local'});
    await cat.connect(rotator.uuid);
    final rotatorSession = rotatorDriver.sessions.single as _RotatorSession;
    await equipment.setRotator({'id': rotator.uuid, 'azimuth': 90});
    final turning = equipmentSignature(cat);
    rotatorSession.heading(40);
    expect(equipmentSignature(cat), turning, reason: 'a heading on the way is no change');
    rotatorSession.heading(90);
    expect(equipmentSignature(cat), isNot(turning), reason: 'arriving lets the target go');
  });
}
