// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The web build runs every bundle in one Worker, evaluated with indirect
// eval in the worker's global scope, beside the bootstrap that carries the
// host's traffic. Anything of the bootstrap's a bundle can reach — a
// top-level name, `self.onmessage`, the worker's own message channel — is a
// way to read what the host sends (other extensions' credentials among it)
// or to put a message on the wire as any extension. So the probe bundle here
// tries each of them, and the host must see none of it.
//
// The kernel is a stand-in: a browser test cannot read the built one from
// disk, and what is under test is the bootstrap, which treats the kernel as
// a `bridge` it holds the token to. host_bridge_test holds the real kernel's
// bridge.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/src/js_engine.dart';

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
let claimed
try { __halo.claimBridge('f'.repeat(64)); claimed = 'claimed' } catch (e) { claimed = String(e.message) }
__halo.defineHook('report', () => ({ reach, forged, claimed, overheard, hijacked, entries: __halo.entries() }))
''';

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
    expect(report['entries'], ['beginBundle', 'endBundle', 'activateAll', 'invokeHook']);
    expect(messages.where((m) => m['type'] == 'hostCall'), isEmpty, reason: "a host call as another extension must never reach the host");
    expect(messages.where((m) => m['id'] == 88), isEmpty);
    expect(jsonEncode(report['forged']), contains('posted'), reason: 'the worker channel stays open; the host is what stops listening to it');
  });
}
