// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_widgets/halo_widgets.dart' show ManualTimeHooks;

import 'settings_service.dart';

/// Manual time entry's one setting (docs/design/logging-fields.md § Manual
/// time entry), in the Logging group.
extension ManualTimeSettings on SettingsService {
  static const _key = 'manualTimeIncrement';

  /// How far manual time entry moves on after each logged contact, stored in
  /// whole minutes; zero leaves the time where it is.
  Duration get manualTimeIncrement {
    final minutes = settingValue(SettingsService.loggingGroup, _key);
    return minutes is int ? Duration(minutes: minutes) : ManualTimeHooks.defaultIncrement;
  }

  Future<void> setManualTimeIncrement(Duration value) => setSettingValue(SettingsService.loggingGroup, _key, value.inMinutes);
}
