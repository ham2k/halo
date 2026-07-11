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

import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// Every log line received so far (the stream only carries new ones).
  final List<String> logLines = [];
  final List<HookCallSample> samples = [];

  final Map<int, Completer<dynamic>> _pending = {};
  final Map<int, (String, Stopwatch)> _inFlight = {};
  int _nextId = 1;

  SendPort? _toIsolate;
  Isolate? _isolate;
  _HostCore? _inProcessCore;

  ExtensionHost._({
    required this.runningInIsolate,
    required this.engine,
    required this.loadMillis,
    this.onHostCall,
  });

  Stream<String> get logs => _logs.stream;

  /// Loads the kernel and extension bundles into a fresh JS runtime.
  static Future<ExtensionHost> start({
    required String kernelSource,
    required List<ExtensionBundle> extensions,
    bool useIsolate = true,
    HostCallHandler? onHostCall,
  }) async {
    if (useIsolate) {
      try {
        return await _startInIsolate(kernelSource, extensions, onHostCall);
      } catch (e) {
        // Fall through to in-process mode; the spike wants to know when this
        // happens, so surface it loudly on the first log line.
        final host = await _startInProcess(kernelSource, extensions, onHostCall);
        host._log('WARN isolate mode failed ($e), running in-process');
        return host;
      }
    }
    return _startInProcess(kernelSource, extensions, onHostCall);
  }

  static Future<ExtensionHost> _startInIsolate(String kernelSource, List<ExtensionBundle> extensions, HostCallHandler? onHostCall) async {
    final fromIsolate = ReceivePort();
    final ready = Completer<Map<String, dynamic>>();
    final earlyMessages = <Map<String, dynamic>>[];
    ExtensionHost? host;

    final isolate = await Isolate.spawn(
      _hostIsolateMain,
      _HostIsolateInit(
        mainPort: fromIsolate.sendPort,
        kernelSource: kernelSource,
        bundles: [for (final p in extensions) [p.key, p.source]],
      ),
      errorsAreFatal: true,
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
    earlyMessages.forEach(host._onCoreMessage);
    return host;
  }

  static Future<ExtensionHost> _startInProcess(String kernelSource, List<ExtensionBundle> extensions, HostCallHandler? onHostCall) async {
    final earlyMessages = <Map<String, dynamic>>[];
    ExtensionHost? host;
    final core = _HostCore(emit: (msg) {
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
    final id = _nextId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _inFlight[id] = (label, Stopwatch()..start());

    final message = {'type': type, 'id': id, ...fields};
    if (_inProcessCore != null) {
      _inProcessCore!.handle(message);
    } else {
      _toIsolate!.send(message);
    }

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(id);
      _inFlight.remove(id);
      throw ExtensionHostException('hook $label timed out after ${timeout.inMilliseconds}ms');
    }
  }

  /// Seeds a value into an extension's key-value namespace (e.g. credentials).
  void setKV(String extensionKey, String key, Object? value) {
    final message = {'type': 'kvSet', 'ns': extensionKey, 'key': key, 'value': value};
    if (_inProcessCore != null) {
      _inProcessCore!.handle(message);
    } else {
      _toIsolate!.send(message);
    }
  }

  void _onCoreMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'result':
        final id = msg['id'] as int;
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
      case 'hostCall':
        final callId = msg['callId'] as int;
        final method = msg['method'] as String;
        final params = (msg['params'] as Map).cast<String, dynamic>();
        _handleHostCallDelegated(callId, method, params);
      case 'fatalError':
        // The engine died outside of any single call (e.g. a Worker crash) —
        // every hook still waiting on a response would otherwise just hang
        // until its own timeout, hiding the real cause.
        final error = msg['error'] as String? ?? 'extension engine crashed';
        _log('ERROR $error');
        for (final completer in _pending.values) {
          completer.completeError(ExtensionHostException(error));
        }
        _pending.clear();
        _inFlight.clear();
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
    _isolate?.kill(priority: Isolate.immediate);
    _inProcessCore?.dispose();
    await _logs.close();
  }
}

class _HostIsolateInit {
  final SendPort mainPort;
  final String kernelSource;
  final List<List<String>> bundles;

  const _HostIsolateInit({required this.mainPort, required this.kernelSource, required this.bundles});
}

Future<void> _hostIsolateMain(_HostIsolateInit init) async {
  final receive = ReceivePort();
  init.mainPort.send({'type': 'port', 'port': receive.sendPort});

  final core = _HostCore(emit: init.mainPort.send);
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

  late final EngineRuntime _js;
  final _http = http.Client();
  final Map<String, Map<String, Object?>> _kv = {};
  final Map<int, Completer<dynamic>> _pendingHostCalls = {};
  Timer? _pump;
  int _outstanding = 0;

  _HostCore({required this.emit});

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
        _outstanding++;
        _ensurePumping();
        try {
          if (msg['type'] == 'invoke') {
            _js.invoke(msg['id'] as int, msg['category'] as String, msg['key'] as String?, msg['method'] as String, msg['argsJson'] as String);
          } else {
            _js.invokeAll(msg['id'] as int, msg['category'] as String, msg['method'] as String, msg['argsJson'] as String);
          }
        } catch (e) {
          _outstanding--;
          emit({'type': 'result', 'id': msg['id'], 'ok': false, 'error': '$e'});
        }
      case 'kvSet':
        _kv.putIfAbsent(msg['ns'] as String? ?? 'default', () => {})[msg['key'] as String] = msg['value'];
    }
  }

  /// Pumps the JS job queue only while hook calls are outstanding, instead
  /// of a permanent fast timer.
  void _ensurePumping() {
    _pump ??= Timer.periodic(const Duration(milliseconds: 5), (_) {
      _js.pump();
      if (_outstanding <= 0) {
        _pump?.cancel();
        _pump = null;
      }
    });
  }

  /// The engine died outside of any single call (e.g. a Worker crash after
  /// load). Stop pumping — nothing will ever decrement `_outstanding` again —
  /// and let `ExtensionHost` fail every hook call still waiting on a result.
  void _onFatalError(String message) {
    _outstanding = 0;
    emit({'type': 'fatalError', 'error': message});
  }

  void _onPoloMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'result':
        _outstanding--;
        emit(msg);
      case 'log':
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

    try {
      _js.hostResponse(callId, ok, jsonEncode(result));
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
      const allowedDomains = {
        'api.pota.app',
        'logbook.qrz.com',
        'country-files.com',
        'pota.app',
        'www.sotadata.org.uk',
        'sotadata.org.uk',
      };
      if (allowedDomains.contains(uri.host)) {
        return Uri.parse('https://services.ham2k.net/${uri.host}${uri.path}${uri.hasQuery ? "?${uri.query}" : ""}');
      }
    }
    return uri;
  }

  Future<Map<String, Object?>> _hostFetch(Map<String, dynamic> params) async {
    final uri = _resolveFetchUri(params['url'] as String);
    if (uri.scheme != 'https') {
      throw ExtensionHostException('only https URLs are allowed');
    }
    final method = (params['method'] as String? ?? 'GET').toUpperCase();
    final headers = ((params['headers'] ?? const {}) as Map).cast<String, String>();

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (params['body'] != null) request.body = params['body'] as String;

    final streamed = await _http.send(request).timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);
    return {'status': response.statusCode, 'body': response.body};
  }

  void dispose() {
    _pump?.cancel();
    _http.close();
    _js.dispose();
  }
}
