// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A definition's `overrides`/`restrictions` are plain data, checked by
// nothing at compile time — a typo'd key (`cvAddress` for `civAddress`) is
// silently ignored by both transport and driver, since "unrecognized key"
// and "hardcode this field" look identical from either one's side. This is
// the one place that gets caught: every definition's hints are checked
// against what its own transport/driver would actually declare, so a typo
// fails a test instead of quietly doing nothing for a radio nobody has
// tested yet.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/civ_power.dart';
import 'package:ham2k_logger/services/cat/drivers/cw_send_queue.dart';
import 'package:ham2k_logger/services/cat/drivers/ft891_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/icom_civ_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_cat_codec.dart';
import 'package:ham2k_logger/services/cat/drivers/kenwood_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/yaesu_cat_codec.dart' show yaesuVoiceMemoryCount;
import 'package:ham2k_logger/services/cat/equipment_brands.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transports/none_transport.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport.dart';
import 'package:ham2k_logger/services/cat/transports/serial_transport_io.dart' as native show SerialTransport;

import '../support/fake_serial_ports.dart';

void main() {
  setUp(() => useSerialPortsForTest(const []));

  final registry = EquipmentRegistry();

  for (final transportKey in ['serial', 'bluetoothSerial']) {
    test('$transportKey catalogue forms read current fixture ports', () {
      final previous = native.SerialTransport.debugPortEnumerator;
      addTearDown(() => expect(native.SerialTransport.debugPortEnumerator, same(previous)));
      final ports = [const SerialPortOption(name: 'COM8', description: 'Test radio')];
      useSerialPortsForTest(ports);
      final type = registry.types.firstWhere((type) => type.transportKey == transportKey);

      List<Object?> offeredPorts() => [
        for (final option in type.configElements().firstWhere((field) => field['key'] == 'port')['options'] as List) (option as Map)['value'],
      ];

      expect(offeredPorts(), ['COM8']);
      // A form opened after an unplug must not reuse its earlier port list.
      ports.clear();
      expect(offeredPorts(), isEmpty);
    });
  }

  test("a baud rate the node's transport has no field for never reaches the driver", () {
    // Left over from a serial pairing the node was switched from, it would
    // pace a WiFi link like a 19200 cable and refuse its scope as too slow.
    const stale = {'host': '10.0.0.5', 'baudRate': 19200};
    expect(registry.typeFor('ic705-network')!.driverConfig(stale)['baudRate'], isNull);
    expect(registry.typeFor('ic705-serial')!.driverConfig(stale)['baudRate'], 19200);
  });

  for (final type in registry.types) {
    group(type.key, () {
      // Every key the transport/driver actually reads — whether or not it
      // shows a field for it.
      final knownKeys = {...type.transport.recognizedConfigKeys, ...type.driver.recognizedConfigKeys};

      test('every overridden key is a field its transport or driver actually declares', () {
        for (final key in type.overrides.keys) {
          expect(
            knownKeys,
            contains(key),
            reason:
                '"$key" is overridden, but neither the transport nor the driver '
                'declares a field by that key — a typo here silently hardcodes nothing.',
          );
        }
      });

      // The test above only proves the KEY is real; it says nothing about
      // whether the transport/driver actually honored the override by
      // hiding the field. That guard is hand-written per field, per
      // provider — nothing enforces it centrally — so this is the one
      // place a forgotten `overrides.containsKey(...)` check gets caught,
      // instead of shipping as a field a user can "edit" whose value
      // silently never takes (EquipmentType._merged clobbers it with the
      // override at connect/save time regardless of what the form showed).
      test('every overridden key is actually hidden from the assembled form', () {
        final renderedKeys = type.configElements().where((e) => e['type'] == 'field').map((e) => e['key'] as String).toSet();
        for (final key in type.overrides.keys) {
          expect(
            renderedKeys,
            isNot(contains(key)),
            reason:
                '"$key" is overridden (meant to be hardcoded and hidden), but still renders '
                'as a field — the transport/driver is missing its containsKey(overrides) guard.',
          );
        }
      });

      test('every restricted key is a field its transport or driver actually declares', () {
        for (final key in type.restrictions.keys) {
          expect(
            knownKeys,
            contains(key),
            reason:
                '"$key" is restricted, but neither the transport nor the driver '
                'declares a field by that key — a typo here silently narrows nothing.',
          );
        }
      });

      test('a restriction only narrows the field\'s own options, never adds to them', () {
        final unrestrictedFields = [...type.transport.configElements(), ...type.driver.configElements()].where((e) => e['type'] == 'field').toList();
        for (final entry in type.restrictions.entries) {
          final field = unrestrictedFields.where((e) => e['key'] == entry.key);
          if (field.isEmpty) continue; // caught by the test above
          final options = field.first['options'];
          final restricted = entry.value;
          if (options is! List || restricted is! List) continue;

          final allowedValues = options.map((o) => (o as Map)['value']).toSet();
          final restrictedValues = restricted.toSet();

          expect(restrictedValues, isNotEmpty, reason: '"${entry.key}" is restricted to nothing at all');
          expect(allowedValues.containsAll(restrictedValues), isTrue, reason: '"${entry.key}" is restricted to a value its transport/driver never offers');
        }
      });
    });
  }

  // resolveIconName answers an unknown name with a puzzle-piece glyph — no
  // exception, no analyzer error, no log. A typo like 'usbport' for
  // 'usb-port' therefore ships as a jigsaw next to a radio and nothing
  // anywhere says so. This is the only thing that can catch it.
  test('every transport names an icon the codepoint table actually has', () {
    for (final type in registry.types) {
      // The one deliberate exception: NoneTransport moves no bytes, so it
      // has nothing to depict as "how it's plugged in" — the equipment
      // tile for its category never renders a transport glyph at all.
      if (type.transportKey == NoneTransport.transportKey) continue;
      final name = type.transportIconName;
      expect(name, isNotNull, reason: '${type.transportKey} has no icon, so its rows show nothing');
      expect(
        resolveIconName(name!),
        isNot(MdiIcons.puzzle),
        reason:
            '"$name" is not in the generated codepoint table — resolveIconName '
            'falls back to a puzzle piece rather than failing',
      );
    }
  });

  // The section header is the operator's only clue about what is behind a
  // collapsed tile, and FormRenderer renders a missing one as an empty
  // string: a bare chevron with no label, silently.
  test('every variant with notes gives them a collapsible section with a title', () {
    for (final type in registry.types) {
      for (final note in type.notes) {
        if (note['type'] != 'markdown') continue;
        expect(note['collapsible'], isTrue, reason: '${type.key} renders notes open, burying its own fields');
        expect(
          note['title'],
          isA<String>().having((t) => t.isNotEmpty, 'is not empty', isTrue),
          reason: '${type.key} would render a chevron with no label at all',
        );
        expect(note['text'], isA<String>().having((t) => t.isNotEmpty, 'is not empty', isTrue));
      }
    }
  });

  // A renamed key is the one change to this file that fails silently and
  // destructively: the stored record survives, resolves to nothing, and the
  // panel lists it as an unrecognized type with the operator's whole
  // configuration sealed inside. Every rename has to leave a forwarding
  // address, and every forwarding address has to point somewhere real.
  group('renamed keys still find their pairing', () {
    test('every old key maps to one the catalogue still has', () {
      for (final entry in renamedTypeKeys.entries) {
        expect(registry.typeFor(entry.value), isNotNull, reason: '"${entry.key}" forwards to "${entry.value}", which no longer exists');
        expect(registry.typeFor(entry.key), isNull, reason: '"${entry.key}" is still a live key, so nothing was actually renamed');
      }
    });

    test('a node stored under the old key loads as the new one', () {
      // The pre-rename record, exactly as a build from before it wrote one.
      final node = EquipmentNode.fromJson('radio-1', {
        'typeKey': 'icom-civ-serial',
        'name': 'The 7300',
        'config': {'port': '/dev/cu.usbserial', 'civAddress': '94'},
      });

      expect(node, isNotNull);
      expect(node!.typeKey, 'icom-generic-serial');
      expect(registry.typeFor(node.typeKey), isNotNull, reason: 'it has to resolve, not just be renamed');
      // And it keeps everything that made it worth migrating.
      expect(node.name, 'The 7300');
      expect(node.config['civAddress'], '94');
    });
  });

  // The equipment editor puts two of its own fields alongside whatever a
  // pairing declares — `name`, and `transport` when a radio offers more than
  // one — and strips both from the config on the way out. A transport or
  // driver declaring either name would have its value overwritten by the
  // editor's and then deleted at every save, silently: the config map is
  // free-form, so nothing else in the system can notice.
  test('nothing declares a config key the editor reserves for itself', () {
    for (final type in registry.types) {
      for (final key in {...type.transport.recognizedConfigKeys, ...type.driver.recognizedConfigKeys}) {
        expect(
          key,
          isNot(anyOf('name', 'transport')),
          reason:
              '${type.key} declares "$key", which the editor uses for its own field '
              'and removes before saving — the value would never survive',
        );
      }
    }
  });

  test('every type key is unique', () {
    final keys = registry.types.map((t) => t.key).toList();
    expect(keys.toSet().length, keys.length, reason: 'a duplicate key makes typeFor() find the wrong one');
  });

  // A variant key is what a configured node stores. Renaming one does not
  // fail anywhere — the node simply stops resolving, and the panel shows it
  // as a type that no longer exists with everything the operator set up
  // still inside it. So the shipped set is written down, and changing it has
  // to be a deliberate edit here rather than a side effect of moving a
  // variant between models.
  test('the shipped variant keys are exactly these', () {
    expect(registry.types.map((t) => t.key).toSet(), {
      'flexradio-tcp',
      'ft891-serial',
      'ft991a-serial',
      'ft710-serial',
      'ftdx10-serial',
      'ftx1-serial',
      'ft450-serial',
      'yaesu-serial',
      'ft817-serial',
      'ft857-serial',
      'ft897-serial',
      'q900-serial',
      'q900-bluetooth',
      'sotacat-tcp',
      'icom-generic-serial',
      'kenwood-serial',
      'qmx-serial',
      'fx4cr-serial',
      'qcx-serial',
      'ts590sg-serial',
      'ts480-serial',
      'tx500-serial',
      'tx500mp-serial',
      'tx500mp-bluetooth',
      'tentec-599-serial',
      'tentec-565-serial',
      'tentec-566-serial',
      'kx2-serial',
      'kx3-serial',
      'k4-serial',
      'k4-tcp',
      'k4-remote',
      'elecraft-serial',
      'ic7300-serial',
      'ic7300mk2-serial',
      'ic7300mk2-network',
      'ic706mkiig-serial',
      'ic7100-serial',
      'ic7610-serial',
      'ic7610-network',
      'ic7760-serial',
      'ic7760-network',
      'ic9700-serial',
      'ic9700-network',
      'ic905-serial',
      'ic905-network',
      'ic7850-serial',
      'ic7850-network',
      'ic7851-serial',
      'ic7851-network',
      'x6100-serial',
      'g90-serial',
      'ic705-network',
      'ic705-serial',
      'ic705-bluetooth',
      'rigctld-tcp',
      'flrig-tcp',
      'hrd-tcp',
      'n3fjp-tcp',
      'dxlab-commander-tcp',
      'placeholder-radio',
      'winkeyer-serial',
      'antenna-genius-tcp',
      'sierra-coax-serial',
      'antenna-none',
      'key-none',
      'rtl-sdr-rtltcp',
      'nesdr-rtltcp',
      'sdrplay-rsptcp',
      // Derived from the model's key, one per real transceiver — stored like
      // any other, so renaming a model's key orphans its placeholder nodes.
      'flexradio-placeholder',
      'ft891-placeholder',
      'ft991a-placeholder',
      'ft710-placeholder',
      'ftdx10-placeholder',
      'ftx1-placeholder',
      'ft450-placeholder',
      'ft817-placeholder',
      'ft857-placeholder',
      'ft897-placeholder',
      'q900-placeholder',
      'yaesu-generic-placeholder',
      'ic705-placeholder',
      'ic7300-placeholder',
      'ic7300mk2-placeholder',
      'ic706mkiig-placeholder',
      'ic7100-placeholder',
      'ic7610-placeholder',
      'ic7760-placeholder',
      'ic9700-placeholder',
      'ic905-placeholder',
      'ic7850-placeholder',
      'ic7851-placeholder',
      'x6100-placeholder',
      'g90-placeholder',
      'icom-generic-placeholder',
      'qmx-placeholder',
      'fx4cr-placeholder',
      'qcx-placeholder',
      'kx2-placeholder',
      'kx3-placeholder',
      'k4-placeholder',
      'elecraft-generic-placeholder',
      'ts590sg-placeholder',
      'ts480-placeholder',
      'kenwood-generic-placeholder',
      'tx500-placeholder',
      'tx500mp-placeholder',
      'tentec-599-placeholder',
      'tentec-565-placeholder',
      'tentec-566-placeholder',
      // Derived the same way, one per model with a serial pairing: that
      // pairing over a Bluetooth LE serial bridge.
      'ft891-ble',
      'ft991a-ble',
      'ft710-ble',
      'ftdx10-ble',
      'ftx1-ble',
      'ft450-ble',
      'ft817-ble',
      'ft857-ble',
      'ft897-ble',
      'q900-ble',
      'yaesu-generic-ble',
      'ic705-ble',
      'ic7300-ble',
      'ic7300mk2-ble',
      'ic706mkiig-ble',
      'ic7100-ble',
      'ic7610-ble',
      'ic7760-ble',
      'ic9700-ble',
      'ic905-ble',
      'ic7850-ble',
      'ic7851-ble',
      'x6100-ble',
      'g90-ble',
      'icom-generic-ble',
      'qmx-ble',
      'fx4cr-ble',
      'qcx-ble',
      'kx2-ble',
      'kx3-ble',
      'k4-ble',
      'elecraft-generic-ble',
      'ts590sg-ble',
      'ts480-ble',
      'kenwood-generic-ble',
      'tx500-ble',
      'tx500mp-ble',
      'tentec-599-ble',
      'tentec-565-ble',
      'tentec-566-ble',
    });
  });

  // A named radio exists so an operator does not have to know their rig's
  // CI-V address or CAT speed to get it talking. The prefills ARE the
  // definition — a model whose defaults drifted to the family's generic ones
  // would still connect for whoever already knew the numbers, and would have
  // stopped doing the one thing it was added for.
  group('radios named after what operators actually run', () {
    final expected = {
      'ft710-serial': ('ft891', {'baudRate': 38400}),
      'ftdx10-serial': ('ft891', {'baudRate': 38400}),
      'ftx1-serial': ('ft891', {'baudRate': 38400}),
      'ic7300-serial': ('icom-civ', {'civAddress': '94', 'baudRate': 19200}),
      // The MK2 is its own entry for this address above all: prefill it with
      // the 7300's '94' and it answers nothing. (It also claims Port A of
      // the two USB ports the original lacks.)
      'ic7300mk2-serial': ('icom-civ', {'civAddress': 'B6', 'baudRate': 115200}),
      'ic706mkiig-serial': ('icom-civ', {'civAddress': '58', 'baudRate': 19200}),
      'ic7100-serial': ('icom-civ', {'civAddress': '88', 'baudRate': 19200}),
      // 115200, pinned: the scope's rate. The MK2 and IC-7760 have no USB
      // speed menu to match; the IC-7610's is set to it.
      'ic7610-serial': ('icom-civ', {'civAddress': '98', 'baudRate': 115200}),
      'ic7760-serial': ('icom-civ', {'civAddress': 'B2', 'baudRate': 115200}),
      'ic9700-serial': ('icom-civ', {'civAddress': 'A2', 'baudRate': 19200}),
      // 115200: the IC-905 has no CI-V speed menu to match, and the scope
      // needs that rate on a serial line.
      'ic905-serial': ('icom-civ', {'civAddress': 'AC', 'baudRate': 115200}),
      // Both on 8E: one radio line, two names on the front panel.
      'ic7850-serial': ('icom-civ', {'civAddress': '8E', 'baudRate': 19200}),
      'ic7851-serial': ('icom-civ', {'civAddress': '8E', 'baudRate': 19200}),
      // CI-V, not the Kenwood protocol the radio's own documentation implies.
      'x6100-serial': ('icom-civ', {'civAddress': 'A4', 'baudRate': 19200}),
      // hamlib's stock G90 address, not the X6100's A4.
      'g90-serial': ('icom-civ', {'civAddress': '88', 'baudRate': 19200}),
      'qmx-serial': ('kenwood', {'baudRate': 9600}),
      // 38400, not the QMX's 9600: the QCX line ships on it, and the QCX-mini
      // behind this entry answered the QMX entry only once changed to it.
      'qcx-serial': ('kenwood', {'baudRate': 38400}),
      // 115200, the TS-590SG's USB speed menu default, not the family's 9600.
      'ts590sg-serial': ('kenwood', {'baudRate': 115200}),
      // The rate the TS-480 was reported working on — also its default.
      'ts480-serial': ('kenwood', {'baudRate': 9600}),
      // 38400, not the Kenwood family's 9600: the whole Elecraft line ships
      // on it, and a speed mismatch is answered with silence, not an error.
      'kx2-serial': ('kenwood', {'baudRate': 38400}),
      'kx3-serial': ('kenwood', {'baudRate': 38400}),
      // The rate Lab599's guide gives for both CAT protocols.
      'tx500-serial': ('kenwood', {'baudRate': 9600}),
      'tx500mp-serial': ('kenwood', {'baudRate': 9600}),
      'tentec-599-serial': ('tentec', {}),
      // RTS high: the Orions' port uses it as the hardware handshake.
      'tentec-565-serial': ('tentec', {'rtsHigh': true}),
      'tentec-566-serial': ('tentec', {'rtsHigh': true}),
    };

    expected.forEach((key, spec) {
      final (driverKey, prefills) = spec;
      test('$key is $driverKey over serial, prefilled with what the radio ships on', () {
        final type = registry.typeFor(key)!;
        expect(type.driver.key, driverKey);
        expect(type.transportKey, SerialTransport.transportKey);
        expect(type.category, kCategoryTransceiver);
        prefills.forEach((field, value) => expect(type.defaultConfig[field], value));
      });
    });
  });

  // A prefill is only where a node starts; these three are pinned, so a node
  // saved at the IC-7610's old 9600 is talked to at 115200 too, and there is
  // no speed field to set wrong. A slower line would also refuse the scope.
  test('the IC-7300 MK2, IC-7610 and IC-7760 talk CI-V at 115200 only', () {
    for (final key in ['ic7300mk2-serial', 'ic7610-serial', 'ic7760-serial']) {
      final type = registry.typeFor(key)!;
      expect(type.targetFor({'port': '/dev/cu.usbmodem1', 'baudRate': 9600})['baudRate'], 115200, reason: key);
      expect([for (final e in type.configElements()) e['key']], isNot(contains('baudRate')), reason: key);
    }
  });

  // The shared CI-V note says to set the radio to "the same number shown
  // here". On an entry whose speed is pinned there is no number shown, and
  // the advice sends the operator looking for a field that is not there.
  test('no entry without a speed field tells the operator to match the one shown', () {
    final matchShown = t.settings.station.civAddressTroubleshooting;
    for (final type in registry.types) {
      if (type.transportKey != SerialTransport.transportKey) continue;
      if ([for (final e in type.configElements()) e['key']].contains('baudRate')) continue;
      for (final note in type.notes) {
        expect(note['text'], isNot(contains(matchShown)), reason: type.key);
      }
    }
    expect(registry.typeFor('ic7610-serial')!.notes.single['text'], contains(t.settings.station.ic7610UsbSpeed));
  });

  // These are what an operator reaches for when their radio is not in the
  // catalogue by name, so the caveat on them is the difference between
  // "worth trying" and "probably pointless". Each is proven by a specific
  // radio: an IC-7300 and an IC-706MKIIG for Icom, an FT-710 for Yaesu, a
  // QRP Labs QMX, a TS-590SG and a TS-480 for Kenwood, a KX2 and a KX3 for
  // Elecraft.

  // Elecraft answers at 38400 while the Kenwood driver's own default is
  // 9600, and a mismatch is answered with silence rather than an error —
  // which is the whole reason this generic exists beside the Kenwood one
  // instead of being a line in its troubleshooting notes.
  test('the generic Elecraft entry is the Kenwood driver at the rate Elecraft ships on', () {
    final type = registry.typeFor('elecraft-serial')!;
    expect(type.driver.key, 'kenwood');
    expect(type.transportKey, SerialTransport.transportKey);
    expect(type.defaultConfig['baudRate'], 38400);
  });

  // A hardware report is where a wrong brand costs something, and the
  // fallback derives one from the driver's name — so every Elecraft entry
  // would file itself as a Kenwood without this.
  test('every Elecraft entry states its own brand rather than its protocol family', () {
    for (final key in ['elecraft-serial', 'kx2-serial', 'kx3-serial']) {
      expect(registry.typeFor(key)!.manufacturer, 'Elecraft', reason: '$key would otherwise report as Kenwood');
    }
  });

  // Same fallback: the TX-500 line rides the Kenwood driver too.
  test('every Lab599 entry states its own brand rather than its protocol family', () {
    for (final key in ['tx500-serial', 'tx500mp-serial', 'tx500mp-bluetooth']) {
      expect(registry.typeFor(key)!.manufacturer, lab599Brand, reason: '$key would otherwise report as Kenwood');
    }
  });

  // Same fallback: both QRP Labs radios ride the Kenwood driver.
  test('every QRP Labs entry states its own brand rather than its protocol family', () {
    for (final key in ['qmx-serial', 'qcx-serial']) {
      expect(registry.typeFor(key)!.manufacturer, qrpLabsBrand, reason: '$key would otherwise report as Kenwood');
    }
  });

  // A named Kenwood exists so the operator never sees the developer-only
  // dialect questions the generic asks. Left unpinned, the TS-590SG and
  // TS-480 would key nothing — or, pinned to the Elecraft shape, send a `KY`
  // the radio ignores while the app shows the message going out.
  test('the named Kenwoods key through the Kenwood `KY` and offer no voice memories', () {
    for (final key in ['ts590sg-serial', 'ts480-serial']) {
      final type = registry.typeFor(key)!;
      final config = type.driverConfig(const {});
      expect(KenwoodDriver.cwDialectFrom(config), KenwoodCwDialect.kenwood, reason: key);
      expect(KenwoodDriver.voiceDialectFrom(config), isNull, reason: key);
      expect(KenwoodDriver.voiceMemoriesFrom(config), 0, reason: key);
    }
  });

  // The one thing the G90 entry is for: on the generic Icom entry the radio
  // ignores every mode change.
  test('the G90 sends a filter with its mode, and states its own brand', () {
    final type = registry.typeFor('g90-serial')!;
    expect(type.driverConfig(const {})[civModeWithFilterConfigKey], isTrue);
    expect(type.manufacturer, xieguBrand);
    expect(registry.typeFor('x6100-serial')!.driverConfig(const {})[civModeWithFilterConfigKey], isNot(isTrue), reason: 'its mode changes work without one');
  });

  // CI-V states power only as a share of the radio's own maximum, so a named
  // radio that does not declare its rating is read against the driver's
  // 100 W guess — a 200 W IC-7760 at full power shows 100 W, a 10 W X6100
  // shows 100 W. Every named CI-V entry is listed, so a new one cannot fall
  // back to the guess without someone writing 100 here.
  test('every named CI-V radio reads power against its own rating', () {
    const rated = {
      'ic7300-serial': 100,
      'ic7300mk2-serial': 100,
      'ic706mkiig-serial': 100,
      'ic7100-serial': 100,
      'ic7610-serial': 100,
      'ic7760-serial': 200,
      'ic9700-serial': 100,
      'ic905-serial': 10,
      'ic7850-serial': 200,
      'ic7851-serial': 200,
      'x6100-serial': 10,
      'g90-serial': 20,
      'ic705-network': 10,
      // A network pairing reads against the same rating as its serial one.
      'ic7300mk2-network': 100,
      'ic7610-network': 100,
      'ic7760-network': 200,
      'ic9700-network': 100,
      'ic905-network': 10,
      'ic7850-network': 200,
      'ic7851-network': 200,
      'ic705-serial': 10,
      'ic705-bluetooth': 10,
      // Over a BLE bridge the rating has to come along with the driver's
      // other pins, or the meter reads against the family default.
      'ic7300-ble': 100,
      'ic7300mk2-ble': 100,
      'ic706mkiig-ble': 100,
      'ic7100-ble': 100,
      'ic7610-ble': 100,
      'ic7760-ble': 200,
      'ic9700-ble': 100,
      'ic905-ble': 10,
      'ic7850-ble': 200,
      'ic7851-ble': 200,
      'x6100-ble': 10,
      'g90-ble': 20,
      'ic705-ble': 10,
    };
    final named = registry.types.where((type) => type.driver.key == 'icom-civ' && !type.key.startsWith('icom-generic-'));
    expect(named.map((type) => type.key), unorderedEquals(rated.keys));
    for (final type in named) {
      final session = type.driver.createSession(_SilentSink(), type.driverConfig(const {})) as IcomCivSession;
      expect(session.maxWatts, rated[type.key], reason: type.key);
    }
  });

  // A band list is read by skipping what is not a `[fromHz, watts]` pair and
  // taking the last pair at or below the frequency — so a typo'd pair, or
  // one out of order, silently rates a band against the wrong ceiling: the
  // 10x power error the list exists to prevent.
  test('every band power list is whole and ascending', () {
    final pinned = registry.types.where((type) => type.overrides.containsKey(civBandMaxWattsConfigKey)).toList();
    expect(pinned.map((type) => type.model.key).toSet(), {'ic9700', 'ic905'});
    for (final type in pinned) {
      final raw = type.overrides[civBandMaxWattsConfigKey] as List;
      final bands = civBandMaxWattsFrom(raw);
      expect(bands, hasLength(raw.length), reason: type.key);
      for (var i = 1; i < bands.length; i++) {
        expect(bands[i].$1, greaterThan(bands[i - 1].$1), reason: type.key);
      }
    }
  });

  // The FTX-1 answers `PC1010;` where the FT-891 answers `PC010;`: on the
  // FT-891's form it would show no power and refuse every power change,
  // silently.
  test('the FTX-1 speaks its own power form, and keys like the rest of the line', () {
    final type = registry.typeFor('ftx1-serial')!;
    final config = type.driverConfig(const {});
    expect(config[yaesuHeadPowerConfigKey], isTrue);
    expect(type.driver.canKeyCwWith(config), isTrue);
    expect(config[voiceMemoriesConfigKey], yaesuVoiceMemoryCount);
  });

  // The FT-710's own CAT manual plays a text memory with `KY0n;`; on the
  // line's `KYA;` every CW message is written and never sent.
  test('the FT-710 plays its keyer memory by channel', () {
    final config = registry.typeFor('ft710-serial')!.driverConfig(const {});
    expect(config[yaesuKeyerPlayByChannelConfigKey], isTrue);
    expect(registry.typeFor('ft891-serial')!.driverConfig(const {})[yaesuKeyerPlayByChannelConfigKey], isNot(isTrue), reason: 'the FT-891 plays KY6-KYA');
  });

  // Outside the table of radios operators have run: nobody has run this one
  // yet. What it pins are the two places the FT-450 leaves the line, and
  // each fails silently when unpinned — every frequency answer dropped, or
  // every CW message written to a memory the radio does not have.
  test('the FT-450 reads eight frequency digits and keys through its third memory', () {
    final type = registry.typeFor('ft450-serial')!;
    final config = type.driverConfig(const {});
    expect(type.driver.key, 'ft891');
    expect(type.transportKey, SerialTransport.transportKey);
    expect(type.defaultConfig['baudRate'], 4800);
    expect(config[yaesuFrequencyDigitsConfigKey], 8);
    expect(config[yaesuKeyerMemoryConfigKey], 3);
    expect(config[yaesuKeyerMemoryCharsConfigKey], 40);
    expect(type.driver.canKeyCwWith(config), isTrue);
    expect(type.driver.voiceMemoryCountWith(config), 0, reason: 'no DVS its CAT is documented to reach');
    expect(type.driver.telemetryMetersWith(config), isEmpty, reason: 'no calibration table');
  });

  // The FX-4CR sits outside the table above because the claim that table's
  // companion test makes — that an operator has run this radio — is the one
  // thing not true of it: the reports behind this entry were operators on
  // the QMX entry, at that entry's 9600. Everything else about it is proven,
  // so it carries no caveat; the rate is the field that stays editable.
  group('the FX-4CR, which reached the catalogue by way of the QMX entry', () {
    test('is the Kenwood driver over serial at the rate the entry prefills', () {
      final type = registry.typeFor('fx4cr-serial')!;
      expect(type.driver.key, 'kenwood');
      expect(type.transportKey, SerialTransport.transportKey);
      expect(type.category, kCategoryTransceiver);
      expect(type.defaultConfig['baudRate'], 115200);
    });

    // Same fallback, same cost as the Elecraft entries above: this rides the
    // Kenwood driver and would file itself as a Kenwood without the brand.
    test('states its own brand rather than its protocol family', () {
      expect(registry.typeFor('fx4cr-serial')!.manufacturer, 'BG2FX');
    });

    // Inherited from the driver, which a QMX and two Elecrafts have answered
    // — not a claim that anyone has run an FX-4CR at 115200. Pinning the
    // rate is the bet this entry makes; the operator can change it in one
    // dropdown, which is why it lives in defaultConfig and not overrides.
  });

  test('the Yaesus that need their front panel say so, each under its own name', () {
    // Recording a memory is half a CAT command and half a front-panel
    // procedure, and the halves differ per RADIO while one driver serves all
    // three — so the note hangs off the model, not the driver.
    // Named rather than `!`, so a catalogue key that goes away is reported
    // as the key it was and not as a null-check on an anonymous line.
    String? noteFor(String key) {
      final model = registry.modelFor(key);
      expect(model, isNotNull, reason: '$key has left the catalogue');
      return model!.recordingHelp;
    }

    final ft891 = noteFor('ft891');
    final ftdx10 = noteFor('ftdx10');
    final ft710 = noteFor('ft710');
    for (final note in [ft891, ftdx10, ft710]) {
      expect(note, isNotNull);
      expect(note, contains('PTT'));
    }
    // The FTDX10 and FT-710 share one string rather than two copies that can
    // drift apart in translation; the FT-891 counts its REC indicator
    // through four blinks, where these two only wait for it to appear.
    expect(ftdx10, ft710);
    expect(ft891, isNot(ftdx10));
    expect(ft891, contains('four times'));

    // A radio nobody has written a procedure for says nothing at all, rather
    // than borrowing another rig's.
    expect(noteFor('yaesu-generic'), isNull);
  });

  for (final model in registry.models) {
    group('model ${model.key}', () {
      test('has at least one way in', () => expect(model.variants, isNotEmpty));

      test('names each transport once', () {
        final keys = model.variants.map((v) => v.transportKey).toList();
        expect(
          keys.toSet().length,
          keys.length,
          reason:
              'two variants on one transport make the editor offer the same choice twice, '
              'and variantForTransport pick whichever comes first',
        );
      });

      // The editor renders EVERY variant's fields at once and narrows them
      // with `visibleWhen`, so two variants sharing a key share one field and
      // one controller. That is deliberate for a genuinely shared setting
      // (`host` on two network transports — type the address once). It is a
      // bug when the key means different things: `port` is a numeric TCP port
      // to one transport and a `/dev/cu.*` device path to another, and
      // switching transport would pour one into the other with no warning.
      // The editor seeds the form from EVERY variant's defaultConfig at once,
      // because that is what lets switching transport land on sensible values
      // with no re-seeding logic. The price is that a key two variants
      // disagree about has one box and can only show one of the two answers —
      // so they are not allowed to disagree. Caught here rather than in the
      // panel because there is no run-time symptom: the operator simply sees
      // a prefill that belongs to the other cable.
      test('two variants never prefill the same key with different values', () {
        final seen = <String, dynamic>{};
        for (final variant in model.variants) {
          for (final entry in variant.defaultConfig.entries) {
            expect(
              seen.putIfAbsent(entry.key, () => entry.value),
              entry.value,
              reason:
                  '${model.key}\'s variants prefill "${entry.key}" differently, but the editor '
                  'renders one field for it — one of the two values can never be shown',
            );
          }
        }
      });

      test('a field key shared between its variants means the same thing in each', () {
        final fieldTypes = <String, String>{};
        for (final variant in model.variants) {
          for (final element in [...variant.transport.configElements(), ...variant.driver.configElements()]) {
            if (element['type'] != 'field') continue;
            final key = element['key'] as String;
            final fieldType = element['fieldType'] as String;
            final seen = fieldTypes[key];
            expect(
              seen ?? fieldType,
              fieldType,
              reason:
                  '"$key" is a $seen on one of ${model.key}\'s transports and a $fieldType on another — '
                  'they share a field in the editor, so one would overwrite the other',
            );
            fieldTypes[key] = fieldType;
          }
        }
      });
    });
  }

  // No registered radio restricts a LIST-valued field, so the per-type
  // "narrows, never adds" checks above never execute their assertions for
  // any of them — that loop stays green even if the narrowing logic itself
  // is broken or deleted. (The `port` restrictions some radios carry are
  // maps, which that check skips; cat_serial_port_choice_test.dart covers
  // them.) This exercises the list implementation (serial baud rate)
  // directly, so the mechanism has to keep working whether or not a radio
  // uses it yet.
  group('restrictions narrowing, exercised directly (no registered radio restricts a list yet)', () {
    const transport = SerialTransport();

    test('an unrestricted baud-rate field offers the full supported list', () {
      final field = transport.configElements().firstWhere((e) => e['key'] == 'baudRate');
      final offered = [for (final o in field['options'] as List) (o as Map)['value']];
      expect(offered, containsAll([4800, 9600, 19200, 38400]));
    });

    test('a restricted baud-rate field narrows to exactly the allowed subset, in order', () {
      final field = transport
          .configElements(
            restrictions: {
              'baudRate': [9600, 4800],
            },
          )
          .firstWhere((e) => e['key'] == 'baudRate');
      final offered = [for (final o in field['options'] as List) (o as Map)['value']];
      expect(offered, [4800, 9600], reason: 'narrowed to the allowed subset, in the transport\'s own order');
    });
  });

  group('expectedUpdateInterval', () {
    // Which drivers PUSH state as it changes and which have to ask, as each
    // one is BEFORE it has heard anything. Spelled out rather than derived,
    // because a driver answering the wrong one is invisible: readings arrive
    // either way. Smart VFO Snap adds the interval to its settle delay, so a
    // pusher that claims a cadence slows every snap on that radio by it, and
    // a poller that claims none settles during the silence between polls and
    // snaps mid-turn (docs/design/cat.md § Smart VFO Snap).
    //
    // CI-V belongs on the polling side HERE and only here: transceive can't
    // be read back, so a fresh session assumes the poll and drops the claim
    // once the radio announces on its own (cat_icom_civ_test.dart).
    // The Winkeyer pushes too: status, echo and pot reports, as they happen.
    // An SDR streams IQ continuously and has no dial of its own to settle.
    const pushes = {'flexradio', 'placeholder-radio', 'antenna-genius', 'winkeyer', 'rtl-tcp'};

    // Antenna/Key have no live connection at all — see NoneTransport — so
    // createSession is documented to throw rather than answer either way.
    // Everything else in the catalogue connects, whether or not it is a
    // radio: scoping this to transceivers let the first non-radio driver
    // that connects skip the check entirely.
    final connectable = [
      for (final type in registry.types)
        if (type.transportKey != NoneTransport.transportKey) type,
    ];

    for (final type in connectable) {
      final pushesUpdates = pushes.contains(type.driver.key) || type.key == 'k4-remote';
      test('${type.key} — ${pushesUpdates ? 'pushes' : 'polls'}', () {
        final session = type.driver.createSession(_SilentSink(), type.defaultConfig);
        addTearDown(session.teardown);
        final interval = session.expectedUpdateInterval;

        if (pushesUpdates) {
          expect(interval, isNull, reason: 'a pushing driver reports changes as they happen');
        } else {
          expect(interval, isNotNull, reason: 'a polling driver must say how long silence proves nothing');
          expect(interval, greaterThan(Duration.zero));
        }
      });
    }
  });
}

/// Enough of a sink to construct a session. Nothing here sends or reads —
/// these tests only ask a session to describe itself.
class _SilentSink implements EquipmentSink {
  final problems = <String?>[];
  List<EquipmentChannel> channels = const [];
  @override
  void send(List<int> bytes) {}
  @override
  void report(VfoReading reading) {}
  @override
  void reportPower(num watts) {}

  final txReports = <bool>[];
  final meterReports = <(RadioMeter, num)>[];
  @override
  void reportTransmitting(bool transmitting) => txReports.add(transmitting);
  @override
  void reportMeter(RadioMeter meter, num value) => meterReports.add((meter, value));

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
  void reportProblem(String? message) => problems.add(message);

  @override
  void reportChannels(List<EquipmentChannel> channels) => this.channels = channels;

  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) {}
  @override
  void reportAlive() {}
}
