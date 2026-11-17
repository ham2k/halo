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
import 'package:ham2k_logger/services/audio/radio_audio.dart' show receiveAudioConfigKey, receiveAudioDelayConfigKey;
import 'package:ham2k_logger/services/audio/radio_audio_settings.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/computer_voice_keyer.dart' show voiceOutputConfigKey;
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
              voiceOutputConfigKey: 'Set A speakers',
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
      expect(cat.nodeFor(added)!.config, {'host': 'flex.local', 'port': 4992, 'slice': '2'}, reason: "the radio's settings, not slice A's sound devices");
      expect(cat.flexSlicesToAdd('flex-a'), isEmpty);
      expect(cat.radioNameFor(cat.nodeFor(added)!), 'Shack Flex · Slice C');
    });

    test("name each slice by the radio's letter, and by its station while two stations hold the radio's slices", () async {
      // Each station letters its own slices from A: under multiFLEX two
      // slices are both "Slice A", and only the station tells them apart.
      Future<CatService> holding(List<Map<String, String>> open, {String? clientId}) => load({
        'version': 4,
        'nodes': {
          'flex-a': {
            ...flex('0'),
            'config': {...flex('0')['config'] as Map<String, dynamic>, flexKnownSlicesConfigKey: open, flexClientIdConfigKey: ?clientId},
          },
          'flex-b': flex('1'),
        },
      });
      var cat = await holding([
        {'key': '0', 'label': 'A', 'holder': 'CUBAGUA'},
        {'key': '1', 'label': 'B', 'holder': 'CUBAGUA'},
        {'key': '2', 'label': 'A', 'holder': 'chirimena'},
      ]);
      expect(cat.channelNameFor(cat.nodeFor('flex-a')!), 'Slice A on CUBAGUA');
      expect(cat.radioNameFor(cat.nodeFor('flex-a/rx:1')!), 'Shack Flex · Slice B on CUBAGUA');
      expect(cat.flexSliceName('flex-a', '2'), 'Slice A on chirimena', reason: "the radio's letter, not one from its index");
      cat = await holding([
        {'key': '0', 'label': 'A', 'holder': 'CUBAGUA'},
        {'key': '2', 'label': 'A', 'holder': 'Chirimena', 'holderId': 'HALO-ID'},
      ], clientId: 'HALO-ID');
      expect(cat.flexSliceName('flex-a', '2'), 'Slice A', reason: "HaLo's own: this computer's, so no station to name");
      // HaLo's station goes by the computer's name, as SmartSDR on it does:
      // left plain, SmartSDR's slice reads exactly like HaLo's own.
      cat = await holding([
        {'key': '0', 'label': 'A', 'holder': 'Chirimena'},
        {'key': '2', 'label': 'A', 'holder': 'Chirimena', 'holderId': 'HALO-ID'},
      ], clientId: 'HALO-ID');
      expect(cat.flexSliceName('flex-a', '0'), 'Slice A on Chirimena');
      expect(cat.flexSliceName('flex-a', '2'), 'Slice A');
      cat = await holding([
        {'key': '0', 'label': 'A', 'holder': 'CUBAGUA'},
        {'key': '1', 'label': 'B', 'holder': 'CUBAGUA'},
      ]);
      expect(cat.channelNameFor(cat.nodeFor('flex-a/rx:1')!), 'Slice B', reason: 'one station: the letter says it all');
    });

    test('share one connection to the radio, which no slice opens again', () async {
      // Two connections are two subscriptions, and the second `sub slice
      // all` breaks the first slice's audio in the operator's headphones.
      final radio = _FakeFlexRadio();
      final cat = await load({
        'version': 4,
        'nodes': {
          'flex-a': {...flex('0'), 'typeKey': _fakeFlexTypeKey},
          'flex-b': {...flex('1'), 'typeKey': _fakeFlexTypeKey},
        },
      }, registry: radio.registry);
      await cat.connect('flex-a');
      await cat.connect('flex-a/rx:1');
      expect(radio.opened, 1);
      radio.say(
        'S1|slice 0 in_use=1 RF_frequency=14.074000 mode=DIGU\n'
        'S1|slice 1 in_use=1 RF_frequency=7.030000 mode=CW\n'
        'S1|slice 2 in_use=1 RF_frequency=21.074000 mode=DIGU\n',
      );
      await pumpEventQueue();
      expect(cat.stateFor('flex-a').vfo.freqKHz, 14074);
      expect(cat.stateFor('flex-a/rx:1').vfo.freqKHz, 7030, reason: 'each slice reads its own from the one stream');
      final added = (await cat.addFlexSlice('flex-a', '2'))!;
      await pumpEventQueue();
      expect(cat.stateFor(added).status, EquipmentStatus.connected, reason: 'a slice picked while the radio is on joins it');
      expect(radio.opened, 1);
      await cat.disconnect(added);
      await cat.disconnect('flex-a');
      expect(radio.closed, 0, reason: 'slice B still holds it');
      await cat.disconnect('flex-a/rx:1');
      await pumpEventQueue();
      expect(radio.closed, 1);
    });

    // Under multiFLEX a key, the power read back and a DAX channel are each
    // the bound station's: followed through another's binding, a slice keys
    // that station's transmitter and plays its audio.
    test("slices two stations hold ride a connection each, and a slice found to be another station's moves onto its own", () async {
      final radio = _FakeFlexRadio();
      final cat = await load({
        'version': 4,
        'nodes': {
          'flex-a': {...flex('0'), 'typeKey': _fakeFlexTypeKey},
          'flex-b': {...flex('1'), 'typeKey': _fakeFlexTypeKey},
        },
      }, registry: radio.registry);
      await cat.connect('flex-a');
      await cat.connect('flex-a/rx:1');
      expect(radio.opened, 1, reason: 'neither slice known to be anyone\'s yet');
      radio.say(
        'V1.4.0.0\nH5AC2F980\n'
        'S1|client 0x3DFA9A2A connected client_id=CUBA-ID program=SmartSDR-Win station=CUBAGUA\n'
        'S1|client 0x13A3B2B3 connected client_id=CHIRI-ID program=AetherSDR station=chirimena\n'
        'S1|slice 0 in_use=1 client_handle=0x13A3B2B3 index_letter=A\n'
        'S1|slice 1 in_use=1 client_handle=0x3DFA9A2A index_letter=A\n',
      );
      await pumpEventQueue();
      expect(radio.opened, 3, reason: "each onto its own station's connection");
      expect(cat.stateFor('flex-a').status, EquipmentStatus.connected);
      expect(cat.stateFor('flex-a/rx:1').status, EquipmentStatus.connected);
      // A connection's refresh describes its slices one at a time, and before
      // it lists its stations: read as held by nobody, a slice would move
      // off its station's connection, and back, at every connect.
      radio.say('V1.4.0.0\nH5AC2F980\nS1|slice 1 in_use=1 client_handle=0x3DFA9A2A index_letter=A\n');
      await pumpEventQueue();
      radio.say('S1|client 0x3DFA9A2A connected client_id=CUBA-ID program=SmartSDR-Win station=CUBAGUA\n');
      await pumpEventQueue();
      expect(radio.opened, 3, reason: "no move while the radio is still saying whose each slice is");
      await cat.disconnect('flex-a');
      await cat.disconnect('flex-a/rx:1');
    });

    test('lose a slice closed on the radio that nothing uses, and keep one a set logs from', () async {
      // Left behind, every slice ever opened and closed in SmartSDR would
      // stay listed, each saying it is not open.
      final radio = _FakeFlexRadio();
      final cat = await load({
        'version': 4,
        'nodes': {
          'flex-a': {...flex('0'), 'typeKey': _fakeFlexTypeKey},
          'flex-b': {...flex('1'), 'typeKey': _fakeFlexTypeKey},
          'flex-c': {...flex('2'), 'typeKey': _fakeFlexTypeKey},
          'flex-d': {
            ...flex('3'),
            'typeKey': _fakeFlexTypeKey,
            'config': {...flex('3')['config'] as Map<String, dynamic>, voiceOutputConfigKey: 'Set B speakers'},
          },
        },
        'positions': {
          'b': {
            'radio': {'local': 'flex-c'},
            'slots': <String, dynamic>{},
          },
        },
        'sets': {'B': 'b'},
      }, registry: radio.registry);
      expect(cat.radio2, 'flex-a/rx:2');
      for (final id in cat.entriesOf('flex-a')) {
        await cat.connect(id);
      }
      radio.say('S1|slice 0 in_use=0\nS1|slice 1 in_use=0\nS1|slice 2 in_use=0\nS1|slice 3 in_use=0\nS1|slice 1 in_use=1\nS1|slice 1 in_use=0\n');
      await pumpEventQueue();
      expect(cat.entriesOf('flex-a'), [
        'flex-a',
        'flex-a/rx:2',
        'flex-a/rx:3',
      ], reason: "slice A is the radio's, slice C is set B's, slice D holds settings of its own");
      expect(cat.stateFor('flex-a/rx:2').problem, isNotNull, reason: 'kept, and saying why it hears nothing');
      expect((await saved())['nodes'].keys, isNot(contains('flex-a/rx:1')));
    });

    test("HaLo's own slice registers its station under the id the radio gave it last time, on a connection of its own", () async {
      // Without the id the radio opens a fresh station, and the slices it
      // kept for HaLo's are never brought back.
      final radio = _FakeFlexRadio();
      final cat = await load({
        'version': 4,
        'nodes': {
          'flex-a': {
            ...flex('0', host: '192.0.2.1'),
            'typeKey': _fakeFlexTypeKey,
            'config': {...flex('0', host: '192.0.2.1')['config'] as Map<String, dynamic>, flexClientIdConfigKey: '1DF30D74'},
          },
          'flex-a/rx:own-A': {
            'typeKey': _fakeFlexTypeKey,
            'name': 'Shack Flex',
            'config': {'host': '192.0.2.1', 'port': 4992, flexOwnSliceConfigKey: 'A'},
          },
        },
      }, registry: radio.registry);
      await cat.connect('flex-a');
      await cat.connect('flex-a/rx:own-A');
      expect(radio.opened, 2, reason: "HaLo's station beside the connection bound to another's");
      radio.say('V1.4.0.0\nH5AC2F980\n');
      await pumpEventQueue();
      expect(radio.sent.where((line) => line.contains('client gui')), [contains('client gui 1DF30D74')]);
      await cat.disconnect('flex-a/rx:own-A');
      await cat.disconnect('flex-a');
    });

    // The editor saves the settings it read as it opened: a station id the
    // radio gave meanwhile, lost, leaves HaLo's slices kept on the radio for
    // a station that never comes back.
    test("an editor's save keeps the station id the radio gave while it was open", () async {
      final cat = await load({
        'version': 4,
        'nodes': {'flex-a': flex('0')},
      });
      final opened = cat.nodeFor('flex-a')!;
      await cat.updateNode(opened.copyWith(config: {...opened.config, flexClientIdConfigKey: '1DF30D74'}));
      await cat.updateNode(opened.copyWith(config: {...opened.config, flexStationNameConfigKey: 'Shack-Mac'}));
      expect(cat.nodeFor('flex-a')!.config[flexClientIdConfigKey], '1DF30D74');
    });

    // The editor shows the buffering at its default: a save of anything else
    // would otherwise drop every radio, mid-QSO.
    test('an edit to the audio buffering reconnects only a radio heard here', () async {
      final radio = _FakeFlexRadio();
      final cat = await load({
        'version': 4,
        'nodes': {
          'flex-a': {...flex('0'), 'typeKey': _fakeFlexTypeKey},
        },
      }, registry: radio.registry);
      await cat.connect('flex-a');
      final node = cat.nodeFor('flex-a')!;
      await cat.updateNode(node.copyWith(config: {...node.config, receiveAudioDelayConfigKey: 500}));
      await pumpEventQueue();
      expect(radio.opened, 1, reason: 'nobody hears it here');
      await cat.disconnect('flex-a');
    });

    test("a connected radio whose audio settings are edited reconnects to take them", () async {
      // Its links to the audio engine are made as it connects: an edit left
      // for the next connect is one the operator does not hear.
      final radio = _FakeFlexRadio();
      final cat = await load({
        'version': 4,
        'nodes': {
          'flex-a': {...flex('0'), 'typeKey': _fakeFlexTypeKey},
        },
      }, registry: radio.registry);
      await cat.connect('flex-a');
      final node = cat.nodeFor('flex-a')!;
      await cat.updateNode(node.copyWith(config: {...node.config, 'host': 'flex.local'}));
      await pumpEventQueue();
      expect(radio.opened, 1, reason: 'nothing to do with its audio');
      await cat.updateNode(node.copyWith(config: {...node.config, receiveAudioConfigKey: true}));
      await pumpEventQueue();
      expect(radio.opened, 2);
      expect(cat.stateFor('flex-a').status, EquipmentStatus.connected);
      await cat.disconnect('flex-a');
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
      radio.say(
        'S1|client 0x2 connected program=Maestro\n'
        'S1|slice 0 in_use=1 index_letter=A\n'
        'S1|slice 1 in_use=1 index_letter=B\n'
        'S1|slice 2 in_use=1 index_letter=C client_handle=0x2\n'
        'S1|slice 3 in_use=0 index_letter=D\n',
      );
      await pumpEventQueue();
      expect((await saved())['nodes']['flex-a']['config'][flexKnownSlicesConfigKey], [
        {'key': '0', 'label': 'A'},
        {'key': '1', 'label': 'B'},
        {'key': '2', 'label': 'C', 'usedBy': 'Maestro', 'holder': 'Maestro'},
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
      // How far behind the radio's audio may fall is set once, in its
      // editor, for every slice: a slice has no editor of its own.
      final edited = cat.nodeFor('flex-a')!;
      await cat.updateNode(edited.copyWith(config: {...edited.config, receiveAudioDelayConfigKey: 250}));
      expect(cat.nodeFor('flex-a/rx:1')!.config[receiveAudioDelayConfigKey], 250);
      await cat.removeNode('flex-a');
      expect(cat.nodes, isEmpty);
    });
  });

  // A slider's every step stored would write the preferences dozens of times
  // a second; stored at the end only, it is heard as it moves all the same.
  test("the mix's volume and each radio's level are heard as they move, and stored as the drag ends", () async {
    final cat = await load({'version': 4, 'nodes': <String, dynamic>{}});
    await cat.setMixVolume(0.3);
    await cat.setMixLevel('flex-a', 0.6);
    expect((cat.mixVolume, cat.mixLevel('flex-a')), (0.3, 0.6));
    expect((settings.stationVolume, settings.radioLevel('flex-a')), (1.0, 1.0), reason: 'not stored mid-drag');
    await cat.setMixVolume(0.4, store: true);
    await cat.setMixLevel('flex-a', 0.7, store: true);
    expect((settings.stationVolume, settings.radioLevel('flex-a')), (0.4, 0.7));
    expect((cat.mixVolume, cat.mixLevel('flex-a')), (0.4, 0.7));
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

/// A Flex the test speaks for, on a link that counts its connections. It
/// never says its handshake, so no subscription, and no meter socket, is
/// opened for it.
class _FakeFlexRadio {
  int opened = 0, closed = 0;

  /// Every command sent, on whichever of its connections.
  final sent = <String>[];
  _FakeConnection? _connection;

  late final _transport = _FakeLink(this);

  late final EquipmentRegistry registry = EquipmentRegistry(
    models: [
      EquipmentModel(
        key: 'fake-flex',
        category: kCategoryTransceiver,
        name: () => 'Fake Flex',
        variants: [EquipmentVariant(key: _fakeFlexTypeKey, driver: const FlexRadioDriver(), transport: _transport)],
      ),
    ],
    transports: {_transport.key: _transport},
  );

  void say(String text) => _connection!._data.add(Uint8List.fromList(utf8.encode(text)));
}

class _FakeLink extends EquipmentTransport {
  final _FakeFlexRadio radio;

  _FakeLink(this.radio);

  @override
  String get key => 'fake-flex-link';

  /// A network link's own fields, as the real one's: what a slice takes from
  /// its radio rather than holding as its own.
  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => const [
    {'type': 'field', 'key': 'host'},
    {'type': 'field', 'key': 'port'},
  ];

  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async {
    radio.opened++;
    return radio._connection = _FakeConnection(radio);
  }
}

class _FakeConnection implements EquipmentConnection {
  final _FakeFlexRadio radio;
  final _data = StreamController<Uint8List>();
  final _closed = Completer<void>();

  _FakeConnection(this.radio);

  @override
  Stream<Uint8List> get data => _data.stream;
  @override
  Future<void> get closed => _closed.future;
  @override
  void send(List<int> bytes) => radio.sent.add(utf8.decode(bytes));
  @override
  Future<void> close() async {
    if (_closed.isCompleted) return;
    radio.closed++;
    _closed.complete();
    unawaited(_data.close());
  }
}
