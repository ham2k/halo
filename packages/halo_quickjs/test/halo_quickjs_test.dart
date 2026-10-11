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
      // Unbounded, the pump never returns. How fast it returns is a measure
      // of the machine (docs/design/time.md §7), so only that it does is
      // asserted, and that the engine is still usable after.
      js.evalBudgetMs = 200;
      js.eval('Promise.resolve(1).then(() => { while (true) {} })');
      js.pump();
      expect(js.eval("'alive'").text, 'alive');
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
      // A wall-clock bound, so it is set wide: past the budget by whatever a
      // starved machine adds before the next interrupt poll, well short of
      // the regression's eleven budgets.
      expect(sw.elapsedMilliseconds, lessThan(1500), reason: 'the budget must hold on the re-entrant path, not just the simple one');
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

  group('a result that cannot be stringified is a failure, not empty success', () {
    test('a Symbol result reports failure rather than ok with empty text', () {
      // REGRESSION: `failed` came from JS_IsException(v) alone, so when
      // JS_ToCString threw on a Symbol the shim returned rc=0 with *out=NULL,
      // which Dart surfaced as ok:true, text:''. engine_runtime_io's
      // _evaluate branches on exactly that flag, so a broken hook would have
      // sailed through as a successful one.
      final r = js.eval("Symbol('x')");
      expect(r.ok, isFalse);
      expect(r.text.toLowerCase(), contains('symbol'));
    });

    test('the failed conversion does not strand an exception for a later call', () {
      // JS_ToCString leaves the exception pending when it throws. Unless it is
      // cleared here it surfaces inside whatever unrelated call comes next.
      js.eval("Symbol('x')");
      final r = js.eval("'clean'");
      expect(r.ok, isTrue);
      expect(r.text, 'clean');
    });

    test('an infinite toString is bounded, not hung and reported as success', () {
      // REGRESSION: halo_leave ran BEFORE stringification, so coercion - which
      // is arbitrary JS - executed with no deadline armed and no interrupt
      // handler in force. This hung indefinitely and then returned rc=0.
      // Outside the budget, the coercion never returns; that it does, and
      // fails, is the whole claim.
      js.evalBudgetMs = 200;
      final r = js.eval('({ toString() { while (true) {} } })');
      expect(r.ok, isFalse, reason: 'coercion must run inside the same budget as the eval');
    });
  });

  test('a send argument that cannot be converted fails instead of arriving empty', () {
    // The trampoline discarded a NULL from JS_ToCString and passed "" on, so a
    // caller passing a Symbol looked to the host like a successful send of an
    // empty message, and left the exception pending.
    var delivered = false;
    js.onSend((_, _) => delivered = true);
    final r = js.eval("sendMessage(Symbol('x'), 'm')");
    expect(r.ok, isFalse);
    expect(delivered, isFalse, reason: 'a failed conversion must not reach the host at all');
  });

  test('the stack guard defaults low enough to actually fire', () {
    // #349: QuickJS defaults its guard to 1MB, but an extension-host isolate
    // thread gets about that on Windows/Android, so the OS stack overflowed
    // first and the process died uncatchably. The shim now defaults to 512KB
    // so the safe value is what you get without the caller setting one.
    final r = js.eval('(function f() { return f() })()');
    expect(r.ok, isFalse);
    expect(r.text.toLowerCase(), contains('stack'));
    expect(js.eval("'alive'").text, 'alive', reason: 'the guard must not poison the runtime');
  });

  test('a nested eval inherits the outer call\'s stack budget, not a fresh one', () {
    // halo_enter re-anchors QuickJS's stack_top ONLY at depth 0. Re-anchoring
    // a nested entry measures a whole fresh budget from an already-deep sp, so
    // the two frames together use ~2x the configured guard and run off the
    // real OS stack: the process dies uncatchably, with nothing on Sentry.
    //
    // Deleting the depth gate leaves every other assertion in this file green,
    // so this test is the only thing standing between that gate and a
    // plausible-looking cleanup.
    //
    // It measures rather than provokes: a segfault-based test would be
    // platform-dependent and would take the runner down instead of failing.
    // The budget is small enough that even the broken case (2x) fits inside
    // the test isolate's real stack, so a regression reports a number here
    // instead of crashing the suite.
    // Re-throws anything that is not the stack guard, so a recursion that
    // stopped for some other reason comes back as ok == false rather than as a
    // smaller number that would silently move every bound derived from it.
    const measureDepth =
        '(function(){ let d=0; function r(){ d++; r() }'
        ' try { r() } catch(e){ if (!/stack/i.test(String(e))) throw e }'
        ' return d })()';
    const stack = 512 * 1024;

    // Nothing is measured inside the callback: halo_quickjs.dart wraps the
    // Dart side of onSend in a bare catch, so an expect() or a parse failure
    // in there vanishes and leaves the test asserting against a sentinel.
    // Carry the raw result out and do all the checking on the way back.
    int depthOf(HaloQuickJsResult r, String what) {
      expect(r.ok, isTrue, reason: '$what did not evaluate: ${r.text}');
      final d = int.tryParse(r.text);
      expect(d, isNotNull, reason: '$what returned ${r.text}, not a depth');
      return d!;
    }

    // Calibrate: how deep one full budget goes on THIS platform. Frame sizes
    // differ per architecture and compiler, so every bound below is derived
    // from this number — never hardcoded.
    final calibrator = HaloQuickJs()..maxStackSize = stack;
    addTearDown(calibrator.dispose);
    final fullBudget = depthOf(calibrator.eval(measureDepth), 'calibration');
    expect(fullBudget, greaterThan(100), reason: 'calibration must have room to discriminate');

    // Drive the outer call most of the way down, then re-enter from the send
    // callback exactly as the host does, and see how much the nested eval has
    // left. Correctly gated it inherits the remainder; ungated it gets the
    // whole budget again.
    final outerTarget = (fullBudget * 0.75).round();
    final nested = HaloQuickJs()..maxStackSize = stack;
    addTearDown(nested.dispose);
    HaloQuickJsResult? nestedResult;
    nested.onSend((_, _) {
      // The outer call unwinds back through here, so measure only the first.
      nestedResult ??= nested.eval(measureDepth);
    });
    final outer = nested.eval(
      "function d(n){ if(n<=0){ sendMessage('c','m'); return 0 } return 1+d(n-1) }"
      "d($outerTarget); 'ok'",
    );

    expect(outer.ok, isTrue, reason: 'the outer call must survive to make the measurement mean anything');
    expect(nestedResult, isNotNull, reason: 'the outer call never reached sendMessage');
    final nestedDepth = depthOf(nestedResult!, 'the nested eval');
    // Measured on macOS arm64: 116 of 535 when gated, exactly 535 when not.
    // Half the budget sits far outside both regimes, so the bound discriminates
    // without depending on the absolute numbers.
    expect(
      nestedDepth,
      lessThan(fullBudget ~/ 2),
      reason:
          'the nested eval got a fresh stack budget — the depth gate on '
          'JS_UpdateStackTop is gone, and two budgets overflow the real stack',
    );
  });

  test('dispose from inside the host callback defers instead of crashing', () {
    // Verified segfault before the guard (EXC_BAD_ACCESS at 0x0): freeing the
    // context while a JS frame is still on the stack pulls it out from under
    // the code about to resume. The free is now deferred to depth 0.
    final iso = HaloQuickJs();
    var calls = 0;
    iso.onSend((_, _) {
      calls++;
      if (calls == 1) iso.dispose();
    });
    // MORE THAN ONE send, deliberately. dispose() closes the NativeCallable
    // behind onSend, so the next send from the still-unwinding frame invoked a
    // DELETED callback — "Callback invoked after it has been deleted", SIGABRT,
    // no Dart exception. The kernel sends many messages per eval, so a
    // single-send test proved nothing. The shim now drops host_fn the moment a
    // free is deferred.
    final r = iso.eval("sendMessage('c','1'); sendMessage('c','2'); sendMessage('c','3'); 'survived'");
    expect(r.ok, isTrue);
    expect(r.text, 'survived');
    expect(calls, 1, reason: 'no call-out may reach a host that is being torn down');
    expect(() => iso.eval('1'), throwsStateError);
  });

  test('an unhandled promise rejection is reported instead of vanishing', () {
    // The silent failure this whole package exists to avoid: nothing throws,
    // no eval returns non-zero, and the reaction simply never runs. flutter_js
    // logged these on Android/Windows/Linux via hostPromiseRejectionHandler,
    // so losing them in the swap would have been a regression there and a
    // continued blind spot on macOS/iOS.
    final seen = <String>[];
    js.onSend((channel, message) => seen.add('$channel|$message'));
    js.eval("Promise.reject(new Error('nobody catches me'))");
    for (var i = 0; i < 20; i++) {
      if (js.pump() == 0) break;
    }
    expect(seen, contains(startsWith('polo:unhandledRejection|')));
    expect(seen.join(), contains('nobody catches me'));
  });

  test('a rejection that IS handled stays quiet', () {
    // is_handled distinguishes a late-attached handler (a retraction of an
    // earlier report) from a genuine unhandled rejection. Reporting both would
    // make the log useless.
    final seen = <String>[];
    js.onSend((channel, message) => seen.add('$channel|$message'));
    js.eval("Promise.reject(new Error('caught')).catch(() => {})");
    for (var i = 0; i < 20; i++) {
      if (js.pump() == 0) break;
    }
    expect(seen.where((s) => s.startsWith('polo:unhandledRejection')), isEmpty);
  });

  test('re-entering the engine from the rejection callback does not corrupt it', () {
    // halo_flush_rejections reports through host_fn while freeing the batch,
    // and the host is explicitly allowed to re-enter — engine_runtime_io's
    // _evaluate ends every hostResponse with pump(), which lands straight back
    // in the flush. Before the guard this aborted the process (SIGABRT) and
    // reported the same rejection once per nesting level on the way down.
    final seen = <String>[];
    var depth = 0;
    js.onSend((channel, message) {
      if (channel != 'polo:unhandledRejection') return;
      seen.add(message);
      depth++;
      if (depth < 3) {
        for (var i = 0; i < 5; i++) {
          if (js.pump() == 0) break;
        }
      }
    });
    js.eval("Promise.reject(new Error('a')); Promise.reject(new Error('b'))");
    for (var i = 0; i < 20; i++) {
      if (js.pump() == 0) break;
    }
    expect(js.eval("'alive'").text, 'alive', reason: 'the engine must survive the re-entry');
    expect(seen.where((m) => m.contains('a')).length, 1, reason: 'each rejection is reported exactly once, not once per nesting level');
  });

  test('a rejection reason whose toString floods the tracker cannot corrupt it', () {
    // The bound was checked BEFORE halo_to_cstring ran the reason's toString —
    // which is arbitrary JS, called synchronously by quickjs at rejection
    // time, so it can queue rejections of its own and fill the array from
    // inside the check. The append then wrote past the end of the array, over
    // the adjacent text pointers, and the next flush passed a JSObject* to
    // strlen and free(). Reachable from extension JS with no host involved.
    js.onSend((_, _) {});
    final r = js.eval("Promise.reject({ toString() { for (let i = 0; i < 40; i++) Promise.reject(i); return 'flood' } })");
    expect(r.ok, isTrue);
    for (var i = 0; i < 200; i++) {
      if (js.pump() == 0) break;
    }
    expect(js.eval('1 + 1').text, '2', reason: 'the heap must still be intact');
  });

  test('an exception that cannot be stringified still reports something', () {
    // `throw Object.create(null)` has no toString, so halo_to_cstring returned
    // NULL and the hook failed with NO diagnostic text at all - the host
    // surfaced ExtensionHostException("evaluating invokeHook: "). Same defect
    // class the eval path already guarded; this was the last site doing it.
    for (final code in ['throw Object.create(null)', "throw Symbol('s')"]) {
      final r = js.eval(code);
      expect(r.ok, isFalse);
      expect(r.text, isNotEmpty, reason: 'a failure with no message is not actionable');
    }
    expect(js.eval('1 + 1').text, '2', reason: 'and no exception may be left pending');
  });

  test('rejections that overflow the tracker but are handled stay quiet', () {
    // Overflowed rejections are counted, not stored, so the retraction scan
    // cannot find them when handlers attach. Reporting the bare count made 40
    // promises that were ALL caught indistinguishable from 40 unhandled ones.
    final seen = <String>[];
    js.onSend((channel, message) {
      if (channel == 'polo:unhandledRejection') seen.add(message);
    });
    js.eval(
      'const ps = []; '
      'for (let i = 0; i < 40; i++) ps.push(Promise.reject(i)); '
      'ps.forEach((p) => p.catch(() => {}))',
    );
    for (var i = 0; i < 300; i++) {
      if (js.pump() == 0) break;
    }
    expect(seen, isEmpty, reason: 'every one of them was handled');
  });

  test('dispose is idempotent and rejects later use', () {
    final one = HaloQuickJs()..onSend((_, _) {});
    one.dispose();
    one.dispose();
    expect(() => one.eval('1'), throwsStateError);
  });
}
