// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Owns the app's single ExtensionHost instance (background isolate) and exposes
// domain-shaped calls on top of raw hook invocations. Boots asynchronously at
// app start; every caller must tolerate `ready == false` — a missing or
// broken extension runtime degrades features, never the core loop.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:halo_core/halo_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'settings_service.dart';
import 'status_bar_service.dart';
import 'package:halo_widgets/halo_widgets.dart';
import '../config/user_agent.dart';
import '../i18n/strings.g.dart';
import '../main.dart';

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
  bool _restarting = false;
  ({String deviceKey, String operatorCall})? _lastSyncCredentials;
  final _secureStorage = const FlutterSecureStorage(
    mOptions: MacOsOptions(
      usesDataProtectionKeychain: false,
      accountName: 'Ham2K Logger',
    ),
    iOptions: IOSOptions(
      accountName: 'Ham2K Logger',
    ),
  );

  SettingsService? settings;
  LookupRepository? lookups;
  StatusBarService? statusBar;

  /// Back the `getOperation`/`getQsos` host calls (HookContext.getOperation/
  /// getQsos in the SDK). Optional like the other service references — a
  /// host without them (bench harnesses, focused tests) answers those calls
  /// with null/empty instead of failing.
  OperationsRepository? operations;
  QsosRepository? qsos;

  bool get ready => _host != null;
  ExtensionHost? get host => _host;

  Future<void> start() {
    return _starting ??= _start();
  }

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final host = _host;
    if (host == null) return const [];
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
      return const [];
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

  /// Every export option offered by every `export` hook (Exports Panel,
  /// ham2k/app-halo-dist#4). Hooks that don't implement
  /// `suggestExportOptions` are silently absent from the list.
  Future<List<Map<String, dynamic>>> getExportOptions(Map<String, dynamic> args) => _collectHookResults(
        'export',
        method: 'suggestExportOptions',
        args: args,
        debugLabel: 'getExportOptions',
      );

  /// Every `spots` hook currently willing to post a spot (Spotting control,
  /// ham2k/app-halo-dist#10), each tagged with `hookKey` so a later
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

  /// Every spot offered by every `spots` hook (Spots Panel,
  /// ham2k/app-halo-dist#9), each tagged with `hookKey` so the panel can
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
    return {for (final entry in entries) entry.key: entry.value};
  }

  Future<String> testCredentials(String accountKey, Map<String, String> credentials) async {
    final host = _host;
    if (host == null) return 'Extension runtime not ready.';
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
      return 'Test failed: $e';
    }
  }

  Future<Map<String, String>> getAccountCredentials(String kvKey) async {
    final raw = await _secureStorage.read(key: 'account_creds_$kvKey');
    if (raw == null) return const {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return const {};
    }
  }

  Future<void> setAccountCredentials(String kvKey, Map<String, String> credentials) async {
    await _secureStorage.write(key: 'account_creds_$kvKey', value: jsonEncode(credentials));
    // Fresh credentials must reach the very next hook call, not whatever
    // the kernel's context cache still holds.
    _host?.invalidateHookContext();
  }

  Future<void> clearAccount(String kvKey) async {
    await _secureStorage.delete(key: 'account_creds_$kvKey');
    await _secureStorage.delete(key: 'account_session_$kvKey');
    _host?.invalidateHookContext();
  }

  /// Drops the kernel's cached HookContext so the next hook call sees fresh
  /// core state — call after mutating anything a HookContext carries
  /// (locale, theme, developer mode). No-op before the runtime is up.
  void invalidateHookContext() => _host?.invalidateHookContext();

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
      if (creds.isEmpty) return {'connected': false};
      final identity = identityFromCredentials(creds);
      return {'connected': true, if (identity != null) 'label': 'Connected as $identity'};
    } catch (e) {
      debugPrint('[extensions] _resolveAccountStatus failed for $accountKey: $e');
      return {'connected': false};
    }
  }

  /// Picks a human-readable identity out of a credentials map — the same
  /// priority (`username` then `email` then `login`) used everywhere in
  /// Settings that displays which account a set of stored credentials
  /// belongs to.
  static String? identityFromCredentials(Map<String, String> creds) {
    return creds['username'] ?? creds['email'] ?? creds['login'];
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
        return 'Invalid field configuration';
      }
      return field['patternError'] as String? ?? 'Invalid value';
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
      return 'Validation error: $e';
    }
  }

  /// Commits one field's value after it's been accepted (validated, and for
  /// Tier 2, transformed). Tier 1 persists directly to Dart-owned storage —
  /// kv (SharedPreferences) normally, `FlutterSecureStorage` for
  /// `fieldType: 'secret'`. Tier 2 has no local persistence at all; the
  /// call is forwarded to `onChangeField` and the extension is responsible
  /// for storing it itself (e.g. its own `host.kvSet`).
  Future<void> commitSettingsFieldValue({
    required String kind,
    required String hookKey,
    required String panelKey,
    required String fieldKey,
    required dynamic value,
    required Map<String, dynamic> state,
    bool isSecret = false,
  }) async {
    if (kind == 'simple') {
      await _writeSettingsValue(panelKey: panelKey, fieldKey: fieldKey, value: value, isSecret: isSecret);
      return;
    }
    final host = this.host;
    if (host == null) return;
    try {
      await host.invokeHook(
        'settingsPanel',
        key: hookKey,
        method: 'onChangeField',
        args: {'panelKey': panelKey, 'fieldKey': fieldKey, 'value': value, 'state': state},
      );
    } catch (e) {
      debugPrint('[extensions] settingsPanel onChangeField failed: $e');
    }
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
    if (host == null) return 'Extension runtime not ready.';
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
      return 'Action failed: $e';
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
    try {
      final index = jsonDecode(await rootBundle.loadString('assets/extensions/index.json')) as Map<String, dynamic>;
      final kernelSource = await rootBundle.loadString('assets/extensions/${index['kernel']}');
      final available = await loadAvailableExtensions(index: index);
      final bundles = <ExtensionBundle>[];
      final fetchAllowlists = <String, List<String>>{};
      final userAgentOverrides = <String>{};
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
      }
      _host = await ExtensionHost.start(
        kernelSource: kernelSource,
        extensions: bundles,
        onHostCall: _handleHostCall,
        fetchAllowlists: fetchAllowlists,
        userAgent: await ham2kUserAgent(),
        userAgentOverrides: userAgentOverrides,
      );
      _loadedExtensionKeys = loaded;
      _host!.logs.listen((line) => debugPrint('[extensions] $line'));
      for (final line in _host!.logLines) {
        debugPrint('[extensions] $line');
      }
      // A crashed runtime (isolate death, worker crash) is replaced, not
      // mourned: DESIGN.md's contract is that extensions degrade, they
      // don't stay dark until app restart.
      _host!.fatalErrors.listen((error) => _scheduleRestart('runtime died: $error'));
      _restartAttempts = 0;
      runtimeGeneration.value++;
    } catch (e) {
      debugPrint('[extensions] failed to start extension runtime: $e');
      // A transient boot failure (asset hiccup, engine init) used to leave
      // extensions off for the rest of the session ("_starting" memoized
      // the failure). Retry with backoff instead.
      _scheduleRestart('start failed: $e');
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
    final delay = Duration(seconds: 1 << _restartAttempts.clamp(1, 5)); // 2s..32s, then flat
    debugPrint('[extensions] $reason — restarting runtime in ${delay.inSeconds}s (attempt $_restartAttempts)');
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
  /// the in-memory sync KV. Serialized behind [_restarting].
  Future<void> _replaceRuntime({required bool onlyIfDead}) async {
    if (_restarting) return;
    _restarting = true;
    try {
      // A boot may already be in flight (e.g. setSyncCredentials calls
      // start()); replacing the host under it would leak a live runtime.
      final inFlight = _starting;
      if (inFlight != null) await inFlight;
      if (onlyIfDead && _host != null && !_host!.isDead) return; // recovered on its own

      final old = _host;
      _host = null;
      _starting = null;
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
      _restarting = false;
    }
  }

  Future<dynamic> _handleHostCall(String method, Map<String, dynamic> params) async {
    switch (method) {
      case 'getAccount':
        final kvKey = params['kvKey'] as String;
        final credsStr = await _secureStorage.read(key: 'account_creds_$kvKey');
        final sessionStr = await _secureStorage.read(key: 'account_session_$kvKey');
        return {
          'credentials': credsStr != null ? jsonDecode(credsStr) : const {},
          'session': sessionStr != null ? jsonDecode(sessionStr) : const {},
        };
      case 'setAccountSession':
        final kvKey = params['kvKey'] as String;
        final session = params['session'] as Map<dynamic, dynamic>;
        await _secureStorage.write(key: 'account_session_$kvKey', value: jsonEncode(session));
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
          'appName': ham2kAppName,
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
              return 'Validation error: $e';
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
      final type = map['type'] as String?;
      if (label == null || type == null) continue;
      switch (type) {
        case 'link':
          final url = map['url'] as String?;
          if (url == null) continue;
          actions.add(StatusBarAction(
            label: label,
            onTap: () => launchUrl(Uri.parse(url)),
          ));
        case 'dialog':
          final text = map['text'] as String? ?? '';
          final title = map['title'] as String?;
          actions.add(StatusBarAction(
            label: label,
            onTap: () {
              final context = navigatorKey.currentContext;
              if (context == null) return;
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: title != null ? Text(title) : null,
                  content: SingleChildScrollView(child: MarkdownBody(data: text)),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                  ],
                ),
              );
            },
          ));
      }
    }
    return actions;
  }

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
  Future<Map<String, dynamic>?> lookupCall(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    bool online = true,
  }) async {
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
        },
        timeout: const Duration(seconds: 8),
      );
      if (result is! Map) return null;
      return result.cast<String, dynamic>();
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] lookup failed: $e');
      return null;
    }
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
      if (execute) return {'error': 'The command failed to run'};
    }
    return null;
  }

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
  Future<List<Map<String, dynamic>>> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
  }) async {
    final host = _host;
    if (host == null) return const [];

    final grid = operationData['grid'] as String?;
    final gridLocation = gridToLocation(grid) ?? fallbackLocation;
    final callsign = (operationData['stationCall'] as String?)?.isNotEmpty == true
        ? operationData['stationCall'] as String
        : settings?.activeProfile.operatorCall;

    try {
      final entries = await host.invokeHookAll(
        'activity',
        method: 'suggest',
        args: {
          'operation': operationData,
          if (gridLocation != null) 'location': {'lat': gridLocation.latitude, 'lon': gridLocation.longitude},
          if (callsign != null && callsign.isNotEmpty) 'callsign': callsign,
          if (searchTerm != null && searchTerm.isNotEmpty) 'searchTerm': searchTerm,
        },
        timeout: const Duration(seconds: 5),
      );

      final suggestions = <Map<String, dynamic>>[];
      for (final entry in entries) {
        if (entry['ok'] != true || entry['value'] is! List) continue;
        suggestions.addAll((entry['value'] as List).cast<Map>().map((s) => s.cast<String, dynamic>()));
      }

      double rank(Map<String, dynamic> s) {
        final distance = s['distance'] as num?;
        final relevance = s['relevance'] as num?;
        if (distance == null || relevance == null || relevance <= 0) return double.infinity;
        return (distance / relevance).toDouble();
      }

      suggestions.sort((a, b) => rank(a).compareTo(rank(b)));
      return suggestions;
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

  final bool core;
  final String name;
  final String? category;
  final bool enabledByDefault;

  /// MDI icon name (resolveIconName), mirroring the icon the extension's
  /// own hooks use (e.g. POTA's 'pine-tree'); null falls back to a
  /// category icon in the panel.
  final String? icon;
  final String? description;

  const ExtensionInfo({
    required this.key,
    required this.file,
    this.domains = const [],
    this.allowUserAgentOverride = false,
    required this.core,
    required this.name,
    this.category,
    this.enabledByDefault = true,
    this.icon,
    this.description,
  });

  factory ExtensionInfo.fromJson(Map<String, dynamic> json) => ExtensionInfo(
        key: json['key'] as String,
        file: json['file'] as String? ?? '${json['key']}.js',
        domains: ((json['domains'] as List?) ?? const []).cast<String>(),
        allowUserAgentOverride: json['allowUserAgentOverride'] as bool? ?? false,
        // A stale index without metadata degrades to "everything core" —
        // the fail-safe: nothing gets silently disabled.
        core: json['core'] as bool? ?? true,
        name: json['name'] as String? ?? json['key'] as String,
        category: json['category'] as String?,
        enabledByDefault: json['enabledByDefault'] as bool? ?? true,
        icon: json['icon'] as String?,
        description: json['description'] as String?,
      );
}
