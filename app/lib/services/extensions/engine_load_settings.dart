// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The developer's view of the extension engine's headroom
// (`EngineLoadMonitor`). A mixin on SettingsService, like
// ExtensionStoreSettings, so readers keep the one service and the one
// ChangeNotifier.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

mixin EngineLoadSettings on ChangeNotifier {
  SharedPreferences get prefs;

  static const _showIdleMetricsKey = 'showIdleMetrics';

  /// Whether the status bar shows how idle the extension engine has been —
  /// a developer's read on whether extensions leave room for logging.
  /// Device-local.
  bool get showIdleMetrics => prefs.getBool(_showIdleMetricsKey) ?? false;

  Future<void> setShowIdleMetrics(bool show) async {
    await prefs.setBool(_showIdleMetricsKey, show);
    notifyListeners();
  }
}
