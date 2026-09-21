// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Maidenhead grid locator → latitude/longitude, used by the Map tab to plot
// QSOs and the operation's own QTH. Same algorithm as app-polo's
// @ham2k/lib-geo-tools gridToLocation; ported here in pure Dart since
// showing a map is core UI (DESIGN.md §7), not extension territory.

class GridLocation {
  final double latitude;
  final double longitude;

  const GridLocation(this.latitude, this.longitude);

  /// Value equality so map data built from locations (marker/line lists)
  /// can be compared with `listEquals` to tell rebuilds from real changes.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GridLocation && latitude == other.latitude && longitude == other.longitude);

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// A decoded Maidenhead cell: where its center is, and how big it is.
///
/// The size is what tells a caller how much a locator actually CLAIMS — four
/// characters is 111 km of latitude, ten is 19 m — so anything comparing a
/// coordinate against a square has to measure in units of the square rather
/// than in degrees (see [isGridCenter]).
class GridCell {
  final GridLocation center;
  final double latSize;
  final double lonSize;

  const GridCell(this.center, this.latSize, this.lonSize);
}

/// Decodes a 4-, 6-, 8- or 10-character Maidenhead grid locator to the lat/lon
/// of the center of the finest cell it can read — stopping at the last level
/// that parses, so a locator with a malformed tail still yields the coarser
/// cell it agrees on. Returns null for anything that doesn't parse at all —
/// wrong length, out-of-range field letters, non-digit squares.
GridLocation? gridToLocation(String? grid) => gridCell(grid)?.center;

/// [gridToLocation] with the cell's dimensions as well.
GridCell? gridCell(String? grid) {
  if (grid == null || grid.length < 4) return null;
  final g = grid.toUpperCase();

  final lonField = g.codeUnitAt(0) - 65; // 'A'
  final latField = g.codeUnitAt(1) - 65;
  if (lonField < 0 || lonField > 17 || latField < 0 || latField > 17) return null;

  final lonSquare = int.tryParse(g[2]);
  final latSquare = int.tryParse(g[3]);
  if (lonSquare == null || latSquare == null) return null;

  // The cell shrinks by the divisor of each level in turn — 24 for a letter
  // pair, 10 for a digit pair — and the return adds half of whatever it ended
  // up as, moving from the cell's south-west corner to its center.
  var lonSize = 2.0;
  var latSize = 1.0;
  var lon = lonField * 20 - 180 + lonSquare * lonSize;
  var lat = latField * 10 - 90 + latSquare * latSize;
  GridCell center() => GridCell(GridLocation(lat + latSize / 2, lon + lonSize / 2), latSize, lonSize);

  if (g.length >= 6) {
    final lonSub = g.codeUnitAt(4) - 65;
    final latSub = g.codeUnitAt(5) - 65;
    if (lonSub < 0 || lonSub >= 24 || latSub < 0 || latSub >= 24) return center();
    lonSize /= 24;
    latSize /= 24;
    lon += lonSub * lonSize;
    lat += latSub * latSize;
  }

  if (g.length >= 8) {
    final lonExt = int.tryParse(g[6]);
    final latExt = int.tryParse(g[7]);
    if (lonExt == null || latExt == null) return center();
    lonSize /= 10;
    latSize /= 10;
    lon += lonExt * lonSize;
    lat += latExt * latSize;
  }

  if (g.length >= 10) {
    final lonSubSub = g.codeUnitAt(8) - 65;
    final latSubSub = g.codeUnitAt(9) - 65;
    if (lonSubSub < 0 || lonSubSub >= 24 || latSubSub < 0 || latSubSub >= 24) return center();
    lonSize /= 24;
    latSize /= 24;
    lon += lonSubSub * lonSize;
    lat += latSubSub * latSize;
  }

  return center();
}

/// A well-formed Maidenhead locator: field pair, square digits, then
/// optional subsquare pair, extended-square digits, and sub-subsquare pair
/// (4, 6, 8, or 10 characters), any case.
final _gridShape = RegExp(
  r'^[A-R]{2}[0-9]{2}(?:[A-X]{2}(?:[0-9]{2}(?:[A-X]{2})?)?)?$',
  caseSensitive: false,
);

/// Whether [grid] is a well-formed Maidenhead locator — 4, 6, 8 or 10
/// characters, in the right alternation of letter pairs and digit pairs.
///
/// The question [gridToLocation] answers is a different one: it DECODES, and
/// decodes leniently, falling back to the square's centre for anything it
/// can't read past position 4. `FN31ZZ` gets a location out of it (`ZZ` is not
/// a subsquare, so it yields FN31's centre) and `FN31pr99xx` gets one too.
/// That is the right behaviour for reading a locator off the air or out of a
/// data file, and the wrong one for deciding whether to accept what an
/// operator typed — validate with this, decode with that.
bool isWellFormedGrid(String? grid) => grid != null && _gridShape.hasMatch(grid.trim());

/// Normalizes a Maidenhead locator to its conventional case combination —
/// uppercase field pair, lowercase subsquare letters ("fn31PR" → "FN31pr").
/// Grid *input* fields are uppercase-only like every other logging control,
/// so this runs where the value is stored/compared, restoring the canonical
/// mixed case. Anything that isn't a well-formed locator is returned
/// unchanged (beyond trimming) — this formats, it doesn't validate.
String normalizeGrid(String grid) {
  final g = grid.trim();
  if (!_gridShape.hasMatch(g)) return g;
  // Positions 0-3 are the field pair (uppercase) and square digits;
  // everything after is either digits (case-less) or subsquare letters
  // (lowercase).
  return g.substring(0, 4).toUpperCase() + (g.length > 4 ? g.substring(4).toLowerCase() : '');
}

/// Grids some sources emit when they have no real location at all. They
/// decode like any other locator — `AA00` is a real square off Antarctica —
/// so nothing downstream can tell one from a location by looking at it; every
/// reader that would place a station has to ask here first.
const _placeholderGrids = {'AA00', 'AA00AA'};

/// Whether [grid] is one of those placeholders, and so names no location.
bool isPlaceholderGrid(String grid) => _placeholderGrids.contains(grid.trim().toUpperCase());

/// Encodes a latitude/longitude as a 6-character Maidenhead grid locator
/// (e.g. `EM89hu`) — the inverse of [gridToLocation], used to show the
/// device's current GPS position as a grid. Same algorithm as app-polo's
/// @ham2k/lib-geo-tools `locationToGrid6`.
String locationToGrid6(double lat, double lon) => _locationToGrid(lat, lon, extended: false);

/// Encodes a latitude/longitude as an 8-character locator (e.g. `EM89hu56`) —
/// the 6-character subsquare plus the extended-square digit pair, a cell 30″
/// of longitude by 15″ of latitude (roughly 700m x 460m at mid latitudes).
///
/// Use this ONLY for a coordinate that is actually known to that precision (a
/// GPS fix, a park's published position). A grid is what the operator reads,
/// so its length is a claim about how well the location is known: eight
/// characters derived from a grid-6 square's own center invent four hundred
/// metres of precision that was never there.
String locationToGrid8(double lat, double lon) => _locationToGrid(lat, lon, extended: true);

String _locationToGrid(double lat, double lon, {required bool extended}) {
  final adjLat = (lat + 90).clamp(0, 180);
  final adjLon = (lon + 180).clamp(0, 360);

  final lonField = (adjLon / 20).floor().clamp(0, 17);
  final latField = (adjLat / 10).floor().clamp(0, 17);

  final lonSquare = ((adjLon - lonField * 20) / 2).floor().clamp(0, 9);
  final latSquare = (adjLat - latField * 10).floor().clamp(0, 9);

  final lonRest = adjLon - lonField * 20 - lonSquare * 2;
  final latRest = adjLat - latField * 10 - latSquare;
  final lonSub = (lonRest / (2 / 24)).floor().clamp(0, 23);
  final latSub = (latRest / (1 / 24)).floor().clamp(0, 23);

  final field = String.fromCharCode(65 + lonField) + String.fromCharCode(65 + latField);
  final square = '$lonSquare$latSquare';
  final sub = String.fromCharCode(97 + lonSub) + String.fromCharCode(97 + latSub);
  if (!extended) return '$field$square$sub';

  final lonExt = ((lonRest - lonSub * (2 / 24)) / (2 / 240)).floor().clamp(0, 9);
  final latExt = ((latRest - latSub * (1 / 24)) / (1 / 240)).floor().clamp(0, 9);
  return '$field$square$sub$lonExt$latExt';
}

/// A coordinate pair as an exact location, or null when either half is
/// missing, non-numeric, not finite, or out of range.
///
/// Takes [Object]s because every caller reads them straight out of a JSON
/// blob (`operation.data`, `qso.their.guess`, an activity ref) where the type
/// is whatever the writer put there — a `0` arriving as `int`, a coordinate
/// arriving as a string from a data file that never got parsed. Answering
/// "is there an exact location here?" in one place keeps every caller from
/// re-deciding what counts.
GridLocation? locationFromLatLon(Object? lat, Object? lon) {
  if (lat is! num || lon is! num) return null;
  final latitude = lat.toDouble();
  final longitude = lon.toDouble();
  if (!latitude.isFinite || !longitude.isFinite) return null;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return null;
  return GridLocation(latitude, longitude);
}

/// The coordinate a record carries, or null when the pair it holds is really
/// a DXCC entity centroid taken straight from the country file. Reads a
/// lookup `guess` or a QSO's `their`, both of which can carry one.
///
/// `locSource: 'prefix'` marks that pair, and today only lib-country-files'
/// `annotateFromCountryFile` sets it — no lookup source of ours writes
/// `locSource` at all, though `mergeLookup` plumbs it so one can later say
/// where its location came from. Two reasons never to read a 'prefix' pair as
/// a coordinate: its `lon` follows cty.dat's WEST-POSITIVE convention, which
/// every other coordinate in the app contradicts, so taking it at face value
/// mirrors the station about the prime meridian; and it is an entity
/// centroid, which [locationForQsoInfoWithSource] resolves for itself further
/// down, from a table signed the way the rest of the world is.
///
/// app-polo spreads the whole annotation onto BOTH `their` and `their.guess`
/// (useCallLookup's `annotateQSO`), so a synced QSO carries the pair, and the
/// tag, in both places. Our own pipeline blanks all three fields — see
/// extensions/core/lookups/src/annotate.ts.
GridLocation? locationFromGuess(Map<String, dynamic>? info) {
  if (info == null || info['locSource'] == 'prefix') return null;
  return locationFromLatLon(info['lat'], info['lon']);
}

/// How many characters a locator is SHOWN with — the operator's Grid
/// Precision setting, resolved once and readable from every package.
///
/// A process-wide singleton for the same reason [NumberFormatting] is one:
/// every surface must agree. A locator's length is a claim about how well a
/// location is known, so two call sites answering differently would have the
/// same station standing in two squares of different sizes on two panels of
/// one screen.
///
/// Six by default. Eight characters is a ~700 x 460 m cell — finer than what
/// an operator puts on the air, and finer than most operators want to publish
/// — so the app states the coarser claim unless asked for the other.
enum GridPrecision {
  six(6),
  eight(8);

  const GridPrecision(this.digits);

  /// The locator length this choice renders, 6 or 8.
  final int digits;

  /// The precision in force, app-wide. The app pushes this here at startup
  /// and on every settings change; nothing else should write it.
  static GridPrecision get current => _current;
  static GridPrecision _current = GridPrecision.six;

  static void configure(GridPrecision precision) => _current = precision;

  /// Back to the default. For tests: this is process-wide state, so a test
  /// that configures it leaks into whatever runs next in the same isolate.
  /// Call it in a tearDown, the way an AppClock test resets travel.
  static void reset() => _current = GridPrecision.six;
}

/// A coordinate as a locator at the operator's [GridPrecision] — what a fix
/// is SHOWN as, and what is stored as the grid beside it. The coordinate
/// itself is stored whole either way; only how finely the app SPEAKS about it
/// is a setting.
String gridForLocation(double lat, double lon) =>
    GridPrecision.current == GridPrecision.eight ? locationToGrid8(lat, lon) : locationToGrid6(lat, lon);

/// The locator to SHOW for a record — derived from its coordinate when it has
/// one, at the operator's [GridPrecision]; otherwise its stored [grid] as
/// written. Null when the record has neither.
///
/// The pair is the record's own `lat`/`lon` (see [locationFromLatLon]), which
/// outranks the grid because it is what the grid was derived FROM.
///
/// The exception is a pair that is the stored grid's own center
/// ([isGridCenter]), which every writer of a hand-stated locator records (see
/// [locationForStatedGrid]). Such a pair says nothing the grid did not, so
/// the stored grid is shown as written — rendering it at the setting's length
/// would state a precision the operator never claimed, and this string seeds
/// the very field they typed it into, so the invented characters would be
/// saved back on the next blur.
String? gridForDisplay({Object? lat, Object? lon, String? grid}) {
  final stored = grid?.trim();
  final normalized = stored == null || stored.isEmpty ? null : normalizeGrid(stored);
  if (locationFromLatLon(lat, lon) case final location?) {
    if (normalized != null && isGridCenter(location, normalized)) return normalized;
    return gridForLocation(location.latitude, location.longitude);
  }
  return normalized;
}

/// How close to a cell's center a coordinate must sit to count as being that
/// center rather than a position inside the cell — a hundredth of the cell's
/// own size, so the question scales with what the locator claims.
///
/// A fraction, never a fixed number of degrees: the cells range from 111 km
/// of latitude (four characters) to 19 m (ten), and one tolerance in degrees
/// would be meaningless at one end and wrong at the other.
///
/// It has to be a tolerance at all because a center does not always reach a
/// reader with the bits it was written with: an ADIF round trip stores
/// coordinates to a thousandth of a minute (~1.8 m), and a file written
/// elsewhere may have computed the same center by different arithmetic.
/// Exact equality would answer "no" to centers that plainly are ones, and the
/// locator would then be rendered longer than anyone claimed. A hundredth of
/// a cell clears that by orders of magnitude while staying far under any
/// distance that would change what an operator reads.
const _gridCenterTolerance = 0.01;

/// Whether [location] is a cell's own center rather than a position inside
/// it — that is, whether the pair says anything [grid] did not.
///
/// This is a question about PROVENANCE (was this pair written FROM that
/// grid?) asked through geometry, because nothing in a QSON record records
/// the answer. Every writer of a hand-stated locator stores the center beside
/// it ([locationForStatedGrid]), and both the display and the ADIF exporter
/// have to recognise those for what they are.
bool isGridCenter(GridLocation location, String? grid) {
  final cell = gridCell(grid);
  if (cell == null) return false;
  return (location.latitude - cell.center.latitude).abs() <= cell.latSize * _gridCenterTolerance &&
      (location.longitude - cell.center.longitude).abs() <= cell.lonSize * _gridCenterTolerance;
}

/// How far outside a cell a coordinate may sit and still be read as being in
/// it — a hundredth of the cell's own size past the edge, the same fraction
/// [_gridCenterTolerance] allows around the center and for the same reason: a
/// station standing on a cell boundary must not read as contradicting the
/// locator it is stored with.
const _gridEdgeTolerance = 0.01;

/// A thousandth of a minute, which is all the precision ADIF stores a
/// coordinate to — so a pair that has been through a file can sit this far
/// from where it was written, whatever the cell it is being judged against.
///
/// A floor under [_gridEdgeTolerance], because that fraction shrinks with the
/// cell while this does not: a hundredth of a ten-character cell is under a
/// metre, so without this the rounding alone could put a coordinate outside
/// the very square it was derived from.
const _adifCoordinateStep = 1 / 60000;

/// Whether [location] sits inside [cell] — the question a record carrying
/// both halves answers about itself.
///
/// A coordinate inside the square says MORE than the square (it is where the
/// grid came from, or a finer fix within it). One outside CONTRADICTS it, and
/// since this app never writes the two in disagreement (docs/design/locations.md),
/// such a record can only have come from a writer that edited one half and
/// left the other — see `repairStatedLocation`.
bool gridCellContains(GridCell cell, GridLocation location) {
  double reach(double size) {
    final margin = size * _gridEdgeTolerance;
    return size / 2 + (margin > _adifCoordinateStep ? margin : _adifCoordinateStep);
  }

  return (location.latitude - cell.center.latitude).abs() <= reach(cell.latSize) &&
      (location.longitude - cell.center.longitude).abs() <= reach(cell.lonSize);
}

/// The coordinate to store beside a locator the operator has just STATED —
/// the center of the square, or null when there is nothing to place.
///
/// Every writer of a hand-entered grid records this pair, so that a record
/// carrying a grid carries a coordinate too and nothing downstream has to
/// re-derive one. It is a true statement — the station is inside the square —
/// and [gridForDisplay] recognises it for what it is, so it never lengthens
/// the locator the operator typed.
///
/// Null for a placeholder ([isPlaceholderGrid]): those name no location at
/// all, and turning one into a coordinate would plant a station on the map at
/// the corner of the world the placeholder happens to decode to, outranking
/// every coarser source that could have answered honestly.
GridLocation? locationForStatedGrid(String? grid) {
  final stated = grid?.trim();
  if (stated == null || stated.isEmpty || isPlaceholderGrid(stated)) return null;
  return gridToLocation(stated);
}
