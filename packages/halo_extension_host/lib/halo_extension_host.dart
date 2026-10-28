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
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart' show realNowUtc;
import 'package:http/http.dart' as http;

import 'src/engine_load.dart';
import 'src/extension_sockets.dart';
import 'src/extension_timers.dart';
import 'src/fetch_client.dart' if (dart.library.io) 'src/fetch_client_io.dart';
import 'src/fetch_policy.dart';
import 'src/hook_call_stats.dart';
import 'src/js_engine.dart';
import 'src/local_network.dart';

export 'src/extension_sockets.dart' show localNetworkEntry, maxWebSocketFrameSize, maxWebSocketsPerExtension;
export 'src/local_network.dart' show isLocalNetworkHost;
export 'src/engine_load.dart' show EngineLoadBucket, EngineLoadFeed, EngineLoadWindow, engineLoadBucketMicros;
export 'src/extension_timers.dart' show TimerSuspension;
export 'src/engine_runtime.dart' show ClockTravelState, ExtensionBundle, ExtensionHostException, HookTimeoutException;
export 'src/fetch_policy.dart' show fetchBodyTimeout, fetchHeaderTimeout;
export 'src/hook_call_stats.dart' show HookCallSample, HookLatencyStat, QueueWaitStat, batchLabel, summarizeLatencies;
export 'src/hook_calls.dart' show HookCalls;
// `show`n rather than exported wholesale: this library is imported unprefixed
// across the app, and a bare `stringsIn` in its public surface turns any
// same-named helper written later into an ambiguous-import error reported at
// the use site, nowhere near the cause.
export 'src/retired_built_ins.dart' show kRetiredBuiltIns;
export 'src/scoring_priority.dart'
    show Scorer, judgedVerdicts, judgesCandidate, judgesWorkedBefore, kWorkedBeforeAlerts, kWorkedBeforeNotices, refTypesOf, scorersFor, withoutWorkedBefore;

part 'src/host_core.dart';

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

  /// Caps [logLines] the same way: a runtime that logs on every hook call
  /// would otherwise fill an all-day session's memory with its own chatter.
  static const _maxLogLines = 2000;

  final _logs = StreamController<String>.broadcast();
  final _fatalErrors = StreamController<String>.broadcast();
  final _interpretationUpdates = StreamController<Map<String, dynamic>>.broadcast();
  final _timerSuspensions = StreamController<TimerSuspension>.broadcast();
  final _sampleAdded = StreamController<HookCallSample>.broadcast();

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

  /// Each hook label's end-to-end latency over [samples], timeouts included,
  /// slowest p95 first.
  List<HookLatencyStat> latencySummary() => summarizeLatencies(samples);

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

  /// Each sample as it joins [samples], timeouts included.
  Stream<HookCallSample> get sampleAdded => _sampleAdded.stream;

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

    /// Whether the app is in developer mode at boot: the one state that lets
    /// a wildcard `domains` grant reach the local network — see
    /// [setDeveloperMode].
    bool developerMode = false,
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
        return await _startInIsolate(
          kernelSource,
          extensions,
          onHostCall,
          fetchAllowlists,
          webSocketAllowlists,
          userAgent,
          userAgentOverrides,
          secrets,
          clock,
          developerMode,
        );
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
          developerMode,
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
      developerMode,
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
    bool developerMode,
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
        developerMode: developerMode,
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
    bool developerMode = false,
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
      developerMode: developerMode,
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

  void _addSample(HookCallSample sample) {
    samples.add(sample);
    if (samples.length > _maxSamples) samples.removeAt(0);
    // A call's timeout can fire after [dispose] has closed the stream.
    if (!_sampleAdded.isClosed) _sampleAdded.add(sample);
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
      if (_inFlight.remove(id) case (final label, final watch)) {
        _addSample(HookCallSample(label: label, totalMillis: watch.elapsedMilliseconds, jsMillis: 0, timedOut: true));
      }
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

  /// Tells the host whether the app is in developer mode: the one state that
  /// lets a wildcard `domains` grant reach the local network, for a server of
  /// the developer's own. Main-isolate state, so it is pushed — send it
  /// whenever it changes; [start] takes it for the boot.
  void setDeveloperMode(bool on) => _dispatch({'type': 'setDeveloperMode', 'on': on});

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
          _addSample(
            HookCallSample(
              label: flight.$1,
              totalMillis: flight.$2.elapsedMilliseconds,
              jsMillis: (msg['jsMillis'] as num?)?.toInt() ?? 0,
              queueMicros: (msg['queueMicros'] as num?)?.toInt() ?? 0,
            ),
          );
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
    if (logLines.length > _maxLogLines) logLines.removeRange(0, logLines.length - _maxLogLines);
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
    await _sampleAdded.close();
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
