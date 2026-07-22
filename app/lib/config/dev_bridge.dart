// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A dev/preview-only bridge for inspecting (and later driving) the running app
// from outside it — so agents and scripts can query app state deterministically
// instead of pixel-hunting the Flutter canvas (ham2k/app-halo-dist#235). This
// read-only first cut exposes a state snapshot; the web installer
// (dev_bridge_installer.dart) surfaces it as `window.__halo`.
//
// Pure Dart with no web import, so it's inert off web and in production: nothing
// installs the JS entry point there, so [stateProvider] is simply never invoked.

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:halo_core/halo_core.dart' show DevLog;

/// The single bridge instance. The active screen registers a [stateProvider];
/// the web installer reads it.
class DevBridge {
  DevBridge._();
  static final DevBridge instance = DevBridge._();

  /// Whether the web entry point was actually installed (dev/preview build on
  /// web) — set by the installer. Screens gate their [stateProvider]
  /// registration on this, so nothing dev-only runs when the bridge is absent
  /// (native, or a production release), and the gate lives in ONE place: extend
  /// the installer's condition and registration follows automatically.
  bool installed = false;

  /// Supplies the current-state snapshot — set by the active screen
  /// (OperationView) on mount and cleared on dispose. Null when no screen has
  /// registered one (e.g. the home screen).
  Map<String, dynamic> Function()? stateProvider;

  /// A JSON-able snapshot of what the app is currently showing/composing, or a
  /// `{'view': 'none'}` placeholder when nothing is registered.
  Map<String, dynamic> state() => stateProvider?.call() ?? <String, dynamic>{'view': 'none'};

  /// Just the current callsign guess (grid/state/name/entityPrefix/…) from the
  /// snapshot, or null.
  Object? guess() => state()['guess'];

  // ── Actions (control side) ────────────────────────────────────────────────
  // Wired by the logging screen (LoggingPanel) to drive LoggingControls; null
  // when no logging screen is active. No-op when unset.

  /// Sets a compose field (`call` today) as if typed.
  void Function(String field, String value)? setFieldHandler;

  /// Performs a compose action (`log`, `wipe`).
  void Function(String action)? actionHandler;

  void setField(String field, String value) => setFieldHandler?.call(field, value);
  void action(String id) => actionHandler?.call(id);

  // ── Fixture reset (#238) ──────────────────────────────────────────────────

  /// Wired in `main()` (when [installed]) to reset the app to a known fixture —
  /// back up then clear operations + QSOs, set font scale/units to defaults,
  /// seed a fresh operation with canned QSOs, and navigate to it. Returns a
  /// summary (`{uuid, qsoCount, backupId, …}`). Null when unregistered.
  ///
  /// Registered asynchronously (after services boot), so a caller should `await`
  /// [ready] before invoking `resetFixture()` — otherwise it hits the no-handler
  /// path below.
  Future<Map<String, dynamic>> Function()? resetFixtureHandler;

  /// Backs `window.__halo.resetFixture()`. A no-op summary when no handler is
  /// registered (native / production, or before boot completes — see above).
  Future<Map<String, dynamic>> resetFixture() =>
      resetFixtureHandler?.call() ?? Future.value(<String, dynamic>{'error': 'no fixture handler'});

  // ── Structured log (#237) ─────────────────────────────────────────────────

  /// Recent structured dev-log events (`[qso]`, `[lookup]`, …), oldest-first —
  /// backs `window.__halo.recentLog()`. Empty unless [DevLog] is enabled (dev
  /// builds). See [DevLog].
  List<Map<String, Object?>> recentLog() => DevLog.instance.recent();

  // ── Readiness (#239) ──────────────────────────────────────────────────────

  Completer<void> _ready = Completer<void>();

  /// Resolves once the app has bootstrapped and the home screen's first data
  /// load (the operations list) has arrived — so agents can `await
  /// window.__halo.ready` instead of sleeping a guessed interval. On native /
  /// production nothing signals or awaits it, so it simply never completes.
  Future<void> get ready => _ready.future;

  /// Marks the app ready. Called once by [HomeView] when its operations stream
  /// first emits, but only while the bridge is [installed]. Idempotent — later
  /// calls (e.g. stream re-emissions, another home mount) are no-ops.
  void signalReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Resets readiness so each test starts from an un-resolved [ready] — the
  /// bridge is a lifetime singleton, so its completer would otherwise stay
  /// completed across tests.
  ///
  /// Tests only, and only before the web installer runs: it captures the
  /// promise from [ready] once (`installDevBridge`), so resetting after that
  /// would leave `window.__halo.ready` bound to the old completer while [ready]
  /// returns a new one.
  @visibleForTesting
  void resetReadyForTest() => _ready = Completer<void>();
}
