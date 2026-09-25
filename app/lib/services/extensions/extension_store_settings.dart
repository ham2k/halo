// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The per-extension records SettingsService keeps about what is installed
// and what may run — the operator's enable/disable overrides, when each
// disabled one was switched off, which arrived hash-verified from the
// catalog, which the catalog has revoked — and the catalog's own two
// scalars. Every one of them is a TOP-LEVEL pref, outside the `settings.*`
// group system: app infrastructure, not a setting, and being top-level keeps
// them out of the extension-facing getSettings view
// (SettingsService.extensionSettingsGroups only scans group keys). A mixin
// rather than a service of its own so readers keep the one SettingsService
// and the one ChangeNotifier.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/experiments.dart';

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

  /// Whether this install has moved its extensions to the catalog.
  ///
  /// Separate from the experiment, which only says the upgrade is OFFERED.
  /// Nothing is withdrawn until this is true, so an operator who defers the
  /// upgrade — or who is offline when it is offered — keeps every extension
  /// they had. Set only once the twins are in hand.
  static const _extensionsMigratedKey = 'extensionsMigrated';

  bool get extensionsMigrated => prefs.getBool(_extensionsMigratedKey) ?? false;

  Future<void> setExtensionsMigrated(bool migrated) async {
    await prefs.setBool(_extensionsMigratedKey, migrated);
    notifyListeners();
  }

  /// Whether the catalog is where this app's extensions come from NOW — the
  /// one question every withdrawal, pre-load and adoption asks.
  ///
  /// Both halves: the experiment says the upgrade is on offer here, and
  /// [extensionsMigrated] says it was taken. Turning the experiment off puts
  /// the built-ins back without forgetting that the upgrade happened, so
  /// turning it on again does not re-run it.
  bool get catalogExtensionsInUse => experimentEnabled(kCatalogExperiment) && extensionsMigrated;

  bool experimentEnabled(String key);

  /// Which catalog twins this app has already fetched for a built-in the
  /// operator had switched on ({key: version}), when the catalog experiment
  /// withdrew the built-ins.
  ///
  /// The same job [extensionPreloaded] does for the bundles the app ships, for
  /// the ones it has to go and get. An empty value records a key the catalog
  /// does not serve: it is still an answer, and re-asking every launch is a
  /// request per built-in per boot for something that will not appear.
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
    // Otherwise a reinstall of the same version lands inert, and
    // uninstall-and-reinstall is the operator's only repair for the corrupt
    // download the attempt limit exists to absorb.
    final refused = extensionRefused;
    if (refused.remove(key) != null) {
      await prefs.setString(_extensionRefusedKey, jsonEncode(refused));
    }
    // Left behind, the record would waive the `ham2k-` refusal for whatever
    // bundle next claims this key from a file.
    final installedFrom = extensionInstalledFrom;
    if (installedFrom.remove(key) != null) {
      await prefs.setString(_extensionInstalledFromKey, jsonEncode(installedFrom));
    }
    // The revocation was of a version that is no longer here; kept, it would
    // silently refuse a reinstall of that version with nothing to say why.
    final revoked = extensionRevoked;
    if (revoked.remove(key) != null) {
      await prefs.setString(_extensionRevokedKey, jsonEncode(revoked));
    }
  }
}
