// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'settings_service.dart';

/// The Map tab's preferences beyond its style ([SettingsService.mapStyle]).
extension MapPreferences on SettingsService {
  static const _showCallsignsKey = 'mapShowCallsigns';

  /// Whether the Map tab draws each contact as a pill holding its callsign
  /// rather than a plain circle (map_panel.dart).
  bool get mapShowCallsigns => (settingValue(SettingsService.generalGroup, _showCallsignsKey) as bool?) ?? false;

  Future<void> setMapShowCallsigns(bool value) => setSettingValue(SettingsService.generalGroup, _showCallsignsKey, value);
}
