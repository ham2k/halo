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

/// Decodes a 4-, 6-, 8- or 10-character Maidenhead grid locator to the lat/lon
/// of the center of the finest cell it can read — stopping at the last level
/// that parses, so a locator with a malformed tail still yields the coarser
/// cell it agrees on. Returns null for anything that doesn't parse at all —
/// wrong length, out-of-range field letters, non-digit squares.
GridLocation? gridToLocation(String? grid) {
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
  GridLocation center() => GridLocation(lat + latSize / 2, lon + lonSize / 2);

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

/// The locator to SHOW for a record — eight characters derived from its
/// coordinate when it has one, otherwise its stored [grid] as written.
///
/// The pair is the record's own `lat`/`lon` (see [locationFromLatLon]), so
/// the length of what comes back tracks how well the location is actually
/// known, rather than how long a string some upstream source happened to
/// send. Null when the record has neither.
String? gridForDisplay({Object? lat, Object? lon, String? grid}) {
  if (locationFromLatLon(lat, lon) case final location?) {
    return locationToGrid8(location.latitude, location.longitude);
  }
  final stored = grid?.trim();
  if (stored == null || stored.isEmpty) return null;
  return normalizeGrid(stored);
}
