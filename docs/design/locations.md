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
(extensions/core/adif) converts on the way out.

## The invariant

**Where a coordinate is present it is authoritative, and the grid is display
only.** Every reader resolves through `locationForQsoInfoWithSource`
(`exact:` outranks `grid:`), or through `Operation.location` / `Qso.ourLocation`
which do the same thing.

The other half is what keeps that honest: **a writer that sets a grid without a
coordinate must clear `lat`/`lon` in the same write.** A stale coordinate
outranks the grid everywhere it is read, so leaving one behind silently
discards what the operator just entered. The writers that carry this today are
`OperationLocationScreen._save`, `ActivitiesView._maybeAdoptLocationFromNewRef`,
and the QSO editor's grid field (`logging_controls.dart`).

A hand-typed grid therefore stores no coordinate at all. That is the correct
answer, not a gap: a square is all the operator stated.

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
give an **8-character** locator for a record holding a real coordinate, and the
stored grid as written for one that isn't. The length of a locator on screen is
a claim about how well the location is known, so:

- Never call `locationToGrid8` on a coordinate that came from decoding a grid.
  That invents four hundred metres of precision nobody had.
- A field the operator TYPES into keeps its hint at whatever would be stored if
  they left it alone — the hint and the stored value must not disagree.

## Privacy

Exact coordinates are the operator's home address to within a few hundred
metres. ADIF export writes `LAT`/`LON`/`MY_LAT`/`MY_LON` only under the
`includePrivateData` export setting, in the same block as `GRIDSQUARE` (the
other operator's location, which they did not necessarily publish).

`MY_GRIDSQUARE` is the exception that always ships — it is our own station's
location and the field award programs read — but **truncated to six characters
unless private data is released**. The operation stores an 8-character locator
whenever its location came from a fix, so writing it verbatim would state the
position to a few hundred metres through the very switch withholding the
coordinate it was derived from.

Peer sync and backups carry everything unconditionally — that is the user's own
data moving between the user's own devices.
