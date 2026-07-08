// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web backend: since QuickJS/flutter_js needs dart:ffi (unavailable on
// web), this runs the kernel + extension bundles directly in the browser's
// own JS engine, inside a dedicated Web Worker so extension work stays off
// the UI thread — mirroring the isolate used natively. The worker is built
// at runtime from a Blob URL (bundle sources are only known at runtime, not
// static asset paths) and speaks the same 'polo' protocol as kernel.ts,
// just over postMessage instead of flutter_js's channel mechanism.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'engine_runtime.dart';

const _bootstrapJs = r'''
let ready = false;
self.sendMessage = function (channel, message) {
  postMessage(JSON.stringify({ kind: 'polo', message: message }));
};
self.onmessage = function (e) {
  const msg = JSON.parse(e.data);
  if (!ready) {
    if (msg.kind !== 'load') return;
    try {
      (0, eval)(msg.kernelSource);
      for (const bundle of msg.bundles) {
        (0, eval)(bundle.source);
      }
      self.__polo.activateAll();
      ready = true;
      postMessage(JSON.stringify({ kind: 'ready' }));
    } catch (err) {
      postMessage(JSON.stringify({ kind: 'initError', error: String((err && err.stack) || err) }));
    }
    return;
  }
  switch (msg.kind) {
    case 'invoke':
      self.__polo.invokeHook(msg.id, msg.category, msg.key, msg.method, msg.argsJson);
      break;
    case 'invokeAll':
      self.__polo.invokeHookAll(msg.id, msg.category, msg.method, msg.argsJson);
      break;
    case 'hostResponse':
      self.__polo.hostResponse(msg.callId, msg.ok, msg.resultJson);
      break;
  }
};
''';

class _WebWorkerEngineRuntime implements EngineRuntime {
  late final web.Worker _worker;
  void Function(Map<String, dynamic>)? _onMessage;

  @override
  bool get available => true;

  @override
  String get engineDescription => 'browser worker';

  @override
  void onMessage(void Function(Map<String, dynamic> message) callback) {
    _onMessage = callback;
  }

  @override
  Future<void> load(String kernelSource, List<ExtensionBundle> bundles) async {
    final blob = web.Blob(
      [_bootstrapJs.toJS].toJS,
      web.BlobPropertyBag(type: 'application/javascript'),
    );
    final url = web.URL.createObjectURL(blob);
    _worker = web.Worker(url.toJS);

    final ready = Completer<void>();
    web.EventStreamProviders.messageEvent.forTarget(_worker).listen((event) {
      final data = (event.data as JSString).toDart;
      final msg = jsonDecode(data) as Map<String, dynamic>;
      switch (msg['kind']) {
        case 'ready':
          if (!ready.isCompleted) ready.complete();
        case 'initError':
          if (!ready.isCompleted) ready.completeError(StateError(msg['error'] as String));
        case 'polo':
          final poloMsg = jsonDecode(msg['message'] as String) as Map<String, dynamic>;
          _onMessage?.call(poloMsg);
      }
    });
    web.EventStreamProviders.errorEvent.forTarget(_worker).listen((event) {
      if (!ready.isCompleted) ready.completeError(StateError('worker failed to load'));
    });

    _worker.postMessage(jsonEncode({
      'kind': 'load',
      'kernelSource': kernelSource,
      'bundles': [for (final b in bundles) {'key': b.key, 'source': b.source}],
    }).toJS);

    await ready.future.timeout(const Duration(seconds: 30));
  }

  @override
  void invoke(int id, String category, String? key, String method, String argsJson) {
    _worker.postMessage(jsonEncode({
      'kind': 'invoke',
      'id': id,
      'category': category,
      'key': key,
      'method': method,
      'argsJson': argsJson,
    }).toJS);
  }

  @override
  void invokeAll(int id, String category, String method, String argsJson) {
    _worker.postMessage(jsonEncode({
      'kind': 'invokeAll',
      'id': id,
      'category': category,
      'method': method,
      'argsJson': argsJson,
    }).toJS);
  }

  @override
  void hostResponse(int callId, bool ok, String resultJson) {
    _worker.postMessage(jsonEncode({
      'kind': 'hostResponse',
      'callId': callId,
      'ok': ok,
      'resultJson': resultJson,
    }).toJS);
  }

  @override
  void pump() {
    // Real JS engine, real event loop — nothing to pump.
  }

  @override
  void dispose() {
    _worker.terminate();
  }
}

EngineRuntime createEngineRuntime() => _WebWorkerEngineRuntime();
