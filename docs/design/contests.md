# Contest Extensions — Porting Design (RFC)

**Status:** In progress — **M0–M8 and M11 are shipped** (12 of the 15
contest-shaped extensions); M9–M10 and M12 remain, see §7. · **Scope:** port
app-polo's 12 contest extensions, plus `fd`, `wfd` and `colonies`, to HaLo
· **Issue:** #149

This RFC specifies the core infrastructure needed to run contest extensions in
HaLo, and a sequence for porting them from app-polo. **All decisions that gate a
milestone are settled** (§8); the questions that remain surface during the
milestone that hits them.
Findings below were verified against `dist` at **0e0ff57** (file:line references
throughout — re-check them if this doc has aged); the per-contest inventory in
the appendix comes from a full read of `app-polo/src/extensions/contests/`.

---

## 1. Summary

App-polo has 12 contest extensions. **None can be ported to HaLo today** — they
depend on core capabilities that don't exist yet. Porting is therefore an
*infrastructure* project first and a *translation* project second.

Three capabilities are **universal** (every contest needs all three), plus a
strong fourth for the US contests:

1. **Typed exchange input** — the logging catalog only has `refList`; there is
   no way to type a zone / serial / state / grid / free-text exchange.
2. **Multi-scorer contest scoring** — scoring is hardwired to a single `core`
   scorer; a contest's scorer is never invoked.
3. **Per-operation contest config** — a way to set and persist a contest's setup
   (contest id, sent exchange, mode, station type, event).
4. **Cabrillo export** — needed by all US contests; *cheap* because
   `@ham2k/lib-qson-cabrillo` is already a shared kernel module.

`simple-contest` is the smallest end-to-end vehicle to build and prove all four,
and is the recommended first increment.

---

## 2. Goals and non-goals

**Goals**
- Support **multiple scorers active on one operation at once** — several
  contests *and* activities *and* the core (dupe / DXCC / bands-modes, later
  US-states) scoring the same log concurrently.
- Preserve **live single-QSO scoring** (notices/alerts for the QSO being typed).
- **Cache partial score + summary state** so appending a QSO (the hot path) and
  editing mid-log do **not** force a full rescore.
- Keep HaLo's architecture: hooks are pure JSON-in/JSON-out; the **core owns the
  loop, the cache, and all persistence** (DESIGN.md §4 "score 500 QSOs in one
  call, not 500 calls"); extensions never hold app state.
- Reuse existing mechanisms where possible (ref persistence, `ExportHook`,
  `adifFields`) so the first increment adds the *minimum* new surface.

**Non-goals (this RFC)**
- Shared US-states/provinces/counties datasets (needed by naqp/qp/stateparks —
  deferred to their milestone).
- QP-Hub / APRS self-spotting from the QSO-parties extension.

---

## 3. Current state (verified)

### 3.1 Scoring
- `ScoringService.rescoreOperation` reads **all** non-event QSOs and calls the
  scoring hook **hardcoded to `key: 'core'`**
  (`app/lib/services/scoring_service.dart:37-42`), returning
  `{qsoScores, daySections, operationSummary}`.
- Results are cached in SQLite so the UI never waits on JS: per-QSO verdicts →
  `qsos.score_cache` (`updateScoreCache`, `scoring_service.dart:46-49`);
  day/operation summaries → `operations.local_data.scoring`
  (`scoring_service.dart:51-56`).
- Live path: `ExtensionService.scoreQso` — also **hardcoded `key: 'core'`**
  (`app/lib/services/extension_service.dart:1357-1358`) — returns
  `{notices, alerts}` for the in-progress QSO; rendered as pills in
  `app/lib/views/operation/call_info_panel.dart:40`.
- The `core/scoring` extension registers **one** hook under key `'core'` with
  `{scoreQsos, scoreQso}` (`extensions/core/scoring/src/index.ts:21`). Its
  `scoring.ts` already *is* a fold internally: `scoreDupe` / `scoreDxcc` /
  `scoreBandsAndModes` verdict functions + `accumulate*Tally` + `summarize*Tally`,
  driven by a chronological loop with day-sectioning.

**Consumers to keep working** when results become multi-scorer:
| Surface | Reads | File |
|---|---|---|
| Day sections | `local_data.scoring.daySections` | `logging_panel.dart:370-383`, `qso_list.dart:155-163` |
| Operation info | `local_data.scoring.operationSummary` (`dxcc`, `qsoCount.duplicates`) | `information_panel.dart:75-114` |
| Live call info | `scoreQso → {notices, alerts}` (the hook, **not** the cache) | `call_info_panel.dart:40` |
| Spot marking | `scoreCandidates → {key: {notices, alerts}}` (the hook, not the cache) | `spots_panel.dart` |
| Carry-forward on QSO rebuild | passes `scoreCache` through untouched | `logging_panel.dart:242`, `lookup_queue_service.dart:284` |

> Worth knowing before designing around it: there are currently **zero
> production readers of the per-QSO cache**. `Qso.scores` is exercised only by
> `repositories_test.dart:347`, and `QsoList.buildRow` renders no dupe, alert or
> tint at all — every live score UI (the call-info pills, the Spots Panel's
> strikethrough and accents) comes from a hook, not from the cache. So any
> per-QSO scoring UI is net-new, and the per-QSO cache shape can still be chosen
> freely.

### 3.2 Logging controls
- `LoggingControlDescriptor.input` is exactly `RefListInputDescriptor`
  (`extensions/sdk/src/types.ts:234`, defined at `:237`) — `kind: 'refList'` only.
- `loggingControls` and `operationControls` **share the same descriptor type**
  (`types.ts:287`, `:292`), so one new input kind serves both the on-air exchange
  and the operation-setup fields.
- `RefHandlerHook.suggestOperationTitle` **now exists** (`types.ts:211`, added by
  #332/#341) — every polo contest defines it, so operation titling ports with no
  new infra. This is a change since the first draft of this RFC.

### 3.3 Config persistence
- Operations persist via `_saveOperationData(patch)` →
  `operation.data` (incl. `refs`) (`activities_view.dart:304-320`); `_saveRefs`
  is just `_saveOperationData({'refs': …})` (`:320`). This is the **core-owned
  path `refList` already uses** to write refs onto an operation. There is **no
  `updateOperation` host call** (the host switch has read-only `getOperation` at
  `extension_service.dart:1013` and `showForm` at `:1081`, no operation write).

### 3.4 Export
- `ExportHook` already accepts an **arbitrary `format`/`exportType`**
  (`types.ts:342`), and `ExportResult` carries `{filename, mimeType,
  content}` (`:317`) — the pipeline is not ADIF-specific.
- `@ham2k/lib-qson-cabrillo` is a **shared kernel module**
  (`extensions/sdk/src/kernel.ts:35,50`) and installed
  (`extensions/node_modules/@ham2k/lib-qson-cabrillo`) — Cabrillo needs **no new
  dependency**.
- `adifFields` hook exists (`types.ts:302`) — contest ADIF fields
  (`CONTEST_ID` / `STX_STRING` / `SRX_STRING`) port with **no new infra**.

### 3.5 Build plumbing
- `extensions/build.mjs` `bundles` array has no contests (`:99`).
- `extensions/tsconfig.json` `include` omits `contests/*`
  (`:18` — has `activities/*`, `core/*`, `lookups/*`, `sync/*`).

### 3.6 Prior design intent (not new)
DESIGN.md already anticipates this work:
- §4: `scoring` = "per-QSO score, day accumulator, summarizer · runs batched in
  JS; results cached per-QSO in SQLite."
- §5: the intended catalog is `textField, refList, select, toggle, segmented,
  infoRow, form, markdown, listSection, mapOverlay, scoreSummary`.
- §10: names "NAQP or a QSO party" as the contest milestone.

So this RFC *specifies* the contest-critical slice of an already-sketched
catalog and scoring model; it does not change direction.

---

## 4. The gap

| # | Capability | Severity | Where it lands |
|---|---|---|---|
| 1 | Typed exchange input (`textField`, → `number`/`serial`/`grid` later) | must-have | SDK `types.ts` input union + Dart control catalog + QSO/ref round-trip |
| 2 | Multi-scorer fan-out + resumable/cached scoring | must-have | `core/scoring`, `scoring_service.dart`, `extension_service.dart`, SDK types |
| 3 | Per-operation contest config (reuse ref path) | must-have | contest extension `operationControls` + existing `_saveOperationData` |
| 4 | Cabrillo export | needed for US contests | new `ExportHook` using `lib-qson-cabrillo` + Dart export picker |

---

## 5. Design

### 5.1 Multi-scorer fan-out

**Requirement:** an operation may carry several contests **and** activities, and
each of them scores it. Core scoring (dupe/DXCC/bands, US-states) runs for every
operation — it is the only thing covering a QSO no contest claims, and its
tallies are the QSO count, DXCC and bands that no contest reports — but it is
the **lowest priority on the worked-before axis**: for any QSO another scorer
has JUDGED on that axis, core says nothing about duplicates. Its dupe rule is call+band+mode,
which knows nothing about references, so beside an activity it contradicts it —
a station worked at a second park is fresh credit to POTA and a duplicate to
core — and the entry row can show only one. Its entity and state notices are
another matter: nothing else in the app reports them, so they stand.

**Proposal:** the `ScoringService` stops calling one hardcoded key and instead
selects the **relevant** scorers for this operation and invokes only those.

Fanning out to *every* registered `scoring` hook and letting each self-select at
runtime would not do: a user may have dozens of extensions enabled while an
operation references a handful. That would cross the bridge once per enabled
extension, on every rescore, to be told "not mine" almost every time.

Instead a scorer **declares its scope at registration**, and the core does the
filtering before invoking anything:

```ts
// A contest: only relevant when its own ref is on the operation.
registerHook('scoring', { hook: CQWWScorer, key: 'cqww', scope: { refTypes: ['cqww'] } })

// DXCC / states / bands-and-modes: relevant to every operation.
registerHook('scoring', { hook: CoreScorer, key: 'core', scope: 'always' })
```

The core then:
1. Collects the ref types present in the operation — **the union across the base
   operation and every segment** (see below), not just `operation.refs`.
2. Invokes `scope: 'always'` scorers plus those whose `refTypes` intersect that
   set. Nothing else is called at all.
3. **Merges per QSO by priority.** An `always` scorer is a `fallback`: on a QSO
   another scorer has judged on the worked-before axis, its own judgement of
   that QSO yields — the `dupe` flag, the alerts in `{duplicate}` and the
   notices in `{newBand, newMode, newDay, newRef, newPark}`. Everything else it says
   stands: `newDXCC`, `newState` and `newProvince` come from core alone, no
   activity or contest emits them, and they contradict nothing — dropping them
   would cost an activation its entity and state pills on every contact. Both
   lists name the keys that yield rather than the keys that survive, so a rule
   added to core later keeps its notice by default.

   **Judging that axis is the test, not answering.** A verdict counts as a
   judgement when it carries `dupe` — `false` included, which is a scorer
   saying its dupe test ran and cleared the contact — a `duplicate` alert, or
   one of those notices. Those notices are a vocabulary a scorer must use rather than a
   survey of what ships: a contest that spells "worked before, but this one
   counts" its own way is not recognized, and its credit lands beside core's
   `duplicate` on the same row (`newPark` is state-parks' spelling, which is
   why it is on the list). Every contest scorer's validity checks return above its dupe test —
   `invalidMode`, `invalidBand`, `invalidCategory`, a VHF test's
   `missingExchange`, which is what it says about every SPOT, since a spot
   carries no exchange — and an activity's `judge` returns nothing when its ref
   filter empties the candidates and the contact carries no reference of its
   own. Each of those is a scorer with no opinion on whether the station was
   worked before, so core keeps its. Reading them as judgements takes the dupe
   warning away with nothing put in its place: no striking on the spots board
   for a whole VHF contest, and no warning when the same station is worked
   twice off-band during ARRL DX.

   The selection and the merge are `halo_extension_host`'s
   `scoring_priority.dart`, not the app's: `halo ext score` applies both, so
   the tool an operator is pointed at when scoring looks wrong describes the
   program that is actually running. `--key` still asks one scorer in
   isolation.

   Per QSO rather than per operation because a ref-gated scorer skips whole
   segments it wasn't running for (§5.1.3): an operation that breaks out of its
   contest and keeps logging casually needs core's dupe rule for that stretch
   and only that stretch. A scorer that FAILED judged nothing, so the fallback
   speaks in full for its QSOs rather than the rows going bare. Summaries never
   yield — every scorer's `daySections` and `operationSummary` are kept.
4. Passes the **matching ref** to the scorer alongside the operation, since a
   scorer may be relevant more than once (two parks, two contests).

This is app-polo's proven model: `scoringHandlersForOperation`
(`src/extensions/scoring/index.js:19-60`) walks `operation.refs`, resolves each
to its `ref:<type>` handler that implements `scoringForQSO`, pairs them as
`{handler, ref}`, and then unconditionally appends DXCC, US-States, Canadian
Provinces and Bands-and-Modes. The declaration above makes that
always-vs-ref-gated split explicit instead of hardcoding the always-on list in
the core, and **diverges** in letting the appended ones lose the worked-before
argument rather than speak over a contest's verdict.

> **Segments.** An operation isn't a single set of refs: app-polo splits a log
> into segments with `break`/`start` event rows whose `qso.event.operation`
> overrides operation attributes **including `refs`**
> (`src/tools/qsonToADIF.js:89-99`) — how a rover changes grid mid-contest, or an
> activator moves to a second park. So scorer selection must consider refs in
> *every* segment, and `scoreQso` must receive the **segment-effective
> operation** for the QSO being scored, not the base one. That also gives the VHF
> ports their rolling rover grid (M6/M7) for free.
>
> HaLo has the event-row scaffolding already — `band == 'event'`, `Qso.event`,
> `Qso.eventKind` (`models.dart:159-171`) — but **not** the `event.operation`
> override payload that carries per-segment refs. **Decided:** segments are in
> scope for this effort and land as their own milestone (§7 M6), before the VHF
> contests that need them. That milestone owns three pieces: the
> `event.operation` payload, core resolution of the segment-effective operation
> for any QSO, and scorer selection over the union of refs across segments.

**Result composition — one entry per scorer. Rules are internal.**

A scorer's *rules* — core's `dupe`/`dxcc`/`bandsAndModes`, a contest's
points-and-mults logic — are **not** part of the external contract. Contests
don't agree on what a rule even is; the rule decomposition is a private concern
shared between a scorer's `scoreQso`, its accumulator, and its summarizer, and
it lives inside the **scoresheet** (§5.2). What crosses the boundary is only:

- per QSO — **notices and alerts** (plus points/mults the UI may show),
- per operation/day — **summaries** (`ScoreTally` records, whose keys the scorer
  chooses for itself).

So the per-QSO cache gains exactly one level, keyed by scorer:

```jsonc
// qsos.score_cache[uuid] — one verdict per scorer
{
  "core": { "value": 1, "notices": ["newBand", "newDXCC"], "alerts": [] },
  "cqww": { "value": 3, "notices": ["newMult"], "alerts": [], "mults": ["20m|Z14"] }
}
```

Today's cache happens to be keyed by core's *rule* names
(`{dupe, dxcc, bandsAndModes}`) — an artifact of `core` being the only scorer.
Those become internal to `core`'s scoresheet; its rule-shaped **summary** keys
(`qsoCount`, `dxcc`, `bandsAndModes`) are unaffected, since summary keys are the
scorer's own choice. Whether the outer level is a map keyed by scorer or an
array of `{key, …}` entries is cosmetic; a map is used here because the write
path replaces one scorer's contribution at a time.

- `operations.local_data.scoring` gains the same extra level:
  `{ [scorerKey]: { operationSummary, daySections } }`. `information_panel` /
  `logging_panel` iterate scorers instead of reading a single
  `operationSummary`. The contest's `summarizeScore` output renders through the
  `scoreSummary` catalog surface (DESIGN.md §5).
- **Scores are shown for the current QSO only** — the call-info pills — not as
  per-row badges in the QSO list. That keeps the display legible with N scorers
  active and avoids a precedence/ordering/cap problem in the day header, which
  is a single non-scrolling row. A logged QSO selected for editing *becomes* the
  current QSO, so its cached verdicts are what the pills show.
- When unioning notices/alerts across scorers for those pills, sort by scorer key
  — `invokeHookAll` does not guarantee stable ordering, and
  `logging_controls.dart:4369` builds a dedupe signature by joining these key
  lists, so unstable order causes spurious churn.

**Live path (`scoreQso`)** fans out the same way; the core unions each scorer's
`{notices, alerts}` for the call-info pills.

**Batched live path (`scoreCandidates`)** answers the same question for many
not-yet-logged candidates at once — the Spots Panel, which judges every spot on
the board against the log to strike the worked ones and accent what is new.
`scoreQso` would cost a bridge crossing *and* a whole-log fold per spot, so this
folds once per scorer and scores every candidate against the result. Two rules
the harness owns:

- **The copy is per candidate.** `ContestScorer.scoreQso` may mutate the
  scoresheet it is handed (§5.2), so candidates sharing one sheet would see each
  other: the first would enter the log and every candidate after it would read as
  a contact that was never made.
- **Candidates carry no uuid**, since a spot is not a record — results come back
  under caller-chosen keys. The *operation* still must carry its uuid, which is
  how the cold path reads the log; without one a candidate is judged against an
  empty log and nothing is ever a duplicate, silently. `ExtensionService`
  takes the uuid as its own argument and folds it in rather than trusting the
  caller's operation map, which for an `Operation.data` does not hold one.

> Migration note: this only changes regenerable cache contents. Old cached blobs
> are re-derivable (scoring is "never load-bearing",
> `scoring_service.dart:26-28`), so a version tag + lazy rescore is enough — no
> data migration. Note there is no data-migration precedent to lean on anyway:
> `schemaVersion` is 4 and every step so far is pure DDL.

#### 5.1.1 Why per-QSO scoring stays *out* of the QSON blob

A natural suggestion is to put scoring in the QSO object itself
(`scoring: [{type: 'cqww', alerts: ['dupe']}, …]`) rather than in a sibling
column. **Rejected** — `qso.data` is the synced record of truth, and three
mechanisms make derived scoring actively harmful there:

1. **Write amplification.** Every `data` write goes through `_restamped`
   (`repositories.dart:437-443`, bumps `updatedAtMillis`) and `_companionFor`
   (`:642-655`, sets `synced: false`). A rescore rewrites verdicts for *every*
   QSO in the operation, so logging one QSO into a 500-QSO contest would restamp
   and re-push 500 records.
2. **Self-triggering rescore loop.** The live-rescore fingerprint is
   `uuid:updatedAtMillis` (`operation_view.dart:378`, rationale at `:120-126`),
   deliberately built to be immune to a rescore's own writes. Scoring inside
   `data` would move the fingerprint on every rescore — forever. A named
   regression test pins this: *"caching scores never bumps updatedAtMillis — the
   invariant live rescore depends on"* (`repositories_test.dart:331`).
3. **Cross-device staleness.** `_buildPayload` uploads `{...q.data, …}`
   (`sync_engine.dart:392-396`) and `mergeFromSync` replaces `data` wholesale
   under last-write-wins. Verdicts depend on which *extension version* produced
   them, so devices would clobber each other's scores — and they would replicate
   into app-polo, which persists whole QSO objects but has no code that reads or
   refreshes a scoring field.

By contrast `updateScoreCache` (`repositories.dart:622-633`) writes only the
`score_cache` column — no `data`, no `synced`, no `updatedAtMillis`, and it
deliberately doesn't fire the sync `onChange`. The naming states the intent:
`score_cache` is *"cached … so list rendering never waits on the plugin
runtime"* (`database.dart:51-52`) and `local_data` is *"device-local state that
never syncs"* (`database.dart:19`).

The legitimate need behind the suggestion — extensions being able to *see*
scores — is real and is met by §5.7 instead.

#### 5.1.2 Cache freshness: rescore on open

Scores are only as good as the extension version that produced them, and
extensions get updated (a contest's rules are corrected, core scoring gains a
rule, and eventually bundles update at runtime). So the cache is a **render
fast-path, never truth**:

- **Opening an operation triggers a full rescore**, unconditionally.
- Cached values render immediately so list scroll never waits on the JS runtime
  (today's property, `scoring_service.dart:4-9`), then are replaced when the
  fresh pass lands.
- Within a session the incremental path applies: an append scores from the
  end-scoresheet; a mid-log edit replays from the nearest day checkpoint (§5.2).

This **already happens today**, but only incidentally: `_lastScoredFingerprint`
is ephemeral view state (`operation_view.dart:364-378`), `null` on a fresh open,
so the first QSO-stream emission always mismatches and schedules a rescore.
That is worth stating as an explicit invariant, because persisting the
fingerprint — an obvious "don't rescore what we already scored" optimization —
would silently reintroduce stale scores after an extension update, with no error.

One useful consequence: **checkpoints never need to be persisted.** Every open
rebuilds them from a full pass, so they can live in memory for the session, and
there is no checkpoint invalidation or versioning story to build.

### 5.1.3 Segments (M6) — the shape actually being built

§5.1's box decided segments are in scope and own three pieces. This is how they
land, written after reading what the code already does.

**The payload.** A `break`/`start` event row may carry `event.operation`: a
PARTIAL operation, spread over the base one, exactly as app-polo does
(`qsonToADIF.js:89-99`). Any operation attribute may appear, and `refs` and
`grid` are the two that matter — a second park, or a rover's new square.
`QsosRepository.addEvent` gains an optional override so a segment is reachable
without new UI.

**Resolution belongs to the core.** `ScoringService.rescoreOperation` filters
event rows OUT before building the payload, so nothing on the JS side can see a
segment even in principle. A pure `SegmentedOperation` in `halo_core` folds the
overrides in `startAtMillis` order and answers two questions: what the operation
looked like at a given instant, and what it looks like now. It stores one map
per SEGMENT, not per QSO — overrides are rare, so a 5000-QSO log holds a handful
of maps and a binary search, not 5000 copies.

**Getting it to the scorers.** The batched contract sends one `operation` for
the whole fold, but `ScoringHook.scoreQso`'s own doc already promises the
segment-effective one (`types.ts:377`). Rather than fattening every QSO with a
copy, the payload carries the base operation plus an ordered `segments` array,
and the SDK harness resolves per QSO as it folds — it already walks
chronologically for day boundaries, so this is a pointer advanced in the same
pass. Extensions change nothing: they receive the right `operation` because the
harness hands it to them.

**Selection spans segments.** `scorersFor` must consider the union of ref types
across the base operation and every segment, or a contest that only covers the
back half of a log never gets invoked at all.

**So the fold has to put back what selection let through.** Selecting a scorer
because *some* segment carries its ref means handing it the *whole* log. A QSO
whose segment carries no ref of that scorer's types was made when the activity
was not running, so the harness skips it outright — it doesn't even count toward
the day tally. Falling back to the selection ref instead would let a contest
that covered half a log claim all of it, and the Cabrillo built from that is a
false claim. This is the direct consequence of segments REPLACING (below): a
segment naming `refs` that omit ours has genuinely dropped us, so "no ref" is a
statement, not a gap to fill in.

**And the entry row follows the current segment.** `_activeRefTypes` (§5.3's
primary-field gate) reads the operation's own refs today, with a standing TODO;
it becomes the LATEST segment, so a contest that ended at a break stops claiming
the entry row.

The live single-candidate pass (`ScoringHook.scoreQso`) follows that same
segment, for the same reason — the scoring pills and the primary fields have to
agree about what is running. It gets the timeline as well: it always runs cold
(the host sends no `resumeFrom`), so it rebuilds the scoresheet from the log on
every keystroke, and that rebuild has to be segmented too or a contest's dupe
check counts contacts made before it started.

**Segments REPLACE, and they do not carry forward.** A `break`/`start` states
what is true for the stretch that follows. A segment that names `refs` owns them
outright — no union with what came before, because "I moved to a second park"
and "I am now at two parks" are different claims and only the operator knows
which.

An attribute a segment does NOT name falls back to the **base operation**, never
to the previous segment. The base is a default that lets an unsegmented log skip
segments entirely; it is not an accumulator. So a grid set in segment one does
not leak into segment two — anything meant to persist across segments is written
into each of them by whatever creates them, which is a UI concern.

This is a deliberate divergence from app-polo, which accumulates
(`operation = {...operation, ...qso.event.operation}`, `qsonToADIF.js:89-99`).

**Deliberately not in this milestone:** any UI for creating or editing a
segment. The data path and `addEvent` make one reachable and testable, but
choosing where that lives in the operation sheet is a separate design question,
and bundling it would make this milestone unreviewable.

### 5.1.4 Segments and exports — one export per REFERENCE

Scoring wants the segment-effective operation per QSO. Exports want something
different, and getting it wrong produces a plainly wrong file rather than a
subtly wrong score.

The motivating case: one operation that runs a contest throughout while also
activating two parks, with a stretch in the middle at neither.

**An activity that supports multiple references gets one export per
reference.** Not one export that knows about segments — two POTA exports, one
per park. And each is asked for, and generated against, a view in which it sees
**one operation carrying one ref, plus the QSOs that correspond to it**. The
export hook does not reason about segments at all; the core has already reduced
the log to the slice that reference is responsible for.

**How polo arranges this, and why HaLo can't copy it directly.** Polo collects
options in TWO passes (`dataExportOptions.js:136-172`):

```js
for (const ref of refs) {                        // per-REFERENCE
  findBestHook(`ref:${ref.type}`).suggestExportOptions({ operation, qsos, ref, settings })
  // keyed handler-format-exportType-refKey, so each reference gets its own option
}
findHooks('export').forEach(h =>                 // operation-WIDE
  h.suggestExportOptions({ operation, qsos, settings }))   // no ref
```

Per-reference exports come from `ref:<type>` hooks; operation-wide ones from
`export` hooks. The category a hook registers under is what decides which it
gets, so nothing has to disambiguate.

HaLo collapsed those into a single `export` category — every contest and
activity registers there — which is why there is nowhere for a `ref` to arrive.
Rather than reintroduce polo's split, `ExportOptionsRequest` gains an optional
`ref` and the host asks each hook **both ways**: once per reference whose type
it handles, and once with no ref at all. A hook answers whichever it supports —
contests answer the ref-less call, activities answer the per-reference one —
and options are keyed on `(hookKey, exportType, reference identity)` so a hook
that ignores the distinction cannot produce duplicates.

The generated export then sees the segment-effective operation for its
reference, with `refs` reduced to that one — matching polo's POTA, which sets
`exportData: { refs: [ref] }`, commented *"exports only see this one ref"*.

> **Unresolved:** which segment, when one reference spans several with
> different other attributes — an operator who leaves a park and returns to it
> later under a different grid. Planned as the FIRST segment carrying the
> reference, since that is where the activation began, but it is a guess and
> polo has no answer.

#### What of this is BUILT

Only the half with consumers: **an export is sliced to the segments carrying
its own ref type.** `ExportOption.refType` names that type, and the core hands
`generateExport` only the matching QSOs. All six contest exports set it; core
ADIF doesn't, because the full ADIF covers the operation rather than one
activity within it.

That was a live bug, not preparation. M6 gated scoring on segments and left
exports behind, so a contest that started or ended at a break put contacts made
when it wasn't running into its Cabrillo — the same mistake the scorer made,
in a file the operator submits.

**Deferred, with the reason:**

| Piece | Why not yet |
|---|---|
| One export **per reference** | **Built elsewhere, and not by the core.** When this was written POTA and SOTA registered no `export` hook at all, so the two-pass collection would have been an interface with no caller. The activities work (ham2k/halo-dist#398) then gave them one: `sdk/src/activityExports.ts` offers one ADIF per activated reference by encoding the reference into the `exportType` (`pota-adif:US-1234`) and declaring `refType` for the QSO slicing. No core change was needed — `exportType` round-trips verbatim and the panel keys selections by `hookKey:exportType`. Whether the core should ALSO grow a per-reference axis is now a genuinely open question rather than a deferral; nothing needs it. |
| `includeAllSegments` | Only means anything once an export is per-reference. |
| `includeOtherRefHandlers` | Same, and honouring it changes ADIF output users have already submitted (see the implementation note below). |

Until then, several refs of one type **union**: one export covers the type,
because quietly dropping half a log would be worse than covering both. And the
"which segment heads it" question above stays open, since it only arises for a
per-reference export.

The two-pass collection sketched above also needs rethinking before it is
built. It assumes each hook's own guard decides whether it answers a
per-reference call — but `core/adif`'s `suggestExportOptions` has **no guard**,
so it would answer every one and offer N+1 identical "ADIF Export" options. An
export that wants slicing probably has to opt in, as `refType` already does,
rather than the core inferring it from who answers.

Two flags widen that default view, each answering a different question:

| Flag | Question it answers |
|---|---|
| `includeAllSegments` | "Give me the whole log, not just the segments carrying my reference." The contest export, which covers the operation regardless of where the parks were. **Defaults off** — an export claims only its own reference's QSOs until it says otherwise. |
| `includeOtherRefHandlers` | "Let OTHER extensions contribute their fields to each QSO too." A full-log ADIF, which should carry everyone's fields; a park submission, which should not. |

**On the names.** `includeAllSegments` is what polo calls `combineSegmentRefs`
— but polo's flag doesn't select segments at all. It chooses whether the
effective operation's refs *follow* the segments or stay pinned to the base
(`qsonToADIF.js:89-99`); neither branch filters QSOs.

> **Corrected while implementing.** This section previously said polo has "no
> segment-based QSO filtering anywhere" and that per-reference slicing is "new
> in HaLo, not a port". Both are wrong. `filterQSOsWithSectionRefs` runs on
> EVERY polo export (`generateExports.js:37`, implemented in
> `@ham2k/lib-qson-tools`): it walks the log tracking `sectionRefs`, updating
> them at each `break`/`start`, and keeps a QSO only if its section carries the
> requested ref. That is `qsosFor`, shipped. So this is largely a PORT, which
> lowers the risk rather than raising it.
>
> **But polo only filters for a ref carrying an IDENTIFIER** —
> `withSectionRefs.filter(ref => ref?.type && ref?.ref)`. A contest ref is
> `{type: 'cqww', mode: 'CW'}` with no `ref`, so the list comes back empty and
> polo exports the WHOLE log for it. Polo therefore does not slice contest
> exports at all.
>
> **HaLo deliberately does** (fix-on-port, §8). A Cabrillo containing contacts
> made after the contest ended is a false claim in a submitted file, and
> §5.1.3 already gates contest SCORING exactly this way — leaving the export
> unsliced would have the score and the submission disagree, which is the thing
> §5.1.3 and §8 both exist to prevent.
>
> One more: this section says "contests answer the ref-less call, activities
> answer the per-reference one". In polo the categories are the other way
> round — contests register under `ref:<type>` (`CQWWExtension.js:27`), and
> only three hooks are in `export` at all.

`includeOtherRefHandlers` keeps polo's real semantics under a name that states
them. Polo's `includeOtherRefs` gathers `[...qso.refs, ...operation.refs]`,
finds each one's `ref:<type>` handler, skips the export's own, and merges that
handler's `adifFieldsForOneQSO` output — first definition wins, except a `false`
value which removes a field. It is about which extensions get to CONTRIBUTE,
not which refs are visible. Exactly one polo export sets it: core ADIF's "Full
ADIF Export".

> **Note for implementation:** HaLo behaves as though that were always on —
> `core/adif` calls `hooks.invokeAll('adifFields', …)` unconditionally, so every
> contributor's fields land in every ADIF, including the contest ADIFs that
> delegate to it. Honouring the flag means the default has to SUBTRACT, which
> changes existing ADIF output for scoped exports.

**Expect to revisit both flags.** They come from ONE motivating case,
generalised into two booleans, with no prior art to validate them. Four of
sixteen extensions are ported; the ones still to come are the ones likely to
stress the shape:

- **VHF contests (M7)** — a rover's grid changes per segment, and the export
  needs each QSO stamped with the grid true when it was made. That is a
  per-segment *value*, not an inclusion decision, and neither flag expresses it.
- **QSO parties (M10)** — county-line operation lets one QSO count for two
  locations, so "which slice does this QSO belong to" stops having one answer.
- **`georgia-pota` (M9)** — synthesises POTA refs from another extension's, so
  "segments carrying my own reference" is the wrong test by construction.
- **Multi-program activations** (WWFF and POTA at one site) — two exports over
  the same QSOs, each wanting its own subset.

A hook answering "is this slice mine?" would cover all four, at the cost of a
bridge crossing per segment. Not worth building on one case — but worth
recording that this IS one case generalised, and that polo validates none of it.

### 5.2 The scorer contract and the caching design

**Problem.** Full rescore on every append/edit is `O(N)` per scorer. With
multiple scorers and long contest logs this is exactly the cost you asked to
avoid. Dupes and multipliers are order-dependent ("first occurrence counts"), so
a change at position *i* can flip a *later* QSO new↔dupe — you genuinely must
replay forward from the change point. The lever is **bounding how far forward**.

**First, a clarification the per-QSO framing invites getting wrong.** DESIGN.md
§4 is non-negotiable: the per-QSO loop runs **inside the JS runtime**, in one
coarse bridge call ("score 500 QSOs in one call, not 500 calls"). A per-QSO
`scoreQso` method does **not** mean Dart calls it 500 times across the bridge —
Dart makes one call with the QSO batch (± a cached checkpoint) and gets back
scores + summary. Today's `core/scoring.scoreQsos` already works exactly this
way (`scoring.ts:183`, loop at `:208`).

**The shape of the problem.** The contract must serve three jobs —
**batch** (score everything), **incremental** (append/edit without O(N) rework),
and **live** (score the in-progress QSO, recording nothing). All three are the
same primitive: *score one more QSO against the running scoresheet*. An append
scores from the end-scoresheet; a mid-log edit scores forward from the nearest
checkpoint; the live QSO is scored and the result thrown away. Because the
contract exposes exactly that primitive, the core implements
caching/incremental/live **once** instead of all 12 contests re-implementing
them.

**Contract (decided).** A contest writes three small pure functions; the core
drives the loop, checkpointing and live path uniformly. The methods are named
for the **scoring process**, not for the functional-programming machinery
underneath — the running state is a **scoresheet**, and `scoreQso` /
`summarizeScore` mirror app-polo's own vocabulary:

```ts
// The scoresheet is the running record a scorer keeps while working through a
// log: worked calls, mult sets, running points. Opaque to the core, owned by
// the scorer, JSON-serializable.
interface ContestScorer<Scoresheet = JSONValue> {
  /// A blank scoresheet. `ref` is the operation ref that selected this scorer
  /// (§5.1), carrying its setup — mode, our-zone, our-section; absent for
  /// `scope: 'always'` scorers.
  startScoresheet(a: { operation; ref? }, ctx): Scoresheet

  /// Score ONE QSO against the scoresheet so far, returning the updated
  /// scoresheet and that QSO's score. Pure, no I/O. This one function serves
  /// the full pass, an append, a mid-log replay, AND the live in-progress QSO
  /// (where the returned scoresheet is simply discarded).
  ///
  /// `operation` is the **segment-effective** operation for this QSO — base
  /// operation with any `break`/`start` segment overrides applied (§5.1), so a
  /// rover's current grid and a segment's refs are simply what the scorer reads.
  scoreQso(
    a: { scoresheet: Scoresheet; qso; operation; ref? }, ctx,
  ): { scoresheet: Scoresheet; score: QsoScoreVerdict }

  /// Render the scoresheet into display tallies, per day and per operation.
  /// The tally keys are the scorer's own — nothing outside interprets them.
  summarizeScore(
    a: { scoresheet: Scoresheet; operation; ref?; scope: 'day' | 'operation' }, ctx,
  ): Record<string, ScoreTally>
}
```

What the core does with them:

```
scoresheet = resumeFrom ?? startScoresheet()   // resumeFrom = cached checkpoint
for qso in tail:                               // tail = whole log, or QSOs ≥ change point
  { scoresheet, score } = scoreQso(scoresheet, qso)
  record score; snapshot scoresheet at day boundaries → checkpoints
summarizeScore(scoresheet, 'operation'); day summaries from the snapshots
```

- Directly mirrors app-polo's `scoringForQSO` / `accumulateScoreForOperation` /
  `summarizeScore`, so contest logic ports faithfully — but because the core
  owns execution, caching and the live path come for free.
- The scoresheet must be JSON (worked-call maps, mult sets → arrays). Payloads
  are small.
- `scoreQso` unit-tests as `(scoresheet, qso) → score` fixtures — no array or
  DB scaffolding.
- Note `scoreQso` here **replaces** today's separate live-path hook method: the
  live call is just this function applied to the candidate QSO.

**Worked sketch** — `simple-contest` in full:

```ts
startScoresheet: () => ({ worked: {} }),               // call -> [band|mode]
scoreQso: ({ scoresheet, qso }) => {
  const k = `${qso.band}|${qso.mode}`, seen = scoresheet.worked[qso.their.call] ?? []
  const dupe = seen.includes(k)
  return {
    scoresheet: { worked: { ...scoresheet.worked, [qso.their.call]: [...seen, k] } },
    score: dupe ? { value: 0, dupe: true, alerts: ['duplicate'] } : { value: 1 },
  }
},
```

`cqww` is the same skeleton with `scoresheet.mults` a set of
`band|Z##`/`band|C##` keys, `scoreQso` pushing `notices:['newMult']` on a new
key, and `summarizeScore` computing `points × mults.size` — a near-mechanical
lift of its existing `scoringForQSO`/`accumulate`/`summarize`.

**Caching / incremental rescore.** The core checkpoints the serialized
scoresheet at **day-section boundaries** (HaLo already sections by day), stored
next to the summary in `local_data.scoring`:
- **Append at end** (logging a QSO — the hot path): restore the cached
  end-scoresheet, `scoreQso` the new QSO(s), update the summary. `O(new QSOs)`,
  **no whole-log read**.
- **Edit / delete / insert at position *i***: restore the nearest checkpoint
  `≤ i` and replay forward. `O(distance to last checkpoint)` — not `O(N)`.
- The cached **end-scoresheet also serves the live path**: instead of rebuilding
  worked-state from the entire log on every debounced keystroke (what
  `core/scoring`'s `scoreQso` does today, `scoring.ts:254-300`), score the
  candidate against the cached end-scoresheet. Same cache, three payoffs.

> **Checkpoint granularity is deliberately deferred to M0.** Day boundaries are
> free (the scorer already sections by day) and bound a mid-log edit to at most
> one day's replay. Whether to add a second axis — a checkpoint every *K* QSOs,
> so a 1,000-QSO single-day CQ WW run doesn't replay the whole day — will be
> decided from **real timings measured during M0** on a realistic contest log,
> not guessed now. The contract above is unaffected either way: granularity is
> purely a core-side policy.

**Subtleties.**
- **Day-sectioning already exists:** `ScoreTally.for` distinguishes day-scoped
  tallies (`qsoCount`) from carry-over ones (`dxcc`, `bandsAndModes`). The core
  snapshots at day boundaries and calls `summarizeScore` per boundary; `for`
  tells the display which resets. No new concept.
- **Multi-scorer merge composes:** scorers are independent, so fan-out is "run K
  scorers over the same batch." Core dupe/DXCC/bands scoring is *just another
  scorer* registered under `core` — an `always`-scoped one, which runs for every
  operation but yields its worked-before judgement on any QSO another scorer has
  judged on that axis (§5.1).
- **`ourInfo`** (our continent/country/zone, needed by cqww/arrl-dx) is
  operation-scoped — read in `startScoresheet` off `ctx`/`operation`, not carried
  per-QSO.
- **An edit that changes a QSO's time** moves it in sort order; the change point
  is `min(old, new)` position. The core knows both and picks the checkpoint.
- **Live during a mid-log edit** wants a scoresheet *excluding* the edited QSO.
  Append is exact and O(1) from the end-scoresheet; a mid-log edit falls back to
  the nearest earlier checkpoint.

**Rejected alternative — resumable batch.** Keep one
`scoreQsos({ operation, qsos, priorScoresheet? })` and let each contest own its
loop and resume protocol. Smallest core change and maximum author control, but
every contest re-implements resume and the live path — so caching correctness
would live in 12 places, and a contest that ignored `priorScoresheet` would
silently degrade to a full rescore, an invisible performance bug. Rejected in
favor of the core owning that logic once.

**Applicability check.** The contract assumes single-pass causal scoring (a
QSO's score depends only on QSOs before it). **Verified against all 12
contests** — every one is single-pass: rover our-grid is just scoresheet state
updated on event rows, and county-line N×M is just one QSO's score listing
several mult keys. Nothing needs lookahead or a second pass.

**Risk note.** M0 exercises this contract before anything depends on it: refactor
`core/scoring` into the `ContestScorer` shape (it already is one internally) and
run it against the same log as `simple-contest`. If the shape proves
wrong there, that is the moment to revisit — before 11 more contests are written
against it.

### 5.3 Exchange inputs: the logging-control catalog

Exchanges come in three flavours, and a survey of all 12 contests plus Field Day
confirms they need genuinely different **widgets**, not just different
validation:

| Flavour | Examples | Needs |
|---|---|---|
| **Freeform** | NAQP name; ARRL DX state-or-power; IARU zone-or-HQ; simple-contest exchange | plain text + transforms |
| **Constrained** | Field Day class `1A`/`2B`/`14F`; CQ WW zone 1–40 | pattern validation, numeric keyboard |
| **Searchable options** | QSO-party counties; ARRL/RAC sections; OHSP park abbreviations; RSGB districts; NAQP's 111 locations | a real suggestion list |

Orthogonal to all three, most exchanges can be **suggested** from the callsign
being worked — see "Suggested values" below.

**The rule that keeps the catalog from sprawling** (DESIGN.md §11 names catalog
creep as a risk): *a new `kind` is earned by a different **widget**, never by
different validation.* A Field Day class field types, transforms and focuses
exactly like a NAQP name field — it just rejects bad values. So constrained is a
**modifier on `text`**, not a kind of its own. That yields four kinds:

```ts
type InputDescriptor =
  | RefListInputDescriptor      // exists today
  | TextInputDescriptor         // freeform AND pattern-constrained
  | OptionsInputDescriptor      // searchable set
  | SerialInputDescriptor       // §5.8

interface TextInputDescriptor {
  kind: 'text'
  refType: string          // the ref the value lands on
  field: string            // the key within it, e.g. 'theirZone'
  placeholder?: string
  pattern?: string         // anchored + case-insensitive, same as refList
  transforms?: {…}[]       // the live-reformat passes refList already supports
  numeric?: boolean        // numeric keyboard (CQ zone)
  uppercase?: boolean      // DEFAULT true — see below
  maxLength?: number
  suggestedValue?: string  // lookup-derived prefill; never overwrites typing
}

interface OptionsInputDescriptor {
  kind: 'options'
  field: string
  /// Inline for small sets; `optionSet` for large ones (see below).
  options?: { code: string; name?: string; group?: string }[]
  optionSet?: string       // '<extensionKey>:<setKey>', e.g. 'operation-data:arrlSections'
  matchOn?: ('code' | 'name')[]   // default both
  allowFreeform?: boolean  // accept a value not in the set
  multiValue?: { separator: string }  // QSO-party county lines ("ORDES/JEF")
  minCharsForSuggestions?: number     // polo uses 3
}
```

Two rules M1 settled, both of which a contest would otherwise hit:

- **`pattern` is compiled identically for every kind** — anchored (`^(?:…)$`)
  and case-insensitive, with a malformed regex disabling validation rather than
  throwing. Before this, `text` compiled it unanchored and case-sensitive while
  `refList` did not, so the same pattern string meant two different things
  depending on which kind an extension put it on.
- **`uppercase` defaults to true**, matching every other logging field and the
  uppercase-unless-explicitly-mixed-case convention. `textCapitalization` alone
  is only a soft-keyboard hint, so on desktop a state typed `ma` stayed
  lowercase — and then failed the case-sensitive pattern above. Set
  `uppercase: false` for genuinely mixed-case data.

  **The worked example this used to give was NAQP's operator name, and that was
  wrong** (corrected at M4, when it was ported). An on-air exchange is not prose:
  an operator not reaching for shift logs `bob`, and a Cabrillo full of
  mixed-case names reads as sloppy against a field everyone else submits in
  caps. polo forces uppercase there too. No contest exchange has yet wanted
  `uppercase: false`; free-prose fields like notes are where it belongs.

**Correction at M7 — no `grid` kind was needed.** This RFC originally proposed
one for a concrete reason: Maidenhead's case convention (`AB12cd`) cannot be
expressed as a find/replace transform, because regex replacement can't change
case. That's real, but it only bites at 6+ characters (the lowercase subsquare
letters) — `arrl-vhf-tests`'s 4-character exchange (`FN31`) has no case
component at all, so `kind: 'text'` with a Maidenhead-shape `pattern` is
exactly correct as-is, no bespoke widget required. The catalog-creep rule
above held: a grid field types and focuses exactly like any other pattern-
constrained one. Revisit this if `r1-vhf-tests`/`rsgb-vhf-tests` (M8, 6-char
grids) turn out to need the case-transform after all — `normalizeGrid()`
already exists in `halo_core` for it (used by the core `their.grid` field),
so it may still be reachable as a `transforms` pass rather than a new kind.

#### Suggested values from callsign info, lookups, and the log

Most contest exchanges are *predictable* from who you're working, and polo leans
on this heavily: CQ WW prefills the zone from the guessed CQ zone; ARRL DX hints
the state; NAQP reuses the name from a prior QSO with the same call, falling back
to the looked-up name, and derives the location from state / DXCC entity.

**The plumbing for this already exists** — no new hook is needed:

- `loggingControls({operation, qso})` receives the in-progress QSO **including
  `their.guess`** from the callsign-lookup pipeline, and is **re-invoked when a
  lookup resolves** (`types.ts:281-290`; the panel passes
  `refreshActivityControls`, `logging_panel.dart`). That callback answers
  **null** when the fan-out could not be read, which the panel keeps its
  current controls over — an empty list means the activities want none, and
  installing one for a failure blanks the fields mid-QSO.
- It is `async`, so an extension may `await host.dbLookupSelectOne` /
  `dbLookupSelectAll` / `dbLookupSelectByLocation` (`sdk/src/index.ts:175-184`,
  Dart side `extension_service.dart:1031-1063`) to consult offline lookup tables
  — county lists, section tables, a bundled dataset.
- `ctx.getQsos(operationUuid)` covers "what did I get from this call last time",
  which is how NAQP's name guess works.

Crucially this runs **once per callsign resolution, not per keystroke**, so a DB
query here is affordable — the same budget `decorateRef` already spends.

What the catalog must add is the distinction between *hinting* and *filling*,
which polo conflates:

```ts
interface ValueInputBase {
  field: string
  placeholder?: string     // hint only — never becomes the value
  suggestedValue?: string  // pre-filled into the field, flagged as a guess
}
```

with one rule the **core** enforces, so no extension has to:

> A `suggestedValue` is written into the field only while the field is empty or
> still holds a previous suggestion. Once the operator types, their value wins,
> and later suggestions downgrade to the placeholder. A lookup that resolves
> late can never clobber what someone already keyed in.

That rule is the whole reason to put this in the core rather than leave it to
extensions. Polo has no such guarantee: NAQP writes its guess back with a
`setTimeout(…, 1)` `updateQSO` and a `guess: true` marker, and each extension
re-implements the "don't stomp the operator" logic — or doesn't.

For searchable sets, the same information can *rank* rather than fill:

```ts
interface OptionsInputDescriptor {
  …
  preferredCodes?: string[]   // float likely values to the top of the list
}
```

so a QSO party can surface the counties of the caller's guessed state first
while still allowing any value — better than a prefill, which would be wrong
often enough to be annoying.

Worked examples, all expressible with the above:

| Contest | Field | Mechanism |
|---|---|---|
| CQ WW | zone | `suggestedValue` from `their.guess.cqZone` |
| ARRL DX | state *or* power | `placeholder` from `their.guess.state` (never filled — polo hints only) |
| NAQP | name | `suggestedValue` from a prior QSO via `ctx.getQsos`, else `their.guess.name` |
| NAQP | location | `suggestedValue` derived from state / entity prefix |
| QSO party | county | `optionSet` + `preferredCodes` from the guessed state |
| IARU HF | zone/HQ | `placeholder` from the guessed ITU zone |

**Deliberately NOT added: `select` / `segmented`.** Polo uses those only for
*operation-level* setup (mode, station type, power class), never in the per-QSO
exchange row — and HaLo already has a richer, rendered schema for exactly that in
`FormDefinition`/`FormField` ([forms.md](../extensions/forms.md)). **Decided:**
reuse and extend that schema rather than duplicating enums into the input union
(§5.4). The extension worth making is the reverse direction — teaching
`FormField` the same searchable-options field backed by `optionSet`, so picking
"my ARRL section" at operation setup uses the same dataset and widget as the
per-QSO exchange.

**Option sets: registered once, not shipped per call.** `loggingControls` is
re-invoked whenever a callsign lookup resolves — roughly once per QSO — so
inlining a large option list would push it across the bridge that often. Measured
sizes say inline is fine for almost everything, and only QSO parties aren't:

| Dataset | Entries | Where |
|---|---|---|
| ARRL + RAC sections | 88 | `operation-data`, shared by FD and WFD |
| US states / Canadian provinces | 50 / 13 | `operation-data` |
| RSGB districts; OHSP parks; NAQP locations | 132 / 76 / 111 | inline in the extension |
| QSO-party counties (+ neighbouring parties) | 3–259 per party (3,478 total); up to 351 more | **registered `optionSet`** |

So large sets register once and the descriptor carries only a pointer:

```ts
/// Registered from onActivation, alongside `dataFile`. The core loads it at
/// most once per (key, version) into the existing `lookups` table, so search
/// runs in SQLite and works offline.
interface OptionSetDefinition {
  key: string
  version?: number
  entries?: OptionEntry[]
  load?: () => Promise<OptionEntry[]>
}
```

This reuses the `dataFile` → `lookups` → `dbLookupSelectAll` machinery that
already exists and adds no sync surface.

> **Deferred at M5, and the claim above is wrong.** It does NOT reuse existing
> machinery. The host exposes three lookup calls and all three READ
> (`dbLookupSelectOne`/`SelectAll`/`SelectByLocation`) — nothing can write rows
> into the `lookups` table, and the one thing that fills it, `DataFileDefinition`,
> mandates `url` + `maxAgeInDays` + `fetchType`, i.e. an HTTP fetch of a file the
> extension does not have. A registered `optionSet` therefore needs a new host
> capability, not a pointer.
>
> It also has no consumer yet. `kind: 'options'` ships with its set **inline in
> the descriptor**, which the table above already prescribes for everything except
> QSO-party counties — and `qp` moved to M10 (§7). Ohio's 76 parks are ~2KB
> against a scoring payload that carries the whole log on every pass, so the cost
> the registered form exists to avoid is not measurable here. Build it when a
> party's 3,478 counties arrive, and measure first.

**Shared datasets live in a new core extension: `operation-data`.** Rather than
each contest vendoring its own copy of the US states table, one always-on core
extension owns the reference data the rest of the app draws on — US states,
Canadian provinces, ARRL/RAC sections, and in time **band plans** and the other
operating reference tables that today sit in Dart (`halo_core`'s `ham/radio.dart`)
or in the `@ham2k/lib-operation-data` package it is named after. Contests then
address them by key:

```ts
input: { kind: 'options', field: 'section', optionSet: 'operation-data:arrlSections' }
```

One copy, one maintainer, addressable by any extension, and offline by
construction since it lands in the same `lookups` table as `dataFile` datasets.
Only the contest-facing option sets are in scope for this effort; folding band
plans in is the same extension's broader remit, not a prerequisite for M0.

#### Amended at M4: `operation-data` can only ever serve the UI, and nothing needs it yet

Two things came out of building against this design that the design did not
anticipate.

**A core extension structurally cannot serve a scorer.** `ContestScorer`'s three
methods are SYNCHRONOUS (`types.ts`: `startScoresheet`, `scoreQso`,
`summarizeScore` all return plain values, not promises), while the only
cross-extension call path — `hooks.invokeOne` → `kernel.invokeLocal` — is async.
So a scorer can never await an option set. The one synchronous channel into a
bundle is `__polo.sharedModules`, and `build-config.mjs` gates that on
`/^(@ham2k\/lib-|i18next$)/`. The consequence is a hard split, and it is worth
stating before someone designs against the wrong half:

- **Scorer-visible reference data must live in an `@ham2k/lib-*` package** — for
  which `@ham2k/lib-operation-data` is already allowlisted in `build-config.mjs`.
- **An `operation-data` EXTENSION can only back async UI lookups** — form fields
  and logging-control option lists. That is still worth having; it just isn't
  the "one copy the rest of the app draws on" this section imagined.

**And nothing in the porting sequence needs it.** Checked when M4 came up:

| Would-be consumer | What it actually needs |
|---|---|
| `iaru-hf` | Nothing. ITU zone and continent come from the bundled country file. |
| `naqp` | 110 location codes — 613 bytes — which the table above already assigns *inline in the extension*. |
| `arrl-dx` (shipped, M2) | Nothing. It uppercases what the operator typed and uses that as the multiplier key. |
| ARRL/RAC sections | Only FD and WFD, which are activities and appear in neither §7's sequence nor §9's twelve contests. |

So `operation-data` is **deferred until a real consumer appears** rather than
built speculatively at M4. The table above stands as the plan for when one does.


**Two behaviours to carry over from polo's logging panel:** SPACE advances to the
next exchange field, and serial fields deliberately **opt out** of that cycle
(polo passes `skipFocus` on every "Our #"). HaLo's logging controls already own
the SPACE-cycles-focus contract, so the catalog needs a per-control `focus:
'skip'` to express the opt-out.

- **Dynamic label/placeholder** (ARRL DX "Their State" vs "Their Power") needs no
  new mechanism: `loggingControls` already receives `{ operation, qso }`
  (`types.ts:287`), so the extension varies `label`/`placeholder` off
  operation state.
- **Round-trip:** unchanged from §5.4 — the core writes the typed value into the
  QSO's contest ref via the **same core-owned path `refList` uses**. No
  `updateOperation` host call is needed for any kind in this catalog; only §5.8's
  sequences add new persistence, entirely core-side.

**Only a running activity gets the entry row.** Every *enabled* extension is
asked for logging controls on every operation, but a `text`/`serial` control
renders as a PRIMARY field only when the operation carries a ref of the type it
writes to. The entry row is the scarcest space in the app, and merely having a
contest installed must not put its exchange in front of someone logging an
ordinary QSO — nor, worse, put a `serial` field there issuing numbers from a
series nobody is keeping.

This is enforced by the **core** (`logging_controls.dart`'s `_textControls`),
not by each extension. Extensions may still return `[]` early off-contest, and
the shipped four do, but purely as an optimization — it skips a country-file
annotation per keystroke-triggered refresh, in the JS isolate, once per enabled
contest. Forgetting it is invisible to the operator.

`refList` controls are deliberately **not** gated: POTA's hunter chip is the
case that matters, since a park is chased from whatever operation happens to be
running. The rule is about primary real estate, not about relevance in general.

Today the gate reads the operation's own refs; once segments land (§5.1) it
reads the segment-effective operation, so a contest covering part of an
operation only claims the entry row during its own segment.

### 5.4 Per-operation contest config (ref path)

A contest's setup — contest identifier, sent exchange, and later mode /
station-type / event — lives as **fields on the contest ref** in
`operation.refs`, persisted through the existing `_saveOperationData` /
`_saveRefs` path (`activities_view.dart:304-320`). The contest exposes these as
`operationControls`; the core renders and persists them exactly as it persists
`refList` refs today. **No `updateOperation` host call is needed** — not for the
first increment, and not for serials either (§5.8 keeps its counters entirely
core-side).

**Setup beyond plain text uses the form schema, not new input kinds.** A
contest's setup is often enum-shaped — ARRL DX's mode and W/VE-vs-DX station
type, CQ WW/WPX mode, IARU station type, Field Day power class. Rather than grow
the logging-control union with `select`/`segmented`, an `operationControls` entry
carries a **`FormDefinition`** ([forms.md](../extensions/forms.md)), which the
core renders with the existing `FormRenderer` and persists onto the contest ref
through the same path above:

```ts
operationControls: async ({ operation }) => [{
  key: 'arrl-dx/setup', label: 'ARRL DX',
  input: { kind: 'form', form: { fields: [
    { key: 'mode',        type: 'radio',  options: [{value:'CW'}, {value:'SSB'}] },
    { key: 'stationType', type: 'radio',  options: [{value:'wve'}, {value:'dx'}] },
    { key: 'exchange',    type: 'text' },
  ] } },
}]
```

Two extensions to the form schema fall out and should land with it: the
**searchable-options field** backed by `optionSet` (§5.3), so "my ARRL section"
uses the same dataset and widget as the on-air exchange; and **dynamic labels**,
since ARRL DX's sent-exchange field is "Your Power" or "Your State/Province"
depending on the station type chosen in the same form.

**A form field key IS a ref key, and some ref keys belong to the core.** This
bit NAQP during M4 and is worth stating outright, because nothing enforces it.
The setup form's values are written onto the contest ref under their field keys,
and `decorateRef` then writes DISPLAY data onto that same ref — `label`,
`shortLabel`, `program`, and `name`, which the Activities row renders as its
subtitle. The decorated ref is what gets persisted. So a setup field called
`name` is silently overwritten by whatever `decorateRef` composes, and the
contest then exports a display string as its sent exchange. NAQP's fields are
`ourName`/`ourLocation` for exactly this reason. **Prefix a setup key whenever
it could collide with `label`, `shortLabel`, `program`, `name`, `type` or
`ref`.**

> **Narrowed at M5.** `ref` is the one exception, and this rule as written
> forbade what §5.6 elsewhere prescribes. A multi-event contest keeps the event
> key in the ref's own `ref` field, and the setup form is the only operation-level
> editor there is — so `stateparks` declares a `select` field keyed `ref` to
> choose the event. That is safe *because the form owns the ref's identity*: the
> form result is merged over the existing ref, `_editRef` finds the row by the
> pre-edit ref before replacing it, and a form activity is added keyed on `type`
> alone, so one event per operation falls out. Read the rule as **never write a
> core key you don't own** — display keys always belong to `decorateRef`, and
> `ref` belongs to a form only when the form is what chooses it.

**What each display key means.** `decorateRef` owns four, and which one a
surface reads is not something an extension gets to choose — so an extension
that mixes up their jobs has no way to fix the result later:

| key | says | shown by |
| --- | --- | --- |
| `label` | the event in full, with its variation and, where there is one, the running's year — "CQ WW CW", "ARRL Field Day 2027" | the Activities row's first line, for a form-configured ref |
| `shortLabel` | the same event, abbreviated to fit — "CQ WW CW", "FD 2027", "OH SP" | the operation header's refs line, the information panel's heading, the location screen's tile, and the Activities row for a ref that is *not* form-configured |
| `name` | what this reference IS beyond its identity — a contest's sent exchange, a park's name — or, while a required exchange is still empty, that the entry is not set up | the Activities row's second line |
| `program` | the family the reference belongs to — `Contest`, `POTA` | grouping and filtering |

**`shortLabel` names the EVENT, never the operator's own exchange.** It is the
only thing three surfaces show, so an exchange there — "3A ENY" — leaves them
naming no contest at all, and reads identically for two different contests in
the same season. The exchange has a field of its own: `name`. Where the full
`label` is genuinely too long for those surfaces, the answer is a shorter form
of the *event* ("FD 2027", not "ARRL Field Day 2027"); most contests have no
such problem and simply set `shortLabel: label`.

The Activities row leads with `label` for a form-configured ref and with
`shortLabel` otherwise (`activityRowTitle` in `activities_view.dart`): a
contest's identity is a name, and a plain reference activity's is a code
("POTA US-1234") that its own `label` would only pad. Both `label` and
`shortLabel` must therefore be present and both must name the event.

A **suggestion is persisted verbatim and never runs through `decorateRef`**
(§5.6), so it has to carry all four itself, composed to say exactly what the
hook would compose for the same reference. Any disagreement makes one
operation read two different ways depending on how it was added.

#### 5.4.1 Conditional fields (M4)

IARU HF is what forces this. Its setup shows **one of three** sent-exchange
controls depending on the station type: a normal station sends its ITU zone, an
HQ station its society abbreviation, an IARU official one of `AC`/`R1`/`R2`/`R3`.
Nothing in HaLo can express that today — `FormField` has no visibility predicate,
and the two obvious workarounds are both closed:

- A `FormDefinition.onChange` closure **cannot survive the trip** across the
  bridge; `FormInputDescriptor` says so explicitly, and the definition is static
  JSON by construction.
- Recomputing the descriptor per `operationControls` call — arrl-dx's trick for
  its dynamic *label* — cannot change a field **inside an already-open dialog**,
  because the controls are loaded once on init.

So the predicate is declarative and lives on the field:

```ts
interface FormField {
  // …
  /// Show this field only while a sibling holds one of these values. A list
  /// means "any of". Naming a field that does not exist resolves to null and
  /// therefore hides — safe rather than a crash.
  visibleWhen?: { field: string; equals: JSONValue | JSONValue[] }
}
```

**Only `build` filters.** `FormRenderer` passes `controller: _controllers[key]`
with no lazy creation, so a field first initialized when it becomes visible would
render against a null controller and silently drop everything typed into it — a
hazard the class's own doc comment already names. Field registration, state
initialization and submit therefore keep iterating **every declared field**; the
visibility filter applies to the rendered element list alone.

**Hidden fields still submit their values**, which is the behaviour we want: an
operator who types a zone, switches to HQ, and switches back gets their zone
again. It does mean a contest reading these values must select by the
discriminator field — never "first non-empty".

### 5.5 Cabrillo export

- A contest registers an `ExportHook`: `suggestExportOptions` offers a
  `'cabrillo'` format alongside `'contest-adif'`; `generateExport` builds the
  Cabrillo header block + per-QSO `QSO:` rows (app-polo's
  `cabrilloHeaders` / `qsoToCabrilloParts` logic).
- **Correction to an earlier draft of this RFC:** `@ham2k/lib-qson-cabrillo`
  only exports `cabrilloToQSON` — it is an *importer*, with no writer. The
  generator is therefore ported from polo's `src/tools/qsonToCabrillo.js` and
  lives in the contest extension (`simple-contest/src/cabrillo.ts`), written
  contest-agnostically so the next contest shares it rather than copying. It
  does use `fmtCabrilloDate`/`fmtCabrilloTime` from `@ham2k/lib-format-tools`,
  which are available.
- ADIF contest fields ride the existing `adifFields` hook — no new infra.
- The Dart export picker is format-agnostic at the type level
  (`ExportResult.mimeType`, §3.4); confirm the picker UI surfaces a non-`adif`
  option during implementation.
- **The export hook scores for itself when the cache is cold.** A Cabrillo export
  needs per-QSO points and mults, and on a freshly-synced device the score cache
  is empty (§5.1.1 — it never syncs). Rather than have the core force a rescore
  before every export, `generateExport` runs the contest's own `ContestScorer`
  over the QSOs it was handed whenever `_scoring` (§5.7) is absent. The scorer is
  the same module, so this is a few lines, and it makes the export
  **self-sufficient** — correct on any device, in any cache state, with no
  ordering dependency between scoring and exporting.

**REG1TEST/EDI is in scope** for this effort (M8), not deferred: the R1 and RSGB
VHF families submit EDI rather than Cabrillo, so it is the same
"contest-registers-a-non-ADIF-exporter" shape as above, with a
`qsonToReg1test`-style writer ported from polo.

### 5.6 QSO Parties: one extension, many events, surfaced through `suggest`

Issue #149 asks that QSO Parties and State POTAs "provide separate extensions
for each event, sharing some common logic." **The goal is discovery, not
packaging** — a user should find "Texas QSO Party" by name rather than enable a
`qp` extension and then hunt for Texas in a dropdown.

That goal is met without splitting the bundle. `qp` (and `stateparks`) stay
**one extension each**, and every event is offered as its own entry in the
operation sheet's **activity suggestion/search** — the existing `suggest` hook
(`ActivityHook.suggest → ActivitySuggestion[]`, `types.ts:287`), which already
powers "add activity" and is what POTA/SOTA use for references:

```ts
// qp's suggest — one suggestion per party, not one extension per party
async suggest({ searchTerm }, ctx): Promise<ActivitySuggestion[]> {
  return PARTIES
    .filter((p) => matches(p, searchTerm))          // "texas", "TXQP", "TX"
    .map((p) => ({
      type: 'qp',
      ref: p.key,                                    // 'txqp'
      name: p.name,                                  // 'Texas QSO Party'
      relevance: relevanceFromDate(p.nextRunsAt),    // this weekend ranks first
    }))
}
```

Why this is the better shape:
- **Discovery is identical** — the user searches "Texas" in the activity picker
  and gets the party directly. The dated hint polo's dropdown showed ("This
  weekend", "in 12 days") becomes `relevance`, which the core already sorts on.
- **The event-picker UI disappears** from the M5 critical path either way.
- **No ~50-bundle problem.** Bundles are self-contained IIFEs each carrying
  their own SDK copy, so 50 extensions would have needed a shared-engine
  mechanism, generated manifests, and a much larger `index.json` (which must
  list even *disabled* extensions). None of that is needed now — **this closes
  what was the RFC's hardest open question.**
- **Ref-gated scoring still works unchanged** (§5.1): the scorer declares
  `refTypes: ['qp']` and receives the matching ref, whose `ref` field names the
  specific party (`txqp`), which selects that party's rules and county list.

The same treatment applies to `stateparks`, which has the identical
one-extension-many-events structure — assumed here unless decided otherwise.

### 5.7 Extensions can't currently see scores — the QSON projection

Extensions only ever receive `qso.data`. Both paths strip everything else:

```dart
// qsonPayloadFor — extension_service.dart:34-37
'qsos': [for (final qso in qsos) qso.data],
// host getQsos — extension_service.dart:1019-1030
return [for (final qso in list) qso.data];
```

So per-QSO verdicts are invisible to extensions, which blocks four things this
RFC depends on:
1. **Cabrillo export (§5.5)** — needs each QSO's points/mults, and
   `ExportService` calls `qsonPayloadFor` (`export_service.dart:73, 92`), so an
   export hook is verdict-blind today.
2. **`adifFields`** — same payload; contest ADIF fields derived from scoring
   have no access.
3. **Incremental scoring (§5.2)** — feeding prior verdicts and a checkpoint back
   into the batch call is the whole premise.
4. **The live path** — `scoreQso` replays the entire log on every debounce
   (`scoring.ts:254-300`) precisely because `getQsos` hands it verdict-free QSOs.

**Fix:** keep `score_cache` as the device-local column (§5.1.1) and *project* it
into the QSON that extensions **receive**, without ever storing or syncing it:

```dart
'qsos': [for (final qso in qsos) {...qso.data, if (qso.scores != null) '_scoring': qso.scores}],
```

The `_` prefix is the ecosystem's existing marker for transient, non-persisted
fields (app-polo strips `_isNew`/`_needsLookup` before writing). `Qso.scores`
already decodes defensively and returns `null` on a parse failure, so a cold or
corrupt cache simply omits the key.

> **Guard — the projection must not reach exported files.** `ExportService`
> reuses `qsonPayloadFor`, and the dev QSON export dumps the payload verbatim.
> Since app-polo persists whole QSO objects it receives, an export/import
> round-trip could otherwise smuggle stale verdicts into synced polo data — the
> exact failure §5.1.1 avoids, through a back door. Strip `_scoring` on the
> file-export path explicitly; don't rely on importers ignoring `_` keys.

> **Cold cache — resolved.** On a freshly-synced device the cache is empty (it
> never syncs), so an export can't rely on it. **Decided:** the export hook
> scores for itself when `_scoring` is absent (§5.5). That demotes this whole
> projection from a *correctness* requirement to a **performance optimization** —
> exports stay correct without it, they just avoid re-scoring when the cache is
> warm. Which in turn means §5.7 need not land in M0 alongside Cabrillo; it can
> follow once there's a measured reason.

### 5.8 Serial numbers: a core-owned labeled sequence service

**What polo does today, and why it can't be ported.** There is no core serial
infrastructure at all: four extensions each hand-roll ~30 lines of counter logic,
keeping the counter as an ad-hoc `nextNumber` on the operation's contest ref and
mutating it through a full `setOperationData` on every logged QSO. Concretely:

- **Three of the four carry the same typo** disabling the monotonicity guard
  (`CQWPXExtension.js:310`, `QSOPartiesExtension.js:878`,
  `RSGBVHFContestsExtension.js:485`; only `Region1VHFContestsExtension.js:423` is
  correct — the fix was never back-ported). With it, editing QSO #5 of a 400-QSO
  log resets the counter to 6 and every later QSO duplicates.
- Numbers are **claimed at compose time**, so wiping a half-typed QSO leaks one,
  and tapping a spot mid-QSO parks the half-typed QSO *with its number* and
  starts a new one from the same counter — two QSOs, one serial.
- A call-list batch gives every QSO the **same** number.
- Serials are **lost on ADIF import** (no STX/SRX mapping).
- Writing the counter into the operation record dirties the whole operation for
  sync per QSO, and in multi-operator it *is* the duplicate-serial mechanism:
  two clients keep their own scalar and clobber each other wholesale under
  last-write-wins.

**Three invariants** make the core-owned version correct by construction:

1. **An allocated number is data of record.** It was sent on the air, so it
   lives in `qso.data` — synced, exported, ADIF `STX` — never in the score cache.
   (Note the deliberate contrast with §5.1.1: scores are derived, serials aren't.)
2. **The counter is derived; the numbers are not.** The stored counter is a
   high-water mark, always rebuildable as `max(serial across all QSOs including
   soft-deleted) + 1`. Every hard case — delete, edit, crash, inbound sync,
   import — is answered by "rebuild the counter, never the numbers."
3. **Allocation happens exactly once, at commit,** inside the QSO insert
   transaction. Not at compose time (polo's root defect), not on edit, not on
   rescore.

Invariant 3 makes "rescoring never renumbers" **structural** rather than a
discipline: nothing in the scoring path can write a sequence.

**The entire extension-facing API** — declarative, no imperative call:

```ts
interface SequenceBinding {
  key: string                        // names the sequence within this operation
  /// Separate sequences per band/mode. The core computes the label AT COMMIT
  /// from the committed QSO — which matters, because the descriptor is a
  /// snapshot from when the lookup resolved, and the operator may change band
  /// before pressing Enter. Only the core knows the real band.
  ///   CQ WPX:      { key: 'serial' }                    one flat sequence
  ///   R1/RSGB VHF: { key: 'serial', scope: ['band'] }   each band from 001
  scope?: ('band' | 'mode')[]
  start?: number                     // operator-settable; default 1
  padTo?: number                     // display padding only ('001')
}
```

Used as `input: { kind: 'serial', field, sequence }`. There is nothing to call
because by the time any hook sees the QSO — `scoreQso`, `adifFields`,
`generateExport` — the number is already persisted on it. **Zero lines of polo's
counter logic survive the port.**

**Where it lives — one deliberate deviation from the brief.** You asked for the
scoring service to own the sequences. Allocation itself can't: `ScoringService`
is debounced, async, and degrades silently, while a serial must be allocated
*atomically with the QSO insert*. So allocation sits in `halo_core`, invoked
inside `QsosRepository.add`'s existing transaction beside
`_refreshOperationCounters`; the scoring/extension layer owns the **declarations**
(resolving which sequences an operation has from the active descriptors), which
is the part that genuinely belongs there. Same split, correct atomicity.

Persistence is a small `sequences` table keyed `(operation, label)` — not
`operation.data` (dirties the operation per QSO, and is polo's multi-op bug) and
not `local_data` (shallow-merge, and shares a namespace with wipeable derived
state). A table also gives an atomic `nextValue + 1` inside the QSO transaction.

| Event | Behaviour |
|---|---|
| Soft delete | number retained; counter **never rolls back** (a gap is fine, a reuse is not) |
| Edit a QSO | never allocates; the record keeps its number |
| Operator hand-edits a serial | honoured; counter raised to `max(stored, typed + 1)`; no other QSO touched |
| Rescore | no effect — no write path exists |
| Crash / cold start | counter rebuilt as `max(stored, derived)` — never `derived` alone, since a counter ahead of the log is correct |
| ADIF import | importer writes the field; the next `max()` picks it up |

**How multi-client sync slots in later, without touching the API.** v1 keeps
sequences local and, after inbound sync, raises each label to
`max(stored, max(inbound serial))`. That is correct for the common case (one
operator, several of their own devices) and, for genuinely concurrent multi-op,
**detects rather than prevents** collisions — which is the **decided** v1
behaviour: a duplicate serial arriving from another client raises an alert on the
affected QSOs rather than being silently reconciled or renumbered. Note this path
*can* fire in v1 (two devices logging the same operation, then syncing), so it
must actually be built, not merely designed. It needs no new sync record type,
since sequences are reconstructed from data that already syncs.

v2 can then use client blocks, stride/interleave, or server coordination —
extensions never learn which, because they never see allocation. The three
properties that survive all of them, and are therefore the real contract:
allocation is atomic at commit; an allocated number is never reassigned; the
counter is a cache and `max()` over the log always rebuilds it.

M3 (`cqwpx`, one flat sequence) proves allocation/peek/edit/delete; M7's VHF
contests then exercise `scope: ['band']` with **no core change** — which is the
test of whether the label design was right.

**As built (M3).** `SequenceDescriptor.fromInput` reads the `serial` input
descriptor; `QsosRepository.add(op, data, serialSequences: [...])` resolves each
label from the committed QSO and allocates inside the existing transaction. The
caller passes the descriptors rather than the repository looking them up — the
extension layer stays where the declarations are, and `halo_core` never invokes
a hook (let alone inside a transaction).

**The displayed number is the number.** The logging panel fills the serial field
from `peek`, and that value is written to the ref exactly like something typed —
it is not a suggestion. The operator read it off the screen and *sent it on the
air*; the log has to agree with what went out, and nobody re-keys a number the
app already showed them. `_withAllocatedSerial` therefore treats a number
already on the ref as authoritative and raises the sequence past it; allocation
is the fallback for QSOs that arrive without one (the second and later calls of
a call list, an extension-driven `addQso`, any headless caller). Both paths
store an `int`, so exports and the high-water rebuild never branch on provenance.

Allocate-at-commit still does the work that matters: the counter only advances
when a QSO is actually committed, so a wiped entry leaks nothing, and two
concurrent inserts can't collide. What it no longer does is override what the
operator was shown — that was a bug in the first cut of this, not a feature.

Two places the displayed number must NOT be copied, both of which were live bugs
in the first cut of write-through:

- **A comma-separated call list.** It belongs to the first station only; the
  rest of the pileup got the next numbers in the series, so `dataFor` strips the
  field for index > 0 and lets the sequence issue them.
- **An existing QSO opened for editing.** That record's number was sent long
  ago. `_applyFieldsFromData` restores it from the ref (it must treat `serial`
  exactly as `text`, or the field is left empty *and* any sibling field on the
  same ref goes unrestored and is cleared on save), and `_refreshSerialPreviews`
  refuses to run at all while `editingQso != null`. Without both, correcting a
  callsign on QSO #1 of a 400-QSO log rewrites its serial to the sequence's next
  number — destroying the number that went on the air, and inventing one for an
  ordinary QSO that never carried a contest ref.

The value is normalized to `int` in the panel rather than only in
`_withAllocatedSerial`, because `QsosRepository.update` deliberately never
allocates and so never passes through it.

`peek` resolves `max(stored counter, derived mark)`, and the **derived mark is
memoized in `SequencesRepository`** — deriving it afresh meant scanning and
JSON-decoding the whole log on every insert (twice, counting the panel's preview
refresh), which made logging a contest quadratic: 0.5ms → 13.8ms per insert at
3000 QSOs, on the UI isolate. With the memo it is 0.4ms and flat.

The memo may only ever be too HIGH, never too low: too high leaves a gap, which
every sponsor accepts, while too low re-issues a number that already went on the
air. So allocation raises it precisely (`noteIssued`), and anything that can put
a serial in the log *without* passing through the allocator drops it —
`update` (a hand-edited number), `mergeFromSync` (another device's numbers), an
`add` carrying refs but no declared sequences (ADIF import, an extension's
`addQso`), and `backupAndClearAll`. Worst case is one rescan.

Two orderings that a first cut got wrong, both of which reintroduce stale-low:

- **Invalidate AFTER the write commits, never before.** A scan starting in
  between reads the old log and memoizes it as current.
- **A scan already in flight must not memoize what it read.** The assignment
  sits across an `await`, so an invalidation landing in that window would be
  undone by the scan's continuation, pinning the pre-invalidation mark forever.
  A generation counter, re-checked before the assignment, closes it.

Neither is reachable in an in-memory test database, which completes the scan too
promptly to interleave — the second is covered through a `debugAfterScan` seam,
the first only by construction.

Cold start needs no explicit step: with no memo and no stored row, `peek`
derives from the log, which is exactly right. Two pieces of §5.8 are **declared but not yet built**:
`padTo` (display padding) is ignored, and the concurrent-multi-op duplicate
**alert** has no implementation — v1 currently raises past a collision silently
rather than flagging the affected QSOs. `setStart` exists on the repository but
no UI surfaces it yet.

`scope: ['band']` works and is covered by tests, but no shipped extension uses it
until M7 — so the label design is only proven against the flat case so far.

#### 5.8.1 Multi-client coordination: claims over the peer link (v2, designed)

Several devices logging the same operation — one operator with a phone and a
laptop, or a Multi-Single with a run position and a mult position on one
sequence — each need a number on screen *before* the QSO is committed, because
the operator reads it off the screen and sends it on the air. v1's
detect-after-sync cannot help there: LoFi latency is seconds to minutes, and the
number is needed in under one. The peer link (HALO-310/395) already carries
every position's draft between devices in real time, and that is the channel.

**The rule that keeps this simple: a number the operator has been shown is
never changed.** Everything below is arranged so that any negotiation happens
before display, and anything that arrives after display is recorded, not acted
on.

**Claims.** A claim is `(operation uuid, sequence label, number, client id)`.
The label is the binding key plus the scope values resolved from the draft
(`serial`, `serial/20m`), so scoped sequences coordinate per label with no extra
machinery.

- **Taken on the operator's first edit to a fresh draft** — a keystroke into
  any main-row field, a spot tapped, a call list pasted — not at peek: an idle
  panel holds nothing, so a phone left on the table burns no number and a
  device that never logs leaves no gap. A band or mode change from the radio
  is not an edit and never claims. Until a claim exists the serial field shows
  **no tentative number** — a blank, never a number that might move — and that
  holds with no peers connected too: one rule everywhere, at the cost of the
  where-does-the-series-stand glance at open (the log answers that).
- **Chosen locally** as the smallest number above the local `peek` that no live
  peer currently claims on the same label, then announced on the ephemeral
  channel as its own `serialClaims` message beside the draft — the draft goes
  out on the keystroke, the claim only once the database has answered, so
  they cannot share a message. Every message carries the sender's whole
  current claim set, versioned, so a missed one costs nothing and the
  establish-time snapshot is the same message again. Peers skip claimed
  numbers when choosing their own — and a number just **committed** stays in
  the sender's set for a minute, flagged as such, since the QSO carrying it
  reaches the peers through the durable sync a moment later than the release
  would. A committed number stands against any claimant whatever the
  tie-break would have said: it is in a log already.
- **Released by wipe**, by leaving the operation, and — for that label only —
  by a band/mode change that moves a scoped sequence to a different label
  (release, re-claim on the new label; the displayed number changes, which is
  correct — nothing has been sent yet; an unscoped sequence beside it keeps
  its number). An undo-wipe, or an edit opened over the draft, keeps the hold:
  both put the draft back. Several operations can be composing at once — one
  opened over another — and each holds its own.
- **Consumed by commit**, which writes it to the ref exactly as today; the core's
  allocate-at-commit treats the number on the ref as authoritative and raises
  the counter past it. Nothing in `halo_core` learns what a claim is.
- **Survives sleep.** A claim stands as long as the draft does: the phone that
  slept mid-QSO usually wakes up and logs it. A claim whose session drops stays
  blocked on the other devices until the peer re-establishes, when its
  snapshot — one message per operation it has ever held in, an empty set
  included — replaces whatever was on its books. Switching sharing off lets
  every hold go locally without telling anyone: the sessions drop with it,
  and a hold the peers keep for a device that left costs a gap, never a
  duplicate. A number logged late (an `042` at the end of the log) is not an
  error if that is what went out on the air, and a gap is never an error.

**Crossing claims.** Claims are announcements, not requests. Two devices that
claim the same number inside one round trip each hear the other's claim and
apply the same tie-break — lowest client id wins, the loser redraws. No ack is
needed for that to be correct. Acks answer a different question: *have I heard
from every live peer, so no crossing claim is still in flight?* — and that is
the only thing the pre-display wait is for.

- **Show after every live peer has acked, capped at ~500 ms.** The cap is set
  by the human, not the network: the claim is taken on the first keystroke of
  the call, and nobody reads the number aloud before finishing the call and
  reaching for the exchange. On a LAN the acks arrive in tens of milliseconds
  and the blank is never seen.
- **Live** means an established LAN session that has been answering. A peer
  that lets one round run to the cap — a phone asleep in a pocket behind a
  session TCP has not yet closed, or a build predating the message, which
  never answers — is **quiet**: still told every claim, so it skips them on
  waking, but not waited on again until it next says anything. Otherwise a
  dead device would cost the cap on every QSO.
- **Every peer sharing the operation competes.** Should peers ever carry a
  role — a position that logs, against a bridge or a spectator that never
  will — only the logging ones need consulting, and the roster a claim is
  announced to is the one place to narrow.
- **Needing the number settles it.** A commit inside the window waits for the
  claim (at most the cap) rather than writing a blank the allocator would
  fill from the local counter alone, blind to the peers' holds.
- **A losing conflict that arrives after display is kept, not redrawn.** The
  operator may already have sent it. The loser re-announces its claim so both
  sides know the collision happened, and **both QSOs are flagged at commit**
  through the duplicate-serial alert (the one v1 declares and does not yet
  build): a marker persisted on the QSO at commit whenever the number is
  already in the log for that label, synced like any field and drawn as a
  warning on the log row. When the loser's mark reaches the winner only after
  the winner's QSO was committed, the mark is written onto that record after
  the fact (`QsosRepository.markSerialConflict`). The same marker serves v1's
  sync-time detection. The outcome is a duplicate serial, which most adjudicators do not
  penalize — they check what the other station copied. The design leans toward
  availability because the strict alternative, redrawing inside a grace window
  after display, buys almost nothing and breaks the one rule above.

**Where it lives.** The counter, the `sequences` table and allocate-at-commit
stay in `halo_core`, network-unaware as now. The claim service lives in the app
beside `PeerDrafts` / `PeerChannels`, where the ephemeral session and the draft
snapshot already are: claim for a draft, release, the live claims from peers,
the ack round. The logging panel asks that service for the number instead of
calling `peek` directly; the service consults `peek` plus the live claims.
Devices that do not share the operation exchange no claims and fall through to
v1's sync-time alert. **The extension-facing API does not change**: an extension
still declares `{ kind: 'serial', field, sequence }` and never sees a claim,
which is the test §5.8 set for any v2.

**As built.** `SerialNumberSource` (halo_core, beside `SequencesRepository`)
is the panel's seam: `claim`, `release(committed:)`, `isConflicted`. The app's
`SerialClaims` (`app/lib/services/peer/serial_claims.dart`) implements it over
`PeerService.sendEphemeralTo`, and `LocalSerialNumberSource` is the fallback
when nothing is wired (tests, tooling) — `peek`, straight away. `LoggingControls`
takes the number from the source once the draft has content (a call, or a
touched exchange field), releases it on wipe, and hands the committed numbers
back after the insert. The alert is `Qso.serialConflict`, set by
`_withAllocatedSerial` when `SequencesRepository.isIssued` already knows the
number, or by the panel when the source says another position showed it; the
QSO list draws it as an error-coloured mark in the refs column. **Not yet
built:** the sync-time half of the alert — a QSO arriving through LoFi or peer
sync with a number already in the log is not marked, because the merge path
does not know which ref field is the serial; it only raises the counter, as
v1 did.

**Not in scope, decided.** Per-position stride or blocks (zero coordination,
works with no peer link) is not built: it changes what the operator sees, some
sponsors expect consecutive numbers, and the scope mechanism already covers the
cases where sponsors allow separate sequences (CQ WPX Multi-Two/Multi-Multi per
band). Server-side coordination stays the reconciler of last resort.

---

### 5.9 Field ops: `fd`, `wfd`, `colonies`

Reassigned here from the activities port (docs/design/activities.md §5) because
all three want contest machinery — Cabrillo headers, typed exchange fields, and
in two cases an ARRL section table — and none of them activate a reference.
app-polo files them under `category: 'fieldOps'`, not as awards.

2005 lines across the three, but they are not three separate problems: FD and
WFD are the same contest twice.

#### What they are

| | `fd` | `wfd` | `colonies` |
|---|---|---|---|
| Exchange | class + section (`1H` `ENY`) | same, class `^[1-9]+[HIMO]$` | none — the callsign IS the exchange |
| Points | phone 1, CW/data 2 | same | 1 per colony |
| Dupes | per band **and** mode | same | same |
| Multiplier | power: 5W+battery ×5, 5W ×2, 100W ×2, else ×1 | its own | none |
| Bonus | operator-entered | its own | none |
| Cabrillo | yes | yes | no |
| Sections | 71 ARRL + 14 RAC + `MX`/`DX`, tallied separately | its own copy of the same table | no |

`colonies` is not a contest at all: thirteen fixed callsigns (`K2A`–`K2M`) plus
special stations, and the score is how many of them you have worked. Its point
is the CHECKLIST — which colonies are still missing — not the total.

#### What HaLo already covers

Everything the two Field Days need for logging and export:

- **The exchange.** Class is a `text` control with a pattern; section is exactly
  what `kind: 'options'` was built for (§5.3) — a known set of ~85 codes with
  names, searchable, Space to accept.
- **Setup.** Power class and bonus points are a `form` with `select` and numeric
  fields, the same shape `stateparks` uses for `ourPower`/`ourCategory` (§5.4).
- **Scoring.** `ContestScorer` folds it: per-band-and-mode dupes, a points table
  by super-mode, a multiplier applied at summary time. The invalid-band rule
  (60/30/17/12m score 0 with an alert) is an ordinary verdict.
- **Cabrillo.** The writer is already shared out of `simple-contest/src/cabrillo.ts`.
- **ADIF.** `CONTEST_ID`/`CLASS`/`ARRL_SECT`. app-polo emits these even when FD is
  not the main handler; HaLo fans `adifFields` out to every hook anyway, so this
  is the default rather than a special case.

#### The two real gaps

**1. There is no ARRL section table in HaLo.** app-polo's `FDSections.js` is 308
lines — `ARRL_SECTIONS`, `RAC_SECTIONS`, `ABBREVIATED_SECTION_NAMES` and a
`PREFIX_TO_LOCATION` guess table — and `wfd` imports it from `fd`. Two
extensions needing one table is the case `extensions/shared/` already exists for
(`gmaSpots.ts`), and it must be inline data rather than a cross-extension call:
scorers are SYNCHRONOUS and host calls are not (§5.3's `operation-data` note).

Not a blocker — just the largest single piece of work here, and worth checking
against the current ARRL list rather than copied blind.

**Built, and DUPLICATED into each extension (2026-07-27).** Each of `fd` and
`wfd` carries its own `sections.ts` and its own `scorer.ts`, near-identical by
choice: an extension that can be read, moved and distributed without reaching
into a sibling is worth more than not repeating a table. Note the bundles were
already independent — `build.mjs` inlines shared imports into each single-file
IIFE — so this buys SOURCE separation, not runtime separation.

The cost lands on the tests, and is paid there: `field_day_test.dart` asserts
every rule the two are supposed to SHARE against both of them, so a change to
one that should have been made to both fails rather than drifting quietly.

The one thing still shared is the Cabrillo writer, imported from
`simple-contest` the way all seven contests import it. Forking that per contest
is a separate decision from separating these two.

**2. `colonies` reads QSOs from OTHER operations.** Its checklist calls
`findQSOsInOtherOps`, because the thirteen are worked across a week and nobody
runs one operation for it. HaLo has no such host call — an extension sees the
operation it is scoring and nothing else, by design.

| | Cost | Gives up |
|---|---|---|
| **A. Ship `colonies` scoped to one operation** | none | the checklist's whole point across operations |
| **B. Add a host call for a cross-operation callsign search** | a core addition: a new read method, and a decision about what an extension may see | nothing |
| **C. Defer `colonies`, ship `fd` + `wfd`** | none | `colonies` |

B is what the feature actually needs, and the host call is narrow — "which of
these calls appear in my log, when" — but it is the first time an extension
reads outside the operation it was handed, which is a boundary worth deciding
deliberately rather than in passing.

**C was chosen (2026-07-27).** `fd` and `wfd` ship as M11 and need no core
change; `colonies` is deferred to M12 with the boundary question still open. It
is NOT dropped — the analysis above stands and the extension is small once the
host call exists.

## 6. First increment — port `simple-contest` end-to-end

The smallest slice that exercises the whole pipeline (setup → typed exchange →
scoring → export) and forces exactly the four capabilities, no more:
dupe-only scoring (1 pt/QSO, dupe on same band+mode), **one** free-text received
exchange, two setup fields, no data files, no serials, no multipliers.

**Create** (mirror `extensions/activities/pota/` layout):
- `extensions/contests/simple-contest/manifest.json` — `key: "simple-contest"`,
  `category: "contest"`, name/shortName/version/description/hooks.
- `extensions/contests/simple-contest/src/index.ts` — `defineExtension`;
  `onActivation` registers: `activity` (operationControls = one `kind: 'form'`
  control carrying the Contest Identifier + Exchange Sent fields per §5.4;
  loggingControls = one received-exchange text field),
  `ref:simple-contest`, `scoring` (a `ContestScorer`), `adifFields`, `export`
  (ADIF + Cabrillo).
- `src/i18n.ts`, `src/i18n/en.json`, `src/i18n/es.json` (POTA's pattern).
- `src/index.test.ts` — `scoreQso` dupe/points fixtures + Cabrillo-row tests.

**Edit (plumbing):**
- `extensions/build.mjs` — add `{ key: 'simple-contest', entry:
  'contests/simple-contest/src/index.ts', kind: 'extension' }` to `bundles`.
- `extensions/tsconfig.json` — add `contests/*/src/**/*.ts` to `include`.

**Edit (the real infra):**
- `extensions/sdk/src/types.ts` — input union + `TextInputDescriptor`;
  `ContestScorer` (§5.2); scorer `scope` declaration (§5.1).
- Dart control catalog — render the `text` input kind (logging + operation
  controls) and persist its value via the existing ref path.
- `app/lib/services/scoring_service.dart` + `extension_service.dart:1357` — select
  relevant scorers by declared scope and fan out to those; drive the per-QSO loop
  with day-boundary checkpoints and resume.
- `extensions/core/scoring/src/*` — adapt the existing fold to `ContestScorer`,
  so core scoring runs through the same harness as any contest.
- New export hook using `lib-qson-cabrillo`, scoring internally when the cache is
  cold (§5.5) + Dart export-picker acceptance.
- `app/lib/views/extensions_panel.dart` + `settings_view.dart` + i18n — a
  dedicated **"Contests"** category, so contests don't land under "Other
  Extensions" (currently only `activity`/`lookup` are special-cased).

**Success criteria:** create a `simple-contest` operation, set contest id + sent
exchange in setup, log QSOs typing a received exchange, see 1 pt/QSO with
same-band+mode dupes zeroed *and* core DXCC/bands still tallying, and export both
a Cabrillo file and `CONTEST_ID`/`STX_STRING`/`SRX_STRING` ADIF. Verify an append
scores without a full rescore, and **measure replay cost on a realistic contest
log** to settle checkpoint granularity (§5.2).

---

## 7. Porting sequence

| Milestone | Delivers | Contests |
|---|---|---|
| **M0** ✅ | The four capabilities, proven end-to-end; "Contests" extension category | `simple-contest` |
| **M1** ✅ | Harden: finalize input union, settle checkpoint granularity from M0's timings, lock the current-QSO score display | — |
| **M2** ✅ | Band-mult conventions + numeric exchange + suggested values (§5.3) | `cqww` (zone), `arrl-dx` (state/power) |
| **M3** ✅ | Core-owned labeled sequence service (§5.8) | `cqwpx` |
| **M4** ✅ | Form-schema conditional fields (`visibleWhen`, §5.4); `operation-data` deferred for want of a consumer (§5.3) | `iaru-hf`, `naqp` |
| **M5** ✅ | Searchable-options input (`kind: 'options'`) + dated `suggest` ranking (§5.6) | `stateparks` |
| **M6** ✅ | **Segments** — `event.operation` override, segment-effective operation, scorer selection across segments (§5.1) | — |
| **M7** ✅ | Great-circle distance scoring + rover our-grid from segments (no new input kind — see below) | `arrl-vhf-tests` |
| **M8** ✅ | REG1TEST/EDI export writer | `r1-vhf-tests`, `rsgb-vhf-tests` |
| **M9** | Cross-extension POTA ref synthesis | `georgia-pota` |
| **M10** | Stateful rolling-location scoring, county-line N×M, bonuses | full `qp` rules |
| **M11** ✅ | ARRL/RAC section table duplicated into each extension; power multiplier + bonus in setup (§5.9) | `fd`, `wfd` |
| **M12** | Cross-operation callsign search, if §5.9's option B is chosen | `colonies` |

✅ means shipped and verifiable in the tree, not merely started. M1 carries no
contest of its own, so its evidence is worth naming: the `pattern`/`uppercase`
union rules (§5.3), the checkpoint-granularity measurement (§8), and the
current-QSO score display with its staleness gate and notice rows
(`halo_widgets/lib/src/logging_controls.dart`). The live count of ported
extensions is [parity.md](../parity.md) §1, not this table.

Per §5.6, `qp` and `stateparks` each stay a **single extension** whose individual
events are offered through the activity `suggest` search, so #149's discovery
goal is met without a per-event bundle explosion.

**Amended at M5.** `qp` moved out of M5 in full: multi-value per-token feedback
(a county line, `ORDES/JEF`) is a QSO-party need and nothing in `stateparks`
exercises it, so it goes with the rest of the party rules to M10 rather than
being built speculatively against no consumer. What M5 actually shipped is the
single-value `kind: 'options'` field, the ranking behind it
(`option_matching.dart`), the two-band fix to `suggest` ranking that `relevance`
needed to mean anything at all (`activity_suggestions.dart`), and `stateparks`.

Two things `stateparks` needed that this section did not anticipate, both
recorded where they belong (§5.3, §5.4) rather than only here:
- `kind: 'options'` is a **logging-panel kind**. Operation settings render
  `refList` and `form` and drop every other kind silently, and the form schema
  has no searchable single select — so "which park am I activating" is a plain
  76-option `select` inside the setup form, answered once per operation and
  usually pre-filled from the POTA activation.
- An event ref reaches an operation by **two paths with different behaviour**:
  the setup form (which decorates) and a `suggest` tap (which does not). A
  multi-event contest has to carry `label`/`shortLabel`/`name`/`program` on the
  suggestion itself or the same ref reads differently depending on how it was
  added.

---

## 8. Decisions made and questions still open

**Decided** (2026-07-24). Every question that gated a milestone is now settled —
**M0 is unblocked**, and so is the sequencing through M10.

- **Scorer contract → `ContestScorer`** (§5.2): `startScoresheet` / `scoreQso` /
  `summarizeScore`, named for the scoring process rather than the functional
  machinery, with the core owning the loop, checkpointing and live path. The
  resumable-batch alternative was rejected (§5.2).
- **Checkpoint granularity → day boundaries only. Measured, M1.** A benchmark
  through the real JS engine (`halo_extension_host/test/scoring_benchmark_test.dart`)
  puts a full pass at 6ms for 1,000 QSOs and 31ms for 5,000, so a worst-case
  mid-log replay is imperceptible and a per-*K*-QSO axis buys nothing. Resuming
  from the cached end-scoresheet still makes an append ~6x cheaper at 5,000
  QSOs, so the capability stays in the contract — but it needs no Dart-side
  plumbing at these sizes.
  The same benchmark caught the fold being **quadratic**: copying the
  accumulated state per QSO cost 289ms at 5,000 QSOs. Scorers may now mutate
  the scoresheet they're handed, with the harness taking one defensive copy of
  any checkpoint at its boundary — 289ms → 31ms, and linear.
- **Beta-fidelity → fix on port, document the divergence.** Known polo defects
  (10 GHz VHF `distanceAndPoints` leaving `value` undefined; the stateparks
  bonus handling below) get fixed as they're ported rather than reproduced,
  with each divergence noted in the extension so polo can follow.

  > **Corrected at M5.** This bullet used to say "stateparks power-mult/bonus
  > double-count", and both halves were wrong. `powerMultipliers` appears in two
  > JSON files (`txsp`, and `qp`'s `ky`) and is read by **no code at all**, so
  > there is nothing to double-count. And the bonus double-count — two
  > consecutive blocks with the identical guard, each adding to
  > `score.bonusPoints` (`StateParksExtension.js:373-379`) — is **dead**: it
  > guards on `sp.options?.bonusPoints?.perParkActivated`, while every data file
  > puts `bonusPoints` at the TOP level and `options` holds only `multipliers`.
  > So the real defect is the opposite of the one recorded: TXSP's 100 points
  > per park activated are never awarded at all.
  >
  > A third defect, unrecorded and worse, is a crash. `scoring.bonusStations.push(…)`
  > (`:281`) runs whenever the worked station is one of the event's bonus
  > stations, but `scoring` is initialised with `bonuses: []` and no
  > `bonusStations` (`:243-255`) — so working TXSP's `K5LRK` throws a
  > TypeError out of the scorer.
  >
  > **And four more, found while porting.** Recorded here because this list was
  > taken as the defect checklist for the port and was not sufficient:
  > `activationRefs` is mapped to strings and then filtered as if the entries were
  > still objects (`:228-232`), so the parks an operator activates are ALWAYS zero
  > — which silently turns Georgia's activated-park multiplier into 1 and halves
  > the activated+hunted rule for Texas and Ohio; `score.bonusPoints` is computed
  > and then never added, because the total adds `score.bonus`, a third name
  > nothing assigns (`:371-390`); the per-event `bands`/`excludedBands` the data
  > files carry are read by nothing, so one hard-coded WARC exclusion stands in
  > for Ohio's 80-10m rule and Florida's 160-6m list; and GASP's
  > `points.distinctStatePark` is read by nothing either, which its own notes
  > admit. All four are fixed in the port, which therefore does NOT reproduce
  > polo's numbers — see the divergence list in `stateparks/src/scorer.ts`.
  >
  > **Amended after M5.** `powerMultipliers` is read now: setup asks for a power
  > class where the answer reaches something we produce (Texas's score, Ohio's
  > Cabrillo), and Texas §6.5.1 makes that number a **term in the multiplier
  > sum** — "total QSO points X (power multiplier + Texas State Parks worked
  > multiplier + Texas State Parks activated multiplier) + bonus points" — not
  > the factor its name suggests. The same pass stopped offering the contest ADIF
  > for Ohio, whose rules refuse it in as many words, and put the four CATEGORY
  > headers their checker reads into Ohio's Cabrillo.
- **Per-QSO scoring stays out of the QSON blob** (§5.1.1) — it lives in
  `score_cache`/`local_data.scoring`, is never synced, and is regenerable.
  Extensions get a read-only `_scoring` projection instead (§5.7), which is a
  performance optimization rather than a correctness requirement (see below).
- **Shared reference data lives in a new `operation-data` core extension**
  (§5.3) — US states, Canadian provinces, ARRL/RAC sections now; band plans and
  other operating reference tables as its broader remit. Contests address sets by
  `operation-data:<key>`; one copy, offline, no per-contest vendoring.
  **Amended at M4** (§5.3): scorers are synchronous and cross-extension calls
  are not, so scorer-visible data has to live in an `@ham2k/lib-*` package and
  an `operation-data` extension can only back async UI lookups. Nothing in the
  sequence needs one yet, so it is deferred rather than built speculatively.
- **Operation setup reuses and extends the form schema** (§5.4) rather than
  adding `select`/`segmented` to the input union. `operationControls` carries a
  `FormDefinition`; the schema gains a searchable-options field backed by
  `optionSet`, plus dynamic labels — and, from M4, `visibleWhen` (§5.4.1), since
  IARU HF's sent exchange is one of three fields chosen by station type.
- **`optionType` is DROPPED, not implemented** (M4). It is declared in the SDK,
  set five times (always to `'optional'`, which equals the default) and read
  nowhere. Porting it would not work: polo's secondary row is **opt-in**, so
  `mandatory` is how a control appears at all, whereas HaLo's row is **opt-out**
  — every contributed chip is already visible, so `mandatory` could only revoke
  the user's ability to hide one. Worse, it cannot reach a contest exchange at
  all: `_ControlDescriptor` is built only for `kind: 'refList'`, and every
  contest exchange is a `text`/`serial` primary field. The three newest contests
  already omit the field.
- **An exchange the operator EMPTIES stays empty** (M4). The guess above fires
  on an ABSENT field only. When the operator clears a field they touched, the
  core records `field: ''` rather than dropping it, so "nothing was received" is
  a decision the log carries and re-editing the QSO cannot undo it. Reopening
  such a QSO restores the field as operator input, so a lookup resolving
  afterwards can't refill it either. Serials are exempt — the sequence owns the
  number, and a blank there is not something an operator records.
- **A received exchange nobody typed is written onto the ref at save** (M4),
  following polo's IARU: `processQsoBeforeSave` stamps the country-file value —
  IARU's ITU zone, CQ WW's CQ zone — onto the contest ref, so the log, the
  scorer and the export all agree. This settles an inconsistency already shipped
  in `cqww`, whose scorer falls back to the country-file zone (earning the
  multiplier) while its Cabrillo and `SRX_STRING` print `-` or omit it, so a log
  could score a zone and export a dash. Fixing `cqww` to match is part of M4.
- **Multi-operator serials → detect and alert in v1** (§5.8). Concurrent-multi-op
  duplicates raise an alert on the affected QSOs rather than blocking on
  distributed allocation. The path can fire in v1, so it gets built, not just
  designed.
- **Multi-value exchanges get live per-token feedback** (§5.3) — county lines
  (`ORDES/JEF`) validate each token as it's typed, rather than being normalized
  silently at scoring time.
- **REG1TEST/EDI is in scope** (§5.5, M8) — the R1/RSGB VHF families submit EDI,
  so a `qsonToReg1test`-style writer is ported rather than deferred.
- **A dedicated "Contests" extension category** ships with M0, rather than
  letting contests fall under "Other Extensions".
- **Exports score for themselves when the cache is cold** (§5.5) — `generateExport`
  runs the contest's own scorer when `_scoring` is absent, making exports correct
  on any device in any cache state, with no scoring/export ordering dependency.
- **Score display is per-current-QSO only** (§5.1) — no per-row badges in the QSO
  list, which retires the day-header precedence/ordering/cap problem entirely.
  Cached per-QSO verdicts still drive the display when a logged QSO is selected
  for editing.
- **Segments are in scope and land at M6**, before the VHF contests that need
  them (§5.1): the `event.operation` override payload, segment-effective
  operation resolution, and scorer selection across segment refs.
- **Scorers declare their scope** (§5.1) — `'always'` (DXCC/states/bands) or
  ref-gated — and the core invokes only the relevant ones, rather than calling
  every enabled extension and being told "not mine".
- **Exchange fields can be suggested from callsign info** (§5.3) — via the
  existing lookup-resolve re-invocation and `host.dbLookup*`, with the core
  enforcing that a suggestion never overwrites operator-typed input.
- **Rules are internal to a scorer** (§5.1). Contests don't share a rule
  vocabulary; only notices/alerts and summaries cross the boundary, so the
  per-QSO cache carries one entry per scorer, not per rule.
- **QSO Parties / State POTAs stay one extension each** (§5.6), with events
  surfaced through the activity `suggest` search rather than as ~50 bundles.
  This retires what had been the RFC's hardest open question.
- **Serial numbers become a core-owned, labeled sequence service** (§5.8), not
  each contest's own counter — which also answers the former "serial
  write-path" question.
- **The cache is refreshed on every operation open** (§5.1.2), so an updated
  extension can't leave stale scores behind. A consequence: checkpoints need not
  be persisted.

**Still open** — everything blocking a milestone has been decided; these surface
during the milestone that hits them:

1. **Segment scoring window (M6):** does a scorer selected only by a *later*
   segment's ref score the QSOs before that segment, or only its own? Settle when
   segments are built; it changes nothing before M6.
2. **`operation-data`'s wider remit:** how much of the band-plan/reference data
   currently in `halo_core` and `@ham2k/lib-operation-data` migrates into the new
   extension, and when. Contest option sets don't wait on this.
3. **Suggestion matching:** deterministic ranked substring match (exact code >
   code prefix > name prefix > substring) in SQLite, versus polo's fuzzy match.
   Fuzzy would mean either a per-keystroke bridge crossing (ruled out by
   DESIGN.md §5) or a Dart-side fuzzy ranker. Substring is stricter — e.g. "EMASS"
   would no longer find "EMA".
4. **Divergences from polo to enumerate** (per the fix-on-port decision): zone
   range validation, real error messages on invalid values, NAQP gaining
   suggestions, consistent STX/SRX ADIF, serials surviving import, a settable
   starting serial. These should be listed for review rather than discovered
   during side-by-side testing. Landed so far, all covered by tests:
   - **WPX points** — polo scores same-continent-different-country at 2 (the
     North American rate, applied worldwide, so EU-to-EU pays double) and
     doubles same-country QSOs on the low bands, which rule B.3 exempts
     ("1 point regardless of band"). HaLo implements the published table.
   - **WPX prefixes** — polo takes `parseCallsign`'s prefix verbatim, which
     drops the multiplier entirely for a numberless call (`XEFTJW`, `PA/N8BJQ`)
     and splits the special-event calls the rules name as whole prefixes
     (`HG19`, `LY1000`). Both are silent under-counts.
   - **WPX serials** — every failure mode listed at the top of §5.8 is gone by
     construction, not by fixing the counter logic.
   - **Contest exports are sliced to their own segments** — polo filters QSOs
     by segment on every export, but only for a ref carrying an IDENTIFIER
     (`ref?.type && ref?.ref`), so a contest ref never qualifies and polo
     exports the whole log for it. A Cabrillo containing contacts made after
     the contest ended is a false claim, and §5.1.3 already gates contest
     SCORING this way, so leaving the export unsliced would have the score and
     the submission disagree.
   - **NAQP band and mode** — polo validates NEITHER. It defines `VALID_BANDS`
     and never consults it, so a 30m QSO scores, and it never compares the QSO's
     mode against the contest's, so a CW contact counts in the SSB running.
     Both are checked on port.
   - **NAQP duplicates** — polo's dupe test mixes exact mode (`q.mode === mode`)
     with super-mode in the same function, so USB and LSB on one band read as
     two different contacts. NAQP is single-mode per running, so a duplicate is
     simply the same station on the same band.
   - **IARU HQ multipliers** — namespaced (`HQ:ARRL`) so a society abbreviating
     to `R1` can't silently merge with the IARU Region 1 office. polo keys both
     off the raw exchange.

---

## 9. Appendix — per-contest readiness

All 12 are **blocked** on capabilities 1–3 except `georgia-pota` (**partial** —
no exchange, no export; needs scoring fan-out + a POTA-ref annotation). Effort is
*after* the shared infra exists.

| Contest | Scoring | Mults / band-mults | Exchange typed | Export | Data files | Effort |
|---|---|---|---|---|---|---|
| `simple-contest` | simple | – / – | free text | adif, cabrillo | none | small |
| `cqww` | moderate | ✓ / ✓ | CQ zone (num) | adif, cabrillo | none | medium |
| `arrl-dx` | moderate | ✓ / ✓ | state *or* power (dynamic) | adif, cabrillo | none | medium |
| `cqwpx` | moderate | ✓ / – | serial | adif, cabrillo | none | medium |
| `iaru-hf` | complex | ✓ / ✓ | zone/HQ-abbr (polymorphic) | adif, cabrillo | none | large |
| `naqp` | moderate | ✓ / ✓ | name + state (guessed) | adif, cabrillo | none (needs states data) | large |
| `georgia-pota` | moderate | ✓ / – | state (standard field) | – | none | medium *(partial)* |
| `stateparks` | complex | ✓ / – | park abbreviation (OHSP only) | cabrillo (OHSP only) | `states/*.json` | large |
| `qp` | complex | ✓ / ✓ | serial + county/state | adif, cabrillo | 49 `parties/*.json` | large |
| `arrl-vhf-tests` | complex | ✓ / ✓ | grid (4/6) | adif, cabrillo | `all-events.js` | large |
| `r1-vhf-tests` | moderate | – / ✓ | serial + grid | adif, **reg1test** | `all-events.js` (8) | large |
| `rsgb-vhf-tests` | complex | ✓ / ✓ | serial + grid + district | adif, **reg1test** | `all-events.js` (~124) | large |

Rows describe **app-polo's** structure, except `stateparks`, corrected at M5 when
it was ported: only Ohio has a typed exchange (a park abbreviation, not a state)
and only Ohio exports a Cabrillo — the other three events read their parks off
the POTA references already being logged. Each sponsor is offered the one file
it asks for and nothing else: Ohio's Cabrillo; a per-park ADIF for Texas and
Georgia, whose uploaders dictate the filename (`CALL@US-PARK-DATE`) and read
the park out of it, so those files carry POTA's `SIG_INFO`/`MY_SIG_INFO`
alongside the contest's own fields; and nothing at all for Florida, whose rules
name no filename and whose §7.4 asks only for "the recommended POTA log
format" — which is POTA's own per-park export, as it is in polo. ADIF's
`Contest_ID` enumeration lists none of the four events, and no sponsor reads
the value. Per #149 and §5.6, `qp` and
`stateparks` ship in HaLo as ONE extension each whose events are offered through
the activity `suggest` search, and their data files stay one bundled catalog.
