// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Owns the app's single ExtensionHost instance (background isolate) and exposes
// domain-shaped calls on top of raw hook invocations. Boots asynchronously at
// app start; every caller must tolerate `ready == false` — a missing or
// broken extension runtime degrades features, never the core loop.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:halo_build_tools/halo_build_tools.dart' show kEdition;
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_core/halo_core.dart';
import 'error_reporting_service.dart';
import 'location_service.dart';
import 'settings_service.dart';
import 'spots_service.dart';
import 'status_bar_service.dart';
import 'package:halo_widgets/halo_widgets.dart';
import '../config/secret_policy.dart';
import '../config/secrets.dart';
import '../config/dev_flags.dart';
import '../config/dev_fixture.dart';
import '../config/user_agent.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import '../i18n/strings.g.dart';
import '../main.dart';
import 'link_opener.dart';
import '../tools/backoff.dart';
import '../tools/form_chrome_labels.dart';
import '../tools/activity_suggestions.dart';
import '../tools/qso_patch.dart';

/// This device's LoFi identity: the Pusher channel to subscribe
/// to, and the signed token a webhook-relayed OAuth login embeds in its
/// `state` param. Returned by [ExtensionService.ensureLofiClientRegistered]
/// and [HaLoServices.connectLofiRealtime] alike.
typedef LofiClientRegistration = ({String pushChannelName, String webhookClientToken});

/// The QSON payload shape shared by every hook that takes a whole operation's
/// worth of QSOs in one coarse call (export, scoring, …) — `operation.data`
/// with `uuid` folded in, plus each QSO's raw QSON `data`.
Map<String, dynamic> qsonPayloadFor({required Operation operation, required List<Qso> qsos}) => {
      'operation': {...operation.data, 'uuid': operation.uuid},
      'qsos': [for (final qso in qsos) qso.data],
    };

class ExtensionService {
  ExtensionHost? _host;
  Future<void>? _starting;
  Timer? _restartTimer;
  int _restartAttempts = 0;

  /// The in-flight [_replaceRuntime] call, if any — [commitSettingsFieldValue]
  /// awaits this instead of bailing out when [host] is momentarily null
  /// mid-restart, so a commit that lands in that window still reaches the
  /// fresh runtime instead of silently no-oping.
  Future<void>? _restartFuture;

  /// True when the last runtime start proceeded past the bounded activation
  /// wait without every extension's onActivation settling — hook
  /// registrations may be INCOMPLETE for this generation. Consumers that
  /// treat the hook set as authoritative (the data-file orphan purge) must
  /// check this and stand down rather than act on a partial picture.
  bool get activationIncomplete => _activationIncomplete;
  bool _activationIncomplete = false;
  ({String deviceKey, String operatorCall})? _lastSyncCredentials;

  static const _keychainAccountName = 'Ham2K Logger';


  final _secureStorage = const FlutterSecureStorage(
    mOptions: MacOsOptions(
      // FILE keychain on macOS. The data-protection keychain needs the RESTRICTED
      // keychain-access-groups entitlement, which a Developer ID build can't
      // carry (no provisioning profile → spawn crash), so it fails every
      // save with errSecMissingEntitlement (-34018). The file keychain needs no
      // entitlement and works under the sandbox.
      // A future Mac App Store build has a profile and can switch back.
      usesDataProtectionKeychain: false,
      accountName: _keychainAccountName,
    ),
    iOptions: IOSOptions(
      accountName: _keychainAccountName,
    ),
  );

  /// Per-account iCloud Keychain sync flag (`kSecAttrSynchronizable`), keyed
  /// by account `kvKey`, as declared by each extension's `account` hook
  /// (`synchronizable`, default false). Resolved ONCE from the account
  /// definitions at runtime start (see [_refreshAccountSynchronizable], called
  /// from [_start], which also covers every restart) so that every read/write/
  /// delete for a given key uses the SAME flag: a synchronizable and a
  /// non-synchronizable item are DISTINCT keychain entries, so a mismatch
  /// would silently miss. An unknown key defaults to false — the fail-safe is
  /// "never accidentally sync". Only `account_creds_`/`account_session_` items
  /// consult this; secret settings fields stay device-local (the default).
  final Map<String, bool> _accountSynchronizable = {};

  /// The resolved flags, so a test can assert the boot-time refresh actually
  /// captured them. Nothing else observes this map directly — its effect is a
  /// keychain option on a platform tests don't run on — so without this the
  /// only provable symptom of the refresh failing is a log line.
  @visibleForTesting
  Map<String, bool> get accountSynchronizable => Map.unmodifiable(_accountSynchronizable);

  /// Completes once [_refreshAccountSynchronizable] has resolved the flags for
  /// the current runtime generation (or start failed) — reset per [_start],
  /// completed in its `finally`. Account access awaits this so an early lookup
  /// (the lookup queue gates on [ready], which flips true before the flags are
  /// cached) can't read a synchronizable account under the wrong flag and miss
  /// it. A fresh, never-started service leaves it pending, so
  /// [_accountKeychainOptions] only awaits it when a start is actually in play.
  Completer<void> _accountSyncReady = Completer<void>();

  /// True while [_refreshAccountSynchronizable] is in flight.
  ///
  /// The refresh asks the kernel for the account definitions, and the kernel
  /// answers by CALLING BACK into Dart (`getAccount`, to build the hook ctx for
  /// any account member that is a function). Without this flag that host call
  /// waits on [_accountSyncReady] — the completer the refresh itself is on its
  /// way to completing — and the two wait on each other until the hook times
  /// out. See [_accountKeychainOptions].
  bool _refreshingAccountSynchronizable = false;

  /// Rebuilds [_accountSynchronizable] from the current account definitions.
  /// Best-effort: a failure leaves accounts device-local, never crashes boot.
  Future<void> _refreshAccountSynchronizable() async {
    _refreshingAccountSynchronizable = true;
    try {
      final accounts = await getAccounts();
      // Couldn't ask (already logged by getAccounts). Leave whatever the last
      // successful refresh resolved in place rather than wiping it: on a
      // restart, stale flags still describe the accounts the user has, while
      // an empty map silently reads and writes every account under the
      // device-local default — the exact miss this cache exists to prevent.
      if (accounts == null) return;
      _accountSynchronizable
        ..clear()
        ..addEntries(accounts
            .where((a) => a['kvKey'] is String)
            .map((a) => MapEntry(a['kvKey'] as String, a['synchronizable'] == true)));
    } catch (e) {
      debugPrint('[extensions] refreshAccountSynchronizable failed: $e');
    } finally {
      _refreshingAccountSynchronizable = false;
    }
  }

  /// The complete keychain options for one account's items, matching the
  /// instance defaults but with the account's declared `synchronizable` flag.
  /// Per-call options REPLACE (don't merge with) the instance defaults, so
  /// the data-protection-keychain and account-name settings are repeated here.
  ///
  /// Awaits [_accountSyncReady] first (only while a start is in flight, so a
  /// never-started service doesn't hang) so the flag is resolved before the
  /// first read/write. Near-free once the flags are cached.
  ///
  /// macOS: a synchronizable item requires the data-protection keychain, but the
  /// app uses the FILE keychain on macOS (Developer ID can't carry the
  /// keychain-access-groups entitlement the data-protection keychain needs — see
  /// the instance default), so macOS accounts are never synchronizable and stay
  /// device-local. iOS always uses the data-protection keychain, so it syncs when
  /// the account declares it. Both keep `synchronizable` and
  /// `usesDataProtectionKeychain` from ever contradicting.
  /// [fromHostCall] marks the calls the extension runtime makes back into us
  /// while a hook is running. Those must never wait on [_accountSyncReady]
  /// during [_refreshAccountSynchronizable]: the refresh is what completes that
  /// completer, and it cannot finish until the hook it is waiting on returns —
  /// which cannot happen until this call does. Deliberately NOT a blanket
  /// bypass: direct Dart callers (a lookup firing as soon as [ready] flips)
  /// still wait, because getting them the right flag is the whole reason the
  /// gate exists.
  ///
  /// Bypassing yields the device-local defaults. Without the bypass the
  /// refresh deadlocks and times out, leaving the flag map empty for the
  /// whole session — so the bypass is never worse, and unlike the deadlock
  /// the flags are correct a moment later.
  Future<({MacOsOptions mOptions, IOSOptions iOptions})> _accountKeychainOptions(
    String kvKey, {
    bool fromHostCall = false,
  }) async {
    final wouldDeadlock = fromHostCall && _refreshingAccountSynchronizable;
    if (!wouldDeadlock && !_accountSyncReady.isCompleted && (_starting != null || _host != null)) {
      await _accountSyncReady.future;
    }
    final declared = _accountSynchronizable[kvKey] ?? false;
    return (
      mOptions: MacOsOptions(
        // File keychain on macOS (see the instance default), so accounts can't
        // be synchronizable here — kSecAttrSynchronizable requires the
        // data-protection keychain, which Developer ID can't use. macOS account
        // creds stay device-local; iOS (always data-protection) still syncs when
        // the account declares it.
        usesDataProtectionKeychain: false,
        accountName: _keychainAccountName,
        synchronizable: false,
      ),
      iOptions: IOSOptions(
        accountName: _keychainAccountName,
        synchronizable: declared,
      ),
    );
  }

  SettingsService? settings;
  LookupRepository? lookups;
  StatusBarService? statusBar;

  /// Back the `getOperation`/`getQsos` host calls (HookContext.getOperation/
  /// getQsos in the SDK). Optional like the other service references — a
  /// host without them (bench harnesses, focused tests) answers those calls
  /// with null/empty instead of failing.
  OperationsRepository? operations;
  QsosRepository? qsos;

  /// Backs the `getLocation` host call (SDK's `host.getLocation()`) — a
  /// one-shot device GPS fix for a command with no operation grid to fall
  /// back to. Optional like the other service references above.
  LocationService? location;

  /// Backs the `getSpotsForCall` host call (HookContext.getSpotsForCall),
  /// which the `spot-history` lookup hook reads. Optional like the other
  /// service references — a host without it answers with an empty list, so
  /// the hook simply contributes nothing.
  SpotsService? spots;

  /// Extension keys allowed to call `getLocation` (manifest.json
  /// `requiresLocation`) — same allowlist shape as [_fetchAllowlists]
  /// below, resolved once at load time in [_start].
  Set<String> _locationAllowlist = const {};

  /// Whether [extensionKey] (or its bundle, for a sub-extension like
  /// `pota-all-parks`) may call `getLocation` — mirrors the prefix rule
  /// `ExtensionHost._fetchAllowlistFor` applies to `domains`.
  bool _locationAllowed(String? extensionKey) {
    if (extensionKey == null) return false;
    if (_locationAllowlist.contains(extensionKey)) return true;
    return _locationAllowlist.any((key) => extensionKey.startsWith('$key-') || extensionKey.startsWith('${key}_'));
  }

  bool get ready => _host != null;
  ExtensionHost? get host => _host;

  Future<void> start() {
    return _starting ??= _start();
  }

  /// Every extension-declared account, or null when the extensions could not
  /// be asked at all — no runtime yet, a dead one, or the fan-out failing or
  /// timing out. That is deliberately distinct from an empty list ("asked,
  /// and nobody declares an account"): the two look identical to a caller but
  /// mean opposite things, and a caller that caches the answer must never
  /// cache a failure (see settings_view's `_accountsCache`). Failures are
  /// logged here rather than thrown, so a caller that has nothing better to do
  /// can still treat null as "no accounts" with `?? const []`.
  Future<List<Map<String, dynamic>>?> getAccounts() async {
    final host = this.host;
    if (host == null) return null;
    try {
      final entries = await host.invokeHookAll('account', method: 'getDefinition', timeout: const Duration(seconds: 2));
      final accounts = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          accounts.add((entry['value'] as Map).cast<String, dynamic>());
        }
      }
      return accounts;
    } catch (e) {
      debugPrint('[extensions] getAccounts failed: $e');
      return null;
    }
  }

  /// Fans a call out to every hook in `category` via `invokeHookAll`,
  /// flattens each hook's returned list, and tags every item with
  /// `hookKey` — the hook's own registration key — so a later call can be
  /// routed back to the hook that offered it. Hooks that don't implement
  /// `method`, or whose call fails, are silently absent from the result
  /// (a failing source never poisons the others). Shared by `getExportOptions`
  /// and `getSpots`, which otherwise just differ by category/method/args.
  Future<List<Map<String, dynamic>>> _collectHookResults(
    String category, {
    required String method,
    required Object? args,
    required String debugLabel,
  }) async {
    final host = _host;
    if (host == null) return const [];
    try {
      final entries = await host.invokeHookAll(
        category,
        method: method,
        args: args,
        timeout: const Duration(seconds: 10),
      );
      final results = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! List) continue;
        final hookKey = entry['key'] as String?;
        for (final item in (entry['value'] as List)) {
          if (item is Map) {
            results.add({...item.cast<String, dynamic>(), 'hookKey': hookKey});
          }
        }
      }
      return results;
    } catch (e) {
      debugPrint('[extensions] $debugLabel failed: $e');
      return const [];
    }
  }

  /// Every export option offered by every `export` hook (Exports Panel).
  /// Hooks that don't implement
  /// `suggestExportOptions` are silently absent from the list.
  Future<List<Map<String, dynamic>>> getExportOptions(Map<String, dynamic> args) => _collectHookResults(
        'export',
        method: 'suggestExportOptions',
        args: args,
        debugLabel: 'getExportOptions',
      );

  /// Every `spots` hook currently willing to post a spot (Spotting
  /// control), each tagged with `hookKey` so a later
  /// `sendSpot` call can be routed back to it. Calls `isSelfSpotEnabled`
  /// when `qso` is omitted, `isOtherSpotEnabled` otherwise; hooks that don't
  /// implement the relevant method, or report `enabled: false`, are
  /// silently absent — same convention as `getExportOptions`.
  Future<List<Map<String, dynamic>>> suggestSpotSources({
    required Map<String, dynamic> operation,
    Map<String, dynamic>? qso,
  }) async {
    final host = _host;
    if (host == null) return const [];
    final method = qso == null ? 'isSelfSpotEnabled' : 'isOtherSpotEnabled';
    final args = qso == null ? {'operation': operation} : {'qso': qso};
    try {
      final entries = await host.invokeHookAll('spots', method: method, args: args, timeout: const Duration(seconds: 5));
      final sources = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! Map) continue;
        final value = (entry['value'] as Map).cast<String, dynamic>();
        if (value['enabled'] != true) continue;
        sources.add({...value, 'hookKey': entry['key']});
      }
      return sources;
    } catch (e) {
      debugPrint('[extensions] suggestSpotSources failed: $e');
      return const [];
    }
  }

  /// Every spot offered by every `spots` hook (Spots Panel),
  /// each tagged with `hookKey` so the panel can
  /// group/filter by source.
  Future<List<Map<String, dynamic>>> getSpots() => _collectHookResults(
        'spots',
        method: 'fetchSpots',
        args: const {},
        debugLabel: 'getSpots',
      );

  /// `{hookKey: sourceName}` for every `spots` hook, for the Spots Panel's
  /// source filter labels (e.g. `pota` -> "POTA.app"). `sourceName` is a
  /// plain data member on each hook, not a method — `invokeHookAll` returns
  /// it directly without an args/ctx round-trip, same as any other field
  /// access through the hook-call bridge.
  Future<Map<String, String>> getSpotSourceNames() async {
    final host = _host;
    if (host == null) return const {};
    try {
      final entries = await host.invokeHookAll('spots', method: 'sourceName', timeout: const Duration(seconds: 5));
      return {
        for (final entry in entries)
          if (entry['ok'] == true && entry['value'] is String) entry['key'] as String: entry['value'] as String,
      };
    } catch (e) {
      debugPrint('[extensions] getSpotSourceNames failed: $e');
      return const {};
    }
  }

  /// Posts a spot via every hook in `sources` (as returned by
  /// `suggestSpotSources`) concurrently — independent per-source calls, no
  /// ordering dependency between them. Returns `{hookKey: PostResult}` so
  /// the caller can color each source's status icon. `freq`/`mode` are only
  /// used for a self-spot (`qso == null`); spotting an existing QSO derives
  /// them from the QSO itself, JS-side.
  Future<Map<String, Map<String, dynamic>>> sendSpot({
    required List<Map<String, dynamic>> sources,
    required Map<String, dynamic> operation,
    Map<String, dynamic>? qso,
    double? freq,
    String? mode,
    String? comment,
    String? spotterCall,
  }) async {
    final host = _host;
    if (host == null) return const {};
    final method = qso == null ? 'postSelfSpot' : 'postOtherSpot';
    final args = qso == null
        ? {'operation': operation, 'freq': freq, 'mode': mode, 'comment': comment}
        : {'qso': qso, 'comment': comment, 'spotterCall': spotterCall};
    final entries = await Future.wait(sources.map((source) async {
      final hookKey = source['hookKey'] as String?;
      try {
        final result = await host.invokeHook(
          'spots',
          key: hookKey,
          method: method,
          args: args,
          timeout: const Duration(seconds: 15),
        ) as Map;
        return MapEntry(hookKey ?? '', result.cast<String, dynamic>());
      } catch (e) {
        return MapEntry(hookKey ?? '', <String, dynamic>{'ok': false, 'message': e.toString()});
      }
    }));
    for (final entry in entries) {
      debugPrint('[spots] $method via ${entry.key}: ${entry.value}');
      final userMessage = entry.value['userMessage'];
      if (userMessage is Map) {
        presentResultMessage(userMessage.cast<String, dynamic>(), ns: entry.key);
      }
    }
    return {for (final entry in entries) entry.key: entry.value};
  }

  Future<String> testCredentials(String accountKey, Map<String, String> credentials) async {
    final host = _host;
    if (host == null) return t.extensionService.runtimeNotReady;
    try {
      final dynamic res = await host.invokeHook(
        'account',
        key: accountKey,
        method: 'testCredentials',
        args: credentials,
        timeout: const Duration(seconds: 10),
      );
      return res is String ? res : res?.toString() ?? '';
    } catch (e) {
      return t.extensionService.testFailed(error: e);
    }
  }

  /// The credentials stored for [kvKey]: a map, `{}` when nothing is stored —
  /// and NULL when secure storage could not be reached at all.
  ///
  /// The distinction is the whole point. An empty map means "this account is not
  /// connected", which is a fact about the account; null means "we cannot know",
  /// which is a fact about the machine — a Linux box with no Secret Service
  /// running, a locked keyring. Collapsing the two would tell an operator
  /// they had been logged out, and invite them to log in again into a store that
  /// cannot keep it.
  ///
  /// Never let this throw: `_loadAccounts` would spin forever and the account
  /// dialog would render with no fields at all, because both read it before
  /// their own `setState`.
  Future<Map<String, String>?> getAccountCredentials(String kvKey) async {
    final o = await _accountKeychainOptions(kvKey);
    final String? raw;
    try {
      raw = await _secureStorage.read(key: 'account_creds_$kvKey', mOptions: o.mOptions, iOptions: o.iOptions);
    } catch (e, st) {
      // EVERYTHING, not just PlatformException: a build where the plugin failed
      // to register raises MissingPluginException, and catching only the former
      // would reopen the exact hang this exists to prevent — `_loadAccounts`
      // reads this before its own `setState`. `KeyringLocked` on Linux covers three
      // different situations anyway (no Secret Service, no default collection,
      // one that would not unlock), so nothing here claims which.
      debugPrint('[extensions] secure storage unavailable reading $kvKey: $e');
      ErrorReportingService.report(e, st, context: 'accounts:read-credentials');
      return null;
    }
    if (raw == null) return const {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return const {};
    }
  }

  Future<void> setAccountCredentials(String kvKey, Map<String, String> credentials) async {
    final o = await _accountKeychainOptions(kvKey);
    await _secureStorage.write(
      key: 'account_creds_$kvKey',
      value: jsonEncode(credentials),
      mOptions: o.mOptions,
      iOptions: o.iOptions,
    );
    // Any stored session was derived from the OLD credentials — e.g. OAuth
    // tokens refreshed from a previous login — and could keep acting as the
    // previous account if left behind.
    await _deleteAccountItem('account_session_$kvKey', o);
    // Fresh credentials must reach the very next hook call, not whatever
    // the kernel's context cache still holds.
    _host?.invalidateHookContext();
  }

  Future<void> clearAccount(String kvKey) async {
    final o = await _accountKeychainOptions(kvKey);
    await _deleteAccountItem('account_creds_$kvKey', o);
    await _deleteAccountItem('account_session_$kvKey', o);
    _host?.invalidateHookContext();
  }

  /// Best-effort keychain delete. Deleting an item that doesn't exist is
  /// fine everywhere except macOS 26, which reports it as
  /// errSecMissingEntitlement (-34018) instead of "not found" — so delete
  /// failures are logged, never thrown.
  Future<void> _deleteAccountItem(String key, ({MacOsOptions mOptions, IOSOptions iOptions}) o) async {
    try {
      await _secureStorage.delete(key: key, mOptions: o.mOptions, iOptions: o.iOptions);
    } catch (e) {
      debugPrint('[extensions] keychain delete $key failed (ignored): $e');
    }
  }

  /// Drops the kernel's cached HookContext so the next hook call sees fresh
  /// core state — call after mutating anything a HookContext carries
  /// (locale, theme, developer mode). No-op before the runtime is up.
  void invalidateHookContext() {
    // The command catalog's `describe` strings are localized by the hook
    // against that same context, so a stale cache would keep the palette in
    // the previous language after a locale switch (⌘⇧L).
    _commandCatalog = null;
    _host?.invalidateHookContext();
  }

  /// Every panel across every extension's `settingsPanel` registration, one
  /// entry per PANEL (not per registration — a Tier 2 hook's `getPanels()`
  /// can fan one registration out to several), sorted by `order`. Each
  /// entry is `{panelKey, hookKey, extensionKey, title, icon, order, kind}`
  /// — `hookKey` is what routes `getSettingsPanelDefinition`/action calls
  /// back to the right registered object; `panelKey` is what's passed as
  /// `args.panelKey`. They're equal for Tier 1; only a multi-panel Tier 2
  /// registration tells them apart.
  Future<List<Map<String, dynamic>>> getSettingsPanels() async {
    final host = this.host;
    if (host == null) return const [];
    try {
      final entries = await host.invokeHookAll('settingsPanel', method: 'getPanels', timeout: const Duration(seconds: 2));
      final panels = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          panels.add((entry['value'] as Map).cast<String, dynamic>());
        }
      }
      panels.sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
      return panels;
    } catch (e) {
      debugPrint('[extensions] getSettingsPanels failed: $e');
      return const [];
    }
  }

  /// The `FormDefinition` for one panel. For a Tier 1 (`kind: 'simple'`)
  /// panel, this is the ONLY bridge call in its whole lifecycle — every
  /// plain/secret field's live value is overlaid from Dart-owned storage
  /// right here, and every subsequent read/write/validate happens locally
  /// (see [commitSettingsFieldValue]/[validateSettingsField]), matching
  /// Tier 1's "no bridge call per keystroke" design. A Tier 2
  /// (`kind: 'dynamic'`) panel's other fields are already current as
  /// returned — that tier owns its own persistence, so nothing is
  /// overlaid for them. `fieldType: 'account'` fields are resolved here
  /// regardless of tier — neither tier can know live account connection
  /// status itself, since that's entirely host-owned (see AccountHook).
  Future<Map<String, dynamic>?> getSettingsPanelDefinition({
    required String hookKey,
    required String panelKey,
    required String kind,
  }) async {
    final host = this.host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook(
        'settingsPanel',
        key: hookKey,
        method: 'getDefinition',
        args: {'panelKey': panelKey},
        timeout: const Duration(seconds: 5),
      );
      if (result is! Map) return null;
      final definition = Map<String, dynamic>.from(result);
      final elements = ((definition['elements'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      for (final el in elements) {
        if (el['type'] != 'field') continue;
        final fieldKey = el['key'] as String?;
        if (fieldKey == null) continue;
        if (el['fieldType'] == 'account') {
          final accountKey = (el['account'] as Map?)?['key'] as String?;
          if (accountKey != null) el['value'] = await _resolveAccountStatus(accountKey);
          continue;
        }
        if (kind != 'simple') continue;
        final stored = await _readSettingsValue(panelKey: panelKey, fieldKey: fieldKey, isSecret: el['fieldType'] == 'secret');
        if (stored != null) el['value'] = stored;
      }
      definition['elements'] = elements;
      return definition;
    } catch (e) {
      debugPrint('[extensions] getSettingsPanelDefinition failed: $e');
      return null;
    }
  }

  /// `{connected, label}` for a `fieldType: 'account'` field — `label` is
  /// only set when connected (a human-readable "Connected as X"). Guarded
  /// on its own: a credential-storage failure here must not take down the
  /// whole panel the way an unguarded exception bubbling up to
  /// [getSettingsPanelDefinition]'s own try/catch would.
  Future<Map<String, dynamic>> _resolveAccountStatus(String accountKey) async {
    try {
      final creds = await getAccountCredentials(accountKey);
      // Null is "we could not look", not "not connected" — say so, so an
      // extension's own UI can tell the difference too.
      if (creds == null) return {'connected': false, 'unavailable': true};
      if (creds.isEmpty) return {'connected': false};
      final identity = identityFromCredentials(creds);
      return {'connected': true, if (identity != null) 'label': t.extensionService.connectedAs(identity: identity)};
    } catch (e) {
      debugPrint('[extensions] _resolveAccountStatus failed for $accountKey: $e');
      return {'connected': false};
    }
  }

  /// Picks a human-readable identity out of a credentials map — the same
  /// priority (`username` then `email` then `login`) used everywhere in
  /// Settings that displays which account a set of stored credentials
  /// belongs to. OAuth accounts store tokens instead of a username, so as a
  /// last resort the OIDC id_token's identity claims are read from its JWT
  /// payload (no signature check needed — it came straight from the
  /// provider's token endpoint and is only used for display).
  static String? identityFromCredentials(Map<String, String> creds) {
    final direct = creds['username'] ?? creds['email'] ?? creds['login'];
    if (direct != null) return direct;
    final idToken = creds['idToken'];
    if (idToken == null) return null;
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if (payload is! Map) return null;
      return (payload['preferred_username'] ?? payload['email'] ?? payload['name']) as String?;
    } catch (_) {
      return null;
    }
  }

  /// Validates one field's value. Tier 1 checks `pattern`/`patternError`
  /// declaratively, entirely in Dart — no bridge call. Tier 2 forwards to
  /// its `validateField` hook method.
  Future<String?> validateSettingsField({
    required String kind,
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> field,
    required String fieldKey,
    required dynamic value,
    required Map<String, dynamic> state,
  }) async {
    if (kind == 'simple') {
      final pattern = field['pattern'] as String?;
      if (pattern == null || pattern.isEmpty) return null;
      try {
        if (RegExp(pattern).hasMatch(value?.toString() ?? '')) return null;
      } catch (e) {
        // A malformed pattern is an extension bug, not a user input error —
        // still can't let it crash the caller, which (unlike submit()'s own
        // validator call) doesn't wrap this in a try/catch on the on-blur path.
        debugPrint('[extensions] settingsPanel field "${field['key']}" has an invalid pattern "$pattern": $e');
        return t.extensionService.invalidFieldConfiguration;
      }
      return field['patternError'] as String? ?? t.extensionService.invalidValue;
    }
    final host = this.host;
    if (host == null) return null;
    try {
      final res = await host.invokeHook(
        'settingsPanel',
        key: hookKey,
        method: 'validateField',
        args: {'panelKey': panelKey, 'fieldKey': fieldKey, 'value': value, 'state': state},
      );
      return res as String?;
    } catch (e) {
      return t.extensionService.validationError(error: e);
    }
  }

  /// Commits one field's value after it's been accepted (validated, and for
  /// Tier 2, transformed). Tier 1 persists directly to Dart-owned storage —
  /// kv (SharedPreferences) normally, `FlutterSecureStorage` for
  /// `fieldType: 'secret'`. Tier 2 has no local persistence at all; the
  /// call is forwarded to `onChangeField` and the extension is responsible
  /// for storing it itself (e.g. its own `host.setSettings` — NOT
  /// `host.kvSet`, which is in-memory only).
  ///
  /// [restartOnChange] (the field's own `restartOnChange` attribute, see
  /// docs/extensions/settings.md's "Restarting the runtime after a Tier 2
  /// field commits") restarts the extension runtime once the commit above
  /// finishes, so `onActivation` re-runs and can pick up the new value via
  /// `getSettings()` — for a value nothing else re-reads on its own.
  Future<void> commitSettingsFieldValue({
    required String kind,
    required String hookKey,
    required String panelKey,
    required String fieldKey,
    required dynamic value,
    required Map<String, dynamic> state,
    bool isSecret = false,
    bool restartOnChange = false,
  }) async {
    if (kind == 'simple') {
      await _writeSettingsValue(panelKey: panelKey, fieldKey: fieldKey, value: value, isSecret: isSecret);
      return;
    }
    // Wait out any in-flight restart before touching `host` — it's briefly
    // null while `_replaceRuntime` tears down and reboots. Without this, a
    // commit landing in that window bailed out below (host == null) without
    // ever calling onChangeField, silently dropping that edit rather than
    // just delaying it.
    final inFlightRestart = _restartFuture;
    if (inFlightRestart != null) await inFlightRestart;
    final host = this.host;
    if (host == null) return;
    // Counted so a pending debounce timer cannot restart the runtime UNDER
    // this commit's bridge call — disposing the host completes the pending
    // invokeHook with an exception and the edit would be silently dropped.
    // The timer waits for quiescence before restarting.
    _inFlightFieldCommits++;
    try {
      await host.invokeHook(
        'settingsPanel',
        key: hookKey,
        method: 'onChangeField',
        args: {'panelKey': panelKey, 'fieldKey': fieldKey, 'value': value, 'state': state},
      );
    } catch (e) {
      debugPrint('[extensions] settingsPanel onChangeField failed: $e');
      // Not restarted below: onChangeField is the extension's own persistence
      // call (e.g. host.setSettings) — if IT failed, the value never
      // actually saved, so restarting anyway would just re-run onActivation
      // against the same stale settings for no benefit.
      return;
    } finally {
      _inFlightFieldCommits--;
      if (_inFlightFieldCommits == 0) {
        _fieldCommitsIdle?.complete();
        _fieldCommitsIdle = null;
      }
    }
    if (restartOnChange) await _debouncedRestartRuntime();
  }

  int _inFlightFieldCommits = 0;
  Completer<void>? _fieldCommitsIdle;

  Timer? _restartOnChangeDebounce;
  Completer<void>? _restartOnChangeCompleter;

  /// Coalesces a burst of `restartOnChange` commits (e.g. deleting or
  /// reordering several rows of an inline list field one at a time) into a
  /// SINGLE runtime restart once they settle, instead of tearing down and
  /// rebooting every OTHER loaded extension once per row action — a full
  /// [restartRuntime] is the existing, already-accepted cost of
  /// `restartOnChange` (the same one an extension enable/disable toggle
  /// pays), but nothing before call-notes' `customFiles` field exercised it
  /// from a rapid, un-awaited per-row UI action.
  Future<void> _debouncedRestartRuntime() {
    _restartOnChangeDebounce?.cancel();
    final completer = _restartOnChangeCompleter ??= Completer<void>();
    _restartOnChangeDebounce = Timer(const Duration(milliseconds: 400), () async {
      // A commit whose onChangeField round trip is still in flight when this
      // timer fires must finish before the restart tears the host down; the
      // loop re-checks because a waiting commit can itself be followed by
      // another within the same window.
      while (_inFlightFieldCommits > 0) {
        await (_fieldCommitsIdle ??= Completer<void>()).future;
      }
      // A commit that finished DURING that wait re-armed the timer onto this
      // same completer — but its write is already durable and the restart
      // below will read it, so that re-arm is redundant: absorb it. If a
      // parallel firing of this callback got here first, the completer no
      // longer matches and this one stands down.
      if (!identical(_restartOnChangeCompleter, completer)) return;
      _restartOnChangeCompleter = null;
      _restartOnChangeDebounce?.cancel();
      restartRuntime().then(completer.complete, onError: completer.completeError);
    });
    return completer.future;
  }

  /// Transforms one field's value (Tier 2 only — Tier 1 fields never carry
  /// a transform, by construction of the `SettingsField` type).
  /// `transformField` is optional on `DynamicSettingsPanel` — a hook that
  /// doesn't implement it has nothing to distinguish "no transform
  /// declared" from "explicitly transformed to null" once the call comes
  /// back over the bridge (kernel.ts's generic dispatch has no per-field
  /// fallback the way the `form` category's kernel-side wrapper does), so
  /// a bare `null` result falls back to the original value rather than
  /// silently nulling out the field being committed.
  Future<dynamic> transformSettingsField({
    required String hookKey,
    required String panelKey,
    required String fieldKey,
    required dynamic value,
    required Map<String, dynamic> state,
  }) async {
    final host = this.host;
    if (host == null) return value;
    try {
      final result = await host.invokeHook(
        'settingsPanel',
        key: hookKey,
        method: 'transformField',
        args: {'panelKey': panelKey, 'fieldKey': fieldKey, 'value': value, 'state': state},
      );
      return result ?? value;
    } catch (e) {
      return value;
    }
  }

  /// Invokes a `FormActionElement`'s `method` (e.g. a "Test Connection" or
  /// "Clear Cache" button) against the panel's current state and returns
  /// the result string to show as a banner. `method` isn't a fixed hook
  /// method — it's resolved against whatever extra property the extension
  /// put on its registered panel object (see docs/extensions/settings.md's
  /// "The action element").
  Future<String?> runSettingsAction({
    required String hookKey,
    required String panelKey,
    required String method,
    required Map<String, dynamic> state,
  }) async {
    final host = this.host;
    if (host == null) return t.extensionService.runtimeNotReady;
    try {
      final res = await host.invokeHook(
        'settingsPanel',
        key: hookKey,
        method: method,
        args: {'panelKey': panelKey, 'state': state},
        timeout: const Duration(seconds: 10),
      );
      return res is String ? res : res?.toString();
    } catch (e) {
      return t.extensionService.actionFailed(error: e);
    }
  }

  Future<dynamic> _readSettingsValue({required String panelKey, required String fieldKey, required bool isSecret}) async {
    final raw = isSecret
        ? await _secureStorage.read(key: _settingsSecretStorageKey(panelKey, fieldKey))
        : settings?.prefs.getString(_settingsPrefsKey(panelKey, fieldKey));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _writeSettingsValue({required String panelKey, required String fieldKey, required dynamic value, required bool isSecret}) async {
    final encoded = jsonEncode(value);
    if (isSecret) {
      await _secureStorage.write(key: _settingsSecretStorageKey(panelKey, fieldKey), value: encoded);
      return;
    }
    await settings?.prefs.setString(_settingsPrefsKey(panelKey, fieldKey), encoded);
  }

  String _settingsPrefsKey(String panelKey, String fieldKey) => 'settingsPanel.$panelKey.$fieldKey';

  String _settingsSecretStorageKey(String panelKey, String fieldKey) => 'settingsPanel_secret_${panelKey}_$fieldKey';

  /// The LoFi app-attestation secret, injected at build time
  /// (`flutter build ... --dart-define=HAM2K_LOFI_SECRET=...`) — the same
  /// role as app-polo's `Config.HAM2K_LOFI_SECRET` from react-native-config.
  /// It identifies the *build* to the server, not the device (the device
  /// key does that); dev builds without the define fall back to the
  /// extension's 'no-secret' default, exactly like app-polo dev builds.
  static const _lofiSecret = String.fromEnvironment('HAM2K_LOFI_SECRET');

  /// Seeds the `ham2k-lofi` sync extension's device identity (a stable
  /// per-install key, generated once by `SettingsService.syncDeviceKey`),
  /// operator callsign, and build secret. Called both at boot and whenever
  /// Settings saves a new operator callsign. There's
  /// deliberately no `token` seeded here: the extension re-registers with
  /// the server on first use each run (the token is session-scoped, kept in
  /// the extension's own module state, same as app-polo's `GLOBAL.syncLoFiToken`
  /// being memory-only there too).
  Future<void> setSyncCredentials({required String deviceKey, required String operatorCall}) async {
    _lastSyncCredentials = (deviceKey: deviceKey, operatorCall: operatorCall); // replayed after a runtime restart
    await start();
    _host?.setKV('ham2k-lofi', 'key', deviceKey);
    _host?.setKV('ham2k-lofi', 'call', operatorCall);
    if (_lofiSecret.isNotEmpty) _host?.setKV('ham2k-lofi', 'secret', _lofiSecret);
  }

  Future<void> _start() async {
    // Fresh gate per generation: account access blocks on it until the
    // synchronizable flags are resolved (or start fails), so an early lookup
    // can't read an account under the wrong sync flag. Completed in `finally`.
    _accountSyncReady = Completer<void>();
    try {
      final index = jsonDecode(await rootBundle.loadString('assets/extensions/index.json')) as Map<String, dynamic>;
      final kernelSource = await rootBundle.loadString('assets/extensions/${index['kernel']}');
      final available = await loadAvailableExtensions(index: index);
      final bundles = <ExtensionBundle>[];
      final fetchAllowlists = <String, List<String>>{};
      final extensionSecrets = <String, Map<String, String>>{};
      final userAgentOverrides = <String>{};
      final locationAllowlist = <String>{};
      final loaded = <String>{};
      for (final info in available) {
        // Disabled extensions are simply never loaded — their hooks,
        // settings panels, and commands are absent until a re-enable
        // restarts the runtime with them included.
        if (!isExtensionEnabled(info)) continue;
        loaded.add(info.key);
        bundles.add(ExtensionBundle(
          key: info.key,
          source: await rootBundle.loadString('assets/extensions/${info.file}'),
        ));
        // The manifest's declared network capabilities (build.mjs `domains`
        // and `allowUserAgentOverride`).
        fetchAllowlists[info.key] = info.domains;
        if (info.allowUserAgentOverride) userAgentOverrides.add(info.key);
        // The manifest's declared `getLocation` capability (build.mjs
        // `requiresLocation`).
        if (info.requiresLocation) locationAllowlist.add(info.key);
        // Resolve what this extension is allowed to see, once, at load time —
        // the host then holds only that subset and needs no policy of its own.
        // A build without a value configured simply has none, and every
        // consumer degrades rather than failing: a fresh checkout must run.
        final visible = <String, String>{
          for (final entry in secrets.entries)
            if (entry.value.isNotEmpty && extensionMaySeeSecret(info.key, entry.key))
              entry.key: entry.value,
        };
        if (visible.isNotEmpty) extensionSecrets[info.key] = visible;
      }
      _locationAllowlist = locationAllowlist;
      _host = await ExtensionHost.start(
        kernelSource: kernelSource,
        extensions: bundles,
        onHostCall: _handleHostCall,
        fetchAllowlists: fetchAllowlists,
        secrets: extensionSecrets,
        // Resolve the UA resiliently: a missing native build number (headless
        // test host, or an early-boot platform channel not yet ready) must
        // not throw here and leave every extension dark.
        userAgent: await ham2kUserAgentOrFallback(),
        userAgentOverrides: userAgentOverrides,
      );
      _loadedExtensionKeys = loaded;
      _host!.logs.listen((line) => debugPrint('[extensions] $line'));
      _host!.interpretationUpdates.listen(_interpretationUpdates.add);
      for (final line in _host!.logLines) {
        debugPrint('[extensions] $line');
      }
      // A crashed runtime (isolate death, worker crash) is replaced, not
      // mourned: DESIGN.md's contract is that extensions degrade, they
      // don't stay dark until app restart.
      _host!.fatalErrors.listen((error) => _scheduleRestart('runtime died: $error'));
      _restartAttempts = 0;
      // Every extension's onActivation has now genuinely settled — not just
      // been kicked off (kernel.ts's activateAll fires it fire-and-forget).
      // Without this await, a caller querying dataFile/settingsPanel hooks
      // right after start() returned could miss a registration an extension
      // makes only after its own internal await (call-notes' custom files
      // await host.getSettings() first). Bounded: a hung extension's
      // activation must degrade boot, not stall it forever.
      _activationIncomplete = false;
      await _host!.activated.timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('[extensions] activation did not complete within 5s — continuing anyway');
        _activationIncomplete = true;
      });
      runtimeGeneration.value++;
      // Resolve each account's synchronizable flag; account access blocks on
      // _accountSyncReady (completed below) until this is done, so every
      // keychain op for a key uses a consistent flag. Covers restarts too:
      // _replaceRuntime routes back through start()/_start().
      await _refreshAccountSynchronizable();
    } catch (e) {
      debugPrint('[extensions] failed to start extension runtime: $e');
      // A transient boot failure (asset hiccup, engine init) must not leave
      // extensions off for the rest of the session ("_starting" memoizes),
      // so retry with backoff.
      _scheduleRestart('start failed: $e');
    } finally {
      // Never leave account access blocked, even if start threw before the
      // refresh ran — the empty cache then yields device-local defaults.
      if (!_accountSyncReady.isCompleted) _accountSyncReady.complete();
    }
  }

  /// The extensions the build index declares, with their user-facing
  /// metadata — readable without booting (or evaluating) any JS, so the
  /// Extensions panel can list DISABLED extensions and still render when
  /// the runtime is down. Memoized; [index] lets [_start] reuse its own
  /// parse.
  Future<List<ExtensionInfo>> loadAvailableExtensions({Map<String, dynamic>? index}) async {
    if (_availableExtensions != null) return _availableExtensions!;
    final parsed = index ?? jsonDecode(await rootBundle.loadString('assets/extensions/index.json')) as Map<String, dynamic>;
    return _availableExtensions = [
      for (final entry in (parsed['extensions'] as List).cast<Map<String, dynamic>>()) ExtensionInfo.fromJson(entry),
    ];
  }

  /// The already-loaded metadata, or empty before [loadAvailableExtensions]
  /// first resolves.
  List<ExtensionInfo> get availableExtensions => _availableExtensions ?? const [];
  List<ExtensionInfo>? _availableExtensions;

  @visibleForTesting
  void debugSetAvailableExtensions(List<ExtensionInfo> extensions) => _availableExtensions = extensions;

  /// Which extension keys the CURRENT runtime was started with — compared
  /// against the desired set to decide whether a toggle needs a restart.
  Set<String> _loadedExtensionKeys = const {};

  /// Bumped after every successful runtime (re)start — panels listen to
  /// re-fetch extension-contributed content (settings panels, listings).
  final ValueNotifier<int> runtimeGeneration = ValueNotifier(0);

  /// A `command` hook pushed a later CommandInterpretation for an `input` it
  /// was already asked to interpret (SOLAR/WEATHER's fetch
  /// resolving after their own describe-preview call already returned).
  /// Owned by the service, not the current [_host]: a restart replaces
  /// [_host] but callers (LoggingControls) hold one subscription for the
  /// service's whole lifetime, so [_start] re-subscribes the fresh host into
  /// this same controller each time instead of handing out a new stream.
  final _interpretationUpdates = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get commandInterpretationUpdates => _interpretationUpdates.stream;

  /// Core extensions are always on; the rest follow the user's override,
  /// falling back to the build index's default. A null [settings] (tests,
  /// benches) resolves to defaults.
  bool isExtensionEnabled(ExtensionInfo info) =>
      info.core || (settings?.extensionOverrides[info.key] ?? info.enabledByDefault);

  /// Persists enable/disable choices and applies them by restarting the
  /// runtime with the filtered bundle set — but only when the effective
  /// set actually changes (and the runtime is up; a pending boot picks the
  /// fresh overrides up on its own). The overrides land BEFORE any restart,
  /// so a quit mid-apply loses nothing.
  Future<void> setExtensionsEnabled(Map<String, bool> changes) async {
    final currentSettings = settings;
    if (currentSettings == null || changes.isEmpty) return;
    await currentSettings.setExtensionOverrides({...currentSettings.extensionOverrides, ...changes});
    await _updateDisabledSince(currentSettings);
    final desired = {
      for (final info in availableExtensions)
        if (isExtensionEnabled(info)) info.key,
    };
    if (_host == null || setEquals(desired, _loadedExtensionKeys)) return;
    await restartRuntime();
  }

  /// Stamps the moment each non-core extension became disabled, and clears
  /// the stamp when it's enabled again — the clock DataFileManager's
  /// grace-period purge reads. Only meaningful for extensions that could
  /// own data, but harmless (and simpler) to track for all non-core keys.
  Future<void> _updateDisabledSince(SettingsService settings) async {
    final disabledSince = {...settings.extensionDisabledSince};
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    for (final info in availableExtensions) {
      if (info.core) continue;
      final disabled = !isExtensionEnabled(info);
      if (disabled && !disabledSince.containsKey(info.key)) {
        disabledSince[info.key] = now;
        changed = true;
      } else if (!disabled && disabledSince.remove(info.key) != null) {
        changed = true;
      }
    }
    if (changed) await settings.setExtensionDisabledSince(disabledSince);
  }

  Future<void> setExtensionEnabled(String key, bool enabled) => setExtensionsEnabled({key: enabled});

  /// The activated extensions of the LIVE runtime, with versions — served
  /// by the kernel's own `kernel-info` extension (the one place versions
  /// exist). Empty when the runtime is down.
  Future<List<Map<String, dynamic>>> listActiveExtensions() async {
    // `this.host`, not the field: mock-host test subclasses override the
    // getter.
    final host = this.host;
    if (host == null) return const [];
    try {
      final result = await host.invokeHook('runtime',
          key: 'kernel', method: 'listExtensions', timeout: const Duration(seconds: 2));
      return result is List ? result.cast<Map>().map((e) => e.cast<String, dynamic>()).toList() : const [];
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] listActiveExtensions failed: $e');
      return const [];
    }
  }

  /// Schedules a full runtime replacement (dispose + fresh start + re-seed)
  /// with capped exponential backoff. Safe against double-triggering: a
  /// crash reports through more than one channel, and a restart may itself
  /// fail and re-schedule.
  void _scheduleRestart(String reason) {
    if (_restartTimer != null) return;
    _restartAttempts++;
    final delay = exponentialBackoff(_restartAttempts, cap: const Duration(seconds: 32)); // 2s..32s, then flat
    debugPrint('[extensions] $reason — restarting runtime in ${delay.inSeconds}s (attempt $_restartAttempts)');
    // A crash-looping runtime is a single point of failure for lookups, data
    // files, spots, and scoring all at once — the same "app just isn't doing
    // the thing" symptom class sync's own silent failures had.
    ErrorReportingService.report(reason, StackTrace.current, context: 'extensions:restart (attempt $_restartAttempts)');
    _restartTimer = Timer(delay, () async {
      _restartTimer = null;
      // onlyIfDead: by the time the backoff fires the runtime may have
      // recovered on its own (a crash reports through several channels) —
      // don't replace a healthy host.
      await _replaceRuntime(onlyIfDead: true);
    });
  }

  /// Restarts a LIVE runtime deliberately — extension enable/disable
  /// toggles use this to apply the new bundle set. Any pending crash-backoff
  /// timer is superseded (the replacement it wanted is happening now).
  Future<void> restartRuntime() {
    _restartTimer?.cancel();
    _restartTimer = null;
    return _replaceRuntime(onlyIfDead: false);
  }

  /// The one runtime-replacement path: dispose + fresh [start] + re-seed of
  /// the in-memory sync KV. Serialized behind [_restartFuture] — a second
  /// call while one is already in flight returns the SAME future rather than
  /// racing a second replace, so every caller (including
  /// [commitSettingsFieldValue], which awaits [_restartFuture] directly to
  /// avoid reading [host] while it's momentarily null) observes one
  /// consistent completion.
  Future<void> _replaceRuntime({required bool onlyIfDead}) {
    final inFlight = _restartFuture;
    if (inFlight != null) return inFlight;
    final future = _doReplaceRuntime(onlyIfDead: onlyIfDead);
    _restartFuture = future;
    return future;
  }

  Future<void> _doReplaceRuntime({required bool onlyIfDead}) async {
    try {
      // A boot may already be in flight (e.g. setSyncCredentials calls
      // start()); replacing the host under it would leak a live runtime.
      final inFlight = _starting;
      if (inFlight != null) await inFlight;
      if (onlyIfDead && _host != null && !_host!.isDead) return; // recovered on its own

      final old = _host;
      _host = null;
      _starting = null;
      // The new runtime may carry a different set of extensions (this is the
      // path an enable/disable toggle takes), so their advertised commands
      // have to be re-read rather than served from the old set's cache.
      _commandCatalog = null;
      await old?.dispose();
      await start();
      if (_host != null) {
        // The fresh runtime lost all seeded KV state (it's in-memory).
        final creds = _lastSyncCredentials;
        if (creds != null) {
          await setSyncCredentials(deviceKey: creds.deviceKey, operatorCall: creds.operatorCall);
        }
        debugPrint('[extensions] runtime restarted');
      }
    } finally {
      _restartFuture = null;
    }
  }

  /// [_handleHostCall] for tests — the runtime credential path has no other
  /// seam, and it is the one that decides what an extension believes.
  @visibleForTesting
  Future<dynamic> debugHandleHostCall(String method, Map<String, dynamic> params) => _handleHostCall(method, params);

  Future<dynamic> _handleHostCall(String method, Map<String, dynamic> params) async {
    switch (method) {
      case 'getAccount':
        final kvKey = params['kvKey'] as String;
        final o = await _accountKeychainOptions(kvKey, fromHostCall: true);
        // This is the path an extension actually uses at runtime, so it must
        // not lie: an unguarded throw here rejects the host call, the
        // kernel turns a rejection into `undefined` (sdk/src/kernel.ts), and the
        // extension reads that as a logged-out account — the same collapse
        // `getAccountCredentials` refuses to make. Saying `unavailable` instead
        // lets an extension tell "you are signed out" from "we could not look".
        try {
          final credsStr = await _secureStorage.read(key: 'account_creds_$kvKey', mOptions: o.mOptions, iOptions: o.iOptions);
          final sessionStr = await _secureStorage.read(key: 'account_session_$kvKey', mOptions: o.mOptions, iOptions: o.iOptions);
          return {
            'credentials': credsStr != null ? jsonDecode(credsStr) : const {},
            'session': sessionStr != null ? jsonDecode(sessionStr) : const {},
          };
        } catch (e, st) {
          debugPrint('[extensions] secure storage unavailable for host getAccount $kvKey: $e');
          ErrorReportingService.report(e, st, context: 'accounts:host-get-account');
          return {'credentials': const {}, 'session': const {}, 'unavailable': true};
        }
      case 'setAccountSession':
        final kvKey = params['kvKey'] as String;
        final o = await _accountKeychainOptions(kvKey, fromHostCall: true);
        final session = params['session'] as Map<dynamic, dynamic>;
        await _secureStorage.write(
          key: 'account_session_$kvKey',
          value: jsonEncode(session),
          mOptions: o.mOptions,
          iOptions: o.iOptions,
        );
        return null;
      case 'getSettings':
        // The full read view of the app's settings — resolved typed values
        // with defaults applied, so extensions never re-derive fallbacks.
        // Deliberately absent: credentials and accounts (those live in the
        // platform keychain via the account hook system, never in
        // SettingsService) and device identifiers.
        return {
          'developerMode': settings?.developerMode ?? false,
          'locale': settings?.locale ?? 'en',
          // Machine-facing: extensions put this in ADIF PROGRAMID, a spot's
          // source, etc. — so the fixed, platform-agnostic "Ham2K Logger", not
          // the UI's platform-tailored name.
          'appName': ham2kMachineName,
          // 'dev' | 'next' | 'prod' — for a hook whose static config must
          // vary per build edition (e.g. SOTA's OAuth client).
          'edition': kEdition.name,
          'themeMode': settings?.themeMode.name ?? 'system',
          'fontScale': settings?.fontScale.name ?? 'normal',
          'distanceUnits': settings?.distanceUnits.name ?? 'kilometers',
          'syncEnabled': settings?.syncEnabled ?? false,
          'operatorCall': settings?.activeProfile.operatorCall ?? '',
          'leftieMode': settings?.leftieMode ?? false,
          'fieldsOnTop': settings?.fieldsOnTop ?? false,
          'dxFlags': settings?.dxFlags.name ?? 'dx',
          'showBearing': settings?.showBearing ?? false,
          'switchSentRcvd': settings?.switchSentRcvd ?? false,
          'jumpAfterRST': settings?.jumpAfterRST ?? false,
          'defaultReport': settings?.defaultReport ?? '',
          'defaultReportCW': settings?.defaultReportCW ?? '',
          'defaultReportFT8': settings?.defaultReportFT8 ?? '',
          'bands': settings?.enabledBands ?? SettingsService.defaultBands,
          'modes': settings?.enabledModes ?? SettingsService.defaultModes,
          'showRSTFields': settings?.showRSTFields ?? true,
          'showStateField': settings?.showStateField ?? false,
          'showGridField': settings?.showGridField ?? false,
          'showDeletedQSOs': settings?.showDeletedQSOs ?? false,
          'showQsoNumbers': settings?.showQsoNumbers ?? true,
          'consentAppData': settings?.consentAppData ?? false,
          'consentOpData': settings?.consentOpData ?? false,
          // Extension-owned groups, raw — every extension can read every
          // group (settings are not secrets); writes are another matter.
          'extensions': settings?.extensionSettingsGroups() ?? const {},
        };
      case 'setSettings':
        // Writes are namespaced to the calling extension's own group
        // (`extension_<ns>`), enforced here by the SDK-injected ns — an
        // extension can never write core settings or another extension's.
        final ns = params['ns'] as String?;
        final values = params['values'];
        if (ns == null || ns.isEmpty || values is! Map) {
          debugPrint('[extensions] setSettings: missing ns or values — ignored');
          return null;
        }
        await settings?.updateSettingsGroup('extension_$ns', values.cast<String, dynamic>());
        return null;
      case 'translate':
        final key = params['key'] as String;
        final value = t[key];
        return value is String ? value : null;
      case 'translateAll':
        final keys = (params['keys'] as List).cast<String>();
        return {
          for (final key in keys) key: (t[key] is String ? t[key] : null),
        };
      case 'getOperation':
        final uuid = params['uuid'] as String;
        final operation = await operations?.get(uuid);
        // Same shape as qsonPayloadFor's `operation`: the QSON with `uuid`
        // folded in.
        return operation == null ? null : {...operation.data, 'uuid': operation.uuid};
      case 'getQsos':
        final operationUuid = params['operationUuid'] as String;
        // Null — not an empty list — when the operation is unknown or this
        // host has no log access, so callers can tell "no such operation"
        // from "operation with no QSOs yet" (see HookContext.getQsos).
        if (operations == null || qsos == null) return null;
        if (await operations!.get(operationUuid) == null) return null;
        // One-shot read via the watch stream's first emission — the same
        // convention ScoringService/ExportService use. Excludes soft-deleted
        // records, keeps event markers; oldest first.
        final list = await qsos!.watchForOperation(operationUuid).first;
        return [for (final qso in list) qso.data];
      case 'getSpotsForCall':
        // Reads the already-fetched cache — never triggers a fetch. This
        // runs inside the per-keystroke lookup pipeline, where waiting on a
        // fan-out to every spot source's API would blow the lookup's own 8s
        // budget; an empty answer before the first refresh lands is the
        // correct trade.
        final call = params['call'] as String?;
        final maxAgeMinutes = params['maxAgeMinutes'];
        if (call == null || spots == null) return const <Map<String, dynamic>>[];
        return spots!.spotsForCall(
          call,
          maxAge: Duration(minutes: maxAgeMinutes is num ? maxAgeMinutes.toInt() : 30),
        );
      case 'dbLookupSelectOne':
        final category = params['category'] as String;
        final key = params['key'] as String;
        final row = await lookups?.getLookup(category, key);
        return row == null
            ? null
            : {
                'category': row.category,
                'subCategory': row.subCategory,
                'key': row.key,
                'name': row.name,
                'data': row.data != null ? jsonDecode(row.data!) : null,
                'lat': row.lat,
                'lon': row.lon,
                'flags': row.flags,
              };
      case 'dbLookupSelectAll':
        final category = params['category'] as String;
        final query = params['query'] as String;
        final list = await lookups?.queryLookups(category, query) ?? const [];
        return list
            .map((row) => {
                  'category': row.category,
                  'subCategory': row.subCategory,
                  'key': row.key,
                  'name': row.name,
                  'data': row.data != null ? jsonDecode(row.data!) : null,
                  'lat': row.lat,
                  'lon': row.lon,
                  'flags': row.flags,
                })
            .toList();
      case 'dbLookupSelectByLocation':
        final category = params['category'] as String;
        final lat = (params['lat'] as num).toDouble();
        final lon = (params['lon'] as num).toDouble();
        final delta = (params['delta'] as num).toDouble();
        final list = await lookups?.queryLookupsByLocation(category, lat, lon, delta) ?? const [];
        return list
            .map((row) => {
                  'category': row.category,
                  'subCategory': row.subCategory,
                  'key': row.key,
                  'name': row.name,
                  'data': row.data != null ? jsonDecode(row.data!) : null,
                  'lat': row.lat,
                  'lon': row.lon,
                  'flags': row.flags,
                })
            .toList();
      case 'getLocation':
        // One-shot device GPS fix (SDK's `host.getLocation()`) — e.g. WEATHER
        // falling back to device location when there's no operation grid.
        // May prompt for location permission; null on any denial/failure.
        // Gated by the manifest's `requiresLocation` capability,
        // same allowlist shape as host.fetch's `domains`.
        final extensionKey = params['extensionKey'] as String?;
        if (!_locationAllowed(extensionKey)) {
          throw ExtensionHostException(
            "getLocation blocked: extension '${extensionKey ?? 'unknown'}' does not declare requiresLocation",
          );
        }
        final position = await location?.getCurrentPosition();
        return position == null ? null : {'latitude': position.latitude, 'longitude': position.longitude};
      case 'showForm':
        final formId = params['formId'] as String;
        final formDef = (params['form'] as Map).cast<String, dynamic>();
        final state = (params['state'] as Map? ?? const {}).cast<String, dynamic>();

        final context = navigatorKey.currentContext;
        if (context == null) {
          throw StateError('No active navigation context found');
        }

        final result = await showFormDialog(
          context,
          formDefinition: formDef,
          initialState: state,
          labels: formRendererLabelsFor(t),
          validator: (fieldKey, value, currentState) async {
            try {
              final res = await _host?.invokeHook(
                'form',
                key: formId,
                method: 'validateField',
                args: {
                  'formId': formId,
                  'fieldKey': fieldKey,
                  'value': value,
                  'state': currentState,
                },
              );
              return res as String?;
            } catch (e) {
              return t.extensionService.validationError(error: e);
            }
          },
          transformer: (fieldKey, value, currentState) async {
            try {
              final res = await _host?.invokeHook(
                'form',
                key: formId,
                method: 'transformField',
                args: {
                  'formId': formId,
                  'fieldKey': fieldKey,
                  'value': value,
                  'state': currentState,
                },
              );
              return res;
            } catch (_) {
              return value;
            }
          },
          onChange: (fieldKey, value, currentState) async {
            try {
              final res = await _host?.invokeHook(
                'form',
                key: formId,
                method: 'onChangeField',
                args: {
                  'formId': formId,
                  'fieldKey': fieldKey,
                  'value': value,
                  'state': currentState,
                },
              );
              if (res is Map) {
                return res.cast<String, dynamic>();
              }
              return null;
            } catch (_) {
              return null;
            }
          },
          developerMode: settings?.developerMode ?? false,
        );
        return result;
      case 'showMessage':
        presentResultMessage(params, ns: params['ns'] as String? ?? 'extensions');
        return null;
      case 'statusBarSetMessage':
        statusBar?.setMessage(
          key: _namespacedKey(params),
          icon: params['icon'] as String?,
          title: params['title'] as String?,
          text: params['text'] as String?,
        );
        return null;
      case 'statusBarSetProgress':
        statusBar?.setProgress(
          key: _namespacedKey(params),
          icon: params['icon'] as String?,
          title: params['title'] as String?,
          text: params['text'] as String?,
          value: (params['value'] as num?)?.toDouble(),
        );
        return null;
      case 'statusBarClear':
        statusBar?.clear(_namespacedKey(params));
        return null;
      case 'statusBarShowNotice':
        statusBar?.showNotice(
          key: _namespacedKey(params),
          icon: params['icon'] as String?,
          title: params['title'] as String?,
          text: params['text'] as String? ?? '',
          actions: _noticeActionsFromJson(params['actions'], _namespacedKey(params)),
        );
        return null;
      case 'statusBarDismissNotice':
        statusBar?.dismissNotice(_namespacedKey(params));
        return null;
      default:
        throw UnimplementedError('Host call method $method not implemented');
    }
  }

  /// Extension-supplied keys are prefixed with the calling extension's key so
  /// one extension's status bar items/notices can never collide with — or be
  /// cleared/dismissed by — another's. Same `ns` convention as `kvGet`/`kvSet`.
  String _namespacedKey(Map<String, dynamic> params) {
    final ns = params['ns'] as String;
    final key = params['key'] as String;
    return '$ns:$key';
  }

  /// Set by the app shell: opens an account's standalone dialog (Settings →
  /// Accounts) from anywhere — the handler behind declarative `account`
  /// actions (an extension's "reconnect your account" button).
  void Function(String accountKey, {String? subkey})? onOpenAccount;

  /// Notice actions from extensions are declarative JSON, not callbacks back
  /// into the extension (matches the `activity` hook's "describe UI as data"
  /// convention) — `link` opens a URL, `dialog` shows a markdown dialog.
  List<StatusBarAction> _noticeActionsFromJson(dynamic raw, String noticeKey) {
    if (raw is! List) return const [];
    final actions = <StatusBarAction>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final label = map['label'] as String?;
      final handler = _declarativeActionHandler(map);
      if (label == null || handler == null) continue;
      actions.add(StatusBarAction(label: label, onTap: handler));
    }
    return actions;
  }

  /// The tap handler for one declarative action (the SDK's NoticeAction):
  /// `link` opens a URL, `dialog` shows a markdown dialog, `account` opens
  /// that account's standalone dialog via [onOpenAccount]. Returns null for
  /// malformed or unknown actions, which the caller drops.
  VoidCallback? _declarativeActionHandler(Map<String, dynamic> map) {
    switch (map['type'] as String?) {
      case 'link':
        final url = map['url'] as String?;
        if (url == null) return null;
        // platformDefault, not the shared default: an http(s) link from a
        // notice action has always opened in an in-app browser (Custom Tab /
        // SFSafariViewController) rather than backgrounding the logger.
        return () => openExternalUrl(url, mode: LaunchMode.platformDefault);
      case 'dialog':
        final text = map['text'] as String? ?? '';
        final title = map['title'] as String?;
        return () => _showMarkdownDialog(title: title, text: text);
      case 'account':
        final key = map['key'] as String?;
        if (key == null) return null;
        return () => onOpenAccount?.call(key, subkey: map['subkey'] as String?);
    }
    return null;
  }

  void _showMarkdownDialog({String? title, required String text, List<Map<String, dynamic>> actions = const []}) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        wide: true,
        title: title != null ? Text(title) : null,
        content: MarkdownBody(data: text),
        cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(t.common.close)),
        actions: [
          for (final action in actions)
            if (action['label'] is String && _declarativeActionHandler(action) != null)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _declarativeActionHandler(action)!();
                },
                child: Text(action['label'] as String),
              ),
        ],
      ),
    );
  }

  /// Presents a ResultMessage (the SDK type of the same name): `status` is
  /// a transient status-bar message, `dialog` a modal markdown dialog whose
  /// buttons are declarative NoticeActions. Reached from a hook result's
  /// `userMessage` (see [sendSpot]) or the imperative `showMessage` host
  /// call (hooks whose results can't carry one, e.g. lookups).
  void presentResultMessage(Map<String, dynamic> message, {String ns = 'extensions'}) {
    final title = message['title'] as String?;
    final text = message['text'] as String? ?? '';
    if (message['presentation'] == 'dialog') {
      final actions =
          ((message['actions'] as List?) ?? const []).whereType<Map>().map((a) => a.cast<String, dynamic>()).toList();
      _showMarkdownDialog(title: title, text: text, actions: actions);
    } else {
      statusBar?.setMessage(key: '$ns:resultMessage', icon: message['icon'] as String?, title: title, text: text);
    }
  }

  /// Deterministic offline lookups: with `--dart-define=HALO_STUB_LOOKUPS=1`
  /// in a dev build, [lookupCall] returns a fixed canned result instead of
  /// invoking the (network/credentialed) lookup extensions. `debugEnvFlag`
  /// returns '' in release, so this can never engage there.
  static final bool stubLookups =
      debugEnvFlag(const String.fromEnvironment('HALO_STUB_LOOKUPS'), 'HALO_STUB_LOOKUPS').isNotEmpty;

  /// Runs the full lookup pipeline for one callsign — the hardcoded
  /// callsign-annotation pre-step plus every registered `lookup` hook
  /// (QRZ, HamDB, POTA, SOTA…), merged with locationScope-aware rules —
  /// entirely inside the JS runtime via the single `lookupService/core`
  /// hook (mirrors `ScoringService`'s "one coarse call in, everything back
  /// out" shape). `online: false` asks every hook to skip network access
  /// (for a fast local-data-only preview pass); `qso`/`operation` give
  /// QSO-scoped hooks (e.g. POTA) access to refs already on the in-progress
  /// QSO. Returns `{lookups: [...], guess: {...}}`, or null if the runtime
  /// isn't up or nothing came back.
  ///
  /// `recentContext: true` additionally runs the `recentContextLookup` hooks
  /// (spot history, and whatever else comes to describe what a station is
  /// doing right now). Only the logging panel's compose path sets it: those
  /// hooks' answers are meaningless for a saved QSO being re-enriched, for
  /// the spots board's own per-call annotation, or for the quick lookup
  /// dialog — and each of those fans out over far more callsigns than the
  /// one being typed.
  Future<Map<String, dynamic>?> lookupCall(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    bool online = true,
    bool recentContext = false,
  }) async {
    if (stubLookups) return call.length < 3 ? null : stubbedLookupResult(call);
    final host = _host;
    if (host == null || call.length < 3) return null;

    try {
      final result = await host.invokeHook(
        'lookupService',
        key: 'core',
        method: 'lookupCallInfo',
        args: {
          'callInfo': {'call': call},
          'qso': qso,
          'operation': operation,
          'online': online,
          'recentContext': recentContext,
        },
        timeout: const Duration(seconds: 8),
      );
      if (result is! Map) return null;
      return result.cast<String, dynamic>();
    } on ExtensionHostException catch (e, st) {
      debugPrint('[extensions] lookup failed: $e');
      ErrorReportingService.report(e, st, context: 'extensions:lookup-call');
      return null;
    }
  }

  /// `{hookKey: scope}` for every `scoring` hook. `scope` is a plain data
  /// member on each hook (same access pattern as `spots`' `sourceName`), either
  /// the string `'always'` or `{refTypes: [...]}`, so the core can decide which
  /// scorers an operation needs *before* invoking any of them — a user may have
  /// dozens of extensions enabled while an operation references a handful
  /// (docs/design/contests.md §5.1).
  Future<Map<String, dynamic>> getScoringScopes() async {
    final host = _host;
    if (host == null) return const {};
    try {
      final entries = await host.invokeHookAll('scoring', method: 'scope', timeout: const Duration(seconds: 5));
      return {
        for (final entry in entries)
          if (entry['ok'] == true && entry['value'] != null) entry['key'] as String: entry['value'],
      };
    } catch (e) {
      debugPrint('[extensions] getScoringScopes failed: $e');
      return const {};
    }
  }

  /// The scoring hook keys relevant to [operation], paired with the ref that
  /// selected each. An `'always'` scorer maps to a null ref; a ref-gated one is
  /// listed once per matching ref TYPE — two refs of one type are ONE
  /// invocation, carrying the first, so an operation running two events of the
  /// same contest scores only one of them.
  /// [segments] resolves the operation's `break`/`start` overrides. Selection
  /// spans EVERY segment: a contest that only covers the back half of a log
  /// would never be invoked if this read the base operation alone
  /// (docs/design/contests.md §5.1.3). The ref handed back is the first
  /// occurrence — the harness re-resolves it per QSO from the segment-effective
  /// operation, so a segment that restates its setup still wins.
  static List<({String key, Map<String, dynamic>? ref})> scorersFor(
    Map<String, dynamic> operation,
    Map<String, dynamic> scopes, {
    SegmentedOperation? segments,
  }) {
    final refs = [
      for (final segment in segments?.segments ?? const [])
        ...segment.refs,
      if (segments == null)
        ...((operation['refs'] as List?) ?? const [])
            .whereType<Map>()
            .map((r) => r.cast<String, dynamic>()),
    ];

    final selected = <({String key, Map<String, dynamic>? ref})>[];
    for (final entry in scopes.entries) {
      final scope = entry.value;
      if (scope == 'always') {
        selected.add((key: entry.key, ref: null));
        continue;
      }
      final refTypes = ((scope is Map ? scope['refTypes'] : null) as List?)?.whereType<String>().toSet();
      if (refTypes == null || refTypes.isEmpty) continue;
      final seen = <String>{};
      for (final ref in refs) {
        final type = ref['type'];
        if (type is! String || !refTypes.contains(type)) continue;
        // One selection per type, however many segments carry it.
        if (seen.add(type)) selected.add((key: entry.key, ref: ref));
      }
    }
    return selected;
  }

  /// One scorer's batched pass over an operation's QSOs. [resumeFrom] hands back
  /// that scorer's cached end-of-log scoresheet so only [qsos] — a tail — needs
  /// replaying; omit it for a full pass.
  Future<Map<String, dynamic>?> scoreQsos({
    required String scorerKey,
    required Map<String, dynamic> args,
  }) async {
    final host = _host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook(
        'scoring',
        key: scorerKey,
        method: 'scoreQsos',
        args: args,
        timeout: const Duration(seconds: 10),
      );
      return result is Map ? result.cast<String, dynamic>() : null;
    } catch (e) {
      // One contest's scorer blowing up must not cost the operation its core
      // scoring, so failures are per-scorer.
      debugPrint('[extensions] scoreQsos($scorerKey) failed: $e');
      return null;
    }
  }

  /// Scores the single in-progress QSO — the callsign being typed, before
  /// Enter — for the logging panel's live call-info line. Returns
  /// `{notices, alerts}` of scoring keys (`duplicate`, `newBand`, `newMode`,
  /// `newDXCC`, `newState`, `newProvince`, plus whatever a contest scorer emits
  /// — the vocabulary is open), merged across every scorer relevant to the
  /// operation, or null
  /// when the runtime isn't up. Debounced on the caller's side.
  /// [excludeUuid] drops the record being edited so it can't flag itself as
  /// its own duplicate. [operation] must carry `uuid` (the hook reads the log
  /// via it) — pass the same uuid-folded shape command hooks get.
  ///
  /// [operation] is the CURRENT segment, not the base, so scorer selection
  /// follows what the operator is doing right now: a contest that ended at a
  /// break stops contributing pills, one that started at a break begins.
  /// [segments] (`SegmentedOperation.payload`, omitted when unsegmented) is
  /// what lets the hook fold the history under each QSO's own segment
  /// (docs/design/contests.md §5.1.3).
  Future<Map<String, dynamic>?> scoreQso({
    required Map<String, dynamic> operation,
    required Map<String, dynamic> qso,
    String? excludeUuid,
    List<Map<String, dynamic>>? segments,
  }) async {
    final host = _host;
    if (host == null) return null;

    final scorers = scorersFor(operation, await getScoringScopes());
    if (scorers.isEmpty) return null;

    // Sorted by scorer key so the merged notice/alert order is stable —
    // invokeHookAll gives no ordering guarantee, and the call-info line builds
    // a dedupe signature by joining these lists.
    final notices = SplayTreeSet<String>();
    final alerts = SplayTreeSet<String>();
    var any = false;

    await Future.wait(scorers.map((scorer) async {
      try {
        final result = await host.invokeHook(
          'scoring',
          key: scorer.key,
          method: 'scoreQso',
          args: {
            'operation': operation,
            'qso': qso,
            'excludeUuid': ?excludeUuid,
            'ref': ?scorer.ref,
            'segments': ?segments,
          },
          timeout: const Duration(seconds: 4),
        );
        if (result is! Map) return;
        any = true;
        notices.addAll(((result['notices'] as List?) ?? const []).whereType<String>());
        alerts.addAll(((result['alerts'] as List?) ?? const []).whereType<String>());
      } catch (e) {
        debugPrint('[extensions] scoreQso(${scorer.key}) failed: $e');
      }
    }));

    if (!any) return null;
    return {'notices': notices.toList(), 'alerts': alerts.toList()};
  }

  /// Asks every registered `command` hook (priority order) to interpret the input command.
  /// Returns the first non-null interpretation result: `{describe, confirm, commands}`.
  /// Returns null when nothing matched, the input is empty, or the runtime isn't up.
  /// [execute] should be true only for the final call made right before
  /// actually running a complete interpretation — see CommandHook.interpret's
  /// `execute` doc (extensions/sdk/src/types.ts). Every other call (the
  /// typing-debounce describe preview) should leave it false.
  Future<Map<String, dynamic>?> interpretCommand(
    String input, [
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    bool execute = false,
  ]) async {
    final host = _host;
    if (host == null || input.isEmpty) return null;
    try {
      final entries = await host.invokeHookAll(
        'command',
        method: 'interpret',
        args: {
          'input': input,
          'operation': ?operation,
          'qso': ?qso,
          if (execute) 'execute': true,
        },
        // The describe preview must stay snappy (it reruns on every
        // keystroke pause), but the one execute call is where hooks do
        // real work — SEED's log read + lookups, SOLAR/WEATHER's network
        // fetch — so it gets room to breathe instead of dying at 2s.
        timeout: execute ? const Duration(seconds: 30) : const Duration(seconds: 2),
      );
      for (final entry in entries) {
        if (entry['ok'] == true && entry['value'] is Map) {
          return (entry['value'] as Map).cast<String, dynamic>();
        }
      }
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] interpretCommand failed: $e');
      // At execute time the user pressed Enter on a recognized command —
      // returning null here would read as "no command matched" and the UI
      // would silently do nothing after a long wait (a hook exceeding its
      // timeout, e.g. a stalled SOLAR/WEATHER fetch, lands here). Surface
      // it through the same `error` channel a hook itself would use.
      if (execute) return {'error': t.extensionService.commandFailed};
    }
    return null;
  }

  /// Every command advertised by a `command` hook's optional `catalog()`, for
  /// the command dialog's browsable list — `{command, describe, params?,
  /// category?, needsOperation?, expectsParams?, suggest?}` per entry (see
  /// `CommandCatalogEntry`, extensions/sdk/src/types.ts).
  ///
  /// Cached, deliberately: unlike [interpretCommand] this is NOT per
  /// keystroke — the palette matches the typed text against these entries
  /// host-side, on plain strings. The cache is dropped whenever the runtime is
  /// replaced (extension enable/disable) or the hook context is invalidated
  /// (locale change), which are the only things that change the answer.
  ///
  /// Entries keep hook priority order, so a higher-priority extension's
  /// commands list first, matching which one would actually win `interpret`.
  Future<List<Map<String, dynamic>>> getCommandCatalog() async {
    final cached = _commandCatalog;
    if (cached != null) return cached;

    final host = this.host;
    if (host == null) return const [];
    try {
      final entries = await host.invokeHookAll('command', method: 'catalog', timeout: const Duration(seconds: 2));
      final catalog = <Map<String, dynamic>>[];
      for (final entry in entries) {
        // `catalog` is optional on CommandHook, so a hook that doesn't
        // implement it reports not-ok here — that's expected, not a failure.
        if (entry['ok'] != true || entry['value'] is! List) continue;
        for (final item in entry['value'] as List) {
          if (item is! Map) continue;
          final map = item.cast<String, dynamic>();
          // A malformed entry would render as a blank, unselectable row.
          if (map['command'] is! String || (map['command'] as String).isEmpty) continue;
          catalog.add(map);
        }
      }
      _commandCatalog = List.unmodifiable(catalog);
      return _commandCatalog!;
    } catch (e) {
      debugPrint('[extensions] getCommandCatalog failed: $e');
      // Not cached — a transient runtime failure shouldn't leave the palette
      // permanently empty for the rest of the session.
      return const [];
    }
  }

  /// [getCommandCatalog]'s cache. Null means "not read yet"; an empty list is
  /// a real answer (no hook advertises anything).
  List<Map<String, dynamic>>? _commandCatalog;

  /// Descriptors for controls activities want on the logging panel. `qso` is
  /// the in-progress QSO (including any `their.guess` from the callsign
  /// lookup pipeline) — pass it so an extension can key a QSO-scoped
  /// `placeholder`/`transforms` (e.g. a DXCC-derived reference prefix) off
  /// it; omit for a QSO-agnostic refresh (e.g. right after the operation loads).
  Future<List<Map<String, dynamic>>> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) =>
      _collectControls('loggingControls', operationData, qso: qso);

  /// Descriptors for controls activities want in operation settings.
  Future<List<Map<String, dynamic>>> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) =>
      _collectControls('operationControls', operationData, qso: qso);

  /// Lets activities project data they own into generic QSON fields just
  /// before a QSO is written — a contest mirroring the exchange it keeps on
  /// its own ref into `their.exchange`, which is what the QSO row's exchange
  /// column and a plain ADIF export read. See `ActivityHook.processQsoBeforeSave`.
  ///
  /// Returns [qsoData] with every hook's patch merged in, unchanged if nothing
  /// contributed. Degrades silently: a hook that throws or times out must never
  /// cost the operator their QSO, so the save proceeds undecorated.
  ///
  /// Skipped when the operation carries no refs — ordinary logging is the
  /// common case and must not pay a bridge crossing per QSO for a hook only
  /// contests implement.
  Future<Map<String, dynamic>> decorateQsoBeforeSave(
    Map<String, dynamic> qsoData,
    Map<String, dynamic> operationData,
  ) async {
    final host = _host;
    if (host == null) return qsoData;
    final refs = operationData['refs'];
    if (refs is! List || refs.isEmpty) return qsoData;

    try {
      final entries = await host.invokeHookAll(
        'activity',
        method: 'processQsoBeforeSave',
        args: {'qso': qsoData, 'operation': operationData},
        // Saving blocks the operator's next QSO, so a stalled hook loses its
        // contribution rather than the log its pace.
        timeout: const Duration(seconds: 2),
      );
      var merged = qsoData;
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! Map) continue;
        // The hook's own key is what lets a patch touch that extension's ref
        // and no other (see `mergeQsoPatch`). An entry with no key can still
        // project into `their`/`our`, but writes no ref at all.
        final owner = entry['key'];
        merged = mergeQsoPatch(
          merged,
          (entry['value'] as Map).cast<String, dynamic>(),
          owner: owner is String ? owner : '',
        );
      }
      return merged;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] processQsoBeforeSave failed: $e');
      return qsoData;
    }
  }

  Future<List<Map<String, dynamic>>> _collectControls(
    String method,
    Map<String, dynamic> operationData, {
    Map<String, dynamic>? qso,
  }) async {
    final host = _host;
    if (host == null) return const [];
    try {
      final entries = await host.invokeHookAll(
        'activity',
        method: method,
        args: {'operation': operationData, 'qso': ?qso},
      );
      final controls = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! List) continue;
        controls.addAll((entry['value'] as List).cast<Map>().map((c) => c.cast<String, dynamic>()));
      }
      controls.sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
      return controls;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] $method failed: $e');
      return const [];
    }
  }

  /// Candidate activities for the "add activity" search, merged across every
  /// `activity` hook and sorted by `distance / relevance` ascending — a more
  /// relevant hit (relevance is 0..1, higher is better) effectively counts
  /// as closer, so it doesn't lose out to a less relevant but nearer one
  /// (results missing a distance sort after ranked ones — an extension
  /// search hit with no location still surfaces). `location` comes from the operation's
  /// own grid if it has one, otherwise [fallbackLocation] (typically the
  /// device's current GPS position — see ActivitiesView) so nearby
  /// suggestions still work before the operation's location is set.
  /// `callsign` falls back from the operation's own settings to the
  /// operator's global default.
  /// [activityKey] scopes the fan-out to ONE activity extension (the search
  /// field's `pota:` prefix) — that hook alone is asked, rather than every
  /// hook's results being merged and then filtered, so an unrelated
  /// extension's slow search can't hold up a scoped one.
  Future<List<Map<String, dynamic>>> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
    String? activityKey,
  }) async {
    final host = _host;
    if (host == null) return const [];

    final grid = operationData['grid'] as String?;
    final gridLocation = gridToLocation(grid) ?? fallbackLocation;
    final callsign = (operationData['stationCall'] as String?)?.isNotEmpty == true
        ? operationData['stationCall'] as String
        : settings?.activeProfile.operatorCall;

    final args = {
      'operation': operationData,
      if (gridLocation != null) 'location': {'lat': gridLocation.latitude, 'lon': gridLocation.longitude},
      if (callsign != null && callsign.isNotEmpty) 'callsign': callsign,
      if (searchTerm != null && searchTerm.isNotEmpty) 'searchTerm': searchTerm,
    };

    try {
      final entries = activityKey == null
          ? await host.invokeHookAll(
              'activity',
              method: 'suggest',
              args: args,
              timeout: const Duration(seconds: 5),
            )
          // Wrapped in invokeHookAll's own {ok, value} entry shape so the
          // merge below doesn't need a second code path.
          : [
              {
                'ok': true,
                'value': await host.invokeHook(
                  'activity',
                  key: activityKey,
                  method: 'suggest',
                  args: args,
                  timeout: const Duration(seconds: 5),
                ),
              },
            ];

      final suggestions = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! List) continue;
        suggestions.addAll((entry['value'] as List).cast<Map>().map((s) => s.cast<String, dynamic>()));
      }

      return rankActivitySuggestions(suggestions);
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] suggestActivities failed: $e');
      return const [];
    }
  }

  /// The current LoFi account/device/client info, for display in Settings.
  /// Returns null if the runtime isn't up or the request failed (e.g. no
  /// network) — callers should treat that as "status unknown", not "no sync".
  ///
  /// Every fresh fetch also persists the snapshot into
  /// `settings.syncState['accountData']` — the static copy the declarative
  /// sync settings group displays, so building a settings schema never
  /// needs a network round-trip. Only this method (called from the Sync
  /// panel's refreshes and post-link flows) updates it.
  Future<Map<String, dynamic>?> syncAccountData() async {
    final host = _host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook('syncTransport', method: 'getAccountData', args: const {});
      final data = result is Map ? result.cast<String, dynamic>() : null;
      final currentSettings = settings;
      if (data != null && currentSettings != null) {
        final state = currentSettings.syncState;
        // Only write (and notify) on a real change — the Sync panel
        // refreshes on every open.
        if (jsonEncode(state['accountData']) != jsonEncode(data)) {
          await currentSettings.setSyncState({...state, 'accountData': data});
        }
      }
      return data;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] syncAccountData failed: $e');
      return null;
    }
  }

  /// Requests a link permission from the sync server: a pending challenge
  /// for [email] (or an immediate switch when this client already has a
  /// permission on that account), or — with null — a blank permission for
  /// QR-code linking. Server rejections (e.g. no account with that email)
  /// come back as `{'error': ..., 'error_status': ...}` in the map; null
  /// means the server couldn't be reached at all.
  Future<Map<String, dynamic>?> syncLinkClient(String? email) async {
    final host = _host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook(
        'syncTransport',
        method: 'linkClient',
        args: {if (email != null) 'email': email},
      );
      return result is Map ? result.cast<String, dynamic>() : null;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] syncLinkClient failed: $e');
      return null;
    }
  }

  /// Requests a link-by-email challenge from the sync server. Returns null
  /// on failure; callers should surface that as "couldn't reach the server".
  Future<Map<String, dynamic>?> syncLinkClientWithEmail(String email) async {
    final host = _host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook('syncTransport', method: 'linkClientWithEmail', args: {'email': email});
      return result is Map ? result.cast<String, dynamic>() : null;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] syncLinkClientWithEmail failed: $e');
      return null;
    }
  }

  /// Ensures this device is registered with the sync server — independent
  /// of whether the operator has QSO sync enabled; registration
  /// establishes device identity and the realtime push channel, it never
  /// pushes log data. Returns null if the runtime isn't up or registration
  /// failed (e.g. no network) — callers should treat that as "not
  /// available yet", not as "sync is off".
  Future<LofiClientRegistration?> ensureLofiClientRegistered() async {
    final host = _host;
    if (host == null) return null;
    try {
      final result = await host.invokeHook('syncTransport', method: 'ensureClientRegistered', args: const {});
      if (result is! Map) return null;
      final map = result.cast<String, dynamic>();
      final pushChannelName = map['push_channel_name'] as String?;
      final webhookClientToken = map['webhook_client_token'] as String?;
      if (pushChannelName == null || webhookClientToken == null) return null;
      return (pushChannelName: pushChannelName, webhookClientToken: webhookClientToken);
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] ensureLofiClientRegistered failed: $e');
      return null;
    }
  }

  /// Fetches this device's pending webhook events — the poll
  /// fallback, and how a caller retrieves the actual payload after a
  /// [HaLoServices.webhookEvents] Pusher ping (which intentionally carries
  /// only an id, never the sensitive payload).
  Future<List<Map<String, dynamic>>> fetchLofiWebhookEvents() async {
    final host = _host;
    if (host == null) return const [];
    try {
      final result = await host.invokeHook('syncTransport', method: 'fetchWebhookEvents', args: const {});
      final events = result is Map ? result['webhook_events'] : null;
      if (events is! List) return const [];
      return events.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] fetchLofiWebhookEvents failed: $e');
      return const [];
    }
  }

  /// Decorates a ref (park name, location…) via its `ref:<type>` handler.
  /// Returns the input unchanged if no handler answers.
  Future<Map<String, dynamic>> decorateRef(Map<String, dynamic> ref) async {
    final host = _host;
    final type = ref['type'] as String?;
    if (host == null || type == null) return ref;
    try {
      final decorated = await host.invokeHook('ref:$type', method: 'decorateRef', args: {'ref': ref});
      if (decorated is Map) return decorated.cast<String, dynamic>();
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] decorateRef failed: $e');
    }
    return ref;
  }
}

/// One entry of the build index (assets/extensions/index.json) — the static,
/// user-facing metadata build.mjs emits so the app can describe every
/// extension (including disabled ones whose bundles never load). Core
/// entries are always enabled and never listed in the Extensions panel;
/// versions deliberately live only in the runtime (see listActiveExtensions).
class ExtensionInfo {
  final String key;
  final String file;
  final List<String> domains;


  /// Whether this extension may set its own `User-Agent` on host.fetch
  /// (build.mjs `allowUserAgentOverride`). Off by default: the host stamps
  /// HaLo's canonical UA — see docs/design/network.md.
  final bool allowUserAgentOverride;

  /// Whether this extension may call the `getLocation` host call (build.mjs
  /// `requiresLocation`) — the device's raw GPS fix. Off by default,
  /// same allowlist shape as [domains].
  final bool requiresLocation;

  final bool core;
  final String name;
  final String? shortName;
  final String? category;
  final bool enabledByDefault;

  /// MDI icon name (resolveIconName), mirroring the icon the extension's
  /// own hooks use (e.g. POTA's 'pine-tree'); null falls back to a
  /// category icon in the panel.
  final String? icon;
  final String? description;

  /// The extension's brand accent as a #RRGGBB hex string (manifest.json
  /// `accentColor`, e.g. POTA's green) — informational, for hosts that
  /// want to tint extension UI.
  final String? accentColor;

  /// Extra Extensions-panel search terms beyond name/description.
  final List<String> keywords;

  /// The hook categories the extension's manifest declares (informational;
  /// the runtime learns actual hooks from registerHook).
  final List<String> hooks;

  /// Per-locale overrides for [name]/[description] plus extra localized
  /// search [keywords] (manifest.json `translations`, baked into index.json
  /// so they're readable without running any JS, same as the base
  /// metadata). Keyed by language code; a missing locale or field falls
  /// back to the English base value.
  final Map<String, Map<String, Object?>> translations;

  const ExtensionInfo({
    required this.key,
    required this.file,
    this.domains = const [],
    this.allowUserAgentOverride = false,
    this.requiresLocation = false,
    required this.core,
    required this.name,
    this.shortName,
    this.category,
    this.enabledByDefault = true,
    this.icon,
    this.description,
    this.accentColor,
    this.keywords = const [],
    this.hooks = const [],
    this.translations = const {},
  });

  String get effectiveShortName => shortName ?? name;

  String nameFor(String locale) => (translations[locale]?['name'] as String?) ?? name;
  String? descriptionFor(String locale) => (translations[locale]?['description'] as String?) ?? description;

  /// The base [keywords] plus the locale's extra ones — localized keywords
  /// add to the English set (both stay searchable), they don't replace it.
  List<String> keywordsFor(String locale) => [
        ...keywords,
        ...((translations[locale]?['keywords'] as List?) ?? const []).cast<String>(),
      ];

  /// Whether a user's search text should surface this extension. Matches the
  /// key, the name and description in BOTH the given locale and English (so
  /// either spelling finds it), and the keywords. [query] is expected
  /// already trimmed; an empty one matches nothing, since "show everything"
  /// is the caller's decision, not a match.
  bool matchesSearch(String query, {required String locale}) {
    if (query.isEmpty) return false;
    final needle = query.toLowerCase();
    return key.toLowerCase().contains(needle) ||
        name.toLowerCase().contains(needle) ||
        nameFor(locale).toLowerCase().contains(needle) ||
        (description ?? '').toLowerCase().contains(needle) ||
        (descriptionFor(locale) ?? '').toLowerCase().contains(needle) ||
        keywordsFor(locale).any((keyword) => keyword.toLowerCase().contains(needle));
  }

  factory ExtensionInfo.fromJson(Map<String, dynamic> json) => ExtensionInfo(
        key: json['key'] as String,
        file: json['file'] as String? ?? '${json['key']}.js',
        domains: ((json['domains'] as List?) ?? const []).cast<String>(),
        allowUserAgentOverride: json['allowUserAgentOverride'] as bool? ?? false,
        requiresLocation: json['requiresLocation'] as bool? ?? false,
        // A stale index without metadata degrades to "everything core" —
        // the fail-safe: nothing gets silently disabled.
        core: json['core'] as bool? ?? true,
        name: json['name'] as String? ?? json['key'] as String,
        shortName: json['shortName'] as String?,
        category: json['category'] as String?,
        enabledByDefault: json['enabledByDefault'] as bool? ?? true,
        icon: json['icon'] as String?,
        description: json['description'] as String?,
        accentColor: json['accentColor'] as String?,
        keywords: ((json['keywords'] as List?) ?? const []).cast<String>(),
        hooks: ((json['hooks'] as List?) ?? const []).cast<String>(),
        translations: {
          for (final entry in ((json['translations'] as Map?) ?? const {}).entries)
            entry.key as String: (entry.value as Map).cast<String, Object?>(),
        },
      );
}
