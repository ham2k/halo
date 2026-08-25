// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Desktop binary self-update via a Sparkle-style appcast (docs/releases.md
// §3.2), driven by the `auto_updater` plugin — Sparkle on macOS, WinSparkle on
// Windows. The native updater UI handles the "update available" prompt,
// download, and install; we only point it at the right per-edition feed and
// kick off a check. The feed is signed with our EdDSA key (public key in the
// macOS Info.plist / WinSparkle config); artifacts + appcasts live on R2.
//
// Active only where a self-update makes sense:
//   - desktop only (mobile updates via the stores/APK, web reloads on load),
//   - release builds only (a debug build has no signed artifact to update to),
//   - not the Dev edition (it ships with no appcast, §2.6).
// Everywhere else `start()` is a no-op, so it is safe to call unconditionally
// at boot. It never throws into the caller — a missing feed or offline box must
// not disturb startup.

import 'dart:async';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';

import '../config/version.dart' show Edition, kBuildNumber, kEdition;
import 'error_reporting_service.dart';
import 'restart_service.dart' show quitThroughFramework;
import 'winsparkle_config.dart';

/// Signature of [configureWinSparkleBeforeInit], so a test can stand in for it
/// — see [AutoUpdateService.debugConfigureWinSparkle].
typedef WinSparkleConfigurator = bool Function({
  required String buildVersion,
  required int checkIntervalSeconds,
  required bool automaticChecks,
});

/// Outcome of a [AutoUpdateService.checkSilently] call.
enum SparkleCheckResult { upToDate, updateAvailable, error }

/// One-shot [UpdaterListener] that resolves [result] on the first terminal
/// Sparkle/WinSparkle event and ignores the rest.
class _SilentCheckListener with UpdaterListener {
  final _result = Completer<SparkleCheckResult>();
  Future<SparkleCheckResult> get result => _result.future;

  void _resolve(SparkleCheckResult value) {
    if (!_result.isCompleted) _result.complete(value);
  }

  @override
  void onUpdaterUpdateAvailable(AppcastItem? appcastItem) => _resolve(SparkleCheckResult.updateAvailable);
  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) => _resolve(SparkleCheckResult.upToDate);
  @override
  void onUpdaterError(UpdaterError? error) => _resolve(SparkleCheckResult.error);
  @override
  void onUpdaterCheckingForUpdate(Appcast? appcast) {}
  @override
  void onUpdaterUpdateDownloaded(AppcastItem? appcastItem) {}
  @override
  void onUpdaterBeforeQuitForUpdate(AppcastItem? appcastItem) {}
}

/// Quits the app when WinSparkle is about to install an update.
///
/// WINDOWS ONLY, and load-bearing there. WinSparkle launches the installer and
/// then asks the host to shut down; it never terminates the host itself, and
/// `auto_updater_windows` implements that callback by forwarding this event and
/// nothing else — so without this the app stays up. It and the crash handler it
/// spawned then hold every file in the install folder open, the installer stops
/// on files-in-use, and the operator's only way forward is Task Manager.
///
/// NOT macOS: there this same event comes from Sparkle's
/// `willInstallUpdateOnQuit`, which means "installed whenever you next quit",
/// not "quit now" — quitting on it would close the app out from under the
/// operator the moment a background download finished. Sparkle terminates the
/// app itself when it does install, through `NSApp.terminate`, which reaches
/// the same exit hook this does.
class _QuitForUpdateListener with UpdaterListener {
  @override
  void onUpdaterBeforeQuitForUpdate(AppcastItem? appcastItem) {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    final quit = (kDebugMode ? AutoUpdateService.debugQuitForUpdate : null) ?? quitThroughFramework;
    unawaited(quit('auto-update'));
  }

  @override
  void onUpdaterCheckingForUpdate(Appcast? appcast) {}
  @override
  void onUpdaterUpdateAvailable(AppcastItem? appcastItem) {}
  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) {}
  @override
  void onUpdaterUpdateDownloaded(AppcastItem? appcastItem) {}
  @override
  void onUpdaterError(UpdaterError? error) {}
}

class AutoUpdateService {
  const AutoUpdateService();

  /// Base URL of the update host (Cloudflare R2 behind updates.ham2k.net).
  /// Overridable at build time for staging via
  /// `--dart-define=HALO_UPDATES_BASE_URL=…`.
  static const _baseUrl = String.fromEnvironment(
    'HALO_UPDATES_BASE_URL',
    defaultValue: 'https://updates.ham2k.net',
  );

  /// How often the native updater re-checks in the background. Sparkle's floor
  /// is one hour; anything lower is clamped.
  static const _checkIntervalSeconds = 3600;

  /// Whether a self-update makes sense on this build at all (see the file
  /// comment) — public so callers (e.g. the About panel's "Check for
  /// Updates" row) can decide whether to offer this mechanism.
  bool get isSupported {
    // The kDebugMode guard is load-bearing, not belt-and-braces: unguarded,
    // any non-test write to the override would short-circuit the web, Dev and
    // platform gates below in a shipped build, pointing Sparkle at a feed no
    // such build has (_platform falls through to macos-universal off Windows).
    if (kDebugMode && debugSupportedOverride != null) return debugSupportedOverride!;
    if (kIsWeb || kDebugMode) return false;
    if (kEdition == Edition.dev) return false; // Dev has no appcast (§2.6).
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  /// The R2 prefix segment for this build's feed. Names the VARIANT, not just
  /// the OS, so a future arm64-only or Intel-only macOS build can ship its own
  /// feed rather than fighting over one path (same reasoning as linux-x64 vs
  /// linux-arm64).
  ///
  /// CHANGING THIS STRANDS EVERY EXISTING INSTALL. Each app polls the URL baked
  /// into it, so a build that starts asking for a new path leaves everything
  /// already installed asking for the old one - which 404s, silently, forever.
  /// The old path must keep serving this same appcast until those installs have
  /// taken an update; see LEGACY_APPCAST_PREFIXES in app_dist/ci/build-macos.sh.
  String get _platform => defaultTargetPlatform == TargetPlatform.windows
      ? 'windows-x64'
      : 'macos-universal';

  /// The per-edition, per-platform appcast, e.g.
  /// `https://updates.ham2k.net/halo-next/macos/appcast.xml`. The path is
  /// product-qualified (`halo-<edition>`) so the updates host can namespace
  /// Ham2K products without collision.
  String get feedUrl => '$_baseUrl/halo-${kEdition.name}/$_platform/appcast.xml';

  /// The process-wide [_QuitForUpdateListener], registered by [start]. Held so
  /// it is added exactly once — the plugin's listener list is a plain `List`,
  /// so a second `addListener` would quit the app twice over.
  static _QuitForUpdateListener? _quitListener;

  /// The in-flight or completed one-and-only configuration call, shared by
  /// every caller. See [_ensureConfigured].
  static Future<void>? _configureCall;

  /// The operator's [SettingsService.automaticUpdateChecks], handed over by
  /// [start] at boot.
  ///
  /// Held rather than passed because the configuration runs once per process
  /// and any caller may be the one to trigger it, while only [start] — which
  /// runs first, unconditionally, from bootstrap — has the settings in hand.
  /// The default matches the setting's own: an operator who never opens
  /// Settings still hears about a release.
  static bool _automaticChecks = true;

  /// Whether the automatic-check preference is ours to honour on this
  /// platform, so the About panel knows whether to offer the switch at all.
  /// Windows only: macOS has no binding for it here and Sparkle asks the user
  /// directly, so a switch there would be a control that changes nothing.
  bool get ownsAutomaticCheckSetting =>
      isSupported && defaultTargetPlatform == TargetPlatform.windows;

  /// Configures the native updater — the Windows-only settings the plugin
  /// exposes no channel for, the feed URL, and the scheduled-check interval —
  /// **exactly once per process**.
  ///
  /// `setFeedURL` is not idempotent on Windows. `auto_updater_windows`
  /// registers the Flutter event sink inside its `setFeedURL` handler and does
  /// it by *moving* the plugin's `unique_ptr`, so a second call hands
  /// WinSparkle a moved-from (null) sink and every later native callback is
  /// silently dropped — [checkSilently] then times out instead of resolving,
  /// and the About panel's row reports "up to date" no matter what the appcast
  /// says. It also re-runs `win_sparkle_init()`, which WinSparkle expects once.
  /// macOS holds its sink in a plain field and tolerates repeat calls, which is
  /// why this only ever broke Windows.
  ///
  /// A failure is deliberately not memoized: a boot that could not reach the
  /// updater (offline, plugin not yet up) must not strand every later check.
  /// The interval is set here rather than in [start] for the same reason —
  /// left there, a boot that threw would skip it and nothing would ever apply
  /// it again, leaving the process on the native default for its whole life.
  Future<void> _ensureConfigured() async {
    final call = _configureCall ??= () async {
      // BEFORE setFeedURL, always. That handler is where the Windows plugin
      // runs win_sparkle_init(), and everything this configures is documented
      // before-init only (winsparkle_config_io.dart says which and why).
      // No-op off Windows, where the plugin leaves nothing unexposed.
      final configure = (kDebugMode ? debugConfigureWinSparkle : null) ?? configureWinSparkleBeforeInit;
      final configured = configure(
        buildVersion: kBuildNumber.toString(),
        checkIntervalSeconds: _checkIntervalSeconds,
        automaticChecks: _automaticChecks,
      );

      await autoUpdater.setFeedURL(feedUrl);

      // Redundant on Windows once the shim has run, and it lands after init
      // there, which is out of contract — so let the shim own it when it can.
      if (!configured) await autoUpdater.setScheduledCheckInterval(_checkIntervalSeconds);
    }();
    try {
      await call;
    } catch (_) {
      if (identical(_configureCall, call)) _configureCall = null;
      rethrow;
    }
  }

  /// Test seam. [isSupported]'s `kDebugMode` gate makes this service inert in
  /// every test binary, so without an override the once-per-process contract
  /// above — the thing whose regression silently breaks Windows — cannot be
  /// observed by any test at all.
  @visibleForTesting
  static bool? debugSupportedOverride;

  /// Test seam for the WinSparkle shim. The real one resolves symbols that
  /// exist only on Windows, so the ordering contract it depends on — every
  /// setting applied BEFORE the plugin's setFeedURL runs win_sparkle_init() —
  /// is otherwise unobservable from any other platform, and a violation is
  /// silent: WinSparkle ignores a late call rather than failing it.
  ///
  /// Read only under [kDebugMode], for the same reason as
  /// [debugSupportedOverride]: it must not be able to divert a shipped build.
  @visibleForTesting
  static WinSparkleConfigurator? debugConfigureWinSparkle;

  /// Test seam for the quit itself, which otherwise ends the test binary.
  /// Read only under [kDebugMode], for the same reason as the seams above.
  @visibleForTesting
  static Future<void> Function(String logTag)? debugQuitForUpdate;

  @visibleForTesting
  static void debugResetConfiguration() {
    _configureCall = null;
    _automaticChecks = true;
    if (_quitListener != null) autoUpdater.removeListener(_quitListener!);
    _quitListener = null;
  }

  /// Point the native updater at this build's feed and hand it the operator's
  /// scheduled-check preference — [automaticChecks], which turns those checks
  /// off as readily as on.
  ///
  /// Deliberately does NOT run an interactive check here: the startup check
  /// must stay silent — Sparkle/WinSparkle's scheduled checks only surface UI
  /// when an update is actually available, never a "you're up to date"
  /// dialog. For an explicit, user-asked check (the "Check for Updates…" menu
  /// item) use [checkForUpdatesInteractively].
  Future<void> start({bool automaticChecks = true}) async {
    _automaticChecks = automaticChecks;
    if (!isSupported) return;
    if (_quitListener == null) autoUpdater.addListener(_quitListener = _QuitForUpdateListener());
    try {
      await _ensureConfigured();
    } catch (e, st) {
      // A failed setup must never break startup — just log it.
      debugPrint('[auto-update] setup failed for $feedUrl: $e');
      ErrorReportingService.report(e, st, context: 'auto-update:start');
    }
  }

  /// A user-initiated check (the macOS "Check for Updates…" menu item). Unlike
  /// the silent [start] check, this shows the native updater's full UI —
  /// including a "you're up to date" dialog when there's nothing new — because
  /// the user explicitly asked and should get an answer either way.
  Future<void> checkForUpdatesInteractively() async {
    if (!isSupported) return;
    try {
      await _ensureConfigured();
      await autoUpdater.checkForUpdates();
    } catch (e, st) {
      debugPrint('[auto-update] manual check failed for $feedUrl: $e');
      ErrorReportingService.report(e, st, context: 'auto-update:check-interactively');
    }
  }

  /// A silent check with a structured result — for a status row (the About
  /// panel's "Check for Updates") that wants to report an outcome itself
  /// rather than delegate entirely to native UI. Uses `inBackground: true`,
  /// which (like [start]'s scheduled check) only surfaces the native
  /// "update available" prompt, never a "you're up to date" dialog — so this
  /// is safe to run automatically (e.g. on opening the About panel).
  ///
  /// `AutoUpdater`'s listener list is a single global broadcast stream, not
  /// scoped per call — if this check happens to overlap with an unrelated
  /// terminal event (the scheduled background check, or a concurrent
  /// [checkForUpdatesInteractively]), that event, not necessarily the
  /// response to the `checkForUpdates` call made here, could resolve this
  /// one first. In practice the reported status is still accurate (it
  /// reflects the feed's real current state); this just isn't a guarantee
  /// that the result came from *this specific* request.
  Future<SparkleCheckResult> checkSilently() async {
    if (!isSupported) return SparkleCheckResult.upToDate;
    final listener = _SilentCheckListener();
    autoUpdater.addListener(listener);
    try {
      await _ensureConfigured();
      await autoUpdater.checkForUpdates(inBackground: true);
      // The native updater always fires a terminal event, but don't hang
      // forever on a wedged plugin/offline box.
      return await listener.result.timeout(
        const Duration(seconds: 20),
        onTimeout: () => SparkleCheckResult.error,
      );
    } catch (e, st) {
      debugPrint('[auto-update] silent check failed for $feedUrl: $e');
      ErrorReportingService.report(e, st, context: 'auto-update:check-silently');
      return SparkleCheckResult.error;
    } finally {
      autoUpdater.removeListener(listener);
    }
  }
}
