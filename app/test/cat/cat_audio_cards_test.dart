// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A radio on a USB codec, heard through one of this computer's sound cards
// and keyed with the operator's microphone sent into another
// (docs/design/station-model.md § 5.1, docs/design/audio.md § 7): its
// position's audio slots naming a card rather than the radio's own audio.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/audio/radio_audio.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
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

/// An IC-7300 on its USB codec: keyed from CAT, with its transmit audio
/// switched to the computer's for a key that sends it.
class _Rig implements TransceiverSession, ComputerAudioPttSession {
  final keys = <String>[];
  void Function()? refused;
  bool switches = true;
  bool refusesAtOnce = false;
  bool keyThrows = false;

  @override
  bool get switchesToComputerAudio => switches;
  @override
  void setPttWithComputerAudio(bool on, {void Function()? refused}) {
    if (on && keyThrows) throw StateError('link down');
    keys.add(on ? 'computer on' : 'computer off');
    this.refused = refused;
    // A Flex that cannot transmit says so from inside the key.
    if (on && refusesAtOnce) refused?.call();
  }

  @override
  void setPtt(bool on) => keys.add(on ? 'on' : 'off');
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
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final rig = _Rig();
    made.add(rig);
    return rig;
  }
}

void main() {
  late SettingsService settings;
  late CatService cat;
  late RadioAudio audio;
  late List<_Rig> rigs;
  // Hex, as the engine writes a device's id: the null backend opens it as
  // the one device it has.
  const codec = AudioDevice(id: 'c0dec0', name: 'USB Audio CODEC', channels: 2);
  var listed = <AudioDevice>[codec];

  setUpAll(() {
    try {
      HaloAudio.useNullBackend();
    } on StateError {
      // Chosen already by another test in this process.
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setExperimentEnabled('audio', true);
    final radio = RadioService(await SharedPreferences.getInstance(), writeDelay: Duration.zero);
    addTearDown(radio.dispose);
    rigs = [];
    listed = [codec];
    final transport = _Transport();
    audio = RadioAudio(outputs: () => listed, inputs: () => listed, ear: (radio) => cat.earInMix(radio));
    cat = CatService(
      settings,
      radio: radio,
      radioAudio: audio,
      registry: EquipmentRegistry(
        models: [
          EquipmentModel(
            key: 'rig',
            category: kCategoryTransceiver,
            name: () => 'Rig',
            variants: [EquipmentVariant(key: 'rig-type', driver: _RigDriver(rigs), transport: transport)],
          ),
        ],
        transports: {'fake': transport},
      ),
    );
    addTearDown(cat.dispose);
  });

  Future<EquipmentNode> aRig() async {
    final node = await cat.addNode(typeKey: 'rig-type');
    await cat.setRadio1(LocalRadio(node.uuid));
    return node;
  }

  group('heard through a sound card', () {
    test('while its radio is connected, and not once it is not', () async {
      // A radio switched off is not heard as its codec's hiss.
      final rig = await aRig();
      await cat.setHeardCard(rig.uuid, codec);
      expect(cat.heardCard(rig.uuid), (id: 'c0dec0', name: 'USB Audio CODEC'));
      expect(audio.hearsCard(rig.uuid), isFalse);
      await cat.connect(rig.uuid);
      expect(audio.hearsCard(rig.uuid), isTrue);
      await cat.disconnect(rig.uuid);
      expect(audio.hearsCard(rig.uuid), isFalse);
    });

    test('is heard through this computer, and counts for its mixer', () async {
      final rig = await aRig();
      await cat.setHeardCard(rig.uuid, codec);
      expect(cat.radiosThroughComputer.map((node) => node.uuid), [rig.uuid]);
      await cat.setHearsInHalo(rig.uuid, false);
      expect(cat.heardCard(rig.uuid), isNull, reason: 'On The Radio clears the card');
      expect(cat.radiosThroughComputer, isEmpty);
    });

    test('lets this computer be SO2R\'s switcher, as a radio\'s own audio does', () async {
      // Two radios on codecs are the station this was built for: the mixer
      // pans and mutes both, as it does a Flex's slices heard here.
      await settings.setExperimentEnabled('so2r', true);
      await pumpEventQueue();
      final a = await aRig();
      final b = await cat.addNode(typeKey: 'rig-type');
      await cat.setRadio1(LocalRadio(a.uuid));
      await cat.setRadio2(b.uuid);
      await cat.setHeardCard(a.uuid, codec);
      expect(cat.so2rComputerSwitches, isFalse);
      await cat.setHeardCard(b.uuid, const AudioDevice(id: 'c0dec1', name: 'USB Audio CODEC 2'));
      expect(cat.so2rComputerSwitches, isTrue);
    });

    test('only while its radio is a logging set\'s, and from the moment it becomes one', () async {
      // A slice the operator moved away from stays heard otherwise, with no
      // choice left to quiet it: Listen to Audio is a set's.
      final rig = await aRig();
      final spare = await cat.addNode(typeKey: 'rig-type');
      await cat.setRadio1(LocalRadio(rig.uuid));
      await cat.setHeardCard(spare.uuid, codec);
      await cat.connect(spare.uuid);
      expect(audio.hearsCard(spare.uuid), isFalse);
      expect(cat.radiosThroughComputer, isEmpty);
      await cat.setRadio1(LocalRadio(spare.uuid));
      expect(audio.hearsCard(spare.uuid), isTrue);
      expect(cat.radiosThroughComputer.map((node) => node.uuid), [spare.uuid]);
      await cat.setRadio1(LocalRadio(rig.uuid));
      expect(audio.hearsCard(spare.uuid), isFalse);
    });

    test('radio B is heard as SO2R turns on, and not once it turns off', () async {
      // Turning SO2R on makes Radio B a set: its slider shows, and it must
      // play then, not at some later reconnect.
      await settings.setExperimentEnabled('so2r', true);
      await pumpEventQueue();
      final a = await aRig();
      final b = await cat.addNode(typeKey: 'rig-type');
      await cat.setRadio1(LocalRadio(a.uuid));
      await cat.setRadio2(b.uuid);
      await cat.setHeardCard(b.uuid, codec);
      await cat.connect(b.uuid);
      expect(audio.hearsCard(b.uuid), isTrue);
      await settings.setExperimentEnabled('so2r', false);
      await pumpEventQueue();
      expect(audio.hearsCard(b.uuid), isFalse);
      await settings.setExperimentEnabled('so2r', true);
      await pumpEventQueue();
      expect(audio.hearsCard(b.uuid), isTrue);
    });

    test('a radio the mixer does not list plays nothing, whatever is still open', () async {
      // A radio leaving its set keeps its stream until it next reconnects;
      // at its level until then, it plays with no slider to turn it down.
      final rig = await aRig();
      final spare = await cat.addNode(typeKey: 'rig-type');
      await cat.setRadio1(LocalRadio(spare.uuid));
      await cat.setHeardCard(spare.uuid, codec);
      expect(audio.gainsFor(spare.uuid), (1.0, 1.0));
      await cat.setRadio1(LocalRadio(rig.uuid));
      expect(audio.gainsFor(spare.uuid), (0.0, 0.0));
    });

    test('is heard again in the operator\'s new headphones', () async {
      // Its route goes with the old output; asked again for the same card,
      // a radio still holding it would stay silent until it reconnects.
      final rig = await aRig();
      await cat.setHeardCard(rig.uuid, codec);
      await cat.connect(rig.uuid);
      final before = audio.cardInput(rig.uuid);
      await cat.setOperatorHeadphones(codec);
      expect(audio.cardInput(rig.uuid), isNotNull);
      expect(audio.cardInput(rig.uuid), isNot(same(before)));
    });

    test('a card not plugged in says so on the radio\'s row', () async {
      final rig = await aRig();
      await cat.setHeardCard(rig.uuid, codec);
      listed = [];
      await cat.connect(rig.uuid);
      expect(cat.stateFor(rig.uuid).audioProblem, t.settings.station.audioProblemReceiveCard(name: 'USB Audio CODEC'));
      expect(audio.hearsCard(rig.uuid), isFalse);
    });
  });

  group('the microphone through a sound card', () {
    test('a key opens it into the card and keys with the computer\'s audio, and the unkey closes both', () async {
      final rig = await aRig();
      await cat.setTalkCard(rig.uuid, codec);
      await cat.connect(rig.uuid);
      cat.togglePtt(rig.uuid);
      expect(rigs.single.keys, ['computer on']);
      expect(audio.talksToCard, isTrue);
      cat.togglePtt(rig.uuid);
      // A plain key would send the radio's own microphone, and a route left
      // open would play the operator's room into the card after the over.
      expect(rigs.single.keys, ['computer on', 'computer off']);
      expect(audio.talksToCard, isFalse);
    });

    test('a radio out of every set keys its own microphone, whatever card it had', () async {
      // Its Microphone choice is a set's: out of a set, a card it kept would
      // take the operator's voice with no choice on screen saying so.
      final rig = await aRig();
      final spare = await cat.addNode(typeKey: 'rig-type');
      await cat.setRadio1(LocalRadio(spare.uuid));
      await cat.setTalkCard(spare.uuid, codec);
      await cat.setRadio1(LocalRadio(rig.uuid));
      await cat.connect(spare.uuid);
      cat.togglePtt(spare.uuid);
      expect(rigs.single.keys, ['on']);
      expect(audio.talksToCard, isFalse);
    });

    test('a key with no card picked is the radio\'s own', () async {
      final rig = await aRig();
      await cat.connect(rig.uuid);
      cat.togglePtt(rig.uuid);
      expect(rigs.single.keys, ['on']);
      expect(audio.talksToCard, isFalse);
    });

    test('a card that will not open keys nothing, and says why', () async {
      // Keyed anyway, the radio would send its own idle mic, or the
      // computer's silence, under the operator's key.
      final rig = await aRig();
      await cat.setTalkCard(rig.uuid, codec);
      await cat.connect(rig.uuid);
      listed = [];
      cat.togglePtt(rig.uuid);
      expect(rigs.single.keys, isEmpty);
      expect(cat.pttHeldOn(rig.uuid), isFalse);
      expect(cat.stateFor(rig.uuid).audioProblem, t.settings.station.audioProblemTalkCard(name: 'USB Audio CODEC'));
    });

    test('a source the radio refuses lets go of the key', () async {
      final rig = await aRig();
      await cat.setTalkCard(rig.uuid, codec);
      await cat.connect(rig.uuid);
      cat.togglePtt(rig.uuid);
      rigs.single.refused!();
      expect(cat.pttHeldOn(rig.uuid), isFalse);
      expect(audio.talksToCard, isFalse);
    });

    test('the unkey goes out whatever changed during the over', () async {
      // The key is latched: the operator can move the radio out of its set
      // mid-over, and an unkey that read the set again would leave the
      // radio keyed and the microphone open.
      final rig = await aRig();
      final spare = await cat.addNode(typeKey: 'rig-type');
      await cat.setRadio1(LocalRadio(rig.uuid));
      await cat.setTalkCard(rig.uuid, codec);
      await cat.connect(rig.uuid);
      cat.togglePtt(rig.uuid);
      await cat.setRadio1(LocalRadio(spare.uuid));
      await pumpEventQueue();
      cat.togglePtt(rig.uuid);
      expect(rigs.first.keys, ['computer on', 'computer off']);
      expect(audio.talksToCard, isFalse);
    });

    test('a refusal from inside the key closes the over, says so, and leaves the next key plain', () async {
      // Held as an over through the card after the refusal let go of it,
      // the next radio's unkey would go to the card's path and never out.
      final rig = await aRig();
      final plain = await cat.addNode(typeKey: 'rig-type');
      await cat.setRadio1(LocalRadio(rig.uuid));
      await cat.setTalkCard(rig.uuid, codec);
      await cat.connect(rig.uuid);
      await cat.connect(plain.uuid);
      rigs.first.refusesAtOnce = true;
      cat.togglePtt(rig.uuid);
      expect(cat.pttHeldOn(rig.uuid), isFalse);
      expect(audio.talksToCard, isFalse);
      expect(cat.stateFor(rig.uuid).audioProblem, t.settings.station.audioProblemTalkCardRefused);
      cat.togglePtt(plain.uuid);
      cat.togglePtt(plain.uuid);
      expect(rigs.last.keys, ['on', 'off']);
    });

    test('a key that fails closes the microphone it opened', () async {
      final rig = await aRig();
      await cat.setTalkCard(rig.uuid, codec);
      await cat.connect(rig.uuid);
      rigs.single.keyThrows = true;
      cat.togglePtt(rig.uuid);
      expect(cat.pttHeldOn(rig.uuid), isFalse);
      expect(audio.talksToCard, isFalse);
    });

    test('a radio that no longer takes the computer\'s audio keys as any other', () async {
      // A K4 refused once keys plainly after: the operator's microphone sent
      // into a card the radio is not listening to is an over of silence.
      final rig = await aRig();
      await cat.setTalkCard(rig.uuid, codec);
      await cat.connect(rig.uuid);
      rigs.single.switches = false;
      cat.togglePtt(rig.uuid);
      expect(rigs.single.keys, ['on']);
      expect(audio.talksToCard, isFalse);
    });

    test('its radio dropping mid-over closes what went into the card', () async {
      final rig = await aRig();
      await cat.setTalkCard(rig.uuid, codec);
      await cat.connect(rig.uuid);
      cat.togglePtt(rig.uuid);
      await cat.disconnect(rig.uuid);
      expect(audio.talksToCard, isFalse);
    });
  });
}
