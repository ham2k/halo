// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// App shell for phase 2 (core logging loop). Deliberately thin: opens the
// database, builds the repositories, and hands them to the screens. State
// management stays at "constructor injection + streams" until it earns more
// machinery — the database is the source of truth (DESIGN.md §6).

import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:math' as math;

import 'package:intl/intl.dart';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb, kReleaseMode, setEquals, visibleForTesting, TargetPlatform;
import 'dart:ui' show AppExitResponse;
// Prefixed separately from the AppExitResponse import above: some import in
// this file's graph makes the bare name `TextDirection` resolve to something
// without an `.ltr` getter, so the real dart:ui one needs this to be reached
// unambiguously.
import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'tools/contest_bench.dart';
import 'tools/operation_title.dart';
import 'views/command_dialog.dart';
import 'views/confirm_device_dialog.dart';
import 'views/operation_dialogs.dart';
import 'views/operation/operation_location_screen.dart';
import 'views/operation_view.dart';
import 'views/home_navigation_rail.dart';
import 'views/home_view.dart';
import 'views/extension_install_flow.dart';
import 'views/settings_view.dart';
import 'views/notice_actions.dart';
import 'views/onboarding_overlay.dart';
import 'views/release_overlay.dart';
import 'views/tester_overlay.dart';
import 'views/splash_view.dart';
import 'config/dev_bridge.dart';
import 'config/dev_bridge_installer.dart';
import 'config/dev_fixture.dart';
import 'config/dev_flags.dart';
import 'config/experiments.dart';
import 'config/release_notes.dart';
import 'config/tester_notes.dart';
import 'config/secrets.dart';
import 'config/version.dart';
import 'services/app_storage.dart';
import 'services/auto_update_service.dart';
import 'services/database_snapshot_service.dart';
import 'package:http/http.dart' as http;

import 'services/deep_link_service.dart';
import 'services/export_service.dart';
import 'services/build_freshness_service.dart';
import 'services/connectivity_service.dart';
import 'views/offline_indicator.dart';
import 'views/peers_dialog.dart';
import 'views/station_config_dialog.dart';
import 'views/station_panel.dart' show equipmentStatusLabel;
import 'services/error_reporting_backend.dart';
import 'services/bottom_chrome_squeezed.dart';
import 'services/error_policy.dart';

import 'services/error_reporting_service.dart';
import 'services/extension_dev_client.dart';
import 'services/extension_service.dart';
import 'services/installed_extensions.dart';
import 'services/opened_files_service.dart';
import 'services/geoshape_service.dart';
import 'services/unclean_quit.dart';
import 'services/cat/equipment.dart' show kCategoryTransceiver;
import 'services/cat/cat_service.dart';
import 'services/peer/ble/peer_ble.dart';
import 'services/peer/peer_channels.dart';
import 'services/peer/peer_drafts.dart';
import 'services/peer/serial_claims.dart';
import 'services/peer/peer_account_tag.dart';
import 'services/peer/peer_screen_views.dart';
import 'services/peer/peer_remote_radios.dart';
import 'services/peer/peer_screens.dart';
import 'services/peer/ble/peer_ble_transport.dart';
import 'services/peer/peer_service.dart';
import 'views/peer_pairing_dialog.dart';
import 'services/inbound_qso_listener_service.dart';
import 'services/location_service.dart';
import 'services/lookup_queue_service.dart';
import 'services/metrics_service.dart';
import 'services/panel_service.dart';
import 'services/purchase_service.dart';
import 'services/pusher_service.dart';
import 'services/radio_service.dart';
import 'services/restart_service.dart';
import 'services/operation_title_service.dart';
import 'services/scoring_service.dart';
import 'services/settings_service.dart';
import 'services/spots_service.dart';
import 'services/spots_status_reporter.dart';
import 'services/status_bar_service.dart';
import 'services/view_focus_guard.dart';
import 'services/web_popup.dart';
import 'services/web_storage_persistence.dart';
import 'settings/core_settings_groups.dart';
import 'settings/settings_command.dart';
import 'settings/settings_registry.dart';
import 'settings/settings_target_dialog.dart';
import 'settings/system_lists.dart';
import 'services/hardware_keyboard_service.dart';
import 'services/window_chrome_service.dart';
import 'services/update_check_service.dart';
import 'services/staleness_service.dart';
import 'services/update_service.dart';
import 'services/update_notices.dart';
import 'services/shorebird_update_service.dart';
import 'services/data_file_manager.dart';
import 'services/flags_service.dart';
import 'i18n/strings.g.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// [args] is the command line. Windows and Linux hand a document opened
/// through the file manager to the app as an argument — their runners already
/// forward argv to this entrypoint — which is how a double-clicked `.h2kext`
/// arrives on those two platforms (macOS and iOS use a delegate callback
/// instead, and Android an intent).
void main(List<String> args) => runHaLoApp(launchArguments: args);

/// The whole app launch sequence, with the distribution-only services
/// injectable — the OSS `main()` above runs it with the no-op defaults,
/// while a private distribution entrypoint (`app_dist`'s `main_dist.dart`)
/// passes real implementations (e.g. the analytics and crash-reporting
/// backends, and a Shorebird+Sparkle-aware [UpdateCheckService]). Vendor-
/// specific code stays out of this repo entirely; the app only knows the
/// generic [MetricsService]/[ErrorReportingBackend]/[UpdateCheckService]
/// interfaces and the consent-gated [HaLoServices.track].
void runHaLoApp({
  List<String> launchArguments = const [],
  MetricsService? metrics,
  PurchaseService? purchases,
  UpdateService? updates,
  UpdateCheckService? updateCheck,
  ErrorReportingBackend? errorReporting,
}) {
  // Global error capture: backend upload when one is injected, local
  // logging + the error tile + a StatusBar notice everywhere — see
  // services/error_reporting_service.dart. The ENTIRE startup sequence
  // (binding init included) runs inside so everything shares one zone: a
  // binding initialized outside the zone that runApp runs in trips
  // Flutter's zone-mismatch warning, and on web uncaught async errors are
  // only catchable by the zone, not PlatformDispatcher.onError.
  unawaited(ErrorReportingService.run(
    () => _mainBody(
        launchArguments: launchArguments,
        metrics: metrics,
        purchases: purchases,
        updates: updates,
        updateCheck: updateCheck),
    backend: errorReporting,
  ));
}

/// Whether a dev flag passed as a dart-define or an environment variable is
/// on. Accepts `1` and `true` (any case): the flags are documented as `=1`
/// but a dart-define spelled `=true` is the shape `bool.fromEnvironment`
/// trained everyone to expect, and silently ignoring either one is how
/// POLO_OPEN_FIRST_OP went unnoticed.
bool isDevFlagSet(String value) {
  final v = value.trim().toLowerCase();
  return v == '1' || v == 'true';
}

void _mainBody({
  List<String> launchArguments = const [],
  MetricsService? metrics,
  PurchaseService? purchases,
  UpdateService? updates,
  UpdateCheckService? updateCheck,
}) {
  WidgetsFlutterBinding.ensureInitialized();
  // Native only: on web, the engine's own bootstrap (ui_web.bootstrapEngine
  // → _downloadAssetFonts) already eagerly downloads, registers AND shapes
  // every FontManifest-declared font, including this one, before main() ever
  // runs — preloading again here would just double the fetch. On native,
  // pubspec-declared fonts genuinely do load and shape lazily on first use —
  // held in the splash gate below (see `bootstrap`'s call site) rather than
  // fired here, so it's paid once, off-screen, instead of racing whichever
  // screen happens to measure or paint the first emoji.
  // Turn on structured dev logging ([qso], [lookup], …) for all non-release
  // builds — console output + a buffer window.__halo.recentLog() can query.
  // Off in release, so nothing is emitted or buffered there.
  DevLog.instance.enabled = !kReleaseMode;
  // `halo_core` normalizes wrong-typed QSON on its way into storage but is
  // pure Dart and cannot reach the crash backend itself. Dropping a value
  // nothing can use fixes the symptom and leaves the WRITER of a bool mode
  // unknown, which is the thing worth learning — so route what it finds here.
  // Only DROPPED values arrive: a numeric string coerces by design. Reported
  // at the first occurrence (like malformed spot data), keyed by write path
  // and field so a device holding one bad record reports once rather than
  // once per sync round.
  onQsonTypeViolation = (context, violation) {
    ErrorReportingService.reportIfRepeated(
      'qson:malformed:$context:${violation.path}',
      MalformedQsonDataException(context, violation),
      null,
      context: 'qson:malformed:$context',
      threshold: 1,
    );
  };
  // Before bootstrap, so the offline flag is answered by the time anything
  // can fail (map errors are stamped with it — see MapError).
  ConnectivityService.start();
  WindowChromeService.init();
  HardwareKeyboardService.init();
  // No I/O, but not free either: this parses an embedded ~250 KB blob into
  // ~340 zones and their transition tables, about 19 ms under JIT, on the
  // main isolate, for every launch whether or not a Clock pane exists. It is
  // eager anyway because the Operation View reads the zone list while
  // registering its panels, so deferring only moves the same cost onto the
  // first operation opened — and a lazy database that loses the race throws
  // out of a painter instead.
  tz_data.initializeTimeZones();
  // Web only: undoes the browser's spurious "the view lost focus" reports,
  // which otherwise park every field dead mid-typing. See ViewFocusGuard.
  ViewFocusGuard.install();
  // Web only: without this, the BROWSER's own right-click menu wins every
  // time — Flutter never even sees the secondary click to hand it to a
  // GestureDetector's `onSecondaryTapUp` (currently only the Logs column
  // menu). This is APP-WIDE — Flutter web has no per-widget way to opt out
  // of the browser's own context menu — so it also gives up the native
  // menu everywhere else a right-click would have reached it (a map
  // webview, text selection), with nothing Flutter-side standing in for it
  // outside the Logs table. Not awaited: it's a JS interop call that
  // resolves once the engine's context-menu listener is attached, and
  // nothing before the first right-click depends on that having happened
  // yet.
  if (kIsWeb) unawaited(BrowserContextMenu.disableContextMenu());
  // Web-only, non-release-only: exposes window.__halo for agent inspection
  // (no-op on native and in production release). See config/dev_bridge.dart.
  installDevBridge();
  // Same dev/web condition (the bridge sets `installed`): force Flutter web's
  // accessibility DOM on. It's normally opt-in behind the "Enable
  // accessibility" button, which leaves generic browser tools (read_page /
  // find / computer) staring at a blank canvas — with it on they see labeled,
  // Semantics(identifier:)-targetable nodes. The handle is intentionally left
  // undisposed so semantics stay on for the app's lifetime. Native already has
  // real accessibility; production is untouched.
  if (DevBridge.instance.installed) {
    SemanticsBinding.instance.ensureSemantics();
  }
  // Kicked off before runApp (not awaited here) so the splash screen paints
  // on the very first frame instead of waiting on the DB/extension/settings
  // boot sequence — see `BootGate`.
  final servicesFuture = bootstrap(metrics: metrics, purchases: purchases, updates: updates, updateCheck: updateCheck);
  runApp(TranslationProvider(child: BootGate(servicesFuture: servicesFuture)));

  servicesFuture.then((services) async {
    // One app_started per launch, with the UI preferences app-polo's
    // matching event carries (consent-gated inside track, like everything).
    services.track('app_started', {
      'language': services.settings.locale,
      // The EFFECTIVE scheme, not the ThemeMode: the enum interpolates to
      // "ThemeMode.dark", and `system` describes the setting rather than what
      // the user is actually looking at. app-polo reports the same way.
      'colorScheme': switch (services.settings.themeMode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark
              ? 'dark'
              : 'light',
      },
      'fontScale': services.settings.fontScale.name,
    });
    ErrorReportingService.attachStatusBar(services.statusBar);
    ErrorReportingService.attachSettings(services.settings);
    BuildFreshnessService(statusBar: services.statusBar).start();

    // Names a spot source that stops answering. Cached after the first
    // successful fetch — a hook's `sourceName` is static per build — but
    // retried while the cache is still empty, which is what makes it correct
    // no matter when the runtime came up: `start()` is fire-and-forget, its
    // first attempt can fail and be retried by `_scheduleRestart`, and the
    // fan-out has a 5s timeout of its own on a cold launch. Any of those
    // would otherwise leave every message naming `sota` rather than
    // SOTAWatch, permanently. Only ever reached when an outage is being
    // reported, so the retry costs nothing on a healthy run.
    // One shared future, not a map plus an emptiness check: the reporter
    // resolves every down source at once, so N separate lookups would all
    // find the cache empty and fire N concurrent fan-outs over the runtime —
    // at the exact moment it is already struggling with an outage.
    Future<Map<String, String>>? spotSourceNames;
    attachSpotsStatusReporter(
      spots: services.spots,
      statusBar: services.statusBar,
      disabledSources: () => services.settings.disabledSpotSources,
      disabledSourcesChanges: services.settings,
      nameFor: (hookKey) async {
        final names = await (spotSourceNames ??= services.extensions.getSpotSourceNames());
        // A fan-out that answered nothing is not an answer worth keeping —
        // drop it so the next outage asks again instead of naming every
        // source by its raw hook key for the rest of the session.
        if (names.isEmpty) spotSourceNames = null;
        return names[hookKey] ?? hookKey;
      },
    );

    // Is this install out of date, and in which of the three ways? One
    // evaluation, at most one verdict per launch (services/staleness.dart).
    // Evaluated here so an expired build still nags with no network, and again
    // after each flags refresh once the server-driven signals have arrived.
    services.staleness.start();
    // Check for an over-the-air Dart patch on the device's selected track
    // (docs/releases.md §4). Fire-and-forget on purpose: this makes a network
    // call the Shorebird package warns can be slow, so it must NOT gate startup
    // — a downloaded patch applies on the *next* restart regardless. No-ops in
    // any build without the Shorebird engine. When one IS downloaded, prompt the
    // user to restart to apply it (desktop gets a "Restart now" button).
    unawaited(services.updates.checkAndApply().then((updated) {
      if (updated) showPatchReadyNotice(services.statusBar, const RestartService());
    }));

    // Deliberately AFTER the update machinery above, and guarded. This parses
    // hand-edited server JSON, writes prefs and schedules a dialog — none of
    // which may cost the operator the code-push download it is about to tell
    // them to restart for, nor the deep links wired below.
    try {
      services.staleness.evaluate();
    } catch (e, stack) {
      debugPrint('[staleness] evaluation failed: $e\n$stack');
    }

    // Desktop binary self-update: point Sparkle/WinSparkle at this build's
    // per-edition appcast and run a background check (docs/releases.md §3.2).
    // Fire-and-forget; no-op off desktop / in debug / for the Dev edition.
    // The preference reaches the updater HERE or not at all: everything it
    // configures is before-init only, and start() is what runs first.
    unawaited(const AutoUpdateService().start(
      automaticChecks: services.settings.automaticUpdateChecks,
    ));

    _listenForDeepLinks(services);
    _listenForOpenedExtensionFiles(services);
    // Windows and Linux deliver an opened document as an argument to a FRESH
    // process, so there is no callback to wait for — it is simply already
    // here. An instance that is already running gets nothing, which is the
    // same limitation their deep links have.
    // The first only. Several would stack consent dialogs on top of each
    // other, which is exactly what the drop target refuses for the same
    // reason.
    final bundleArg = launchArguments.where((a) => a.toLowerCase().endsWith('.h2kext')).firstOrNull;
    if (bundleArg != null) _openInstallExtension(services, Uri.file(bundleArg));

    // Wire window.__halo.resetFixture() to a real reset now that services
    // exist — only in dev/web where the bridge is installed.
    if (DevBridge.instance.installed) {
      DevBridge.instance.resetFixtureHandler = () => resetDevFixture(services);
    }

    // Dev nicety: launch with POLO_OPEN_FIRST_OP=1 in the environment (e.g.
    // SIMCTL_CHILD_POLO_OPEN_FIRST_OP=1 simctl launch ...) to jump straight
    // into the most recent operation.
    // Read as a STRING, not with `bool.fromEnvironment`, which recognizes only
    // the literals "true" and "false" — every other value, `=1` included,
    // reads as false. Both this flag's documented spellings use `=1`
    // (DEVELOPMENT.md), so the dart-define half silently did nothing: the app
    // launched, printed `openFirstOp=false`, and looked like the flag had been
    // dropped rather than mis-typed. The env-var half below always worked,
    // which is what kept it hidden.
    const openFirstOpDefine = String.fromEnvironment('POLO_OPEN_FIRST_OP');
    final openFirstOp = isDevFlagSet(openFirstOpDefine) ||
        (!kIsWeb && isDevFlagSet(Platform.environment['POLO_OPEN_FIRST_OP'] ?? ''));
    debugPrint('[boot] openFirstOp=$openFirstOp (define="$openFirstOpDefine")');
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
    // BootGate's own catchError (below) is what surfaces this to the user;
    // this one only exists so bootstrap() failing doesn't also throw an
    // unrelated unhandled-rejection for the openFirstOp dev nicety above.
    debugPrint('[boot] bootstrap() failed: $error');
  });
}

/// Opens the "Confirm a device" pane for an incoming `link_client` deep
/// link — the QR code a device asking to join this account displays (see
/// [DeepLinkService.linkClientRequest]).
///
/// App-wide rather than owned by the Sync settings panel: the operator scans
/// that QR with a phone camera and the OS hands the link to whatever the app
/// happens to be showing, which is rarely Settings. A link arriving before
/// the first frame has no navigator to open onto and is dropped; the code
/// entry in the same pane is the way back from that.
/// A `.h2kext` opened from Finder installs the same way a picked one does.
///
/// Anything else the OS hands us is ignored rather than refused: this app is
/// registered for exactly one document type, so a file arriving here that is
/// not one is a platform oddity, not something to interrupt the operator about.
void _listenForOpenedExtensionFiles(HaLoServices services) {
  services.openedFiles.openedFiles.listen((path) {
    if (!path.toLowerCase().endsWith('.h2kext')) {
      debugPrint('[open-file] ignoring $path');
      return;
    }
    _openInstallExtension(services, Uri.file(path));
  }, onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'open-file'));
}

/// Every incoming `com.ham2k*://` link, dispatched in one place — see
/// [DeepLinkService] for the catalog. The order below is "during an
/// activation" before "during setup", which is also roughly how often each
/// arrives.
void _listenForDeepLinks(HaLoServices services) {
  services.deepLinks.links.listen((uri) {
    final install = DeepLinkService.installExtensionRequest(uri);
    if (install != null) {
      _openInstallExtension(services, install);
      return;
    }
    // The companion-app bridge, ahead of link_client only because these are
    // the links that arrive during an activation rather than during setup.
    final vfo = DeepLinkService.vfoRequest(uri);
    if (vfo != null) {
      _applyVfoDeepLink(services, vfo);
      return;
    }
    final linkedQso = DeepLinkService.qsoRequest(uri);
    if (linkedQso != null) {
      unawaited(_presentDeepLinkedQso(services, linkedQso));
      return;
    }
    final ourRefs = DeepLinkService.operationRequest(uri);
    if (ourRefs != null) {
      unawaited(_openDeepLinkedOperation(services, ourRefs));
      return;
    }
    final request = DeepLinkService.linkClientRequest(uri);
    if (request == null) return;
    // A device with no account of its own has nothing to admit anybody to,
    // and the pane would open only to report that. Says so where the
    // operator is looking instead — they just scanned a code and are owed
    // an answer either way.
    if (!services.settings.syncEnabled) {
      services.statusBar.showNotice(
        key: 'sync:link-request-needs-sync',
        icon: 'cloud-off',
        title: t.confirmDevice.needsSyncTitle,
        text: t.confirmDevice.needsSyncText,
        actions: [
          StatusBarAction(
            label: t.settings.syncPanel.openSettings,
            onTap: () => navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => SettingsView(services: services, initialPanel: 'sync')),
            ),
          ),
        ],
      );
      return;
    }
    _openConfirmDevicePane(services, request);
  }, onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'deep-link'));
}

/// How recent an operation has to be for an `/operation` link to reuse it
/// rather than start a new one. Matches app-polo's `RECENT_WINDOW_MS`: an
/// activation interrupted overnight is the same activation, and one from last
/// month is not.
const _deepLinkRecentWindow = Duration(hours: 48);

/// Puts the radio state a `/vfo` link reports into the app's own VFO.
///
/// Needs no navigator, and so is the one deep link that works during a cold
/// launch: it writes a service, not a screen.
void _applyVfoDeepLink(HaLoServices services, ({double? freqKHz, String? band, String? mode}) vfo) {
  services.radio.setVfo('vfoA', freq: vfo.freqKHz, band: vfo.band, mode: vfo.mode);
  services.track('deep_link_vfo', {});
}

/// Presents the QSO a `/qso` link proposes in the front-most operation — or,
/// with none open, in the most recent one.
///
/// The radio state travels with it, unlike a spot tap: a companion app sending
/// a QSO is reporting where this operator's radio IS (app-polo's
/// `_updatesVFO`), so the fields and the VFO must agree afterwards.
Future<void> _presentDeepLinkedQso(
  HaLoServices services,
  ({
    List<String> calls,
    double? freqKHz,
    String? band,
    String? mode,
    int? startAtMillis,
    List<({String key, String ref})> theirRefs,
  }) link,
) async {
  final resolved = await _deepLinkRefs(services, link.theirRefs, (types) => types.huntingType);
  if (link.freqKHz != null || link.band != null || link.mode != null) {
    services.radio.setVfo('vfoA', freq: link.freqKHz, band: link.band, mode: link.mode);
  }
  final outcome = await _deliverDeepLinkedQso(services, {
    // Comma-joined, which is HaLo's "one QSO per call" syntax — see
    // `DeepLinkService.qsoRequest`.
    'their': {'call': link.calls.join(',')},
    if (link.freqKHz != null) 'freq': link.freqKHz,
    if (link.band != null) 'band': link.band,
    if (link.mode != null) 'mode': link.mode,
    if (link.startAtMillis != null) 'startAtMillis': link.startAtMillis,
    'refs': resolved.refs,
  });
  // The contact landed, but not everything the link asked for came with it —
  // the operator is about to log a hunt that records fewer programs than the
  // sender named, and only they can tell the companion-app author.
  if (outcome == _DeepLinkOutcome.delivered && resolved.dropped.isNotEmpty) {
    _reportDroppedRefs(services, resolved);
  }
  services.track('deep_link_qso', {
    'outcome': outcome.name,
    'refsDropped': resolved.dropped.length,
  });
}

/// What became of a `/qso` link, so telemetry counts deliveries rather than
/// attempts and the caller knows whether to bother reporting anything else.
enum _DeepLinkOutcome { delivered, noOperation, noNavigator }

/// Tells the operator which references a link named that this device could
/// not place, and why.
///
/// A load failure and an unknown key are different sentences on purpose:
/// "your activity is unknown" is a confident claim about their setup, and
/// saying it because the runtime had not booted sends them hunting through
/// Manage Extensions for a problem that is not there.
void _reportDroppedRefs(HaLoServices services, ({List<Map<String, dynamic>> refs, List<String> dropped, bool loadFailed}) resolved) {
  final names = resolved.dropped.join(', ');
  services.statusBar.setMessage(
    key: 'deep-link:dropped-refs',
    text: resolved.loadFailed
        ? t.deepLink.activitiesUnavailable(refs: names)
        : t.deepLink.unknownActivities(refs: names),
  );
}

/// Hands [suggestion] to an operation's logging fields.
///
/// Prefers the operation already in front — pushing a second copy of a view
/// the operator is already looking at would bury their work under it. Only
/// with nothing open does this fall back to the most recent operation, which
/// is what a companion app assumes "the log" means.
///
/// The retry mirrors [_openInstallExtension]'s: a link that cold-launches the
/// app arrives before the first frame, and dropping it silently leaves
/// whoever sent it with nothing at all.
Future<_DeepLinkOutcome> _deliverDeepLinkedQso(
  HaLoServices services,
  Map<String, dynamic> suggestion, {
  int attemptsLeft = 20,
}) async {
  final front = services.frontOperationContext;
  final suggest = front?.suggestQso;
  if (suggest != null) {
    suggest(suggestion);
    // The fields are filled, but behind Settings or a nested operation there
    // is nothing on screen to show for it — so the link looks dead unless we
    // say where the contact went. Not popped: whatever is on top may hold an
    // edit in progress, and a link is not permission to discard it.
    if (front?.isVisible?.call() == false) {
      services.statusBar.setMessage(key: 'deep-link:delivered-behind', text: t.deepLink.waitingInOperation);
    }
    return _DeepLinkOutcome.delivered;
  }
  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    if (attemptsLeft <= 0) {
      // A navigator still absent five seconds after launch is our bug, not a
      // state to wait out — and the operator is owed an answer either way.
      ErrorReportingService.report(
        StateError('deep link dropped: no navigator after 5s'),
        StackTrace.current,
        context: 'deep-link',
      );
      return _DeepLinkOutcome.noNavigator;
    }
    Timer(const Duration(milliseconds: 250),
        () => unawaited(_deliverDeepLinkedQso(services, suggestion, attemptsLeft: attemptsLeft - 1)));
    // Not an outcome yet — the retry reports its own. Counting this as a
    // delivery is what would make the metric read 100% success forever.
    return _DeepLinkOutcome.noNavigator;
  }
  final operations = await services.operations.watchAll().first;
  if (operations.isEmpty) {
    // Nowhere to put it, and no operation to invent on a link's say-so: a
    // contact belongs to an activation the operator started. app-polo returns
    // silently here; saying so is the difference between a broken link and a
    // link that needs one thing first.
    services.statusBar.setMessage(key: 'deep-link:no-operation', text: t.deepLink.needsAnOperation);
    return _DeepLinkOutcome.noOperation;
  }
  // Re-read rather than reusing the one checked above: the database await
  // between them is long enough for a hot restart or a root rebuild to
  // deactivate that state, and pushing onto a dead navigator throws out of an
  // unawaited future.
  final target = navigatorKey.currentState;
  if (target == null) return _DeepLinkOutcome.noNavigator;
  target.push(MaterialPageRoute(
    builder: (_) => OperationView(
      services: services,
      operationUuid: operations.first.uuid,
      initialSuggestedQso: suggestion,
    ),
  ));
  return _DeepLinkOutcome.delivered;
}

/// Finds the recent operation activating exactly the references an
/// `/operation` link names, or creates one, and opens it.
///
/// Exact set matching, as in app-polo: a park-only request must not latch onto
/// a park-and-summit operation, and vice versa — those are distinct
/// activations, and reusing one for the other silently files the contacts
/// under the wrong award.
Future<void> _openDeepLinkedOperation(
  HaLoServices services,
  List<({String key, String ref})> pairs, {
  int attemptsLeft = 20,
}) async {
  if (navigatorKey.currentState == null) {
    if (attemptsLeft <= 0) {
      ErrorReportingService.report(
        StateError('deep link dropped: no navigator after 5s'),
        StackTrace.current,
        context: 'deep-link',
      );
      return;
    }
    Timer(const Duration(milliseconds: 250),
        () => unawaited(_openDeepLinkedOperation(services, pairs, attemptsLeft: attemptsLeft - 1)));
    return;
  }
  final resolved = await _deepLinkRefs(services, pairs, (types) => types.activationType);
  if (resolved.refs.isEmpty) {
    _reportDroppedRefs(services, resolved);
    return;
  }
  // Some resolved, some did not — and this is the dangerous half. `wanted`
  // below is built from what SURVIVED, so a truncated request would be
  // matched, and created, as a smaller activation than the one asked for:
  // exactly the cross-award filing `activationRefsMatch` exists to prevent.
  // Proceeding is the operator's call to undo; saying nothing is not.
  if (resolved.dropped.isNotEmpty) _reportDroppedRefs(services, resolved);

  final wanted = {for (final ref in resolved.refs) '${ref['type']}:${ref['ref']}'};
  final cutoff = nowMillis() - _deepLinkRecentWindow.inMilliseconds;
  final operations = await services.operations.watchAll().first;
  Operation? existing;
  for (final operation in operations) {
    final lastActive = operation.startAtMillisMax ?? operation.createdAtMillis ?? 0;
    if (lastActive < cutoff) continue;
    if (DeepLinkService.activationRefsMatch(operation.data['refs'], wanted)) {
      existing = operation;
      break;
    }
  }

  final uuid = existing?.uuid ?? await _createDeepLinkedOperation(services, resolved.refs);
  // Re-read: `_deepLinkRefs`, the operation query and `decorateRef`'s network
  // round trips are tens of seconds during which the state read at entry can
  // be deactivated.
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  navigator.push(MaterialPageRoute(builder: (_) => OperationView(services: services, operationUuid: uuid)));
  services.track('deep_link_operation', {
    'created': existing == null,
    'refsDropped': resolved.dropped.length,
  });
}

/// Creates the operation an `/operation` link asked for, with its references
/// already decorated.
///
/// Decorating BEFORE the view mounts, rather than letting it fill in
/// afterwards: the view titles itself from the refs it finds
/// (`OperationTitleService`), so mounting on bare codes titles the operation
/// from them and only re-titles if something writes the names later.
Future<String> _createDeepLinkedOperation(HaLoServices services, List<Map<String, dynamic>> refs) async {
  final decorated = <Map<String, dynamic>>[];
  for (final ref in refs) {
    // An unnamed park is better than no operation, so a decoration that fails
    // costs that reference its name and nothing more.
    //
    // `decorateRef` already swallows ExtensionHostException itself and hands
    // the ref back unchanged, so a program that cannot reach its API never
    // arrives here. What does is the residue — a wrong-typed hook result, a
    // kernel ArgumentError — and those are OUR bugs, which a bare catch would
    // bury for good. Same split as activities_view.dart's.
    try {
      decorated.add(await services.extensions.decorateRef(ref));
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'deep-link:decorate-ref');
      decorated.add(ref);
    }
  }
  final operation = await services.operations.create(
    stationCall: services.settings.activeProfile.operatorCall,
  );
  await services.operations
      .saveData(Operation(uuid: operation.uuid, data: {...operation.data, 'refs': decorated}));
  return operation.uuid;
}

/// A deep link's `key:ref` pairs as QSON refs, with [typeFor] choosing which
/// of the extension's two reference types applies — an operation ACTIVATES,
/// a QSO HUNTS.
///
/// A key no installed activity claims is skipped rather than guessed at (as
/// in app-polo): inventing `${key}Activation` would write a reference type
/// nothing scores, exports or recognizes.
///
/// `dropped` names the keys that got no type, and `loadFailed` says WHY they
/// did — the runtime could not be asked, versus nothing claims them. The two
/// are different sentences to the operator, and the caller must not report an
/// empty result as "you don't have that activity" when it never got to ask.
///
/// A non-empty `dropped` alongside a non-empty `refs` is a PARTIAL result,
/// which is the case worth care: the request has been silently narrowed, and
/// downstream set matching will honour the narrowed version.
Future<({List<Map<String, dynamic>> refs, List<String> dropped, bool loadFailed})> _deepLinkRefs(
  HaLoServices services,
  List<({String key, String ref})> pairs,
  String? Function(({String? activationType, String? huntingType}) types) typeFor,
) async {
  if (pairs.isEmpty) return (refs: const <Map<String, dynamic>>[], dropped: const <String>[], loadFailed: false);
  final types = await services.extensions.activityRefTypes();
  final refs = <Map<String, dynamic>>[];
  final dropped = <String>[];
  for (final pair in pairs) {
    final known = types.byKey[pair.key];
    final type = known == null ? null : typeFor(known);
    if (type == null) {
      dropped.add(pair.key);
      continue;
    }
    refs.add({'type': type, 'ref': pair.ref});
  }
  if (dropped.isNotEmpty) {
    debugPrint('[deep-link] no reference type for ${dropped.join(', ')} (loadFailed=${types.loadFailed})');
  }
  return (refs: refs, dropped: dropped, loadFailed: types.loadFailed);
}

/// Downloads the bundle a link named and offers to install it, once there is
/// a navigator to ask on.
///
/// The download happens INSIDE the install flow's read step, so a fetch that
/// fails is reported the same way an unreadable file is, and nothing is
/// written before the operator has seen where it came from and agreed. The
/// retry mirrors the link_client one: a deep link that cold-launches the app
/// arrives before the first frame, and dropping it silently leaves whoever
/// clicked it with nothing at all.
void _openInstallExtension(HaLoServices services, Uri source, {int attemptsLeft = 20}) {
  final context = navigatorKey.currentContext;
  final store = services.extensions.installed;
  if (context == null || store == null) {
    if (attemptsLeft <= 0) {
      debugPrint('[deep-link] install_extension dropped: no navigator or store after 5s');
      return;
    }
    Timer(const Duration(milliseconds: 250),
        () => _openInstallExtension(services, source, attemptsLeft: attemptsLeft - 1));
    return;
  }
  // A file the operator double-clicked is one they chose, exactly like one
  // picked through the button — so it names no source, and an update that
  // asks for nothing new goes through without a second dialog. Only a bundle
  // fetched from a link is attributed.
  final local = source.isScheme('file');
  unawaited(installExtensionFromBytes(
    context,
    store: store,
    read: local ? () => File(source.toFilePath()).readAsBytes() : () => _downloadBundle(source),
    from: local ? null : source.host,
    commit: services.extensions.installBundle,
  ).then((name) {
    if (name == null) return;
    services.track('extension_installed', {});
    services.statusBar.setMessage(key: 'extensions:installed', text: t.extensionsPanel.installedMessage(name: name));
  }));
}

/// Fetches a bundle, refusing anything implausibly large before it is held in
/// memory — the link naming it is not one this app chose to trust.
Future<List<int>> _downloadBundle(Uri source) async {
  final client = http.Client();
  try {
    var target = source;
    // Redirects followed by hand, because the point of demanding https is
    // that nobody on the path can rewrite what the consent screen describes —
    // and a client following redirects for us will happily walk https into
    // http and hand back the result as though it were the URL we asked for.
    for (var hop = 0; hop < 5; hop++) {
      final request = http.Request('GET', target)..followRedirects = false;
      final response = await client.send(request).timeout(const Duration(seconds: 30));
      final location = response.headers['location'];
      if (response.statusCode >= 300 && response.statusCode < 400 && location != null) {
        final next = target.resolve(location);
        if (next.scheme != 'https') {
          throw BundleException(BundleRejection.notAnArchive, t.extensionsPanel.downloadNotSecure);
        }
        target = next;
        continue;
      }
      if (response.statusCode != 200) {
        throw BundleException(BundleRejection.notAnArchive,
            t.extensionsPanel.downloadFailed(source: target.host, status: response.statusCode));
      }
      // Counted as it arrives. Reading the whole body first and measuring it
      // afterwards is a cap that has already let the thing it refuses into
      // memory.
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (bytes.length > kMaxDownloadBytes) {
          throw BundleException(BundleRejection.tooLarge, t.extensionsPanel.downloadTooLarge);
        }
      }
      return bytes;
    }
    throw BundleException(BundleRejection.notAnArchive, t.extensionsPanel.downloadFailed(source: source.host, status: 310));
  } finally {
    client.close();
  }
}

/// Opens the pane once there is a navigator to open it onto.
///
/// A deep link that cold-launches the app arrives while the first frame is
/// still being built, and dropping it there is invisible to the operator:
/// for a QR request there is no code to fall back to typing, and no
/// Connection Requests row either, since a blank permission has no account
/// behind it for `pending_challenges` to count. Retries on the same cadence
/// the staleness nag uses for the same reason.
void _openConfirmDevicePane(
  HaLoServices services,
  ({String clientUuid, String challengeToken}) request, {
  int attemptsLeft = 20,
}) {
  final context = navigatorKey.currentContext;
  if (context == null) {
    if (attemptsLeft <= 0) {
      debugPrint('[deep-link] link_client dropped: no navigator after 5s');
      return;
    }
    Timer(const Duration(milliseconds: 250),
        () => _openConfirmDevicePane(services, request, attemptsLeft: attemptsLeft - 1));
    return;
  }
  unawaited(showConfirmDeviceDialog(
      context,
      findByCode: services.extensions.syncFindLinkRequest,
      findByClient: services.extensions.syncFindLinkRequestByClient,
      approve: services.extensions.syncApproveLinkRequest,
      clientUuid: request.clientUuid,
      challengeToken: request.challengeToken,
    ).then((linked) {
      // Re-read rather than reusing the context above: the pane was open
      // across an arbitrary stretch of the operator's attention.
      final messengerContext = navigatorKey.currentContext;
      if (linked != true || messengerContext == null) return;
      ScaffoldMessenger.of(messengerContext)
          .showSnackBar(SnackBar(content: Text(t.settings.syncPanel.deviceLinked)));
    }));
}

/// Raises the pairing prompt wherever the operator happens to be.
///
/// The Peers panel prompts too, but a device asking to pair is not something
/// an operator goes looking for — it arrives while they are logging. Without
/// this the request is silent everywhere except one settings screen, which
/// looks exactly like peer sync not working.
void _listenForPeerPairingRequests(HaLoServices services) {
  services.peerService.addListener(() {
    final pending = services.peerService.pendingPairing;
    final peer = pending?.session?.peer;
    if (peer == null) return;
    _openPeerPairingPrompt(services, peer.deviceId, peer.deviceName,
        viaBluetooth: pending?.session?.link is PeerBleLink);
  });
}

/// True while a prompt is on screen, so the service's own notifications —
/// one per beacon, several a second — cannot stack a second dialog on top of
/// the one the operator is reading.
bool _peerPairingPromptOpen = false;

/// Opens the prompt once there is a navigator to open it onto.
///
/// Same cold-start retry as [_openConfirmDevicePane], for the same reason: a
/// peer can be discovered while the first frame is still being built, and a
/// dropped prompt leaves a device sitting at `needsPairing` with nothing on
/// screen to say so. Unlike a QR deep link this one does have a way back —
/// the Peers panel lists the waiting device — so it gives up quietly.
void _openPeerPairingPrompt(
  HaLoServices services,
  String deviceId,
  String deviceName, {
  required bool viaBluetooth,
  int attemptsLeft = 20,
}) {
  if (_peerPairingPromptOpen) return;
  final context = navigatorKey.currentContext;
  if (context == null) {
    if (attemptsLeft <= 0) {
      debugPrint('[peer] pairing prompt dropped: no navigator after 5s — '
          'the Peers panel still lists $deviceId');
      return;
    }
    Timer(const Duration(milliseconds: 250),
        () => _openPeerPairingPrompt(services, deviceId, deviceName,
            viaBluetooth: viaBluetooth, attemptsLeft: attemptsLeft - 1));
    return;
  }
  _peerPairingPromptOpen = true;
  // catchError as well as the finally below: a navigator torn down while the
  // dialog is up completes this future with an ERROR, which `then`'s finally
  // does not run for — and a latched flag suppresses every future pairing
  // prompt for the rest of the process.
  unawaited(showPeerPairingDialog(context,
          deviceName: deviceName, deviceId: deviceId, viaBluetooth: viaBluetooth)
      .catchError((Object e) {
    debugPrint('[peer] pairing prompt failed: $e');
    return null;
  }).then((allowed) async {
    try {
      // Dismissed rather than answered: left pending on purpose, so the
      // Peers panel still offers it instead of it counting as a refusal.
      if (allowed == null) return;
      if (allowed) {
        await services.peerService.acceptPairing(deviceId);
      } else {
        await services.peerService.rejectPairing(deviceId);
      }
    } finally {
      _peerPairingPromptOpen = false;
    }
  }));
}

/// Forces the bundled color-emoji font's glyph data to load AND shape now,
/// instead of on whichever `Text` — or text *measurement* — happens to need
/// it first (see [bootstrap]'s call site).
///
/// Never throws, but the report is not ceremony: every flag in the app is a
/// glyph from this font and nothing renders one without it, so a load that
/// fails takes the feature with it rather than merely moving a cost.
///
/// It detects only an ABSENT asset, which is the loud case. A font that is
/// present and wrong — truncated, or a build with no flag glyphs — loads
/// here without complaint, because FontLoader accepts bytes it cannot decode
/// and `layout()` never throws for a missing glyph. That case is caught
/// before it ships, by app/test/emoji_font_asset_test.dart reading the
/// artifact, since at runtime it has no signal at all.
Future<void> _preloadEmojiFont() async {
  try {
    // FontLoader needs the family name to register under (matching what
    // emojiStyle() requests) and the asset bytes to register it with,
    // independently — both come from halo_widgets/theme.dart.
    final data = await rootBundle.load(emojiFontAssetPath);
    await (FontLoader(emojiFontFamily)..addFont(Future.value(data))).load();
    // Registering the font is cheap; laying it out is not. A flag emoji is
    // two combined regional-indicator codepoints — Skia's first shape of
    // that combination through a multi-megabyte color font is a real,
    // one-time cost (measured over 1s), paid wherever the first `Text` or
    // width *measurement* using this font happens to land. For QsoList
    // (HALO-258) that was the first operation's row metrics, mid-transition.
    // A throwaway layout here pays it during the splash instead.
    (TextPainter(
      text: TextSpan(text: '🇨🇦', style: emojiStyle()),
      textDirection: dart_ui.TextDirection.ltr,
    )..layout())
        .dispose();
  } catch (error, stackTrace) {
    debugPrint('[boot] emoji font preload failed: $error\n$stackTrace');
    ErrorReportingService.report(error, stackTrace, context: 'boot:emoji-font-preload');
  }
}

/// Resets the app to a known fixture for agent/dev verification: back up
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
  final backupId = nowUtc().toIso8601String();
  await services.db.transaction(() async {
    await services.operations.backupAndClearAll(backupId);
    await services.qsos.backupAndClearAll(backupId);
  });

  // Known UI state — the settings that most often skew visual verification.
  await services.settings.setFontScale(FontScale.normal);
  await services.settings.setDistanceUnits(DistanceUnits.kilometers);

  final operatorCall = services.settings.activeProfile.operatorCall;
  final stationCall = operatorCall.isNotEmpty ? operatorCall : 'N0DEV';
  final operation = await services.operations.create(stationCall: stationCall, userTitle: 'HALO Fixture');
  await services.operations
      .saveData(Operation(uuid: operation.uuid, data: {...operation.data, 'grid': fixtureOperationGrid}));

  final seeds = fixtureQsos(nowMillis());
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
@visibleForTesting
class BootGate extends StatefulWidget {
  final Future<HaLoServices> servicesFuture;

  const BootGate({super.key, required this.servicesFuture});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> with SingleTickerProviderStateMixin {
  static const _transitionDuration = Duration(milliseconds: 200);

  late final AnimationController _fadeController = AnimationController(vsync: this, duration: _transitionDuration)..value = 1;

  Widget _currentChild = const MaterialApp(
    key: ValueKey('splash'),
    debugShowCheckedModeBanner: false,
    home: SplashScreen(),
  );
  Widget? _previousChild;

  /// Bounds how long [initState] waits for the onboarding photo (see below)
  /// before giving up and switching off the splash without it.
  static const _onboardingPhotoTimeout = Duration(seconds: 5);

  /// Warms the image cache with onboarding's full-bleed release photo (a
  /// JPEG several hundred KB — real weight on web) so that by the time
  /// `_OnboardingGate` mounts moments after this resolves, `Image.asset`
  /// paints it immediately instead of a frame (or several, on a slow
  /// connection) behind — the whole point of waiting here instead of
  /// switching off the splash first. Takes the already-started
  /// [releaseNotes] future rather than loading it itself, since [initState]
  /// kicks that off before `servicesFuture` resolves. `context` is fine to
  /// use for `precacheImage` despite no `MaterialApp`/`MediaQuery` ancestor
  /// existing yet (see this class's own build() comment): the release photo
  /// has no resolution-variant assets declared, so its cache key doesn't
  /// depend on the devicePixelRatio that'd otherwise come from one.
  Future<void> _prepareOnboardingPhoto(Future<List<ReleaseNotesEntry>> releaseNotes) async {
    final notes = await releaseNotes;
    if (notes.isEmpty || !mounted) return;
    await precacheImage(AssetImage(notes.first.imageAssetPath), context);
  }

  @override
  void initState() {
    super.initState();
    // Started here, not inside the `.then` below: loading the release notes
    // has no actual dependency on `services` — only the decision to wait on
    // it (below) does — so this overlaps with bootstrap() instead of being
    // serialized behind it. Cheap regardless of whether onboarding ends up
    // showing: `loadReleaseNotes` caches its result, and the release-overlay
    // gate reads the same asset unconditionally on every boot anyway.
    final releaseNotes = loadReleaseNotes();
    widget.servicesFuture.then((services) async {
      if (!mounted) return;
      if (_onboardingWillShow(services)) {
        try {
          await _prepareOnboardingPhoto(releaseNotes).timeout(_onboardingPhotoTimeout, onTimeout: () {});
        } catch (error, stackTrace) {
          // Best-effort, same "fine to arrive late, or never" tolerance as
          // _OnboardingGateState._show() itself — a broken/missing
          // release-notes asset or photo must not block boot. Caught here
          // rather than left to the `.catchError` below, which would
          // otherwise mislabel it as `bootstrap()` failing and take down
          // the whole app instead of just onboarding's photo.
          debugPrint('[boot] onboarding photo prep failed (not a bootstrap() failure): $error\n$stackTrace');
        }
      }
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
      // Fail loud: runApp() happens before bootstrap() resolves, so an
      // unhandled rejection here would strand the user
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
    // `BootGate` sits above `TranslationProvider`/`MaterialApp`, so there's
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
  UpdateCheckService? updateCheck,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before everything else: settles where the app's files live and moves any
  // left in an older location, which SettingsService.load() below depends on
  // — once shared_preferences has read its file, it caches it.
  // Held for the notice below: the operator has to be told when settings they
  // had made are gone, and this is the only moment anything knows it.
  final preferencesRecovery = await initializeAppStorage();
  // What drift's web worker actually negotiated — read by
  // [reportWebStorageHealth] once the (lazy) database has opened, so boot
  // can warn when the browser degraded to storage that can lose the log.
  WasmDatabaseResult? webDbResult;
  final db = HaLoDatabase(driftDatabase(
    name: kDatabaseName,
    web: kIsWeb
        ? DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
            onResult: (result) => webDbResult = result,
          )
        : null,
    // drift resolves this lazily, right before opening the file — which is
    // what makes it the correct place to hang the one-shot relocation off
    // Documents: no boot step can accidentally open the database first.
    native: kIsWeb ? null : DriftNativeOptions(databaseDirectory: appDataDirectory),
  ));
  // Opened HERE rather than left to whichever query happens to be first.
  // drift runs its migration on the first statement, so a log written by a
  // newer build refuses to open somewhere deep in a sync round or a list
  // rebuild — and what the operator sees is a feature that quietly stops
  // working, with the only account of why in the console. Asking at boot is
  // what lets the notice below name the cause.
  //
  // NOT awaited here: the open is what every step below is already waiting on
  // lazily, and holding boot for it would put a disk round-trip in front of
  // the extension runtime and the settings load, which currently overlap it.
  final logRefusal = _openLogNow(db);
  final extensions = ExtensionService();
  // Fire-and-forget, and kicked off before awaiting settings below so these
  // two independent boot steps run concurrently instead of serialized; the
  // core logging loop never waits on the extension runtime either way.
  extensions.start();
  final settings = await SettingsService.load();
  // The previous run's database close, if it left a mark: the quit itself has
  // no time to report one, so this boot is the first moment it can be told.
  // Not awaited — the report is fire-and-forget either way, and a boot must
  // not wait on the last quit's postmortem.
  unawaited(reportUncleanQuit(settings.prefs));
  // Existing installs never ran through the 'first-use' counter — it didn't
  // exist yet — but they've already onboarded (see the method doc); a no-op
  // once seeded, so this is safe on every boot.
  await settings.seedFirstUseOnboardingForExistingUsers();
  // Reads the same "already onboarded" signal, so it must run before
  // onboarding gets a chance to write a callsign.
  await settings.seedSyncEnabledDefault();
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
    // Web and debug builds never have the engine, and constructing
    // ShorebirdUpdater() there prints the package's "Updater is unavailable"
    // notice on every boot — skip it and go straight to the no-op.
    updates: updates ?? (kIsWeb || kDebugMode ? const NoopUpdateService() : ShorebirdUpdateService(settings)),
    updateCheck: updateCheck,
  );
  // Cache the running code-push number for the synchronous version displays
  // (views/version_label.dart's buildDetails). Awaited rather than
  // fire-and-forget: a late arrival would leave the first frames naming a
  // build identity that no rebuild is coming to correct. Started here but
  // awaited at the end of boot (see below) so the wait overlaps the keyring,
  // sync and extension work instead of sitting in front of it.
  //
  // Every failure mode is swallowed to null, and deliberately so: this decides
  // a suffix on a version label, and nothing about a version label may cost
  // the operator their log. A hang is bounded by the timeout; a throw is
  // caught here rather than in the callee, because UpdateService is an
  // injectable interface and ShorebirdUpdateService catches only the one
  // exception its package documents — an isolate that fails to spawn under
  // memory pressure, or a future package version's new type, would otherwise
  // escape into bootstrap() and strand the user on the boot-error screen.
  //
  // Note what this does NOT bound: constructing ShorebirdUpdater above reads
  // the patch synchronously on this isolate, and the package's own source
  // warns that can block on the updater's config lock. No timer can fire
  // through that, so the guarantee here covers this read, not that one.
  // `.then` before `.timeout`, so "resolved" marks the read having ANSWERED —
  // a null answer means no push applied, which is a fact. A timeout or a throw
  // leaves it false, and the code-push floor stays silent rather than nagging
  // an install it cannot describe (services/staleness.dart).
  // Both values arrive together, from the layer that knows whether the read
  // answered. Setting "resolved" here instead would be wrong twice over: a
  // timeout does not cancel the future underneath it, so a late completion
  // would flip the flag beside a number nobody assigned; and a read exception
  // swallowed further down already returns a bare null. Either way the pair
  // would read as "no code push applied" and nag an operator who is current.
  final codePushFuture = services.updates
      .currentPatchNumber()
      .timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('[boot] code-push number timed out — the version label drops the suffix');
          return (resolved: false, number: null);
        },
      )
      .catchError((Object e) {
        debugPrint('[boot] code-push number unreadable: $e');
        return (resolved: false, number: null);
      });
  // A locked/absent keyring yields a null device key (ensureSyncDeviceKey no
  // longer throws) — boot must still complete, so skip sync setup and pick it
  // up on a later launch once the keyring is available.
  final syncDeviceKey = await settings.ensureSyncDeviceKey();
  if (syncDeviceKey != null) {
    services.extensions.setSyncCredentials(deviceKey: syncDeviceKey, operatorCall: settings.activeProfile.operatorCall);
    services.syncEngine.start();
    services.watchReceivedTestOperationPurges();
    // Independent of syncEngine.start() above: this registers device
    // identity/the realtime channel regardless of whether the operator has
    // QSO sync enabled — registration pushes no log data, only
    // syncEngine (gated on settings.syncEnabled) does that. Not awaited:
    // it's a network round-trip and boot must not wait on it.
    unawaited(services.connectLofiRealtime());
  } else {
    debugPrint('[boot] no sync device key (secure storage unavailable) — continuing without sync');
  }
  services.maybeStartInboundQsoListener();
  services.maybeStartPeerSync();
  _listenForPeerPairingRequests(services);
  // Reads the flag rather than this branch: a null device key means storage
  // threw, but saying so out loud keeps the notice tied to the fact it reports
  // instead of to one caller's control flow.
  if (settings.secureStorageUnavailable) maybeShowNoKeyringNotice(services);
  showPreferencesRecoveryNotice(services, preferencesRecovery);
  await showLogFromNewerBuildNotice(services, await logRefusal);

  // Reconnect the designated radio (docs/design/cat.md). Not awaited: the
  // radio may be off, and boot must not wait on a socket timeout. Gated on
  // the experiment so nothing opens a connection unless CAT is on.
  if (settings.experimentEnabled('gato') /* stored key, see experiments.yaml */ && !kIsWeb) {
    unawaited(services.cat.reconnectDesignatedRadio());
  }

  // OUTSIDE the experiment gate, deliberately: gated inside it, turning CAT
  // on in Settings mid-session and then connecting a radio would leave no
  // listener at all — bypassing exactly the people who had just
  // enabled the feature. shutdown() is a no-op when nothing is connected, so
  // installing it always costs nothing.
  if (!kIsWeb) shutdownOnExit(services);

  // macOS app-menu actions (see WindowChromeService and macos/Runner): "About"
  // shows the release overlay, "Preferences…" (⌘,) opens the Settings view.
  WindowChromeService.onShowReleaseOverlay = services.devSplashTrigger.trigger;
  WindowChromeService.onOpenSettings = () => navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => SettingsView(services: services)),
      );
  WindowChromeService.onCheckForUpdates = () => unawaited(const AutoUpdateService().checkForUpdatesInteractively());

  // The panel catalog is read HERE, before bootstrap returns and the first
  // view builds, rather than by whichever view happens to want it: a saved
  // dock arrangement names extension panels, and a view built against a
  // catalog that has not arrived yet shows placeholders for panes that are
  // perfectly fine.
  //
  // ONE short budget for this and the emoji-font warm-up below, because this
  // is splash time — `runApp` shows the splash until this future resolves,
  // and nothing else in bootstrap waits on the runtime (the logging loop
  // deliberately never does). Overrunning is not a failure and not fatal: a
  // panel that hasn't been read yet renders as a placeholder, the catalog
  // re-reads itself the moment the runtime comes up (`runtimeGeneration`),
  // and an unwarmed emoji font just shapes its first glyph later, exactly as
  // it did before this existed. The wait buys a tidier first frame in the
  // ordinary case; it must never buy a slow one.
  try {
    await Future.wait([
      extensions.start().then((_) => services.panels.refreshExtensionPanels()),
      // See _preloadEmojiFont's doc: pays the color-emoji font's one-time
      // load-and-shape cost here instead of on whichever screen measures or
      // paints the first flag glyph (HALO-258's QsoList open was 1s+ of it).
      if (!kIsWeb) _preloadEmojiFont(),
    ]).timeout(_panelCatalogBootBudget);
  } catch (e) {
    debugPrint('[boot] panel catalog not ready before first build ($e); panes will fill in');
  }

  // Await the extension system being fully booted, then initialize and sync data files
  unawaited(extensions.start().then((_) async {
    // BEFORE the data files, and awaited: connecting replaces the runtime, and
    // a replacement landing mid-load kills it against a disposed host — after
    // which the sync behind it fetches a 304, finds nothing to import, and the
    // session simply runs without that data (HALO-429). Sequenced here so
    // there is one runtime swap and then one load, against the runtime that
    // will actually serve it. Only ever with developer mode on AND the toggle
    // set — no address is ever discovered, only typed.
    if (settings.developerMode &&
        settings.extensionDevServerEnabled &&
        settings.extensionDevServerUrl.isNotEmpty) {
      // Never throws — the client records a failed connection as status
      // rather than an error, so a dev server that has since been stopped
      // costs a restarting app nothing but a line in Developer settings.
      await services.extensionDev.connect(settings.extensionDevServerUrl);
    }
    await services.dataFiles.loadRawDataFiles();
    // Unattended (no user action prompted this): a persistent failure notice
    // here would repeat on every single offline boot.
    await services.dataFiles.syncAllDataFiles(notifyOnFailure: false);
    // After the enabled extensions have refreshed their data-file ownership
    // records, drop the data of any extension disabled long enough ago.
    await services.dataFiles.purgeStaleExtensionData(settings.extensionDisabledSince);
  }).catchError((e) {
    debugPrint('[boot] failed to initialize data files: $e');
  }));

  // Settled BEFORE the flags refresh below, not merely before `return`: the
  // notice environment reads this global to report `appCodePush`, and a
  // `codePushes` rule that evaluated against a not-yet-resolved value would
  // silently target the wrong installs. Everything above has overlapped the
  // wait; by here it has almost always already completed.
  final codePushRead = await codePushFuture;
  currentCodePush = codePushRead.number;
  currentCodePushResolved = codePushRead.resolved;

  // Fetch feature flags + notices for the current callsign once the runtime
  // is up (the callsign→DXCC-entity annotation needs it). Fire-and-forget;
  // failures leave flags empty and are logged inside the service.
  unawaited(extensions.start().then((_) {
    return services.flags.refreshForCall(settings.activeProfile.operatorCall);
  }).catchError((e) {
    debugPrint('[boot] failed to fetch feature flags: $e');
  }));

  // Fire-and-forget like the boot steps above: neither the persistence
  // request nor the health warning is worth delaying first paint for.
  if (kIsWeb) unawaited(reportWebStorageHealth(services, () => webDbResult));

  if (!kIsWeb) {
    // Rotating file-level backups (see DatabaseSnapshotService's header).
    // Delayed well past boot: the first `VACUUM INTO` rides the statement
    // queue, and first paint must not wait behind a whole-file copy.
    final snapshots = DatabaseSnapshotService(db, dataDirectory: appDataDirectory);
    Timer(const Duration(minutes: 2), snapshots.start);
  }

  return services;
}

/// Web only: requests the persistent-storage grant and warns when drift's
/// worker degraded to storage that can lose the log.
///
/// Native builds keep the database in a real file the OS never evicts; on
/// web BOTH halves of durability are opt-in. Without
/// `navigator.storage.persist()` the browser may evict the whole origin
/// under storage pressure (and Safari expires script-writable storage after
/// seven days of disuse) — wiping every QSO that never synced. And drift
/// silently falls back to `unsafeIndexedDb` (two tabs clobber each other)
/// or `inMemory` (gone at tab close) when the worker handshake degrades;
/// the chosen implementation is only observable through
/// `DriftWebOptions.onResult`. The SELECT 1 forces the lazy database open
/// so that callback has fired before [result] is read.
Future<void> reportWebStorageHealth(HaLoServices services, WasmDatabaseResult? Function() result) async {
  // A false is normal on browsers that gate the grant behind engagement
  // heuristics, and asking again next boot is free — so no notice for it;
  // only the storage fallbacks below are worth an operator's attention.
  unawaited(requestPersistentWebStorage());
  try {
    await services.db.customSelect('SELECT 1').get();
  } catch (_) {
    return; // a database that can't even open reports through boot, not here
  }
  final negotiated = result();
  if (negotiated == null) return;
  debugPrint('[web-storage] using ${negotiated.chosenImplementation}'
      '${negotiated.missingFeatures.isEmpty ? '' : ', missing ${negotiated.missingFeatures}'}');
  switch (negotiated.chosenImplementation) {
    case WasmStorageImplementation.inMemory:
      services.statusBar.showNotice(key: 'webStorage', icon: 'database-alert', text: t.notices.webStorageInMemory);
    case WasmStorageImplementation.unsafeIndexedDb:
      services.statusBar.showNotice(key: 'webStorage', icon: 'database-alert', text: t.notices.webStorageUnreliable);
    case WasmStorageImplementation.opfsShared:
    case WasmStorageImplementation.opfsLocks:
    case WasmStorageImplementation.sharedIndexedDb:
      break;
  }
}

/// How long boot will wait for the extension runtime, its panel catalog, and
/// the emoji-font warm-up before showing the first view anyway. Deliberately
/// short: this is splash time, and the only thing it buys is not briefly
/// showing a placeholder panel or an unshaped flag glyph that both turn out
/// to be fine moments later.
const _panelCatalogBootBudget = Duration(seconds: 3);

/// Key for the notice below, and the pref that keeps it to one showing.
const noKeyringNoticeKey = 'accounts:no-keyring';
const _noKeyringNoticeShownKey = 'accounts:noKeyringNoticeShown';

/// Says once, on Linux, that account logins cannot be saved.
///
/// Public for its test: the Linux-only condition and the once-ness are the parts
/// worth pinning.
///
/// Reached when `ensureSyncDeviceKey` came back null, which happens only when
/// secure storage threw — on Linux that is libsecret reporting `KeyringLocked`,
/// which covers no Secret Service running, no default collection, and a
/// genuinely locked one. The copy therefore names all three rather than picking.
///
/// Deliberately NOT shown for the other failure this has: if the libsecret
/// SHARED LIBRARY is missing, the process dies before `main()` and no notice can
/// exist. That case is documentation only (docs/quirks.md).
///
/// Shown once, tracked in prefs rather than in notice history — history is
/// capped at 50 entries and would eventually let this reappear. An undismissed
/// notice is persisted and comes back on its own next launch, so posting it a
/// second time would also resurrect one the operator had dismissed.
@visibleForTesting
void maybeShowNoKeyringNotice(HaLoServices services) {
  // `defaultTargetPlatform` reports the HOST on web, so the kIsWeb guard is what
  // keeps a Linux browser out of a desktop-only message.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.linux) return;
  final prefs = services.settings.prefs;
  if (prefs.getBool(_noKeyringNoticeShownKey) ?? false) return;
  unawaited(prefs.setBool(_noKeyringNoticeShownKey, true));
  services.statusBar.showNotice(
    key: noKeyringNoticeKey,
    // `key-off` is NOT in the bundled MDI table and renders the puzzle-piece
    // fallback; `key-alert` is.
    icon: 'key-alert',
    title: t.settings.accounts.noKeyringTitle,
    text: t.settings.accounts.noKeyringText,
  );
}

/// Tells the operator that this launch had to repair an unreadable
/// preferences file. The upload happens back in [initializeAppStorage], where
/// the fact is first known and cannot be lost to a later boot failure.
///
/// Posted every time rather than once, unlike [maybeShowNoKeyringNotice]:
/// this describes something that happened on THIS launch, and a second
/// occurrence is a second loss of settings, not a repeat of the first.
@visibleForTesting
void showPreferencesRecoveryNotice(HaLoServices services, PreferencesRecovery recovery) {
  if (recovery == PreferencesRecovery.none) return;
  final restored = recovery == PreferencesRecovery.restoredFromBackup;
  services.statusBar.showNotice(
    key: 'preferencesRecovery',
    icon: 'cog-refresh',
    title: restored ? t.notices.preferencesRestoredTitle : t.notices.preferencesResetTitle,
    text: restored ? t.notices.preferencesRestored : t.notices.preferencesReset,
  );
}

/// Opens the log, and answers with the refusal if it was written by a build
/// newer than this one.
///
/// Every OTHER failure is left alone: the open is retried by the first real
/// query, so an error swallowed here is reported there instead — exactly as
/// it is today. Turning them all into boot failures is a much bigger change
/// than naming this one.
Future<LogFromNewerBuild?> _openLogNow(HaLoDatabase db) async {
  try {
    await db.customSelect('SELECT 1').get();
  } catch (e, st) {
    // Through `within` rather than an `on LogFromNewerBuild` clause, which
    // would match only in a test: the app opens its database over a
    // background isolate, so the refusal arrives wrapped in a
    // DriftRemoteException. See LogFromNewerBuild.within.
    final refusal = LogFromNewerBuild.within(e);
    if (refusal == null) {
      // Every other failure is left alone: the open is retried by the first
      // real query and reported from there, exactly as it is today.
      debugPrint('[boot] the log did not open yet: $e');
      return null;
    }
    ErrorReportingService.report(e, st, context: 'db:log-from-newer-build');
    return refusal;
  }
  return null;
}

/// Tells the operator that this build cannot open the log it found, and why.
///
/// The versions and the directory are all in the notice, because the two
/// questions this raises — which build wrote it, and which file is it — have
/// no other answer anywhere in the app, and the alternative is diagnosing an
/// app that simply refuses to save from a console line.
@visibleForTesting
Future<void> showLogFromNewerBuildNotice(HaLoServices services, LogFromNewerBuild? refusal) async {
  if (refusal == null) return;
  // Two strings rather than one with a stand-in for the path: on web there
  // is no folder to name — the log is in the browser's own storage — and
  // splicing an English "this browser" into the sentence would leave every
  // other locale reading its own words and then a foreign phrase.
  final text = kIsWeb
      ? t.notices.logFromNewerBuildNoLocation(
          storage: refusal.storage.toString(),
          understood: refusal.understood.toString(),
        )
      : t.notices.logFromNewerBuild(
          storage: refusal.storage.toString(),
          understood: refusal.understood.toString(),
          location: (await appDataDirectory()).path,
        );
  services.statusBar.showNotice(
    key: 'logFromNewerBuild',
    icon: 'database-alert',
    title: t.notices.logFromNewerBuildTitle,
    text: text,
  );
}

/// One open Operation View's contribution to the ⌘K dialog's context — see
/// [HaLoServices.openOperationContext].
class OperationCommandContext {
  OperationCommandContext(this.uuid);

  final String uuid;

  /// The operation QSON with `uuid` folded in, once it has loaded.
  Map<String, dynamic>? operation;

  /// This operation's logging panel dispatcher, while one is mounted.
  CommandActionsDispatcher? dispatch;

  /// Puts a QSON-shaped suggestion into this operation's logging fields — the
  /// same prefill a tapped spot performs (`OperationView`'s `_suggestQso`).
  ///
  /// Here rather than as a [CommandActionsDispatcher] action because a
  /// suggestion is not a command: it arrives from outside the operation
  /// entirely (a `/qso` deep link), carries refs and radio state together, and
  /// must reach the view even when no logging panel is mounted to dispatch
  /// through — which is exactly when [dispatch] is null.
  void Function(Map<String, dynamic> qso)? suggestQso;

  /// Whether this operation is the route the operator is actually looking at.
  /// False with Settings, or a nested operation, pushed over it — where a
  /// suggestion still lands correctly but nothing on screen shows it.
  bool Function()? isVisible;
}

/// Kept alive for the process lifetime — an [AppLifecycleListener] stops
/// observing when it is garbage collected.
AppLifecycleListener? _shutdownLifecycle;

/// Say goodbye to connected equipment, and to SQLite, before the app stops
/// existing.
///
/// A session the radio is never told to end is one it keeps holding. The
/// IC-705 has a single remote-control slot and holds the login until it times
/// out on its own, so quitting without a disconnect is what makes the NEXT
/// connect fail — the "radio did not answer the login".
///
/// NOT the reason: "the radio streams ~95 packets/second at us and an
/// ungraceful exit leaves that flood pointed at a dead port" — measured
/// FALSE on hardware (see the CAT commit "the IC-705 sends us no audio");
/// the radio only streams audio to a client that has completed a session
/// handshake on port 50003, which we never do. The
/// reason above is the real one.
///
/// `onExitRequested` is the desktop hook that can actually *await* cleanup
/// before the process goes. `detached` is BEST EFFORT ONLY: onStateChange is
/// synchronous, so the work cannot be awaited, and on a dying isolate a
/// disconnect needing a 600ms ack will usually not complete. Deliberately NOT
/// `paused`: on Android that fires every time the operator switches away to
/// look something up. So an Android kill from the background still escapes
/// this — see docs/design/cat.md.
@visibleForTesting
void shutdownOnExit(HaLoServices services) {
  _shutdownLifecycle ??= AppLifecycleListener(
    onExitRequested: () async {
      // Before any of the teardown below: from here on, a write that loses its
      // race with the database close is expected rather than a defect, and
      // ErrorPolicy's `database-closed-on-exit` rule reads this to tell the
      // two apart.
      ErrorPolicy.appIsExiting = true;
      try {
        // Bounded. shutdown() awaits each node in turn, and while the Icom
        // path is bounded (600ms ack + 20ms), a serial port wedged mid-write
        // has no such guarantee. Without a ceiling one stuck radio hangs
        // Cmd-Q with no window and no feedback, and the force-quit that
        // follows skips the very disconnect this exists to send.
        await services.cat.shutdown().timeout(const Duration(seconds: 5));
      } catch (e, st) {
        // Never block the user's quit on a radio that will not let go.
        ErrorReportingService.report(e, st, context: 'cat:shutdown-on-exit');
      }
      // After CAT, which writes through the same database on its way out.
      await closeDatabaseOnExit(services);
      _reportARefusedExit();
      return AppExitResponse.exit;
    },
    onStateChange: (state) {
      if (state == AppLifecycleState.detached) unawaited(services.cat.shutdown());
    },
  );
}


/// How long the database step may take, split so the part that must happen
/// still gets its turn if the part that merely should takes too long.
///
/// Both are bounded for the same reason CAT's shutdown is: a wedged write must
/// not leave Cmd-Q hanging with no window and no feedback. Their sum is
/// deliberately well under CAT's own ceiling — the steps are serialized and
/// what an operator experiences is the total, so a matching 5s here would
/// allow the very windowless wait each ceiling exists to prevent.
const _drainBudget = Duration(milliseconds: 1500);
const _closeBudget = Duration(seconds: 2);
const _markBudget = Duration(milliseconds: 500);

/// Shuts the database down on the way out, as carefully as an exit allows —
/// the operator's log is the one thing in this app that cannot be recreated.
///
/// Three steps, in this order, each load-bearing:
///
/// 1. **Stop scheduling.** SyncEngine's loop is what starts new work on its
///    own; a round beginning between the drain and the close would be rolled
///    back by it, for the next launch to redo. PeerService is deliberately NOT
///    disposed here: it is a lazily-built ChangeNotifier that a session may
///    never have constructed, and building one at quit just to dispose it —
///    while widgets that listen to it are still mounted — costs more than the
///    inbound event it would prevent, which the peer resends anyway.
/// 2. **Drain.** drift's close is NOT a barrier: the background isolate acts
///    on the terminate request whenever it arrives and closes the connection
///    under whatever is still running, so a multi-statement transaction in
///    flight (an ADIF import, a sync round) is rolled back rather than
///    finished. An empty transaction queues behind any real one — drift
///    serializes them on a single lock — so awaiting it means the connection
///    is idle before the close begins.
/// 3. **Close**, so SQLite shuts down on a live isolate rather than during the
///    VM's teardown, where it aborts (see [shutdownOnExit]).
///
/// SQLite's own guarantees cover what none of this can: a transaction is
/// atomic, so even a process killed outright leaves a consistent file that
/// the next open recovers. What these steps buy is the write that would
/// otherwise be rolled back, and an exit that isn't a crash report.
///
/// The breadcrumb around it all is the only part that outlives the process:
/// the engine tears the app down the moment this returns, so a `report()` from
/// a failed close never reaches the backend. The next boot reports it instead
/// (`reportUncleanQuit`, wired into [bootstrap]).
@visibleForTesting
Future<void> closeDatabaseOnExit(HaLoServices services) async {
  final prefs = services.settings.prefs;
  // Guarded and bounded like everything else on this path, and for a sharper
  // reason: the mark is worth less than the close it describes. An unwritable
  // prefs file or a wedged platform channel must not throw or hang in FRONT of
  // the close — that would leave the process to abort on the way out, which is
  // the very failure the mark exists to record.
  try {
    await markDatabaseClosing(prefs).timeout(_markBudget);
  } catch (e, st) {
    ErrorReportingService.report(e, st, context: 'db:mark-on-exit');
  }
  services.syncEngine.dispose();
  try {
    await services.db.transaction(() async {}).timeout(_drainBudget);
  } catch (e, st) {
    // Reported, not rethrown: a drain that cannot finish is a write about to
    // be lost, which is worth knowing — and the close still has to happen, or
    // the process aborts on the way out with that write lost anyway.
    ErrorReportingService.report(e, st, context: 'db:drain-on-exit');
  }
  try {
    await services.db.close().timeout(_closeBudget);
    await markDatabaseClosed(prefs).timeout(_markBudget);
  } catch (e, st) {
    ErrorReportingService.report(e, st, context: 'db:close-on-exit');
  }
}

/// Says so, loudly, if the app is still running after its database was closed.
///
/// The framework asks EVERY observer whether it may exit and takes a `cancel`
/// from any one of them, so our own `exit` answer does not decide the outcome:
/// a refusal anywhere leaves this app alive on a database drift cannot reopen.
/// Nothing here cancels one today — we are the only `onExitRequested` in the
/// app, and no plugin in the tree implements `didRequestAppExit` — which makes
/// this a guard against a future observer, not a live path.
///
/// Volume is the entire point. Every write from here on fails, and
/// `ErrorPolicy.appIsExiting` is what tells the policy those failures are
/// expected; left set on an app that did not exit, it would turn an operator
/// logging into nothing into the quietest tier we have.
void _reportARefusedExit() {
  Timer(const Duration(seconds: 2), () {
    ErrorPolicy.appIsExiting = false;
    ErrorReportingService.report(
      StateError('the app is still running after its database was closed to exit'),
      StackTrace.current,
      context: 'db:exit-refused',
    );
  });
}

/// The core services bundle passed down to screens.
class HaLoServices {
  final HaLoDatabase db;
  final SettingsService settings;
  final ExtensionService extensions;
  final MetricsService metrics;
  final PurchaseService purchases;
  final UpdateService updates;
  final UpdateCheckService updateCheck;

  /// Every local write fans out to BOTH consumers, and both repositories get
  /// the same lambda — a third repository wired to only one of them would
  /// leave that consumer silently behind on those writes. `notifyChanged` is
  /// a no-op on each until it has something to do (sync disabled, or no
  /// operation being shared), so this costs nothing when neither is running.
  void _onLocalWrite() {
    syncEngine.notifyChanged();
    peerOutbox.notifyChanged();
  }

  late final OperationsRepository operations = OperationsRepository(
    db,
    onChange: _onLocalWrite,
    // The latest segment follows a local edit to what it restates: a rover
    // who sets a new square through the Location screen after a BREAK would
    // otherwise keep scoring from the break's old one (contests.md §5.1.3).
    onLocalSave: (before, after) async {
      if (before != null && !segmentOverrideDiffers(before.data, after.data)) return;
      final override = segmentOverrideOf(after.data);
      // The segment's contacts follow its station call, unasked: the segment
      // states which station was on the air for that stretch, so a contact
      // inside it cannot say otherwise. The FIRST call — several live in the
      // field as one string, and a contact holds one (HALO-507).
      await qsos.restampSegmentStationCall(after.uuid, after.stationCalls.first);
      // The description is composed only once a row is actually going to be
      // written: it fans out to an extension hook per ref, and an
      // unsegmented log (the common case) must not pay that on every save.
      await qsos.restampLatestSegment(
        after.uuid,
        override,
        describe: () => segmentDescription(after, override),
      );
    },
  );
  late final SequencesRepository sequences = SequencesRepository(db);
  late final QsosRepository qsos = QsosRepository(db, onChange: _onLocalWrite, sequences: sequences);

  /// Files the OS asked this app to open — a double-clicked `.h2kext`
  /// (HALO-422). Lazy: nothing listens until something wires it up.
  late final OpenedFilesService openedFiles = OpenedFilesService();

  /// The app end of the extension dev loop
  /// (docs/extensions/development.md). Lazy, and inert until someone turns it
  /// on in Developer settings and types a server address — an operator who
  /// never writes an extension pays nothing for it.
  late final ExtensionDevClient extensionDev = ExtensionDevClient(extensions: extensions);

  /// The peer-sync outbox (HALO-310). Owned here rather than inside
  /// [peerService] because the repositories' `onChange` reaches it on every
  /// local write, including while nothing is being shared — when it does
  /// nothing at all.
  late final PeerOutbox peerOutbox = PeerOutbox(db);

  /// LAN peer device sync. Binds nothing until the master switch turns it
  /// on, so a lazy `late final` that nobody touches costs an operator who
  /// never uses this exactly nothing.
  final PeerService? _peerServiceOverride;
  late final PeerService peerService = _peerServiceOverride ??
      PeerService(
        db: db,
        outbox: peerOutbox,
        operations: operations,
        qsos: qsos,
        localDeviceId: settings.peerDeviceId,
        localDeviceName: settings.peerDeviceName,
        // Null on web. Constructing the gateway touches no radio; only the
        // Bluetooth sub-switch wakes it.
        bleGateway: createPeerBleGateway(),
      );

  /// Routes the sessions' ephemeral channel (GPS, CAT next) between
  /// [peerService] and the app services that produce and consume it. Its
  /// construction is what plugs the channel in, so [updatePeerSharing]
  /// touches it before starting anything — lazily, like the service itself.
  late final PeerChannels peerChannels = PeerChannels(
    peers: peerService,
    location: location,
    radio: radio,
    // Both halves of screen sharing, constructed only when the experiment
    // is on: touching either lazy field is what registers a native channel
    // handler and what makes this router route those messages at all.
    screens: settings.experimentEnabled('remote') ? peerScreens : null,
    views: settings.experimentEnabled('remote') ? peerScreenViews : null,
    // Gated on p2p rather than on `remote`: this is peer sync's own live
    // logging view, not screen sharing.
    drafts: settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ ? peerDrafts : null,
    claims: settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ ? serialClaims : null,
    station: cat,
    remoteRadios: peerRemoteRadios,
  );

  /// The radios the PEERS are offering (HALO-416), for the Station panel's
  /// main-VFO picker. Not experiment-gated the way the screen halves are:
  /// the CAT bridge rides peer sync itself, and an empty holder is exactly
  /// what a build with no peers has.
  late final PeerRemoteRadios peerRemoteRadios = PeerRemoteRadios();
  /// The producer half of screen sharing (HALO-369). Lazy like the rest, and
  /// for a stronger reason than most: constructing it registers the native
  /// capture channel's handlers, and an install that never turns the
  /// experiment on should never so much as name ScreenCaptureKit.
  late final PeerScreens peerScreens = PeerScreens(settings: settings, peers: peerService);

  /// What every operating position sharing the open operation is composing
  /// (HALO-395) — this device's own block included. Lazy like the rest: an
  /// install that never turns the experiment on never constructs it, and
  /// `PeerChannels` then has nowhere to route a `qsoDraft`.
  late final PeerDrafts peerDrafts = PeerDrafts(peers: peerService);

  /// The contest serial numbers this device holds while composing, against
  /// its peers' (HALO-476). Lazy like the rest: the panel only asks for it
  /// while sharing drafts, and falls back to `peek` otherwise. Unlike the
  /// drafts it crosses Bluetooth links too: a claim is a few hundred bytes,
  /// and a position on BLE left out of the round could only ever learn of a
  /// collision from the log. In the round, an idle link acks well inside
  /// the cap; one congested by a sync batch lets the claimant show at the
  /// cap and turns the collision, if there is one, into the conflict mark.
  late final SerialClaims serialClaims = SerialClaims(
    localDeviceId: peerService.localDeviceId,
    peek: sequences.peek,
    livePeers: () => [
      for (final deviceId in peerService.peers.keys)
        if (peerService.hasSession(deviceId)) deviceId,
    ],
    send: (deviceId, message) => peerService.sendEphemeralTo(deviceId, message, allowBle: true),
    onCommittedConflict: (operationUuid, request, number) =>
        unawaited(qsos.markSerialConflict(operationUuid, request, number)),
  );

  /// The viewer half — what this device's peers offer, and what its Remote
  /// Screen panes are watching (HALO-369).
  late final PeerScreenViews peerScreenViews = PeerScreenViews(
    peers: peerService,
    // Its own producer, so a pane here can show a screen THIS device shares.
    screens: peerScreens,
    localName: t.settings.peers.screenThisDevice,
  );

  late final LookupRepository lookups = LookupRepository(db);

  /// Reference outlines (a SOTA activation zone and the like), fetched on
  /// demand and cached on the device. Lazy like the rest: an operator who
  /// never opens the Activities map never builds one.
  late final GeoshapeService geoshapes = GeoshapeService(extensions: extensions, lookups: lookups);
  late final InboundCaptureRepository inboundCaptures = InboundCaptureRepository(db);
  final ExportService? _exportsOverride;
  late final ExportService exports =
      _exportsOverride ?? ExportService(extensions: extensions, qsos: qsos, settings: settings);
  late final ScoringService scoring = ScoringService(extensions: extensions, qsos: qsos, operations: operations);
  /// The panel catalog a customizable view arranges (docs/design/layouts.md).
  /// Lazy like the rest: nothing asks the extensions for panels until a view
  /// that can hold one is actually built.
  late final PanelService panels = PanelService(extensions);
  late final OperationTitleService operationTitles = OperationTitleService(extensions: extensions, operations: operations);

  /// Deletes a Test Operation for real, QSOs included — see
  /// `OperationsRepository.purge`. Never call for a non-test operation:
  /// `operation_dialogs.dart`'s delete confirmation and PURGETESTS are the
  /// only two callers, and both check `Operation.isTestOperation` first.
  Future<void> purgeOperation(String uuid) async {
    // One transaction: a crash or throw between the two writes must never
    // leave the operation tombstoned while its QSOs are still live, or vice
    // versa — the orphan would then survive every future purge round, since
    // nothing revisits an operation once it isn't dirty.
    await db.transaction(() async {
      await operations.purge(uuid);
      await qsos.purgeForOperation(uuid);
    });
  }

  /// The operator confirmed the "these were removed elsewhere" prompt
  /// ([watchReceivedTestOperationPurges] below) for [uuids] — hard-deletes them and
  /// their QSOs. Unlike [purgeOperation], these were never purged on this
  /// device; `operations.eligibleReceivedPurges` is what actually decides
  /// which of [uuids] still qualify (re-checked against the database, not
  /// trusted from whatever was on screen when the operator tapped confirm).
  ///
  /// Isolated per operation, like [_runPurgeTests]'s own loop, but ALSO
  /// atomic per operation (`db.transaction`): the operator confirmed
  /// removing potentially several at once, and one throwing must not
  /// silently strand the rest — nor, within a single operation, delete its
  /// QSOs and then fail before the operation row goes too (or the reverse).
  /// A transaction is what makes "delete QSOs, then the operation row"
  /// order actually safe instead of just less likely to go wrong: without
  /// it, a failure between the two steps still leaves exactly the stranded
  /// state this exists to prevent.
  ///
  /// Returns both `eligible` (how many of [uuids] were still real
  /// candidates — the rest were dropped legitimately, e.g. the
  /// callsign-edit escape hatch fired between listing and confirming) and
  /// `removed` (how many of those actually succeeded). A caller comparing
  /// `removed` against `uuids.length` instead of `eligible` would read a
  /// clean run full of legitimate drops as a batch of failures.
  Future<({int eligible, int removed})> confirmReceivedTestOperationPurges(Iterable<String> uuids) async {
    final eligibleUuids = await operations.eligibleReceivedPurges(uuids);
    var removedCount = 0;
    for (final uuid in eligibleUuids) {
      try {
        await db.transaction(() async {
          await qsos.hardDeleteAllForOperation(uuid);
          await operations.hardDeleteOperation(uuid);
        });
        removedCount++;
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'confirmReceivedTestOperationPurges:$uuid');
      }
    }
    return (eligible: eligibleUuids.length, removed: removedCount);
  }
  late final RadioService radio = _buildRadioService();

  /// The VFO store, with the one-time migration of the operator's stated
  /// power into it. Power used to live in `SettingsService.currentPower`
  /// (Station Configuration's field wrote it); it now rides on the VFO with
  /// frequency and mode, where every surface reads it. The old key is left
  /// where it is rather than deleted — nothing writes it any more, and it is
  /// the only record of the value for an operator who hasn't set one since.
  RadioService _buildRadioService() {
    final service = RadioService(settings.prefs);
    final legacy = settings.currentPower;
    if (service.vfoA.power == null && legacy != null) service.setVfo('vfoA', power: legacy);
    return service;
  }
  // Station equipment and CAT control, behind the `cat` experiment
  // (docs/design/cat.md). Lazy: nothing connects until the user asks it to
  // from Settings → Station Configuration, so this costs nothing while the
  // experiment is off.
  /// Injectable like [_exportsOverride], so a test can hand in a CatService
  /// built over a fake transport — the real one can only reach `connected`
  /// through hardware.
  final CatService? _catOverride;
  late final CatService cat = _catOverride ?? CatService(settings, radio: radio, onTrack: track);
  /// Injectable like [_exportsOverride]: `permissionDenied` and `unavailable`
  /// are reachable only by denying an OS permission or losing a GPS fix, so a
  /// widget test of what those states put on screen has no other way in.
  final LocationService? _locationOverride;
  late final LocationService location = _locationOverride ?? LocationService();
  /// Injectable like [_exportsOverride]: the real one reads
  /// `AppLinks().uriLinkStream`, a platform channel with no implementation
  /// under `flutter test`, so a redirect coming back from the OS is
  /// otherwise unreachable — and the OAuth login it completes is the one
  /// flow whose happy path exists nowhere else.
  final DeepLinkService? _deepLinksOverride;
  late final DeepLinkService deepLinks = _deepLinksOverride ?? DeepLinkService();

  /// Pusher app key + cluster for the realtime client — public,
  /// non-secret values (every Pusher client SDK ships them this way), but
  /// still build-time configured like SOTA's OAuth client id
  /// (config/secrets.dart) since they point at whichever LoFi
  /// deployment this build talks to. Empty in a checkout that hasn't filled
  /// them in: [pusher] is then null and every realtime feature falls back
  /// to its polling path rather than crashing.
  /// Injectable so a test can drive the realtime path over a fake socket —
  /// the real one only ever exists in a build whose secrets name a Pusher
  /// deployment, which no test has.
  final PusherService? _pusherOverride;
  late final PusherService? pusher = _pusherOverride ??
      ((secrets['PUSHER_KEY']?.isEmpty ?? true) || (secrets['PUSHER_CLUSTER']?.isEmpty ?? true)
          ? null
          : PusherService(appKey: secrets['PUSHER_KEY']!, cluster: secrets['PUSHER_CLUSTER']!));

  /// Registers this device with the sync server — independent of QSO sync
  /// being enabled, deliberately — and, once that succeeds,
  /// subscribes the realtime client to its push channel. Safe to call
  /// repeatedly (boot, and every [setOperatorCall]):
  /// `ensureLofiClientRegistered` is idempotent, and re-subscribing an
  /// already-subscribed channel is a no-op ([PusherService.subscribe]).
  ///
  /// Returns the registration so a caller that also needs it directly (e.g.
  /// `_doOAuth`, for the `webhookClientToken` its `state` param carries) can
  /// go through this one place rather than re-registering by hand.
  Future<LofiClientRegistration?> connectLofiRealtime({bool refreshWebhookToken = false}) async {
    final registration =
        await extensions.ensureLofiClientRegistered(refreshWebhookToken: refreshWebhookToken);
    if (registration != null) pusher?.subscribe(registration.pushChannelName);
    return registration;
  }

  /// Webhook-relay events on this device's push channel — an
  /// OAuth flow waiting on a provider redirect listens here for
  /// the ping, then calls [ExtensionService.fetchLofiWebhookEvents] for the
  /// payload (the push itself only ever carries an event id, never the
  /// sensitive payload — deliberately).
  Stream<PusherEvent> get webhookEvents =>
      pusher?.events.where((e) => e.event == 'webhook_event') ?? const Stream.empty();
  final DataFileManager? _dataFilesOverride;
  late final DataFileManager dataFiles = _dataFilesOverride ??
      DataFileManager(
        lookups: lookups,
        extensions: extensions,
        prefs: settings.prefs,
        statusBar: statusBar,
        offlineChanges: ConnectivityService.offlineChanges,
        isOffline: () => ConnectivityService.isOffline,
      );
  late final StatusBarService statusBar = StatusBarService(settings.prefs);

  /// Where a focused field publishes the mobile numbers row, so
  /// `StatusBarOverlay` can draw it below the status footer and directly on
  /// the keyboard — an order no single route can produce for itself.
  final KeyboardAccessoryController keyboardAccessory = KeyboardAccessoryController();
  /// Spots fetched once and shared by the Spots Panel and the `spot-history`
  /// lookup hook. Idle until something subscribes (see SpotsService).
  late final SpotsService spots = SpotsService(
    fetchSpots: extensions.getSpots,
    isOffline: () => ConnectivityService.isOffline,
    offlineChanges: ConnectivityService.offlineChanges,
  );

  final LookupQueueService? _lookupQueueOverride;
  late final LookupQueueService lookupQueue = _lookupQueueOverride ??
      LookupQueueService(
        lookup: extensions.lookupCall,
        qsos: qsos,
        operations: operations,
        statusBar: statusBar,
        lookupReady: () => extensions.ready,
        isOffline: () => ConnectivityService.isOffline,
        offlineChanges: ConnectivityService.offlineChanges,
      );

  /// See `InboundQsoListenerService`: listens for another logging program's
  /// QSOs (N1MM's UDP broadcast protocol) and buffers them until an operator
  /// adds them to an operation's log. Lazy like the rest, but
  /// [maybeStartInboundQsoListener] forces it into existence at boot when
  /// the setting is already on — a `late final` nobody has touched yet would
  /// otherwise never bind the socket, even though the operator turned
  /// listening on in a previous session.
  final InboundQsoListenerService? _inboundQsosOverride;
  late final InboundQsoListenerService inboundQsos = _inboundQsosOverride ??
      InboundQsoListenerService(
        settings: settings,
        captures: inboundCaptures,
        qsos: qsos,
        operations: operations,
        lookupQueue: lookupQueue,
        statusBar: statusBar,
      );

  /// Touches [inboundQsos] if listening is already enabled, so a setting
  /// left on from a previous session resumes without the operator having to
  /// open the Imports panel first. A no-op otherwise: nothing should bind a
  /// UDP port on every boot for a feature nobody turned on.
  void maybeStartInboundQsoListener() {
    if (settings.listenForOtherAppsEnabled) inboundQsos;
  }

  /// Resumes peer sync when the switch was left on in a previous session —
  /// the same reason [maybeStartInboundQsoListener] exists: a `late final`
  /// nobody has touched yet would otherwise never start, even though the
  /// operator turned it on.
  void maybeStartPeerSync() {
    if (settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ && settings.peerSyncEnabled) {
      updatePeerSharing();
    }
  }

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
    onTrack: track,
    staleness: staleness,
  );

  /// Decides whether this install is out of date and, if so, says it exactly
  /// once (services/staleness.dart ranks the three signals). Fed by [flags]
  /// after each refresh and re-checked on resume.
  late final StalenessService staleness = StalenessService(
    statusBar: statusBar,
    navigatorKey: navigatorKey,
    prefs: settings.prefs,
    updates: updates,
    onNoticeAction: handleNoticeAction,
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
    ..register(RadioSettingsGroup(settings))
    ..register(MapSettingsGroup(settings))
    ..register(PrivacySettingsGroup(settings))
    ..register(ExportsSettingsGroup(settings))
    ..register(SyncSettingsGroup(settings, onToggle: setSyncEnabled));

  /// One open Operation View's command context, for the ⌘K dialog: the
  /// operation as command hooks expect it, plus the logging panel's action
  /// dispatcher while one is mounted.
  ///
  /// These live on a STACK rather than in a single slot, because open
  /// operations nest — the palette can open operation B from inside operation
  /// A. A slot cleared on dispose leaves A silently context-less after B pops,
  /// even though A's logging panel is still mounted and visible; a stack
  /// simply reveals A's entry again. Entries are removed by identity, so the
  /// same operation opened twice is two independent entries.
  final List<OperationCommandContext> _operationStack = [];

  /// The front-most open operation, as the `{...operation.data, 'uuid': …}`
  /// map command hooks expect (the uuid is what lets them reach
  /// `ctx.getOperation` / `ctx.getQsos`; see `logging_controls.dart`'s
  /// `_operationDataForCommands`). Null wherever no operation is open: Home,
  /// Settings.
  ///
  /// The ⌘K command dialog reads this so operation-scoped commands (SEED,
  /// NOTE, SPOT) run against the open operation instead of coming back with
  /// their "needs an open operation" error. It exists because the operation is
  /// otherwise route-local state inside `OperationView`, which a global
  /// keyboard shortcut has no path to. When the app grows real multi-window
  /// support (docs/design/user-interface.md, "Future directions"), this
  /// becomes per-window rather than app-wide.
  Map<String, dynamic>? get currentOperationContext =>
      _operationStack.isEmpty ? null : _operationStack.last.operation;

  /// The front-most logging panel's `CommandAction` dispatcher, or null when
  /// no operation is open.
  ///
  /// The QSO-scoped actions — `setVfo`, `addQso`, `updateQso`,
  /// `setCallField`, `sendSpots` — can only be applied by the widget that owns
  /// the in-progress QSO and its controllers. Without this a "20M" run from
  /// the ⌘K dialog interprets fine, returns `setVfo`, and then silently does
  /// nothing. Routing the whole batch through here instead makes a command
  /// from the palette behave exactly as if it had been typed into the call
  /// field — `LoggingControls`' dispatcher handles the app-scoped actions too.
  CommandActionsDispatcher? get currentCommandDispatch =>
      _operationStack.isEmpty ? null : _operationStack.last.dispatch;

  /// The front-most open operation's stack entry, or null when none is open.
  ///
  /// How a `/qso` deep link reaches the operation the operator is already in
  /// rather than pushing a second copy of it. The whole entry, not just its
  /// `suggestQso`, because the caller also has to ask whether that operation
  /// is the visible route before deciding what to tell the operator. Same
  /// stack, same reasoning as [currentCommandDispatch].
  OperationCommandContext? get frontOperationContext =>
      _operationStack.isEmpty ? null : _operationStack.last;

  /// Where a command action's message goes: the command bar that is running a
  /// command right now, on its own response line, rather than the status bar
  /// (see [runCommandAction]). Returns whether it could show it.
  ///
  /// A sink here rather than a parameter because a command bar does NOT
  /// dispatch most commands itself: with an operation open the whole action
  /// batch goes to the front-most logging panel ([currentCommandDispatch]),
  /// whose own handler is the one that ends up calling [runCommandAction]. So
  /// the message comes back through code the bar never touches, and this is
  /// the only thing they share.
  ///
  /// Set for the duration of ONE command's dispatch by `CommandEngine`, not
  /// for a bar's lifetime: every action's message arrives inside that awaited
  /// window, and a slot held open longer catches messages from commands typed
  /// somewhere else entirely — a SPOT started in the call field, answering
  /// seconds later on a palette that has since opened, blanking the card and
  /// dismissing itself over a command the operator never typed there.
  bool Function(String message, {bool failed})? commandResponseSink;

  /// Registers a newly opened Operation View and returns its entry, which the
  /// caller fills in as its operation loads and must pass back to
  /// [closeOperationContext] on dispose.
  OperationCommandContext openOperationContext(String uuid) {
    final entry = OperationCommandContext(uuid);
    _operationStack.add(entry);
    updatePeerSharing();
    return entry;
  }

  /// Removes [entry] by identity, so a disposing view can never take a
  /// still-live one's place with it.
  void closeOperationContext(OperationCommandContext entry) {
    _operationStack.remove(entry);
    updatePeerSharing();
  }

  /// Tells peer sync what to share: the front-most open operation while the
  /// master switch is on, nothing otherwise.
  ///
  /// Driven off [_operationStack] rather than hooked into OperationView's
  /// initState/dispose because the stack already gets nesting right — opening
  /// operation B from inside A and popping back reveals A again, where a
  /// dispose-clears-the-slot hook would have left A silently un-shared.
  ///
  /// Does NOT touch [peerService] while the feature has never been switched
  /// on, so an operator who does not use this never constructs it and never
  /// binds a socket. [_peerSyncTouched] latches once it has, so turning the
  /// switch back OFF still reaches the service to tear everything down.
  void updatePeerSharing() {
    // The experiment gate sits here rather than only on the settings panel:
    // this is the ONE path that starts discovery, binds a socket or opens a
    // link, so gating it means an install without the experiment is not
    // merely missing the UI — it is not on the network at all.
    final wanted =
        settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ && settings.peerSyncEnabled;
    // [_peerSyncTouched] latches so turning the experiment (or the switch)
    // back OFF still reaches the service to tear everything down, while an
    // install that never turned it on never constructs it at all.
    if (!wanted && !_peerSyncTouched) return;
    _peerSyncTouched = true;
    final front = _operationStack.isEmpty ? null : _operationStack.last.uuid;
    // Re-read every time: the name is editable and callsign-derived, so a
    // value captured once at construction goes stale on a rename or on the
    // first callsign the operator sets.
    peerService.localDeviceName = settings.peerDeviceName;
    // A hint for the Peers panel, and deliberately not what the picker
    // reads: it crosses once per session and names no radio, while
    // `catOffer` is live and does. Configuration rather than link state for
    // exactly that reason — read once at hello, "a rig is connected right
    // now" would say whatever happened to be true the moment the pair formed
    // and never correct itself.
    peerService.localCapabilities = () => [
          if (cat.nodes.any((node) => cat.typeFor(node)?.category == kCategoryTransceiver)) 'cat',
        ];
    peerService.localAccountTag = () => peerAccountTag(settings);
    // A peer link is expected to come and go — a device carried out of
    // range, a park with no WiFi — so both edges are news the operator can
    // act on, and neither is an error. Keyed per device so two peers do not
    // overwrite each other's message, and both self-dismiss: the footer is
    // where the operator glances, not something they should have to tidy.
    peerService.onPeerConnectionChanged = (deviceId, deviceName, {required connected}) {
      statusBar.setMessage(
        key: 'peer:$deviceId',
        icon: connected ? 'lan-connect' : 'lan-disconnect',
        text: connected ? t.settings.peers.statusConnected(device: deviceName) : t.settings.peers.statusLost(device: deviceName),
        dismissAfter: StatusBarService.completedDismissDelay,
      );
    };
    // Touched for its side effect: the lazy field's construction is what
    // wires the ephemeral channel, and a session established before that
    // would drop its GPS snapshot into an unplugged callback.
    peerChannels;
    unawaited(peerService.setEnabled(wanted));
    unawaited(peerService.setBleEnabled(settings.peerBleEnabled));
    unawaited(peerService.setOpenOperation(front));

    // Screen sharing (HALO-369) rides on top of peer sharing: with no
    // session there is nothing to carry an offer, so it ends whenever peer
    // sharing does. Its gate sits HERE for the same reason p2p's does —
    // this is the one path that can leave a capture running, and an install
    // without the experiment must not hold a Screen Recording grant open.
    // The latch mirrors [_peerSyncTouched]: once the feature has been wanted
    // it stays reachable to be torn down. It does NOT keep [peerScreens]
    // unconstructed — the router builds it whenever the experiment is on,
    // and so does opening the Peers panel; the experiment is what gates the
    // native channel, not this.
    final wantsScreens =
        wanted && settings.experimentEnabled('remote') /* stored key, see experiments.yaml */ && settings.peerScreenShareEnabled;
    if (wantsScreens || _peerScreensTouched) {
      _peerScreensTouched = true;
      if (wantsScreens) {
        // Nothing else populates the OS source list, and what this device
        // OFFERS is that list intersected with what the operator picked — so
        // without this a relaunch announces nothing at all, however many
        // sources are still ticked, until someone opens the settings panel.
        unawaited(peerScreens.ensureSourcesFresh());
      } else {
        unawaited(peerScreens.stopAll());
      }
    }

    // With sharing off there is no block for this device and nothing true
    // left to say about anyone else's: every draft held was read against an
    // operation this device is no longer in. Reached through the same latch,
    // so switching OFF still tears down what switching on built.
    if (!wanted && settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */) {
      peerDrafts.clearLocal();
      // And the numbers held: the panel stops asking this source the moment
      // sharing is off, so nothing else would ever let them go.
      serialClaims.releaseAll();
    }
  }

  bool _peerSyncTouched = false;
  bool _peerScreensTouched = false;

  /// Attaches (or detaches) a logging panel's dispatcher to the innermost open
  /// entry for [uuid]. Looked up rather than passed down so the logging panel
  /// needs nothing new beyond the services and operation it already has.
  void setCommandDispatchFor(String uuid, CommandActionsDispatcher? dispatch) {
    for (final entry in _operationStack.reversed) {
      if (entry.uuid == uuid) {
        entry.dispatch = dispatch;
        return;
      }
    }
  }

  /// Fires on DEVSPLASH (`handleCommandAction`'s `devSplash` case) —
  /// `_ReleaseOverlayGateState` listens for this to force-show the release
  /// overlay on demand, bypassing its normal once-per-version gate.
  final DevOverlayTrigger devSplashTrigger = DevOverlayTrigger();

  /// DEVONBOARD's counterpart: `_OnboardingGateState` listens for this to
  /// force-show the onboarding overlay, bypassing its callsign-undefined
  /// gate.
  final DevOverlayTrigger devOnboardTrigger = DevOverlayTrigger();

  /// DEVTESTER: `_TesterOverlayGateState` listens for this to force-show the
  /// tester overlay, bypassing its edition and last-seen-build gates.
  final DevOverlayTrigger devTesterTrigger = DevOverlayTrigger();

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
    onError: ErrorReportingService.report,
    onAuthError: _showSyncAuthNotice,
    // Sync doubles as the app's connectivity probe: it is the one request the
    // app makes on its own schedule whatever else is suspended, and its
    // success is what declares us back online. It is also the one
    // subsystem NOT suspended while offline, for the same reason — everything
    // else is waiting on it.
    onReachability: (reached) {
      ConnectivityService.reportProbe(reached: reached);
      ConnectivityService.reportService('sync', label: t.offline.syncService, reached: reached);
    },
    onProbeStopped: ConnectivityService.stopProbing,
    isTransportFailure: ErrorPolicy.isTransportFailure,
  );

  /// Status-bar item key for backfill progress; the Sync settings panel
  /// renders the same item inline (see `settings_view.dart`).
  static const syncProgressStatusKey = 'sync_backfill_progress';

  /// Stable key so a later rejection replaces rather than stacks, and a
  /// round that finally succeeds can clear it.
  static const syncAuthNoticeKey = 'sync:auth';

  /// The server has rejected this device's registration for several rounds
  /// running (SyncEngine's [SyncEngine.authErrorNotifyThreshold]) — not a
  /// transient blip, so it's worth surfacing. The likely fix is on the
  /// user's end (e.g. the callsign on file no longer matches the server's
  /// expected format), so the action opens Sync settings directly rather
  /// than just naming the problem.
  void _showSyncAuthNotice(String message, {int? status}) {
    statusBar.showNotice(
      key: syncAuthNoticeKey,
      icon: 'cloud-off',
      title: t.settings.syncPanel.authIssueTitle,
      text: t.settings.syncPanel.authIssueText,
      actions: [
        StatusBarAction(
          label: t.settings.syncPanel.openSettings,
          onTap: () => navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => SettingsView(services: this, initialPanel: 'sync')),
          ),
        ),
      ],
    );
  }

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
      title: 'Syncing in progress…',
      text: qsoTotal > 0
          ? '${formatNumber(qsoDone)} of ${formatNumber(qsoTotal)} QSOs'
          : '${formatNumber(done)} of ${formatNumber(total)} records',
      value: done / total,
    );
  }

  /// How long DEVHAMMER churns for when the command doesn't say.
  static const _statusBarHammerDefaultSeconds = 15;

  /// Set while a run is in flight, so a second DEVHAMMER doesn't interleave
  /// with the first — two runs share the same four keys, and the first to
  /// finish would clear the other's items out from under it.
  bool _hammering = false;

  /// Reproduces a data-file sync's churn on demand (DEVHAMMER): several items
  /// appearing, ticking and clearing, the way `DataFileManager` does one
  /// entry per file.
  ///
  /// This exists because that churn is what provokes the web engine into
  /// blurring the focused text field (see `ViewFocusGuard`), and the real
  /// thing only happens on a cold profile — once the files are cached a
  /// RELOAD finishes without churning at all, so there is nothing left to
  /// test a fix against. What matters is items COMING AND GOING: a single
  /// progress bar ticking on a stable key changes a label and provokes
  /// nothing.
  ///
  /// Returns false when a run is already in flight, so the caller can say so
  /// rather than echo a confirmation over nothing happening.
  Future<bool> _hammerStatusBar(int seconds) async {
    if (_hammering) return false;
    _hammering = true;
    try {
      // A beat before the first item, deliberately: the interesting case is
      // typing INTO the churn, and without this the tester is still reaching
      // for the keyboard while it runs.
      await Future<void>.delayed(const Duration(seconds: 1));
      const slots = 4;
      const tick = Duration(milliseconds: 120);
      // Real time: DEVHAMMER's point is to churn the UI for that many real
      // seconds while a tester types into it.
      final until = realNowUtc().add(Duration(seconds: seconds));
      var step = 0;
      while (realNowUtc().isBefore(until)) {
        final slot = step % slots;
        statusBar.setProgress(
          key: _hammerKey(slot),
          icon: 'progress-download',
          title: 'Hammer $slot',
          text: 'file $step',
          value: (step % 10) / 10,
        );
        // Retire a DIFFERENT slot: the one written two ticks ago, so frames
        // have gone by between its last write and its removal. Clearing the
        // slot just set, in the same breath and with no frame between, only
        // undoes the write — no item ever appears, so none ever leaves, and
        // leaving is the half that provokes anything. Offsetting by two also
        // takes every slot in turn; keying the clear off `step % 10` reached
        // only the odd ones.
        if (step >= slots) statusBar.clear(_hammerKey((slot + 2) % slots));
        step++;
        await Future<void>.delayed(tick);
      }
      for (var slot = 0; slot < slots; slot++) {
        statusBar.clear(_hammerKey(slot));
      }
      return true;
    } finally {
      _hammering = false;
    }
  }

  static String _hammerKey(int slot) => 'command:devHammer:$slot';

  HaLoServices(
    this.db,
    this.settings, {
    ExtensionService? extensions,
    MetricsService? metrics,
    PurchaseService? purchases,
    UpdateService? updates,
    UpdateCheckService? updateCheck,
    DataFileManager? dataFiles,
    LookupQueueService? lookupQueue,
    ExportService? exports,
    CatService? cat,
    PusherService? pusher,
    LocationService? location,
    InboundQsoListenerService? inboundQsos,
    PeerService? peerService,
    DeepLinkService? deepLinks,
  })  : _catOverride = cat,
        _deepLinksOverride = deepLinks,
        _peerServiceOverride = peerService,
        _inboundQsosOverride = inboundQsos,
        _locationOverride = location,
        _pusherOverride = pusher,
        extensions = extensions ?? ExtensionService(),
        metrics = metrics ?? const NoopMetricsService(),
        purchases = purchases ?? const NoopPurchaseService(),
        // Defaults to no-op so tests (which construct HaLoServices directly)
        // never touch the Shorebird FFI; bootstrap() injects the real
        // ShorebirdUpdateService for the running app.
        updates = updates ?? const NoopUpdateService(),
        // Defaults to the web-only build-SHA check; app_dist's main_dist.dart
        // injects a real Shorebird+Sparkle-aware implementation (see
        // update_check_service.dart).
        updateCheck = updateCheck ?? const WebFreshnessUpdateCheckService(),
        _dataFilesOverride = dataFiles,
        _lookupQueueOverride = lookupQueue,
        // A widget test of the Exports panel can't use the real one: its
        // option listing awaits a drift stream's `.first`, which never
        // resolves under `testWidgets` (see operation_export_panel_test).
        _exportsOverride = exports {
    this.extensions.settings = settings;
    this.extensions.lookups = lookups;
    this.extensions.statusBar = statusBar;
    this.extensions.operations = operations;
    this.extensions.qsos = qsos;
    // `this.` is load-bearing: the constructor's `location` parameter is the
    // OVERRIDE, null in every production build, and shadows the field here.
    this.extensions.location = this.location;
    this.extensions.spots = spots;
    this.extensions.onOpenAccount =
        (key, {subkey}) => unawaited(showAccountDialogByKey(this, key, subkey: subkey));
    this.extensions.onSearchSettings = (args, kind) => searchSettingsForCommand(this, args: args, kind: kind);
    // Time travel is developer-mode-only, and this is the ONE place that can
    // see developer mode go off no matter which surface turned it off (DEVMODE,
    // the Settings toggle, a settings command). Leaving the clock travelled
    // after it goes off would strand a non-developer app on a fake clock with
    // no visible way back.
    settings.addListener(_enforceTimeTravelGate);
    // Same reasoning, and the same one place: a Number Formatting change can
    // arrive from the Settings picker or from a settings command, and every
    // package reads the answer out of one process-wide singleton. Applied
    // here at construction too, so the very first frame formats correctly
    // rather than repainting once the listener happens to fire.
    //
    // The listener is enough on its own: a settings listener only marks the
    // tree dirty, so the rebuild happens on the NEXT frame and the singleton
    // is already updated whichever order the listeners ran in.
    settings.addListener(_applyNumberFormatting);
    _applyNumberFormatting();
  }

  /// Resolves the operator's Number Formatting choice into the two characters
  /// [NumberFormatting] hands to every package.
  ///
  /// Runs at construction and on every settings change. NOT on a device
  /// region change while the app is running — nothing observes
  /// `didChangeLocales`, so under [NumberFormatStyle.locale] that is picked
  /// up at the next launch.
  ///
  /// halo_core is pure Dart and cannot do this itself — it has neither the
  /// device locale nor ICU. The explicit choices are spelled out rather than
  /// looked up: "period" and "comma" ARE definitions, and routing them
  /// through a locale would make them depend on that locale's data being
  /// bundled. Only [NumberFormatStyle.locale] asks intl anything.
  void _applyNumberFormatting() {
    switch (settings.numberFormatStyle) {
      case NumberFormatStyle.period:
        NumberFormatting.instance.configure(decimal: '.', grouping: ',', locale: 'en_US');
      case NumberFormatStyle.comma:
        // de_DE only for intl's benefit — formatNumber groups through it, and
        // grouping is not every three digits everywhere.
        NumberFormatting.instance.configure(decimal: ',', grouping: '.', locale: 'de_DE');
      case NumberFormatStyle.locale:
        final tag = dart_ui.PlatformDispatcher.instance.locale.toString();
        dynamic symbols;
        try {
          symbols = NumberFormat.decimalPattern(tag).symbols;
        } catch (e, stack) {
          // intl has no symbols for this tag — `verifiedLocale` throws rather
          // than degrading, so this branch is reachable on a real device (it
          // ships 313 locales; `mi`, `ceb`, `tt`, `ba`, `sah` are not among
          // them). `catch`, NOT `on Exception`: what it throws is an
          // ArgumentError, which is an Error — an `on Exception` clause here
          // catches nothing at all and the throw escapes the HaLoServices
          // constructor on the way to the first frame.
          //
          // Reported as well as logged. Falling back is the right behaviour
          // (this runs on the way to the first frame, and US conventions beat
          // a crash), but an operator who silently gets the wrong separators
          // has no way to tell that from the setting simply working — and
          // neither would we.
          debugPrint('[numberFormatting] no number symbols for "$tag", using US conventions: $e');
          ErrorReportingService.report(e, stack, context: 'settings:numberFormat:$tag');
        }
        // Outside the try, so its own rejection is never mistaken for a
        // missing locale. A locale that groups with a non-breaking space
        // (fr, ru) keeps it: coercing that to a comma would contradict what
        // the device shows everywhere else.
        final applied = symbols != null &&
            NumberFormatting.instance.configure(
              decimal: symbols.DECIMAL_SEP as String,
              grouping: symbols.GROUP_SEP as String,
              locale: tag,
            );
        if (!applied) {
          NumberFormatting.instance.configure(decimal: '.', grouping: ',', locale: 'en_US');
        }
    }
  }

  StreamSubscription<List<Operation>>? _receivedPurgesSub;

  /// Test Operations purged on another device only tombstone here on
  /// receipt (`OperationsRepository.mergeFromSync`) — this is what turns
  /// that into an actual prompt to remove them for real, once the operator
  /// says so. Reactive rather than tied to a specific sync callback: it
  /// fires on the app's own boot (a leftover from before this device was
  /// last open) just as readily as on a live sync round.
  ///
  /// NOT started from the constructor: a `HaLoServices` built for a widget
  /// test never calls this, same as `syncEngine.start()` — a live drift
  /// stream subscription that outlives the test's `pumpAndSettle` is exactly
  /// the trap `operation_export_panel_test.dart`'s own doc comment warns
  /// about, and this app-wide watch would otherwise hang every single test
  /// that constructs `HaLoServices`, not just the one that needs a real
  /// stream. The real app calls this once, from `bootstrap()`, alongside
  /// `syncEngine.start()`.
  void watchReceivedTestOperationPurges() {
    _receivedPurgesSub ??= operations.watchReceivedPurgesPending().listen(_onReceivedPurgesPending);
  }

  static const _receivedPurgesNoticeKey = 'testOperations:receivedPurges';

  /// The uuid set the notice currently reflects, so a `watch()` re-emission
  /// with the SAME pending operations (any unrelated write to `operations`
  /// re-fires the stream, not just a change to this query's result) doesn't
  /// re-show the notice and silently undo an operator's dismissal of it.
  Set<String> _lastReceivedPurgesShown = const {};

  void _onReceivedPurgesPending(List<Operation> pending) {
    final uuids = pending.map((op) => op.uuid).toSet();
    if (uuids.isEmpty) {
      _lastReceivedPurgesShown = const {};
      statusBar.dismissNotice(_receivedPurgesNoticeKey);
      return;
    }
    if (setEquals(uuids, _lastReceivedPurgesShown)) return;
    _lastReceivedPurgesShown = uuids;
    statusBar.showNotice(
      key: _receivedPurgesNoticeKey,
      icon: 'flask-outline',
      text: t.commands.receivedPurgesPending(count: pending.length),
      // Not persisted: `StatusBarNotice.persist`'s own doc says why — its
      // actions can't survive a restart, so a persisted copy would come
      // back forever as a dead husk with no working Review button once
      // this session ends.
      persist: false,
      actions: [
        StatusBarAction(
          label: t.commands.receivedPurgesReview,
          onTap: () => _confirmReceivedPurgesFromNotice(pending),
        ),
      ],
    );
  }

  /// `pending` is a snapshot from when the notice was built; the dialog
  /// itself only asks the operator, and `confirmReceivedTestOperationPurges`
  /// re-validates every uuid against the database before deleting anything
  /// — see its own doc for why that matters (the callsign-edit escape
  /// hatch racing this).
  void _confirmReceivedPurgesFromNotice(List<Operation> pending) {
    statusBar.dismissNotice(_receivedPurgesNoticeKey);
    final context = navigatorKey.currentContext;
    if (context == null) {
      // Only reachable by tapping the status-bar action with no navigator up
      // at all — logged so "I tapped Review and nothing happened" has a
      // trail, matching `_openConfirmDevicePane`'s treatment of the same gap.
      debugPrint('[testOperations] receivedPurges review dropped: no navigator context');
      return;
    }
    // Nothing below this line has run yet, so re-showing here is always
    // correct: `pending` is exactly what's still on the database whenever
    // this fires before a genuine removal.
    void reArmNotice() {
      _lastReceivedPurgesShown = const {};
      _onReceivedPurgesPending(pending);
    }

    unawaited(confirmReceivedTestOperationPurgesDialog(context, pending).then((confirmed) async {
      if (confirmed != true) {
        // The dismiss above already ran; without this, cancelling — the
        // common case, an operator tapping Review to look and backing out —
        // leaves the notice gone for the rest of the session, same as an
        // unhandled throw would.
        reArmNotice();
        return;
      }
      try {
        final result = await confirmReceivedTestOperationPurges(pending.map((op) => op.uuid));
        // Against `eligible`, not `pending.length`: some of `pending` can be
        // legitimately gone already (the callsign-edit escape hatch fired
        // between listing and confirming) without anything having failed.
        final text = result.removed == result.eligible
            ? t.commands.testOperationsPurged(count: result.removed)
            : t.commands.receivedPurgesSomeFailed(removed: result.removed, total: result.eligible);
        statusBar.setMessage(key: 'commandAction', text: text);
      } catch (e, st) {
        // `eligibleReceivedPurges` itself failing (not one of the per-uuid
        // deletes, which `confirmReceivedTestOperationPurges` already
        // isolates) — nothing was removed, so `pending` is still exactly
        // accurate.
        ErrorReportingService.report(e, st, context: 'confirmReceivedPurgesFromNotice');
        reArmNotice();
        statusBar.setMessage(key: 'commandAction', text: t.commands.receivedPurgesFailed);
      }
    }));
  }

  void _enforceTimeTravelGate() {
    if (!AppClock.instance.isTravelling || settings.developerMode) return;
    // Said out loud: every clock, QSO default and spot age in the app jumps, and
    // the only visible cause is a developer-mode toggle several screens away.
    final was = AppClock.instance.travelLabel;
    statusBar.showNotice(
      key: 'clock:timeTravelEnded',
      icon: 'clock-check',
      title: 'Back to real time',
      text: 'Leaving developer mode ended time travel${was == null ? '' : ' ($was)'}.',
      persist: false,
    );
    // Guarded, not bare `unawaited`: the clock is reset FIRST inside, so a throw
    // later in the sequence (the status item, the heartbeat, restarting sync)
    // would otherwise surface only as an unhandled async error and leave the
    // chip on screen over a clock that is no longer travelling.
    unawaited(_endTimeTravel().catchError((Object e, StackTrace stack) {
      ErrorReportingService.report(e, stack, context: 'clock:end-time-travel');
    }));
  }

  /// The ONE gate for analytics: forwards to
  /// [metrics] only while the user's "Share app usage data" consent is on.
  /// Every instrumentation site calls this — never metrics.logEvent
  /// directly — so consent is checked live at each event, and turning the
  /// setting off silences tracking immediately. Event names and property
  /// keys follow app-polo's set (docs/design/telemetry.md).
  void track(String event, [Map<String, Object?> properties = const {}]) {
    if (!settings.consentAppData) return;
    metrics.logEvent(event, properties: properties);
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
      // Independent of QSO sync being enabled — see connectLofiRealtime's
      // doc comment. Not awaited, same reasoning as the flags
      // refresh below.
      unawaited(connectLofiRealtime());
    }
    // Flags are callsign-specific — refresh them (a no-op if the callsign
    // didn't actually change). Not awaited: the callsign edit shouldn't block
    // on a network round-trip.
    unawaited(flags.refreshForCall(settings.activeProfile.operatorCall));
  }

  /// The status bar's key for the time-travel indicator — public so the widget
  /// test can find the item rather than matching on its text.
  static const timeTravelStatusKey = 'clock:timeTravel';

  /// A run in flight. DEVBENCH yields to the event loop on every contact, so
  /// the palette stays usable and a second run can be started on top of the
  /// first — two Test Operations interleaving their inserts and rescores
  /// through one database, each timing the other's load, which corrupts the
  /// slope this tool exists to report. They also share the `devbench` status
  /// key, so whichever finishes first clears the other's progress. DEVHAMMER
  /// guards the same way for the same reason.
  bool _benchmarking = false;

  /// How often the DEVBENCH progress bar advances, in contacts. The bench runs
  /// on the UI isolate, so every repaint is time the run is not measuring the
  /// thing it exists to measure — and at the default 100-QSO size a per-contact
  /// bar would be pure overhead for a run that finishes in a second anyway.
  static const _benchProgressEvery = 100;

  /// DEVBENCH: log a synthetic contest into a throwaway Test Operation and
  /// report what each phase cost as the log grew (HALO-119).
  ///
  /// The developer-mode gate is re-checked here rather than trusted from the
  /// command hook. The hook's own check keeps the command from existing for an
  /// ordinary operator, but this writes thousands of contacts and purges an
  /// operation, and a gate that matters does not live only in the sandbox —
  /// the same reasoning as [_travelTime]'s.
  Future<CommandActionOutcome?> _runContestBench(Map<String, dynamic>? params) async {
    if (!settings.developerMode) {
      return (text: 'DEVBENCH needs developer mode', failed: true);
    }
    if (_benchmarking) return (text: 'A benchmark is already running', failed: true);

    // Read defensively and BEFORE the flag is raised. A command action is raw
    // JSON from any hook, template or third-party extension — the SDK's
    // `qsoCount?: number` is a compile-time claim, not a runtime one — so a
    // string here would throw a cast error, and anything that throws between
    // raising the flag and entering the try leaves it raised for the session,
    // refusing every later run.
    //
    // Clamped rather than trusted for the same reason: a zero would run no
    // contacts, close no bands, and hand the report an "expected growth" of
    // -1.0x, nonsense carrying the confidence of a measurement.
    final requested = params?['qsoCount'];
    final qsoCount = (requested is num ? requested.toInt() : 100).clamp(1, 20000);

    _benchmarking = true;

    // A determinate bar from the start: a run of a few thousand contacts takes
    // long enough that an operator with no feedback has no way to tell it from
    // a hang. Updated every `_benchProgressEvery` contacts rather than every
    // one — repainting the bar per contact would have the bench measuring the
    // repaints as much as the work.
    statusBar.setProgress(
      key: 'devbench',
      icon: 'speedometer',
      title: 'Benchmarking',
      text: '0 of $qsoCount QSOs',
      value: 0,
    );
    try {
      final result = await runContestBench(
        qsos: qsos,
        operations: operations,
        extensions: extensions,
        scoring: scoring,
        qsoCount: qsoCount,
        purge: purgeOperation,
        onProgress: (done, total) {
          if (done % _benchProgressEvery != 0 && done != total) return;
          statusBar.setProgress(
            key: 'devbench',
            icon: 'speedometer',
            title: 'Benchmarking',
            text: '$done of $total QSOs',
            value: done / total,
          );
        },
      );

      // On screen: the notice card renders markdown tables, so the operator
      // gets the shape rather than a number they would have to trust. Not
      // persisted, because the copy action is the point and an action cannot
      // survive into notice history.
      statusBar.showNotice(
        key: 'devbench:result',
        icon: 'speedometer',
        title: 'Benchmark: $qsoCount QSOs',
        text: result.markdownSummary,
        persist: false,
        actions: [
          StatusBarAction(
            label: 'Copy details',
            onTap: () => unawaited(Clipboard.setData(ClipboardData(text: result.plainReport))),
          ),
        ],
      );

      // And a copy off the device, so a slow phone's numbers can be read
      // without the phone. Not an exception: nothing went wrong, and the
      // reporting backend keeps this out of the crash stream.
      final uploaded = ErrorReportingService.diagnostic(title: 'DEVBENCH', body: result.plainReport);

      // A build with no reporting backend keeps the numbers on the device, and
      // an operator told nothing would reasonably believe they are retrievable
      // from it. DEVSENTRY draws the same distinction.
      //
      // It cannot promise the upload LANDED. The Sentry backend fires its
      // capture unawaited, so `uploaded` only catches a backend that throws
      // synchronously, and `reportingEnabled` stays true even when that
      // backend's own init failed. Copy details is the answer to both, which
      // is why the notice carries it.
      final sent = uploaded && ErrorReportingService.reportingEnabled ? '' : ' (local only)';
      return (text: '${result.headline}$sent', failed: false);
    } on BenchCleanupFailed catch (error, stackTrace) {
      // The one outcome that leaves the log dirty, so it says so instead of
      // being reported as an ordinary failure.
      ErrorReportingService.report(error, stackTrace, context: 'devbench:cleanup');
      return (
        text: 'Benchmark left its test operation behind — run PURGETESTS to remove it',
        failed: true,
      );
    } on BenchNotConfigured catch (error) {
      // The operator's to fix, so it is NOT reported: an unconfigured run is
      // not a defect, and uploading it would put it in the crash stream.
      return (text: '$error', failed: true);
    } catch (error, stackTrace) {
      ErrorReportingService.report(error, stackTrace, context: 'devbench');
      return (text: 'Benchmark failed: $error', failed: true);
    } finally {
      _benchmarking = false;
      statusBar.clear('devbench');
    }
  }

  /// DEVTT: moves the app clock (docs/design/time.md).
  ///
  /// Both gates live here rather than in the command hook, because neither the
  /// sync account nor developer mode is visible from inside the extension
  /// sandbox — and because the sync account gate is the one thing in this
  /// feature that protects real user data, so it belongs where it cannot be
  /// bypassed by a different caller of the action.
  Future<CommandActionOutcome?> _travelTime(Map<String, dynamic>? params) async {
    if (params?['reset'] == true) {
      if (!AppClock.instance.isTravelling) return (text: 'The clock is already on real time', failed: false);
      await _endTimeTravel();
      return (text: 'Back to real time', failed: false);
    }

    if (!settings.developerMode) {
      return (text: 'Time travel needs developer mode', failed: true);
    }

    // Deliberately no sync-account gate: what the account is called says
    // nothing about what this session can damage, because `WritePolicy` admits
    // only test data while the clock is travelled. Keying on the account would
    // also mean reading `syncState['accountData']`, a cache refreshed only when
    // the operator opens Settings › Sync — a check that fails closed on absence
    // but open on staleness, which is the wrong way round for anything standing
    // between a dev tool and somebody's real log.

    // Applied BEFORE anything is changed on its behalf: `travel` refuses an
    // out-of-range offset or speed, and a refusal that had already switched
    // something off would leave that thing off with no travel to undo.
    final deltaMillis = (params?['deltaMillis'] as num?)?.toInt() ?? 0;
    final speed = (params?['speed'] as num?)?.toDouble();
    ClockListenerException? notFollowed;
    try {
      AppClock.instance.travel(delta: Duration(milliseconds: deltaMillis), speed: speed);
    } on ArgumentError catch (e) {
      // Validation, which runs before any mutation: nothing moved.
      return (text: 'Time travel refused: ${e.message}', failed: true);
    } on ClockListenerException catch (e, stack) {
      // A listener threw (the sandbox push, the UI heartbeat). The clock HAS
      // moved — so everything below still has to happen, most of all the status
      // indicator: a travelled clock nobody can see is the one failure
      // docs/design/time.md §4 says must not be possible. Only the report at the
      // end differs.
      ErrorReportingService.report(e.cause, stack, context: 'clock:travel-listener');
      notFollowed = e;
    }

    // Nothing to switch off: SyncEngine's own `_mayRun` check now refuses every
    // path while the clock is travelled, including a round already on a timer.

    // Subscribing here rather than at construction: WallClock arms no timer
    // until something listens, so an app that never travels pays nothing.
    if (!_travelStatusTicking) {
      _travelStatusTicking = true;
      WallClock.seconds.addListener(_refreshTimeTravelStatus);
    }
    _refreshTimeTravelStatus();
    final now = 'Clock now ${_utcStamp(nowUtc())}${_travelSuffix()}';
    if (notFollowed != null) {
      return (text: '$now — but ${notFollowed.cause}', failed: true);
    }
    return (text: now, failed: false);
  }

  bool _travelStatusTicking = false;

  /// What the status item last said, so an unchanged label costs nothing.
  String? _travelStatusText;

  /// Keeps the status-bar item showing how far the clock is from real time and
  /// how fast it is running.
  ///
  /// Re-read once per second rather than posted once, because the offset GROWS:
  /// `DEVTT 100x` sets no offset at all, and a snapshot would sit at "at 100x"
  /// for the whole session while the clock ran days ahead. Posting only on a
  /// CHANGE is what keeps that affordable — every post notifies the whole
  /// status bar, and at 1x with a fixed offset the label never changes, so an
  /// ordinary travelled session is silent after the first one.
  void _refreshTimeTravelStatus() {
    final label = AppClock.instance.liveTravelLabel;
    if (label == _travelStatusText) return;
    _travelStatusText = label;
    if (label == null) {
      statusBar.clear(timeTravelStatusKey);
      return;
    }
    statusBar.setMessage(
      key: timeTravelStatusKey,
      icon: 'clock-fast',
      // Everything in the TITLE, with no separate `text`. The collapsed footer
      // — the always-visible one — renders `title ?? text`, so a title of
      // "Time travel" with the offset in `text` reads as a bare "Time travel"
      // until someone expands the bar, which is the one place this item must not
      // need. Phrased to read as one line: "Time travel +5m at 100x",
      // "Time travel at 100x", "Time travel +2h".
      title: 'Time travel $label',
    );
  }

  /// Returns to real time and undoes everything travel imposed.
  Future<void> _endTimeTravel() async {
    try {
      AppClock.instance.reset();
    } on ClockListenerException catch (e, stack) {
      // The clock IS back on real time — reset mutates before notifying — so
      // everything below still has to run, exactly as on the travel path. Left
      // to propagate, it would strand the status item on screen over an
      // untravelled clock and never restart sync.
      ErrorReportingService.report(e.cause, stack, context: 'clock:end-travel-listener');
    }
    if (_travelStatusTicking) {
      _travelStatusTicking = false;
      WallClock.seconds.removeListener(_refreshTimeTravelStatus);
    }
    _travelStatusText = null;
    statusBar.clear(timeTravelStatusKey);
    // The engine stopped rescheduling itself while travelling, so nothing would
    // pick it up again on its own.
    syncEngine.start();
    watchReceivedTestOperationPurges();
  }

  String _travelSuffix() {
    final label = AppClock.instance.travelLabel;
    return label == null ? '' : ' ($label)';
  }

  /// `2026-08-11 14:03z` — a UTC stamp to the minute, which is the precision a
  /// logger's operator thinks in.
  static String _utcStamp(DateTime utc) => '${utc.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}z';

  /// Returns false when the request was REFUSED — callers must not report or
  /// record a change that did not happen (see `_toggleSync`, which would
  /// otherwise fire a `sync_enabled` analytics event and install an account
  /// watcher for a sync that is off).
  Future<bool> setSyncEnabled(bool enabled) async {
    await settings.setSyncEnabled(enabled);
    if (!enabled) return true;
    // Boot skips credential setup when the keyring is locked
    // (ensureSyncDeviceKey returns null), so starting the engine now without a
    // device key would run sync unauthenticated. If boot never established the
    // key, re-attempt here (a null result isn't cached, so this retries secure
    // storage) and only start once we actually have credentials.
    if (settings.syncDeviceKey == null) {
      final deviceKey = await settings.ensureSyncDeviceKey();
      if (deviceKey == null) {
        debugPrint('[sync] enabled but secure storage is unavailable — not starting sync');
        // The SETTING is on (written above, and the no-keyring banner explains
        // itself); only the engine could not start. Not a refusal.
        return true;
      }
      await extensions.setSyncCredentials(
        deviceKey: deviceKey,
        operatorCall: settings.activeProfile.operatorCall,
      );
      unawaited(connectLofiRealtime());
    }
    syncEngine.start();
    watchReceivedTestOperationPurges();
    return true;
  }

  /// Handles a named command action from the call field — the `dev-commands`
  /// extension's DEVNOTICE/DEVSTATUS/DEVPROGRESS/RELOAD and friends.
  /// (`SYNCALL` and PURGETESTS are intercepted in [runCommandAction] instead:
  /// both must confirm with the operator before doing anything irreversible,
  /// which needs a BuildContext this switch deliberately runs without.)
  /// Returns a message for the caller to show in a SnackBar, or null for
  /// nothing — the dev-command cases return null since their `confirm` text
  /// already shows in the call field, and the status bar item itself is the
  /// visible result.
  Future<CommandActionOutcome?> handleCommandAction(String action, [Map<String, dynamic>? params]) async {
    track('command_executed', {'command': action});
    switch (action) {
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
              text: t.commands.noDataFilesMatched(target: target),
              value: 1.0,
            );
          }
        }).catchError((e) {
          // Belt-and-suspenders: syncAllDataFiles already isolates each data
          // file's own errors, but this still needs to fail loud (not just
          // silently drop the failure) for anything unexpected that slips
          // past that per-entry try/catch.
          debugPrint('[data-file] reloadDataFiles failed: $e');
          statusBar.setProgress(key: 'command:reloadDataFiles', text: t.commands.reloadFailed(error: e), value: 1.0);
        }));
        return (
          text: target == 'ALL' ? t.commands.reloadingAll : t.commands.reloadingTarget(target: target),
          failed: false,
        );
      case 'devNotice':
        final p = params ?? const {};
        final devNoticeKey = p['key'] as String? ??
            // Real: a uniqueness token, and a clock moved BACKWARD can hand back
            // an instant already used — replacing an unrelated notice instead of
            // adding one, from the command whose job is testing notices.
            'devNotice-${realNowUtc().microsecondsSinceEpoch}';
        statusBar.showNotice(
          key: 'command:devNotice:$devNoticeKey',
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
      case 'devHammer':
        // Normally no text of our own — the extension's `confirm` says it, in
        // English, like every other dev command's (dev-commands carries no
        // i18n). The exception is a run already in flight: the confirmation is
        // printed before this returns, so staying quiet would tell the tester
        // it is hammering while nothing happens — and a tester who sees no
        // churn concludes the churn stopped provoking the bug.
        if (_hammering) return (text: 'DEVHAMMER is already running', failed: true);
        unawaited(_hammerStatusBar((params?['seconds'] as num?)?.toInt() ?? _statusBarHammerDefaultSeconds));
        return null;
      case 'devSplash':
        devSplashTrigger.trigger();
        return null;
      case 'devOnboard':
        devOnboardTrigger.trigger();
        return null;
      case 'devTester':
        devTesterTrigger.trigger();
        return null;
      case 'devTimeTravel':
        return _travelTime(params);
      case 'devPopup':
        if (!kIsWeb) return (text: 'DEVPOPUP is web-only', failed: true);
        return openPopupWindow()
            ? (text: 'Opened in a standalone window', failed: false)
            : (text: 'Popup blocked — allow popups for this site', failed: true);
      case 'devSentry':
        // DEVSENTRY [message]: push a synthetic error through the real
        // reporting pipeline to verify the Sentry wiring end to end.
        // Deliberately report(), not throw — the point is testing upload
        // + feedback, not exercising the error UI (DEVNOTICE covers that).
        final message = (params?['message'] as String? ?? 'test message').trim();
        ErrorReportingService.report(
          StateError('DEVSENTRY: $message'),
          StackTrace.current,
          context: 'devsentry',
        );
        return (
          text: ErrorReportingService.reportingEnabled ? t.commands.sentryTestSent : t.commands.sentryTestLocalOnly,
          failed: false,
        );
      case 'devBench':
        return _runContestBench(params);
      case 'sendSpots':
        return _sendSpot(params ?? const {});
      case 'toggleExperiment':
        // EXP <key-or-alias>: the command hook only parsed; resolving the
        // token against the catalog and flipping the stored state happens
        // here, and the returned message is the user's only feedback.
        final token = (params?['token'] as String? ?? '').trim();
        if (token.isEmpty) return null;
        final experiment = findExperiment(await loadExperiments(), token);
        if (experiment == null) {
          return (text: t.commands.unknownExperiment(token: token.toUpperCase()), failed: true);
        }
        final enabled = !settings.experimentEnabled(experiment.key);
        await settings.setExperimentEnabled(experiment.key, enabled);
        // The availability pass may restart the extension runtime (an
        // experiment revealing or hiding gated extensions) — don't hold
        // the command's feedback on it.
        unawaited(extensions.applyExtensionAvailability());
        return (
          text: enabled
              ? t.commands.experimentEnabled(name: experiment.name)
              : t.commands.experimentDisabled(name: experiment.name),
          failed: false,
        );
      case 'updateSetting':
        // SET/SHOW/HIDE: the hook already resolved the key and coerced the
        // value through `searchSettings`, so this only writes. Returns null on
        // success — the hook's own `confirm` is the user's feedback; a message
        // here would be a second one saying the same thing. A non-null return
        // is therefore always a failure the hook couldn't have known about
        // (an extension field's validator rejecting the value).
        final settingKey = params?['key'] as String?;
        if (settingKey == null || settingKey.isEmpty) return null;
        final rejected = await applySettingCommand(this, key: settingKey, value: params?['value']);
        return rejected == null ? null : (text: rejected, failed: true);
      case 'updateOperation':
        return _updateOperation(params ?? const {});
      case 'markSegment':
        return _markSegment(params ?? const {});
      case 'setPower':
        // POWER command (e.g. "5W" typed into the call field): the same
        // write the Station Configuration Power field and the Power logging
        // control make — the app's VFO, which CAT forwards to radio1's
        // session if one is connected. Returns null on success for the same
        // reason as updateSetting: the hook's own confirm already told the
        // operator.
        final watts = params?['watts'] as num?;
        if (watts == null) return null;
        radio.setVfo('vfoA', power: watts);
        return null;
      case 'setKeyerSpeed':
        // WPM command ("20WPM"): straight to radio1's keyer. Unlike power
        // there is no app-side value to fall back on — the speed is the
        // radio's — so with nothing connected that can key, the command
        // fails out loud rather than confirming a change nothing heard.
        final wpm = params?['wpm'];
        if (wpm is! num) return null;
        // The hooks decline while the experiment is off, but an action can
        // still arrive — an interpretation computed before the flip, or an
        // extension of its own — and must not reach the radio quietly.
        if (!settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */) {
          return (text: t.commands.keyerExperimentOff, failed: true);
        }
        return cat.setKeyerSpeed(wpm.round()) ? null : (text: t.commands.noCwKeyer, failed: true);
      case 'showKeyer':
        // KEYER / MACROS: the keyer area listens for this. With the
        // experiment off no area is mounted to hear it; with nothing that can
        // key there is nothing for it to do — say so rather than confirm.
        if (!settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */) {
          return (text: t.commands.keyerExperimentOff, failed: true);
        }
        if (!cat.canKeyCw && !cat.canPlayVoice) return (text: t.commands.noKeyer, failed: true);
        // The area lives in an operation's logging panel; from Home there is
        // nothing to show, and confirming would be a lie.
        if (currentOperationContext == null) return (text: t.commands.keyerNeedsOperation, failed: true);
        cat.showKeyerArea();
        return null;
      case 'openSettings':
        // The setting can't be typed on one line (multiselect, account,
        // secret), the operator named it without a value, or the query
        // matched several equally well — all three want the settings form
        // rather than a guess.
        final context = navigatorKey.currentContext;
        if (context == null) return null;
        final keys = (params?['keys'] as List?)?.whereType<String>().toList() ?? const <String>[];
        if (keys.isEmpty) return null;
        unawaited(showSettingsForKeys(
          context,
          services: this,
          keys: keys,
          title: params?['title'] as String? ?? t.settings.title,
        ));
        return null;
      default:
        return null;
    }
  }

  /// OPER / POSITION: writes one edit to the open operation. The hook parsed
  /// the text and its own `confirm` already told the operator what is
  /// happening, so success returns null, exactly as `updateSetting` does —
  /// a non-null return is a failure the hook could not have known about.
  ///
  /// The two fields deliberately go to different places: the operator
  /// callsign is the operation's own data and syncs with it, while the
  /// position names THIS device and must not (see `spotCallForSelfSpot`).
  Future<CommandActionOutcome?> _updateOperation(Map<String, dynamic> params) async {
    final uuid = asQsonString(params['uuid']) ?? '';
    final operation = uuid.isEmpty ? null : await operations.get(uuid);
    if (operation == null) return (text: t.commands.noOperationOpen, failed: true);

    // The position lands first, and the operator goes into the slot it names.
    // Both writes are guarded on the change — a local_data write rebuilds the
    // Operation View (see the details dialog's own write), and a data write
    // pushes a revision to every other device — and the operator's guard reads
    // the DESTINATION seat, not the one this device is leaving: a command
    // carrying both fields would otherwise compare against the old seat's
    // operator and skip a write the new seat needs.
    // Trimmed and uppercased at the boundary, like the details dialog: this
    // is public SDK surface (`updateOperation`), and a value arriving with
    // stray space would never equal the trimmed slot it is compared against —
    // so every repeat of the same command would push another revision.
    final operatorCall = params['operatorCall']?.toString().trim().toUpperCase();
    final raw = params['multiIdentifier']?.toString();
    final multiIdentifier = raw == null ? null : normalizedMultiIdentifier(raw);
    if (multiIdentifier != null && multiIdentifier != multiIdentifierFor(operation)) {
      await operations.updateLocalData(operation.uuid, {multiIdentifierKey: multiIdentifier});
    }
    if (operatorCall != null) {
      final key = operatorCallKeyFor(multiIdentifier ?? multiIdentifierFor(operation));
      final seatOperatorCall = (asQsonString(operation.data[key]) ?? '').trim();
      if (operatorCall != seatOperatorCall) {
        await operations.saveData(Operation(uuid: operation.uuid, data: {...operation.data, key: operatorCall}));
      }
    }
    return null;
  }

  /// What a segment row says in the list — polo's `describeOperation`: each
  /// ref's title fragments, then "at <grid>", joined with " • " ("for ARRL
  /// 10G Sep • POTA: US-1000 • at FN21rm"). Stored on the row rather than
  /// composed at render, so a synced row reads the same on a device without
  /// the extension that named the ref.
  /// Null when the references could not all be asked — the runtime is down,
  /// or a hook threw. A truncated phrase must not be PERSISTED as though it
  /// were the whole truth: it would replace a good description on a restamp,
  /// and no later pass recomposes it. The row falls back to what it can
  /// render from its own override instead (`EventRow`).
  Future<String?> segmentDescription(Operation operation, Map<String, dynamic> override) async {
    final resolved = Operation(uuid: operation.uuid, data: {...operation.data, ...override});
    final result = await operationTitles.suggestForRefs(resolved);
    if (result == null || !result.complete) return null;
    return segmentDescriptionFor(t, result.suggestions, resolved.displayGrid);
  }

  /// START / BREAK / STOP / ROVERQTH: writes the segment boundary the scoring
  /// model reads (docs/design/contests.md §5.1.3). A `break` row states what
  /// is true for the stretch that FOLLOWS it, and the base operation is only
  /// a default under the segments, not an accumulator — so a log getting its
  /// first break also gets a `start` at its top holding what the contacts so
  /// far were made under; otherwise, the moment the base moves, they would
  /// all silently move with it. `stop` moves an existing stop row to now
  /// rather than stacking a second one, as polo does.
  ///
  /// With `setLocation` (ROVERQTH) the Location screen opens afterwards, and
  /// what it returns is saved onto the operation; `onLocalSave` then restamps
  /// the break just written, which is how the new stretch resolves to the
  /// new square. A cancelled screen leaves a break restating the old
  /// location, which scores exactly as before.
  ///
  /// Returns null on success — the hook's own `confirm` already told the
  /// operator what is happening, as `updateOperation` does.
  Future<CommandActionOutcome?> _markSegment(Map<String, dynamic> params) async {
    final kind = asQsonString(params['kind']);
    if (kind != 'start' && kind != 'break' && kind != 'stop') {
      // Only a malformed extension action reaches this, so it must name the
      // real fault rather than borrow the no-operation message.
      return (text: t.commands.unknownSegmentKind(kind: kind ?? ''), failed: true);
    }
    final uuid = asQsonString(params['uuid']) ?? '';
    final operation = uuid.isEmpty ? null : await operations.get(uuid);
    if (operation == null) return (text: t.commands.noOperationOpen, failed: true);

    // Event rows only: the whole log would be decoded to read a handful of
    // them, and the one thing needed from the contacts is the earliest time.
    final events = await qsos.eventsForOperation(operation.uuid);
    final override = segmentOverrideOf(operation.data);
    final description = await segmentDescription(operation, override);
    final hasStart = events.any((q) => q.eventKind == 'start');
    final hasSegment = events.any((q) => eventKindOpensSegment(q.eventKind));

    Future<void> addStart() async {
      final firstAt = await qsos.firstContactMillis(operation.uuid);
      await qsos.addEvent(
        operation.uuid,
        kind: 'start',
        atMillis: firstAt == null ? nowMillis() : firstAt - 1000,
        operation: override,
        description: description,
      );
    }

    switch (kind) {
      case 'start':
        // Reported, not silent: the operator asked to mark the start NOW,
        // and the row that exists sits at the top of the log with an older
        // timestamp. A bare success would read as though it had moved.
        if (hasStart) return (text: t.commands.operationAlreadyStarted, failed: true);
        await addStart();
      case 'break':
        if (!hasSegment) await addStart();
        await qsos.addEvent(operation.uuid, kind: 'break', atMillis: nowMillis(), operation: override, description: description);
      case 'stop':
        Qso? previous;
        for (final q in events) {
          if (q.eventKind == 'stop') previous = q;
        }
        if (previous == null) {
          await qsos.addEvent(operation.uuid, kind: 'stop', atMillis: nowMillis(), operation: override, description: description);
        } else {
          await qsos.update(Qso(
            uuid: previous.uuid,
            operationUuid: previous.operationUuid,
            data: {
              ...previous.data,
              'startAtMillis': nowMillis(),
              // The override is being restated, so a description that
              // could not be composed in full is CLEARED rather than kept:
              // the old line would describe the stretch this row no longer
              // states (see [segmentDescription]).
              'event': {
                ...?previous.event,
                'operation': override,
                'description': description,
              }..removeWhere((key, value) => key == 'description' && value == null),
            },
          ));
        }
    }

    if (params['setLocation'] != true) return null;
    final context = navigatorKey.currentContext;
    // The hook's confirm already said "now set your new location". Going
    // quiet here would leave the operator holding that promise while the
    // next stretch scores from the old square.
    if (context == null) return (text: t.commands.couldNotOpenLocation, failed: true);
    final patch = await showHaloDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => OperationLocationScreen(services: this, operation: operation),
    );
    if (patch == null) return null;
    // The counters and local data ride along: `rescoreOperation` reads
    // `localData['huntedRefTypes']` to decide whether to write, and an
    // operation rebuilt without it looks uncached every time — a local_data
    // write, and the Operation View rebuild behind it, on every ROVERQTH.
    final updated = Operation(
      uuid: operation.uuid,
      data: {...operation.data, ...patch},
      qsoCount: operation.qsoCount,
      startAtMillisMin: operation.startAtMillisMin,
      startAtMillisMax: operation.startAtMillisMax,
      localData: operation.localData,
    );
    await operations.saveData(updated);
    unawaited(scoring.rescoreOperation(updated));
    return null;
  }

  /// Backs both the Spotting control's send button and the SPOT/QRV/QRT/
  /// QSY/QRX/SPOTLAST-family commands (`logging_controls.dart`'s
  /// `_dispatchActions`, which already resolved *who* gets spotted —
  /// this only posts and summarizes the per-source result).
  Future<CommandActionOutcome?> _sendSpot(Map<String, dynamic> params) async {
    final operation = (params['operation'] as Map?)?.cast<String, dynamic>() ?? const {};
    final qso = (params['qso'] as Map?)?.cast<String, dynamic>();
    final target = params['target'] as String? ?? 'self';
    if (target == 'last' && qso == null) return (text: t.spotting.noQsoYet, failed: true);
    final freq = (params['freq'] as num?)?.toDouble();
    if (qso == null && freq == null) return (text: t.spotting.setFrequencyFirst, failed: true);

    final sources = await extensions.suggestSpotSources(operation: operation, qso: qso);
    if (sources.isEmpty) return (text: t.spotting.nothingToSpot, failed: true);

    final results = await extensions.sendSpot(
      sources: sources,
      operation: operation,
      qso: qso,
      freq: freq,
      mode: params['mode'] as String?,
      comment: params['comment'] as String?,
      spotterCall: settings.activeProfile.operatorCall,
    );

    // Only failures get a notice — a successful spot already shows in the
    // Spotting control's per-source status icons, and a "Spotted on X" text
    // notice on top of that is a confirmation nobody asked to acknowledge.
    // A refusal still has to surface: it's bad news the operator needs to
    // see, since the icon alone is easy to miss. Distinct from every source
    // failing: no result at all (every hookKey missing from `results`) means
    // the spot never went anywhere, which is its own failure to report.
    var anyResult = false;
    final failures = <String>[];
    for (final source in sources) {
      final hookKey = source['hookKey'] as String? ?? '?';
      final result = results[hookKey];
      if (result == null) continue;
      anyResult = true;
      if (result['ok'] != true) {
        failures.add(t.spotting.spotFailed(source: hookKey, message: result['message'] ?? t.spotting.unknownError));
      }
    }
    if (!anyResult) return (text: t.spotting.notSent, failed: true);
    if (failures.isEmpty) return null;
    return (text: failures.join('; '), failed: true);
  }

  Future<Map<String, dynamic>> _syncTransportCall(String method, Map<String, dynamic> args) async {
    final host = extensions.host;
    // Not an error - the extension host is still loading. On a cold start the
    // first periodic round can fire before it is up, and every other consumer
    // (scoring, operation titles, export) already treats that as a no-op.
    // Throwing a plain StateError here made each launch count a sync failure
    // and file a crash report for a race that clears in seconds.
    if (host == null) throw const SyncTransportNotReady();
    final result =
        await host.invokeHook('syncTransport', method: method, args: args, timeout: const Duration(seconds: 30));
    return (result as Map).cast<String, dynamic>();
  }
}

/// What a command action had to say about what it did, and whether that is
/// bad news.
///
/// The two travel together because the destination has to tell them apart:
/// "Spotted on POTA" and "POTA: 503" reach the same line, and rendered alike
/// the second reads as the first. Only the action knows which it is —
/// `updateSetting` returns text ONLY on failure, while `syncAll` returns it
/// either way — so the classification is made where that is known and carried
/// from there, never guessed from the wording downstream.
typedef CommandActionOutcome = ({String text, bool failed});

/// Runs one command action through [HaLoServices.handleCommandAction] and
/// surfaces its returned message — so feedback that's only known app-side (a
/// toggled experiment's outcome, syncAll's status) isn't silently dropped.
/// Shared by home_view's, operation_view's and the ⌘K dialog's command
/// dispatch.
///
/// A command typed into one of the two command bars is answered THERE, on the
/// bar's own response line ([HaLoServices.commandResponseSink], which that bar
/// holds open only while its command is dispatching). Everything else — a
/// command typed into the call field — gets the status bar beside it.
///
/// The action's word is the LATER and more specific news than the hook's
/// optimistic `confirm` — it is usually the bad news — so it deliberately
/// replaces it rather than queueing behind it.
///
/// A non-null message ALWAYS reaches something. A bar that has closed is a
/// reason to say it somewhere else and never a reason to drop it: a rejected
/// write announced to nobody leaves the operator holding a confirmation for
/// something that did not happen, which is the failure this whole path exists
/// to prevent. The sink declining is what routes it onward, so a caller must
/// not second-guess that with a liveness test of its own — whether the widget
/// that dispatched the action is still mounted says nothing about whether the
/// bar waiting on the answer is.
///
/// Returns true when the action had something to say at all.
///
/// [context] is only needed for `purgeTests` (PURGETESTS) and `syncAll`
/// (SYNCALL): unlike every other action, which
/// [HaLoServices.handleCommandAction] can run with no UI at all, both have
/// to ask for confirmation before doing anything irreversible — so they're
/// intercepted here rather than reaching that switch. Every real call site
/// (home, ⌘K, the logging panel) has a BuildContext to pass; omitting it
/// only degrades those two commands.
Future<bool> runCommandAction(HaLoServices services, String action,
    [Map<String, dynamic>? params, BuildContext? context]) async {
  final outcome = switch (action) {
    'purgeTests' => await _runPurgeTests(services, context),
    'syncAll' => await _runSyncAll(services, context),
    _ => await services.handleCommandAction(action, params),
  };
  if (outcome == null) return false;
  final sink = services.commandResponseSink;
  if (sink == null || !sink(outcome.text, failed: outcome.failed)) {
    services.statusBar.setMessage(key: 'commandAction', text: outcome.text);
  }
  return true;
}

/// PURGETESTS: lists every Test Operation this device holds, asks once for
/// all of them (`confirmPurgeTestOperations`), then purges each — see
/// `HaLoServices.purgeOperation`. Returns null (no message at all) when the
/// user cancels, same as any other dismissed dialog.
///
/// Test contacts belonging to NO operation go too. Nothing else can reach
/// them: this command walks operations and the received-purge prompt is keyed
/// on operation uuids, so without this they accumulate and sync forever. A
/// travelled clock can author exactly these — a test call is the only thing
/// identifying a contact with no operation to belong to.
Future<CommandActionOutcome?> _runPurgeTests(HaLoServices services, BuildContext? context) async {
  // Bypasses handleCommandAction's switch (see runCommandAction's doc), so
  // it has to fire the same usage event that switch's callers get for free.
  services.track('command_executed', {'command': 'purgeTests'});

  final testOperations = (await services.operations.watchAll().first).where((op) => op.isTestOperation).toList();
  final looseQsos = await services.qsos.testQsosWithoutOperation();
  if (testOperations.isEmpty && looseQsos.isEmpty) return (text: t.commands.noTestOperations, failed: false);
  if (context == null) return (text: t.commands.purgeTestsUnavailable, failed: true);
  // The await above is a real gap: the widget that owns `context` (the
  // command dialog, home view, or logging panel) can be gone by the time it
  // resolves — e.g. the operator closed ⌘K while this was still listing.
  if (!context.mounted) return (text: t.commands.purgeTestsUnavailable, failed: true);
  if (!await confirmPurgeTestOperations(context, testOperations, looseQsoCount: looseQsos.length)) return null;

  // Isolated per operation: one purge throwing must not strand the rest
  // half-purged with no report of how far it got.
  var purgedCount = 0;
  for (final operation in testOperations) {
    try {
      await services.purgeOperation(operation.uuid);
      purgedCount++;
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'purgeTests:${operation.uuid}');
    }
  }
  // Isolated from the loop above for the same reason, and counted separately:
  // the two are different things to the operator, and one number cannot stand
  // for both. `purgeQsos` reports what it actually wrote, not what was asked.
  var purgedContacts = 0;
  var contactsFailed = false;
  if (looseQsos.isNotEmpty) {
    try {
      purgedContacts = await services.qsos.purgeQsos(looseQsos.map((qso) => qso.uuid));
    } catch (e, st) {
      contactsFailed = true;
      ErrorReportingService.report(e, st, context: 'purgeTests:looseQsos');
    }
  }
  services.track('test_operations_purged', {'count': purgedCount, 'contacts': purgedContacts});

  // Every branch names what it actually did. Reporting only the operations —
  // "Purged 0 Test Operations" after tombstoning five contacts the operator
  // just confirmed — reads as a command that silently failed.
  final parts = <String>[
    if (purgedCount > 0) t.commands.testOperationsPurged(count: purgedCount),
    if (purgedContacts > 0) t.commands.testContactsPurged(count: purgedContacts),
  ];
  if (purgedCount < testOperations.length) {
    return (text: t.commands.purgeTestsSomeFailed(purged: purgedCount, total: testOperations.length), failed: true);
  }
  if (contactsFailed) return (text: t.commands.purgeTestsContactsFailed, failed: true);
  if (parts.isEmpty) return (text: t.commands.purgeTestsNothingToDo, failed: false);
  return (text: parts.join(' · '), failed: false);
}

/// SYNCALL: backs up and WIPES the local log, then refills it from the
/// server (`SyncEngine.forceFullResync`) — intercepted like PURGETESTS
/// because it must confirm before doing anything irreversible. The backfill
/// can only return what the server holds: any row it never received (a
/// failed push, a long-offline device) does NOT come back, and the operator
/// most likely to type SYNCALL — "sync looks stuck, force it" — is exactly
/// the one most likely to be holding such rows, so the dialog names the
/// unsynced count outright. Returns null when the user cancels, same as any
/// other dismissed dialog.
Future<CommandActionOutcome?> _runSyncAll(HaLoServices services, BuildContext? context) async {
  // Bypasses handleCommandAction's switch, so it fires the same usage event.
  services.track('command_executed', {'command': 'syncAll'});
  if (!services.settings.syncEnabled) return (text: t.commands.enableSyncFirst, failed: true);
  if (context == null) return (text: t.commands.syncAllUnavailable, failed: true);
  final counts = await services.qsos.syncCounts();
  // NOT `counts.pending`: that number counts every dirty row — tombstones
  // and event markers included — and a dialog warning "N QSOs will not come
  // back" with a number the operator can see is wrong teaches them to
  // distrust the one gate on this wipe.
  final unsynced = await services.qsos.unsyncedContactCount();
  // The awaits above are a real gap — same reasoning as _runPurgeTests.
  if (!context.mounted) return (text: t.commands.syncAllUnavailable, failed: true);
  if (!await confirmFullResyncDialog(context, qsoCount: counts.total, unsyncedCount: unsynced)) return null;

  // A refusal has to be reported: this command backs up and WIPES the
  // local log before refilling it from the server, so "started" against a
  // clock that bars sync would be the operator watching their log vanish
  // with nothing that would refill it (docs/design/time.md §4).
  if (!await services.syncEngine.forceFullResync()) {
    return (text: 'A full resync needs the real clock — run DEVTT first', failed: true);
  }
  return (text: t.commands.fullResyncStarted, failed: false);
}



class HaLoApp extends StatefulWidget {
  final HaLoServices services;

  const HaLoApp({super.key, required this.services});

  @override
  State<HaLoApp> createState() => _HaLoAppState();
}

/// Lets HomeView notice when it is on top again. It is `MaterialApp.home`, so
/// its State is created once and never disposed — `initState` alone would
/// report one home visit per LAUNCH while the operation and settings screens,
/// which are pushed, report per visit. The three counts have to be comparable
/// or `screen_viewed` cannot be read as navigation at all.
final homeRouteObserver = RouteObserver<PageRoute<dynamic>>();

class _HaLoAppState extends State<HaLoApp> {
  // Held as a field (not rebuilt per frame) so its route count survives
  // MaterialApp rebuilds; drives `modalBarrierIsVisible` for the window-chrome
  // mask. See navigatorObservers below.
  final _modalBarrierObserver = ModalBarrierRouteObserver();

  /// Whether the ⌘K command dialog is currently up, so a second ⌘K closes it
  /// instead of opening another one over it.
  bool _commandDialogOpen = false;

  // iOS never delivers ⌘-letter chords to HardwareKeyboard below — UIKit's
  // key-command discovery intercepts them first — so AppDelegate.swift
  // registers native UIKeyCommands for the same combos and forwards them
  // here instead.
  static const _keyCommandChannel = MethodChannel('ham2k/key_commands');

  // The channel only holds one handler at a time, so whichever State set it
  // last has to be the only one that clears it — otherwise an older
  // instance's dispose() can null out a newer instance's handler. Same
  // identity-check shape as the DevBridge guard in dispose() below.
  static _HaLoAppState? _keyCommandHandlerOwner;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _keyCommandHandlerOwner = this;
    _keyCommandChannel.setMethodCallHandler(_handleNativeKeyCommand);
    if (DevBridge.instance.installed) {
      DevBridge.instance.openCommandBarHandler = _openCommandDialog;
      DevBridge.instance.closeCommandBarHandler = _closeCommandDialog;
    }
  }

  @override
  void dispose() {
    _densityMessageTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    if (identical(_keyCommandHandlerOwner, this)) {
      _keyCommandChannel.setMethodCallHandler(null);
      _keyCommandHandlerOwner = null;
    }
    if (DevBridge.instance.openCommandBarHandler == _openCommandDialog) {
      DevBridge.instance.openCommandBarHandler = null;
      DevBridge.instance.closeCommandBarHandler = null;
    }
    super.dispose();
  }

  /// One `run` call per native UIKeyCommand in AppDelegate.swift, naming the
  /// same actions `_handleKeyEvent` dispatches by key/modifier below — kept
  /// as a single switch so the two paths can't drift apart.
  Future<void> _handleNativeKeyCommand(MethodCall call) async {
    if (call.method != 'run') return;
    switch (call.arguments as String) {
      case 'commandDialog':
        _toggleCommandDialog();
      case 'themeToggle':
        _toggleTheme();
      case 'localeToggle':
        _toggleLocale();
      case 'zoomIn':
        widget.services.settings.increaseFontScale();
      case 'zoomOut':
        widget.services.settings.decreaseFontScale();
      case 'zoomReset':
        widget.services.settings.setFontScale(FontScale.normal);
    }
  }

  /// The window height the density ladder actually sees: the real height
  /// divided by the UI scale.
  ///
  /// `LayoutDensityScope` sits INSIDE `UiScale` and so reads an already-
  /// divided `MediaQuery` (docs/design/ui-scaling.md rule 4). This handler's
  /// context is above that wrapper, where the height is still the raw window,
  /// so the division has to be redone here — without it a zoomed-in operator
  /// would step from a density they aren't actually looking at.
  double get _densityLadderHeight =>
      MediaQuery.sizeOf(context).height / widget.services.settings.fontScale.scaleFactor;

  void _stepDensity({required bool denser}) {
    final settings = widget.services.settings;
    final next = settings.densityPreference.stepped(height: _densityLadderHeight, denser: denser);
    if (next == null) {
      _announceDensity(settings.densityPreference, atLimit: true);
      return;
    }
    settings.setDensityPreference(next);
    _announceDensity(next);
  }

  Timer? _densityMessageTimer;
  static const _densityMessageKey = 'layoutDensity';

  /// Names the density the operator just landed on, in the status bar.
  ///
  /// Not decoration: the shortcut can legitimately change the stored
  /// preference without changing the layout — a roomier pick on a window too
  /// short for it is stored but clamped by [DensityPreference.resolve]'s
  /// ceiling — and a key that appears to do nothing reads as broken. The
  /// message is the only place that difference is visible.
  void _announceDensity(DensityPreference preference, {bool atLimit = false}) {
    final effective = preference.resolve(_densityLadderHeight);
    final settingLabel = context.t['settings.layoutDensityOpts.${preference.name}'] as String;
    final effectiveLabel = context.t['settings.layoutDensityOpts.${effective.name}'] as String;

    // The SETTING leads, always: the shortcut's job is to move the setting,
    // and on Auto — or when the ceiling clamps a pick — the density in force
    // is not the same thing. Naming only one of the two leaves the operator
    // unable to tell which they just changed.
    final detail = switch (preference) {
      _ when preference != DensityPreference.auto && preference.name != effective.name =>
        context.t.settings.layoutDensityClamped(effective: effectiveLabel),
      _ when atLimit => context.t.settings.layoutDensityAtLimit,
      DensityPreference.auto => effectiveLabel,
      _ => null,
    };
    final text = detail == null ? settingLabel : '$settingLabel — $detail';

    widget.services.statusBar.setMessage(
      key: _densityMessageKey,
      icon: 'arrow-collapse-vertical',
      title: context.t.settings.layoutDensity,
      text: text,
    );
    _densityMessageTimer?.cancel();
    _densityMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) widget.services.statusBar.clear(_densityMessageKey);
    });
  }

  /// Opens the ⌘K dialog, unless it's already up. Shared by the shortcut and
  /// the dev bridge (which exists because synthetic modifier combos can't
  /// reach the Flutter canvas — see DevBridge).
  void _openCommandDialog() {
    if (_commandDialogOpen) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;
    _commandDialogOpen = true;
    unawaited(showCommandDialog(context, widget.services).whenComplete(() => _commandDialogOpen = false));
  }

  void _closeCommandDialog() {
    if (!_commandDialogOpen) return;
    navigatorKey.currentState?.pop();
  }

  /// A second ⌘K while the dialog is open closes it rather than stacking a
  /// second copy on top of the first.
  void _toggleCommandDialog() {
    if (_commandDialogOpen) {
      _closeCommandDialog();
    } else {
      _openCommandDialog();
    }
  }

  void _toggleTheme() {
    final settings = widget.services.settings;
    settings.setThemeMode(
      toggledThemeMode(settings.themeMode, WidgetsBinding.instance.platformDispatcher.platformBrightness),
    );
  }

  void _toggleLocale() {
    final settings = widget.services.settings;
    final newLocale = settings.locale == 'es' ? 'en' : 'es';
    settings.setLocale(newLocale);
    LocaleSettings.setLocaleRaw(newLocale);
    widget.services.extensions.invalidateHookContext();
  }

  bool _handleKeyEvent(KeyEvent event) {
    // The tester overlay owns the keyboard while covering the app. Its own
    // Focus node can't block this handler (HardwareKeyboard dispatches
    // ahead of the focus tree), and acting here would fire chords into
    // chrome the overlay hides — ⌘K would open the command dialog invisibly
    // beneath it and steal its focus.
    if (testerOverlayCovering.value) return false;
    if (event is! KeyDownEvent) return false;

    final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    final hasModifier = isMetaPressed || isControlPressed;

    if (!hasModifier) return false;

    final key = event.logicalKey;
    final settings = widget.services.settings;

    if (key == LogicalKeyboardKey.keyK) {
      // ⌘K (⌃K on Windows/Linux) opens the command dialog. ⌘⇧K is accepted
      // as the same action — iOS reserves plain ⌘K for its own software
      // keyboard toggle, so AppDelegate.swift only gets ⌘⇧K to work with there.
      _toggleCommandDialog();
      return true;
    }

    if (HardwareKeyboard.instance.isShiftPressed && key == LogicalKeyboardKey.keyD) {
      // ⌘⇧D (⌃⇧D on non-Mac): flip between light and dark themes.
      _toggleTheme();
      return true;
    }

    if (HardwareKeyboard.instance.isShiftPressed && key == LogicalKeyboardKey.keyL) {
      // ⌘⇧L (⌃⇧L on non-Mac): toggle language between English and Spanish.
      _toggleLocale();
      return true;
    }

    // ⌘⇧-/⌘⇧=/⌘⇧0 (⌃⇧ on non-Mac): step the Layout Density, on the same keys
    // as Font Scale one modifier up. The two are the same question — how much
    // fits on screen — so an operator reaching for one is already thinking
    // about the other.
    //
    // This block MUST precede the Font Scale one: the shifted forms of those
    // keys are exactly what it matches (`+` IS shift-equal, `_` IS
    // shift-minus), so ⌘⇧= would otherwise have zoomed rather than loosened.
    // Claiming them costs ⌘+ and ⌘_ as aliases for ⌘= and ⌘-, which is the
    // deliberate trade.
    if (HardwareKeyboard.instance.isShiftPressed) {
      final denser = key == LogicalKeyboardKey.minus ||
          key == LogicalKeyboardKey.underscore ||
          key == LogicalKeyboardKey.numpadSubtract;
      final sparser = key == LogicalKeyboardKey.equal ||
          key == LogicalKeyboardKey.add ||
          key == LogicalKeyboardKey.numpadAdd;
      if (denser || sparser) {
        _stepDensity(denser: denser);
        return true;
      }
      if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
        // Back to Auto, not to Normal: Auto is the default, and "reset" here
        // means "stop overriding" rather than "pick the middle rung".
        settings.setDensityPreference(DensityPreference.auto);
        _announceDensity(DensityPreference.auto);
        return true;
      }
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
        navigatorObservers: [_modalBarrierObserver, homeRouteObserver, homeRailRouteObserver],
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
          // The header height is density-resolved, so both the snap and the
          // native traffic-light report happen in `_LayoutDensityFromWindow`
          // below — the first place the rung is known.
          //
          // The window's resize floor is the S-size layout width plus room for
          // the native window controls that float over the header (traffic
          // lights / caption buttons), so neither the S content nor the
          // controls is ever squeezed (desktopMinimumWindowSize; layouts.md).
          WindowChromeService.reportMinimumSize(desktopMinimumWindowSize(scale));

          // Full-screen toggles change the traffic-light clearance the
          // headers reserve (macOSTrafficLightClearance → 0 while the
          // buttons live in the system's auto-hiding overlay). The scope is
          // the delivery mechanism — see MacOSFullScreenScope's own comment.
          // On chromeless Windows/Linux the caption buttons are
          // Flutter-drawn and float over every route's header from here —
          // the same "window chrome above app content" role the native
          // traffic lights play on macOS. Headers reserve trailing room via
          // windowsCaptionClearance. On macOS the native traffic lights
          // already float there; we overlay a same-colored mask beneath them
          // (MacOSTrafficLightMask) so header content animating through the
          // top-left corner doesn't flash out around the buttons.
          Widget content = child;
          if (isWindowsChromelessWindow || isLinuxChromelessWindow) {
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

          // The app shows NO hover labels (docs/design/user-interface.md).
          // Our own buttons simply don't set one, but Flutter's built-ins
          // (BackButton, CloseButton, PopupMenuButton, Chip's delete icon)
          // supply their own from MaterialLocalizations and take no parameter
          // to turn it off — so the rule is enforced here, for the whole app
          // at once, instead of being re-litigated per widget. Accessible
          // names live on `Icon(semanticLabel:)`, which this does not touch.
          return TooltipVisibility(
            visible: false,
            child: ValueListenableBuilder<bool>(
                valueListenable: macOSWindowIsFullScreen,
                builder: (context, isFullScreen, _) => MacOSFullScreenScope(
                  isFullScreen: isFullScreen,
                  child: UiScale(
                    scale: scale,
                    // INSIDE UiScale, deliberately: the density ladder reads
                    // the divided height, so a large font scale genuinely
                    // fits less and reaches for a tighter layout sooner —
                    // the same bargain ShirtSize makes on width
                    // (docs/design/ui-scaling.md rule 4). Reading the real
                    // window height here would leave the operator who zoomed
                    // in with a sparse layout that no longer fits.
                    child: _LayoutDensityFromWindow(
                      settings: widget.services.settings,
                      scale: scale,
                      // Outermost so it covers every field in the app — the gates'
                      // own overlays and anything pushed on the Navigator (which is
                      // `content`, i.e. dialogs and panes) included.
                      child: TapToDismissEmptyField(
                      // Outermost of the startup gates: the tester overlay
                      // paints above even the onboarding flow — a tester's
                      // fresh install gets the caution warning before
                      // anything else.
                      child: _TesterOverlayGate(
                        services: widget.services,
                        child: _OnboardingGate(
                          services: widget.services,
                          child: _ReleaseOverlayGate(
                            services: widget.services,
                            child: StatusBarOverlay(services: widget.services, child: content),
                          ),
                        ),
                      ),
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

/// Publishes the app-wide [LayoutDensity], resolved from the window's height
/// and the operator's [DensityPreference].
///
/// A separate widget rather than an expression inline in the builder so it
/// rebuilds on a window resize without dragging the whole `MaterialApp`
/// builder with it: `MediaQuery.sizeOf` is read HERE, so only this subtree is
/// marked dirty when the height changes.
///
/// Reads `MediaQuery.sizeOf(context).height`, which below `UiScale` is the
/// divided height — and which does NOT shrink when the on-screen keyboard
/// opens (`StatusBarOverlay` consumes that inset on the way down; see
/// home_view.dart's note). That is the intended behaviour: the whole UI
/// reflowing every time the keyboard appears would be worse than the tight
/// fit it would relieve, and it is the same call `onboarding_overlay.dart`
/// makes for its own compact threshold.
class _LayoutDensityFromWindow extends StatefulWidget {
  final SettingsService settings;
  final double scale;
  final Widget child;

  const _LayoutDensityFromWindow({required this.settings, required this.scale, required this.child});

  @override
  State<_LayoutDensityFromWindow> createState() => _LayoutDensityFromWindowState();
}

class _LayoutDensityFromWindowState extends State<_LayoutDensityFromWindow> {
  LayoutDensity _density = LayoutDensity.normal;

  /// Seeded from the ladder's own `normal` rung rather than Flutter's
  /// `kToolbarHeight` (56): the two disagree, and stating the default twice is
  /// how they drift. Never painted — `didChangeDependencies` resolves before
  /// the first build — but it is what any earlier read would get.
  double _toolbarHeight = LayoutMetrics.normal.chromeHeight;

  /// The derived theme, rebuilt only when the height it derives from moves.
  ///
  /// `ThemeData.copyWith` copies around a hundred fields, and this widget
  /// depends on `MediaQuery.sizeOf` — so without the cache a window drag
  /// pays for a full copy, and a full `ThemeData ==` in the inherited theme's
  /// updateShouldNotify, on every frame. The height only changes at a band
  /// boundary, so almost every one of those frames is answered from here.
  ThemeData? _derivedTheme;
  ThemeData? _derivedFrom;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _LayoutDensityFromWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The preference lives in a service, not in the widget, so a settings
    // change arrives as a rebuild from the AnimatedBuilder above rather than
    // as a dependency change.
    _resolve();
  }

  /// Resolves the density and the header height, and tells the native window
  /// chrome about the latter.
  ///
  /// Deliberately NOT in `build`: `reportTitleBarHeight` crosses a platform
  /// channel, and `build` has to stay free of side effects — the framework
  /// may call it speculatively or more than once per frame, and this widget
  /// depends on `MediaQuery.sizeOf`, so it rebuilds on every resize frame.
  void _resolve() {
    final density = widget.settings.densityPreference.resolve(MediaQuery.sizeOf(context).height);

    // The header's bottom edge is a color boundary against the body, so it has
    // to land on the device pixel grid: inside UiScale one logical pixel is
    // `scale × devicePixelRatio` device pixels, and 48 × 0.85 × 2.0 = 81.6 is
    // not a whole one — the leftover antialiases into the content below as a
    // hairline seam. Snapped ONCE here and pushed into the theme, so every
    // AppBar in the app inherits it and the seam can't come back view by view.
    //
    // The DENSITY-RESOLVED value is what gets snapped, not the base constant:
    // snapping 48 and swapping in a shorter header downstream would put the
    // seam straight back at every non-1.0 font scale.
    final toolbarHeight = PixelGrid.of(context).snap(density.metrics.chromeHeight);

    // Plain assignment, no setState: both callers are immediately followed
    // by a build, and marking dirty from didChangeDependencies would only
    // schedule a second one.
    if (toolbarHeight != _toolbarHeight) _derivedTheme = null;
    _density = density;
    _toolbarHeight = toolbarHeight;

    // The same snapped height the headers actually render at, scaled back to
    // real pixels, so the fixed-size native traffic lights stay centered in
    // it. Reported from here rather than above UiScale because the density is
    // not known up there and the value would be stale the moment the operator
    // changed it. Deduped inside the service.
    WindowChromeService.reportTitleBarHeight(toolbarHeight * widget.scale);
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    if (_derivedTheme == null || !identical(base, _derivedFrom)) {
      _derivedFrom = base;
      _derivedTheme = base.copyWith(
        appBarTheme: base.appBarTheme.copyWith(toolbarHeight: _toolbarHeight),
      );
    }
    return LayoutDensityScope(
      density: _density,
      child: Theme(data: _derivedTheme!, child: widget.child),
    );
  }
}


/// Debug-only shortcut for skipping the onboarding flow: set
/// `ONBOARD_AS=CALL,activity,...` — e.g. `ONBOARD_AS=KI2D,pota,sota` — as a
/// `--dart-define` or an environment variable, and a first run applies that
/// operator callsign and enables the listed activity extensions instead of
/// showing onboarding. The first comma-separated token is the callsign; the
/// rest are extension keys to enable. Empty (and inert) in release builds.
String get _onboardAsConfig => debugEnvFlag(const String.fromEnvironment('ONBOARD_AS'), 'ONBOARD_AS');

/// Whether onboarding is about to show for [services]: the default profile
/// has never had a callsign set, and no ONBOARD_AS debug override is
/// skipping the flow instead. Shared by `_OnboardingGateState.initState`
/// (which decides whether to actually show it) and `_BootGateState` (which
/// decides whether to wait for its photo before switching off the splash)
/// so the two can't silently drift apart into two different answers.
bool _onboardingWillShow(HaLoServices services) =>
    !services.settings.defaultProfileCallsignDefined && _onboardAsConfig.isEmpty;

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

/// First-run onboarding: wraps the release overlay gate so the
/// onboarding paints on top of everything, whenever the default profile has
/// NEVER had a callsign set — undefined, not '' (an explicit empty from a
/// previous Skip counts as answered). Unlike the release overlay/About photo
/// modal, always full screen — even on wide layouts — rather than
/// `wideModalChrome`'s centered card: this is a first impression, and the
/// release photo should fill the whole window rather than float over a
/// blurred backdrop. No barrier dismissal either way; the flow's own
/// Skip/Done are the exits.
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
    if (_onboardingWillShow(widget.services)) {
      _firstRun = true;
      // 'shown' the moment the organic flow is decided, not when it's
      // dismissed — this is a display count, and DEVONBOARD re-shows
      // (the only other caller of _show()) must not bump it.
      unawaited(widget.services.settings.recordOnboardingShown(OnboardingFlows.firstUse));
      _show();
    } else if (!widget.services.settings.defaultProfileCallsignDefined) {
      // Debug-only: ONBOARD_AS is set — apply it and skip the onboarding
      // flow entirely.
      unawaited(applyOnboardAsSpec(widget.services, _onboardAsConfig));
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
    // release overlay. Onboarding must never be stuck waiting on it (this is
    // a first run — the flow has to appear right away), so it's fine to
    // arrive late (or never); OnboardingOverlayView itself crossfades the
    // photo in once it's actually finished downloading rather than popping
    // it in, so a late arrival still doesn't look broken.
    loadReleaseNotes().then((notes) {
      if (mounted && notes.isNotEmpty) setState(() => _release = notes.first);
    }).catchError((Object error, StackTrace stackTrace) {
      // Same tolerance as above: a broken/missing release-notes asset just
      // means no photo, not a broken onboarding flow — but still needs a
      // handler, or this becomes an unhandled rejection.
      debugPrint('[onboarding] release notes unavailable: $error\n$stackTrace');
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
      // Always full screen — see this class's doc comment — so no
      // wideModalChrome wrap on wide layouts, unlike the release overlay.
      final view = OnboardingOverlayView(
        // Re-inflates the whole subtree per showing, so the content's State is
        // fresh (matters for DEVONBOARD re-shows — step position and toggles
        // reset). This widget holds no state of its own.
        key: ValueKey('onboarding-$_firstRun-$_pending'),
        services: widget.services,
        release: _release,
        onDone: _dismiss,
      );
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
/// whole app (same one-integration-point wrapping as `StatusBarOverlay`
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
    // The newest entry whatever the running version — and the overlay's header
    // names the RUNNING build (version_label.dart), not this entry, so on a
    // build that has moved past the newest notes the preview shows this
    // version over that release's changes.
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

/// Shows `TesterOverlayView` on the Dev and Next editions whenever
/// `kBuildNumber` has advanced past `SettingsService.lastSeenTesterBuild`
/// and the build carries no explicit `DEV_LABEL`, listing every tester-notes
/// entry in between (tester_notes.dart, tester_overlay.dart). Outermost of
/// the startup gates — it paints above the onboarding flow too, so even a
/// fresh install leads with the caution warning. Dismissing persists
/// `kBuildNumber`, so it won't show again until the next build with notes.
///
/// Because AGENTS.md has every `flutter run` pass a `DEV_LABEL`, the organic
/// path below is unreachable in normal development, and DEVTESTER exercises
/// only `_showDevTester` (no `lastSeen` filtering, no stamping). Checking a
/// change to the pending-entry filter or to stamp-on-dismiss means running
/// once WITHOUT the label; nothing else reaches that code before a tester's
/// real build does.
class _TesterOverlayGate extends StatefulWidget {
  final HaLoServices services;
  final Widget child;

  const _TesterOverlayGate({required this.services, required this.child});

  @override
  State<_TesterOverlayGate> createState() => _TesterOverlayGateState();
}

class _TesterOverlayGateState extends State<_TesterOverlayGate> {
  List<TesterNotesEntry>? _pending;
  ReleaseNotesEntry? _release;

  /// Whether the current showing is the organic once-per-build one — only
  /// that one stamps `lastSeenTesterBuild` on dismissal. A DEVTESTER
  /// preview must not consume the real overlay (DEVONBOARD's `_firstRun`
  /// rationale).
  bool _organicShowing = false;

  @override
  void initState() {
    super.initState();
    _checkForNewBuild();
    widget.services.devTesterTrigger.addListener(_showDevTester);
  }

  @override
  void dispose() {
    widget.services.devTesterTrigger.removeListener(_showDevTester);
    super.dispose();
  }

  Future<void> _checkForNewBuild() async {
    // Testers-only: prod users get the release overlay, never this one.
    if (kEdition == Edition.prod) return;
    // A build carrying a DEV_LABEL is somebody's working copy, not a tester's:
    // the overlay would cover the app on every cold start of the thing they
    // are working on, and dismissing it would burn the once-per-build showing
    // a real tester should get. Only the explicit label counts — a web
    // preview derives its own from the URL, and those ARE handed to testers.
    // DEVTESTER still previews the overlay on demand.
    if (debugEnvFlag(const String.fromEnvironment('DEV_LABEL'), 'DEV_LABEL').isNotEmpty) return;
    final lastSeen = widget.services.settings.lastSeenTesterBuild;
    if (lastSeen >= kBuildNumber) return;
    final notes = await loadTesterNotes();
    // The release cut numbers an entry and bumps kBuildNumber in one commit,
    // so an entry above this build means someone hand-typed a number the
    // tooling would never write — this build still shouldn't promise it.
    final pending = notes.where((entry) => entry.build > lastSeen && entry.build <= kBuildNumber).toList();
    if (pending.isEmpty || !mounted) return;
    // Shown before the backdrop resolves — onboarding mounts synchronously
    // beneath this gate, and every await here extends the window where a
    // fresh install sees it flash before the tester overlay covers it. The
    // photo crossfades in when it arrives, same as everywhere else.
    _organicShowing = true;
    setState(() => _pending = pending);
    final release = await _loadBackdrop();
    if (release != null && mounted && _pending != null) setState(() => _release = release);
  }

  /// DEVTESTER (dev-commands extension) — shows every entry up to the
  /// current build, ignoring the edition and `lastSeenTesterBuild` gates
  /// entirely, for re-previewing the overlay on demand (DEVSPLASH's
  /// sibling). Falls back to the whole file when nothing is ≤ the current
  /// build — the command has already confirmed in the UI, so it must never
  /// no-op. Notes accumulated since the last cut are NOT previewable here:
  /// they live under tester-notes.yaml's `upcoming` key, which the parser
  /// drops until a release names it.
  Future<void> _showDevTester() async {
    // Same edition guard as the organic path — a prod build has no
    // business rendering tester-only content, dev command or not.
    if (kEdition == Edition.prod) return;
    final notes = await loadTesterNotes();
    var pending = notes.where((entry) => entry.build <= kBuildNumber).toList();
    if (pending.isEmpty) pending = notes;
    if (pending.isEmpty || !mounted) return;
    // A preview must never stamp — even one that lands while the organic
    // showing is on screen and replaces its content.
    _organicShowing = false;
    setState(() => _pending = pending);
    final release = await _loadBackdrop();
    if (release != null && mounted && _pending != null) setState(() => _release = release);
  }

  /// The newest release's entry, for the overlay's backdrop photo — or null.
  /// Tolerant the same way onboarding is: a broken/missing release-notes
  /// asset just means no photo (the view falls back to a flat color), not a
  /// broken overlay.
  Future<ReleaseNotesEntry?> _loadBackdrop() async {
    try {
      final notes = await loadReleaseNotes();
      return notes.isNotEmpty ? notes.first : null;
    } catch (error, stackTrace) {
      debugPrint('[tester-overlay] release notes unavailable: $error\n$stackTrace');
      return null;
    }
  }

  void _dismiss() {
    if (_organicShowing) widget.services.settings.setLastSeenTesterBuild(kBuildNumber);
    _organicShowing = false;
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

  /// Always full screen, even on wide layouts — the same presentation choice
  /// as `_OnboardingGate` (not `_ReleaseOverlayGate`'s centered modal): the
  /// two overlays can show back-to-back on a fresh install, and switching
  /// chrome between them would read as a glitch.
  Widget _buildOverlay(BuildContext context, List<TesterNotesEntry> entries) {
    return Positioned.fill(
      child: TesterOverlayView(entries: entries, release: _release, onDismiss: _dismiss),
    );
  }
}

/// A bare `notifyListeners()` signal for the dev commands that force-show a
/// startup overlay: `devSplashTrigger` (DEVSPLASH → release overlay),
/// `devOnboardTrigger` (DEVONBOARD → onboarding overlay) and
/// `devTesterTrigger` (DEVTESTER → tester overlay). Carries no state of its
/// own.
class DevOverlayTrigger extends ChangeNotifier {
  void trigger() => notifyListeners();
}

/// How much room each growable piece of the bottom chrome may take.
///
/// The bottom of the window is shared four ways: the notice stack and the
/// status footer can both grow, the numbers row is a fixed height whenever a
/// focused field publishes one, and the keyboard strip takes whatever the
/// keyboard is using. The app gets what is left — and must not be squeezed to
/// nothing, which is what happens when each of these sizes itself against the
/// whole window on its own and their sum quietly exceeds the strip they share.
///
/// So the sum is bounded here, once, rather than each piece guessing.
///
/// Two of the four pieces do not negotiate: the numbers row is a fixed
/// [NumberKeys.height] whenever a field publishes one, and the footer takes
/// [StatusBarFooter.collapsedHeight] whenever it has anything to say. Those
/// come off the top; what remains is split between the growable chrome and
/// the app, so the app keeps `1 - _chromeShare` of it no matter what.
///
/// "No matter what" only holds if every cap here is one the consumer cannot
/// exceed, so both are TOTALS — the whole stack including its band, the whole
/// expanded footer including its collapsed height. Handing
/// [NoticeStack] a cap for the card alone and paying for the band here lets
/// the stack overrun a tight budget by the whole band (measured at 3pt on a
/// 375pt landscape phone at Largest+ and 5pt at Largest++ with a 210pt
/// keyboard). Chrome a widget adds on its own account has to be that widget's
/// arithmetic.
///
/// Getting this wrong is not hypothetical, and it is not visible in portrait:
/// `UiScale` implements the Font Scale setting by dividing the window AND the
/// insets it hands down (docs/design/ui-scaling.md), while the fixed 52 and 28
/// above stay put. On a landscape phone with the keyboard up, that fixed 80
/// grows from 42% of the space above the keyboard at Normal to all of it at
/// Largest++ — which is how the sum can run past the window and drive the
/// app to zero height.
@visibleForTesting
class BottomChromeBudget {
  /// The cap for the whole notice stack, its band included — the total, which
  /// is what [NoticeStack.maxHeight] means.
  final double noticeMax;

  /// The cap for the whole expanded footer, collapsed height included.
  final double footerMax;

  /// Whether the notice stack got at least the row it needs to be readable.
  ///
  /// False only where the window cannot seat one at all — every other piece
  /// has already yielded by then. The notice is not dropped in that case (it
  /// is where ErrorPolicy puts what the operator must read, so a missing one
  /// is worse than a cramped one); it is reported instead, because an error
  /// raised into a box too small to read is an error nobody was told.
  final bool seatsNotice;

  /// Whether the footer is drawn at all, and whether the numbers row is.
  ///
  /// False where the band cannot fit above the keyboard however the growable
  /// pieces are capped: the field being typed into and the keyboard itself
  /// already take the window between them. Something has to give, and these
  /// two give in this order — status first, then the row — because both come
  /// straight back when the keyboard goes away, and the field does not.
  final bool showFooter;
  final bool showNumbersRow;

  const BottomChromeBudget({
    required this.noticeMax,
    required this.footerMax,
    this.showFooter = true,
    this.showNumbersRow = true,
    this.seatsNotice = true,
  });

  /// The most of the negotiable space the growable chrome may take between
  /// them, so the app always keeps the rest.
  static const double _chromeShare = 0.6;

  /// How that share splits. The notice carries prose and wants the larger part;
  /// the footer's rows are short and it scrolls past its cap anyway. The
  /// footer's part stays reserved while it is collapsed — it can be expanded
  /// by a tap at any time, and a budget that only holds until the user touches
  /// something is not a budget.
  static const double _noticeShare = 0.7;

  /// [numbersRowHeight] and [footerHeight] are passed in rather than read
  /// from the widgets: both are density-resolved now, and this is a plain
  /// factory with no context. Passing them also keeps the arithmetic
  /// testable against any pair of values, which is what the device matrix in
  /// status_bar_keyboard_test does.
  factory BottomChromeBudget.of({
    required double windowHeight,
    required double keyboardInset,
    required bool hasNumbersRow,
    required bool hasStatusItems,
    required double numbersRowHeight,
    required double footerHeight,
    double homeChromeHeight = 0,
    double noticeFloor = 0,
  }) {
    // Only what is actually on screen is charged: the footer collapses to
    // nothing when the caller says it has no band to draw (over a keyboard,
    // with nothing to say), exactly as the row is absent without a spec.
    // [homeChromeHeight] is what the home layer needs for chrome of its OWN —
    // Quick Lookup, which Home draws inside itself — and zero when a view that
    // owns the window has replaced it. It is not part of this band, but it
    // comes out of the same window: a budget blind to it hands the notice and
    // the footer room Home has already spent, and Home overflows rather than
    // the band.
    // What is left once the one piece that cannot yield has taken its share:
    // Quick Lookup is the field the keyboard is up FOR, and dropping it would
    // take away what the operator is typing into.
    final unyielding = windowHeight - keyboardInset - homeChromeHeight;
    // Then status, then the row — dropped rather than overflowing the window,
    // and only with the keyboard up. With it down there is always room, and
    // chrome that came and went on a desktop window would be a flicker with no
    // cause the operator can see. Reachable on a landscape phone at a large
    // Font Scale, where `UiScale` divides the window while the row's and the
    // field's tap-target floors stay put (docs/design/ui-scaling.md): at 1.90
    // the field, its row and the keyboard alone want 16pt more than the window
    // has.
    final tight = keyboardInset > 0;
    final wantedRow = hasNumbersRow ? numbersRowHeight : 0.0;
    final showFooter = !tight || unyielding - wantedRow >= footerHeight;
    final showNumbersRow = !tight || unyielding >= wantedRow;
    final row = showNumbersRow ? wantedRow : 0.0;
    final collapsedFooter = hasStatusItems && showFooter ? footerHeight : 0.0;
    final negotiable = math.max(0.0, unyielding - row - collapsedFooter);
    final chrome = negotiable * _chromeShare;
    // The notice takes its share, or [noticeFloor] — one readable row —
    // whichever is larger. The difference comes out of the FOOTER's share and
    // never out of the app's: the whole point of [_chromeShare] is that the
    // app keeps the rest no matter what, and a floor that borrowed past it
    // would drive the app toward zero to seat a notice, which is the failure
    // this class exists to prevent. Between the two of them the footer is the
    // one that can give — it scrolls past its cap, and its rows are short.
    final noticeMax = math.min(chrome, math.max(chrome * _noticeShare, noticeFloor));
    final footerMax = collapsedFooter + math.max(0.0, chrome - noticeMax);
    return BottomChromeBudget(
      noticeMax: noticeMax,
      footerMax: footerMax,
      showFooter: showFooter,
      showNumbersRow: showNumbersRow,
      seatsNotice: noticeMax >= noticeFloor,
    );
  }
}

/// The navigation rail's state, owned by the ROOT window rather than by a view.
///
/// It lives here because the rail is a sibling of the whole window — every
/// view's header and panes AND the status footer sit to its right. Drawn
/// inside the navigator it would be shortened whenever the footer took height,
/// and its bottom-anchored Settings destination would ride up and down as
/// status items came and went. Navigation must not move because a sync
/// reported progress.
///
/// [visible] follows the route: Home and the Settings it shows in place have
/// it; an operation takes it away.
///
/// One of the destinations the rail can point at — [HomeDestination.logs]
/// only reaches the rail when the `logs` experiment is on, but the state
/// still carries it whether or not it's currently offered, same as the
/// others.
enum HomeDestination { operations, logs, settings }

class HomeRailState extends ChangeNotifier {
  int _covering = 0;
  int _coveringPages = 0;
  bool _expanded = false;
  HomeDestination _destination = HomeDestination.operations;

  /// Whether ANYTHING is on top of the home layer — a pushed view, a dialog, a
  /// modal pane.
  ///
  /// The rail is drawn either side of the routes depending on this, and
  /// nothing else about it changes: it does not hide, narrow, or animate for
  /// navigation. Over the routes it is the window fixture Home sits beside and
  /// can be pressed; under them whatever arrived simply covers it, which is
  /// what a view that owns the window — or a dialog that dims it — should do.
  /// It has to be over them the rest of the time because the overlay a route
  /// lives in takes every pointer that lands in it, and a rail permanently
  /// underneath is a rail nothing can press.
  ///
  /// A COUNT rather than a flag, and driven by the navigator rather than by
  /// one route class opting in ([HomeRailRouteObserver]). Declared by the
  /// route, this is wrong for every route that forgets to declare — a ⌘K jump
  /// to an operation left a live rail pasted over the logging screen, pressing
  /// its Settings destination drove the Home underneath, and nothing said so.
  /// A flag is wrong again the moment two of them stack, since the inner one
  /// clears it on the way out while the outer is still up.
  bool get covered => _covering > 0;

  /// Whether the home layer's own chrome — Quick Lookup — is still on screen.
  ///
  /// Not the same question as [covered]: a dialog covers the rail without
  /// taking Quick Lookup off the window, so the bottom-chrome budget must go
  /// on reserving its height. Only a full page over the top replaces it.
  bool get homeChromeShowing => _coveringPages == 0;

  bool get expanded => _expanded;
  HomeDestination get destination => _destination;

  /// Whichever of [HomeDestination.operations]/[HomeDestination.logs] was
  /// active right before Settings opened — what closing Settings (the rail
  /// entry's own toggle, or its in-pane back button) returns to, rather than
  /// both of those hardcoding [HomeDestination.operations] and silently
  /// dropping out of Logs.
  HomeDestination _lastNonSettingsDestination = HomeDestination.operations;
  HomeDestination get lastNonSettingsDestination => _lastNonSettingsDestination;

  /// Counts one route arriving over the home layer, or leaving it. [page] for
  /// a route that REPLACES what is under it rather than dimming it.
  void coveringChanged(int delta, {required bool page}) => _set(() {
        _covering = math.max(0, _covering + delta);
        if (page) _coveringPages = math.max(0, _coveringPages + delta);
      }, false);

  set expanded(bool value) => _set(() => _expanded = value, _expanded == value);
  set destination(HomeDestination value) => _set(() {
        if (_destination != HomeDestination.settings) _lastNonSettingsDestination = _destination;
        _destination = value;
      }, _destination == value);

  /// Applies a change and tells the shell, deferring when we are inside a
  /// build: a view sets these from `initState`, which runs while the shell
  /// ABOVE it is building, and notifying straight through there is
  /// markNeedsBuild-during-build — refused by the framework, so the rail never
  /// appears and ErrorPolicy keeps the reason off the screen.
  void _set(VoidCallback apply, bool unchanged) {
    if (unchanged) return;
    apply();
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
      return;
    }
    notifyListeners();
  }
}

final homeRail = HomeRailState();

/// Keeps [HomeRailState.covered] in sync with the navigator's route stack.
///
/// Every route above the home layer counts, whatever pushed it and whatever
/// class it is — that is the whole point of observing the navigator instead of
/// asking routes to declare themselves. The bottom route is the home layer
/// itself and is not counted: it is what everything else covers.
class HomeRailRouteObserver extends NavigatorObserver {
  /// The first route pushed is the one the app starts on. Held rather than
  /// counted so a later push of the same class is still counted.
  Route<dynamic>? _homeRoute;

  /// What is currently counted, so no route is released twice — a pop that is
  /// followed by a remove, or an exit animation that finishes after the route
  /// has already gone, must not take a second off the count and expose the
  /// rail over whatever else is up.
  final Set<Route<dynamic>> _counted = {};

  bool _isPage(Route<dynamic> route) => route is PageRoute;

  void _cover(Route<dynamic> route) {
    if (identical(route, _homeRoute)) return;
    if (_counted.add(route)) homeRail.coveringChanged(1, page: _isPage(route));
  }

  void _uncover(Route<dynamic> route) {
    if (_counted.remove(route)) homeRail.coveringChanged(-1, page: _isPage(route));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null && _homeRoute == null) {
      _homeRoute = route;
      return;
    }
    _cover(route);
  }

  /// Released when the route is GONE, not when the pop is asked for.
  ///
  /// `didPop` fires as the pop begins, with the outgoing view still filling
  /// the window for the length of its reverse transition — 400ms for the
  /// operation view. Counting it out there paints the rail over a screen that
  /// is still on its way off and, being topmost, hands it the operator's taps:
  /// a press on Settings mid-slide drives the Home layer under an operation
  /// that is still visible. So the exit animation is what releases it.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final animation = route is TransitionRoute ? route.animation : null;
    if (animation == null || animation.isDismissed) {
      _uncover(route);
      return;
    }
    void whenGone(AnimationStatus status) {
      if (status != AnimationStatus.dismissed) return;
      animation.removeStatusListener(whenGone);
      _uncover(route);
    }

    animation.addStatusListener(whenGone);
  }

  /// A removal has no transition to wait for — the route is off the stack
  /// already. This also covers a pop whose animation never reaches dismissed
  /// because the route was disposed under it.
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _uncover(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      if (identical(oldRoute, _homeRoute)) {
        _homeRoute = newRoute;
        return;
      }
      _uncover(oldRoute);
    }
    if (newRoute != null) _cover(newRoute);
  }
}

final homeRailRouteObserver = HomeRailRouteObserver();

/// Paints the modal barrier over one piece of bottom chrome, and takes its
/// pointers, while a dimming route is up.
///
/// The chrome is drawn OUTSIDE the Navigator — it owns the bottom of the
/// window across every route — so a dialog's own barrier stops at the routes
/// and leaves a lit, pressable footer beside a dimmed window, where a tap
/// opens a second dialog behind the first. Modal means modal.
///
/// [modalBarrierIsVisible] is the app's existing answer to "is something
/// dimming the window?" (it also drives the macOS traffic-light mask), so this
/// and the window chrome cannot disagree about it, and
/// [modalBarrierIsDismissible] carries the top route's own answer, so a dialog
/// that refuses barrier dismissal is not dismissed from down here either. The
/// pop goes through [navigatorKey] because this is drawn above the Navigator
/// and has no Navigator of its own to ask.
///
/// **Never a [ModalBarrier] here**, tempting as it is — the widget whose job
/// this is brings a [BlockSemantics], which drops everything painted BEFORE
/// it, and [HomeRailShell] draws the chrome after the routes. Measured: with
/// one in this slot, opening a dialog left the window with two semantics nodes
/// and none of the dialog's own. So the barrier is hand-rolled, and it takes
/// the chrome out of the semantics tree by covering ITSELF ([ExcludeSemantics]
/// around the child) rather than by blocking what it does not own. That
/// exclusion is not tidiness: with accessibility on, Flutter web hangs a DOM
/// element off every node and that element takes the click before any hit test
/// runs, so a scrim that only absorbed pointers would be clicked through into
/// the bar underneath.
class _ChromeScrim extends StatelessWidget {
  final Widget child;

  const _ChromeScrim({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([modalBarrierIsVisible, modalBarrierIsDismissible]),
      builder: (context, child) {
        final scrimmed = modalBarrierIsVisible.value;
        return Stack(
          children: [
            ExcludeSemantics(excluding: scrimmed, child: child!),
            if (scrimmed)
              Positioned.fill(
                child: ExcludeSemantics(
                  child: GestureDetector(
                    // Opaque with no callback still absorbs, which is what a
                    // non-dismissible barrier has to do: the chrome under it
                    // must not take the tap either way.
                    behavior: HitTestBehavior.opaque,
                    onTap: modalBarrierIsDismissible.value ? () => navigatorKey.currentState?.maybePop() : null,
                    child: ColoredBox(color: haloBarrierColor(context)),
                  ),
                ),
              ),
          ],
        );
      },
      child: child,
    );
  }
}


@visibleForTesting
class StatusBarOverlay extends StatefulWidget {
  final HaLoServices services;
  final Widget child;

  const StatusBarOverlay({super.key, required this.services, required this.child});

  @override
  State<StatusBarOverlay> createState() => _StatusBarOverlayState();
}

class _StatusBarOverlayState extends State<StatusBarOverlay> {
  /// What the last frame's budget gave way on, so the console gets one line
  /// per transition rather than one per frame — this rebuilds on every
  /// progress tick of a sync.
  String? _lastSqueeze;

  /// How long a message stays up over a virtual keyboard before the footer
  /// slides away again.
  ///
  /// The band is permanent everywhere else, but over a keyboard it is taking
  /// its height from the field being typed into, so there it earns its place
  /// only while it has something new to say. The item is NOT cleared — it is
  /// still in `StatusBarService` and comes straight back with the keyboard,
  /// so nothing is lost by having read it late.
  static const _keyboardLinger = Duration(seconds: 5);

  Timer? _lingerTimer;
  bool _lingering = false;

  /// Whether the footer's message list is open. Held HERE rather than inside
  /// [StatusBarFooter] because an open list is modal: it puts a scrim over the
  /// rest of the window, and the widget that draws that scrim is a sibling of
  /// the footer, not a descendant of it. (The permanent statuses open a menu
  /// of their own, which brings its own modality and needs none of this.)
  bool _footerExpanded = false;

  /// The item list as it was when the linger last restarted. Compared rather
  /// than counted: a progress bar refreshing on one key is activity that
  /// should hold the bar up, and so is a message replaced in place, neither
  /// of which changes the count.
  String? _itemSignature;

  @override
  void initState() {
    super.initState();
    widget.services.statusBar.addListener(_onStatusBarChanged);
    _itemSignature = _signatureOf(widget.services.statusBar);
  }

  @override
  void dispose() {
    widget.services.statusBar.removeListener(_onStatusBarChanged);
    _lingerTimer?.cancel();
    super.dispose();
  }

  late final bool _gatoEnabled =
      widget.services.settings.experimentEnabled('gato') /* stored key, see experiments.yaml */;

  /// The permanent statuses, in the order they take the trailing edge of the
  /// bar.
  ///
  /// Built here rather than posted by whoever owns each state: this is the
  /// only place that can see them all, and their ORDER is a property of the
  /// bar. Connectivity comes first because it is the one that answers "why is
  /// nothing updating?".
  List<StatusBarPermaData> _permaStatuses(BuildContext context, bool offline) {
    return [
      StatusBarPermaData(
        key: 'connectivity',
        icon: offline ? MdiIcons.cloudOff : MdiIcons.cloudCheck,
        text: offline ? context.t.offline.statusOffline : context.t.offline.statusOnline,
        onTap: () => showOfflineDetail(
          navigatorKey: navigatorKey,
          onRetry: widget.services.syncEngine.retryNow,
          nextAttemptAt: () => widget.services.syncEngine.nextAttemptAt,
        ),
      ),
      // Only once there is something to count, and only under the experiment
      // that publishes the Peers panel this opens: an operator who has never
      // linked a device is not told "0 devices" — the feature is one they do
      // not use — and a status whose action lands on a panel Settings is
      // hiding is worse than no status.
      if (widget.services.settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */)
        for (final linked in [widget.services.peerService.linkedDeviceIds])
          if (linked.isNotEmpty)
            for (final connected in [linked.where(widget.services.peerService.hasSession).length])
              StatusBarPermaData(
                key: 'peers',
                icon: MdiIcons.lanConnect,
                // The badge is the LIVE count and the line is both numbers: at a
                // glance the question is "is my other device reachable right
                // now", and the total is what makes a 0 mean something.
                badge: '$connected',
                // Nothing reaching anything is a true state worth showing — a
                // peer dropping off is exactly when the operator looks — but it
                // is not one to draw at full strength beside a live one.
                muted: connected == 0,
                text: context.t.settings.peers.statusPerma(connected: connected, linked: linked.length),
                onTap: () {
                  final navigatorContext = navigatorKey.currentContext;
                  if (navigatorContext == null) {
                    // Two gestures deep — the menu opened, an entry chosen — so
                    // a silent no-op is the operator's action disappearing.
                    debugPrint('[status-bar] no navigator for the peers status');
                    return;
                  }
                  showPeersDialog(navigatorContext, widget.services);
                },
              ),
      if (_gatoEnabled) ...[
        for (final uuid in [widget.services.cat.radio1])
          if (uuid != null)
            for (final node in [widget.services.cat.nodeFor(uuid)])
              if (node != null)
                StatusBarPermaData(
                  key: 'radio1',
                  icon: MdiIcons.cat,
                  // Name AND state, in the Station panel's own words
                  // ([equipmentStatusLabel]): the name alone answers "which
                  // rig", which is the question the operator already knows the
                  // answer to — "is it talking to me" is the one they open the
                  // bar for.
                  text: '${widget.services.cat.displayNameFor(node)}: '
                      '${equipmentStatusLabel(context, widget.services.cat.stateFor(uuid))}',
                  // The Radio control's own quick-access pane, not the full
                  // Station Configuration page — the same one tapping the
                  // logging row's Radio chip opens, so the two ways in do not
                  // land somewhere different.
                  onTap: () {
                    final navigatorContext = navigatorKey.currentContext;
                    if (navigatorContext == null) {
                      // Two gestures deep — the menu opened, an entry chosen —
                      // so a silent no-op here is the operator's action
                      // disappearing. It means the chrome outlived the
                      // navigator, which is worth knowing about.
                      debugPrint('[status-bar] no navigator for the radio status');
                      return;
                    }
                    showStationConfigDialog(navigatorContext, widget.services);
                  },
                ),
      ],
    ];
  }

  String _signatureOf(StatusBarService statusBar) =>
      statusBar.items.map((item) => '${item.key}@${item.updatedAt.microsecondsSinceEpoch}').join(',');

  /// Restarts the linger whenever the ITEMS changed. The service also
  /// notifies for notices, which have their own stack and must not hold the
  /// footer up.
  void _onStatusBarChanged() {
    final signature = _signatureOf(widget.services.statusBar);
    if (signature == _itemSignature) return;
    _itemSignature = signature;
    _lingerTimer?.cancel();
    _lingerTimer = Timer(_keyboardLinger, () {
      if (mounted) setState(() => _lingering = false);
    });
    if (_lingering) return;
    _lingering = true;
    // Marking this element dirty during a build is refused by the framework —
    // and the service DOES notify during one (see `DockHost`'s notice
    // plumbing). Deferring a frame there rather than relying on the
    // `ListenableBuilder` below to rebuild for us: it listens to the same
    // service, but only a notification that reaches it AFTER this one shows
    // the flag, and a message posted from inside a build that has already
    // passed this element would simply never appear. Same shape as
    // `HomeRailState._set`.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  /// Puts the message list away when this frame cannot show it — the band
  /// gone under a keyboard, the window too short to seat a footer, or the
  /// items down to the one that shows in full collapsed anyway.
  ///
  /// CLEARED, not masked. A flag left set behind a band that has gone away
  /// re-opens the list the moment the band returns — a scrim over the window
  /// the operator did not ask for and has no memory of asking for — and no
  /// gesture can correct it in the meantime, because the widget that would
  /// report the change is not on screen to be tapped.
  ///
  /// Deferred a frame because this is decided inside `build`.
  void _closeListIfUnopenable(bool listOpen, bool showFooter) {
    if (!_footerExpanded || (listOpen && showFooter)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _footerExpanded) setState(() => _footerExpanded = false);
    });
  }

  /// Says out loud that the window could not seat all of the bottom chrome.
  ///
  /// Nothing else would: the pieces are simply absent, at the one moment the
  /// operator is looking at a field rather than at the chrome, and the setting
  /// that publishes the numbers row still reads ON. Reported from a post-frame
  /// callback because this is decided inside `build`, and reporting there is a
  /// side effect during layout.
  void _reportSqueeze(BottomChromeBudget bottom) {
    final gave = [
      if (!bottom.showFooter) 'the status footer',
      if (!bottom.showNumbersRow) 'the numbers row',
      if (!bottom.seatsNotice) 'a readable notice',
    ];
    final detail = gave.isEmpty ? null : gave.join(' and ');
    if (detail == _lastSqueeze) return;
    _lastSqueeze = detail;
    if (detail == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ErrorReportingService.report(
        BottomChromeSqueezed('no room above the keyboard for $detail'),
        StackTrace.current,
        context: 'bottom-chrome',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // The offline state is a Stream rather than a Listenable, and it belongs
    // OUTSIDE the merged listenable below for a reason the budget makes
    // load-bearing: the indicator opens the footer on its own, so a change to
    // it changes how the bottom of the window is divided up, and a stale read
    // here would hand the notice room the footer has already taken.
    return StreamBuilder<bool>(
      stream: ConnectivityService.offlineChanges,
      initialData: ConnectivityService.isOffline,
      builder: (context, offlineSnapshot) => _buildChrome(context, offlineSnapshot.data ?? false),
    );
  }

  Widget _buildChrome(BuildContext context, bool offline) {
    return ListenableBuilder(
      // All three, because the budget below has to see the numbers row and the
      // home layer: whether a row is published and whether Quick Lookup is on
      // screen both change how much room the notice and the footer get, and
      // listening only to the status bar would leave that stale.
      // `cat` only when Station Configuration is on: it is a `late final` that
      // builds a whole CatService the first time it is touched, and an
      // operator without the experiment must not pay for one just so this can
      // ask it for a radio it cannot have.
      listenable: Listenable.merge([
        widget.services.statusBar,
        widget.services.keyboardAccessory,
        homeRail,
        // The open list's scrim stands down while a dialog is up — see it.
        modalBarrierIsVisible,
        // Both halves of the peer status: the linked devices it counts against
        // (this service caches them) and the live sessions the badge counts,
        // which change on their own as a link comes up or drops.
        widget.services.peerService,
        if (_gatoEnabled) widget.services.cat,
      ]),
      builder: (context, _) {
        final statusBar = widget.services.statusBar;
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

        // This widget owns the bottom of the window while the on-screen
        // keyboard is up — it both RESERVES the keyboard's height and CONSUMES
        // the inset, and the two have to go together.
        //
        // Reserving: this Column's bottom edge is the WINDOW's
        // bottom edge and anything placed there is behind the keyboard. The
        // footer is chrome the operator needs precisely while typing (a
        // sync's progress,
        // a command's output), so instead the keyboard's height is held back
        // below the footer and the footer rides above it. The strip is painted
        // in the app-bar colour — the one the footer and the mobile numbers row
        // already use — so the chrome reads as continuing behind the keyboard
        // instead of flashing a gap during its animation.
        //
        // Consuming: everything below this point must NOT reserve the keyboard
        // again. `removeViewInsets` is what makes that true by construction
        // rather than by asking each descendant to remember. Without it the
        // inset is still in the MediaQuery the routes read, so every stock
        // `Scaffold` (only Home and Operation opt out of resizing) shrinks its
        // own body a second time, and anything padding by `viewInsets.bottom`
        // double-pads — measured as a form squeezed to a third of its height
        // with a keyboard-tall blank band above the keyboard.
        //
        // The two consumers that legitimately still need to know the keyboard
        // is up read the raw `FlutterView` instead (`virtualKeyboardIsUp`,
        // `LoggingControls._bottomReserve`), which this cannot and should not
        // hide from them.
        //
        // Not gated on platform: a desktop window simply reports no bottom
        // inset, while mobile WEB does report one (and the Home Scaffold opts
        // out of resizing there too, so nothing else would hold it back). An
        // iPad's hardware-keyboard accessory bar reports a small one, and
        // reserving for that is right as well — it obscures the bottom exactly
        // like a keyboard does, just less of it.
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

        // How much of the window the chrome below the app may take, divided
        // between the two pieces that can grow. If everything down here
        // sized itself against the WHOLE window independently — the notice at
        // 40% of it, the expanded footer at another 40%, the numbers row at
        // whatever it is — their sum could exceed the strip they share and
        // the Column would overflow, crushing the app to nothing. Capping
        // one piece just moves the overflow to the next; the
        // sum is the thing that has to be bounded, so it is worked out once,
        // here, by the only widget that can see all of them.
        // Over a virtual keyboard the footer is transient: it opens for a new
        // message and slides away once it has been read (see
        // [_keyboardLinger]). Everywhere else — every desktop window, and a
        // phone with the keyboard down — the band is permanent, so the bottom
        // edge of the app does not move as messages come and go.
        //
        // Hiding it is done by handing the widget an EMPTY list rather than by
        // dropping the widget: the footer animates its own collapse, and a
        // removed widget would just vanish.
        final keyboardUp = keyboardInset > 0;
        final footerHidden = keyboardUp && !_lingering;
        // The footer refuses to expand a list of one — a single message shows
        // in full collapsed — so the scrim has to answer to the same rule or
        // it outlives what it covers: dismiss one of two open messages and the
        // band snaps shut while a full-window barrier stays painted over a
        // window with nothing modal in it.
        final listOpen = _footerExpanded && !footerHidden && items.length > 1;
        final footerItems = footerHidden ? const <StatusBarItemData>[] : items;
        // The perma icons go with the items: over a keyboard the whole band
        // is borrowed space, and a row of icons is no more entitled to it
        // than a message is.
        final perma = footerHidden ? const <StatusBarPermaData>[] : _permaStatuses(context, offline);

        final accessory = widget.services.keyboardAccessory.value;
        final hasStatusItems = !keyboardUp || footerItems.isNotEmpty || perma.isNotEmpty;
        final bottom = BottomChromeBudget.of(
          windowHeight: MediaQuery.sizeOf(context).height,
          keyboardInset: keyboardInset,
          hasNumbersRow: accessory != null,
          hasStatusItems: hasStatusItems,
          numbersRowHeight: NumberKeys.heightOf(context),
          // The band's own safe area is part of what a drawn footer takes:
          // it holds the home indicator for the whole window (see
          // [footerHoldsBottomInset]), so a charge of the bar alone leaves
          // the notice and the expanded list a strip of an iPhone that is
          // already spent. Zero with the keyboard up, which is the only state
          // where this term decides whether the footer is drawn at all.
          footerHeight: StatusBarFooter.collapsedHeightOf(context) + MediaQuery.paddingOf(context).bottom,
          // Quick Lookup is chrome for the home layer and nothing else, so it
          // is charged exactly while that layer is showing — a view that owns
          // the window replaces it, and charging for it there would take the
          // room from the notice for a bar that is not on screen. Home draws
          // it itself; what is reserved here is the room it needs.
          //
          // The bar alone, with no safe area added: the home indicator's strip
          // belongs to whoever is drawn over it, and that is the footer
          // whenever there IS a strip to hold (see [footerHoldsBottomInset] —
          // it is the keyboard that takes the strip otherwise, and then the
          // safe area is zero anyway).
          homeChromeHeight: homeRail.homeChromeShowing ? HomeQuickLookup.heightOf(context) : 0,
          // One readable notice, floored the way the footer floors its own
          // expanded cap: the notice is the surface ErrorPolicy raises to, and
          // a share-of-what-is-left that works out to a few points renders the
          // error as a sliver nobody can read and nothing logs.
          noticeFloor: NoticeStack.minHeightOf(context),
        );
        _reportSqueeze(bottom);
        _closeListIfUnopenable(listOpen, bottom.showFooter);

        // A drawn footer paints over the bottom safe area and holds it with a
        // `SafeArea` of its own, so nothing ABOVE it may reserve that strip a
        // second time — a view that does leaves a band of its own background
        // between its last row and the footer. Whether the footer is DRAWN is
        // the whole condition: the widget holds the strip from outside its own
        // switcher, so an empty band still covers it and the two cannot
        // disagree for a frame. Passed to the shell rather than applied here
        // because the rail is the shell's child, not the routes': Quick Lookup
        // and the rail's Settings cap sit side by side across the foot of the
        // home layer and have to answer to this together.
        final footerHoldsBottomInset = bottom.showFooter;

        // The rail runs the full height beside this whole strip, so a status
        // item shortens the views and never the navigation.
        return MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: HomeRailShell(
            services: widget.services,
            routes: widget.child,
            bottomInsetHeldByChrome: footerHoldsBottomInset,
            // An open list is modal: the operator opened it to read it, and a
            // tap anywhere else means "put it away" rather than whatever that
            // spot would otherwise do. Painted, not invisible — a window that
            // silently eats one tap is worse than one that says why.
            // Nothing while a dialog is up. This layer is drawn ABOVE the
            // routes — dialogs included — so a list left holding it would
            // paint over the very dialog its own row just opened. The dialog
            // is the modal thing at that point, its own barrier covers the
            // window, and `_ChromeScrim` covers the bar; the list's scrim
            // comes back when it closes.
            scrim: listOpen && bottom.showFooter && !modalBarrierIsVisible.value
                // A real [ModalBarrier], and here it is the right widget where
                // in the chrome band it is the wrong one: the BlockSemantics
                // it brings drops what was painted BEFORE it, which inside
                // this Stack is the routes and the rail — exactly what it
                // covers — and leaves the band below untouched. That block is
                // load-bearing: with accessibility on, Flutter web hangs a DOM
                // element off every node and that element takes the click
                // before any hit test runs, so a scrim that only absorbed
                // POINTERS would be clicked straight through.
                ? ModalBarrier(
                    color: haloBarrierColor(context),
                    dismissible: true,
                    onDismiss: () => setState(() => _footerExpanded = false),
                  )
                : null,
            chrome: [
              for (final piece in [
              if (notices.isNotEmpty)
                NoticeStack(
                  notices: notices,
                  onDismiss: statusBar.dismissNotice,
                  maxHeight: bottom.noticeMax,
                  dismissLabel: context.t.common.dismiss,
                ),
              if (bottom.showFooter)
                StatusBarFooter(
                  items: footerItems,
                  perma: perma,
                  showWhenEmpty: !keyboardUp,
                  // See [_closeListIfUnopenable]: the flag behind this is
                  // cleared rather than masked, so a list the band took away
                  // does not come back by itself when the band does.
                  expanded: listOpen,
                  onExpandedChanged: (expanded) => setState(() => _footerExpanded = expanded),
                  onDismiss: statusBar.clear,
                  maxExpandedHeight: bottom.footerMax,
                  dismissLabel: context.t.common.dismiss,
                ),
              ])
                // Modal means modal. The chrome is drawn OUTSIDE the
                // Navigator (it owns the bottom of the window across every
                // route), so a dialog's own barrier stops at the routes and
                // leaves a lit, pressable footer beside a dimmed window —
                // where a tap opens a second dialog behind the first, or
                // dismisses a notice the operator cannot see.
                _ChromeScrim(child: piece),
            ],
            keyboard: [
              // The mobile numbers row, published by whichever field has focus
              // (KeyboardAccessoryController). Drawn HERE, below the footer and
              // directly on the keyboard: it reads as an extension of the
              // keyboard, so nothing may come between the two — and the footer
              // is status, which belongs above both. A route cannot achieve
              // that order itself, since the footer is one level up from it.
              //
              // Read straight off the controller rather than through a nested
              // builder: this whole subtree already rebuilds when it changes
              // (see the merged listenable above), and the budget must be
              // computed from the SAME value this renders — a nested builder
              // could show a row the budget above had not accounted for.
              if (accessory != null && bottom.showNumbersRow)
                NumberKeys(
                  onKey: accessory.onKey,
                  extraKey: accessory.extraKey,
                  vibrate: accessory.vibrate,
                  backgroundColor: Color(accessory.backgroundColor),
                  foregroundColor: Color(accessory.foregroundColor),
                ),
              if (keyboardInset > 0)
                SizedBox(
                  width: double.infinity,
                  height: keyboardInset,
                  child: ColoredBox(
                    color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

