# Import & export

Four categories move a log in and out of the app. `export` writes a file;
`adifFields` lets a program add its own fields to every ADIF record a
contact produces, whoever is writing the file; `adifImport` recovers a
program's references from an ADIF file someone else wrote; `transfer` sends
contacts to a service and remembers what it sent. [How hooks
work](hooks.md) covers registration, keys, priority and `ctx`. Which files
operators expect, and what goes in them, is in Guidelines,
[for an activity](guidelines.md#exports) and
[for a contest](guidelines.md#cabrillo-and-contest-adif).

## `export`

**For:** a file the operator can save or share: a program's submission, a
contest's Cabrillo, a full log.

**Called:** in two steps. The Exports panel asks every hook
`suggestExportOptions` to build its list; a hook that omits it never appears
there. Then it calls `generateExport` only for the options the operator
selected, passing back the chosen option's `exportType` and `exportKey`. The
app owns file I/O and the save-or-share dialog; you produce content.

```ts
interface ExportHook {
  getExportTypes?(args: {}, ctx): Promise<ExportTypeDefinition[]>
  suggestExportOptions?(args: ExportOptionsRequest, ctx): Promise<ExportOption[]>
  generateExport(args: ExportRequest, ctx): Promise<ExportResult>
}
// ExportOptionsRequest: { operation, qsos, segments?, compactFilenames? }
// ExportOption:         { exportType, exportKey?, format, label, filename?, instructions?, icon?, color?, refType?, ref?,
//                         priority?, selectedByDefault?, qsoCount?, templateData? }
// ExportRequest:        { operation, qsos, segments?, events?, exportType?, exportKey?, compactFilenames?,
//                         exportSettings?, exportData?, exportTitle?, includePrivateData?, includeLookupData?,
//                         mainHandler?, includeFieldsFrom?, operatorFallback? }
// ExportResult:         { filename, mimeType, content }
```

`qsos` holds contacts alone; the log's event rows (`break`, `start`, notes)
come separately in `events`, for a file that writes the timeline, and
`segments` is what they resolve to. `operation.startAtMillisMin` and
`startAtMillisMax` span the contacts in `qsos`, not the whole operation.

**Identity.** `exportType` is the stable kind (`potaActivation-adif`);
`exportKey` identifies one option within the hook (`pota-adif:US-1234`).
Options sharing a type must have distinct keys; omit `exportKey` for a
single option of a type. Both round-trip unchanged, and the app also keeps
the hook key and the station callsign with a selection, so different hooks
and stations stay independent. Prefer `<activationType>-<format>` to a key
namespace: two extensions offering that type share one settings entry, the
highest-priority registration supplies its definition, and the others must
honor it; a program with distinct sponsor requirements uses a distinct type.

**Types and settings.** `getExportTypes` runs without an operation, so
Settings can list your types before the operator has a matching log:

```ts
async getExportTypes() {
  return [exportTypeDefinition("potaActivation", "adif", "POTA", { includePrivateData: false, includeLookupData: true })]
}
```

An exporter without it still works but has no entry in the export settings.
`ExportSettings` holds `includePrivateData`, `includeLookupData`,
`customTemplates`, `filenameTemplate`, `compactFilenameTemplate`,
`titleTemplate`, `adifNotesTemplate`, `adifCommentTemplate`,
`adifQslMessageTemplate` and `choices` (below), all optional, resolved from the SDK's defaults,
then the operator's global preferences, then the type's own `defaults`.
`GlobalExportSettings` adds `referenceFilenameTemplate`,
`referenceCompactFilenameTemplate` and `referenceTitleTemplate` and the
matching `other…` set: a type with `templateCategory: 'reference'` uses the
reference set, other types the other, and the ADIF field templates are
common to both. Per-type data choices override the global ones; per-type
template overrides apply only while `customTemplates` is on, and turning it
off keeps the operator's edits for later. Non-ADIF formats expose only the
filename templates. Settings apply globally and per type, never per
operation. Empty templates deliberately suppress text. A definition may
supply `templateSample: { operation, log }` for the editor's preview.

**A type's own settings.** `choices` (extension API 25) adds settings of
the type's own to its page in Settings → Exports, each one pick among a few
options:

```ts
choices: [{
  key: "sigFields",
  label: t("sigFieldsLabel"),
  description: t("sigFieldsDescription"),
  options: [{ value: "potaRef", label: t("potaRefOnly") }, { value: "both", label: t("potaRefAndSig") }],
  default: "potaRef",
}]
```

The picks arrive in `exportSettings.choices`, keyed by each choice's `key`:
always one of its option values, and its `default` until the operator picks
another. An app older than API 25 shows no choices and sends none, so a
missing pick means the operator was never offered the choice: write what
your files held before it existed, which a new default may not be. Forward `exportSettings` when you delegate to
`adifForExport`, and your `adifFields` hook receives them too (below).

**How a row looks.** `refType` names the activity the export covers: the
app slices the file's contacts by it and takes the row's icon and color
from that activity's own control. `icon` and `color` override that, which is
how an export claiming no activity asks for a glyph; an icon name that does
not resolve, or an unreadable color, falls back to the activity's. An
export claiming
**one** reference of its type (one park's log when the operation activated
several) names it in `ref`, and the app narrows the slice to the segments
carrying that reference. `qsoCount` tells the app how many contacts an
option covers when the hook filters further; `templateData`
(`{ ref, refName, activity, modifier, … }`) populates the `log` namespace
the filename and title templates read. `instructions` (extension API 25)
is one short sentence telling the operator what to do with the file, shown
below its name as inline markdown and cut off after two lines; a link to the
upload page says more than a paragraph would. A link opens only when it is
`https`, `http` or `mailto`, and images are not shown.

**Filenames.** Build them with the SDK's `exportFilename`, passing the
request's `compactFilenames` through; that is what makes the operator's
"compact file names" setting apply, and what keeps every extension's names
consistent:

```ts
filename: exportFilename({
  stationCall: operation.stationCall,
  ref: "US-1234",                        // or activity: "CQ-WW-CW", or neither
  startAtMillis: startMillisOf(operation, qsos),
  extension: "adi",
  compact: args.compactFilenames,
})
// "2026-07-27 N0CALL at US-1234.adi"  /  "N0CALL@US-1234-20260727.adi"
```

Set `filename` on the **option**: the panel shows it and the app writes the
file under it. A name computed again in `generateExport` sees a different
input, only the contacts the option covers, and the two would disagree.

**Building the ADIF.** Compose a program's fields from the `adifFields`
hooks below rather than knowing other programs. The SDK's `adifForExport`
builds a record set, and when you delegate to it forward `exportSettings`,
`exportData`, `exportTitle`, `includePrivateData` and `includeLookupData`,
or the operator's preferences never reach the writer. Name yourself as
`mainHandler` and list in `includeFieldsFrom` the other programs whose
fields you accept (POTA lists `satellites`, since a park worked through a
bird is still a park activation). A listed key that answers nothing is fine,
since the operator may have that extension off; a `mainHandler` that
answers nothing is an error, since the file would claim no program. By
default the app writes `OPERATOR` only where it says something
`STATION_CALLSIGN` does not; `operatorFallback: 'base'` or `'station'`
writes the contact's own operator on every record, falling back to the
station call's base call or to the station call itself, for an uploader that
needs it.

The factories `activityExportHook` and `huntingExportHook` build the whole
hook for a reference program from its rules, register its types and forward
the settings. `k2hrc-llota` leaves them out; `ham2k-wwbota` in
[ham2k/extensions](https://github.com/ham2k/extensions) shows them in use,
and `ham2k-cqww` a contest's Cabrillo.

## `adifFields`

**For:** a program's own fields on each ADIF record a contact produces,
whoever is writing the file: POTA's `SIG`/`SIG_INFO`/`POTA_REF` for hunted
parks and `MY_SIG`/`MY_SIG_INFO`/`MY_POTA_REF` for the activation.

**Called:** inside the runtime, by exporters, through `hooks.invokeForRefs`
or `hooks.invokeOne`; no bridge crossing. Which hooks are asked is below.

```ts
interface AdifFieldsHook {
  fieldsForOneQSO(args: { qso, operation, mainHandler?, exportSettings? }, ctx): Promise<{ name, value }[]>
  fieldCombinationsForOneQSO?(args: { qso, operation, mainHandler?, exportSettings? }, ctx): Promise<{ name, value }[][]>
}
```

`mainHandler` is true when the file is your own export: how a program
writes what only its own submission asks for, such as both stations'
gridsquares, which the full export leaves to the contact's privacy rules.
`exportSettings` (extension API 25) is the file's own, present when the file
is a program's export rather than the full one: with `mainHandler`, its
`choices` are the operator's picks for your file, such as which fields name
your references.

**One contact can owe several records.** Where a program takes one
reference per record, work a station standing at two of its references and
each is submitted separately; a program whose field takes a list, as POTA's
`POTA_REF` does, gets one record naming both. `fieldCombinationsForOneQSO`
returns one field set per record; the exporter writes that many, shifting
each later record's `QSO_DATE`/`TIME_ON` by a second so they are not read as
duplicates. The record count is the largest any hook asks for. A hook
returning a single set describes the contact, and its fields go on every
record. Declaring both methods is fine: a hook that does is asked both,
its combinations win unless the list is empty, and either one failing fails
the file. Only a named export asks for combinations, of its own
program and the programs it includes, `mainHandler` saying which the hook
is; the full export is one record per contact, the copy the operator keeps, and
asks every hook for `fieldsForOneQSO` alone, so a splitting program answers
that too, naming its first reference in `SIG_INFO` and every one in its
`*_REF` list. A hook answering only combinations is left out of the full
export, and the runtime logs an error for it at activation.

**Who is asked.**

- **A program's own export** asks its own hook, named as `mainHandler`, and
  the hooks it lists in `includeFieldsFrom`. Not the whole category: activate
  a park that is also a lighthouse and each file claims its own reference.
- **The full export**, which names no main handler, asks the extensions the
  contact **belongs to**: for each reference on the contact's operation and
  on the contact itself, every extension holding the strongest claim on it
  (the longest `ref:<type>/<code>` prefix, else the bare `ref:<type>`; a
  longer claim excludes a shorter one, so an old `{ type: 'qp', ref: 'CA' }`
  belongs to the party claiming `qp/ca` and not also to the extension
  claiming all of `qp`). A hunted reference counts as much as an activation.
  Equal claims are all asked, whatever their priority. An extension the
  contact has nothing to do with is never asked, so a hook that forgets to
  check its own references costs nothing here; checking them is still how it
  behaves when named by another program's export.
- An extension with something to say about **every** contact opts in from
  its manifest, `"adifFieldsScope": "always"`. The packer refuses a manifest
  listing `adifFields` with neither a `ref:` type nor that opt-in, and the
  runtime logs an error at activation for one that registers the hook,
  answers for no reference and does not opt in. A hook named as
  `mainHandler` or in `includeFieldsFrom` is asked whatever the contact
  carries, opt-in or not.

**A field name is written once per record, and the first to carry a value
wins.** Hooks are asked main handler first, then each `includeFieldsFrom`
key in order; in the full export, in priority order. The contact's own
fields come after every hook's, since a program knows what its file needs
better than the contact's generic answer does, except what identifies the
contact: `CALL`, `QSO_DATE`, `TIME_ON`, `QSO_DATE_OFF`, `TIME_OFF`, `BAND`,
`FREQ`, `MODE`, `SUBMODE`, `STATION_CALLSIGN`, `OPERATOR`. A hook answering
one of those is dropped. **Answer a pair whole or not at all**: a hook
offering `MY_SIG` without `MY_SIG_INFO` takes the name and leaves the next
hook's reference under it, claiming another program's park for yours.

## `adifImport`

**For:** your program's references, recovered from an ADIF file. The app's
parser maps universal ADIF only and produces **no references at all**:
`SIG`, `SIG_INFO`, `SOTA_REF`, `IOTA`, `CONTEST_ID` and every `*_REF` field
mean nothing to it. This hook is the whole reference vocabulary on import.

**Called:** every hook, with the records in **batches of 500**, since each
call is a bridge crossing and a ten-thousand-contact import is twenty
crossings rather than ten thousand.

```ts
interface AdifImportHook {
  refsForRecords(args: { records: { fields: Record<string, string> }[] }, ctx): Promise<({ refs?: Ref[] } | null)[]>
}
```

`fields` is the record's raw ADIF, names lowercased and values decoded.

**Return one entry per record, positionally**, `null` for a record you have
nothing to say about. Never filter the empties out: the app matches results
to records by index, and a reply whose length does not match the batch is
discarded whole. Refs from different hooks accumulate, deduplicated by
`type` and `ref`; a park-to-park contact during a summit activation
legitimately carries both.

A returned ref may carry **`for: 'operation'`** to say it belongs on the
operation, as an activation does. ADIF has no operation, so it writes the
activation onto every record and a hook only ever sees one record; the tag
is how you say where the reference goes. The importer moves it and
consumes the tag. Untagged means the contact.

**The factory.** Most programs write the same `SIG`/`SIG_INFO` pair plus
their own comma-separated `*_REF` list, and
`activityAdifImport({ sig, huntingType, activationType, refField, normalize })`
builds the whole hook, tagging the activation side for you.
`referenceActivity` returns one ready-built.

- It reads **both** sources and merges them, deduplicated on the normalized
  value: a program's own exports may carry `SOTA_REF` and no `SIG` at all,
  while other software writes the same reference only as `SIG`/`SIG_INFO`,
  which names only the primary reference. The `SIG` value is checked before
  `SIG_INFO` is claimed, or every program would import every other's.
- **A reference the program's pattern rejects is imported anyway**, as
  written. By the time `normalize` runs the file has said whose the
  reference is, so a pattern failure means malformed, not foreign. The
  decorated reference is labeled invalid, in front of the operator to fix;
  discarding it would lose the only text a correction could work from.
  `normalize` repairs what it can (a dashless `us1234` becomes `US-1234`).

Two shapes the factory does not fit, for comparison: a satellite program
that writes `SAT_NAME`/`BAND_RX` and no `SIG` hand-writes its hook,
recovering the transponder where the downlink and uplink allow and importing
the bare bird otherwise; and a free-form "custom" program registers none,
because a hook claiming every `SIG` would add a spurious reference to every
other program's records, and "claim the `SIG`s nobody else claimed" is not
expressible by hooks that run independently.

## `transfer`

**For:** sending the operator's contacts to a service that keeps a copy of
the log: a logbook site, a program's archive (extension API 28).

**Called:** every hook's `suggestPushes` and `suggestDestinations` build
the list the operator picks from; then the chosen hook's `push`, once per
chunk of up to 25 contacts. The app builds every record,
decides which contacts go, and writes the results back on each contact; your
hook only talks to the service.

```ts
interface TransferHook {
  label: Localizable<string>
  description?: Localizable<string>
  services: TransferService[]               // { key, label }
  suggestDestinations(args: DestinationsRequest, ctx): Promise<TransferDestination[]>
  suggestPushes?(args: PushSuggestionsRequest, ctx): Promise<PushSuggestion[]>
  push?(args: PushRequest, ctx): Promise<PushRecordResult[]>
}
// DestinationsRequest:    { service, scope: PushScope, stationCalls: string[] }
// TransferDestination:    { id, label?, stationCall? }
// PushSuggestionsRequest: { scope: PushScope, sent? }
// PushScope:              { kind: "operation", operation }
// TransferSummary:        { key?, sentAtMillis?, sentCount? }   (each of `sent`'s entries, by record key; sentCount: the operation's contacts the destination holds)
// PushSuggestion:         { key, service, label, description?, payload?, select, emphasis?, selectedByDefault? }
// PushPayload:            { mainHandler, includeFieldsFrom? } | { full: true, includePrivateData?, omit? }
// QsoSelector:            { hunted?, activated?, notSentTo?, changedSince? }
// PushRequest:            { service, stationCall, destination, records: PushRecord[] }
// PushRecord:             { uuid, adif: string[], deleted?, id? }
// PushRecordResult:       { uuid, id?, error? }
```

**Services and records.** A service is where your hook sends contacts:
`qrz`, `wavelog`, `sota`. Where on it a contact goes is a destination (see
below), with an id you choose. The app keeps one record on each contact per
service and destination, under `<service>:<destination id>` in lower case:
`qrz:ki2d`, `qrz:n0club`, `sota:chase`. A service with one place names a
default destination of its own, such as `wavelog:main`. A service key is
lower case without `:`, and belongs to one extension: a second hook
declaring it is ignored for it, and a suggestion naming a service your hook
did not declare is dropped. A service's `label`, or your hook's when it
gives none, names its push rows, and your hook's `description` stands in
for a suggestion that gives none.

**Suggestions.** `suggestPushes` is asked about a scope, which is one
operation (`kind: "operation"`). Check `kind` and offer nothing for one you
do not know: later API levels add other scopes. `sent` holds the
operation's summary of earlier pushes, by record key, and
`scope.operation.status` says whether the operator finished it.
You name the contacts with `select` and the app finds them, so you never
receive the log:

- `hunted`: the contact carries a reference of that type;
- `activated`: the contact's operation carries one;
- `notSentTo`: the contact was never sent there;
- `changedSince`: the contact, or its operation, changed after it was last
  sent there.

`notSentTo` and `changedSince` take a service or a whole record key. A
service (`"qrz"`) is read against the destination being counted, so a
contact sent to one QRZ logbook is still `notSentTo: "qrz"` for another. A
record key (`"sota:chase"`) names that record whatever the destination.
Every condition you give must hold, and each suggestion names `notSentTo`
or `changedSince` of its own service (or a record key under it), so what
it sends stops being selected: one naming neither, or another service's,
is dropped. The app counts what each suggestion selects and leaves
out one that selects nothing, so offer a suggestion whenever it could
apply:

```ts
async suggestPushes({ scope, sent }) {
  if (scope.kind !== "operation") return []
  const push = { key: "qrz", service: "qrz", label: "Push to QRZ", select: { notSentTo: "qrz" } }
  if (!Object.keys(sent ?? {}).some((key) => key.startsWith("qrz:"))) return [{ ...push, emphasis: "due" }]
  return [push, { key: "qrz-updates", service: "qrz", label: "Push updates to QRZ", select: { changedSince: "qrz" }, emphasis: "updates" }]
}
```

A deleted contact the destination still holds goes with a suggestion of its
service as a delete, unless the suggestion selects `notSentTo` that service.

**What is sent.** `payload` says how each record is built, as the exports
build them: `{ mainHandler }` for your program's own records, its
`adifFields` hook composed as its export composes it; `{ full: true }` for
the operator's full copy. A full copy leaves the private fields out unless
`includePrivateData`, and leaves out every field `omit` names, a trailing
`*` matching a prefix (`"app_*"`). Left out, `payload` is the full copy.

**Destinations.** A destination is a place on the service the contacts can
go: a logbook, a folder, a station location. The app asks
`suggestDestinations` for each service with the scope (the operation itself,
in the Exports panel) and `stationCalls`, every station callsign the
scope's contacts were made under, segments included. Offer as many as fit:
none hides the push, and each one you offer is a push of its own, which the
operator sends separately. Name a `stationCall` when only that call's
contacts belong there, which is the usual case for a logbook; leave it out
to take every contact in the scope. Throw to say why you cannot offer any,
and the operator sees your message. The app asks each time and saves
nothing, so answer from what the scope says. A destination is a name, never
a secret: look up the key it needs from your account.

**Pushing.** A hook without `push` only pulls, and the operator is offered
no push rows for it. `push` gets one station callsign's records, at most 25 at a
time. A contact split into several records by its program carries them all
in `adif`. Return one result per record, by `uuid`:

- `id`, the service's own id for the contact. The app sends it back with
  every later update and with the delete, in `PushRecord.id`.
- `error`, when the service refused it. The contact stays unsent and is
  offered again.

A record with `deleted` asks you to remove the contact from the service by
its `id`; return it without an `error` once removed.

**Rules:**

- The app skips a contact whose record is unchanged since it was last sent
  to the same destination, so a push of updates may send fewer than it
  counted.
- Throwing from `push`, or taking over a minute, stops the push there.
  Nothing from that chunk is saved, since you may have sent part of it, so
  the next push sends those records again without an `id`: make sending a
  record twice harmless, as QRZ's `OPTION=REPLACE` does. Refuse one record
  with its `error` instead, and the rest of the push goes on.
- A push that ends with every record accepted marks its operation
  processed, as an export does.
