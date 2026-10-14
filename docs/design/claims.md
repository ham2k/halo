# Claims: what a contact counts toward

*Status: partial. The hook (§2) is built. Its programs are DXCC (core),
and POTA's hunter checklist and WAS (catalog extensions).
The `claims` table and the service keeping it current (§5–§7) are built, and
run only under `EXP CHASE`. They sync through LoFi once the server
advertises them. Verdicts, goals and alerts (§8) are built
(`app/lib/services/chase_service.dart`). Imports (§9) are built as claim
records in the log; matching a record to a contact is not.*

Chasing is about programs that ask for contacts with references: a POTA
park, a DXCC entity, a US state for WAS, a US county, a Spanish municipio.
The reference comes over the air, or is guessed from the callsign or other
data. What an operator wants to know — about the log, and about every spot —
is how far along each program's checklist they are, and whether this
station would move it.

A **claim** is one line of such a checklist: "this station can claim this
reference, on this band, in this mode". Extensions decide what a contact
claims; the app keeps the best claim for each line, syncs them, and compares
spots against them.

## 1. Slots and levels

A claim fills a **slot**:

```
(program, holder, edition, ref, band, mode)
```

Every part but `program` and `ref` is the program's to decide (§3). A
program's set of slots is its checklist, and only claims that exist are
stored — there is no row for a reference not yet worked.

A claim is at one of three **levels**:

| Level | Means | Read from |
| --- | --- | --- |
| `worked` | a contact counts toward the slot | the contact itself |
| `confirmed` | that contact has a QSL the program accepts | `qso.qsl` |
| `verified` | the sponsor credited **that contact** to the award | `qso.credits.<program>` |

Which QSL sources a program accepts is its own rule: LoTW and paper cards
for DXCC, any of them for another.

A slot holds **one** claim. The rule that picks it:

**A higher level wins, even when its contact came later; within a level,
the earliest contact wins.** Ties break on the contact's uuid, so every
device picks the same one.

So the first contact with a park holds its slot as `worked` until a
confirmed one exists, and that one until a verified one does — however long
after the first contact either came.

## 2. The hook

A hook category, `chasing`, registered once per program and keyed by the
program's key ([hooks.md](../extensions/hooks.md) has the full contract):

```ts
interface ChasingHook {
  program: {                              // plain data, read without invoking anything
    label: string; icon?: string; color?: string
    version: number                       // bump when claims would change; triggers a rebuild (§6)
    editions: 'lifetime' | 'annual' | 'event'
  }
  claimsForQsos({ qsos }, ctx): Record<string, QsoClaim[]>    // keyed by qso uuid
  holdersFor({ station }, ctx): string[]
  summarizeClaims({ holder, edition, slots }, ctx): Record<string, ClaimsTally>
  importClaims?({ importer, file, station }, ctx): { claims: ImportedClaim[], skipped? }   // §9
}

interface QsoClaim {
  holder: string
  ref: string
  band: string | null       // null: any band
  mode: string | null       // the program's own grouping. null: any mode
  edition?: string          // omitted: '' (lifetime)
  level: 'worked' | 'confirmed' | 'verified'
  by?: string               // what lifted it above worked: 'lotw', 'qsl', 'pota'…
  label?: string
  guess?: boolean           // the ref is inferred, not reported (§8)
}
```

**`claimsForQsos` is a pure function of each contact** and the extension's
reference data. It never reads the log. That is what lets a device holding
only part of the log, or none of it, compute a spot's claims (§8) and apply
a new contact's (§6). A program that needs the log to decide a claim cannot
be expressed here, and that is deliberate.

One contact usually yields several claims, one per granularity the program
tracks. DXCC returns three: `(K, null, null)` for Mixed, `(K, '20m', null)`
per band and `(K, null, 'CW')` per mode.

`summarizeClaims` turns a holder's slots into the tallies the info panel
shows, as scoring does — `ScoreTally`, with `grid` for a fixed-set
checklist.

## 3. What the program decides

- **Holder.** Who can claim. Programs differ: some credit the operator,
  some keep `KI2D` and `KI2D/P` apart and others merge them, some split by
  the DXCC entity operated from (`KI2D` and `KI2D/VE2` differ), and WAS
  claims for a call at a place (`KI2D@FN31`: ARRL counts contacts made
  within 50 miles of one place, and a 4-character grid stands in for it).
  A contact made in an operation records no place of its own, so the app
  hands a program the operation's (`our.grid`, `our.lat`/`lon`) unless the
  contact states one, and hands `holdersFor` the station's. **Not yet
  followed:** a segment's own place (a rover's later stretch claims at the
  operation's), and a place the operation gets after its contacts were
  claimed, which reaches them only at the next rebuild. Both are wanted
  before a program keyed by place leaves `EXP CHASE`. The holder is
  an opaque string the program builds; `holdersFor` lists the ones a
  station uses, so the view knows which checklist to show.
- **Mode.** Whatever grouping the program uses — `CW`, `PHONE`, `FT8`,
  `DIGITAL`. The app never maps modes for it.
- **Edition.** Lifetime programs leave it empty. A recurring or special
  event — the DX Marathon, 13 Colonies, Route 66 — puts the edition in each
  claim, computed from the contact's date (`'2026'`). One program, one
  goal, one set of settings, and a new checklist each year; the view shows
  the current edition and keeps the rest queryable.

## 4. What lives on the contact

**No derived claims on the QSO.** Refs say what the contact *was*; claims
say what it *counts for* under a program's rules today. Stored on the QSO
they would go stale with every rules change, repeat what `their` already
says, and add to every QSO sync.

What does belong on the QSO is outside fact about that contact, which
programs read to decide a level:

```jsonc
"qsl":     { "lotw": { "received": true, "receivedOn": … } },   // confirmations
"credits": { "dxcc": { "level": "verified", "by": "lotw", "awards": ["DXCC", "DXCC_BAND"] },
             "ham2k-pota": { "level": "verified", "by": "pota", "at": … } }   // sponsor credit
```

`credits` is keyed by program. `awards`, when present, names the ADIF awards
the sponsor granted: DXCC credits Mixed, a band and a mode separately, and a
credit listing its awards verifies only those slots.

ADIF carries both fields both ways. Each confirmation goes in its own
`*_QSL_RCVD` and date fields, and credit goes in `CREDIT_GRANTED`
(`DXCC:LOTW,DXCC_BAND:LOTW`). Only the awards of a program that exists are
read; the table mapping awards to programs is in `adif_to_qson.dart`, and its
mirror is in the ADIF export.

The planned `confirmation` hook (LoTW download and the like) writes these
same two fields.

## 5. The `claims` table

```
claims                     synced through LoFi and backed up; never over peer links
  uuid        v5 of the JSON array [program, holder, edition, ref, band, mode, source]
  program, holder, edition, ref, band, mode
  source      'log': every row derives from the log (§9's imports too)
  level       'worked' | 'confirmed' | 'verified'
  at_millis   when the claiming contact happened (null if an import didn't say)
  qso         the claiming contact, or claim record (§9)               (indexed)
  data        by, label, guess
  version     the program version that computed it
  epoch       raised by a rescan; outranks the claim on merge (§7)
  deleted, synced, updated_at_millis
```

A slot has one row, the best claim any row of the log makes for it, by
§1's rule: **the checklist is the claims table**. The `source` column
leaves room for rows no log stands behind; nothing writes one.

Rows are derivable from the log, and synced anyway: a device holding
part of the log, or a web client holding none, reads its checklists from
here. Every device computes the same row from the same contacts, and the
uuid is deterministic, so they agree on which row they are writing.

## 6. Keeping it current

`ClaimsService` follows every write to the log through
`QsosRepository.changes`. That covers local edits, imports, and what sync
and peers merge; writes to the score cache are not included.

The log is every contact that is not deleted and is not in a deleted
operation. Deleting or restoring an operation writes none of its contacts,
so `OperationsRepository.deletions` names the operation instead, and its
contacts are treated as changed: a restore raises what they claim, and a
deletion rescans only the programs whose slots they held. A program that is
missing when changes arrive, because its extension is off or the runtime is
restarting, never sees them, so it is rebuilt once it is back. One that
fails on a pass is rebuilt once more right after it. A runtime that cannot
list the programs at all says nothing about which exist, so the changes
wait, still marked on disk, for a pass that can.

Changes waiting for a pass are held in memory, so a marker on disk says
some are waiting; a launch that finds it, after a quit or a crash, rebuilds.
The service hears changes from the start of boot, before the runtime that
answers for the programs is up, and holds them until it is.

**Holding the whole log.** A device holds the whole log once LoFi has
reported a completed full sync, or, with sync off, if it never linked an
account. A device still backfilling holds part of it, and so does one that
linked an account and turned sync off before its backfill finished.

| Change | Needs | Done by |
| --- | --- | --- |
| **Upgrade** — a new or edited contact beats the slot's claim | that contact and the slot | any device |
| **Downgrade** — the contact holding a slot is deleted, or no longer qualifies | the runner-up, so the whole log | a device holding the whole log |
| **Rebuild** — a program's `version` changed | the whole log | a device holding the whole log |
| **Matching an import** to a contact | that contact | any device holding it |

An upgrade is the hook's claims for the changed contact, each compared with
its slot's row. "Which slots does this contact hold?" is `claims WHERE qso =
?`; "what does it count for?" is a fresh hook call. An upgrade keeps the
row's epoch.

A downgrade has no runner-up on record — the hook maps a contact to claims,
never a slot to contacts — so a device holding the whole log rescans that
program, in the background and in batches. It writes only the rows that
changed, each under an epoch above any of the program's rows, so they
outrank what devices that missed the change computed. A program that fails
on any batch abandons the rescan, writing nothing, since a checklist built
from part of the log would withdraw every slot the rest of it holds. It does
this for its own edits and for deletions and edits that arrive by sync
alike: a whole-log device that syncs a deletion of a slot's contact finds it
in `claims.qso` and rescans.

A rescan never lowers or withdraws a row naming a contact this device has
never seen. Sync is not instant: the contact holding that slot may not have
arrived yet, and it may beat everything here. A contact the program left out
of its answer keeps its rows for the same reason. Which rows to keep is
decided inside the rescan's write, so a row sync merges while the rescan
reads the log is judged too.

**Batching.** Changes gather until the log has been quiet for a second, so
an import or a sync backlog reaches the programs as one pass rather than one
per contact. A pass reads the changed contacts, and a rescan reads the log,
250 at a time, with one hook call per program per batch. A pass over more
than a thousand contacts shows its progress in the footer.

A device holding only part of the log leaves the slot as it was. A claim
withdrawn there stays overstated until a whole-log device syncs — or, for a
user with none, until LoFi can rescan (§9). That is accepted: withdrawing a
claim is rare, and is expected on a device with the whole log.

The rows' `version` tells a partial device its claims are from an older
program version it cannot rebuild itself. A whole-log device rebuilds a
program when its version changes, or when it has not yet rebuilt it from the
whole log. That second condition covers a first run, a device that has just
finished its backfill, and turning `EXP CHASE` back on after changes went
unfollowed. A row computed by a newer version than this device's extension
is never overwritten by a rebuild. One an older version computed elsewhere,
from a contact this device holds, is rebuilt when sync brings it (§7); the
rows a rebuild kept because it could not judge them keep their old version,
so the version of the rows on hand is no sign a rebuild is owed.

## 7. Merging on sync

Last-writer-wins would let a device that cannot see the better contact
overwrite the better claim with a newer, worse one. So an incoming row is
merged:

1. The higher `epoch` wins — only a rescan raises it, which is how a
   deliberate downgrade gets through.
2. At the same epoch, a live claim beats a withdrawn one. An upgrade made
   by a device that missed a rescan refills the slot at the rescan's epoch.
3. Then the better claim wins, by §1's rule, and then the newer write.

A device that holds a better row than the one it received writes it back,
stamped newer than the row it beat: LoFi itself keeps the newer write and
knows nothing of these rules. The order is total, so every device converges
on the same rows.

A row merged in can still be wrong. One from a device that has not yet
heard of a deletion can carry a higher epoch and name the deleted contact.
A device holding the whole log checks the contacts the accepted rows name,
and rescans a program whose row names one it holds deleted, itself or
through its operation, or was computed by an older version of the program
from a contact it holds. A row naming a contact that has not arrived here says
nothing either way.

**Over the wire.** Claims are LoFi's third kind of record, beside
operations and contacts. LoFi says it takes them with `meta.flags.claims`. A
server without that flag answers 200 and drops them, so HaLo sends and asks
for claims only after a reply carrying it, and marks them synced only on such
a reply. They are paged forward from the start, by `synced_since`, in every
round that pulls, during a backfill too. Until that first catch-up they
include this device's own writes, which a device starting over needs back;
after it they do not, or every push would come straight back.
A device still downloading its history therefore reads its checklists at
once. Claims take no part in deciding when the backfill is complete.

An epoch only ranks rows within one history. Linking, combining, replacing
or switching an account, and `SYNCALL`, therefore clear the table and the
claims window. The device rebuilds from the whole log once its backfill
completes. Claims are not kept in the local backup tables: `log` rows can be
rebuilt, and LoFi's failure backup captures them with the rest of the
payload.

## 8. Spots and the logging panel

A spot goes through the same hook as a contact: the app builds a candidate
contact from it — their call, the band from the frequency, the spotted
mode, any refs the spot carries, our station and its place — and calls
`claimsForQsos`. A spot says nothing about the state it is in, so the
candidate carries the state an offline lookup gives for its call and refs,
as the lookup's guess: call history's for a station worked before, the
park's for a park spot. A station never worked, spotted on a cluster, has
none, and a program that chases states does not judge it.
What comes back is what working the station would claim, at `worked`.
Typing a call in the logging panel does the same.

Compared against the checklist, each candidate gets a **verdict**:

1. **New ref** — the any-band, any-mode slot is missing.
2. **New band** or **new mode** — only the narrower slot is missing.
3. **Unconfirmed** — the slot exists at `worked`; working them again may
   bring a QSL.
4. **Worked** — nothing new.

Ties break by the operator's goal order. The Chasing view ranks spots by
verdict, and its alerts fire on the verdicts the operator picks. A claim
marked `guess` reads "probably new": a county or state inferred from a
callsign is wrong for a station operating away from home.

Verdicts are cached per spot and recomputed when the spot changes or when a
slot it touched does. What a candidate claims is asked of the program once
per candidate, whatever the time, and kept until the runtime restarts; the
checklist it is compared against is reread whenever the table changes.

**Goals** are programs. The Chasing sheet orders them and turns them on and
off. A program not chosen yet joins the goals, on: an extension enabled with
a program in it is one the operator means to chase. A program turned off
stays off, even when its extension is removed and added again. Only the goals
that are on are judged. Every hunting control shows on the Chasing view's
logging panel whatever the goals say: a goal decides what is judged, not
which references can be logged.

**Notices.** A verdict travels as a notice key beside the scorers' own
(`chase:<program>:<verdict>`, with `:guess` and `:alert` flags), so the spot
rows and the pills by the call field carry both through one mechanism. In
the Chasing view the verdicts replace scoring's notices, and scoring keeps
only its `duplicate`: a station worked this period. A duplicate gets no
verdict notice, so its row stays struck. Under `EXP CHASE`, an operation's
spots and calls also carry the verdicts the operator alerts on, beside the
operation's own scoring. A program names the scoring notices its verdicts
stand in for (`supersedes`; DXCC's is core scoring's `newDXCC`, WAS's its `newState`), and where it
judges a call those are dropped: the scorer keeps them for everyone chasing
does not reach yet, and a feature leaves core scoring only once chasing
ships without the experiment. A notice names the reference by what the
program calls one (`refLabel`: "New POTA Park"), or by the program's label
("New DXCC").

**Alerts.** The operator picks which verdicts alert; new ref, new band and
new mode until they do. An alerting spot's callsign takes the green accent
of something new, not the multiplier's, and its band or mode the new-band or
new-mode one. A spot whose reference is the one a new-ref verdict names
(`ChaseJudgement.refs`) has that reference accented too; a new DXCC entity
names none a spot row shows. The Chasing view
can show only alerting spots. Sound and notifications are not built.

**Most wanted** is the Chasing view's own spot sort, and its default: by
verdict, then goal order, then newest. Spots no goal judges follow, and
spots worked this period come last.

The Info panel shows each goal's checklist through `summarizeClaims`, for
the station's first holder in the current edition: empty for a lifetime
program, the UTC year for an annual one. An event program has no current
edition the app can tell from the date, and shows none. Each tally reads as
one sentence ("2 DXCC Entities, 0 confirmed"), not scoring's columns.

## 9. Imports

A sponsor's export confirms or verifies references but rarely says which
contact did it — POTA's CSV of hunted parks, for one — and the contact may
not be in this log at all. Each export has its own format, so reading it is
the program's `importClaims`, for the importers its `program.imports` lists
(`{key, label, extensions}`):

```ts
interface ImportedClaim extends QsoClaim {
  at?: number
  match?: { theirCall?: string; startAtMillis?: number; band?: string; mode?: string }
}
```

Every record becomes a **claim record** in the log: a loose event row, like
an operation's start and break markers, so it syncs with the log — through
LoFi and over peer links — and every contact query already leaves it out:

```jsonc
{
  "band": "event",
  "our": { "call": "EVENT" }, "their": { "call": "CLAIM" },  // what a PoLo device keys each row on
  "startAtMillis": 1689379200000,                            // the claim's date, or the import's
  "event": {
    "event": "claim", "program": "ham2k-pota", "importer": "hunted-parks",
    "claim": { "holder": "KI2D", "ref": "US-0022", "band": null, "mode": null,
               "level": "verified", "by": "pota", "label": "Denali National Park",
               "at": 1689379200000 }
  }
}
```

The claims service reads a claim record as the claim it holds, under its
own program, without asking the program again (§6): the program made that
claim when it read the file. So the claims table stays a cache of the log,
and emptying it — as a device joining an account does — loses nothing.

A record's uuid is one per program, importer and slot. Exports are
cumulative, so a file is the whole of its importer's records: importing the
same kind of file again rewrites the records that changed, deletes those the
new file no longer lists, and leaves the rest alone, so the same file twice
syncs nothing. A file the program answers with no claims replaces nothing,
since an empty export and a file picked by mistake read the same.

The operator imports from a goal's row in the Chasing sheet, or by dropping
a file on the Chasing view, which offers the importers that take its
extension.

**Not yet built: matching.** A record that names its contact (`match`) and
verifies the slot should become `qso.credits.<program>` on that contact, so
the claim derives from the contact from then on, and a contact that arrives
later — by sync, or an ADIF import — should be matched the next time a device
holding it reconciles. No importer yet reads such a file: POTA's hunted parks
name no contact, and POTA's hunter log is only ever worked. It is built with
the first importer that needs it.

## 10. Not yet decided

- **LoFi-side rescans.** Downgrades for a user with no device holding the
  whole log need the server to hold every contact and run the hooks.
  Later.
- **The LoFi record type** for `claims`, and the web-lofi reader.
