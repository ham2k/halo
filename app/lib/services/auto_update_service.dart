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

import '../config/version.dart' show Edition, kEdition;
import 'error_reporting_service.dart';

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
    if (kIsWeb || kDebugMode) return false;
    if (kEdition == Edition.dev) return false; // Dev has no appcast (§2.6).
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  String get _platform =>
      defaultTargetPlatform == TargetPlatform.windows ? 'windows' : 'macos';

  /// The per-edition, per-platform appcast, e.g.
  /// `https://updates.ham2k.net/halo-next/macos/appcast.xml`. The path is
  /// product-qualified (`halo-<edition>`) so the updates host can namespace
  /// Ham2K products without collision.
  String get feedUrl => '$_baseUrl/halo-${kEdition.name}/$_platform/appcast.xml';

  /// Point the native updater at this build's feed and enable silent scheduled
  /// checks. Deliberately does NOT run an interactive check here: the startup
  /// check must stay silent — Sparkle/WinSparkle's scheduled checks only surface
  /// UI when an update is actually available, never a "you're up to date"
  /// dialog. For an explicit, user-asked check (the "Check for Updates…" menu
  /// item) use [checkForUpdatesInteractively].
  Future<void> start() async {
    if (!isSupported) return;
    try {
      await autoUpdater.setFeedURL(feedUrl);
      await autoUpdater.setScheduledCheckInterval(_checkIntervalSeconds);
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
      await autoUpdater.setFeedURL(feedUrl);
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
      await autoUpdater.setFeedURL(feedUrl);
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
