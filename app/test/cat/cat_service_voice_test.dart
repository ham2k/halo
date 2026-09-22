// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The voice surface of CatService, against the placeholder radio: which
// radio plays (radio1, not the key in use), what the surfaces are told
// while nothing can, and whose activity is shown. The placeholder is a
// real VoiceKeyerSession that "plays" for a few seconds, so what the
// service reports is what a session reported, not a hand-built stand-in.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/placeholder_radio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices();
    final settings = harness.settings;
    services = harness.services;
    await settings.setExperimentEnabled('keyer', true);
  });

  Future<EquipmentNode> connectPlaceholder(String name) async {
    final node = await services.cat.addNode(typeKey: 'placeholder-radio', name: name, config: placeholderRadioModel.variants.single.defaultConfig);
    await services.cat.connect(node.uuid);
    addTearDown(() => services.cat.disconnect(node.uuid));
    return node;
  }

  test('nothing can play until a radio is connected, and every count is zero', () async {
    final cat = services.cat;
    expect(cat.canPlayVoice, isFalse);
    expect(cat.voiceMemoryCount, 0);
    expect(cat.canRecordVoice, isFalse);
    // No-ops, not errors: the surfaces exist only while canPlayVoice, so
    // reaching here is the radio dropping between the check and the key.
    cat.playVoiceMemory(1);
    cat.stopVoice();
    expect(cat.voiceActivity.value, isNull);
  });

  test('radio1 plays: its memories are offered, a play is shown, a stop clears it', () async {
    final cat = services.cat;
    await connectPlaceholder('Bench Rig');
    expect(cat.radio1, isNotNull, reason: 'sanity: the first transceiver becomes radio1');
    expect(cat.canPlayVoice, isTrue);
    expect(cat.voiceMemoryCount, placeholderVoiceMemoryCount);
    expect(cat.canRecordVoice, isTrue);

    cat.playVoiceMemory(3);
    expect(cat.voiceActivity.value, const VoiceActivity(memory: 3));
    cat.stopVoice();
    expect(cat.voiceActivity.value, isNull);

    cat.recordVoiceMemory(2);
    expect(cat.voiceActivity.value, const VoiceActivity(memory: 2, recording: true));
    cat.stopVoice();
    expect(cat.voiceActivity.value, isNull);
  });

  test('only radio1\'s activity is shown, and moving radio1 clears what was', () async {
    final cat = services.cat;
    final first = await connectPlaceholder('Rig A');
    final second = await connectPlaceholder('Rig B');
    // Adding a transceiver makes it radio1; put A back in charge.
    await cat.setRadio1(LocalRadio(first.uuid));

    cat.playVoiceMemory(1);
    expect(cat.voiceActivity.value, isNotNull);
    // The trap: a change of radio1 leaving Rig A's "playing" on a strip
    // that now belongs to Rig B.
    await cat.setRadio1(LocalRadio(second.uuid));
    expect(cat.voiceActivity.value, isNull);
    // Rig A is still playing for real; its report must not land on B's strip.
    expect(cat.stateFor(first.uuid).status, EquipmentStatus.connected, reason: 'sanity');
    cat.playVoiceMemory(2); // on B, now radio1
    expect(cat.voiceActivity.value, const VoiceActivity(memory: 2));
  });

  test('a disconnect clears what radio1 was playing', () async {
    final cat = services.cat;
    final node = await connectPlaceholder('Bench Rig');
    cat.playVoiceMemory(1);
    expect(cat.voiceActivity.value, isNotNull);
    await cat.disconnect(node.uuid);
    expect(cat.voiceActivity.value, isNull);
  });
}
