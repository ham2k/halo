# Scoring & chasing hooks

The [hook reference](hooks.md) says how hooks are registered and invoked, and what every hook is handed.

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

A candidate's answer may name an `icon` (an MDI or `fa-` name) and a `color`
(`#RRGGBB`) to mark its spot: the row shows it before the chasing programs'
and the references' icons (see `getSpots`' `display.icons`), in the order the
scorers run, each name once. Name one only where the spot is worth the
operator's eye — a multiplier, a station a contest is after — since a row has
room for few. A `contestScorer()` passes on the `icon` and `color` its
`scoreQso` verdict carries to `scoreCandidates`, and leaves them out of the
logged contacts' cached verdicts. An `'always'` scorer's icon goes with a
verdict that said only worked-before things, where another scorer ruled on
that axis; one that answers with an icon and nothing else keeps it, so a
scorer that judges nothing can still mark a spot.

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
  ("New POTA Park"), the program's `label` when left out. A program may
  instead word a verdict's notice itself: `notices` by verdict (`newRef`,
  `newBand`, `newMode`, `unconfirmed`), where `{{band}}` names the band a
  new band is on and `{{mode}}` the mode a new mode is in, through
  `modeLabels`, with both per language under `translations` (`{ es: {
  notices, modeLabels } }`). A verdict it leaves out, or one whose notice
  lacks the band or mode its words name, reads the app's way; a guess reads
  "Probably …" around the program's words.
  `supersedes` names the scoring notices the program's verdicts stand in for
  (DXCC: `newDXCC`): wherever the program judges a call or a spot, the
  scorer's notice is dropped in favor of the verdict.
  `icon` and `color` (`#RRGGBB`) mark a spot the program's verdict alerts
  for: its row shows the icon, tinted, beside the references' (see
  `getSpots`' `display.icons`). A verdict that does not alert adds none.
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

Implemented by: `ham2k-dxcc` (catalog, pre-loaded; core `dxcc` until
HALO-844) — Mixed, per-mode and per-band slots for the station call worked
from each entity, worded "DXCC ATNO", "DXCC in CW", "DXCC in 80m"; LoTW and
paper QSLs confirm, `credits.dxcc` verifies; the DXCC Challenge is a tally of
its band slots. A stored goal for `dxcc` carries to it
(`kRenamedChasePrograms`). `k2hrc-dxcc` is the SDK's worked example. `ham2k-pota` — one slot per park hunted, worked only; its
hunted-parks export verifies. `ham2k-was` — Mixed, per-band and per-mode
slots (plus FT8 and RTTY) for the station call worked from one 4-character
grid; LoTW and paper QSLs confirm, `WAS` credit verifies.
