# Data Transfer & Interchange: moving contacts to and from other services

*Status: in progress (HALO-948), behind `EXP PUSH`: with it off the app
asks no `transfer` hook anything. Push (§2–§7) is built in the app and the
SDK, at extension API 28, and offered from the Exports panel; the Logs and
Chasing views do not offer it yet. The `import` hook
(§9) builds on imports.md (HALO-841), and pull (§8) on both.*

Operators keep copies of their log elsewhere: QRZ.com's logbook, Wavelog,
a program's own archive (SOTA's activator and chaser logs). Getting contacts
there today means exporting a file and uploading it by hand, and nothing
remembers which contacts went where. Getting them back (a QRZ download with
its confirmations) is an ADIF import that forgets where the file came from.

This design adds **transfers**: an extension that talks to a service pushes
contacts to it and pulls them back, and the app remembers, per contact and
per service, what was sent.

## 1. Two things, kept apart

- **Confirmation** is whether the other station confirmed the contact, and
  through which medium: LoTW, eQSL, a paper card, QRZ.com. It lives in
  `qso.qsl.<medium>`, in the shape the ADIF importer writes today
  (`received`, `receivedOn`, `sentOn`, `id`), and [claims.md](claims.md)
  reads it.
- **Transport** is where a copy of the contact was sent, and what it was
  called there. It lives in `qso.transfer["<service>:<destination>"]` (§2).

They stay apart because confirmations arrive through many channels and only
some are services the app talks to: a paper card, a file a sponsor mails, a
QRZ download that also carries LoTW's dates. A transfer never writes
`qso.qsl` itself. What it pulls goes through the `import` hooks (§9), and
only they write confirmations.

So a QRZ.com extension offers a `transfer` hook for pushing and pulling, and
separately an `import` interpreter and a `qsl:qrz` handler for what QRZ
says about confirmations. A Wavelog extension offers only the `transfer`
hook.

## 2. Services and the transfer record

A **service** is where a hook sends contacts: `qrz`, `wavelog`, `sota`,
`lotw`. Where on it a contact goes is a **destination** (§6): a QRZ
logbook, a Wavelog station location, SOTA's chase or activation log. The
hook names its destinations, and each has an id of the hook's choosing,
unique within its service. A service with one place names a default of its
own, such as `wavelog:main`.

A contact keeps one **record per service and destination**, under the key
`<service>:<destination id>`, in lower case:

```jsonc
qso.transfer["qrz:ki2d"] = {
  key: "ham2k-qrz",             // the extension that last wrote this
  id: "2134-5543534",           // the service's own id for the contact there, if it gives one
  sentAtMillis: 1794000000000,  // when the service accepted it
  sentRevision: 1794000000123,  // the contact's updatedAtMillis after this record was written (§7)
  hash: "…",                    // of the ADIF record that was sent (§5)
  operationHash: "…",           // of the operation content it was written from (§7)
}
qso.transfer["qrz:n0club"] = { … }       // the same contact in a second QRZ logbook
qso.transfer["sota:chase"] = { … }       // a summit-to-summit contact goes to both SOTA logs
qso.transfer["sota:activation"] = { … }

operation.data.transfer["qrz:ki2d"] = { key, sentAtMillis, sentCount }   // sentCount: the operation's contacts it holds
```

A contact cannot be in one QRZ logbook twice, but it can be in two: a
multi-op operation's contact goes to the logbook of each station call it
was made under whose operator pushes it. Each record keeps its own id, hash
and revision, so pushing to one destination never makes another look sent,
or behind. A record is keyed by where the contact went, not by what it is: a
contact can carry two POTA references and still have one record per place
it was sent.

A service key is lower case and never contains `:`, so a record key splits
at its first one. An extension declares its services when it registers, so
two extensions claiming one service are reported at startup, not discovered
at write time, and every record under a service is that extension's.

`sentAtMillis` and `sentRevision` are `realNowMillis()` stamps, for the same
reason the sync revision is ([time.md](time.md)): they persist and are
compared against `updatedAtMillis`.

**The (record key, id) pair is an external id**, and so is an import's logger
key (HALO-841's imports.md §3 writes one as `qrz:629033963`, a service and
an id, not a record key): a QRZ push gets back the same `LOGID` that a QRZ
export writes as `APP_QRZLOG_LOGID`. Both feed one
lookup from external id to contact, so a contact pushed and later pulled
back is found by its id and never by the matcher.

## 3. The `transfer` hook

```ts
registerHook("transfer", {
  key: "qrz",
  hook: {
    label: "QRZ.com Logbook",
    services: [{ key: "qrz", label: "QRZ.com Logbook" }],
    suggestDestinations(args: { service; scope: PushScope; stationCalls: string[] }, ctx): Promise<TransferDestination[]>,   // §6
    suggestPushes?(args: { scope: PushScope; sent?: Record<recordKey, TransferSummary> }, ctx): Promise<PushSuggestion[]>,
    push?(args: { service; stationCall; destination; records: PushRecord[] }, ctx): Promise<PushRecordResult[]>,
    pull?(args: { service; destination; cursor?: string }, ctx): Promise<PullResult>,   // §8
  },
})
```

The hook's own key goes in each contact's record as `key`. A hook without
`push` only pulls, and is offered no push rows. Its `label` names a
service that gives none, and its `description` a suggestion that gives none. The extension's
`account` hook holds whatever credentials push and pull use.

Settings list transfers under their own category, **Data Transfer &
Interchange**: each service and its account.

## 4. Suggestions and scopes

The app asks every `transfer` hook what it would push, the way the Exports
panel asks every `export` hook for its options. A suggestion is asked about
a **scope**, because pushing is not only about operations:

```ts
type PushScope =
  | { kind: "operation"; operation }        // the Exports panel; operation.status included
  | { kind: "chasing" }                     // contacts logged outside any operation
  | { kind: "log"; stationCall; selection?: true }   // the Logs view: its callsign filter,
                                                     // or the selected rows when there are any
// `chasing` and `log` come with push from the Logs and Chasing views; the
// SDK declares only `operation` until then.

interface PushSuggestion {
  key: string
  service: string
  label: string                             // "Push to QRZ", "Push updates to QRZ"
  description?: string
  payload: PushPayload                      // §5
  select: QsoSelector
  emphasis?: "due" | "updates"
  selectedByDefault?: boolean
}

interface QsoSelector {
  hunted?: string                           // a ref type the contact hunted
  activated?: string                        // a ref type the operation activated
  notSentTo?: string                        // no record on the contact for this key
  changedSince?: string                     // a record behind the contact (§7)
}
```

A suggestion names `notSentTo` or `changedSince` of its own service, or of a
record key under it: the push writes its records there, so without one it
selects its contacts again once they are sent, and its row is never done.
The app drops it. The two record selectors take a service or a whole record key. A service
(`"qrz"`) is read against the destination of the push being counted (§6),
so a contact sent to one QRZ logbook is still `notSentTo: "qrz"` for
another. A record key (`"sota:chase"`) names that record whatever the
destination.

**The hook names the contacts; the app finds them.** A Logs scope can hold
tens of thousands of contacts, so they never cross into the extension. The
app evaluates `select` over the contacts it already holds for the scope,
counts the result, and drops any suggestion that selects nothing. So a SOTA extension offers "Push SOTA
hunter QSOs" with `{ hunted: "sota", notSentTo: "sota:chase" }`
unconditionally, and it appears only where there are such contacts.

**The Exports panel shows a row per destination, not per suggestion.** Its
"Sync & Push to Services" section lists Ham2K Cloud Sync first, then, for
each service a hook suggested anything for, a row per destination the hook
offers (§6), named by the hook's first suggestion and the destination's
label. A row with nothing selected for its destination is done, and shows a
check and how many of the scope's contacts that destination holds.
Otherwise its one Push sends every suggestion that selects something there,
in turn, and a contact two of them select goes with the first only.

What a hook reads to decide is the scope itself and `sent`, the operation's
summary of earlier pushes. A QRZ extension offers "Push to QRZ"
(`notSentTo: "qrz"`) with emphasis `due` on a `completed` operation it has
never pushed, and "Push
updates to QRZ" with `changedSince: "qrz"` once it has. An edit after a push
moves a `processed` operation back to `completed`
([operations_repository.dart](../../packages/halo_core/lib/src/repo/operations_repository.dart),
`followContact`), so that state alone tells the hook a push has gone stale.

## 5. What is sent

A suggestion names how each record is built, in the export vocabulary
([import-export.md](../extensions/import-export.md)):

```ts
type PushPayload =
  | { mainHandler: string; includeFieldsFrom?: string[] }   // a program's own records, as its export composes them
  | { full: true; includePrivateData?: boolean; omit?: string[] }   // the operator's full copy; private fields only
                                                                    // when asked, without what `omit` names ("app_*")
```

Each record is the core ADIF exporter's own record for that contact, run
through the same payload the Exports panel builds (segments and station-call
rewrites included, the log's segment events left out: a service takes
contacts), then rewritten field by field, without ADIF's optional data
types, so one contact always renders, and hashes, the same.

**The app builds each contact's ADIF, not the extension.** It generates the
records through the same `adifFields` composition every export uses, hashes
each one, and leaves out a contact whose hash matches its record's `hash`
for the destination. A count from `changedSince` is therefore an upper bound, and the
push sends what actually changed. A contact that owes several records
(`fieldCombinationsForOneQSO`) is one `PushRecord` with several ADIF lines.

```ts
interface PushRecord { uuid: string; adif: string[]; deleted?: boolean; id?: string }
interface PushRecordResult { uuid: string; id?: string; error?: string }
```

**Deletes travel too.** A deleted contact (its tombstone) that still has a
record for the destination is pushed there with `deleted: true` and that
record's `id`, and the hook removes it from the service. That record is
cleared once the service confirms; the contact's records for other
destinations stay until their own deletes go. A delete goes with every
suggestion of its service except one selecting `notSentTo` that service: the
destination holds the contact, so it was sent.

**A push goes by station callsign.** A destination that names a station
callsign takes the contacts made under it, each written as that call's log
writes it, the way the Exports panel files them per call. One that names
none takes every contact in the scope, each written under its own call.
Operator calls never decide where a contact goes.

**The app drives the push in chunks**, each a bounded bridge call with
progress shown, so an interrupted push keeps what already landed. A chunk
the hook throws on, or takes over a minute on, stops the push: the hook may still be
sending it, and the service may hold some of it with no id saved, so the
next chunk waits for the operator to push again. That push sends those
records again without an id, so a hook makes a resend harmless (QRZ's
`OPTION=REPLACE`).

## 6. Destinations

A service often holds several logbooks: QRZ.com issues an API key per
logbook, and Wavelog has a station location per callsign. Where a scope's
contacts can go is a **destination**, and the hook decides which there are:

```ts
interface TransferDestination { id: string; label?: string; stationCall?: string }
```

- The app asks `suggestDestinations` with the scope (the operation itself,
  in the Exports panel) and `stationCalls`, every station callsign its
  contacts were made under, segments included. The hook offers none, one or
  several: QRZ offers each logbook it holds a key for whose callsign is one
  of them.
- Each destination is a push row of its own, and the operator pushes each
  separately. One the hook does not offer is not shown; a hook that throws
  shows its message in place of rows.
- Nothing is saved: the hook is asked each time, so it can answer from the
  operation in front of it.
- A contact keeps a record per destination (§2), so pushing it to two
  logbooks of one service records both. In an operation with several
  station calls the others usually belong to other operators, who take
  their own ADIF files, so most contacts go to one.
- A destination is a name, never a secret. For QRZ it is the logbook's
  callsign as `ACTION=STATUS` reports it, and the push looks up the API key
  for that logbook from the account. A name also survives the operator
  regenerating the key, which a hash of the key would not.

That needs one addition to the `account` hook: a **repeating secret field**,
so the QRZ account holds a list of logbook keys the operator adds to and
removes from. Each key is checked with `STATUS` when it is added.

## 7. Writing back

The app writes each chunk's results itself, never the extension:

- **Only under a service the hook declared**, one record key at a time: a
  `qrz:ki2d` write never disturbs `qrz:n0club` or `sota:chase`.
- **One transaction and one change notification per chunk.** A write per
  contact would rebuild the operation view once per contact.
- **The write bumps `updatedAtMillis`**, which is the sync revision: a
  record written without a bump is overwritten by the next stale copy sync
  brings in. The first push of a log therefore re-syncs it, which is
  correct.
- **An edit made while the push was out stays due.** The record's
  `sentRevision` is the write's revision only when the contact is still the
  copy that was sent; otherwise it keeps that copy's revision, so the
  contact reads as behind and the edit goes next time. The service's `id`
  is saved either way, or the next push would make a copy.
- **The write does not go through `followContact`.** It is bookkeeping, not
  an edit: through `followContact`, every push would move its own operation
  from `processed` back to `completed` and read as stale at once.
- **A successful push marks the operation `processed`**, from `active`,
  `paused` or `completed` alike: sending the log out is the operator saying
  it is done. Successful means every suggestion on the row ran and the
  service accepted every record; a push that throws or has a record refused
  leaves the status alone. The summary in `operation.data.transfer` is
  recorded either way, since what went is at the service.

**Keeping `changedSince` honest.** The bump makes every other record look
behind: push to Wavelog, and every contact reads as changed for QRZ; push to
one QRZ logbook, and it reads as changed for the other. So when the app
writes one destination's record, in the same transaction it moves forward
every other record's `sentRevision` that was
equal to the contact's previous `updatedAtMillis`. Those records were up to
date, and the only change since is bookkeeping. An edit made elsewhere (PoLo, an older
HaLo) moves only `updatedAtMillis`, and counts as a change, as it should.

**Operation edits count too.** Correcting an operation's park, grid or a
segment's station call rewrites every contact's record without touching any
contact. So each record keeps `operationHash`, a hash of what the operation
writes into it: the operation's fields and its segments, without the
bookkeeping (status, transfer summaries, timestamps) that moves on every
status change. A record whose `operationHash` differs from the operation's
now is behind, as an edited contact is. A push that finds the ADIF unchanged
(a new title is in no record) sends nothing and writes the record back with
the new hash and revision, so it is not selected again. The operation's own
`updatedAtMillis` cannot serve: finishing, resuming and the push itself all
move it.

## 8. Pulling

A pull returns what the service holds, in a format an `import` reader knows
(§9):

```ts
interface PullResult { format: string; content: string | Uint8Array; cursor?: string }
```

**A pull is an import.** The payload goes through the pipeline in
imports.md §3 (HALO-841), recorded as an import whose source is the
service instead of a filename: unchanged rows are skipped by their hash, a
row whose external id is known goes straight to its contact, and the rest
meet the account-wide matcher. The destination supplies the station
callsign, so a pull never asks for one. A matched or added contact gets its
record for that destination refreshed (`id`), and the `import` interpreters
read the confirmation fields into `qso.qsl`.

A pull covers the whole log, not one operation: confirmations arrive for
contacts of every operation. It runs as a command from the Logs view.

## 9. The `import` hook and `qsl:<medium>`

`import` generalizes today's `adifImport` into two roles, both batched:

```ts
registerHook("import", {
  hook: {
    formats?: [{ key: "wavelog-json", label, extensions?: ["json"] }],     // a reader
    readRecords?(args: { format; content; source }, ctx)
      : Promise<{ records: { qso: Qson; fields?: Record<string, string>; raw?: Uint8Array }[]; skipped?: number }>,

    reads?: { adif: ["lotw_*", "app_qrzlog_*"] },                         // an interpreter
    loggerKey?: { format: "adif"; field: "app_qrzlog_logid"; service: "qrz" },
    interpret?(args: { format; records: { qso; fields }[]; source }, ctx): Promise<(Partial<Qson> | null)[]>,
  },
})
// source: { file: name } | { transfer: service; destination? }
```

- A **reader** turns a file or a pulled payload into records. The ADIF reader
  stays in Dart, for speed, as the built-in reader for `adif`. A reader
  hands back each record's raw bytes so the import can hash it as it hashes
  an ADIF row.
- An **interpreter** declares the fields it reads, by format, and is called
  only for batches that carry one of them, with only those fields. It
  returns part of a QSON record, merged under the rules imports already
  follow ([qso_merge.dart](../../packages/halo_core/lib/src/models/qso_merge.dart)):
  references accumulate, `qsl.<medium>` merges per medium and never loses
  `received`, other fields fill gaps, and priority decides between two
  hooks setting one field.
- **`loggerKey` is data**, read by the app before any hook runs, since
  triage happens before the hooks.
- The core ADIF extension supplies the default interpreters: paper, LoTW and
  eQSL confirmations, taking over from `_qslFrom` in
  [adif_to_qson.dart](../../packages/halo_core/lib/src/adif/adif_to_qson.dart).
  The `app_qrzlog_*` rule moves to the QRZ extension.
- An `adifImport` registration keeps working, as an interpreter reading
  every ADIF field.

`qsl:<medium>` explains a medium, as `ref:<type>` explains a reference
type: `label`, `shortLabel`, `icon`, `color`, `describeQsl` ("Confirmed on
QRZ.com, 1 May 2026") and `linkForQsl`. Nothing displays `qso.qsl` today;
this stage adds a Confirmations section to the contact's details.

## 10. Stages

1. **Push**, with QRZ.com: §2–§7.
2. **The `import` hook and `qsl:<medium>`**: §9, on top of imports.md.
3. **Pull**, with QRZ.com's downloads and confirmations: §8.
4. **Wavelog**: push and pull, no confirmations, to prove `transfer`
   stands on its own.

Each stage changes the extension API and lands with its pages under
`docs/extensions/`.

## 11. Not yet decided

- Pushing on every logged contact, as a live stream, rather than on
  request; and pushing when an operation finishes (HALO-946).
- LoTW, whose upload is a signed file (HALO-941…944).
- Reprocessing stored import rows when a new interpreter arrives, so
  installing an extension confirms contacts already imported.
- Whether two logbooks of one service under one callsign need QRZ's book id
  beside the name.
- Which destination an imported file's logger key belongs to: a QRZ export
  carries `APP_QRZLOG_LOGID` but not the logbook, so the external id
  (`qrz:<logbook>`, id) needs the logbook from somewhere else, such as the
  file's `STATION_CALLSIGN` or the import's source.
