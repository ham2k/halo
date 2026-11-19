// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The station's audio mixing, as settings — beside the audio engine rather
// than in settings_service.dart, which is over its size budget.

import '../cat/computer_voice_keyer.dart' show voiceDeviceFromConfig;
import '../settings_service.dart';

/// What each radio heard in HaLo is mixed at (docs/design/audio.md), and
/// the station's microphone and output in the older form, `{id, name}` as
/// the voice keyer stores a device.
extension RadioAudioSettings on SettingsService {
  static const _microphoneKey = 'microphone';
  static const _outputKey = 'output';
  static const _volumeKey = 'volume';
  static const _levelsKey = 'levels';

  /// The microphone and output as builds before the operator's picks kept
  /// them (CatService.operatorMicrophone, operatorHeadphones): read once, to
  /// move them there, and left for an older build to read.
  ({String? id, String? name})? get stationMicrophone => voiceDeviceFromConfig(settingValue(SettingsService.radioGroup, _microphoneKey));
  ({String? id, String? name})? get stationOutput => voiceDeviceFromConfig(settingValue(SettingsService.radioGroup, _outputKey));

  /// The mix's overall volume, 0 to 1.
  double get stationVolume => _unit(settingValue(SettingsService.radioGroup, _volumeKey));

  Future<void> setStationVolume(double volume) => setSettingValue(SettingsService.radioGroup, _volumeKey, volume.clamp(0.0, 1.0));

  /// What [radio] is mixed at, 0 to 1, before the overall volume.
  double radioLevel(String radio) => switch (settingValue(SettingsService.radioGroup, _levelsKey)) {
    final Map<dynamic, dynamic> levels => _unit(levels[radio]),
    _ => 1.0,
  };

  Future<void> setRadioLevel(String radio, double level) {
    final levels = switch (settingValue(SettingsService.radioGroup, _levelsKey)) {
      final Map<dynamic, dynamic> stored => {for (final MapEntry(:key, :value) in stored.entries) '$key': value},
      _ => <String, dynamic>{},
    };
    return setSettingValue(SettingsService.radioGroup, _levelsKey, {...levels, radio: level.clamp(0.0, 1.0)});
  }

  static double _unit(Object? value) => value is num ? value.toDouble().clamp(0.0, 1.0) : 1.0;
}
