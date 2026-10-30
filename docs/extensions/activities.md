# Activities

An activity is a program the operator takes part in: parks, summits, lakes,
lighthouses, a contest. It gives the app **references** (a park's code, a
contest's name), the controls to enter them, the setup for an operation
that runs it, suggestions of what is nearby, and the data behind all of
that. Three categories carry it: `activity` for the controls and
suggestions, `ref:<type>` for what one kind of reference means, and
`dataFile` for an offline list. Most award programs need almost none of it
written by hand: the `referenceActivity` factory builds the lot from one
description. [How hooks work](hooks.md) covers registration, keys, priority
and `ctx`.

## The `referenceActivity` factory

The shape of POTA, SOTA, WWFF and a dozen others, in one call:

```ts
import { defineExtension, referenceActivity } from "@ham2k/extension-sdk"

const lakes = referenceActivity({
  key: manifest.key,
  label: "LLOTA",
  activationType: "w7abcLakeActivation",
  huntingType: "w7abcLake",
  referenceRegex: /^[A-Z]{2}-\d{4,5}$/,
  icon: "waves",
  color: "#2F7FA6",
  category: "w7abc-lakes",                       // the dataFile category the list fills
  tFor: (ctx) => createTranslator(resources, ctx.locale ?? "en"),
  adifProgram: "LLOTA",
  adifRefField: "LLOTA_REF",
  allowsMultiple: true,
  linkUrl: (ref) => `https://llota.app/lakes/${ref}`,
  activationRadius: { activationRadiusInMeters: 500 },
})

defineExtension({
  ...manifest,
  onActivation({ registerHook }) {
    registerHook("activity", { hook: lakes.activityHook })
    registerHook("ref:w7abcLake", { hook: lakes.refHandler })
    registerHook("ref:w7abcLakeActivation", { hook: lakes.refHandler })
    registerHook("adifFields", { hook: lakes.adifFieldsHook })
    registerHook("adifImport", { hook: lakes.adifImportHook })
    registerHook("dataFile", { hook: lakeList })
  },
})
```

| Field | |
| --- | --- |
| `key` | Your extension key. It prefixes the control keys (`w7abc-lakes/activation`); two extensions keying controls under one prefix share a serial counter. The scope words in the activity search come from the reference types and the extension key itself |
| `label` | The short program name on the control and in ADIF's `MY_SIG` |
| `activationType` | The reference type an operation carries while activating |
| `huntingType` | The type a contact carries for a reference the other station was at. Omit it for an award that recognises only activations; with it the logging panel gains a per-QSO control and exports carry `SIG`/`SIG_INFO` |
| `splitRecordsPerHuntedRef` | Whether a contact hunting several references is submitted as one ADIF record per reference |
| `referenceRegex` | What a code looks like; a value that fails it is flagged, never refused |
| `icon`, `color` | The control's glyph and accent |
| `placeholder` | The field's hint |
| `category` | The `dataFile` category whose rows are the program's list |
| `tFor` | `(ctx) => t`, a translator for the program's own strings |
| `adifProgram`, `adifRefField` | What the program's `SIG` is and which `*_REF` field it writes |
| `allowsMultiple` | Whether an operation may activate several at once |
| `linkUrl` | A reference's page on the web, built from its code |
| `transforms` | Live reformatting passes for the field, `{ pattern, replacement, flags? }` |
| `refInput` | Per-operation extras for the field: a placeholder or transforms that depend on where the operator is |
| `activationRadius` | How far from the point an activator may be, as a value or a function of the list row |

`referenceRegex`, `key`, `label`, `activationType` and `tFor` are required;
`category` defaults to the extension key, `adifProgram` to `label`,
`allowsMultiple` to false. The translator `tFor` returns must answer four
keys the factory uses for its own labels: `activationControl`,
`huntingControl`, `unknownReference` and `invalidReference`; an entry left
out shows as the raw key.

It returns `refHandler`, `activityHook`, `adifFieldsHook` and
`adifImportHook`, which you register as above. Pair it with
`activityScorer` for the program's activation rules
([Scoring & chasing](scoring.md#scoring-an-activity)) and
`activityExportHook` or `huntingExportHook` for its log files
([Import & export](import-export.md#export)). `k2hrc-llota` in the SDK's
samples is the whole shape in one file; `ham2k-wwbota` and `ham2k-pota` in
[ham2k/extensions](https://github.com/ham2k/extensions) are published
programs built on it. The rest of this page is what the factory does for
you, for when you need to go past it.

## `activity`

**For:** the controls an activity adds to the logging panel and to an
operation's setup, the suggestions it offers, and a last look at a contact
before it is saved.

**Called:** every registered hook, in one round trip, for the controls and
for suggestions; `processQsoBeforeSave` on every save path.

```ts
interface ActivityHook {
  loggingControls?(args: { operation, qso? }, ctx): Promise<LoggingControlDescriptor[]>
  operationControls?(args: { operation, qso? }, ctx): Promise<LoggingControlDescriptor[]>
  suggest?(args: SuggestArgs, ctx): Promise<ActivitySuggestion[]>
  processQsoBeforeSave?(args: { qso, operation }, ctx): Promise<Patch | null>
}
// LoggingControlDescriptor: { key, label, shortLabel?, skipFocus?, icon?, color?, order?,
//                             allowsMultiple?, editable?, input }
// SuggestArgs:              { operation, location?: { lat, lon }, callsign?, searchTerm?, scoped?,
//                             bounds?: { south, west, north, east } }
// ActivitySuggestion:       Ref & { distance?, relevance?, allowsMultiple? }
```

### Controls

`loggingControls` appear on the logging panel, for what each contact
carries; `operationControls` appear in the operation's Activities dialog,
for what the operation is doing ("which park am I activating"). `qso` is the
draft contact, with `their.guess` from the lookup, supplied again when a
lookup resolves, so a label or a suggested value can follow who is being
worked.

A descriptor names the control and says what it edits through `input`, one
of a closed catalog. A new kind is earned by a different widget, never by
different validation:

| `input.kind` | Edits | Also takes | Where |
| --- | --- | --- | --- |
| `refList` | a list of references of `refType` | `placeholder`, `pattern`, `transforms`, `numbersRowKey` | both |
| `text` | one `field` on the ref of `refType` | `placeholder`, `pattern`, `transforms`, `numeric`, `uppercase` (default true), `numbersRowKey`, `maxLength`, `suggestedValue` | logging panel |
| `options` | one `field`, from a known set | `options: [{ code, name? }]`, `matchOn`, `allowFreeform`, `preferredCodes`, `minCharsForSuggestions`, and everything `text` takes | logging panel |
| `serial` | a serial number the app allocates | `sequence: { key, scope?, start?, padTo? }`, `editable` | logging panel |
| `form` | a whole form over the ref | `form` | operation setup |

- `pattern` is anchored and matched case-insensitively; a malformed regex
  disables validation rather than throwing. A mismatch **tints the field but
  accepts the value**: a reference that fails it reaches the log and the
  exports as typed, because the pattern is the app's idea of the program,
  and may never cost the operator a reference.
- `numbersRowKey` is the one character the mobile numbers row offers after
  its digits while the field has focus. A `refList` offers `-` without it,
  the other kinds the operator's decimal separator.
- `text`, `options` and `serial` values round-trip onto a ref of `refType`
  under `field`; several may share one `refType` and merge into one ref.
  They render as primary fields, shown only while the operation runs that
  activity. `suggestedValue` fills the field only while the operator has
  not typed into it.
- An `options` field searches its set, shows a ranked suggestion line in
  the info area, and Space accepts the top hit before advancing, but only a
  hit the typed text is a prefix of, and never from an empty field. A value
  outside the set tints the field unless `allowFreeform`.
- A `serial`'s number is allocated by the app when the contact commits. Two
  extensions keying controls under one prefix share a counter.
- `shortLabel` is the same name in fewer characters, for a row that has
  squeezed the field below its label's width; the app measures and picks.
  `skipFocus: true` takes a field out of the Space and Tab cycle; the arrow
  keys still reach it. Every shipped contest sets it on *Our Serial*.
- `icon` is a Material Design Icons name or a FontAwesome `fa-` name;
  `color` an `#RRGGBB` accent the app uses sparingly: behind the icon in the
  Activities picker, on the reference's chip, on a spot row carrying a
  reference of this type.
- `editable` says whether a reference of this type has anything to edit once
  it is on the operation. Default false: a plain reference carries only the
  code its own `suggest` resolved, so the row stays inert and the operator
  removes it and picks again. Set it for a type whose references carry more
  than the code.
- `allowsMultiple` says whether an operation may carry more than one
  reference of the type at once. Default false: picking one **replaces** the
  operation's existing reference of that type. Declare it on the suggestion
  and on the descriptor; the app reads the suggestion's first. Picking a
  reference the operation already has flashes the existing row rather than
  adding it twice.
- `optionType` (`optional` or `mandatory`) is in the descriptor's type and
  set by the factory, and the app does not read it yet.
- **A `form` control prompts on add.** Tapping one of its suggestions saves
  the reference and then opens the form over it, because a contest that has
  not been set up cannot score. Cancelling leaves the activity added and
  unconfigured. So the suggestion must carry its own `label`, `shortLabel`
  and `program`, since the cancel path never reaches `decorateRef`; and
  `decorateRef` runs on whatever the form submits, merged with the
  suggestion's fields, so it must tolerate a reference it has already
  decorated once. A `refList` control does not prompt.

### Suggestions

`suggest` powers the Activities view's search and its nearby list. The app
resolves `location` and `callsign` from the operation if set, else from the
station defaults.

- **With no `searchTerm`**, answer what is nearby, with a `distance` from
  the given `location`. When the operator pans the results map the app asks
  again with the view as `bounds` and its centre as `location`: answer with
  **every** reference inside the view, not the nearest few, or the corners
  stay empty however far they pan. `nearbyLookupRows` from the SDK reads
  either case for you, through `host.dbLookupSelectInBounds` for a view
  (only an app that sends `bounds` answers that call).
- **With a `searchTerm`**, match codes and names. Answer `[]` for whichever
  case you do not serve.
- **`scoped: true`** says your own list was asked for: the operator tapped
  your row under *Activity Types* or typed one of your scope words.
  An extension that keeps itself out of the nearby list (an event offered
  only around a session) answers a scoped call anyway.
- **Rank** with `relevance`. The app orders results in two bands: everything
  with a `distance` first, by `distance / relevance` ascending, so a more
  relevant hit counts as nearer; then everything without one by descending
  `relevance`, ties in the order you emitted them. `relevance` alone orders
  placeless suggestions among themselves and never lifts one above a located
  reference. Measure `distance` from the `location` you were given; the app
  re-measures a panned answer from the operation's own place before any card
  shows it.
- **A scoped search offers the reference the operator typed, listed or
  not.** Programs built on the factory answer a scoped search with the typed
  code itself when no row matched it, named `unknownReference` where it fits
  the pattern and `invalidReference` where it does not, because the search
  is the only way onto the operation and a program whose list is stale would
  otherwise answer a reference handed to the operator on the air with "no
  results". Only a code-shaped term: a single word is how a park is looked
  up by name.

**Scope words.** Typing `pota:` or tapping a row under *Activity Types* asks
only the extensions serving that type. An extension answers to two kinds of
word: each reference type its manifest declares as a plain `ref:<type>`, by
the type's base name lowercased (`ref:potaActivation` and `ref:pota` are both
`pota:`, and two running extensions declaring one type share the word), and
its own key (`ham2k-pota:` asks that extension alone). A qualified claim
(`ref:qp/ny`) makes no word. The scoped call reaches you under the key you
registered the `activity` hook with, which is your manifest key; the app
reads which extension supplied a control from the fan-out that returned it,
never from the control's own key.

What arrives: `pota:` alone is a scoped call with no `searchTerm` (your own
list, which is how it differs from the nearby call, since neither carries a
term). `pota: bear mtn` is a scoped call with `searchTerm: "bear mtn"`. The
same word **without** its colon gives precedence instead of scoping: `pota`
on its own asks the extensions serving the type for their own list (scoped,
no term) and every other extension to search for the text `pota`; `pota
bear mtn` asks the type's extensions for `bear mtn` and every other one for
the whole text, in two round trips kept apart so a fan-out that runs out of
time cannot cost the named type its answers. A switched-off or
not-yet-installed extension is offered from the same words.

### `processQsoBeforeSave`

The last chance to shape a contact before it is written: for projecting data
you own into the generic fields the rest of the app reads. A contest keeps
its exchange on its own ref, which nothing generic reads; mirroring it into
`their.exchange` fills the QSO row's exchange column and a plain ADIF export.
A contest whose sent exchange changes per contact (a serial) mirrors that
into `our.exchange` too, and the column shows it ahead of theirs; keep it to
the part that varies, since it repeats on every row.

Return a **patch**, not a mutated QSO: it merges shallowly except `our` and
`their`, which merge one level deep, so `{ their: { exchange: "ZN5" } }` sets
that field and leaves the callsign alone. `refs` in a patch merge field-wise
into the QSO's ref of each type **you own**, appended when the QSO has none
yet. A type is yours when you alone register a bare `ref:<type>` for it and
your manifest declares that hook; it is matched by the ref **type**, which
for a catalog contest is not its key (`ham2k-cqww` writes `cqww`). A type two
extensions answer for belongs to neither, and a qualified claim owns nothing.
Entries of other types are ignored, no ref is ever removed, and `uuid` is
never patchable. Return `null` to do nothing.

Called on every save path (one QSO, a call list, a call stack, an edit),
skipped entirely when the operation has no refs, so ordinary logging pays
nothing. A serial the app allocates at commit is not visible here for the
second and later contacts of a call list.

## `ref:<type>`

**For:** what one kind of reference means: whether a code is valid, what it
is called and where it is, where to read about it, what shape it has on a
map, and what an operation at it should be titled.

**Called:** one handler per type, the one `registerHook("ref:<type>")`
registered, or, for a reference whose code a qualified claim covers, the
one `registerHook("ref:<type>/<prefix>")` registered (below).

```ts
interface RefHandlerHook {
  validateRef?(args: { ref: Ref }, ctx): Promise<{ valid: boolean; normalized?: string }>
  decorateRef?(args: { ref: Ref }, ctx): Promise<Ref>                               // may use the network
  suggestOperationTitle?(args: { ref: Ref; operation }, ctx): Promise<TitleSuggestion | null>
  linkForRef?(args: { ref: Ref }, ctx): Promise<RefLink | null>                      // { url, label? }
  geojsonUrlForRef?(args: { ref: Ref }, ctx): Promise<RefGeojson | null>             // { url, maxAgeInDays?, missMaxAgeInDays?, sourceName? }
}
// Ref: { type, ref?, name?, label?, shortLabel?, grid?, lat?, lon?, location?, program?, state?,
//        activationRadiusInMeters?, activationRadiusInFeet?, largeArea?, assistance?, selfSpotting?, … }
// TitleSuggestion: { title?, for?, at?, subtitle?, priority? }
```

**The app asks in batches.** Every reference an ADIF import or a deep link
brings is decorated in one round trip, and so is every link a list of
results needs, every outline a map draws, every phrase of a title. Each
reference is still its own call to your single-reference method. The time
budget belongs to the batch: **ten seconds** for all of it. A handler that
has not answered by then costs only its own reference, which stays as it
was; a `decorateRef` that goes to the network should answer well within
that.

- **`decorateRef`** fills in the name, location and labels. Results update
  the reference's chip asynchronously.
- **`linkForRef`** says where the reference can be read about: the program's
  own page for it, or for a contest the rules it runs under. The Operation
  Setup sheet asks for one link per reference whenever the operation's
  references change, and shows a web button on the row. Build the URL from
  the reference and return; **never use the network**. Return `null` for a
  reference the program would not accept, and implement nothing for a
  program with no page per reference, since a link into a search form is
  worse than no button. Nothing is stored on the ref, so a program that
  moves its URLs takes effect with the extension. `label` names the
  destination for assistive technology only where it is not the row's own
  subject, as a contest's rules are; a handler answering for another
  program's type leaves it off.
- **`geojsonUrlForRef`** says where the reference's footprint is published
  as GeoJSON: a summit's activation zone, a park's boundary. Same contract:
  build the URL, never fetch, `null` for a reference with no shape. The app
  fetches and caches; you name only the two ages: `maxAgeInDays` (default
  30) for how long a fetched shape stays usable offline, `missMaxAgeInDays`
  (default 1) for how long the app remembers that a reference has no shape,
  shorter so a newly surveyed zone appears within a day; either is ignored
  unless positive. `sourceName` is who drew the shapes, for the credit line
  under the map, the URL's host when left out; name the data's owner, not
  the server relaying it. The URL must be https and the app follows no
  redirects. A document past 16 MB is remembered as a miss. `Polygon` and
  `MultiPolygon` are drawn filled with an edge, `LineString` and
  `MultiLineString` as an edge alone, points are ignored. Shapes are asked
  for sparingly: the Map tab asks about the operation's own references, the
  Activities results map about those plus the one suggestion whose card is
  open, and the rest of its suggestions only once zoomed in.
- **`suggestOperationTitle`** contributes a fragment of the operation's
  title: `title`, `for` ("for Field Day") or `at` ("at Yosemite NP"). The
  app groups the fragments by kind and joins them with localized
  connectives, so return proper nouns, never the prose around them. Only for
  the type that means "this operation is happening at or for this
  reference", an activation and not a hunted reference. `priority` breaks
  ties within a kind; the default is 0.

**A reference's shape on the map.** A reference carrying
`activationRadiusInMeters` or `activationRadiusInFeet` is circled on both
maps around its `lat`/`lon`, never around a `grid`. Set it on the reference
itself, from `suggest` and `decorateRef`, since some programs vary it by
region or by kind; meters win when both are set. A reference with an outline
and a radius draws both. A reference whose point is representative rather
than where an activator stands (a park across several states) carries
**`largeArea: true`**, and never places an operation that has no location
of its own; the maps draw it and the nearby search finds it as before. A
reference inside exactly one state names it in `state`, and places the
station there for lookups.

### What a reference forbids

A ref states what its rules forbid. `assistance: false` on an operation's
ref, a contest's non-assisted category, turns assistance off for the whole
operation: no spot source is asked, every lookup runs offline. `selfSpotting:
false` turns self-spotting off. The Operation Details switches show off,
locked, naming the extension's short name as the rules complied with. Absent
means the ref has no say.

### Claiming another type's references

A reference type that once held many events in one extension and became
one extension per event leaves old logs carrying references nothing answers
for. The new extension claims them without rewriting anything, and the
claim is stated three times, once where each layer can read it:

| Layer | Where | Decides |
| --- | --- | --- |
| Manifest | `"hooks": ["ref:qp/ny"]` | which extension is **offered** for an unhandled reference |
| Control | `input.alsoHandles: ["qp/ny"]` | which control **answers** for it once the extension is on |
| Runtime | `registerHook("ref:qp/ny")` | which handler a `ref:qp` call is **routed** to |

The code is matched as a lower-cased prefix and the longest match wins. A
control's form reads from, and writes back onto, whichever reference it
matched, keeping that reference's own `type` and `ref`. A claim no control
declares in `alsoHandles` is refused by the build, and a control answering
for a claim the manifest does not make is never offered for it. Registering
a handler for a type you do **not** declare in the manifest is how a
decorate-only handler is written: it answers for the type without offering
itself for it.

## `dataFile`

**For:** a large offline dataset (a park list, a summit list) the app
downloads, caches, indexes and refreshes on a schedule. You supply the URL
and a row-to-entry mapper; the rows come back through the
`host.dbLookup*` calls ([The host API](host.md#reference-data)), which is
where `suggest` and the grid-resolving lookups get their answers.

```ts
const lakeList: DataFileDefinition = {
  key: "w7abc-lakes-all",
  name: "All lakes",
  description: "The LLOTA lake list",
  url: "https://llota.app/lakes.csv",
  maxAgeInDays: 7,
  fetchType: "csv",
  category: "w7abc-lakes",
  csvOptions: { hasHeaders: true },
  csvToLookupEntry: (row) =>
    row.Code ? { key: row.Code, name: row.Name, lat: Number(row.Lat), lon: Number(row.Lon), data: { region: row.Region } } : null,
}
```

| Field | |
| --- | --- |
| `key`, `name`, `description` | Identity; `name` and `description` are `Localizable` |
| `url` | Where to fetch; `Localizable` too. `n1mm-history:<stem>` is a special form, below |
| `maxAgeInDays` | How often to refresh |
| `fetchType` | `csv`, `json` or `raw` |
| `category` | The lookup category the rows land in |
| `csvOptions` | `{ hasHeaders?, skipRows?, delimiter? }` |
| `csvToLookupEntry(row)` | One row to one `LookupEntry` (`{ key, name?, lat?, lon?, flags?, data?, subCategory? }`), or `null` to skip it |
| `jsonOptions`, `jsonToLookupEntry(entry)` | The same for a JSON array |
| `rawToJSONData({ body, url, options })`, `onLoadRawData(data)`, `onRemoveRawData()` | For a `raw` file: parse it yourself; the parsed JSON is cached and replayed through `onLoadRawData` at every start |

**How CSV rows reach your mapper.** You write a per-row mapper; the app
sends rows positionally with the header row once per chunk, and the SDK
zips them back into the `Record<string, string>` your mapper takes. A file
with `hasHeaders: false` hands the mapper the positional `string[]` instead.
A short row leaves its trailing keys **absent**, so `!row.Code` works as the
emptiness test. The zipped row has a null prototype: column names come from
a third-party file and must never reach `Object.prototype`. A definition
that supplies `mapCsvBatch` itself bypasses the zipping and receives the raw
`{ rows, headers? }`. Set `flags: 0` on a reference the program has retired;
`activeOnly` reads skip it.

**N1MM call history files** are uploaded to N1MM's site under a new name
with every update and downloaded by a form, so no URL points at the current
one. A `url` of `n1mm-history:<stem>` asks the app to find it (extension
API 11): the newest file whose name is the stem, or the stem followed by `-`
or `_` (`CWOPS` takes `CWOPS_4002.txt` and `CWOPS_4000-CCC.txt`, never
`CWOPSOPEN_2026-002.txt`; name the variant to follow one). The file's name,
publish date and page stand in for an ETag, so a re-upload under the same
name still counts as new, a refresh whose newest file is the one last
downloaded stops after the search, and a forced refresh downloads it
regardless. It arrives in N1MM's format, a `!!Order!!,…` column line, `#`
comments, then CSV rows; `fetchType: 'raw'` fits, and `rawToJSONData` parses
it, with the `n1mm-history:` string as its `url`. A stem nothing matches, a
refused download, or a page that no longer has the shape the app reads
fails the download; the operator sees a notice on a refresh they asked for,
and a background pass fails quietly.

The operator can force a refresh from the Data Files screen or by typing
`RELOAD <program>` in the call field, which bypasses the cache.
