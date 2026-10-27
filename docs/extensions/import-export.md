# Import & export hooks

The [hook reference](hooks.md) says how hooks are registered and invoked, and what every hook is handed.

## ✅ `export` — log file generation

```ts
interface ExportHook {
  getExportTypes?(args: {}, ctx): Promise<ExportTypeDefinition[]>
  suggestExportOptions?(args: ExportOptionsRequest, ctx): Promise<ExportOption[]>
  generateExport(args: ExportRequest, ctx): Promise<ExportResult>
}
// ExportOptionsRequest: {operation, qsos, segments?, compactFilenames?}
// ExportOption: {exportType, exportKey?, format, label, filename?, icon?, color?, refType?, ref?, priority?, selectedByDefault?}
// ExportRequest: {operation, qsos, segments?, events?, exportType?, exportKey?, compactFilenames?}  — full QSON, one coarse call
// ExportResult:  {filename, mimeType, content}
```

`qsos` holds contacts alone. The log's event rows — `break`, `start`, notes —
come separately in `events`, for a file that writes the timeline (the full
ADIF does, with private data); `segments` is what they resolve to.
`operation` carries `startAtMillisMin`/`startAtMillisMax`: the span of the
contacts in `qsos`, not of the whole operation.

Two-step flow: the Exports Panel calls `suggestExportOptions` on every
`export` hook to build its selectable list (a hook that omits it never
appears in the panel), then calls `generateExport` — passing back the
chosen option's `exportType` and `exportKey` — only for the options the user
selected. The core owns file I/O and save/share; the hook only produces content.

`exportType` is the stable kind (for example `potaActivation-adif`); `exportKey`
identifies an individual option within the hook (for example
`pota-adif:US-1234`). Options sharing a type must have distinct keys. Omit
`exportKey` for a single option of a type: selection and generation default
it to `exportType`. Both values round-trip unchanged when an explicit key is
provided; the core does not interpret them. Selection also includes the
hook key and station callsign, keeping different hooks and stations independent.

Exporters should compose per-QSO program fields from `adifFields` hooks (see
below) rather than knowing about specific activities. Implemented by the whole-log `adif` exporter, activity exports, and contest
ADIF/Cabrillo exporters.

**Registering types and settings.** `getExportTypes` runs without an operation,
so Settings can list types even before the operator has a matching log:

```ts
async getExportTypes() {
  return [{
    exportType: 'potaActivation-adif',
    activationType: 'potaActivation',
    format: 'adif',
    label: 'POTA',
    defaults: { includePrivateData: false, includeLookupData: true },
  }]
}
```

Prefer `<activationType>-<format>` to an extension-key namespace. Two
extensions offering that type share one settings entry. The highest-priority
registration supplies its definition; other exporters using it must honor
that contract. Distinct sponsor requirements can use a distinct type. The
SDK's `exportTypeDefinition(activationType, format, label, defaults?)` builds
the conventional definition; the activity and hunting helpers register their
own types. An exporter without `getExportTypes` still works, but does not
appear in the export settings list.

`ExportSettings` contains `includePrivateData`, `includeLookupData`,
`customTemplates`, `filenameTemplate`, `compactFilenameTemplate`,
`titleTemplate`, `adifNotesTemplate`, `adifCommentTemplate`, and
`adifQslMessageTemplate`. All are optional. Defaults resolve from the SDK,
then global preferences, then the type's declared defaults.
`GlobalExportSettings` adds `referenceFilenameTemplate`,
`referenceCompactFilenameTemplate`, `referenceTitleTemplate` and the matching
`other…` fields. A type with `templateCategory: 'reference'` uses the reference
set; other types use the other set. The activity export helper registers
reference types automatically. ADIF field templates remain common to both sets.
Saved common filename/title defaults remain fallbacks for categories without
an explicit setting. Per-type data
choices override those; per-type template overrides apply only when
`customTemplates` is on. Empty templates intentionally suppress text. Turning
custom templates off preserves the operator's edits for later. Non-ADIF
formats expose only the filename templates and their custom-template switch.

Type definitions may supply `templateSample: {operation, log}` for representative
editor examples. Each format supplies its own filename extension in the sample.

An option can supply `qsoCount` when its hook further filters the contacts
(for example, a hunter export). Otherwise the host derives the count from
activity and station scope. Filename and title templates use this count.

Options can carry `templateData: {ref, refName, activity, modifier, ...}`,
which populates the `log` namespace. The app renders filenames and titles
before showing the option, and passes the same `exportSettings`, `exportData`
and `exportTitle` to generation. It also passes the resolved
`includePrivateData` and `includeLookupData` for ADIF. Forward those fields
when delegating through `adifForExport`, or a program's preferences will not
reach the ADIF writer. Settings apply globally and per type, never per operation.
The whole-log ADIF defaults to including private data, but its type setting
can override that default.

**How a row looks.** `refType` names the activity the export covers — the
core slices the file's QSOs by it, and the panel takes the row's icon and
accent colour from that activity's own control, so a contest's file is
recognisably the contest's without saying anything about glyphs. `icon` and
`color` override that, and are how an export that claims no activity — the
whole-log ADIF — asks for a glyph of its own instead of borrowing one. An
`icon` name that doesn't resolve falls back to the activity's, same as an
unreadable `color` does.

**One reference's file.** An export claiming one reference of its `refType` —
one park's log, when the operation activated several — names it in `ref`, and
the core narrows the slice to the segments carrying that reference. Without
it, a park activated after a break gets every contact made at the park before
it. `activityExportHook` sets it for you.

**Filenames.** Build them with the SDK's `exportFilename` rather than
spelling one out, passing the request's `compactFilenames` straight through —
that is what makes the user's "Use compact file names" setting apply to your
export, and what keeps every extension's names consistent:

```ts
filename: exportFilename({
  stationCall: operation.stationCall,
  ref: 'US-1234',                            // or `activity: 'CQ-WW-CW'`, or neither
  startAtMillis: startMillisOf(operation, qsos),
  extension: 'adi',
  compact: args.compactFilenames,
})
// normal  → "2026-07-27 N0CALL at US-1234.adi"
// compact → "N0CALL@US-1234-20260727.adi"
```

Set `filename` on the OPTION, not just on the result: the panel shows the
option's name, and the core writes the file under it. A name computed again
in `generateExport` sees a different input — that call is handed only the
QSOs the option's `refType` (and `ref`) covers — so the two would otherwise disagree in
front of the user.

## ✅ `adifFields` — per-QSO export field contributions

How activities inject program fields into ADIF exports without the exporter
knowing them. Called by the `adif` extension **inside the runtime** via
`hooks.invokeAll` — no bridge crossing.

```ts
interface AdifFieldsHook {
  fieldsForOneQSO(args: { qso, operation, mainHandler? }, ctx): Promise<{name, value}[]>
  // One field set PER ADIF RECORD this contact should produce.
  fieldCombinationsForOneQSO?(args: { qso, operation, mainHandler? }, ctx): Promise<{name, value}[][]>
}
```

`mainHandler` is true when the file is this extension's own export — app-polo's
argument of the same name. It is how a program writes what only its own
submission asks for: SOTA's files carry both stations' gridsquares, which the
full export leaves to the contact's own privacy rules.

POTA contributes `SIG/SIG_INFO/POTA_REF` (hunted refs on the QSO) and
`MY_SIG/MY_SIG_INFO/MY_POTA_REF` (activation refs on the operation).

`fieldCombinationsForOneQSO` exists because **one contact can owe several ADIF
records**: work a station standing in two parks and each park is submitted
separately, which is also why it counts twice toward an activation
(docs/design/activities.md §4). Return one field set per record; the exporter
writes that many, shifting each successive record's `QSO_DATE`/`TIME_ON` by a
second so otherwise-identical records aren't read as duplicates (app-polo's
`qsonToADIF.js:144` does the same).

Record count is the largest any hook asks for. A hook returning a single set
is describing the *contact*, so its fields go on every record; only a hook
returning several is describing individual records. Declaring both methods is
fine and expected — a hook that does is asked only for its combinations, so
its plain fields aren't written twice. Implemented by: `pota`.

Only a program's **own** export asks for combinations. The full ADIF export is
one record per contact — the copy the operator keeps, which a reimport or a
log processor must not read as several contacts — so it asks every hook for
`fieldsForOneQSO` alone, as app-polo's does. A splitting program answers that
method too, for the one record — POTA names its first hunted park in `SIG_INFO`
and every one in `POTA_REF`. A hook answering only combinations is left out of
the full export, and the kernel logs an error for it as it activates.

**Only the export's OWN hook is asked.** A file submitted to one program is
that program's log, so an export that delegates the ADIF build names itself as
`mainHandler` in the `ExportRequest` — app-polo's "main handler"
(`qsonToADIF`'s `handler`) — and the `adif` extension invokes that hook alone,
not the whole category. Activate a park that is also a lighthouse and each
file claims its own reference; ask every hook and both programs'
`MY_SIG`/`MY_SIG_INFO` pairs land in every record, leaving the receiving
program to guess which is its. The delegate cannot work out who called it, so
naming yourself is not optional.

The full ADIF export names no `mainHandler`, and every program the contact
belongs to contributes — polo's `includeOtherRefs`, which only its full export
sets. That is the export claiming no program: the complete copy the operator
keeps.

**The full export asks only the extensions a contact belongs to.** For each
reference on the contact's operation (the segment-effective one) and on the
contact itself, the kernel takes every extension holding the strongest claim
on it — the longest `ref:<type>/<code>` prefix that begins the reference's
code, or else the bare `ref:<type>` — and asks those extensions' hooks, and no
other's. A hunted reference on the contact counts as much as an activation on
the operation, so a chaser's log keeps its `SOTA_REF`s. A longer claim excludes
a shorter one: an old `{type: 'qp', ref: 'CA'}` reference belongs to the party
that claims `qp/ca`, not also to the extension claiming all of `qp`. Equal
claims are all asked, whatever their priority: WCA also registers
`ref:ecaActivation` to resolve a castle while ECA is off, and ECA's fields
must not depend on which of the two registered first. An installed extension the
contact has nothing to do with is never asked, so a hook that forgets to check
its own references costs nothing here; checking them is still how a hook
behaves correctly when named by a program's own export.

An extension that genuinely has something to say about every contact opts in
from its **manifest**, `"adifFieldsScope": "always"`, and is asked whatever the
contact carries. The field lives in the manifest, not on the hook, so the
packer can check it without running the bundle: a manifest listing
`adifFields` with neither a `ref:` type nor the opt-in is refused at packing
and at publishing, and the app's own build refuses it too. The kernel reads the
opt-in from the extension's definition, so spread the manifest into
`defineExtension`, and it logs an error at activation for an extension that
registers `adifFields` but answers for no reference and does not opt in.
`mainHandler` and `includeFieldsFrom` are unaffected: a named hook is asked
whatever the contact carries.

An export can also name a **list** of other hooks it accepts,
`includeFieldsFrom` — polo's all-or-nothing flag narrowed to what the program
itself says it reads. It is for what DESCRIBES a contact rather than claiming
it: POTA's exports list `satellites`, because a park worked through a bird is
still a park activation and POTA's uploader reads `PROP_MODE`/`SAT_NAME`. A
listed key that answers nothing is fine — the operator may have that extension
off — where a `mainHandler` that answers nothing is an error, since that file
would claim no reference at all.

**A field name is written once per record, and the first to carry a value
wins.** ADIF gives no meaning to a repeated field, so where two hooks answer
the same name — the full export asks every program on the contact, and a park
and a summit both answer `MY_SIG` — the later one is dropped. Hooks are asked
main handler first, then each `includeFieldsFrom` key in the order given, so
that order decides — whichever of the two methods each hook answered. The
contact's own fields come after every hook's: a program knows what its file
needs in a field better than the contact's generic answer does (the section a
Field Day station sent, a satellite's downlink band). The exception is what
identifies the contact — `CALL`, `QSO_DATE`, `TIME_ON`, `QSO_DATE_OFF`,
`TIME_OFF`, `BAND`, `FREQ`, `MODE`, `SUBMODE`, `STATION_CALLSIGN`,
`OPERATOR`: a hook answering one of those is dropped, since it would rewrite
every record it is asked about, the whole-log backup included. A program whose
uploader needs `OPERATOR` on every record asks for it on the export instead,
`ExportRequest.operatorFallback` (`operatorFallback` on `activityExportHook`'s
and `huntingExportHook`'s rules): the core writes `OPERATOR` only where it says
something `STATION_CALLSIGN` doesn't, and with `'base'` or `'station'` it
writes the contact's own operator on every record, falling back to the station
call's base call or the station call itself. This is a
deliberate divergence from app-polo, whose contact fields come first and whose
main handler's are appended unchecked, so a name both answer is written twice. The **full export**, which asks every
program on the contact, has no main handler to order by: hooks are asked in priority order,
so which of two programs keeps a shared `MY_SIG` there is not something either
of them chose.

Because the winner is picked per field name, **answer a pair whole or not at
all**: a hook offering `MY_SIG` without `MY_SIG_INFO` takes the name and leaves
the next hook's reference under it, which claims another program's park for
yours. `custom` is the one activity whose two halves are free text, and it
drops both when either is empty.

## ✅ `adifImport` — per-QSO reference recovery on import

The inverse of `adifFields`. The core's ADIF parser
(`packages/halo_core/lib/src/adif/`) maps **universal ADIF only** and produces
**no references at all** — `SIG`/`SIG_INFO`, `SOTA`, `IOTA`, `CONTEST_ID` and
every `*_REF` field mean nothing to it. This hook is the entire ref vocabulary
on import, not a refinement of a core guess. An import with no `adifImport`
hook registered yields ref-less QSOs.

```ts
interface AdifImportHook {
  refsForRecords(
    args: { records: { fields: Record<string, string> }[] },
    ctx: HookContext,
  ): Promise<({ refs?: Ref[] } | null)[]>
}
```

`fields` is the record's raw ADIF, names lowercased and values entity-decoded.

**Batched, unlike every other per-QSO hook.** `adifFields` is called by the
`adif` extension *inside the runtime*, so a call per QSO costs nothing there.
This one is driven from Dart (`app/lib/services/adif_import_service.dart`), so
each call is a bridge crossing — a ten-thousand-contact import is twenty
crossings, not ten thousand. Batch size is 500.

Return **one entry per record, positionally**; `null` for a record the hook has
nothing to say about. Never filter the empties out: the core matches results
back to records by index, and a shortened array would land one QSO's references
on another. A reply whose length doesn't match the batch is discarded whole for
that reason. Refs from different hooks accumulate (a park-to-park contact made
during a summit activation legitimately carries both), deduped by `type`+`ref`.

A returned ref may carry **`for: 'operation'`** to say it belongs on the
operation rather than the QSO — an activation. ADIF has no operation, so it
writes the activation onto every record, and a hook only ever sees one record;
tagging is how it says where the reference actually goes. The importer moves it
and **consumes the tag**, since once the reference sits on the operation its
position is the answer. Untagged means the QSO. Without this the only test
available to the importer is "every record carries it", which cannot tell an
activation from a short log where everyone hunted the same reference.
`activityAdifImport` tags the activation side for you.

Returning an object rather than a bare `Ref[]` leaves room for the other things
an importer may eventually owe a QSO — a contest serial out of `STX`/`SRX`,
an exchange — as an additive change.

Most reference programs write the same `SIG`/`SIG_INFO`/`MY_SIG`/`MY_SIG_INFO`
pair plus their own comma-separated `*_REF` list, so the SDK's
`activityAdifImport({sig, huntingType, activationType, refField, normalize})`
builds the whole hook.

**A reference the program's own pattern rejects is imported anyway**, as
written. By the time `normalize` runs, the file has already said whose the
reference is — the `*_REF` list field is program-specific, and `SIG_INFO` is
gated on `SIG` — so a pattern failure means *malformed*, not *foreign*.
`decorateRef` labels it invalid, which puts it in front of the operator to fix;
discarding it would lose the only text a correction could work from, and lose it
without a word. `normalize` still repairs what it can (POTA turns a dashless
`us1234` into `US-1234`); only its failures fall through as raw text. The same
rule governs `satellites`, which imports a bird it cannot resolve to a
transponder rather than dropping the QSO's satellite.

It reads **both** sources and merges them, deduped on the normalized value.
Neither subsumes the other: `*_REF` lists every reference but not every program
writes it (SOTA's own exports carry `SOTA_REF` and no `SIG` at all), while
other software writes the same reference only as `SIG`/`SIG_INFO`. The union is
safe *because* it dedupes — taking `SIG_INFO` in preference to the list would
import an n-fer as a one-fer, since `SIG_INFO` names only the primary
reference; taking both cannot, because the primary is already in the list. The
`SIG` value is still checked before `SIG_INFO` is claimed, or every program
would import every other program's references.

`referenceActivity()` returns a ready-built `adifImportHook` from the config it
already has, so an activity using that factory opts in with one `registerHook`
line. Implemented by every activity except two:

- **`satellites`** writes `SAT_NAME`/`BAND_RX` and no `SIG` at all, so it
  hand-writes its own. Its reference is a *transponder* while ADIF names only
  the bird, so the hook recovers the transponder where it can — narrowing by
  `BAND_RX` (the downlink) and the record's own `BAND`/`FREQ` (the uplink) —
  and otherwise imports the bare satellite the file named. It validates
  nothing: an unknown bird, a contradictory `BAND_RX` and a record with no band
  all import. The reference degrades cleanly, since `decorateRef` falls back to
  the whole string and the exporter writes `SAT_NAME` from the same segment.
- **`custom`** deliberately registers none. Its `SIG` is a program name the
  *operator* typed, so there is no constant to match, and a hook claiming every
  `SIG` would add a spurious reference to every other program's records.
  "Claim the `SIG`s nobody else claimed" is the rule that works and it is not
  expressible in a hook — these run independently and additively, so none can
  see what the others took. It belongs to the importer.
