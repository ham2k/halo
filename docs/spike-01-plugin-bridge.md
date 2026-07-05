# Spike 01 — JS plugin runtime bridge

This is step 1 of the sequencing plan in [DESIGN.md](../DESIGN.md) §10: prove
the riskiest joint of the architecture — TypeScript plugins running in an
embedded JS engine, bridged to a Flutter host — and measure it.

## What's here

- **`plugins/`** — TypeScript workspace:
  - `sdk/` — `@ham2k/polo-sdk`: typed hook contracts (`types.ts`), the runtime
    **kernel** (`kernel.ts`, evaluated first, owns the hook registry and the
    host-call bridge as a singleton on `globalThis.__polo`), and the thin
    plugin-facing wrappers (`index.ts`).
  - `lookups/hamdb/` — no-auth callsign lookup plugin (simplest possible hook).
  - `lookups/qrz/` — QRZ XML API plugin: credentials from host KV, session key
    kept across calls, re-login on expiry.
  - `spots/pota/` — POTA spots source. Imports `@ham2k/lib-operation-data`
    from npm — the same package app-polo uses — to prove existing ham-js-libs
    run unchanged in the plugin runtime.
  - `build.mjs` — esbuild bundling to `app/assets/plugins/` + `index.json`.
- **`packages/polo_plugin_host/`** — Dart package. `PluginHost` spawns a
  background isolate that owns the JS engine (via `flutter_js`), evaluates
  kernel + plugin bundles, and exposes `invokeHook(category, key, method,
  args)` with per-call timeouts. Falls back to in-process mode if the engine
  can't start in an isolate. Host calls served to JS: `fetch` (https only),
  `kvGet`/`kvSet`. Collects per-call latency samples.
- **`app/`** — stub Flutter UI: boots the host, runs a self-test on launch
  (bridge echo benchmark ×100, HamDB lookup of W1AW, POTA spots fetch), and
  has interactive controls for lookups (HamDB/QRZ), spots, benchmarks, and a
  stats table.

## Running it

```sh
cd plugins && npm install && npm run build   # bundles → app/assets/plugins/
cd ../app && flutter run -d macos            # (flutter provided via mise)
```

The self-test result is printed to the console between
`=== SPIKE SELF-TEST ===` markers and shown in the UI.

## What the spike is measuring

1. **Bridge round-trip latency** — `bench/kernel#echo` ×100, p50/p95/max.
   Budget from DESIGN.md: hooks fire on human timescales; anything under a few
   ms round-trip is a non-issue.
2. **Cold-start cost** — kernel + 3 bundles evaluated at boot (`loadMillis`).
   Extrapolate to ~40 plugins; decide how aggressive lazy loading must be.
3. **Isolate viability** — does the JS engine run on a background isolate on
   each platform, or does the in-process fallback trigger?
4. **Real-plugin viability** — session state across calls (QRZ), npm library
   reuse (POTA + `@ham2k/lib-operation-data`), error propagation and timeouts.

## Findings

| Platform | Engine | Isolate? | Load ms (kernel+3) | Echo p50 / p95 | Notes |
|---|---|---|---|---|---|
| macOS (arm64, debug) | JavaScriptCore | yes | ~30ms (~270ms total boot) | 0.16ms / ~2–3ms | 2026-07-05, M-series. Full self-test green: HamDB lookup, POTA spots (65, bands computed by `@ham2k/lib-operation-data`), QRZ session flow wired. |
| Android 12 (arm64 emulator, debug) | QuickJS (`QuickJsRuntime2`) | yes | ~60ms (~690ms total boot) | 0.49ms / ~7ms | 2026-07-05. Full self-test green. This is the design's target engine. Emulator on M-series ≈ mid-range device; re-measure on real low-end hardware before calling perf final. |
| iOS | | | | | not yet run |

Verdict so far: **the architecture's riskiest joint holds.** Sub-millisecond
median bridge round-trips (budget was "a few ms"), trivial bundle load cost
(~10ms/bundle → even 40 eagerly-loaded plugins would be acceptable, and lazy
loading remains planned), JS engine runs fine on a background isolate, and an
unmodified npm ham-js-lib executed correctly inside the runtime.

Things learned the hard way (already reflected in the code):

- macOS needs the `com.apple.security.network.client` entitlement for
  outgoing plugin fetches; the Flutter template doesn't include it.
- `definePlugin` activates synchronously, so hooks must be declared before
  the `definePlugin(...)` call in plugin source — esbuild's IIFE output
  hoists later declarations as `undefined` instead of failing fast. The
  kernel now throws a descriptive error on `registerHook` with a missing
  hook. The real SDK should switch to lazy activation (export a definition,
  kernel calls `onActivation` after the whole bundle is evaluated) to remove
  the footgun entirely.
- JavaScriptCore `Error.stack` omits the message; the kernel reports
  `message + stack` explicitly.
- flutter_js's Android module compiles Kotlin at JVM target 1.8 vs Java 11,
  which current Gradle rejects; worked around with
  `kotlin.jvm.target.validation.mode=warning` in `gradle.properties`. One
  more nudge toward binding QuickJS-NG ourselves instead of depending on
  flutter_js maintenance.

## Known spike shortcuts (not the real design)

- KV store is a single flat namespace in memory; real design is per-plugin
  namespaces with credentials in the platform keychain.
- Promise pumping uses a 5ms periodic timer; real design pumps only while
  calls are outstanding.
- No capability enforcement beyond https-only fetch; real design enforces
  per-plugin domain allowlists from the manifest.
- Hook context is a stub (`{online: true}`).
- `flutter_js` picks the engine per platform (QuickJS on Android/desktop,
  JavaScriptCore on iOS/macOS); the real design binds QuickJS-NG directly for
  interrupt/memory control and a single engine everywhere.
