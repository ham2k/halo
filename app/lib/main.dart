// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// App shell for phase 2 (core logging loop). Deliberately thin: opens the
// database, builds the repositories, and hands them to the screens. State
// management stays at "constructor injection + streams" until it earns more
// machinery — the database is the source of truth (DESIGN.md §6).
//
// What this wires lives beside what it wires: services/halo_services.dart
// (the service graph), services/bootstrap.dart, services/app_exit.dart,
// services/deep_link_router.dart, and views/app_shell/ (the widget tree
// above the home view). Lib code imports those files directly —
// entry_point_not_imported_test.dart holds it to that — and the exports
// below exist for the tests, which reach the app through its entry point.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsBinding;
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'views/map/map_gl_script.dart' show preloadMapGlLibrary;
import 'views/operation_view.dart';
import 'config/dev_bridge.dart';
import 'config/dev_bridge_installer.dart';
import 'services/app_storage.dart' show databaseFilePath;
import 'services/auto_update_service.dart';

import 'services/build_freshness_service.dart';
import 'services/connectivity_service.dart';
import 'services/error_reporting_backend.dart';

import 'services/error_reporting_service.dart';
import 'services/metrics_service.dart';
import 'services/purchase_service.dart';
import 'services/restart_service.dart';
import 'services/spots_status_reporter.dart';
import 'services/view_focus_guard.dart';
import 'services/hardware_keyboard_service.dart';
import 'services/window_chrome_service.dart';
import 'services/update_check_service.dart';
import 'services/update_service.dart';
import 'services/update_notices.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'config/navigation.dart';
import 'services/bootstrap.dart';
import 'services/deep_link_router.dart';
import 'services/dev_fixture_reset.dart';
import 'views/app_shell/boot_gate.dart';

export 'config/navigation.dart';
export 'services/deep_link_router.dart';
export 'services/peer/peer_pairing_prompt.dart';
export 'services/dev_fixture_reset.dart';
export 'views/app_shell/boot_gate.dart';
export 'services/bootstrap.dart';
export 'services/app_exit.dart';
export 'services/halo_services.dart';
export 'services/command_actions.dart';
export 'views/app_shell/halo_app.dart';
export 'views/app_shell/onboarding_gate.dart';
export 'views/app_shell/release_overlay_gate.dart';
export 'views/app_shell/tester_overlay_gate.dart';
export 'services/dev_overlay_trigger.dart';
export 'views/app_shell/bottom_chrome_budget.dart';
export 'views/app_shell/home_rail_state.dart';
export 'views/app_shell/status_bar_overlay.dart';

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
  unawaited(
    ErrorReportingService.run(
      () => _mainBody(launchArguments: launchArguments, metrics: metrics, purchases: purchases, updates: updates, updateCheck: updateCheck),
      backend: errorReporting,
    ),
  );
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
  // Reads the bundled MapLibre library into memory. Not awaited: the Map tab
  // cannot be open before the first frame, and the page build that needs it
  // reads a plain String rather than a Future precisely so the web view is
  // never gated on I/O (see map_gl_script.dart).
  unawaited(preloadMapGlLibrary());
  final servicesFuture = bootstrap(metrics: metrics, purchases: purchases, updates: updates, updateCheck: updateCheck);
  runApp(TranslationProvider(child: BootGate(servicesFuture: servicesFuture)));

  servicesFuture
      .then((services) async {
        // One app_started per launch, with the UI preferences app-polo's
        // matching event carries (consent-gated inside track, like everything).
        services.track('app_started', {
          'language': resolveLocaleSetting(services.settings.locale).languageTag,
          // The EFFECTIVE scheme, not the ThemeMode: the enum interpolates to
          // "ThemeMode.dark", and `system` describes the setting rather than what
          // the user is actually looking at. app-polo reports the same way.
          'colorScheme': switch (services.settings.themeMode) {
            ThemeMode.dark => 'dark',
            ThemeMode.light => 'light',
            ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark ? 'dark' : 'light',
          },
          'fontScale': services.settings.fontScale.name,
        });
        ErrorReportingService.attachStatusBar(services.statusBar);
        ErrorReportingService.attachSettings(services.settings, databasePath: await databaseFilePath());
        BuildFreshnessService(statusBar: services.statusBar).start();
        services.extensions.observeAppLifecycle();

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
        unawaited(
          services.updates.checkAndApply().then((updated) {
            if (updated) showPatchReadyNotice(services.statusBar, const RestartService());
          }),
        );

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
        unawaited(const AutoUpdateService().start(automaticChecks: services.settings.automaticUpdateChecks));

        listenForDeepLinks(services);
        listenForOpenedExtensionFiles(services);
        // Windows and Linux deliver an opened document as an argument to a FRESH
        // process, so there is no callback to wait for — it is simply already
        // here. An instance that is already running gets nothing, which is the
        // same limitation their deep links have.
        // The first only. Several would stack consent dialogs on top of each
        // other, which is exactly what the drop target refuses for the same
        // reason.
        final bundleArg = launchArguments.where((a) => a.toLowerCase().endsWith('.h2kext')).firstOrNull;
        if (bundleArg != null) openInstallExtension(services, Uri.file(bundleArg));

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
        final openFirstOp = isDevFlagSet(openFirstOpDefine) || (!kIsWeb && isDevFlagSet(Platform.environment['POLO_OPEN_FIRST_OP'] ?? ''));
        debugPrint('[boot] openFirstOp=$openFirstOp (define="$openFirstOpDefine")');
        if (openFirstOp) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            final operations = await services.operations.watchAll().first;
            if (operations.isNotEmpty) {
              unawaited(
                navigatorKey.currentState?.push(
                  MaterialPageRoute<void>(
                    builder: (_) => OperationView(services: services, operationUuid: operations.first.uuid),
                  ),
                ),
              );
            }
          });
        }
      })
      .catchError((Object error, StackTrace stackTrace) {
        // BootGate's own catchError (below) is what surfaces this to the user;
        // this one only exists so bootstrap() failing doesn't also throw an
        // unrelated unhandled-rejection for the openFirstOp dev nicety above.
        debugPrint('[boot] bootstrap() failed: $error');
      });
}
