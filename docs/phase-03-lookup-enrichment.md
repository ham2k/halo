# Phase 3 — Lookup enrichment: extensions join the logging loop

Spike 01 proved the bridge in isolation; phase 2 proved the logging loop in
isolation. This phase joins them at the architecture's most sensitive seam: a
extension participating in the hot logging path without ever degrading it.

## What's here

### SDK hardening (lessons from spike 01, done in context)

- **Lazy activation.** `defineExtension` now only registers the definition; the
  Dart host calls `__polo.activateAll()` after every bundle is evaluated.
  The declaration-order footgun (esbuild IIFE var-hoisting) is gone.
- **Per-extension KV namespaces.** Each extension bundle carries its own copy of
  the SDK module, so the SDK captures the extension key in module scope at
  `defineExtension` time and namespaces every `host.kvGet/kvSet` with it —
  extensions never pass their own identity around.
- **`invokeHookAll`.** Kernel-side fan-out: one bridge round-trip invokes a
  method on every hook in a category (priority order) and returns
  `{key, ok, value|error}` per source. A failing source is isolated, never
  poisoning the rest — and this is the coarse-batch shape DESIGN.md §4
  demands (one call, not N).
- **Pump-on-demand.** The JS job queue is pumped only while hook calls are
  outstanding, replacing the spike's permanent 5ms timer.
- **Integration test** (`polo_extension_host/test/extension_host_test.dart`):
  boots the real engine in-process against the built kernel bundle plus an
  inline test extension; covers activation, invoke, invokeAll error isolation,
  KV namespacing, and unknown-hook errors.

### App integration

- **`ExtensionService`** (app): owns the app's single `ExtensionHost` (background
  isolate), boots fire-and-forget at startup — the core loop never waits on
  the extension runtime. `lookupCall()` fans out to all lookup sources via
  `invokeHookAll` and merges results in priority order (first source to
  provide a field wins), collecting attribution in `sources`.
- **`LoggingPanel.lookup`**: optional async enrichment callback. Debounced
  300ms behind the keystroke, stale-result guarded, rendered as an
  enrichment line (name • city, state • country • grid) above the call
  field. On log, the enrichment folds into the QSO's `their` map — same
  shape app-polo uses. Esc/log wipes it.
- **`QsoList`** shows the logged name dimmed after the callsign.

## The contract this phase establishes

The keystroke path stays pure Dart. Extensions get involved only debounced and
async, their failures degrade to "no enrichment," and their results are
folded into QSON only at log time. This is the template for every future
extension touchpoint in the logging flow (activity controls, command matching,
validation).

## Still deferred

- QRZ credentials UI + keychain persistence (QRZ source works once
  credentials exist in its KV namespace; HamDB needs none).
- Lookup caching (app-polo caches in the `lookups` table).
- ADIF import/export (next up).
- Fetch domain allowlists from extension manifests.
