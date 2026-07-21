// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Small app-wide preferences that need to survive a restart: theme mode,
// callsign profiles, and sync state — backed by SharedPreferences (plain,
// unencrypted, fine for non-secret preferences). The one secret here, the
// sync device key (the bearer credential for the account's synced log),
// lives in the platform keychain via FlutterSecureStorage instead; QRZ
// credentials live in secure storage too, handled by ExtensionService's
// account storage.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _uuidGenerator = Uuid();

/// The theme mode the light/dark toggle (⌘⇧D) switches to: always the opposite
/// of what's currently on screen, resolving [ThemeMode.system] against the
/// current [platformBrightness] so the first press flips what the user sees.
ThemeMode toggledThemeMode(ThemeMode current, Brightness platformBrightness) {
  final showingDark =
      current == ThemeMode.dark || (current == ThemeMode.system && platformBrightness == Brightness.dark);
  return showingDark ? ThemeMode.light : ThemeMode.dark;
}

class SettingsService extends ChangeNotifier implements SyncSettings {
  static const _themeModeKey = 'themeMode';
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
  static const _experimentsKey = 'experiments';
  static const _layoutKey = 'layout';
  static const _lastSeenReleaseVersionKey = 'lastSeenReleaseVersion';
  static const _shorebirdTrackKey = 'shorebirdTrack';

  /// The Shorebird code-push tracks this build can follow, riskiest first
  /// (docs/releases.md §4.3). `stable` is the default and what everyone gets;
  /// the others are opt-in via Developer Settings and only reach devices that
  /// select them here.
  static const shorebirdTracks = ['bleeding-edge', 'unstable', 'stable'];

  final SharedPreferences _prefs;

  /// The sync device key is the de-facto bearer credential for the account's
  /// synced log, so it lives in the platform keychain, not SharedPreferences.
  ///
  /// It must stay PER-DEVICE: these options never set `synchronizable`, so the
  /// key is device-local (`kSecAttrSynchronizable` defaults to false) and never
  /// reaches iCloud Keychain. Do NOT make it synchronizable — it's a
  /// per-install identifier (LoFi's `syncUniqueId`), and syncing it would make
  /// two of the user's devices present as the same sync client. Account-level
  /// logins that ARE the same everywhere (e.g. QRZ) opt into syncing through
  /// the extension account hook's `synchronizable` flag instead — see
  /// ExtensionService.
  final FlutterSecureStorage _secureStorage;

  String? _cachedDeviceKey;

  SettingsService(this._prefs, {FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            // Release uses the data-protection keychain (no consent prompt);
            // debug uses the file keychain so ad-hoc-signed local builds work.
            // See ExtensionService._secureStorage for the full rationale.
            mOptions: MacOsOptions(usesDataProtectionKeychain: kReleaseMode, accountName: 'Ham2K Logger'),
            iOptions: IOSOptions(accountName: 'Ham2K Logger'),
          );

  SharedPreferences get prefs => _prefs;

  static Future<SettingsService> load() async {
    return SettingsService(await SharedPreferences.getInstance());
  }

  /// Per-extension enable/disable overrides ({key: bool}), consulted against
  /// each extension's `enabledByDefault` from the build index (see
  /// ExtensionService.isExtensionEnabled). Deliberately a TOP-LEVEL pref,
  /// outside the `settings.*` group system: it is app infrastructure, not a
  /// setting — and being top-level keeps it out of the extension-facing
  /// getSettings view ([extensionSettingsGroups] only scans group keys).
  static const _extensionOverridesKey = 'extensionOverrides';

  Map<String, bool> get extensionOverrides =>
      {for (final e in _jsonMapPref(_extensionOverridesKey).entries) if (e.value is bool) e.key: e.value as bool};

  Future<void> setExtensionOverrides(Map<String, bool> overrides) async {
    await _prefs.setString(_extensionOverridesKey, jsonEncode(overrides));
    notifyListeners();
  }

  /// When each currently-disabled extension was disabled ({key: epochMillis}).
  /// A disabled extension's downloaded data (data files) is KEPT so a
  /// re-enable is instant; only after it's been disabled for the grace
  /// period does DataFileManager purge that data. Stamped/cleared by
  /// ExtensionService as extensions toggle; an entry vanishes on re-enable.
  static const _extensionDisabledSinceKey = 'extensionDisabledSince';

  Map<String, int> get extensionDisabledSince =>
      {for (final e in _jsonMapPref(_extensionDisabledSinceKey).entries) if (e.value is int) e.key: e.value as int};

  Future<void> setExtensionDisabledSince(Map<String, int> disabledSince) async {
    await _prefs.setString(_extensionDisabledSinceKey, jsonEncode(disabledSince));
    notifyListeners();
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
  /// before first use — call [ensureSyncDeviceKey] at boot.
  Future<String> ensureSyncDeviceKey() async {
    if (_cachedDeviceKey != null) return _cachedDeviceKey!;

    final fromSecure = await _secureStorage.read(key: _syncDeviceKeyKey);
    if (fromSecure != null && fromSecure.isNotEmpty) {
      return _cachedDeviceKey = fromSecure;
    }

    final key = _uuidGenerator.v4();
    await _secureStorage.write(key: _syncDeviceKeyKey, value: key);
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

  /// Per-experiment state, keyed by the experiment key from experiments.yaml:
  /// `{enabled: bool, firstEnabledAtMillis: int, lastDisabledAtMillis: int}`.
  /// Entries whose definition has since left the catalog are deliberately
  /// KEPT (never pruned) — a returning experiment picks its old state up.
  Map<String, dynamic> get experimentStates => _jsonMapPref(_experimentsKey);

  bool experimentEnabled(String key) {
    final state = experimentStates[key];
    return state is Map && state['enabled'] == true;
  }

  /// The number of [keys] currently enabled — the Developer menu's count,
  /// computed against the CURRENT catalog so stale state for removed
  /// experiments doesn't inflate it. One state read, not one per key.
  int enabledExperimentCount(Iterable<String> keys) {
    final states = experimentStates;
    return keys.where((key) {
      final state = states[key];
      return state is Map && state['enabled'] == true;
    }).length;
  }

  Future<void> setExperimentEnabled(String key, bool enabled) async {
    final states = experimentStates;
    final entry = {...?(states[key] as Map?)?.cast<String, dynamic>()};
    entry['enabled'] = enabled;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (enabled) {
      entry['firstEnabledAtMillis'] ??= now;
    } else {
      entry['lastDisabledAtMillis'] = now;
    }
    await _prefs.setString(_experimentsKey, jsonEncode({...states, key: entry}));
    notifyListeners();
  }

  /// Which Shorebird patch track this device follows (docs/releases.md §4.3).
  /// Defaults to `stable`; an unrecognized stored value also falls back to
  /// `stable`, so a track that later disappears can't strand a device.
  String get shorebirdTrack {
    final stored = _prefs.getString(_shorebirdTrackKey);
    return shorebirdTracks.contains(stored) ? stored! : 'stable';
  }

  Future<void> setShorebirdTrack(String track) async {
    if (!shorebirdTracks.contains(track)) return;
    await _prefs.setString(_shorebirdTrackKey, track);
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

  Future<void> setLayoutDimension(String key, double value) => _setLayoutValue(key, value);

  /// A structured layout value (the dock-layout prototype's arrangement
  /// tree) riding in the same per-key layout map as the scalar dimensions.
  Map<String, dynamic>? layoutData(String key) {
    final value = (_layoutCache ??= _jsonMapPref(_layoutKey))[key];
    return value is Map<String, dynamic> ? value : null;
  }

  Future<void> setLayoutData(String key, Map<String, dynamic> value) => _setLayoutValue(key, value);

  /// The one writer of the layout map: cache first (build methods read the
  /// cache synchronously), then persist the whole map, then notify.
  Future<void> _setLayoutValue(String key, Object value) async {
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

  /// The mobile "numbers row" — a bar of digit keys the logging panel floats
  /// above the on-screen keyboard while a logging field has focus (issue
  /// #27). Off by default (opt-in), matching app-polo's `showNumbersRow`.
  /// The two settings below only take effect while this is on: the extra
  /// contextual key ("/" while composing a callsign, "." in numeric fields,
  /// on by default) and haptic feedback on each key press (on by default).
  bool get showNumbersRow => _loggingBool('showNumbersRow', false);
  bool get showExtraInNumbersRow => _loggingBool('showExtraInNumbersRow', true);
  bool get vibrateNumbersRow => _loggingBool('vibrateNumbersRow', true);

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

/// Declared in ascending scale order — [SettingsService.increaseFontScale] and
/// [SettingsService.decreaseFontScale] step by `index`, so the order IS the
/// ordering.
///
/// The four outermost levels are [selectable] `false`: reachable only with the
/// keyboard shortcuts, and deliberately absent from the Settings picker. They
/// exist for the rare setup that needs more range (a far-away shack display, a
/// user who needs very large text) without cluttering the everyday list of
/// five. When one is in effect the picker annotates the nearest selectable
/// entry instead — see [nearestSelectable] and `core_settings_groups.dart`.
enum FontScale {
  smallestMinusMinus(0.50, 'Smallest--', selectable: false),
  smallestMinus(0.60, 'Smallest-', selectable: false),
  smallest(0.70, 'Smallest'),
  smaller(0.85, 'Smaller'),
  normal(1.00, 'Normal'),
  larger(1.20, 'Larger'),
  largest(1.40, 'Largest'),
  largestPlus(1.65, 'Largest+', selectable: false),
  largestPlusPlus(1.90, 'Largest++', selectable: false);

  /// The uniform UI zoom factor. Consumed in exactly ONE place — `main.dart`'s
  /// `MaterialApp.builder`, which feeds it to `UiScale` to scale the entire
  /// interface at the root. Do NOT multiply widget/theme dimensions by this
  /// anywhere else: everything below `UiScale` already scales, so a second
  /// multiply double-scales. See docs/design/ui-scaling.md.
  final double scaleFactor;
  final String label;

  /// Whether the Settings picker offers this level. False for the four
  /// shortcut-only extremes.
  final bool selectable;

  const FontScale(this.scaleFactor, this.label, {this.selectable = true});

  /// The levels the Settings picker lists, in order.
  static List<FontScale> get selectableValues => values.where((s) => s.selectable).toList();

  /// The selectable level this one is annotated against: itself when
  /// selectable, otherwise the nearest selectable level in the direction of
  /// Normal (so 1.90 and 1.65 both answer `largest`, 0.50 and 0.60 both answer
  /// `smallest`).
  FontScale get nearestSelectable {
    if (selectable) return this;
    return scaleFactor > normal.scaleFactor ? selectableValues.last : selectableValues.first;
  }
}

/// The dotted keys for [SettingsService.layoutDimension] /
/// [SettingsService.setLayoutDimension] — constants so a divider's read and
/// write can't typo apart (a forked key would silently reset the pane width
/// on every launch, and only across restarts).
abstract final class LayoutKeys {
  static const homeLeftColumn = 'home.leftColumn';
  static const operationLeftColumn = 'operation.leftColumn';
  static const operationDock = 'operation.dock';
}
