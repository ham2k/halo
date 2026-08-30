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

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/user_agent.dart';
import 'error_reporting_service.dart';

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
  static const _extensionDevServerUrlKey = 'extensionDevServerUrl';
  static const _extensionDevServerEnabledKey = 'extensionDevServerEnabled';
  static const _automaticUpdateChecksKey = 'automaticUpdateChecks';
  static const _localeKey = 'locale';
  static const _fontScaleKey = 'fontScale';
  static const _layoutCustomizationKey = 'layoutCustomization';
  static const _homeNavExpandedKey = 'homeNavExpanded';
  static const _layoutDensityKey = 'layoutDensity';
  static const _mapStyleKey = 'mapStyle';
  static const _secondaryControlsOrderKey = 'secondaryControlsOrder';
  static const _hiddenSecondaryControlsKey = 'hiddenSecondaryControls';
  static const _showRSTFieldsKey = 'showRSTFields';
  static const _showStateFieldKey = 'showStateField';
  static const _showGridFieldKey = 'showGridField';
  static const _showDeletedQSOsKey = 'showDeletedQSOs';
  static const _showQsoNumbersKey = 'showQsoNumbers';
  static const _distanceUnitsKey = 'distanceUnits';
  static const _numberFormatKey = 'numberFormat';
  static const _spottingFiltersKey = 'spottingFilters';
  static const _stationEquipmentKey = 'stationEquipment';
  static const _experimentsKey = 'experiments';
  static const _onboardingKey = 'onboarding';
  static const _layoutKey = 'layout';
  static const _lastSeenReleaseVersionKey = 'lastSeenReleaseVersion';
  static const _lastSeenTesterBuildKey = 'lastSeenTesterBuild';
  static const _shorebirdTrackKey = 'shorebirdTrack';
  static const _listenForOtherAppsEnabledKey = 'listenForOtherAppsEnabled';
  static const _peerSyncEnabledKey = 'peerSyncEnabled';
  static const _peerBleEnabledKey = 'peerBleEnabled';
  static const _peerScreenShareEnabledKey = 'peerScreenShareEnabled';
  static const _peerSharedScreenIdsKey = 'peerSharedScreenIds';
  static const _peerDeviceIdKey = 'peerDeviceId';
  static const _peerDeviceNameKey = 'peerDeviceName';
  static const _n1mmProtocolEnabledKey = 'n1mmProtocolEnabled';
  static const _n1mmListenPortKey = 'n1mmListenPort';
  static const _wsjtxProtocolEnabledKey = 'wsjtxProtocolEnabled';
  static const _wsjtxListenPortKey = 'wsjtxListenPort';
  static const _wsjtxMulticastGroupKey = 'wsjtxMulticastGroup';

  /// N1MM's own default UDP broadcast port — see "Listen for other apps".
  static const n1mmDefaultListenPort = 12060;

  /// WSJT-X's own defaults for its UDP protocol (a DIFFERENT protocol from
  /// N1MM's — multicast, binary — not just a different port).
  static const wsjtxDefaultListenPort = 2237;
  static const wsjtxDefaultMulticastGroup = '239.239.0.2';

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

  /// True once a secure-storage call has failed this session.
  ///
  /// On Linux that means no Secret Service is reachable — nothing running
  /// (gnome-keyring, KWallet, KeePassXC), no default collection, or one that is
  /// locked and would not unlock. The plugin reports all three as
  /// `KeyringLocked`, so this deliberately does not claim which
  /// (flutter_secure_storage_linux, `Secret.hpp` `warmupKeyring`). Boot reads it
  /// to say, once, that account logins cannot be saved.
  ///
  /// Not persisted: it describes THIS session, and a keyring installed or
  /// unlocked later must be picked up on the next launch without anything to
  /// reset.
  bool get secureStorageUnavailable => _secureStorageUnavailable;
  bool _secureStorageUnavailable = false;

  SettingsService(this._prefs, {FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            // macOS uses the FILE keychain, not the data-protection keychain.
            // The data-protection keychain requires the `keychain-access-groups`
            // entitlement, which is RESTRICTED: a Developer ID direct-download
            // build has no provisioning profile to validate it, so ADDING it
            // makes the app fail to spawn and NOT adding it makes every
            // save throw errSecMissingEntitlement (-34018). The file keychain
            // needs no entitlement and works under the sandbox (it's what debug
            // already uses). A future Mac App Store build has a profile
            // and can switch back. See ExtensionService._secureStorage.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false, accountName: 'Ham2K Logger'),
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
  static const exportsGroup = 'exports';
  static const radioGroup = 'radio';
  static const stationInfoGroup = 'stationInfo';

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

  /// Removes everything an extension stored: its settings group, and the
  /// enable/disable override the operator set for it.
  ///
  /// For uninstalling one (HALO-422). Deliberately NOT called when an
  /// extension is merely disabled, or updated — a disabled extension keeps its
  /// configuration for when it comes back, and an update is not a reinstall.
  Future<void> forgetExtension(String key) async {
    await _prefs.remove('settings.extension_$key');
    // Settings-panel values. A panel's key is the extension's own or prefixed
    // with it (the namespacing registerHook enforces), which is the only
    // handle left once the extension is gone and cannot be asked what panels
    // it had. Secrets live in the keychain and are ExtensionService's to
    // remove — this half is the plain values.
    for (final prefsKey in _prefs.getKeys().toList()) {
      if (prefsKey.startsWith('settingsPanel.$key.') || prefsKey.startsWith('settingsPanel.${key}_')) {
        await _prefs.remove(prefsKey);
      }
    }
    final overrides = extensionOverrides;
    if (overrides.remove(key) != null) {
      await _prefs.setString(_extensionOverridesKey, jsonEncode(overrides));
    }
    // Otherwise a reinstall inherits a disabled-since stamp from an extension
    // that no longer exists, and the data purge counts from the wrong day.
    final disabledSince = extensionDisabledSince;
    if (disabledSince.remove(key) != null) {
      await _prefs.setString(_extensionDisabledSinceKey, jsonEncode(disabledSince));
    }
    notifyListeners();
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

  /// The `kBuildNumber` the user last dismissed the tester overlay for
  /// (tester_overlay.dart) — the overlay shows again once `kBuildNumber`
  /// exceeds this, listing every tester-notes entry in between.
  int get lastSeenTesterBuild => _prefs.getInt(_lastSeenTesterBuildKey) ?? 0;

  Future<void> setLastSeenTesterBuild(int build) async {
    await _prefs.setInt(_lastSeenTesterBuildKey, build);
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

  /// Writes free-form profile fields ([Profile.operatorName] and friends) in
  /// one go: a single store write and a single notification, however many
  /// fields changed, because they are edited together in one dialog.
  ///
  /// Trims only — a field whose value is a code normalizes its own case at the
  /// call site. [operatorCall] keeps its own setter because changing it also
  /// re-keys sync and feature flags (HaLoServices.setOperatorCall).
  Future<void> setProfileFields(String profileId, Map<String, String> fields) async {
    await _prefs.setString(
      _profilesKey,
      jsonEncode({
        ..._profilesData,
        profileId: {
          ..._profile(profileId).data,
          for (final entry in fields.entries) entry.key: entry.value.trim(),
        },
      }),
    );
    notifyListeners();
  }

  /// Whether the native updater looks for new versions on its own. Defaults
  /// ON: an operator who never opens Settings should still hear about a
  /// release, which on Windows they otherwise never would.
  ///
  /// Read at boot and pushed into the updater BEFORE it initializes (see
  /// AutoUpdateService), so a change here reaches the updater at the next
  /// launch rather than mid-session — its scheduler cannot be re-armed once
  /// running.
  bool get automaticUpdateChecks => _prefs.getBool(_automaticUpdateChecksKey) ?? true;

  Future<void> setAutomaticUpdateChecks(bool enabled) async {
    await _prefs.setBool(_automaticUpdateChecksKey, enabled);
    notifyListeners();
  }

  /// Whether this device syncs its log. [seedSyncEnabledDefault] writes the
  /// key at first boot, so the bare fallback here is only ever reached
  /// before that has run.
  bool get syncEnabled => _prefs.getBool(_syncEnabledKey) ?? false;

  Future<void> setSyncEnabled(bool enabled) async {
    await _prefs.setBool(_syncEnabledKey, enabled);
    notifyListeners();
  }

  /// Whether the app listens for other logging programs on the network at
  /// all, app-wide and independent of which operation (if any) is open —
  /// see "Listen for other apps". The master switch:
  /// [InboundQsoListenerService] starts nothing while this is off, whatever
  /// [n1mmProtocolEnabled]/[wsjtxProtocolEnabled] say. Those two decide
  /// WHICH protocols run once this is on — an operator who only uses
  /// WSJT-X shouldn't have N1MM's port bound for no reason.
  bool get listenForOtherAppsEnabled => _prefs.getBool(_listenForOtherAppsEnabledKey) ?? false;

  Future<void> setListenForOtherAppsEnabled(bool enabled) async {
    await _prefs.setBool(_listenForOtherAppsEnabledKey, enabled);
    notifyListeners();
  }

  /// The master switch for peer device sync (HALO-310).
  ///
  /// Off by default, and the ONLY thing that opens a socket: with this off
  /// nothing binds, nothing announces, and this device is invisible to the
  /// network. On, whichever operation the operator has open is shared
  /// automatically — there is no per-operation step, so the switch itself is
  /// the whole consent, which is why it says what it does in the settings
  /// row rather than only in a help page.
  bool get peerSyncEnabled => _prefs.getBool(_peerSyncEnabledKey) ?? false;

  Future<void> setPeerSyncEnabled(bool enabled) async {
    await _prefs.setBool(_peerSyncEnabledKey, enabled);
    notifyListeners();
  }

  /// The Bluetooth sub-switch under [peerSyncEnabled] (HALO-342). Its own
  /// opt-in where location sharing has none, because turning it on does
  /// what the master switch alone never did: pops an OS Bluetooth
  /// permission prompt and keeps a radio busy. Off, BLE code touches
  /// nothing and existing LAN users see no new prompt.
  bool get peerBleEnabled => _prefs.getBool(_peerBleEnabledKey) ?? false;

  Future<void> setPeerBleEnabled(bool enabled) async {
    await _prefs.setBool(_peerBleEnabledKey, enabled);
    notifyListeners();
  }

  /// The screen-sharing sub-switch under [peerSyncEnabled] (HALO-369), and
  /// its own opt-in for the same reason BLE has one: turning it on does
  /// something the master switch never implied. A shared operation is the
  /// operator's own log; a shared screen is their email, their browser and
  /// whatever else is on that display, and on macOS it also asks the OS for
  /// a Screen Recording grant that outlives the app.
  bool get peerScreenShareEnabled => _prefs.getBool(_peerScreenShareEnabledKey) ?? false;

  Future<void> setPeerScreenShareEnabled(bool enabled) async {
    await _prefs.setBool(_peerScreenShareEnabledKey, enabled);
    notifyListeners();
  }

  /// Which sources this device offers — nothing is shared merely because the
  /// switch above is on, so a mis-tapped switch cannot expose a screen.
  ///
  /// Ids, not names, and deliberately kept even when a source is not
  /// currently present: an application that is closed and reopened, or an
  /// external display unplugged over lunch, must come back offered rather
  /// than silently dropped from the list the operator built.
  List<String> get peerSharedScreenIds => _prefs.getStringList(_peerSharedScreenIdsKey) ?? const [];

  Future<void> setPeerSharedScreenIds(List<String> ids) async {
    await _prefs.setStringList(_peerSharedScreenIdsKey, ids);
    notifyListeners();
  }

  /// This install's identifier for peer device sync (HALO-310) — the only
  /// thing another device's trust is ever keyed on.
  ///
  /// Deliberately NOT [syncDeviceKey]. That one is a bearer credential for
  /// the account's log and lives in the platform keychain; this one is
  /// broadcast in the clear to every device on the network, so it belongs in
  /// plain prefs — and a keychain-backed id would leave peer sync dead on a
  /// headless Linux box with a locked keyring, where `ensureSyncDeviceKey`
  /// legitimately returns null.
  ///
  /// Generated on first read and persisted fire-and-forget. If that write
  /// were ever to fail the device would come back under a new id and its
  /// peers would ask to pair again — recoverable, and a much better failure
  /// than making every caller handle a null identity.
  String get peerDeviceId {
    final cached = _cachedPeerDeviceId;
    if (cached != null) return cached;
    final existing = _prefs.getString(_peerDeviceIdKey);
    if (existing != null && existing.isNotEmpty) return _cachedPeerDeviceId = existing;
    final generated = _uuidGenerator.v4();
    _cachedPeerDeviceId = generated;
    unawaited(_prefs.setString(_peerDeviceIdKey, generated));
    return generated;
  }

  String? _cachedPeerDeviceId;

  /// What this device calls itself to peers. Shown beside [peerDeviceId] in
  /// the pairing prompt so an operator can tell their laptop from their
  /// phone — self-asserted, and never trusted as identity by the receiving
  /// side.
  String get peerDeviceName {
    final stored = _prefs.getString(_peerDeviceNameKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final call = operatorCall;
    final platform = platformName();
    return call.isEmpty ? platform : '$call ($platform)';
  }

  Future<void> setPeerDeviceName(String name) async {
    await _prefs.setString(_peerDeviceNameKey, name.trim());
    notifyListeners();
  }

  /// Whether N1MM's broadcast protocol specifically is listened to, gated
  /// by [listenForOtherAppsEnabled]. Defaults on: most operators want every
  /// protocol this app understands the moment they turn listening on at all.
  bool get n1mmProtocolEnabled => _prefs.getBool(_n1mmProtocolEnabledKey) ?? true;

  Future<void> setN1mmProtocolEnabled(bool enabled) async {
    await _prefs.setBool(_n1mmProtocolEnabledKey, enabled);
    notifyListeners();
  }

  /// The UDP port N1MM's broadcast is heard on. Configurable because N1MM's
  /// own broadcast port can be reconfigured, and more than one
  /// N1MM-compatible program may share a machine.
  int get n1mmListenPort => _prefs.getInt(_n1mmListenPortKey) ?? n1mmDefaultListenPort;

  Future<void> setN1mmListenPort(int port) async {
    await _prefs.setInt(_n1mmListenPortKey, port);
    notifyListeners();
  }

  /// See [n1mmProtocolEnabled] — the same per-protocol opt-out for WSJT-X.
  bool get wsjtxProtocolEnabled => _prefs.getBool(_wsjtxProtocolEnabledKey) ?? true;

  Future<void> setWsjtxProtocolEnabled(bool enabled) async {
    await _prefs.setBool(_wsjtxProtocolEnabledKey, enabled);
    notifyListeners();
  }

  /// The UDP port WSJT-X's multicast protocol is heard on.
  int get wsjtxListenPort => _prefs.getInt(_wsjtxListenPortKey) ?? wsjtxDefaultListenPort;

  Future<void> setWsjtxListenPort(int port) async {
    await _prefs.setInt(_wsjtxListenPortKey, port);
    notifyListeners();
  }

  /// The multicast group WSJT-X's UDP Server broadcasts to (its Settings →
  /// Reporting → UDP Server tab) — configurable because that field is
  /// itself configurable in WSJT-X, and a station running several rigs may
  /// use a non-default group to keep instances from colliding.
  String get wsjtxMulticastGroup => _prefs.getString(_wsjtxMulticastGroupKey) ?? wsjtxDefaultMulticastGroup;

  Future<void> setWsjtxMulticastGroup(String group) async {
    await _prefs.setString(_wsjtxMulticastGroupKey, group);
    notifyListeners();
  }

  /// Decides, once per install, whether sync starts on: yes for a new
  /// install, no for one that predates this default.
  ///
  /// The distinction has to be recorded rather than defaulted. Flipping the
  /// getter's fallback to true would turn sync on for every existing device
  /// whose owner deliberately left the toggle alone, and the first they'd
  /// know of it is their log appearing in the cloud after an app update.
  /// [defaultProfileCallsignDefined] is the same "has this device ever been
  /// through onboarding" signal [seedFirstUseOnboardingForExistingUsers]
  /// uses, and this runs beside it at boot — before onboarding can set a
  /// callsign, so a genuinely new install still reads as new.
  Future<void> seedSyncEnabledDefault() async {
    if (_prefs.containsKey(_syncEnabledKey)) return;
    await setSyncEnabled(!defaultProfileCallsignDefined);
  }

  /// A stable opaque per-install identifier for the LoFi sync server (the
  /// Flutter equivalent of app-polo's `DeviceInfo.syncUniqueId()`), generated
  /// once and persisted in the platform keychain forever after. Since it's
  /// the bearer credential for the account's synced log, it must be loaded
  /// before first use — call [ensureSyncDeviceKey] at boot.
  ///
  /// Returns null (never throws) when secure storage is locked or absent — a
  /// locked GNOME keyring / headless Linux box — so boot can still complete
  /// and the caller runs without sync this session. The null result is NOT
  /// cached, so a later call retries once the keyring is available.
  Future<String?> ensureSyncDeviceKey() async {
    if (_cachedDeviceKey != null) return _cachedDeviceKey;

    // Secure storage (libsecret on Linux, the keychain elsewhere) can be locked
    // or absent — a headless box or a locked GNOME keyring throws KeyringLocked.
    // The device key is a bearer credential, so it must NOT fall back to plain
    // prefs; instead we return null and let the caller run without sync this
    // session, picking it back up on a later launch once the keyring is
    // available. This must never throw, or it takes bootstrap() down with it
    // (main.dart) and the whole app fails to start.
    try {
      final fromSecure = await _secureStorage.read(key: _syncDeviceKeyKey);
      if (fromSecure != null && fromSecure.isNotEmpty) {
        _secureStorageUnavailable = false;
        return _cachedDeviceKey = fromSecure;
      }

      final key = _uuidGenerator.v4();
      await _secureStorage.write(key: _syncDeviceKeyKey, value: key);
      _secureStorageUnavailable = false;
      return _cachedDeviceKey = key;
    } catch (e, st) {
      debugPrint('[settings] secure storage unavailable ($e) — sync disabled this session');
      ErrorReportingService.report(e, st, context: 'settings:sync-device-key');
      _secureStorageUnavailable = true;
      return null;
    }
  }

  /// Reads a per-equipment secret from the platform keychain.
  ///
  /// Equipment configuration lives in a plain SharedPreferences JSON blob
  /// ([stationEquipment]), which is the right home for a hostname and the
  /// wrong one for a password. The IC-705's network login is the first
  /// credential CAT needs, so it goes here instead, keyed by node uuid.
  ///
  /// Returns null when secure storage is locked or absent (a headless Linux
  /// box, a locked GNOME keyring) rather than throwing — the caller reports
  /// "no credentials" and the radio simply doesn't connect.
  Future<String?> equipmentSecret(String uuid, String field) async {
    try {
      // DO NOT rename this 'gato.' prefix to 'cat.' — it is the live keychain
      // key. The GATO codename was retired from the code, deliberately not
      // from persisted keys: changing this orphans every stored radio password
      // on every machine that has one, and the symptom is a radio that stops
      // connecting with no error worth reading. A rename would need a
      // read-old/write-new migration, and that migration would have to live
      // here forever to serve a string no user ever sees.
      return await _secureStorage.read(key: 'gato.$uuid.$field');
    } catch (e, st) {
      debugPrint('[settings] could not read equipment secret: $e');
      ErrorReportingService.report(e, st, context: 'settings:equipment-secret-read');
      return null;
    }
  }

  /// Writes (or, with a null value, clears) a per-equipment secret.
  ///
  /// Returns whether it landed. The caller has to know: [CatService]
  /// strips the secret out of the stored config once it believes the
  /// keychain has it, so a swallowed failure meant the password existed in
  /// NEITHER place — a locked keyring turned a successful-looking save into
  /// a credential the user had to retype but was never told about.
  Future<bool> setEquipmentSecret(String uuid, String field, String? value) async {
    try {
      // 'gato.', deliberately — see the note in [equipmentSecret]. Both sites
      // must agree, and both must stay as they are.
      final key = 'gato.$uuid.$field';
      if (value == null || value.isEmpty) {
        await _secureStorage.delete(key: key);
      } else {
        await _secureStorage.write(key: key, value: value);
      }
      return true;
    } catch (e, st) {
      debugPrint('[settings] could not write equipment secret: $e');
      ErrorReportingService.report(e, st, context: 'settings:equipment-secret-write');
      return false;
    }
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

  /// Hook keys the operator switched off in the Spots Panel's source filter
  /// — the `disabledSources` slice of [spottingFilters], typed here so
  /// consumers outside the panel (the spots status reporter) don't each
  /// re-derive the map's shape.
  ///
  /// Tolerant of a wrong-typed slice rather than throwing: a corrupt filter
  /// pref must not take the outage reporter down with it — its whole
  /// evaluation, retraction included, runs behind this read. Tolerance is
  /// still said out loud, because a silently-empty set here un-disables the
  /// operator's opt-outs.
  Set<String> get disabledSpotSources {
    final raw = spottingFilters['disabledSources'];
    if (raw is! List) {
      if (raw != null) debugPrint('[settings] ignoring disabledSources of type ${raw.runtimeType}');
      return const {};
    }
    return raw.whereType<String>().toSet();
  }

  /// The station's configured equipment — radios today, eventually antenna
  /// switches and rotators (docs/design/data-model.md § Stations). Shaped
  /// `{version: 1, nodes: {uuid: {...}}}`; see [CatService], which owns the
  /// reading and writing of it.
  ///
  /// Device-local and never synced, like [syncState] and `radioVfoState`:
  /// physical equipment is per-shack. Only what the user configured is
  /// stored — nothing about a live connection, so a stale "connected" can't
  /// survive a restart and lie about the radio.
  Map<String, dynamic> get stationEquipment => _jsonMapPref(_stationEquipmentKey);

  Future<void> setStationEquipment(Map<String, dynamic> equipment) async {
    await _prefs.setString(_stationEquipmentKey, jsonEncode(equipment));
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
    final now = nowMillis();
    if (enabled) {
      entry['firstEnabledAtMillis'] ??= now;
    } else {
      entry['lastDisabledAtMillis'] = now;
    }
    await _prefs.setString(_experimentsKey, jsonEncode({...states, key: entry}));
    notifyListeners();
  }

  /// Per-flow onboarding state, keyed by flow id ([OnboardingFlows]):
  /// `{shownCount: int, firstShownAtMillis: int, lastShownAtMillis: int}`.
  /// "Shown" is flow-specific — for a flow that gates a UI overlay
  /// (`OnboardingFlows.firstUse`, `.operationSheet`) it's a real display of
  /// that overlay; for one that just counts an outcome the flow is nudging
  /// toward (`.newOperation` counts operations opened, not times a nudge
  /// showed) it's whatever [recordOnboardingShown] is called for. A missing
  /// entry reads as never shown (count 0).
  Map<String, dynamic> get onboardingStates => _jsonMapPref(_onboardingKey);

  int onboardingShownCount(String flow) {
    final state = onboardingStates[flow];
    return state is Map ? ((state['shownCount'] as num?)?.toInt() ?? 0) : 0;
  }

  Future<void> recordOnboardingShown(String flow) async {
    final states = onboardingStates;
    final entry = {...?(states[flow] as Map?)?.cast<String, dynamic>()};
    final now = nowMillis();
    entry['shownCount'] = ((entry['shownCount'] as num?)?.toInt() ?? 0) + 1;
    entry['firstShownAtMillis'] ??= now;
    entry['lastShownAtMillis'] = now;
    await _prefs.setString(_onboardingKey, jsonEncode({...states, flow: entry}));
    notifyListeners();
  }

  /// Existing installs never ran through the `first-use` flow's counter — it
  /// didn't exist yet — but they've unambiguously already been through
  /// onboarding: the default profile has a callsign (or an explicit blank
  /// one from skipping it). Seeds the counter to 1 so they don't read as
  /// "never onboarded"; a no-op once the counter is non-zero, so it's safe
  /// to call on every boot.
  Future<void> seedFirstUseOnboardingForExistingUsers() async {
    if (!defaultProfileCallsignDefined) return;
    if (onboardingShownCount(OnboardingFlows.firstUse) > 0) return;
    final now = nowMillis();
    await _prefs.setString(
      _onboardingKey,
      jsonEncode({
        ...onboardingStates,
        OnboardingFlows.firstUse: {
          'shownCount': 1,
          'firstShownAtMillis': now,
          'lastShownAtMillis': now,
        },
      }),
    );
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

  /// The extension dev server to load extensions from
  /// (docs/extensions/development.md). Typed by hand, never discovered: this
  /// is code the app will run, so nothing on the network gets to volunteer
  /// itself.
  String get extensionDevServerUrl => _prefs.getString(_extensionDevServerUrlKey) ?? '';

  Future<void> setExtensionDevServerUrl(String url) async {
    await _prefs.setString(_extensionDevServerUrlKey, url.trim());
    notifyListeners();
  }

  /// Whether to connect to [extensionDevServerUrl] at launch. Persisted so a
  /// dev session survives a restart of the app, which is most of what an
  /// author does with it.
  bool get extensionDevServerEnabled => _prefs.getBool(_extensionDevServerEnabledKey) ?? false;

  Future<void> setExtensionDevServerEnabled(bool enabled) async {
    await _prefs.setBool(_extensionDevServerEnabledKey, enabled);
    notifyListeners();
  }

  @override
  String get operatorCall => activeProfile.operatorCall;

  @override
  bool get enabled => syncEnabled;

  @override
  Map<String, dynamic> get state => syncState;

  @override
  Future<void> setState(Map<String, dynamic> state) => setSyncState(state);

  /// Whether a view that CAN be rearranged is (docs/design/layouts.md). Off,
  /// the Operation View uses its fixed two-pane split and there is no layout
  /// button in the header at all; on, it uses the dock and the header carries
  /// the way into edit mode.
  ///
  /// Two-pane only, and off by default: a fixed arrangement is the one an
  /// operator can be talked through over the air, so rearranging is something
  /// they opt into.
  /// Deliberately independent of which panels exist: enabling a dashboard
  /// panel extension must never quietly rearrange the operator's view as
  /// well — two features behind one switch.
  bool get layoutCustomization => (settingValue(generalGroup, _layoutCustomizationKey) as bool?) ?? false;

  Future<void> setLayoutCustomization(bool value) =>
      setSettingValue(generalGroup, _layoutCustomizationKey, value);

  /// Whether Home's navigation rail shows its labels. Not a visibility switch:
  /// the rail is always there, and this is only how wide (see
  /// `HomeNavigationRail`). Collapsed by default — the rail's two destinations
  /// are a notebook and a gear, and an operator who wants the words has one
  /// click to them.
  ///
  /// Read differently at each width, because the two have different room to
  /// give: wide it means LABELS, narrow it means the rail is on screen at all
  /// (labels would take a third of a phone's width from the panes). See
  /// `HomeNavigationRail.widthFor`.
  bool get homeNavExpanded => (settingValue(generalGroup, _homeNavExpandedKey) as bool?) ?? false;

  Future<void> setHomeNavExpanded(bool value) =>
      setSettingValue(generalGroup, _homeNavExpandedKey, value);

  String get locale => (settingValue(generalGroup, _localeKey) as String?) ?? 'en';

  Future<void> setLocale(String localeCode) async {
    await setSettingValue(generalGroup, _localeKey, localeCode);
    Intl.defaultLocale = localeCode;
  }

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

  String _loggingString(String key) => ((settingValue(loggingGroup, key) as String?) ?? '').trim();

  /// Exports panel's settings. Handed to the export hooks, which build their
  /// filenames from it (`exportFilename` in the extension SDK) — so it takes
  /// effect on the names the panel LISTS, not just the files it writes.
  ///
  /// Off by default: the readable form is the better first impression, and
  /// operators who want terse names for an uploader go looking for the
  /// setting. Same default as app-polo's `useCompactFileNames`.
  bool get useCompactFileNames => (settingValue(exportsGroup, 'useCompactFileNames') as bool?) ?? false;

  Future<void> setUseCompactFileNames(bool value) =>
      setSettingValue(exportsGroup, 'useCompactFileNames', value);

  /// Whether exports may carry the operator's private notes about the stations
  /// they worked — names, towns, gridsquares, QSO notes.
  ///
  /// Off by default, because most exports exist to be UPLOADED: a park's log
  /// goes to POTA's servers, a Cabrillo to a contest sponsor, and neither has
  /// any business with the operator's notes about who they met. The whole-log
  /// ADIF backup is exempt — it declares `alwaysIncludePrivateData`, since
  /// being complete is the whole point of it.
  bool get includePrivateData => (settingValue(exportsGroup, 'includePrivateData') as bool?) ?? false;

  Future<void> setIncludePrivateData(bool value) =>
      setSettingValue(exportsGroup, 'includePrivateData', value);

  /// Smart VFO Snap: whether a knob turn on the connected radio settles on a
  /// round frequency (app/lib/services/cat/vfo_snap.dart).
  ///
  /// Off by default — it moves the operator's radio, which nothing else in
  /// the app does uninvited, so it is opted into rather than out of.
  ///
  /// One setting for the VFO the app is driving, not one per radio: the
  /// operator has one pair of ears and one preference about where voice
  /// contacts sit.
  bool get smartVfoSnap => (settingValue(radioGroup, 'smartVfoSnap') as bool?) ?? false;

  Future<void> setSmartVfoSnap(bool value) => setSettingValue(radioGroup, 'smartVfoSnap', value);

  /// Smart VFO Snap's feel, as four numbers the operator can turn.
  ///
  /// The option lists live HERE rather than beside the settings fields, and
  /// the getters resolve through them, because the alternative is a setting
  /// that displays one value and acts on another: the picker has to fall back
  /// to an offered option when the stored one isn't in its list (a
  /// `DropdownButtonFormField` throws on a value with no matching item), and
  /// if that fallback happened only in the UI, a stored value withdrawn from
  /// the list would keep driving the snapper while the dialog showed
  /// something else.
  ///
  /// Values are the option strings the `select` fields emit — the convention
  /// every other select-backed setting here follows (`fontScale`,
  /// `distanceUnits`).
  static const smartVfoSnapDebounceOptions = ['150', '200', '250', '300', '400', '500', '750', '1000'];
  static const smartVfoSnapLongMoveOptions = ['1', '1.5', '2', '3', '5', '10'];
  static const smartVfoSnapMinMoveOptions = ['0.1', '0.15', '0.2', '0.3', '0.5'];
  static const smartVfoSnapMinSpeedOptions = ['0.25', '0.5', '1', '2', '4'];

  /// The stored value for [key], resolved to the nearest value [options]
  /// actually offers. An unparseable or missing value takes [fallback], which
  /// must itself be one of the options.
  double _radioNumber(String key, List<String> options, String fallback) {
    final stored = '${settingValue(radioGroup, key) ?? ''}';
    if (options.contains(stored)) return double.parse(stored);
    // Not offered: the closest one that is — measured against what was
    // stored while that still parses as a number, and against the default
    // when it doesn't. Same answer the picker shows, because the picker
    // reads this getter.
    final target = double.tryParse(stored) ?? double.parse(fallback);
    return options.map(double.parse).reduce((a, b) => (a - target).abs() <= (b - target).abs() ? a : b);
  }

  /// How long the VFO must hold still before a movement is settled.
  ///
  /// The one that decides whether the feature feels immediate or laggy, and
  /// the one with a real cost at either end: too short chops a slow move into
  /// pieces that each measure as a fine adjustment, too long leaves the
  /// frequency jumping after the operator has moved on to the callsign field.
  Duration get smartVfoSnapDebounce =>
      Duration(milliseconds: _radioNumber('smartVfoSnapDebounceMs', smartVfoSnapDebounceOptions, '300').round());

  double get smartVfoSnapLongMoveKHz =>
      _radioNumber('smartVfoSnapLongMoveKHz', smartVfoSnapLongMoveOptions, '2');

  double get smartVfoSnapMinMoveKHz => _radioNumber('smartVfoSnapMinMoveKHz', smartVfoSnapMinMoveOptions, '0.2');

  double get smartVfoSnapMinSpeed => _radioNumber('smartVfoSnapMinSpeed', smartVfoSnapMinSpeedOptions, '0.5');

  /// Whether tuning to a CW spot lands a little off the spotted frequency
  /// rather than exactly on it (app/lib/services/cat/zero_beat.dart).
  ///
  /// Off by default, for the same reason as [smartVfoSnap]: the frequency an
  /// operator transmits on and logs is theirs to choose, so anything that
  /// moves it is opted into rather than out of. That this one only redirects a
  /// retune the operator just asked for, rather than moving the radio
  /// uninvited, makes it milder — not automatic.
  ///
  /// Everyone who clicks the same spot otherwise transmits on exactly the same
  /// frequency, and a CW pileup stacked on one note is one the activator
  /// cannot pick a callsign out of.
  bool get avoidZeroBeat => (settingValue(radioGroup, 'avoidZeroBeat') as bool?) ?? false;

  Future<void> setAvoidZeroBeat(bool value) => setSettingValue(radioGroup, 'avoidZeroBeat', value);

  /// How far off the spotted frequency [avoidZeroBeat] may land, in Hz either
  /// side. Same reason the option list lives here as [smartVfoSnapDebounceOptions].
  static const zeroBeatRangeOptions = ['10', '25', '50', '75'];

  /// The widest offset in Hz; the draw also keeps clear of a dead zone around
  /// zero (see `zeroBeatOffsetHz`), so this is a bound, not the typical value.
  double get zeroBeatRangeHz => _radioNumber('zeroBeatRangeHz', zeroBeatRangeOptions, '25');

  /// Whether the Station Configuration panel offers to record which
  /// transceiver, power, antenna and/or CW key went with each QSO.
  ///
  /// Off by default — most operators log with one of each, so the field
  /// would say the same thing on every row. [stationInfoTrackedFields] and
  /// [includeStationInfoInAdif] only take effect while this is on.
  bool get trackStationInfo => (settingValue(stationInfoGroup, 'trackStationInfo') as bool?) ?? false;

  Future<void> setTrackStationInfo(bool value) => setSettingValue(stationInfoGroup, 'trackStationInfo', value);

  /// Whether a tracked QSO's station info rides along in an ADIF export.
  /// Off by default, for the same reason as [includePrivateData]: most
  /// exports go to a park, a contest sponsor, or an uploader, none of which
  /// asked which radio worked the contact.
  bool get includeStationInfoInAdif =>
      (settingValue(stationInfoGroup, 'includeStationInfoInAdif') as bool?) ?? false;

  Future<void> setIncludeStationInfoInAdif(bool value) =>
      setSettingValue(stationInfoGroup, 'includeStationInfoInAdif', value);

  /// Which of `rig`/`power`/`antenna`/`key` to record. Defaults to just the
  /// two most operators already have exactly one of — antenna and key are
  /// opt-in, since tracking them means adding them to the inventory first.
  static const defaultStationInfoTrackedFields = ['rig', 'power'];

  Set<String> get stationInfoTrackedFields {
    final value = settingValue(stationInfoGroup, 'trackedFields');
    return value is List ? value.whereType<String>().toSet() : defaultStationInfoTrackedFields.toSet();
  }

  Future<void> setStationInfoTrackedFields(Set<String> fields) =>
      setSettingValue(stationInfoGroup, 'trackedFields', fields.toList());

  /// The power the operator is currently running, in watts — set from the
  /// Radio control's quick CAT dialog, since nothing in the app reads it off
  /// the rig itself. Null means unset, not zero.
  num? get currentPower => settingValue(stationInfoGroup, 'currentPower') as num?;

  Future<void> setCurrentPower(num? value) => setSettingValue(stationInfoGroup, 'currentPower', value);

  /// Logging view "..." menu toggles.
  bool get showRSTFields => _loggingBool(_showRSTFieldsKey, true);

  Future<void> setShowRSTFields(bool value) => setSettingValue(loggingGroup, _showRSTFieldsKey, value);

  bool get showStateField => _loggingBool(_showStateFieldKey, false);

  Future<void> setShowStateField(bool value) => setSettingValue(loggingGroup, _showStateFieldKey, value);

  bool get showGridField => _loggingBool(_showGridFieldKey, false);

  Future<void> setShowGridField(bool value) => setSettingValue(loggingGroup, _showGridFieldKey, value);

  /// Off by default — deleted QSOs are hidden from the list unless the user
  /// opts in.
  bool get showDeletedQSOs => _loggingBool(_showDeletedQSOsKey, false);

  Future<void> setShowDeletedQSOs(bool value) => setSettingValue(loggingGroup, _showDeletedQSOsKey, value);

  bool get showQsoNumbers => _loggingBool(_showQsoNumbersKey, true);

  Future<void> setShowQsoNumbers(bool value) => setSettingValue(loggingGroup, _showQsoNumbersKey, value);

  // Logging settings, defaults matching app-polo.
  bool get leftieMode => _loggingBool('leftieMode', false);
  bool get showBearing => _loggingBool('showBearing', false);

  /// Declared in the settings registry and persisted here, but NOT consumed
  /// anywhere — the panel puts the logging fields below the QSO list whichever
  /// way this is set. The toggle stays offered deliberately, waiting on the
  /// layout work: wire it up, don't withdraw it.
  bool get fieldsOnTop => _loggingBool('fieldsOnTop', false);

  /// Both reach the logging row, its keyboard order, the QSO list and the More
  /// pane — see `docs/design/logging-fields.md`, whose focus rules they bend.
  bool get switchSentRcvd => _loggingBool('switchSentRcvd', false);
  bool get jumpAfterRST => _loggingBool('jumpAfterRST', false);

  /// The report an untouched Sent/Rcvd field stands for, per mode band —
  /// `5NN` instead of `599` for a CW operator, `+00` instead of `+0`.
  ///
  /// Empty here means "the standard report", which is what [defaultRSTFor]
  /// resolves them against; storing the standard values as the defaults would
  /// bake today's constants into every install's preferences.
  String get defaultReport => _loggingString('defaultReport');
  String get defaultReportCW => _loggingString('defaultReportCW');
  String get defaultReportFT8 => _loggingString('defaultReportFT8');

  /// The mobile "numbers row" — a bar of digit keys the logging panel floats
  /// above the on-screen keyboard while a logging field has focus.
  /// Off by default (opt-in), matching app-polo's `showNumbersRow`.
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

  /// Which characters numbers are written and read with — see
  /// [NumberFormatting], which is where the resolved answer lives. Defaults
  /// to the device's own conventions rather than to either fixed choice: an
  /// operator whose phone already writes `14.285,5` has told us once
  /// already, and the two explicit options exist for the ones it gets wrong.
  NumberFormatStyle get numberFormatStyle {
    final value = settingValue(generalGroup, _numberFormatKey);
    for (final style in NumberFormatStyle.values) {
      if (style.name == value) return style;
    }
    return NumberFormatStyle.locale;
  }

  Future<void> setNumberFormatStyle(NumberFormatStyle style) =>
      setSettingValue(generalGroup, _numberFormatKey, style.name);

  /// The operator's Layout Density choice. [DensityPreference.auto] by
  /// default, which is what makes the height ladder the normal behaviour and
  /// an explicit pick the exception.
  DensityPreference get densityPreference {
    final value = settingValue(generalGroup, _layoutDensityKey);
    return DensityPreference.values.firstWhere((e) => e.name == value, orElse: () => DensityPreference.auto);
  }

  Future<void> setDensityPreference(DensityPreference preference) =>
      setSettingValue(generalGroup, _layoutDensityKey, preference.name);

  /// The MapLibre basemap choice (see map_panel.dart). [MapStyle.automatic]
  /// by default, which keeps the existing light/dark-aware basemap; any
  /// other value pins one style regardless of the app's theme.
  MapStyle get mapStyle {
    final value = settingValue(generalGroup, _mapStyleKey);
    return MapStyle.values.firstWhere((e) => e.name == value, orElse: () => MapStyle.automatic);
  }

  Future<void> setMapStyle(MapStyle style) => setSettingValue(generalGroup, _mapStyleKey, style.name);
}

/// One callsign profile from [SettingsService.activeProfile] — an id plus a
/// free-form data map, so profile fields can grow without schema churn.
class Profile {
  final String id;
  final Map<String, dynamic> data;

  const Profile(this.id, this.data);

  String get operatorCall => (data['operatorCall'] as String?) ?? '';

  /// Personal details about the operator, offered to log generators that need
  /// them for a submission (Cabrillo headers name a NAME, CLUB and EMAIL; the
  /// ARRL/RAC section is Field Day's own exchange). All free-form and all
  /// optional — nothing in the app requires any of them.
  String get operatorName => (data['operatorName'] as String?) ?? '';

  String get operatorEmail => (data['operatorEmail'] as String?) ?? '';

  String get operatorClub => (data['operatorClub'] as String?) ?? '';

  /// ARRL section, or RAC section for a Canadian call — the same code space
  /// (`extensions/contests/fd/src/sections.ts` holds the authoritative table).
  /// Free-form: an out-of-date table must never block a valid entry.
  String get operatorSection => (data['operatorSection'] as String?) ?? '';
}

enum DistanceUnits { kilometers, miles }

/// A MapLibre basemap (see map_gl_script.dart's `mapLibreStyleUrl`) —
/// [automatic] keeps the app's own light/dark-aware default (Liberty /
/// Dark Matter); every other value pins one style regardless of theme.
enum MapStyle { automatic, liberty, bright, positron, voyager, darkMatter }

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
  static const operationLeftColumn = 'operation.leftColumn';
  static const operationDock = 'operation.dock';

  /// The dock's STATE — which pane is on top, and later which collapsible
  /// panes are hidden — deliberately apart from the arrangement above.
  /// Sharing one key would make a tab tap a write to the arrangement, which
  /// is how looking at a pane came to be able to replace a saved layout.
  static const operationDockState = 'operation.dockState';

  /// Per-pane layout options (title, header, scale and density overrides),
  /// keyed by module id. Part of the ARRANGEMENT, not its state: they are
  /// edited and saved with it, and a pane taken out of the layout takes them
  /// with it. Their own key rather than a branch of the dock tree so the tree
  /// stays what it is — splits, weights and module ids and nothing else.
  static const operationPaneOptions = 'operation.paneOptions';

  /// The VIEW's own layout options — its name, and scale/density for
  /// everything in it. The same shape as a pane's, one level up: a pane that
  /// overrides nothing inherits these, and these in turn fall back to the
  /// app's own settings.
  static const operationViewOptions = 'operation.viewOptions';

  /// The same four, for the NARROW arrangement — the one drawn below the
  /// two-pane boundary. A separate set rather than a flag inside the wide
  /// one: a phone's arrangement is a different tree, with its own defaults,
  /// its own pane options and its own idea of which pane is on top, and an
  /// operator who rearranges one has said nothing about the other.
  ///
  /// Instance ids are NOT shared across the two — see
  /// [DockLayoutKeys.everySpec], which lists these so a panel placed narrow
  /// cannot be handed an id the wide arrangement is already storing under.
  static const operationNarrowDock = 'operation.narrowDock';
  static const operationNarrowDockState = 'operation.narrowDockState';
  static const operationNarrowPaneOptions = 'operation.narrowPaneOptions';
  static const operationNarrowViewOptions = 'operation.narrowViewOptions';

  /// Home's OLD divider width, in pixels, from before its split became a dock.
  /// Read once, by the migration that turns it into the dock's initial split
  /// weights (`_migratedColumnWeights` in home_view.dart), and never written
  /// again. Kept rather than deleted: an operator's dragged width is a
  /// deliberate choice, and dropping the key would reset it silently on
  /// upgrade.
  static const homeLeftColumn = 'home.leftColumn';

  /// Home's dock, in the same four parts and for the same reasons. There is no
  /// live `leftColumn` counterpart to Operation's: Home's split IS the dock's,
  /// and the dock carries its own weights.
  static const homeDock = 'home.dock';
  static const homeDockState = 'home.dockState';
  static const homePaneOptions = 'home.paneOptions';
  static const homeViewOptions = 'home.viewOptions';

  /// Home's narrow arrangement, for the same reasons as Operation's.
  static const homeNarrowDock = 'home.narrowDock';
  static const homeNarrowDockState = 'home.narrowDockState';
  static const homeNarrowPaneOptions = 'home.narrowPaneOptions';
  static const homeNarrowViewOptions = 'home.narrowViewOptions';

  /// The Logs destination's dock, in the same four parts, for the same
  /// reasons as Home's.
  static const logsDock = 'logs.dock';
  static const logsDockState = 'logs.dockState';
  static const logsPaneOptions = 'logs.paneOptions';
  static const logsViewOptions = 'logs.viewOptions';

  /// The Logs destination's narrow arrangement, likewise.
  static const logsNarrowDock = 'logs.narrowDock';
  static const logsNarrowDockState = 'logs.narrowDockState';
  static const logsNarrowPaneOptions = 'logs.narrowPaneOptions';
  static const logsNarrowViewOptions = 'logs.narrowViewOptions';

  /// The Logs QSO table's user-dragged column widths, keyed by column id
  /// (see `_LogsColumnWidths`) — its own key rather than a branch of the dock
  /// tree, since the table can be resized whether or not the dock around it
  /// has ever been rearranged.
  static const logsQsoColumnWidths = 'logs.qsoColumnWidths';

  /// Which of the Logs QSO table's columns are shown at all, keyed by the
  /// same column ids as [logsQsoColumnWidths] — its own key, not a flag
  /// folded into the widths map, since a hidden column has no width of its
  /// own to store.
  static const logsQsoVisibleColumns = 'logs.qsoVisibleColumns';

  /// The user-dragged left-to-right order of ALL the Logs QSO table's
  /// columns, Name included (see `_LogsViewState._columnOrder`). Carries one
  /// value, `order`, a `List<String>` of column ids —
  /// [SettingsService.layoutData] only stores maps, hence the wrapper key
  /// rather than the list directly.
  static const logsQsoColumnOrder = 'logs.qsoColumnOrder';
}

/// Flow ids for [SettingsService.onboardingShownCount] /
/// [SettingsService.recordOnboardingShown].
abstract final class OnboardingFlows {
  /// The app's first-run overlay.
  static const firstUse = 'first-use';

  /// The operation sheet, auto-opened once for a user who's never seen it —
  /// independent of (and in addition to) the existing new-operation auto-open.
  static const operationSheet = 'operation-sheet';

  /// Not an overlay: counts new operations opened, so the home FAB's nudge
  /// (see `_NewOperationNudge`) knows when to stop.
  static const newOperation = 'new-operation';

  /// Not an overlay either: counts ⌘K command-dialog opens, so the dialog
  /// knows when to stop offering sample commands on an empty field (see
  /// `CommandDialog._suggestionsThreshold`). Someone who has opened it a
  /// dozen times knows what's in there.
  static const commandDialog = 'command-dialog';
}
