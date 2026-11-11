// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Web backend: since QuickJS needs dart:ffi (unavailable on
// web), this runs the kernel + extension bundles directly in the browser's
// own JS engine, inside a dedicated Web Worker so extension work stays off
// the UI thread — mirroring the isolate used natively. The worker is built
// at runtime from a Blob URL (bundle sources are only known at runtime, not
// static asset paths) and speaks the same 'polo' protocol as kernel.ts,
// just over a private MessagePort instead of the native `sendMessage` global.
//
// The worker runs inside a hidden sandboxed iframe, never on the app's own
// page (docs/design/js-engine.md, "The web sandbox"). A worker shares its
// creator's origin and Content-Security-Policy, and the app's page has every
// network permission and all of the app's storage: a bundle there could
// call `fetch` or open a WebSocket to a host its manifest never named, or
// rewrite the installed extensions in IndexedDB. The iframe has an opaque
// origin, which owns no storage, and a policy of its own that refuses every
// request, so the worker it creates inherits both.
//
// The iframe's document also inherits any policy the app's page carries. A
// page policy has to allow the iframe's inline script, `'unsafe-eval'` and
// `worker-src blob:`, or no extension loads.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:meta/meta.dart';
import 'package:web/web.dart' as web;

import 'engine_runtime.dart';

/// See the counterpart in engine_runtime_io.dart.
const bool runningOnWeb = true;

/// The worker's bootstrap, for the test that runs it outside the sandbox.
@visibleForTesting
String get webWorkerBootstrap => _bootstrapJs;

const _bootstrapJs = r'''
// All of it inside one function: a bundle is evaluated with indirect eval, in
// the worker's global scope, where every top-level name of a classic script
// is in reach — a bundle could call this glue's own send and dispatch by
// name, and put any message on the wire as any extension. Strict, so that a
// function of this glue that ever reaches a bundle carries no readable
// `arguments` or `caller`: the load message, token and port included.
(function () {
'use strict';
// Dart's side of the conversation is a MessageChannel port that arrives with
// the load message, held here and nowhere else. The worker's own channel is
// not private: any bundle can add a 'message' listener to `self` and read
// what the host sends — host results, other extensions' credentials
// included — or post to the host through DedicatedWorkerGlobalScope's
// prototype. So the host listens only to the port, and this glue only to the
// port once loaded.
let port = null;
// The port's own postMessage, bound in onLoad before any bundle evaluates:
// `port.postMessage(...)` looks the method up on MessagePort.prototype at
// every call, and a bundle that replaced it there would be handed the port.
let portPost = null;
// A message's `data`, read through the platform's own getter: `e.data` looks
// it up on MessageEvent.prototype, where a bundle's getter would read every
// message the host sends.
const dataOf = Function.prototype.call.bind(Object.getOwnPropertyDescriptor(MessageEvent.prototype, 'data').get);
// The host bridge's token, from the load message: what lets this glue call
// the kernel's host-only entries, which no bundle can.
let token = null;
let kernel = null;
// The sandbox's check, taken before the names below leave the global.
const probeFetch = self.fetch.bind(self);
// What reaches the network or storage without the host: the iframe's policy
// and opaque origin already refuse them, and taking the names away too means
// a browser that lets one through still hands a bundle nothing to call.
for (const name of ['fetch', 'XMLHttpRequest', 'WebSocket', 'WebSocketStream', 'WebTransport', 'EventSource', 'importScripts',
    'indexedDB', 'caches', 'FontFace', 'fonts', 'Worker', 'SharedWorker', 'BroadcastChannel']) {
  // Some live on the global scope's prototypes rather than the global.
  for (let o = self; o !== null; o = Object.getPrototypeOf(o)) Reflect.deleteProperty(o, name);
}
// Settles only if this worker is in the sandbox the host built it in: an
// opaque origin, and a policy under which even a `data:` fetch, which never
// leaves the browser, is refused. Anywhere else no bundle evaluates.
function checkSandbox() {
  if (self.origin !== 'null') return Promise.reject(new Error('the extension worker is not in an opaque origin'));
  return probeFetch('data:,').then(
    function () { throw new Error('the extension worker can make requests'); },
    function () {},
  );
}
function bridge(entry, a, b, c, d, e) {
  return kernel.bridge(token, entry, a, b, c, d, e);
}
function post(payload) {
  portPost(JSON.stringify(payload));
}
// The kernel captures this and removes it from the global before any bundle
// evaluates.
self.sendMessage = function (channel, message) {
  // `message` is already JSON, written by the kernel: passed on as it came,
  // never parsed and written out again here, where what an object in this
  // shared realm answers when written out would decide what the host reads.
  portPost('{"kind":"polo","message":' + message + '}');
};
// What a busy span is charged to — the labels the native core uses, as far
// as the worker can tell them apart (it never learns a host call's method).
// Mirrors batchLabel in hook_call_stats.dart.
function batchLabel(callsJson) {
  try {
    const methods = new Set(JSON.parse(callsJson).map(function (call) { return call && call.method; }));
    return methods.size === 1 ? 'batch:' + methods.values().next().value : 'batch:mixed';
  } catch (err) {
    return 'batch';
  }
}
function busyLabel(msg) {
  switch (msg.kind) {
    case 'invoke': return msg.category + '.' + msg.method + (msg.key ? '@' + msg.key : '');
    case 'invokeAll': return msg.category + '.' + msg.method;
    case 'invokeBatch': return batchLabel(msg.callsJson);
    case 'runTimers': return 'timers';
    default: return msg.kind;
  }
}
// A busy span opens when a message arrives and closes when a task queued
// behind it runs — after the microtasks its handling started. That is where
// a hook's body runs: the kernel awaits the hook's context before calling
// it, so closing the span when the handler returns would time the dispatch
// and miss the hook. A message arriving while a span is open joins it
// rather than overlapping it. Work the worker does outside a message's
// microtasks is not seen, so this approximates the native number.
//
// A span's start is the real wall clock, the one Dart places slices by —
// captured here, before the kernel replaces Date with the sandbox's
// travelled one. Its length is performance.now(), which is monotonic but
// stops during a system sleep, so as an anchor it would drift behind and
// every later span would land in the past and be dropped.
const realDateNow = Date.now.bind(Date);
const monotonicNow = performance.now.bind(performance);
const spanCloser = new MessageChannel();
const closeSpan = spanCloser.port2.postMessage.bind(spanCloser.port2, null);
let spanStart = null;
let spanStartMono = 0;
let spanLabel = 'message';
// A ping that arrives inside a span is answered when it closes, after its
// busy report: answered sooner, the heartbeat would call the engine free
// while the span's time had not reached Dart yet.
let pongOwed = false;
function pong() {
  post({ kind: 'polo', message: { type: 'pong' } });
}
spanCloser.port1.onmessage = function () {
  const length = monotonicNow() - spanStartMono;
  if (length > 0) {
    post({ kind: 'busy', start: Math.round(spanStart * 1000), end: Math.round((spanStart + length) * 1000), label: spanLabel });
  }
  spanStart = null;
  if (pongOwed) {
    pongOwed = false;
    pong();
  }
};
function onPortMessage(e) {
  // Never a span of its own, or every heartbeat would read as busy time.
  const data = dataOf(e);
  if (data === '{"kind":"ping"}') {
    if (spanStart === null) pong();
    else pongOwed = true;
    return;
  }
  const opens = spanStart === null;
  if (opens) {
    spanStart = realDateNow();
    spanStartMono = monotonicNow();
    spanLabel = 'message';
  }
  try {
    const msg = JSON.parse(data);
    if (opens) spanLabel = busyLabel(msg);
    handleMessage(msg);
  } finally {
    if (opens) closeSpan();
  }
}
// The one message the worker's own channel carries. Removed before anything
// else runs, so no later message there — a bundle's synthetic one included —
// reaches this glue.
function onLoad(e) {
  self.removeEventListener('message', onLoad);
  port = e.ports[0];
  portPost = port.postMessage.bind(port);
  // Set now, while MessagePort.prototype's `onmessage` setter is still the
  // platform's: set after the bundles, it could be one of theirs, handed
  // the port. Nothing arrives on it before `ready`.
  port.onmessage = onPortMessage;
  const msg = JSON.parse(e.data);
  token = msg.token;
  checkSandbox().then(function () { loadAll(msg); }, function (err) {
    post({ kind: 'initError', error: 'extension sandbox unavailable: ' + err.message });
  });
}
function loadAll(msg) {
  try {
    (0, eval)(msg.kernelSource);
    kernel = self.__halo;
    // Before any bundle: the first claim is the only one the kernel accepts.
    kernel.claimBridge(token);
    if (msg.clock) {
      bridge('setClockTravel', msg.clock.anchorRealMillis, msg.clock.anchorVirtualMillis, msg.clock.speed);
    }
    bridge('declareBundles', msg.declaredKeys);
    for (const bundle of msg.bundles) {
      bridge('beginBundle', bundle.key, bundle.api);
      (0, eval)(bundle.source);
      bridge('endBundle');
    }
    bridge('activateAll');
    post({ kind: 'ready' });
  } catch (err) {
    post({ kind: 'initError', error: String((err && err.stack) || err) });
  }
}
self.addEventListener('message', onLoad);
function handleMessage(msg) {
  switch (msg.kind) {
    case 'invoke':
      bridge('invokeHook', msg.id, msg.category, msg.key, msg.method, msg.argsJson);
      break;
    case 'invokeAll':
      bridge('invokeHookAll', msg.id, msg.category, msg.method, msg.argsJson, msg.wantsPartials);
      break;
    case 'invokeBatch':
      bridge('invokeHookBatch', msg.id, msg.callsJson, msg.wantsPartials);
      break;
    case 'hostResponse':
      bridge('hostResponse', msg.callId, msg.ok, msg.resultJson);
      break;
    case 'socketEvent':
      bridge('socketEvent', msg.socketId, msg.eventJson);
      break;
    case 'reload':
      // The dev loop's per-extension reload. Mirrors engine_runtime_io's
      // reloadBundle, including closing the bundle window in a finally so a
      // source that throws part-way can't leave it open and get every later
      // definition refused.
      try {
        bridge('unloadBundle', msg.key);
        bridge('beginBundle', msg.key, msg.api);
        try {
          (0, eval)(msg.source);
        } finally {
          bridge('endBundle');
        }
        bridge('activateReloaded', msg.key, msg.token);
      } catch (err) {
        post({
          kind: 'polo',
          message: { type: 'reloadComplete', token: msg.token, ok: false, error: String((err && err.stack) || err) },
        });
      }
      break;
    case 'runTimers':
      bridge('runTimers');
      break;
    case 'setAppVisible':
      bridge('setAppVisible', msg.visible);
      break;
    case 'invalidateContext':
      bridge('invalidateContext');
      break;
    case 'setClockTravel':
      bridge('setClockTravel', msg.anchorRealMillis, msg.anchorVirtualMillis, msg.speed);
      break;
  }
}
})();
''';

/// What the sandbox's iframe may do: run its own inline script, eval in the
/// worker, and build that worker from a `blob:` URL. Every request — fetch,
/// WebSocket, `import()` of a URL, a font, an image — falls under
/// `default-src 'none'`.
const _sandboxPolicy = "default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval' blob:; worker-src blob:";

/// The sandbox's iframe document. It waits for the host's one message, builds
/// the worker from the bootstrap it carries, hands the worker the load
/// message and the host's port, and from then on only reports the worker's
/// errors, on a port of their own. The worker's URL has to be made here: a
/// worker's script must share its creator's origin, and this one's is opaque.
const _sandboxDocument = """<!doctype html><meta http-equiv="Content-Security-Policy" content="$_sandboxPolicy"><script>
'use strict';
addEventListener('message', function start(e) {
  // Only the host's message: anything else posted to this window first would
  // otherwise be taken for it, and the host's would find no one listening.
  if (e.source !== parent || e.ports.length !== 2 || !e.data || typeof e.data.bootstrap !== 'string') return;
  removeEventListener('message', start);
  const errors = e.ports[1];
  try {
    const worker = new Worker(URL.createObjectURL(new Blob([e.data.bootstrap], { type: 'text/javascript' })));
    worker.onerror = function (ev) { errors.postMessage('extension worker error: ' + ((ev && ev.message) || 'no message')); };
    worker.postMessage(e.data.load, [e.ports[0]]);
  } catch (err) {
    errors.postMessage('extension sandbox unavailable: ' + err);
  }
});
</script>""";

class _WebWorkerEngineRuntime implements EngineRuntime {
  web.HTMLIFrameElement? _sandbox;
  web.MessagePort? _port;
  web.MessagePort? _errors;
  void Function(Map<String, dynamic>)? _onMessage;
  void Function(int startMicros, int endMicros, String label)? _onBusySpan;

  @override
  String get engineDescription => 'browser worker';

  @override
  void onMessage(void Function(Map<String, dynamic> message) callback) {
    _onMessage = callback;
  }

  @override
  void onFatalError(void Function(String message) callback) {
    // A worker's error event is never its death (see load); a worker that
    // stops answering leaves each call to its own timeout.
  }

  @override
  void onBusySpan(void Function(int startMicros, int endMicros, String label) callback) {
    _onBusySpan = callback;
  }

  @override
  Future<void> load(String kernelSource, List<ExtensionBundle> bundles, {ClockTravelState clock = const ClockTravelState.real()}) async {
    // Everything after the load travels on this channel's port, which only
    // the bootstrap's closure holds: the worker's own channel is open to
    // every bundle in it, both ways (see the bootstrap).
    final channel = web.MessageChannel();
    _port = channel.port1;
    final errors = web.MessageChannel();
    _errors = errors.port1;
    final ready = Completer<void>();
    web.EventStreamProviders.messageEvent.forTarget(channel.port1).listen((event) {
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
        case 'busy':
          if (msg case {'start': int start, 'end': int end, 'label': String label}) _onBusySpan?.call(start, end, label);
      }
    });
    // A port listened to through addEventListener delivers nothing until
    // started; `onmessage` would start it implicitly.
    channel.port1.start();
    web.EventStreamProviders.messageEvent.forTarget(errors.port1).listen((event) {
      final what = (event.data as JSString).toDart;
      if (!ready.isCompleted) {
        ready.completeError(ExtensionHostException(what));
      } else {
        // Once loaded, this is an exception nothing caught — a bundle's
        // callback that throws — and the worker carries on, as the native
        // engine does past a job that throws. Fatal here, one bundle's bug
        // would stop every extension.
        _onMessage?.call({'type': 'log', 'message': what});
      }
    });
    errors.port1.start();

    final load = jsonEncode({
      'kind': 'load',
      'token': newBridgeToken(),
      'kernelSource': kernelSource,
      'bundles': [
        for (final b in bundles) {'key': b.key, 'source': b.source, 'api': b.api},
      ],
      'declaredKeys': declaredBundleKeys(bundles),
      // Applied by the bootstrap between the kernel and the bundles, so the
      // sandbox's Date is already on the app's clock when they evaluate.
      if (!clock.isReal) 'clock': {'anchorRealMillis': clock.anchorRealMillis, 'anchorVirtualMillis': clock.anchorVirtualMillis, 'speed': clock.speed},
    });
    // No `allow-same-origin`: that is what makes the iframe's origin opaque.
    final sandbox = web.HTMLIFrameElement()
      ..setAttribute('sandbox', 'allow-scripts')
      ..setAttribute('aria-hidden', 'true')
      ..setAttribute('srcdoc', _sandboxDocument);
    sandbox.style.display = 'none';
    _sandbox = sandbox;
    // Posted once the iframe's script is listening, which its load event
    // follows. '*' is the only target an opaque origin answers to; the
    // message goes to this iframe's window and no other.
    unawaited(
      web.EventStreamProviders.loadEvent
          .forTarget(sandbox)
          .first
          .then((_) {
            final window = sandbox.contentWindow;
            if (window == null) throw ExtensionHostException('extension sandbox unavailable: the iframe has no window');
            window.postMessage({'bootstrap': _bootstrapJs, 'load': load}.jsify(), '*'.toJS, [channel.port2, errors.port2].toJS);
          })
          .catchError((Object error, StackTrace stack) {
            if (!ready.isCompleted) ready.completeError(error, stack);
          }),
    );
    (web.document.body ?? web.document.documentElement!).append(sandbox);
    // On failure, _HostCore.init disposes us before rethrowing. An iframe
    // whose script never runs (a page policy that blocks it) reports nothing,
    // so the timeout is what names it.
    await ready.future.timeout(const Duration(seconds: 30), onTimeout: () => throw ExtensionHostException('extension sandbox did not start within 30s'));
  }

  @override
  void reloadBundle(ExtensionBundle bundle, int token) {
    // Unlike the io backend, evaluation happens inside the worker and so
    // cannot throw back to this call — the bootstrap reports a failed reload
    // as a `reloadComplete` with ok:false instead.
    _send({'kind': 'reload', 'key': bundle.key, 'source': bundle.source, 'api': bundle.api, 'token': token});
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
  void ping() {
    // Matched by the bootstrap as this exact string.
    _port!.postMessage('{"kind":"ping"}'.toJS);
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
    _port!.postMessage(jsonEncode(payload).toJS);
  }

  @override
  bool pump() {
    // Real JS engine, real event loop — nothing to pump.
    return false;
  }

  @override
  void dispose() {
    _port?.close();
    _errors?.close();
    // Takes the iframe's document down, and the worker with it.
    _sandbox?.remove();
  }
}

EngineRuntime createEngineRuntime() => _WebWorkerEngineRuntime();
