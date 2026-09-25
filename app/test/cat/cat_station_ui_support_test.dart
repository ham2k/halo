// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the Station panel leans on from the CAT layer: a radio added before
// it has a port or an address, the Bluetooth pairing's port preference, and
// the Radio Mode picker's list of modes and the command it sends.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_cat_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/rigctld_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/yaesu_binary_codec.dart' as binary;
import 'package:ham2k_logger/services/cat/drivers/yaesu_cat_codec.dart' as yaesu;
import 'package:ham2k_logger/services/cat/drivers/civ_codec.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/main_vfo.dart';
import 'package:ham2k_logger/services/cat/radio_modes.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transports/bluetooth_serial_transport.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';
import 'package:ham2k_logger/services/peer/peer_station_radios.dart';
import 'package:ham2k_logger/views/operation/logging_panel.dart' show radio1ConnectAction;

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final registry = EquipmentRegistry();

  test('a radio with no port is unconfigured: the editor saves it, and nothing ever tries it', () async {
    // The trap on either side: an editor that refuses a blank port leaves an
    // operator no way to add the rig before the cable arrives; a connect
    // that tries one fails on every retry and paints the row red for it.
    final services = (await makeHaLoServices()).services;
    final node = await services.cat.addNode(typeKey: 'ft891-serial', name: 'Rig', config: const {});
    final type = services.cat.typeFor(node)!;

    expect(type.isUnconfigured(node.config), isTrue);
    expect(type.validateEditorField('port', '', node.config), isNull, reason: 'the editor saves it');
    expect(type.validate(node.config), isNotNull, reason: 'a connect would still refuse it, so it must never get that far');

    await services.cat.connect(node.uuid);
    final state = services.cat.stateFor(node.uuid);
    expect(state.status, EquipmentStatus.disconnected);
    expect(state.error, isNull, reason: 'not configured is not a failure');
  });

  test('a port makes it configured again, and the transport checks come back', () {
    final type = registry.typeFor('ft891-serial')!;
    final config = {'port': '/dev/cu.usbserial-1'};
    expect(type.isUnconfigured(config), isFalse);
    expect(type.validateEditorField('port', '/dev/cu.usbserial-1', config), isNull);
  });

  test('the Bluetooth pairing ranks the ports with no USB identity first', () {
    // macOS reads no USB ids, so the NAME is what tells a paired radio's
    // cu.<name> apart from a USB bridge there.
    const bluetooth = BluetoothSerialTransport();
    expect(bluetooth.prefersPort(const SerialPortOption(name: '/dev/cu.ICOM_BT_IC-705')), isTrue);
    expect(bluetooth.prefersPort(const SerialPortOption(name: '/dev/cu.usbserial-00F8E1EB0')), isFalse);
    expect(bluetooth.prefersPort(const SerialPortOption(name: 'COM7', vendorId: 0x0403)), isFalse, reason: 'a USB bridge on Windows');
    expect(const SerialTransport().prefersPort(const SerialPortOption(name: '/dev/cu.ICOM_BT_IC-705')), isFalse, reason: 'USB serial ranks nothing on its own');
    // The ports every machine has open and then answer nothing: suggesting
    // one sends the operator to a CAT timeout.
    expect(bluetooth.prefersPort(const SerialPortOption(name: '/dev/cu.Bluetooth-Incoming-Port')), isFalse);
    expect(bluetooth.prefersPort(const SerialPortOption(name: '/dev/cu.debug-console')), isFalse);
    expect(bluetooth.prefersPort(const SerialPortOption(name: '/dev/ttyS0')), isFalse);
    expect(bluetooth.prefersPort(const SerialPortOption(name: 'COM1')), isFalse, reason: 'a PC\'s own serial port');
    expect(bluetooth.prefersPort(const SerialPortOption(name: '/dev/rfcomm0')), isTrue);
    expect(bluetooth.prefersPort(const SerialPortOption(name: 'COM9', description: 'Standard Serial over Bluetooth link')), isTrue);
  });

  test('a named Icom offers its own modes, not every mode CI-V can name', () {
    // One driver serves them all; a mode the model lacks is a pick the radio
    // refuses, so each named radio pins its own list.
    List<String> modesOf(String key) {
      final type = registry.typeFor(key)!;
      return type.driver.settableModes(type.driverConfig(type.defaultConfig));
    }

    expect(modesOf('ic705-network'), containsAll(['DV', 'WFM', 'DATA-USB']));
    expect(modesOf('ic7300-serial'), isNot(anyOf(contains('DV'), contains('WFM'))));
    expect(modesOf('ic7300-serial'), contains('DATA-USB'));
    expect(modesOf('ic706mkiig-serial'), isNot(contains('DATA-USB')), reason: 'no DATA submode on this radio');
    expect(modesOf('icom-generic-serial'), containsAll(['DV', 'WFM', 'DATA-USB']), reason: 'an unnamed Icom could be any of them');
  });

  test('every mode the Radio Mode picker offers is one its driver has a command for', () {
    // The list is drawn from the same table setMode sends from; a mode
    // listed but unsendable would be a pick that silently does nothing.
    bool sends(EquipmentType type, String mode) => switch (type.driver.key) {
      'ft891' => yaesu.buildSetModeCommand(mode) != null,
      'yaesu-binary' => binary.buildSetModeCommand(mode) != null,
      'elecraft-k4' => buildK4SetModeCommand(mode) != null,
      'kenwood' => buildKenwoodSetModeCommand(mode) != null || dataModeBases.containsKey(mode),
      'icom-civ' => civModeCodes.containsKey(mode) || dataModeBases.containsKey(mode),
      'rigctld' => hamlibModeForAppMode(mode) != null,
      _ => true,
    };
    var checked = 0;
    for (final type in registry.types) {
      final modes = type.driver.settableModes(type.driverConfig(type.defaultConfig));
      if (type.category == kCategoryTransceiver) expect(modes, isNotEmpty, reason: '${type.key} offers no mode at all');
      for (final mode in modes) {
        expect(sends(type, mode), isTrue, reason: '${type.key} offers $mode');
        checked++;
      }
    }
    expect(checked, greaterThan(100), reason: 'the loop reached the catalogue');
  });

  /// Waits on a condition, not a guess at how long the radio takes.
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue, reason: 'the radio never got there');
  }

  test('picking a radio mode tells the radio, and the logged mode follows the radio\'s report', () async {
    // The picker speaks the radio's modes and never writes VFO A itself: the
    // mode reaches the log only through the radio's report, the same path a
    // turn of the rig's own mode knob takes.
    final services = (await makeHaLoServices()).services;
    final node = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench', config: placeholderRadioModel.variants.single.defaultConfig);
    await services.cat.setRadio1(LocalRadio(node.uuid));
    await services.cat.connect(node.uuid);
    expect(services.cat.stateFor(node.uuid).status, EquipmentStatus.connected);
    expect(services.cat.radio1SettableModes, containsAll(['CW', 'DATA-USB']));

    services.cat.setRadio1Mode('CW');
    await until(() => services.cat.stateFor(node.uuid).vfo.mode == 'CW');
    await until(() => services.radio.vfoA.mode == 'CW');
  });

  test('the Radio control\'s plug is offered only for a radio this device can connect', () async {
    // Hidden for a peer's radio (its session is the other device's), for one
    // with no port (nothing to open) and for one already up.
    final services = (await makeHaLoServices()).services;
    final cat = services.cat;

    final bare = await cat.addNode(typeKey: 'ft891-serial', name: 'No Port', config: const {});
    await cat.setRadio1(LocalRadio(bare.uuid));
    expect(radio1ConnectAction(cat, connected: false), isNull, reason: 'unconfigured');

    final bench = await cat.addNode(typeKey: 'placeholder-radio', name: 'Bench', config: placeholderRadioModel.variants.single.defaultConfig);
    await cat.setRadio1(LocalRadio(bench.uuid));
    expect(radio1ConnectAction(cat, connected: true), isNull, reason: 'already connected');
    final connect = radio1ConnectAction(cat, connected: false);
    expect(connect, isNotNull);
    connect!();
    await until(() => cat.stateFor(bench.uuid).status == EquipmentStatus.connected);

    await cat.setRadio1(const PeerRadio(PeerRadioSelection(deviceId: 'd', radioId: 'r', deviceName: 'Pad', radioName: 'FTDX10')));
    expect(radio1ConnectAction(cat, connected: false), isNull, reason: "a peer's radio");
  });

  test('a port filled in on the main radio is tried at once, not left for a manual Connect', () async {
    // Nothing retries an unconfigured node, so the save is the only moment
    // the app learns there is now something to connect to.
    final services = (await makeHaLoServices()).services;
    final cat = services.cat;
    final node = await cat.addNode(typeKey: 'ft891-serial', name: 'Rig', config: const {});
    await cat.setRadio1(LocalRadio(node.uuid));
    await cat.connect(node.uuid);
    expect(cat.stateFor(node.uuid).status, EquipmentStatus.disconnected);

    await cat.updateNode(node.copyWith(config: {'port': '/dev/cu.nothing-here', 'baudRate': 4800}));
    // No serial port exists in a test, so the attempt fails — and failing is
    // the proof it was made.
    await until(() => cat.stateFor(node.uuid).status != EquipmentStatus.disconnected);
  });

  test('a stored port of the wrong shape is a broken record, not an unconfigured one', () {
    // Read as "not configured" it would be skipped in silence; it has to
    // reach validate(), which reports it.
    final type = registry.typeFor('ft891-serial')!;
    expect(type.isUnconfigured({'port': 42}), isFalse);
    expect(type.isUnconfigured({'port': '   '}), isTrue);
  });
}
