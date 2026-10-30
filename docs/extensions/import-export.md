# Import & export

Three categories move a log in and out of the app. `export` writes a file;
`adifFields` lets a program add its own fields to every ADIF record a
contact produces, whoever is writing the file; `adifImport` recovers a
program's references from an ADIF file someone else wrote. [How hooks
work](hooks.md) covers registration, keys, priority and `ctx`.

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
// ExportOption:         { exportType, exportKey?, format, label, filename?, icon?, color?, refType?, ref?,
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
honour it; a program with distinct sponsor requirements uses a distinct type.

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
`titleTemplate`, `adifNotesTemplate`, `adifCommentTemplate` and
`adifQslMessageTemplate`, all optional, resolved from the SDK's defaults,
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

**How a row looks.** `refType` names the activity the export covers: the
app slices the file's contacts by it and takes the row's icon and colour
from that activity's own control. `icon` and `color` override that, which is
how an export claiming no activity asks for a glyph; an icon name that does
not resolve, or an unreadable colour, falls back to the activity's. An
export claiming
**one** reference of its type (one park's log when the operation activated
several) names it in `ref`, and the app narrows the slice to the segments
carrying that reference. `qsoCount` tells the app how many contacts an
option covers when the hook filters further; `templateData`
(`{ ref, refName, activity, modifier, … }`) populates the `log` namespace
the filename and title templates read.

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
  fieldsForOneQSO(args: { qso, operation, mainHandler? }, ctx): Promise<{ name, value }[]>
  fieldCombinationsForOneQSO?(args: { qso, operation, mainHandler? }, ctx): Promise<{ name, value }[][]>
}
```

`mainHandler` is true when the file is your own export: how a program
writes what only its own submission asks for, such as both stations'
gridsquares, which the full export leaves to the contact's privacy rules.

**One contact can owe several records.** Work a station standing in two
parks and each park is submitted separately. `fieldCombinationsForOneQSO`
returns one field set per record; the exporter writes that many, shifting
each later record's `QSO_DATE`/`TIME_ON` by a second so they are not read as
duplicates. The record count is the largest any hook asks for. A hook
returning a single set describes the contact, and its fields go on every
record. Declaring both methods is fine: a hook that does is asked only for
its combinations. Only a program's **own** export asks for combinations;
the full export is one record per contact, the copy the operator keeps, and
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
  decorated reference is labelled invalid, in front of the operator to fix;
  discarding it would lose the only text a correction could work from.
  `normalize` repairs what it can (a dashless `us1234` becomes `US-1234`).

Two shapes the factory does not fit, for comparison: a satellite program
that writes `SAT_NAME`/`BAND_RX` and no `SIG` hand-writes its hook,
recovering the transponder where the downlink and uplink allow and importing
the bare bird otherwise; and a free-form "custom" program registers none,
because a hook claiming every `SIG` would add a spurious reference to every
other program's records, and "claim the `SIG`s nobody else claimed" is not
expressible by hooks that run independently.
