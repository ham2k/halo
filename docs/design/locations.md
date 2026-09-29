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
`OperationLocationScreen._save`, `ActivitiesView._maybeAdoptLocationFromNewRef`,
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
claims to be located — no QTH on the map, no lines, no nearby suggestions, and
`ActivitiesView._maybeAdoptLocationFromNewRef` will not offer it a location
either, because it already has a grid.

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
  describes it. `''` and a fragment (`IL2`) alike: this app's own editor
  refuses to store either (`isWellFormedGrid`), so nothing is lost that a
  local edit could have made. An explicit `grid: null` is a record with no
  locator rather than a broken one, and is left as it is.

The coordinate is read with `asQsonCoordinate`, not as a bare number: polo's
ADIF import copies `MY_LAT`/`LAT` verbatim, so a well-formed coordinate
arrives as `N041 41.250` and the QSON normalizer converts it *after* this
runs. A reader that only knew numbers would find nothing to judge on exactly
the records this exists for.

A placeholder (`AA00`) is left alone on both counts. It decodes like any other
square, so judging a coordinate against it would drop a real fix in favour of a
corner of the Atlantic that names nothing.

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
and its `lon` follows cty.dat's **west-positive** convention — the opposite of
every other coordinate here. `locationFromGuess` refuses that pair wherever one
is read, so the resolver falls through to the grid and then to
`entity_locations.dart`, which holds the same centroids signed the way the rest
of the world signs them. Read as a coordinate it would outrank both and mirror
the station about the prime meridian.

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

The setting governs how finely the app SPEAKS about a location, never how
finely it holds one. Coordinates are stored and measured from at full
precision either way, and the resolution order above is untouched by it: a
coordinate outranks a grid at 6 characters exactly as it does at 8.

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
