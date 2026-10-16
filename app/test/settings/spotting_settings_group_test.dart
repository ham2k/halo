// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Spotting section: what it stores, what the logging panel reads back,
// and that the Spotting control's tune button finds its fields.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/spotting_settings.dart';
import 'package:ham2k_logger/settings/spotting_settings_group.dart';

void main() {
  Future<SettingsService> fresh([Map<String, Object> stored = const {}]) async {
    SharedPreferences.setMockInitialValues(stored);
    return SettingsService(await SharedPreferences.getInstance());
  }

  test('defaults to every ten minutes, offering rather than starting, and pulsing', () async {
    final settings = await fresh();
    expect(SpottingSettings.respotInterval(settings), const Duration(minutes: 10));
    expect(SpottingSettings.autoRespotByDefault(settings), isFalse);
    expect(SpottingSettings.pulseBeforeRespot(settings), isTrue);
  });

  test('what the section commits is what the panel reads back', () async {
    final settings = await fresh();
    final group = SpottingSettingsGroup(settings);
    await group.commit('respotIntervalMinutes', '20');
    await group.commit('autoRespotByDefault', true);
    await group.commit('pulseBeforeRespot', false);
    expect(SpottingSettings.respotInterval(settings), const Duration(minutes: 20));
    expect(SpottingSettings.autoRespotByDefault(settings), isTrue);
    expect(SpottingSettings.pulseBeforeRespot(settings), isFalse);
  });

  // A string under a toggle's key would make its getter throw where the
  // logging panel reads it.
  test('a value of the wrong kind for its key is not stored', () async {
    final settings = await fresh();
    final group = SpottingSettingsGroup(settings);
    await group.commit('autoRespotByDefault', 'yes');
    await group.commit('pulseBeforeRespot', 'no');
    await group.commit('respotIntervalMinutes', true);
    await group.commit('someRenamedKey', true);
    expect(settings.settingsGroup(SpottingSettings.group), isEmpty);
    expect(SpottingSettings.autoRespotByDefault(settings), isFalse);
  });

  // A value the picker never offered — another build's list, a hand-edited
  // store — would otherwise show one interval while respotting on another.
  test('a stored interval the picker does not offer snaps to the nearest one it does', () async {
    final settings = await fresh({'settings.spotting': '{"respotIntervalMinutes": "45"}'});
    expect(SpottingSettings.respotInterval(settings), const Duration(minutes: 30));
    final interval = (await SpottingSettingsGroup(settings).buildElements()).firstWhere((e) => e['key'] == 'respotIntervalMinutes');
    expect(interval['value'], '30');
  });

  test('a stored interval that is no number at all takes the default', () async {
    final settings = await fresh({'settings.spotting': '{"respotIntervalMinutes": "NaN"}'});
    expect(SpottingSettings.respotInterval(settings), const Duration(minutes: 10));
  });

  // The tune button opens `target: 'spotting'`: a field without it would be
  // in All settings and missing from the dialog.
  test('every field is in the tune dialog', () async {
    final elements = await SpottingSettingsGroup(await fresh()).buildElements();
    expect(elements, hasLength(3));
    expect(elements.map((e) => e['target']), everyElement('spotting'));
    final options = elements.firstWhere((e) => e['key'] == 'respotIntervalMinutes')['options'] as List;
    expect([for (final o in options) (o as Map)['value']], [for (final m in SpottingSettings.respotIntervalOptions) '$m']);
  });
}
