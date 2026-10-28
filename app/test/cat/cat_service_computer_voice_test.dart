// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The computer's voice keyer as CatService wires it, against the placeholder
// radio — a real PttSession that reports TX as it keys, and a voice keyer of
// its own that the computer's must take over from.
//
// The traps: the radio's own memories still playing after the operator
// picked the computer, a message keyed on a radio that reads as off the air
// (the antenna lock and Smart VFO Snap trust that reading), a length shown
// from a stale measurement instead of the file, and a radio left keyed when
// the operator switches back mid-message.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_audio/halo_audio.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/computer_voice_keyer.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/transport.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/fake_clock.dart';
import '../support/fake_voice_audio.dart';
import '../support/halo_test_support.dart';

const codec = AudioDevice(id: 'c0dec', name: 'USB Audio CODEC');

final cq = VoiceMessageSet.empty(id: 's1', name: 'CQ');

// A radio with memories of its own and no CAT key — the shape of a driver
// whose protocol documents a voice keyer and no PTT set.
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
  String get key => 'unkeyable';
  @override
  Future<EquipmentConnection> connect(Map<String, dynamic> target, {required CatCancelToken cancel}) async => _Connection();
}

class _UnkeyableSession implements TransceiverSession, VoiceKeyerSession {
  final played = <int>[];
  @override
  void handleData(Uint8List chunk) {}
  @override
  void startUpdates() {}
  @override
  void stopUpdates() {}
  @override
  void setFrequency(double freqKHz) {}
  @override
  void setMode(String mode) {}
  @override
  void setPower(num watts) {}
  @override
  Duration? get expectedUpdateInterval => null;
  @override
  void teardown() {}
  @override
  int get voiceMemoryCount => 4;
  @override
  bool get canRecordVoice => false;
  @override
  Duration get voiceMemoryCeiling => voiceActivityCeiling;
  @override
  void playVoiceMemory(int n) => played.add(n);
  @override
  void recordVoiceMemory(int n) {}
  @override
  void stopVoice() {}
}

class _UnkeyableDriver extends EquipmentDriver {
  final session = _UnkeyableSession();
  @override
  String get key => 'unkeyable-driver';
  @override
  String get name => 'Unkeyable Radio';
  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late FakeVoiceAudio audio;

  setUp(() async {
    audio = FakeVoiceAudio()
      ..outputDevices = [codec]
      ..lengths['/v/s1/1.wav'] = const Duration(milliseconds: 2400);
    final harness = await makeHaLoServices(
      cat: (settings) => CatService(settings, voiceAudio: audio, voiceMessagesDirectory: () async => '/v'),
    );
    services = harness.services;
    await harness.settings.setExperimentEnabled('keyer', true);
    await harness.settings.setVoiceMessageSets([cq], active: VoiceMessageSet.defaultId);
  });

  Future<EquipmentNode> connectRig({bool fromComputer = true}) async {
    final node = await services.cat.addNode(
      typeKey: 'placeholder-radio',
      name: 'Bench Rig',
      config: {
        ...placeholderRadioModel.variants.single.defaultConfig,
        voiceOutputConfigKey: voiceDeviceToConfig(codec),
        voiceLeadConfigKey: 0,
        voiceTailConfigKey: 0,
      },
    );
    await services.cat.connect(node.uuid);
    addTearDown(() => services.cat.disconnect(node.uuid));
    if (fromComputer) {
      await services.cat.selectVoiceKeyingSource(VoiceKeyingSource.computer);
      await services.cat.selectVoiceMessageSet(cq.id);
    }
    // The recordings directory is found the first time something asks.
    await pumpEventQueue();
    return node;
  }

  test('a radio set to play from the computer keys and plays the recording, not its own memory', () async {
    final cat = services.cat;
    await connectRig();
    expect(cat.voiceMessagesFromComputer, isTrue);
    expect(cat.canPlayVoice, isTrue);
    expect(cat.canRecordVoice, isTrue, reason: 'recording is the computer\'s, whatever the radio can do');

    cat.playVoiceMemory(1, repeat: false);
    await pumpEventQueue();
    expect(audio.plays.single.path, '/v/s1/1.wav');
    expect(audio.plays.single.output!.deviceId, codec.id);
    expect(cat.voiceActivity.value, const VoiceActivity(memory: 1));
    expect(cat.radio1IsTransmitting, isTrue);

    audio.plays.single.end();
    await pumpEventQueue();
    expect(cat.voiceActivity.value, isNull);
    expect(cat.radio1IsTransmitting, isFalse, reason: 'unkeyed once the message ends');
  });

  test('a message\'s length is its file\'s, known before it has ever played', () async {
    final cat = services.cat;
    await connectRig();
    expect(cat.voiceMessageDuration(1), 2400);
    expect(cat.voiceMessageDuration(2), 0);
  });

  test('a message said with words has no length, whatever recording it still has', () async {
    // The recording beside the words is not what plays: shown, it says the
    // message is the recording, and the keyer area paces a 2.4 s bar
    // against words that take one.
    final cat = services.cat;
    await connectRig();
    await services.settings.setExperimentEnabled('words', true);
    await cat.keyer('A').setVoiceMessageTemplate(1, '{{ qso.call }}');
    expect(cat.voiceMessageDuration(1), 0);
    expect(cat.keyer('A').voiceMessageVoiced(1), isTrue);
  });

  test('without the setting, the radio plays its own memories as before', () async {
    final cat = services.cat;
    await connectRig(fromComputer: false);
    expect(cat.voiceMessagesFromComputer, isFalse);
    cat.playVoiceMemory(1, repeat: false);
    await pumpEventQueue();
    expect(audio.plays, isEmpty);
    expect(cat.voiceActivity.value, const VoiceActivity(memory: 1));
    cat.stopVoice();
  });

  test('switching back to the radio\'s memories mid-message stops it and unkeys', () async {
    final cat = services.cat;
    await connectRig();
    cat.playVoiceMemory(1, repeat: false);
    await pumpEventQueue();
    expect(cat.radio1IsTransmitting, isTrue);

    await cat.selectVoiceKeyingSource(VoiceKeyingSource.radio);
    // The next question any surface asks finds the radio's own keyer — and
    // the computer's, dropped on the way, stops what it was playing.
    expect(cat.canPlayVoice, isTrue);
    expect(audio.plays.single.stopped, isTrue);
    expect(cat.radio1IsTransmitting, isFalse);
  });

  group('sets', () {
    // The set in use picks the recordings: a label or a length read from
    // another set's — or from the radio's own memories — names audio that
    // is not what plays.
    test("each set has its own recordings and labels, and the radio's own memories keep theirs", () async {
      final cat = services.cat;
      await services.settings.setVoiceMessageLabel(1, 'Radio CQ');
      await connectRig();
      await cat.setVoiceMessageLabel(1, 'Recorded CQ');
      expect(cat.voiceMessageDuration(1), 2400);
      expect(cat.voiceMessageLabel(1), 'Recorded CQ');

      final pota = await cat.addVoiceMessageSet('POTA');
      expect(services.settings.voiceMessageSetId, pota!.id, reason: 'a new set is put in use');
      audio.lengths.remove('/v/${pota.id}/1.wav');
      await cat.setVoiceMessageLabel(1, 'POTA CQ');
      expect(cat.voiceMessageDuration(1), 0);
      cat.playVoiceMemory(1, repeat: false);
      expect(audio.plays, isEmpty, reason: 'nothing recorded in this set, and nothing borrowed from another');

      await cat.selectVoiceMessageSet(cq.id);
      expect(cat.voiceMessageLabel(1), 'Recorded CQ');
      await cat.selectVoiceKeyingSource(VoiceKeyingSource.radio);
      expect(cat.voiceMessageLabel(1), 'Radio CQ');
    });

    test('a new set copies the set in use, recordings included', () async {
      final cat = services.cat;
      await connectRig();
      await cat.setVoiceMessageLabel(1, 'CQ');
      final copy = await cat.addVoiceMessageSet('CQ again');
      expect(audio.copied, [('/v/s1/1.wav', '/v/${copy!.id}/1.wav')]);
      expect(cat.voiceMessageLabel(1), 'CQ');
      expect(cat.voiceMessageDuration(1), 2400);
    });

    // The trap: a file this app cannot play reading as "Not recorded" — and
    // left out of a copy as if it were not there, though it is the
    // operator's, in the folder.
    test("a file the computer cannot play is said to be one, and a new set copies it all the same", () async {
      final cat = services.cat;
      audio.unreadable.add('/v/s1/2.wav');
      await connectRig();
      expect(cat.voiceMessageDuration(2), 0);
      expect(cat.keyer('A').voiceMessageUnplayable(2), isTrue);
      expect(cat.keyer('A').voiceMessageUnplayable(3), isFalse, reason: 'not recorded is not unplayable');

      final copy = await cat.addVoiceMessageSet('Copy');
      expect(audio.copied, contains(('/v/s1/2.wav', '/v/${copy!.id}/2.wav')));
    });

    test('deleting the set in use stops its message, removes its recordings, and puts the next set in use', () async {
      final cat = services.cat;
      await connectRig();
      final second = await cat.addVoiceMessageSet('Second');
      await cat.selectVoiceMessageSet(cq.id);
      cat.playVoiceMemory(1, repeat: false);
      await pumpEventQueue();
      expect(cat.radio1IsTransmitting, isTrue, reason: 'sanity');

      await cat.deleteVoiceMessageSet(cq.id);
      expect(audio.plays.single.stopped, isTrue);
      expect(cat.radio1IsTransmitting, isFalse);
      expect(audio.deleted, contains('/v/s1'));
      expect(audio.lengths.keys.where((path) => path.startsWith('/v/s1/')), isEmpty);
      expect(services.settings.voiceMessageSetId, second!.id);

      await cat.deleteVoiceMessageSet(second.id);
      expect(services.settings.voiceMessageSetId, VoiceMessageSet.defaultId, reason: 'the set beside it, which is the default');
    });

    // The default set has a directory every install shares, and a name the
    // operator's language gives it: deleted, its recordings would go with
    // it; renamed, the name would stop following the language.
    test('the default set is always there, first, and is neither deleted nor renamed', () async {
      final cat = services.cat;
      await connectRig();
      expect([for (final set in services.settings.voiceMessageSets) set.id], [VoiceMessageSet.defaultId, cq.id]);
      await cat.selectVoiceMessageSet(VoiceMessageSet.defaultId);
      await cat.setVoiceMessageLabel(1, 'CQ POTA');
      await cat.deleteVoiceMessageSet(VoiceMessageSet.defaultId);
      await cat.renameVoiceMessageSet(VoiceMessageSet.defaultId, 'Mine');
      expect(audio.deleted, isEmpty);
      final kept = services.settings.voiceMessageSets.first;
      expect(kept.id, VoiceMessageSet.defaultId);
      expect(kept.name, 'Sound files on this computer');
      expect(kept.label(1), 'CQ POTA', reason: 'its labels are stored like any set');
    });

    // A stored pick whose set is gone (deleted on a synced settings copy,
    // say) must not fall to another of the operator's sets, whose audio they
    // never chose for this — only to the one every install has.
    test('a pick whose set is gone means the default set', () async {
      await services.settings.setVoiceMessageSets([cq], active: cq.id);
      await services.settings.updateSettingsGroup(SettingsService.radioGroup, {VoiceMessageSet.setsKey: <Object>[]});
      expect(services.settings.voiceMessageSetId, VoiceMessageSet.defaultId);
    });
  });

  // The operator picked the computer: falling back to the radio's own
  // memories while the directory is looked up would put audio on the air
  // they did not choose.
  test('until the recordings directory is known, nothing plays: not the radio\'s own memories either', () async {
    final pending = Completer<String>();
    final harness = await makeHaLoServices(
      cat: (settings) => CatService(settings, voiceAudio: audio, voiceMessagesDirectory: () => pending.future),
    );
    await harness.settings.setExperimentEnabled('keyer', true);
    final cat = harness.services.cat;
    final node = await cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    await cat.connect(node.uuid);
    addTearDown(() => cat.disconnect(node.uuid));
    await cat.selectVoiceKeyingSource(VoiceKeyingSource.computer);
    await pumpEventQueue();
    expect(cat.voiceMessagesFromComputer, isFalse);
    expect(cat.canPlayVoice, isFalse);

    pending.complete('/v');
    await pumpEventQueue();
    expect(cat.voiceMessagesFromComputer, isTrue);
  });

  // None is the operator turning phone messages off: the radio's memories
  // must not play from a key, and the surfaces say it is off rather than
  // that the radio cannot.
  test('Phone Keying set to None plays nothing, and says it is off', () async {
    final cat = services.cat;
    await connectRig(fromComputer: false);
    expect(cat.canPlayVoice, isTrue, reason: 'sanity: the radio has memories');
    await cat.selectVoiceKeyingSource(VoiceKeyingSource.none);
    expect(cat.canPlayVoice, isFalse);
    expect(cat.radio1HasVoiceMemories, isFalse);
    expect(cat.phoneKeyingOff, isTrue);
    expect(cat.radio1OffersVoiceMemories, isTrue, reason: 'the radio is still offered as a source');
  });

  // The pick is about radio1 and this desk's sound devices: Radio B keeps to
  // its own memories, and "None" for radio1 must not silence it.
  test("under SO2R, Phone Keying is radio1's: Radio B plays its own memories whatever is picked", () async {
    await services.settings.setExperimentEnabled('so2r', true);
    final cat = services.cat;
    Future<String> rig(String name) async {
      final node = await cat.addNode(typeKey: 'placeholder-radio', name: name, config: placeholderRadioModel.variants.single.defaultConfig);
      await cat.connect(node.uuid);
      addTearDown(() => cat.disconnect(node.uuid));
      return node.uuid;
    }

    final left = await rig('Left Rig'), right = await rig('Right Rig');
    await cat.setRadio1(LocalRadio(left));
    await cat.setRadio2(right);
    // Radio B wired to a sound card of its own: a computer keyer built for
    // it opens that device, which is how one would show here.
    await cat.updateNode(cat.nodeFor(right)!.copyWith(config: {...cat.nodeFor(right)!.config, voiceOutputConfigKey: voiceDeviceToConfig(codec)}));
    await cat.selectVoiceKeyingSource(VoiceKeyingSource.none);
    expect(cat.keyer('A').canPlayVoice, isFalse);
    expect(cat.keyer('B').canPlayVoice, isTrue);
    expect(cat.keyer('B').phoneKeyingOff, isFalse);

    await cat.selectVoiceKeyingSource(VoiceKeyingSource.computer);
    await pumpEventQueue();
    expect(cat.keyer('B').voiceMessagesFromComputer, isFalse, reason: "the computer's recordings play on radio1");
    expect(cat.keyer('B').canPlayVoice, isTrue);
    expect(audio.opened, isEmpty, reason: "no computer keyer for Radio B, holding its sound device");
  });

  // The recordings are this operator's, for the radio they key: a keyer for
  // a radio this device only offers would take its sound device (or a Flex's
  // DAX source) and play this desk's recordings to the peer keying it.
  test('a radio other than radio1 gets no computer keyer', () async {
    final cat = services.cat;
    final mine = await cat.addNode(typeKey: 'placeholder-radio', name: 'My Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    final other = await cat.addNode(
      typeKey: 'placeholder-radio',
      name: 'Offered Rig',
      config: {...placeholderRadioModel.variants.single.defaultConfig, voiceOutputConfigKey: voiceDeviceToConfig(codec)},
    );
    for (final node in [mine, other]) {
      await cat.connect(node.uuid);
      addTearDown(() => cat.disconnect(node.uuid));
    }
    await cat.setRadio1(LocalRadio(mine.uuid));
    await cat.selectVoiceKeyingSource(VoiceKeyingSource.computer);
    await pumpEventQueue();
    expect(audio.opened, isEmpty, reason: "a computer keyer built for the offered radio opens its sound device");
  });

  test('Escape stops the message and unkeys', () async {
    final cat = services.cat;
    await connectRig();
    cat.playVoiceMemory(1, repeat: false);
    await pumpEventQueue();
    expect(cat.stopKeying(), isTrue);
    expect(audio.plays.single.stopped, isTrue);
    expect(cat.radio1IsTransmitting, isFalse);
  });

  test('a disconnect mid-message silences the audio', () async {
    final cat = services.cat;
    final node = await connectRig();
    cat.playVoiceMemory(1, repeat: false);
    await pumpEventQueue();
    await cat.disconnect(node.uuid);
    expect(audio.plays.single.stopped, isTrue);
    expect(cat.voiceActivity.value, isNull);
  });

  // The keyer goes with the session, and its going is not the message
  // ending: taken for one, the repeat waits out its cooldown and keys the CQ
  // again on a radio that reconnects within it.
  test('a disconnect mid-message ends the repeat', () async {
    final cat = services.cat;
    await services.settings.setVoiceRepeat(true);
    await services.settings.setVoiceRepeatCooldown(3);
    final node = await connectRig();
    cat.playVoiceMemory(1);
    await pumpEventQueue();
    await cat.disconnect(node.uuid);
    await pumpEventQueue();
    expect(cat.keyerRepeat.value, isNull, reason: 'no wait started');
    expect(cat.keyerRepeating, isFalse);
  });

  // Skipping the timing of a recording's play once also skipped what ends
  // a play for the repeat: the CQ played once and never again.
  test(
    'a message played from the computer repeats, like a radio memory',
    () => runOnFakeClock((_) async {
      final cat = services.cat;
      await services.settings.setVoiceRepeat(true);
      await services.settings.setVoiceRepeatCooldown(3);
      await connectRig();
      cat.playVoiceMemory(1);
      await pumpEventQueue();
      audio.plays.single.end();
      await pumpEventQueue();
      expect(cat.keyerRepeat.value?.delay, const Duration(seconds: 3), reason: 'waiting to go again');
      await Future<void>.delayed(const Duration(seconds: 3, milliseconds: 100));
      expect(audio.plays, hasLength(2));
      cat.stopVoice();
    }),
  );

  // Repeated, a play that failed fails again — keying the radio for its lead
  // each cooldown, with nothing going out after it.
  test(
    'a message whose sound device goes away mid-play is not repeated',
    () => runOnFakeClock((_) async {
      final cat = services.cat;
      await services.settings.setVoiceRepeat(true);
      await services.settings.setVoiceRepeatCooldown(3);
      await connectRig();
      cat.playVoiceMemory(1);
      await pumpEventQueue();
      expect(audio.plays, hasLength(1));
      audio.opened.single.unplug();
      await Future<void>.delayed(voiceDoubtLinger + const Duration(seconds: 3, milliseconds: 100));
      expect(cat.keyerRepeating, isFalse);
      expect(audio.plays, hasLength(1));
    }),
  );

  test('a radio its CAT cannot key plays nothing — never its own memories in the computer\'s place', () async {
    final driver = _UnkeyableDriver();
    final transport = _Transport();
    final registry = EquipmentRegistry(
      models: [
        EquipmentModel(
          key: 'unkeyable',
          category: kCategoryTransceiver,
          name: () => 'Unkeyable Radio',
          variants: [EquipmentVariant(key: 'unkeyable-type', driver: driver, transport: transport)],
        ),
      ],
      transports: {'unkeyable': transport},
    );
    final harness = await makeHaLoServices(
      cat: (settings) => CatService(settings, registry: registry, voiceAudio: audio, voiceMessagesDirectory: () async => '/v'),
    );
    await harness.settings.setExperimentEnabled('keyer', true);
    await harness.settings.setVoiceMessageSets([cq], active: cq.id);
    final cat = harness.services.cat;
    final node = await cat.addNode(typeKey: 'unkeyable-type', config: {'host': 'radio.local', voiceOutputConfigKey: voiceDeviceToConfig(codec)});
    await cat.connect(node.uuid);
    addTearDown(() => cat.disconnect(node.uuid));
    await cat.selectVoiceKeyingSource(VoiceKeyingSource.computer);
    // The directory is looked up the first time a surface asks.
    expect(cat.computerVoiceAudio, isNotNull);
    await pumpEventQueue();

    expect(cat.voiceMessagesFromComputer, isTrue);
    expect(cat.canPlayVoice, isFalse);
    expect(cat.computerVoiceProblem, ComputerVoiceProblem.cannotKey);
    cat.playVoiceMemory(1, repeat: false);
    expect(driver.session.played, isEmpty);
    expect(audio.opened, isEmpty);
    expect(cat.canRecordVoice, isTrue, reason: 'recording keys nothing');
  });

  // The sets are named and recorded before the rig is on the desk: recording
  // keys nothing, so it needs no radio — and with none, nothing plays.
  test('with no radio at all, a message is recorded, and nothing plays', () async {
    final cat = services.cat;
    await cat.selectVoiceKeyingSource(VoiceKeyingSource.computer);
    await cat.selectVoiceMessageSet(cq.id);
    // The directory is looked up the first time a surface asks.
    expect(cat.computerVoiceAudio, isNotNull);
    await pumpEventQueue();
    expect(cat.canRecordVoice, isTrue);
    expect(cat.canPlayVoice, isFalse);
    cat.recordVoiceMemory(2);
    expect(cat.voiceActivity.value, const VoiceActivity(memory: 2, recording: true));
    expect(audio.opened, isEmpty, reason: 'recording opens no output');
    audio.lengths[audio.recordings.single.path] = const Duration(seconds: 2);
    cat.stopVoice();
    expect(cat.voiceActivity.value, isNull);
    expect(audio.replaced.single.$2, '/v/s1/2.wav', reason: 'kept as the message');
    expect(cat.listenToVoiceMessage(2), isNotNull, reason: 'and heard back on the computer');
  });

  test('a recording started with no radio is kept when the radio connects', () async {
    final cat = services.cat;
    await cat.selectVoiceKeyingSource(VoiceKeyingSource.computer);
    await cat.selectVoiceMessageSet(cq.id);
    // The directory is looked up the first time a surface asks.
    expect(cat.computerVoiceAudio, isNotNull);
    await pumpEventQueue();
    cat.recordVoiceMemory(2);
    audio.lengths[audio.recordings.single.path] = const Duration(seconds: 2);
    await connectRig();
    expect(audio.recordings.single.stopped, isTrue, reason: "the radio's keyer takes over");
    expect(audio.replaced.single.$2, '/v/s1/2.wav');
    expect(cat.voiceActivity.value, isNull);
  });
}
