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
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _uuidGenerator = Uuid();

class SettingsService extends ChangeNotifier implements SyncSettings {
  static const _themeModeKey = 'themeMode';
  static const _qrzUsernameKey = 'qrzUsername';
  static const _qrzPasswordKey = 'qrzPassword';
  static const _operatorCallKey = 'operatorCall';
  static const _syncEnabledKey = 'syncEnabled';
  static const _syncDeviceKeyKey = 'syncDeviceKey';
  static const _syncStateKey = 'syncState';
  static const _developerModeKey = 'developerMode';
  static const _localeKey = 'locale';
  static const _fontScaleKey = 'fontScale';
  static const _secondaryControlsOrderKey = 'secondaryControlsOrder';
  static const _hiddenSecondaryControlsKey = 'hiddenSecondaryControls';
  static const _showRSTFieldsKey = 'showRSTFields';
  static const _showStateFieldKey = 'showStateField';
  static const _showGridFieldKey = 'showGridField';
  static const _showDeletedQSOsKey = 'showDeletedQSOs';
  static const _showQsoNumbersKey = 'showQsoNumbers';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  SharedPreferences get prefs => _prefs;

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

  @override
  bool get developerMode => _prefs.getBool(_developerModeKey) ?? false;

  @override
  Future<void> setDeveloperMode(bool enabled) async {
    await _prefs.setBool(_developerModeKey, enabled);
    notifyListeners();
  }

  @override
  bool get enabled => syncEnabled;

  @override
  Map<String, dynamic> get state => syncState;

  @override
  Future<void> setState(Map<String, dynamic> state) => setSyncState(state);

  String get locale => _prefs.getString(_localeKey) ?? 'en';

  Future<void> setLocale(String localeCode) async {
    await _prefs.setString(_localeKey, localeCode);
    notifyListeners();
  }

  FontScale get fontScale {
    final value = _prefs.getString(_fontScaleKey);
    return FontScale.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FontScale.normal,
    );
  }

  Future<void> setFontScale(FontScale scale) async {
    await _prefs.setString(_fontScaleKey, scale.name);
    notifyListeners();
  }

  Future<void> increaseFontScale() async {
    final current = fontScale;
    final index = current.index;
    if (index < FontScale.values.length - 1) {
      await setFontScale(FontScale.values[index + 1]);
    }
  }

  Future<void> decreaseFontScale() async {
    final current = fontScale;
    final index = current.index;
    if (index > 0) {
      await setFontScale(FontScale.values[index - 1]);
    }
  }

  /// The user's preferred order for the logging panel's secondary control
  /// chips (Time, Radio, activity-contributed ones, More), by key. Missing
  /// keys (a newly-installed extension, or before this was ever set) fall
  /// back to whatever default order the panel itself uses.
  List<String> get secondaryControlsOrder => _prefs.getStringList(_secondaryControlsOrderKey) ?? const [];

  Future<void> setSecondaryControlsOrder(List<String> order) async {
    await _prefs.setStringList(_secondaryControlsOrderKey, order);
    notifyListeners();
  }

  /// Control keys hidden from the secondary control row. Time and Radio
  /// can't be hidden — the panel itself enforces that, this is just storage.
  Set<String> get hiddenSecondaryControls => _prefs.getStringList(_hiddenSecondaryControlsKey)?.toSet() ?? const {};

  Future<void> setHiddenSecondaryControls(Set<String> hidden) async {
    await _prefs.setStringList(_hiddenSecondaryControlsKey, hidden.toList());
    notifyListeners();
  }

  /// Logging view "..." menu toggles (ham2k/app-halo-dist#1).
  bool get showRSTFields => _prefs.getBool(_showRSTFieldsKey) ?? true;

  Future<void> setShowRSTFields(bool value) async {
    await _prefs.setBool(_showRSTFieldsKey, value);
    notifyListeners();
  }

  bool get showStateField => _prefs.getBool(_showStateFieldKey) ?? false;

  Future<void> setShowStateField(bool value) async {
    await _prefs.setBool(_showStateFieldKey, value);
    notifyListeners();
  }

  bool get showGridField => _prefs.getBool(_showGridFieldKey) ?? false;

  Future<void> setShowGridField(bool value) async {
    await _prefs.setBool(_showGridFieldKey, value);
    notifyListeners();
  }

  /// Off by default — deleted QSOs are hidden from the list unless the user
  /// opts in, matching `QsoRepository.watchForOperation`'s previous
  /// hardcoded behavior of always excluding them.
  bool get showDeletedQSOs => _prefs.getBool(_showDeletedQSOsKey) ?? false;

  Future<void> setShowDeletedQSOs(bool value) async {
    await _prefs.setBool(_showDeletedQSOsKey, value);
    notifyListeners();
  }

  bool get showQsoNumbers => _prefs.getBool(_showQsoNumbersKey) ?? true;

  Future<void> setShowQsoNumbers(bool value) async {
    await _prefs.setBool(_showQsoNumbersKey, value);
    notifyListeners();
  }
}

enum FontScale {
  smallest(0.70, 'Smallest'),
  smaller(0.85, 'Smaller'),
  normal(1.00, 'Normal'),
  larger(1.20, 'Larger'),
  largest(1.40, 'Largest');

  final double scaleFactor;
  final String label;

  const FontScale(this.scaleFactor, this.label);
}
