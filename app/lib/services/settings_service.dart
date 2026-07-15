// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Small app-wide preferences that need to survive a restart: theme mode,
// operator callsign, and sync state — backed by SharedPreferences (plain,
// unencrypted, fine for non-secret preferences). The one secret here, the
// sync device key (the bearer credential for the account's synced log),
// lives in the platform keychain via FlutterSecureStorage instead; QRZ
// credentials likewise moved to secure storage (migrated at boot in
// main.dart, then handled by ExtensionService's account storage).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const _distanceUnitsKey = 'distanceUnits';
  static const _spottingFiltersKey = 'spottingFilters';

  final SharedPreferences _prefs;

  /// The sync device key is the de-facto bearer credential for the account's
  /// synced log, so it lives in the platform keychain, not SharedPreferences.
  final FlutterSecureStorage _secureStorage;

  String? _cachedDeviceKey;

  SettingsService(this._prefs, {FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(usesDataProtectionKeychain: false, accountName: 'Ham2K Logger'),
              iOptions: IOSOptions(accountName: 'Ham2K Logger'),
            );

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
  /// once and persisted in the platform keychain forever after. Since it's
  /// the bearer credential for the account's synced log, it must be loaded
  /// (and migrated off any old SharedPreferences copy) before first use —
  /// call [ensureSyncDeviceKey] at boot.
  Future<String> ensureSyncDeviceKey() async {
    if (_cachedDeviceKey != null) return _cachedDeviceKey!;

    final fromSecure = await _secureStorage.read(key: _syncDeviceKeyKey);
    if (fromSecure != null && fromSecure.isNotEmpty) {
      return _cachedDeviceKey = fromSecure;
    }

    // One-time migration: earlier builds kept the key in SharedPreferences.
    final legacy = _prefs.getString(_syncDeviceKeyKey);
    final key = (legacy != null && legacy.isNotEmpty) ? legacy : _uuidGenerator.v4();
    await _secureStorage.write(key: _syncDeviceKeyKey, value: key);
    if (legacy != null) await _prefs.remove(_syncDeviceKeyKey);
    return _cachedDeviceKey = key;
  }

  /// The already-loaded device key, or null before [ensureSyncDeviceKey] has
  /// run — for display only (e.g. Settings → System Information).
  String? get syncDeviceKey => _cachedDeviceKey;

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

  /// The Spots Panel's persisted band/mode/age/sources/continents/sort/
  /// group filters — device-wide, like [syncState], for the same reason:
  /// a handful of viewing-preference scalars, not per-row data.
  Map<String, dynamic> get spottingFilters {
    final raw = _prefs.getString(_spottingFiltersKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return const {};
    }
  }

  Future<void> setSpottingFilters(Map<String, dynamic> filters) async {
    await _prefs.setString(_spottingFiltersKey, jsonEncode(filters));
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

  /// Distances (the Map tab's popups) in km or miles. Until the user picks
  /// one, defaults by operator callsign the way app-polo does: miles for the
  /// non-metric entities (US, UK, Liberia, Myanmar), km everywhere else.
  DistanceUnits get distanceUnits {
    final value = _prefs.getString(_distanceUnitsKey);
    for (final unit in DistanceUnits.values) {
      if (unit.name == value) return unit;
    }
    // US prefixes K/N/W/AA–AL, UK G/M/2xx, Liberia EL/A8/5L/6Z/D5, Myanmar
    // XY/XZ — matching on the raw callsign since Dart has no callsign parser
    // (app-polo checks the parsed entityPrefix instead).
    final call = operatorCall;
    final miles = RegExp(r'^(A[A-L]|A8|[KNW]|G|M|2|EL|5L|6Z|D5|XY|XZ)').hasMatch(call);
    return miles ? DistanceUnits.miles : DistanceUnits.kilometers;
  }

  Future<void> setDistanceUnits(DistanceUnits units) async {
    await _prefs.setString(_distanceUnitsKey, units.name);
    notifyListeners();
  }
}

enum DistanceUnits { kilometers, miles }

enum FontScale {
  smallest(0.70, 'Smallest'),
  smaller(0.85, 'Smaller'),
  normal(1.00, 'Normal'),
  larger(1.20, 'Larger'),
  largest(1.40, 'Largest');

  /// The uniform UI zoom factor. Consumed in exactly ONE place — `main.dart`'s
  /// `MaterialApp.builder`, which feeds it to `UiScale` to scale the entire
  /// interface at the root. Do NOT multiply widget/theme dimensions by this
  /// anywhere else: everything below `UiScale` already scales, so a second
  /// multiply double-scales. See docs/design/ui-scaling.md.
  final double scaleFactor;
  final String label;

  const FontScale(this.scaleFactor, this.label);
}
