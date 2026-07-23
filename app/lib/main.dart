// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// App shell for phase 2 (core logging loop). Deliberately thin: opens the
// database, builds the repositories, and hands them to the screens. State
// management stays at "constructor injection + streams" until it earns more
// machinery — the database is the source of truth (DESIGN.md §6).

import 'dart:async';
import 'dart:io' show Platform;

import 'package:intl/intl.dart';


import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'views/operation_view.dart';
import 'views/home_view.dart';
import 'views/settings_view.dart';
import 'views/notice_actions.dart';
import 'views/onboarding_overlay.dart';
import 'views/release_overlay.dart';
import 'views/splash_view.dart';
import 'config/dev_bridge.dart';
import 'config/dev_bridge_installer.dart';
import 'config/dev_fixture.dart';
import 'config/dev_flags.dart';
import 'config/experiments.dart';
import 'config/release_notes.dart';
import 'config/version.dart';
import 'services/auto_update_service.dart';
import 'services/deep_link_service.dart';
import 'services/export_service.dart';
import 'services/error_reporting_service.dart';
import 'services/extension_service.dart';
import 'services/location_service.dart';
import 'services/lookup_queue_service.dart';
import 'services/metrics_service.dart';
import 'services/purchase_service.dart';
import 'services/radio_service.dart';
import 'services/restart_service.dart';
import 'services/scoring_service.dart';
import 'services/settings_service.dart';
import 'services/status_bar_service.dart';
import 'settings/core_settings_groups.dart';
import 'settings/settings_registry.dart';
import 'settings/system_lists.dart';
import 'services/window_chrome_service.dart';
import 'services/update_service.dart';
import 'services/update_notices.dart';
import 'services/shorebird_update_service.dart';
import 'services/data_file_manager.dart';
import 'services/flags_service.dart';
import 'i18n/strings.g.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Global error capture (#76): Sentry upload in any build given a DSN at
  // build time, local logging + the error tile + a StatusBar notice
  // everywhere — see services/error_reporting_service.dart. The ENTIRE
  // startup sequence (binding init included) runs inside so everything
  // shares one zone: a binding initialized outside the zone that runApp
  // runs in trips Flutter's zone-mismatch warning, and on web uncaught
  // async errors are only catchable by the zone, not
  // PlatformDispatcher.onError.
  unawaited(ErrorReportingService.run(_mainBody));
}

void _mainBody() {
  WidgetsFlutterBinding.ensureInitialized();
  // Turn on structured dev logging ([qso], [lookup], …) for all non-release
  // builds — console output + a buffer window.__halo.recentLog() can query.
  // Off in release, so nothing is emitted or buffered there (#237).
  DevLog.instance.enabled = !kReleaseMode;
  WindowChromeService.init();
  // Web-only, non-release-only: exposes window.__halo for agent inspection
  // (no-op on native and in production release). See config/dev_bridge.dart.
  installDevBridge();
  // Same dev/web condition (the bridge sets `installed`): force Flutter web's
  // accessibility DOM on. It's normally opt-in behind the "Enable
  // accessibility" button, which leaves generic browser tools (read_page /
  // find / computer) staring at a blank canvas — with it on they see labeled,
  // Semantics(identifier:)-targetable nodes. The handle is intentionally left
  // undisposed so semantics stay on for the app's lifetime. Native already has
  // real accessibility; production is untouched (#236).
  if (DevBridge.instance.installed) {
    SemanticsBinding.instance.ensureSemantics();
  }
  // Kicked off before runApp (not awaited here) so the splash screen paints
  // on the very first frame instead of waiting on the DB/extension/settings
  // boot sequence — see `_BootGate`.
  final servicesFuture = bootstrap();
  runApp(TranslationProvider(child: _BootGate(servicesFuture: servicesFuture)));

  servicesFuture.then((services) async {
    ErrorReportingService.attachStatusBar(services.statusBar);
    // Check for an over-the-air Dart patch on the device's selected track
    // (docs/releases.md §4). Fire-and-forget on purpose: this makes a network
    // call the Shorebird package warns can be slow, so it must NOT gate startup
    // — a downloaded patch applies on the *next* restart regardless. No-ops in
    // any build without the Shorebird engine. When one IS downloaded, prompt the
    // user to restart to apply it (desktop gets a "Restart now" button).
    unawaited(services.updates.checkAndApply().then((updated) {
      if (updated) showPatchReadyNotice(services.statusBar, const RestartService());
    }));

    // Desktop binary self-update: point Sparkle/WinSparkle at this build's
    // per-edition appcast and run a background check (docs/releases.md §3.2).
    // Fire-and-forget; no-op off desktop / in debug / for the Dev edition.
    unawaited(const AutoUpdateService().start());

    // Wire window.__halo.resetFixture() to a real reset now that services
    // exist — only in dev/web where the bridge is installed (#238).
    if (DevBridge.instance.installed) {
      DevBridge.instance.resetFixtureHandler = () => resetDevFixture(services);
    }

    // Dev nicety: launch with POLO_OPEN_FIRST_OP=1 in the environment (e.g.
    // SIMCTL_CHILD_POLO_OPEN_FIRST_OP=1 simctl launch ...) to jump straight
    // into the most recent operation.
    const openFirstOpDefine = bool.fromEnvironment('POLO_OPEN_FIRST_OP');
    final openFirstOp = openFirstOpDefine || (!kIsWeb && Platform.environment['POLO_OPEN_FIRST_OP'] == '1');
    debugPrint('[boot] openFirstOp=$openFirstOp (define=$openFirstOpDefine)');
    if (openFirstOp) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final operations = await services.operations.watchAll().first;
        if (operations.isNotEmpty) {
          navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => OperationView(services: services, operationUuid: operations.first.uuid),
          ));
        }
      });
    }
  }).catchError((Object error, StackTrace stackTrace) {
    // _BootGate's own catchError (below) is what surfaces this to the user;
    // this one only exists so bootstrap() failing doesn't also throw an
    // unrelated unhandled-rejection for the openFirstOp dev nicety above.
    debugPrint('[boot] bootstrap() failed: $error');
  });
}

/// Resets the app to a known fixture for agent/dev verification (#238): back up
/// then clear all operations + QSOs, restore font scale and distance units to
/// their defaults, seed a fresh operation with canned QSOs, and navigate into
/// it. Returns a summary including the `backupId` of the pre-reset snapshot.
/// Backs `window.__halo.resetFixture()`; only reachable in dev/web (see
/// `main()`), so it never runs in release.
Future<Map<String, dynamic>> resetDevFixture(HaLoServices services) async {
  // Clean slate — but back the live data up first rather than hard-deleting, so
  // a stray reset over real data is recoverable. Copies operations + QSOs into
  // the OperationsBackup/QsosBackup tables under a shared backupId, then clears
  // the live tables: the same copy-then-delete the sync engine uses when
  // replacing local data. One transaction so a crash mid-clear can't leave
  // orphaned QSOs. The drift streams (watchAll) re-emit, so the UI follows.
  final backupId = DateTime.now().toUtc().toIso8601String();
  await services.db.transaction(() async {
    await services.operations.backupAndClearAll(backupId);
    await services.qsos.backupAndClearAll(backupId);
  });

  // Known UI state — the settings that most often skew visual verification.
  await services.settings.setFontScale(FontScale.normal);
  await services.settings.setDistanceUnits(DistanceUnits.kilometers);

  final operatorCall = services.settings.activeProfile.operatorCall;
  final stationCall = operatorCall.isNotEmpty ? operatorCall : 'N0DEV';
  final operation = await services.operations.create(stationCall: stationCall, title: 'HALO Fixture');

  final seeds = fixtureQsos(DateTime.now().toUtc().millisecondsSinceEpoch);
  for (final qso in seeds) {
    await services.qsos.add(operation.uuid, qso);
  }

  // Land in the seeded operation, clearing whatever was on the stack (keep the
  // home route beneath so Back still works).
  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => OperationView(services: services, operationUuid: operation.uuid)),
    (route) => route.isFirst,
  );

  // `backupId` lets a caller find the pre-reset data in the backup tables.
  return {'uuid': operation.uuid, 'stationCall': stationCall, 'qsoCount': seeds.length, 'backupId': backupId};
}

/// Shows `SplashScreen` on the very first frame — before `bootstrap()`'s
/// async services are ready — then fades into the real `HaLoApp` once they
/// resolve. Nothing is interactive during the splash (no routes have been
/// pushed yet), so swapping to a second, fully-formed `MaterialApp` instance
/// for the real app is safe: there's no Navigator state to lose.
///
/// Deliberately NOT `AnimatedSwitcher`: its default transition fades the
/// outgoing screen out at the same time as it fades the incoming one in, so
/// for the middle third of the transition both are semi-transparent at once
/// — the splash's logo shows through, ghosted, on top of the home screen's
/// background, and the double-transparency washes the whole frame out
/// (reported as "flashing"). Keeping the outgoing screen fully opaque and
/// only fading the incoming one in on top removes both the ghosting and the
/// wash-out: at every point during the transition there's exactly one
/// opaque screen plus one partially-visible screen layered on it, not two.
class _BootGate extends StatefulWidget {
  final Future<HaLoServices> servicesFuture;

  const _BootGate({required this.servicesFuture});

  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> with SingleTickerProviderStateMixin {
  static const _transitionDuration = Duration(milliseconds: 200);

  late final AnimationController _fadeController = AnimationController(vsync: this, duration: _transitionDuration)..value = 1;

  Widget _currentChild = const MaterialApp(
    key: ValueKey('splash'),
    debugShowCheckedModeBanner: false,
    home: SplashScreen(),
  );
  Widget? _previousChild;

  @override
  void initState() {
    super.initState();
    widget.servicesFuture.then((services) {
      if (!mounted) return;
      // Wrapped separately from the `.catchError` below: that one exists to
      // catch `bootstrap()` itself failing, and without this try/catch it
      // would also swallow an unrelated error thrown by `_switchTo` here,
      // mislabeling it as a boot failure in the debug log.
      try {
        _switchTo(HaLoApp(key: const ValueKey('app'), services: services));
      } catch (error, stackTrace) {
        debugPrint('[boot] unexpected error building HaLoApp (not a bootstrap() failure): $error\n$stackTrace');
        ErrorReportingService.report(error, stackTrace, context: 'boot:build-app');
        _switchTo(MaterialApp(
          key: const ValueKey('boot-error'),
          debugShowCheckedModeBanner: false,
          home: BootErrorScreen(error: error),
        ));
      }
    }).catchError((Object error, StackTrace stackTrace) {
      // Fail loud: previously `await bootstrap()` in main() let a boot
      // failure throw before runApp() ever ran; now that runApp() happens
      // first, an unhandled rejection here would otherwise strand the user
      // on the splash screen forever with no visible error.
      debugPrint('[boot] bootstrap() failed: $error\n$stackTrace');
      ErrorReportingService.report(error, stackTrace, context: 'boot:bootstrap');
      if (mounted) {
        _switchTo(MaterialApp(
          key: const ValueKey('boot-error'),
          debugShowCheckedModeBanner: false,
          home: BootErrorScreen(error: error),
        ));
      }
    });
  }

  void _switchTo(Widget next) {
    setState(() {
      _previousChild = _currentChild;
      _currentChild = next;
    });
    _fadeController.value = 0;
    _fadeController.forward().whenCompleteOrCancel(() {
      if (mounted) setState(() => _previousChild = null);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `_BootGate` sits above `TranslationProvider`/`MaterialApp`, so there's
    // no `Directionality` ancestor yet — `Stack`'s default alignment
    // (`AlignmentDirectional.topStart`) needs one; `Alignment.topLeft`
    // doesn't, since it's not text-direction-relative.
    //
    // `StackFit.expand`, NOT the default `loose`: this Stack is the app's
    // root, and loose constraints silently break the font scale ABOVE 1.0.
    // UiScale's FittedBox needs tight constraints to scale up to — given
    // loose ones it just shrink-wraps its (smaller-than-window) child and
    // paints at natural size, so the UI reflows to the narrower logical
    // width without ever being magnified. Scaling DOWN kept working, which
    // is why this hid: an oversized child still gets clamped to the max.
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        if (_previousChild != null) _previousChild!,
        FadeTransition(opacity: _fadeController, child: _currentChild),
      ],
    );
  }
}

/// Runs the shared boot sequence (database, extensions, settings, sync) and
/// returns the assembled services bundle. Distribution-specific entrypoints
/// (e.g. a private `main_dist.dart`) call this with real implementations of
/// the distribution-only services instead of the OSS no-op defaults.
Future<HaLoServices> bootstrap({
  MetricsService? metrics,
  PurchaseService? purchases,
  UpdateService? updates,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = HaLoDatabase(driftDatabase(
    name: 'ham2k_logger',
    web: kIsWeb
        ? DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          )
        : null,
  ));
  final extensions = ExtensionService();
  // Fire-and-forget, and kicked off before awaiting settings below so these
  // two independent boot steps run concurrently instead of serialized; the
  // core logging loop never waits on the extension runtime either way.
  extensions.start();
  final settings = await SettingsService.load();
  LocaleSettings.setLocaleRaw(settings.locale);
  Intl.defaultLocale = settings.locale;
  final services = HaLoServices(
    db,
    settings,
    extensions: extensions,
    metrics: metrics,
    purchases: purchases,
    // The running app checks Shorebird for a Dart patch on the selected track
    // (§4.3); no-ops in any build without the engine. Overridable for tests.
    updates: updates ?? ShorebirdUpdateService(settings),
  );
  // A locked/absent keyring yields a null device key (ensureSyncDeviceKey no
  // longer throws) — boot must still complete, so skip sync setup and pick it
  // up on a later launch once the keyring is available.
  final syncDeviceKey = await settings.ensureSyncDeviceKey();
  if (syncDeviceKey != null) {
    services.extensions.setSyncCredentials(deviceKey: syncDeviceKey, operatorCall: settings.activeProfile.operatorCall);
    services.syncEngine.start();
  } else {
    debugPrint('[boot] no sync device key (secure storage unavailable) — continuing without sync');
  }

  // macOS app-menu actions (see WindowChromeService and macos/Runner): "About"
  // shows the release overlay, "Preferences…" (⌘,) opens the Settings view.
  WindowChromeService.onShowReleaseOverlay = services.devSplashTrigger.trigger;
  WindowChromeService.onOpenSettings = () => navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => SettingsView(services: services)),
      );
  WindowChromeService.onCheckForUpdates = () => unawaited(const AutoUpdateService().checkForUpdatesInteractively());

  // Await the extension system being fully booted, then initialize and sync data files
  unawaited(extensions.start().then((_) async {
    await services.dataFiles.loadRawDataFiles();
    await services.dataFiles.syncAllDataFiles();
    // After the enabled extensions have refreshed their data-file ownership
    // records, drop the data of any extension disabled long enough ago.
    await services.dataFiles.purgeStaleExtensionData(settings.extensionDisabledSince);
  }).catchError((e) {
    debugPrint('[boot] failed to initialize data files: $e');
  }));

  // Fetch feature flags + notices for the current callsign once the runtime
  // is up (the callsign→DXCC-entity annotation needs it). Fire-and-forget;
  // failures leave flags empty and are logged inside the service.
  unawaited(extensions.start().then((_) {
    return services.flags.refreshForCall(settings.activeProfile.operatorCall);
  }).catchError((e) {
    debugPrint('[boot] failed to fetch feature flags: $e');
  }));

  return services;
}

/// The core services bundle passed down to screens.
class HaLoServices {
  final HaLoDatabase db;
  final SettingsService settings;
  final ExtensionService extensions;
  final MetricsService metrics;
  final PurchaseService purchases;
  final UpdateService updates;

  late final OperationsRepository operations = OperationsRepository(db, onChange: () => syncEngine.notifyChanged());
  late final QsosRepository qsos = QsosRepository(db, onChange: () => syncEngine.notifyChanged());
  late final LookupRepository lookups = LookupRepository(db);
  late final ExportService exports = ExportService(extensions: extensions, qsos: qsos, settings: settings);
  late final ScoringService scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
  late final RadioService radio = RadioService(settings.prefs);
  final LocationService location = LocationService();
  final DeepLinkService deepLinks = DeepLinkService();
  final DataFileManager? _dataFilesOverride;
  late final DataFileManager dataFiles = _dataFilesOverride ??
      DataFileManager(
        lookups: lookups,
        extensions: extensions,
        prefs: settings.prefs,
        statusBar: statusBar,
      );
  late final StatusBarService statusBar = StatusBarService(settings.prefs);
  final LookupQueueService? _lookupQueueOverride;
  late final LookupQueueService lookupQueue = _lookupQueueOverride ??
      LookupQueueService(
        lookup: extensions.lookupCall,
        qsos: qsos,
        operations: operations,
        statusBar: statusBar,
        lookupReady: () => extensions.ready,
      );

  /// Server-driven feature flags + notices for the active profile callsign
  /// (see FlagsService). Refreshed at boot and whenever the callsign changes
  /// via [setOperatorCall] — not per operation. The callsign is annotated
  /// through the extension runtime's offline lookup to derive the DXCC entity
  /// used to pick per-entity/per-call flag files.
  late final FlagsService flags = FlagsService(
    statusBar: statusBar,
    annotate: (call) async {
      final result = await extensions.lookupCall(call, qso: const {}, operation: const {}, online: false);
      final guess = result?['guess'];
      return guess is Map ? guess.cast<String, dynamic>() : null;
    },
    onNoticeAction: handleNoticeAction,
    prefs: settings.prefs,
  );

  /// Named option vocabularies for `options: "$name"` settings
  /// declarations (see settings/system_lists.dart).
  late final SystemLists systemLists = SystemLists();

  /// The declarative settings groups (docs in settings/settings_registry.dart)
  /// rendered by the Common Preferences and All Settings panels. Extension
  /// panels aren't registered here — the All Settings panel composes them
  /// from [ExtensionService.getSettingsPanels] at build time (the runtime
  /// boots asynchronously).
  late final SettingsRegistry settingsRegistry = SettingsRegistry()
    ..register(GeneralSettingsGroup(settings, extensions))
    ..register(LoggingSettingsGroup(settings))
    ..register(PrivacySettingsGroup(settings))
    ..register(SyncSettingsGroup(settings, onToggle: setSyncEnabled));

  /// Fires on DEVSPLASH (`handleCommandAction`'s `devSplash` case) —
  /// `_ReleaseOverlayGateState` listens for this to force-show the release
  /// overlay on demand, bypassing its normal once-per-version gate.
  final DevOverlayTrigger devSplashTrigger = DevOverlayTrigger();

  /// DEVONBOARD's counterpart: `_OnboardingGateState` listens for this to
  /// force-show the onboarding overlay, bypassing its callsign-undefined
  /// gate.
  final DevOverlayTrigger devOnboardTrigger = DevOverlayTrigger();

  /// The dirty-flag sync loop (DESIGN.md §4) — batching and bookkeeping stay
  /// here in Dart; only the network call crosses into the `ham2k-lofi`
  /// extension via `_syncTransportCall`.
  late final SyncEngine syncEngine = SyncEngine(
    operations: operations,
    qsos: qsos,
    transport: _syncTransportCall,
    settings: settings,
    log: debugPrint,
    onProgress: _showSyncProgress,
  );

  /// Status-bar item key for backfill progress; the Sync settings panel
  /// renders the same item inline (see `settings_view.dart`).
  static const syncProgressStatusKey = 'sync_backfill_progress';

  /// Surfaces backfill progress in the footer. Backfill can take a while on
  /// a large account (the server cooldown-gates fetch rounds), so without
  /// this the app looks idle while history is still arriving. Completion
  /// pushes the bar to 1.0, which StatusBarService auto-clears shortly
  /// after.
  void _showSyncProgress(SyncProgress progress) {
    final total = (progress.qsosTotal ?? 0) + (progress.operationsTotal ?? 0);
    if (!progress.backfilling) {
      // Only announce completion if progress was actually shown: a fresh
      // empty account completes backfill on its first round, and "history
      // downloaded" out of nowhere would just confuse.
      if (statusBar.items.any((item) => item.key == syncProgressStatusKey)) {
        statusBar.setProgress(
          key: syncProgressStatusKey,
          icon: 'cloud-sync',
          title: 'Sync',
          text: 'Account history downloaded',
          value: 1.0,
        );
      }
      return;
    }
    if (total <= 0) return;
    final left = (progress.qsosLeft ?? 0) + (progress.operationsLeft ?? 0);
    final done = (total - left).clamp(0, total);
    final qsoTotal = progress.qsosTotal ?? 0;
    final qsoDone = (qsoTotal - (progress.qsosLeft ?? 0)).clamp(0, qsoTotal);
    statusBar.setProgress(
      key: syncProgressStatusKey,
      icon: 'cloud-sync',
      title: 'Syncing account history',
      text: qsoTotal > 0 ? '$qsoDone of $qsoTotal QSOs' : '$done of $total records',
      value: done / total,
    );
  }

  HaLoServices(
    this.db,
    this.settings, {
    ExtensionService? extensions,
    MetricsService? metrics,
    PurchaseService? purchases,
    UpdateService? updates,
    DataFileManager? dataFiles,
    LookupQueueService? lookupQueue,
  })  : extensions = extensions ?? ExtensionService(),
        metrics = metrics ?? const NoopMetricsService(),
        purchases = purchases ?? const NoopPurchaseService(),
        // Defaults to no-op so tests (which construct HaLoServices directly)
        // never touch the Shorebird FFI; bootstrap() injects the real
        // ShorebirdUpdateService for the running app.
        updates = updates ?? const NoopUpdateService(),
        _dataFilesOverride = dataFiles,
        _lookupQueueOverride = lookupQueue {
    this.extensions.settings = settings;
    this.extensions.lookups = lookups;
    this.extensions.statusBar = statusBar;
    this.extensions.operations = operations;
    this.extensions.qsos = qsos;
    this.extensions.onOpenAccount =
        (key, {subkey}) => unawaited(showAccountDialogByKey(this, key, subkey: subkey));
  }



  /// Sets the sync device identity + operator callsign in one call. Writes
  /// to the default profile — the
  /// Callsign settings panel edits that one; sync follows the ACTIVE
  /// profile's callsign (the same profile until multi-profile lands).
  Future<void> setOperatorCall(String call) async {
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, call);
    final deviceKey = await settings.ensureSyncDeviceKey();
    if (deviceKey != null) {
      await extensions.setSyncCredentials(
        deviceKey: deviceKey,
        operatorCall: settings.activeProfile.operatorCall,
      );
    }
    // Flags are callsign-specific — refresh them (a no-op if the callsign
    // didn't actually change). Not awaited: the callsign edit shouldn't block
    // on a network round-trip.
    unawaited(flags.refreshForCall(settings.activeProfile.operatorCall));
  }

  Future<void> setSyncEnabled(bool enabled) async {
    await settings.setSyncEnabled(enabled);
    if (!enabled) return;
    // Boot skips credential setup when the keyring is locked
    // (ensureSyncDeviceKey returns null), so starting the engine now without a
    // device key would run sync unauthenticated. If boot never established the
    // key, re-attempt here (a null result isn't cached, so this retries secure
    // storage) and only start once we actually have credentials.
    if (settings.syncDeviceKey == null) {
      final deviceKey = await settings.ensureSyncDeviceKey();
      if (deviceKey == null) {
        debugPrint('[sync] enabled but secure storage is unavailable — not starting sync');
        return;
      }
      await extensions.setSyncCredentials(
        deviceKey: deviceKey,
        operatorCall: settings.activeProfile.operatorCall,
      );
    }
    syncEngine.start();
  }

  /// Handles a named command action from the call field — `SYNCALL` (see
  /// `extensions/sync/ham2k-lofi`) and the `dev-commands` extension's
  /// DEVNOTICE/DEVSTATUS/DEVPROGRESS/RELOAD. Returns a message for the
  /// caller to show in a SnackBar, or null for nothing — the dev-command
  /// cases return null since their `confirm` text already shows in the
  /// call field, and the status bar item itself is the visible result.
  Future<String?> handleCommandAction(String action, [Map<String, dynamic>? params]) async {
    switch (action) {
      case 'syncAll':
        if (!settings.syncEnabled) return 'Enable sync in Settings first.';
        await syncEngine.forceFullResync();
        return 'Full resync started — local data was backed up first.';
      case 'reloadDataFiles':
        final p = params ?? const {};
        final target = (p['target'] as String?)?.toUpperCase();
        if (target == null) return null;
        // Downloading + reprocessing can take a while (tens of thousands
        // of CSV rows through the extension bridge) — don't block the
        // call-field's command flow on it. Each matched data file already
        // reports its own transient progress/completion in the status bar
        // (see DataFileManager), so no separate summary is shown here.
        unawaited(dataFiles.syncAllDataFiles(force: true, categoryFilter: target == 'ALL' ? null : target).then((matched) {
          if (matched == 0) {
            statusBar.setProgress(
              key: 'command:reloadDataFiles',
              text: 'No data files matched "$target".',
              value: 1.0,
            );
          }
        }).catchError((e) {
          // Belt-and-suspenders: syncAllDataFiles already isolates each data
          // file's own errors, but this still needs to fail loud (not just
          // silently drop the failure) for anything unexpected that slips
          // past that per-entry try/catch.
          debugPrint('[data-file] reloadDataFiles failed: $e');
          statusBar.setProgress(key: 'command:reloadDataFiles', text: 'Reload failed: $e', value: 1.0);
        }));
        return target == 'ALL' ? 'Reloading all data files…' : 'Reloading $target data files…';
      case 'devNotice':
        final p = params ?? const {};
        statusBar.showNotice(
          key: 'command:devNotice',
          icon: p['icon'] as String?,
          title: p['title'] as String?,
          text: p['text'] as String? ?? '',
        );
        return null;
      case 'devStatus':
        final p = params ?? const {};
        final devStatusKey = p['key'] as String? ?? 'devStatus';
        statusBar.setMessage(
          key: 'command:devStatus:$devStatusKey',
          icon: p['icon'] as String?,
          title: p['title'] as String?,
          text: p['text'] as String?,
        );
        return null;
      case 'devProgress':
        final p = params ?? const {};
        final percent = p['percent'] as num?;
        statusBar.setProgress(
          key: 'command:devProgress',
          icon: p['icon'] as String?,
          title: p['title'] as String?,
          value: percent == null ? null : percent.toDouble() / 100,
        );
        return null;
      case 'devSplash':
        devSplashTrigger.trigger();
        return null;
      case 'devOnboard':
        devOnboardTrigger.trigger();
        return null;
      case 'sendSpots':
        return _sendSpot(params ?? const {});
      case 'toggleExperiment':
        // EXP <key-or-alias>: the command hook only parsed; resolving the
        // token against the catalog and flipping the stored state happens
        // here, and the returned message is the user's only feedback.
        final token = (params?['token'] as String? ?? '').trim();
        if (token.isEmpty) return null;
        final experiment = findExperiment(await loadExperiments(), token);
        if (experiment == null) return 'Unknown experiment "${token.toUpperCase()}"';
        final enabled = !settings.experimentEnabled(experiment.key);
        await settings.setExperimentEnabled(experiment.key, enabled);
        return '${experiment.name} ${enabled ? 'enabled' : 'disabled'}';
      default:
        return null;
    }
  }

  /// Backs both the Spotting control's send button and the SPOT/QRV/QRT/
  /// QSY/QRX/SPOTLAST-family commands (`logging_controls.dart`'s
  /// `_dispatchActions`, which already resolved *who* gets spotted —
  /// this only posts and summarizes the per-source result).
  Future<String> _sendSpot(Map<String, dynamic> params) async {
    final operation = (params['operation'] as Map?)?.cast<String, dynamic>() ?? const {};
    final qso = (params['qso'] as Map?)?.cast<String, dynamic>();
    final target = params['target'] as String? ?? 'self';
    if (target == 'last' && qso == null) return 'No QSO logged yet to spot.';
    final freq = (params['freq'] as num?)?.toDouble();
    if (qso == null && freq == null) return 'Set a frequency first.';

    final sources = await extensions.suggestSpotSources(operation: operation, qso: qso);
    if (sources.isEmpty) return 'Nothing to spot — no extension offers spotting here.';

    final results = await extensions.sendSpot(
      sources: sources,
      operation: operation,
      qso: qso,
      freq: freq,
      mode: params['mode'] as String?,
      comment: params['comment'] as String?,
      spotterCall: settings.activeProfile.operatorCall,
    );

    final summaries = <String>[];
    for (final source in sources) {
      final hookKey = source['hookKey'] as String? ?? '?';
      final result = results[hookKey];
      if (result == null) continue;
      summaries.add(result['ok'] == true ? 'Spotted on $hookKey' : '$hookKey failed: ${result['message'] ?? 'unknown error'}');
    }
    return summaries.isEmpty ? 'Spot not sent.' : summaries.join('; ');
  }

  Future<Map<String, dynamic>> _syncTransportCall(String method, Map<String, dynamic> args) async {
    final host = extensions.host;
    if (host == null) throw StateError('extension runtime is not ready yet');
    final result =
        await host.invokeHook('syncTransport', method: method, args: args, timeout: const Duration(seconds: 30));
    return (result as Map).cast<String, dynamic>();
  }
}

/// Runs one command action through [HaLoServices.handleCommandAction] and
/// surfaces its returned message in the status bar (skipped if [state] was
/// unmounted while the action ran) — so feedback that's only known app-side
/// (a toggled experiment's outcome, syncAll's status) isn't silently
/// dropped. Shared by home_view's and operation_view's command dispatch.
Future<void> runCommandAction(HaLoServices services, State state, String action,
    [Map<String, dynamic>? params]) async {
  final message = await services.handleCommandAction(action, params);
  if (message != null && state.mounted) {
    services.statusBar.setMessage(key: 'commandAction', text: message);
  }
}



class HaLoApp extends StatefulWidget {
  final HaLoServices services;

  const HaLoApp({super.key, required this.services});

  @override
  State<HaLoApp> createState() => _HaLoAppState();
}

class _HaLoAppState extends State<HaLoApp> {
  // Held as a field (not rebuilt per frame) so its route count survives
  // MaterialApp rebuilds; drives `modalBarrierIsVisible` for the window-chrome
  // mask. See navigatorObservers below.
  final _modalBarrierObserver = ModalBarrierRouteObserver();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    final hasModifier = isMetaPressed || isControlPressed;

    if (!hasModifier) return false;

    final key = event.logicalKey;
    final settings = widget.services.settings;

    if (HardwareKeyboard.instance.isShiftPressed && key == LogicalKeyboardKey.keyD) {
      // ⌘⇧D (⌃⇧D on non-Mac): flip between light and dark themes.
      settings.setThemeMode(
        toggledThemeMode(settings.themeMode, WidgetsBinding.instance.platformDispatcher.platformBrightness),
      );
      return true;
    }

    if (HardwareKeyboard.instance.isShiftPressed && key == LogicalKeyboardKey.keyL) {
      // ⌘⇧L (⌃⇧L on non-Mac): toggle language between English and Spanish.
      final newLocale = settings.locale == 'es' ? 'en' : 'es';
      settings.setLocale(newLocale);
      LocaleSettings.setLocaleRaw(newLocale);
      widget.services.extensions.invalidateHookContext();
      return true;
    }

    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      settings.increaseFontScale();
      return true;
    } else if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract ||
        key == LogicalKeyboardKey.underscore) {
      settings.decreaseFontScale();
      return true;
    } else if (key == LogicalKeyboardKey.digit0 ||
        key == LogicalKeyboardKey.numpad0) {
      settings.setFontScale(FontScale.normal);
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds when Settings changes themeMode or fontScale, so toggling it in the
    // Settings screen takes effect immediately rather than needing a restart.
    return AnimatedBuilder(
      animation: widget.services.settings,
      builder: (context, _) => MaterialApp(
        // Android task-switcher card title / web tab title — matches each
        // platform's own OS-level app name (see isWindowedPlatform's other
        // uses: macos/Runner/Configs/AppInfo.xcconfig "Ham2K Logger",
        // android's AndroidManifest.xml label "HaLo").
        title: isWindowedPlatform ? 'Ham2K Logger' : 'HaLo',
        navigatorKey: navigatorKey,
        navigatorObservers: [_modalBarrierObserver],
        locale: TranslationProvider.of(context).locale.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildHaLoTheme(Brightness.light),
        darkTheme: buildHaLoTheme(Brightness.dark),
        themeMode: widget.services.settings.themeMode,
        debugShowCheckedModeBanner: false,
        home: HomeView(services: widget.services),
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          final scale = widget.services.settings.fontScale.scaleFactor;

          // One knob scales the WHOLE interface (UiScale, halo_widgets) — not
          // just text and icons but every layout dimension, uniformly, so
          // ordinary widget code stays scale-agnostic and proportions never
          // drift. The base theme's dimensions are unchanged; UiScale does the
          // scaling.
          //
          // The native macOS traffic lights float over the AppBar and stay a
          // fixed system size, so they center in the on-screen header
          // height = the base AppBar height scaled by UiScale below (see
          // WindowChromeService; deduped, so calling it every build is fine).
          final baseToolbarHeight = Theme.of(context).appBarTheme.toolbarHeight ?? 48.0;
          WindowChromeService.reportTitleBarHeight(baseToolbarHeight * scale);
          // The window's resize floor is the S-size layout width plus room for
          // the native window controls that float over the header (traffic
          // lights / caption buttons), so neither the S content nor the
          // controls is ever squeezed (desktopMinimumWindowSize; layouts.md).
          WindowChromeService.reportMinimumSize(desktopMinimumWindowSize(scale));

          // Full-screen toggles change the traffic-light clearance the
          // headers reserve (macOSTrafficLightClearance → 0 while the
          // buttons live in the system's auto-hiding overlay). The scope is
          // the delivery mechanism — see MacOSFullScreenScope's own comment.
          // On chromeless Windows the caption buttons are Flutter-drawn and
          // float over every route's header from here — the same "window
          // chrome above app content" role the native traffic lights play
          // on macOS. Headers reserve trailing room via
          // windowsCaptionClearance. On macOS the native traffic lights
          // already float there; we overlay a same-colored mask beneath them
          // (MacOSTrafficLightMask) so header content animating through the
          // top-left corner doesn't flash out around the buttons.
          Widget content = child;
          if (isWindowsChromelessWindow) {
            content = Stack(children: [
              content,
              const Positioned(top: 0, right: 0, child: WindowsCaptionButtons()),
            ]);
          } else if (isMacOSChromelessWindow) {
            content = Stack(children: [
              content,
              const Positioned(top: 0, left: 0, child: MacOSTrafficLightMask()),
            ]);
          }

          return ValueListenableBuilder<bool>(
            valueListenable: macOSWindowIsFullScreen,
            builder: (context, isFullScreen, _) => MacOSFullScreenScope(
              isFullScreen: isFullScreen,
              child: UiScale(
                scale: scale,
                // Outermost so it covers every field in the app — the gates'
                // own overlays and anything pushed on the Navigator (which is
                // `content`, i.e. dialogs and panes) included.
                child: TapToDismissEmptyField(
                  child: _OnboardingGate(
                    services: widget.services,
                    child: _ReleaseOverlayGate(
                      services: widget.services,
                      child: _StatusBarOverlay(services: widget.services, child: content),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// First-run onboarding (Issue #43): wraps the release overlay gate so the
/// onboarding paints on top of everything, whenever the default profile has
/// NEVER had a callsign set — undefined, not '' (an explicit empty from a
/// previous Skip counts as answered). Same presentation split as the
/// release overlay: full screen on XS/S, `wideModalChrome` on L/XL — but
/// with no barrier dismissal; the flow's own Skip/Done are the exits.
/// Debug-only shortcut for skipping the onboarding flow: set
/// `ONBOARD_AS=CALL,activity,...` — e.g. `ONBOARD_AS=KI2D,pota,sota` — as a
/// `--dart-define` or an environment variable, and a first run applies that
/// operator callsign and enables the listed activity extensions instead of
/// showing onboarding. The first comma-separated token is the callsign; the
/// rest are extension keys to enable. Empty (and inert) in release builds.
String get _onboardAsConfig => debugEnvFlag(const String.fromEnvironment('ONBOARD_AS'), 'ONBOARD_AS');

/// Applies an `ONBOARD_AS=CALL,activity,...` spec (see [_onboardAsConfig]):
/// sets the operator callsign and enables the listed activity extensions.
/// Writing the callsign marks onboarding answered, so the flow never shows.
/// The first comma-separated token is the callsign; the rest are extension
/// keys to enable. A no-op for a blank/empty spec.
@visibleForTesting
Future<void> applyOnboardAsSpec(HaLoServices services, String spec) async {
  final parts = spec.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return;
  final call = parts.first.toUpperCase();
  final activities = parts.skip(1).map((s) => s.toLowerCase()).toList();
  debugPrint('[onboarding] ONBOARD_AS: callsign=$call activities=$activities');
  await services.setOperatorCall(call);
  if (activities.isNotEmpty) {
    await services.extensions.setExtensionsEnabled({for (final a in activities) a: true});
  }
}

class _OnboardingGate extends StatefulWidget {
  final HaLoServices services;
  final Widget child;

  const _OnboardingGate({required this.services, required this.child});

  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  bool _pending = false;
  ReleaseNotesEntry? _release;

  /// Whether the current showing is the organic first run (vs a DEVONBOARD
  /// re-show) — only the first run stamps the release notes as seen.
  bool _firstRun = false;

  @override
  void initState() {
    super.initState();
    if (!widget.services.settings.defaultProfileCallsignDefined) {
      final onboardAs = _onboardAsConfig;
      if (onboardAs.isNotEmpty) {
        // Debug-only: apply ONBOARD_AS and skip the onboarding flow entirely.
        unawaited(applyOnboardAsSpec(widget.services, onboardAs));
      } else {
        _firstRun = true;
        _show();
      }
    }
    widget.services.devOnboardTrigger.addListener(_show);
  }

  @override
  void dispose() {
    widget.services.devOnboardTrigger.removeListener(_show);
    super.dispose();
  }

  /// First run, or DEVONBOARD (which bypasses the callsign-undefined gate
  /// for iterating on the flow — and is real: its Done writes settings).
  /// Re-triggering during the dismissal fade re-arms the overlay.
  void _show() {
    if (!mounted) return;
    setState(() {
      _pending = true;
      _dismissing = false;
    });
    // The background photo is the newest release's — same imagery as the
    // release overlay. Fine to arrive late (or never): the overlay shows
    // a plain backdrop until then.
    loadReleaseNotes().then((notes) {
      if (mounted && notes.isNotEmpty) setState(() => _release = notes.first);
    });
  }

  /// True while the finished overlay dissolves into the home screen —
  /// removed from the tree only once the fade completes.
  bool _dismissing = false;

  void _dismiss() {
    if (_dismissing) return;
    // A fresh install doesn't need "what's new" for the version it just
    // installed — mark it seen so the release overlay doesn't follow the
    // onboarding (its own gate also skips while onboarding is pending).
    // NOT on DEVONBOARD re-shows: those never displayed any notes, and
    // stamping would suppress a pending release overlay.
    if (_firstRun) widget.services.settings.setLastSeenReleaseVersion(kPublicVersion);
    setState(() => _dismissing = true);
  }

  void _finalizeDismiss() {
    if (!mounted || !_dismissing) return;
    setState(() {
      _pending = false;
      _dismissing = false;
      _firstRun = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget? overlay;
    if (_pending) {
      Widget view = OnboardingOverlayView(
        // A fresh State per showing (matters for DEVONBOARD re-shows —
        // step position and toggles reset).
        key: ValueKey('onboarding-$_firstRun-$_pending'),
        services: widget.services,
        release: _release,
        onDone: _dismiss,
      );
      if (ShirtSize.of(context).isTwoPane) {
        // No barrier dismissal — onboarding exits through its own Skip/Done.
        view = wideModalChrome(context: context, onDismiss: () {}, child: view);
      }
      // The onboarding subtree mounts inside its OWN Overlay (Overlay.wrap):
      // this gate sits in MaterialApp.builder, above the Navigator, and the
      // callsign step's TextField requires an Overlay ancestor. Done/Skip
      // dissolve the whole overlay (chrome included) into the home screen
      // rather than cutting away.
      overlay = Positioned.fill(
        child: AnimatedOpacity(
          opacity: _dismissing ? 0 : 1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          onEnd: _finalizeDismiss,
          child: IgnorePointer(ignoring: _dismissing, child: Overlay.wrap(child: view)),
        ),
      );
    }
    return Stack(
      children: [
        widget.child,
        if (overlay != null) overlay,
      ],
    );
  }
}

/// Shows `ReleaseOverlayView` once per new `kPublicVersion`, on top of the
/// whole app (same one-integration-point wrapping as `_StatusBarOverlay`
/// below, which it wraps). Gated on `SettingsService.lastSeenReleaseVersion`
/// (release_notes.dart, settings_service.dart) — dismissing it persists
/// `kPublicVersion` there, so it won't show again until the next release.
class _ReleaseOverlayGate extends StatefulWidget {
  final HaLoServices services;
  final Widget child;

  const _ReleaseOverlayGate({required this.services, required this.child});

  @override
  State<_ReleaseOverlayGate> createState() => _ReleaseOverlayGateState();
}

class _ReleaseOverlayGateState extends State<_ReleaseOverlayGate> {
  ReleaseNotesEntry? _pending;

  @override
  void initState() {
    super.initState();
    _checkForNewRelease();
    widget.services.devSplashTrigger.addListener(_showDevSplash);
  }

  @override
  void dispose() {
    widget.services.devSplashTrigger.removeListener(_showDevSplash);
    super.dispose();
  }

  Future<void> _checkForNewRelease() async {
    // First run: onboarding is showing (see _OnboardingGate) and marks this
    // version seen on dismissal — don't stack "what's new" behind it.
    if (!widget.services.settings.defaultProfileCallsignDefined) return;
    if (widget.services.settings.lastSeenReleaseVersion == kPublicVersion) return;
    final notes = await loadReleaseNotes();
    ReleaseNotesEntry? current;
    for (final entry in notes) {
      if (entry.version == kPublicVersion) {
        current = entry;
        break;
      }
    }
    if (current == null || !mounted) return;
    setState(() => _pending = current);
  }

  /// DEVSPLASH (dev-commands extension) — always shows the newest release's
  /// notes, ignoring `lastSeenReleaseVersion` entirely (unlike
  /// `_checkForNewRelease`), since the whole point is re-previewing it on
  /// demand.
  Future<void> _showDevSplash() async {
    final notes = await loadReleaseNotes();
    if (notes.isEmpty || !mounted) return;
    setState(() => _pending = notes.first);
  }

  void _dismiss() {
    widget.services.settings.setLastSeenReleaseVersion(kPublicVersion);
    setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    return Stack(
      children: [
        widget.child,
        if (pending != null) _buildOverlay(context, pending),
      ],
    );
  }

  /// Same shirt-size logic as halo_widgets' Modal Panes
  /// (packages/halo_widgets/lib/src/modal_pane.dart): full screen on
  /// XS/S, a centered pane-sized modal over the home screen on L/XL. This
  /// overlay isn't a pushed route and keeps its own full-bleed photo
  /// design rather than `ModalPaneRoute`'s AppBar/dialog-card chrome, so
  /// the presentation split is reimplemented here instead of reusing
  /// `showModalPane` directly. The wide-mode chrome itself is shared with
  /// the About screen's photo modal — see `wideModalChrome`.
  Widget _buildOverlay(BuildContext context, ReleaseNotesEntry release) {
    if (!ShirtSize.of(context).isTwoPane) {
      return ReleaseOverlayView(release: release, onDismiss: _dismiss);
    }
    return Positioned.fill(
      child: wideModalChrome(
        context: context,
        onDismiss: _dismiss,
        child: ReleaseOverlayView(release: release, onDismiss: _dismiss),
      ),
    );
  }
}

/// A bare `notifyListeners()` signal for the dev commands that force-show a
/// startup overlay: `devSplashTrigger` (DEVSPLASH → release overlay) and
/// `devOnboardTrigger` (DEVONBOARD → onboarding overlay). Carries no state
/// of its own.
class DevOverlayTrigger extends ChangeNotifier {
  void trigger() => notifyListeners();
}

/// Wraps the whole app (every route, since `MaterialApp.builder` wraps the
/// Navigator as a single instance) with the global footer + notice stack —
/// one integration point instead of touching every view's `Scaffold`.
class _StatusBarOverlay extends StatelessWidget {
  final HaLoServices services;
  final Widget child;

  const _StatusBarOverlay({required this.services, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.statusBar,
      builder: (context, _) {
        final statusBar = services.statusBar;
        final items = [
          for (final item in statusBar.items)
            StatusBarItemData(
              key: item.key,
              icon: item.icon,
              title: item.title,
              text: item.text,
              progressValue: item.progressValue,
              isIndeterminateProgress: item.isIndeterminateProgress,
            ),
        ];
        final notices = [
          for (final notice in statusBar.activeNotices)
            StatusBarNoticeData(
              key: notice.key,
              icon: notice.icon,
              title: notice.title,
              text: notice.text,
              actions: [
                for (final action in notice.actions)
                  StatusBarActionData(label: action.label, onTap: action.onTap),
              ],
              createdAt: notice.createdAt,
            ),
        ];

        // Mobile-only: the footer is hidden entirely while the keyboard is
        // open (user-interface.md's footer spec), not just left empty.
        final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
        final hideFooter = keyboardOpen && !isWindowedPlatform;

        return Column(
          children: [
            Expanded(child: child),
            if (notices.isNotEmpty && !hideFooter)
              NoticeStack(notices: notices, onDismiss: statusBar.dismissNotice),
            if (!hideFooter) StatusBarFooter(items: items, onDismiss: statusBar.clear),
          ],
        );
      },
    );
  }
}

