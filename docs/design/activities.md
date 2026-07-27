# Porting app-polo's activity extensions

Status: **every activity is ported** (A0–A5). Tracking issue:
ham2k/app-halo-dist#148.

Companion to [contests.md](contests.md), which owns the twelve contest
extensions and, per the decision in §5 below, also owns `fd`, `wfd` and
`colonies`.

---

## 1. Summary

app-polo ships 21 activity extensions. HaLo has ported two — `pota` and
`sota` — and they exercised every hook the rest need except two, both of which
every activity depends on and neither of which existed: **nothing scored an
activation**, and **nothing produced a submittable per-reference log**.
Seventeen of the nineteen remaining activities implement `scoringForQSO`, and
so do the two already ported.

So the port is a little shared infrastructure — built in A0, §3.1 and §3.2 —
plus a long tail of small, near-identical extensions. The shared work came
first because it was also a retrofit for `pota` and `sota`.

---

## 2. Current state (verified)

Read against `extensions/activities/pota/src/index.ts` and app-polo at
`/Users/sd/Work/ham2k/app-polo/src/extensions/activities`.

**Hooks that already carry an activity.** `activity` (logging/operation
controls, `suggest`), `ref:<type>` (validate/decorate/title), `adifFields`,
`spots` (fetch, self-spot, other-spot), `lookup`, `dataFile`, `account`.
POTA uses all but `account`; SOTA adds it. No new hook *category* is needed
for the reference-based activities.

**Data files map almost 1:1.** `DataFileDefinition` already has
`fetchType: 'csv' | 'json' | 'raw'` with `csvToLookupEntry` /
`jsonToLookupEntry`, and the host owns batching, progress and the `lookups`
table. app-polo hand-writes that loop per activity (`WCADataFile.js` is 180
lines); the HaLo equivalent is roughly 25.

**Cross-extension sharing works.** The contests thread already shares its
Cabrillo writer by relative import
(`import { qsonToCabrillo } from "../../simple-contest/src/cabrillo.ts"`), so
one activity can host a module the others import.

**The scoring seam is the right shape.** `contestScorer` in
`extensions/sdk/src/scoring.ts` already does the checkpointing, day
sectioning, live-candidate and segment resolution an activity scorer needs,
and `scope: {refTypes: [...]}` already keeps a scorer away from operations
that aren't running it. `app/lib/tools/scoring_summaries.dart` renders any
scorer's tallies with no per-scorer code.

---

## 3. The gap

Five things stood between the ported pair and a mechanical port of the rest.
The two shared ones are built; three remain, and each blocks only itself.

### 3.1 Activation scoring (blocking, shared) — **BUILT (A0)**

Shipped as `extensions/sdk/src/activityScoring.ts`; `pota` and `sota` are
retrofitted onto it. What follows is the gap it closed; §4 is the design as
built.

No HaLo equivalent of app-polo's `generateActivityScorer` /
`generateActivityOperationAccumulator` / `generateActivitySumarizer`
(`src/extensions/shared/activityScoring.js`). It supplies:

- `value` per QSO, and duplicate detection relaxed by `uniquePer`
  (`band`, `mode`, `day`, `ref`) with the `newDay`/`newBand`/`newMode`/
  `newRef`/`maybeDupe` notices;
- per-reference activation counts (`activatedRefs`), hunted-reference counts,
  and the `N/qsosToActivate` → `N ✓✓` summary;
- the multi-reference operation totals block.

Design in §4.

### 3.2 Per-reference exports — **BUILT (A0)**

Every app-polo OTA activity offers one ADIF per activated reference
(`suggestExportOptions` returning `exportData: {refs: [ref]}`), because
activating two parks at once means owing the program two logs, one claiming
each. HaLo's `pota` and `sota` registered **no `export` hook at all**.

Shipped as `extensions/sdk/src/activityExports.ts` —
`activityExportHook(rules)`, registered by `pota` and `sota`. **It needed
nothing from the core.** `exportType` is opaque to the core and round-trips
verbatim into `generateExport`, and the Exports panel already keys selections
by `hookKey:exportType` (`operation_export_screen.dart:68`) so several options
from one hook are independently selectable — encoding the reference into the
exportType (`pota-adif:US-0001`) is enough. `generateExport` narrows the
operation to that one activation ref and delegates to the `adif` extension in
the runtime, so each file is byte-identical to a normal export of that narrowed
operation.

This is the multiplicity ham2k/app-halo-dist#389 left unbuilt for want of a
producer; it consumes #389 rather than changing it, declaring `refType` so the
core slices to the segments where the activity was actually running.

Not to be confused with the *other* multiplicity, which **is** built (A0):
**one QSO can owe several ADIF records.** §4's per-reference rule says a
park-to-park contact with a two-park station counts twice because it is
submitted as two records — so `adifFields` gained
`fieldCombinationsForOneQSO`, returning one field set per record, and the
exporter writes that many, shifting each successive record's
`QSO_DATE`/`TIME_ON` by a second (as app-polo's `qsonToADIF.js:144` does).
`pota` implements it. That is per HUNTED reference, WITHIN one file; §3.2's is
per ACTIVATED reference, ACROSS files. The two compose: activate two parks,
work a station standing in two others, and you get two files of two records
each.

POTA's combinations still write `MY_POTA_REF` comma-joined over every activated
park, where app-polo names a single one. Inside an activity export that is now
moot — §3.2 hands `generateExport` an operation carrying one activation ref, so
the joined list has one element. It still shows in the *plain* ADIF export of an
n-fer activation, which is the honest thing for a file that claims both.

### 3.3 The GMA spot-posting API (shared) — **BUILT (A1)**

`GMAPostSpotAPI` / `GMACommonPostSelfSpot` / `GMACommonPostOtherSpot` are
shared by seven activities: `bca`, `blha`, `eca`, `ela`, `gma`, `mota`, `wca`.
Ported once into `extensions/shared/gmaSpots.ts` and imported by relative path.
It lives outside any extension directory because no single one of them owns it;
`build.mjs` lists its bundles explicitly, so nothing there is mistaken for an
extension. `postOtherSpot` is not ported yet — none of A1's programs use it.

### 3.4 Build-time API keys — **BUILT** (the secrets store, #411)

Three of app-polo's activities sit behind a key, and not only for their lists:
`tota` puts one in its data-file URL as a query parameter, while `wwff` and
`llota` send one as an `X-API-Key` header on their spot feeds and spot posting.
So `wwff` and `llota` can be ported without a key and simply lose spotting;
`tota` cannot be ported at all without one.

HaLo had `fieldType: 'secret'` for *user-entered* credentials but no way to
thread a build-time app secret into an extension. It does now:

- `app/lib/config/secret_policy.dart` decides which extension may read which
  secret — by default its own `KEY_*` prefix (see `docs/extensions/README.md`);
- `host.secret(name)` returns it, and the kernel stamps the caller's identity
  onto the call — `'secret'` is in `IDENTITY_HOST_METHODS` — so an extension can
  only ever receive secrets that policy grants it;
- values come from the environment into a gitignored
  `app/lib/config/secrets.dart`, generated from `secrets.dart.example`.

Every consumer must expect null and degrade: a fresh checkout, a fork and any
build without the secret all have none.

A flat key map plus one accessor is a **stopgap**. A proper secrets service, and
flags to gate the external calls that use these keys, are planned — written up
under "Planned: a secrets service, and flags to gate external calls" in
`docs/extensions/README.md`.

### 3.5 Satellites (bespoke)

HaLo has no satellite support of any kind. app-polo's extension is small — 256
lines across five files — but almost none of it is award logic: it is a picker,
a radio action, and three ADIF fields.

**This section's earlier assessment was wrong and is corrected here.** It
claimed satellites needed "a transponder picker no existing `input.kind`
covers". That was true when it was written; the contest work has since shipped
`kind: 'options'` (a searchable set with a code and a name, for QSO-party
counties and park abbreviations), and a transponder list is exactly that shape.
Re-checking what the core can already do turned four assumed gaps into two.

#### What app-polo does

| | |
|---|---|
| Reference | `{type: 'satellite', ref: 'SO-50/145.85/fm'}` — name, uplink MHz and uplink mode joined by `/` |
| Data | `polo.ham2k.com/data/satellites.json`: per bird a `name`, `aliases`, and parallel `uplinks`/`downlinks` arrays of `{lowerMHz, upperMHz, mode}` |
| Picker | one dropdown row per satellite × uplink, labelled `SO-50 • Fm: 145.850 → 436.795` |
| On select | writes the QSO ref, **tunes the radio** to the uplink, and stores `operation.satellite` |
| New QSO | `prepareNewQSO` copies `operation.satellite` onto each new QSO |
| Exchange | forces the `grid` field on — a grid is the normal satellite exchange |
| ADIF | `PROP_MODE: SAT`, `SAT_NAME`, `BAND_RX` from the matching DOWNLINK |
| QSO list | shows the other station's 4-character grid |

#### What HaLo already covers

- **The compound reference.** Refs are opaque strings; `custom` already ships one
  built from two fields (§3.6). Nothing needed.
- **The data file.** `dataFile` + `jsonToLookupEntry`, one row per bird with the
  transponder arrays in `data`. Note `queryLookups` caps at **100 rows** — fine
  for ~40 active birds, but it is a silent cap, so store per BIRD, not per
  transponder.
- **The picker.** `kind: 'options'` on `loggingControls`. The option list is
  data, not a closure, and `loggingControls` is a hook call — so it can read the
  data file and expand each bird's uplinks per call.
- **The per-operation default.** `OptionsInputDescriptor.suggestedValue`,
  computed from the operation's own satellite ref. No `prepareNewQSO` equivalent
  is needed, and no new operation field: the operation carries a ref like every
  other activity.
- **The ADIF fields.** `adifFields.fieldsForOneQSO`, and `bandForFrequency` is
  already in the SDK.

#### The two real gaps

1. **Tuning the radio from a control.** `CommandAction.setVfo` exists and does
   exactly the right thing — but only the `command` hook can emit actions. A
   `loggingControls` selection writes its value through the core and cannot ask
   for anything else to happen.
2. **An exchange field that is a QSO field, not a ref field.** Every input
   descriptor targets a `refType`; `their.grid` is neither. There is no way for
   an extension to say "show the grid field on this QSO".

A third, minor: no equivalent of `relevantInfoForQSOItem`, so the QSO list would
not show the worked station's grid.

#### Options for gap 1 — **C was chosen and built**

| | Cost | Gives up |
|---|---|---|
| **A. Command only** (`SAT SO-50`) | none — `setVfo` + `updateQso` already work end to end | the picker; the operator types a name |
| **B. Picker only** | none | tuning; the operator sets frequency themselves |
| **C. Both** ✅ | none | nothing, but two ways to do one thing |
| **D. Let controls emit `CommandAction`s** | a core change to the control result path | nothing |

C ships the picker AND the command, and needed no core change at all. D remains
the honest fix and is reusable — any control that should have a side effect
wants it — so if a second extension needs one, build D and let the picker tune
directly.

What that means in practice:

- `operationControls` is a **`form`** with one `select` of every transponder,
  because `operationControls` renders only `refList` and `form` (an `options`
  control there would silently never appear). It sets the operation's bird.
- `loggingControls` is **`options`**, whose `suggestedValue` is that same bird —
  so a pass is one choice rather than one per contact, which is what app-polo's
  `operation.satellite` buys, without a second place to store it.
- `SAT SO-50` tunes and names in one move. It merges `refs` rather than writing
  them, because `updateQso` writes whole fields and a bare list would drop the
  park the contact is also for.

Gap 2 is smaller than it looks: a grid can be typed into the exchange the same
way any other field is, and forcing it on is a convenience. **Deferred.**

#### Two things the data settled

The feed was read before any of this was written, which is the rule this port
learned the hard way.

- **`aliases` does not exist.** app-polo's picker label appends `sat.aliases`;
  no bird in the feed has the field. Dead code, not ported.
- **AO-7 is why the reference names a TRANSPONDER.** Of 38 birds only two have
  more than one uplink, and only AO-7's differ in downlink band — 2m up → 10m
  down, 70cm up → 2m down. A reference naming just the bird would put the wrong
  `BAND_RX` on half its contacts and tune 300 MHz away.

`fmtFreq` is not used for these labels: it reads its argument as kHz, so
QO-100's 10489.5 MHz renders as "10.489.500" (as it does in app-polo).


### 3.6 Custom: one activation reference

`custom` is the only activity with nothing to search — the operator names the
program, the reference and an optional name, so there is no list, no lookup and
no validation beyond "not empty". HaLo's closest existing surface is the
`kind: 'form'` operation control the contest work added, which reads and writes
**one** ref of a type.

app-polo lets an operation carry SEVERAL custom references, added one at a time
through a bespoke three-field composer with its own add/remove list. HaLo ships
**one**, deliberately: a repeating add/remove group is a core addition to
`FormDefinition` and its renderer, and nothing in the submitted log depends on
it — `MY_SIG_INFO` carries a single reference in either app. Hunting is
unaffected; a QSO records as many of the other station's references as it is
given, and exports one record each.

If someone actually needs to activate two unsupported programs at once, the
repeating group is the fix, and it is worth doing properly rather than
approximating with a delimiter convention.
---

## 4. Design — the activity scorer

`activityScorer(...)` is a **`ContestScorer` factory**, not a new harness: it
returns the three pure functions `contestScorer` already wraps, so
checkpointing, day sections, the live path and segment resolution are
inherited unchanged.

```ts
// extensions/sdk/src/activityScoring.ts
export interface ActivityScoringRules {
  key: string                 // 'pota'
  label: string               // 'POTA'
  icon?: string
  activationType: string      // 'potaActivation'
  huntingType: string         // 'pota'
  qsosToActivate?: number     // default 10
  allowsMultipleReferences?: boolean
  uniquePer?: ('band' | 'mode' | 'day' | 'ref')[]
}
export function activityScorer(rules: ActivityScoringRules): ContestScorer<ActivityScoresheet>
```

Registered the same way a contest is:

```ts
registerHook('scoring', {
  hook: contestScorer(activityScorer(POTA_RULES), {
    scope: { refTypes: [ACTIVATION_TYPE, HUNTING_TYPE] },
  }),
  key: 'pota',
})
```

Two things do **not** carry over from app-polo and are worth stating, because
both are easy to get wrong:

**The scorer must read the operation's activation refs itself, not the
harness's `ref`.** `contestScorer` resolves a single ref (`refs.find(...)`) —
correct for a contest, which has one. A POTA n-fer activates several parks at
once and app-polo scores each, keying them apart inside one shared score
object via `activatedRefs[ref.ref]` (`src/extensions/scoring/index.js:139`
pushes one handler entry per operation ref, all sharing the key `ref.type`).
`scoreQso` receives `operation`, so the scorer filters
`operation.refs` for `activationType` itself. No harness change; just don't
trust the singular `ref` for the activation side.

**Duplicate detection is scoresheet state, not a log re-scan.**
`generateActivityScorer` calls `filterNearDupes({qso, qsos, ...})` — an O(N)
scan of the whole log per QSO, i.e. O(N²) per operation. HaLo's harness folds
a running scoresheet forward instead, so the rules become a lookup into a
`workedByCall`-style map, exactly as `core/scoring`'s `scoring.ts` already
does for its own dupe rule. Port the *rules*, not the scan.

**A park-to-park contact counts once per reference, not once.** app-polo's
`value` on the activation side is `refCount || 1`, and that is the programs'
rule rather than an arithmetic slip: a single on-air contact with a station
declaring two references is submitted as two records, one per reference, so it
advances the activation by two. A station at one reference, or at none, is one
contact. Only `allowsMultipleReferences` programs (`pota`, `llota`, `tota`) can
reach a count above one — elsewhere the hunted refs are sliced to at most one
first. Ported as-is.

Retrofitting `pota` and `sota` onto this was the acceptance test: their
`scoring: {...}` blocks in app-polo (`qsosToActivate: 10 / 4`,
`uniquePer: ['band','mode','day','ref'] / ['day','ref']`) became the rules
literal. Covered by 22 rule tests under `node --test` plus six integration
tests driving the real bundle through QuickJS
(`packages/halo_extension_host/test/activity_scoring_test.dart`).

**Two things it needed from the core, and one it still does.** `newDay` and
`newRef` joined `scoring_labels.dart` (an unlabelled notice reaches the operator
as raw camelCase). The Information panel's per-scorer heading looked up a ref
whose `type` equals the scorer key — true of a contest, false of an activity,
whose ref type is the key plus a suffix — so it now falls back to a prefix
match and an activation is headed "POTA US-0001" rather than "pota".

Still open: **`ExtensionService` selects scorers from the OPERATION's refs**
(`extension_service.dart:1398`), so an operation that only HUNTS references
never selects the activity's scorer and gets no hunted-reference tally.
app-polo covers this with `generalHuntingType`, which adds the handler to every
operation regardless. The obvious HaLo equivalent — `scope: 'always'` — costs a
full-log payload serialization per activity per operation, which is what `scope`
exists to avoid, and it does not scale to nineteen activities. Deferred rather
than papered over.

---

## 4b. Design — the reference-activity factory (A1)

A dozen of app-polo's activities are the same file copied: a program that is a
list of places with codes, activated by working people from one, with no API
beyond a downloadable list. `referenceActivity(config)`
(`extensions/sdk/src/referenceActivity.ts`) builds their `ref:<type>`,
`activity` and `adifFields` hooks from that config; each extension supplies the
config plus its own `dataFile`, which is the one genuinely per-program part —
every list has its own shape.

Scoring and exports stay separate factories the extension composes itself, so a
program can have neither: `pga` scores nothing in app-polo and registers no
`scoring` hook here.

`pota` and `sota` deliberately do NOT use it. They have live APIs, spot feeds,
accounts and n-fers; hand-written is the honest way to say so.

Two details worth knowing before adding the seventh program:

- The config takes the extension's own `tFor`, and the factory looks up a fixed
  vocabulary — `invalidReference`, `unknownReference`, `activationControl`. A
  program that omits one gets the raw key in its UI.
- Control keys are `<extensionKey>/activation`, which is what makes `wca:`
  scoping work in the activity search. The core derives the scope from the part
  before the slash, so a control keyed anything else silently never gets scoped.

`huntingType` became optional on `activityScorer` for these: several of the
castle and lighthouse awards only recognise activations, and app-polo says so by
leaving it off its Info. Their scorers then credit one per contact and report no
hunting tally.

**A2 added the hunting side** — `huntingType` on the factory brings a per-QSO
control, SIG/SIG_INFO on export, and other-spotting — plus three rules that
batch's awards need and A1's never did. Each is configuration because the
programs genuinely disagree, not because the shape was unclear:

| Rule | Who needs it |
|---|---|
| `splitRecordsPerHuntedRef` — one ADIF record per hunted reference, or one naming them all | split: `pota`, `mota`; join: `gma`, `siota`, `wwbota`, `zlota` |
| `qsosToActivate` as a function of the activated references | `wwbota` (10 in S5/Z3, else 25), `zlota` (1–4 by kind of place) |
| `freshRefRescuesActivation` — does a fresh hunted reference rescue the activation credit on a repeat contact? | false for `mota`, `siota`; true elsewhere |
| `tracksActivation` — does the award have a threshold at all? | false for `mota`, which counts nothing |

A joining program must declare NO `fieldCombinationsForOneQSO`, not one that
returns a single set — the exporter would otherwise ask twice for one answer.

---

## 5. Scope

**In:** the sixteen reference-based activities, `custom`, `satellites`, and
the shared infrastructure in §3.

**Out — moved to [contests.md](contests.md):** `fd`, `wfd` and `colonies`.
They are contests wearing activity clothes — Cabrillo headers,
`qsoToCabrilloParts`, typed exchange fields, ARRL/RAC section tables — and
they need that thread's `cabrillo.ts`, form inputs and exchange handling. Two
of the three are already acknowledged there (§5's exchange survey is "all 12
contests plus Field Day"). Add all three to that porting sequence.

---

## 6. Porting sequence

| Step | Content | Why here |
|---|---|---|
| **A0** ✅ | `activityScorer` and `activityExportHook` in the SDK; per-record ADIF combinations; retrofit `pota` + `sota` | §3.1/§3.2. Unblocks everything; fixes the two shipped activities |
| **A1** ✅ | `bca` `blha` `eca` `ela` `wca` `pga` + the GMA spot API and the `referenceActivity` factory | Six activation-only extensions over one data-file shape and one spot API — widest validation for the least code |
| **A2** ✅ | `gma` `mota` `siota` `wwbota` `zlota` | Adds hunting refs and a second reference type per extension |
| **A3** ✅ | `wwff` `llota` `tota` | The three behind API keys; `tota`'s LIST needs one |
| **A4** ✅ | `custom` | Free-form SIG/SIG_INFO; no data file, no scoring, no network — a three-field `kind: 'form'` control, §3.6 |
| **A5** ✅ | `satellites` | §3.5. The only non-award activity: a picker, a `SAT` command, and three ADIF fields |

A1 is one PR, not six: the six differ only in reference regex, data-file URL
and strings, and splitting them would review six copies of the same diff.

---

## 7. Appendix — per-activity readiness

`Refs`: A = activation-only, H+A = hunting and activation.
`Spots`: F = fetches a spot feed, S = posts self-spots, O = posts spots for
others. `Score` = implements `scoringForQSO` in app-polo.

| Activity | Refs | Data file | Spots | Score | Step | Notes |
|---|---|---|---|---|---|---|
| `bca` | A | Google Drive CSV | S | ✓ | A1 | shared scorer |
| `blha` | A | Google Drive CSV | S | ✓ | A1 | shared scorer |
| `eca` | A | JSON | S | ✓ | A1 | own scorer |
| `ela` | A | JSON | S | ✓ | A1 | own scorer |
| `wca` | A | CSV | S | ✓ | A1 | also handles `ecaActivation`/`bcaActivation` |
| `pga` | A | CSV | – | – | A1 | no spotting, no scoring |
| `gma` | H+A | CSV | S O | – | A2 | hosts the shared spot API |
| `mota` | H+A | CSV | S O | ✓ | A2 | |
| `siota` | H+A | CSV | – | ✓ | A2 | |
| `wwbota` | H+A | CSV | F S O | ✓ | A2 | |
| `zlota` | H+A | JSON | F S O | ✓ | A2 | app-polo also registers `setting` |
| `wwff` | H+A | CSV | F S O | ✓ | A3 | shared scorer, `qsosToActivate: 44` |
| `llota` | H+A | JSON | F S O | ✓ | A3 | shared scorer |
| `tota` | H+A | API + key | F S O | ✓ | A3 | **blocked** on §3.4 |
| `custom` | H+A | – | – | – | A4 | user-supplied SIG/SIG_INFO; §3.6 |
| `satellites` | one type | JSON | – | – | A5 | **blocked** on §3.5 |
| `fd` | one type | – | – | ✓ | — | → contests.md |
| `wfd` | one type | – | – | ✓ | — | → contests.md |
| `colonies` | one type | – | – | ✓ | — | → contests.md |

Rows describe **app-polo's** structure. "own scorer" means the extension
hand-writes `scoringForQSO` rather than calling
`generateActivityScorer`; whether those genuinely differ from the shared
rules, or merely predate them, is checked per extension during its step.
