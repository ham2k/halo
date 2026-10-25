// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Owns the app's single ExtensionHost instance (background isolate) and exposes
// domain-shaped calls on top of raw hook invocations. Boots asynchronously at
// app start; every caller must tolerate `ready == false` — a missing or
// broken extension runtime degrades features, never the core loop.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show setEquals, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
// Prefixed alias of the same public library, so the forwarders below can
// reach the shared functions without recursing into themselves.
import 'package:halo_extension_host/halo_extension_host.dart' as priority;
import 'package:halo_core/halo_core.dart';
import 'catalog_service.dart';
import '../connectivity_service.dart';
import '../error_reporting_service.dart';
import 'export_type_registry.dart';
import 'extension_account_cache.dart';
import 'extension_info.dart';
import 'extension_keychain.dart';
import 'extension_force_disable.dart';
import 'extension_refusals.dart';
import 'extension_messages.dart';
import 'extension_ref_results.dart';
import 'extension_catalog_migration.dart';
import 'extension_disabled_since.dart';
import 'extension_secrets.dart';
import 'extension_chasing.dart';
import 'extension_scoring.dart';
import 'installed_extensions.dart';
import 'preloaded_extensions.dart';
import '../location_service.dart';
import '../panel_service.dart';
import 'cluster_host_calls.dart';
import 'radio_host_calls.dart';
import 'settings_placement.dart';
import '../settings_service.dart';
import '../spots_service.dart';
import '../status_bar_service.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../config/secrets.dart';
import '../../config/dev_flags.dart';
import '../../config/experiments.dart';
import '../../config/dev_fixture.dart';
import '../../config/device_identity.dart';
import '../../config/user_agent.dart';
import '../../config/version.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../config/navigation.dart';
import '../../tools/backoff.dart';
import '../../tools/activity_suggestions.dart';
import '../../tools/date_order.dart';
import '../../tools/qso_patch.dart';
import 'engine_load_monitor.dart';

// The types callers pair with the runtime: one import serves both.
export 'extension_info.dart';
export 'settings_placement.dart' show ExtensionSettingsPlacement;
export 'extension_ref_results.dart';

// One class, one library, several files. The pieces share the runtime's
// private state — the keychain gate `_start` resets, the restart future a
// settings commit waits on, the `_host` field the fake host cannot reach — so
// each is a mixin in a part of this library rather than a library of its own,
// and each declares at its top what it reads of the rest.
part 'extension_hook_api.dart';
part 'extension_sync_calls.dart';
part 'extension_panels.dart';
part 'extension_accounts.dart';
part 'extension_installs.dart';
part 'extension_host_calls.dart';

/// An extension's timers, suspended for breaking their budget
/// (extensions/sdk/src/timerQueue.ts). Its own type so the crash backend can
/// say which extensions trip it in the field, and how often: the operator
/// sees only a feature stop, and outside developer mode nothing else says why.
class ExtensionTimersSuspended implements Exception {
  const ExtensionTimersSuspended(this.extensionKey, this.reason);

  final String extensionKey;
  final String reason;

  @override
  String toString() => 'timers of $extensionKey suspended ($reason)';
}

class ExtensionService
    with
        ExtensionScoring,
        ExtensionChasing,
        _ExtensionHookApi,
        _ExtensionSyncCalls,
        _ExtensionPanels,
        _ExtensionAccounts,
        _ExtensionInstalls,
        WidgetsBindingObserver {
  @override
  ExtensionHost? _host;
  @override
  Future<void>? _starting;
  Timer? _restartTimer;
  int _restartAttempts = 0;

  /// The in-flight [_replaceRuntime] call, if any — [commitSettingsFieldValue]
  /// awaits this instead of bailing out when [host] is momentarily null
  /// mid-restart, so a commit that lands in that window still reaches the
  /// fresh runtime instead of silently no-oping.
  @override
  Future<void>? _restartFuture;

  /// Set by [shutdownForExit], never cleared: from then on nothing brings a
  /// runtime back, because a runtime alive while the VM tears down is the
  /// crash that method exists to prevent.
  bool _exiting = false;

  /// True when the last runtime start proceeded past the bounded activation
  /// wait without every extension's onActivation settling — hook
  /// registrations may be INCOMPLETE for this generation. Consumers that
  /// treat the hook set as authoritative (the data-file orphan purge) must
  /// check this and stand down rather than act on a partial picture.
  @override
  bool get activationIncomplete => _activationIncomplete;
  bool _activationIncomplete = false;
  ({String deviceKey, String operatorCall})? _lastSyncCredentials;

  @override
  SettingsService? settings;
  LookupRepository? lookups;
  @override
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

  /// The radio host calls, behind their manifest capabilities.
  final radioCalls = RadioHostCalls();

  /// The DX cluster host calls, behind their manifest capabilities.
  final clusterCalls = ClusterHostCalls();

  /// Backs the `getSpotsForCall` host call (HookContext.getSpotsForCall),
  /// which the `spot-history` lookup hook reads. Optional like the other
  /// service references — a host without it answers with an empty list, so
  /// the hook simply contributes nothing.
  SpotsService? spots;

  /// Where a withdrawn built-in's twin is fetched from. Null before
  /// HaLoServices wires it, which simply means nothing is adopted.
  @override
  CatalogService? catalog;

  /// Who may call `getLocation` (manifest.json `requiresLocation`), resolved
  /// once at load time in [_start].
  CapabilityGrant _location = const CapabilityGrant();

  bool get ready => _host != null;
  @override
  ExtensionHost? get host => _host;

  /// How idle the engine has been, followed across every runtime this
  /// service boots.
  late final engineLoad = EngineLoadMonitor(consented: () => settings?.consentAppData ?? false);

  @override
  Future<void> start() {
    if (_exiting) return Future.value();
    // Attached here rather than in a constructor: the service is built long
    // before any runtime exists, and this is the one path every start (and
    // every restart, through _start) goes through.
    if (!_clockListenerAttached) {
      _clockListenerAttached = true;
      AppClock.instance.addListener(_pushClockTravel);
    }
    return _starting ??= _start();
  }

  /// What [ask] answers from a runtime that is up, or from none once a boot
  /// or replacement has settled without one.
  ///
  /// A replacement fails every call pending on the host it disposes, so a
  /// call it catches answers empty or null while no runtime is up — which
  /// reads as "nothing registered", or as a runtime that failed to start.
  /// It is asked again of whatever the replacement brought up. A runtime
  /// that did fail to come up answers as no host does, and [ready] says so.
  ///
  /// With no host up it waits for the whole replacement, not just [start]:
  /// a caller that queued on a boot behind a replacement resumes after the
  /// replacement has taken the host down. With a host up it asks at once, so
  /// a call made from inside a hook — `searchSettings`, during activation —
  /// never waits on the boot that is running it.
  Future<T> whenSettled<T>(Future<T> Function() ask) async {
    while (true) {
      if (host == null) await (_restartFuture?.catchError((_) {}) ?? start());
      final asked = host;
      final answer = await ask();
      if (identical(asked, host)) return answer;
    }
  }

  bool _clockListenerAttached = false;

  /// The app clock's travel state, in the form the sandbox needs
  /// (docs/design/time.md §6).
  ClockTravelState _clockTravelState() {
    final clock = AppClock.instance;
    return ClockTravelState(anchorRealMillis: clock.anchorRealMillis, anchorVirtualMillis: clock.anchorVirtualMillis, speed: clock.speed);
  }

  /// Pushes a CHANGE of travel into a running sandbox. Registered as an
  /// [AppClock] listener for the life of the service; a runtime that boots
  /// later gets the state through [ExtensionHost.start] instead, which is the
  /// only way to be in place before extensions activate.
  void _pushClockTravel() {
    final clock = _clockTravelState();
    final host = _host;
    if (host == null) {
      // No runtime to push into — the whole of a boot or a restart, which is
      // seconds of bundle loading and activation. Swallowing this leaves the
      // sandbox on a clock the app is not on for the LIFE of that runtime,
      // because a boot already snapshotted the state it started with and
      // nothing reconciles the two afterwards. The re-push at the end of
      // `_start` is what actually closes the window; this says so when it
      // happens.
      debugPrint('[extensions] clock travel not pushed: no runtime yet (re-pushed once it boots)');
      return;
    }
    host.setClockTravel(anchorRealMillis: clock.anchorRealMillis, anchorVirtualMillis: clock.anchorVirtualMillis, speed: clock.speed);
  }

  /// Whether the app is in view, as extensions were last told (their
  /// `onShow`/`onHide`). Kept here because the runtime is replaced whole:
  /// each new one starts out assuming the app is visible and is told the
  /// truth once it boots.
  bool _appVisible = true;

  /// Tells extensions the app was shown or hidden. Driven by
  /// [observeAppLifecycle].
  void setAppVisible(bool visible) {
    // Every focus change on desktop reports inactive then resumed — both
    // visible — and each would otherwise be a message and an evaluation in
    // the one engine every hook call queues on.
    if (visible == _appVisible) return;
    _appVisible = visible;
    _host?.setAppVisible(visible);
  }

  /// Follows the app's lifecycle into [setAppVisible] for the rest of the
  /// session. Called once, from main, where a binding exists.
  void observeAppLifecycle() {
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null) didChangeAppLifecycleState(state);
  }

  /// Visible means what it means to the panes: resumed, or merely inactive —
  /// a dialog over the window, or the app switcher opening.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setAppVisible(state == AppLifecycleState.resumed || state == AppLifecycleState.inactive);
  }

  /// Reports an extension whose timers the runtime suspended, and names it in
  /// a notice in developer mode only: the operator can do nothing about it and
  /// the extension's hooks still answer, but its author needs to know which
  /// extension and why, and on a phone the console is out of reach.
  void _noticeTimerSuspension(TimerSuspension suspension) {
    ErrorReportingService.report(ExtensionTimersSuspended(suspension.extensionKey, suspension.reason), StackTrace.current, context: 'extensions:timers');
    if (settings?.developerMode != true) return;
    final info = availableExtensions.where((info) => info.key == suspension.extensionKey).firstOrNull;
    final name = info?.nameFor(LocaleSettings.currentLocale.languageCode) ?? suspension.extensionKey;
    final text = switch (suspension.reason) {
      'failures' => t.extensionService.timersSuspendedFailures(name: name),
      'interrupted' => t.extensionService.timersSuspendedInterrupted(name: name),
      _ => t.extensionService.timersSuspendedBudget(name: name),
    };
    statusBar?.showNotice(key: 'extension-timers:${suspension.extensionKey}', icon: 'timer-alert-outline', text: text, persist: false);
  }

  /// Drops the kernel's cached HookContext so the next hook call sees fresh
  /// core state — call after mutating anything a HookContext carries
  /// (locale, theme, developer mode). No-op before the runtime is up.
  @override
  void invalidateHookContext() {
    // The command catalog's `describe` strings are localized by the hook
    // against that same context, so a stale cache would keep the palette in
    // the previous language after a locale switch (⌘⇧L).
    _commandCatalog = null;
    _host?.invalidateHookContext();
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

  /// The LoFi app-attestation secret, injected at build time
  /// (`flutter build ... --dart-define=HAM2K_LOFI_SECRET=...`) — the same
  /// role as app-polo's `Config.HAM2K_LOFI_SECRET` from react-native-config.
  /// It identifies the *build* to the server, not the device (the device
  /// key does that); dev builds without the define fall back to the
  /// extension's 'no-secret' default, exactly like app-polo dev builds.
  static const _lofiSecret = String.fromEnvironment('HAM2K_LOFI_SECRET');

  /// Shared secret for the standalone LoFi backup capture service
  /// (`flutter build ... --dart-define=HAM2K_BACKUP_TOKEN=...`). Unset means
  /// the extension's fallback capture on a LoFi failure is a no-op — same
  /// shape as `_lofiSecret` going unset, just with "skip the feature" as the
  /// fallback instead of a shared dev default.
  static const _backupToken = String.fromEnvironment('HAM2K_BACKUP_TOKEN');

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
    final seed = lofiClientSeed(await deviceIdentity(), appVersion: await haloVersionLabel());
    // No `await` from here on: a registration racing this seeding (boot starts
    // sync right after) would otherwise read `key` without `secret` and
    // register under the default secret.
    _host?.setKV('ham2k-lofi', 'key', deviceKey);
    _host?.setKV('ham2k-lofi', 'call', operatorCall);
    for (final entry in seed.entries) {
      _host?.setKV('ham2k-lofi', entry.key, entry.value);
    }
    if (_lofiSecret.isNotEmpty) _host?.setKV('ham2k-lofi', 'secret', _lofiSecret);
    if (_backupToken.isNotEmpty) _host?.setKV('ham2k-lofi', 'backupToken', _backupToken);
  }

  /// What `ham2k-lofi` is told about this device. `clientName` is what a
  /// device already on the account is asked to approve — PoLo's confirmation
  /// dialog names it — so it's the device's own name, as PoLo sends, or which
  /// app this is when the platform has no name to give. `deviceName` is what
  /// the server renames an already-registered client from; left out where
  /// there is no name, so the client keeps the one it has.
  @visibleForTesting
  static Map<String, Object> lofiClientSeed(DeviceIdentity device, {required String appVersion}) => {
    'clientName': device.name.isNotEmpty ? device.name : withEdition(ham2kAppName),
    'diagnostics': {'device': device.description, if (device.name.isNotEmpty) 'deviceName': device.name, 'appVersion': appVersion},
  };

  Future<void> _start() async {
    // Fresh gate per generation: account access blocks on it until the
    // synchronizable flags are resolved (or start fails), so an early lookup
    // can't read an account under the wrong sync flag. Completed in `finally`.
    _accountSyncReady = Completer<void>();
    // The flags the cache was read under may change with this generation.
    _accountItems.clear();
    try {
      await _awaitEarlyForceDisabled();
      final index = jsonDecode(await rootBundle.loadString('assets/extensions/index.json')) as Map<String, dynamic>;
      final kernelSource = await rootBundle.loadString('assets/extensions/${index['kernel']}');
      await loadAvailableExtensions(index: index);
      final available = availableExtensions;
      final bundles = <ExtensionBundle>[];
      final fetchAllowlists = <String, List<String>>{};
      final webSocketAllowlists = <String, List<String>>{};
      final extensionSecrets = <String, Map<String, String>>{};
      final userAgentOverrides = <String>{};
      final loaded = <String>{};
      for (final info in available) {
        // Disabled (or experiment-gated) extensions are simply never
        // loaded — their hooks, settings panels, and commands are absent
        // until a re-enable restarts the runtime with them included.
        if (!isExtensionActive(info)) continue;
        loaded.add(info.key);
        bundles.add(ExtensionBundle(key: info.key, source: await _sourceFor(info), api: info.runtimeApi));
        // The manifest's declared network capabilities (`domains`,
        // `webSockets` and `allowUserAgentOverride`; see
        // extensions/build-config.mjs).
        fetchAllowlists[info.key] = info.domains;
        webSocketAllowlists[info.key] = info.webSockets;
        if (info.allowUserAgentOverride) userAgentOverrides.add(info.key);
        // Resolve what this extension is allowed to see, once, at load time —
        // the host then holds only that subset and needs no policy of its own.
        // A build without a value configured simply has none, and every
        // consumer degrades rather than failing: a fresh checkout must run.
        final visible = visibleSecretsFor(info, secrets);
        if (visible.isNotEmpty) extensionSecrets[info.key] = visible;
      }
      // Boot is a gating site too: an experiment can change between runs
      // (or an update can gate an extension that used to load), and nothing
      // else stamps disabledSince before the stale-data purge reads it —
      // without this, a gated-at-startup extension's purge grace clock
      // never starts.
      final settingsForStamps = settings;
      if (settingsForStamps != null) {
        await updateExtensionDisabledSince(settings: settingsForStamps, available: availableExtensions, isActive: isExtensionActive);
      }
      // The manifest's declared host-call capabilities (`requiresLocation`,
      // `requiresRadio*`; see extensions/build-config.mjs).
      final loadedInfos = available.where((info) => loaded.contains(info.key)).toList();
      _location = CapabilityGrant.among(loadedInfos, (info) => info.requiresLocation);
      radioCalls.allow(loadedInfos);
      clusterCalls.allow(loadedInfos);
      // Pessimistic from the moment a host exists until its activations have
      // genuinely settled below, so a consumer reading it the instant `host`
      // goes non-null is not told the hook set is authoritative while
      // extensions are still registering into it. The data-file orphan purge
      // is what reads this; the panel catalog deliberately does NOT, because
      // a panel missing from an early read costs a placeholder that repairs
      // itself, while an extension's data purged on a partial one is gone.
      _activationIncomplete = true;
      final host = await ExtensionHost.start(
        kernelSource: kernelSource,
        extensions: bundles,
        onHostCall: _hostCalls.handle,
        fetchAllowlists: fetchAllowlists,
        webSocketAllowlists: webSocketAllowlists,
        secrets: extensionSecrets,
        // Resolve the UA resiliently: a missing native build number (headless
        // test host, or an early-boot platform channel not yet ready) must
        // not throw here and leave every extension dark.
        userAgent: await ham2kUserAgentOrFallback(),
        userAgentOverrides: userAgentOverrides,
        // Handed to the boot itself, not pushed after it returns: `start`
        // evaluates every bundle AND runs their activations, so a clock that
        // arrives afterwards has already missed them and an extension reading a
        // date while activating would bake in the real one. Covers restarts too
        // — _replaceRuntime routes back through here.
        clock: _clockTravelState(),
      );
      // The quit began while this boot was in flight: install it now and the
      // VM's teardown gets a live isolate — and the exit's own wait for this
      // boot may already have timed out, so nothing else would dispose it.
      if (_exiting) {
        await host.dispose();
        return;
      }
      _host = host;
      _loadedExtensionKeys = loaded;
      engineLoad.attach(host);
      _host!.logs.listen((line) => debugPrint('[extensions] $line'));
      _host!.interpretationUpdates.listen(_interpretationUpdates.add);
      _host!.timerSuspensions.listen(_noticeTimerSuspension);
      for (final line in _host!.logLines) {
        debugPrint('[extensions] $line');
      }
      // A crashed runtime (isolate death, worker crash) is replaced, not
      // mourned: DESIGN.md's contract is that extensions degrade, they
      // don't stay dark until app restart.
      _host!.fatalErrors.listen((error) => _scheduleRestart('runtime died: $error'));
      _restartAttempts = 0;
      // AFTER the runtime is up, and deliberately not awaited. Unzipping and
      // writing the pre-loaded bundles — plus a keychain the platform may take its
      // time refusing — is seconds of work, and boot is behind a three-second
      // gate: done inline it spends the whole budget and the app arrives with
      // no extensions at all, which is what happens without this.
      //
      // So the first launch runs on what it already had and picks the
      // pre-loads up on the restart below, the same way an install does.
      unawaited(catchUpOnCatalogExtensions(this));
      // Every extension's onActivation has now genuinely settled — not just
      // been kicked off (kernel.ts's activateAll fires it fire-and-forget).
      // Without this await, a caller querying dataFile/settingsPanel hooks
      // right after start() returned could miss a registration an extension
      // makes only after its own internal await (call-notes' custom files
      // await host.getSettings() first). Bounded: a hung extension's
      // activation must degrade boot, not stall it forever.
      var settled = true;
      final booting = _host!;
      await booting.activated.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[extensions] activation did not complete within 5s — continuing anyway');
          settled = false;
        },
      );
      _activationIncomplete = !settled;
      if (!settled) {
        // The wait is bounded so a hung extension degrades boot instead of
        // stalling it — but nothing re-checks afterwards, so a slow device
        // that merely overran the cap would carry "the hook set is
        // incomplete" for the whole generation, and every consumer that
        // stands down on it (the data-file purge, the panel catalog) would
        // stay stood down for the session. Identity-checked: a runtime
        // replaced meanwhile owns this flag now.
        unawaited(
          booting.activated
              .then((_) {
                if (!identical(_host, booting)) return;
                debugPrint('[extensions] activation completed late; the hook set is whole after all');
                _activationIncomplete = false;
                runtimeGeneration.value++;
              })
              .catchError((_) {}),
        );
      }
      // Re-pushed unconditionally, after the host is live: the `clock:` argument
      // above was read BEFORE loading the bundles, so a DEVTT during those
      // seconds would otherwise be lost (`_pushClockTravel` had no host to push
      // into) and this runtime would stay on the pre-boot clock for good.
      // Idempotent and cheap.
      _pushClockTravel();
      // After activation has settled, so an extension that activated while
      // the app was hidden hears its onHide.
      _host?.setAppVisible(_appVisible);
      runtimeGeneration.value++;
      // Resolve each account's synchronizable flag; account access blocks on
      // _accountSyncReady (completed below) until this is done, so every
      // keychain op for a key uses a consistent flag. Covers restarts too:
      // _replaceRuntime routes back through start()/_start().
      await _refreshAccountSynchronizable();
    } catch (e) {
      debugPrint('[extensions] failed to start extension runtime: $e');
      // Kept, not just reported: `EngineRuntime.load` evaluates each bundle
      // under its own key, so this message names the one that took the
      // generation down — which is the only way an upgrade can put it aside
      // and try the rest.
      _lastStartFailure = '$e';
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

  /// Stands in for what a real [_start] records, which a test's fake host
  /// never runs — so the generation's own keys can be exercised without
  /// booting a runtime.
  @visibleForTesting
  set debugLoadedExtensionKeys(Set<String> keys) => _loadedExtensionKeys = keys;

  /// Stands in for what a failed boot records, which a test's fake host never
  /// runs.
  @visibleForTesting
  set debugLastStartFailure(String? failure) => _lastStartFailure = failure;

  /// Stands in for the host a real boot installs, so a test can hand a
  /// replacement an old host of its own to tear down.
  @visibleForTesting
  set debugHost(ExtensionHost? host) => _host = host;

  /// Arms the crash backoff the way a boot failure or a dying runtime does,
  /// so a test can ask what a queued restart means for a live generation.
  @visibleForTesting
  void debugScheduleRestart(String reason) => _scheduleRestart(reason);

  /// Which extension keys the CURRENT runtime was started with — compared
  /// against the desired set to decide whether a toggle needs a restart.
  @override
  Set<String> _loadedExtensionKeys = const {};

  String? _lastStartFailure;

  /// The installed extension whose bundle took the last boot down, or null.
  ///
  /// `EngineRuntimeIo.load` evaluates every bundle as `evaluating <key>: …`,
  /// so the failure names its own culprit. Answered only for a key this app
  /// currently offers as an INSTALLED extension: a built-in that will not
  /// evaluate is a defect in the app itself, and putting it aside would
  /// quietly ship an install that is missing part of the app.
  String? get lastStartFailureKey => bundleKeyFromStartFailure(_lastStartFailure, availableExtensions);

  /// Whether a runtime is up, which is the most a caller can ask and the
  /// only thing the operator is told.
  ///
  /// Deliberately NOT "and no restart is queued". `_start` installs the host
  /// and then has awaits of its own — the activation wait, the account-flag
  /// refresh that reaches the keychain and is refused on a locked macOS — and
  /// a throw in any of them schedules a backoff restart over a generation
  /// that is loaded and serving hooks. Reading that as unhealthy makes a
  /// keychain prompt revert a perfectly good upgrade.
  bool get runtimeIsHealthy => host != null;

  /// Bumped after every successful runtime (re)start — panels listen to
  /// re-fetch extension-contributed content (settings panels, listings).
  @override
  final ValueNotifier<int> runtimeGeneration = ValueNotifier(0);

  /// Completes once the first boot catch-up has settled — the pre-load and
  /// any shipped extensions put back — so what is still missing after it is
  /// what only the operator can decide about.
  Future<void> get firstCatchUp => _firstCatchUp.future;
  final _firstCatchUp = Completer<void>();

  /// Whether [firstCatchUp] has settled.
  bool get firstCatchUpSettled => _firstCatchUp.isCompleted;

  /// Settles [firstCatchUp]: called by a catch-up that ran to its end.
  void markFirstCatchUpDone() {
    if (!_firstCatchUp.isCompleted) _firstCatchUp.complete();
  }

  /// A `command` hook pushed a later CommandInterpretation for an `input` it
  /// was already asked to interpret (SOLAR/WEATHER's fetch
  /// resolving after their own describe-preview call already returned).
  /// Owned by the service, not the current [_host]: a restart replaces
  /// [_host] but callers (LoggingControls) hold one subscription for the
  /// service's whole lifetime, so [_start] re-subscribes the fresh host into
  /// this same controller each time instead of handing out a new stream.
  final _interpretationUpdates = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get commandInterpretationUpdates => _interpretationUpdates.stream;

  /// Schedules a full runtime replacement (dispose + fresh start + re-seed)
  /// with capped exponential backoff. Safe against double-triggering: a
  /// crash reports through more than one channel, and a restart may itself
  /// fail and re-schedule.
  void _scheduleRestart(String reason) {
    if (_restartTimer != null || _exiting) return;
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

  /// Takes the runtime down for good, on the way out of the app.
  ///
  /// The host is the one isolate that lets native code call back into Dart
  /// (QuickJS's `send` is a `NativeCallable`), and the VM's teardown disables
  /// isolate creation BEFORE it kills the isolates still running: a callback
  /// in that window is a FATAL abort on the way out (HALO-394). Disposing the
  /// host frees the JS runtime, so nothing is left to call back.
  ///
  /// Terminal: [start] and the crash-backoff restart stand down from here on.
  /// A boot or replacement already in flight is waited for, then disposed; if
  /// the caller's budget runs out first, [_start] disposes what it booted,
  /// because it re-reads [_exiting] before installing the host.
  Future<void> shutdownForExit() async {
    _exiting = true;
    _restartTimer?.cancel();
    _restartTimer = null;
    final inFlight = _restartFuture ?? _starting;
    if (inFlight != null) {
      await inFlight.catchError((_) {});
    }
    // Through the getter, not the field: a service whose host is supplied
    // some other way still owns its shutdown.
    final old = host;
    _host = null;
    await old?.dispose();
  }

  /// Restarts a LIVE runtime deliberately — extension enable/disable
  /// toggles use this to apply the new bundle set. Any pending crash-backoff
  /// timer is superseded (the replacement it wanted is happening now).
  @override
  Future<void> restartRuntime({bool fresh = false}) async {
    _restartTimer?.cancel();
    _restartTimer = null;
    // [fresh] for a caller whose verdict is about the generation IT asked
    // for: `_replaceRuntime` hands back a replacement already in flight, and
    // that one began before this caller's own changes to the set — so it
    // would judge a generation that never saw them.
    //
    // Its error is not ours: a replacement that threw belongs to whoever
    // started it, and rethrowing here would abandon the restart this caller
    // came for — leaving the bundles it just installed unloaded, which is
    // what waiting was supposed to prevent.
    if (fresh) await _restartFuture?.catchError((_) {});
    await _replaceRuntime(onlyIfDead: false);
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
      // The new runtime may carry a different set of extensions (this is the
      // path an enable/disable toggle takes), so their advertised commands
      // have to be re-read rather than served from the old set's cache.
      _commandCatalog = null;
      final dying = _loadedExtensionKeys;
      // A new generation starts with no failure recorded. A crash LATER in
      // the session schedules a restart too, and a name left from an earlier
      // boot would be read as the culprit for a failure it had nothing to do
      // with — which, for a catch-up setting aside what will not run, means
      // refusing an innocent extension permanently.
      _lastStartFailure = null;
      // A caller arriving while the old host is disposed waits for the boot
      // that follows it. With no boot memoized, its [start] would begin the
      // next runtime alongside the dying one, ahead of the sweep below.
      final next = Completer<void>();
      _starting = next.future;
      try {
        try {
          await old?.dispose();
        } catch (e, stack) {
          // Reported, not thrown: the old runtime is gone either way, and a
          // caller that just installed a bundle would read a thrown teardown
          // as its install failing while the next runtime loads it.
          ErrorReportingService.report(e, stack, context: 'extensions:dispose');
        }
        // AFTER the dispose, not before: the old host is alive across that
        // await, and a fetch finishing inside that window posts its progress
        // through a host call that would land after the sweep, re-creating the
        // orphan. What "returning" means is decided here, where the next
        // generation's set is known.
        clearGenerationStatus(
          statusBar: statusBar,
          dying: dying,
          returning: {
            for (final info in availableExtensions)
              if (isExtensionActive(info)) info.key,
          },
        );
      } finally {
        // Whatever happened above: every caller that arrived meanwhile is
        // waiting on [next].
        _starting = null;
        next.complete(start());
      }
      await next.future;
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

  /// Answers every call the runtime makes back into the app — see
  /// [_ExtensionHostCalls].
  late final _hostCalls = _ExtensionHostCalls(this);

  /// [_ExtensionHostCalls.handle] for tests — the runtime credential path has
  /// no other seam, and it is the one that decides what an extension believes.
  @visibleForTesting
  Future<dynamic> debugHandleHostCall(String method, Map<String, dynamic> params) => _hostCalls.handle(method, params);

  /// Set by the app shell: opens an account's standalone dialog (Settings →
  /// Accounts) from anywhere — the handler behind declarative `account`
  /// actions (an extension's "reconnect your account" button).
  OpenAccount? onOpenAccount;

  /// See [presentExtensionResultMessage] — wired to this service's status bar
  /// and account opener, which its two callers here already have.
  @override
  void presentResultMessage(Map<String, dynamic> message, {String ns = 'extensions'}) =>
      presentExtensionResultMessage(message, statusBar: statusBar, onOpenAccount: onOpenAccount, ns: ns);

  /// Set by the app shell: backs the `searchSettings` host call, resolving a
  /// SET/SHOW/HIDE query against the settings catalog
  /// (settings_command.dart). Lives here as a callback rather than a service
  /// reference because answering it needs the whole [HaLoServices] graph —
  /// the settings registry, the system lists, and this service itself.
  /// Unset in harnesses, which then report no match rather than failing.
  Future<Map<String, dynamic>> Function(String args, String? kind)? onSearchSettings;

  /// Set by the app shell: backs the `getSpots` host call
  /// (spots_for_extensions.dart), a callback for the same reason as
  /// [onSearchSettings] — the operator's filters, the radio, the log and the
  /// scorers all go into the answer. Unset in harnesses, which then answer an
  /// empty board.
  Future<List<Map<String, dynamic>>> Function(Map<String, dynamic> params)? onGetSpots;

  /// Puts a spot's station into the logging fields of the operation in
  /// front — [operationUuid]'s only, when given — as tapping it in the Spots
  /// Panel does. False when no such operation is open to take it.
  bool Function(Map<String, dynamic> qso, String? operationUuid)? onSuggestQso;

  /// Deterministic offline lookups: with `--dart-define=HALO_STUB_LOOKUPS=1`
  /// in a dev build, [lookupCall] returns a fixed canned result instead of
  /// invoking the (network/credentialed) lookup extensions. `debugEnvFlag`
  /// returns '' in release, so this can never engage there.
  static final bool stubLookups = debugEnvFlag(const String.fromEnvironment('HALO_STUB_LOOKUPS'), 'HALO_STUB_LOOKUPS').isNotEmpty;

  /// The scoring hook keys relevant to [operation], paired with the ref that
  /// selected each. An `'always'` scorer maps to a null ref; a ref-gated one is
  /// listed once per matching ref TYPE — two refs of one type are ONE
  /// invocation, carrying the first, so an operation running two events of the
  /// same contest scores only one of them.
  ///
  /// An `'always'` scorer is marked `fallback` and sorted last. It still runs —
  /// it is the only thing covering a QSO no ref-gated scorer claims, and its
  /// tallies are the operation's QSO count, DXCC and bands — but its per-QSO
  /// verdict yields to any other scorer that scored the same QSO (the merge in
  /// `ScoringService.rescoreOperation`, [scoreQso] and [scoreCandidates]).
  /// Core's rule is call+band+mode, which knows nothing about references, so
  /// beside an activity it contradicts it: a station worked at a second park is
  /// fresh credit to POTA and a duplicate to core, and the entry row can show
  /// only one. Ref-gated scorers do NOT yield to each other — a POTA activation
  /// during CQ WW gets both, which is the operator running both.
  /// [segments] resolves the operation's `break`/`start` overrides. Selection
  /// spans EVERY segment: a contest that only covers the back half of a log
  /// would never be invoked if this read the base operation alone
  /// (docs/design/contests.md §5.1.3). The ref handed back is the first
  /// occurrence — the harness re-resolves it per QSO from the segment-effective
  /// operation, so a segment that restates its setup still wins.
  ///
  /// [alsoRefTypes] selects a ref-gated scorer the operation itself doesn't
  /// name — the ref types found in the LOG and in whatever is being scored.
  /// Without it an operation that only HUNTS references (the ordinary POTA
  /// chaser, no activation ref) selects no activity scorer at all, so nothing
  /// but the core call/band/mode dupe rule applies to it: a station worked at
  /// one park reads as a duplicate when spotted at another
  /// (docs/design/activities.md §4).
  ///
  /// Matched against the scope's `huntingRefTypes` ONLY, never its `refTypes`.
  /// A contest's ref type also rides its QSOs — as exchange data (`{type:
  /// 'cqww', theirZone}`) — so matching `refTypes` here would re-select a
  /// contest that a `break` has already ended, or one removed from the
  /// operation outright, which is precisely what segments exist to prevent.
  ///
  /// Such a scorer is paired with a null ref, like an `'always'` one. There is
  /// no operation ref to hand it and none is invented: an activity reads the
  /// references it is ACTIVATING off the operation, not off this ref
  /// (`activityScoring.ts`'s `activationRefsOf`), so a hunt-only operation
  /// correctly earns no activation credit.
  ///
  /// app-polo instead gives every activity a `generalHuntingType` and runs all
  /// of them on every operation. That is affordable in-process and is not here:
  /// each scorer is a bridge crossing carrying the log. Matching on ref types
  /// actually present adds at most one scorer per type hunted, rather than one
  /// per installed activity.
  static List<Scorer> scorersFor(
    Map<String, dynamic> operation,
    Map<String, dynamic> scopes, {
    SegmentedOperation? segments,
    Set<String> alsoRefTypes = const {},
  }) => priority.scorersFor(
    operation,
    scopes,
    segmentRefs: segments == null ? null : [for (final segment in segments.segments) segment.refs],
    alsoRefTypes: alsoRefTypes,
  );

  /// The activity reference types appearing on [qsos] — what an operation is
  /// HUNTING, as opposed to the refs on the operation itself, which is what it
  /// is activating. Feeds [scorersFor]'s `alsoRefTypes`.
  ///
  /// `Qso.data` is already decoded, so this is a map read per QSO rather than a
  /// parse; callers that hold the log (a rescore, the logging panel) pay
  /// nothing extra for it.
  static Set<String> huntedRefTypesOf(Iterable<Qso> qsos) => {
    for (final qso in qsos)
      for (final ref in qso.refs)
        if (ref['type'] case final String type) type,
  };

  /// The reference types on one QSO-shaped map — a candidate being scored,
  /// which is not a [Qso] yet (the callsign being typed, a spot).
  static Set<String> refTypesOf(Map<String, dynamic> qso) => priority.refTypesOf(qso);
}
