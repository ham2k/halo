// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Platform boundary for the JS engine. QuickJS (packages/halo_quickjs, via
// dart:ffi) backs native platforms; web has no dart:ffi, so it runs the same kernel +
// extension bundles in a real Web Worker instead, talking to it over
// postMessage. See engine_runtime_io.dart / engine_runtime_web.dart and
// js_engine.dart for the conditional-export wiring.

class ExtensionBundle {
  final String key;
  final String source;

  const ExtensionBundle({required this.key, required this.source});
}

class ExtensionHostException implements Exception {
  final String message;
  ExtensionHostException(this.message);

  @override
  String toString() => 'ExtensionHostException: $message';
}

/// A call the host stopped waiting for. Its own type because it is the one
/// failure with work worth salvaging behind it — hooks that already answered
/// — which `invokeHookAll`'s `partialOnTimeout` returns and every other
/// failure has no equivalent of. Callers that only care that something went
/// wrong still catch [ExtensionHostException].
class HookTimeoutException extends ExtensionHostException {
  HookTimeoutException(super.message);

  @override
  String toString() => 'HookTimeoutException: $message';
}

abstract class EngineRuntime {
  String get engineDescription;

  /// Registers the callback invoked for every message the JS side posts on
  /// the 'polo' channel: {type:'result'|'log'|'hostCall', ...}. Must be
  /// called before [load].
  void onMessage(void Function(Map<String, dynamic> message) callback);

  /// Registers the callback invoked when the engine dies outside of any
  /// single call (e.g. an uncaught exception crashing a Worker after it's
  /// already loaded). Backends that can't fail this way (QuickJS, in-process)
  /// simply never call it.
  void onFatalError(void Function(String message) callback);

  /// Loads the kernel bundle, then every extension bundle in order, then
  /// activates all extensions. Throws if any step fails.
  /// [clock] is applied BEFORE any bundle evaluates, so extensions activate on
  /// the same clock the app is on (see [ClockTravelState]).
  Future<void> load(String kernelSource, List<ExtensionBundle> bundles,
      {ClockTravelState clock = const ClockTravelState.real()});

  /// Replaces one already-loaded bundle in place: unloads whatever it
  /// contributed, evaluates [bundle]'s new source, and activates what that
  /// defines — reporting completion as a `reloadComplete` message carrying
  /// [token], since activation settles asynchronously.
  ///
  /// For the extension dev loop only (HALO-118). Throwing here means the new
  /// source failed to evaluate, and the bundle is then UNLOADED rather than
  /// reverted: nothing keeps the old source around to fall back to, and a dev
  /// server that just failed to build has nothing to serve either. The
  /// operator sees the build error and fixes it.
  void reloadBundle(ExtensionBundle bundle, int token);

  void invoke(int id, String category, String? key, String method, String argsJson);
  /// [wantsPartials] asks the kernel to narrate the fan-out — a roster and
  /// one message per hook as it settles — so a caller that stops waiting can
  /// still keep what arrived. Off by default because it doubles how much of
  /// each result crosses the bridge, and only a caller that will actually
  /// salvage them has anything to show for that.
  void invokeAll(int id, String category, String method, String argsJson, {bool wantsPartials = false});
  void hostResponse(int callId, bool ok, String resultJson);

  /// Drops the kernel's cached hook context (settings, account credentials)
  /// so the next hook call re-fetches — called after the host writes either.
  void invalidateContext();

  /// Points the sandbox's `Date` at the app clock (docs/design/time.md), as the
  /// anchor pair and speed the kernel needs to reproduce it. `anchorRealMillis`
  /// of 0 means real time.
  void setClockTravel(int anchorRealMillis, int anchorVirtualMillis, double speed);

  /// Pumps the engine's job queue, for backends (QuickJS) that don't have a
  /// real event loop and need manual pumping to process microtasks/promises.
  /// A no-op for backends (Worker) with a real event loop.
  void pump();

  void dispose();
}

/// The app clock's travel state as the sandbox needs it: the anchor pair and
/// speed the kernel reproduces the clock from (docs/design/time.md §6).
///
/// Passed to [EngineRuntime.load] rather than only pushed afterwards, because
/// `load` evaluates every bundle AND calls `activateAll` — so a clock that
/// arrives after it returns has already missed activation, and an extension
/// that reads a date while activating bakes in the wrong one. This host has no
/// opinion on where the numbers come from: it never reads a clock itself, which
/// is what keeps it independent of the app's.
class ClockTravelState {
  final int anchorRealMillis;
  final int anchorVirtualMillis;
  final double speed;

  const ClockTravelState({
    required this.anchorRealMillis,
    required this.anchorVirtualMillis,
    required this.speed,
  });

  /// Real time — no travel.
  const ClockTravelState.real()
      : anchorRealMillis = 0,
        anchorVirtualMillis = 0,
        speed = 1;

  bool get isReal => anchorRealMillis == 0 && speed == 1;
}
