// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Operating positions as the station stores them, and the migration into
// them from the keys that came before (docs/design/station-model.md § 9).
//
// Station Configuration is in every release, so the migration runs on real
// stations. What these tests defend is that nothing an operator set up is
// lost or moved on the way: the radio driving `vfoA`, SO2R's Radio B, and
// the antenna and key picked for each radio, None included.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/station_positions.dart';
import 'package:ham2k_logger/services/peer/peer_station_radios.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var ids = 0;
  String newId() => 'p${ids++}';
  setUp(() => ids = 0);

  const peer = PeerRadioSelection(deviceId: 'device-a', radioId: 'rig-1', deviceName: 'Laptop', radioName: 'IC-705');

  Map<String, dynamic> nodes(List<String> uuids) => {
    for (final uuid in uuids) uuid: {'typeKey': 'fake-type', 'name': uuid},
  };

  group('the stored positions', () {
    test('a radio has one position, and picking it again finds the same one', () {
      // What makes a rig's antenna and key come back when it is picked again.
      final positions = StationPositions(newId);
      positions.slotsFor(const LocalRadio('rig'))['antenna'] = 'yagi';
      positions.setRadio(kSetA, const LocalRadio('other'));
      positions.setRadio(kSetA, const LocalRadio('rig'));
      expect(positions.slotsOf(positions.radioOf(kSetA)), {'antenna': 'yagi'});
      expect(positions.all.where((p) => p.radio == const LocalRadio('rig')), hasLength(1));
    });

    test('a peer radio picked again under a new name keeps the new name', () {
      final positions = StationPositions(newId)..setRadio(kSetA, const PeerRadio(PeerRadioSelection(deviceId: 'device-a', radioId: 'rig-1')));
      positions.setRadio(kSetA, const PeerRadio(peer));
      expect((positions.radioOf(kSetA)! as PeerRadio).selection.radioName, 'IC-705');
      expect(positions.all, hasLength(1));
    });

    test('a removed node leaves its own position and every pick of it', () {
      final positions = StationPositions(newId)
        ..setRadio(kSetA, const LocalRadio('rig'))
        ..setRadio(kSetB, const LocalRadio('rig-b'));
      positions.slotsFor(const LocalRadio('rig-b'))['key'] = 'paddle';
      positions.slotsFor(const LocalRadio('rig'))['key'] = 'paddle';
      positions.slotsFor(const LocalRadio('rig'))['antenna'] = null;

      positions.forgetNode('rig-b');
      expect(positions.radioOf(kSetB), isNull);
      positions.forgetNode('paddle');
      // Never decided again, not None: a radio that keys goes back to keying
      // for itself. The explicit None for the antenna is not a pick of the
      // paddle and stays.
      expect(positions.slotsOf(const LocalRadio('rig')), {'antenna': null});
    });

    test('a position with nothing picked that no set logs from is not stored', () {
      final positions = StationPositions(newId)
        ..setRadio(kSetA, const LocalRadio('one'))
        ..setRadio(kSetA, const LocalRadio('two'));
      final stored = positions.toJson()['positions'] as Map;
      expect(stored.values.map((p) => (p as Map)['radio']), [
        {'local': 'two'},
      ]);
    });

    test('what is stored reads back as the same station', () {
      final positions = StationPositions(newId)
        ..setRadio(kSetA, const PeerRadio(peer))
        ..setRadio(kSetB, const LocalRadio('rig-b'));
      positions.slotsFor(const PeerRadio(peer))['key'] = null;
      positions.slotsFor(null)['antenna'] = 'dipole';

      final read = StationPositions.fromJson(jsonDecode(jsonEncode(positions.toJson())) as Map<String, dynamic>, hasNode: (_) => true, newId: newId);
      expect(read.radioOf(kSetA), const PeerRadio(peer));
      expect((read.radioOf(kSetA)! as PeerRadio).selection.deviceName, 'Laptop');
      expect(read.radioOf(kSetB), const LocalRadio('rig-b'));
      expect(read.slotsOf(const PeerRadio(peer)), {'key': null});
      expect(read.slotsOf(null), {'antenna': 'dipole'});
    });

    test('what no longer exists is dropped on read, and never replaced by something that does', () {
      final read = StationPositions.fromJson(
        {
          'positions': {
            'gone': {
              'radio': {'local': 'unloaded-rig'},
              'slots': {'antenna': 'yagi'},
            },
            'here': {
              'radio': {'local': 'rig'},
              'slots': {'antenna': 'unloaded-antenna', 'key': null},
            },
            'again': {
              'radio': {'local': 'rig'},
              'slots': {'antenna': 'yagi'},
            },
          },
          'sets': {'A': 'gone', 'B': 'here'},
        },
        hasNode: (uuid) => uuid == 'rig' || uuid == 'yagi',
        newId: newId,
      );
      // Set A was a radio that did not load: None, never the rig next to it.
      expect(read.radioOf(kSetA), isNull);
      expect(read.radioOf(kSetB), const LocalRadio('rig'));
      // A second position for one radio is a hand edit, and the first wins.
      // The pick of a node that did not load goes; the explicit None stays.
      expect(read.slotsOf(const LocalRadio('rig')), {'key': null});
    });

    test('set B never logs from set A\'s radio, or from a peer\'s', () {
      Map<String, dynamic> blob(Map<String, dynamic> radio) => {
        'positions': {
          'a': {
            'radio': {'local': 'rig'},
            'slots': <String, dynamic>{},
          },
          'b': {'radio': radio, 'slots': <String, dynamic>{}},
        },
        'sets': {'A': 'a', 'B': 'b'},
      };
      expect(StationPositions.fromJson(blob({'local': 'rig'}), hasNode: (_) => true, newId: newId).radioOf(kSetB), isNull);
      expect(StationPositions.fromJson(blob({'peer': peer.toJson()}), hasNode: (_) => true, newId: newId).radioOf(kSetB), isNull);
    });
  });

  group('a station stored before positions', () {
    late SettingsService settings;

    Future<CatService> load(Map<String, dynamic> blob) async {
      SharedPreferences.setMockInitialValues({'stationEquipment': jsonEncode(blob)});
      final prefs = await SharedPreferences.getInstance();
      settings = SettingsService(prefs);
      await settings.setExperimentEnabled('so2r', true);
      final cat = CatService(settings, radio: RadioService(prefs, writeDelay: Duration.zero));
      addTearDown(cat.dispose);
      return cat;
    }

    final version3 = {
      'version': 3,
      'mainVfo': {'radio': 'rig-a'},
      'radio2': 'rig-b',
      'designated': {
        'rig-a': {'antenna': 'yagi', 'key': null},
        'rig-b': {'key': 'paddle'},
        'rig-c': {'antenna': 'dipole'},
        'none': {'antenna': 'dipole'},
      },
      'nodes': nodes(['rig-a', 'rig-b', 'rig-c', 'yagi', 'dipole', 'paddle']),
    };

    test('keeps both radios and every radio\'s picks, None included', () async {
      final cat = await load(version3);
      expect(cat.radio1, const LocalRadio('rig-a'));
      expect(cat.radio2, 'rig-b');
      expect(cat.designatedFor(kCategoryAntenna), 'yagi');
      // The operator's None, not a radio keying for itself.
      expect(cat.designatedFor(kCategoryKey), isNull);
      expect(cat.designatedFor(kCategoryKey, radio: 'rig-b'), 'paddle');

      // A radio in neither set keeps its picks for when it is picked again,
      // and so does "no radio".
      await cat.setRadio1(const LocalRadio('rig-c'));
      expect(cat.designatedFor(kCategoryAntenna), 'dipole');
      await cat.setRadio1(null);
      expect(cat.designatedFor(kCategoryAntenna), 'dipole');
      await cat.setRadio1(const LocalRadio('rig-a'));
      expect(cat.designatedFor(kCategoryAntenna), 'yagi');
    });

    test('is written back as positions, and reads back the same', () async {
      final cat = await load(version3);
      await cat.setRadio1(const LocalRadio('rig-c'));
      await cat.setRadio1(const LocalRadio('rig-a'));

      final blob = jsonDecode((await SharedPreferences.getInstance()).getString('stationEquipment')!) as Map<String, dynamic>;
      expect(blob['version'], 4);
      expect(blob['positions'], isNotEmpty);

      final reloaded = await load(blob);
      expect(reloaded.radio1, const LocalRadio('rig-a'));
      expect(reloaded.radio2, 'rig-b');
      expect(reloaded.designatedFor(kCategoryAntenna), 'yagi');
      expect(reloaded.designatedFor(kCategoryKey), isNull);
      expect(reloaded.designatedFor(kCategoryKey, radio: 'rig-b'), 'paddle');
    });

    test('opened in an older build and saved there, comes back with nothing lost', () async {
      // A tester going back to a build from before positions: it reads the
      // version 3 keys and saves without the positions. Written as positions
      // alone, that save would leave every radio and pick None.
      final cat = await load(version3);
      await cat.setRadio1(const LocalRadio('rig-c'));
      await cat.setRadio1(const LocalRadio('rig-a'));
      final saved = jsonDecode((await SharedPreferences.getInstance()).getString('stationEquipment')!) as Map<String, dynamic>;
      final olderBuildSave = {...saved, 'version': 3}
        ..remove('positions')
        ..remove('sets');

      final back = await load(olderBuildSave);
      expect(back.radio1, const LocalRadio('rig-a'));
      expect(back.radio2, 'rig-b');
      expect(back.designatedFor(kCategoryAntenna), 'yagi');
      expect(back.designatedFor(kCategoryKey), isNull, reason: 'None stays None');
      expect(back.designatedFor(kCategoryKey, radio: 'rig-b'), 'paddle');
      await back.setRadio1(const LocalRadio('rig-c'));
      expect(back.designatedFor(kCategoryAntenna), 'dipole', reason: 'a radio in neither set keeps its picks too');
    });

    test('keeps a peer radio driving vfoA, with its name and its picks', () async {
      final cat = await load({
        'version': 3,
        'mainVfo': {'peer': peer.toJson()},
        'designated': {
          peerRadioValue(peer): {'key': null},
        },
        'nodes': <String, dynamic>{},
      });
      expect(cat.radio1, const PeerRadio(peer));
      expect((cat.radio1! as PeerRadio).selection.radioName, 'IC-705');
      // None stays None: the peer's own keying is only the default.
      expect(cat.peerKeyIsInUse, isFalse);
    });

    test('version 1\'s one set of picks belongs to the radio it was written under', () async {
      final cat = await load({
        'version': 1,
        'radio1': 'rig-a',
        'designated': {'antenna': 'yagi'},
        'nodes': nodes(['rig-a', 'rig-c', 'yagi']),
      });
      expect(cat.designatedFor(kCategoryAntenna), 'yagi');
      await cat.setRadio1(const LocalRadio('rig-c'));
      expect(cat.designatedFor(kCategoryAntenna), isNull, reason: 'another radio\'s antenna is not decided by this one\'s');
    });

    test('a Radio B that is also radio1 is dropped, not swapped', () async {
      final cat = await load({
        'version': 3,
        'mainVfo': {'radio': 'rig-a'},
        'radio2': 'rig-a',
        'nodes': nodes(['rig-a']),
      });
      expect(cat.radio1, const LocalRadio('rig-a'));
      expect(cat.radio2, isNull);
    });
  });
}
