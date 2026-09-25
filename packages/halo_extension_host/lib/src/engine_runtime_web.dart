// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web backend: since QuickJS needs dart:ffi (unavailable on
// web), this runs the kernel + extension bundles directly in the browser's
// own JS engine, inside a dedicated Web Worker so extension work stays off
// the UI thread — mirroring the isolate used natively. The worker is built
// at runtime from a Blob URL (bundle sources are only known at runtime, not
// static asset paths) and speaks the same 'polo' protocol as kernel.ts,
// just over postMessage instead of the native `sendMessage` global.
//
// The bootstrap script below loads bundle sources via indirect `eval` and
// the worker itself is constructed from a `blob:` URL. A Content-Security-
// Policy hardened for production will need `script-src 'unsafe-eval'` and
// `worker-src blob:` (or equivalent) for extensions to keep working — there
// is no CSP configured yet (see app/web/index.html), so this is dormant
// until one gets added.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'engine_runtime.dart';

/// See the counterpart in engine_runtime_io.dart.
const bool runningOnWeb = true;

const _bootstrapJs = r'''
let ready = false;
// Captured before any bundle evaluates: raw postMessage is the web
// equivalent of the native `sendMessage` global — left reachable, any
// extension could forge protocol messages. The kernel captures and removes
// `sendMessage` itself; this closes the underlying worker channel too.
const rawPostMessage = self.postMessage.bind(self);
self.sendMessage = function (channel, message) {
  // `message` is already JSON (kernel.ts's post() calls JSON.stringify
  // before handing it to us) — parse it back so the envelope below only
  // stringifies it once instead of double-escaping the whole payload.
  rawPostMessage(JSON.stringify({ kind: 'polo', message: JSON.parse(message) }));
};
self.onmessage = function (e) {
  const msg = JSON.parse(e.data);
  if (!ready) {
    if (msg.kind !== 'load') return;
    try {
      (0, eval)(msg.kernelSource);
      try {
        self.postMessage = function () { throw new Error('the raw worker channel is kernel-private'); };
      } catch (err) { /* not shadowable: nothing more we can do */ }
      if (msg.clock) {
        self.__polo.setClockTravel(msg.clock.anchorRealMillis, msg.clock.anchorVirtualMillis, msg.clock.speed);
      }
      for (const bundle of msg.bundles) {
        self.__polo.beginBundle(bundle.key);
        (0, eval)(bundle.source);
        self.__polo.endBundle();
      }
      self.__polo.activateAll();
      ready = true;
      rawPostMessage(JSON.stringify({ kind: 'ready' }));
    } catch (err) {
      rawPostMessage(JSON.stringify({ kind: 'initError', error: String((err && err.stack) || err) }));
    }
    return;
  }
  switch (msg.kind) {
    case 'invoke':
      self.__polo.invokeHook(msg.id, msg.category, msg.key, msg.method, msg.argsJson);
      break;
    case 'invokeAll':
      self.__polo.invokeHookAll(msg.id, msg.category, msg.method, msg.argsJson, msg.wantsPartials);
      break;
    case 'invokeBatch':
      self.__polo.invokeHookBatch(msg.id, msg.callsJson, msg.wantsPartials);
      break;
    case 'hostResponse':
      self.__polo.hostResponse(msg.callId, msg.ok, msg.resultJson);
      break;
    case 'socketEvent':
      self.__polo.socketEvent(msg.socketId, msg.eventJson);
      break;
    case 'reload':
      // The dev loop's per-extension reload. Mirrors engine_runtime_io's
      // reloadBundle, including closing the bundle window in a finally so a
      // source that throws part-way can't leave it open and get every later
      // definition refused.
      try {
        self.__polo.unloadBundle(msg.key);
        self.__polo.beginBundle(msg.key);
        try {
          (0, eval)(msg.source);
        } finally {
          self.__polo.endBundle();
        }
        self.__polo.activateReloaded(msg.key, msg.token);
      } catch (err) {
        self.sendMessage('polo', JSON.stringify({
          type: 'reloadComplete',
          token: msg.token,
          ok: false,
          error: String((err && err.stack) || err),
        }));
      }
      break;
    case 'runTimers':
      self.__polo.runTimers();
      break;
    case 'setAppVisible':
      self.__polo.setAppVisible(msg.visible);
      break;
    case 'invalidateContext':
      self.__polo.invalidateContext();
      break;
    case 'setClockTravel':
      self.__polo.setClockTravel(msg.anchorRealMillis, msg.anchorVirtualMillis, msg.speed);
      break;
  }
};
''';

class _WebWorkerEngineRuntime implements EngineRuntime {
  web.Worker? _worker;
  String? _blobUrl;
  void Function(Map<String, dynamic>)? _onMessage;
  void Function(String)? _onFatalError;

  @override
  String get engineDescription => 'browser worker';

  @override
  void onMessage(void Function(Map<String, dynamic> message) callback) {
    _onMessage = callback;
  }

  @override
  void onFatalError(void Function(String message) callback) {
    _onFatalError = callback;
  }

  @override
  Future<void> load(String kernelSource, List<ExtensionBundle> bundles, {ClockTravelState clock = const ClockTravelState.real()}) async {
    final blob = web.Blob([_bootstrapJs.toJS].toJS, web.BlobPropertyBag(type: 'application/javascript'));
    final url = web.URL.createObjectURL(blob);
    _blobUrl = url;
    final worker = web.Worker(url.toJS);
    _worker = worker;

    final ready = Completer<void>();
    web.EventStreamProviders.messageEvent.forTarget(worker).listen((event) {
      final data = (event.data as JSString).toDart;
      final msg = jsonDecode(data) as Map<String, dynamic>;
      switch (msg['kind']) {
        case 'ready':
          if (!ready.isCompleted) ready.complete();
        case 'initError':
          if (!ready.isCompleted) ready.completeError(ExtensionHostException(msg['error'] as String));
        case 'polo':
          final poloMsg = (msg['message'] as Map).cast<String, dynamic>();
          _onMessage?.call(poloMsg);
      }
    });
    web.EventStreamProviders.errorEvent.forTarget(worker).listen((event) {
      if (!ready.isCompleted) {
        ready.completeError(ExtensionHostException('worker failed to load'));
      } else {
        // A crash after we've already loaded — nothing else will ever tell
        // Dart this worker died, so every hook call still waiting on a
        // 'result' message would otherwise hang until its own timeout.
        _onFatalError?.call('extension worker crashed');
      }
    });

    _send({
      'kind': 'load',
      'kernelSource': kernelSource,
      'bundles': [
        for (final b in bundles) {'key': b.key, 'source': b.source},
      ],
      // Applied by the bootstrap between the kernel and the bundles, so the
      // sandbox's Date is already on the app's clock when they evaluate.
      if (!clock.isReal) 'clock': {'anchorRealMillis': clock.anchorRealMillis, 'anchorVirtualMillis': clock.anchorVirtualMillis, 'speed': clock.speed},
    });
    // On failure, _HostCore.init disposes us before rethrowing.
    await ready.future.timeout(const Duration(seconds: 30));
  }

  @override
  void reloadBundle(ExtensionBundle bundle, int token) {
    // Unlike the io backend, evaluation happens inside the worker and so
    // cannot throw back to this call — the bootstrap reports a failed reload
    // as a `reloadComplete` with ok:false instead.
    _send({'kind': 'reload', 'key': bundle.key, 'source': bundle.source, 'token': token});
  }

  @override
  void invoke(int id, String category, String? key, String method, String argsJson) {
    _send({'kind': 'invoke', 'id': id, 'category': category, 'key': key, 'method': method, 'argsJson': argsJson});
  }

  @override
  void invokeAll(int id, String category, String method, String argsJson, {bool wantsPartials = false}) {
    _send({'kind': 'invokeAll', 'id': id, 'category': category, 'method': method, 'argsJson': argsJson, 'wantsPartials': wantsPartials});
  }

  @override
  void invokeBatch(int id, String callsJson, {bool wantsPartials = false}) {
    _send({'kind': 'invokeBatch', 'id': id, 'callsJson': callsJson, 'wantsPartials': wantsPartials});
  }

  @override
  void hostResponse(int callId, bool ok, String resultJson) {
    _send({'kind': 'hostResponse', 'callId': callId, 'ok': ok, 'resultJson': resultJson});
  }

  @override
  void socketEvent(int socketId, String eventJson) {
    _send({'kind': 'socketEvent', 'socketId': socketId, 'eventJson': eventJson});
  }

  @override
  void runTimers() {
    _send({'kind': 'runTimers'});
  }

  @override
  void setAppVisible(bool visible) {
    _send({'kind': 'setAppVisible', 'visible': visible});
  }

  @override
  void invalidateContext() {
    _send({'kind': 'invalidateContext'});
  }

  @override
  void setClockTravel(int anchorRealMillis, int anchorVirtualMillis, double speed) {
    _send({'kind': 'setClockTravel', 'anchorRealMillis': anchorRealMillis, 'anchorVirtualMillis': anchorVirtualMillis, 'speed': speed});
  }

  void _send(Map<String, dynamic> payload) {
    _worker!.postMessage(jsonEncode(payload).toJS);
  }

  @override
  void pump() {
    // Real JS engine, real event loop — nothing to pump.
  }

  @override
  void dispose() {
    _worker?.terminate();
    final url = _blobUrl;
    if (url != null) web.URL.revokeObjectURL(url);
  }
}

EngineRuntime createEngineRuntime() => _WebWorkerEngineRuntime();
