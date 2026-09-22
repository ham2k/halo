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
  static config must vary per-edition — e.g. SOTA's OAuth redirect URL, one
  per edition and each registered separately with the provider.
* `enabledExperiments?: string[]` — Keys of every experiment
  (`app/experiments.yaml`) currently on for this user. For a hook whose own
  effect must stay invisible until an experiment gating the surface it
  belongs to has shipped ungated — checked per-call, since gating at the
  whole-extension `manifest.experiments` grain would also hide any other
  hook the same extension registers (e.g. `radio-commands`' POWER command
  checks `gato` here; its BAND/MODE/frequency siblings don't).
* `experiments?: { key, name, aliases }[]` — The experiment catalog itself,
  on or off, so a hook can resolve a typed key-or-alias to one of the keys
  `enabledExperiments` lists (the EXP preview says "Enable"/"Disable" rather
  than "Toggle"). The app remains the authority when it flips the state.
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
* `getHistoryForCall?(call, options?)` — the most recent non-deleted contacts
  logged with `call` (five unless `limit` says otherwise, never more than
  50), across every operation, newest first, as raw QSON — the one log read
  that is cross-operation rather than scoped to a single one, since it
  answers "who is this station" from the whole log rather than "what's in
  this operation". Resolves `[]` for no match or no log access; unlike
  `getQsos` there is no "unknown call" to distinguish from "no history".
  Used by `call-history` to fold the most recent past QSO's fields into a
  lookup result.

  `options` (`HistoryForCallOptions` in `types.ts`) narrow the history
  before it is ordered and limited, so `{ refType: 'cwt' }` finds last
  month's CWT exchange behind a week of POTA contacts. The filters are
  `refType` (a ref in the QSO's own `refs` or its operation's, since an
  activation's ref lives on the operation), `refPrefix` (such a ref whose
  `ref` starts with it, ignoring ASCII case; with `refType`, the same ref
  must pass both, so `{ refType: 'potaActivation', refPrefix: 'FR-' }` finds
  every contact made activating a French park; an operation's refs are its
  base ones unless `refsSegmentAware: true`, which reads them as they stood
  at each contact, so a rove's second park or a contest that ended at a
  break is seen), `operation`/`excludeOperation`,
  `band`/`excludeBand`, `mode`/`excludeMode` (`SSB` also matches its
  sidebands, and `CW`/`PHONE`/`DATA` match their whole family), whole UTC
  days through `fromDate`/`toDate` or `fromDateMillis`/`toDateMillis`, and
  exact instants through `fromTime`/`toTime` or
  `fromTimeMillis`/`toTimeMillis`. All the bounds are inclusive. A malformed
  option, an unknown one, or an include option given no values
  (`operation: []`) rejects the call instead of answering an unfiltered
  history. Hosts older than these options ignore them and answer the latest
  five contacts unfiltered, so a caller re-checks on the results whatever it
  relies on — and an empty answer there means "none among the latest five",
  not "none at all".

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
// LookupResult:      (CallInfoLookup & {locAccuracy?, refs?: RefInfo[], online?: boolean})[] —
//                    zero or more records; [] to skip
// CallInfoLookup:    CallInfo & {source?, scope?: 'general'|'operation'|'qso', notes?, history?}
```

Set `online: true` on a result ONLY when answering it required an actual
network round-trip — never on one your source could have produced with
`ctx.online` false. `LookupQueueService._hasOnlineLookup` reads this flag
generically to decide whether a saved QSO already has a real online answer
worth not re-fetching; omitting it (the default) is correct for anything
from local/offline data — a log query, a cached reference file, notes — even
if that source usually needs the network for OTHER calls (POTA/SOTA's
`fetchPark`/`fetchSummit` try a local reference-data cache before falling
back to a live fetch, so they leave it unset rather than risk mistagging a
cache hit). The one-time offline annotation pre-step never sets it either.

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
inspect `qso.refs` for a hunted park reference. Implemented by: `qrz`,
`ham2k-lookup` (`scope: 'general'`), `pota`, `sota` (`scope: 'qso'`, grid of
any hunted ref on the current QSO), `call-notes` (`scope: 'general'`,
offline — combined `note`/`emoji` extra fields from the Hams of Note file,
issue #17), and `call-history` (`scope: 'general'`, offline — the most
recent past QSO's own identity fields, from `ctx.getHistoryForCall`).
Registers at **priority -1** — below every other lookup source, and below
the 0 an undeclared hook defaults to: the log is a fallback, filling only
what nothing else answered, and that holds even for a field the operator
TYPED on the past QSO — a live source describes the station today, the log
describes it whenever it was last worked. It still labels a carried-forward
field by where it came from (`Call History` for a typed one, `Call History
(guess)` for a guessed one), and a station's whole location travels in one
of the two so the merge's grid/city reconciliation cannot split it — see
`extensions/lookups/call-history/src/index.ts`.

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
- Location fields merge as a group, never per field. A same-scope result
  bringing a pin (a grid, or a full lat/lon pair) to a guess that has none
  replaces the established city/state/county/country/location with its own
  values (or just clears them, if it carries only the pin) — even where
  per-field priority would have kept the earlier town. A result whose own
  pin loses to an already-established one contributes no location fields at
  all, and a pinless result's town is used only where the higher-priority
  lookups left no town or pin (an entity-level `country` alone doesn't
  count as located): a town is never spliced with a pin — or a town half —
  it wasn't reported with.
- Grid/lat-lon reconciliation, scoped to fields the result actually set:
  grid-only → lat/lon computed from the grid; lat/lon-only → a 6-digit grid
  computed from them; both given → taken verbatim. Setting grid/lat/lon
  clears city/state/country/county unless the *same* result also supplies
  them. The converse clause — a town write clearing grid/lat/lon — can only
  sweep a leftover half lat/lon pair: the group rule above blocks a town
  from landing at all where a full pin already stands.
- `notes`/`history` are per-`CallInfoLookup` fields, not part of the merged
  `guess` — they simply accumulate, unconditionally, in the returned
  `lookups[]` array.
- **`locSource: 'prefix'` is reserved**, and a `lat`/`lon` merged under it is
  never read as a coordinate (`locationFromGuess`, halo_core). It marks
  lib-country-files' DXCC entity centroid, whose longitude follows cty.dat's
  west-positive convention — the opposite of every other coordinate here. A
  source reporting a real position must leave `locSource` unset or name
  itself; tagging one `'prefix'` gets its coordinate discarded.

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
  getExportTypes?(args: {}, ctx): Promise<ExportTypeDefinition[]>
  suggestExportOptions?(args: ExportOptionsRequest, ctx): Promise<ExportOption[]>
  generateExport(args: ExportRequest, ctx): Promise<ExportResult>
}
// ExportOptionsRequest: {operation, qsos, compactFilenames?}
// ExportOption: {exportType, exportKey?, format, label, filename?, icon?, color?, refType?, priority?, selectedByDefault?}
// ExportRequest: {operation, qsos, exportType?, exportKey?, compactFilenames?}  — full QSON, one coarse call
// ExportResult:  {filename, mimeType, content}
```

Two-step flow: the Exports Panel calls `suggestExportOptions` on every
`export` hook to build its selectable list (a hook that omits it never
appears in the panel), then calls `generateExport` — passing back the
chosen option's `exportType` and `exportKey` — only for the options the user
selected. The core owns file I/O and save/share; the hook only produces content.

`exportType` is the stable kind (for example `potaActivation-adif`); `exportKey`
identifies an individual option within the hook (for example
`pota-adif:US-1234`). Options sharing a type must have distinct keys. Omit
`exportKey` for a single option of a type: selection and generation default
it to `exportType`. Both values round-trip unchanged when an explicit key is
provided; the core does not interpret them. Selection also includes the
hook key and station callsign, keeping different hooks and stations independent.

Exporters should compose per-QSO program fields from `adifFields` hooks (see
below) rather than knowing about specific activities. Implemented by the whole-log `adif` exporter, activity exports, and contest
ADIF/Cabrillo exporters.

**Registering types and settings.** `getExportTypes` runs without an operation,
so Settings can list types even before the operator has a matching log:

```ts
async getExportTypes() {
  return [{
    exportType: 'potaActivation-adif',
    activationType: 'potaActivation',
    format: 'adif',
    label: 'POTA',
    defaults: { includePrivateData: false, includeLookupData: true },
  }]
}
```

Prefer `<activationType>-<format>` to an extension-key namespace. Two
extensions offering that type share one settings entry. The highest-priority
registration supplies its definition; other exporters using it must honor
that contract. Distinct sponsor requirements can use a distinct type. The
SDK's `exportTypeDefinition(activationType, format, label, defaults?)` builds
the conventional definition; the activity and hunting helpers register their
own types. An exporter without `getExportTypes` still works, but does not
appear in the export settings list.

`ExportSettings` contains `includePrivateData`, `includeLookupData`,
`customTemplates`, `filenameTemplate`, `compactFilenameTemplate`,
`titleTemplate`, `adifNotesTemplate`, `adifCommentTemplate`, and
`adifQslMessageTemplate`. All are optional. Defaults resolve from the SDK,
then global preferences, then the type's declared defaults.
`GlobalExportSettings` adds `referenceFilenameTemplate`,
`referenceCompactFilenameTemplate`, `referenceTitleTemplate` and the matching
`other…` fields. A type with `templateCategory: 'reference'` uses the reference
set; other types use the other set. The activity export helper registers
reference types automatically. ADIF field templates remain common to both sets.
Saved common filename/title defaults remain fallbacks for categories without
an explicit setting. Per-type data
choices override those; per-type template overrides apply only when
`customTemplates` is on. Empty templates intentionally suppress text. Turning
custom templates off preserves the operator's edits for later. Non-ADIF
formats expose only the filename templates and their custom-template switch.

Type definitions may supply `templateSample: {operation, log}` for representative
editor examples. Each format supplies its own filename extension in the sample.

An option can supply `qsoCount` when its hook further filters the contacts
(for example, a hunter export). Otherwise the host derives the count from
activity and station scope. Filename and title templates use this count.

Options can carry `templateData: {ref, refName, activity, modifier, ...}`,
which populates the `log` namespace. The app renders filenames and titles
before showing the option, and passes the same `exportSettings`, `exportData`
and `exportTitle` to generation. It also passes the resolved
`includePrivateData` and `includeLookupData` for ADIF. Forward those fields
when delegating through `adifForExport`, or a program's preferences will not
reach the ADIF writer. Settings apply globally and per type, never per operation.
The whole-log ADIF defaults to including private data, but its type setting
can override that default.

**How a row looks.** `refType` names the activity the export covers — the
core slices the file's QSOs by it, and the panel takes the row's icon and
accent colour from that activity's own control, so a contest's file is
recognisably the contest's without saying anything about glyphs. `icon` and
`color` override that, and are how an export that claims no activity — the
whole-log ADIF — asks for a glyph of its own instead of borrowing one. An
`icon` name that doesn't resolve falls back to the activity's, same as an
unreadable `color` does.

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

`registerHook` takes the type alone. The **qualified** `ref:<type>/<code>` form
is a manifest claim, not a category — it tells the host which legacy reference
an extension answers for so it can rewrite one (docs/extensions/README.md), and
registering a hook under it would register a category nothing ever invokes.

```ts
interface RefHandlerHook {
  validateRef?(args: { ref: Ref }, ctx): Promise<{valid: boolean; normalized?: string}>
  decorateRef?(args: { ref: Ref }, ctx): Promise<Ref>   // may hit the network
  suggestOperationTitle?(args: { ref: Ref; operation }, ctx): Promise<TitleSuggestion | null>
  linkForRef?(args: { ref: Ref }, ctx): Promise<RefLink | null>   // {url, label?}
  geojsonUrlForRef?(args: { ref: Ref }, ctx): Promise<RefGeojson | null>
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

`linkForRef` says where a reference can be read about on the web — the
program's own page for it (POTA's park page, SOTA's summit page), or, for a
contest, the rules the event is run under. The Operation Setup sheet asks for
one link per ref every time the operation's refs change and renders a web
button on the row; **nothing is stored on the ref**, so a program that moves
its URLs takes effect with the extension rather than needing saved operations
rewritten. Build the URL from the reference and return: this hook must not hit
the network. Return `null` for a reference the program would not accept (a
half-typed code links to a page that cannot exist) and implement nothing at all
for a program whose list is a download with no page per reference — a link into
a search form is worse than no link, and the row simply shows no button.
`label` names the destination for assistive technology, wrapped in the app's
own localized phrasing — set it only where the destination is NOT the row's own
subject, as a contest's rules are; leave it off for a reference's own page and
the app names the row instead. A handler registered for another program's ref
type (WCA answers for `ecaActivation`) must leave it off: a label built from
its own program name reads the wrong program aloud. Programs built on the SDK's `referenceActivity` factory get this
from one `linkUrl` config line.

`geojsonUrlForRef` says where the reference's own footprint can be fetched as
GeoJSON — a SOTA summit's activation zone, and whatever equivalent another
program publishes. Same contract as `linkForRef`: build the URL from the
reference, **never hit the network**, return `null` for a reference the program
has no shape for. The core does the fetching and the caching (`GeoshapeService`),
so an extension never decides how long a device keeps a file or how large one may
be; it only names the two ages the core should use:

```ts
// RefGeojson: {url, maxAgeInDays?, missMaxAgeInDays?}
```

`maxAgeInDays` (default 30) is how long a fetched shape stays usable offline —
boundaries move on the scale of surveys. `missMaxAgeInDays` (default 1) is how
long the core remembers that a reference has NO shape, deliberately shorter so a
newly surveyed zone appears within a day rather than a month. Both are ignored
unless positive: a zero would re-fetch on every rebuild of the map.

The URL must be `https`, and the core does not follow redirects to reach it.
Unlike a link, this one is fetched rather than handed to the platform, and a
plaintext one — named outright, or arrived at through a `Location:` header —
would downgrade every activator's connection on a program's say-so.

Shapes are asked for sparingly: the Map tab asks about the operation's own
references, and the Activities pane's results map about those plus the one
suggestion whose card is open. Neither fetches a shape per search hit — a search
answers with dozens of references, and at the zoom that shows dozens of them a
footprint is a few pixels across. Implemented by: `sota` (both types, via
SOTLAS's `az.sotl.as`, used with the operators' permission).

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
// SuggestArgs: {operation, location?: {lat, lon}, callsign?, searchTerm?, scoped?}
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
// mismatch tints the field but still accepts the value — a `refList` segment
// that fails it becomes a ref like any other, and reaches the log and the
// exports as typed. The pattern is HaLo's idea of the program rather than the
// program's own, so it may never cost the operator a reference.
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
it in the Activities picker, the icon itself once a reference is entered
in the logging panel's secondary pills, or the reference icon on a spot row
whose ref is of this control's type. Missing or unrecognized values just
mean no accent.

`processQsoBeforeSave` is the last chance to shape a QSO before it is written,
for projecting data the extension owns into the generic QSON fields the rest of
the app reads. A contest keeps its exchange on its own ref (`theirZone`,
`theirSerial`, …), which nothing generic knows how to read — mirroring it into
`their.exchange` is what fills the QSO row's exchange column and a plain ADIF
export. A contest whose sent exchange changes per QSO (a serial) mirrors that
into `our.exchange` too, and the column shows it ahead of theirs, in the RST
cell's order — keep it to the part that varies, since it repeats on every row.
Return a PATCH, not a mutated QSO: it merges shallowly except `our` and
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
extension may honor either, both, or neither (returning `[]`). `scoped` is
true when THIS extension alone was asked — the operator tapped its "Activity
Types" row or typed its key as a scope — which a bare scope otherwise cannot be
told from the nearby list, since neither carries a `searchTerm`. An extension
that keeps itself out of the nearby list (`cwt`, offered only around a session)
answers a scoped call anyway: it is the one being asked. The core fans
out to every `activity` hook via `invokeHookAll`, merges results, and ranks them
in TWO BANDS (`app/lib/tools/activity_suggestions.dart`): everything carrying a
`distance` first, by `distance / relevance` ascending — a more relevant hit
counts as nearer — then everything without one, by DESCENDING `relevance`, with
ties broken on the order the extension emitted them. So `relevance` alone orders
a set of placeless suggestions (dated contest events, say) among themselves, but
never lifts one above a located park. Implemented by: `pota`, `sota`,
`stateparks`, `cwt`.

**A scoped search offers the reference the operator typed, listed or not.** The
reference programs (`pota`, `sota` and every one built on `referenceActivity`)
answer a scoped search with the typed code itself when no row matched it —
named `unknownReference` where it fits the program's pattern, `invalidReference`
where it does not. The search is the only way onto the operation, so a program
whose list is stale, or whose pattern this app has wrong, would otherwise answer
a reference the operator was handed on the air with "no results". The scope is
what keeps the MALFORMED half of that narrow: unscoped, every enabled program
would answer any text at all with an invented reference of its own, burying the
real matches. (A well-formed code needs no scope — POTA has always offered one,
since only that program's own pattern can accept it.) A search term that is not
code-shaped is left alone either way: a single word is how a park or summit gets
looked up BY NAME, and `pota: beersel` must not answer with an invented BEERSEL.
The row is marked, and the reference is stored, logged and exported as typed —
the same rule ADIF import follows for a malformed `*_REF` (below).

The activity search box also treats a leading scope word as a scope — typing
`pota:` (or tapping a row under "Activity Types") asks the extension serving
that reference type alone, via a key-scoped `invokeHook` rather than the usual
fan-out. The word is the **reference type's base name**, lowercased —
`potaActivation` and `pota` both scope as `pota:` — never the extension key: a
user-published `ki2d-pota` serving `potaActivation` is still scoped as
`pota:`, since the operator is adding POTA parks whichever extension supplies
them. Two enabled extensions serving one type share the word, and the scoped
search asks both. For the hook call to reach the extension, its `activity`
hook must be registered under its own **extension key**, and its control
descriptors keyed `<extensionKey>/<name>` (`pota/activation`) — the core
derives the hook key from the part before the slash. An extension that
deviates simply never gets scoped: its rows still add references, but the
scope would ask a hook that doesn't exist and come back empty.

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

**Only the export's OWN hook is asked.** A file submitted to one program is
that program's log, so an export that delegates the ADIF build names itself as
`mainHandler` in the `ExportRequest` — app-polo's "main handler"
(`qsonToADIF`'s `handler`) — and the `adif` extension invokes that hook alone,
not the whole category. Activate a park that is also a lighthouse and each
file claims its own reference; ask every hook and both programs'
`MY_SIG`/`MY_SIG_INFO` pairs land in every record, leaving the receiving
program to guess which is its. The delegate cannot work out who called it, so
naming yourself is not optional.

The full ADIF export names no `mainHandler` and every hook contributes —
polo's `includeOtherRefs`, which only its full export sets. That is the export
claiming no program: the complete copy the operator keeps.

An export can also name a **list** of other hooks it accepts,
`includeFieldsFrom` — polo's all-or-nothing flag narrowed to what the program
itself says it reads. It is for what DESCRIBES a contact rather than claiming
it: POTA's exports list `satellites`, because a park worked through a bird is
still a park activation and POTA's uploader reads `PROP_MODE`/`SAT_NAME`. A
listed key that answers nothing is fine — the operator may have that extension
off — where a `mainHandler` that answers nothing is an error, since that file
would claim no reference at all.

**A field name is written once per record, and the first to carry a value
wins.** ADIF gives no meaning to a repeated field, so where two hooks answer
the same name — the full export asks everyone, and a park and a summit both
answer `MY_SIG` — the later one is dropped, and the contact's own fields
outrank all of them. Hooks are asked main handler first, then each
`includeFieldsFrom` key in the order given, so that order decides — whichever
of the two methods each hook answered. app-polo resolves a collision the same
way ("keep the first one defined"). The **full export**, which asks everyone,
has no such order: hooks answering `fieldCombinationsForOneQSO` are asked as one
group and hooks answering `fieldsForOneQSO` as another, so which of two programs
keeps a shared `MY_SIG` there is not something either of them chose.

Because the winner is picked per field name, **answer a pair whole or not at
all**: a hook offering `MY_SIG` without `MY_SIG_INFO` takes the name and leaves
the next hook's reference under it, which claims another program's park for
yours. `custom` is the one activity whose two halves are free text, and it
drops both when either is empty.

## ✅ `adifImport` — per-QSO reference recovery on import

The inverse of `adifFields`. The core's ADIF parser
(`packages/halo_core/lib/src/adif/`) maps **universal ADIF only** and produces
**no references at all** — `SIG`/`SIG_INFO`, `SOTA`, `IOTA`, `CONTEST_ID` and
every `*_REF` field mean nothing to it. This hook is the entire ref vocabulary
on import, not a refinement of a core guess. An import with no `adifImport`
hook registered yields ref-less QSOs.

```ts
interface AdifImportHook {
  refsForRecords(
    args: { records: { fields: Record<string, string> }[] },
    ctx: HookContext,
  ): Promise<({ refs?: Ref[] } | null)[]>
}
```

`fields` is the record's raw ADIF, names lowercased and values entity-decoded.

**Batched, unlike every other per-QSO hook.** `adifFields` is called by the
`adif` extension *inside the runtime*, so a call per QSO costs nothing there.
This one is driven from Dart (`app/lib/services/adif_import_service.dart`), so
each call is a bridge crossing — a ten-thousand-contact import is twenty
crossings, not ten thousand. Batch size is 500.

Return **one entry per record, positionally**; `null` for a record the hook has
nothing to say about. Never filter the empties out: the core matches results
back to records by index, and a shortened array would land one QSO's references
on another. A reply whose length doesn't match the batch is discarded whole for
that reason. Refs from different hooks accumulate (a park-to-park contact made
during a summit activation legitimately carries both), deduped by `type`+`ref`.

A returned ref may carry **`for: 'operation'`** to say it belongs on the
operation rather than the QSO — an activation. ADIF has no operation, so it
writes the activation onto every record, and a hook only ever sees one record;
tagging is how it says where the reference actually goes. The importer moves it
and **consumes the tag**, since once the reference sits on the operation its
position is the answer. Untagged means the QSO. Without this the only test
available to the importer is "every record carries it", which cannot tell an
activation from a short log where everyone hunted the same reference.
`activityAdifImport` tags the activation side for you.

Returning an object rather than a bare `Ref[]` leaves room for the other things
an importer may eventually owe a QSO — a contest serial out of `STX`/`SRX`,
an exchange — as an additive change.

Most reference programs write the same `SIG`/`SIG_INFO`/`MY_SIG`/`MY_SIG_INFO`
pair plus their own comma-separated `*_REF` list, so the SDK's
`activityAdifImport({sig, huntingType, activationType, refField, normalize})`
builds the whole hook.

**A reference the program's own pattern rejects is imported anyway**, as
written. By the time `normalize` runs, the file has already said whose the
reference is — the `*_REF` list field is program-specific, and `SIG_INFO` is
gated on `SIG` — so a pattern failure means *malformed*, not *foreign*.
`decorateRef` labels it invalid, which puts it in front of the operator to fix;
discarding it would lose the only text a correction could work from, and lose it
without a word. `normalize` still repairs what it can (POTA turns a dashless
`us1234` into `US-1234`); only its failures fall through as raw text. The same
rule governs `satellites`, which imports a bird it cannot resolve to a
transponder rather than dropping the QSO's satellite.

It reads **both** sources and merges them, deduped on the normalized value.
Neither subsumes the other: `*_REF` lists every reference but not every program
writes it (SOTA's own exports carry `SOTA_REF` and no `SIG` at all), while
other software writes the same reference only as `SIG`/`SIG_INFO`. The union is
safe *because* it dedupes — taking `SIG_INFO` in preference to the list would
import an n-fer as a one-fer, since `SIG_INFO` names only the primary
reference; taking both cannot, because the primary is already in the list. The
`SIG` value is still checked before `SIG_INFO` is claimed, or every program
would import every other program's references.

`referenceActivity()` returns a ready-built `adifImportHook` from the config it
already has, so an activity using that factory opts in with one `registerHook`
line. Implemented by every activity except two:

- **`satellites`** writes `SAT_NAME`/`BAND_RX` and no `SIG` at all, so it
  hand-writes its own. Its reference is a *transponder* while ADIF names only
  the bird, so the hook recovers the transponder where it can — narrowing by
  `BAND_RX` (the downlink) and the record's own `BAND`/`FREQ` (the uplink) —
  and otherwise imports the bare satellite the file named. It validates
  nothing: an unknown bird, a contradictory `BAND_RX` and a record with no band
  all import. The reference degrades cleanly, since `decorateRef` falls back to
  the whole string and the exporter writes `SAT_NAME` from the same segment.
- **`custom`** deliberately registers none. Its `SIG` is a program name the
  *operator* typed, so there is no constant to match, and a hook claiming every
  `SIG` would add a spurious reference to every other program's records.
  "Claim the `SIG`s nobody else claimed" is the rule that works and it is not
  expressible in a hook — these run independently and additively, so none can
  see what the others took. It belongs to the importer.

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
// CommandAction (closed set): {setVfo?, setPower?, updateQso?, addQso?,
//   setKeyerSpeed?, showKeyer?, setEnterSends?, sendSpots?, syncAll?, updateSettings?, updateSetting?, openSettings?,
//   updateOperation?, markSegment?, setCallField?, reloadDataFiles?, devNotice?, devStatus?,
//   devProgress?, devHammer?, devSplash?, devOnboard?, devTester?, devPopup?,
//   devTimeTravel?, toggleExperiment?}
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
exercising that UI without a real extension driving it; DEVHAMMER
(`devHammer`) churns the footer the way a data-file sync does — items
appearing, ticking and clearing — which is what provokes the web engine into
blurring a focused text field, and which the real thing only does on a cold
profile; DEVSPLASH re-shows
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
action field — the hook parses "EXP <key-or-alias>" and resolves the token
against `ctx.experiments` only for its preview ("Enable"/"Disable"); the app
resolves it again when it flips the state and reports the outcome, since the
stored per-experiment state lives app-side;
DEVTT/DEVTIMETRAVEL move the app clock via the `devTimeTravel` action field —
"DEVTT +3h", "DEVTT -1d", "DEVTT 2x", bare "DEVTT" to return to real time — so
anything that turns on the date or on elapsed time can be tested without
waiting for it. The hook only parses, and only while developer mode is on; the
app applies the offset, refuses it against a real sync account, and reports the
resulting time. Deliberately the one command here with NO `catalog`, so it can
never surface in the palette (docs/design/time.md)),
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
expands a Callsign Notes entry whose note — once a leading heading OR emoji
marker (never both) is stripped — is a plain comma list of calls into the
call field via `setCallField` — issue #17; the call field explicitly excludes a field
STARTING with "//" from call stacking, or a note key that's itself a valid
callsign would also read as a stacked call, so the two syntaxes coexist. A key
stacked ALONGSIDE other calls reaches this hook too, but never as a whole-field
command: the call field asks again with just the segment under the cursor
("//1AB") and splices the answer back into that segment, so the hook itself
needs to know nothing about stacks. See
[logging-fields.md](../design/logging-fields.md) § "More than one call in the
field" for the order Enter resolves the two syntaxes in).
Future command hooks (spotting, operator change…) register in the same
category and compete on priority with these.

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

## ✅ `template` — rendering on the app's behalf

The Liquid renderer (templates.md) lives in the SDK and runs only inside the
extension runtime. A Dart-side surface that wants a template filled in — a
CW message about to be keyed (docs/design/cat.md § CW keying) — reaches it
through this hook, registered once by the core `templates` extension under
the key `templates`:

```ts
interface TemplateHook {
  render(
    args: { template: string; operation?; qso?; qsoCount?: number },
    ctx,
  ): Promise<{ text: string } | { error: string }>
  // Several templates against one context in one crossing (the keyer
  // area's button labels): one result per template, in order.
  renderMany(
    args: { templates: string[]; operation?; qso?; qsoCount?: number },
    ctx,
  ): Promise<{ results: ({ text: string } | { error: string })[] }>
}
```

`operation` and `qso` are the same objects a `panel` hook's `render` gets,
and the result is built with the same `templateContext`, so a placeholder
means the same thing wherever the app renders it. A template that does not
parse comes back as `error` carrying the renderer's own message — a typo in
a message the operator typed, to show them, not a bridge failure to report.
The app calls them as `ExtensionService.renderTemplate` and `renderTemplates`.

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
results are namespaced per scorer. An `'always'` scorer is the **lowest priority
on the worked-before axis**: for a QSO some other scorer has judged on that axis
— a verdict carrying `dupe`, a `duplicate` alert, or a
`newBand`/`newMode`/`newDay`/`newRef` notice — the host drops the `always`
scorer's own `dupe`, `duplicate` and those notices, so core's call+band+mode
rule never contradicts an activity's. What core alone reports — `newDXCC`,
`newState`, `newProvince` — always survives, and a verdict that says nothing
about a prior contact (`invalidBand`, `missingExchange`, a bare `{value}`)
displaces nothing: core's dupe warning is then the only one there is.

So emit `dupe` whenever your dupe test actually ran, `dupe: false` included —
that is what tells the host you have ruled on the question. It travels on the
live paths too (`scoreQso`, `scoreCandidates`), not just in `qsoScores`. Rule
only on what you have seen: a scorer folds only the segments it was running
for, so a station absent from YOUR history may have been worked in a stretch
you skipped, and staying silent there hands the question to the scorer holding
the whole log. And when your
verdict means "worked before, and this one counts anyway", say it in one of
those notice keys (`newPark` is state-parks' spelling of `newRef`) rather than
inventing a spelling of your own: an unrecognized key leaves core's `duplicate`
standing beside your credit, on the one row that can show only one.

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
//   qsoScores: Record<uuid, QsoScoreVerdict>,   // one per QSO claimed; see above
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
A candidate that carries no `startAtMillis` (the draft's time is still
automatic) reaches the scorer stamped with the current time on both live
paths, so a day-bucketed rule judges it as of now rather than at the epoch; a
candidate that states a time keeps it.
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

`linkClient` must NOT mail anything. The core shows the challenge code on
screen and offers the email as a separate choice, so a transport that mails
here sends a confirmation nobody asked for — and one more on every renewal,
since an expiring code re-requests through this same call.
`linkClientWithEmail` is the call the operator reaches by choosing the
email over the code, and the only one in this seam that mails. A server
that mails by default (LoFi does) has to be told not to.

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

## ✅ `panel` — panes an extension contributes to a view

A panel is a PANE the operator can put in a customizable view's layout
(docs/design/layouts.md), listed in Layout Setup alongside the app's own
QSOs / Info / Spots / Map. One extension may declare several, each with its
own identity, config form and refresh budget.

```ts
interface PanelHook {
  getPanels(args: {}, ctx): Promise<PanelDescriptor[]>
  render(args: PanelRenderArgs, ctx): Promise<PanelContent>
  onEvent?(args: PanelRenderArgs & {event: PanelSceneEvent}, ctx): Promise<PanelSceneEventResult>
}
// PanelDescriptor: {key, title, description?, icon?, preview?, on?, form?}
// PanelRenderArgs: {panelKey, operation, qso?, qsoCount, config, reason}
// PanelContent:    {kind: 'markdown' | 'svg' | 'html', content, title?, triggers?}
```

The host addresses a panel as `ext:<hookKey>:<key>`, and that id is stored
inside saved layouts — renaming a `key` drops the panel out of every
arrangement holding it.

An experimental fourth kind, `svgScene`, adds native SVG layers, numeric bindings,
local controls, and host-run animations. Its payload is `{kind: 'svgScene', scene,
title?, triggers?}`; it does not have a `content` string. Scene-capable hosts pass
`instanceId` on render/event calls. `onEvent` handles control events and returns
numeric value patches; local-only controls and animation frames make no bridge
calls. Controls with `continuous: true` send `change` events during dragging and a
final `commit` on release; pending movements are coalesced to the newest value.
Numeric text supports `scale`, `truncate`, `modulo`, and `minIntegerDigits`
for local numeric formatting; bindings accept `scale`, `truncate` and `modulo`
too, applied to the value before the ramp. KI2D’s Radio Panel uses these for its Modern
frequency groups; its settings offer Modern/LCD styles and radio selection. Local sliders may use `hover` and `discrete` hourly buckets. Text `samples`
may hold numbers or preformatted strings; control `valueLabels` supplies accessible
value descriptions. Transform/opacity bindings may also supply numeric `samples`,
equally spaced over their `input` range, instead of the `output` ramp. The host
interpolates and clamps these locally; chart markers and callouts can follow
individual readings without bridge calls. See [the design notes and open milestones](../design/svg-scenes.md)
and the `k2hrc-svg-scenes` sample. This API is experimental.

Scene-capable hosts also supply `args.environment` on **render and event** calls:

- `width`, `height`, and `safeInsets` describe the current panel in logical pixels.
  The app's Font Scale is already applied to this coordinate space. Do not multiply
  coordinates by a font-scale preference or `devicePixelRatio`.
- `brightness` is resolved to `light` or `dark`, including system theme changes.
  `colors` contains `surface`, `surfaceContainer`, `onSurface`, `onSurfaceVariant`,
  `accent`, `primary`, `onPrimary`, `secondary`, `outline`, `outlineVariant`,
  `error`, and `onError`, all `#RRGGBB` strings.
- `typography` contains `body`, `label`, `title`, `display`, and `mono` roles, each
  with `fontFamily`, fallbacks, `fontSize`, `scaledFontSize`, `fontWeight`,
  `lineHeight`, and `letterSpacing`. Family can be null for a platform default.
  `scaledFontSize` describes OS accessibility scaling **at that role's size**;
  do not assume one linear factor for all sizes. Use it when reserving label space.
  Supply the unscaled `fontSize` as scene text `size`: the host scales text once.
- `locale`, `textDirection`, `devicePixelRatio`, `reducedMotion`, and `highContrast`
  describe the resolved presentation context. Font names refer to host fonts;
  they are not URLs or permission to load remote fonts.

For a panel showing an `svgScene`, environment changes automatically request a
render through the existing throttle, even with no triggers declared. Hidden
panels catch up on reveal; repeated resize updates coalesce; a scene laid out for
an old environment cannot overwrite a newer one. Markdown and HTML panels are
themed and laid out by the host, so an environment change does not re-render
them; their next render carries the current environment.
`args.clock.nowMillis` follows the app clock; `realNowMillis` is for network retry
and cache budgets, so developer time travel does not hammer an external API.
Both `environment` and `clock` are optional in the SDK for older-host detection.

Use scene **text layers** for typography; SVG `<text>` is not a portable text path
through the renderer. Text supports either `literal` or bound `value`, plus
`fontFamily`, `fontWeight`, `lineHeight`, and `letterSpacing`. Text participates
in native directionality, accessibility scaling and semantics.
Button controls can supply `menu: [{label, event}]` to open a native dropdown.
Selecting an item emits its `event` as the action with the original control ID;
dismissing the menu emits nothing.

The `ki2d-weather-panel`, `ki2d-solar-panel` and `ki2d-radio-panel` reference
panels live in
[ham2k/extensions](https://github.com/ham2k/extensions/tree/main/extensions/dashboard).
They use public host APIs and ship as `.h2kext` packages, not app assets.
Install the packages, then add their panels through Edit Layout. See that
repository's dashboard README for building them.

The radio host calls are manifest capabilities, refused unless declared — the
same shape as `requiresLocation`, and shown to the operator at install:
`"requiresRadioRead": true` allows `host.listRadios()` and `host.readRadio()`;
`"requiresRadioWrite": true` allows `host.tuneRadio()` and
`host.setRadioConnection()`, and implies read, since a command answers with the
radio's state. An undeclared call rejects rather than answering null.
A capability belongs to the bundle that declared it, and to the sub-extensions
that bundle defines under its own key. A separately installed bundle never
inherits one through its name: `rigpanel-themes` gets nothing from `rigpanel`.

An `onEvent` that cannot read its panel's config is refused rather than run
with an empty one, since a config is where a panel keeps which radio it
commands. The host allows an event up to about ten seconds in all (config, then
the hook); the control shows its pending value until the outcome is known.

**KI2D’s Radio Panel** is the CAT reference extension. `host.listRadios()` lists configured
local transceivers. `host.readRadio(id?)` returns
a **local** radio's reported frequency (Hz), mode, connection state,
power, TX state and fresh telemetry, or null on hosts without this API.
`meters.signalDbm` is receive power in whole dBm when supported, refreshed a few
times a second; it expires after two seconds without a reading. The Flex driver receives the selected slice’s LEVEL
meter through its native UDP channel. The reference panel draws a segmented
receive meter and leaves it unlit when unavailable, stale, or transmitting. It does
not substitute the app's manually entered VFO for a radio reading.
`host.tuneRadio({id, frequencyHz?, mode?})` targets that same radio through the
existing VFO/CAT service. Supported mode requests are LSB, USB, CW, AM and FM.
The host rejects a changed designation, disconnected/stale radio, transmission
in progress or malformed command, and spaces accepted tuning requests by at
least 250 ms. Omitting a selection follows the designated logging radio; an explicit `selection`
pins tuning to that local radio without changing the logging designation.
An accepted result means requested, not confirmed; only subsequent
reported state confirms it. Drivers retain their own protocol/echo handling.
`host.setRadioConnection({id, selection?, connected})` starts or ends a local CAT
connection using the same selection and identity checks. Acceptance starts the
operation; follow reported connection state for completion. It does not switch
the hardware's mains power or initiate transmission. The reference panel samples
state once per second while visible; knob motion and LCD digit updates run locally,
and tuning is sent continuously during dragging, paced by the CAT adapter. The
main readout follows the requested value immediately; confirmation status distinguishes pending requests from the radio
reporting the requested frequency. Radio-specific hardware verification remains
necessary before considering the experimental control API stable.

**Content is a document, not widgets** — the same UI-catalog seam every
other declarative hook sits behind. Prefer `markdown`: it renders with the
app's own typography, theme, font scale and density, and costs no web view.
`svg` is drawn as a vector image. `html` is the escape hatch and runs
sandboxed: **no JavaScript, no network for subresources (inline what you
need as a `data:` URI), and no navigation** — a link the operator taps opens
in the OS browser; one the document triggers itself is blocked. The
no-network half is enforced by content blockers on Apple platforms and
`blockNetworkLoads` on Android; a platform whose web view honours neither
still gets no scripts and no navigation, so treat "no network" as a rule
your panel must follow rather than one it is held to everywhere. HTML
panels do not render at all where there is no web view (Linux, and Windows
without the WebView2 runtime) — the pane says so. Nor on the web build, where
one exists but is an iframe whose sandbox grants top-level navigation and
popups: the no-navigation rule above is the one part a panel cannot be trusted
to keep on its own, so the pane refuses rather than render under it.
`markdown` has none of these caveats, which is the other reason to prefer it.

**`on`** is a refresh budget, not a subscription: `'operation'`,
`'qsoLogged'`, `'spots'`, `'lookup'`, `'qso'`, or `` `tick:<seconds>` ``
(one second is the fastest; anything below it is not a recognized trigger and
is dropped with a line in the console, so the panel gets no tick at all). The host
keeps at least 750ms of idle between one render FINISHING and the next
starting — a gap, not a period, so a slow panel simply runs less often
instead of monopolising a single-threaded runtime. A tick that arrives while
a render is already coming is DROPPED rather than queued: another is aimed at
the next boundary, and the render that is coming reads fresh context anyway.
Everything else waits instead of being dropped. Ticks are aimed at wall-clock
boundaries, so panels sharing a period render in the same frame. The host
renders nothing while the panel is behind another dock tab, or while the whole
app is hidden — an unselected tab stays mounted, so without that a four-panel
layout would pay for the three nobody is looking at. A trigger that arrives
while the panel is away is remembered, and the panel renders once when it
comes back. Do not treat the first render as something that happens at mount:
a panel placed on a tab nobody has selected is not rendered until that tab is,
so one-time setup belongs in the hook's own initialization, not in a render. A trigger name outside this list is dropped when
the panel is read, with a line in the console: it would otherwise sit in the
descriptor looking live and never fire. A descriptor with no `on` renders once when it
appears. Omitting it is the right default: a trigger costs a bridge call
every time it fires.

`'qso'` is the expensive one. `args.qso` is the whole QSO being composed —
every field, in QSON, as it would be logged — and it changes as fast as the
operator types. The host debounces it to one wake per pause and stops
producing it entirely when no panel in the arrangement asked, but a panel
that wants only the resolved callsign should declare `'lookup'` instead: it
fires when a lookup is ANSWERED, not while a call is being typed, and the
guess is inside `args.qso` either way — declaring `'lookup'` is enough to be
sent the draft, so what it saves over `'qso'` is renders, not the QSO.

`'lookup'` fires when the panel is shown a callsign that HAS an answer —
which includes opening a QSO whose stored record already carries one, not
only a fresh lookup resolving. It does not fire when a lookup starts, fails,
or times out. A panel keyed to it alone cannot tell "still looking"
from "no answer coming", and will sit on whatever it last drew. A panel that
needs to show either state wants `'qso'` too, and should read
`qso.their.guess` to decide which it is looking at.

**`form`** declares the panel's own configuration in the same field schema
a Tier 1 `settingsPanel` uses ([settings.md](./settings.md)), rendered by
the core's `FormRenderer` and reached from the gear beside the panel in
Layout Setup. Values are host-persisted per panel and handed back as
`args.config`; there is no per-keystroke bridge call and nothing for the
extension to store.

**`multiple`** lets an operator place more than one of your panel. Off by
default, because most panels are one thing — two maps or two spot lists would
be a mistake to offer. Set it where two is the point: a panel whose content
is the operator's OWN, like `custom-text`'s notes.

Each placement gets its own id and therefore its own config, so `args.config`
differs per pane with nothing to do on your side. What you DO owe an
instanceable panel is a `title` on the render result — without one every pane
reads the same descriptor title and the operator cannot tell them apart.

**`preview`** is a still image for that same list — an SVG document or a
`data:` URI, never a URL: the list renders offline, and a remote preview
would make opening it a fetch (and a beacon).

A render result may carry a **`title`**, which replaces the tab label for
that pane. Blank is ignored rather than producing a nameless tab, and a
result with no title keeps the descriptor's.

A render result may also carry **`triggers`** — the same names as `on`,
added to the descriptor's for THAT PLACEMENT only. `on` is per panel and so
is paid by every pane of it; this is per pane, and exists for panels whose
content is written by the operator: `custom-text` derives its triggers from
the template in each pane (`triggersForTemplate`), so a pane showing a band
plan renders once while the pane beside it, naming the callsign being typed,
gets woken per keystroke pause. Unknown names are dropped with a line in the
console, exactly as in a descriptor.

The declaration necessarily lands AFTER the render that carried it, so a
panel asking for `'qso'` this way is answered without one the first time and
woken by the next change to the draft. Declare in `on` instead when the
panel always needs the signal — a descriptor's triggers are in force before
its first render.

The whole log is deliberately absent from `render`'s args. A panel that
needs it calls `ctx.getQsos(operation.uuid)` — right for a `'qsoLogged'`
render, wrong for a per-keystroke one.

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
`app/lib/views/settings/accounts_panel.dart`).

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
`HookContext.edition` below). SOTA is the one such hook: every edition
authenticates as the SAME Keycloak client, and what varies is the redirect
URL — `com.ham2k.logger.<edition>.auth://sota`, one per edition, each
registered against that one client.

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
