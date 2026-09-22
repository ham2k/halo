// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
import 'settings_service.dart';

/// Preferences are keyed by the shared export type, never by extension or log.
extension ExportPreferences on SettingsService {
  Map<String, dynamic> exportTypeOverrides(String type) =>
      Map<String, dynamic>.from((settingValue(SettingsService.exportsGroup, 'type:$type') as Map?) ?? const {});

  Map<String, dynamic> get exportGlobalSettings => {'includePrivateData': includePrivateData, ...exportTypeOverrides('default')};

  Future<void> setExportTypeSetting(String type, String key, dynamic value) =>
      setSettingValue(SettingsService.exportsGroup, 'type:$type', {...exportTypeOverrides(type), key: value});
}
