// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The station's audio mixing, as settings — beside the audio engine rather
// than in settings_service.dart, which is over its size budget.

import 'package:halo_audio/halo_audio.dart' show AudioDevice;

import '../cat/computer_voice_keyer.dart' show voiceDeviceFromConfig, voiceDeviceToConfig;
import '../settings_service.dart';

/// The station's microphone and output, and what each radio heard in HaLo
/// is mixed at (docs/design/audio.md): one for the station, since the
/// operator speaks into one microphone and hears every radio in one pair of
/// headphones. Devices are stored as the voice keyer stores its own,
/// `{id, name}`, and matched the same way.
extension RadioAudioSettings on SettingsService {
  static const _microphoneKey = 'microphone';
  static const _outputKey = 'output';
  static const _volumeKey = 'volume';
  static const _levelsKey = 'levels';

  /// Null for the system's default input.
  ({String? id, String? name})? get stationMicrophone => voiceDeviceFromConfig(settingValue(SettingsService.radioGroup, _microphoneKey));

  Future<void> setStationMicrophone(AudioDevice? device) =>
      setSettingValue(SettingsService.radioGroup, _microphoneKey, device == null ? null : voiceDeviceToConfig(device));

  /// Where every radio heard in HaLo plays: null for the system's default
  /// output.
  ({String? id, String? name})? get stationOutput => voiceDeviceFromConfig(settingValue(SettingsService.radioGroup, _outputKey));

  Future<void> setStationOutput(AudioDevice? device) =>
      setSettingValue(SettingsService.radioGroup, _outputKey, device == null ? null : voiceDeviceToConfig(device));

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
