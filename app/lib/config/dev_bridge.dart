// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A dev-only bridge for inspecting and driving the running app from outside
// it — so agents and scripts can query app state deterministically instead of
// pixel-hunting the Flutter canvas. The installer (dev_bridge_installer.dart)
// surfaces it as `window.__halo` on web and as `ext.halo.*` VM-service
// extensions on every other platform, which `scripts/halo-dev.mjs` calls.
//
// No platform import here, so it is inert in production: nothing installs an
// entry point in a release build, so [stateProvider] is simply never invoked.

import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kDebugMode, kIsWeb, kProfileMode, visibleForTesting;
import 'package:halo_core/halo_core.dart' show DevLog, realNowUtc;

import 'dev_bridge_semantics.dart' as semantics;
import 'dev_flags.dart' show devDataDirectory;
import 'dev_label.dart';
import 'version.dart';

/// The single bridge instance. The active screen registers a [stateProvider];
/// the installer reads it.
class DevBridge {
  DevBridge._();
  static final DevBridge instance = DevBridge._();

  /// Whether an entry point was actually installed (a non-release build) — set
  /// by the installer. Screens gate their [stateProvider] registration on
  /// this, so nothing dev-only runs when the bridge is absent (a production
  /// release), and the gate lives in ONE place: extend the installer's
  /// condition and registration follows automatically.
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

  /// The fields [setFieldHandler] sets: the ones LoggingControls' dev
  /// setter (`_devSetField` in halo_widgets) handles. Any other is refused
  /// here rather than dropped there.
  static const settableFields = {'call'};

  /// Sets [field] through [setFieldHandler], answering `{set: field}`, or an
  /// error when no logging screen is open or the field is not settable.
  Map<String, dynamic> setField(String field, String value) {
    final handler = setFieldHandler;
    if (handler == null) return {'error': 'no logging screen is open'};
    if (!settableFields.contains(field)) return {'error': 'only ${settableFields.join(', ')} can be set, not "$field"'};
    handler(field, value);
    return {'set': field};
  }

  void action(String id) => actionHandler?.call(id);

  /// The compose actions [actionHandler] performs directly, without going
  /// through the semantics tree.
  static const composeActions = {'log', 'wipe'};

  /// Taps [target]: a compose action ([composeActions]) through the logging
  /// screen, anything else through the semantics tree — by its stable
  /// identifier (`action.log`, `qso.row.W1AW`), else its label, exact before
  /// contained. A target that matches several controls taps none and lists
  /// them, so a script never presses a button it did not mean — which is
  /// also why a compose action with no logging screen open is refused, not
  /// matched against whatever label happens to contain "log".
  Future<Map<String, dynamic>> tap(String target) async {
    if (composeActions.contains(target)) {
      final handler = actionHandler;
      if (handler == null) return {'error': 'no logging screen is open for "$target"'};
      handler(target);
      return {'tapped': target};
    }
    return semantics.tapTarget(target);
  }

  /// Every control [tap] can reach on screen right now, as
  /// `{identifier?, label}`.
  Future<List<Map<String, dynamic>>> targets() => semantics.tapTargets();

  // ── Command text ──────────────────────────────────────────────────────────

  /// Runs command text the way a bound key does — wired by `HaLoApp`, which
  /// owns that path. Null before the app shell mounts.
  Future<Map<String, dynamic>> Function(String text)? runCommandHandler;

  /// Runs [text] (`SEED 20`, `DEVTT +3h`, `20M; CW`) in one call, against the
  /// operation in front. Driving the ⌘K dialog for the same thing takes four
  /// calls with waits between them, and its first open after a cold boot can
  /// outlast the wait [openCommandBar] allows.
  Future<Map<String, dynamic>> runCommand(String text) =>
      runCommandHandler?.call(text) ?? Future.value(<String, dynamic>{'error': 'the app shell has not mounted yet'});

  // ── Command dialog (⌘K) ───────────────────────────────────────────────────
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

  Map<String, dynamic> commandBarState() => commandBarStateProvider?.call() ?? <String, dynamic>{'open': false};

  // ── Fixture reset ─────────────────────────────────────────────────────────

  /// Wired in `main()` (when [installed]) to reset the app to a known fixture —
  /// back up then clear operations + QSOs, set font scale/units to defaults,
  /// seed a fresh operation with canned QSOs, and navigate to it. Returns a
  /// summary (`{uuid, qsoCount, backupId, …}`). Null when unregistered.
  ///
  /// Registered asynchronously (after services boot), so a caller should `await`
  /// [ready] before invoking `resetFixture()` — otherwise it hits the no-handler
  /// path below.
  Future<Map<String, dynamic>> Function()? resetFixtureHandler;

  /// Wired in `main()` with [resetFixtureHandler]: connects this session to
  /// an extension dev server, or with null disconnects it. Nothing is saved,
  /// as with the `HALO_EXT_DEV_SERVER` launch flag. Answers the client's state.
  Future<Map<String, dynamic>> Function(String? url)? devServerHandler;

  /// Backs `window.__halo.connectDevServer(url)` and `disconnectDevServer()`.
  Future<Map<String, dynamic>> devServer(String? url) => devServerHandler?.call(url) ?? Future.value(<String, dynamic>{'error': 'no dev server handler'});

  /// Backs `window.__halo.resetFixture()`. A no-op summary when no handler is
  /// registered (production, or before boot completes — see above).
  Future<Map<String, dynamic>> resetFixture() => resetFixtureHandler?.call() ?? Future.value(<String, dynamic>{'error': 'no fixture handler'});

  // ── Stored data ───────────────────────────────────────────────────────────

  static const _servicesNotUp = "the app's services are not up: still starting, or the boot failed (halo-dev log --errors)";

  /// Wired in `main()` once services exist (`devSettings`, `devSql`); null
  /// before then.
  Future<Map<String, Object?>> Function(String match)? settingsProvider;
  Future<Map<String, Object?>> Function(String query)? sqlHandler;

  /// The stored preferences whose key contains [match], as `{settings}`.
  Future<Map<String, Object?>> settings(String match) => settingsProvider?.call(match) ?? Future.value({'error': _servicesNotUp});

  /// One read-only SQL statement against the app's database, as `{columns,
  /// rows, rowCount, truncated}`, or `{error}`.
  Future<Map<String, Object?>> sql(String query) => sqlHandler?.call(query) ?? Future.value({'error': _servicesNotUp});

  // ── Structured log ────────────────────────────────────────────────────────

  /// Recent structured dev-log events (`[qso]`, `[lookup]`, …), oldest-first —
  /// backs `window.__halo.recentLog()`. Empty unless [DevLog] is enabled (dev
  /// builds). See [DevLog].
  List<Map<String, Object?>> recentLog() => DevLog.instance.recent();

  // ── Build identity ────────────────────────────────────────────────────────

  /// The checkout the launcher built this from (`HALO_DEV_WORKTREE`), empty
  /// for a build started some other way.
  static const worktree = String.fromEnvironment('HALO_DEV_WORKTREE');

  /// When this launch started (real time, not the travelled clock: it says
  /// when the process began, which time travel does not change).
  final DateTime launchedAt = realNowUtc();

  /// The extension bundles the running runtime loaded, keyed by extension:
  /// `{origin, file, sha256}`. Wired in `main()` once services exist.
  Map<String, Map<String, String>> Function()? extensionBundlesProvider;

  /// Which build this is and what it is running — what a script compares
  /// against the checkout to tell a stale build from a fresh one.
  Map<String, dynamic> build() => {
    'sha': kGitSha,
    'edition': kEdition.name,
    'label': devLabel,
    'worktree': worktree,
    'dataDirectory': devDataDirectory,
    'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'mode': kDebugMode ? 'debug' : (kProfileMode ? 'profile' : 'release'),
    'launchedAt': launchedAt.toIso8601String(),
    'extensions': extensionBundlesProvider?.call() ?? const <String, Map<String, String>>{},
  };

  // ── Readiness ─────────────────────────────────────────────────────────────

  Completer<void> _ready = Completer<void>();

  /// Resolves once the app has bootstrapped and the home screen's first data
  /// load (the operations list) has arrived — so agents can `await
  /// window.__halo.ready` (or `halo-dev ready`) instead of sleeping a guessed
  /// interval. In production nothing signals or awaits it, so it simply never
  /// completes.
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
  /// Tests only, and only before the installer runs: it captures the
  /// promise from [ready] once (`installDevBridge`), so resetting after that
  /// would leave `window.__halo.ready` bound to the old completer while [ready]
  /// returns a new one.
  @visibleForTesting
  void resetReadyForTest() => _ready = Completer<void>();
}
