// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ExtensionHost runs the HaLo extension runtime (a JS engine evaluating the kernel
// bundle plus extension bundles) and bridges hook invocations to it.
//
// By default the JS engine lives on a dedicated background isolate so extension
// work never blocks the UI thread; if engine creation fails there (FFI
// availability varies by platform), the host falls back to running in the
// main isolate, still fully async at the API level.
//
// Protocol with the JS side (see extensions/sdk/src/kernel.ts):
//   Dart → JS   __polo.invokeHook(id, category, key|null, method, argsJson)
//               __polo.invokeHookAll(id, category, method, argsJson, wantsPartials)
//               __polo.invokeHookBatch(id, callsJson, wantsPartials)
//               __polo.hostResponse(callId, ok, resultJson)
//               __polo.unloadBundle(key) + beginBundle/eval/endBundle +
//               __polo.activateReloaded(token)  — the dev loop's reload
//               __polo.runTimers(), __polo.setAppVisible(visible)
//   JS → Dart   'polo' channel messages:
//               {type:'result', id, ok, value|error, jsMillis}
//                 — the core adds `queueMicros` on the way through: how long
//                   the call waited for the engine, which only the core can
//                   see (see _noteQueueWait)
//               {type:'partial', id, keys}    — an invokeAll's roster (a
//                                               batch's: its call indices), and
//               {type:'partial', id, entry}   — one hook of it as it settles;
//                                               both only when wantsPartials
//               {type:'hostCall', callId, method, params}
//               {type:'log', message}
//               {type:'reloadComplete', token, ok, error?}
//               {type:'timerWake', delayMillis|null}, {type:'timersSuspended', extensionKey, reason}

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:halo_core/halo_core.dart' show realNowUtc;
import 'package:http/http.dart' as http;

import 'src/engine_load.dart';
import 'src/extension_sockets.dart';
import 'src/extension_timers.dart';
import 'src/fetch_policy.dart';
import 'src/hook_call_stats.dart';
import 'src/js_engine.dart';

export 'src/extension_sockets.dart' show isLocalNetworkHost, localNetworkEntry, maxWebSocketFrameSize, maxWebSocketsPerExtension;
export 'src/engine_load.dart' show EngineLoadBucket, EngineLoadFeed, EngineLoadWindow, engineLoadBucketMicros;
export 'src/extension_timers.dart' show TimerSuspension;
export 'src/engine_runtime.dart' show ClockTravelState, ExtensionBundle, ExtensionHostException, HookTimeoutException;
export 'src/fetch_policy.dart' show fetchBodyTimeout, fetchHeaderTimeout;
export 'src/hook_call_stats.dart' show HookCallSample, QueueWaitStat;
export 'src/hook_calls.dart' show HookCalls;
// `show`n rather than exported wholesale: this library is imported unprefixed
// across the app, and a bare `stringsIn` in its public surface turns any
// same-named helper written later into an ambiguous-import error reported at
// the use site, nowhere near the cause.
export 'src/retired_built_ins.dart' show kRetiredBuiltIns;
export 'src/scoring_priority.dart'
    show Scorer, judgedVerdicts, judgesCandidate, judgesWorkedBefore, kWorkedBeforeAlerts, kWorkedBeforeNotices, refTypesOf, scorersFor, withoutWorkedBefore;

typedef HostCallHandler = Future<dynamic> Function(String method, Map<String, dynamic> params);

/// One call in an [ExtensionHost.invokeHookBatch]: the same four things an
/// [ExtensionHost.invokeHook] takes.
typedef HookCall = ({String category, String? key, String method, Object? args});

class ExtensionHost {
  final bool runningInIsolate;
  final String engine;
  final int loadMillis;
  final HostCallHandler? onHostCall;

  /// Caps `samples`' growth over a long session (an all-day operation makes
  /// many debounced lookup/control calls) — this is diagnostic data for the
  /// spike screen, not something worth unbounded memory for.
  static const _maxSamples = 2000;

  final _logs = StreamController<String>.broadcast();
  final _fatalErrors = StreamController<String>.broadcast();
  final _interpretationUpdates = StreamController<Map<String, dynamic>>.broadcast();
  final _timerSuspensions = StreamController<TimerSuspension>.broadcast();

  /// Every log line received so far (the stream only carries new ones).
  final List<String> logLines = [];
  final List<HookCallSample> samples = [];

  final Map<int, Completer<dynamic>> _pending = {};
  final Map<int, (String, Stopwatch)> _inFlight = {};

  /// Per in-flight `invokeAll`, what the runtime has told us so far. Entered
  /// only while the call is in `_pending` and removed on every exit from it,
  /// so a fan-out nobody is waiting on leaves nothing behind.
  final Map<int, _FanOutProgress> _partials = {};
  int _nextId = 1;
  bool _dead = false;
  bool _disposed = false;

  /// Completes once the kernel's `activationComplete` message arrives — every
  /// extension's `onActivation` has genuinely settled, not just been kicked
  /// off (kernel.ts's `activateAll` fires this fire-and-forget from `load()`,
  /// so it can arrive as an early message before this object even exists;
  /// see the `earlyMessages` replay in `start()`). A caller that needs every
  /// registered hook to be in its final state — not just "the bundles
  /// evaluated" — should await [activated] rather than relying on incidental
  /// timing elsewhere.
  final _activated = Completer<void>();

  SendPort? _toIsolate;
  Isolate? _isolate;
  final List<ReceivePort> _isolatePorts = [];
  _HostCore? _inProcessCore;

  ExtensionHost._({required this.runningInIsolate, required this.engine, required this.loadMillis, this.onHostCall});

  Stream<String> get logs => _logs.stream;

  /// What has queued worst behind the single engine, per hook label, worst
  /// first — the standing question the per-call log line only ever answers
  /// one call at a time.
  ///
  /// Built from [samples], so it covers the last [_maxSamples] calls rather
  /// than the whole session, and reads all-zero on a host running the core
  /// in-process (see [HookCallSample.queueMicros]).
  List<QueueWaitStat> queueWaitSummary() => summarizeQueueWaits(samples);

  /// See [_activated]'s doc comment.
  Future<void> get activated => _activated.future;

  /// A `command` hook pushed a later CommandInterpretation for an `input` it
  /// was already asked to interpret (see `host.updateInterpretation`'s SDK
  /// doc) — `{'input': String, 'interpretation': Map<String, dynamic>}` per
  /// event. Unlike hook calls, there's no request/response pairing here:
  /// the caller decides for itself whether `input` is still current.
  Stream<Map<String, dynamic>> get interpretationUpdates => _interpretationUpdates.stream;

  /// An extension whose timers broke their budget (extensions/sdk/src/timerQueue.ts); its hooks keep working.
  Stream<TimerSuspension> get timerSuspensions => _timerSuspensions.stream;

  /// The engine's busy time, and whether it is still answering.
  late final engineLoad = EngineLoadFeed(ping: () => _dispatch(const {'type': 'ping'}), nowMicros: () => realNowUtc().microsecondsSinceEpoch);

  /// Fires when the runtime dies outside any single call (isolate/worker
  /// crash or unexpected exit). By then every pending hook call has been
  /// failed and [isDead] is true — the host can't recover itself; the owner
  /// (ExtensionService) is expected to dispose it and start a fresh one.
  Stream<String> get fatalErrors => _fatalErrors.stream;

  /// True once the runtime has died; every subsequent hook call fails fast
  /// instead of burning its full timeout against a dead engine.
  bool get isDead => _dead;

  /// Loads the kernel and extension bundles into a fresh JS runtime.
  ///
  /// [fetchAllowlists] maps each extension key to the hostnames its
  /// `host.fetch` may reach (the manifest's declared network capability):
  /// exact hosts, `*.example.com` for subdomains, or a lone `*` for any
  /// https host. Extensions with no entry get no network access.
  ///
  /// [httpClient] replaces the transport `host.fetch` goes out on. Supplying
  /// one forces in-process mode, since a client cannot cross an isolate
  /// boundary.
  ///
  /// This is the seam for testing anything that fetches — spot feeds, spot
  /// posting, data files — and it is deliberately BELOW the interesting code:
  /// the allowlist check, the https requirement, the canonical User-Agent and
  /// both timeouts all still run. Stubbing `host.fetch` itself would test none
  /// of them.
  ///
  /// [userAgent], when set, is stamped as the `User-Agent` on every
  /// `host.fetch` request — overriding any the extension supplied — so all
  /// extension traffic identifies HaLo consistently (see
  /// docs/design/network.md). The app passes its canonical UA here.
  ///
  /// [userAgentOverrides] lists the extension keys exempt from that override:
  /// a whitelisted extension that sets its own `User-Agent` keeps it (the
  /// manifest's `allowUserAgentOverride` capability). Everyone else, and any
  /// whitelisted extension that sets none, still gets [userAgent].
  ///
  /// [webSocketAllowlists] is the same shape as [fetchAllowlists], for
  /// `host.webSocket` (the manifest's `webSockets`): a separate grant, because
  /// a live connection is a different thing to consent to than a request.
  /// Extensions with no entry may open no socket.
  static Future<ExtensionHost> start({
    required String kernelSource,
    required List<ExtensionBundle> extensions,
    bool useIsolate = true,
    HostCallHandler? onHostCall,
    Map<String, Map<String, String>> secrets = const {},
    http.Client? httpClient,
    Map<String, List<String>> fetchAllowlists = const {},
    Map<String, List<String>> webSocketAllowlists = const {},
    String? userAgent,
    Set<String> userAgentOverrides = const {},

    /// The app clock's travel state at boot. Passed in rather than pushed
    /// afterwards so extensions ACTIVATE on the app's clock — see
    /// [ClockTravelState] and [setClockTravel].
    ClockTravelState clock = const ClockTravelState.real(),
  }) async {
    // On web there are no Dart isolates — the "in-process" core runs a Web
    // Worker anyway, so extension work is still off the UI thread. Branching
    // here (instead of letting Isolate.spawn throw) keeps a misleading
    // "isolate mode failed" warning out of every web boot.
    // A client is not sendable across an isolate boundary, so supplying one
    // means in-process — tests that stub the network want that anyway, and
    // silently ignoring it would leave them hitting the real one.
    if (useIsolate && !runningOnWeb && httpClient == null) {
      try {
        return await _startInIsolate(kernelSource, extensions, onHostCall, fetchAllowlists, webSocketAllowlists, userAgent, userAgentOverrides, secrets, clock);
      } catch (e) {
        // Fall through to in-process mode; the spike wants to know when this
        // happens, so surface it loudly on the first log line.
        final host = await _startInProcess(
          kernelSource,
          extensions,
          onHostCall,
          fetchAllowlists,
          webSocketAllowlists,
          userAgent,
          userAgentOverrides,
          secrets,
          clock,
          httpClient,
        );
        host._log('WARN isolate mode failed ($e), running in-process');
        return host;
      }
    }
    return _startInProcess(
      kernelSource,
      extensions,
      onHostCall,
      fetchAllowlists,
      webSocketAllowlists,
      userAgent,
      userAgentOverrides,
      secrets,
      clock,
      httpClient,
    );
  }

  static Future<ExtensionHost> _startInIsolate(
    String kernelSource,
    List<ExtensionBundle> extensions,
    HostCallHandler? onHostCall,
    Map<String, List<String>> fetchAllowlists,
    Map<String, List<String>> webSocketAllowlists,
    String? userAgent,
    Set<String> userAgentOverrides,
    Map<String, Map<String, String>> secrets,
    ClockTravelState clock,
  ) async {
    final fromIsolate = ReceivePort();
    final onError = ReceivePort();
    final onExit = ReceivePort();
    final ready = Completer<Map<String, dynamic>>();
    final earlyMessages = <Map<String, dynamic>>[];
    ExtensionHost? host;

    // Any uncaught error in the isolate kills it (errorsAreFatal). Without
    // these ports the death is silent: sends to the isolate get dropped,
    // every in-flight hook hangs to its timeout, and all future ones time
    // out forever with no diagnostic and nothing to trigger a restart.
    void fatal(String description) {
      if (!ready.isCompleted) {
        ready.completeError(ExtensionHostException(description));
        return;
      }
      final h = host;
      if (h != null && !h._disposed) {
        h._onCoreMessage({'type': 'fatalError', 'error': description});
      }
    }

    onError.listen((message) {
      final desc = message is List ? [for (final part in message) '$part'].where((s) => s.isNotEmpty).join('\n') : '$message';
      fatal('extension isolate error: $desc');
    });
    onExit.listen((_) => fatal('extension isolate exited unexpectedly'));

    final isolate = await Isolate.spawn(
      _hostIsolateMain,
      _HostIsolateInit(
        mainPort: fromIsolate.sendPort,
        kernelSource: kernelSource,
        bundles: [for (final p in extensions) (key: p.key, source: p.source, api: p.api)],
        fetchAllowlists: fetchAllowlists,
        webSocketAllowlists: webSocketAllowlists,
        secrets: secrets,
        userAgent: userAgent,
        userAgentOverrides: userAgentOverrides,
        clockAnchorRealMillis: clock.anchorRealMillis,
        clockAnchorVirtualMillis: clock.anchorVirtualMillis,
        clockSpeed: clock.speed,
      ),
      errorsAreFatal: true,
      onError: onError.sendPort,
      onExit: onExit.sendPort,
      debugName: 'polo-extension-host',
    );

    SendPort? toIsolate;
    fromIsolate.listen((message) {
      final msg = (message as Map).cast<String, dynamic>();
      switch (msg['type']) {
        case 'port':
          toIsolate = msg['port'] as SendPort;
        case 'ready':
          ready.complete(msg);
        case 'initError':
          if (!ready.isCompleted) ready.completeError(ExtensionHostException(msg['error'] as String));
        default:
          if (host == null) {
            earlyMessages.add(msg);
          } else {
            host._onCoreMessage(msg);
          }
      }
    });

    final Map<String, dynamic> readyMsg;
    try {
      readyMsg = await ready.future.timeout(const Duration(seconds: 30));
    } catch (e) {
      isolate.kill(priority: Isolate.immediate);
      fromIsolate.close();
      onError.close();
      onExit.close();
      rethrow;
    }

    host = ExtensionHost._(runningInIsolate: true, engine: readyMsg['engine'] as String, loadMillis: readyMsg['loadMillis'] as int, onHostCall: onHostCall);
    host._isolate = isolate;
    host._toIsolate = toIsolate;
    host._isolatePorts.addAll([fromIsolate, onError, onExit]);
    earlyMessages.forEach(host._onCoreMessage);
    return host;
  }

  static Future<ExtensionHost> _startInProcess(
    String kernelSource,
    List<ExtensionBundle> extensions,
    HostCallHandler? onHostCall,
    Map<String, List<String>> fetchAllowlists,
    Map<String, List<String>> webSocketAllowlists,
    String? userAgent,
    Set<String> userAgentOverrides,
    Map<String, Map<String, String>> secrets,
    ClockTravelState clock, [
    http.Client? httpClient,
  ]) async {
    final earlyMessages = <Map<String, dynamic>>[];
    ExtensionHost? host;
    final core = _HostCore(
      fetchAllowlists: fetchAllowlists,
      webSocketAllowlists: webSocketAllowlists,
      secrets: secrets,
      httpClient: httpClient,
      userAgent: userAgent,
      userAgentOverrides: userAgentOverrides,
      emit: (msg) {
        if (host == null) {
          earlyMessages.add(msg);
        } else {
          host._onCoreMessage(msg);
        }
      },
    );
    final loadMillis = await core.init(kernelSource, extensions, clock: clock);
    host = ExtensionHost._(runningInIsolate: false, engine: core.engineDescription, loadMillis: loadMillis, onHostCall: onHostCall);
    host._inProcessCore = core;
    earlyMessages.forEach(host._onCoreMessage);
    return host;
  }

  /// Invokes `method` on the highest-priority hook registered under
  /// `category` (optionally narrowed to a specific hook `key`).
  ///
  /// `args` must be JSON-encodable. Returns the hook's JSON result.
  Future<dynamic> invokeHook(String category, {String? key, required String method, Object? args, Duration timeout = const Duration(seconds: 10)}) {
    return _send('invoke', '$category.$method', {
      'category': category,
      'key': key,
      'method': method,
      // Encoded by the core, not here: on a large payload (a whole
      // operation's QSOs going to a scorer) this is real CPU, and here means
      // the UI isolate.
      //
      // A caller may still mutate `args` the moment this returns, because
      // both dispatch paths capture the value before it does — the isolate
      // path deep-copies at `send`, and the in-process path runs the core's
      // encode synchronously inside `_dispatch`. Neither may become lazy
      // without giving callers a snapshot of their own.
      'args': args ?? const <String, Object?>{},
    }, timeout);
  }

  /// Invokes `method` on every hook in `category` (priority order). Returns
  /// one entry per hook: `{key, ok, value|error}` — a failing source never
  /// poisons the others.
  ///
  /// [timeout] is one budget for the whole fan-out, not one per hook, because
  /// the runtime answers a fan-out with a single call. What happens when it
  /// expires is [partialOnTimeout]'s question:
  ///
  /// - **false (default)** — throws, and every hook's work is discarded
  ///   however long ago it finished. Right where a partial answer is a WRONG
  ///   answer: half of `adifFields` writes a silently incomplete export, half
  ///   of `dataFile.getDefinition` means a data file that quietly does not
  ///   exist.
  /// - **true** — returns the hooks that did answer, plus a synthesized
  ///   `{key, ok: false, error: 'timed out'}` for each one that did not, so a
  ///   caller can name the source rather than just noticing an absence. Right
  ///   where the hooks are independent contributors and some data beats none
  ///   — spot sources being the case this exists for.
  ///
  /// Neither setting stops the slow hook: nothing in the runtime can be
  /// cancelled, so this is about how long the CALLER waits.
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async {
    // Allocated here rather than read back off `_nextId`, so the id this
    // reads partials under is provably the one the call was sent under.
    final id = _nextId++;
    try {
      final result = await _send(
        'invokeAll',
        '$category.$method*',
        {
          'category': category,
          'method': method,
          // Encoded by the core — see invokeHook.
          'args': args ?? const <String, Object?>{},
          // Narration is not free — it puts every hook's result on the bridge a
          // second time — so it is requested only by a caller that will keep it.
          'wantsPartials': partialOnTimeout,
        },
        timeout,
        id: id,
      );
      return (result as List).cast<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>()).toList();
    } on HookTimeoutException {
      // Only a timeout salvages. A runtime that died, or a fan-out the kernel
      // failed wholesale, has nothing trustworthy to hand back — those stay
      // exceptions whatever `partialOnTimeout` says.
      final progress = _partials.remove(id);
      if (!partialOnTimeout || progress == null) rethrow;
      return progress.settledPlusMissing(timeout);
    }
  }

  /// Runs several single-hook calls in ONE crossing, each routed and run
  /// exactly as [invokeHook] would run it, all of them concurrently. Returns
  /// one entry per call, in call order: `{ok: true, value}` or
  /// `{ok: false, error}` — one call throwing, having no hook (`noHandler:
  /// true`), or answering what JSON cannot carry never costs the others.
  ///
  /// For a list of independent calls that would otherwise cross one at a time
  /// — every reference an import brings, every search result's link. The
  /// bridge is coarse by design (DESIGN.md §4): a crossing per item is a
  /// message and a pump per item, and a loop that awaits each one pays every
  /// item's latency in turn.
  ///
  /// [timeout] is one budget for the whole batch, and [partialOnTimeout] is
  /// [invokeHookAll]'s: true keeps every call that answered and returns each
  /// one that did not as `{ok: false, error, timedOut: true}` — unless a batch
  /// of several runs out before the runtime has reported on it at all, which
  /// throws, having nothing to keep.
  Future<List<Map<String, dynamic>>> invokeHookBatch(
    List<HookCall> calls, {
    Duration timeout = const Duration(seconds: 10),
    bool partialOnTimeout = false,
  }) async {
    if (calls.isEmpty) return const [];
    // Allocated here for the same reason as invokeHookAll's.
    final id = _nextId++;
    // Narration puts every answer on the bridge twice, and a batch of ONE has
    // nothing else to salvage: its timed-out entry is made up here instead.
    final narrated = partialOnTimeout && calls.length > 1;
    List<Map<String, dynamic>> entries;
    try {
      final result = await _send(
        'invokeBatch',
        batchLabel([for (final call in calls) call.method]),
        {
          'calls': [
            // Encoded by the core — see invokeHook.
            for (final call in calls) {'category': call.category, 'key': call.key, 'method': call.method, 'args': call.args ?? const <String, Object?>{}},
          ],
          'wantsPartials': narrated,
        },
        timeout,
        id: id,
      );
      entries = (result as List).cast<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>()).toList();
    } on HookTimeoutException {
      final progress = _partials.remove(id);
      if (!partialOnTimeout || (narrated && progress == null)) rethrow;
      entries = (progress ?? (_FanOutProgress()..expected = const ['0'])).settledPlusMissing(timeout);
    }
    // Keyed by index, because salvaged entries arrive in the order they
    // settled rather than the order they were asked for.
    final byIndex = {for (final entry in entries) entry['key']: entry};
    return [
      // Every call has an entry by here — the runtime's own, or one made up for
      // a timeout — so a missing one is a bridge that answered wrongly, not an
      // extension that did.
      for (var i = 0; i < calls.length; i++) byIndex['$i'] ?? (throw StateError('the runtime answered a batch of ${calls.length} with no entry for call $i')),
    ];
  }

  Future<dynamic> _send(String type, String label, Map<String, Object?> fields, Duration timeout, {int? id}) async {
    if (_dead) {
      throw ExtensionHostException('extension runtime is dead (hook $label not attempted)');
    }
    id ??= _nextId++;
    engineLoad.wake();
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _inFlight[id] = (label, Stopwatch()..start());

    // Stamped here rather than in `_dispatch`: the core subtracts it from its
    // own read of the same clock to learn how long the message sat in the
    // isolate's port queue, and only the hook-call messages carry a caller
    // waiting on that number. `realNow`, not the app clock — a travelled
    // session must not report a queue wait measured in virtual time
    // (docs/design/time.md §1).
    try {
      _dispatch({'type': type, 'id': id, 'sentAtMicros': realNowUtc().microsecondsSinceEpoch, ...fields});
    } catch (e) {
      // `args` crosses as a live object graph now, so `SendPort.send` can
      // refuse it (a closure, a ReceivePort, anything holding a native
      // resource) — and the core never learns the id exists, so no result
      // and no `abandon` will ever clear these. Without this the entries,
      // and the Stopwatch with them, are kept for the life of the host.
      _pending.remove(id);
      _inFlight.remove(id);
      rethrow;
    }

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(id);
      _inFlight.remove(id);
      // Tell the core to stop counting this call as outstanding: a hook
      // that never settles would otherwise keep the 5ms pump timer spinning
      // forever — constant CPU wake-ups on an all-day field session.
      _dispatch({'type': 'abandon', 'id': id});
      throw HookTimeoutException('hook $label timed out after ${timeout.inMilliseconds}ms');
    }
  }

  /// Sends one message to the core, whichever side it runs on. (`_toIsolate`
  /// is never nulled once set, so the two branches cover every live host.)
  void _dispatch(Map<String, Object?> message) {
    if (_inProcessCore != null) {
      _inProcessCore!.handle(message);
    } else {
      _toIsolate?.send(message);
    }
  }

  /// Replaces one loaded bundle with a freshly built [bundle], without
  /// restarting the runtime: its hooks are dropped, the new source is
  /// evaluated, and whatever it defines is activated. Every other extension
  /// keeps running, and so does the KV each one holds.
  ///
  /// For the extension dev loop (HALO-118), which iterates on one extension
  /// while dozens stay live. The app never calls this in normal operation —
  /// enabling or disabling an extension still replaces the whole runtime.
  ///
  /// [domains] replaces the extension's `host.fetch` allowlist, so a manifest
  /// edited between builds takes effect here too; omit it to leave the
  /// capability as it was. Build secrets are deliberately NOT re-resolved:
  /// they are visible only to extensions baked into the app's assets, and a
  /// reload never changes that (HALO-425).
  ///
  /// Completes once the new source has evaluated AND its activation settled.
  /// Throws if the source failed to evaluate, in which case the extension is
  /// left UNLOADED rather than reverted — the previous source is gone, and a
  /// dev server that just failed to build has nothing to put back.
  Future<void> reloadBundle(ExtensionBundle bundle, {List<String>? domains, Duration timeout = const Duration(seconds: 10)}) {
    if (_dead) {
      throw ExtensionHostException('extension runtime is dead (bundle ${bundle.key} not reloaded)');
    }
    final token = _nextId++;
    final completer = Completer<void>();
    _pendingReloads[token] = completer;
    _dispatch({'type': 'reloadBundle', 'token': token, 'key': bundle.key, 'source': bundle.source, 'api': bundle.api, 'domains': ?domains});
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingReloads.remove(token);
        throw HookTimeoutException('reloading ${bundle.key} timed out after ${timeout.inMilliseconds}ms');
      },
    );
  }

  /// Reload tokens awaiting their `reloadComplete`. Separate from [_pending]
  /// because a reload is not a hook call: it carries no result and no sample.
  final Map<int, Completer<void>> _pendingReloads = {};

  /// Seeds a value into an extension's key-value namespace (e.g. credentials).
  void setKV(String extensionKey, String key, Object? value) {
    _dispatch({'type': 'kvSet', 'ns': extensionKey, 'key': key, 'value': value});
  }

  /// Drops the kernel's cached hook context (settings, account credentials).
  /// Call after the app writes either, so the next hook call sees the fresh
  /// values instead of waiting out the kernel-side cache TTL.
  void invalidateHookContext() {
    _dispatch(const {'type': 'invalidateContext'});
  }

  /// Points the sandbox's `Date` at the app clock (docs/design/time.md).
  ///
  /// The travel state is main-isolate state, and the runtime may live in
  /// another isolate or a worker, so it has to be PUSHED: send it whenever it
  /// changes and again whenever a runtime boots or is replaced, or a restarted
  /// engine silently reverts every extension to real time.
  void setClockTravel({required int anchorRealMillis, required int anchorVirtualMillis, required double speed}) {
    _dispatch({'type': 'setClockTravel', 'anchorRealMillis': anchorRealMillis, 'anchorVirtualMillis': anchorVirtualMillis, 'speed': speed});
  }

  /// Tells extensions the app was shown or hidden (`onShow`/`onHide`); send it after every boot too.
  void setAppVisible(bool visible) => _dispatch({'type': 'setAppVisible', 'visible': visible});

  void _onCoreMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'result':
        // Defensive cast: a malformed id from the JS side must not throw
        // inside this listener — it would kill the subscription, and on the
        // isolate path the isolate itself.
        final id = msg['id'];
        if (id is! int) return;
        final completer = _pending.remove(id);
        final flight = _inFlight.remove(id);
        if (completer == null) return; // timed out; drop the late result
        if (flight != null) {
          flight.$2.stop();
          samples.add(
            HookCallSample(
              label: flight.$1,
              totalMillis: flight.$2.elapsedMilliseconds,
              jsMillis: (msg['jsMillis'] as num?)?.toInt() ?? 0,
              queueMicros: (msg['queueMicros'] as num?)?.toInt() ?? 0,
            ),
          );
          if (samples.length > _maxSamples) samples.removeAt(0);
        }
        _partials.remove(id);
        if (msg['ok'] == true) {
          completer.complete(msg['value']);
        } else {
          completer.completeError(ExtensionHostException(msg['error'] as String? ?? 'unknown extension error'));
        }
      case 'partial':
        final id = msg['id'];
        if (id is! int) return;
        // Only accumulate for a call still being waited on: a `partial`
        // arriving after the timeout belongs to a fan-out nobody is holding,
        // and keeping it would leak an entry per abandoned call.
        if (!_pending.containsKey(id)) return;
        final progress = _partials.putIfAbsent(id, _FanOutProgress.new);
        final keys = msg['keys'];
        if (keys is List) progress.expected = keys.whereType<String>().toList();
        final entry = msg['entry'];
        if (entry is Map) progress.entries.add(entry.cast<String, dynamic>());
      case 'log':
        _log(msg['message'] as String? ?? '');
      case 'activationComplete':
        if (!_activated.isCompleted) _activated.complete();
      case 'reloadComplete':
        final completer = _pendingReloads.remove(msg['token']);
        if (completer == null || completer.isCompleted) return; // already timed out
        if (msg['ok'] == false) {
          completer.completeError(ExtensionHostException('reloading bundle failed: ${msg['error'] ?? 'unknown error'}'));
        } else {
          completer.complete();
        }
      case 'engineLoad':
        engineLoad.add(msg);
      case 'pong':
        engineLoad.pong();
      case 'timersSuspended':
        if (msg case {'extensionKey': String key, 'reason': String reason}) _timerSuspensions.add((extensionKey: key, reason: reason));
      case 'updateInterpretation':
        final input = msg['input'] as String?;
        if (input == null) return;
        _interpretationUpdates.add({'input': input, 'interpretation': ((msg['interpretation'] as Map?) ?? const {}).cast<String, dynamic>()});
      case 'hostCall':
        final callId = msg['callId'] as int;
        final method = msg['method'] as String;
        final params = (msg['params'] as Map).cast<String, dynamic>();
        _handleHostCallDelegated(callId, method, params);
      case 'fatalError':
        // The engine died outside of any single call (e.g. a Worker or
        // isolate crash) — every hook still waiting on a response would
        // otherwise just hang until its own timeout, hiding the real cause.
        // A crash reports through more than one channel (onError + onExit);
        // only the first one does the work.
        if (_dead) return;
        _dead = true;
        final error = msg['error'] as String? ?? 'extension engine crashed';
        _log('ERROR $error');
        for (final completer in _pending.values) {
          completer.completeError(ExtensionHostException(error));
        }
        _pending.clear();
        _inFlight.clear();
        // A dead engine's partials describe a fan-out that will never
        // finish; nothing may salvage them (the completers above threw
        // ExtensionHostException, not HookTimeoutException, so nothing tries).
        _partials.clear();
        // A reload in flight when the engine died is never going to be told
        // it finished, and its caller would wait out the full timeout for a
        // runtime that no longer exists.
        for (final completer in _pendingReloads.values) {
          if (!completer.isCompleted) completer.completeError(ExtensionHostException(error));
        }
        _pendingReloads.clear();
        _fatalErrors.add(error);
        unawaited(engineLoad.dispose());
        // A crash before activation ever finishes must not leave a caller
        // awaiting [activated] hanging forever.
        if (!_activated.isCompleted) _activated.complete();
    }
  }

  Future<void> _handleHostCallDelegated(int callId, String method, Map<String, dynamic> params) async {
    final handler = onHostCall;
    if (handler == null) {
      _sendHostCallResponse(callId, false, 'no host call handler configured');
      return;
    }
    try {
      final res = await handler(method, params);
      _sendHostCallResponse(callId, true, res);
    } catch (e) {
      _sendHostCallResponse(callId, false, e.toString());
    }
  }

  void _sendHostCallResponse(int callId, bool ok, Object? result) {
    if (_inProcessCore != null) {
      _inProcessCore!.handleHostCallResponse(callId, ok, result);
    } else {
      _toIsolate?.send({'type': 'hostCallResponse', 'callId': callId, 'ok': ok, 'result': result});
    }
  }

  void _log(String message) {
    logLines.add(message);
    _logs.add(message);
  }

  Future<void> dispose() async {
    _disposed = true;
    _dead = true;
    // Callers still awaiting a hook would otherwise wait out their full
    // timeouts against a runtime that's already gone.
    for (final completer in _pending.values) {
      completer.completeError(ExtensionHostException('extension host disposed'));
    }
    _pending.clear();
    _inFlight.clear();
    // Same reason as the fatalError path: a fan-out on a host that is going
    // away has nothing worth salvaging, and leaving the map populated is a
    // trap for whoever makes disposal recoverable.
    _partials.clear();

    // Ask the isolate to shut the engine down before killing it.
    //
    // Isolate.kill reclaims Dart memory, not the JS engine's. QuickJS holds a
    // real malloc'd heap — the kernel bundle alone needs 10-12MB before any
    // extension loads — and only halo_qjs_free returns it, so skipping this
    // leaks the engine on every restart (and the crash-restart path in
    // extension_service.dart retries with backoff).
    //
    // Best effort by design: the kill still happens, so a wedged isolate
    // (mid-runaway-hook, say) cannot hold shutdown up.
    if (_toIsolate != null) {
      try {
        _toIsolate!.send({'type': 'dispose'});
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } catch (_) {
        // The isolate may already be gone; killing below is still correct.
      }
    }
    _isolate?.kill(priority: Isolate.immediate);
    for (final port in _isolatePorts) {
      port.close();
    }
    _inProcessCore?.dispose();
    await _logs.close();
    await _fatalErrors.close();
    await _interpretationUpdates.close();
    await _timerSuspensions.close();
    await engineLoad.dispose();
  }
}

/// What one in-flight `invokeAll` or batch has reported: the roster of hooks
/// (a batch's: call indices) it is about to call, then their entries as they
/// settle.
class _FanOutProgress {
  /// Hook keys the runtime said it would call. Empty until the roster
  /// arrives, which is the first thing the runtime posts.
  List<String> expected = const [];
  final List<Map<String, dynamic>> entries = [];

  /// Everything that answered, plus a failure entry naming everything that
  /// didn't. The synthesized entries are the point: a caller comparing
  /// against the roster can say WHICH source went quiet, where a bare list
  /// of what arrived can't distinguish a stalled hook from an absent one.
  List<Map<String, dynamic>> settledPlusMissing(Duration timeout) {
    final answered = {for (final entry in entries) entry['key']};
    return [
      ...entries,
      for (final key in expected)
        if (!answered.contains(key))
          {
            'key': key,
            'ok': false,
            'error': 'timed out after ${timeout.inMilliseconds}ms',
            // Distinguishes "never answered" from a hook that ran and threw,
            // which also arrives as ok:false. A caller telling the operator a
            // source is unreachable must not say so about one that answered
            // with an error, and matching on the message text to tell them
            // apart would be a bug waiting for a reworded string.
            'timedOut': true,
          },
    ];
  }
}

class _HostIsolateInit {
  final SendPort mainPort;
  final String kernelSource;
  final List<({String key, String source, int? api})> bundles;
  final Map<String, List<String>> fetchAllowlists;
  final Map<String, List<String>> webSocketAllowlists;

  /// Extension key → its own build-time API key, resolved host-side.
  final Map<String, Map<String, String>> secrets;
  final String? userAgent;
  final Set<String> userAgentOverrides;

  /// The app clock's travel state, as three sendable primitives — the isolate
  /// has its OWN memory, so nothing about the app's clock is visible there
  /// unless it crosses in this payload (docs/design/time.md §6).
  final int clockAnchorRealMillis;
  final int clockAnchorVirtualMillis;
  final double clockSpeed;

  const _HostIsolateInit({
    required this.mainPort,
    required this.kernelSource,
    required this.bundles,
    required this.fetchAllowlists,
    required this.webSocketAllowlists,
    required this.secrets,
    required this.userAgent,
    required this.userAgentOverrides,
    required this.clockAnchorRealMillis,
    required this.clockAnchorVirtualMillis,
    required this.clockSpeed,
  });
}

Future<void> _hostIsolateMain(_HostIsolateInit init) async {
  final receive = ReceivePort();
  init.mainPort.send({'type': 'port', 'port': receive.sendPort});

  final core = _HostCore(
    emit: init.mainPort.send,
    fetchAllowlists: init.fetchAllowlists,
    webSocketAllowlists: init.webSocketAllowlists,
    secrets: init.secrets,
    userAgent: init.userAgent,
    userAgentOverrides: init.userAgentOverrides,
  );
  try {
    final loadMillis = await core.init(
      init.kernelSource,
      [for (final b in init.bundles) ExtensionBundle(key: b.key, source: b.source, api: b.api)],
      clock: ClockTravelState(anchorRealMillis: init.clockAnchorRealMillis, anchorVirtualMillis: init.clockAnchorVirtualMillis, speed: init.clockSpeed),
    );
    init.mainPort.send({'type': 'ready', 'loadMillis': loadMillis, 'engine': core.engineDescription});
  } catch (e, st) {
    init.mainPort.send({'type': 'initError', 'error': '$e\n$st'});
    return;
  }

  await for (final message in receive) {
    final msg = (message as Map).cast<String, dynamic>();
    if (msg['type'] == 'dispose') break;
    if (msg['type'] == 'hostCallResponse') {
      core.handleHostCallResponse(msg['callId'] as int, msg['ok'] as bool, msg['result']);
    } else {
      core.handle(msg);
    }
  }
  core.dispose();
}

/// The part of the host that owns the JS runtime. Runs either inside the
/// extension isolate or (fallback) in the main isolate.
class _HostCore {
  final void Function(Map<String, dynamic>) emit;

  /// Per-extension fetch capability — see [ExtensionHost.start]. Copied into
  /// a mutable map rather than held as given: a dev-loop reload carries the
  /// extension's manifest `domains` with it, so a capability edited between
  /// two builds takes effect without restarting the runtime, and callers
  /// routinely pass an unmodifiable literal here.
  final Map<String, List<String>> fetchAllowlists;

  /// Per-extension WebSocket capability — see [ExtensionHost.start]. Fixed for
  /// the runtime's life: a dev reload that changes it restarts the runtime
  /// (`ExtensionInfo.sameStartTimeCapabilities`).
  final Map<String, List<String>> webSocketAllowlists;

  late final _sockets = ExtensionSockets(
    userAgent: userAgent,
    deliver: (socketId, event) {
      try {
        _busy('socket', () => _js.socketEvent(socketId, jsonEncode(event)));
      } catch (e) {
        emit({'type': 'log', 'message': 'ERROR delivering socket event: $e'});
      }
    },
  );

  /// Extension key → its own build-time API key, resolved host-side.
  final Map<String, Map<String, String>> secrets;

  /// Canonical `User-Agent` stamped on every `host.fetch` — see
  /// [ExtensionHost.start] and docs/design/network.md.
  final String? userAgent;

  /// Extension keys allowed to keep their own `User-Agent` — see
  /// [ExtensionHost.start].
  final Set<String> userAgentOverrides;

  late final EngineRuntime _js;

  /// The transport `host.fetch` goes out on. Injectable so a test can answer
  /// requests without a network, while everything ABOVE it — the manifest
  /// allowlist, the https requirement, the canonical User-Agent, the two
  /// timeouts — still runs for real. Replacing `_hostFetch` wholesale would
  /// test none of that.
  final http.Client _http;

  /// Only close what we opened: an injected client belongs to the caller and
  /// may outlive this host (or be shared between several).
  final bool _ownsHttpClient;
  final Map<String, Map<String, Object?>> _kv = {};
  final Map<int, Completer<dynamic>> _pendingHostCalls = {};
  Timer? _pump;
  late final _timers = ExtensionTimerWake(runTimers: _runTimers, log: (message) => emit({'type': 'log', 'message': message}));

  void _runTimers() {
    _lastEvalLabel = 'timers';
    _busy('timers', _js.runTimers);
  }

  late final _load = EngineLoadMeter(
    onBucket: (bucket) => emit({'type': 'engineLoad', ...bucket.toMessage()}),
    nowMicros: () => realNowUtc().microsecondsSinceEpoch,
  );

  /// Runs [body], charging its wall time to the engine's busy time under
  /// [label] — every way into the engine goes through here, so the idle
  /// share is the whole thread's, not just the hooks'.
  ///
  /// A pass-through on web, where the engine runs in a worker that times
  /// itself: this thread's time there is the UI's, not the engine's.
  T _busy<T>(String label, T Function() body) => runningOnWeb ? body() : _load.run(label, body);

  /// Ids (not a bare counter) so a duplicate/forged 'result' can't drive
  /// the count negative and stall the pump while genuine calls wait, and so
  /// an 'abandon' after a Dart-side timeout can't double-decrement if the
  /// hook's own late result eventually arrives too.
  final Set<int> _outstandingIds = {};

  /// Dev-loop reloads whose activation has not yet settled. Kept apart from
  /// [_outstandingIds] because it holds tokens, not call ids, but read by the
  /// same pump condition: a reload's activation can await a host round trip,
  /// and nothing else need be outstanding to keep the job queue moving.
  final Set<int> _reloadsInFlight = {};

  /// How long each in-flight call waited before its eval began, carried here
  /// only until its `result` goes back — the host records it against the
  /// sample it already keeps for that id.
  final Map<int, int> _queueMicros = {};

  /// What this engine most recently began evaluating. A call that waited is
  /// reported against this, because [handle] runs *between* evals: whatever
  /// the engine was busy with is by then the previous entry, and naming it is
  /// the difference between "something was slow" and a lead worth pulling.
  String? _lastEvalLabel;

  /// `--dart-define=HALO_SLOW_HOOK_MS=<n>`: the threshold in milliseconds,
  /// and the switch that turns these lines on in a RELEASE build.
  ///
  /// Both at once, deliberately. A debug build's Dart is slow enough that its
  /// waits overstate what an operator's build does, so the numbers worth
  /// quoting only exist in release — and someone who has gone as far as
  /// naming a threshold is measuring, which is the only reason to want the
  /// line there. Unset (0) leaves the default below, debug-only.
  static const _slowHookMillisOverride = int.fromEnvironment('HALO_SLOW_HOOK_MS');

  /// Roughly six frames at 60Hz — below this a call is merely behind ordinary
  /// work, and logging it would bury the waits that cost a visible pause.
  static const _defaultSlowQueueMillis = 100;

  static const _slowQueueMicros = (_slowHookMillisOverride > 0 ? _slowHookMillisOverride : _defaultSlowQueueMillis) * 1000;

  /// Measuring never stops (see [_noteQueueWait]); only the reporting is
  /// gated, so a release build sweeping the threshold down reports the same
  /// numbers it was already computing.
  static const _reportsSlowQueue = _slowHookMillisOverride > 0 || debugBuild;

  _HostCore({
    required this.emit,
    Map<String, List<String>> fetchAllowlists = const {},
    this.webSocketAllowlists = const {},
    this.secrets = const {},
    this.userAgent,
    this.userAgentOverrides = const {},
    http.Client? httpClient,
  }) : fetchAllowlists = Map.of(fetchAllowlists),
       _http = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  String get engineDescription => _js.engineDescription;

  Future<int> init(String kernelSource, List<ExtensionBundle> bundles, {ClockTravelState clock = const ClockTravelState.real()}) async {
    final stopwatch = Stopwatch()..start();
    _js = createEngineRuntime();
    _js.onMessage(_onPoloMessage);
    _js.onFatalError(_onFatalError);
    _js.onBusySpan(_load.record);
    try {
      // `load` is async, but on native every evaluation in it runs before it
      // returns its future, so the wrapper times the whole boot — and host
      // calls answered during it count as part of it, not on top of it.
      await _busy('load', () => _js.load(kernelSource, bundles, clock: clock));
    } catch (e) {
      _timers.dispose(); // a timer set while activating may already be armed
      _js.dispose();
      rethrow;
    }

    return (stopwatch..stop()).elapsedMilliseconds;
  }

  /// A ping is answered outside [_busy]: timed, every heartbeat would open a slice of its own.
  void handle(Map<String, dynamic> msg) =>
      msg['type'] == 'ping' ? _js.ping() : (runningOnWeb ? _handle(msg) : _load.run(engineLoadLabel(msg), () => _handle(msg)));

  void _handle(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'invoke':
      case 'invokeAll':
      case 'invokeBatch':
        final id = msg['id'] as int;
        _outstandingIds.add(id);
        _ensurePumping();
        final calls = msg['calls'];
        final label = calls is List ? batchLabel([for (final call in calls) (call as Map)['method']]) : '${msg['category']}.${msg['method']}';
        _noteQueueWait(id, label, msg['sentAtMicros']);
        try {
          // Inside the try, so an arg the caller believed JSON-encodable and
          // is not fails as this call's error rather than as an uncaught
          // throw on the extension isolate — where nothing is waiting to turn
          // it back into an answer, and the caller would burn its whole
          // timeout to learn nothing.
          //
          // The label rides along in the message because this is the one
          // failure here that is the CALLER's bug rather than the runtime's,
          // and every caller that catches it degrades quietly — so without
          // the hook named, the only trace is a console line that says
          // something somewhere failed to encode.
          final String argsJson;
          try {
            argsJson = calls is List ? '[${calls.map(_encodeBatchCall).join(',')}]' : jsonEncode(msg['args'] ?? const <String, Object?>{});
          } catch (e) {
            throw ExtensionHostException('hook $label was given arguments that are not JSON-encodable: $e');
          }
          switch (msg['type']) {
            case 'invoke':
              _js.invoke(id, msg['category'] as String, msg['key'] as String?, msg['method'] as String, argsJson);
            case 'invokeAll':
              _js.invokeAll(id, msg['category'] as String, msg['method'] as String, argsJson, wantsPartials: msg['wantsPartials'] == true);
            default:
              _js.invokeBatch(id, argsJson, wantsPartials: msg['wantsPartials'] == true);
          }
          // Only once an eval has actually begun: a call that failed above
          // never reached the engine, and naming it as what the NEXT slow
          // call queued behind would send a reader after a hook that never
          // ran.
          _lastEvalLabel = label;
        } catch (e) {
          _settle(id, {'type': 'result', 'id': id, 'ok': false, 'error': '$e'});
        }
      case 'reloadBundle':
        final token = msg['token'] as int;
        final key = msg['key'] as String;
        // The manifest travels with the source: a dev build may have edited
        // the extension's declared `domains`, and the allowlist is consulted
        // per fetch, so replacing it here is all it takes for the new
        // capability to apply. Absent means "leave it as it was".
        final domains = (msg['domains'] as List?)?.cast<String>();
        if (domains != null) fetchAllowlists[key] = domains;
        _reloadsInFlight.add(token);
        try {
          _js.reloadBundle(ExtensionBundle(key: key, source: msg['source'] as String, api: msg['api'] as int?), token);
          // Success is NOT reported here: the kernel's activateReloaded posts
          // `reloadComplete` once activation has genuinely settled, which is
          // strictly later than this call returning.
        } catch (e) {
          _reloadsInFlight.remove(token);
          emit({'type': 'reloadComplete', 'token': token, 'ok': false, 'error': '$e'});
        }
        // The reload's own activation may await a host round trip (an
        // extension calling getSettings() before it registers), and nothing
        // else is outstanding to keep the queue moving.
        _ensurePumping();
      case 'abandon':
        // The main-isolate side timed this call out and stopped waiting.
        _outstandingIds.remove(msg['id']);
        // No result will carry this one home, so drop it rather than leaking
        // an entry per abandoned call over a long session.
        _queueMicros.remove(msg['id']);
      case 'kvSet':
        _kv.putIfAbsent(msg['ns'] as String? ?? 'default', () => {})[msg['key'] as String] = msg['value'];
      case 'invalidateContext':
        try {
          _js.invalidateContext();
        } catch (e) {
          emit({'type': 'log', 'message': 'ERROR invalidating hook context: $e'});
        }
      case 'setAppVisible':
        try {
          _js.setAppVisible(msg['visible'] as bool);
        } catch (e) {
          emit({'type': 'log', 'message': 'ERROR setting app visibility: $e'});
        }
      case 'setClockTravel':
        try {
          _js.setClockTravel(msg['anchorRealMillis'] as int, msg['anchorVirtualMillis'] as int, (msg['speed'] as num).toDouble());
        } catch (e) {
          // Reported as FATAL, not merely logged: unlike every other message
          // here, a failure means the app and its extensions now disagree about
          // what time it is, for the life of this runtime, and the symptom
          // (spot ages, ADIF stamps, clock panels contradicting the clock chip)
          // reads as an extension bug. The owner replaces a runtime on a fatal,
          // which is the only thing that repairs this — a fresh one is handed
          // the clock as part of its boot.
          emit({'type': 'log', 'message': 'ERROR setting clock travel: $e'});
          emit({'type': 'fatalError', 'error': 'could not set the sandbox clock: $e'});
        }
    }
  }

  /// One call of a batch as JSON, encoded on its own: a call whose arguments
  /// JSON cannot hold becomes one carrying that error instead, which the
  /// kernel answers as that call's failure — encoded together, one bad call
  /// would fail every call in the batch.
  static String _encodeBatchCall(Object? call) {
    try {
      return jsonEncode(call);
    } catch (e) {
      final c = call is Map ? call : const <String, Object?>{};
      return jsonEncode({'category': c['category'], 'key': c['key'], 'method': c['method'], 'error': 'arguments are not JSON-encodable: $e'});
    }
  }

  /// Finishes call [id] off: drops the bookkeeping it owns and sends [result]
  /// home carrying whatever queue wait was measured for it.
  ///
  /// The ONE way an id is closed out. A hook that failed before reaching the
  /// engine settles here too, rather than emitting a result of its own — two
  /// exits meant the failure path silently kept its `_queueMicros` entry
  /// forever, and reported a call that may have queued for a second as having
  /// waited none, biasing the summary away from exactly the calls most likely
  /// to have stalled.
  void _settle(Object? id, Map<String, dynamic> result) {
    _outstandingIds.remove(id);
    final queued = _queueMicros.remove(id);
    emit(queued == null ? result : {...result, 'queueMicros': queued});
  }

  /// Records how long the call that just arrived spent waiting for the
  /// engine, and says so in the log when the wait was long enough to matter.
  ///
  /// The wait is a subtraction across the isolate boundary, so it is only
  /// meaningful because both sides read the same real clock; a host running
  /// the core in-process dispatches synchronously and lands at ~0, which is
  /// the true answer there rather than a missing measurement.
  ///
  /// Measured on every build but logged only in debug: making release skip
  /// the read would leave the shipped path different from the measured one,
  /// and the whole point of the number is to describe what an operator's
  /// build actually does.
  void _noteQueueWait(int id, String label, Object? sentAtMicros) {
    if (sentAtMicros is! int) {
      // Not a runtime condition: `_send` is the only builder of these
      // messages and stamps every one, with the spread after the stamp so no
      // caller can shadow it. So an unstamped message is a bridge that has
      // been changed wrongly — and staying silent would hide it perfectly,
      // because an unmeasured call and an instant one both report zero.
      assert(false, 'hook message for $label reached the core with no sentAtMicros stamp');
      if (debugBuild) {
        emit({'type': 'log', 'message': 'UNSTAMPED-HOOK $label — queue wait not measured'});
      }
      return;
    }
    // Clamped at zero: nothing downstream should have to reason about a
    // negative wait if the two reads ever straddle a clock adjustment.
    final waited = max(0, realNowUtc().microsecondsSinceEpoch - sentAtMicros);
    _queueMicros[id] = waited;
    if (_reportsSlowQueue && waited >= _slowQueueMicros) {
      final behind = _lastEvalLabel;
      emit({
        'type': 'log',
        'message':
            'SLOW-QUEUE $label waited ${waited ~/ 1000}ms'
            '${behind == null ? '' : ' (behind $behind)'}',
      });
    }
  }

  /// Pumps the JS job queue only while hook calls are outstanding, instead
  /// of a permanent fast timer.
  void _ensurePumping() {
    _pump ??= Timer.periodic(const Duration(milliseconds: 5), (_) {
      runningOnWeb ? _js.pump() : _load.runIfWorked('jobs', _js.pump);
      if (_outstandingIds.isEmpty && _reloadsInFlight.isEmpty) {
        _pump?.cancel();
        _pump = null;
      }
    });
  }

  /// The engine died outside of any single call (e.g. a Worker crash after
  /// load). Stop pumping — nothing will ever settle these calls — and let
  /// `ExtensionHost` fail every hook call still waiting on a result.
  void _onFatalError(String message) {
    _outstandingIds.clear();
    // Nothing will settle these calls, so nothing would ever drop their
    // measurements. The label goes too: the next runtime's first slow call
    // must not be reported as queued behind a hook from the dead one.
    _queueMicros.clear();
    _lastEvalLabel = null;
    for (final token in _reloadsInFlight.toList()) {
      emit({'type': 'reloadComplete', 'token': token, 'ok': false, 'error': message});
    }
    _reloadsInFlight.clear();
    emit({'type': 'fatalError', 'error': message});
  }

  void _onPoloMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'result':
        _settle(msg['id'], msg);
      case 'partial':
        // Running commentary on an in-flight `invokeAll`. Deliberately does
        // NOT touch `_outstandingIds` — the call is still outstanding, and
        // dropping it here would stop the pump with hooks left to run.
        emit(msg);
      case 'log':
        emit(msg);
      case 'activationComplete':
        emit(msg);
      case 'reloadComplete':
        _reloadsInFlight.remove(msg['token']);
        emit(msg);
      case 'updateInterpretation' || 'timersSuspended' || 'pong':
        emit(msg);
      case 'timerWake':
        _timers.arm((msg['delayMillis'] as num?)?.ceil());
      case 'socketsDropped':
        // An unloaded extension's listeners are gone, so nothing would ever
        // hear from these sockets again — and the reloaded code, which never
        // opened them, holds no id that reaches them.
        _sockets.abandon(((msg['socketIds'] as List?) ?? const []).whereType<int>());
      case 'hostCall':
        _handleHostCall((msg['callId'] as num).toInt(), msg['method'] as String, ((msg['params'] ?? const <String, dynamic>{}) as Map).cast<String, dynamic>());
    }
  }

  Future<void> _handleHostCall(int callId, String method, Map<String, dynamic> params) async {
    // Read before the first await, while the requesting call still runs: the
    // answer resumes it (the kernel fetches a hook's settings before running
    // it), so charging it to the host call would name `getSettings` for
    // every busy hook there is.
    final chargedTo = _load.currentLabel ?? 'host:$method';
    Object? result;
    bool ok = true;
    try {
      switch (method) {
        case 'fetch':
          result = await _hostFetch(params);
        case 'secret':
          // `extensionKey` is kernel-bound, so this really is "what the caller
          // declared" — an extension cannot read a name it never listed, nor
          // one belonging to somebody else. Absent is null, not an error: a
          // build without the value is a normal build.
          result = secrets[params['extensionKey'] as String?]?[params['name'] as String?];
        case 'webSocketOpen':
          _sockets.open(params, allowlist: _allowlistFor(webSocketAllowlists, params['extensionKey'] as String?) ?? const [], matches: _hostAllowed);
        case 'webSocketSend':
          _sockets.send(params);
        case 'webSocketClose':
          _sockets.close(params);
        case 'kvGet':
          // In-memory per-extension namespaces; credentials move to the
          // platform keychain when settings become persistent.
          result = _kv[params['ns'] ?? 'default']?[params['key']];
        case 'kvSet':
          _kv.putIfAbsent(params['ns'] as String? ?? 'default', () => {})[params['key'] as String] = params['value'];
        default:
          final completer = Completer<dynamic>();
          _pendingHostCalls[callId] = completer;
          emit({'type': 'hostCall', 'callId': callId, 'method': method, 'params': params});
          result = await completer.future;
      }
    } catch (e) {
      ok = false;
      result = '$e';
    }

    // Encode before deciding the response: if the app's handler returned
    // something JSON can't encode (a DateTime, a plain object), that must
    // become an ok:false response — never an undelivered one, which leaks
    // the kernel's pending call and wedges the awaiting hook until the
    // Dart-side timeout.
    _busy(chargedTo, () {
      String resultJson;
      try {
        resultJson = jsonEncode(result);
      } catch (e) {
        ok = false;
        resultJson = jsonEncode('host call $method returned an unencodable result: $e');
      }
      try {
        _js.hostResponse(callId, ok, resultJson);
      } catch (e) {
        emit({'type': 'log', 'message': 'ERROR delivering host response: $e'});
      }
    });
  }

  void handleHostCallResponse(int callId, bool ok, Object? result) {
    final completer = _pendingHostCalls.remove(callId);
    if (completer != null) {
      if (ok) {
        completer.complete(result);
      } else {
        completer.completeError(result ?? 'unknown host call error');
      }
    }
  }

  /// Whether [extensionKey] is [bundleKey] or one of the sub-extensions its
  /// bundle defines ('pota-all-parks' for 'pota') — same prefix rule the
  /// kernel applies to defineExtension.
  static bool _belongsTo(String extensionKey, String bundleKey) =>
      extensionKey == bundleKey || extensionKey.startsWith('$bundleKey-') || extensionKey.startsWith('${bundleKey}_');

  /// [extensionKey]'s entry in [allowlists], resolving a sub-extension to its
  /// bundle's declaration.
  static List<String>? _allowlistFor(Map<String, List<String>> allowlists, String? extensionKey) {
    if (extensionKey == null) return null;
    final exact = allowlists[extensionKey];
    if (exact != null) return exact;
    for (final entry in allowlists.entries) {
      if (_belongsTo(extensionKey, entry.key)) return entry.value;
    }
    return null;
  }

  /// Whether [host] matches a declared allowlist: exact hosts, `*.example.com`
  /// for subdomains, a lone `*` for any.
  static bool _hostAllowed(List<String>? allowlist, String host) {
    for (final entry in allowlist ?? const <String>[]) {
      if (entry == '*') return true;
      if (entry.startsWith('*.')) {
        if (host.endsWith(entry.substring(1))) return true;
      } else if (host == entry) {
        return true;
      }
    }
    return false;
  }

  /// Enforces the manifest's declared network capability (DESIGN.md §3).
  /// `extensionKey` is kernel-derived (bound at activation), never supplied
  /// by extension code, so this really is "who is calling", and the check
  /// runs against the ORIGINAL host — before any proxy rewrite.
  void _checkFetchAllowed(String? extensionKey, String host) {
    if (_hostAllowed(_allowlistFor(fetchAllowlists, extensionKey), host)) return;
    throw ExtensionHostException("fetch blocked: '$host' is not in extension '${extensionKey ?? 'unknown'}'s declared domains");
  }

  Future<Map<String, Object?>> _hostFetch(Map<String, dynamic> params) async {
    _checkFetchAllowed(params['extensionKey'] as String?, Uri.parse(params['url'] as String).host);
    final uri = extensionFetchUri(Uri.parse(params['url'] as String), onWeb: runningOnWeb);
    if (uri.scheme != 'https') {
      throw ExtensionHostException("fetch refused: '${params['url']}' is not https");
    }
    final method = (params['method'] as String? ?? 'GET').toUpperCase();
    final headers = ((params['headers'] ?? const <String, dynamic>{}) as Map).cast<String, String>();

    // Set last so it wins over anything addAll put in: http.Request.headers
    // is case-insensitive, so this stamps HaLo's canonical UA on every call —
    // except for whitelisted extensions that supplied their own (see
    // resolveFetchUserAgent and docs/design/network.md).
    final effectiveUA = resolveFetchUserAgent(
      canonical: userAgent,
      extensionKey: params['extensionKey'] as String?,
      overrides: userAgentOverrides,
      callerHeaders: headers,
    );
    final body = params['body'] as String?;

    // The caller's ask is ONE budget for the whole call — both phases and the
    // retry below — so it is measured, not handed out per phase. See
    // `remainingFetchTimeout`. The host's own defaults stay per-phase: they
    // were chosen that way, and waiting for headers is not the same thing as
    // reading a slow body.
    final requested = (params['timeout'] as num?)?.toInt();
    final spent = Stopwatch()..start();
    Duration remaining(Duration ceiling) => remainingFetchTimeout(requested: requested, elapsed: spent.elapsed, ceiling: ceiling);

    for (var attempt = 0; ; attempt++) {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (effectiveUA != null) request.headers['User-Agent'] = effectiveUA;
      if (body != null) request.body = body;

      try {
        final streamed = await _http.send(request).timeout(remaining(fetchHeaderTimeout));
        // Headers arriving is no guarantee the body ever finishes: a server
        // stalling mid-body would otherwise hang the calling hook indefinitely
        // (the timeout above only covers up to the response headers).
        final response = await http.Response.fromStream(streamed).timeout(remaining(fetchBodyTimeout));
        return {'status': response.statusCode, 'body': response.body};
      } on http.ClientException catch (e) {
        // A resolver hiccup during a network handover, sleep/wake or VPN
        // toggle surfaces as "Failed host lookup: '<host>'" (package:http's
        // IOClient wraps the underlying SocketException verbatim — this
        // never fires on web, where BrowserClient wraps a failed fetch()
        // differently) and is usually gone on the next try — one retry
        // clears it without troubling the caller. Anything else (timeout,
        // connection refused, HTTP error) still surfaces at once.
        //
        // The message must name this call's OWN target host: dart:io follows
        // redirects inside the same send(), so a lookup failure can name a
        // redirect's target host after the original host has already fully
        // received this request's body — retrying would then resend a
        // non-idempotent request (e.g. a sync POST) a second time. Only the
        // original hop is safe to retry.
        if (attempt > 0 || !e.message.startsWith("Failed host lookup: '${uri.host}'")) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 300 + _retryJitter.nextInt(200)));
      }
    }
  }

  static final _retryJitter = Random();

  void dispose() {
    _pump?.cancel();
    _load.dispose();
    _timers.dispose();
    _sockets.abandonAll();
    if (_ownsHttpClient) _http.close();
    _js.dispose();
  }
}
