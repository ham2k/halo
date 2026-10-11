// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's arrangement, kept per view: the Chasing view's entry
// row, QSO list and pill row are set up apart from every operation's.

import 'settings_service.dart';

/// Which logging panel a setting is read for. What its entry row and list
/// show, and which pills in what order, belong to the scope; everything
/// about HOW the operator logs (default reports, Leftie Mode, the numbers
/// row) is shared.
enum LoggingScope { operation, chase }

/// The Chasing view's own logging settings group.
const chaseLoggingGroup = 'chaseLogging';

/// The display settings each [LoggingScope] keeps for itself.
const loggingScopedKeys = {'showRSTFields', 'showStateField', 'showGridField', 'showQsoNumbers', 'showDeletedQSOs'};

/// Where [key] is stored for [scope].
String loggingGroupFor(String key, LoggingScope scope) =>
    scope == LoggingScope.chase && loggingScopedKeys.contains(key) ? chaseLoggingGroup : SettingsService.loggingGroup;

extension LoggingScopeSettings on SettingsService {
  /// One of [loggingScopedKeys] as [scope] has it, with the operation's
  /// defaults.
  bool loggingDisplay(String key, LoggingScope scope) =>
      (settingValue(loggingGroupFor(key, scope), key) as bool?) ?? (key == 'showRSTFields' || key == 'showQsoNumbers');

  /// [SettingsService.secondaryControlsOrder] as [scope] has it. The
  /// operation's stays where it always was; the Chasing view's lives in its
  /// own group.
  List<String> secondaryControlsOrderFor(LoggingScope scope) => switch (scope) {
    LoggingScope.operation => secondaryControlsOrder,
    LoggingScope.chase => [...((settingValue(chaseLoggingGroup, 'secondaryControlsOrder') as List?) ?? const []).whereType<String>()],
  };

  Set<String> hiddenSecondaryControlsFor(LoggingScope scope) => switch (scope) {
    LoggingScope.operation => hiddenSecondaryControls,
    LoggingScope.chase => {...((settingValue(chaseLoggingGroup, 'hiddenSecondaryControls') as List?) ?? const []).whereType<String>()},
  };

  Future<void> setSecondaryControlsOrderFor(LoggingScope scope, List<String> order) => switch (scope) {
    LoggingScope.operation => setSecondaryControlsOrder(order),
    LoggingScope.chase => setSettingValue(chaseLoggingGroup, 'secondaryControlsOrder', order),
  };

  Future<void> setHiddenSecondaryControlsFor(LoggingScope scope, Set<String> hidden) => switch (scope) {
    LoggingScope.operation => setHiddenSecondaryControls(hidden),
    LoggingScope.chase => setSettingValue(chaseLoggingGroup, 'hiddenSecondaryControls', hidden.toList()),
  };
}
