# Claims: what a contact counts toward

*Status: partial. The hook (§2) is built, with DXCC as its first program.
The `claims` table and the service keeping it current (§5–§7) are built, and
run only under `EXP CHASE`. Claims do not sync yet. The Chasing view's goals
(`app/lib/views/chase_view.dart`) are still activities' hunter controls.*

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
  importClaims?({ file, holders }, ctx): Promise<ImportedClaim[]>      // §9, not built yet
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
  claims for a call at a place (`KI2D@FN21rq`). The holder is an opaque
  string the program builds; `holdersFor` lists the ones a station uses, so
  the view knows which checklist to show.
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
  source      'log' | 'import:<batchId>'
  level       'worked' | 'confirmed' | 'verified'
  at_millis   when the claiming contact happened (null if an import didn't say)
  qso         the claiming contact; null for an unmatched import     (indexed)
  data        by, label, guess, and an import's own fields
  version     the program version that computed it
  epoch       raised by a rescan; outranks the claim on merge (§7)
  deleted, synced, updated_at_millis
```

A slot has at most one `log` row, plus any `import:` rows. **The checklist
is the best row per slot across sources**, by §1's rule.

`log` rows are derivable from the log, and synced anyway: a device holding
part of the log, or a web client holding none, reads its checklists from
here. Every device computes the same row from the same contacts, and the
uuid is deterministic, so they agree on which row they are writing.

## 6. Keeping it current

`ClaimsService` follows every write to the log through
`QsosRepository.changes`. That covers local edits, imports, and what sync
and peers merge; writes to the score cache are not included.

The log is every contact that is not deleted and is not in a deleted
operation. Deleting or restoring an operation writes none of its contacts,
so `OperationsRepository.deletions` reports it instead, and a device
holding the whole log rescans. A program that is missing when changes
arrive, because its extension is off or the runtime is restarting, never
sees them, so it is rebuilt once it is back. One that fails on a pass is
rebuilt once more right after it.

Changes waiting for a pass are held in memory, so a marker on disk says
some are waiting; a launch that finds it, after a quit or a crash, rebuilds.
The service hears changes from the start of boot, before the runtime that
answers for the programs is up, and holds them until it is.

**Holding the whole log.** A device holds the whole log when sync is off, or
when LoFi has reported a completed full sync. A device still backfilling
holds part of it.

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
is never overwritten by a rebuild.

## 7. Merging on sync

Last-writer-wins would let a device that cannot see the better contact
overwrite the better claim with a newer, worse one. So an incoming row is
merged:

1. The higher `epoch` wins — only a rescan raises it, which is how a
   deliberate downgrade gets through.
2. At the same epoch, a live claim beats a withdrawn one. An upgrade made
   by a device that missed a rescan refills the slot at the rescan's epoch.
3. Then the better claim wins, by §1's rule, and then the newer write.

A device that holds a better row than the one it received writes it back.
The order is total, so every device converges on the same rows.

## 8. Spots and the logging panel

A spot goes through the same hook as a contact: the app builds a candidate
contact from it — their call, the band from the frequency, the spotted
mode, any refs the spot carries, our station — and calls `claimsForQsos`.
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
slot it touched does.

## 9. Imports

A sponsor's export confirms or verifies references but rarely says which
contact did it — POTA's CSV of hunted parks, for one — and the contact may
not be in this log at all. Each export has its own format, so reading it is
the program's `importClaims`:

```ts
interface ImportedClaim extends QsoClaim {
  at?: number
  match?: { theirCall?: string; startAtMillis?: number; band?: string; mode?: string }
}
```

The app reconciles each record against the contacts it holds:

- **A contact matches** (same call, close in time, same band if given):
  the record becomes `qso.credits.<program>` on that contact, and the claim
  derives from the contact from then on.
- **None does:** the record becomes an `import:<batchId>` row with no
  contact behind it.

A contact that arrives later — by sync, or an ADIF import — is matched the
next time any device holding it reconciles. The unmatched row and the
derived one can both stand; the slot is the better of the two.

## 10. Not yet decided

- **LoFi-side rescans.** Downgrades for a user with no device holding the
  whole log need the server to hold every contact and run the hooks.
  Later.
- **The LoFi record type** for `claims`, and the web-lofi reader.
- **Moving the Chasing goals onto programs**: today a goal is an
  activity's hunter control; with this, a goal is a program, and its
  controls follow from the extension that registers it.
