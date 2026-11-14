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

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;

  Future<CatService> load(Map<String, dynamic> blob, {Map<String, String> passwords = const {}, bool keychainRefuses = false}) async {
    SharedPreferences.setMockInitialValues({'stationEquipment': jsonEncode(blob)});
    final prefs = await SharedPreferences.getInstance();
    settings = SettingsService(prefs, secureStorage: FakeSecureStorage(failWrites: keychainRefuses));
    await settings.setExperimentEnabled('so2r', true);
    for (final MapEntry(key: identity, value: password) in passwords.entries) {
      await settings.setEquipmentSecret(identity, 'password', password);
    }
    final cat = CatService(settings, radio: RadioService(prefs, writeDelay: Duration.zero));
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
