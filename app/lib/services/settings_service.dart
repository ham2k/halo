// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Small app-wide preferences that need to survive a restart: theme mode,
// QRZ.com credentials, operator callsign, and sync state. Backed by
// SharedPreferences — plain, unencrypted storage, same caveat as
// ExtensionHost's in-memory KV store had ("platform keychain when settings
// become persistent"): fine for a dev-stage app, but the QRZ password
// deserves real secure storage before this ships for real.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _uuidGenerator = Uuid();

class SettingsService extends ChangeNotifier {
  static const _themeModeKey = 'themeMode';
  static const _qrzUsernameKey = 'qrzUsername';
  static const _qrzPasswordKey = 'qrzPassword';
  static const _operatorCallKey = 'operatorCall';
  static const _syncEnabledKey = 'syncEnabled';
  static const _syncDeviceKeyKey = 'syncDeviceKey';
  static const _syncStateKey = 'syncState';

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

  /// The operator's own callsign — a global default, distinct from
  /// `Operation.stationCall` (which is per-operation and may differ, e.g.
  /// a club callsign). Sync needs one identity to register the device's
  /// account under.
  String get operatorCall => _prefs.getString(_operatorCallKey) ?? '';

  Future<void> setOperatorCall(String call) async {
    await _prefs.setString(_operatorCallKey, call.trim().toUpperCase());
    notifyListeners();
  }

  /// Sync is opt-in — off until the user turns it on in Settings.
  bool get syncEnabled => _prefs.getBool(_syncEnabledKey) ?? false;

  Future<void> setSyncEnabled(bool enabled) async {
    await _prefs.setBool(_syncEnabledKey, enabled);
    notifyListeners();
  }

  /// A stable opaque per-install identifier for the LoFi sync server (the
  /// Flutter equivalent of app-polo's `DeviceInfo.syncUniqueId()`), generated
  /// once on first access and persisted forever after.
  String get syncDeviceKey {
    final existing = _prefs.getString(_syncDeviceKeyKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _uuidGenerator.v4();
    unawaited(_prefs.setString(_syncDeviceKeyKey, generated));
    return generated;
  }

  /// Free-form sync bookkeeping (last-synced account uuid, server-tunable
  /// overrides) — see the design note in DESIGN.md §6: this is a handful of
  /// scalars, not per-row data, so it lives here rather than in a drift
  /// table.
  Map<String, dynamic> get syncState {
    final raw = _prefs.getString(_syncStateKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return const {};
    }
  }

  Future<void> setSyncState(Map<String, dynamic> state) async {
    await _prefs.setString(_syncStateKey, jsonEncode(state));
    notifyListeners();
  }
}
