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
* `edition?: string` — The running build's edition: `'dev' | 'next' | 'prod'`
  (see `packages/halo_build_tools/lib/src/edition.dart`). For a hook whose
  static config must vary per-edition — e.g. SOTA's OAuth client, since each
  edition is a distinct app identity registered as its own client.
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
* `getSpotsForCall?(call, maxAgeMinutes = 30)` — the spots the host has
  already fetched for `call`, no older than `maxAgeMinutes` (measured on the
  spot's own `spot.timeInMillis`, not on when it was fetched), newest first.
  Reads the host's cache and **never triggers a fetch**, so unlike the log
  reads above it is cheap enough for the lookup path; it resolves `[]`
  whenever the cache is cold or the host keeps no spots. Used by
  `spot-history` to pull a hunted park or summit into the QSO being logged.

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
// LookupResult:      (CallInfoLookup & {locAccuracy?, refs?: RefInfo[]})[] —
//                    zero or more records; [] to skip
// CallInfoLookup:    CallInfo & {source?, scope?: 'general'|'operation'|'qso', notes?, history?}
```

A result's `refs` **proposes** activity references for the QSO being logged.
The host applies only those whose `type` the QSO does not already carry — a
lookup never overrides a reference the operator entered — and re-runs the
lookup once afterwards so QSO-scoped hooks (POTA/SOTA) see the new ref and
can resolve its grid. Because an already-applied type is filtered out on the
next pass, that re-run settles instead of cycling.

Return `[]` for "can't answer" (not configured, not found, or `!ctx.online`
and this source has no offline data) — never throw for expected conditions.
`callInfo`/`qso`/`operation` are the full QSON-shaped objects (all from
`@ham2k/lib-qson-tools`'s `CallInfo`/`QSON` types), so e.g. a POTA lookup can
inspect `qso.refs` for a hunted park reference. Implemented by: `hamdb`,
`qrz` (`scope: 'general'`), `pota`, `sota` (`scope: 'qso'`, grid of any
hunted ref on the current QSO), and `call-notes` (`scope: 'general'`,
offline — combined `note`/`emoji` extra fields from the Hams of Note file,
issue #17).

## ✅ `recentContextLookup` — live-context lookups

Same `LookupHook` interface, run by the same orchestrator immediately after
the `lookup` fan-out and folded through the same merge — but **only when the
request sets `recentContext`**, which the logging panel does solely while
composing a new contact.

The split is about what the answer depends on. A `lookup` hook answers *who
is this callsign*, which is true whenever asked. A `recentContextLookup` hook
answers *what is this station doing right now* — from spots, from the last
minutes of the log, from whatever else is live — and that is a question about
a contact in progress. Asked about a QSO logged an hour ago, or about every
callsign on the spots board, the answer is not just useless but wrong.

Registering here rather than under `lookup` is therefore correctness first
and economy second, though the economy is real: the spots board runs a lookup
per distinct spotted call, and the background queue one per saved QSO, so an
ordinary `lookup` hook is asked hundreds of times for answers nobody reads.

Implemented by: `spot-history` (offline — `refs` from the host's recent
spots, see `ctx.getSpotsForCall`).

## ✅ `lookupService` — the lookup orchestrator

One hook call resolves an entire callsign decoration pass: the hardcoded
callsign-annotation pre-step (via `@ham2k/lib-country-files`, always first,
regardless of any other hook's priority) plus every registered `lookup` hook
above — and, when `recentContext` is set, the `recentContextLookup` hooks
after them — merged according to the `locationScope` rules, all inside the
runtime, mirroring `scoring`'s "one coarse call in, everything back out"
shape.

```ts
interface LookupServiceHook {
  lookupCallInfo(
    args: { callInfo: CallInfo; qso; operation; recentContext?: boolean },
    ctx,
  ): Promise<{ lookups: CallInfoLookup[]; guess: CallInfo }>
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

## ✅ `spots` — spot sources and spotting (ham2k/halo-dist#9, #10)

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
// ExportOptionsRequest: {operation, qsos, compactFilenames?}
// ExportOption: {exportType, format, label, filename?, icon?, priority?, selectedByDefault?}
// ExportRequest: {operation, qsos, exportType?, compactFilenames?}  — full QSON, one coarse call
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

**Filenames.** Build them with the SDK's `exportFilename` rather than
spelling one out, passing the request's `compactFilenames` straight through —
that is what makes the user's "Use compact file names" setting apply to your
export, and what keeps every extension's names consistent:

```ts
filename: exportFilename({
  stationCall: operation.stationCall,
  ref: 'US-1234',                            // or `activity: 'CQ-WW-CW'`, or neither
  startAtMillis: startMillisOf(operation, qsos),
  extension: 'adi',
  compact: args.compactFilenames,
})
// normal  → "2026-07-27 N0CALL at US-1234.adi"
// compact → "N0CALL@US-1234-20260727.adi"
```

Set `filename` on the OPTION, not just on the result: the panel shows the
option's name, and the core writes the file under it. A name computed again
in `generateExport` sees a different input — that call is handed only the
QSOs the option's `refType` covers — so the two would otherwise disagree in
front of the user.

## ✅ `ref:<type>` — reference handlers

One category **per ref type** (e.g. `ref:pota`, `ref:potaActivation`),
following app-polo's QSON conventions. Handles validation and enrichment of
activity references on QSOs and operations.

```ts
interface RefHandlerHook {
  validateRef?(args: { ref: Ref }, ctx): Promise<{valid: boolean; normalized?: string}>
  decorateRef?(args: { ref: Ref }, ctx): Promise<Ref>   // may hit the network
  suggestOperationTitle?(args: { ref: Ref; operation }, ctx): Promise<TitleSuggestion | null>
}
// Ref: {type, ref?, name?, label?, shortLabel?, grid?, location?, program?, ...}
// TitleSuggestion: {title?, for?, at?, subtitle?, priority?} — a fragment of
// the operation's title/subtitle sentence (ham2k/halo-dist#174). Only
// return one for the ref type that means "this operation is happening AT/FOR
// this reference" (e.g. an activation, not a hunted ref) — a hunting ref
// contributes nothing here. `priority` breaks ties when multiple refs supply
// the same fragment kind (higher wins); default 0.
```

`decorateRef` fills names/locations/labels (park names via the POTA API,
etc.); results update ref chips asynchronously in the UI. Implemented by:
`pota` (both types).

`suggestOperationTitle` lets an activity build a natural-language operation
title/subtitle from its refs — "at Yosemite NP" (POTA), "for Field Day"
(contest programs, when ported) — mirroring app-polo's
`buildOperationTitle`. The core (`OperationTitleService`) calls this once per
ref, groups the non-null results by fragment kind (`title`/`for`/`at`,
highest `priority` first within a kind), and joins them with a **localized**
"for"/"at" — unlike app-polo, which hardcodes those joiner words in English;
HaLo threads them through `strings.g.dart` instead, so extensions only ever
return proper nouns/names (locale-agnostic or self-translated via their own
`tFor`), never the connective prose. Implemented by: `pota`, `sota`
(activation ref types only).

## ✅ `activity` — declarative UI contributions

The UI-catalog seam (DESIGN.md §5): activities describe controls as data;
the core renders them with native widgets and calls back into ref handlers
for behavior.

```ts
interface ActivityHook {
  // `qso` is the in-progress QSO, including `their.guess` from the callsign
  // lookup — re-supplied when a lookup resolves, so a control can key a
  // dynamic label/placeholder/suggestedValue off who's being worked.
  loggingControls?(args: { operation, qso? }, ctx): Promise<LoggingControlDescriptor[]>
  operationControls?(args: { operation, qso? }, ctx): Promise<LoggingControlDescriptor[]>
  suggest?(args: SuggestArgs, ctx): Promise<ActivitySuggestion[]>
  processQsoBeforeSave?(args: { qso, operation }, ctx): Promise<Patch | null>
}
// LoggingControlDescriptor: {key, label, icon?, color?, order?, optionType?,
//   allowsMultiple?, editable?, input}
// SuggestArgs: {operation, location?: {lat, lon}, callsign?, searchTerm?}
// ActivitySuggestion: Ref & {distance?, relevance?, allowsMultiple?}

// The input catalog. A new kind is earned by a different WIDGET, never by
// different validation — so a pattern-constrained field is `text` with a
// `pattern`, not a kind of its own (docs/design/contests.md §5.3).
//   {kind: 'refList', refType, placeholder?, pattern?, transforms?}
//   {kind: 'text',    refType, field, placeholder?, pattern?, transforms?,
//                     numeric?, uppercase? /* default true */, maxLength?,
//                     suggestedValue?}
//   {kind: 'options', refType, field, options: [{code, name?}], matchOn?,
//                     allowFreeform?, preferredCodes?, minCharsForSuggestions?,
//                     placeholder?, pattern?, transforms?, numeric?, uppercase?,
//                     maxLength?, suggestedValue?}
//   {kind: 'serial',  refType, field, sequence: {key, scope?, start?, padTo?},
//                     editable?}
//   {kind: 'form',    refType, form}   // operationControls only
//
// `pattern` is anchored (`^(?:…)$`) and matched case-insensitively for every
// kind; a malformed regex disables validation rather than throwing. A
// mismatch tints the field but still accepts the value.
//
// `text`, `options` and `serial` values round-trip onto a ref of `refType` under
// `field`, through the same core-owned path refList writes refs — several may
// share one refType and are merged into a single ref. `suggestedValue` fills the
// field only while the operator hasn't typed into it. A `serial`'s number is
// allocated by the core (docs/design/contests.md §5.8), and all three kinds
// render as PRIMARY fields, shown only when the operation is running that
// activity.
//
// An `options` field searches a KNOWN SET: it shows a ranked suggestion line and
// Space accepts the top hit before advancing, and a value outside the set tints
// the field unless `allowFreeform`. Space accepts only a suggestion the typed
// text is a PREFIX of, and never from an empty field — a substring hit is worth
// showing, but swapping one in rewrites the operator's own text into something it
// isn't the start of. The suggestion line is added to the info area, above
// whatever it was already showing, so a DUPE stays visible while an exchange
// field has focus. The set is inline — §5.3's registered `optionSet` is deferred
// (nothing can write rows into the lookups table today).
// `text`, `serial` and `options` are logging-panel kinds: operation settings
// render `refList` and `form` and silently ignore the rest.
//
// `optionType` is NOT yet honored by the core.
```

`icon` is a Material Design Icons name (e.g. `'pine-tree'`), or a FontAwesome6
solid-style name prefixed with `'fa-'` (e.g. `'fa-tree'`) — same convention
app-polo itself uses. Any name in either set works with no core-repo change;
an unrecognized name falls back to a placeholder glyph rather than erroring.

`color` is an optional `'#RRGGBB'` accent (e.g. POTA's `'#068541'`) the core
may use sparingly to highlight this control's icon — a tinted circle behind
it in the Activities picker, or the icon itself once a reference is entered
in the logging panel's secondary pills. Missing or unrecognized values just
mean no accent.

`processQsoBeforeSave` is the last chance to shape a QSO before it is written,
for projecting data the extension owns into the generic QSON fields the rest of
the app reads. A contest keeps its exchange on its own ref (`theirZone`,
`theirSerial`, …), which nothing generic knows how to read — mirroring it into
`their.exchange` is what fills the QSO row's exchange column and a plain ADIF
export. Return a PATCH, not a mutated QSO: it merges shallowly except `our` and
`their`, which merge one level deep, so `{their: {exchange: 'ZN5'}}` sets that
field and leaves the callsign alone. `refs` and `uuid` in a patch are ignored —
refs are shared with the core and with other activities. Return null to do
nothing. Called on every save path (single QSO, call list, call stack, edit),
and skipped entirely when the operation has no refs, so ordinary logging pays
no bridge crossing. A serial the CORE allocates at commit is NOT visible here
for the second and later calls of a call list (docs/design/contests.md §5.8).

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
out to every `activity` hook via `invokeHookAll`, merges results, and ranks them
in TWO BANDS (`app/lib/tools/activity_suggestions.dart`): everything carrying a
`distance` first, by `distance / relevance` ascending — a more relevant hit
counts as nearer — then everything without one, by DESCENDING `relevance`, with
ties broken on the order the extension emitted them. So `relevance` alone orders
a set of placeless suggestions (dated contest events, say) among themselves, but
never lifts one above a located park. Implemented by: `pota`, `sota`,
`stateparks`.

The activity search box also treats a leading `key:` as a scope — typing
`pota:` (or tapping a row under "Activity Types") asks that extension alone,
via a key-scoped `invokeHook` rather than the usual fan-out. For that to
work, an extension's `activity` hook must be registered under its own
**extension key**, and its control descriptors keyed `<extensionKey>/<name>`
(`pota/activation`) — the core derives the scope from the part before the
slash. An extension that deviates simply never gets scoped: its rows still
add references, but `key:` would ask a hook that doesn't exist and come back
empty.

`editable` declares whether a reference of this type has anything to edit
once it's on the operation. It defaults to **false**: a plain reference
activity carries only the code its own `suggest` already resolved, so the
Current Activities row stays inert — the user removes it and picks again
rather than retyping a code no lookup would re-check. `pota` and `sota` leave
it off. Set it true for a type whose references carry more than the code.

A **`kind: 'form'` control prompts on add.** Tapping one of its suggestions
saves the reference and then opens the setup form over it, because a contest
that has not been set up cannot score and nothing on its row says so. The
save comes first, so cancelling the form leaves the activity added and
unconfigured rather than undoing the tap. Two consequences for the hook:

- The suggestion still has to carry its own `label`/`shortLabel`/`program`
  (§5.4 of contests.md) — the cancel path never reaches `decorateRef`, so a
  suggestion that relies on being decorated reads as a blank row.
- `decorateRef` runs on whatever the form submits, immediately after. It is
  handed the suggestion's own fields merged with the form's, so it must
  tolerate being called with a reference it has already decorated once.

A `refList` control does **not** prompt: its suggestion already carries the
code that identifies it, so a form could only ask the user to retype what
they just picked.

`allowsMultiple` declares whether an operation may carry more than one
reference of that type at a time. It defaults to **false**: picking one of
the type's references **replaces** the operation's existing reference of
that type rather than adding alongside it. A type that genuinely stacks
declares `allowsMultiple: true` — `pota` does, for n-fers. Declare it on the
suggestion (for the search/nearby list) *and* on the type's
`LoggingControlDescriptor` (for references the user types in by hand); the
core reads the suggestion's value first and falls back to the control's.
Selecting a reference the operation already has is still a duplicate, not a
replacement — the core flashes the existing row instead of adding it twice.

## ✅ `adifFields` — per-QSO export field contributions

How activities inject program fields into ADIF exports without the exporter
knowing them. Called by the `adif` extension **inside the runtime** via
`hooks.invokeAll` — no bridge crossing.

```ts
interface AdifFieldsHook {
  fieldsForOneQSO(args: { qso, operation }, ctx): Promise<{name, value}[]>
  // One field set PER ADIF RECORD this contact should produce.
  fieldCombinationsForOneQSO?(args: { qso, operation }, ctx): Promise<{name, value}[][]>
}
```

POTA contributes `SIG/SIG_INFO/POTA_REF` (hunted refs on the QSO) and
`MY_SIG/MY_SIG_INFO/MY_POTA_REF` (activation refs on the operation).

`fieldCombinationsForOneQSO` exists because **one contact can owe several ADIF
records**: work a station standing in two parks and each park is submitted
separately, which is also why it counts twice toward an activation
(docs/design/activities.md §4). Return one field set per record; the exporter
writes that many, shifting each successive record's `QSO_DATE`/`TIME_ON` by a
second so otherwise-identical records aren't read as duplicates (app-polo's
`qsonToADIF.js:144` does the same).

Record count is the largest any hook asks for. A hook returning a single set
is describing the *contact*, so its fields go on every record; only a hook
returning several is describing individual records. Declaring both methods is
fine and expected — a hook that does is asked only for its combinations, so
its plain fields aren't written twice. Implemented by: `pota`.

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
  catalog?(ctx): Promise<CommandCatalogEntry[]>
}
// CommandInterpretation: {expectsParams?, mixedCase?, error?, describe?, confirm?, commands?: CommandAction[]}
// CommandCatalogEntry: {command, describe, params?, category?, needsOperation?, expectsParams?, suggest?}
// CommandAction (closed set): {setVfo?, updateQso?, addQso?, sendSpots?,
//   syncAll?, updateSettings?, updateSetting?, openSettings?, setCallField?,
//   reloadDataFiles?, devNotice?, devStatus?, devProgress?, devSplash?,
//   devOnboard?, devTester?, toggleExperiment?}
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

A hook whose complete result needs a network fetch doesn't have to block
`interpret`'s own returned Promise on it — even on a describe-preview call.
Return quickly with a placeholder `describe` ("Fetching…"), kick the fetch
off in the background, and once it resolves call:

```ts
host.updateInterpretation(input: string, interpretation: CommandInterpretation): void
```

One-way, like `host.log` — no response ever comes back, nothing to await.
`input` must be the same `input` the triggering `interpret` call received;
the host discards a push whose `input` no longer matches the live call field
(the user typed past it), the same way it already discards a stale
describe-preview result. This is how `annotation-commands`' SOLAR/WEATHER
(below) show their fetched reading in the UI before the user ever presses
Enter, without either blocking every keystroke-debounce call on a live
fetch or requiring a second command invocation.

Note that only the logging panel consumes those pushes today — the ⌘K palette
and the Home search bar do not — so a hook that needs its describe on every
surface must resolve it inside `interpret` instead. `settings-commands` awaits
its host call for that reason.

A command that needs to reach the app's SETTINGS asks rather than carrying its
own list of them:

```ts
host.searchSettings({ args: string, kind?: 'set' | 'show' | 'hide' }): Promise<SettingsSearchResult>
```

`args` is everything the operator typed after the command word, whole: where
the setting's name ends and its value begins is decided app-side, because only
the settings catalog can tell `SET AVOID ZERO BEAT N` (a four-word name plus a
value) from `SET THEME DARK` (a one-word name plus a value). Matching is by
subsequence over each setting's key, aliases and label, and the catalog is
derived from the app's declarative settings registry — so it reaches every
setting the settings screen would currently show, and only those (`devMode`,
`environment` and `visibleWhen` all apply). The result carries the setting's
label, section, current value and the coerced new value, each already
localized; a `secret` field's value is never included. Write the result back
with the `updateSetting` action, or open the settings form with `openSettings`.

This call re-enters the extension runtime while the calling hook is still
awaiting it (reading every `settingsPanel` is part of building the catalog).
That is safe by construction — hook calls are keyed by id with independent
completers and no lock — but it is the only host call that does so, and any
new one that re-enters should say so here.

Implemented by `radio-commands` (band/frequency/mode shortcuts — "20m ",
"14285 ", "14.285 ", "cw "), ported from app-polo's `RadioCommands`
extension. Notably, this replaced an earlier hand-rolled Dart regex for
frequency parsing that rejected valid MHz-style input ("14.285") because it
required 3+ digits before any decimal point; the extension delegates to
`@ham2k/lib-format-tools`' published `parseFreq` instead, which already
handles this correctly. Also implemented by `dev-commands` (DEVMODE toggles
developer mode; DEVNOTICE/DEVSTATUS/DEVPROGRESS post sample items to the
status bar via the `devNotice`/`devStatus`/`devProgress` action fields, for
exercising that UI without a real extension driving it; DEVSPLASH re-shows
the startup release-notes overlay (Issue #42) via the `devSplash` action
field, bypassing its normal once-per-version gate — for previewing that
overlay on demand instead of only once per release; RELOAD forces a
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
`interpret`; EXP toggles an experimental feature via the `toggleExperiment`
action field — the hook only parses "EXP <key-or-alias>", and the app
resolves the token against `app/experiments.yaml` and reports the outcome,
since the catalog and the stored per-experiment state both live app-side),
`annotation-commands` (ham2k/halo-dist#64, ported from
app-polo's AnnotationCommands: NOTE/TODO `<text>`, SOLAR, and WEATHER each
add an annotation row to the log — an event pseudo-QSO, `band: 'event'`,
via `addQso`, rendered as a yellow row by the QSO list. SOLAR fetches
hamqsl.com's solar indices and WEATHER fetches Open-Meteo conditions for
the operation's grid square — as soon as the command is recognized
(ham2k/halo-dist#189), not only at `execute`: `interpret` kicks the
fetch off in the background and returns a placeholder `describe`
immediately, then pushes the resolved reading via `host.updateInterpretation`
once it lands, so it shows in the UI before the user presses Enter. One
in-flight fetch is shared by every `interpret` call for the same command
until an `execute` call consumes it (reusing the same reading rather than
fetching twice) and clears it, so the next SOLAR/WEATHER starts fresh. The
raw readings land in the logged event's `data` and the emoji summary line
in its `description`. This superseded the original `note-command`
extension, whose NOTE wrote to the in-progress QSO's notes field instead of
the timeline), and `call-notes` (`//KEY`
expands a Callsign Notes entry whose note is a plain comma list of calls
into the call field via `setCallField` — issue #17; leading "//" never
parses as call stacking, whose first segment would be empty, so the two
syntaxes coexist). Future command hooks (spotting, operator change…)
register in the same category and compete on priority with these.

### `catalog` — advertising commands to the ⌘K dialog

`interpret` answers *"what does this exact text mean?"* — one answer, for
text the user has already typed. The command dialog (⌘K, issue #55) needs the
other direction: *"what commands exist?"*, so it can list them before the
user knows the syntax. That's the optional `catalog(ctx)`, returning one
entry per command:

```ts
{ command: 'NOTE', params: '<text>', describe: 'Add a note to the log',
  category: 'Log annotations', needsOperation: true, expectsParams: true }
```

`command` is both what the palette matches against and what it types into the
field when the entry is chosen, so it has to be something `interpret`
recognizes. `params` is display-only. `describe` may use inline markdown
(`**bold**`, `*italic*`, `` `code` ``), the same as `interpret`'s own
`describe`/`confirm` — the dialog renders it as one ellipsized line rather
than as blocks, so keep it to a single sentence. `needsOperation` drops the row entirely when
no operation is open, instead of letting the user pick it and get
`interpret`'s `error` back. `expectsParams` leaves the field open for typing
rather than running the command immediately — the catalog counterpart of
`CommandInterpretation.expectsParams`, and the reason picking NOTE doesn't
log an empty note. `suggest` opts the entry into the empty-field "Try"
samples shown while the dialog is new; it's opt-in on purpose — the samples
go to users who don't yet know what a command does, so anything destructive,
heavyweight or developer-only must stay out. Absent means listed and
searchable, never volunteered.

Three things differ from `interpret`, all deliberate:

- **Called once and cached**, not per keystroke — dropped when the runtime is
  replaced (an extension enabled/disabled) or the hook context is
  invalidated (locale change, since `describe` is localized by the hook).
- **Matching is host-side**, plain case-insensitive substring against
  `command` and `describe`. Same rule `interpret`'s own matching follows: the
  host never compiles extension-supplied patterns.
- **List commands, not variants.** `radio-commands` advertises one BAND
  entry, not fifteen; `call-notes` advertises `//`, not every key the user
  has defined.

A hook without `catalog` contributes nothing to the palette's suggestions and
still works fine when its commands are typed in full — that's why it's
optional. `dev-commands` uses `ctx.developerMode` to keep DEVMODE, SEED and
friends out of the list unless developer mode is on (RELOAD, being genuinely
user-facing, is always listed); the commands themselves still run either way.

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

Authors don't implement this directly. Write a **`ContestScorer`** — three
pure functions — and wrap it with `contestScorer()`, which supplies the loop,
day sectioning, checkpointing and the live single-QSO path
(docs/design/contests.md §5.2):

```ts
interface ContestScorer<S> {
  startScoresheet({operation, ref?}, ctx): S
  scoreQso({scoresheet, qso, operation, ref?, isNewDay}, ctx): {scoresheet: S, score}
  summarizeScore({scoresheet, operation, ref?, scope}, ctx): Record<string, ScoreTally>
}

registerHook('scoring', {
  hook: contestScorer(MyScorer, { scope: { refTypes: ['cqww'] } }),
  key: 'cqww',
})
```

`scope` decides which operations the scorer applies to, and the host reads it
*before* invoking anything: `'always'` (core dupe/DXCC/bands) or a `refTypes`
list, so an operation that doesn't carry the ref never crosses the bridge.
Several scorers run on one operation — contests alongside core — and their
results are namespaced per scorer.

A scorer's internal *rules* stay private to its scoresheet: contests don't
share a rule vocabulary, so only notices, alerts, points and summary tallies
cross the boundary. `scoreQso` **may mutate** the scoresheet it's given and
return it; copying accumulated state per QSO is quadratic, and the harness
copies any checkpoint at its boundary.

```ts
// The wire shape the harness produces, for reference:
interface ScoringHook {
  scoreQsos(args: ScoreQsosRequest, ctx): Promise<ScoreQsosResult>
  scoreQso?(args: ScoreQsoRequest, ctx): Promise<QsoScoreNotices>
  scoreCandidates?(args: ScoreCandidatesRequest, ctx): Promise<ScoreCandidatesResult>
}
// ScoreQsosRequest: {operation, qsos, ref?, resumeFrom?}
// ScoreQsosResult:  {
//   qsoScores: Record<uuid, QsoScoreVerdict>,   // one verdict per QSO
//   daySections: {day, count, scores: Record<tallyKey, ScoreTally>}[],
//   operationSummary: Record<tallyKey, ScoreTally>,
//   scoresheet,                                  // checkpoint to resume from
// }
// ScoreCandidatesRequest: {operation, candidates: {key, qso}[], ref?, segments?, resumeFrom?}
// ScoreCandidatesResult:  Record<candidateKey, QsoScoreNotices>
```

All three arrive already implemented by `contestScorer()`; a scorer writes the
three pure `ContestScorer` functions and gets the loop, the checkpointing and
both live paths for free.

`scoreQso` answers for ONE not-yet-logged QSO — the callsign being typed.
`scoreCandidates` answers the same question for many at once, which is what the
Spots Panel asks to mark the spots already worked: the log is folded once per
scorer and every candidate scored against a COPY of the result, so no candidate
can become another's duplicate. Candidates carry no uuid — a spot is not a
record — so results come back under caller-chosen keys.

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

The account-management methods are all optional and all follow that same
"a rejection is data, not a throw" convention, because every one of them
reports to an operator in the middle of an action: `setAccountEmail` /
`resendAccountEmail` change the address that identifies the account (it
stays pending until the operator opens a mailed confirmation link, so a
typo can never hand the account to a stranger), and `findLinkRequest` /
`findLinkRequestByClient` / `approveLinkRequest` are the CONFIRMING side of
linking — where `linkClient` asks to join some other account, these let
this device admit another one into its own, from a typed challenge code or
from the `com.ham2k:///link_client?id=…&token=…` deep link a requesting
device's QR code carries. `approveLinkRequest` must be given the
`challenge_token` for a blank/QR permission: that token is what binds a
permission created with no account behind it to this one.

`submitReport`
(optional) files a report the host composed — the equipment editor's radio
report — as a real CaBo card; the host writes the title, body and kind, the
transport adds who/where/what-build and owns the account gate.
Implemented by: `ham2k-lofi`.

## ✅ `settingsPanel` — extension settings forms

Declarative settings panels rendered by the core's `FormRenderer` — full
schema, kernel dispatch, `ExtensionService`, and `SettingsView` wiring; see
[settings.md](./settings.md). Complementary to `account`, not a replacement.
Implemented by: `settings` (the core General panel).

## ✅ `account` — account connections

Account connections (QRZ, LoFi, SOTA): credential fields, `testCredentials`,
and optional OAuth2, surfaced in `SettingsView`'s Accounts panel via
`ExtensionService.getAccounts`/`testCredentials`. Credentials live in the
platform keychain, keyed by the account's `kvKey`. Implemented by: `qrz`
(username/password) and `sota` (OAuth2 via Keycloak — `sso.sota.org.uk`; the
host runs the whole PKCE flow itself, see `_doOAuth` in
`app/lib/views/settings_view.dart`).

**`label` / `description` / `fields`** — each either a plain value, or a
function `(args, ctx) => value` called the same way any other hook method is,
so extensions can localize them from `ctx.locale` (via the SDK's
`createTranslator`). The same `Localizable<T>` convention applies to a
`dataFile` registration's `name`/`description`. QRZ localizes its account
description and field labels this way.

**`oauth2`** (optional) — either a plain `OAuth2Config`
(`{issuer, clientId, redirectUrl, scopes}`), or, for a client that varies by
build edition, a function `(args, ctx) => OAuth2Config` called the same way
any other hook method is (`ctx.edition` is `'dev' | 'next' | 'prod'` — see
`HookContext.edition` below). SOTA registers a separate Keycloak client per
edition (ham2k/halo-dist#253 — each edition is its own app identity,
`com.ham2k.logger.dev`/`.next`/`.prod`, each needing its own redirect URL
registered with SOTA) rather than sharing one client across builds.

**`synchronizable`** (optional, default `false`) — on Apple platforms (macOS
and iOS), when `true` the account's stored credentials and session sync across
the user's devices via iCloud Keychain (`kSecAttrSynchronizable`); when `false`
they stay device-local. No effect on other platforms. Set it `true` only for
account-level logins that are genuinely the same on every device — QRZ.com sets
it, since one QRZ login is shared across a user's installs. **Never** set it for
per-device identifiers or bearer tokens: the LoFi sync **device key** is a
per-install identifier and deliberately stays device-local (it isn't even an
`account` hook — it lives in `SettingsService`, non-synchronizable, and must
stay that way, or two devices would present as the same sync client).

The flag must be consistent for a `kvKey` across its whole lifetime: a
synchronizable and a non-synchronizable keychain item are *distinct entries*,
so the host resolves each account's flag once at runtime start
(`ExtensionService._accountSynchronizable`) and applies it to every
read/write/delete. Flipping the flag on an account that already has stored
credentials makes the old entry invisible — the credentials must be re-entered
once (there is no automatic migration between the two entries).

## ✅ `dataFile` — offline reference datasets

Large offline datasets (park/summit lists) the core downloads, caches, and
refreshes on a schedule; the extension supplies the URL and a
row/entry→`LookupRow` transform. See `DataFileManager`
(`app/lib/services/data_file_manager.dart`). Implemented by: `pota`
(`pota-all-parks`), `sota` (`sota-all-summits`), and `call-notes`
(`fetchType: 'raw'` — the parsed Hams of Note index is cached as JSON and
replayed through `onLoadRawData` at startup, issue #17).

### How CSV rows reach `csvToLookupEntry`

An extension writes a **per-row** mapper; the kernel synthesizes the batch
method around it. What crosses the boundary is **not** what the mapper sees:
the host sends rows **positionally** plus the header row **once per chunk**,
and `registerHook` zips them back into the `Record<string, string>` the mapper
is declared to take. Building those maps host-side instead meant every column
name was repeated for every row — 61% of the bytes on SOTA's 181k-row file
(APP-16).

Consequences worth knowing:

- A file with `hasHeaders: false` sends no headers, and the mapper receives the
  positional `string[]` — the other half of the declared
  `string[] | Record<string, string>` signature.
- A short row leaves its trailing keys **absent**, not `undefined`-valued, so
  `!row.SummitCode` still works as the emptiness test.
- The zipped row has a **null prototype**: column names come from a
  third-party file and must never reach `Object.prototype`.
- An extension that defines `mapCsvBatch` **itself** bypasses all of the above
  and receives the raw `{ rows, headers? }` — it has to zip on its own. Nothing
  does this today, and `DataFileDefinition` doesn't declare the method, so the
  type checker will not remind you.

---

## 🔜 Planned categories

| Category | Role | Notes |
|---|---|---|
| `confirmation` | QSL/confirmation sources (spot-history cross-checking) | |
| `opSetting` | per-operation settings contributions | |

When one of these lands, move it above the line with its real signature.
