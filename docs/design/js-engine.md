# JS Engine Binding — direct QuickJS-NG via `dart:ffi`

> Status: as-built · Last updated: 2026-08-07

DESIGN.md §3 specifies the extension runtime's engine as **QuickJS (QuickJS-NG)
via dart:ffi**, bound directly for control over interrupts, memory limits and
module loading. `packages/halo_quickjs` is that binding.

This document describes what it does, the decisions that give it its shape, and
— the part worth reading before changing anything — the invariants it depends
on. Native binding bugs are segfaults and silent wrong answers, not exceptions,
so most of what follows is a constraint rather than a description.

**One engine, every native platform.** `engine_runtime_io.dart` uses
`halo_quickjs` on macOS, iOS, Android, Windows and Linux; web has its own
Worker-backed implementation (`engine_runtime_web.dart`) on the browser's
engine. A single native engine is the point: when native was split between
QuickJS and JavaScriptCore, the same extension could behave differently by
platform, and the test suite — running on macOS — exercised the engine the
*minority* of users had.

---

## 1. Two decisions that shape the package

### 1.1 Static linking, not a separate shared library

quickjs is compiled into a **static** library and linked into the plugin's own
shared library — the one Flutter already builds, bundles and signs per
platform. There is no separate binary to locate, ship, sign, or get out of sync,
and no `dlopen` at runtime.

This is load-bearing, and the reason is worth keeping: a separately-`dlopen`'d
engine produces load-path hacks, bundling quirks, silent architecture
mismatches, and an "is it even in the build?" failure mode that no test catches.
Static linking also makes architecture correct by construction — the plugin is
compiled by the platform toolchain for whatever it targets, rather than by
someone remembering to publish an artifact for that arch.

### 1.2 Compile from source; do not ship prebuilts

The vendored source is pinned by tag in
`packages/halo_quickjs/src/quickjs/VERSION` (tag **and** exact commit sha).
Every platform compiles it.

The cost is small: all core translation units (`quickjs.c`, `libregexp.c`,
`libunicode.c`, `cutils.c`, `dtoa.c`, ~70k lines) build in **4.6s wall / ~5s
CPU** at `-O2` on an 18-core Apple Silicon machine — 1.1 MB static, 964 KB
shared. Even several times slower on a modest CI builder that is well under 1%
of a Flutter build. CMake and Xcode cache the objects, so incremental builds
recompile only when the pin moves.

**Shipping our own prebuilts is rejected, and should stay rejected.** It means
owning an 8–10 target matrix (linux x64/arm64, win x64/arm64, android
arm64/armv7/x86_64, macos universal, ios arm64) plus hosting, checksums and
version pinning, permanently — and it adds a problem compiling from source does
not have: a downloaded `.dylib` must be signed and notarized as part of the
macOS app. If CI minutes ever justify it, the lever is **build caching** keyed
on quickjs version + platform + arch, not a distribution pipeline.

---

## 2. The FFI boundary is flat, and must stay flat

**No QuickJS type crosses the FFI boundary.** `src/halo_qjs.{c,h}` exposes a
flat, pointer/int-based C API; the boundary is string-in / string-out.

This is not stylistic. `JSValue`'s *representation changes by architecture
inside our own target matrix*: `quickjs.h` auto-enables `JS_NAN_BOXING` when
`INTPTR_MAX < INT64_MAX`, making `JSValue` a `uint64_t` on 32-bit targets
(Android `armeabi-v7a`) and a 16-byte `{JSValueUnion u; int64_t tag;}` struct on
every 64-bit one. Dart FFI bindings resolve at compile time, so a by-value
`JSValue` would need two incompatible Dart definitions in one binary.
Independently, `JS_NewCFunction` and `JS_ToCStringLen` are `static inline` in
the header and are not exported symbols at all — unreachable from FFI whatever
the ABI does.

`tool/verify_targets.sh` cross-compiles the shim and quickjs for every target
ABI and asserts the representation with a `_Static_assert`: NaN-boxed
`uint64_t` on `armeabi-v7a`, 16-byte struct on arm64 and iOS. That the same
shim source compiles against both is the property the flat boundary exists to
guarantee — run it after any bump.

---

## 3. The host callback contract

JS reaches Dart through a `sendMessage` global installed by the shim, called
synchronously on the calling thread via `NativeCallable.isolateLocal`
(*not* `.listener`, which queues asynchronously).

The kernel's side of the contract (`extensions/sdk/src/kernel.ts`) is:

```ts
declare function sendMessage(channel: string, message: string): void
```

Two arguments, **void return** — the kernel discards any value. The property
must also be **configurable**: `kernel.ts` does `delete globalThis.sendMessage`
as its containment boundary, and a non-configurable property makes that delete
fail silently, degrading the kernel to a throwing shadow.
`JS_SetPropertyStr`'s default flags satisfy this.

**Re-entrancy is mandatory, not incidental.** `halo_extension_host.dart`'s
`kvGet`/`kvSet` cases reach `_js.hostResponse(...)` with **no `await`** in
between, so the enclosing `async` function runs straight through and re-enters
`JS_Eval` *from inside* the `sendMessage` callback. The shim therefore keeps no
per-call scratch state, and nesting is exercised to three levels.

Two behaviours the Dart side must design around:

1. **A Dart exception inside the callback is silently swallowed** — the
   callback returns null, JS sees `undefined`, and nothing surfaces anywhere.
   Host-side failures must be encoded in the reply payload; they can never be
   signalled by throwing.
2. **An unclosed `NativeCallable` keeps its isolate alive forever.**
   `dispose()` must close every callable it ever created, or the extension-host
   isolate never shuts down.

`ExtensionHost.dispose()` must also actually send the `'dispose'` message its
entry point waits for. Killing the isolate without it leaks the engine's native
heap — 10–12 MB for the kernel bundle alone — on every restart.

---

## 4. Everything on the runtime struct is shared with nested calls

This is the single most important invariant in the shim, and the one that has
already produced defects three separate ways.

Because the host callback re-enters `JS_Eval`, any state stored on the runtime
handle is visible to nested calls. Three fields need depth-awareness, and
**every field added later needs the same question asked**:

- **The eval deadline** — refreshed only on the outermost entry, or nested
  calls push it out indefinitely.
- **The stack anchor** — re-anchored only on the 0→1 depth transition.
- **The interrupt latch** — set when the deadline fires, cleared only on the
  outermost entry.

### The stack anchor

A Dart isolate is not pinned to one OS thread, so QuickJS's recorded
`stack_top` can belong to a thread we have since migrated off; it must be
re-anchored with `JS_UpdateStackTop`. But re-anchoring a *nested* entry moves
`stack_top` down to the already-deep stack pointer and hands the nested frame a
full fresh budget measured from there — overflowing the real OS stack.

**Exactly one test covers this gate** — *a nested eval inherits the outer
call's stack budget, not a fresh one*, in `packages/halo_quickjs/test/`. Every
other assertion in that file stays green with the gate deleted, so it is the
only thing standing between a load-bearing invariant and a plausible-looking
cleanup. It is verified to fail against a mutant with `JS_UpdateStackTop`
hoisted out of the `depth == 0` branch.

It **measures** rather than provokes: a segfault-based test is
platform-dependent and takes the runner down instead of failing. It calibrates
a full budget's recursion depth at runtime, drives the outer call to 75% of it,
then re-enters from the send callback and measures what the nested eval has
left. A correctly gated anchor leaves the remainder; an ungated one returns the
*full* calibrated depth. On macOS arm64 with a 512KB guard that is 116 versus
535 — but nothing absolute is asserted, because frame sizes differ by
architecture and compiler.

### The interrupt latch

QuickJS raises the interrupt as a JS exception. Landing inside a **nested**
eval, `halo_format_exception`'s `JS_GetException` **clears** it; the nested call
returns, the host discards the result, and the outer loop resumes. Since nearly
every operation the outer loop performs happens inside that callback, an
unlatched interrupt is consumed on essentially every iteration, forever — a
runaway hook measured 2201ms against a 200ms budget, defeated in exactly the
scenario the interrupt exists for.

The fix is two-part and both halves are required: the interrupt is **latched**
on the handle, and the send trampoline **re-raises** it after the host returns,
so the outer script unwinds instead of resuming. With both, the ceiling comes
from the shim — 202ms even when the caller nests for 10s.

The general lesson, worth applying to any future `JS_GetException` in a nested
context: **an error path that consumes an exception can swallow a control
signal.**

### The depth window

Coercion must run *inside* the depth window. `JS_ToCString` runs arbitrary JS,
so stringifying a result after leaving the window executes it with no deadline
armed — an infinite `toString` then hangs indefinitely and is reported as
success. For the same reason `halo_qjs_free` is deferred to depth 0: freeing
from inside the host callback pulls the context out from under a live JS frame.

Failure must also be reported from more than `JS_IsException`: a result that
cannot be stringified (a `Symbol`) otherwise returns rc=0 with `*out=NULL`,
which reaches Dart as `ok: true, text: ''` — the exact flag `_evaluate`
branches on — and strands the pending exception to surface inside a later,
unrelated call.

---

## 5. Resource limits

**The stack guard is 512KB on every platform** (defaulted in `halo_qjs_new`, so
the safe value is what a caller gets without having to remember). QuickJS
defaults to 1MB, but an extension-host isolate thread gets roughly that on
Windows and Android, so QuickJS never trips its own check and the OS stack
overflows first — an uncatchable `EXCEPTION_STACK_OVERFLOW`, no Dart error,
nothing on Sentry.

A generous value is the dangerous one. Measured on Linux, recursing until the
guard fires:

| guard | result |
|---|---|
| 512KB | caught, 527 frames |
| 1024KB | caught, 1056 frames |
| 1536KB | **process killed, SIGBUS** |
| 2048KB | **process killed, SIGBUS** |

Reasoning from the 8MB *pthread* default is what produces the dangerous
numbers: a Dart isolate thread is sized by the VM, not by pthread.

**A 15s eval budget** applies on every platform, sitting deliberately above the
host's own 10s hook timeout: the host still reports first, and the budget only
makes the isolate usable afterwards. It covers one outermost call, so note that
a count-based bound on `pump()` is not equivalent — every `pump()` is its own
outermost call and gets a fresh 15s.

**The interrupt is deliberately not catchable**, and `halo_qjs.h` says so. A
script killed by the budget cannot report its own failure, so the host must fail
the outstanding request when eval returns non-zero rather than waiting for a
JS-side result that can never arrive. `_evaluate` throws on an error result,
which is the shape this depends on — keep that property.

**The memory ceiling is Android-only, deliberately** (256 MB): Android is where
one runaway extension most readily takes the app down, and desktop values have
not been measured. Extending it to desktop, which does the largest imports,
belongs with the untrusted-extension work rather than here.

### Engine load

One engine answers every hook, so a keystroke's lookup or dupe check waits
behind whatever else extensions are doing. How much room it has is measured
as **busy time**, in 100ms slices of real time
(`halo_extension_host/lib/src/engine_load.dart`). Each slice carries its busy
total, its time by label, and the longest single busy span that ended in it,
at its full length — the worst wait a call arriving during it could have had.

- **Native** times every entry into the engine from the core
  (`_HostCore._busy`): incoming calls, the job pump, timers, socket events,
  host responses, the boot. Only the outermost entry counts, because the host
  callback re-enters the engine and would otherwise be charged twice.
- **A host response is charged to the call that made the request**, not to the
  host method: the answer resumes that call, and the kernel fetches a hook's
  settings before running it, so without this every busy hook reads as
  `host:getSettings`.
- **Web** is approximate. The worker opens a span when a message arrives and
  closes it when a task queued behind it runs, so the microtasks the message
  started — where a hook's body runs, after the kernel awaits its context —
  are inside it. Work outside those microtasks is not seen.
- **A span's length is monotonic, its place is real time.** Measured on the
  wall clock, a laptop asleep mid-call would wake to a span hours long. No
  span is recorded longer than the minute the window keeps.
- **A span is known only once it ends**, so a heartbeat covers the call still
  running (`EngineLoadFeed`). The host pings the engine once a second; the
  ping queues behind whatever holds it (on web, the worker answers only once
  its open span has been reported). A ping unanswered for a whole heartbeat
  makes every slice since it was sent count as busy, until the answer comes —
  without it, a long call reads as idle until it returns, and a wedged web
  worker as idle for good. The heartbeat runs only while the engine reported
  busy time in the last 10 seconds or a call is being sent, so a hang that
  starts from quiet is noticed with the next call, the first one it holds up.
  A ping is never timed as busy time itself, and a dead engine's heartbeat
  stops with it rather than reading as a stall until it is replaced.
- A slice with no busy time is never sent, and the flush timer runs only
  while a slice is open, armed once per slice — an idle engine costs no
  wake-ups. A job-pump tick that finds the queue empty is not busy time: the
  pump ticks every 5ms while a hook awaits the network.

`EngineLoadMonitor` (app) follows the slices across runtime replacements.
Settings → Developer → Show idle metrics (or `DEVIDLE`) shows the 1-second
idle share in the status bar; tapped, it opens to the 1-, 10- and 60-second
shares. Each share is yellow at 70% or below and red at 50% or below.
The readout is a developer-mode setting: leaving developer mode hides it with
its switch. Below 30% it sends an "Extension engine busy" diagnostic
([error-reporting.md](error-reporting.md)) at most every five minutes, and only
while "Share app usage data" is on, since the app volunteers it. In the first
runtime's first minute it reports only when that launch drew a 10% sample,
rolled once, so a busy launch does not report itself; a replacement runtime
gets no such exemption, since an engine that crash-loops is the one most worth
hearing about.

---

## 6. Where quickjs-ng differs from a browser

**`Intl` does not exist.** `toLocaleString` is wired to
`Number.prototype.toString` and ignores both arguments, so `fmtInteger` in
`@ham2k/lib-format-tools` silently stops grouping — a 1500-QSO tally reads
`1500 QSOs`, a contest score `345320`. `extensions/sdk/src/number-format.ts`
patches `Number.prototype.toLocaleString`, imported first in `kernel.ts` so the
patch precedes any module that formats a number, and behaviour-gated so the real
implementation survives on the web runtime.

This is deliberately **not** an `Intl` shim. i18next activates its own Formatter
on `typeof Intl !== "undefined"` and then calls `Intl.NumberFormat`,
`DateTimeFormat` and `PluralRules`; a partial `Intl` converts a quiet
degradation of `{{v, datetime}}` into a thrown error that fails the whole hook.

**Unhandled promise rejections** are reported via
`JS_SetHostPromiseRejectionTracker`, **deferred until the job queue drains**.
The delay is the point: quickjs reports a rejection immediately and again when a
handler attaches, so reporting eagerly logs every `Promise.reject(x).catch(f)`.

---

## 7. Platform integration

**Apple platforms need Swift Package Manager, not just a podspec.** The app
resolves every one of its Apple plugins through SPM, and a plugin shipping only
a podspec draws "The following plugins do not support Swift Package Manager for
macos: halo_quickjs. This will become an error in a future version of Flutter."
So `macos/halo_quickjs/` and `ios/halo_quickjs/` carry a `Package.swift` each;
the podspecs stay for CocoaPods consumers and the two coexist.

`Sources/` holds the same kind of forwarder the podspec's `Classes/` uses, for
the same reason: SPM requires a target's files to live inside the package
directory. It works because `#include "..."` resolves relative to the
**including** file, so quickjs's bare-name includes of each other still land in
`src/quickjs/` without any header search path escaping the package.

**`flutter test` never performs a platform native build**, so the host VM has no
plugin library to load — and the integration suite runs against the *real*
engine in-process. `tool/build_host.sh` produces one host-arch library into
`build/`, cached; `scripts/test.sh` runs it before the suites, and the binding's
library-open logic prefers it under test.

**The engine is verified to actually ship.** `tool/verify_engine_ships.sh` (and
its `.ps1` twin) assert the library is present in the packaged bundle — a check
worth having, because a plugin silently missing from a build is the failure mode
static linking is meant to prevent and the app only fails at runtime. On Apple
platforms the engine lands in the app's `*.debug.dylib` (macOS 1.3 MB, iOS
2.6 MB), not in the thin launcher binary — worth knowing before concluding it
is missing.

**Static linking force-exports 248 `JS_*` symbols** on ELF/Mach-O, because
`JS_EXTERN`'s explicit `visibility("default")` overrides
`C_VISIBILITY_PRESET hidden`. Windows is unaffected — `JS_EXTERN` is empty
there. This is currently harmless because nothing else in the app links a
QuickJS; it becomes a real problem the moment something does.

---

## 8. Bumping the pin

Treat a bump as its own piece of work. quickjs-ng has made deliberate breaking
changes to the classic Bellard API, so signatures must be read from the pinned
version's own `quickjs.h` rather than from Bellard-era examples — and a clean
compile is necessary but not sufficient, because several invariants above live
in *our* shim rather than in quickjs. The procedure and the "why this needs a
human" argument are in [maintenance.md](../maintenance.md) §1.

---

## 9. Verification

- `packages/halo_extension_host/test/extension_host_test.dart` — the
  integration suite, run against the real engine, is the primary gate. It
  drives the actual kernel and extension bundles rather than mocks.
- `packages/halo_quickjs/test/` — the binding's own suite, covering the API
  surface bound here: eval, exceptions and stacks, the `sendMessage` bridge,
  promise pumping, interrupt, memory limit, re-entrancy.
- `tool/verify_targets.sh` — every target ABI cross-compiles and the `JSValue`
  representation assertion holds.
- Per-platform smoke: first-run onboarding with a real callsign, the path an
  engine-startup crash takes down first.

**A suite that blocks in native code cannot time itself out.** A blocked
isolate never runs the timer behind `flutter test`'s own per-test timeout — a
3s timeout does not fire against a runaway eval. So losing the eval deadline
does not turn these tests red, it hangs the run: the assertions after the eval
simply never execute, and the suite neither passes nor fails.

Only a kill from outside the process converts that back into a failure, and
**nothing provides one**: these tests belong to the full gate, which runs only
on a developer's machine (the Checks workflow analyzes but never tests), so a
hung `./scripts/test.sh` waits for a Ctrl-C rather than for a runner timeout.
An in-script watchdog is the wrong way to add one — wrapping the runner risks
making a broken environment look like a pass, which is far worse than the hang
it would prevent. Recognising the hang for what it is remains the operator's
job: a gate that has stopped producing output has not "nearly finished".

**Native code is not Shorebird-patchable** (docs/releases.md §4), so a change
here ships in a normal release cycle, not a code push.
