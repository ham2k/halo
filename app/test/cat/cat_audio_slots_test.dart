// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where a radio is heard and the operator's microphone goes, as a position's
// audio slots, and the operator's own microphone and headphones beside the
// positions (docs/design/station-model.md § 5 and § 6.1).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart' show AudioDevice;
import 'package:ham2k_logger/services/audio/radio_audio.dart' show receiveAudioConfigKey, talkAudioConfigKey;
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/station_positions.dart';
import 'package:ham2k_logger/services/radio_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;

  Future<CatService> load(Map<String, dynamic> blob, {Map<String, Object?> radioSettings = const {}}) async {
    SharedPreferences.setMockInitialValues({'stationEquipment': jsonEncode(blob)});
    final prefs = await SharedPreferences.getInstance();
    settings = SettingsService(prefs);
    for (final MapEntry(:key, :value) in radioSettings.entries) {
      await settings.setSettingValue(SettingsService.radioGroup, key, value);
    }
    final cat = CatService(settings, radio: RadioService(prefs, writeDelay: Duration.zero));
    addTearDown(cat.dispose);
    return cat;
  }

  Future<Map<String, dynamic>> saved() async => jsonDecode((await SharedPreferences.getInstance()).getString('stationEquipment')!) as Map<String, dynamic>;

  Map<String, dynamic> flex(String slice, {Map<String, dynamic> extra = const {}}) => {
    'typeKey': 'flexradio-tcp',
    'name': 'Shack Flex',
    'config': {'host': 'flex.local', 'port': 4992, 'slice': slice, ...extra},
  };

  test('hearing a radio in HaLo is its position\'s receive audio, the radio\'s own', () async {
    final cat = await load({
      'version': 4,
      'nodes': {'flex-a': flex('0')},
    });
    await cat.setHearsInHalo('flex-a', true);
    await cat.setTalksThroughHalo('flex-a', true);
    expect(cat.hearsInHalo('flex-a'), isTrue);
    expect(cat.talksThroughHalo('flex-a'), isTrue);

    // A position's slot, not the radio's settings: the radio is what is
    // heard, and where it is heard is the operator's arrangement.
    final blob = await saved();
    expect(blob['nodes']['flex-a']['config'], isNot(contains(receiveAudioConfigKey)));
    final slots = (blob['positions'] as Map).values.single['slots'];
    expect(slots, {kSlotReceiveAudio: 'flex-a/audio:0', kSlotTransmitAudio: 'flex-a/audio:0'});

    final again = await load(blob);
    expect(again.hearsInHalo('flex-a'), isTrue);
    await again.setHearsInHalo('flex-a', false);
    expect(again.hearsInHalo('flex-a'), isFalse);
    expect(again.talksThroughHalo('flex-a'), isTrue);
  });

  test('a radio\'s old flags become its slots once, and a choice made since stays made', () async {
    final cat = await load({
      'version': 4,
      'nodes': {
        'flex-a': flex('0', extra: {receiveAudioConfigKey: true, talkAudioConfigKey: true}),
      },
    });
    expect(cat.hearsInHalo('flex-a'), isTrue);
    expect(cat.talksThroughHalo('flex-a'), isTrue);

    // The flags stay for an older build. Read again over a slot answered
    // None, they would turn the radio back on at every launch.
    await cat.setHearsInHalo('flex-a', false);
    final blob = await saved();
    expect(blob['nodes']['flex-a']['config'][receiveAudioConfigKey], isTrue);
    final again = await load(blob);
    expect(again.hearsInHalo('flex-a'), isFalse);
    expect(again.talksThroughHalo('flex-a'), isTrue);
  });

  test('the station microphone and output become the operator\'s, by id with the name beside', () async {
    final cat = await load(
      {'version': 4, 'nodes': <String, dynamic>{}},
      radioSettings: {
        'microphone': {'id': 'mic-id', 'name': 'USB Microphone'},
        'output': {'id': 'out-id', 'name': 'USB Audio CODEC'},
      },
    );
    expect(cat.operatorMicrophone, (id: 'mic-id', name: 'USB Microphone'));
    expect(cat.operatorHeadphones, (id: 'out-id', name: 'USB Audio CODEC'));

    // The system's default, picked since, is an answer: the old setting
    // must not come back over it.
    await cat.setOperatorMicrophone(null);
    await cat.setOperatorHeadphones(const AudioDevice(id: 'new-id', name: 'Headset'));
    final blob = await saved();
    final again = await load(
      blob,
      radioSettings: {
        'microphone': {'id': 'mic-id', 'name': 'USB Microphone'},
      },
    );
    expect(again.operatorMicrophone, isNull);
    expect(again.operatorHeadphones, (id: 'new-id', name: 'Headset'));
  });

  test('a pick of a slice the radio merged follows the slice', () async {
    // Slice B's node becomes the radio's rx:1 when both load at one
    // address: a pick on its old id would otherwise name nothing.
    final cat = await load({
      'version': 4,
      'nodes': {'flex-a': flex('0'), 'flex-b': flex('1')},
      'positions': {
        'p-b': {
          'radio': {'local': 'flex-b'},
          'slots': {kSlotReceiveAudio: 'flex-b/audio:1', kSlotTransmitAudio: 'flex-b/audio:1/out:0'},
        },
      },
      'sets': {'A': 'p-b'},
    });
    expect(cat.nodes.map((n) => n.uuid), contains('flex-a/rx:1'));
    expect(cat.hearsInHalo('flex-a/rx:1'), isTrue);
    // A channel stays the channel it was: forwarded as the whole audio, a
    // route of one channel would carry both.
    await cat.setHearsInHalo('flex-a/rx:1', false);
    final slots = ((await saved())['positions'] as Map).values.single['slots'];
    expect(slots[kSlotTransmitAudio], 'flex-a%2Frx:1/audio:1/out:0');
  });

  test('a pick of something this station does not have is dropped as it loads', () async {
    final cat = await load({
      'version': 4,
      'nodes': {'flex-a': flex('0')},
      'positions': {
        'p-a': {
          'radio': {'local': 'flex-a'},
          'slots': {kSlotReceiveAudio: 'gone/audio:0', kSlotTransmitAudio: 'flex-a/audio:0'},
        },
      },
      'sets': {'A': 'p-a'},
      'operator': {kOperatorHeadphones: 'computer/audio:aa', kOperatorMicrophone: 'gone/audio:bb'},
    });
    expect(cat.hearsInHalo('flex-a'), isFalse);
    expect(cat.talksThroughHalo('flex-a'), isTrue);
    // This computer is always there, and its cards are matched as the
    // engine opens them, so a card not plugged in now is kept.
    expect(cat.operatorHeadphones, (id: 'aa', name: null));
    expect(cat.operatorMicrophone, isNull);
  });

  group('a pick naming a Flex slice\'s node, whose id is an address itself', () {
    // `<flex>/rx:1` names slice B's node, not the radio: read as an audio
    // address it would be the radio's, kept while the slice is gone and
    // left behind when the slice is removed.
    var next = 0;
    String newId() => 'p${next++}';

    test('is kept while that node is here, and dropped when it is not', () {
      final blob = {
        'positions': {
          'p-a': {
            'radio': {'local': 'flex-a'},
            'slots': {'key': 'flex-a/rx:1'},
          },
        },
      };
      final kept = StationPositions.fromJson(blob, hasNode: {'flex-a', 'flex-a/rx:1'}.contains, newId: newId);
      expect(kept.slotsOf(const LocalRadio('flex-a')), {'key': 'flex-a/rx:1'});
      final dropped = StationPositions.fromJson(blob, hasNode: {'flex-a'}.contains, newId: newId);
      expect(dropped.slotsOf(const LocalRadio('flex-a')), isEmpty);
    });

    test('goes with that node, and not with the radio\'s', () {
      final positions = StationPositions(newId);
      positions.slotsFor(const LocalRadio('k3'))['key'] = 'flex-a/rx:1';
      positions.slotsFor(const LocalRadio('k3'))[kSlotReceiveAudio] = 'flex-a/audio:0';
      positions.forgetNode('flex-a/rx:1');
      expect(positions.slotsOf(const LocalRadio('k3')), {kSlotReceiveAudio: 'flex-a/audio:0'});
      positions.forgetNode('flex-a');
      expect(positions.slotsOf(const LocalRadio('k3')), isEmpty);
    });
  });
}
