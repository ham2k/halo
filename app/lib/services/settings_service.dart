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

import '../config/dev_flags.dart';
import '../config/device_identity.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../config/user_agent.dart';
import 'error_reporting_service.dart';
import 'extensions/extension_store_settings.dart';
import 'cw_message_set.dart';
import 'onboarding_flows.dart';

// Importers of this file name a flow in the same breath as the calls that
// take one.
export 'onboarding_flows.dart';
export 'cw_message_set.dart';

const _uuidGenerator = Uuid();

/// The theme mode the light/dark toggle (⌘⇧D) switches to: always the opposite
/// of what's currently on screen, resolving [ThemeMode.system] against the
/// current [platformBrightness] so the first press flips what the user sees.
ThemeMode toggledThemeMode(ThemeMode current, Brightness platformBrightness) {
  final showingDark = current == ThemeMode.dark || (current == ThemeMode.system && platformBrightness == Brightness.dark);
  return showingDark ? ThemeMode.light : ThemeMode.dark;
}

class SettingsService extends ChangeNotifier with ExtensionStoreSettings implements SyncSettings {
  static const _themeModeKey = 'themeMode';
  static const _profilesKey = 'profiles';
  static const _activeProfileKey = 'activeProfile';
  static const _syncEnabledKey = 'syncEnabled';
  static const _syncDeviceKeyKey = 'syncDeviceKey';
  static const _syncStateKey = 'syncState';
  static const _developerModeKey = 'developerMode';
  static const _extensionDevServerUrlKey = 'extensionDevServerUrl';
  static const _extensionDevServerEnabledKey = 'extensionDevServerEnabled';
  static const _catTrafficLogPathKey = 'catTrafficLogPath';
  static const _catTrafficLogResumeKey = 'catTrafficLogResume';
  static const _automaticUpdateChecksKey = 'automaticUpdateChecks';
  static const _localeKey = 'locale';
  static const _fontScaleKey = 'fontScale';
  static const _keepDeviceAwakeKey = 'keepDeviceAwake';
  static const _homeNavExpandedKey = 'homeNavExpanded';
  static const _layoutDensityKey = 'layoutDensity';
  static const _mapStyleKey = 'mapStyle';
  static const _postcardShapeKey = 'postcardShape';
  static const _postcardMapStyleKey = 'postcardMapStyle';
  static const _postcardSectionsKey = 'postcardSections';
  static const _secondaryControlsOrderKey = 'secondaryControlsOrder';
  static const _hiddenSecondaryControlsKey = 'hiddenSecondaryControls';
  static const _showRSTFieldsKey = 'showRSTFields';
  static const _showStateFieldKey = 'showStateField';
  static const _showGridFieldKey = 'showGridField';
  static const _showDeletedQSOsKey = 'showDeletedQSOs';
  static const _showQsoNumbersKey = 'showQsoNumbers';
  static const _distanceUnitsKey = 'distanceUnits';
  static const _numberFormatKey = 'numberFormat';
  static const _gridPrecisionKey = 'gridPrecision';
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

  @override
  SharedPreferences get prefs => _prefs;

  /// How long a locator is shown is one process-wide answer that every
  /// package reads out of [GridPrecision], for the same reason
  /// [NumberFormatting] is a singleton: two surfaces disagreeing would put
  /// one station in two squares of different sizes on one screen.
  ///
  /// Pushed from HERE, on every notify, rather than from a listener
  /// somewhere: a settings restore, a sync pull and the Settings picker all
  /// reach the store by different routes and only this one is common to
  /// them. Ahead of `super`, so a listener rebuilding on this very
  /// notification already reads the new answer.
  ///
  /// halo_core can resolve this itself — unlike Number Formatting it needs
  /// neither the device locale nor ICU — but it must not READ settings, so
  /// the value is pushed rather than pulled.
  @override
  void notifyListeners() {
    GridPrecision.configure(gridPrecision);
    super.notifyListeners();
  }

  static Future<SettingsService> load() async {
    final settings = SettingsService(await SharedPreferences.getInstance());
    // The very first frame formats locators correctly, rather than repainting
    // once something happens to change a setting.
    GridPrecision.configure(settings.gridPrecision);
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
  static const exportsGroup = 'exports';
  static const radioGroup = 'radio';
  static const stationInfoGroup = 'stationInfo';

  String _groupPrefsKey(String group) => 'settings.$group';

  Map<String, dynamic> settingsGroup(String group) => jsonMapPref(_groupPrefsKey(group));

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
        if (prefsKey.startsWith(prefix)) prefsKey.substring('settings.'.length): jsonMapPref(prefsKey),
    };
  }

  /// Copies every prefs-side record of [from] onto [to], leaving [from]
  /// untouched — the halves of an extension's identity that live outside the
  /// keychain (ExtensionService.copyExtensionSecrets does the rest).
  ///
  /// For an extension that changed its key rather than its code: the
  /// catalog's `ham2k-pota` is the built-in `pota` under a name the catalog
  /// can serve (HALO-581), and an operator who has set it up should not have
  /// to do so again. Copied rather than moved, so turning the experiment
  /// back off finds the built-in exactly as it was.
  ///
  /// A value already stored under [to] wins: this runs once per key, but
  /// "once" is a record that could be lost, and overwriting a choice the
  /// operator made under the NEW key with one they made under the old is the
  /// worse mistake.
  Future<void> copyExtensionRecords({required String from, required String to}) async {
    final group = _prefs.getString('settings.extension_$from');
    if (group != null && _prefs.getString('settings.extension_$to') == null) {
      await _prefs.setString('settings.extension_$to', group);
    }
    // A panel's key is the extension's own or prefixed with it, which is what
    // makes the leading segment safe to rewrite.
    for (final prefsKey in _prefs.getKeys().toList()) {
      String? moved;
      if (prefsKey.startsWith('settingsPanel.$from.')) {
        moved = 'settingsPanel.$to.${prefsKey.substring('settingsPanel.$from.'.length)}';
      } else if (prefsKey.startsWith('settingsPanel.${from}_')) {
        moved = 'settingsPanel.${to}_${prefsKey.substring('settingsPanel.${from}_'.length)}';
      }
      if (moved == null || _prefs.get(moved) != null) continue;
      final value = _prefs.get(prefsKey);
      if (value is String) await _prefs.setString(moved, value);
      if (value is bool) await _prefs.setBool(moved, value);
      if (value is int) await _prefs.setInt(moved, value);
      if (value is double) await _prefs.setDouble(moved, value);
      if (value is List<String>) await _prefs.setStringList(moved, value);
    }
    final overrides = extensionOverrides;
    if (overrides.containsKey(from) && !overrides.containsKey(to)) {
      await setExtensionOverrides({...overrides, to: overrides[from]!});
    }
    notifyListeners();
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
    await forgetExtensionRecords(key);
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

  Map<String, dynamic> get _profilesData => jsonMapPref(_profilesKey);

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
  @override
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
        profileId: {..._profile(profileId).data, for (final entry in fields.entries) entry.key: entry.value.trim()},
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
    final deviceName = resolvedDeviceIdentity?.name ?? '';
    final device = deviceName.isNotEmpty ? deviceName : platformName();
    return call.isEmpty ? device : '$call ($device)';
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
    // A dev data sandbox is NOT a fresh install, however empty it looks. The
    // keychain is keyed by bundle id and nothing sandboxes it, so this
    // launch holds the developer's real sync device key — defaulting an
    // empty log to sync-on would point it at their actual account, with two
    // processes claiming one device key. Off unless they ask for it; the
    // setting is theirs to turn on once they know which log they are in.
    if (devDataDirectory.isNotEmpty) return setSyncEnabled(false);
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
  @override
  Map<String, dynamic> jsonMapPref(String key) {
    try {
      // getString INSIDE the try, not before it: it is a cast over the
      // plugin's cache, so a prefs file holding a number (or an object) under
      // this key throws a TypeError rather than returning null — and this is
      // read during CatService's construction, where nothing catches.
      final raw = _prefs.getString(key);
      if (raw == null || raw.isEmpty) return const {};
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return const {};
    }
  }

  /// Free-form sync bookkeeping (last-synced account uuid, server-tunable
  /// overrides) — see the design note in DESIGN.md §6: this is a handful of
  /// scalars, not per-row data, so it lives here rather than in a drift
  /// table.
  Map<String, dynamic> get syncState => jsonMapPref(_syncStateKey);

  Future<void> setSyncState(Map<String, dynamic> state) async {
    await _prefs.setString(_syncStateKey, jsonEncode(state));
    notifyListeners();
  }

  /// The Spots Panel's persisted band/mode/age/sources/continents/sort/
  /// group filters — device-wide, like [syncState], for the same reason:
  /// a handful of viewing-preference scalars, not per-row data.
  Map<String, dynamic> get spottingFilters => jsonMapPref(_spottingFiltersKey);

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
  Map<String, dynamic> get stationEquipment => jsonMapPref(_stationEquipmentKey);

  Future<void> setStationEquipment(Map<String, dynamic> equipment) async {
    await _prefs.setString(_stationEquipmentKey, jsonEncode(equipment));
    notifyListeners();
  }

  /// Per-experiment state, keyed by the experiment key from experiments.yaml:
  /// `{enabled: bool, firstEnabledAtMillis: int, lastDisabledAtMillis: int}`.
  /// Entries whose definition has since left the catalog are deliberately
  /// KEPT (never pruned) — a returning experiment picks its old state up.
  Map<String, dynamic> get experimentStates => jsonMapPref(_experimentsKey);

  bool experimentEnabled(String key) {
    final state = experimentStates[key];
    return state is Map && state['enabled'] == true;
  }

  /// Whether [key] has been enabled at some point, on or off now — what
  /// admits a private experiment to the Experiments list: EXP revealed it
  /// once, so the switch to turn it back on stays reachable.
  bool experimentEverEnabled(String key) {
    final state = experimentStates[key];
    return state is Map && state['firstEnabledAtMillis'] != null;
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
    if (key == 'esm' /* stored key, see experiments.yaml */ && enabled) await _offerEsmMessageSet();
  }

  /// Adds [CwMessageSet.esm] and makes it the one in use, the first time
  /// Enter Sends Messages is turned on — ever, not each time: a set the
  /// operator renamed, edited or deleted is theirs, and re-enabling the
  /// experiment must not put a second copy beside it or undo the deletion.
  /// In use because ESM keys by position, and the set in use before it was
  /// laid out for keying by hand.
  Future<void> _offerEsmMessageSet() async {
    if (settingValue(radioGroup, 'esmMessageSetOffered') == true) return;
    final sets = cwMessageSets;
    final esm = CwMessageSet.esm();
    final taken = sets.any((set) => set.name == esm.name);
    await updateSettingsGroup(radioGroup, {
      'esmMessageSetOffered': true,
      if (!taken)
        cwMessageSetsKey: [
          for (final set in [...sets, esm]) set.toJson(),
        ],
      if (!taken) cwMessageSetKey: esm.name,
    });
  }

  /// Per-flow onboarding state, keyed by flow id ([OnboardingFlows]):
  /// `{shownCount: int, firstShownAtMillis: int, lastShownAtMillis: int}`.
  /// "Shown" is flow-specific — for a flow that gates a UI overlay
  /// (`OnboardingFlows.firstUse`, `.operationSheet`) it's a real display of
  /// that overlay; for one that just counts an outcome the flow is nudging
  /// toward (`.newOperation` counts operations opened, not times a nudge
  /// showed) it's whatever [recordOnboardingShown] is called for. A missing
  /// entry reads as never shown (count 0).
  Map<String, dynamic> get onboardingStates => jsonMapPref(_onboardingKey);

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
        OnboardingFlows.firstUse: {'shownCount': 1, 'firstShownAtMillis': now, 'lastShownAtMillis': now},
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
    final value = (_layoutCache ??= jsonMapPref(_layoutKey))[key];
    return value is num ? value.toDouble() : null;
  }

  Future<void> setLayoutDimension(String key, double value) => _setLayoutValue(key, value);

  /// A structured layout value (the dock-layout prototype's arrangement
  /// tree) riding in the same per-key layout map as the scalar dimensions.
  Map<String, dynamic>? layoutData(String key) {
    final value = (_layoutCache ??= jsonMapPref(_layoutKey))[key];
    return value is Map<String, dynamic> ? value : null;
  }

  Future<void> setLayoutData(String key, Map<String, dynamic> value) => _setLayoutValue(key, value);

  /// The one writer of the layout map: cache first (build methods read the
  /// cache synchronously), then persist the whole map, then notify.
  Future<void> _setLayoutValue(String key, Object value) async {
    final updated = {...(_layoutCache ??= jsonMapPref(_layoutKey)), key: value};
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

  /// A DEVLOGCAT recording as the next launch should find it: its file, and
  /// whether that launch resumes it or sends it. Null when nothing is
  /// recording. No listeners are told — nothing on screen shows it.
  ({String path, bool resume})? get catTrafficLogCarry {
    final path = _prefs.getString(_catTrafficLogPathKey);
    if (path == null || path.isEmpty) return null;
    return (path: path, resume: _prefs.getBool(_catTrafficLogResumeKey) ?? false);
  }

  Future<void> setCatTrafficLogCarry(String? path, {bool resume = false}) async {
    if (path == null) {
      await _prefs.remove(_catTrafficLogPathKey);
      await _prefs.remove(_catTrafficLogResumeKey);
      return;
    }
    await _prefs.setString(_catTrafficLogPathKey, path);
    await _prefs.setBool(_catTrafficLogResumeKey, resume);
  }

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

  /// Whether the device is held awake while the operator is on the logging
  /// view or a sync is making progress — see `WakeLockService`, which is
  /// what actually holds it and lets go after fifteen idle minutes. Off by
  /// default, like PoLo: keeping a screen lit is a battery decision the
  /// operator makes.
  bool get keepDeviceAwake => (settingValue(generalGroup, _keepDeviceAwakeKey) as bool?) ?? false;

  Future<void> setKeepDeviceAwake(bool value) => setSettingValue(generalGroup, _keepDeviceAwakeKey, value);

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

  Future<void> setHomeNavExpanded(bool value) => setSettingValue(generalGroup, _homeNavExpandedKey, value);

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

  /// Whether the Operation Details dialog offers the operator's own callsign
  /// as the operator of an operation running under a DIFFERENT station call —
  /// a club station, a special event, a callsign borrowed for a contest. On by
  /// default (app-polo's `suggestDefaultOperator`), because the operator at
  /// the key is nearly always whoever set the operation up; off for the club
  /// secretary who creates the operations and does not operate them.
  bool get suggestDefaultOperator => _loggingBool('suggestDefaultOperator', true);

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

  Future<void> setUseCompactFileNames(bool value) => setSettingValue(exportsGroup, 'useCompactFileNames', value);

  /// Whether exports may carry the operator's private notes about the stations
  /// they worked — names, towns, gridsquares, QSO notes.
  ///
  /// Off by default, because most exports exist to be UPLOADED: a park's log
  /// goes to POTA's servers, a Cabrillo to a contest sponsor, and neither has
  /// any business with the operator's notes about who they met. The whole-log
  /// ADIF backup is exempt — it declares `alwaysIncludePrivateData`, since
  /// being complete is the whole point of it.
  bool get includePrivateData => (settingValue(exportsGroup, 'includePrivateData') as bool?) ?? false;

  Future<void> setIncludePrivateData(bool value) => setSettingValue(exportsGroup, 'includePrivateData', value);

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

  /// How many CW messages there are: one per function key F1-F8.
  static const cwMessageCount = 8;

  /// The stored key of message [n] (1-based) — also its settings field key.
  /// It addresses a message WITHIN the active set: the sets are the storage
  /// (`cwMessageSets`), and these keys are what Settings and SET name a
  /// message by, so both surfaces move with the set the operator picked.
  static String cwMessageKey(int n) => 'cwMessage$n';

  /// Liquid templates (docs/extensions/templates.md), one per function
  /// key, keyed through the radio's CAT keyer. Empty means the key does
  /// nothing. One set for the app rather than per operation: the
  /// placeholders are what make the same eight messages serve a POTA
  /// activation and a contest alike.
  String cwMessage(int n) => activeCwMessageSet.message(n);

  Future<void> setCwMessage(int n, String value) => _editActiveCwMessageSet((set) => set.withMessage(n, value));

  /// An optional name for message [n] — what the editor's row shows beside
  /// the key, since a template is not always readable at a glance.
  static String cwMessageLabelKey(int n) => 'cwMessageLabel$n';

  String cwMessageLabel(int n) => activeCwMessageSet.label(n);

  Future<void> setCwMessageLabel(int n, String value) => _editActiveCwMessageSet((set) => set.withLabel(n, value));

  /// The stored key of the SETS, and of the name of the one in use. Both in
  /// the radio group, beside everything else the keyer reads.
  static const cwMessageSetsKey = 'cwMessageSets';
  static const cwMessageSetKey = 'cwMessageSet';

  /// Every set the operator has, in the order they are offered. Never empty:
  /// an install with nothing stored is answered with the seeds, and one whose
  /// F1-F8 were written before sets existed keeps them as a set of their own
  /// ([CwMessageSet.seeded]) rather than losing them to the seeds.
  ///
  /// Derived rather than persisted at startup: a getter that seeds and a
  /// setter that writes cannot disagree, while a migration that runs once at
  /// launch fails silently on the install where it threw.
  List<CwMessageSet> get cwMessageSets {
    final stored = settingValue(radioGroup, cwMessageSetsKey);
    if (stored is List && stored.isNotEmpty) {
      final sets = [
        for (final entry in stored)
          if (entry is Map) CwMessageSet.fromJson(entry.cast<String, dynamic>()),
      ];
      if (sets.isNotEmpty) return sets;
    }
    return CwMessageSet.seeded(_legacyCwMessageSet());
  }

  /// The pre-sets messages as a set, or null when there were none — every
  /// field empty is an install that never wrote one, not a set of blanks.
  CwMessageSet? _legacyCwMessageSet() {
    final messages = [for (var n = 1; n <= cwMessageCount; n++) (settingValue(radioGroup, cwMessageKey(n)) as String?) ?? ''];
    final labels = [for (var n = 1; n <= cwMessageCount; n++) (settingValue(radioGroup, cwMessageLabelKey(n)) as String?) ?? ''];
    if (messages.every((text) => text.trim().isEmpty)) return null;
    return CwMessageSet(name: t.settings.radio.cwMessages.setSaved, messages: messages, labels: labels);
  }

  /// The name of the set F1-F8 key. Falls back to the first set rather than
  /// to a name: a stored name whose set was renamed away would otherwise
  /// leave the keys with nothing to send.
  String get cwMessageSetName {
    final sets = cwMessageSets;
    final stored = settingValue(radioGroup, cwMessageSetKey) as String?;
    if (stored != null && sets.any((set) => set.name == stored)) return stored;
    return sets.first.name;
  }

  CwMessageSet get activeCwMessageSet {
    final name = cwMessageSetName;
    return cwMessageSets.firstWhere((set) => set.name == name, orElse: () => cwMessageSets.first);
  }

  /// Writes the sets and, when given, which one is in use — one write, so a
  /// pick that arrives with edits cannot land half-applied.
  Future<void> setCwMessageSets(List<CwMessageSet> sets, {String? active}) async {
    if (sets.isEmpty) return;
    final name = active != null && sets.any((set) => set.name == active) ? active : sets.first.name;
    await updateSettingsGroup(radioGroup, {
      cwMessageSetsKey: [for (final set in sets) set.toJson()],
      cwMessageSetKey: name,
    });
  }

  Future<void> _editActiveCwMessageSet(CwMessageSet Function(CwMessageSet) edit) {
    final name = cwMessageSetName;
    final sets = [for (final set in cwMessageSets) set.name == name ? edit(set) : set];
    return setCwMessageSets(sets, active: name);
  }

  /// The delays message 1 may repeat at, in seconds — `'0'` being off.
  /// Strings, like every other option list here, so a stored value names an
  /// item of the picker that set it.
  static const cwRepeatDelayOptions = ['0', '2', '3', '4', '5', '6', '7', '8', '9', '10'];

  /// How long after message 1 finishes keying before it goes again, or
  /// [Duration.zero] for no repeat. Only message 1 repeats: it is the CQ,
  /// and a repeating exchange or report would key over the contact it is
  /// answering (docs/design/cat.md § CW keying).
  Duration get cwRepeatDelay => Duration(seconds: int.tryParse((settingValue(radioGroup, 'cwRepeatDelay') as String?) ?? '') ?? 0);

  Future<void> setCwRepeatDelay(int seconds) => setSettingValue(radioGroup, 'cwRepeatDelay', '$seconds');

  /// How many voice memory labels there are: one per function key, like
  /// the CW messages — the most any radio here has (an Icom's T1-T8). A
  /// radio with fewer shows fewer; the labels past its count keep.
  static const voiceMessageCount = 8;

  /// The name shown for the radio's voice memory [n] (1-based) — its
  /// button in the keyer area and its row in the Phone Keyer dialog.
  /// A label and nothing more: the audio lives in the radio, which is why
  /// there is no `voiceMessage$n` beside it.
  static String voiceMessageLabelKey(int n) => 'voiceMessageLabel$n';

  String voiceMessageLabel(int n) => (settingValue(radioGroup, voiceMessageLabelKey(n)) as String?) ?? '';

  Future<void> setVoiceMessageLabel(int n, String value) => setSettingValue(radioGroup, voiceMessageLabelKey(n), value);

  /// How long memory [n] plays for, in MILLISECONDS — timed off the radio's
  /// own end-of-play report (CatService.playVoiceMemory), never guessed.
  /// Zero means unmeasured, which is what a memory stays until it is played
  /// once. Milliseconds rather than seconds because the measurement has
  /// them: a 4.2-second memory rounded to 5 paces a progress bar that
  /// finishes late every time.
  static String voiceMessageDurationKey(int n) => 'voiceMessageDurationMs$n';

  int voiceMessageDuration(int n) => (settingValue(radioGroup, voiceMessageDurationKey(n)) as num?)?.round() ?? 0;

  Future<void> setVoiceMessageDuration(int n, int millis) => setSettingValue(radioGroup, voiceMessageDurationKey(n), millis);

  /// Whether the logging panel's keyer area is showing. A setting rather
  /// than session state: an operator who opened the strip wants it there
  /// tomorrow too, and one who closed it does not want it back at the next
  /// launch.
  bool get keyerAreaShown => settingValue(radioGroup, 'keyerAreaShown') == true;

  Future<void> setKeyerAreaShown(bool value) => setSettingValue(radioGroup, 'keyerAreaShown', value);

  /// Enter Sends Messages (docs/design/logging-fields.md § Enter Sends
  /// Messages): whether Enter keys the exchange's messages, and whether the
  /// operator is running (the default — ESM's home ground) or searching and
  /// pouncing. Device-wide like the keyer area: they describe how this
  /// operator works the radio, not one operation.
  bool get enterSendsMessages => settingValue(radioGroup, 'enterSendsMessages') == true;
  bool get enterSendsRunning => settingValue(radioGroup, 'enterSendsRunning') != false;

  Future<void> setEnterSends({required bool on, required bool running}) =>
      updateSettingsGroup(radioGroup, {'enterSendsMessages': on, 'enterSendsRunning': running});

  /// The voice counterpart of [cwRepeatDelay], and the same rule: only
  /// memory 1 repeats, because it is the CQ.
  Duration get voiceRepeatDelay => Duration(seconds: int.tryParse((settingValue(radioGroup, 'voiceRepeatDelay') as String?) ?? '') ?? 0);

  Future<void> setVoiceRepeatDelay(int seconds) => setSettingValue(radioGroup, 'voiceRepeatDelay', '$seconds');

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
  Duration get smartVfoSnapDebounce => Duration(milliseconds: _radioNumber('smartVfoSnapDebounceMs', smartVfoSnapDebounceOptions, '300').round());

  double get smartVfoSnapLongMoveKHz => _radioNumber('smartVfoSnapLongMoveKHz', smartVfoSnapLongMoveOptions, '2');

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
  bool get includeStationInfoInAdif => (settingValue(stationInfoGroup, 'includeStationInfoInAdif') as bool?) ?? false;

  Future<void> setIncludeStationInfoInAdif(bool value) => setSettingValue(stationInfoGroup, 'includeStationInfoInAdif', value);

  /// Which of `rig`/`power`/`antenna`/`key` to record. Defaults to just the
  /// two most operators already have exactly one of — antenna and key are
  /// opt-in, since tracking them means adding them to the inventory first.
  static const defaultStationInfoTrackedFields = ['rig', 'power'];

  Set<String> get stationInfoTrackedFields {
    final value = settingValue(stationInfoGroup, 'trackedFields');
    return value is List ? value.whereType<String>().toSet() : defaultStationInfoTrackedFields.toSet();
  }

  Future<void> setStationInfoTrackedFields(Set<String> fields) => setSettingValue(stationInfoGroup, 'trackedFields', fields.toList());

  /// The power the operator was running, in watts, from before power moved
  /// onto the VFO ([Vfo.power], persisted by `RadioService`). Read once, by
  /// the migration in `HaLoServices._buildRadioService`, and never written
  /// again — kept rather than deleted so an upgrade doesn't silently forget
  /// a stated power. Null means unset, not zero.
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

  /// Key and alias are app-polo's (`showDeletedOps` / `deletedOps`).
  bool get showDeletedOps => _loggingBool('showDeletedOps', false);

  bool get showQsoNumbers => _loggingBool(_showQsoNumbersKey, true);

  Future<void> setShowQsoNumbers(bool value) => setSettingValue(loggingGroup, _showQsoNumbersKey, value);

  // Logging settings, defaults matching app-polo.
  bool get leftieMode => _loggingBool('leftieMode', false);
  bool get showBearing => _loggingBool('showBearing', false);

  /// Renders a bearing as "45° / 225°" — the great-circle bearing back to
  /// us, which is not simply +180° on a long path. Read only while
  /// [showBearing] is on; the registry offers it only then.
  bool get showReverseBearing => _loggingBool('showReverseBearing', false);

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

  /// Privacy consents. The fallback here is false, but that is not the same
  /// as "off for operators": onboarding shows `consentAppData` PRE-CHECKED
  /// and writes it on finish either way, so in the field it behaves as
  /// opt-out — see docs/design/telemetry.md § Privacy model before putting
  /// anything new behind it. `consentOpData` really is off unless asked for.
  /// Same keys as app-polo
  /// (`consentAppData`/`consentOpData`) for cross-app parity. Distribution
  /// builds gate their telemetry on these; in the OSS app `MetricsService`
  /// is a no-op, but the gate itself is not dead code —
  /// `HaLoServices.reportWorkingRadio` reads `consentAppData` directly.
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

  Future<void> setNumberFormatStyle(NumberFormatStyle style) => setSettingValue(generalGroup, _numberFormatKey, style.name);

  /// How many characters a locator is shown with, app-wide — see
  /// [GridPrecision], which is where the resolved answer lives.
  /// [GridPrecision.six] by default: a 6-character square is what an operator
  /// puts on the air, and eight states a position to a few hundred metres.
  GridPrecision get gridPrecision {
    final value = settingValue(generalGroup, _gridPrecisionKey);
    for (final precision in GridPrecision.values) {
      if (precision.name == value) return precision;
    }
    return GridPrecision.six;
  }

  Future<void> setGridPrecision(GridPrecision precision) => setSettingValue(generalGroup, _gridPrecisionKey, precision.name);

  /// The operator's Layout Density choice. [DensityPreference.auto] by
  /// default, which is what makes the height ladder the normal behaviour and
  /// an explicit pick the exception.
  DensityPreference get densityPreference {
    final value = settingValue(generalGroup, _layoutDensityKey);
    return DensityPreference.values.firstWhere((e) => e.name == value, orElse: () => DensityPreference.auto);
  }

  Future<void> setDensityPreference(DensityPreference preference) => setSettingValue(generalGroup, _layoutDensityKey, preference.name);

  /// The MapLibre basemap choice (see map_panel.dart). [MapStyle.automatic]
  /// by default, which keeps the existing light/dark-aware basemap; any
  /// other value pins one style regardless of the app's theme.
  MapStyle get mapStyle {
    final value = settingValue(generalGroup, _mapStyleKey);
    return MapStyle.values.firstWhere((e) => e.name == value, orElse: () => MapStyle.automatic);
  }

  Future<void> setMapStyle(MapStyle style) => setSettingValue(generalGroup, _mapStyleKey, style.name);

  /// The Operation Postcard's last shape, by `PostcardShape` name
  /// (operation_postcard.dart) — null until the operator picks one.
  String? get postcardShape => asQsonString(settingValue(generalGroup, _postcardShapeKey));

  Future<void> setPostcardShape(String shape) => setSettingValue(generalGroup, _postcardShapeKey, shape);

  /// The Operation Postcard's last map style — null until the operator picks
  /// one, and the postcard starts in Liberty. Kept apart from [mapStyle]: a
  /// postcard in Dark Matter is no reason to log over one.
  MapStyle? get postcardMapStyle {
    final value = settingValue(generalGroup, _postcardMapStyleKey);
    return MapStyle.values.where((e) => e.name == value).firstOrNull;
  }

  Future<void> setPostcardMapStyle(MapStyle style) => setSettingValue(generalGroup, _postcardMapStyleKey, style.name);

  /// The Operation Postcard's summary sections as last picked, by section key
  /// (`PostcardSummarySection.key`): in [order], less the [hidden] ones. Both
  /// empty until the operator picks, which is every section in its own order.
  ({List<String> order, Set<String> hidden}) get postcardSections {
    final value = settingValue(generalGroup, _postcardSectionsKey);
    List<String> strings(Object? list) => list is List ? list.whereType<String>().toList() : const [];
    return value is Map ? (order: strings(value['order']), hidden: strings(value['hidden']).toSet()) : (order: const [], hidden: const {});
  }

  Future<void> setPostcardSections(List<String> order, Set<String> hidden) =>
      setSettingValue(generalGroup, _postcardSectionsKey, {'order': order, 'hidden': hidden.toList()});

  /// Forgets every pick, this operation's and every other's.
  Future<void> clearPostcardSections() => setSettingValue(generalGroup, _postcardSectionsKey, null);
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
  /// live `leftColumn` beside it: Home's split IS the dock's, and the dock
  /// carries its own weights.
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

  /// The Logs QSO table's sort: `column`, one of its column ids, and
  /// `ascending`. Absent, the table runs newest first.
  static const logsQsoSort = 'logs.qsoSort';

  /// The Logs destination's last pick in its callsign picker, for the next
  /// visit to open on: `call`, a station callsign, or null for All.
  static const logsFilter = 'logs.filter';
}
