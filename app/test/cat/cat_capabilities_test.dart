// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a device offers, and how one of those things is addressed
// (docs/design/station-model.md § 4).
//
// A declaration is made without a connection, so that a picker works with the
// radio switched off. That is also what makes it dangerous: nothing at run
// time compares it with the session the same entry creates, and a receiver
// offered by an entry whose session cannot tune is a slot that accepts a pick
// and then does nothing. The catalogue-wide test here is that comparison.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/capability.dart';
import 'package:ham2k_logger/services/cat/capability_offers.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/everyware_server.dart';
import 'package:ham2k_logger/services/cat/drivers/flexradio_driver.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_shared_session.dart';
import 'package:ham2k_logger/services/cat/drivers/k4_shared_session_config.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_details.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/spectrum.dart';
import 'package:ham2k_logger/services/cat/transports/none_transport.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final registry = EquipmentRegistry();
  Set<String> offered(String typeKey, [Map<String, dynamic> config = const {}]) {
    final type = registry.typeFor(typeKey)!;
    return {
      for (final capability in type.offers({...type.defaultConfig, ...config})) '${capability.kind}:${capability.key}',
    };
  }

  group('an address', () {
    test('reads back what it wrote, whatever the equipment called the thing', () {
      // A key is the equipment's own name, and an Everyware server's operator
      // names rotors freely. A slash or a percent left raw would split the
      // address somewhere else on the way back in.
      for (final address in [
        const CapabilityAddress.device('3f2c'),
        const CapabilityAddress('3f2c', kCapabilityReceiver, key: '2'),
        const CapabilityAddress('3f2c', kCapabilityRotator, key: 'rotor:Tower 1'),
        const CapabilityAddress('3f2c', kCapabilityRotator, key: '80m 4/sq 50%'),
        const CapabilityAddress.input('3f2c', kCapabilitySwitch, radioSwitchKey, 'ANT1'),
        const CapabilityAddress.output('3f2c', kCapabilitySwitch, 'main', 'A/B'),
        const CapabilityAddress('peer:laptop:3f2c', kCapabilityTransmitter),
      ]) {
        expect(CapabilityAddress.parse('$address'), address, reason: '$address');
      }
      expect('${const CapabilityAddress('3f2c', kCapabilityRotator, key: '80m 4/sq 50%')}', '3f2c/rotator:80m 4%2Fsq 50%25');
    });

    test('a port names the capability it is on', () {
      const port = CapabilityAddress.input('3f2c', kCapabilitySwitch, radioSwitchKey, 'ANT1');
      expect(port.capability, const CapabilityAddress('3f2c', kCapabilitySwitch, key: radioSwitchKey));
      expect(port.capability.port, isNull);
    });

    test('is refused when it is not one, rather than read as something near it', () {
      // A stored address that no longer parses must resolve to nothing. Read
      // leniently, a damaged one would point a slot at a different receiver.
      for (final text in [
        '',
        '/rx:0',
        '3f2c/',
        '3f2c/rx',
        '3f2c/rx:',
        '3f2c/:0',
        '3f2c/9x:0',
        '3f2c/rx:0/up:1',
        '3f2c/rx:0/in:',
        '3f2c/rx:0/in:1/x',
        '3f2c%2/rx:0',
      ]) {
        expect(CapabilityAddress.parse(text), isNull, reason: '"$text"');
      }
    });
  });

  group('what an entry declares is what its session can do', () {
    // Antenna and key entries never connect (NoneTransport), and their
    // createSession throws by design.
    final connectable = [
      for (final type in registry.types)
        if (type.transportKey != NoneTransport.transportKey) type,
    ];

    // Each entry twice. As added, its address is blank, and what an address
    // turns on — a K4's scope over the LAN, a Flex's audio mixer — would
    // never be held against a session: a declaration could drop either and
    // every entry would still agree with itself.
    const configured = [
      ('as added', <String, dynamic>{}),
      ('with an address', <String, dynamic>{'host': '10.0.0.5'}),
    ];

    for (final type in connectable) {
      for (final (label, extra) in configured) {
        test('${type.key}, $label', () {
          final stored = {...type.defaultConfig, ...extra};
          final config = type.driverConfig(stored);
          final kinds = {for (final capability in type.offers(stored)) capability.kind};
          // The session the service runs, which for a K4 secure link is not
          // the driver's: its receivers are facades on one shared owner
          // (cat_connection.dart). Held against the driver's, this entry's
          // scope would read as a promise nothing keeps.
          final session = type.key == 'k4-remote'
              ? K4SharedSession(send: (_) {}, pan: const Stream.empty(), config: config).attach(_SilentSink(), receiver: type.driver.offerKeyWith(config))
              : type.driver.createSession(_SilentSink(), config);
          addTearDown(session.teardown);

          // Both ways for what a category alone decides: a receiver nothing can
          // tune is a dead pick, and a session that tunes with no receiver
          // offered is a radio no position can be given.
          expect(kinds.contains(kCapabilityReceiver), session is TransceiverSession, reason: 'receiver');
          expect(kinds.contains(kCapabilityTransmitter), session is TransceiverSession, reason: 'transmitter');
          expect(kinds.contains(kCapabilityRotator), session is RotatorSession, reason: 'rotator');
          expect(kinds.contains(kCapabilitySwitch), session is AntennaSwitchSession, reason: 'switch');
          expect(kinds.contains(kCapabilitySo2rController), session is So2rSwitchSession, reason: 'SO2R controller');

          // One way for what an entry may withhold: a generic Icom's session
          // can key, and its entry offers no keyer until the operator says the
          // rig has one.
          if (kinds.contains(kCapabilityKeyer)) expect(session, isA<CwKeyerSession>(), reason: 'keyer');
          if (kinds.contains(kCapabilityVoice)) expect(session, isA<VoiceKeyerSession>(), reason: 'voice');
          if (kinds.contains(kCapabilityAudioMixer)) expect(session, isA<So2rRadioAudioSession>(), reason: 'audio mixer');
          if (kinds.contains(kCapabilityScope)) expect(session, isA<SpectrumSession>(), reason: 'scope');
          if (session case final SpectrumSession scope when scope.spectrumUnavailable == null) {
            expect(kinds, contains(kCapabilityScope), reason: 'a session with a working scope, and none offered');
          }
        });
      }
    }

    test('an entry with nothing to connect to offers the thing itself', () {
      expect(offered('antenna-none'), {'antenna:main'});
      expect(offered('key-none'), {'key:main'});
    });
  });

  group('a key is the equipment\'s own name', () {
    test('a Flex node offers the receiver and scope of its own slice, and the radio\'s one transmitter', () {
      final slice2 = offered('flexradio-tcp', {'host': '10.0.0.5', 'slice': '2'});
      expect(slice2, containsAll(['rx:2', 'scope:2', 'tx:main', 'keyer:main', 'audioMixer:main']));
      expect(slice2, isNot(contains('rx:0')));
      // A record from before the setting existed is on slice A.
      expect(offered('flexradio-tcp', {'host': '10.0.0.5'}), contains('rx:0'));
    });

    test('every spelling of a slice the session accepts is one key, and the slice it runs', () {
      // The key ends up in stored addresses, and the editor accepts all of
      // these. Read any other way than the session reads them, a node on
      // slice C would offer slice A's receiver while tuning C.
      for (final Object spelling in [2, '2', ' 2', '02', 2.0]) {
        expect(FlexRadioDriver.sliceFromConfig({'slice': spelling}), 2, reason: 'sanity: the session runs slice 2 for "$spelling"');
        expect(offered('flexradio-tcp', {'slice': spelling}), contains('rx:2'), reason: '"$spelling"');
      }
      // What the session takes for slice A, it offers as slice A.
      expect(offered('flexradio-tcp', {'slice': '9'}), contains('rx:0'));
    });

    test('a K4 node offers the receiver it is on', () {
      expect(offered('k4-remote', {k4ReceiverConfigKey: 'sub'}), contains('rx:sub'));
      expect(offered('k4-remote', {k4ReceiverConfigKey: ''}), contains('rx:main'));
    });

    test('a rotor and a directional switch of one name are two rotators', () {
      // Both are offered as rotators, and a server lists rotors and switches
      // apart, so one name can be both.
      final rotor = offered(everywareRotorTypeKey, {everywareDeviceConfigKey: 'North'});
      final directional = offered(everywareDirectionalTypeKey, {everywareDeviceConfigKey: 'North'});
      expect(rotor, {'rotator:rotor:North'});
      expect(directional, {'rotator:switchBox:North'});
    });
  });

  group('what an entry withholds', () {
    test('a generic Icom offers a keyer only once the operator says the rig has one', () {
      expect(offered('icom-generic-serial', {cwKeyerConfigKey: false}), isNot(contains('keyer:main')));
      expect(offered('icom-generic-serial', {cwKeyerConfigKey: true}), contains('keyer:main'));
    });

    test('a receive-only SDR offers its scope and no receiver', () {
      // Nothing tunes it but the app and nothing logs from it. Offered as a
      // receiver it would be pickable as a position's radio.
      expect(offered('rtl-sdr-rtltcp'), {'scope:main'});
    });
  });

  group('the equipment corrects what was declared', () {
    test('a switch lists its ports once it has said what they are', () {
      final type = registry.typeFor('antenna-genius-tcp')!;
      expect(type.offersWith(type.defaultConfig, const EquipmentState()), [const Capability(kCapabilitySwitch)]);

      const reported = EquipmentState(
        switchAntennas: [
          SwitchAntenna(key: '1', name: 'Yagi'),
          SwitchAntenna(key: '3', name: 'Dipole'),
        ],
        switchPorts: [
          SwitchPort(key: 'A', label: 'A'),
          SwitchPort(key: 'B', label: 'B'),
        ],
      );
      // By the switch's own keys, gap included: antenna 3 is not "the second".
      expect(type.offersWith(type.defaultConfig, reported), [
        const Capability(kCapabilitySwitch, inputs: ['1', '3'], outputs: ['A', 'B']),
      ]);
    });

    test('a radio\'s own antenna ports are a switch, wired to its receiver and transmitter', () {
      final type = registry.typeFor('ft891-serial')!;
      expect(type.offersWith(type.defaultConfig, const EquipmentState()).where((c) => c.kind == kCapabilitySwitch), isEmpty);
      // A radio that answered with no ports has said it has none. Offered as
      // a switch with an empty list, it would read as one that has not said
      // yet, and accept any port at all.
      const none = EquipmentState(
        antennas: RadioAntennas(rxPorts: [], txPorts: []),
      );
      expect(type.offersWith(type.defaultConfig, none).where((c) => c.kind == kCapabilitySwitch), isEmpty);

      const reported = EquipmentState(
        antennas: RadioAntennas(rxPorts: ['ANT1', 'ANT2', 'RX'], txPorts: ['ANT1', 'ANT2'], rx: 'RX', tx: 'ANT1', separate: true),
      );
      expect(
        type.offersWith(type.defaultConfig, reported),
        contains(const Capability(kCapabilitySwitch, key: radioSwitchKey, inputs: ['ANT1', 'ANT2', 'RX'], outputs: radioSwitchOutputs)),
      );
    });
  });

  test('a radio report says what the app took the entry to offer', () {
    // Where a rig that keys but was offered no keyer shows up: nothing on
    // screen says what an entry was read as, outside developer mode.
    final type = registry.typeFor('ft891-serial')!;
    final node = EquipmentNode(uuid: 'u', typeKey: type.key, config: type.defaultConfig);
    final lines = equipmentSetupLines(node: node, type: type, state: const EquipmentState(), registry: registry);
    expect(lines, contains(startsWith('- Offers: rx:main, tx:main')));
  });

  group('an address on this station', () {
    late CatService cat;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      cat = CatService(SettingsService(prefs), radio: RadioService(prefs, writeDelay: Duration.zero));
      addTearDown(cat.dispose);
    });

    test('a bare device id is its receiver, as it was "the radio" before', () async {
      // Extension calls, peer offers and stored picks all hold a node's id
      // and mean its radio by it.
      final flex = await cat.addNode(typeKey: 'flexradio-tcp', config: const {'host': '10.0.0.5', 'slice': '3'});
      final resolved = cat.resolveCapability(CapabilityAddress.device(flex.uuid))!;
      expect(resolved.node.uuid, flex.uuid);
      expect(resolved.capability, const Capability(kCapabilityReceiver, key: '3'));
    });

    test('a bare device id of something with no receiver is the thing it is', () async {
      final rotator = await cat.addNode(typeKey: 'simulated-rotator', config: registry.typeFor('simulated-rotator')!.defaultConfig);
      expect(cat.resolveCapability(CapabilityAddress.device(rotator.uuid))!.capability.kind, kCapabilityRotator);
    });

    test('what the device does not offer resolves to nothing, never to what it does', () async {
      final flex = await cat.addNode(typeKey: 'flexradio-tcp', config: const {'host': '10.0.0.5', 'slice': '3'});
      // The slice beside the node's own is another node's, or nobody's.
      expect(cat.resolveCapability(CapabilityAddress(flex.uuid, kCapabilityReceiver, key: '2')), isNull);
      expect(cat.resolveCapability(CapabilityAddress(flex.uuid, kCapabilityRotator)), isNull);
      expect(cat.resolveCapability(const CapabilityAddress('no-such-device', kCapabilityReceiver)), isNull);
      // Only a switch has ports. A receiver with none listed is not a switch
      // that has yet to list them.
      expect(cat.resolveCapability(CapabilityAddress.input(flex.uuid, kCapabilityReceiver, '3', 'ANT1')), isNull);
    });

    test('a port resolves on a switch that is off, and is checked on one that has answered', () async {
      final type = registry.typeFor('simulated-switch')!;
      final node = await cat.addNode(typeKey: 'simulated-switch', config: type.defaultConfig);
      final key = type.offers(type.defaultConfig).single.key;
      final madeUp = CapabilityAddress.input(node.uuid, kCapabilitySwitch, key, 'no-such-port');

      // Off, it has not said what it has: an address stored against it has
      // to outlive that.
      expect(cat.resolveCapability(madeUp), isNotNull);

      await cat.connect(node.uuid);
      final ports = cat.capabilitiesOf(node.uuid).single;
      expect(ports.inputs, isNotEmpty);
      expect(cat.resolveCapability(CapabilityAddress.input(node.uuid, kCapabilitySwitch, key, ports.inputs.first)), isNotNull);
      expect(cat.resolveCapability(madeUp), isNull);
    });
  });
}

/// Enough of a sink to construct a session: every report goes nowhere.
class _SilentSink implements EquipmentSink {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
