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

import 'package:flutter_js/flutter_js.dart';
import 'package:http/http.dart' as http;

class ExtensionBundle {
  final String key;
  final String source;

  const ExtensionBundle({required this.key, required this.source});
}

/// One completed hook invocation, for latency analysis.
class HookCallSample {
  final String label;
  final int totalMillis;
  final int jsMillis;

  const HookCallSample({required this.label, required this.totalMillis, required this.jsMillis});
}

class ExtensionHostException implements Exception {
  final String message;
  ExtensionHostException(this.message);

  @override
  String toString() => 'ExtensionHostException: $message';
}

class ExtensionHost {
  final bool runningInIsolate;
  final String engine;
  final int loadMillis;

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
  });

  Stream<String> get logs => _logs.stream;

  /// Loads the kernel and extension bundles into a fresh JS runtime.
  static Future<ExtensionHost> start({
    required String kernelSource,
    required List<ExtensionBundle> extensions,
    bool useIsolate = true,
  }) async {
    if (useIsolate) {
      try {
        return await _startInIsolate(kernelSource, extensions);
      } catch (e) {
        // Fall through to in-process mode; the spike wants to know when this
        // happens, so surface it loudly on the first log line.
        final host = await _startInProcess(kernelSource, extensions);
        host._log('WARN isolate mode failed ($e), running in-process');
        return host;
      }
    }
    return _startInProcess(kernelSource, extensions);
  }

  static Future<ExtensionHost> _startInIsolate(String kernelSource, List<ExtensionBundle> extensions) async {
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
    );
    host._isolate = isolate;
    host._toIsolate = toIsolate;
    earlyMessages.forEach(host._onCoreMessage);
    return host;
  }

  static Future<ExtensionHost> _startInProcess(String kernelSource, List<ExtensionBundle> extensions) async {
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
    host = ExtensionHost._(runningInIsolate: false, engine: core.engineDescription, loadMillis: loadMillis);
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
    core.handle(msg);
  }
  core.dispose();
}

/// The part of the host that owns the JS runtime. Runs either inside the
/// extension isolate or (fallback) in the main isolate.
class _HostCore {
  final void Function(Map<String, dynamic>) emit;

  late final JavascriptRuntime _js;
  final _http = http.Client();
  final Map<String, Map<String, Object?>> _kv = {};
  Timer? _pump;
  int _outstanding = 0;

  _HostCore({required this.emit});

  String get engineDescription => _js.runtimeType.toString();

  Future<int> init(String kernelSource, List<ExtensionBundle> bundles) async {
    final stopwatch = Stopwatch()..start();
    _js = getJavascriptRuntime(xhr: false);

    _js.onMessage('polo', (dynamic args) {
      _onPoloMessage(args);
      return null;
    });

    _evaluate(kernelSource, name: 'kernel');
    for (final bundle in bundles) {
      _evaluate(bundle.source, name: bundle.key);
    }
    // Activation is deferred until every bundle is evaluated, so extensions
    // never depend on declaration order within their own bundle.
    _evaluate('__polo.activateAll()', name: 'activateAll');

    return (stopwatch..stop()).elapsedMilliseconds;
  }

  void handle(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'invoke':
      case 'invokeAll':
        final code = msg['type'] == 'invoke'
            ? '__polo.invokeHook('
                '${msg['id']}, '
                '${jsonEncode(msg['category'])}, '
                '${msg['key'] == null ? 'null' : jsonEncode(msg['key'])}, '
                '${jsonEncode(msg['method'])}, '
                '${jsonEncode(msg['argsJson'])})'
            : '__polo.invokeHookAll('
                '${msg['id']}, '
                '${jsonEncode(msg['category'])}, '
                '${jsonEncode(msg['method'])}, '
                '${jsonEncode(msg['argsJson'])})';
        _outstanding++;
        _ensurePumping();
        try {
          _evaluate(code, name: 'invokeHook');
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
      _executePendingJobs();
      if (_outstanding <= 0) {
        _pump?.cancel();
        _pump = null;
      }
    });
  }

  void _evaluate(String code, {required String name}) {
    final result = _js.evaluate(code);
    if (result.isError) {
      throw ExtensionHostException('evaluating $name: ${result.stringResult}');
    }
    _executePendingJobs();
  }

  void _executePendingJobs() {
    try {
      _js.executePendingJob();
    } catch (_) {
      // Engines without an explicit job queue may not support this.
    }
  }

  void _onPoloMessage(dynamic args) {
    final msg = (args is String ? jsonDecode(args) : args) as Map;
    switch (msg['type']) {
      case 'result':
        _outstanding--;
        emit(msg.cast<String, dynamic>());
      case 'log':
        emit(msg.cast<String, dynamic>());
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
          ok = false;
          result = 'unknown host method $method';
      }
    } catch (e) {
      ok = false;
      result = '$e';
    }

    final code = '__polo.hostResponse($callId, $ok, ${jsonEncode(jsonEncode(result))})';
    try {
      _evaluate(code, name: 'hostResponse');
    } catch (e) {
      emit({'type': 'log', 'message': 'ERROR delivering host response: $e'});
    }
  }

  Future<Map<String, Object?>> _hostFetch(Map<String, dynamic> params) async {
    final uri = Uri.parse(params['url'] as String);
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
  }
}
