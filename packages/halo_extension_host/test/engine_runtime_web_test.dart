// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The web build runs every bundle in one Worker, evaluated with indirect
// eval in the worker's global scope, beside the bootstrap that carries the
// host's traffic. Anything of the bootstrap's a bundle can reach — a
// top-level name, `self.onmessage`, the worker's own message channel — is a
// way to read what the host sends (other extensions' credentials among it)
// or to put a message on the wire as any extension. So the probe bundle here
// tries each of them, and the host must see none of it. It also tries the
// browser's own network and storage, which the worker's sandbox must refuse.
//
// The kernel is a stand-in: a browser test cannot read the built one from
// disk, and what is under test is the bootstrap, which treats the kernel as
// a `bridge` it holds the token to. host_bridge_test holds the real kernel's
// bridge.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/src/js_engine.dart';
import 'package:web/web.dart' as web;

/// Defines `__halo` with the two members the bootstrap uses, records every
/// bridge call it is let through, and answers `invokeHook` by running the
/// named function the probe registered.
const _kernel = r'''
(function () {
  const send = self.sendMessage
  delete self.sendMessage
  const post = (message) => send('polo', JSON.stringify(message))
  let token = null
  const entries = []
  const hooks = {}
  const kernel = {
    claimBridge(t) {
      if (token !== null) throw new Error('already claimed')
      token = t
    },
    bridge(t, entry, a, b, c, d, e) {
      if (token === null || t !== token) throw new Error('refused')
      entries.push(entry)
      if (entry === 'invokeHook') {
        Promise.resolve(hooks[d]()).then((value) => post({ type: 'result', id: a, ok: true, value }))
      }
    },
    defineHook(name, fn) {
      hooks[name] = fn
    },
    entries: () => entries.slice(),
  }
  Object.freeze(kernel)
  Object.defineProperty(self, '__halo', { value: kernel })
})()
''';

const _probe = r'''
// The bootstrap's port, and the host's messages, through the prototypes every
// MessagePort and MessageEvent shares: each hijack passes through, and counts
// what it was handed.
const hijacked = { ports: 0, reads: 0 }
const realPost = MessagePort.prototype.postMessage
MessagePort.prototype.postMessage = function (...args) {
  hijacked.ports++
  return realPost.apply(this, args)
}
const onmessage = Object.getOwnPropertyDescriptor(MessagePort.prototype, 'onmessage')
Object.defineProperty(MessagePort.prototype, 'onmessage', {
  get() { return onmessage.get.call(this) },
  set(fn) { hijacked.ports++; onmessage.set.call(this, fn) },
})
const data = Object.getOwnPropertyDescriptor(MessageEvent.prototype, 'data')
Object.defineProperty(MessageEvent.prototype, 'data', {
  get() { hijacked.reads++; return data.get.call(this) },
})
let overheard = 0
self.addEventListener('message', () => { overheard++ })
const reach = {
  rawPostMessage: typeof rawPostMessage,
  handleMessage: typeof handleMessage,
  onLoad: typeof onLoad,
  port: typeof port,
  token: typeof token,
  bridge: typeof bridge,
  onmessage: self.onmessage === null ? 'null' : typeof self.onmessage,
}
const forged = []
// A host call as another extension, straight onto the worker's own channel.
try {
  self.postMessage(JSON.stringify({ kind: 'polo', message: { type: 'hostCall', callId: 77, method: 'setSettings', params: { extensionKey: 'victim', ns: 'victim' } } }))
  forged.push('posted')
} catch (e) { forged.push('post refused: ' + e.message) }
// A host message, as if from the host.
self.dispatchEvent(new MessageEvent('message', { data: JSON.stringify({ kind: 'invoke', id: 88, category: 'bench', key: null, method: 'report', argsJson: '{}' }) }))
// That one, the probe's own listener heard; count only what the host sends.
overheard = 0
// The network and the app's storage, by the ways deleting a global cannot
// close: a module import of a URL, which only the sandbox's policy refuses,
// and the origin's own file system, which only an opaque origin lacks.
const ambient = ['fetch', 'XMLHttpRequest', 'WebSocket', 'WebSocketStream', 'WebTransport', 'EventSource', 'importScripts',
  'indexedDB', 'caches', 'FontFace', 'fonts', 'Worker', 'SharedWorker', 'BroadcastChannel']
  .filter((name) => name in self)
const imported = import('data:text/javascript,export default 1').then(() => 'loaded', () => 'refused')
const files = Promise.resolve().then(() => navigator.storage.getDirectory()).then(() => 'opened', () => 'refused')
let claimed
try { __halo.claimBridge('f'.repeat(64)); claimed = 'claimed' } catch (e) { claimed = String(e.message) }
__halo.defineHook('report', async () => ({
  reach, forged, claimed, overheard, hijacked, entries: __halo.entries(),
  sandbox: { origin: self.origin, ambient, imported: await imported, files: await files },
}))
''';

/// A load message for the bootstrap run outside the host: the kernel, if it
/// is ever evaluated, says so first.
final _standInLoad = jsonEncode({
  'kind': 'load',
  'token': 'f' * 64,
  'kernelSource': "sendMessage('polo', JSON.stringify({ type: 'kernelEvaluated' }))",
  'bundles': <Object>[],
  'declaredKeys': <String>[],
});

/// The first message the bootstrap sends back on [port].
Future<Map<String, dynamic>> _firstReply(web.MessagePort port) {
  final first = Completer<Map<String, dynamic>>();
  web.EventStreamProviders.messageEvent.forTarget(port).listen((event) {
    if (!first.isCompleted) first.complete(jsonDecode((event.data as JSString).toDart) as Map<String, dynamic>);
  });
  port.start();
  return first.future.timeout(const Duration(seconds: 10));
}

void main() {
  test("a bundle reaches none of the web bootstrap's channel, and the host hears nothing it forges", () async {
    final runtime = createEngineRuntime();
    addTearDown(runtime.dispose);
    final messages = <Map<String, dynamic>>[];
    final reported = Completer<Map<String, dynamic>>();
    runtime.onMessage((message) {
      messages.add(message);
      if (message['type'] == 'result' && message['id'] == 1) reported.complete((message['value'] as Map).cast<String, dynamic>());
    });

    await runtime.load(_kernel, [const ExtensionBundle(key: 'probe', source: _probe)]);
    runtime.invoke(1, 'bench', null, 'report', '{}');
    final report = await reported.future.timeout(const Duration(seconds: 10));

    expect(report['reach'], {
      'rawPostMessage': 'undefined',
      'handleMessage': 'undefined',
      'onLoad': 'undefined',
      'port': 'undefined',
      'token': 'undefined',
      'bridge': 'undefined',
      'onmessage': 'null',
    });
    expect(report['claimed'], 'already claimed');
    expect(report['hijacked'], {
      'ports': 0,
      'reads': 0,
    }, reason: "a bundle's MessagePort or MessageEvent prototype must never see the host's port or what comes over it");
    // The host's own `invoke` above came on the private port: a bundle
    // listening on the worker hears none of it.
    expect(report['overheard'], 0);
    // Only the host's calls went through: loading the probe, and the one
    // invoke. The synthetic invoke (id 88) reached nothing.
    expect(report['entries'], ['declareBundles', 'beginBundle', 'endBundle', 'activateAll', 'invokeHook']);
    expect(messages.where((m) => m['type'] == 'hostCall'), isEmpty, reason: "a host call as another extension must never reach the host");
    expect(messages.where((m) => m['id'] == 88), isEmpty);
    expect(jsonEncode(report['forged']), contains('posted'), reason: 'the worker channel stays open; the host is what stops listening to it');
    expect(report['sandbox'], {
      'origin': 'null',
      'ambient': <String>[],
      'imported': 'refused',
      'files': 'refused',
    }, reason: "a bundle reaches the network and the app's storage only through the host");
  });

  test('outside its sandbox, the worker evaluates nothing and says why', () async {
    // The worker the host builds always sits in the sandbox, so this runs the
    // same bootstrap in a plain worker of the test page: the page's origin,
    // and no policy. Were the bootstrap to load anyway, every bundle would
    // run with the page's network and storage.
    final url = web.URL.createObjectURL(web.Blob([webWorkerBootstrap.toJS].toJS, web.BlobPropertyBag(type: 'text/javascript')));
    final worker = web.Worker(url.toJS);
    addTearDown(() {
      worker.terminate();
      web.URL.revokeObjectURL(url);
    });
    final channel = web.MessageChannel();
    final replied = _firstReply(channel.port1);
    worker.postMessage(_standInLoad.toJS, [channel.port2].toJS);

    final reply = await replied;
    expect(reply['kind'], 'initError', reason: 'the kernel must not evaluate: its message would come first');
    expect(reply['error'], contains('extension sandbox unavailable'));
  });

  test('in an opaque origin whose policy does not reach the worker, the worker evaluates nothing', () async {
    // The origin check alone passes here. Only the `data:` fetch tells this
    // worker from the sandbox's: a browser that kept the iframe's policy from
    // its worker would otherwise run every bundle with the network open.
    final frame = web.HTMLIFrameElement()
      ..setAttribute('sandbox', 'allow-scripts')
      ..setAttribute('srcdoc', '''<!doctype html><script>
addEventListener('message', function (e) {
  const worker = new Worker(URL.createObjectURL(new Blob([e.data.bootstrap], { type: 'text/javascript' })));
  worker.postMessage(e.data.load, [e.ports[0]]);
});
</script>''');
    final loaded = web.EventStreamProviders.loadEvent.forTarget(frame).first;
    web.document.body!.append(frame);
    addTearDown(() => frame.remove());
    await loaded;
    final channel = web.MessageChannel();
    final replied = _firstReply(channel.port1);
    frame.contentWindow!.postMessage({'bootstrap': webWorkerBootstrap, 'load': _standInLoad}.jsify(), '*'.toJS, [channel.port2].toJS);

    final reply = await replied;
    expect(reply['kind'], 'initError', reason: 'the kernel must not evaluate: its message would come first');
    expect(reply['error'], contains('can make requests'));
  });

  test("a bundle's uncaught exception is logged, and every extension carries on", () async {
    final runtime = createEngineRuntime();
    addTearDown(runtime.dispose);
    final results = <int, Object?>{};
    final logs = <String>[];
    final fatal = <String>[];
    final logged = Completer<void>();
    final answered = Completer<void>();
    runtime.onFatalError(fatal.add);
    runtime.onMessage((message) {
      if (message['type'] == 'log') {
        logs.add(message['message'] as String);
        if (!logged.isCompleted) logged.complete();
      }
      if (message['type'] == 'result') {
        results[message['id'] as int] = message['value'];
        if (message['id'] == 2) answered.complete();
      }
    });

    await runtime.load(_kernel, [
      const ExtensionBundle(
        key: 'careless',
        source: r'''
__halo.defineHook('throwLater', () => { queueMicrotask(() => { throw new Error('thrown later') }); return 'queued' })
__halo.defineHook('alive', () => 'alive')
''',
      ),
    ]);
    runtime.invoke(1, 'bench', null, 'throwLater', '{}');
    await logged.future.timeout(const Duration(seconds: 10));
    runtime.invoke(2, 'bench', null, 'alive', '{}');
    await answered.future.timeout(const Duration(seconds: 10));

    expect(logs.single, contains('thrown later'));
    expect(fatal, isEmpty, reason: "one bundle's bug must not stop every extension");
    expect(results, {1: 'queued', 2: 'alive'});
  });
}
