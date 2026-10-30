# Scoring & chasing

A **scorer** keeps the score of one operation: a contest's points and
multipliers, an activation's progress toward its threshold, the app's own
duplicate and new-entity rules. A **chasing program** keeps an award's
checklist across every operation: which entities, parks or states a station
has worked and confirmed, so the app can rank spots by what working them
would add. [How hooks work](hooks.md) covers registration, keys, priority
and `ctx`.

## `scoring`

**For:** a contest's rules, an activity's activation rules, any score kept
per operation.

**Called:** once per operation per scorer whose scope matches, with every
contact at once: the app asks for 500 verdicts in one call, not 500 calls.
The day sectioning (24-hour UTC buckets) and the accumulation happen inside
the runtime; the app supplies the operation and its contacts and caches
everything that comes back. Then, as the operator works, for one draft
contact at a time and for the spots board's candidates.

You do not implement the wire shape. You write a **`ContestScorer`**, three
pure functions, and wrap it with `contestScorer()`, which supplies the loop,
the day sectioning, the checkpoints and both live paths:

```ts
interface ContestScorer<S> {
  startScoresheet({ operation, ref? }, ctx): S
  scoreQso({ scoresheet, qso, operation, ref?, isNewDay }, ctx): { scoresheet: S, score: QsoScoreVerdict }
  summarizeScore({ scoresheet, operation, ref?, scope }, ctx): Record<string, ScoreTally>
}
// QsoScoreVerdict: { value, dupe?, notices?, alerts?, icon?, color? }
// ScoreTally:      { key, for: 'day' | 'operation', total, label?, summary?, longSummary?, icon?, grid? }

registerHook("scoring", {
  key: "cqww",
  hook: contestScorer(MyScorer, { scope: { refTypes: ["cqww"] } }),
})
```

- **`scope`** decides which operations the scorer applies to, and the app
  reads it before invoking anything: `'always'`, or `{ refTypes: [...] }`,
  so an operation that does not carry the reference never crosses the
  bridge. Several scorers run on one operation, a contest's beside the app's
  own, and their results are namespaced by key.
- **The contacts arrive ordered by start time, deleted ones excluded**, so a
  day-bucketed rule can fold them as they come.
- **The scoresheet is yours.** Its rules stay private; only notices, alerts,
  points and summary tallies cross the boundary. `scoreQso` **may mutate** the
  scoresheet it is given and return it; copying accumulated state per
  contact is quadratic. The live paths hand you a copy-on-write view that
  takes every kind of write and refuses the ones that would reach the held
  sheet by other means: `Object.freeze`, `seal` or `preventExtensions` on it
  throws. A sheet is plain JSON; one that is frozen or carries accessors is
  outside the contract and throws at the first touch.
- **`summarizeScore`** answers tallies for the `day` and `operation` scopes.
  A contest returns `contestSummary(...)`: one tally titled with the
  contest's name and score, its detail opening on a `contestArithmetic(...)`
  line, and nothing for the `day` scope, since a contest's multipliers run
  the whole event. The SDK's `tally()` builds any other.
- **`scoreQso` on the live path** judges one not-yet-logged contact, the
  callsign being typed. A draft with no time of its own reaches you stamped
  with the current time, so a day-bucketed rule judges it as of now. The
  harness replays the contacts logged since the last checkpoint onto a view
  of it and scores the candidate against the result.
- **Candidates from the spots board** are scored many at once, each against
  its own view of the folded log, so no candidate becomes another's
  duplicate. A candidate's verdict may name an `icon` (Material Design
  Icons or `fa-`) and a `color` to mark its spot, before the chasing
  programs' and the references' icons, in the order the scorers run, each
  name once. Name one only where the spot is worth the operator's eye: a
  multiplier, a station the contest is after. `contestScorer()` passes on
  the `icon` and `color` a `scoreQso` verdict carries to the candidates and
  leaves them out of the logged contacts' cached verdicts. An `'always'`
  scorer's icon goes with a verdict that said only worked-before things
  where another scorer ruled on that axis; one that answers an icon and
  nothing else keeps it.

**Worked-before is shared between scorers**, and the rule for who speaks is
worth learning once. An `'always'` scorer is the lowest priority on that
axis: for a contact another scorer has judged there (a verdict carrying
`dupe`, a `duplicate` alert, or a `newBand`/`newMode`/`newDay`/`newRef`
notice) the app drops the `'always'` scorer's own `dupe`, `duplicate` and
those notices, so the app's call-band-mode rule never contradicts an
activity's. What the app alone reports (`newDXCC`, `newState`,
`newProvince`) always survives, and a verdict that says nothing about a
prior contact displaces nothing. So:

- **Emit `dupe` whenever your dupe test ran**, `dupe: false` included; that
  is what tells the app you have ruled. Rule only on what you have seen: a
  scorer folds only the segments it runs for, so stay silent about a station
  absent from your history.
- When your verdict means "worked before, and this one counts anyway", say
  it in one of those notice keys rather than inventing a spelling, or the
  app's `duplicate` stands beside your credit on the one row that can show
  only one. `newPark` is accepted as a spelling of `newRef`.

**Checkpoints** are the harness's business. A sheet the size of a long log's
worked-call map crossing the bridge on every keystroke would be most of the
keystroke's cost, so the app names each checkpoint and the harness keeps the
end sheet under that name, one per operation, for the last few operations;
a live call carries the name alone. A name the harness no longer holds is an
error, never a silent cold fold, and the app answers it by sending the sheet
once more. A scorer written against the SDK gets all of this without
knowing it exists; one built on an SDK from before the cache never says it
holds a checkpoint, and keeps receiving the sheet.

### Scoring an activity

A reference program's rules (so many contacts to activate a park, repeats
on a new band count, a hunted reference rescues a repeat) are a
`ContestScorer` too, built by `activityScorer(rules)` and wrapped like any
other:

```ts
registerHook("scoring", {
  hook: contestScorer(activityScorer(RULES), { scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE] } }),
})
```

| Rule | |
| --- | --- |
| `label`, `icon` | The tally's name and glyph |
| `activationType`, `huntingType` | The reference types, as for `referenceActivity`; omit `huntingType` for an award with no hunting side |
| `qsosToActivate` | Contacts one reference needs before it counts as activated (POTA 10, SOTA 4, WWFF 44), or a function of the activated references for a program whose bar varies by place; the highest bar among references activated at once applies |
| `tracksActivation` | Whether there is a threshold at all; `false` reports no activation tally rather than inventing one |
| `tracksOperators` | Whether progress also breaks down per operator once someone other than the station call logs a contact; default true |
| `freshRefRescuesActivation` | Whether a hunted reference this station has not given before also counts toward the activation on an otherwise-repeat contact; default true |
| `distinctCallsPerDay` | Whether the activation counts different stations in a UTC day rather than contacts; default false |
| `allowsMultipleReferences` | Whether one contact can credit several hunted references |
| `uniquePer` | Which axes make a repeat fresh again: `day`, `band`, `mode`, `ref`; empty means any repeat is a duplicate |
| `activates` | `'daily'` (the default), a reference is activated per UTC day; `'once'`, the count accrues across the operation |
| `refNoun`, `refNounPlural`, `p2pLabel` | The program's own words ("park", "summit", "P2P"), as strings or functions of `ctx` for translation |

`k2hrc-llota` in the SDK's samples registers one beside the factory's hooks;
`k2hrc-cqww` is a contest written out in full.

## `chasing`

Extension API 9. **For:** an award kept as a checklist: DXCC, WAS, parks
hunted. The app keeps the best claim per line, shows the holder's progress,
and ranks spots against it.

**Called:** every program, isolated from each other; one that throws or
times out answers nothing for that call.

```ts
registerHook("chasing", {
  key: "w7abc-lakes",                                   // your key, or <key>_suffix: one extension may register several programs
  hook: {
    program: { label: "LLOTA", icon: "waves", version: 1, editions: "lifetime", refLabel: "lake" },
    claimsForQsos({ qsos }, ctx) { /* { [uuid]: QsoClaim[] } */ },
    holdersFor({ station }, ctx) { /* string[] */ },
    summarizeClaims({ holder, edition, slots }, ctx) { /* { [key]: ClaimsTally } */ },
    importClaims({ importer, file, station }, ctx) { /* { claims: ImportedClaim[], skipped? } */ },   // optional
  },
})
// QsoClaim: { holder, ref, band: string | null, mode: string | null, level: 'worked' | 'confirmed' | 'verified', edition?, by?, label?, guess? }
```

- **`program`** is plain data, read across every extension without invoking
  anything. `version`: raise it whenever the same contacts would claim
  something different; the app keeps no claim from an older version.
  `editions`: `lifetime`, `annual` (named by UTC year) or `event`.
  `refLabel` is what one reference is called in a notice ("New POTA Park"),
  the program's `label` when left out. `notices` words a verdict's notice
  yourself (`newRef`, `newBand`, `newMode`, `unconfirmed`), with `{{band}}`
  naming the band and `{{mode}}` the mode, through `modeLabels`, both
  translatable under `translations` (`{ es: { notices, modeLabels } }`); a
  verdict you leave out, or whose notice lacks the band or mode its words
  name, reads the app's way, and a guess reads "Probably …" around your
  words. `supersedes` names the scoring notices your verdicts stand in for
  (DXCC: `newDXCC`). `icon` and `color` mark a spot your verdict alerts for.
  `imports` lists the importers `importClaims` accepts, each
  `{ key, label, extensions }`.
- **`claimsForQsos`** answers every contact in the batch, by `uuid`, with
  the slots it fills. A caller asking about something that is not a stored
  contact (a spot, the call being typed) gives it a `uuid` of its own, and a
  contact without one is left out. `band` and `mode` are explicit, `null`
  meaning "any", and a program usually claims several granularities per
  contact (DXCC: Mixed, the band, the mode); `mode` is the program's own
  grouping, never mapped by the app. `level` is `worked`, `confirmed` (a QSL
  the program accepts, from `qso.qsl`) or `verified` (sponsor credit, from
  `qso.credits.<program>`). **It must be a pure function of each contact and
  your own data, never of the log**, because the app asks it about spots,
  and about contacts on a device that holds only part of the log. An empty
  list is an answer, and so is one for an event marker (`band: 'event'`),
  whose placeholder call is not a station. A contact's `our` carries the
  place it was made from (`grid`, `lat`/`lon`; its own, or its operation's),
  for a program that keeps a checklist per place; a spot candidate's `their`
  carries the lookup's `guess.state` when an offline lookup knows one.
- **`holdersFor`** lists the holders a station claims as, the opaque strings
  you put on claims, so the app knows whose checklist to show: the first, in
  the current edition. `station` carries its call and, when it has one, its
  place, as a contact's `our` does. An `annual` program names its editions
  by UTC year (`'2026'`); an `event` program's checklist has no current
  edition to show.
- **`summarizeClaims`** reads one holder's filled slots
  (`{ ref, band, mode, level, label? }` each) into tallies, a `ScoreTally`
  without its `for`.
- **`importClaims`** reads one file (`{ name, text }`) the operator picked or
  dropped, for the station they chase as (`station`, as `holdersFor` gets
  it), and answers the claims it makes, each a `QsoClaim` plus `at` (epoch
  millis) if the file says when, and `skipped`, the records it could not
  read. Each claim is kept in the log as a claim record and synced with it,
  and `claimsForQsos` is never asked about one. The file is the whole of its
  importer's records: importing the same kind of file again replaces every
  claim the last one gave, and a file answered with no claims replaces
  nothing.

A contact with any malformed claim is left out of the answer, keeping the
claims it already holds. The packer refuses a `chasing` hook under `api` 9,
so an older app, which would install it and never ask it anything, is never
offered it.

**Examples:** `k2hrc-dxcc` in the SDK's samples; `ham2k-dxcc`, `ham2k-was`
and `ham2k-pota`'s hunted-parks program in
[ham2k/extensions](https://github.com/ham2k/extensions).
