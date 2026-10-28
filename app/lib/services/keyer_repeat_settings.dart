// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'settings_service.dart';

/// The cooldowns message 1 may wait before it goes again, in seconds.
/// Strings, like every other option list in the settings, so a stored value
/// names an item of the picker that set it.
const keyerRepeatCooldowns = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];

/// Message 1's repeat as settings — beside the keyer rather than in
/// settings_service.dart, which is over its size budget. Only message 1
/// repeats: it is the CQ, and a repeating exchange or report would key over
/// the contact it is answering (docs/design/cat.md § CW keying). A switch
/// and a cooldown, kept apart so turning the repeat off and on again keeps
/// the wait the operator chose.
extension KeyerRepeatSettings on SettingsService {
  static const _defaultCooldown = 5;

  bool get cwRepeat => _repeats('cwRepeat', 'cwRepeatDelay');
  Future<void> setCwRepeat(bool on) => setSettingValue(SettingsService.radioGroup, 'cwRepeat', on);

  /// The wait before message 1 goes again while it repeats, whether or not
  /// it does now.
  Duration get cwRepeatCooldown => _cooldown('cwRepeatDelay');
  Future<void> setCwRepeatCooldown(int seconds) => setSettingValue(SettingsService.radioGroup, 'cwRepeatDelay', '$seconds');

  /// How long after message 1 finishes keying before it goes again, or
  /// [Duration.zero] for no repeat.
  Duration get cwRepeatDelay => cwRepeat ? cwRepeatCooldown : Duration.zero;

  /// The voice counterparts, and the same rule: only memory 1 repeats.
  bool get voiceRepeat => _repeats('voiceRepeat', 'voiceRepeatDelay');
  Future<void> setVoiceRepeat(bool on) => setSettingValue(SettingsService.radioGroup, 'voiceRepeat', on);
  Duration get voiceRepeatCooldown => _cooldown('voiceRepeatDelay');
  Future<void> setVoiceRepeatCooldown(int seconds) => setSettingValue(SettingsService.radioGroup, 'voiceRepeatDelay', '$seconds');
  Duration get voiceRepeatDelay => voiceRepeat ? voiceRepeatCooldown : Duration.zero;

  /// The switch, once set. Until then a stored delay is the switch, the way
  /// one picker was both: any delay repeats, and 0 does not.
  bool _repeats(String key, String delayKey) {
    final on = settingValue(SettingsService.radioGroup, key);
    if (on is bool) return on;
    return (int.tryParse('${settingValue(SettingsService.radioGroup, delayKey)}') ?? 0) > 0;
  }

  /// One of [keyerRepeatCooldowns], the default for anything else stored.
  Duration _cooldown(String key) {
    final seconds = int.tryParse('${settingValue(SettingsService.radioGroup, key)}');
    return Duration(seconds: seconds != null && keyerRepeatCooldowns.contains('$seconds') ? seconds : _defaultCooldown);
  }
}
