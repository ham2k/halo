// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The side of the host that owns the JS runtime: what the extension isolate
// runs, and [_HostCore], which runs there or — the fallback — in the main
// isolate. Everything it says to [ExtensionHost] goes through `emit`, as the
// messages listed at the top of halo_extension_host.dart.

part of '../halo_extension_host.dart';

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

  /// Developer mode at boot — see [_HostCore.developerMode].
  final bool developerMode;

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
    required this.developerMode,
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
    developerMode: init.developerMode,
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

  /// The transport for a hop the local network is not the caller's to reach:
  /// every hop but one developer mode, or an exact `domains` entry, admits
  /// there. Natively it resolves the name itself and refuses a private
  /// answer (fetch_client_io.dart); an injected client stands in for both.
  final http.Client _httpGuarded;

  /// Whether the app is in developer mode, as last told: the one state that
  /// admits a wildcard grant to the local network, for a server of the
  /// developer's own. Pushed by `setDeveloperMode` when it changes.
  bool developerMode;

  /// `host.fetch` calls in flight per extension, against [kMaxFetchesInFlight].
  final Map<String, int> _fetchesInFlight = {};

  /// Only close what we opened: an injected client belongs to the caller and
  /// may outlive this host (or be shared between several).
  final bool _ownsHttpClient;
  final Map<String, Map<String, Object?>> _kv = {};

  /// Keys the app seeded (`setKV`), by namespace: outside the bundle's quota,
  /// which is for what an extension stores itself, however either rewrites
  /// them later. Each is a key its namespace holds.
  final Map<String, Set<String>> _kvSeeded = {};

  /// Host calls awaiting an answer, per bundle and in all, against
  /// [kMaxHostCallsPending] and [kMaxHostCallsPendingTotal].
  final Map<String, int> _hostCallsPending = {};
  int _hostCallsPendingTotal = 0;
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
    this.developerMode = false,
    http.Client? httpClient,
  }) : fetchAllowlists = Map.of(fetchAllowlists),
       _http = httpClient ?? http.Client(),
       _httpGuarded = httpClient ?? guardedFetchClient(),
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
        // The app's own seeding: counted, so the quota judges what the bundle
        // then adds on top, but never refused.
        _kvSet(msg['ns'] as String? ?? 'default', msg['key'] as String, msg['value'], budgeted: false);
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
      case 'setDeveloperMode':
        developerMode = msg['on'] as bool;
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
    // Budgeted by the caller's bundle, as fetch slots are; a call the kernel
    // did not attribute counts against the ceiling alone. Resolved inside the
    // try: a call malformed here is answered, like one that fails anywhere.
    var slot = '';
    var admitted = false;
    try {
      slot = _bundleOf(params['extensionKey'] as String?);
      _admitHostCall(slot, method);
      admitted = true;
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
          _sockets.open(
            params,
            allowlist: _allowlistFor(webSocketAllowlists, params['extensionKey'] as String?) ?? const [],
            matches: _hostAllowed,
            bundle: slot,
          );
        case 'webSocketSend':
          _sockets.send(params);
        case 'webSocketClose':
          _sockets.close(params);
        case 'kvGet':
          // In-memory per-extension namespaces; credentials move to the
          // platform keychain when settings become persistent.
          result = _kv[params['ns'] ?? 'default']?[params['key']];
        case 'kvSet':
          _kvSet(params['ns'] as String? ?? 'default', params['key'] as String, params['value'], budgeted: true);
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
    if (admitted) _releaseHostCall(slot);

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
  static List<String>? _allowlistFor(Map<String, List<String>> allowlists, String? extensionKey) => allowlists[_bundleKeyFor(allowlists, extensionKey)];

  /// The bundle [extensionKey] belongs to, for everything the host holds a
  /// bundle to: `fetchAllowlists` lists every loaded bundle, domains declared
  /// or none, so it doubles as the registry [_bundleKeyFor] resolves against.
  String _bundleOf(String? extensionKey) => _bundleKeyFor(fetchAllowlists, extensionKey);

  /// The bundle [extensionKey] was loaded from, as [allowlists] knows it:
  /// itself, or the one it is a sub-extension of. The one resolution behind a
  /// grant, the fetch slots and every budget a bundle is held to, so a
  /// bundle's extensions share them all. A key no bundle claims counts for
  /// itself, which the map answers null for.
  static String _bundleKeyFor(Map<String, List<String>> allowlists, String? extensionKey) {
    if (extensionKey == null) return '';
    if (allowlists.containsKey(extensionKey)) return extensionKey;
    for (final key in allowlists.keys) {
      if (_belongsTo(extensionKey, key)) return key;
    }
    return extensionKey;
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

  /// Admits one more host call from [slot], or refuses it: a bundle may have
  /// [kMaxHostCallsPending] awaiting an answer, and all of them together
  /// [kMaxHostCallsPendingTotal]. Refused rather than queued, so a loop that
  /// fires without awaiting fails where it runs instead of parking a completer
  /// here, and one in the kernel, for as long as the app takes to answer.
  void _admitHostCall(String slot, String method) {
    final pending = _hostCallsPending[slot] ?? 0;
    if (slot.isNotEmpty && pending >= kMaxHostCallsPending) {
      throw ExtensionHostException("host call refused: '$slot' already has $pending calls awaiting an answer ($method)");
    }
    if (_hostCallsPendingTotal >= kMaxHostCallsPendingTotal) {
      throw ExtensionHostException('host call refused: $_hostCallsPendingTotal calls are awaiting an answer across every extension ($method)');
    }
    _hostCallsPending[slot] = pending + 1;
    _hostCallsPendingTotal++;
  }

  void _releaseHostCall(String slot) {
    final left = _hostCallsPending[slot]! - 1;
    if (left == 0) {
      _hostCallsPending.remove(slot);
    } else {
      _hostCallsPending[slot] = left;
    }
    _hostCallsPendingTotal--;
  }

  /// How many keys [slot]'s extensions store themselves, read from the store
  /// so that a sub-extension's keys follow its bundle even when the bundle
  /// registered after they were stored. `kvSet` is rare enough to pay for it.
  int _kvKeysOf(String slot) {
    var keys = 0;
    for (final MapEntry(key: ns, value: space) in _kv.entries) {
      if (_bundleOf(ns) != slot) continue;
      final seeded = _kvSeeded[ns];
      keys += seeded == null ? space.length : space.keys.where((key) => !seeded.contains(key)).length;
    }
    return keys;
  }

  /// Stores [value] under [key] in [ns], or frees the key for null. A seeded
  /// write ([budgeted] false) is the app's own and never refused; an
  /// extension's is held to its bundle's quota: [kMaxKvKeysPerBundle] keys of
  /// its own, each entry — key and value — [kMaxKvEntryChars] of JSON.
  /// Measured as JSON because that is what crossed the bridge, and what the
  /// heap holds in its stead.
  void _kvSet(String ns, String key, Object? value, {required bool budgeted}) {
    final space = _kv.putIfAbsent(ns, () => {});
    if (value == null) {
      space.remove(key);
      _kvSeeded[ns]?.remove(key);
      return;
    }
    if (budgeted) {
      final chars = key.length + jsonEncode(value).length;
      if (chars > kMaxKvEntryChars) {
        throw ExtensionHostException("kvSet refused: '$key' and its value are $chars characters of JSON, more than $kMaxKvEntryChars");
      }
      if (!space.containsKey(key)) {
        final slot = _bundleOf(ns);
        if (_kvKeysOf(slot) >= kMaxKvKeysPerBundle) {
          throw ExtensionHostException("kvSet refused: '$slot' already holds $kMaxKvKeysPerBundle keys");
        }
      }
    } else {
      _kvSeeded.putIfAbsent(ns, () => {}).add(key);
    }
    space[key] = value;
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
    final extensionKey = params['extensionKey'] as String?;
    // Counted before anything is sent and released however the call ends,
    // so a refused or failed fetch never keeps a slot.
    final slot = _bundleOf(extensionKey);
    final inFlight = _fetchesInFlight[slot] ?? 0;
    if (inFlight >= kMaxFetchesInFlight) {
      throw ExtensionHostException("fetch refused: '$slot' already has $inFlight requests in flight");
    }
    _fetchesInFlight[slot] = inFlight + 1;
    try {
      return await _fetch(extensionKey, params);
    } finally {
      final left = _fetchesInFlight[slot]! - 1;
      if (left == 0) {
        _fetchesInFlight.remove(slot);
      } else {
        _fetchesInFlight[slot] = left;
      }
    }
  }

  Future<Map<String, Object?>> _fetch(String? extensionKey, Map<String, dynamic> params) async {
    // The URL as the extension named it, before any proxy rewrite: the
    // allowlist is judged on it, and a redirect's relative Location resolves
    // against it.
    var target = Uri.parse(params['url'] as String);
    var route = _fetchTarget(extensionKey, target);
    var method = (params['method'] as String? ?? 'GET').toUpperCase();
    final headers = ((params['headers'] ?? const <String, dynamic>{}) as Map).cast<String, String>();

    // Set last so it wins over anything addAll put in: http.Request.headers
    // is case-insensitive, so this stamps HaLo's canonical UA on every call —
    // except for whitelisted extensions that supplied their own (see
    // resolveFetchUserAgent and docs/design/network.md).
    final effectiveUA = resolveFetchUserAgent(canonical: userAgent, extensionKey: extensionKey, overrides: userAgentOverrides, callerHeaders: headers);
    var body = params['body'] as String?;

    // The caller's ask is ONE budget for the whole call — every hop, both
    // phases and the retry — so it is measured, not handed out per phase.
    // See `remainingFetchTimeout`. The host's own defaults stay per-phase:
    // they were chosen that way, and waiting for headers is not the same
    // thing as reading a slow body.
    final requested = (params['timeout'] as num?)?.toInt();
    final spent = Stopwatch()..start();
    Duration remaining(Duration ceiling) => remainingFetchTimeout(requested: requested, elapsed: spent.elapsed, ceiling: ceiling);

    // The host's own header ceiling covers the whole walk, not each hop: a
    // chain of slow redirects would otherwise hold the fetch for the ceiling
    // times the hops before the body phase even starts.
    Duration headerBudget() {
      final left = fetchHeaderTimeout - spent.elapsed;
      return remaining(left.isNegative ? const Duration(milliseconds: 1) : left);
    }

    // Redirects followed by hand. A client following them inside one send()
    // walks an allowed host into any other — the allowlist was judged on the
    // host asked for, not on the one answering — and https into http. Each
    // hop is held to both checks as the first was, and to a count. On web
    // the browser follows them itself and exposes no hop, so what it allows
    // there is CORS's, the allowlist holds the first host only, and a 3xx
    // never reaches this loop.
    var hopHeaders = Map<String, String>.of(headers);
    for (var hop = 0; ; hop++) {
      final streamed = await _sendOnce(route.client, method, route.uri, hopHeaders, effectiveUA, body, headerBudget);
      final location = streamed.headers['location'];
      if (_redirectStatuses.contains(streamed.statusCode) && location != null) {
        // The body is dropped, and the socket with it; the next hop opens
        // its own.
        await streamed.stream.listen(null).cancel();
        if (hop >= kMaxFetchRedirects) {
          throw ExtensionHostException("fetch refused: '${params['url']}' redirected more than $kMaxFetchRedirects times");
        }
        final next = target.resolve(location);
        final otherHost = next.host != target.host;
        target = next;
        route = _fetchTarget(extensionKey, target);
        // Credentials were meant for the host they were sent to, as a
        // browser treats them on a cross-origin redirect.
        if (otherHost) hopHeaders = _withoutCredentials(hopHeaders);
        // A 303, or a 301 or 302 answering anything but a GET or HEAD,
        // continues as a GET with no body — and without the headers that
        // described one; a 307 or 308 repeats the request as it was.
        if (streamed.statusCode == 303 || ((streamed.statusCode == 301 || streamed.statusCode == 302) && method != 'GET' && method != 'HEAD')) {
          method = 'GET';
          body = null;
          hopHeaders = _withoutContentHeaders(hopHeaders);
        }
        continue;
      }
      return {'status': streamed.statusCode, 'body': await _readBody(streamed, target, remaining(fetchBodyTimeout))};
    }
  }

  /// The answers a client follows; a 300 or a 304 carrying a Location is an
  /// answer in its own right.
  static const _redirectStatuses = {301, 302, 303, 307, 308};

  static Map<String, String> _withoutCredentials(Map<String, String> headers) => {
    for (final MapEntry(:key, :value) in headers.entries)
      if (!const {'authorization', 'proxy-authorization', 'cookie'}.contains(key.toLowerCase())) key: value,
  };

  static Map<String, String> _withoutContentHeaders(Map<String, String> headers) => {
    for (final MapEntry(:key, :value) in headers.entries)
      if (!key.toLowerCase().startsWith('content-')) key: value,
  };

  /// [streamed]'s body, counted as it arrives and refused past the cap — a
  /// cap measured after the whole body is in has already let what it refuses
  /// into memory — with [budget] for the whole read. `await for` cancels the
  /// subscription when the cap throws; a read the budget cuts short keeps
  /// its subscription until the server sends more or closes, as it did when
  /// the body was read whole.
  Future<String> _readBody(http.StreamedResponse streamed, Uri target, Duration budget) async {
    final bytes = BytesBuilder(copy: false);
    await () async {
      await for (final chunk in streamed.stream) {
        bytes.add(chunk);
        if (bytes.length > kMaxFetchBodyBytes) {
          throw ExtensionHostException("fetch refused: '${target.host}' answered with more than $kMaxFetchBodyBytes bytes");
        }
      }
    }().timeout(budget);
    return http.Response.bytes(bytes.takeBytes(), streamed.statusCode, headers: streamed.headers, request: streamed.request).body;
  }

  /// [target] as this hop must fetch it, and the client to fetch it on:
  /// checked against the extension's allowlist and the local-network rule,
  /// rewritten for this build (the proxy, on web or for an http-only host),
  /// and held to https. Every hop of a fetch passes here, and the one reading
  /// of the host decides both the refusal and the transport.
  ///
  /// The local network is never reached on a wildcard. A `*` grant means the
  /// internet, and the operator's router, printer and radio web UIs are not
  /// that: an extension that talks to gear names it in `domains`, and a
  /// developer reaching a server of their own turns developer mode on. Judged
  /// by spelling here; natively the guarded client judges what the name
  /// resolves to as well ([fetchHopGuarded]).
  ({Uri uri, http.Client client}) _fetchTarget(String? extensionKey, Uri target) {
    final host = target.host;
    _checkFetchAllowed(extensionKey, host);
    final local = isLocalNetworkHost(host);
    final named = allowlistNamesHost(_allowlistFor(fetchAllowlists, extensionKey), host);
    if (local && !developerMode && !named) {
      throw ExtensionHostException(
        "fetch refused: '$host' is on the local network, which extension '${extensionKey ?? 'unknown'}' reaches only by naming it in its declared domains, or in developer mode",
      );
    }
    final uri = extensionFetchUri(target, onWeb: runningOnWeb);
    if (uri.scheme != 'https') {
      throw ExtensionHostException("fetch refused: '$target' is not https");
    }
    return (uri: uri, client: fetchHopGuarded(developerMode: developerMode, namedHost: named) ? _httpGuarded : _http);
  }

  /// One hop of a fetch: the request sent once, with a single retry when
  /// the host's name failed to resolve.
  Future<http.StreamedResponse> _sendOnce(
    http.Client client,
    String method,
    Uri uri,
    Map<String, String> headers,
    String? userAgent,
    String? body,
    Duration Function() headerBudget,
  ) async {
    for (var attempt = 0; ; attempt++) {
      // Followed by hand natively (see the loop above). The browser's client
      // turns `false` into a fetch that fails on any redirect, so on web it
      // follows them itself.
      final request = http.Request(method, uri)
        ..followRedirects = runningOnWeb
        ..headers.addAll(headers);
      if (userAgent != null) request.headers['User-Agent'] = userAgent;
      if (body != null) request.body = body;
      try {
        return await client.send(request).timeout(headerBudget());
      } on http.ClientException catch (e) {
        // A resolver hiccup during a network handover, sleep/wake or VPN
        // toggle surfaces as "Failed host lookup: '<host>'" (package:http's
        // IOClient wraps the underlying SocketException verbatim — this
        // never fires on web, where BrowserClient wraps a failed fetch()
        // differently) and is usually gone on the next try — one retry
        // clears it without troubling the caller. Anything else (timeout,
        // connection refused, HTTP error) still surfaces at once.
        //
        // The message must name THIS hop's host. With redirects followed by
        // hand a send reaches one host only, so a lookup failure means
        // nothing was sent, and the retry resends nothing twice.
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
    if (_ownsHttpClient) {
      _http.close();
      _httpGuarded.close();
    }
    _js.dispose();
  }
}
