// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Small app-wide preferences that need to survive a restart: theme mode and
// QRZ.com credentials. Backed by SharedPreferences — plain, unencrypted
// storage, same caveat as ExtensionHost's in-memory KV store had ("platform
// keychain when settings become persistent"): fine for a dev-stage app, but
// the QRZ password deserves real secure storage before this ships for real.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const _themeModeKey = 'themeMode';
  static const _qrzUsernameKey = 'qrzUsername';
  static const _qrzPasswordKey = 'qrzPassword';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  static Future<SettingsService> load() async => SettingsService(await SharedPreferences.getInstance());

  ThemeMode get themeMode {
    switch (_prefs.getString(_themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
    notifyListeners();
  }

  String get qrzUsername => _prefs.getString(_qrzUsernameKey) ?? '';
  String get qrzPassword => _prefs.getString(_qrzPasswordKey) ?? '';
  bool get hasQrzCredentials => qrzUsername.isNotEmpty && qrzPassword.isNotEmpty;

  Future<void> setQrzCredentials({required String username, required String password}) async {
    await _prefs.setString(_qrzUsernameKey, username);
    await _prefs.setString(_qrzPasswordKey, password);
    notifyListeners();
  }
}
