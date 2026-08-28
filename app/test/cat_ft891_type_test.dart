// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The FT-891 as a configurable piece of equipment: what the editor asks
// for, what the transport is handed, and what the list row says.
//
// The point of most of this is that baud is the operator's to choose.
// app-polo hardcoded 4800 with no UI, which its own notes call out as a
// silent-failure mode — a radio whose CAT menu says 38400 answers with
// garbage and no error, and nothing on screen suggests why.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/ft891_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/yaesu_cat_codec.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';

void main() {
  final type = EquipmentRegistry().typeFor('ft891-serial')!;

  test('is a transceiver reached over a serial port', () {
    expect(type.key, 'ft891-serial');
    expect(type.category, kCategoryTransceiver);
    expect(type.transportKey, SerialTransport.transportKey);
    expect(type.driver.key, 'ft891');
  });

  test('defaults to the radio\'s factory CAT speed, and offers the rest', () {
    expect(type.defaultConfig['baudRate'], Ft891Driver.defaultBaudRate);
    expect(Ft891Driver.defaultBaudRate, 4800, reason: 'what the CAT menu ships set to');

    final baudField = type.configElements().firstWhere((e) => e['key'] == 'baudRate');
    final offered = [for (final o in baudField['options'] as List) (o as Map)['value']];
    // Not hardcoded: the mismatch this prevents is invisible otherwise.
    expect(offered, containsAll([4800, 9600, 19200, 38400]));
  });

  group('the status packet Auto-Information actually pushes', () {
    // Captured from a live FT-891 over its own USB port, alongside the
    // FA/MD answers the radio gave for the same moment — so the offsets
    // below are the radio's, not the manual's.
    const captured = 'IF001014233700+000000200000;';

    test('carries both the frequency and the mode in one packet', () {
      final info = parseInformationParams(captured.substring(2, captured.length - 1));
      expect(info, isNotNull);
      expect(info!.freqHz, 14233700, reason: 'the radio answered FA014233700; at the same moment');
      expect(info.mode, 'USB', reason: 'and MD02;');
    });

    test('a driver session reports it, so a dial turn does not wait for the poll', () {
      final sink = _FakeSink();
      final session = Ft891Session(sink);
      session.handleData(Uint8List.fromList(ascii.encode(captured)));

      // Ignoring IF is why a connected radio used to move only every 5s:
      // FA and MD only ever arrive as answers to a read.
      expect(sink.readings, [const VfoReading(freqKHz: 14233.7, mode: 'USB')]);
    });

    test('a short or malformed packet is skipped, not reported as a frequency', () {
      expect(parseInformationParams('001'), isNull);
      expect(parseInformationParams('001xxxxxxxxx+000000200000'), isNull);
    });
  });

  test('asks for a port and a speed, and nothing else', () {
    // Fields only: the form also carries a divider and the troubleshooting
    // note, which have no key and ask the operator for nothing.
    final keys = [
      for (final e in type.configElements())
        if (e['type'] == 'field') e['key'],
    ];
    expect(keys, ['port', 'baudRate']);
  });

  test('and tells the operator why a connected radio can still say nothing', () {
    // The failure this driver actually produces is silence: the commands go
    // out, nothing comes back, and nothing reports an error. Every cause is
    // a setting somewhere else, so the editor is where it has to be said.
    final note = type.configElements().firstWhere((e) => e['type'] == 'markdown');
    expect(note['text'], contains('05-08'), reason: "the radio's CAT RTS menu item");
    expect(note['text'], contains('PTT'), reason: 'why the app will not raise RTS itself');
  });

  test('hands the transport exactly what it needs to open the port', () {
    final target = type.targetFor({'port': '/dev/cu.SLAB_USBtoUART', 'baudRate': 38400});
    expect(target, {'port': '/dev/cu.SLAB_USBtoUART', 'baudRate': 38400});
  });

  test('a baud round-tripped through JSON as a string still opens the port', () {
    // Stored config goes through jsonEncode/Decode, and a select can hand
    // back either shape depending on how it was seeded.
    expect(type.targetFor({'port': 'COM3', 'baudRate': '19200'})['baudRate'], 19200);
    expect(type.targetFor({'port': 'COM3'})['baudRate'], Ft891Driver.defaultBaudRate);
  });

  test('the list row says where it is and how fast', () {
    expect(type.describeTarget({'port': 'COM3', 'baudRate': 9600}), 'COM3 @ 9600');
  });

  test('a node with no port chosen is refused before the port is opened', () {
    expect(type.validate({'baudRate': 4800}), isNotNull);
    expect(type.validate({'port': '', 'baudRate': 4800}), isNotNull);
    expect(type.validate({'port': 'COM3', 'baudRate': 4800}), isNull);
  });

  test('the registry offers it alongside FlexRadio, over its own transport', () {
    final registry = EquipmentRegistry();
    expect(registry.typeFor('ft891-serial')?.key, 'ft891-serial');
    expect(registry.typeFor('flexradio-tcp')?.key, 'flexradio-tcp');
    // Two drivers, two transports — the split earning its keep.
    expect(registry.transportFor('serial'), isNotNull);
    expect(registry.transportFor('tcp'), isNotNull);
  });

  test('enumerating ports is safe with no hardware attached', () {
    // Runs on CI machines with nothing plugged in; must return a list, not
    // throw, so the editor can say "no serial ports found".
    expect(availableSerialPorts(), isA<List<SerialPortOption>>());
  });
}

class _FakeSink implements EquipmentSink {
  final problems = <String?>[];
  List<EquipmentChannel> channels = const [];
  final sent = <List<int>>[];
  final readings = <VfoReading>[];
  final powers = <num>[];
  final diagnostics = <String?>[];

  @override
  void send(List<int> bytes) => sent.add(bytes);

  @override
  void report(VfoReading reading) => readings.add(reading);

  @override
  void reportPower(num watts) => powers.add(watts);

  @override
  void reportDiagnostic(String? note) => diagnostics.add(note);
  @override
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportChannels(List<EquipmentChannel> channels) => this.channels = channels;

  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
}
