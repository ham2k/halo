# HaLo Next — Architecture & Design

*Ham2K Portable Logger, next generation: a Flutter core with TypeScript extensions.*

Status: **living document.** Steps 1–2 of the plan in §10 are complete
**except ADIF import, which has a parser but no user-facing path** (the
largest remaining parity gap — [docs/parity.md](docs/parity.md) §1); steps
3–5 are largely built; steps 6–7 remain. Open work is tracked in
[docs/backlog.md](docs/backlog.md) and [CaBo](https://cabo.ham2k.com/halo).
Last updated: 2026-08-05

---

## 1. Background and motivation

HaLo today ([app-polo](../app-polo)) is a React Native app built around a hook
registry: extensions register hooks by category (`activity`, `spots`, `lookup`,
`command`, `sync`, `export`, `scoring`, `confirmation`, `ref:<type>`, …), sorted
by priority and toggleable per user settings. Everything — POTA, SOTA, contests,
QRZ lookups, Discord spotting, even the LoFi sync transport — is an extension.
The data model is QSON: plain JSON QSOs and Operations with a generic `refs`
list, stored in SQLite as JSON blobs plus a few indexed columns, with
dirty-flag (`synced`) based sync and a `lookups` table for offline reference
datasets.

That extension model has proven itself across ~40 extensions and is worth
preserving. [web-lofi](../web-lofi) already started a second iteration: its
`src/extensions/@framework` folder contains typed TS hook contracts
(`ActivityHook`, `ReferenceHandlerHook`, `ExportHandlerHook`) — the embryo of a
formal extension SDK.

### What we keep

- The **hook registry** model: categories, priorities, per-user enablement,
  activate/deactivate lifecycle.
- **QSON** as the data model, and the `refs` system tying QSOs and Operations
  to activities and programs.
- The **SQLite schema shape**: JSON blob + indexed columns, `lookups` table for
  offline datasets, `synced`/`deleted` flags.
- The **sync design**: dirty flags, small-batch on change, large-batch on a
  loop, server-tunable knobs, pluggable transports
  (see `app-polo/src/store/sync/README.md`).

### Architectural debts we fix

1. **Hooks are entangled with Redux and React.** Half the hooks are thunks
   (`decorateRefWithDispatch`, `lookupCallWithDispatch`) reaching into RTK
   Query internals; the other half return React components (`InputComponent`,
   `Options`). The extension contract is implicitly "all of React Native plus
   the store" — which is exactly why the same extensions had to be rewritten
   for web-lofi.
2. **Everything is statically compiled in.** `loadExtensions.js` imports every
   extension; adding an activity program means shipping an app release.
3. **Untyped contracts.** Hook shapes are documented by convention and
   duck-typing.
4. Migrations, sync policy, and scoring logic live in ad-hoc places.

The key observation that makes this project feasible: **almost all hook logic
is JSON in / JSON out** (QSON QSOs, refs, spots, ADIF field lists, score
objects). That is precisely the shape of API that survives a language
boundary. The only hooks that don't cross cleanly are the UI ones — solved in
§5 with declarative UI contributions.

---

## 2. The core split

```
┌────────────────────────────────────────────────────────────┐
│ Flutter / Dart  — "the machine"                            │
│  • UI shell, navigation, adaptive layout, multi-window     │
│  • Widget catalog (logging panel, QSO list, map, spots…)   │
│  • SQLite storage (drift), reactive queries                │
│  • Sync engine (dirty-flag loop, batching — policy only)   │
│  • Settings, i18n, theming, platform services (GPS, files) │
│  • Extension host: JS runtime + bridge + capabilities     │
├────────────────────────────────────────────────────────────┤
│ TypeScript extension runtime — "the knowledge"            │
│  • QuickJS engine on a background isolate                  │
│  • @ham2k/halo-extension-sdk (typed hook contracts, host API)        │
│  • Extensions: activities, contests, lookups, spots,      │
│    exporters, scoring, sync transports, commands           │
│  • Reuses existing @ham2k JS libs (callsigns, country      │
│    files, qson-adif, qson-cabrillo…) unchanged             │
└────────────────────────────────────────────────────────────┘
```

**Guiding rule: Dart owns pixels, storage, and time; TypeScript owns domain
knowledge.** The core knows nothing about POTA, QRZ, or Cabrillo. It knows
about operations, QSOs, refs, spots, scores, and export files as
opaque-but-schema'd JSON — the same philosophy as today, but with the boundary
made physical instead of conventional.

A major practical win of keeping extensions in TS rather than porting them to
Dart: `@ham2k/lib-callsigns`, `lib-country-files`, `lib-qson-adif`,
`lib-qson-cabrillo`, `lib-operation-data`, etc. (the `ham-js-libs` repo) run
as-is inside the extension runtime. That is years of accumulated edge-case
knowledge we do not re-port. Only hot-path utilities the UI needs at 60fps
(frequency/time formatting, band-for-frequency) get small Dart ports.

---

## 3. Extension runtime and bridge

### Engine

- **QuickJS (QuickJS-NG) via dart:ffi.** We bind to QuickJS directly, in
  `packages/halo_quickjs`, for control over interrupts, memory limits, and
  module loading. QuickJS is ~700KB, runs on iOS / Android / macOS / Windows /
  Linux, and is more than adequate for this workload: hooks fire on human
  timescales (keystrokes, spot refreshes), never per-frame. Web runs on the
  browser's own engine. [js-engine.md](docs/design/js-engine.md) covers the
  binding and the constraints it enforces.
- The engine runs on a **dedicated background isolate**. The UI never blocks
  on an extension; every hook call is async by construction.
- The engine choice is hidden behind the bridge interface. If QuickJS ever
  becomes the bottleneck, Hermes or JavaScriptCore can be swapped in — the
  protocol, not the engine, is the contract.

### Protocol

JSON message passing; essentially JSON-RPC with cancellation and timeouts.

**Dart → JS:** `invokeHook(category, key, method, argsJson)` with a per-call
budget (e.g. 2s for lookups, 250ms for command matching). A misbehaving extension
degrades — it never hangs the app.

**JS → Dart (host API):** a capability-scoped surface, wrapped by the SDK in
typed functions:

| API | Purpose |
|---|---|
| `host.fetch()` | HTTP, restricted to per-extension domain allowlists from the manifest |
| `host.lookups` | Shared reference dataset store (today's `lookups` table + `dataFiles` machinery, unified). The **core** handles download / cache / refresh scheduling of large files; the extension supplies the URL and a streaming transform to records. |
| `host.kv` | Per-extension namespaced settings and state |
| `host.qsos` / `host.operations` | Read queries (scoring, dupe checking) served by the core's indexed SQLite — the log never ships wholesale across the bridge |
| `host.events` | Subscriptions: `qsoAdded`, `operationChanged`, `online`/`offline`, `tick` |
| `host.secrets` | Credential storage in the platform keychain (QRZ passwords no longer live in settings JSON) |

### Packaging and distribution

Each extension is a **manifest + an ESBuild-bundled ESM file**. Two channels:

1. Baked into app assets (the default set).
2. Downloaded / updated from a Ham2K extension registry at runtime — new activity
   programs, new QSO parties, contest rule fixes **without an app-store
   release**.

The manifest declares capabilities (`network: [pota.app]`,
`hooks: [activity, spots, ref:potaActivation]`), which doubles as a review and
consent story for third-party extensions later. Extension bundles are lazy-loaded on
first activation to protect app startup time.

---

## 4. Hook taxonomy

Carried over from app-polo, tightened, and formalized as TS interfaces in the
SDK (grown from web-lofi's `@framework/types`):

| Hook | Role | Change vs today |
|---|---|---|
| `activity` | logging controls, options, self/other-spotting | UI becomes declarative (§5) |
| `ref:<type>` | decorate / validate / suggest refs, ADIF fields, titles | pure JSON already — ports as-is |
| `lookup` | callsign lookups (QRZ, HamDB, HamQTH) | loses Redux; becomes `lookup(callInfo, ctx) → record`; core owns the merge/cache pipeline |
| `spots` | fetch and enrich spot sources | pure JSON already |
| `command` | text shortcuts in the call field | `match` regex + `describe`/`invoke`; commands mutate via a whitelisted field-change operation, not arbitrary state |
| `scoring` | per-QSO score, day accumulator, summarizer | runs batched in JS; results cached per-QSO in SQLite so list scroll never waits on JS |
| `export` | ADIF / Cabrillo / CSV generation | extension streams records; core writes the file and drives the share sheet |
| `syncTransport` | LoFi (or future) sync backends | core keeps the loop / batching / dirty flags in Dart — sync must work even if the JS runtime is wedged |
| `settingsPanel`, `accountConnection`, `confirmation` | forms via the declarative catalog | |

**One deliberate change:** hooks are pure functions of explicit context
(`settings`, `operation`, `online`, `t`) plus host-API calls. No dispatch, no
store access. This is the single biggest architectural improvement over
app-polo: it makes hooks testable with plain vitest and portable to any host
(including future web clients).

**Bridge APIs are coarse by design.** Score 500 QSOs in one call, not 500
calls. The current per-item hook signatures are not to be copied blindly.

---

## 5. Extension UI: declarative contributions

The one contract that cannot cross the boundary is
`InputComponent: <ReactComponent>`. But the components extensions actually
provide are small and regular: a text field with validation and chips, an
options form with a reference picker, a list row with icon and label. The
current API is already half-declarative (`inputWidthMultiplier`, `optionType`,
`order`, `icon`, `label`).

**The core ships a widget catalog; extensions describe UI as data and handle
events as logic.**

```ts
// TS side — POTA extension
loggingControls: ({ operation }) => [{
  key: 'pota/activator',
  order: 10, icon: 'pota', optionType: 'mandatory',
  label: ({ qso }) => refCount(qso) ? '✓ P2P' : 'POTA',
  input: {
    kind: 'refList',            // core-provided component
    refType: 'potaHunting',
    placeholder: 'US-1234',
    validate: 'onChange',       // core calls back into validateRef()
    suggest: 'onFocus',         // core calls back into suggestRefs()
  }
}]
```

A catalog of roughly a dozen components covers every extension in app-polo
today:

`textField` (masks / validation), `refList` (chips + lookup + nearby
suggestions), `select`, `toggle`, `segmented`, `infoRow`, `form` (Options
panels), `markdown` (program notes), `listSection`, `mapOverlay`,
`scoreSummary`.

Each component exposes *behavior slots* (validate, suggest, decorate, format)
that call back into the extension. This is server-driven-UI mechanics with a
fixed native catalog: fast, accessible, theme-consistent — and the same
declarative descriptions can render in a future web client, fixing the
app-polo / web-lofi duplication at the root.

**Escape hatches**, in order of preference:

1. Propose the missing component for the catalog. The catalog is versioned;
   extensions declare `minCatalog`.
2. A sandboxed webview surface for rare full-custom screens (stats dashboards,
   program-specific maps) — acceptable there because those are not
   latency-critical.

**The fast path never crosses the bridge.** Keystroke → text field → QSO list
update is pure Dart. Extensions get debounced, async involvement (lookup
enrichment, command matching, validation) — which matches how they behave
today anyway.

> Discipline note: extensions will always want "just one custom widget."
> Catalog additions are deliberate core PRs; keeping the catalog small and
> declarative is the point.

---

## 6. Data layer

Keep the schema shape — `app-polo`'s migration history shows it converged here
deliberately:

```
operations (uuid PK, data JSON, local_data JSON,
            start_at_millis_min, start_at_millis_max,
            qso_count, deleted, synced)

qsos       (uuid PK, operation, our_call, their_call,
            band, mode, start_at_millis, data JSON,
            deleted, synced, score_cache JSON)

lookups    (extension, category, key PK, name, lat, lon,
            data JSON, updated)          -- now extension-namespaced

extension_kv (extension, key, value JSON)
```

`sync_state` (last-synced timestamps, linked account uuid, server-tunable
batch sizes/delay) turned out to be a handful of scalars, not per-row data —
implemented as a JSON blob in `SettingsService` (SharedPreferences) instead
of a drift table, alongside `syncEnabled`/`syncDeviceKey`/`operatorCall`. See
`packages/halo_core/lib/src/sync/sync_engine.dart`'s `SyncSettings`
interface and `app/lib/main.dart`'s `_SettingsSyncAdapter`.

- **drift** for typed SQL, versioned migrations, and reactive streams; runs on
  all six platforms via `sqlite3` FFI (wasm on web later).
- Reactive queries feed the UI directly: the QSO list is a
  `Stream<List<QsoRow>>`. This is also the backbone of multi-window (§8).
- **Riverpod** for app state, kept thin — the database is the source of truth.
  (app-polo already moved this way; Redux there is mostly a cache over
  SQLite.)
- The **sync engine** is a Dart service implementing exactly the design in
  `app-polo/src/store/sync/README.md`: dirty flags, small-batch on change,
  large-batch on loop, server-tunable parameters. Only the transport call goes
  through an extension.

---

## 7. UI architecture: modules, not screens

The UI is composed of **modules**, each a widget taking an `OperationScope`
and subscribing to DB streams:

`LoggingPanel`, `QsoList`, `SpotsBoard`, `OpMap`, `ScoreSummary`,
`OpSettings`, `CallInfoCard`, …

- **Phone:** modules composed into the familiar tab layout
  (Logging / Spots / Map / Info / Settings).
- **Tablet / desktop single window:** a docking layout — logging panel pinned
  at the bottom, QSO list center, spots and call info in side panels.
  Contest-logger ergonomics (N1MM-style).
- **Keyboard support is a first-class core concern from day one:** tab order,
  Enter-to-log, ESC-to-wipe, function keys. This is the biggest UX payoff of
  going desktop and the hardest thing to retrofit. The logging fields' own
  focus and navigation contract is specified in
  [docs/design/logging-fields.md](docs/design/logging-fields.md).

The concrete size breakpoints, resizable splits, and modal-pane mechanics
are specified in [docs/design/layouts.md](docs/design/layouts.md).

---

## 8. Multi-window

Flutter's official multi-window support is still maturing (Windows first;
`desktop_multi_window` spawns a separate engine per window). Therefore:
**do not share in-memory state across windows.**

- Every window is a fresh engine that opens the same SQLite file and
  subscribes to the same reactive queries.
- A minimal cross-window notify channel signals "data changed, re-query."
  **SQLite is the multi-window bus.**
- The extension runtime runs only in the primary window's process; secondary
  windows are pure views, so extension state never forks.
- Desktop users can tear off any module (spots monitor on a second screen, map
  on another) into its own OS window.

This design costs nothing on mobile and does not bet on any particular
multi-window API. Tear-off windows stay **out of the v1 critical path**.

---

## 9. Repository layout

```
app-halo/
  app/                    # Flutter app (thin: wiring + distro config)
  packages/
    halo_core/            # Dart: models, db, sync engine, services
    halo_widgets/         # Dart: widget catalog + modules
    halo_extension_host/     # Dart: QuickJS binding, bridge, manifests
  extensions/                # TypeScript workspace
    sdk/                  # @ham2k/halo-extension-sdk — hook types + host API
    activities/           # pota, sota, wwff, ...
    contests/             # naqp, qp, cqwpx, ...
    lookups/              # qrz, hamdb, hamqth
    spots/
    sync/                 # ham2k-lofi
  tools/                  # extension bundler, manifest validator, dev server
  docs/
```

### Extension developer experience

- `polo extension dev`: a watcher that rebundles and hot-reloads an extension into a
  running app. The runtime re-evaluates the bundle and re-registers hooks —
  the activate/deactivate lifecycle already supports this.
- A headless test harness so extension authors run their hooks against fixture
  QSOs in vitest, with no Flutter involved.

---

## 10. Sequencing

1. **Spike the riskiest piece (2–3 weeks).** QuickJS on an isolate + bridge +
   the QRZ lookup extension + POTA spots extension against a stub UI. Measure:
   bridge latency, memory on a low-end Android device, cold-start cost of
   loading ~40 bundles.
2. **Core logging loop, no extensions.** Operations, QSO entry, QSO list, SQLite,
   ADIF import. Prove the keyboard/entry ergonomics on desktop and mobile.
3. **SDK v1 + three archetype extensions:** POTA (location activity, the
   richest), NAQP or a QSO party (contest with exchange + scoring), QRZ
   (lookup). These exercise every hook category; the remaining ~35 extensions
   are then mostly mechanical ports — and the TS-ification already underway in
   web-lofi's `@framework` feeds directly into the SDK.
4. **Sync** via the LoFi transport extension, validated against the existing
   server.
5. **Spots, map, scoring cache, export.**
6. **Desktop polish + multi-window tear-off.**
7. Long tail of extension ports; extension registry / OTA update channel.

---

## 11. Risks

| Risk | Mitigation |
|---|---|
| Bridge chattiness | Coarse batch APIs everywhere; per-call budgets; measure in the spike |
| QuickJS performance ceiling | Engine hidden behind the bridge interface; Hermes/JSC swappable |
| Catalog creep | Catalog additions are core PRs; versioned catalog; webview escape hatch for non-critical surfaces |
| Flutter multi-window immaturity | SQLite-as-bus design; tear-off windows out of v1 |
| JS runtime wedged / extension crash | Sync and logging fast path are pure Dart; timeouts degrade features, never the app |
| Startup cost of many extensions | Lazy-load bundles on first activation |

Larger known gaps in the implementation (incomplete features, unverified
platforms) are tracked in [docs/backlog.md](docs/backlog.md), not here.

---

## 12. Summary of improvements over the current architecture

- Typed, host-independent extension contracts.
- Extensions updatable without app releases.
- One extension codebase servable to Flutter **and** web clients.
- Sync that cannot be broken by an extension.
- Credentials in the platform keychain.
- A UI that scales from a phone tab bar to a multi-monitor contest station
  without forking the extension ecosystem.

---

*Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com> — MPL-2.0*
