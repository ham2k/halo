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
* `appName?: string` — Platform-appropriate app name ("Ham2K Logger" on
  desktop, "Ham2K Portable Logger" on mobile) — use this instead of a
  hardcoded name when identifying the app to an external service or file
  (e.g. a spot's `source` field, an ADIF `PROGRAMID` header).
* `getOperation?(uuid)` / `getQsos?(operationUuid)` — log-data reads, for
  hooks that only receive part of the picture as arguments (e.g. a `command`
  hook handed the operation it's typed into, needing the existing QSOs —
  dev-commands' SEED). `getOperation` resolves the operation's QSON with
  `uuid` folded in (null for an unknown uuid); `getQsos` resolves every QSO's
  raw QSON, oldest first, excluding soft-deleted records but *including*
  event markers (`band: 'event'`) — or null when the operation is unknown or
  the host has no log access, distinct from `[]` (the operation exists and
  simply has no QSOs yet). Each call is a bridge round-trip carrying a whole
  log — fine at command-execution or export scale, not on per-keystroke
  paths.

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
hunted ref on the current QSO), and `call-notes` (`scope: 'general'`,
offline — combined `note`/`emoji` extra fields from the Hams of Note file,
issue #17).

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

## ✅ `spots` — spot sources and spotting (ham2k/app-halo-dist#9, #10)

```ts
interface SpotsHook {
  sourceName: string
  fetchSpots(args: {}, ctx): Promise<Spot[]>
  isSelfSpotEnabled?(args: { operation }, ctx): Promise<SpotEligibility>
  isOtherSpotEnabled?(args: { qso }, ctx): Promise<SpotEligibility>
  postSelfSpot?(args: PostSelfSpotRequest, ctx): Promise<PostResult>
  postOtherSpot?(args: PostOtherSpotRequest, ctx): Promise<PostResult>
}
// Spot: {their: {call}, freq?, band?, mode?, refs?: Ref[],
//        spot: {timeInMillis, source, label?, sourceInfo?}}
// SpotEligibility: {enabled, icon?}
// PostResult: {ok, message?}
// PostSelfSpotRequest: {operation, freq, mode?, comment?}
// PostOtherSpotRequest: {qso, comment?, spotterCall?}
```

Map upstream spots into QSON-shaped spot objects; filter out QRT/stale
entries at the source. `Spot` may also carry an `icon` (MDI/FontAwesome
name, same convention as `activity` controls). Implemented by: `pota`,
`sota` (SOTAWatch) — fetch only.

The four posting methods are all optional; a hook that omits them just
never appears in the Spotting control's icon row (same "silently absent"
convention as `export`'s `suggestExportOptions`). `isSelfSpotEnabled`/
`isOtherSpotEnabled` are checked once to decide whether to show a source's
icon at all (e.g. only when the operation/QSO has a matching activation
ref); `postSelfSpot`/`postOtherSpot` are only called for sources that
reported `enabled: true`. Implemented by: `pota` (self + other, posts
directly to the POTA API, no auth required). `sota`'s spot API requires an
authenticated account app-halo doesn't have yet, so `sota` stays
fetch-only for now.

## ✅ `export` — log file generation

```ts
interface ExportHook {
  suggestExportOptions?(args: ExportOptionsRequest, ctx): Promise<ExportOption[]>
  generateExport(args: ExportRequest, ctx): Promise<ExportResult>
}
// ExportOptionsRequest: {operation, qsos}
// ExportOption: {exportType, format, label, filename?, icon?, priority?, selectedByDefault?}
// ExportRequest: {operation, qsos, exportType?}   — full QSON, one coarse call
// ExportResult:  {filename, mimeType, content}
```

Two-step flow: the Exports Panel calls `suggestExportOptions` on every
`export` hook to build its selectable list (a hook that omits it never
appears in the panel), then calls `generateExport` — passing back the
chosen option's `exportType` — only for the options the user selected. The
core owns file I/O and save/share; the hook only produces content.
Exporters should compose per-QSO program fields from `adifFields` hooks (see
below) rather than knowing about specific activities. Implemented by: `adif`
(key `adif`, one option); Cabrillo will register here too.

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
interface CommandHook {
  interpret(
    args: { input: string; operation?; qso?; execute? },
    ctx,
  ): Promise<CommandInterpretation | null>
}
// CommandInterpretation: {expectsParams?, mixedCase?, error?, describe?, confirm?, commands?: CommandAction[]}
// CommandAction (closed set): {setVfo?, updateQso?, addQso?, sendSpots?,
//   syncAll?, updateSettings?, setCallField?, reloadDataFiles?, devNotice?,
//   devStatus?, devProgress?}
```

Each hook does its own matching internally and returns `null` for "not mine"
— the host never compiles extension-supplied regex source itself. A match
returns an interpretation the core previews (`describe`) and, on confirm,
applies: state changes go only through the closed `CommandAction` field set
(DESIGN.md §4's "whitelisted field-change operations"), never arbitrary
state. `expectsParams: true` is the "recognized prefix, keep typing" signal
described below.

A command that IS recognized but can't run in the current context returns
`{ error: '…' }` instead of matching silently or pretending to succeed —
e.g. the operation-scoped commands (SEED, NOTE, SPOT/SPOTLAST) typed into
the home screen's quick search, where no operation is open. The UI presents
the error message, never executes the interpretation, and leaves the typed
input in place for editing. Commands that work anywhere (DEVMODE, RELOAD,
band/frequency/mode…) never need it.

`interpret` is called on **every** keystroke pause (the call field's 150ms
typing-debounce, for the live `describe` preview), not just once when the
command actually runs — so a hook whose `commands` are expensive to build
must not compute them unconditionally. `execute: true` is the signal that
this particular call IS the one about to run the command (the host makes a
final `interpret` call with it set, right before dispatching `commands`,
discarding whatever a stale preview may have returned); it's false/undefined
on every describe-preview call. A hook with cheap `commands` can ignore this
entirely. `SEED` (below) is the one hook that needs it: skips its `ctx.getQsos`
read and per-generated-QSO lookups — real bridge/network-ish work — unless
`execute` is set, returning a cheap describe-only result otherwise.

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
changing, not the source data; SEED fills the current log with generated
QSOs via `addQso` actions — "SEED" adds 10, "SEED 20" adds 20, "SEED 15 3H"
spreads 15 over the 3 hours up to now, or over the 3 hours *ending at the
earliest existing QSO* when the log's own time span is under a third of
that spread. Calls come from the Callsign Notes data — call-notes exposes
its parsed index to other extensions through an in-runtime `callNotes`/
`allCalls` hook — and are mutated 80% of the time by swapping the digit or
a suffix letter; RSTs lean heavily toward 55/57/59; each generated QSO gets
the lookup service's offline `their.guess` decoration. The placement rule
needs the existing log: SEED reads it through `ctx.getQsos`, using the
`uuid` the logging panel folds into the `operation` map it passes to
`interpret`), `note-command` (NOTE <text> sets the
in-progress QSO's notes field via `updateQso`), and `call-notes` (`//KEY`
expands a Callsign Notes entry whose note is a plain comma list of calls
into the call field via `setCallField` — issue #17; leading "//" never
parses as call stacking, whose first segment would be empty, so the two
syntaxes coexist). Future command hooks (spotting, operator change…)
register in the same category and compete on priority with these.

A command that recognizes its own prefix but needs more typed input before
it can run (e.g. bare "RELOAD", before its target word) returns
`{ expectsParams: true }` instead of `null` or a full result. That switches
the call field to free-text entry — spaces allowed, no callsign character
restriction — and space no longer advances focus to the next field while
it's set; the interpretation is never executed even if Enter is pressed
while it still just says `expectsParams`. The field stays uppercase-only
(all logging input is uppercase unless explicitly mixed-case) unless the
interpretation also says `mixedCase: true` — for commands whose parameter
is free prose (NOTE's text), which lifts the uppercase rule. Return
`mixedCase` on both the bare-prefix result and the complete result, so
continued typing after the command is already complete ("NOTE Hello…")
isn't snapped back to uppercase. `mixedCase` is also what keeps Space a
literal character once a command is *already complete* — `expectsParams`
can't, since it also blocks execution — which is why SEED returns it on
every result despite its parameters not being prose: bare "SEED" must be
executable (default count) yet still extendable to "SEED 15 3H".

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
rescoring is not wired up yet (see [backlog.md](../backlog.md)).

Implemented by: `scoring` (key `core`) — three rules so far: duplicate-contact
detection, DXCC entities worked (via `@ham2k/lib-country-files`'
`useBuiltinCountryFile`, no network needed), and bands/modes worked. US
States and Canadian Provinces rules are deferred (see [backlog.md](../backlog.md)).

## ✅ `bench` — kernel diagnostics

Registered by the kernel itself (`bench/kernel`): `echo` (bridge round-trip
measurement) and `spin` (JS compute). Used by the spike screen; not for
extensions.

---

## ✅ `syncTransport` — sync backends

The transport seam for LoFi (and future) sync. The Dart core owns the
loop, batching, and dirty flags (`packages/halo_core`'s `SyncEngine`); the
hook only moves an already-selected payload over the network, so sync keeps
working even if the JS runtime is wedged (DESIGN.md §4). Registered as a
single object with `sync`/`getAccountData`/`linkClient`/
`linkClientWithEmail` methods — `linkClient` (optional) requests a link
permission (pending challenge code for an email, immediately-active for an
already-permitted account, or a blank permission for QR-code linking) and
returns server rejections as `{ error, error_status }` data.
Implemented by: `ham2k-lofi`.

## ✅ `settingsPanel` — extension settings forms

Declarative settings panels rendered by the core's `FormRenderer` — full
schema, kernel dispatch, `ExtensionService`, and `SettingsView` wiring; see
[settings.md](./settings.md). Complementary to `account`, not a replacement.
Implemented by: `settings` (the core General panel).

## ✅ `account` — account connections

Account connections (QRZ, LoFi): credential fields, `testCredentials`, and
optional OAuth2, surfaced in `SettingsView`'s Accounts panel via
`ExtensionService.getAccounts`/`testCredentials`. Credentials live in the
platform keychain, keyed by the account's `kvKey`. Implemented by: `qrz`.

## ✅ `dataFile` — offline reference datasets

Large offline datasets (park/summit lists) the core downloads, caches, and
refreshes on a schedule; the extension supplies the URL and a
row/entry→`LookupRow` transform. See `DataFileManager`
(`app/lib/services/data_file_manager.dart`). Implemented by: `pota`
(`pota-all-parks`), `sota` (`sota-all-summits`), and `call-notes`
(`fetchType: 'raw'` — the parsed Hams of Note index is cached as JSON and
replayed through `onLoadRawData` at startup, issue #17).

---

## 🔜 Planned categories

| Category | Role | Notes |
|---|---|---|
| `confirmation` | QSL/confirmation sources (spot-history cross-checking) | |
| `opSetting` | per-operation settings contributions | |

When one of these lands, move it above the line with its real signature.
