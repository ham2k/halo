// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The voice message sets as settings (voice_message_set.dart): read on every
// message button's rebuild, so decoded once per write of the Radio group.

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/settings_service.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The trap: what was decoded kept past a write. A set picked, a source
  // changed, or either arriving through settings sync — which writes the
  // group, not these setters — would leave the keys playing the old set.
  test('a write to the Radio group is read back at once, whoever made it', () async {
    final settings = (await makeHaLoServices()).settings;
    expect(settings.voiceMessageSets.map((set) => set.id), [VoiceMessageSet.defaultId]);
    expect(settings.voiceKeyingSource, VoiceKeyingSource.radio);

    const contest = VoiceMessageSet(id: 'contest', name: 'Contest', labels: ['CQ', '', '', '', '', '', '', '']);
    await settings.setVoiceMessageSets([...settings.voiceMessageSets, contest], active: contest.id);
    expect(settings.voiceMessageSets.map((set) => set.id), [VoiceMessageSet.defaultId, 'contest']);
    expect(settings.voiceMessageSetId, 'contest');
    expect(settings.activeVoiceMessageSet.label(1), 'CQ');

    await settings.setVoiceKeyingSource(VoiceKeyingSource.computer);
    expect(settings.voiceKeyingSource, VoiceKeyingSource.computer);

    await settings.updateSettingsGroup(SettingsService.radioGroup, {VoiceMessageSet.sourceKey: VoiceKeyingSource.none.name, VoiceMessageSet.activeKey: null});
    expect(settings.voiceKeyingSource, VoiceKeyingSource.none);
    expect(settings.voiceMessageSetId, VoiceMessageSet.defaultId);
  });
}
