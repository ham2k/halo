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

  // ── Command dialog (⌘K, #55) ──────────────────────────────────────────────
  // The shortcut itself cannot be driven from outside: synthetic modifier
  // combos don't reach the Flutter canvas (a plain `key "ctrl+k"` no-ops, and
  // so does the pre-existing ⌘⇧D), so without these the dialog is
  // unreachable to any script or agent — it can't even be looked at.

  /// Opens the command dialog. Wired by `HaLoApp`, which owns the shortcut.
  void Function()? openCommandBarHandler;

  /// Dismisses it. Also `HaLoApp`'s, for the same reason.
  void Function()? closeCommandBarHandler;

  Completer<void>? _commandBarOpened;

  /// Opens the dialog and resolves once it's actually mounted and
  /// registered.
  ///
  /// Awaitable on purpose: the route mounts a frame after the call, so a
  /// caller that immediately reads [commandBarState] or calls
  /// [setCommandText] gets `{'open': false}` and a silent no-op — which
  /// looks exactly like the dialog having closed itself.
  Future<void> openCommandBar() {
    if (commandBarStateProvider != null) return Future.value();
    // Nothing to open yet — the app is still booting, or this isn't a build
    // with a UI attached. Resolve rather than leaving the caller hanging on
    // a promise that can never complete.
    final handler = openCommandBarHandler;
    if (handler == null) return Future.value();
    final completer = _commandBarOpened = Completer<void>();
    handler();
    // A bounded wait for the same reason: if the route somehow doesn't mount
    // (no navigator context), the caller gets control back and can see for
    // itself via [commandBarState] that nothing opened.
    return completer.future.timeout(const Duration(seconds: 2), onTimeout: () {});
  }

  /// Called by the dialog once it has registered. Resolves [openCommandBar].
  void signalCommandBarOpen() {
    final completer = _commandBarOpened;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  /// Dismisses the dialog. A no-op when it isn't up — popping blind would
  /// take whatever route happened to be on top instead.
  void closeCommandBar() {
    if (commandBarStateProvider == null) return;
    closeCommandBarHandler?.call();
  }

  /// Types [text] into the open dialog, as if entered. Registered by
  /// `CommandDialog` while it's up; a no-op when it isn't.
  void Function(String text)? commandTextHandler;

  /// Runs whatever the dialog currently has selected — the Enter key.
  void Function()? commandSubmitHandler;

  /// Moves the dialog's selection by [delta] rows — the arrow keys.
  void Function(int delta)? commandMoveHandler;

  void setCommandText(String text) => commandTextHandler?.call(text);
  void commandSubmit() => commandSubmitHandler?.call();
  void commandMove(int delta) => commandMoveHandler?.call(delta);

  /// What the dialog is showing: its text, the visible rows, which is
  /// selected, and how far the callsign lookup has got. `{'open': false}`
  /// when it isn't up.
  Map<String, dynamic> Function()? commandBarStateProvider;

  Map<String, dynamic> commandBarState() =>
      commandBarStateProvider?.call() ?? <String, dynamic>{'open': false};


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
