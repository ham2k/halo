// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The per-extension records SettingsService keeps about what is installed
// and what may run — the operator's enable/disable overrides, when each
// disabled one was switched off, which arrived hash-verified from the
// catalog, which the catalog has revoked — and the catalog's own three
// scalars. Every one of them is a TOP-LEVEL pref, outside the `settings.*`
// group system: app infrastructure, not a setting, and being top-level keeps
// them out of the extension-facing getSettings view
// (SettingsService.extensionSettingsGroups only scans group keys). A mixin
// rather than a service of its own so readers keep the one SettingsService
// and the one ChangeNotifier.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'installed_extensions.dart' show CatalogChannel;

mixin ExtensionStoreSettings on ChangeNotifier {
  SharedPreferences get prefs;

  /// A JSON map stored under one prefs key; corrupt or missing data reads as
  /// empty. The base class's reader.
  @protected
  Map<String, dynamic> jsonMapPref(String key);

  /// Per-extension enable/disable overrides ({key: bool}), consulted against
  /// each extension's `enabledByDefault` from the build index (see
  /// ExtensionService.isExtensionEnabled).
  static const _extensionOverridesKey = 'extensionOverrides';

  Map<String, bool> get extensionOverrides => {
    for (final e in jsonMapPref(_extensionOverridesKey).entries)
      if (e.value is bool) e.key: e.value as bool,
  };

  Future<void> setExtensionOverrides(Map<String, bool> overrides) async {
    await prefs.setString(_extensionOverridesKey, jsonEncode(overrides));
    notifyListeners();
  }

  /// The highest version of each pre-loaded extension this app has ever
  /// offered ({key: version}, HALO-581).
  ///
  /// Not "what is installed" — the store answers that. This answers "what
  /// have we already put in front of the operator", which is what makes a
  /// pre-load happen once. Without it, every launch would reinstall over a
  /// catalog update the operator took, and resurrect an extension they
  /// uninstalled. An app upgrade carrying a newer bundle than the recorded
  /// one is the only thing that pre-loads a key a second time.
  ///
  /// Survives an uninstall on purpose: uninstalling is the operator saying
  /// they do not want it, and forgetting that we ever offered it would bring
  /// it back on the next launch.
  static const _extensionPreloadedKey = 'extensionPreloaded';

  Map<String, String> get extensionPreloaded => {
    for (final e in jsonMapPref(_extensionPreloadedKey).entries)
      if (e.value is String) e.key: e.value as String,
  };

  Future<void> setExtensionPreloaded(Map<String, String> preloaded) async {
    await prefs.setString(_extensionPreloadedKey, jsonEncode(preloaded));
    notifyListeners();
  }

  /// Whether this install has moved off the built-ins the app no longer has
  /// onto their catalog copies — carrying each one's on/off choice across —
  /// or never ran them. Set once the move's pre-load has run.
  static const _extensionsMigratedKey = 'extensionsMigrated';

  bool get extensionsMigrated => prefs.getBool(_extensionsMigratedKey) ?? false;

  Future<void> setExtensionsMigrated(bool migrated) async {
    await prefs.setBool(_extensionsMigratedKey, migrated);
    notifyListeners();
  }

  /// Decides, once per install, whether it has a move to make: none for a new
  /// one, which never ran the built-ins; one for an install that predates
  /// this, made at its next catch-up (`catchUpOnCatalogExtensions`).
  ///
  /// Recorded rather than defaulted, like `seedSyncEnabledDefault`, and on
  /// the same signal — so it has to run before onboarding can set a
  /// callsign. The getter's fallback stays false, so an install that ran the
  /// built-ins is never left without its choices carried across.
  Future<void> seedExtensionsMigratedDefault() async {
    if (prefs.containsKey(_extensionsMigratedKey)) return;
    await setExtensionsMigrated(!defaultProfileCallsignDefined);
  }

  bool get defaultProfileCallsignDefined;

  /// Whether this install has had the pre-loaded bundles and built-ins'
  /// twins it held switched off taken out of the store, once
  /// (`catchUpOnCatalogExtensions`). An install can hold every one the app
  /// ships, whatever its switch, and nothing else removes them.
  static const _extensionsSwitchedOffRemovedKey = 'extensionsSwitchedOffRemoved';

  bool get extensionsSwitchedOffRemoved => prefs.getBool(_extensionsSwitchedOffRemovedKey) ?? false;

  Future<void> setExtensionsSwitchedOffRemoved(bool removed) async {
    await prefs.setBool(_extensionsSwitchedOffRemovedKey, removed);
    notifyListeners();
  }

  /// Which catalog twins this app has already fetched for a retired built-in
  /// the operator had switched on ({key: version}).
  ///
  /// The same job [extensionPreloaded] does for the bundles the app ships, for
  /// the ones it has to go and get. Only a twin that landed is recorded: a key
  /// the listing lacked is asked for again, since a listing cannot tell "never
  /// served" from "not published yet".
  ///
  /// Survives an uninstall, for the reason the pre-load record does — taking
  /// an extension away is the operator's decision, not one to undo at boot.
  static const _extensionAdoptedKey = 'extensionAdopted';

  Map<String, String> get extensionAdopted => {
    for (final e in jsonMapPref(_extensionAdoptedKey).entries)
      if (e.value is String) e.key: e.value as String,
  };

  Future<void> setExtensionAdopted(Map<String, String> adopted) async {
    await prefs.setString(_extensionAdoptedKey, jsonEncode(adopted));
    notifyListeners();
  }

  /// The installed extensions that would not evaluate, and the version of
  /// each that failed ({key: version}).
  ///
  /// Keyed by VERSION rather than by key alone: one bundle that will not load
  /// takes the whole runtime down with it, so it has to be kept out of the
  /// set — but the next release of the same extension is a different bundle
  /// and deserves its chance. A catalog that fixes the fault is then picked up
  /// by an ordinary update, with nobody having to notice anything.
  static const _extensionRefusedKey = 'extensionRefused';

  Map<String, String> get extensionRefused => {
    for (final e in jsonMapPref(_extensionRefusedKey).entries)
      if (e.value is String) e.key: e.value as String,
  };

  Future<void> setExtensionRefused(Map<String, String> refused) async {
    await prefs.setString(_extensionRefusedKey, jsonEncode(refused));
    notifyListeners();
  }

  /// When each currently-disabled extension was disabled ({key: epochMillis}).
  /// A disabled extension's downloaded data (data files) is KEPT so a
  /// re-enable is instant; only after it's been disabled for the grace
  /// period does DataFileManager purge that data. Stamped/cleared by
  /// ExtensionService as extensions toggle; an entry vanishes on re-enable.
  static const _extensionDisabledSinceKey = 'extensionDisabledSince';

  Map<String, int> get extensionDisabledSince => {
    for (final e in jsonMapPref(_extensionDisabledSinceKey).entries)
      if (e.value is int) e.key: e.value as int,
  };

  Future<void> setExtensionDisabledSince(Map<String, int> disabledSince) async {
    await prefs.setString(_extensionDisabledSinceKey, jsonEncode(disabledSince));
    notifyListeners();
  }

  /// Where each installed extension's bytes came from, for the ones that
  /// arrived hash-verified from the extension catalog
  /// (`{key: {host, sha256, version}}`, docs/extensions/distribution.md).
  /// The record is what waives the `ham2k-` key refusal for that key on
  /// every read, so it is written ONLY by an install whose bytes matched the
  /// catalog listing's sha256, and any other install of the same key clears
  /// it. Same shape and same top-level placement as [extensionDisabledSince].
  static const _extensionInstalledFromKey = 'extensionInstalledFrom';

  Map<String, Map<String, String>> get extensionInstalledFrom => {
    for (final e in jsonMapPref(_extensionInstalledFromKey).entries)
      if (e.value is Map)
        e.key: {
          for (final f in (e.value as Map).entries)
            if (f.key is String && f.value is String) f.key as String: f.value as String,
        },
  };

  Future<void> setExtensionInstalledFrom(Map<String, Map<String, String>> installedFrom) async {
    await prefs.setString(_extensionInstalledFromKey, jsonEncode(installedFrom));
    notifyListeners();
  }

  /// Every extension the operator has installed, whatever the store holds
  /// right now ({key: name}).
  ///
  /// The operator's intent, kept apart from the store because the store can
  /// be lost while preferences survive — a browser clearing IndexedDB alone,
  /// a data directory deleted by hand, a store that failed mid-session.
  /// Written by every install, removed only by an uninstall (or the operator
  /// choosing Forget), and read as the set to put back: what is here and not
  /// in the store is missing, however it went. The name is kept because the
  /// manifest that carried it may be gone. Where it came from is
  /// [extensionInstalledFrom]'s answer; a key with no record there came from
  /// a file.
  static const _extensionsInstalledKey = 'extensionsInstalled';

  Map<String, String> get extensionsInstalled => {
    for (final e in jsonMapPref(_extensionsInstalledKey).entries)
      if (e.value is String) e.key: e.value as String,
  };

  /// Whether [extensionsInstalled] has ever been written — false on an
  /// install that predates it, which is seeded from the store once.
  bool get extensionsInstalledRecorded => prefs.containsKey(_extensionsInstalledKey);

  Future<void> setExtensionsInstalled(Map<String, String> installed) async {
    await prefs.setString(_extensionsInstalledKey, jsonEncode(installed));
    notifyListeners();
  }

  /// The installed releases the catalog has revoked (`{key: {version, note}}`,
  /// the shape of [extensionDisabledSince]). Its own bit, apart from the
  /// operator's override: a revoked version does not run whatever the
  /// switch says (ExtensionService.isExtensionEnabled), and the record — not
  /// the switch — is what says the operator has already been told. Written
  /// by the update check, cleared by an install of a different version and
  /// by an uninstall.
  static const _extensionRevokedKey = 'extensionRevoked';

  Map<String, Map<String, String>> get extensionRevoked => {
    for (final e in jsonMapPref(_extensionRevokedKey).entries)
      if (e.value is Map && (e.value as Map)['version'] is String)
        e.key: {
          for (final f in (e.value as Map).entries)
            if (f.key is String && f.value is String) f.key as String: f.value as String,
        },
  };

  Future<void> setExtensionRevoked(Map<String, Map<String, String>> revoked) async {
    await prefs.setString(_extensionRevokedKey, jsonEncode(revoked));
    notifyListeners();
  }

  /// When the unattended catalog update check last got an answer, epoch
  /// millis on the REAL clock (docs/design/time.md §1: it persists and
  /// outlives any travel that wrote it). Null until the first answer.
  static const _catalogUpdateCheckedAtKey = 'catalogUpdateCheckedAt';

  int? get catalogUpdateCheckedAt => prefs.getInt(_catalogUpdateCheckedAtKey);

  Future<void> setCatalogUpdateCheckedAt(int millis) => prefs.setInt(_catalogUpdateCheckedAtKey, millis);

  /// An extension catalog other than `catalog.ham2k.net` — a local one, for
  /// working on the catalog itself. Honoured by CatalogService only under
  /// `developerMode`, the same gate as `extensionDevServerUrl` and for the
  /// same reason: bundles are code the app will run, and the trusted host is
  /// baked in. Empty means the real catalog. Never ends in a slash, on the
  /// way in or out: the paths joined onto it start with one, and
  /// `//api/v1/...` is a request the catalog answers 404.
  static const _catalogBaseUrlKey = 'catalogBaseUrl';

  String get catalogBaseUrl => _normalizeCatalogBaseUrl(prefs.getString(_catalogBaseUrlKey) ?? '');

  Future<void> setCatalogBaseUrl(String url) async {
    await prefs.setString(_catalogBaseUrlKey, _normalizeCatalogBaseUrl(url));
    notifyListeners();
  }

  static String _normalizeCatalogBaseUrl(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

  /// The roughest channel the catalog listing is asked for — Settings →
  /// Developer → Extension Catalog's "Catalog Search Tracks". Honoured by
  /// CatalogService only under `developerMode`, like [catalogBaseUrl]: turning
  /// developer mode off returns the panel to stable releases, while every
  /// install already on a rougher track keeps following it.
  static const _catalogSearchChannelKey = 'catalogSearchChannel';

  CatalogChannel get catalogSearchChannel => CatalogChannel.tryParse(prefs.getString(_catalogSearchChannelKey)) ?? CatalogChannel.stable;

  Future<void> setCatalogSearchChannel(CatalogChannel channel) async {
    await prefs.setString(_catalogSearchChannelKey, channel.name);
    notifyListeners();
  }

  /// Drops every per-extension record of [key]. Does NOT notify: the caller,
  /// SettingsService.forgetExtension, notifies once after the extension's
  /// settings values have gone too.
  @protected
  Future<void> forgetExtensionRecords(String key) async {
    final overrides = extensionOverrides;
    if (overrides.remove(key) != null) {
      await prefs.setString(_extensionOverridesKey, jsonEncode(overrides));
    }
    // Otherwise a reinstall inherits a disabled-since stamp from an extension
    // that no longer exists, and the data purge counts from the wrong day.
    final disabledSince = extensionDisabledSince;
    if (disabledSince.remove(key) != null) {
      await prefs.setString(_extensionDisabledSinceKey, jsonEncode(disabledSince));
    }
    await _dropInstallRecords({key});
  }

  /// Drops what records [keys] as installed, and keeps what the operator set
  /// for each — its override and disabled-since stamp here, its settings and
  /// credentials elsewhere — for bundles taken out of the store that are not
  /// being uninstalled: should one come back, it comes back as they left it.
  /// Where each came from goes too, its release track with it: left behind,
  /// the record waives the `ham2k-` refusal for a file claiming the key.
  /// Each record is written once, and listeners told once, however many go.
  Future<void> forgetExtensionInstalls(Set<String> keys) async {
    await _dropInstallRecords(keys);
    notifyListeners();
  }

  Future<void> _dropInstallRecords(Set<String> keys) async {
    // Every key, not `keys.any`: that stops at the first one it removes.
    bool dropped(Map<String, Object?> records) {
      var changed = false;
      for (final key in keys) {
        if (records.remove(key) != null) changed = true;
      }
      return changed;
    }

    // Otherwise a reinstall of the same version lands inert, and
    // uninstall-and-reinstall is the operator's only repair for the corrupt
    // download the attempt limit exists to absorb.
    final refused = extensionRefused;
    if (dropped(refused)) {
      await prefs.setString(_extensionRefusedKey, jsonEncode(refused));
    }
    // Left behind, the record would waive the `ham2k-` refusal for whatever
    // bundle next claims this key from a file.
    final installedFrom = extensionInstalledFrom;
    if (dropped(installedFrom)) {
      await prefs.setString(_extensionInstalledFromKey, jsonEncode(installedFrom));
    }
    // Otherwise the next launch reads it as missing and offers it back.
    final installed = extensionsInstalled;
    if (dropped(installed)) {
      await prefs.setString(_extensionsInstalledKey, jsonEncode(installed));
    }
    // The revocation was of a version that is no longer here; kept, it would
    // silently refuse a reinstall of that version with nothing to say why.
    final revoked = extensionRevoked;
    if (dropped(revoked)) {
      await prefs.setString(_extensionRevokedKey, jsonEncode(revoked));
    }
  }
}
