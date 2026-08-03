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
//   JS → Dart   'polo' channel messages:
//               {type:'result', id, ok, value|error, jsMillis}
//               {type:'hostCall', callId, method, params}
//               {type:'log', message}

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;

import 'src/js_engine.dart';

export 'src/engine_runtime.dart' show ExtensionBundle, ExtensionHostException;

typedef HostCallHandler = Future<dynamic> Function(String method, Map<String, dynamic> params);

/// One completed hook invocation, for latency analysis.
class HookCallSample {
  final String label;
  final int totalMillis;
  final int jsMillis;

  const HookCallSample({required this.label, required this.totalMillis, required this.jsMillis});
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
  int _nextId = 1;
  bool _dead = false;
  bool _disposed = false;

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
  /// of them, and the absence of any seam here previously let a wrong spot
  /// payload reach review untested.
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
  }) async {
    // On web there are no Dart isolates — the "in-process" core runs a Web
    // Worker anyway, so extension work is still off the UI thread. Branching
    // here (instead of letting Isolate.spawn throw) keeps a misleading
    // "isolate mode failed" warning out of every web boot.
    // A client is not sendable across an isolate boundary, so supplying one
    // means in-process — tests that stub the network want that anyway, and
    // silently ignoring it would leave them hitting the real one.
    if (useIsolate && !kIsWeb && httpClient == null) {
      try {
        return await _startInIsolate(kernelSource, extensions, onHostCall, fetchAllowlists, userAgent, userAgentOverrides, secrets);
      } catch (e) {
        // Fall through to in-process mode; the spike wants to know when this
        // happens, so surface it loudly on the first log line.
        final host = await _startInProcess(
            kernelSource, extensions, onHostCall, fetchAllowlists, userAgent, userAgentOverrides, secrets, httpClient);
        host._log('WARN isolate mode failed ($e), running in-process');
        return host;
      }
    }
    return _startInProcess(
        kernelSource, extensions, onHostCall, fetchAllowlists, userAgent, userAgentOverrides, secrets, httpClient);
  }

  static Future<ExtensionHost> _startInIsolate(String kernelSource, List<ExtensionBundle> extensions, HostCallHandler? onHostCall,
      Map<String, List<String>> fetchAllowlists, String? userAgent, Set<String> userAgentOverrides,
      Map<String, Map<String, String>> secrets) async {
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
      Map<String, Map<String, String>> secrets, [http.Client? httpClient]) async {
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
    final loadMillis = await core.init(kernelSource, extensions);
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
  Future<List<Map<String, dynamic>>> invokeHookAll(
    String category, {
    required String method,
    Object? args,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final result = await _send('invokeAll', '$category.$method*', {
      'category': category,
      'method': method,
      'argsJson': jsonEncode(args ?? const <String, Object?>{}),
    }, timeout);
    return (result as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<dynamic> _send(String type, String label, Map<String, Object?> fields, Duration timeout) async {
    if (_dead) {
      throw ExtensionHostException('extension runtime is dead (hook $label not attempted)');
    }
    final id = _nextId++;
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
      throw ExtensionHostException('hook $label timed out after ${timeout.inMilliseconds}ms');
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

  void _onCoreMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'result':
        // Defensive cast: a malformed id from the JS side must not throw
        // inside this listener (on the isolate path that used to be exactly
        // what killed the isolate; here it would kill the subscription).
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
        if (msg['ok'] == true) {
          completer.complete(msg['value']);
        } else {
          completer.completeError(ExtensionHostException(msg['error'] as String? ?? 'unknown extension error'));
        }
      case 'log':
        _log(msg['message'] as String? ?? '');
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
        _fatalErrors.add(error);
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

    // Ask the isolate to shut the engine down before killing it.
    //
    // Isolate.kill reclaims Dart memory, not the JS engine's. QuickJS holds a
    // real malloc'd heap — the kernel bundle alone needs 10-12MB before any
    // extension loads — and only halo_qjs_free returns it. The isolate entry
    // point has always had a `{'type':'dispose'}` branch that runs
    // core.dispose(), but nothing ever sent the message, so that branch and
    // the EngineRuntime.dispose() behind it were dead code. Under flutter_js
    // that was invisible; now it leaks the engine on every restart, and the
    // crash-restart path in extension_service.dart retries with backoff.
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

class _HostIsolateInit {
  final SendPort mainPort;
  final String kernelSource;
  final List<List<String>> bundles;
  final Map<String, List<String>> fetchAllowlists;
  /// Extension key → its own build-time API key, resolved host-side.
  final Map<String, Map<String, String>> secrets;
  final String? userAgent;
  final Set<String> userAgentOverrides;

  const _HostIsolateInit({
    required this.mainPort,
    required this.kernelSource,
    required this.bundles,
    required this.fetchAllowlists,
    required this.secrets,
    required this.userAgent,
    required this.userAgentOverrides,
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

  /// Per-extension fetch capability — see [ExtensionHost.start].
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

  _HostCore(
      {required this.emit,
      this.fetchAllowlists = const {},
      this.secrets = const {},
      this.userAgent,
      this.userAgentOverrides = const {},
      http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  String get engineDescription => _js.engineDescription;

  Future<int> init(String kernelSource, List<ExtensionBundle> bundles) async {
    final stopwatch = Stopwatch()..start();
    _js = createEngineRuntime();
    _js.onMessage(_onPoloMessage);
    _js.onFatalError(_onFatalError);
    try {
      await _js.load(kernelSource, bundles);
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
            _js.invokeAll(id, msg['category'] as String, msg['method'] as String, msg['argsJson'] as String);
          }
        } catch (e) {
          _outstandingIds.remove(id);
          emit({'type': 'result', 'id': id, 'ok': false, 'error': '$e'});
        }
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
    }
  }

  /// Pumps the JS job queue only while hook calls are outstanding, instead
  /// of a permanent fast timer.
  void _ensurePumping() {
    _pump ??= Timer.periodic(const Duration(milliseconds: 5), (_) {
      _js.pump();
      if (_outstandingIds.isEmpty) {
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
    emit({'type': 'fatalError', 'error': message});
  }

  void _onPoloMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'result':
        _outstandingIds.remove(msg['id']);
        emit(msg);
      case 'log':
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
    if (kIsWeb) {
      // OAuth/SSO hosts are never proxied, even on web builds where that
      // means the call is CORS-blocked instead: refresh grants and the
      // tokens they return must only ever transit the identity provider
      // itself, not services.ham2k.net.
      const ssoDomains = {
        'sso.sota.org.uk',
      };
      if (ssoDomains.contains(uri.host)) {
        return uri;
      }
      const allowedDomains = {
        'api.pota.app',
        'logbook.qrz.com',
        'xmldata.qrz.com',
        'api.hamdb.org',
        'country-files.com',
        'pota.app',
        'www.sotadata.org.uk',
        'sotadata.org.uk',
        'www.hamqsl.com',
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

    for (var attempt = 0;; attempt++) {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (effectiveUA != null) request.headers['User-Agent'] = effectiveUA;
      if (body != null) request.body = body;

      try {
        final streamed = await _http.send(request).timeout(const Duration(seconds: 15));
        // Headers arriving is no guarantee the body ever finishes: a server
        // stalling mid-body would otherwise hang the calling hook indefinitely
        // (the 15s above only covers up to the response headers).
        final response = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 30));
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
