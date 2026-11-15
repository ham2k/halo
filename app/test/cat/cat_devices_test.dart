// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A device with several receivers, rotors or switches, and the ids a station
// stored before it was one (docs/design/station-model.md § 9).
//
// A station stored by an older build holds a remote K4's Sub and each
// Everyware rotor or switch as a node with a random uuid, which positions,
// layouts and extensions may hold; here each is an entry keyed by its
// capability's address. What these tests defend is that whatever named the
// old id goes on naming the same receiver or rotor, and that a forwarded id
// is never handed to another entry.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/computer_voice_keyer.dart' show voiceOutputConfigKey;
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/flexradio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;

  Future<CatService> load(
    Map<String, dynamic> blob, {
    Map<String, String> passwords = const {},
    bool keychainRefuses = false,
    EquipmentRegistry? registry,
  }) async {
    SharedPreferences.setMockInitialValues({'stationEquipment': jsonEncode(blob)});
    final prefs = await SharedPreferences.getInstance();
    settings = SettingsService(prefs, secureStorage: FakeSecureStorage(failWrites: keychainRefuses));
    await settings.setExperimentEnabled('so2r', true);
    for (final MapEntry(key: identity, value: password) in passwords.entries) {
      await settings.setEquipmentSecret(identity, 'password', password);
    }
    final cat = CatService(
      settings,
      radio: RadioService(prefs, writeDelay: Duration.zero),
      registry: registry,
    );
    addTearDown(cat.dispose);
    return cat;
  }

  Future<Map<String, dynamic>> saved() async => jsonDecode((await SharedPreferences.getInstance()).getString('stationEquipment')!) as Map<String, dynamic>;

  Map<String, dynamic> k4(String receiver, String identity, {String name = 'K4'}) => {
    'typeKey': 'k4-remote',
    'name': name,
    'config': {'host': '192.0.2.4', 'remotePort': 9204, 'receiver': receiver, 'k4ConnectionId': identity},
  };

  group('a remote K4 stored as two nodes', () {
    final blob = {
      'version': 4,
      'nodes': {
        'k4-main': k4('main', 'k4-main'),
        'k4-sub': k4('sub', 'k4-main', name: 'K4 Sub'),
        'paddle': {'typeKey': 'paddle', 'name': 'Paddle'},
      },
      'positions': {
        'a': {
          'radio': {'local': 'k4-main'},
          'slots': <String, dynamic>{},
        },
        'b': {
          'radio': {'local': 'k4-sub'},
          'slots': {'key': 'paddle', 'antenna': null},
        },
      },
      'sets': {'A': 'a', 'B': 'b'},
    };

    test('is one device: the Sub is the Main\'s rx:sub, and what named it names it still', () async {
      final cat = await load(blob);
      expect(cat.nodes.map((node) => node.uuid), ['k4-main', 'k4-main/rx:sub', 'paddle']);
      expect(cat.radio2, 'k4-main/rx:sub', reason: 'set B logged from the Sub, and still does');
      expect(cat.designatedFor('key', radio: 'k4-main/rx:sub'), 'paddle');
      expect(cat.logicalChannelFor('k4-main/rx:sub')?['key'], 'sub');
      // Named as the device it is part of, and picked as which receiver of
      // it: two radios both called "K4" would be told apart by nothing.
      expect(cat.displayNameFor(cat.nodeFor('k4-main/rx:sub')!), 'K4');
      expect(cat.radioNameFor(cat.nodeFor('k4-main/rx:sub')!), 'K4 · Sub');
      expect(cat.radioNameFor(cat.nodeFor('k4-main')!), 'K4 · Main');
      expect(cat.radioNameFor(cat.nodeFor('paddle')!), 'Paddle');
    });

    test('the forwarding is saved, and a reload of what was saved changes nothing', () async {
      final cat = await load(blob);
      await cat.removeNode('paddle');
      final first = await saved();
      expect(first['forwarded'], {'k4-sub': 'k4-main/rx:sub'});
      final again = await load(first);
      expect(again.nodes.map((node) => node.uuid), ['k4-main', 'k4-main/rx:sub']);
      expect(again.radio2, 'k4-main/rx:sub');
    });
  });

  test('a K4 with only a Sub gets a Main under a new id, never the Sub\'s old one, and the same one at every load', () async {
    // The Sub's old id is forwarded to the Sub. Were it the Main's, everything
    // stored since that names the Main would be forwarded to the Sub on the
    // next load. And a station is not saved by loading it: a Main made anew
    // each time would leave a layout that picked it pointing at nothing.
    final subOnly = {
      'version': 4,
      'nodes': {'k4-sub': k4('sub', 'k4-sub')},
      'positions': {
        'a': {
          'radio': {'local': 'k4-sub'},
          'slots': <String, dynamic>{},
        },
      },
      'sets': {'A': 'a'},
    };
    final cat = await load(subOnly, passwords: {'k4-sub': 'secret'});
    final main = cat.nodes.first.uuid;
    expect((await load(subOnly)).nodes.first.uuid, main);
    // The device is its Main, not the connection id: that is the Sub's old
    // id, which names the Sub now.
    expect(cat.logicalDeviceIdFor('$main/rx:sub'), main);
    expect(main, isNot('k4-sub'));
    expect(cat.nodes.map((node) => node.uuid), [main, '$main/rx:sub']);
    expect(cat.radio1, LocalRadio('$main/rx:sub'));
    expect(await cat.storedSecretFields(main), {'password'}, reason: 'the keychain entry stays under the connection id both receivers share');
    expect(await cat.storedSecretFields('$main/rx:sub'), {'password'});
  });

  test('a peer\'s radio keeps its ids, even one equal to an id forwarded here', () async {
    // Two installs copied from one set of settings share node ids, and the
    // other one's radio is named by its own.
    final cat = await load({
      'version': 4,
      'nodes': {'k4-main': k4('main', 'k4-main'), 'k4-sub': k4('sub', 'k4-main')},
      'positions': {
        'a': {
          'radio': {
            'peer': {'deviceId': 'laptop', 'radioId': 'k4-sub'},
          },
          'slots': <String, dynamic>{},
        },
      },
      'sets': {'A': 'a'},
    });
    expect((cat.radio1! as PeerRadio).selection.radioId, 'k4-sub');
  });

  test('a version 2 station\'s peer radio keeps its ids too', () async {
    final cat = await load({
      'version': 2,
      'nodes': {'k4-main': k4('main', 'k4-main'), 'k4-sub': k4('sub', 'k4-main')},
      'remoteRadio1': {'deviceId': 'laptop', 'radioId': 'k4-sub'},
    });
    expect((cat.radio1! as PeerRadio).selection.radioId, 'k4-sub');
  });

  test('a K4 moved off the secure link keeps its Sub when the keychain refuses the edit', () async {
    // The Sub, and what was picked for it, go only with an edit that saved.
    final cat = await load({
      'version': 4,
      'nodes': {'k4-main': k4('main', 'k4-main'), 'k4-sub': k4('sub', 'k4-main')},
    }, keychainRefuses: true);
    final main = cat.nodeFor('k4-main')!;
    await expectLater(cat.updateNode(main.copyWith(typeKey: 'k4-tcp', config: {...main.config, 'password': 'typed'})), throwsA(anything));
    expect(cat.nodeFor('k4-main/rx:sub'), isNotNull);
  });

  group('Flex nodes at one address', () {
    Map<String, dynamic> flex(String slice, {String host = 'flex.local', String name = 'Shack Flex'}) => {
      'typeKey': 'flexradio-tcp',
      'name': name,
      'config': {'host': host, 'port': 4992, 'slice': slice},
    };

    test('are one device: slice A\'s node is the device, and slice B\'s is its rx:1, picks and all', () async {
      final cat = await load({
        'version': 4,
        'nodes': {
          'flex-a': flex('0'),
          'flex-b': flex('1', name: 'Flex B'),
          'paddle': {'typeKey': 'paddle', 'name': 'Paddle'},
        },
        'positions': {
          'a': {
            'radio': {'local': 'flex-a'},
            'slots': <String, dynamic>{},
          },
          'b': {
            'radio': {'local': 'flex-b'},
            'slots': {'key': 'paddle'},
          },
        },
        'sets': {'A': 'a', 'B': 'b'},
      });
      expect(cat.nodes.map((node) => node.uuid), ['flex-a', 'flex-a/rx:1', 'paddle']);
      expect(cat.radio2, 'flex-a/rx:1');
      expect(cat.designatedFor('key', radio: 'flex-a/rx:1'), 'paddle');
      expect(cat.nodeFor('flex-b')?.uuid, 'flex-a/rx:1', reason: 'a layout holding the old id finds the slice');
      expect(cat.radioNameFor(cat.nodeFor('flex-a/rx:1')!), 'Shack Flex · Slice B');
      expect(cat.entriesOf('flex-a'), ['flex-a', 'flex-a/rx:1']);
    });

    test('with no node on slice A get one made from the address, the same at every load', () async {
      final onlyB = {
        'version': 4,
        'nodes': {'flex-b': flex('1')},
        'positions': {
          'a': {
            'radio': {'local': 'flex-b'},
            'slots': <String, dynamic>{},
          },
        },
        'sets': {'A': 'a'},
      };
      final cat = await load(onlyB);
      final device = cat.nodes.first.uuid;
      expect(device, isNot('flex-b'), reason: 'the old id is the slice\'s, forwarded to it');
      expect(cat.nodes.map((node) => node.uuid), [device, '$device/rx:1']);
      expect(cat.radio1, LocalRadio('$device/rx:1'));
      expect((await load(onlyB)).nodes.first.uuid, device);
    });

    test('at two addresses are two radios', () async {
      final cat = await load({
        'version': 4,
        'nodes': {'shack': flex('0'), 'remote': flex('0', host: 'remote.example')},
      });
      expect(cat.nodes.map((node) => node.uuid), ['shack', 'remote']);
    });

    test('offer the slices the radio last said were open, and picking one adds it as an entry', () async {
      // Read while the radio is off: a slice picked then is reached once it
      // is on, and one the radio did not mention cannot be offered at all.
      final cat = await load({
        'version': 4,
        'nodes': {
          'flex-a': {
            'typeKey': 'flexradio-tcp',
            'name': 'Shack Flex',
            'config': {
              'host': 'flex.local',
              'port': 4992,
              'slice': '0',
              flexKnownSlicesConfigKey: [
                {'key': '0', 'label': 'A'},
                {'key': '2', 'label': 'C', 'usedBy': 'Maestro'},
              ],
            },
          },
        },
      });
      expect(cat.flexSlicesToAdd('flex-a').map((slice) => (slice.key, slice.usedBy)), [('2', 'Maestro')], reason: 'slice A has its entry already');
      final added = (await cat.addFlexSlice('flex-a', '2'))!;
      expect(added, 'flex-a/rx:2');
      expect(cat.nodeFor(added)!.config, {'host': 'flex.local', 'port': 4992, 'slice': '2'});
      expect(cat.flexSlicesToAdd('flex-a'), isEmpty);
      expect(cat.radioNameFor(cat.nodeFor(added)!), 'Shack Flex · Slice C');
    });

    test('keep the slices the radio says are open, from whichever slice says so, for the picker while it is off', () async {
      // Without this the picker offers nothing to add until the radio is on
      // AND one of its slices connected, and nothing at all once it is off.
      final radio = _FakeFlexRadio();
      final cat = await load({
        'version': 4,
        'nodes': {
          'flex-a': {...flex('0'), 'typeKey': _fakeFlexTypeKey},
          'flex-b': {...flex('1'), 'typeKey': _fakeFlexTypeKey},
        },
      }, registry: radio.registry);
      await cat.connect('flex-a/rx:1');
      radio.sinks.single.reportChannels(const [
        EquipmentChannel(key: '0', label: 'A', inUse: true),
        EquipmentChannel(key: '1', label: 'B', inUse: true),
        EquipmentChannel(key: '2', label: 'C', inUse: true, usedBy: 'Maestro'),
        EquipmentChannel(key: '3', label: 'D', inUse: false),
      ]);
      expect((await saved())['nodes']['flex-a']['config'][flexKnownSlicesConfigKey], [
        {'key': '0', 'label': 'A'},
        {'key': '1', 'label': 'B'},
        {'key': '2', 'label': 'C', 'usedBy': 'Maestro'},
      ], reason: "slice B's report lands on the device, and only the open slices");
      await cat.disconnect('flex-a/rx:1');
      expect(cat.flexSlicesToAdd('flex-a').map((slice) => slice.key), ['2']);
    });

    test('follow the device: an edit to its address is every slice\'s, and removing it removes them all', () async {
      final cat = await load({
        'version': 4,
        'nodes': {'flex-a': flex('0'), 'flex-b': flex('1')},
      });
      final slice = cat.nodeFor('flex-a/rx:1')!;
      await cat.updateNode(slice.copyWith(config: {...slice.config, voiceOutputConfigKey: 'Set B speakers'}));
      final device = cat.nodeFor('flex-a')!;
      await cat.updateNode(device.copyWith(config: {...device.config, 'host': 'flex.lan', voiceOutputConfigKey: 'Set A speakers'}));
      // Left on the old address, slice B would be a radio of its own on the
      // next load. Given the device's sound devices, set B's voice messages
      // would play on set A's.
      expect(cat.nodeFor('flex-a/rx:1')!.config, {'host': 'flex.lan', 'port': 4992, 'slice': '1', voiceOutputConfigKey: 'Set B speakers'});
      await cat.removeNode('flex-a');
      expect(cat.nodes, isEmpty);
    });
  });

  test('a remote K4 added is both its receivers, and the Main keeps the VFO', () async {
    final cat = await load({'version': 4, 'nodes': <String, dynamic>{}});
    final added = await cat.addNode(typeKey: 'k4-remote', config: {'host': '192.0.2.4', 'remotePort': 9204});
    expect(cat.nodes.map((node) => node.uuid), [added.uuid, '${added.uuid}/rx:sub']);
    expect(cat.radio1, LocalRadio(added.uuid));
  });

  test('an Everyware rotor and switch are their server\'s, named by what the server calls them', () async {
    final cat = await load({
      'version': 4,
      'nodes': {
        'server': {'typeKey': 'gh-everyware-tcp', 'name': 'WU2X'},
        'rotor-node': {
          'typeKey': 'gh-everyware-rotor',
          'name': 'Tower 1',
          'config': {'everywareServer': 'server', 'everywareDevice': 'Tower 1'},
        },
        'switch-node': {
          'typeKey': 'gh-everyware-directional',
          'name': 'Stack/Dir',
          'config': {'everywareServer': 'server', 'everywareDevice': 'Stack/Dir'},
        },
      },
    });
    // A map switch is a switch on the wire: its kind there, not the rotator
    // it is picked as, is what keeps its id when it is retyped.
    expect(cat.nodes.map((node) => node.uuid), ['server', 'server/rotator:Tower 1', 'server/switch:Stack%2FDir']);
    expect((await saved())['forwarded'], isNull, reason: 'nothing saved yet');
  });
}

const _fakeFlexTypeKey = 'fake-flex';

/// A Flex whose sessions say nothing on their own: the test speaks for the
/// radio through the sink each connection was handed.
class _FakeFlexRadio {
  final sinks = <EquipmentSink>[];

  late final _transport = _FakeLink();

  late final EquipmentRegistry registry = EquipmentRegistry(
    models: [
      EquipmentModel(
        key: 'fake-flex',
        category: kCategoryTransceiver,
        name: () => 'Fake Flex',
        variants: [EquipmentVariant(key: _fakeFlexTypeKey, driver: _FakeFlexDriver(sinks), transport: _transport)],
      ),
    ],
    transports: {_transport.key: _transport},
  );
}

class _FakeFlexDriver extends FlexRadioDriver {
  final List<EquipmentSink> sinks;

  _FakeFlexDriver(this.sinks);

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    sinks.add(sink);
    return _QuietSession();
  }
}

class _QuietSession implements EquipmentSession {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeLink extends EquipmentTransport {
  @override
  String get key => 'fake-flex-link';

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async => _FakeConnection();
}

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
