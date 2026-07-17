// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Small app-wide preferences that need to survive a restart: theme mode,
// callsign profiles, and sync state — backed by SharedPreferences (plain,
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
  static const _legacyOperatorCallKey = 'operatorCall';
  static const _profilesKey = 'profiles';
  static const _activeProfileKey = 'activeProfile';
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
  static const _layoutKey = 'layout';
  static const _lastSeenReleaseVersionKey = 'lastSeenReleaseVersion';

  final SharedPreferences _prefs;

  /// The sync device key is the de-facto bearer credential for the account's
  /// synced log, so it lives in the platform keychain, not SharedPreferences.
  final FlutterSecureStorage _secureStorage;

  String? _cachedDeviceKey;

  SettingsService(this._prefs, {FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false, accountName: 'Ham2K Logger'),
            iOptions: IOSOptions(accountName: 'Ham2K Logger'),
          );

  SharedPreferences get prefs => _prefs;

  static Future<SettingsService> load() async {
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings._migrateLegacyOperatorCall();
    await settings._migrateScalarPrefsToGroups();
    return settings;
  }

  // ---------------------------------------------------------------------
  // Declarative settings groups (docs: the FormRenderer element dialect is
  // the declaration schema — see app/lib/settings/settings_registry.dart).
  // Core settings are stored one JSON map per group under a `settings.`
  // prefix (mirroring the Tier 1 extension convention of
  // `settingsPanel.<panelKey>.<fieldKey>`), with typed getters below as
  // thin wrappers so hot-path consumers keep their existing API.

  static const generalGroup = 'general';
  static const loggingGroup = 'logging';
  static const privacyGroup = 'privacy';

  String _groupPrefsKey(String group) => 'settings.$group';

  Map<String, dynamic> settingsGroup(String group) => _jsonMapPref(_groupPrefsKey(group));

  dynamic settingValue(String group, String key) => settingsGroup(group)[key];

  Future<void> setSettingValue(String group, String key, dynamic value) async {
    await _prefs.setString(_groupPrefsKey(group), jsonEncode({...settingsGroup(group), key: value}));
    notifyListeners();
  }

  /// Batch form of [setSettingValue]: one write, one notify.
  Future<void> updateSettingsGroup(String group, Map<String, dynamic> changes) async {
    if (changes.isEmpty) return;
    await _prefs.setString(_groupPrefsKey(group), jsonEncode({...settingsGroup(group), ...changes}));
    notifyListeners();
  }

  /// Every extension-owned settings group (`settings.extension_<key>`),
  /// keyed by the bare `extension_<key>` group name — for the extension
  /// bridge's getSettings read view.
  Map<String, Map<String, dynamic>> extensionSettingsGroups() {
    const prefix = 'settings.extension_';
    return {
      for (final prefsKey in _prefs.getKeys())
        if (prefsKey.startsWith(prefix)) prefsKey.substring('settings.'.length): _jsonMapPref(prefsKey),
    };
  }

  /// One-time migration: these all began life as individual scalar prefs;
  /// they now live in the per-group JSON maps. Existing group values win
  /// (the migration ran before, or a newer build wrote the group).
  Future<void> _migrateScalarPrefsToGroups() async {
    const groupedKeys = {
      generalGroup: [_themeModeKey, _localeKey, _fontScaleKey, _distanceUnitsKey],
      loggingGroup: [_showRSTFieldsKey, _showStateFieldKey, _showGridFieldKey, _showDeletedQSOsKey, _showQsoNumbersKey],
    };
    for (final entry in groupedKeys.entries) {
      final migrated = <String, dynamic>{};
      for (final key in entry.value) {
        if (!_prefs.containsKey(key)) continue;
        migrated[key] = _prefs.get(key);
        await _prefs.remove(key);
      }
      if (migrated.isEmpty) continue;
      await _prefs.setString(
        _groupPrefsKey(entry.key),
        jsonEncode({...migrated, ...settingsGroup(entry.key)}),
      );
    }
  }

  ThemeMode get themeMode {
    switch (settingValue(generalGroup, _themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) => setSettingValue(generalGroup, _themeModeKey, mode.name);

  /// The `kPublicVersion` the user last dismissed the startup release
  /// overlay for (release_overlay.dart) — the overlay shows again once
  /// `kPublicVersion` no longer matches this.
  String get lastSeenReleaseVersion => _prefs.getString(_lastSeenReleaseVersionKey) ?? '';

  Future<void> setLastSeenReleaseVersion(String version) async {
    await _prefs.setString(_lastSeenReleaseVersionKey, version);
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

  /// Callsign profiles, keyed by profile id — one JSON map under a single
  /// prefs key, like [syncState]. Today there's only the [defaultProfileId]
  /// profile holding the operator's callsign (a global default, distinct
  /// from `Operation.stationCall`, which is per-operation and may differ,
  /// e.g. a club callsign); multi-profile support is planned, so consumers
  /// read profile data through [activeProfile] rather than a scalar pref.
  static const defaultProfileId = 'default';

  Map<String, dynamic> get _profilesData => _jsonMapPref(_profilesKey);

  /// Which profile is active — the default profile until multi-profile
  /// support lands.
  String get activeProfileId => _prefs.getString(_activeProfileKey) ?? defaultProfileId;

  Profile get activeProfile => _profile(activeProfileId);

  Profile _profile(String id) {
    final data = _profilesData[id];
    return Profile(id, data is Map ? data.cast<String, dynamic>() : const {});
  }

  /// Whether the default profile has EVER had a callsign set — the
  /// onboarding trigger. Distinct from `activeProfile.operatorCall.isEmpty`:
  /// an explicitly-empty '' (the user skipped onboarding) counts as
  /// defined, so onboarding only shows while the key has never been
  /// written at all.
  bool get defaultProfileCallsignDefined {
    final profile = _profilesData[defaultProfileId];
    return profile is Map && profile.containsKey('operatorCall');
  }

  Future<void> setProfileOperatorCall(String profileId, String call) async {
    await _prefs.setString(
      _profilesKey,
      jsonEncode({
        ..._profilesData,
        profileId: {..._profile(profileId).data, 'operatorCall': call.trim().toUpperCase()},
      }),
    );
    notifyListeners();
  }

  /// One-time migration: earlier builds kept the operator callsign as a
  /// scalar pref; it now lives in the default profile. An EMPTY legacy
  /// value still counts as answered — it migrates to a defined-empty
  /// profile key, so an upgrading user isn't greeted with first-run
  /// onboarding (see [defaultProfileCallsignDefined]).
  Future<void> _migrateLegacyOperatorCall() async {
    final legacy = _prefs.getString(_legacyOperatorCallKey);
    if (legacy == null) return;
    if (!defaultProfileCallsignDefined) {
      await setProfileOperatorCall(defaultProfileId, legacy);
    }
    await _prefs.remove(_legacyOperatorCallKey);
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

  /// A JSON map stored under one prefs key. Corrupt or missing data reads
  /// as empty — callers own their defaults.
  Map<String, dynamic> _jsonMapPref(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return const {};
    }
  }

  /// Free-form sync bookkeeping (last-synced account uuid, server-tunable
  /// overrides) — see the design note in DESIGN.md §6: this is a handful of
  /// scalars, not per-row data, so it lives here rather than in a drift
  /// table.
  Map<String, dynamic> get syncState => _jsonMapPref(_syncStateKey);

  Future<void> setSyncState(Map<String, dynamic> state) async {
    await _prefs.setString(_syncStateKey, jsonEncode(state));
    notifyListeners();
  }

  /// The Spots Panel's persisted band/mode/age/sources/continents/sort/
  /// group filters — device-wide, like [syncState], for the same reason:
  /// a handful of viewing-preference scalars, not per-row data.
  Map<String, dynamic> get spottingFilters => _jsonMapPref(_spottingFiltersKey);

  Future<void> setSpottingFilters(Map<String, dynamic> filters) async {
    await _prefs.setString(_spottingFiltersKey, jsonEncode(filters));
    notifyListeners();
  }

  /// User-dragged pane widths (docs/design/layouts.md), keyed by
  /// [LayoutKeys] — one JSON map under a single prefs key, like
  /// [spottingFilters]. Callers own the defaults; a missing key returns
  /// null. Cached because layouts read this from build methods that rerun
  /// on every window-resize frame; only [setLayoutDimension] changes it.
  double? layoutDimension(String key) {
    final value = (_layoutCache ??= _jsonMapPref(_layoutKey))[key];
    return value is num ? value.toDouble() : null;
  }

  Future<void> setLayoutDimension(String key, double value) async {
    final updated = {...(_layoutCache ??= _jsonMapPref(_layoutKey)), key: value};
    _layoutCache = updated;
    await _prefs.setString(_layoutKey, jsonEncode(updated));
    notifyListeners();
  }

  Map<String, dynamic>? _layoutCache;

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

  String get locale => (settingValue(generalGroup, _localeKey) as String?) ?? 'en';

  Future<void> setLocale(String localeCode) => setSettingValue(generalGroup, _localeKey, localeCode);

  FontScale get fontScale {
    final value = settingValue(generalGroup, _fontScaleKey);
    return FontScale.values.firstWhere((e) => e.name == value, orElse: () => FontScale.normal);
  }

  Future<void> setFontScale(FontScale scale) => setSettingValue(generalGroup, _fontScaleKey, scale.name);

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

  bool _loggingBool(String key, bool fallback) => (settingValue(loggingGroup, key) as bool?) ?? fallback;

  /// Logging view "..." menu toggles (ham2k/app-halo-dist#1).
  bool get showRSTFields => _loggingBool(_showRSTFieldsKey, true);

  Future<void> setShowRSTFields(bool value) => setSettingValue(loggingGroup, _showRSTFieldsKey, value);

  bool get showStateField => _loggingBool(_showStateFieldKey, false);

  Future<void> setShowStateField(bool value) => setSettingValue(loggingGroup, _showStateFieldKey, value);

  bool get showGridField => _loggingBool(_showGridFieldKey, false);

  Future<void> setShowGridField(bool value) => setSettingValue(loggingGroup, _showGridFieldKey, value);

  /// Off by default — deleted QSOs are hidden from the list unless the user
  /// opts in, matching `QsoRepository.watchForOperation`'s previous
  /// hardcoded behavior of always excluding them.
  bool get showDeletedQSOs => _loggingBool(_showDeletedQSOsKey, false);

  Future<void> setShowDeletedQSOs(bool value) => setSettingValue(loggingGroup, _showDeletedQSOsKey, value);

  bool get showQsoNumbers => _loggingBool(_showQsoNumbersKey, true);

  Future<void> setShowQsoNumbers(bool value) => setSettingValue(loggingGroup, _showQsoNumbersKey, value);

  // New logging settings, defaults matching app-polo. Declared in the
  // settings registry and persisted here, but NOT yet consumed by the
  // logging UI — wiring the behavior is follow-up work per setting.
  bool get leftieMode => _loggingBool('leftieMode', false);
  bool get fieldsOnTop => _loggingBool('fieldsOnTop', false);
  bool get showBearing => _loggingBool('showBearing', false);
  bool get switchSentRcvd => _loggingBool('switchSentRcvd', false);
  bool get jumpAfterRST => _loggingBool('jumpAfterRST', false);

  /// Which contacts get a country flag next to them.
  DxFlags get dxFlags {
    final value = settingValue(loggingGroup, 'dxFlags');
    return DxFlags.values.firstWhere((e) => e.name == value, orElse: () => DxFlags.dx);
  }

  List<String> _loggingList(String key, List<String> fallback) {
    final value = settingValue(loggingGroup, key);
    return value is List ? value.whereType<String>().toList() : fallback;
  }

  static const defaultBands = ['80m', '40m', '30m', '20m', '17m', '15m', '12m', '10m', '6m', '2m'];
  static const defaultModes = ['SSB', 'CW', 'FT8', 'FT4', 'FM'];

  List<String> get enabledBands => _loggingList('bands', defaultBands);
  List<String> get enabledModes => _loggingList('modes', defaultModes);

  /// Privacy consents, both opt-in (default false). Same keys as app-polo
  /// (`consentAppData`/`consentOpData`) for cross-app parity. Nothing in the
  /// OSS app consumes them yet — MetricsService is a no-op — but
  /// distribution builds gate their telemetry on these.
  bool get consentAppData => (settingValue(privacyGroup, 'consentAppData') as bool?) ?? false;
  bool get consentOpData => (settingValue(privacyGroup, 'consentOpData') as bool?) ?? false;

  /// Distances (the Map tab's popups) in km or miles. Until the user picks
  /// one, defaults by operator callsign the way app-polo does: miles for the
  /// non-metric entities (US, UK, Liberia, Myanmar), km everywhere else.
  DistanceUnits get distanceUnits {
    final value = settingValue(generalGroup, _distanceUnitsKey);
    for (final unit in DistanceUnits.values) {
      if (unit.name == value) return unit;
    }
    // US prefixes K/N/W/AA–AL, UK G/M/2xx, Liberia EL/A8/5L/6Z/D5, Myanmar
    // XY/XZ — matching on the raw callsign since Dart has no callsign parser
    // (app-polo checks the parsed entityPrefix instead).
    final call = activeProfile.operatorCall;
    final miles = RegExp(r'^(A[A-L]|A8|[KNW]|G|M|2|EL|5L|6Z|D5|XY|XZ)').hasMatch(call);
    return miles ? DistanceUnits.miles : DistanceUnits.kilometers;
  }

  Future<void> setDistanceUnits(DistanceUnits units) => setSettingValue(generalGroup, _distanceUnitsKey, units.name);
}

/// One callsign profile from [SettingsService.activeProfile] — an id plus a
/// free-form data map, so profile fields can grow without schema churn.
class Profile {
  final String id;
  final Map<String, dynamic> data;

  const Profile(this.id, this.data);

  String get operatorCall => (data['operatorCall'] as String?) ?? '';
}

enum DistanceUnits { kilometers, miles }

/// Country flags on contacts: DX only (app-polo's default), everyone, or off.
enum DxFlags { dx, all, none }

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

/// The dotted keys for [SettingsService.layoutDimension] /
/// [SettingsService.setLayoutDimension] — constants so a divider's read and
/// write can't typo apart (a forked key would silently reset the pane width
/// on every launch, and only across restarts).
abstract final class LayoutKeys {
  static const homeLeftColumn = 'home.leftColumn';
  static const operationLeftColumn = 'operation.leftColumn';
  static const settingsLeftColumn = 'settings.leftColumn';
}
