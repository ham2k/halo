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

Data sources for callsign/QSO enrichment (QRZ, HamDB, POTA, SOTA…). Never
called directly from Dart — the `lookupService/core` hook below fans out to
every registered `lookup` hook **sequentially, in priority order**, folding
each result into the next hook's input, and applies the locationScope-aware
merge rules (see below). Fired debounced from the logging panel, never
per-keystroke.

```ts
interface LookupHook {
  lookupCall(args: { callInfo: AnnotatedCallInfo; qso; operation }, ctx): Promise<LookupResult>
}
// AnnotatedCallInfo: CallInfo & {guess?: CallInfo, lookups?: CallInfoLookup[]}
// LookupResult:      CallInfoLookup[] — zero or more records; [] to skip
// CallInfoLookup:    CallInfo & {source?, scope?: 'general'|'operation'|'qso', notes?, history?}
```

Return `[]` for "can't answer" (not configured, not found, or `!ctx.online`
and this source has no offline data) — never throw for expected conditions.
`callInfo`/`qso`/`operation` are the full QSON-shaped objects (all from
`@ham2k/lib-qson-tools`'s `CallInfo`/`QSON` types), so e.g. a POTA lookup can
inspect `qso.refs` for a hunted park reference. Implemented by: `hamdb`,
`qrz` (`scope: 'general'`), `pota`, `sota` (`scope: 'qso'`, grid of any
hunted ref on the current QSO).

## ✅ `lookupService` — the lookup orchestrator

One hook call resolves an entire callsign decoration pass: the hardcoded
callsign-annotation pre-step (via `@ham2k/lib-country-files`, always first,
regardless of any other hook's priority) plus every registered `lookup` hook
above, merged according to the `locationScope` rules — all inside the
runtime, mirroring `scoring`'s "one coarse call in, everything back out"
shape.

```ts
interface LookupServiceHook {
  lookupCallInfo(args: { callInfo: CallInfo; qso; operation }, ctx): Promise<{ lookups: CallInfoLookup[]; guess: CallInfo }>
}
```

**locationScope merge rules** (`CallInfo.locationScope`, ranked
`qth < prefixed < portable`, most general to most specific):
- A result whose `locationScope` is strictly more specific than the current
  guess's clears all location fields (`locSource, lat, lon, grid, city,
  state, county, country`) before merging the result in, and the guess
  adopts the more specific scope.
- Otherwise, priority order applies as usual: a field already present in the
  guess is never overwritten by a later (lower-priority) result. A
  location field additionally requires the result's own scope to be at
  least as specific as the guess's current scope — a more general-scoped
  result can never populate a slot a more specific one already claimed,
  even if that slot is currently empty.
- Grid/lat-lon reconciliation, scoped to fields the result actually set:
  grid-only → lat/lon computed from the grid; lat/lon-only → a 6-digit grid
  computed from them; both given → taken verbatim. Setting grid/lat/lon
  clears city/state/country/county unless the *same* result also supplies
  them; conversely, setting city/state/country (without county, and without
  also setting grid/lat/lon in the same result) clears grid/lat/lon.
- `notes`/`history` are per-`CallInfoLookup` fields, not part of the merged
  `guess` — they simply accumulate, unconditionally, in the returned
  `lookups[]` array.

Implemented by: `lookups` (key `core`). The merge algorithm itself
(`mergeLookupIntoGuess`/`runLookupPipeline` in
`extensions/core/lookups/src/mergeLookup.ts`) is a pure, host-independent
function with its own unit test suite
(`extensions/core/lookups/src/mergeLookup.test.ts`, run via `npm test` in
`extensions/`) — this is the highest-defect-risk logic in the feature, so it
is tested in isolation from the hook/bridge plumbing.

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
  suggest?(args: SuggestArgs, ctx): Promise<ActivitySuggestion[]>
}
// LoggingControlDescriptor: {key, label, icon?, order?, optionType?, input}
// input (catalog v0): {kind: 'refList', refType, placeholder?, pattern?}
// SuggestArgs: {operation, location?: {lat, lon}, callsign?, searchTerm?}
// ActivitySuggestion: Ref & {distance?, relevance?}
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

`suggest` powers the Activities view's "add activity" search: called with a
`location`/`callsign` the core resolves from the operation if set, else the
station defaults (extensions never need to know which). Called with no
`searchTerm` for nearby suggestions, or with one for name/code search — an
extension may honor either, both, or neither (returning `[]`). The core fans
out to every `activity` hook via `invokeHookAll`, merges results, and sorts
by `distance * relevance` ascending (missing `distance` treated as
unsorted/unknown, sorted after ranked ones). Implemented by: `pota`, `sota`.

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
handles this correctly. Also implemented by `dev-commands` (DEVMODE toggles
developer mode; DEVNOTICE/DEVSTATUS/DEVPROGRESS post sample items to the
status bar via the `devNotice`/`devStatus`/`devProgress` action fields, for
exercising that UI without a real extension driving it; RELOAD forces a
`dataFile` re-sync via the `reloadDataFiles` action field — "RELOAD POTA"/
"RELOAD SOTA" target one activity's data file(s) by category, "RELOAD ALL",
"RELOADALL", or bare "RELOAD!" target every data file, and it bypasses ETag caching
since a manual reload is usually about our own `csvToLookupEntry` mapping
changing, not the source data) and `note-command` (NOTE <text> sets the
in-progress QSO's notes field via `updateQso`). Future command hooks
(spotting, operator change…) register in the same category and compete on
priority with these.

A command that recognizes its own prefix but needs more typed input before
it can run (e.g. bare "RELOAD", before its target word) returns
`{ expectsParams: true }` instead of `null` or a full result. That switches
the call field to normal free-text entry — spaces and lowercase allowed,
platform-normal capitalization — instead of the uppercase-only callsign
restriction, and space no longer advances focus to the next field while it's
set; the interpretation is never executed even if Enter is pressed while it
still just says `expectsParams`.

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
| `settingsPanel` | extension settings forms via the declarative catalog | Schema defined in [settings.md](./settings.md); complementary to `account` below, not a replacement — Dart-side rendering/dispatch not wired up yet. |
| `account` | account connections (QRZ, LoFi) | Implemented today (`ExtensionService.getAccounts`/`testCredentials`, `SettingsView`'s Accounts panel); table placement is stale, not a `settingsPanel` migration target. |
| `opSetting` | per-operation settings contributions | |

When one of these lands, move it above the line with its real signature.
