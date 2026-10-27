# Lookup hooks

The [hook reference](hooks.md) says how hooks are registered and invoked, and what every hook is handed.

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

For an operation without assistance (see `ref:<type>`), every lookup runs
with `ctx.online` false — the background enrichment of logged contacts
included — so a source answers from local data or not at all. The one
exception is a Lookup All QSOs the operator confirms after being warned.

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
