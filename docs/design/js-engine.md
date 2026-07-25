# JS Engine Binding — direct QuickJS-NG via `dart:ffi`

> Status: plan · Last updated: 2026-07-25

DESIGN.md §3 specifies the extension runtime's engine as "**QuickJS
(QuickJS-NG) via dart:ffi** — the `flutter_js` package wraps QuickJS, but we
bind directly for control over interrupts, memory limits, and module
loading." Today we still run on `flutter_js`. This document is the plan to
close that gap, and the reasoning behind the two decisions that shape it.

The trigger is Linux ARM64 support (Raspberry Pi and friends — a real
audience for a portable logger), but the case no longer rests on that alone:
the package we depend on is unmaintained at the layer that matters, and it
has already cost us a production crash.

---

## 1. Why now

**The native bridge is abandoned.** `flutter_js`'s Dart side still sees
occasional releases, but its actual C bridge lives in a separate repository,
[`abner/quickjs-c-bridge`](https://github.com/abner/quickjs-c-bridge), whose
last commit is **2021-04-13**. Everything below follows from that.

**ARM is broken upstream, and known to be.** `flutter_js`'s own
`android/build.gradle` disables its from-source QuickJS build with the
comment:

```
//quickjs C build disabled for now - crashing with SEGV_MAPERR on ARM based devices
```

So Android runs on prebuilt `.so`s instead. On Linux and Windows there is no
from-source path at all — the package ships a single prebuilt binary each,
and both are **x86-64 only** (verified directly against the files in the pub
cache). There is no ARM64 artifact to ship, and the from-source route
upstream abandoned is the one that crashes on ARM. Upstream QuickJS-NG, by
contrast, publishes `qjs-linux-aarch64` release binaries and builds ARM64 in
its own CI — **the ARM problem is `flutter_js`'s bridge, not QuickJS.**

**Those stale prebuilts already cost us capability.** `engine_runtime_io.dart`
carries this comment today:

> The memory limit is Android-only: flutter_js compiles the QuickJS bridge
> from source there, but ships stale prebuilt binaries on Linux and Windows
> that export `jsSetMaxStackSize` and NOT `jsSetMemoryLimit`, so a non-null
> memoryLimit crashes engine startup on those platforms.

A runaway extension can therefore OOM the app on desktop, and we cannot fix
it without a bridge rebuild we don't control.

**And it cost us a production crash.** #349 (merged 2026-07-25) fixed a
Windows first-run hard-crash: the QuickJS stack guard sat beyond the isolate
thread's real ~1MB native stack, so QuickJS never tripped its own check, the
OS stack overflowed first, and the process died with an uncatchable
`EXCEPTION_STACK_OVERFLOW` — no Dart error, nothing on Sentry. The fix
(lower the guard to 512KB) is sound, but it is a workaround against an
engine we can't instrument, and that PR's own note says confirmation still
needs a Windows crash dump. Owning the binding gives us the interrupt
handler and memory limit needed to make this class of failure *catchable*
rather than fatal.

**We already maintain three workarounds for it.** All exist solely because
the bridge ships as a separate, prebuilt, `dlopen`'d library:

| Location | Workaround |
|---|---|
| `app/linux/CMakeLists.txt` | Re-bundles the `.so` by hand — upstream registers it under a variable name Flutter never reads |
| `scripts/test.sh` | Points `LD_LIBRARY_PATH` at the pub cache so `flutter test` can find it |
| `app_dist/ci/build-linux.sh` | A "safety net" copy of the same file |

All three are deleted by this work.

---

## 2. Two decisions

### 2.1 Static linking, not a separate shared library

**This is the decision that matters most, and it is independent of ARM.**

Every problem in the table above traces to one root cause: quickjs arrives as
a *separate dynamic library*, `dlopen`'d at runtime. That is what produces
the load-path hacks, the bundling quirks, the silent arch mismatch, and the
"is it even in the build?" failure mode.

We instead compile quickjs into a **static** library and link it into our own
plugin's shared library — the one Flutter already builds, bundles, and signs
per platform. There is then no separate binary to locate, ship, sign, or get
out of sync. The arch question disappears too: the plugin is compiled by the
platform toolchain for whatever it targets, so ARM64 is correct by
construction rather than by someone remembering to publish an artifact.

### 2.2 Compile from source; do not ship our own prebuilts

The obvious objection is build time. Measured, on an 18-core Apple Silicon
machine, `-O2`, all five core translation units (`quickjs.c`, `libregexp.c`,
`libunicode.c`, `cutils.c`, `dtoa.c` — ~70k lines):

```
4.6s wall / ~5.0s CPU
```

Even several times slower on a modest CI x86 builder, that is 10–15 seconds
against Flutter builds already measured in minutes — well under 1% and not
worth engineering around. CMake and Xcode cache object files, so incremental
and local builds recompile it only when the pinned version changes.

Shipping our own prebuilts was considered and rejected: it **recreates the
exact failure mode we are escaping.** `flutter_js` did not fail because
prebuilts are inherently wrong; it failed because prebuilts for one
architecture, from a maintainer who moved on, leave downstream with no
recourse. Owning them means owning an 8–10 target matrix (linux x64/arm64,
win x64, android arm64/armv7/x86_64, macos universal, ios arm64) plus
hosting, checksums, and version pinning — permanently — and adds a genuinely
new problem: a downloaded `.dylib` must be signed and notarized as part of
the macOS app, which a compiled-in static library sidesteps entirely. We
would be buying ~10 seconds a build with a standing maintenance obligation
and a fresh way to ship the wrong architecture.

If CI minutes ever justify it, the right lever is **build caching** keyed on
quickjs version + platform + arch — speed without a distribution pipeline.

---

## 3. Shape of the change

The `EngineRuntime` interface
(`packages/halo_extension_host/lib/src/engine_runtime.dart`) is deliberately
small and **does not change**: `onMessage`, `onFatalError`, `load`, `invoke`,
`invokeAll`, `hostResponse`, `invalidateContext`, `pump`, `dispose`. Web
already has its own Worker-backed implementation and is untouched. This work
replaces exactly one file's implementation — `engine_runtime_io.dart` — plus
the native package behind it.

```
packages/halo_quickjs/            # new federated plugin
  src/quickjs-ng/                 # vendored upstream source, pinned by tag
  src/halo_qjs_shim.{c,h}         # flat C API over QuickJS (see §4.1)
  lib/halo_quickjs.dart           # dart:ffi bindings
  linux/CMakeLists.txt            # ─┐
  windows/CMakeLists.txt          #  ├ each compiles shim + quickjs statically
  android/build.gradle (CMake)    #  │ into the plugin library
  macos/halo_quickjs.podspec      #  │
  ios/halo_quickjs.podspec        # ─┘
```

The engine also stops differing by platform. Today native splits
QuickJS (Android/Windows/Linux) vs JavaScriptCore (macOS/iOS), so resource
limits and failure modes differ per platform — #349 crashed only where
QuickJS ran. Unifying every native platform on QuickJS-NG is what makes
"control over interrupts and memory limits" true *everywhere*, as §3 intends.

### Capabilities this unlocks

- `JS_SetMemoryLimit` on **every** platform, not just Android.
- `JS_SetInterruptHandler` — a real per-call deadline. Today a runaway hook
  is only `abandon`ed Dart-side while the engine keeps spinning; an
  interrupt handler stops it.
- A stack guard we can set coherently against the actual isolate thread
  stack, instead of the per-platform constants #349 had to hand-tune.

---

## 4. Open questions the spike had to settle

These were genuinely unresolved when the plan was written. §4b records what
the spike actually found — including where these assumptions were WRONG. They
were
assumptions to *validate*, not conclusions.

### 4.1 Does the C shim need to hide `JSValue`?

QuickJS returns `JSValue` **by value** from most API calls. It is a 16-byte
`{ JSValueUnion u; int64_t tag; }` in the default build (or a `uint64_t`
under NaN-boxing). `dart:ffi` supports structs by value, but small-struct
return ABI is exactly where platform calling conventions differ most, across
five platforms and two architectures each. Existing bindings (`flutter_qjs`,
`quickjs-dart`, and the abandoned `quickjs-c-bridge`) all interpose a
C/C++ wrapper rather than exposing raw `JSValue` — that is a strong signal.

**Working assumption:** expose a flat, pointer/int-based C API from
`halo_qjs_shim.c` and never pass `JSValue` across the FFI boundary. Confirm
in the spike.

### 4.2 JS → Dart calls

The host channel (`__polo` messages, `hostCall`) needs JS to invoke Dart
**synchronously on the calling thread**. The candidate is
`NativeCallable.isolateLocal`, which is same-thread and synchronous, as
opposed to `NativeCallable.listener`, which queues asynchronously. Needs
confirming against the FFI docs and a real round-trip, including what
happens on the isolate the extension host actually runs on.

### 4.3 `flutter test` has no plugin library

`flutter test` runs in the host VM and never performs the platform native
build, which is precisely why `scripts/test.sh` needs today's
`LD_LIBRARY_PATH` hack. Our 1168-line integration suite
(`packages/halo_extension_host/test/extension_host_test.dart`) runs against
the **real** engine in-process, so it needs a host-native library to load.

Planned answer: a small `scripts/build-quickjs-host.sh` producing one
host-arch library into `build/`, cached, with the binding's library-open
logic preferring it under test. Same shape as the workaround it replaces,
but ours and arch-independent.

### 4.4 QuickJS-NG vs Bellard API drift

QuickJS-NG has made deliberate breaking changes to the classic Bellard API.
The exact signatures we depend on (`JS_ExecutePendingJob`, `JS_SetMemoryLimit`,
`JS_SetInterruptHandler`, `JS_Eval`, `JS_Call`, JSON helpers) must be read
from the pinned version's own `quickjs.h`, not from Bellard-era examples or
from what `flutter_js` assumed.

---

## 4b. Phase 0 spike results

Run against quickjs-ng **v0.15.1** on macOS arm64, statically linked, with a
throwaway C harness and a throwaway Dart FFI harness. Every assertion below
was executed, not reasoned about.

**§4.1 — the C shim is required, and not for the reason we assumed.** The
struct-by-value question turned out to be secondary. The decisive fact is
that `JSValue`'s *representation changes by architecture inside our own
target matrix*: `quickjs.h` auto-enables `JS_NAN_BOXING` when
`INTPTR_MAX < INT64_MAX`, making `JSValue` a `uint64_t` on 32-bit targets
(Android armeabi-v7a) and a 16-byte `{JSValueUnion u; int64_t tag;}` struct
on every 64-bit one. Dart FFI bindings are resolved at compile time, so a
by-value `JSValue` would need two incompatible Dart definitions in one
binary. Two independent confirmations: `JS_NewCFunction` and
`JS_ToCStringLen` are `static inline` in the header and are not exported
symbols at all, so they are unreachable from FFI regardless. **No QuickJS
type crosses the boundary; the shim is string-in/string-out.**

**§4.2 — `NativeCallable.isolateLocal` works, including re-entrantly.**
Proven: it runs synchronously inside the C call, JS observes its effects
within the same `eval`, it survives being called repeatedly in one eval, and
it works on a background isolate (the real deployment shape).

**The protocol in the original plan was wrong.** The spike initially guessed
a one-argument, string-returning global. The kernel's actual contract
(`extensions/sdk/src/kernel.ts:55`) is:

```ts
declare function sendMessage(channel: string, message: string): void
```

Two arguments, **void return** — the kernel discards any value. And
`kernel.ts:70` does `delete globalThis.sendMessage` as its containment
boundary, so the property **must be configurable** or the kernel silently
degrades to a throwing shadow. `JS_SetPropertyStr`'s default flags satisfy
this; verified by deleting it from JS.

**Re-entrancy is mandatory, not incidental.** `halo_extension_host.dart`'s
`kvGet`/`kvSet` cases reach `_js.hostResponse(...)` with **no `await`** in
between, so the enclosing `async` function runs straight through and
re-enters `JS_Eval` *from inside* the `sendMessage` callback. Verified to
three levels of nesting, with the engine healthy afterwards, both on the
main isolate and a background one. The shim therefore keeps no per-call
scratch state.

**Stack re-anchoring must be depth-gated — and this is #349's family.** A
Dart isolate is not pinned to one OS thread, so QuickJS's recorded
`stack_top` can belong to a thread we have since migrated off; it must be
re-anchored with `JS_UpdateStackTop`. But re-anchoring a *nested* entry
would move `stack_top` down to the already-deep stack pointer and hand the
nested frame a full fresh budget measured from there — overflowing the real
OS stack, exactly the failure mode #349 hit. The shim re-anchors only on the
0→1 depth transition.

**The interrupt guarantee was broken, and took three attempts to fix.** This
is the most important thing the spike produced, and it only surfaced under
adversarial review.

*Symptom.* A runaway hook that calls `sendMessage` was never interrupted:
**2201ms against a 200ms budget**, i.e. defeated in precisely the scenario
the interrupt exists for.

*First diagnosis — wrong.* The deadline was refreshed on every
`halo_qjs_eval` entry, so nested calls appeared to push it out. Depth-gating
the refresh made one run report 204ms and it was recorded here as fixed. It
was not: run 50 times it failed 12 times, and raising only the *harness's*
own nesting bound from 2s to 10s moved the measurement to 10001ms — proof
the shim imposed no ceiling at all and the harness had been supplying it.

*Actual mechanism.* QuickJS raises the interrupt as a JS exception. When it
lands inside a **nested** eval, `halo_format_exception`'s `JS_GetException`
**clears** it; the nested call returns, the host discards the result, and
the outer loop resumes. Because nearly every operation the outer loop
performs happens inside that callback, the interrupt was consumed by the
nested call on essentially every iteration, forever. Depth-gating the
deadline never touched this — the deadline had already passed.

*Fix, in two parts.* The interrupt is now **latched** on the handle (set
when the deadline fires, cleared only on the outermost entry), and the
send trampoline **re-raises** it after the host returns, so the outer script
unwinds instead of resuming. With both: 50/50 runs pass, and the ceiling now
comes from the shim — 202ms even when the harness is told to nest for 10s.

*Two lessons for Phase 1.* First, **anything on the runtime struct is shared
with nested calls** — deadline, stack anchor and now the interrupt latch all
needed depth-awareness; every future field needs that question asked.
Second, **an error path that consumes an exception can swallow a control
signal.** Any future `JS_GetException` in a nested context needs the same
scrutiny.

**The stack re-anchor gate had no coverage at all.** Review showed the
`JS_UpdateStackTop` depth gate — §4b's "#349's family" — could be deleted or
hoisted out of the gate with every assertion still green. `stack_test.c`
now covers it, and deliberately *not* by provoking a segfault (fragile and
platform-dependent): it measures how deep the nested eval can recurse.
A correctly gated anchor makes the nested call inherit the outer's partly
spent budget (measured depth 2225); an ungated one hands it a fresh budget
(4295). The ~2× gap is deterministic, and the test is verified to fail
against a mutant with the gate removed.

**Two behaviours the binding must design around, both found by running it:**

1. **A Dart exception inside the callback is silently swallowed** — the
   callback returns null and JS sees `undefined`, with no error surfaced
   anywhere. Host-side failures must be encoded in the reply payload; they
   can never be signalled by throwing.
2. **An unclosed `NativeCallable` keeps its isolate alive forever.** The
   first harness leaked one and the process would not exit even after all
   assertions passed. `dispose()` must close every callable it ever created,
   or the extension-host isolate will not shut down.

**Sizes and build cost:** 1.1 MB static / 964 KB shared for the whole
engine, from four translation units (`quickjs.c`, `libregexp.c`,
`libunicode.c`, `dtoa.c`), built in 4.6s wall / ~5s CPU at `-O2`.

**§4.3 (host test library) and §4.4 (API drift) remain open** — the spike
loaded a hand-built dylib by absolute path, which is not the answer for
`flutter test`, and it exercised only the API subset listed above.

## 5. Phasing

Each phase is independently reviewable; nothing ships half-migrated because
the engine swap (Phase 3) lands only once every platform builds.

| Phase | Scope | Done when |
|---|---|---|
| **0 — Spike** | Answer §4.1–4.4. Throwaway code, one platform (macOS or Linux host). | ABI, callback, and host-test approach are settled with evidence |
| **1 — Package** | `packages/halo_quickjs`: vendored source pinned, shim, FFI bindings, host build script. macOS + Linux. | Integration suite green against the new engine on both |
| **2 — Platforms** | Windows, Android, iOS build integration. | All five native platforms build and pass in CI |
| **3 — Swap** | `engine_runtime_io.dart` → new binding; drop `flutter_js`; delete the three workarounds; add interrupt handler + memory limit everywhere. | `flutter_js` gone from `pubspec.yaml`; full suite green |
| **4 — ARM64** | `linux-arm64` CI workflow, packaging, download page. | An ARM64 Linux build is published |

Phase 4 is the original goal but is deliberately last: it is packaging work
that only becomes possible once Phases 1–3 remove the x86-64-only blocker.

---

## 6. Risks

- **Native crashes are unforgiving.** A binding bug is a segfault, not an
  exception. Mitigation: the existing integration suite is a real harness
  (it drives the actual kernel and extension bundles, not mocks), and the
  spike de-risks the ABI questions before any production code is written.
- **Five platforms, and CI is the only place some of them build.** Windows
  and Linux in particular are CI-only for this project. Phase 2 is
  deliberately its own phase for that reason; expect iteration against CI.
- **Not Shorebird-patchable.** Native code changes require a full binary
  release, not a Dart patch (docs/releases.md §4). The swap must land in a
  normal release cycle.
- **Vendored source needs a bump policy.** Pin quickjs-ng by tag, record the
  version, and treat bumps as deliberate changes — the point is that we can
  bump, unlike today.
- **Threading.** A QuickJS runtime is single-threaded and must be used from
  the thread that created it. The host already confines the engine to a
  dedicated isolate, which fits, but the spike must confirm FFI calls and
  the callback both stay on that thread.

---

## 7. Verification

- `packages/halo_extension_host/test/extension_host_test.dart` — the
  1168-line integration suite, run against the real engine, is the primary
  gate. It must pass unchanged: the interface is unchanged, so the tests
  should not need edits. **If they need edits, that is a signal the swap
  changed observable behavior** and deserves scrutiny.
- Per-platform smoke: first-run onboarding with a real callsign — the exact
  path that crashed in #349.
- New coverage for the capabilities the current engine cannot support:
  memory limit enforced, and an interrupt handler actually stopping a
  runaway hook.
