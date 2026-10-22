# Hook reference

Hooks are registered under a **category** with an optional **key** (defaults
to the extension key) and **priority** (higher runs first; default 0). The
host invokes them three ways:

- `invokeHook(category, key?, method, args)` — best (highest-priority) hook.
- `invokeHookAll(category, method, args)` — every hook in the category, one
  bridge round-trip, per-source error isolation.
- `invokeHookBatch(calls)` — several `invokeHook` calls, one bridge
  round-trip, per-call error isolation. Each call reaches the same hook it
  would reach on its own, so a hook cannot tell a batched call from a single
  one.

The categories are a closed list. `registerHook` takes a `HookCategory`
([`extensions/sdk/src/hookCategories.ts`](../../extensions/sdk/src/hookCategories.ts))
or `ref:<type>`, so a misspelled category fails the typecheck rather than
registering a hook nothing calls, and the build rejects a manifest `hooks`
entry that is neither. A new category goes into that list — and, when the host
calls it, into the host's catalog as well
(`packages/halo_core/lib/src/hook_names.dart`).

In both shapes that answer many hooks at once, one hook failing costs its own
entry and nothing else — whether it throws, has no handler, or answers
something JSON cannot carry (a circular object, a `BigInt`). One that runs out
of time does too, when the caller asks for partial results; otherwise, and for
a batch of several calls that runs out of time before any answer has reached
the host, the whole call fails.

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
  hook the same extension registers (e.g. `radio-commands`' WPM command
  checks `keyer` here; its BAND/MODE/frequency siblings don't).
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
  simply has no QSOs yet). Every extension reads one copy of the log the
  runtime keeps, which asks the host only what changed since the last read:
  a call is never staler than itself, and the whole log crosses the bridge
  only the first time. Each call gets a new array. From extension API 9 its
  QSOs are that shared copy, frozen — a write throws, so copy what you mean
  to change; under an older `api` each call gets QSOs of its own.
* `getSpotsForCall?(call, maxAgeMinutes = 30)` — the spots the host has
  already fetched for `call`, no older than `maxAgeMinutes` (measured on the
  spot's own `spot.timeInMillis`, not on when it was fetched), newest first.
  Reads the host's cache and **never triggers a fetch**, so unlike the log
  reads above it is cheap enough for the lookup path; it resolves `[]`
  whenever the cache is cold or the host keeps no spots. Used by
  `spot-history` to pull a hunted park or summit into the QSO being logged.
* `host.suggestQso({qso, operationUuid?})` (extension API 12) — puts a
  station into the logging fields of the operation in front, as tapping its
  spot in the Spots Panel does: `qso.their.call`, and `freq`, `band`, `mode`
  and `refs` where given; nothing else of `qso` reaches the fields. With
  `operationUuid` — a panel's own `operation.uuid` — only that operation's
  fields, so a panel never fills a log the operator is not looking at.
  Answers `{accepted}`, false when no such operation is open. It tunes the
  radio as a tap does, so it needs `requiresRadioWrite`, and it is refused
  except from inside the extension's own panel `onEvent`: it answers the
  operator clicking something, never a timer or a render, which would
  overwrite what they are typing.
* `getSpots?(options?)` — the whole spots board the host already holds,
  for a panel showing spots its own way. Like `getSpotsForCall` it reads the
  cache and never fetches, and resolves `[]` while the cache is cold. By
  default it answers what the operator's Spots Panel shows: their sources,
  enabled bands, band and mode filters (an "auto" filter follows the radio),
  age and continents, merged and ordered as that panel does — so one spot
  can stand for several stations, its `their.call` comma-joined
  (`'K1ABC,W2XYZ'`). `filter: 'all'`
  starts instead from every held spot, one per source report, newest first.
  Either way `maxAgeMinutes`, `band`, `mode` (a mode, or `SSB`/`Phone`/`CW`/
  `Digital` for a family) and `source` (a spot source's hook key, carried on
  each spot as `hookKey`) narrow it further. Spots come back with
  `annotations` — `worked`, `isSelf`, `notices`, judged the way the Spots
  Panel strikes and accents its rows — whenever there is an operation to judge
  them against: `operationUuid`, or the `operation` the calling hook was
  handed, so a panel's render gets them without asking. The verdicts are the
  ones the app already holds for the operation open on screen, so the call
  never waits on a scorer; another operation's spots, and that one's until
  its first verdicts land, come back unannotated rather than guessed.
  From extension API 12 each also carries `display` — `icon` (an MDI or
  `fa-` name), `iconColor` (`#RRGGBB`, where the activity declares one) and
  `emoji` (the call's note emoji, where it has one): what the Spots Panel's row
  shows beside the call, the activity's icon and tint for the spot's first
  reference, else the source's own icon. `annotate: false` returns the spots
  as their sources gave them.
  A panel's `'spots'` trigger fires whenever this answer may have moved: a
  refresh, new verdicts, the operator's spot filters or bands, or the radio's
  band or mode. A malformed or unknown option rejects the call. The CLI host
  has no operator: its `'user'` board is every spot handed to it, never
  annotated.
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
`ham2k-call-history`'s `src/index.ts` in
[ham2k/extensions](https://github.com/ham2k/extensions).

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
  guess's clears all location fields (`locSource, lat, lon, grid, street,
  city, state, postal, county, country`) before merging the result in, and
  the guess adopts the more specific scope. `street` and `postal` are the
  mailing address's own lines, grouped with the town they complete so an
  address never puts one source's street on another source's town.
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
  clears street/city/state/postal/country/county unless the *same* result
  also supplies them. The converse clause — a town write clearing grid/lat/lon — can only
  sweep a leftover half lat/lon pair: the group rule above blocks a town
  from landing at all where a full pin already stands.
- `notes`/`history` are per-`CallInfoLookup` fields, not part of the merged
  `guess` — they simply accumulate, unconditionally, in the returned
  `lookups[]` array.
- **`cqZone`, `ituZone` and `tz` are the exception to first-answer-wins.** The
  pre-step can only answer them for a whole entity or call area (a W6 call
  reads CQ zone 3 wherever the station lives), so once every hook has run,
  a value the pre-step still holds goes to the first hook result that
  carried one (`preferStationValues`) — only while the guess's scope is
  `qth`, since on a portable or prefixed contact a source describes the
  home QTH. `tz` is a UTC offset with its ordinary sign, `"GMT-5"` being
  five hours behind. lib-country-files states it that way from 1.1; the
  SDK's `annotateCallAgainstCountryFile` answers with the ordinary signs
  whichever version the app ships, flipping an older one's west-positive
  `tz` and `lon`.
- **`locSource: 'prefix'` is reserved**, and a `lat`/`lon` merged under it is
  never read as a coordinate (`locationFromGuess`, halo_core). It marks
  lib-country-files' DXCC entity centroid, which synced records carry signed
  either way — west-positive from versions before 1.1 — with nothing to tell
  the two apart. A source reporting a real position must leave `locSource`
  unset or name itself; tagging one `'prefix'` gets its coordinate
  discarded.

- **A guess field of the wrong type is dropped.** The bridge enforces none of
  `CallInfo`'s declared types, so the app normalizes the answer
  (`normalizeLookupResult`, halo_core) before anything reads it: a field its
  readers cannot use — a numeric `continent`, a boolean `emoji` — is dropped
  and reported once by name, and the rest of the guess is still used. A
  numeric string where a number is read (`cqZone: '05'`) is taken as that
  number.

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
// PostResult: {ok, message?, userMessage?, skipped?}
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

A poster whose own rules decline a particular spot — a Discord channel whose
message template renders blank for it — answers `{ok: true, skipped: true}`.
Its icon stays neutral gray instead of lighting as sent, and no failure is
reported. The Spotting chip's color counts only the sources that did not skip.
When every one did, the chip stays neutral and the operator is told so, in
each source's `message` when it gives one; that spot is never what
auto-respotting repeats, and a round of it every source skips ends it.
`skipped` without `ok` is still a failure.

## ✅ `cluster` — the DX cluster connection

```ts
interface ClusterHook {
  onLines(args: { lines: ClusterLine[] }, ctx): Promise<void>
}
// ClusterLine: {seq, at, text}
// host.clusterSubscribe(): Promise<ClusterStatus>   // then onLines, until
// host.clusterUnsubscribe(): Promise<ClusterStatus> // this
// host.clusterLines({after?, limit?}): Promise<ClusterLine[]>
// host.clusterStatus(): Promise<ClusterStatus>
// host.clusterPostSpot({freq, call, comment?}): Promise<ClusterReply>
// host.clusterSend(command): Promise<ClusterReply>
// ClusterReply: {ok, lines: string[], error?, message?}
```

The app holds one telnet connection to the DX cluster node the operator picked
in Settings, logged in as the operator. Extensions share it rather than open
their own, because a node logs a call in once
([docs/design/cluster.md](../design/cluster.md)). Not on web, where every call
answers `error: 'unsupported'`. Extension API 10.

`clusterPostSpot` is how a `spots` hook posts to the cluster: the host builds
the `DX` command, sends at most 60 characters of comment, and spaces spots five
seconds apart. A reply with `ok: true` means the node took the spot without
refusing it. It does not prove the spot left that node: a DXSpider node can keep
a self-spot local and still echo it.

`onLines` is called only for an extension that called `clusterSubscribe()`,
with the lines since the last batch, at most once a second. Register the hook
under the extension's own key (the default): that is the key the host delivers
to. A subscription lasts until `clusterUnsubscribe()` or the runtime restarts,
and keeps the session open while it lasts. A reader that only polls
`clusterLines({ after })` holds nothing open.

Three manifest grants gate it, each including the ones before it:
`"requiresClusterRead": true` for status, lines and subscribing;
`"requiresClusterSpot": true` adds `clusterPostSpot`;
`"requiresClusterCommand": true` adds `clusterSend`, which sends any command in
the operator's name. Declare the least you need: the consent screen names it.
Implemented by: `ki2d-cluster-spotter` (spot).

## ✅ `export` — log file generation

```ts
interface ExportHook {
  getExportTypes?(args: {}, ctx): Promise<ExportTypeDefinition[]>
  suggestExportOptions?(args: ExportOptionsRequest, ctx): Promise<ExportOption[]>
  generateExport(args: ExportRequest, ctx): Promise<ExportResult>
}
// ExportOptionsRequest: {operation, qsos, compactFilenames?}
// ExportOption: {exportType, exportKey?, format, label, filename?, icon?, color?, refType?, ref?, priority?, selectedByDefault?}
// ExportRequest: {operation, qsos, segments?, events?, exportType?, exportKey?, compactFilenames?}  — full QSON, one coarse call
// ExportResult:  {filename, mimeType, content}
```

`qsos` holds contacts alone. The log's event rows — `break`, `start`, notes —
come separately in `events`, for a file that writes the timeline (the full
ADIF does, with private data); `segments` is what they resolve to.
`operation` carries `startAtMillisMin`/`startAtMillisMax`: the span of the
contacts in `qsos`, not of the whole operation.

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

**One reference's file.** An export claiming one reference of its `refType` —
one park's log, when the operation activated several — names it in `ref`, and
the core narrows the slice to the segments carrying that reference. Without
it, a park activated after a break gets every contact made at the park before
it. `activityExportHook` sets it for you.

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
QSOs the option's `refType` (and `ref`) covers — so the two would otherwise disagree in
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
// Ref: {type, ref?, name?, label?, shortLabel?, grid?, lat?, lon?, location?, program?,
//       activationRadiusInMeters?, activationRadiusInFeet?, largeArea?, ...}
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

**The core asks about references in batches.** Every reference an ADIF import
or a deep link brings is decorated in one bridge round-trip, and so is every
link a list of search results needs, every outline a map draws, and every
phrase of an operation's title. Each reference is still its own call, to the
handler `invokeHook` would pick for it (qualified claims included), so a
handler implements the single-reference methods above and nothing else. The
time budget belongs to the batch, though: ten seconds for all of its calls
together. A handler that has not answered by then costs only its own
reference — it stays as it was, with no name, link or outline — and every
other reference keeps its answer. A `decorateRef` that goes to the network
should answer well within that.

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
GeoJSON — a SOTA summit's activation zone, a POTA park's boundary, and
whatever equivalent another program publishes. Areas (`Polygon`,
`MultiPolygon`) are drawn filled with an edge; lines (`LineString`,
`MultiLineString`) — a trail or a river that is the park — are drawn as an
edge alone; points are ignored. Same contract as `linkForRef`: build the URL from the
reference, **never hit the network**, return `null` for a reference the program
has no shape for. The core does the fetching and the caching (`GeoshapeService`),
so an extension never decides how long a device keeps a file or how large one may
be; it only names the two ages the core should use:

```ts
// RefGeojson: {url, maxAgeInDays?, missMaxAgeInDays?, sourceName?}
```

`maxAgeInDays` (default 30) is how long a fetched shape stays usable offline —
boundaries move on the scale of surveys. `missMaxAgeInDays` (default 1) is how
long the core remembers that a reference has NO shape, deliberately shorter so a
newly surveyed zone appears within a day rather than a month. Both are ignored
unless positive: a zero would re-fetch on every rebuild of the map.

`sourceName` is who drew the shapes, short enough for the credit line a map
shows under its outlines ("Source: OSM, sotl.as") — the host of `url` when it
is left out. Name the data's owner, not the server that relays it: POTA's
outlines are served by Ham2K and credited to OSM.

A document past 16MB is not kept: the core remembers it as a miss, on
`missMaxAgeInDays`, rather than downloading it again on every retry.

The URL must be `https`, and the core does not follow redirects to reach it.
Unlike a link, this one is fetched rather than handed to the platform, and a
plaintext one — named outright, or arrived at through a `Location:` header —
would downgrade every activator's connection on a program's say-so.

Shapes are asked for sparingly: the Map tab asks about the operation's own
references, and the Activities pane's results map about those plus the one
suggestion whose card is open, drawn solid. The rest of the map's suggestions
are asked about only once it is zoomed in (from GL zoom 7, fading in by 8)
and drawn as a dashed edge under the solid ones — a search answers with dozens
of references, and further out a footprint is a few pixels across. Implemented by: `sota` (both types, via
SOTLAS's `az.sotl.as`, used with the operators' permission) and `pota` (both
types, via `services.ham2k.net/lookups/outlines/pota/`, which links parks to
OpenStreetMap shapes; a park not yet linked answers 404).

**POTA is the one exception, and the core makes it, not the hook.** For a
POTA suggestion's dashed outline the core skips `geojsonUrlForRef` and reads
`services.ham2k.net`'s grid bundles instead — every outlined park touching a
Maidenhead cell, simplified and clipped to it, one cached document per cell
(500 m blocks below GL zoom 9, 10 m squares from 9). A long trail's whole
outline runs to megabytes; its pieces in a cell, to kilobytes. The same
bundles add to `suggest`'s answers the parks whose outline, not just whose
point, is near: within 5 km for the nearby list, touching the view for a pan
close in (from about GL zoom 10; see `suggest` below). An open card's POTA suggestion is drawn solid from the
same pieces; the operation's own references still come from
`geojsonUrlForRef`.

**An activation radius is a circle, drawn the same way.** A reference that
carries `activationRadiusInMeters` or `activationRadiusInFeet` — how far from
its point the program lets an activator be — is circled on both maps, in the
same color and under the same rules as an outline: solid for the operation's
own references and the open card, dashed for the other suggestions once
zoomed in. It is set on the reference itself, by `suggest` and `decorateRef`,
because some programs set different distances by region or by kind of
reference; a suggestion is stored on the operation verbatim, so the Map tab
draws it too. Give whichever unit the rules are written in; meters win when
both are set. It is drawn only around `lat`/`lon`, never around a `grid`,
whose centre can sit further from the reference than the whole radius
(docs/design/locations.md). A reference with an outline AND a radius draws
both. A circle has no source, so it adds nothing to the map's outline credits
and is not offered for an outline report. Programs built on the SDK's
`referenceActivity` factory get this from one `activationRadius` config line —
a value, or a function of the list row for rules that vary.

**A reference too large to stand for one place says so.** An operation with
no location of its own takes the first of its references that has one
(docs/design/locations.md), which is right for a summit or a park a few
kilometres across and wrong for a 3,500 km trail. A reference whose point is
representative rather than where an activator stands — POTA's parks that span
several states — carries `largeArea: true`, and that reference never places
the operation. Nothing else reads it: the maps draw it, and the nearby search
finds it, exactly as before.

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
// LoggingControlDescriptor: {key, label, shortLabel?, skipFocus?, icon?, color?,
//   order?, optionType?, allowsMultiple?, editable?, input}
// `shortLabel` is the same name in fewer characters, for a field the logging
// row has squeezed below its label's width. The core measures and picks; the
// extension only says what the short form is.
// `skipFocus: true` takes a main logging field out of the Space and Tab cycle;
// the arrow keys still reach it. Every shipped contest sets it on Our Serial.
// SuggestArgs: {operation, location?: {lat, lon}, callsign?, searchTerm?, scoped?, bounds?: {south, west, north, east}}
// ActivitySuggestion: Ref & {distance?, relevance?, allowsMultiple?}

// The input catalog. A new kind is earned by a different WIDGET, never by
// different validation — so a pattern-constrained field is `text` with a
// `pattern`, not a kind of its own (docs/design/contests.md §5.3).
//   {kind: 'refList', refType, placeholder?, pattern?, transforms?,
//                     numbersRowKey?}
//   {kind: 'text',    refType, field, placeholder?, pattern?, transforms?,
//                     numeric?, uppercase? /* default true */, numbersRowKey?,
//                     maxLength?, suggestedValue?}
//   {kind: 'options', refType, field, options: [{code, name?}], matchOn?,
//                     allowFreeform?, preferredCodes?, minCharsForSuggestions?,
//                     placeholder?, pattern?, transforms?, numeric?, uppercase?,
//                     numbersRowKey?, maxLength?, suggestedValue?}
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
// `numbersRowKey` is the one character the mobile numbers row offers after
// its digits while the field has focus, where the operator would otherwise
// switch keyboard layers for it. Without it a `refList` field offers `'-'`,
// which joins most programs' prefixes to their digits, and the other kinds
// the operator's decimal separator.
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
station defaults (extensions never need to know which). When the operator pans
the Activities results map it asks again with the map's view as `bounds` (and
its centre as `location`, no `searchTerm`, the box's scope if it has one):
answer with EVERY reference inside the view, not the nearest few, or the view's
corners stay empty however far the operator pans. `nearbyLookupRows` reads
either case, through the `dbLookupSelectInBounds` host call for a view — only
an app that sends `bounds` answers that call, so an extension that calls it
only then runs on older apps unchanged, and one that predates `bounds` answers
with what is nearest the view's centre. Measure `distance` from the `location`
given either way; the core re-measures a panned answer from the operation's own
place before any card shows it. For POTA only, the core also adds the parks
whose OUTLINE is near (from the grid bundles above) to the nearby list and to a
pan, labelled by POTA's own `decorateRef`, and gives a park POTA already
suggested the nearer of its point's and its outline's distance — so `pota`'s
`suggest` keeps answering by point, and a trail whose point is a state away
still reaches an operator standing on it. Called with no
`searchTerm` for nearby suggestions, or with one for name/code search — an
extension may honor either, both, or neither (returning `[]`). `scoped` is
true when THIS extension's own list was asked for — the operator tapped its
"Activity Types" row or typed one of its words, with or without the colon
(below) — which otherwise cannot be told from the nearby list, since neither
carries a `searchTerm`. Without the colon the other extensions are asked too,
for the word as text. An extension
that keeps itself out of the nearby list (`cwt`, offered only around a session)
answers a scoped call anyway: it is the one being asked. The core fans out to
every `activity` hook via `invokeHookAll`; a scoped search asks only its own
hooks, in one batch (`invokeHookBatch`); and a search naming a type without the
colon asks that type's hooks in one batch AND fans out to every hook — two
round-trips, kept apart so a fan-out that runs out of time cannot cost the named
type's answers. The core merges results and ranks them
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
`pota:` (or tapping a row under "Activity Types") asks only the extensions
serving that reference type, via a key-scoped `invokeHook` rather than the
usual fan-out. An extension answers to two kinds of word:

- **Each reference type its manifest declares**, as a plain `ref:<type>` in
  `hooks`, by the type's base name lowercased — `ref:potaActivation` and
  `ref:pota` are both `pota:`. A user-published `ki2d-pota` declaring
  `ref:potaActivation` is scoped as `pota:` too, since the operator is adding
  POTA parks whichever extension supplies them: two running extensions
  declaring one type share the word, and the scoped search asks both. A
  qualified claim (`ref:qp/ny`) makes no word.
- **Its own extension key** — `ham2k-pota:` asks that extension alone, which
  is how an operator picks one supplier over another.

The same word without its colon gives precedence instead of scoping. `pota`
on its own asks the extensions serving the type for their own list (as a
scope, `scoped: true` with no `searchTerm`) and every other extension to
search for the text "pota", with the first answers leading. `pota bear mtn`
asks the extensions serving the type for "bear mtn" and every other one for
the whole text — a `suggest` matching codes and names against one string
finds nothing for the word it was named by.

The scoped call reaches the extension under the key it registered its
`activity` hook with, which has to be its manifest key. The search reads which
extension supplied a control from the fan-out that returned it, never from
the descriptor's `key`, so a catalog `ham2k-pota` keying its controls
`pota/activation` is reached as `ham2k-pota`. (A logging control's serial
counter is still namespaced by the `key`'s prefix: two extensions keying
controls under one prefix share a counter.) A
switched-off or not-yet-installed extension is offered from the same words:
typing a type it declares, or its key, puts its enable or install row under
the search.

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
  fieldsForOneQSO(args: { qso, operation, mainHandler? }, ctx): Promise<{name, value}[]>
  // One field set PER ADIF RECORD this contact should produce.
  fieldCombinationsForOneQSO?(args: { qso, operation, mainHandler? }, ctx): Promise<{name, value}[][]>
}
```

`mainHandler` is true when the file is this extension's own export — app-polo's
argument of the same name. It is how a program writes what only its own
submission asks for: SOTA's files carry both stations' gridsquares, which the
full export leaves to the contact's own privacy rules.

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

Only a program's **own** export asks for combinations. The full ADIF export is
one record per contact — the copy the operator keeps, which a reimport or a
log processor must not read as several contacts — so it asks every hook for
`fieldsForOneQSO` alone, as app-polo's does. A splitting program answers that
method too, for the one record — POTA names its first hunted park in `SIG_INFO`
and every one in `POTA_REF`. A hook answering only combinations is left out of
the full export, and the kernel logs an error for it as it activates.

**Only the export's OWN hook is asked.** A file submitted to one program is
that program's log, so an export that delegates the ADIF build names itself as
`mainHandler` in the `ExportRequest` — app-polo's "main handler"
(`qsonToADIF`'s `handler`) — and the `adif` extension invokes that hook alone,
not the whole category. Activate a park that is also a lighthouse and each
file claims its own reference; ask every hook and both programs'
`MY_SIG`/`MY_SIG_INFO` pairs land in every record, leaving the receiving
program to guess which is its. The delegate cannot work out who called it, so
naming yourself is not optional.

The full ADIF export names no `mainHandler`, and every program the contact
belongs to contributes — polo's `includeOtherRefs`, which only its full export
sets. That is the export claiming no program: the complete copy the operator
keeps.

**The full export asks only the extensions a contact belongs to.** For each
reference on the contact's operation (the segment-effective one) and on the
contact itself, the kernel takes every extension holding the strongest claim
on it — the longest `ref:<type>/<code>` prefix that begins the reference's
code, or else the bare `ref:<type>` — and asks those extensions' hooks, and no
other's. A hunted reference on the contact counts as much as an activation on
the operation, so a chaser's log keeps its `SOTA_REF`s. A longer claim excludes
a shorter one: an old `{type: 'qp', ref: 'CA'}` reference belongs to the party
that claims `qp/ca`, not also to the extension claiming all of `qp`. Equal
claims are all asked, whatever their priority: WCA also registers
`ref:ecaActivation` to resolve a castle while ECA is off, and ECA's fields
must not depend on which of the two registered first. An installed extension the
contact has nothing to do with is never asked, so a hook that forgets to check
its own references costs nothing here; checking them is still how a hook
behaves correctly when named by a program's own export.

An extension that genuinely has something to say about every contact opts in
from its **manifest**, `"adifFieldsScope": "always"`, and is asked whatever the
contact carries. The field lives in the manifest, not on the hook, so the
packer can check it without running the bundle: a manifest listing
`adifFields` with neither a `ref:` type nor the opt-in is refused at packing
and at publishing, and the app's own build refuses it too. The kernel reads the
opt-in from the extension's definition, so spread the manifest into
`defineExtension`, and it logs an error at activation for an extension that
registers `adifFields` but answers for no reference and does not opt in.
`mainHandler` and `includeFieldsFrom` are unaffected: a named hook is asked
whatever the contact carries.

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
the same name — the full export asks every program on the contact, and a park
and a summit both answer `MY_SIG` — the later one is dropped. Hooks are asked
main handler first, then each `includeFieldsFrom` key in the order given, so
that order decides — whichever of the two methods each hook answered. The
contact's own fields come after every hook's: a program knows what its file
needs in a field better than the contact's generic answer does (the section a
Field Day station sent, a satellite's downlink band). The exception is what
identifies the contact — `CALL`, `QSO_DATE`, `TIME_ON`, `QSO_DATE_OFF`,
`TIME_OFF`, `BAND`, `FREQ`, `MODE`, `SUBMODE`, `STATION_CALLSIGN`,
`OPERATOR`: a hook answering one of those is dropped, since it would rewrite
every record it is asked about, the whole-log backup included. A program whose
uploader needs `OPERATOR` on every record asks for it on the export instead,
`ExportRequest.operatorFallback` (`operatorFallback` on `activityExportHook`'s
and `huntingExportHook`'s rules): the core writes `OPERATOR` only where it says
something `STATION_CALLSIGN` doesn't, and with `'base'` or `'station'` it
writes the contact's own operator on every record, falling back to the station
call's base call or the station call itself. This is a
deliberate divergence from app-polo, whose contact fields come first and whose
main handler's are appended unchecked, so a name both answer is written twice. The **full export**, which asks every
program on the contact, has no main handler to order by: hooks are asked in priority order,
so which of two programs keeps a shared `MY_SIG` there is not something either
of them chose.

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
// CommandCatalogEntry: {command, describe, params?, category?, needsOperation?, needsTestData?, keywords?, expectsParams?, suggest?}
// CommandAction (closed set): {setVfo?, setPower?, updateQso?, addQso?,
//   setKeyerSpeed?, showKeyer?, setEnterSends?, sendSpots?, autoRespot?, syncAll?, updateSettings?, updateSetting?, openSettings?,
//   updateOperation?, markSegment?, findInLog?, navigate?, setCallField?, setTime?, reloadDataFiles?, devNotice?, devStatus?,
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
LANG `<code>` switches the app's language — hidden locales (CW, QRP, QRO)
included, "LANG SYSTEM" back to the device's — with a plain `updateSetting`
on the `locale` field, which refuses a code the app has no strings for;
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
- **Matching is host-side**, case-insensitive, at the start of a word in
  `command` or in `keywords` — never mid-word, and `describe` is never
  searched. Every word that should find a command belongs in its
  `keywords`: the aliases it accepts when typed, and plain words for what it
  does. Same rule `interpret`'s own matching follows: the host never
  compiles extension-supplied patterns.
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

A contest's `summarizeScore` returns `contestSummary(...)` rather than
building its tallies by hand: one tally titled with the contest's name and
score, its detail opening on a `contestArithmetic(...)` line, and nothing at
all for the `day` scope — a contest's multipliers run the whole event
(docs/design/contests.md §5.2).

A scorer's internal *rules* stay private to its scoresheet: contests don't
share a rule vocabulary, so only notices, alerts, points and summary tallies
cross the boundary. `scoreQso` **may mutate** the scoresheet it's given and
return it; copying accumulated state per QSO is quadratic. The batch pass
copies the checkpoint it resumes from, once; the live paths hand the scorer a
copy-on-write view of it instead (`copyOnWrite` in the SDK), so a candidate's
writes land in the view and the held sheet is never touched.

```ts
// The wire shape the harness produces, for reference:
interface ScoringHook {
  scoreQsos(args: ScoreQsosRequest, ctx): Promise<ScoreQsosResult>
  scoreQso?(args: ScoreQsoRequest, ctx): Promise<QsoScoreNotices>
  scoreCandidates?(args: ScoreCandidatesRequest, ctx): Promise<ScoreCandidatesResult>
}
// ScoreQsosRequest: {operation, qsos, ref?, segments?, resumeFrom?, resumeDay?, resumeKey?, checkpointKey?}
// ScoreQsosResult:  {
//   qsoScores: Record<uuid, QsoScoreVerdict>,   // one per QSO claimed; see above
//   daySections: {day, count, scores: Record<tallyKey, ScoreTally>}[],
//   operationSummary: Record<tallyKey, ScoreTally>,
//   scoresheet,                                  // checkpoint to resume from
//   scoresheetDay?,                              // the day it ends on, handed back as resumeDay
//   checkpointHeld?,                             // true: the harness kept the end sheet under checkpointKey
// }
// ScoreQsoRequest:        {operation, qso, excludeUuid?, ref?, segments?, resumeFrom?, resumeDay?, resumeKey?, qsos?}
// QsoScoreNotices:        {notices, alerts, dupe?, checkpointHeld?}
// ScoreCandidatesRequest: {operation, candidates: {key, qso}[], ref?, segments?, resumeFrom?, resumeDay?, resumeKey?, qsos?}
// ScoreCandidatesResult:  Record<candidateKey, QsoScoreNotices> + {"$checkpointHeld": true} when a checkpoint was named
```

All three arrive already implemented by `contestScorer()`; a scorer writes the
three pure `ContestScorer` functions and gets the loop, the checkpointing and
both live paths for free.

`scoreQso` answers for ONE not-yet-logged QSO — the callsign being typed.
A candidate that carries no `startAtMillis` (the draft's time is still
automatic) reaches the scorer stamped with the current time on both live
paths, so a day-bucketed rule judges it as of now rather than at the epoch; a
candidate that states a time keeps it. On both live paths a checkpoint, with
the `qsos` logged since it, stands in for the whole-log read: the harness
views the checkpoint copy-on-write, replays that tail onto the view
(continuing the day `resumeDay` names, so no scorer's per-day tally restarts
mid-day) and scores the candidate against the result. The host sends a
checkpoint only when it can prove the log is what the checkpoint folded plus
appended contacts; otherwise the harness reads the log through `ctx.getQsos`
and folds it cold. The batched `scoreQsos` resumes the same way: after the
first pass of a session, an append arrives as a checkpoint plus the appended
contacts, and only their verdicts come back.

**A checkpoint is held in the runtime and named, not sent, once it is
there.** A sheet the size of a long log's worked-call map crossing the bridge
on every keystroke would be most of the keystroke's cost. So the host names
each checkpoint (`checkpointKey`, derived from the checkpoint's stamp) when
the batch pass produces it, and the harness keeps the end sheet under that
name — one per operation, the last few operations. A live call, or the next
append, then carries `resumeKey` alone; a `resumeFrom` that arrives beside a
`resumeKey` is filed under it too. A name the harness does not hold — a
runtime restarted since, or one operation more than it keeps — is an error
(`resume-missing`), never a silent cold fold, and the host answers it by
sending the sheet once more. The host names a checkpoint only to a harness
that has said `checkpointHeld: true` for it; a scorer built on an SDK without
the cache never says so and keeps receiving the sheet. A `scoreCandidates`
answer says it under the reserved key `$checkpointHeld`, since its other
entries are the caller's candidate keys — a candidate key never starts with
`$`.

The view a scorer gets on the live paths takes every kind of write —
assignment, `push`, `delete`, `Object.defineProperty` — and refuses the ones
that would reach the base sheet by other means: `Object.freeze` (or `seal`,
`preventExtensions`) on it throws. A sheet is plain JSON; one that is frozen
or carries accessors is outside the contract and throws at the first touch.

`scoreCandidates` answers the same question for many at once, which is what the
Spots Panel asks to mark the spots already worked: the log is folded once per
scorer and every candidate scored against its own copy-on-write VIEW of the
result, so no candidate can become another's duplicate and no candidate pays
for a copy of the log. Candidates carry no uuid — a spot is not a record — so
results come back under caller-chosen keys.

`QsosRepository.forOperation` already filters deleted rows and orders by
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

## ✅ `chasing` — what a contact counts toward

A chasing program — DXCC, POTA hunting, WAS — says which lines of its
checklist each contact fills. The app keeps the best claim per line and ranks
spots against the result; [claims.md](../design/claims.md) is the design.

One registration per program, keyed by the program's key — the extension's own
key, or one prefixed `<extension key>_`, so one extension may register
several:

```ts
registerHook("chasing", { key: "dxcc", hook: {
  program: { label: "DXCC", icon: "earth", version: 1, editions: "lifetime" },
  claimsForQsos({ qsos }, ctx) { /* { [uuid]: QsoClaim[] } */ },
  holdersFor({ station }, ctx) { /* string[] */ },
  summarizeClaims({ holder, edition, slots }, ctx) { /* { [key]: ClaimsTally } */ },
  importClaims({ importer, file, station }, ctx) { /* { claims: ImportedClaim[], skipped? } */ }, // optional
}})
```

- **`program`** is plain data, read across every extension in one call
  without invoking anything. Raise `version` whenever the same contacts would
  claim something different: the app keeps no claim from an older version.
  `refLabel` is what one reference is called where a notice names it
  ("New POTA Park"), the program's `label` when left out.
  `supersedes` names the scoring notices the program's verdicts stand in for
  (DXCC: `newDXCC`): wherever the program judges a call or a spot, the
  scorer's notice is dropped in favor of the verdict.
- **`claimsForQsos`** answers every contact in the batch, by `uuid` — a
  caller asking about something that is not a stored contact (a spot, the
  call being typed) gives it a `uuid` of its own, and a contact without one
  is left out — with the
  slots it fills: `{holder, ref, band, mode, level, edition?, by?, label?,
  guess?}`. `band` and `mode` are explicit — `null` means "any", and a
  program usually claims several granularities per contact (DXCC: Mixed, the
  band, the mode). `mode` is the program's own grouping; the app never maps
  modes for it. `level` is `worked`, `confirmed` (a QSL the program accepts,
  from `qso.qsl`) or `verified` (sponsor credit, `qso.credits.<program>`).
  **It must be a pure function of each contact** and the extension's own
  data — never the log — because the app asks it about spots, and about
  contacts on a device that holds only part of the log. An empty list is an
  answer: that contact claims nothing. So is the list for an event marker
  (`band: 'event'`), whose placeholder calls are not stations. A contact's
  `our` carries the place it was made from — `grid`, `lat`/`lon` — its own,
  or its operation's when it states none, for a program that keeps a
  checklist per place. A spot candidate's `their` carries the lookup's
  `guess.state` when an offline lookup knows one.
- **`holdersFor`** lists the holders a station claims as — the opaque
  strings the program puts on its claims — so the app knows whose checklist
  to show: the first, in the current edition. `station` carries its call
  and, when it has one, its place, as a contact's `our` does. An `annual`
  program names its editions by UTC year (`'2026'`), which is how the app
  tells the current one; an `event` program's checklist has no current
  edition to show.
- **`summarizeClaims`** reads one holder's filled slots (`{ref, band, mode,
  level, label?}` each) into tallies, a `ScoreTally` without its `for`.
- **`importClaims`**, for a program whose `program.imports` lists importers
  (`{key, label, extensions}`), reads one file — `{name, text}` — that the
  operator picked or dropped, for the station they chase as (`station`, its
  call and place as `holdersFor` gets them). It answers the
  claims the file makes, each a `QsoClaim` plus `at` (epoch millis, when the
  slot was earned) if the file says, and `skipped`, the records it could not
  read. Each claim is kept in the log as a claim record — an event row, so it
  syncs with the log ([claims.md](../design/claims.md) §9) — and
  `claimsForQsos` is never asked about one: the app reads the claim it holds.
  The file is the whole of its importer's records: importing the same kind of
  file again replaces every claim the last one gave, and a file answered with
  no claims replaces nothing.

The host isolates programs from each other
(`app/lib/services/extensions/extension_chasing.dart`): a program that throws
or times out answers nothing for that call, and a contact with any
malformed claim is left out of the answer, keeping the claims it already
holds, since dropping one claim would read as the contact no longer making
it. Both are reported once per program and method. The category is
extension API 9: a bundle that registers a program declares `"api": 9`, which
the packer enforces, so an older app — which would install it and never ask
it anything — is never offered it.

Implemented by: `dxcc` (core) — Mixed, per-band and per-mode slots for the
station call worked from each entity; LoTW and paper QSLs confirm, LoTW credit
verifies. `ham2k-pota` — one slot per park hunted, worked only; its
hunted-parks export verifies. `ham2k-was` — Mixed, per-band and per-mode
slots (plus FT8 and RTTY) for the station call worked from one 4-character
grid; LoTW and paper QSLs confirm, `WAS` credit verifies.

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

`sync`'s payload and reply carry `claims` beside `operations` and `qsos`
(docs/design/claims.md §7) once the server's reply has said it takes them
with `meta.flags.claims`. A transport passes the array through like the
other two, both ways.

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

`uploadStashFile` / `listStashFiles` / `emailStashLink`
(optional) back the Exports pane's Stash button, which sends export files
to a store the operator fetches from any browser (Ham2K's File Stash, at
stash.ham2k.net). `uploadStashFile` takes ONE file and the `groupUuid` of
the batch it belongs to — the host mints it, since the sandbox has no uuid
source, and calls once per file: its call timeout does not stop a hook, so a
whole batch in one call would go on uploading unseen after the host had
told the operator it failed. It answers `{ uploaded: true }` or `{ error }`,
never a throw, with `fatal: true` on any failure but the server refusing
that one file — sync off, no account or permission, no answer — so the host
stops instead of having every remaining file fail the same way. No answer
says the file may have arrived: a body can reach the server after the reply
is lost.
`listStashFiles` answers the server's `{ stash_files: [...] }`, newest
first, which the host reads to warn a free account before a new stash
replaces one not yet fetched; `emailStashLink` mails the account's own
address a link to its stash. Both answer `{ error }` for a refusal. All
three own the same sync gate `submitReport` does.
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
//                | {kind: 'scene', scene, title?, triggers?}   (see Panel scene reference)
```

`operation` is the operation's data with its `uuid`, its
`startAtMillisMin`/`startAtMillisMax`, and `operatorCall`: who is at the key on
this device, resolved for its position in a multi-station operation, and empty
when nobody is named.

The host addresses a panel as `ext:<hookKey>:<key>`, and that id is stored
inside saved layouts — renaming a `key` drops the panel out of every
arrangement holding it.

An experimental fourth kind, the **panel scene**, adds SVG and text layers, numeric
bindings, local controls, native Material controls, a layout, and host-run animations.
Its payload is `{kind: 'scene', scene, title?, triggers?}`; it does not have a
`content` string. `kind: 'svgScene'` is the same kind under its name through SDK 0.9,
which the SDK keeps as a deprecated alias along with the `SvgScene*` type names.
**`scene` and everything it adds are extension API 5**: native controls,
`strings`, `layout`, `after` and control `opacity`. A bundle using any of them
declares `"api": 5` ([distribution.md](distribution.md)), and an app speaking
less refuses it at install rather than showing the panel as an unknown kind.
A plain scene that must reach those apps keeps `svgScene` and its lower API.
**Extension API 7** adds the scene's host-fed `radio` values (*Radio values*
below), `scaleX`/`scaleY` bindings, text `glow`, a knob's `menu` and second
axis, and the spectrum control's `follow`, `span` and label `decimals`; a
bundle using any of them declares `"api": 7`. Scene-capable hosts pass
`instanceId` on render/event calls. `onEvent` handles control events and returns
value patches (`values`, and `strings` for string controls); local-only controls and animation frames make no bridge
calls. Controls with `continuous: true` send `change` events during dragging and a
final `commit` on release; pending movements are coalesced to the newest value.
Numeric text supports `scale`, `truncate`, `modulo`, and `minIntegerDigits`
for local numeric formatting; bindings accept `scale`, `truncate` and `modulo`
too, applied to the value before the ramp. KI2D’s Radio Panel uses these for its Modern
frequency groups; its settings offer Modern/LCD styles and radio selection. Local sliders may use `hover` and `discrete` hourly buckets. Text `samples`
may hold numbers or preformatted strings; control `valueLabels` supplies accessible
value descriptions. A layer binds `rotation`, `translateX`/`translateY`,
`scaleX`/`scaleY` and `opacity`; rotation and scale turn about its `pivot`, so
`scaleX` with `pivot: [0, 0.5]` grows a bar's fill from its left end.
Transform/opacity bindings may also supply numeric `samples`,
equally spaced over their `input` range, instead of the `output` ramp. The host
interpolates and clamps these locally; chart markers and callouts can follow
individual readings without bridge calls. See [the design notes and open milestones](../design/panel-scenes.md)
and the `k2hrc-panel-scenes` sample. This API is experimental.

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

For a panel showing a scene, environment changes automatically request a
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
in native directionality, accessibility scaling and semantics. A text `glow`
(`#RRGGBB`) draws a soft halo of that colour around the letters, to keep them
legible over busy artwork.
Button controls can supply `menu: [{label, event}]` to open a native dropdown.
Selecting an item emits its `event` as the action with the original control ID;
dismissing the menu emits nothing. A knob takes a `menu` too: a click opens it,
while a scroll or a drag still turns the knob.

**Native controls.** Besides the drawn `button`, `slider` and `knob` — invisible
hit areas over the extension's own artwork — a scene can use Material widgets
the app themes itself: `nativeButton`, `nativeSlider`, `nativeTextField`,
`nativeDropdown`, `nativeSwitch`, `nativeCheckbox`, `nativeRadio`,
`nativeSegmented`, `nativeChip` and `nativeText`. `PanelSceneControl` in the SDK
lists what each kind takes. String-valued controls (text field, dropdown, radio,
segmented) bind to the scene's `strings` map, which sits beside `values`; a key
is in one or the other, never both; a choice's string is `""` or one of its
`options` (each comma-separated part, for `multi`). Their events carry `text` instead of `value`,
and an `onEvent` result may return `strings` as well as `values`. A text layer
whose `value` names a string shows it as-is. A text field commits on Enter, or
on leaving it after typing; a render that lands while the operator is typing
does not overwrite the typing. Every control's `label` is its accessible name;
the app has no tooltips. A text field or dropdown in a panel keeps keyboard
focus; clicking any other native control hands focus back to the callsign
field, as clicking a button anywhere else in the Operation view does. A drawn
`button` never takes focus from a click, so the operator's typing stays where
it was. A drawn `slider` or `knob` clicked or dragged holds focus for three
seconds after its last use — long enough for the arrow keys to adjust it — then
hands it back to wherever it came from. Focus that arrives by Tab stays.

**Layout.** A native control either has an `x`/`y`/`width`/`height` rect over the
artwork, like the drawn kinds — it takes the rect's width and its own height, up
to the rect's, so give a field a rect tall enough for it — or omits all four and is placed by
`scene.layout` — a tree of Flutter's `row`, `column` and `wrap`, with `flex`/`fit`
(Expanded and Flexible), `width`/`height`, `padding`, `spacing`, the two axis
alignments, `{spacer: flex}`, `{control: id}`, and `{scene: true}` for the
artwork, scaled to fit. Sizes are logical pixels, like the render environment's.
Every rect-less control appears in the layout exactly once; a layout with no
`scene` node shows no artwork, so it may declare no layers either. A text field
or dropdown given no width (a row child without `flex` or `width`) is 200 wide,
and a row's children that do not fit overflow as a Flutter `Row`'s do — use
`flex` or `wrap`. A `flex` only shares space its row or column has: in a row
that is itself an unflexed child of a row, there is none, and its children lay
out at their own size. The layout is at most 8 deep and 128 nodes.

**Controls among the layers.** Layers paint in order, and a control with a rect
paints above all of them unless its `after` names a layer: then it paints
directly after that one, and later layers draw over it. Layers are
click-through: art painted over a control does not stop it working. A layer with
`blocksPointer: true` takes the clicks that land on it while it is visible,
covering the controls under it (keyboard focus still reaches them; mark them
`disabled` too to shut them off). Only a pending action disables action
controls; a value being sent does not. Any control can take an `opacity`, fixed or bound like a layer's;
at 0 it takes no clicks, focus or screen-reader node.

### Panel scene reference

The schema in one place; `panelScene.ts` in the SDK carries the same as types.
Every rule below is checked when the scene arrives: a scene that breaks one is
refused whole, and the pane shows the error naming what is wrong, rather than
drawing part of it.

**The scene document**

| Field | |
|---|---|
| `version` | `1` |
| `width`, `height` | The artwork's viewBox, in scene units. Size it to `environment.width`/`height` and a scene unit is a logical pixel. |
| `values` | `{name: number}`: what bindings, numeric text and numeric controls read. At most 256. |
| `strings` | `{name: string}`: what text fields and choices hold. At most 256, each up to 4096 characters. A name is in `values` or `strings`, never both. |
| `layers` | Painted in order, each over the ones before: `svg` artwork, `text`, or an `icon`. At most 512 (128 before extension API 12), and 1 MiB of artwork and text in all. |
| `controls` | At most 256 (64 before extension API 12). Drawn or native; see below. |
| `layout` | Optional. Where rect-less native controls and the artwork go; omitted, the artwork fills the pane. |
| `scroll` | Optional, `{axis?, value, event?}` (extension API 12): a scene longer than its pane along `axis` (`y` by default), scrolled natively by the app — wheel, trackpad and drag, a drag begun on a button included — with no call to the extension. It fills the pane across and runs on past it. The position, in scene units, is written to the scene value `value`; a render that changes that value moves the view there, one that leaves it alone leaves the operator's scroll alone. `event` is sent as a `commit`, the position as `value`, once a scroll comes to rest. Layers and controls with `fixed: true` stay put over the pane, in pane coordinates. A drag along the scroll on a slider or knob that scrolls with the content is the scroll's: make one that must be dragged `fixed`. Not with `layout`. |
| `radio` | Optional, `{node?}`: the host feeds that radio's live readings into the reserved `radio.*` values. `node` is an id from `listRadios`; omitted, the logging radio. See *Radio values*. |

**Controls.** Every control has an `id` and a `label`, which is its accessible
name. An `event` names the action sent when it is used; without one the control
is local-only: its value changes on screen, survives renders, and never reaches
the extension. `value` names what it shows and sets.

| Kind | Binds to | Sends | Also takes |
|---|---|---|---|
| `button` | — | `activate` | `menu` |
| `slider` | number | `commit` | `min`, `max`, `step`, `discrete`, `hover`, `valueLabels`, `continuous`, `scrollThrough` |
| `knob` | number | `commit` | `min`, `max`, `step`, `sensitivity`, `invertDrag`, `scrollThrough`, `valueLabels`, `continuous`, `menu`, a second axis (`valueY`, `eventY`, `minY`, `maxY`, `stepY`, `sensitivityY`) |
| `nativeButton` | — | `activate` | `variant` (`filled`, `tonal`, `outlined`, `text`), `icon`, `menu`; needs `event` or `menu` |
| `nativeSlider` | number | `commit` | `min`, `max`, `step`, `valueLabels`, `continuous` |
| `nativeTextField` | string | `commit` on Enter, or on leaving it after typing | `placeholder`, `continuous` |
| `nativeDropdown` | string | `commit` | `options`, `placeholder` |
| `nativeRadio` | string | `commit` | `options` |
| `nativeSegmented` | string | `commit` | `options`, `multi` |
| `nativeSwitch`, `nativeCheckbox` | number, 1 or 0 | `commit` | — (shows `label` beside it) |
| `nativeChip` | number, 1 or 0; or none | `commit`; `activate` without a value | `icon`; needs `event` without a value |
| `nativeText` | number, string, or none | nothing | `style` (a typography role), `align` (`start`, `center`, `end`) |
| `spectrum` | — | `commit` with the frequency clicked; `activate` from an annotation | see *Spectrum* below |
| `zoom` | — | `commit` with the factor, on release | `min`, `max` (the factors allowed); only in a scene with `scroll`; extension API 12 |

The three drawn kinds are invisible hit areas over artwork the extension paints;
the native kinds are Material widgets the app paints and themes. Every control
may also take:

- `x`, `y`, `width`, `height`: its rect over the artwork, in scene units.
  Required for the drawn kinds; a native control omits all four to be placed by
  `layout` instead, and takes the rect's width and its own height when it has one.
- `after`: with a rect, the layer it paints directly after.
- `opacity`: 0 to 1, fixed or bound like a layer's. At 0 the control is gone.
- `disabled`: shown, but no click, drag, key or screen-reader adjustment acts on it.
- `hoverSet` (drawn kinds only; extension API 12): `{value, to}`. While the
  pointer is over the control, the scene value `value` reads `to` — set by the
  host, with no call to the extension — and leaving puts back the scene's own
  value. A layer bound to it lights up under the pointer, and several controls
  naming one value with different `to`s light up one thing each. It survives
  renders while the pointer stays.

`options` is `[{label, value}]`, up to 64, with each `value` unique. A choice's
string is `""` or one of them; a `multi` choice holds its values joined with
commas in option order, so no option may contain one. `menu` is
`[{label, event}]`, up to 32: picking an item sends its `event` as the action.

A `zoom` strip is drawn by nothing: it claims a drag that begins on it along a scrolling
scene's axis. Away from the pane's middle zooms in and toward it zooms out, by the ratio of
the two distances from the middle, clamped to `min`…`max`. While the drag lasts the app moves
each layer and control to where the zoom puts its middle, keeping its size, so text and dots
stay as drawn and only spread apart or close in; a layer with `stretch: true` — a background,
a line the length of the scene — scales along the scroll instead. That preview holds until
the render that answers the `commit` arrives, so a scene meant to zoom draws its pieces as
layers of their own rather than as one picture. A tap on the strip still reaches the button there, and a drag that starts off it
still scrolls. A trackpad's two-finger swipe scrolls on the strip as anywhere else; a trackpad
pinch begun on it zooms by the pinch's own scale, clamped the same way, and commits as a drag does.

A scroll steps a slider or knob by its `step`, down and left lowering it; a one-axis
control takes a sideways scroll by its own direction. A slider or knob with
`scrollThrough` (API 12) also takes the scrolls landing on drawn buttons over it, so labels
drawn over a knob that scrolls the artwork do not stop the scroll; anything else in the
way — a native control, a `blocksPointer` layer, another slider or knob — keeps the scroll
from it.
A knob with `invertDrag` (API 12) moves the other way to a drag, as content held under
the finger does — what a knob that scrolls the artwork wants — while its scroll is unchanged.

A knob with `valueY` sets two numbers from one patch of artwork — a passband's
shift across and its width up, say. Horizontal dragging, horizontal scrolling
and the left/right keys set `value`; vertical ones and the up/down keys set
`valueY`, which must be in `values`, with its own range, step and feel from the
`…Y` fields. The second axis sends its events with the action `eventY`, which a
knob with an `event` must give, different from `event` — an event carries no
other mark of which axis moved, and a scene without one is refused. The host queues the two axes separately, so neither
replaces the other's pending value, and a drag commits only the axes it moved.

**Layout nodes.** Each is an object with exactly one of these keys:

| Node | |
|---|---|
| `{row: [...]}`, `{column: [...]}` | Flutter's `Row` and `Column`. `mainAxisAlignment` (`start`, `center`, `end`, `spaceBetween`, `spaceAround`, `spaceEvenly`), `crossAxisAlignment` (`start`, `center`, `end`, `stretch`), `spacing`. |
| `{wrap: [...]}` | Flutter's `Wrap`: `spacing`, `runSpacing`, the same alignments but no `stretch`. |
| `{control: "id"}` | A native control without a rect. Each appears exactly once. |
| `{scene: true}` | The artwork, scaled to fit. At most once. |
| `{spacer: n}` | `Spacer(flex: n)`. |

Any node may add `width`, `height` and `padding` (one number, or
`[start, top, end, bottom]`). A row or column's direct child may add `flex`, with
`fit: "tight"` (the default, Flutter's `Expanded`) or `"loose"` (`Flexible`). At
most 8 deep and 128 nodes.

**Events and results.** `onEvent` receives, beside the render args:

```ts
event: {
  controlId: string      // the control's id
  action: string         // its `event`, or the menu item's
  phase: "activate" | "change" | "commit"
  sequence: number       // increases with every event from this pane
  value?: number         // for a control bound to `values`
  text?: string          // for a control bound to `strings`
}
```

It answers `{values, strings?}`: a patch of names already in the scene. An
answer with neither is taken as a failure, and so is one that throws or runs out
of time: the pane says the action failed, and the control goes back to what the
scene last reported. The host sends one event at a time, keeps only the newest
of a control's queued changes, ignores an answer to an event a newer one has
superseded, and requests a render after each. Action controls are disabled while an
action is waiting for its answer; a value being sent does not disable them. A text field's typing is sent before any action, and an
action queued behind a value the extension refused is not sent.

**An example.** A spot form over a status strip:

```ts
const state = { call: "", band: "20m", status: "Nothing spotted yet" }

export const spotter: PanelHook = {
  async getPanels() {
    return [{ key: "spotter", title: "Spotter", icon: "bullhorn" }]
  },
  async render() {
    return {
      kind: "scene",
      scene: {
        version: 1,
        width: 400,
        height: 40,
        values: {},
        strings: state,
        layers: [
          {
            id: "strip", x: 0, y: 0, width: 400, height: 40,
            svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 40"><rect width="400" height="40" rx="8" fill="#142337"/></svg>',
          },
          { id: "status", x: 12, y: 8, width: 376, height: 24, text: { value: "status", size: 14, color: "#a9efcf" } },
        ],
        controls: [
          { id: "call", kind: "nativeTextField", label: "Callsign", value: "call", event: "set" },
          {
            id: "band", kind: "nativeDropdown", label: "Band", value: "band", event: "set",
            options: ["40m", "20m", "15m"].map((b) => ({ label: b, value: b })),
          },
          { id: "spot", kind: "nativeButton", label: "Spot", icon: "bullhorn", event: "spot" },
        ],
        layout: {
          column: [
            { row: [{ control: "call", flex: 1 }, { control: "band", width: 110 }, { control: "spot" }], spacing: 8 },
            { scene: true, flex: 1 },
          ],
          padding: 12,
          spacing: 8,
          crossAxisAlignment: "stretch",
        },
      },
    }
  },
  async onEvent({ event }) {
    if (event.controlId === "call" && event.text !== undefined) state.call = event.text.toUpperCase()
    if (event.controlId === "band" && event.text !== undefined) state.band = event.text
    if (event.action === "spot") {
      if (!state.call) throw new Error("No callsign to spot")
      state.status = `Spotted ${state.call} on ${state.band}`
    }
    return { values: {}, strings: state }
  },
}
```

The callsign comes back upper-cased, and the field shows the extension's
version once the typing is committed. A bundle carrying this declares
`"api": 5`. The `k2hrc-panel-scenes` sample in the SDK has every kind, a
control faded in over the artwork, and a click-through layer painted over it.

#### Spectrum

A `spectrum` control is a radio's panadapter and waterfall, drawn by the host
from sweeps that never reach the extension. It is **extension API 6**, as is
`host.setRadioSpectrum`: a bundle using either declares `"api": 6`, and an app speaking less refuses it at install
rather than failing to render the scene. It needs `requiresRadioRead`; without it, or on a host or radio
without a spectrum, the control says why instead. It is placed like a native
control and takes the fields of `PanelSceneSpectrum` in the SDK:

- `radio` (an id from `listRadios`; omitted, the designated radio), `display`
  (`both`, `pan`, `waterfall`), `split`, and `flow` — which way the waterfall
  moves (`down`, `up`, `right`, `left`), the panadapter on the side it comes
  from.
- `floor`, `range`, `average` (0–99, default 40), `fps` (default 15),
  `waterfallSpeed`, `waterfallFloor`, `waterfallRange`: numbers, or the names
  of scene values the control reads on every sweep.
- Colors (`#RRGGBB` or `#AARRGGBB`): `palette` or `waterfallColors`,
  `traceColor`/`traceWidth`, `fillColor`/`fillColorBottom`, `backgroundColor`,
  `gridColor`/`gridDashed`, `waterfallGridColor`.
- `center`: the tuned-frequency line, styled per part.
- `overlays`: up to 16 lines (`at`) and areas (`from`, `to`) in Hz from the
  tuned frequency, the sweep's middle, or absolute, each styled per part.
- `scale`: the gap between the panadapter and the waterfall, its fill and
  borders, and frequency `labels` and `ticks`. `labels.decimals` (0–6) fixes
  the decimals of MHz every label shows; omitted, as many as tell one label
  from the next.
- `span`: Hz shown across the control, from the middle of each sweep — a
  number or a scene value. A wider sweep is cropped to it, so a radio whose
  scope comes in a few fixed widths can be shown at any narrower one; set the
  scope to the narrowest that covers it. Everything is drawn, labelled and
  clicked on the window shown.
- `follow` (0–0.45): keeps the tuned frequency at least this share of the
  width from either edge, by moving the radio's scope just far enough to put
  it on that margin — the picture scrolls with the dial rather than jumping
  to centre it. Only where the radio lets the app place its scope (a
  FlexRadio, whose panadapter in SmartSDR moves with it) and the panel
  declares `requiresRadioWrite`; elsewhere it changes nothing.
- `annotations`: up to 64 pieces of text at frequencies, with a pointer to
  where they sit. One with an `event` sends `activate` when clicked, its
  frequency as `value` and its `id` as `annotation`, and does not tune.
- `hoverHz`, `hoverDb`: scene values the pointer writes, for a text layer.
- `tuneStep`: a click elsewhere sends `commit` with the frequency under it,
  rounded to this many Hz. The extension decides whether to tune.

Each waterfall row stays at the frequencies it was taken on: when the radio
retunes its scope the history slides sideways, and when the span changes it
stretches, rather than old signals being redrawn where they never were.

#### Radio values

A scene with a document-level `radio` block (extension API 7) is fed that
radio's live readings by the host, into reserved values a binding, a text
layer or a control's `opacity` can read like any other:

| Value | |
|---|---|
| `radio.signalDbm` | Receive signal, dBm. |
| `radio.powerOut` | RF out, watts. |
| `radio.swr`, `radio.alc`, `radio.supplyVolts` | The transmit meters. |
| `radio.transmitting` | 1 or 0. |
| `radio.swrAverage` | The SWR averaged over the transmission under way, or else over the last one — only readings taken with RF out count. |
| `radio.secondsSinceTransmit` | 0 while transmitting, then counting up; a very large number when there has been no transmission. |

They change as the radio reports them — several times a second — with no
render and no bridge call, so a meter needle moves at the radio's rate while
the extension renders once a second or not at all. A reading the radio has
not given, or no longer fresh, is missing: a binding takes it as the bottom
of its range and a text layer shows `—`. `radio.secondsSinceTransmit` is
re-read on its own for fifteen seconds after a transmission, so a hold or a
fade bound to it ends on time. The names are reserved — a scene may not
declare them in `values` or `strings` — and readable only with the block;
nothing may set them. The feed needs `requiresRadioRead`: without it every
reading is missing.

The `ki2d-weather-panel`, `ki2d-solar-panel` and `ki2d-radio-panel` reference
panels live in
[ham2k/extensions](https://github.com/ham2k/extensions/tree/main/extensions/dashboard).
They use public host APIs and ship as `.h2kext` packages, not app assets.
Install the packages, then add their panels through Edit Layout. See that
repository's dashboard README for building them.

The radio host calls are manifest capabilities, refused unless declared — the
same shape as `requiresLocation`, and shown to the operator at install:
`"requiresRadioRead": true` allows `host.listRadios()` and `host.readRadio()`;
`"requiresRadioWrite": true` allows `host.setRadio()`,
`host.setRadioConnection()` and `host.setRadioSpectrum()` — and transmitting
with them: `host.sendRadioCw()`, `host.playRadioVoice()`, `host.setRadioPtt()`
and `host.stopRadioTransmit()` — and implies read, since a command answers with the
radio's state. `"requiresRadioRaw": true` (extension API 11) also allows
`host.sendRadioRaw()`, any command in the radio's own protocol, and implies
write. An undeclared call rejects rather than answering null.
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
`meters` holds `signalDbm`, `powerOut`, `swr`, `alc` and `supplyVolts`, each
only while its driver has a fresh reading. `meters.signalDbm` is receive power in whole dBm when supported, refreshed a few
times a second; it expires after two seconds without a reading. The Flex driver receives the selected slice’s LEVEL
meter, and the transmitter's forward power and SWR, through its native UDP channel. The reference panel draws a segmented
receive meter and leaves it unlit when unavailable, stale, or transmitting. It does
not substitute the app's manually entered VFO for a radio reading. A scene
that only draws meters reads them as *Radio values* instead, at the radio's
rate. Extension API 7 adds to the answer:

- `maxWatts`: the model's rated output, where the app knows it; `modes`: the
  modes `setRadio` accepts for this radio, in the radio's order.
- `tuner`: `inline`, `bypassed`, `tuning` or `failed`; null for a radio
  without one, or whose driver cannot read it.
- `canStartTune` (extension API 9): the radio starts a tune apart from
  putting its tuner in line — `setRadio`'s `startTune`. False on a FlexRadio,
  whose in line already is the tune, and wherever `tuner` is null.
- `passband`: `{lowHz, highHz}`, the receive filter's edges in Hz from the
  tuned frequency as the radio shows them — `100`…`2800` in USB,
  `-2800`…`-100` in LSB, around zero in CW — or null where its driver cannot
  read it.
- `antennas`: `{rxPorts, txPorts, rx, tx, separate}`, the radio's own antenna
  ports by the radio's names and which it uses, or null where its driver
  cannot read them. `separate`: it picks receive and transmit independently,
  as a FlexRadio does; otherwise one port serves both.
- `keying`: what the app keys with — `canKeyCw`, `cwSending`,
  `keyerSpeedWpm` (the key's own report, null before it has given one),
  `keyerSpeedRange`, `canPtt`, `ptt` (whether the app's PTT latch holds the
  transmitter) and `voiceMemories` (`[{number, label}]`, empty for a radio
  that plays none) — while this is the logging radio, connected, on a host
  with keying enabled; null otherwise.
- `lastTransmission`: `{swrAverage, endedAtMillis}` for the last
  transmission the radio finished since the app started — its SWR averaged over the readings
  taken with RF out (null when there were none), and when it ended, in real
  milliseconds to compare with `clock.realNowMillis` — or null.

Logical receivers retain separate radio `id` values. When several receivers
share a physical radio, the answer may also include `deviceId`, an opaque
string shared by those receivers, and `channel: {key, label}`. For secure K4
receivers, `key` is `main` or `sub` and `label` is localized. These optional
fields are absent for radios that do not expose this grouping. Use them to
group receiver choices; commands and spectrum controls still address the
receiver's radio `id`, not `deviceId` or a spectrum-channel parameter.

`host.setRadio({id, selection?, ...settings})` sets any of these on that same
radio, through the existing VFO/CAT service. It and the keying calls below are
extension API 7: a bundle using them declares `"api": 7`.

- `frequencyHz`; `dial: true` says it comes from an on-screen dial turning,
  not a typed or clicked target, and on the logging radio Smart VFO Snap
  settles it like the radio's own knob.
- `mode`: one of `modes`.
- `powerWatts`: up to `maxWatts` where that is stated. On the logging radio
  it goes through the app's VFO, so it is the power the next QSO logs.
- `keyerSpeedWpm`: the logging radio's keyer, which clamps to its own range —
  `keying.keyerSpeedWpm` says what it took.
- `tunerInline`: puts the antenna tuner in line or bypasses it. On a
  FlexRadio, whose tuner has no other way in, in line is a TUNE — a carrier
  on the air; other radios switch it without transmitting.
- `startTune: true` (extension API 9): starts a tune — a carrier on the air
  until the tuner settles, read back through `tuner` as `tuning`. Only for an
  operator's explicit press: never send it on a hook's own initiative. It
  goes alone — in the same call as any other setting it is `invalid` — and is
  `unsupported` where `canStartTune` is false. It is the radio's own tune,
  not one of the keying calls below: it reaches whichever radio the panel
  shows, with keying on or off. A start while one is running is ignored, and
  `stopRadioTransmit` (or Escape) ends a tune the app started.
- `passband`: `{lowHz, highHz}`, as `passband` reports it. A radio that sets
  only a width from a table takes the nearest, keeping its own shift — read
  the result back from `passband`. It applies to the mode the radio is in: a
  call that also changes `mode` is `invalid`.
- `antenna`: `{rx?, tx?}`, ports from `antennas`; without `separate`, either
  names the one port, and two different ones are `invalid`. An `rx` naming
  the `tx` asked for in the same call is taken even where `rxPorts` does not
  list it yet.

The host rejects a changed designation (`changed`), a disconnected or stale
radio (`disconnected`), a transmission in progress (`transmitting`) and a
malformed command or a value out of range (`invalid`); a setting this radio
cannot take — a tuner, passband or antenna its readout has as null, a keyer
speed without `keying.canKeyCw` — answers `unsupported`. Accepted requests are
spaced by at least 250 ms, since a dragged control would otherwise flood the
CAT link. Omitting a selection follows the designated logging radio; an explicit `selection`
pins the command to that local radio without changing the logging designation.
An accepted result means requested, not confirmed; only subsequent
reported state confirms it. Drivers retain their own protocol/echo handling.

The keying calls transmit, and act only on the logging radio, on a host with
keying enabled — a panel pinned to another radio is answered `unsupported`
rather than keying the logging radio behind the operator's back:

- `host.sendRadioCw({id, selection?, text})` keys `text` (up to 1000
  characters) on the key in use, as the keyer area's messages do.
- `host.playRadioVoice({id, selection?, memory})` plays one of
  `keying.voiceMemories` once. It never arms a repeat: a CQ repeating on a
  panel's say-so is one the operator did not start where they would stop it.
- `host.setRadioPtt({id, selection?, on})` keys or unkeys PTT through the
  app's own latch, so Escape releases it as it does the operator's own.
  `on: false` releases whatever key the app holds and is never refused; a
  radio that does not take the key answers `on: true` with `disconnected`.
- `host.stopRadioTransmit({id, selection?})` stops every CW message, voice
  memory, PTT and tune the app is keying, as Escape does, whatever radio the
  identity names: a stop is never the call that is refused.

A radio that cannot do what is asked (no CW key, no voice memories, no PTT)
answers `unsupported`; one that is not connected, `disconnected`. These are
not paced, and not refused for a transmission in progress.
`host.setRadioConnection({id, selection?, connected})` starts or ends a local CAT
connection using the same selection and identity checks. Acceptance starts the
operation; follow reported connection state for completion. It does not switch
the hardware's mains power or initiate transmission.

`host.sendRadioRaw({id, selection?, text | bytes, replyMs?, until?})`
(extension API 11, `requiresRadioRaw`) sends commands in the radio's own
protocol — exactly one of `text`, sent as UTF-8, or `bytes`, each 0…255, up
to 4096 bytes. **Nothing about them is checked.** They may transmit, change
any setting or put the radio somewhere the app's own controls never would;
that is what the operator agreed to at install, where the grant is shown in
those words. It reaches any local radio through the same `id`/`selection`
check as `setRadio`, with keying on or off, and is neither paced nor refused
for a transmission in progress. One radio's calls go one at a time, in order,
so that one call's reply window never holds the next one's answer, and past
eight waiting the next is refused as `busy`; the app's own polls may come
between two calls.

- `replyMs`, up to 2000: how long to wait for the reply. Omitted or 0, the
  call answers as soon as the commands are handed to the driver, with no
  `reply`.
- `until`, text or bytes, needs `replyMs`: the reply ends just after its first
  occurrence.
- The answer carries `reply: {text, bytes}`, possibly empty, at most 64 KiB,
  with `text` its UTF-8 reading.

What the commands are, and what the reply holds, is the protocol's. Where the
app's driver keeps one question on the wire and reads the next reply as its
answer, a raw command waits its turn in that queue — written beside it, its
answer would be read as the answer to the driver's question — or, on a
FlexRadio, is numbered as the driver's own are. The reply is then the answers
to the raw commands alone, as the radio sent them, once each has come or the
window closes:

| Radio | Commands | Reply |
|---|---|---|
| Icom CI-V | `bytes`: whole frames, `FE FE` … `FD`, one at a time; the app addresses each to the radio from itself, whatever its address bytes say | each frame's answer frame (`FB`/`FA` or its data) |
| Yaesu binary (FT-817/857/897) | `bytes`: five-byte commands | what the radio sends for each before it falls quiet; not read by the app |
| FlexRadio | `text`: one command per line, without `C<seq>\|` — the app numbers each like its own | each one's `R` line |
| Ham Radio Deluxe | `text`: one command per line, without the radio's context — the app adds it | each one's reply text, one per line |
| DXLab Commander | `text`: one whole message (`<command:10>CmdGetFreq<parameters:0>`) | the field it is answered with; without `replyMs` it goes out as a set, waiting for nothing |
| flrig | `text`: one XML-RPC call (`<?xml …?><methodCall>…`) — the app posts it | the response's body |

Every other radio's commands are written as given — several back to back
(`FA00014074000;MD2;`) in one write, none of the app's own between them —
since each of their answers names what it answers: Kenwood, Elecraft and
Yaesu ASCII, rigctld, N3FJP, Guohetec. The reply there is everything the
connection received in the window, the answers to the app's own polls
included, so `until` is worth setting.

The app's driver still reads what the radio sends, so a raw command's effect
shows in `readRadio` as a change made at the front panel would — and a command
that confuses the driver confuses the app. A radio that is not connected
answers `disconnected`; one whose driver takes no raw commands (a placeholder
radio), `unsupported`; a malformed call, or commands that are not the
protocol's (CI-V bytes that are not whole frames), `invalid`. A refusal heard
within a second of a raw command on a protocol whose refusals name no command
(`?;`, rigctld's `RPRT`) is taken as the raw command's, not counted against the
app's own reads.
`readRadio()` carries `spectrum` (absent on an app without a panadapter): null
for a radio without a scope, otherwise its settings as the radio reports them
(`mode`, `spanHz`, `lowHz`/`highHz`, `refLevelDb`, `speed`), what it accepts
(`spansHz`, `refMinDb`…`refStepDb`, `modes`, `speeds`) and `problem`, why it
cannot run, in the operator's language. The settings are known only while a
`spectrum` control has the scope running, and null otherwise.
`host.setRadioSpectrum({id, selection?, mode?, spanHz?, refLevelDb?, speed?})`
changes them; a span between two the radio offers is snapped to the nearer. It
answers `stopped` when no control is running the scope: nothing is queued for
later. The reference panel samples
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

Beside the QSON, a draft carries one key a logged record never does:
`callField`, the call field read at the cursor (`call`, `fullCall`,
`partial`, `nextCall`, `nextPartial`). `their.call` is the field as typed, which may be a whole
`//` stack or comma list; `callField.call` is the one call Enter logs. It
is what [templates.md](templates.md)'s `qso.call` renders from, so a panel
rendering a template needs nothing more, and moving the cursor within a
stack or a list wakes a `'qso'` panel even when the QSON is unchanged.

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
render, which comes for every change to the log: a contact logged, edited
or deleted, or one a sync brought in. Spots are absent for the same reason:
a panel showing them declares `'spots'` and calls `ctx.getSpots()`, which
answers the operator's own filtered board, judged against this operation.

## ✅ `settingsPanel` — extension settings forms

Declarative settings panels rendered by the core's `FormRenderer` — full
schema, kernel dispatch, `ExtensionService`, and `SettingsView` wiring; see
[settings.md](./settings.md). Complementary to `account`, not a replacement.
Implemented by: `settings` (the core General panel).

An extension puts all its settings in one panel, placed in the section that
fits its main purpose and declared in the manifest's `settings` — see
[Where an extension's settings go](./settings.md#where-an-extensions-settings-go).
A category of its own, a sidebar entry or Common Preferences rows are reviewed
on the catalog.

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

### N1MM call history files

N1MM Logger+'s call history files are uploaded to
[n1mmwp.hamdocs.com](https://n1mmwp.hamdocs.com/mmfiles/categories/callhistory/)
under a new name with every update (`CWOPS_4002.txt`), and downloaded by a
form POST that carries a nonce from the file's own page, so no URL points at
the current one. A `url` of `n1mm-history:<stem>` asks the host to find it
(extension API 11):

```ts
{ key: 'cwops-history', url: 'n1mm-history:CWOPS', fetchType: 'raw', maxAgeInDays: 7, /* … */ }
```

- **Which file:** the newest one, by publish date, whose name is the stem or
  the stem followed by `-` or `_` (extension and case aside). `CWOPS` takes
  `CWOPS_4002.txt` and `CWOPS_4000-CCC.txt`, never `CWOPSOPEN_2026-002.txt`,
  though N1MM's search lists all three; to follow one variant only, name it
  (`n1mm-history:CWOPS_4000-CCC`). The search is read newest first, page by
  page, until a page lists one of the stem's files.
- **When:** N1MM sends no ETag; the chosen file's name, publish date and page
  stand in for one, so a re-upload under the same name still counts as new. A
  refresh whose newest file is the one last downloaded stops after the search,
  like a 304. A forced refresh (RELOAD, Refresh) downloads it regardless.
- **What arrives:** the file as served, in N1MM's format — a `!!Order!!,…`
  column line, `#` comment lines, then CSV rows. `fetchType: 'raw'` is the one
  that fits; `rawToJSONData` parses it. `url` in its arguments is the
  `n1mm-history:` string, not the file's address.
- **Failures:** a stem nothing matches, a refused download, or a page that no
  longer has the shape the host reads fails the download with
  `N1mmCallHistoryUnavailable` — a notice on a refresh the operator asked for,
  an upload for the background passes. The requests and parsing are
  `halo_core`'s `n1mm_call_history.dart`, shared by the app and the CLI.

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
