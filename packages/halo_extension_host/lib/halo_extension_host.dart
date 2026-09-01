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
//               __polo.hostResponse(callId, ok, resultJson)
//               __polo.unloadBundle(key) + beginBundle/eval/endBundle +
//               __polo.activateReloaded(token)  — the dev loop's reload
//   JS → Dart   'polo' channel messages:
//               {type:'result', id, ok, value|error, jsMillis}
//               {type:'partial', id, keys}    — an invokeAll's roster, and
//               {type:'partial', id, entry}   — one hook of it as it settles;
//                                               both only when wantsPartials
//               {type:'hostCall', callId, method, params}
//               {type:'log', message}
//               {type:'reloadComplete', token, ok, error?}

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:halo_core/halo_core.dart' show ham2kSsoFetchUri, sotaSsoHost;
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart' show visibleForTesting;

import 'src/js_engine.dart';

export 'src/engine_runtime.dart'
    show ClockTravelState, ExtensionBundle, ExtensionHostException, HookTimeoutException;
// `show`n rather than exported wholesale: this library is imported unprefixed
// across the app, and a bare `stringsIn` in its public surface turns any
// same-named helper written later into an ambiguous-import error reported at
// the use site, nowhere near the cause.
export 'src/scoring_priority.dart'
    show
        Scorer,
        judgesWorkedBefore,
        kWorkedBeforeAlerts,
        kWorkedBeforeNotices,
        refTypesOf,
        scorersFor,
        withoutWorkedBefore;

typedef HostCallHandler = Future<dynamic> Function(String method, Map<String, dynamic> params);

/// One completed hook invocation, for latency analysis.
class HookCallSample {
  final String label;
  final int totalMillis;
  final int jsMillis;

  const HookCallSample({required this.label, required this.totalMillis, required this.jsMillis});
}

/// The host's own allowances for a fetch, and the ceiling an extension's
/// `FetchOptions.timeout` is clamped to.
const fetchHeaderTimeout = Duration(seconds: 15);
const fetchBodyTimeout = Duration(seconds: 30);

/// How long this phase of a fetch may still take: what remains of the
/// caller's [requested] millisecond budget after [elapsed], capped at the
/// host's [ceiling] for the phase.
///
/// Downward only. An extension may declare a request not worth waiting the
/// default for; it may not award itself a longer leash than the host allows,
/// which is the whole reason the host sets one.
///
/// One budget for the whole call, not one per phase. Giving each phase the
/// full ask would let a 3s request take 3s waiting for headers and 3s more
/// reading the body — and 12s once the DNS retry doubles it — so a caller
/// that carefully bounded an optional request would still cost its fan-out
/// everything it was trying to save.
///
/// A zero or negative ask is a caller's bug rather than a request to fail
/// instantly, and falls back to [ceiling] rather than making every fetch
/// throw. A budget genuinely spent DOES return zero: the caller said how long
/// this was worth, and the request is already on the wire by then, so the
/// timeout has something real to interrupt.
@visibleForTesting
Duration remainingFetchTimeout({required int? requested, required Duration elapsed, required Duration ceiling}) {
  if (requested == null || requested <= 0) return ceiling;
  final left = Duration(milliseconds: requested) - elapsed;
  if (left >= ceiling) return ceiling;
  return left.isNegative ? Duration.zero : left;
}

/// The `User-Agent` a `host.fetch` should send. HaLo's [canonical] UA wins,
/// so every request identifies the app consistently — *unless* the calling
/// [extensionKey] is in [overrides] (the manifest's `allowUserAgentOverride`)
/// and [callerHeaders] already carries a `User-Agent`, in which case that one
/// is kept. A whitelisted extension that sets none still gets [canonical], so
/// the request is never left unidentified. See docs/design/network.md.
@visibleForTesting
String? resolveFetchUserAgent({
  required String? canonical,
  required String? extensionKey,
  required Set<String> overrides,
  required Map<String, String> callerHeaders,
}) {
  String? callerUA;
  for (final entry in callerHeaders.entries) {
    if (entry.key.toLowerCase() == 'user-agent') {
      callerUA = entry.value;
      break;
    }
  }
  final mayOverride = extensionKey != null && overrides.contains(extensionKey) && callerUA != null;
  if (mayOverride) return callerUA;
  return canonical ?? callerUA;
}

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

  ExtensionHost._({
    required this.runningInIsolate,
    required this.engine,
    required this.loadMillis,
    this.onHostCall,
  });

  Stream<String> get logs => _logs.stream;

  /// See [_activated]'s doc comment.
  Future<void> get activated => _activated.future;

  /// A `command` hook pushed a later CommandInterpretation for an `input` it
  /// was already asked to interpret (see `host.updateInterpretation`'s SDK
  /// doc) — `{'input': String, 'interpretation': Map<String, dynamic>}` per
  /// event. Unlike hook calls, there's no request/response pairing here:
  /// the caller decides for itself whether `input` is still current.
  Stream<Map<String, dynamic>> get interpretationUpdates => _interpretationUpdates.stream;

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
  static Future<ExtensionHost> start({
    required String kernelSource,
    required List<ExtensionBundle> extensions,
    bool useIsolate = true,
    HostCallHandler? onHostCall,
    Map<String, Map<String, String>> secrets = const {},
    http.Client? httpClient,
    Map<String, List<String>> fetchAllowlists = const {},
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
        return await _startInIsolate(kernelSource, extensions, onHostCall, fetchAllowlists, userAgent, userAgentOverrides, secrets, clock);
      } catch (e) {
        // Fall through to in-process mode; the spike wants to know when this
        // happens, so surface it loudly on the first log line.
        final host = await _startInProcess(
            kernelSource, extensions, onHostCall, fetchAllowlists, userAgent, userAgentOverrides, secrets, clock, httpClient);
        host._log('WARN isolate mode failed ($e), running in-process');
        return host;
      }
    }
    return _startInProcess(
        kernelSource, extensions, onHostCall, fetchAllowlists, userAgent, userAgentOverrides, secrets, clock, httpClient);
  }

  static Future<ExtensionHost> _startInIsolate(String kernelSource, List<ExtensionBundle> extensions, HostCallHandler? onHostCall,
      Map<String, List<String>> fetchAllowlists, String? userAgent, Set<String> userAgentOverrides,
      Map<String, Map<String, String>> secrets, ClockTravelState clock) async {
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
      final desc = message is List
          ? [for (final part in message) '$part'].where((s) => s.isNotEmpty).join('\n')
          : '$message';
      fatal('extension isolate error: $desc');
    });
    onExit.listen((_) => fatal('extension isolate exited unexpectedly'));

    final isolate = await Isolate.spawn(
      _hostIsolateMain,
      _HostIsolateInit(
        mainPort: fromIsolate.sendPort,
        kernelSource: kernelSource,
        bundles: [for (final p in extensions) [p.key, p.source]],
        fetchAllowlists: fetchAllowlists,
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

    host = ExtensionHost._(
      runningInIsolate: true,
      engine: readyMsg['engine'] as String,
      loadMillis: readyMsg['loadMillis'] as int,
      onHostCall: onHostCall,
    );
    host._isolate = isolate;
    host._toIsolate = toIsolate;
    host._isolatePorts.addAll([fromIsolate, onError, onExit]);
    earlyMessages.forEach(host._onCoreMessage);
    return host;
  }

  static Future<ExtensionHost> _startInProcess(String kernelSource, List<ExtensionBundle> extensions, HostCallHandler? onHostCall,
      Map<String, List<String>> fetchAllowlists, String? userAgent, Set<String> userAgentOverrides,
      Map<String, Map<String, String>> secrets, ClockTravelState clock, [http.Client? httpClient]) async {
    final earlyMessages = <Map<String, dynamic>>[];
    ExtensionHost? host;
    final core = _HostCore(
        fetchAllowlists: fetchAllowlists,
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
        });
    final loadMillis = await core.init(kernelSource, extensions, clock: clock);
    host = ExtensionHost._(
      runningInIsolate: false, 
      engine: core.engineDescription, 
      loadMillis: loadMillis,
      onHostCall: onHostCall,
    );
    host._inProcessCore = core;
    earlyMessages.forEach(host._onCoreMessage);
    return host;
  }

  /// Invokes `method` on the highest-priority hook registered under
  /// `category` (optionally narrowed to a specific hook `key`).
  ///
  /// `args` must be JSON-encodable. Returns the hook's JSON result.
  Future<dynamic> invokeHook(
    String category, {
    String? key,
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) {
    return _send('invoke', '$category.$method', {
      'category': category,
      'key': key,
      'method': method,
      'argsJson': jsonEncode(args ?? const <String, Object?>{}),
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
      final result = await _send('invokeAll', '$category.$method*', {
        'category': category,
        'method': method,
        'argsJson': jsonEncode(args ?? const <String, Object?>{}),
        // Narration is not free — it puts every hook's result on the bridge a
        // second time — so it is requested only by a caller that will keep it.
        'wantsPartials': partialOnTimeout,
      }, timeout, id: id);
      return (result as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } on HookTimeoutException {
      // Only a timeout salvages. A runtime that died, or a fan-out the kernel
      // failed wholesale, has nothing trustworthy to hand back — those stay
      // exceptions whatever `partialOnTimeout` says.
      final progress = _partials.remove(id);
      if (!partialOnTimeout || progress == null) rethrow;
      return progress.settledPlusMissing(timeout);
    }
  }

  Future<dynamic> _send(String type, String label, Map<String, Object?> fields, Duration timeout, {int? id}) async {
    if (_dead) {
      throw ExtensionHostException('extension runtime is dead (hook $label not attempted)');
    }
    id ??= _nextId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _inFlight[id] = (label, Stopwatch()..start());

    _dispatch({'type': type, 'id': id, ...fields});

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
    _dispatch({
      'type': 'reloadBundle',
      'token': token,
      'key': bundle.key,
      'source': bundle.source,
      'domains': ?domains,
    });
    return completer.future.timeout(timeout, onTimeout: () {
      _pendingReloads.remove(token);
      throw HookTimeoutException('reloading ${bundle.key} timed out after ${timeout.inMilliseconds}ms');
    });
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
  void setClockTravel({
    required int anchorRealMillis,
    required int anchorVirtualMillis,
    required double speed,
  }) {
    _dispatch({
      'type': 'setClockTravel',
      'anchorRealMillis': anchorRealMillis,
      'anchorVirtualMillis': anchorVirtualMillis,
      'speed': speed,
    });
  }

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
          samples.add(HookCallSample(
            label: flight.$1,
            totalMillis: flight.$2.elapsedMilliseconds,
            jsMillis: (msg['jsMillis'] as num?)?.toInt() ?? 0,
          ));
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
          completer.completeError(
              ExtensionHostException('reloading bundle failed: ${msg['error'] ?? 'unknown error'}'));
        } else {
          completer.complete();
        }
      case 'updateInterpretation':
        final input = msg['input'] as String?;
        if (input == null) return;
        _interpretationUpdates.add({
          'input': input,
          'interpretation': ((msg['interpretation'] as Map?) ?? const {}).cast<String, dynamic>(),
        });
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
      _toIsolate?.send({
        'type': 'hostCallResponse',
        'callId': callId,
        'ok': ok,
        'result': result,
      });
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
  }
}

/// What one in-flight `invokeAll` has reported: the roster of hooks it is
/// about to call, then their entries as they settle.
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
  final List<List<String>> bundles;
  final Map<String, List<String>> fetchAllowlists;
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
      secrets: init.secrets,
      userAgent: init.userAgent,
      userAgentOverrides: init.userAgentOverrides);
  try {
    final loadMillis = await core.init(
      init.kernelSource,
      [for (final b in init.bundles) ExtensionBundle(key: b[0], source: b[1])],
      clock: ClockTravelState(
        anchorRealMillis: init.clockAnchorRealMillis,
        anchorVirtualMillis: init.clockAnchorVirtualMillis,
        speed: init.clockSpeed,
      ),
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
      core.handleHostCallResponse(
        msg['callId'] as int,
        msg['ok'] as bool,
        msg['result'],
      );
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

  _HostCore(
      {required this.emit,
      Map<String, List<String>> fetchAllowlists = const {},
      this.secrets = const {},
      this.userAgent,
      this.userAgentOverrides = const {},
      http.Client? httpClient})
      : fetchAllowlists = Map.of(fetchAllowlists),
        _http = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  String get engineDescription => _js.engineDescription;

  Future<int> init(String kernelSource, List<ExtensionBundle> bundles,
      {ClockTravelState clock = const ClockTravelState.real()}) async {
    final stopwatch = Stopwatch()..start();
    _js = createEngineRuntime();
    _js.onMessage(_onPoloMessage);
    _js.onFatalError(_onFatalError);
    try {
      await _js.load(kernelSource, bundles, clock: clock);
    } catch (e) {
      _js.dispose();
      rethrow;
    }

    return (stopwatch..stop()).elapsedMilliseconds;
  }

  void handle(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'invoke':
      case 'invokeAll':
        final id = msg['id'] as int;
        _outstandingIds.add(id);
        _ensurePumping();
        try {
          if (msg['type'] == 'invoke') {
            _js.invoke(id, msg['category'] as String, msg['key'] as String?, msg['method'] as String, msg['argsJson'] as String);
          } else {
            _js.invokeAll(id, msg['category'] as String, msg['method'] as String, msg['argsJson'] as String,
                wantsPartials: msg['wantsPartials'] == true);
          }
        } catch (e) {
          _outstandingIds.remove(id);
          emit({'type': 'result', 'id': id, 'ok': false, 'error': '$e'});
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
          _js.reloadBundle(ExtensionBundle(key: key, source: msg['source'] as String), token);
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
      case 'kvSet':
        _kv.putIfAbsent(msg['ns'] as String? ?? 'default', () => {})[msg['key'] as String] = msg['value'];
      case 'invalidateContext':
        try {
          _js.invalidateContext();
        } catch (e) {
          emit({'type': 'log', 'message': 'ERROR invalidating hook context: $e'});
        }
      case 'setClockTravel':
        try {
          _js.setClockTravel(
            msg['anchorRealMillis'] as int,
            msg['anchorVirtualMillis'] as int,
            (msg['speed'] as num).toDouble(),
          );
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

  /// Pumps the JS job queue only while hook calls are outstanding, instead
  /// of a permanent fast timer.
  void _ensurePumping() {
    _pump ??= Timer.periodic(const Duration(milliseconds: 5), (_) {
      _js.pump();
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
    for (final token in _reloadsInFlight.toList()) {
      emit({'type': 'reloadComplete', 'token': token, 'ok': false, 'error': message});
    }
    _reloadsInFlight.clear();
    emit({'type': 'fatalError', 'error': message});
  }

  void _onPoloMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'result':
        _outstandingIds.remove(msg['id']);
        emit(msg);
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
      case 'updateInterpretation':
        emit(msg);
      case 'hostCall':
        _handleHostCall(
          (msg['callId'] as num).toInt(),
          msg['method'] as String,
          ((msg['params'] ?? const {}) as Map).cast<String, dynamic>(),
        );
    }
  }

  Future<void> _handleHostCall(int callId, String method, Map<String, dynamic> params) async {
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
        case 'kvGet':
          // In-memory per-extension namespaces; credentials move to the
          // platform keychain when settings become persistent.
          result = _kv[params['ns'] ?? 'default']?[params['key']];
        case 'kvSet':
          _kv.putIfAbsent(params['ns'] as String? ?? 'default', () => {})[params['key'] as String] = params['value'];
        default:
          final completer = Completer<dynamic>();
          _pendingHostCalls[callId] = completer;
          emit({
            'type': 'hostCall',
            'callId': callId,
            'method': method,
            'params': params,
          });
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

  Uri _resolveFetchUri(String urlString) {
    final uri = Uri.parse(urlString);
    if (runningOnWeb) {
      // SOTA's SSO host routes by PATH, not by host: exactly the two
      // endpoints services.ham2k.net proxies go through it, and every other
      // path on that host stays direct. Keeping the rest direct is the point
      // — a refresh grant and the tokens it returns transit Ham2K
      // infrastructure only where a browser leaves no alternative, and never
      // on a native build. See halo_core's ham2kSsoFetchUri for what that
      // costs and why the discovery document is not among them.
      if (uri.host == sotaSsoHost) {
        return ham2kSsoFetchUri(uri, onWeb: true);
      }
      const allowedDomains = {
        'api.pota.app',
        'logbook.qrz.com',
        'xmldata.qrz.com',
        'country-files.com',
        'pota.app',
        'www.sotadata.org.uk',
        'sotadata.org.uk',
        'www.hamqsl.com',
        'llota.app',
        // Spot feeds and self-spotting on hosts that send no CORS headers.
        // Narrower than the data-file allowlist in DataFileManager: the other
        // hosts there serve a reference file and nothing else. The remaining
        // spot sources (spots.wwff.co, api-db2.sota.org.uk, api.open-meteo.com,
        // api.wwbota.org, LoFi) answer cross-origin GETs directly.
        'www.cqgma.org',
        'ontheair.nz',
        'www.rozhledny.eu',
        'www.parksnpeaks.org',
      };
      if (allowedDomains.contains(uri.host)) {
        return Uri.parse('https://services.ham2k.net/${uri.host}${uri.path}${uri.hasQuery ? "?${uri.query}" : ""}');
      }
    }
    return uri;
  }

  /// The allowlist for [extensionKey], resolving a sub-extension ('pota-
  /// all-parks') to its bundle's declaration ('pota') — same prefix rule the
  /// kernel applies to defineExtension.
  List<String>? _fetchAllowlistFor(String? extensionKey) {
    if (extensionKey == null) return null;
    final exact = fetchAllowlists[extensionKey];
    if (exact != null) return exact;
    for (final entry in fetchAllowlists.entries) {
      if (extensionKey.startsWith('${entry.key}-') || extensionKey.startsWith('${entry.key}_')) {
        return entry.value;
      }
    }
    return null;
  }

  /// Enforces the manifest's declared network capability (DESIGN.md §3).
  /// `extensionKey` is kernel-derived (bound at activation), never supplied
  /// by extension code, so this really is "who is calling", and the check
  /// runs against the ORIGINAL host — before any web proxy rewrite.
  void _checkFetchAllowed(String? extensionKey, String host) {
    final allowlist = _fetchAllowlistFor(extensionKey);
    if (allowlist != null) {
      for (final entry in allowlist) {
        if (entry == '*') return;
        if (entry.startsWith('*.')) {
          if (host.endsWith(entry.substring(1))) return;
        } else if (host == entry) {
          return;
        }
      }
    }
    throw ExtensionHostException(
        "fetch blocked: '$host' is not in extension '${extensionKey ?? 'unknown'}'s declared domains");
  }

  Future<Map<String, Object?>> _hostFetch(Map<String, dynamic> params) async {
    _checkFetchAllowed(params['extensionKey'] as String?, Uri.parse(params['url'] as String).host);
    final uri = _resolveFetchUri(params['url'] as String);
    if (uri.scheme != 'https') {
      throw ExtensionHostException('only https URLs are allowed');
    }
    final method = (params['method'] as String? ?? 'GET').toUpperCase();
    final headers = ((params['headers'] ?? const {}) as Map).cast<String, String>();

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
    Duration remaining(Duration ceiling) =>
        remainingFetchTimeout(requested: requested, elapsed: spent.elapsed, ceiling: ceiling);

    for (var attempt = 0;; attempt++) {
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
        await Future.delayed(Duration(milliseconds: 300 + _retryJitter.nextInt(200)));
      }
    }
  }

  static final _retryJitter = Random();

  void dispose() {
    _pump?.cancel();
    if (_ownsHttpClient) _http.close();
    _js.dispose();
  }
}
