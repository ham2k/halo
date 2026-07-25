// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Phase 0 spike's assertions, promoted to a real suite. Several exist
// because a bug got past an earlier, weaker version of the same test — those
// are called out individually, since the reason is the load-bearing part.
//
// Requires the host library: `tool/build_host.sh` (scripts/test.sh runs it).

import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_quickjs/halo_quickjs.dart';

void main() {
  late HaloQuickJs js;

  setUp(() => js = HaloQuickJs());
  tearDown(() => js.dispose());

  test('reports the pinned quickjs-ng version', () {
    expect(HaloQuickJs.version, contains('quickjs-ng'));
  });

  test('evaluates and coerces the result to a string', () {
    final r = js.eval('1 + 1');
    expect(r.ok, isTrue);
    expect(r.text, '2');
  });

  test('a thrown error comes back as data, with a stack, not an exception', () {
    // The host treats a failing hook as degraded, never as a crash — so this
    // must never become a Dart throw.
    final r = js.eval("throw new Error('boom')");
    expect(r.ok, isFalse);
    expect(r.text, contains('boom'));
    expect(r.text, contains('at '), reason: 'the stack is what makes a hook failure actionable');
  });

  group('the kernel protocol', () {
    test('sendMessage(channel, message) reaches the host with both arguments', () {
      String? channel, message;
      js.onSend((c, m) {
        channel = c;
        message = m;
      });
      final r = js.eval("sendMessage('polo', JSON.stringify({type:'log'})); 'sent'");
      expect(r.ok, isTrue);
      expect(channel, 'polo');
      expect(message, '{"type":"log"}');
    });

    test('the global is configurable, so the kernel can delete it', () {
      // kernel.ts installs its own shadow and then deletes the global as a
      // containment boundary. A non-configurable property would leave the
      // kernel silently degraded to a throwing stub, with hooks dead.
      js.onSend((_, _) {});
      final r = js.eval('delete globalThis.$kSendGlobal; typeof globalThis.$kSendGlobal');
      expect(r.ok, isTrue);
      expect(r.text, 'undefined');
    });
  });

  group('re-entrancy', () {
    test('the host can re-enter eval from inside the callback', () {
      // halo_extension_host.dart's kvGet/kvSet path reaches hostResponse with
      // no await, so JS_Eval genuinely runs nested inside sendMessage.
      js.onSend((_, _) => js.eval("globalThis.fromNested = 'set'"));
      final r = js.eval("sendMessage('polo','x'); globalThis.fromNested");
      expect(r.ok, isTrue);
      expect(r.text, 'set');
    });

    test('survives three levels of nesting and stays healthy', () {
      var depth = 0;
      js.onSend((_, _) {
        depth++;
        if (depth < 3) js.eval("sendMessage('polo','deeper')");
      });
      expect(js.eval("sendMessage('polo','start'); 'survived'").text, 'survived');
      expect(depth, 3);
      expect(js.eval('(() => { let s=0; for (let i=0;i<1000;i++) s+=i; return s })()').text, '499500');
    });
  });

  group('promise jobs', () {
    test('reactions need pumping, and settle once pumped', () {
      expect(js.eval("globalThis.r='pending'; Promise.resolve(42).then(v => { globalThis.r = String(v) }); globalThis.r").text, 'pending');
      expect(js.pump(), greaterThan(0));
      expect(js.eval('globalThis.r').text, '42');
    });

    test('a benign reaction does not inherit an expired deadline', () async {
      // REGRESSION: halo_qjs_execute_pending_job used to arm no deadline, so a
      // reaction ran against whatever the previous eval left behind. Measured:
      // a harmless reaction killed by a deadline that expired 350ms before it
      // even started. The work below is deliberately long enough to be polled
      // by the interrupt handler — a 1-2 bytecode reaction slips through
      // before any poll and proves nothing.
      js.evalBudgetMs = 200;
      js.eval("globalThis.ran='no'; Promise.resolve(1).then(() => { let s=0; for (let i=0;i<300000;i++) s+=i; globalThis.ran='yes' })");
      await Future<void>.delayed(const Duration(milliseconds: 350));
      js.pump();
      expect(js.eval('globalThis.ran').text, 'yes');
    });

    test('a runaway reaction is still bounded', () {
      js.evalBudgetMs = 200;
      js.eval('Promise.resolve(1).then(() => { while (true) {} })');
      final sw = Stopwatch()..start();
      js.pump();
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('resource limits', () {
    test('a runaway script is interrupted and the engine survives it', () {
      js.evalBudgetMs = 200;
      final r = js.eval('while (true) {}');
      expect(r.ok, isFalse);
      expect(js.eval("'alive'").text, 'alive', reason: 'an interrupt must not poison the runtime');
    });

    test('a runaway hook that calls out on every pass is still interrupted', () {
      // THE regression. QuickJS raises the interrupt as a JS exception; when
      // it lands in a nested eval the shim's JS_GetException clears it, the
      // host discards the result, and the outer loop resumes — swallowing the
      // interrupt once per iteration, forever. Measured 2201ms against a
      // 200ms budget before the latch + re-raise fix.
      js.evalBudgetMs = 200;
      js.onSend((_, _) => js.eval('1'));
      final sw = Stopwatch()..start();
      final r = js.eval("while (true) { sendMessage('c','m') }");
      expect(r.ok, isFalse);
      expect(sw.elapsedMilliseconds, lessThan(1000),
          reason: 'the budget must hold on the re-entrant path, not just the simple one');
    });

    test('the memory limit trips instead of taking the process down', () {
      final limited = HaloQuickJs()..memoryLimit = 1024 * 1024;
      addTearDown(limited.dispose);
      final r = limited.eval('let a=[]; while (true) { a.push(new Array(10000).fill(1)) }');
      expect(r.ok, isFalse);
      expect(r.text.toLowerCase(), contains('memory'));
    });
  });

  test('works on a background isolate, which is where the host runs it', () async {
    final out = await Isolate.run(() {
      final iso = HaloQuickJs();
      try {
        iso.onSend((_, _) => iso.eval("globalThis.n='ok'"));
        return iso.eval("sendMessage('polo','y'); globalThis.n").text;
      } finally {
        iso.dispose();
      }
    });
    expect(out, 'ok');
  });

  test('dispose is idempotent and rejects later use', () {
    final one = HaloQuickJs()..onSend((_, _) {});
    one.dispose();
    one.dispose();
    expect(() => one.eval('1'), throwsStateError);
  });
}
