# Phase 0 spike — direct QuickJS-NG binding

**Throwaway.** This is not production code and is not built by anything. It
exists so the measurements in [js-engine.md](../../js-engine.md) — the ABI and
callback findings, and the recursion depths behind the stack-anchor gate — are
reproducible rather than asserted. `packages/halo_quickjs` is the real plugin
that replaced it.

`stack_test.c`'s measurement approach now lives in
`packages/halo_quickjs/test/` as a real test, rebuilt to calibrate its bounds at
runtime rather than carry this file's hardcoded macOS-arm64 threshold
(js-engine.md §4).

quickjs-ng source is deliberately **not** vendored here — fetch it.

## Run it

```bash
cd /tmp && git clone --depth 1 --branch v0.15.1 https://github.com/quickjs-ng/quickjs.git qjs-src
mkdir -p /tmp/qjs-spike && cd /tmp/qjs-spike
cp /tmp/qjs-src/*.h /tmp/qjs-src/{quickjs,libregexp,libunicode,dtoa}.c .
cp <this-dir>/{halo_qjs.h,halo_qjs.c,test.c,reentry.dart} .

# C assertions
cc -c -O2 -DNDEBUG -D_GNU_SOURCE -I. quickjs.c libregexp.c libunicode.c dtoa.c halo_qjs.c
ar rcs libhaloqjs.a *.o
cc -O2 -I. test.c libhaloqjs.a -o spike && ./spike

# Dart assertions (protocol + re-entrancy) — needs the shared build
cc -shared -O2 -o libhaloqjs.dylib quickjs.o libregexp.o libunicode.o dtoa.o halo_qjs.o
dart run reentry.dart
```

`reentry.dart` hardcodes `/tmp/qjs-spike/libhaloqjs.dylib`. Solving that
properly — a host-native library `flutter test` can find — is §4.3, still
open.

## What each file proves

| File | Proves |
|---|---|
| `halo_qjs.{h,c}` | A flat, string-in/string-out C boundary is sufficient; no `JSValue` in any encoding needs to cross FFI |
| `test.c` | eval, error+stack, host callback, promise pump, interrupt, memory limit, and the nested-deadline regression — all from C, no Dart involved |
| `reentry.dart` | The real `sendMessage(channel, message)` protocol, `delete globalThis.sendMessage`, and synchronous re-entrant `JS_Eval` from inside the callback, on both the main and a background isolate |
| `deadline_test.c` | Standalone reproduction of the nested-deadline bug (below). Takes the harness's nesting bound as `argv[1]`, so you can check which component is really imposing the ceiling |
| `stack_test.c` | The `JS_UpdateStackTop` depth gate. Measures nested recursion depth rather than provoking a segfault; verified to fail against a mutant with the gate removed |
| `pump_test.c` | `halo_qjs_execute_pending_job` as a real JS entry point: a benign promise reaction must not inherit an expired deadline, and a runaway one must still be bounded |

## Verifying a test can actually fail

`stack_test.c` was checked against a deliberately broken shim (the
`JS_UpdateStackTop` call hoisted out of its depth gate) and **fails** there
while passing on the real one. Do the same for any assertion added in
Phase 1 — two of the defects below were assertions that could not fail.

```bash
# build a mutant with the depth gate removed, then confirm the test catches it
sed 's|  if (h->depth == 0) {\n    JS_UpdateStackTop|  JS_UpdateStackTop|' halo_qjs.c > /dev/null  # see git history for the exact mutation
./stack_test 2000        # gated   -> exit 0
./stack_test_mut 2000    # ungated -> exit 1
```

## The bug review found

A runaway hook calling `sendMessage` was never interrupted: **2201ms against
a 200ms budget**, defeated exactly where it was needed.

It took three attempts to actually fix, and the two wrong ones are the
instructive part.

**Wrong attempt 1 — a bounded experiment that bounded away its own subject.**
The first reproduction capped nesting by *call count*, which stopped nesting
early enough that the deadline fired soon after regardless: 227ms, which
reads as a pass. Only a *wall-clock* bound separated the hypotheses.

**Wrong attempt 2 — a fix that wasn't, validated by a single run.** The
deadline was being refreshed on every entry, so it was depth-gated to the
outermost call. One run reported 204ms and it was written up as fixed. Run
50 times it failed 12; and raising only the *harness's* nesting bound from
2s to 10s moved the measurement to 10001ms — the shim had no ceiling, the
harness did.

**The real mechanism.** QuickJS raises the interrupt as a JS exception. When
it lands in a nested eval, `halo_format_exception`'s `JS_GetException`
**clears** it; the nested call returns, the host discards it, the outer loop
resumes. Since nearly every operation the outer loop performs happens inside
that callback, the interrupt was consumed on essentially every iteration.
Depth-gating the deadline never touched this — the deadline had already
passed.

**The fix** latches the interrupt on the handle (cleared only on the
outermost entry) *and* re-raises it from the send trampoline so the outer
script unwinds. 50/50 runs pass, and the ceiling is now the shim's: 202ms
even when the harness is told to nest for 10s.

Three things to carry into Phase 1:

1. **Any state on the runtime struct is shared with nested calls** — the
   deadline, the stack anchor and the interrupt latch all needed
   depth-awareness.
2. **An error path that consumes an exception can swallow a control
   signal.** Every `JS_GetException` reachable from a nested context needs
   that scrutiny.
3. **Validate a fix across many runs, and check which component is really
   imposing the bound.** A single green run proved nothing here.

## Every entry into JS goes through `halo_enter`/`halo_leave`

The deadline, the stack anchor and the interrupt latch are all
*per-outermost-call* state, and each was got wrong at least once while that
logic lived inline at one call site. `halo_qjs_execute_pending_job` was the
proof: it was a second entry point into JS with none of it, so a promise
reaction ran against whatever deadline the previous `eval` left behind
(measured: a benign reaction killed by a deadline that had expired 350ms
before it started) and re-entered the host at depth 0, re-anchoring the
stack mid-call — #349 again, by a different door.

Phase 1 should treat "is this a new entry point into JS?" as the question
that decides whether something needs `halo_enter`.

## Known-wrong in here, on purpose

`halo_qjs_set_host_fn` still takes a `global_name` parameter. The real
binding should hardcode `sendMessage` — `extensions/sdk/src/kernel.ts:55`
fixes that name, and making it configurable invites a mismatch that fails
silently (the kernel falls back to a throwing shadow and hooks just stop
working).
