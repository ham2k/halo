# Activity hooks

The [hook reference](hooks.md) says how hooks are registered and invoked, and what every hook is handed.

## ✅ `activity` — declarative UI contributions

The UI-catalog seam (DESIGN.md §5): activities describe controls as data;
the core renders them with native widgets and calls back into ref handlers
for behavior.

```ts
interface ActivityHook {
  // `qso` is the in-progress QSO, including `their.guess` from the callsign
  // lookup — re-supplied when a lookup resolves, so a control can key a
  // dynamic label/placeholder/suggestedValue off who's being worked.
  loggingControls?(args: { operation, qso? }, ctx): Promise<LoggingControlDescriptor[]>
  operationControls?(args: { operation, qso? }, ctx): Promise<LoggingControlDescriptor[]>
  suggest?(args: SuggestArgs, ctx): Promise<ActivitySuggestion[]>
  processQsoBeforeSave?(args: { qso, operation }, ctx): Promise<Patch | null>
}
// LoggingControlDescriptor: {key, label, shortLabel?, skipFocus?, icon?, color?,
//   order?, optionType?, allowsMultiple?, editable?, input}
// `shortLabel` is the same name in fewer characters, for a field the logging
// row has squeezed below its label's width. The core measures and picks; the
// extension only says what the short form is.
// `skipFocus: true` takes a main logging field out of the Space and Tab cycle;
// the arrow keys still reach it. Every shipped contest sets it on Our Serial.
// SuggestArgs: {operation, location?: {lat, lon}, callsign?, searchTerm?, scoped?, bounds?: {south, west, north, east}}
// ActivitySuggestion: Ref & {distance?, relevance?, allowsMultiple?}

// The input catalog. A new kind is earned by a different WIDGET, never by
// different validation — so a pattern-constrained field is `text` with a
// `pattern`, not a kind of its own (docs/design/contests.md §5.3).
//   {kind: 'refList', refType, placeholder?, pattern?, transforms?,
//                     numbersRowKey?}
//   {kind: 'text',    refType, field, placeholder?, pattern?, transforms?,
//                     numeric?, uppercase? /* default true */, numbersRowKey?,
//                     maxLength?, suggestedValue?}
//   {kind: 'options', refType, field, options: [{code, name?}], matchOn?,
//                     allowFreeform?, preferredCodes?, minCharsForSuggestions?,
//                     placeholder?, pattern?, transforms?, numeric?, uppercase?,
//                     numbersRowKey?, maxLength?, suggestedValue?}
//   {kind: 'serial',  refType, field, sequence: {key, scope?, start?, padTo?},
//                     editable?}
//   {kind: 'form',    refType, form}   // operationControls only
//
// `pattern` is anchored (`^(?:…)$`) and matched case-insensitively for every
// kind; a malformed regex disables validation rather than throwing. A
// mismatch tints the field but still accepts the value — a `refList` segment
// that fails it becomes a ref like any other, and reaches the log and the
// exports as typed. The pattern is HaLo's idea of the program rather than the
// program's own, so it may never cost the operator a reference.
//
// `numbersRowKey` is the one character the mobile numbers row offers after
// its digits while the field has focus, where the operator would otherwise
// switch keyboard layers for it. Without it a `refList` field offers `'-'`,
// which joins most programs' prefixes to their digits, and the other kinds
// the operator's decimal separator.
//
// `text`, `options` and `serial` values round-trip onto a ref of `refType` under
// `field`, through the same core-owned path refList writes refs — several may
// share one refType and are merged into a single ref. `suggestedValue` fills the
// field only while the operator hasn't typed into it. A `serial`'s number is
// allocated by the core (docs/design/contests.md §5.8), and all three kinds
// render as PRIMARY fields, shown only when the operation is running that
// activity.
//
// An `options` field searches a KNOWN SET: it shows a ranked suggestion line and
// Space accepts the top hit before advancing, and a value outside the set tints
// the field unless `allowFreeform`. Space accepts only a suggestion the typed
// text is a PREFIX of, and never from an empty field — a substring hit is worth
// showing, but swapping one in rewrites the operator's own text into something it
// isn't the start of. The suggestion line is added to the info area, above
// whatever it was already showing, so a DUPE stays visible while an exchange
// field has focus. The set is inline — §5.3's registered `optionSet` is deferred
// (nothing can write rows into the lookups table today).
// `text`, `serial` and `options` are logging-panel kinds: operation settings
// render `refList` and `form` and silently ignore the rest.
//
// `optionType` is NOT yet honored by the core.
```

`icon` is a Material Design Icons name (e.g. `'pine-tree'`), or a FontAwesome6
solid-style name prefixed with `'fa-'` (e.g. `'fa-tree'`) — same convention
app-polo itself uses. Any name in either set works with no core-repo change;
an unrecognized name falls back to a placeholder glyph rather than erroring.

`color` is an optional `'#RRGGBB'` accent (e.g. POTA's `'#068541'`) the core
may use sparingly to highlight this control's icon — a tinted circle behind
it in the Activities picker, the icon itself once a reference is entered
in the logging panel's secondary pills, or the reference icon on a spot row
whose ref is of this control's type. Missing or unrecognized values just
mean no accent.

`processQsoBeforeSave` is the last chance to shape a QSO before it is written,
for projecting data the extension owns into the generic QSON fields the rest of
the app reads. A contest keeps its exchange on its own ref (`theirZone`,
`theirSerial`, …), which nothing generic knows how to read — mirroring it into
`their.exchange` is what fills the QSO row's exchange column and a plain ADIF
export. A contest whose sent exchange changes per QSO (a serial) mirrors that
into `our.exchange` too, and the column shows it ahead of theirs, in the RST
cell's order — keep it to the part that varies, since it repeats on every row.
Return a PATCH, not a mutated QSO: it merges shallowly except `our` and
`their`, which merge one level deep, so `{their: {exchange: 'ZN5'}}` sets that
field and leaves the callsign alone. `refs` in a patch merge field-wise into
the QSO's ref of each type the extension OWNS (appended when the QSO has none
yet), so a contest can stamp the exchange it guessed as data of record — by
its ref TYPE, which for a catalog contest is not its key (`ham2k-cqww` writes
`cqww`). A type is the extension's when it alone registers a bare
`ref:<type>` hook for it and its manifest declares that hook in `hooks`.
Registering a handler is open to anyone, so a type two extensions answer for
belongs to neither, and a qualified `ref:<type>/<code>` claim owns nothing.
An entry of any other type is ignored, since refs are shared with the core
and with other activities, and no ref is ever removed. `uuid` is never
patchable. Return null to do
nothing. Called on every save path (single QSO, call list, call stack, edit),
and skipped entirely when the operation has no refs, so ordinary logging pays
no bridge crossing. A serial the CORE allocates at commit is NOT visible here
for the second and later calls of a call list (docs/design/contests.md §5.8).

`loggingControls` appear on the logging panel (per-QSO refs);
`operationControls` appear in the operation's Activities dialog (e.g. "which
park am I activating"). Catalog components are versioned core code —
proposing a new `input.kind` is a core PR, deliberately (DESIGN.md §5's
"catalog creep" risk). Implemented by: `pota`.

`suggest` powers the Activities view's "add activity" search: called with a
`location`/`callsign` the core resolves from the operation if set, else the
station defaults (extensions never need to know which). When the operator pans
the Activities results map it asks again with the map's view as `bounds` (and
its centre as `location`, no `searchTerm`, the box's scope if it has one):
answer with EVERY reference inside the view, not the nearest few, or the view's
corners stay empty however far the operator pans. `nearbyLookupRows` reads
either case, through the `dbLookupSelectInBounds` host call for a view — only
an app that sends `bounds` answers that call, so an extension that calls it
only then runs on older apps unchanged, and one that predates `bounds` answers
with what is nearest the view's centre. Measure `distance` from the `location`
given either way; the core re-measures a panned answer from the operation's own
place before any card shows it. For POTA only, the core also adds the parks
whose OUTLINE is near (from the grid bundles above) to the nearby list and to a
pan, labelled by POTA's own `decorateRef`, and gives a park POTA already
suggested the nearer of its point's and its outline's distance — so `pota`'s
`suggest` keeps answering by point, and a trail whose point is a state away
still reaches an operator standing on it. Called with no
`searchTerm` for nearby suggestions, or with one for name/code search — an
extension may honor either, both, or neither (returning `[]`). `scoped` is
true when THIS extension's own list was asked for — the operator tapped its
"Activity Types" row or typed one of its words, with or without the colon
(below) — which otherwise cannot be told from the nearby list, since neither
carries a `searchTerm`. Without the colon the other extensions are asked too,
for the word as text. An extension
that keeps itself out of the nearby list (`cwt`, offered only around a session)
answers a scoped call anyway: it is the one being asked. The core fans out to
every `activity` hook via `invokeHookAll`; a scoped search asks only its own
hooks, in one batch (`invokeHookBatch`); and a search naming a type without the
colon asks that type's hooks in one batch AND fans out to every hook — two
round-trips, kept apart so a fan-out that runs out of time cannot cost the named
type's answers. The core merges results and ranks them
in TWO BANDS (`app/lib/tools/activity_suggestions.dart`): everything carrying a
`distance` first, by `distance / relevance` ascending — a more relevant hit
counts as nearer — then everything without one, by DESCENDING `relevance`, with
ties broken on the order the extension emitted them. So `relevance` alone orders
a set of placeless suggestions (dated contest events, say) among themselves, but
never lifts one above a located park. Implemented by: `pota`, `sota`,
`stateparks`, `cwt`.

**A scoped search offers the reference the operator typed, listed or not.** The
reference programs (`pota`, `sota` and every one built on `referenceActivity`)
answer a scoped search with the typed code itself when no row matched it —
named `unknownReference` where it fits the program's pattern, `invalidReference`
where it does not. The search is the only way onto the operation, so a program
whose list is stale, or whose pattern this app has wrong, would otherwise answer
a reference the operator was handed on the air with "no results". The scope is
what keeps the MALFORMED half of that narrow: unscoped, every enabled program
would answer any text at all with an invented reference of its own, burying the
real matches. (A well-formed code needs no scope — POTA has always offered one,
since only that program's own pattern can accept it.) A search term that is not
code-shaped is left alone either way: a single word is how a park or summit gets
looked up BY NAME, and `pota: beersel` must not answer with an invented BEERSEL.
The row is marked, and the reference is stored, logged and exported as typed —
the same rule ADIF import follows for a malformed `*_REF` (below).

The activity search box also treats a leading scope word as a scope — typing
`pota:` (or tapping a row under "Activity Types") asks only the extensions
serving that reference type, via a key-scoped `invokeHook` rather than the
usual fan-out. An extension answers to two kinds of word:

- **Each reference type its manifest declares**, as a plain `ref:<type>` in
  `hooks`, by the type's base name lowercased — `ref:potaActivation` and
  `ref:pota` are both `pota:`. A user-published `ki2d-pota` declaring
  `ref:potaActivation` is scoped as `pota:` too, since the operator is adding
  POTA parks whichever extension supplies them: two running extensions
  declaring one type share the word, and the scoped search asks both. A
  qualified claim (`ref:qp/ny`) makes no word.
- **Its own extension key** — `ham2k-pota:` asks that extension alone, which
  is how an operator picks one supplier over another.

The same word without its colon gives precedence instead of scoping. `pota`
on its own asks the extensions serving the type for their own list (as a
scope, `scoped: true` with no `searchTerm`) and every other extension to
search for the text "pota", with the first answers leading. `pota bear mtn`
asks the extensions serving the type for "bear mtn" and every other one for
the whole text — a `suggest` matching codes and names against one string
finds nothing for the word it was named by.

The scoped call reaches the extension under the key it registered its
`activity` hook with, which has to be its manifest key. The search reads which
extension supplied a control from the fan-out that returned it, never from
the descriptor's `key`, so a catalog `ham2k-pota` keying its controls
`pota/activation` is reached as `ham2k-pota`. (A logging control's serial
counter is still namespaced by the `key`'s prefix: two extensions keying
controls under one prefix share a counter.) A
switched-off or not-yet-installed extension is offered from the same words:
typing a type it declares, or its key, puts its enable or install row under
the search.

`editable` declares whether a reference of this type has anything to edit
once it's on the operation. It defaults to **false**: a plain reference
activity carries only the code its own `suggest` already resolved, so the
Current Activities row stays inert — the user removes it and picks again
rather than retyping a code no lookup would re-check. `pota` and `sota` leave
it off. Set it true for a type whose references carry more than the code.

A **`kind: 'form'` control prompts on add.** Tapping one of its suggestions
saves the reference and then opens the setup form over it, because a contest
that has not been set up cannot score and nothing on its row says so. The
save comes first, so cancelling the form leaves the activity added and
unconfigured rather than undoing the tap. Two consequences for the hook:

- The suggestion still has to carry its own `label`/`shortLabel`/`program`
  (§5.4 of contests.md) — the cancel path never reaches `decorateRef`, so a
  suggestion that relies on being decorated reads as a blank row.
- `decorateRef` runs on whatever the form submits, immediately after. It is
  handed the suggestion's own fields merged with the form's, so it must
  tolerate being called with a reference it has already decorated once.

A `refList` control does **not** prompt: its suggestion already carries the
code that identifies it, so a form could only ask the user to retype what
they just picked.

`allowsMultiple` declares whether an operation may carry more than one
reference of that type at a time. It defaults to **false**: picking one of
the type's references **replaces** the operation's existing reference of
that type rather than adding alongside it. A type that genuinely stacks
declares `allowsMultiple: true` — `pota` does, for n-fers. Declare it on the
suggestion (for the search/nearby list) *and* on the type's
`LoggingControlDescriptor` (for references the user types in by hand); the
core reads the suggestion's value first and falls back to the control's.
Selecting a reference the operation already has is still a duplicate, not a
replacement — the core flashes the existing row instead of adding it twice.

## ✅ `ref:<type>` — reference handlers

One category **per ref type** (e.g. `ref:pota`, `ref:potaActivation`),
following app-polo's QSON conventions. Handles validation and enrichment of
activity references on QSOs and operations.

`registerHook` takes the type alone. The **qualified** `ref:<type>/<code>` form
is a manifest claim, not a category — it tells the host which legacy reference
an extension answers for so it can rewrite one (docs/extensions/README.md), and
registering a hook under it would register a category nothing ever invokes.

```ts
interface RefHandlerHook {
  validateRef?(args: { ref: Ref }, ctx): Promise<{valid: boolean; normalized?: string}>
  decorateRef?(args: { ref: Ref }, ctx): Promise<Ref>   // may hit the network
  suggestOperationTitle?(args: { ref: Ref; operation }, ctx): Promise<TitleSuggestion | null>
  linkForRef?(args: { ref: Ref }, ctx): Promise<RefLink | null>   // {url, label?}
  geojsonUrlForRef?(args: { ref: Ref }, ctx): Promise<RefGeojson | null>
}
// Ref: {type, ref?, name?, label?, shortLabel?, grid?, lat?, lon?, location?, program?,
//       activationRadiusInMeters?, activationRadiusInFeet?, largeArea?,
//       assistance?, selfSpotting?, ...}
// TitleSuggestion: {title?, for?, at?, subtitle?, priority?} — a fragment of
// the operation's title/subtitle sentence (ham2k/halo-dist#174). Only
// return one for the ref type that means "this operation is happening AT/FOR
// this reference" (e.g. an activation, not a hunted ref) — a hunting ref
// contributes nothing here. `priority` breaks ties when multiple refs supply
// the same fragment kind (higher wins); default 0.
```

`decorateRef` fills names/locations/labels (park names via the POTA API,
etc.); results update ref chips asynchronously in the UI. Implemented by:
`pota` (both types).

**A ref states what its rules forbid.** `assistance: false` on an operation's
ref — a contest's non-assisted category — turns assistance off for the whole
operation, and `selfSpotting: false` turns self-spotting off; the Operation
Details switches show off, locked, naming the extension's short name as the
rules complied with. Absent means the ref has no say. What the host then does
is in the `spots` and `lookup` sections; no other extension needs to check.

**The core asks about references in batches.** Every reference an ADIF import
or a deep link brings is decorated in one bridge round-trip, and so is every
link a list of search results needs, every outline a map draws, and every
phrase of an operation's title. Each reference is still its own call, to the
handler `invokeHook` would pick for it (qualified claims included), so a
handler implements the single-reference methods above and nothing else. The
time budget belongs to the batch, though: ten seconds for all of its calls
together. A handler that has not answered by then costs only its own
reference — it stays as it was, with no name, link or outline — and every
other reference keeps its answer. A `decorateRef` that goes to the network
should answer well within that.

`linkForRef` says where a reference can be read about on the web — the
program's own page for it (POTA's park page, SOTA's summit page), or, for a
contest, the rules the event is run under. The Operation Setup sheet asks for
one link per ref every time the operation's refs change and renders a web
button on the row; **nothing is stored on the ref**, so a program that moves
its URLs takes effect with the extension rather than needing saved operations
rewritten. Build the URL from the reference and return: this hook must not hit
the network. Return `null` for a reference the program would not accept (a
half-typed code links to a page that cannot exist) and implement nothing at all
for a program whose list is a download with no page per reference — a link into
a search form is worse than no link, and the row simply shows no button.
`label` names the destination for assistive technology, wrapped in the app's
own localized phrasing — set it only where the destination is NOT the row's own
subject, as a contest's rules are; leave it off for a reference's own page and
the app names the row instead. A handler registered for another program's ref
type (WCA answers for `ecaActivation`) must leave it off: a label built from
its own program name reads the wrong program aloud. Programs built on the SDK's `referenceActivity` factory get this
from one `linkUrl` config line.

`geojsonUrlForRef` says where the reference's own footprint can be fetched as
GeoJSON — a SOTA summit's activation zone, a POTA park's boundary, and
whatever equivalent another program publishes. Areas (`Polygon`,
`MultiPolygon`) are drawn filled with an edge; lines (`LineString`,
`MultiLineString`) — a trail or a river that is the park — are drawn as an
edge alone; points are ignored. Same contract as `linkForRef`: build the URL from the
reference, **never hit the network**, return `null` for a reference the program
has no shape for. The core does the fetching and the caching (`GeoshapeService`),
so an extension never decides how long a device keeps a file or how large one may
be; it only names the two ages the core should use:

```ts
// RefGeojson: {url, maxAgeInDays?, missMaxAgeInDays?, sourceName?}
```

`maxAgeInDays` (default 30) is how long a fetched shape stays usable offline —
boundaries move on the scale of surveys. `missMaxAgeInDays` (default 1) is how
long the core remembers that a reference has NO shape, deliberately shorter so a
newly surveyed zone appears within a day rather than a month. Both are ignored
unless positive: a zero would re-fetch on every rebuild of the map.

`sourceName` is who drew the shapes, short enough for the credit line a map
shows under its outlines ("Source: OSM, sotl.as") — the host of `url` when it
is left out. Name the data's owner, not the server that relays it: POTA's
outlines are served by Ham2K and credited to OSM.

A document past 16MB is not kept: the core remembers it as a miss, on
`missMaxAgeInDays`, rather than downloading it again on every retry.

The URL must be `https`, and the core does not follow redirects to reach it.
Unlike a link, this one is fetched rather than handed to the platform, and a
plaintext one — named outright, or arrived at through a `Location:` header —
would downgrade every activator's connection on a program's say-so.

Shapes are asked for sparingly: the Map tab asks about the operation's own
references, and the Activities pane's results map about those plus the one
suggestion whose card is open, drawn solid. The rest of the map's suggestions
are asked about only once it is zoomed in (from GL zoom 7, fading in by 8)
and drawn as a dashed edge under the solid ones — a search answers with dozens
of references, and further out a footprint is a few pixels across. Implemented by: `sota` (both types, via
SOTLAS's `az.sotl.as`, used with the operators' permission) and `pota` (both
types, via `services.ham2k.net/lookups/outlines/pota/`, which links parks to
OpenStreetMap shapes; a park not yet linked answers 404).

**POTA is the one exception, and the core makes it, not the hook.** For a
POTA suggestion's dashed outline the core skips `geojsonUrlForRef` and reads
`services.ham2k.net`'s grid bundles instead — every outlined park touching a
Maidenhead cell, simplified and clipped to it, one cached document per cell
(500 m blocks below GL zoom 9, 10 m squares from 9). A long trail's whole
outline runs to megabytes; its pieces in a cell, to kilobytes. The same
bundles add to `suggest`'s answers the parks whose outline, not just whose
point, is near: within 5 km for the nearby list, touching the view for a pan
close in (from about GL zoom 10; see `suggest` below). An open card's POTA suggestion is drawn solid from the
same pieces; the operation's own references still come from
`geojsonUrlForRef`.

**An activation radius is a circle, drawn the same way.** A reference that
carries `activationRadiusInMeters` or `activationRadiusInFeet` — how far from
its point the program lets an activator be — is circled on both maps, in the
same color and under the same rules as an outline: solid for the operation's
own references and the open card, dashed for the other suggestions once
zoomed in. It is set on the reference itself, by `suggest` and `decorateRef`,
because some programs set different distances by region or by kind of
reference; a suggestion is stored on the operation verbatim, so the Map tab
draws it too. Give whichever unit the rules are written in; meters win when
both are set. It is drawn only around `lat`/`lon`, never around a `grid`,
whose centre can sit further from the reference than the whole radius
(docs/design/locations.md). A reference with an outline AND a radius draws
both. A circle has no source, so it adds nothing to the map's outline credits
and is not offered for an outline report. Programs built on the SDK's
`referenceActivity` factory get this from one `activationRadius` config line —
a value, or a function of the list row for rules that vary.

**A reference too large to stand for one place says so.** An operation with
no location of its own takes the first of its references that has one
(docs/design/locations.md), which is right for a summit or a park a few
kilometres across and wrong for a 3,500 km trail. A reference whose point is
representative rather than where an activator stands — POTA's parks that span
several states — carries `largeArea: true`, and that reference never places
the operation. Nothing else reads it: the maps draw it, and the nearby search
finds it, exactly as before.

`suggestOperationTitle` lets an activity build a natural-language operation
title/subtitle from its refs — "at Yosemite NP" (POTA), "for Field Day"
(contest programs, when ported) — mirroring app-polo's
`buildOperationTitle`. The core (`OperationTitleService`) calls this once per
ref, groups the non-null results by fragment kind (`title`/`for`/`at`,
highest `priority` first within a kind), and joins them with a **localized**
"for"/"at" — unlike app-polo, which hardcodes those joiner words in English;
HaLo threads them through `strings.g.dart` instead, so extensions only ever
return proper nouns/names (locale-agnostic or self-translated via their own
`tFor`), never the connective prose. Implemented by: `pota`, `sota`
(activation ref types only).

## ✅ `dataFile` — offline reference datasets

Large offline datasets (park/summit lists) the core downloads, caches, and
refreshes on a schedule; the extension supplies the URL and a
row/entry→`LookupRow` transform. See `DataFileManager`
(`app/lib/services/data_file_manager.dart`). Implemented by: `pota`
(`pota-all-parks`), `sota` (`sota-all-summits`), and `call-notes`
(`fetchType: 'raw'` — the parsed Hams of Note index is cached as JSON and
replayed through `onLoadRawData` at startup, issue #17).

### N1MM call history files

N1MM Logger+'s call history files are uploaded to
[n1mmwp.hamdocs.com](https://n1mmwp.hamdocs.com/mmfiles/categories/callhistory/)
under a new name with every update (`CWOPS_4002.txt`), and downloaded by a
form POST that carries a nonce from the file's own page, so no URL points at
the current one. A `url` of `n1mm-history:<stem>` asks the host to find it
(extension API 11):

```ts
{ key: 'cwops-history', url: 'n1mm-history:CWOPS', fetchType: 'raw', maxAgeInDays: 7, /* … */ }
```

- **Which file:** the newest one, by publish date, whose name is the stem or
  the stem followed by `-` or `_` (extension and case aside). `CWOPS` takes
  `CWOPS_4002.txt` and `CWOPS_4000-CCC.txt`, never `CWOPSOPEN_2026-002.txt`,
  though N1MM's search lists all three; to follow one variant only, name it
  (`n1mm-history:CWOPS_4000-CCC`). The search is read newest first, page by
  page, until a page lists one of the stem's files.
- **When:** N1MM sends no ETag; the chosen file's name, publish date and page
  stand in for one, so a re-upload under the same name still counts as new. A
  refresh whose newest file is the one last downloaded stops after the search,
  like a 304. A forced refresh (RELOAD, Refresh) downloads it regardless.
- **What arrives:** the file as served, in N1MM's format — a `!!Order!!,…`
  column line, `#` comment lines, then CSV rows. `fetchType: 'raw'` is the one
  that fits; `rawToJSONData` parses it. `url` in its arguments is the
  `n1mm-history:` string, not the file's address.
- **Failures:** a stem nothing matches, a refused download, or a page that no
  longer has the shape the host reads fails the download with
  `N1mmCallHistoryUnavailable` — a notice on a refresh the operator asked for,
  an upload for the background passes. The requests and parsing are
  `halo_core`'s `n1mm_call_history.dart`, shared by the app and the CLI.

### How CSV rows reach `csvToLookupEntry`

An extension writes a **per-row** mapper; the kernel synthesizes the batch
method around it. What crosses the boundary is **not** what the mapper sees:
the host sends rows **positionally** plus the header row **once per chunk**,
and `registerHook` zips them back into the `Record<string, string>` the mapper
is declared to take. Building those maps host-side instead meant every column
name was repeated for every row — 61% of the bytes on SOTA's 181k-row file
(APP-16).

Consequences worth knowing:

- A file with `hasHeaders: false` sends no headers, and the mapper receives the
  positional `string[]` — the other half of the declared
  `string[] | Record<string, string>` signature.
- A short row leaves its trailing keys **absent**, not `undefined`-valued, so
  `!row.SummitCode` still works as the emptiness test.
- The zipped row has a **null prototype**: column names come from a
  third-party file and must never reach `Object.prototype`.
- An extension that defines `mapCsvBatch` **itself** bypasses all of the above
  and receives the raw `{ rows, headers? }` — it has to zip on its own. Nothing
  does this today, and `DataFileDefinition` doesn't declare the method, so the
  type checker will not remind you.
