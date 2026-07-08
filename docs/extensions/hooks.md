# Hook reference

Hooks are registered under a **category** with an optional **key** (defaults
to the extension key) and **priority** (higher runs first; default 0). The
host invokes them two ways:

- `invokeHook(category, key?, method, args)` — best (highest-priority) hook.
- `invokeHookAll(category, method, args)` — every hook in the category, one
  bridge round-trip, per-source error isolation.

All argument and result types below are defined in
[`extensions/sdk/src/types.ts`](../../extensions/sdk/src/types.ts). Every
hook method receives `(args, ctx)` where `ctx: HookContext` is:
* `online: boolean` — True if the device has an active network connection.
* `developerMode: boolean` — True if developer options are enabled in settings.
* `locale: string` — The active locale code of the application (e.g. `'en'`, `'es'`).

Status legend: ✅ implemented · 🔜 planned (design in DESIGN.md §4).

---

## ✅ `lookup` — callsign lookups

Data sources for callsign enrichment (QRZ, HamDB, HamQTH…). The core fans
out to **all** lookup hooks via `invokeHookAll` and merges results in
priority order — the first source to provide a field wins; `sources` records
attribution. Fired debounced from the logging panel, never per-keystroke.

```ts
interface LookupHook {
  lookupCall(args: { callInfo: CallInfo }, ctx): Promise<LookupRecord>
}
// CallInfo:     {call, baseCall?}
// LookupRecord: {source, call?, name?, city?, state?, country?, grid?,
//                lat?, lon?, image?, error?}
```

Return `{source, error}` for "can't answer" (not configured, not found) —
never throw for expected conditions. Implemented by: `hamdb`, `qrz`.

## ✅ `spots` — spot sources

```ts
interface SpotsHook {
  sourceName: string
  fetchSpots(args: {}, ctx): Promise<Spot[]>
}
// Spot: {their: {call}, freq?, band?, mode?, refs?: Ref[],
//        spot: {timeInMillis, source, label?, sourceInfo?}}
```

Map upstream spots into QSON-shaped spot objects; filter out QRT/stale
entries at the source. Implemented by: `pota`.

## ✅ `export` — log file generation

```ts
interface ExportHook {
  generateExport(args: ExportRequest, ctx): Promise<ExportResult>
}
// ExportRequest: {operation, qsos}   — full QSON, one coarse call
// ExportResult:  {filename, mimeType, content}
```

The core owns file I/O and save dialogs; the hook only produces content.
Exporters should compose per-QSO program fields from `adifFields` hooks (see
below) rather than knowing about specific activities. Implemented by: `adif`
(key `adif`); Cabrillo will register here too.

## ✅ `ref:<type>` — reference handlers

One category **per ref type** (e.g. `ref:pota`, `ref:potaActivation`),
following app-polo's QSON conventions. Handles validation and enrichment of
activity references on QSOs and operations.

```ts
interface RefHandlerHook {
  validateRef?(args: { ref: Ref }, ctx): Promise<{valid: boolean; normalized?: string}>
  decorateRef?(args: { ref: Ref }, ctx): Promise<Ref>   // may hit the network
}
// Ref: {type, ref?, name?, label?, shortLabel?, grid?, location?, program?, ...}
```

`decorateRef` fills names/locations/labels (park names via the POTA API,
etc.); results update ref chips asynchronously in the UI. Implemented by:
`pota` (both types).

## ✅ `activity` — declarative UI contributions

The UI-catalog seam (DESIGN.md §5): activities describe controls as data;
the core renders them with native widgets and calls back into ref handlers
for behavior.

```ts
interface ActivityHook {
  loggingControls?(args: { operation }, ctx): Promise<LoggingControlDescriptor[]>
  operationControls?(args: { operation }, ctx): Promise<LoggingControlDescriptor[]>
}
// LoggingControlDescriptor: {key, label, icon?, order?, optionType?, input}
// input (catalog v0): {kind: 'refList', refType, placeholder?, pattern?}
```

`icon` is a Material Design Icons name (e.g. `'pine-tree'`), or a FontAwesome6
solid-style name prefixed with `'fa-'` (e.g. `'fa-tree'`) — same convention
app-polo itself uses. Any name in either set works with no core-repo change;
an unrecognized name falls back to a placeholder glyph rather than erroring.

`loggingControls` appear on the logging panel (per-QSO refs);
`operationControls` appear in the operation's Activities dialog (e.g. "which
park am I activating"). Catalog components are versioned core code —
proposing a new `input.kind` is a core PR, deliberately (DESIGN.md §5's
"catalog creep" risk). Implemented by: `pota`.

## ✅ `adifFields` — per-QSO export field contributions

How activities inject program fields into ADIF exports without the exporter
knowing them. Called by the `adif` extension **inside the runtime** via
`hooks.invokeAll` — no bridge crossing.

```ts
interface AdifFieldsHook {
  fieldsForOneQSO(args: { qso, operation }, ctx): Promise<{name, value}[]>
}
```

POTA contributes `SIG/SIG_INFO/POTA_REF` (hunted refs on the QSO) and
`MY_SIG/MY_SIG_INFO/MY_POTA_REF` (activation refs on the operation).

## ✅ `command` — call-field text shortcuts

Space in the logging panel's call field tries the typed text as a command
before falling back to "advance focus." The core does no matching itself —
it fans out to **every** registered `command` hook via `invokeHookAll` and
applies the first non-null result, in priority order.

```ts
interface CommandResult {
  freq?: number
  band?: string
  mode?: string
}

interface CommandHook {
  tryCommand(args: { input: string }, ctx): Promise<CommandResult | null>
}
```

Each hook does its own regex matching internally and returns `null` for "not
mine" — the host never compiles extension-supplied regex source itself.
Results mutate only through the closed `CommandResult` field set (DESIGN.md
§4's "whitelisted field-change operations"), never arbitrary state.

Implemented by `radio-commands` (band/frequency/mode shortcuts — "20m ",
"14285 ", "14.285 ", "cw "), ported from app-polo's `RadioCommands`
extension. Notably, this replaced an earlier hand-rolled Dart regex for
frequency parsing that rejected valid MHz-style input ("14.285") because it
required 3+ digits before any decimal point; the extension delegates to
`@ham2k/lib-format-tools`' published `parseFreq` instead, which already
handles this correctly. Future command hooks (spotting, operator change…)
register in the same category and compete on priority with these.

## ✅ `scoring` — per-operation score batches

One hook call scores an entire operation's QSOs at once (DESIGN.md §4:
"score 500 QSOs in one call, not 500 calls"). Day-sectioning (24h UTC
buckets, following app-polo/web-lofi's convention) and accumulation both
happen inside the runtime — the host just supplies the operation and its
QSOs and gets back everything it needs to cache.

```ts
interface ScoringHook {
  scoreQsos(args: ScoreQsosRequest, ctx): Promise<ScoreQsosResult>
}
// ScoreQsosRequest: {operation, qsos}   — full QSON, one coarse call
// ScoreQsosResult:  {
//   qsoScores: Record<uuid, Record<ruleKey, QsoScoreVerdict>>,
//   daySections: {day, count, scores: Record<ruleKey, ScoreTally>}[],
//   operationSummary: Record<ruleKey, ScoreTally>,
// }
```

`Qsos.watchForOperation` already filters deleted rows and orders by
`startAtMillis`, so unlike web-lofi's `analyzeAndSectionQSOs` there's no
`deleted`/`event` row bookkeeping on this side of the bridge.
`ScoringService` (`app/lib/services/scoring_service.dart`) writes
`qsoScores` into each QSO's `score_cache` column (`QsosRepository.updateScoreCache`,
one batched transaction) and `daySections`/`operationSummary` into the
operation's `local_data` (`OperationsRepository.updateLocalData`) — never
synced content, so list scroll and score displays both read from SQLite and
never wait on the JS runtime. Triggered on operation open; per-edit debounced
rescoring is not wired up yet (DESIGN.md §11).

Implemented by: `scoring` (key `core`) — three rules so far: duplicate-contact
detection, DXCC entities worked (via `@ham2k/lib-country-files`'
`useBuiltinCountryFile`, no network needed), and bands/modes worked. US
States and Canadian Provinces rules are deferred (DESIGN.md §11).

## ✅ `bench` — kernel diagnostics

Registered by the kernel itself (`bench/kernel`): `echo` (bridge round-trip
measurement) and `spin` (JS compute). Used by the spike screen; not for
extensions.

---

## 🔜 Planned categories

| Category | Role | Notes |
|---|---|---|
| `syncTransport` | LoFi (and future) sync backends | The Dart core keeps the loop/batching/dirty flags; the hook only transports payloads. Sync must survive a wedged runtime. |
| `confirmation` | QSL/confirmation sources (spot-history cross-checking) | |
| `settingsPanel` | extension settings forms via the declarative catalog | Needed for QRZ credentials. |
| `account` | account connections (QRZ, LoFi) | |
| `opSetting` | per-operation settings contributions | |

When one of these lands, move it above the line with its real signature.
