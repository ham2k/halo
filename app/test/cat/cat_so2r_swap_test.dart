// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// SWAP's radio side — docs/design/cat.md § Radio B, for SO2R: the radios'
// Run or S&P trade places, and on two slices of one radio their antenna
// ports and antennas in use (CatService.swapStyles, CatService.swapRadioSettings). The VFOs move
// with the logging panel's entries, tested in halo_widgets'
// logging_controls_so2r_swap_test.dart.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/cat/transports/none_transport.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Connection implements EquipmentConnection {
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

class _Transport extends EquipmentTransport {
  @override
  String get key => 'fake';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async => _Connection();
}

/// A rig that picks among its own antenna ports, and records each pick.
class _Rig implements TransceiverSession, RadioAntennaSession {
  _Rig(this.sink);
  final EquipmentSink sink;
  final picks = <(String?, String?)>[];

  void ports(RadioAntennas antennas) => (sink as RadioAntennaSink).reportAntennas(antennas);

  @override
  void setAntenna({String? rx, String? tx}) => picks.add((rx, tx));
  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}
  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  void teardown() {}
  @override
  Duration? get expectedUpdateInterval => null;
}

class _RigDriver extends EquipmentDriver {
  _RigDriver(this.made);
  final List<_Rig> made;
  @override
  String get key => 'rig';
  @override
  String get name => 'Rig';

  /// A node configured with a `radio` is that radio's `receiver`: two
  /// slices of one rig.
  @override
  ({String radio, int receiver})? so2rAudioReceiverWith(Map<String, dynamic> config) => switch (config) {
    {'radio': final String radio, 'receiver': final int receiver} => (radio: radio, receiver: receiver),
    _ => null,
  };

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final session = _Rig(sink);
    made.add(session);
    return session;
  }
}

void main() {
  late SettingsService settings;
  late CatService cat;
  late List<_Rig> rigs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setExperimentEnabled('so2r', true);
    final radio = RadioService(await SharedPreferences.getInstance(), writeDelay: Duration.zero);
    addTearDown(radio.dispose);
    rigs = [];
    final transport = _Transport();
    cat = CatService(
      settings,
      radio: radio,
      registry: EquipmentRegistry(
        models: [
          EquipmentModel(
            key: 'rig',
            category: kCategoryTransceiver,
            name: () => 'Rig',
            variants: [EquipmentVariant(key: 'rig-type', driver: _RigDriver(rigs), transport: transport)],
          ),
          antennaModel,
        ],
        transports: {'fake': transport, 'none': const NoneTransport()},
      ),
    );
    addTearDown(cat.dispose);
  });

  /// Radio A's rig and Radio B's, connected, reporting [a] and [b] — two
  /// slices of one radio unless [separate].
  Future<(_Rig, _Rig)> twoRigs(RadioAntennas a, RadioAntennas b, {bool separate = false}) async {
    Map<String, dynamic> slice(String host, int receiver) => separate ? {'host': host} : {'host': host, 'radio': 'flex', 'receiver': receiver};
    final nodeA = await cat.addNode(typeKey: 'rig-type', config: slice('a', 0));
    final nodeB = await cat.addNode(typeKey: 'rig-type', config: slice('b', 1));
    await cat.setRadio1(LocalRadio(nodeA.uuid));
    await cat.setRadio2(nodeB.uuid);
    await cat.connect(nodeA.uuid);
    await cat.connect(nodeB.uuid);
    final rigA = rigs.firstWhere((r) => identical(r, cat.connectedSession(nodeA.uuid)));
    final rigB = rigs.firstWhere((r) => identical(r, cat.connectedSession(nodeB.uuid)));
    rigA.ports(a);
    rigB.ports(b);
    await pumpEventQueue();
    return (rigA, rigB);
  }

  const flexPorts = (rx: ['ANT1', 'ANT2', 'RX_A'], tx: ['ANT1', 'ANT2']);

  test("two slices of one radio trade their ports: each takes the other's receive and transmit antenna", () async {
    final (a, b) = await twoRigs(
      RadioAntennas(rxPorts: flexPorts.rx, txPorts: flexPorts.tx, rx: 'ANT1', tx: 'ANT1', separate: true),
      RadioAntennas(rxPorts: flexPorts.rx, txPorts: flexPorts.tx, rx: 'RX_A', tx: 'ANT2', separate: true),
    );
    cat.swapRadioSettings();
    expect(a.picks, [('RX_A', 'ANT2')]);
    expect(b.picks, [('ANT1', 'ANT1')]);
  });

  // A port name is the same wire only on one radio: an IC-7610's ANT2 is not
  // a TS-890's, and moving one rig to it because the other was there puts
  // that rig's transmitter on whatever its own ANT2 is wired to. Each rig is
  // still on its own wire, which the antenna in use names, so that stays too.
  test('two different rigs keep their own ports and antennas in use, though the port names match', () async {
    const ports = ['ANT1', 'ANT2'];
    final (a, b) = await twoRigs(
      const RadioAntennas(rxPorts: ports, txPorts: ports, rx: 'ANT1', tx: 'ANT1'),
      const RadioAntennas(rxPorts: ports, txPorts: ports, rx: 'ANT2', tx: 'ANT2'),
      separate: true,
    );
    final yagi = await cat.addNode(typeKey: antennaModel.variants.first.key, name: 'Yagi');
    final dipole = await cat.addNode(typeKey: antennaModel.variants.first.key, name: 'Dipole');
    await cat.setDesignated(kCategoryAntenna, yagi.uuid);
    await cat.setDesignated(kCategoryAntenna, dipole.uuid, radio: cat.radio2);

    cat.swapRadioSettings();

    expect(a.picks, isEmpty);
    expect(b.picks, isEmpty);
    expect(cat.designatedFor(kCategoryAntenna), yagi.uuid);
    expect(cat.designatedFor(kCategoryAntenna, radio: cat.radio2), dipole.uuid);
  });

  test('a slice already on the ports it would take is told nothing', () async {
    const same = RadioAntennas(rxPorts: ['ANT1', 'ANT2'], txPorts: ['ANT1', 'ANT2'], rx: 'ANT1', tx: 'ANT1');
    final (a, b) = await twoRigs(same, same);
    cat.swapRadioSettings();
    expect(a.picks, isEmpty);
    expect(b.picks, isEmpty);
  });

  // The antenna in use is what a contact credits. Left with the slice while
  // the ports move, Radio A's next contact names the wire Radio B is on now.
  test("each radio takes the other's antenna in use", () async {
    const one = RadioAntennas(rxPorts: ['ANT1'], txPorts: ['ANT1'], rx: 'ANT1', tx: 'ANT1');
    await twoRigs(one, one);
    final yagi = await cat.addNode(typeKey: antennaModel.variants.first.key, name: 'Yagi');
    final dipole = await cat.addNode(typeKey: antennaModel.variants.first.key, name: 'Dipole');
    await cat.setDesignated(kCategoryAntenna, yagi.uuid);
    await cat.setDesignated(kCategoryAntenna, dipole.uuid, radio: cat.radio2);

    cat.swapRadioSettings();

    expect(cat.designatedFor(kCategoryAntenna), dipole.uuid);
    expect(cat.designatedFor(kCategoryAntenna, radio: cat.radio2), yagi.uuid);
  });

  test('a slice with no antenna in use hands that None across', () async {
    const one = RadioAntennas(rxPorts: ['ANT1'], txPorts: ['ANT1'], rx: 'ANT1', tx: 'ANT1');
    await twoRigs(one, one);
    final yagi = await cat.addNode(typeKey: antennaModel.variants.first.key, name: 'Yagi');
    await cat.setDesignated(kCategoryAntenna, yagi.uuid);
    await cat.setDesignated(kCategoryAntenna, null, radio: cat.radio2);

    cat.swapRadioSettings();

    expect(cat.designatedFor(kCategoryAntenna), isNull, reason: 'Radio A on the Yagi still would credit it to both');
    expect(cat.designatedFor(kCategoryAntenna, radio: cat.radio2), yagi.uuid);
  });

  // Running is the frequency's: the CQ is held there, and after SWAP it is
  // the other radio that holds it.
  test("each radio takes the other's Run or S&P", () async {
    await twoRigs(
      const RadioAntennas(rxPorts: ['ANT1'], txPorts: ['ANT1'], rx: 'ANT1', tx: 'ANT1'),
      const RadioAntennas(rxPorts: ['ANT1'], txPorts: ['ANT1'], rx: 'ANT1', tx: 'ANT1'),
    );
    cat.setRunning('A', true);
    cat.setRunning('B', false);
    cat.swapStyles();
    expect((cat.isRunning('A'), cat.isRunning('B')), (false, true));
    cat.swapStyles();
    expect((cat.isRunning('A'), cat.isRunning('B')), (true, false));
  });
}
