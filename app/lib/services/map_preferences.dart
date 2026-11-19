// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'settings_service.dart';

/// Which view's map pane a per-pane map preference belongs to: each keeps
/// its own, as each view's logging panel keeps its own display settings
/// (LoggingScope).
enum MapScope { operation, chase, logs }

/// The Map tab's preferences beyond its style ([SettingsService.mapStyle]),
/// and the Operation Postcard's grayline.
extension MapPreferences on SettingsService {
  static const _showCallsignsKey = 'mapShowCallsigns';
  static const _showGraylineKey = 'mapShowGrayline';
  static const _postcardGraylineKey = 'postcardGrayline';
  static const _centerOnQsoKey = 'mapCenterOnQso';

  /// Whether the Map tab draws each contact as a pill holding its callsign
  /// rather than a plain circle (map_panel.dart).
  bool get mapShowCallsigns => (settingValue(SettingsService.generalGroup, _showCallsignsKey) as bool?) ?? false;

  Future<void> setMapShowCallsigns(bool value) => setSettingValue(SettingsService.generalGroup, _showCallsignsKey, value);

  /// Whether the Map tab shades the night side of the Earth (map_grayline.dart).
  bool get mapShowGrayline => (settingValue(SettingsService.generalGroup, _showGraylineKey) as bool?) ?? false;

  Future<void> setMapShowGrayline(bool value) => setSettingValue(SettingsService.generalGroup, _showGraylineKey, value);

  /// Whether [scope]'s map pane follows its current QSO — the one in the
  /// logging panel, or the Logs view's selection (map_highlight_camera.dart).
  /// Off, the camera moves only when the operator moves it: not even a
  /// contact logged reframes the log.
  bool mapCenterOnQso(MapScope scope) => (settingValue(SettingsService.generalGroup, '$_centerOnQsoKey.${scope.name}') as bool?) ?? true;

  /// Stores only the option turned off, so the default stays the default.
  Future<void> setMapCenterOnQso(MapScope scope, bool value) =>
      setSettingValue(SettingsService.generalGroup, '$_centerOnQsoKey.${scope.name}', value ? null : false);

  /// Whether the Operation Postcard's map shades the night side of the Earth
  /// — its own choice, as its style is, and not the Map tab's.
  bool get postcardGrayline => (settingValue(SettingsService.generalGroup, _postcardGraylineKey) as bool?) ?? false;

  /// Stores only a grayline turned on, as [SettingsService.setPostcardBandLegend]
  /// stores only a legend turned off.
  Future<void> setPostcardGrayline(bool show) => setSettingValue(SettingsService.generalGroup, _postcardGraylineKey, show ? true : null);
}
