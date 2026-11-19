// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'settings_service.dart';

/// App-wide map choices, read only as the settings a map pane with none of
/// its own starts from (map_pane_config.dart), and the Operation Postcard's
/// grayline.
extension MapPreferences on SettingsService {
  static const _showCallsignsKey = 'mapShowCallsigns';
  static const _showGraylineKey = 'mapShowGrayline';
  static const _postcardGraylineKey = 'postcardGrayline';

  bool get mapShowCallsigns => (settingValue(SettingsService.generalGroup, _showCallsignsKey) as bool?) ?? false;

  bool get mapShowGrayline => (settingValue(SettingsService.generalGroup, _showGraylineKey) as bool?) ?? false;

  /// Whether the Operation Postcard's map shades the night side of the Earth
  /// — its own choice, as its style is, and not the Map tab's.
  bool get postcardGrayline => (settingValue(SettingsService.generalGroup, _postcardGraylineKey) as bool?) ?? false;

  /// Stores only a grayline turned on, as [SettingsService.setPostcardBandLegend]
  /// stores only a legend turned off.
  Future<void> setPostcardGrayline(bool show) => setSettingValue(SettingsService.generalGroup, _postcardGraylineKey, show ? true : null);
}
