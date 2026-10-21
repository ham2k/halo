# Locations: coordinates measure, grids display

A Maidenhead locator is a cell, not a point. Six characters is about 9 × 5 km
at mid latitudes; eight is about 700 × 460 m. Most of what the app knows a
location FROM — a GPS fix, a park's published position, a QRZ record — is a
real coordinate, and reducing it to a square on the way in cannot be undone
afterwards.

So: **wherever a location is captured, capture the coordinate.** The grid stays
what the operator reads.

## The shape

Alongside `grid`, wherever one is stored:

| Record | Keys |
| --- | --- |
| Operation | `data.lat`, `data.lon` (with `data.grid`, `data.gridSource`) |
| QSO, our side | `our.lat`, `our.lon` |
| QSO, their side | `their.lat`, `their.lon`, and `their.guess.lat`/`.lon` from a lookup |
| Activity ref / suggestion | `lat`, `lon` (SDK `Ref`, `extensions/sdk/src/types.ts`) |

Signed decimal degrees, always — never ADIF's `N041 22.500`, which
`parseAdifCoordinate` converts on the way in and `formatAdifCoordinate`
(extensions/core/adif) converts on the way out. "On the way in" includes
the QSON normalizer (`qson_values.dart`), not just the ADIF importer: a
peer that stored the ADIF form verbatim — app-polo's import does — sends it
over sync, and a normalizer that only knew numbers would drop the pair.

## The invariant

**Where a coordinate is present it is authoritative, and the grid is display
only.** Every reader resolves through `locationForQsoInfoWithSource`
(`exact:` outranks `grid:`), or through `Operation.location` / `Qso.ourLocation`
which do the same thing.

The other half is what keeps that honest: **a writer that states a grid must
replace `lat`/`lon` in the same write.** A stale coordinate outranks the grid
everywhere it is read, so leaving one behind silently discards what the
operator just entered. The writers that carry this today are
`OperationLocationScreen._save`, `locationFollowsRefs` (below),
and the QSO editor's grid field (`logging_controls.dart`) — which the More
pane's own Grid field reaches through, blanking its Latitude and Longitude
fields on the same edit. Those fields hold a coordinate the operator STATED,
and after a typed grid there is none: what gets stored is the square's own
center, which is the grid restated rather than a second claim.

The Logs view's editor (`views/logs/logs_edit_panel.dart`) is the fourth
writer. Its Grid field writes only when it was edited, since untouched it may
be showing a lookup's guess, and only a well-formed locator or an emptied
field: anything else changes nothing, rather than storing a square that names
no place and erasing the pair beside it.

What replaces it, where the writer has nothing better, is the square's own
center — `locationForStatedGrid`. It is a true statement (the station is
inside the square) and it says nothing the grid did not, so every reader that
MEASURES has a coordinate to measure from without re-deriving one, and no
reader has to special-case a record that carries a grid and no pair.

**That is a rule for a writer recording what the OPERATOR stated, and for
nobody else.** A lookup stores what its source actually reported: a
grid-only result files a grid and no coordinate at all (`mergeLookup.ts`).
Inventing the square's center there would put a coordinate nobody reported
into the slot that outranks everything else, and the readers need no help —
`locationForQsoInfoWithSource` falls through to the grid on its own. The
reverse still happens, because it invents nothing: a coordinate-only result
has its six-character square derived from the pair, so the guess can name a
grid without claiming one.

Which is why nothing reads that derived grid as the station's square. It is
six characters whatever Grid Precision says, so every surface resolves
through `gridForDisplay` instead — both Grid fields' hints (one
`guessGridDisplay`, so the logging row and the More pane cannot show
different squares for one station), the ADIF `GRIDSQUARE`, the call-info
line.

Two things that pair must never do. It must not survive a locator that names
no place: `locationForStatedGrid` returns null for a placeholder
(`isPlaceholderGrid` — `AA00`, `AA00AA`), which decodes like any other square
and would otherwise plant a station off Antarctica, outranking every coarser
source that could have answered honestly. And it must not lengthen the
locator on screen — see Display.

### Located by its references

An operation with no location of its own takes one from its references, so
the nearby search and the maps work without the operator setting one by hand.
`locationFollowsRefs` (halo_core) decides it, on every local write that
changes the refs: `OperationsRepository.saveData` runs it, so no writer of
refs can skip it. A sync or peer merge never runs it — the device that changed
the refs did.

- The first ref with a location places it: the ref's own coordinate where its
  program publishes one, its square's center otherwise, with
  `gridSource: 'refs'` — app-polo's value, which it follows the same way.
  The grid stored beside it is six characters whatever Grid Precision says
  (`refGrid`): a park's published point says where the park is, not where in
  it the station stands, and eight characters would claim the second. See
  Display for how it is shown.
- Picking the FIRST placeable ref on the Location screen stores the same
  location the refs would: a `refs` location that follows them. Picking any
  other stores it as `manual`, still its six characters — the refs always
  follow the first, so as `refs` that pick would be moved back at their next
  edit. A `largeArea` ref is not offered there.
- A ref marked `largeArea` (SDK `Ref.largeArea`) never places anything. A
  long trail or a park across several states publishes one point for the
  whole of it, and the operator could be hundreds of kilometres from it.
  app-polo makes the same call by withholding the grid from POTA's
  multi-state parks; here the ref keeps its point, so the maps still draw it.
  A ref without the flag is placeable.
- A `refs` location keeps following: replacing the park moves it, and
  removing the last ref that could place it clears all four keys at once.
  Adding a second park leaves it where the first one put it. Any other
  source — the operator, a GPS adoption — is never overridden, and neither is
  a location stated in the same write as the refs.

**The device's position plays no part.** A park picked while the operator
stands in it is better placed by the fix, and the Location screen offers that
fix in one tap — but read here, the answer would depend on when the write
runs: the Activities view's draft and the save that commits it would see
different fixes, or one and none, and the service keeps its last position
after it stops, so a fix can be hours old. app-polo makes the same call.

The setup sheet captures a fix in its own right instead, as a separate write
rather than part of this rule. While it is open — it starts the location
service, and starting puts a stopped stream back to `determining` until a new
position arrives, so `available` there is a live fix — it stores the device's
position as `gridSource: 'gps'` on an operation being set up: one with no
location and no contacts. It never replaces a location already stated,
including one the refs placed a moment before the fix arrived, and never
touches an operation with contacts, which may be a log reopened far from
where it was made. Once captured it is a `gps` location, which a park added
afterwards does not move. The coordinate is rounded to five decimals, about
a metre (`gpsLocationData`), and the grid beside it is the rounded point's at
Grid Precision. Device GPS on the Location screen stores a fix the same way,
and offers one only while the service is `available`.

A device's first answer is often its worst — a cached position, a Wi-Fi or
IP estimate — so while the sheet stays open, the fix that session captured
is replaced by any more accurate one, and a fix vaguer than 500 m is never
stored at all: past that it can name the wrong town, and the town would go
out in every export. Once the operator edits the location in the sheet,
capturing stops for the session; clearing it is their answer, and a capture
on the next position update would make it impossible to leave a new
operation unlocated while GPS is allowed.

The Activities view runs the rule on its draft, on every refs edit, so the
nearby search recentres on the park just added while the sheet is still open.
Its save then passes `followRefs: false`: against the stored row, which
predates the sheet, the rule would see the refs changed and the location
empty, and put back a location the operator cleared on the Location screen
after adding the park.

### Records from another writer

The invariant holds for everything this app writes. It cannot hold for what
arrives from a device running something else, and app-polo is exactly that
case: its operation location screen (`OperationLocationScreen.jsx`) stores
`grid`, `gridSource`, `state` and `county`, and has no concept of the pair. So
an operation relocated there comes back with a new locator and the old
coordinate — which then outranks it at every reader, answering for a place the
operator has moved away from while the location screen shows the locator they
typed. The same screen writes `''` for a field never filled in, and `''` is not
null: every reader asking whether the record has a grid is told yes, while
`gridToLocation` gets nothing out of it. That operation is unplaceable and
claims to be located — no QTH on the map, no lines, no nearby suggestions.

`repairStatedLocation` reconciles the two halves as such a record enters, in
`OperationsRepository.mergeFromSync`. Two rules, and only those two:

- **A coordinate outside the square its locator names is dropped.** Inside is
  no contradiction: a pair within the cell is what the grid was derived from,
  or a finer fix inside it. Outside, one of the halves was edited without the
  other, and it is the grid that was edited — every writer of an operation's
  location states both together, so a coordinate cannot be the newer half.
  The edge is a tolerance (`gridCellContains`), a hundredth of the cell past
  its own boundary and never less than ADIF's own thousandth of a minute,
  which is all the precision a coordinate keeps through a file.
- **A locator that names no place is dropped**, with the `gridSource` that
  describes it and any coordinate beside it. `''` and a fragment (`IL2`)
  alike: this app's own editor refuses to store either (`isWellFormedGrid`),
  so nothing is lost that a local edit could have made. The coordinate goes
  for the same reason as in the first rule — both halves are written
  together, so a pair beside an emptied grid is the half a grid-only writer
  left when it cleared the location. app-polo does exactly that when the park
  that placed an operation (`gridSource: 'refs'`, above) is removed there. An
  explicit `grid: null` is a record with no locator rather than a broken one,
  and is left as it is.

The coordinate is read with `asQsonCoordinate`, not as a bare number: polo's
ADIF import copies `MY_LAT`/`LAT` verbatim, so a well-formed coordinate
arrives as `N041 41.250` and the QSON normalizer converts it *after* this
runs. A reader that only knew numbers would find nothing to judge on exactly
the records this exists for.

A placeholder (`AA00`) is left alone on both counts. It decodes like any other
square, so judging a coordinate against it would drop a real fix in favour of a
point at the South Pole that names nothing.

**An operation's record, and nothing else.** The first rule rests entirely on
both halves being written together, and that holds for an operation's location
and for no other record: the QSO edit pane's Latitude and Longitude fields are
the operator stating where a station is, to the precision they have, and they
deliberately survive an edit to the grid beside them
(`logging_controls_draft.dart`). A contact whose two halves name different
squares is making that statement, not carrying a stale half, and repairing one
would delete what the operator typed.

**The sync path, and not the peer one.** A record that arrives over the peer
channel is stored dirty and pushed onward, so a repair applied there would
send this device's deletion out under the *sender's* revision stamp — which
`inboundIsStale` drops at every other device, leaving the server stripped and
the fleet disagreeing about one record. A peer's operation reaches the server
on its own and comes back through the sync merge, where the repair belongs.

The repair is silent: the row is stored clean and stays `synced`, rather than
going back out as this device's own newer revision. A grid-only peer cannot
represent the pair in the first place, so pushing the repair would state a
revision it would only strip again. Each device heals its own copy on receipt,
deterministically, and everything read locally — the map, the distances, an
export — reads the healed row.

Operations that arrived before any of this are repaired once, by storage
version 14 (`HaLoDatabase._repairStatedLocations`) — nothing re-delivers a
synced record just because this build knows more about it, so without that
step an operation relocated years ago would measure from the coordinate it
left behind until someone opened its location screen. The migration leaves the
revision stamps alone for the same reason the merge does, which also means
what it drops is not recoverable from the record it dropped it from: it logs a
count of the rows it changed, and changes nothing else.

### One pair is not a coordinate

A pair tagged `locSource: 'prefix'` is lib-country-files' DXCC entity centroid,
and a synced record carries it signed either way: **west-positive**, as cty.dat
states it, when lib-country-files before 1.1 wrote it, and east-positive since —
with nothing on the record to tell the two apart. `locationFromGuess` refuses
that pair wherever one is read, so the resolver falls through to the grid and
then to `entity_locations.dart`, which holds the same centroids signed the way
the rest of the world signs them. Read as a coordinate it would outrank both,
and an old one would mirror the station about the prime meridian.

No lookup source of ours sets `locSource` today (`annotate.ts` blanks it, and
the merge plumbs it so a source can later say where its location came from).
The tag arrives with a synced QSO: app-polo spreads the country-file
annotation onto **both** `their` and `their.guess`, so the mirrored pair sits
in the entered slot as well as the guessed one, and both are filtered. The
Call History lookup drops the pair rather than carrying it onto a new contact,
where it would arrive untagged — `locSource` is deliberately not among the
fields it copies forward.

What this cannot catch: a pair that lost the tag on its way through another
program — notably a HaLo ADIF export written before this rule existed, read
back in as `LAT`/`LON`. There is nothing in such a record to tell it from a
real fix.

### Placeholder pairs

Two pairs are what a writer stores when it has no position at all, tag or no
tag (`isPlaceholderLocation`): exactly `0,0`, the default a writer with no fix
leaves behind, and the center of a placeholder grid (`AA00`, `AA00aa`), which
QRZ sends beside `AA00aa` for a station it cannot place. Screening the grid
alone is not enough, because the pair beside it outranks it: the station would
land at the South Pole instead of falling through to its state or entity.

- **Reading.** `locationFromLatLon` refuses both, so every resolver falls
  through to the grid, the state and the entity. The ADIF exporter carries the
  same rule (`adif/src/grid.ts`), so a file never states a position the screen
  refuses — neither as `LAT`/`LON` nor as a locator derived from the pair.
- **Has a place.** A side holding only a placeholder pair has none: the
  operation's place is copied onto it (`withPlaceFrom`), and the exporter takes
  the operation's location for it.
- **Repair.** On an operation arriving by sync or QSON import, a placeholder
  pair beside a real locator contradicts it and goes (`repairStatedLocation`).
  Anywhere else it stays stored: the app and the exporter refuse it, but
  extension hooks receive the record raw.
- **Capture.** A GPS reading of exactly `0,0` is a receiver with nothing to
  report yet. Neither the setup sheet's automatic capture nor the location
  screen's Device GPS row adopts one: captured, it would arrive with a
  `JJ00aa` locator derived from it, and that locator places the station at
  Null Island although the pair itself is refused. The reading is still
  offered as the live position; only storing it is refused.

What this cannot catch, because each stores a locator derived from the pair
and that locator is read like any other:

- a lookup answering `0,0` with no grid, from which `mergeLookup` derives
  `JJ00aa`;
- an operation captured from a `0,0` reading before capture refused one. Its
  `JJ00aa` and the pair agree, so no repair touches it.

Nor does the repair sweep records already stored locally; it runs on what
arrives.

## Display

`gridForDisplay(lat:, lon:, grid:)` — and the `displayGrid` getters over it —
give a locator for a record holding a real coordinate at the operator's **Grid
Precision** (`GridPrecision.current`, 6 or 8 characters, six by default), and
the stored grid as written for one that isn't. The length of a locator on
screen is a claim about how well the location is known, so:

- Never call `locationToGrid8` on a coordinate that came from decoding a grid.
  That invents four hundred metres of precision nobody had. `gridForDisplay`
  refuses it for you: a pair that is the stored grid's own center gets the
  stored grid back, whatever the setting says. That is what lets a
  hand-stated locator carry a coordinate without the round trip growing it —
  and the growth would stick, because the setup sheet seeds its Grid field
  from this string and saves it back on the next blur.

  `isGridCenter` is the test, and it is a **tolerance**, a hundredth of the
  cell's own size — not equality, and never a fixed number of degrees. A
  center does not always reach a reader with the bits it was written with: a
  coordinate that has been through an ADIF file is rounded to a thousandth of
  a minute, and a file written elsewhere may have computed the same center by
  different arithmetic. The cells run from 111 km of latitude to 19 m, so the
  question only makes sense asked in units of the square.
  `extensions/core/adif/src/grid.ts` is the port of it the exporter uses,
  decoding leniently and never throwing, which lib-geo-tools' own
  `gridToLocation` does on any length but 4, 6 or 8.
- A field the operator TYPES into keeps its hint at whatever would be stored if
  they left it alone — the hint and the stored value must not disagree.
- An operation whose refs placed it (`gridSource: 'refs'`) shows its stored
  square, cut to six characters, not a locator derived from the pair at the
  setting's length (`Operation.displayGrid`, `refsGridForDisplay`);
  `MY_GRIDSQUARE` is written the same way. A stored value that is not a
  well-formed locator falls back to deriving from the pair. The
  pair is the park's published point, and deriving from it would name a patch
  of the park the station was never said to be in.
- The setup sheet's location pill names a GPS location by its source —
  "GPS" — rather than by its square; a location from a ref or typed by hand
  shows its grid, on the pin.
- A GPS location, stored or live, looks the way it does in every map app:
  bright blue (`gpsDotColor`), a white ◉ on the blue pill, and on both maps a
  small blue dot in a thin white ring on a dark glow (`gpsMapDot`,
  `operation_location_pin.dart`) — one definition, so the pill and the maps
  cannot drift apart.

The setting governs how finely the app SPEAKS about a location, never how
finely it holds one. Coordinates are stored and measured from at the
precision they arrived with either way — a captured fix at five decimals —
and the resolution order above is untouched by it: a coordinate outranks a
grid at 6 characters exactly as it does at 8.

`GridPrecision` is a process-wide singleton for the same reason
`NumberFormatting` is one — every surface must agree, or one screen shows the
same station standing in two squares of different sizes. `HaLoServices` pushes
the setting into it at startup and on every settings change, and the extension
host passes the resolved LENGTH to hooks as `HookContext.gridPrecision`.

## Privacy

Exact coordinates are the operator's home address to within a few hundred
metres. ADIF export writes `LAT`/`LON`/`MY_LAT`/`MY_LON` only under the
`includePrivateData` export setting, in the same block as `GRIDSQUARE` (the
other operator's location, which they did not necessarily publish).

A pair that is only the stated grid's own center is not written at all, at
either end. It says nothing the gridsquare beside it did not, and an ADIF
reader takes a coordinate over a gridsquare — so writing it would publish the
station standing at a point inside a square it was only placed in.

`MY_GRIDSQUARE` is the exception that always ships — it is our own station's
location and the field award programs read — written at the operator's Grid
Precision but **truncated to six characters unless private data is
released**. The operation stores an 8-character locator
whenever its location came from a fix, so writing it verbatim would state the
position to a few hundred metres through the very switch withholding the
coordinate it was derived from.

SOTA's own exports (activator and hunter) carry both gridsquares whatever the
switch says, because the SOTA Challenge asks for them — app-polo does the
same. Both follow the reading rule above: a real coordinate is written as its
six-character square, otherwise the stored grid goes out, ours cut to six
characters. The full export keeps the rules above for the same contacts.

The coarser location fields are public on both sides, because the award
programs are claimed on them and a callsign or an on-air exchange already
states them: `STATE`, `COUNTRY`, `CNTY`, `DXCC`, `CQZ`, `ITUZ`, `CONT` and
`REGION` for the worked station, and `MY_STATE`, `MY_COUNTRY`, `MY_CNTY`,
`MY_DXCC`, `MY_CQ_ZONE`, `MY_ITU_ZONE`, `MY_CONT` and `MY_REGION` for ours.

The county is a deliberate divergence from app-polo, which withholds it as an
address. In a QSO party it is the EXCHANGE — the other station said it on the
air, and a file withholding it claims nothing the event scores on.

An export reads our own location off the CONTACT before the operation, and a
segmented log stamps each contact with its segment's answer on the way out
(`ExportService._stampSegment`). A hook is handed one operation for the whole
file, so that is the only way a rover's second county reaches the records it
belongs to. The stamp never covers a location the contact recorded itself.

Peer sync and backups carry everything unconditionally — that is the user's own
data moving between the user's own devices.
