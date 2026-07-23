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

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';

import '../config/version.dart' show Edition, kEdition;

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

  bool get _isSupported {
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
    if (!_isSupported) return;
    try {
      await autoUpdater.setFeedURL(feedUrl);
      await autoUpdater.setScheduledCheckInterval(_checkIntervalSeconds);
    } catch (e) {
      // A failed setup must never break startup — just log it.
      debugPrint('[auto-update] setup failed for $feedUrl: $e');
    }
  }

  /// A user-initiated check (the macOS "Check for Updates…" menu item). Unlike
  /// the silent [start] check, this shows the native updater's full UI —
  /// including a "you're up to date" dialog when there's nothing new — because
  /// the user explicitly asked and should get an answer either way.
  Future<void> checkForUpdatesInteractively() async {
    if (!_isSupported) return;
    try {
      await autoUpdater.setFeedURL(feedUrl);
      await autoUpdater.checkForUpdates();
    } catch (e) {
      debugPrint('[auto-update] manual check failed for $feedUrl: $e');
    }
  }
}
