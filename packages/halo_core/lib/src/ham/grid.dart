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

/// Decodes a 4- or 6-character Maidenhead grid locator to the lat/lon of
/// its center (of the subsquare when 6 characters are given and valid,
/// otherwise the square). Returns null for anything that doesn't parse as
/// a valid locator — wrong length, out-of-range field letters, non-digit
/// squares.
GridLocation? gridToLocation(String? grid) {
  if (grid == null || grid.length < 4) return null;
  final g = grid.toUpperCase();

  final lonField = g.codeUnitAt(0) - 65; // 'A'
  final latField = g.codeUnitAt(1) - 65;
  if (lonField < 0 || lonField > 17 || latField < 0 || latField > 17) return null;

  final lonSquare = int.tryParse(g[2]);
  final latSquare = int.tryParse(g[3]);
  if (lonSquare == null || latSquare == null) return null;

  final lon = lonField * 20 - 180 + lonSquare * 2;
  final lat = latField * 10 - 90 + latSquare * 1;

  if (g.length >= 6) {
    final lonSub = g.codeUnitAt(4) - 65;
    final latSub = g.codeUnitAt(5) - 65;
    if (lonSub >= 0 && lonSub < 24 && latSub >= 0 && latSub < 24) {
      return GridLocation(
        lat + latSub * (1 / 24) + (0.5 / 24),
        lon + lonSub * (2 / 24) + (1 / 24),
      );
    }
  }
  return GridLocation(lat + 0.5, lon + 1);
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
String locationToGrid6(double lat, double lon) {
  final adjLat = (lat + 90).clamp(0, 180);
  final adjLon = (lon + 180).clamp(0, 360);

  final lonField = (adjLon / 20).floor().clamp(0, 17);
  final latField = (adjLat / 10).floor().clamp(0, 17);

  final lonSquare = ((adjLon - lonField * 20) / 2).floor().clamp(0, 9);
  final latSquare = (adjLat - latField * 10).floor().clamp(0, 9);

  final lonSub = (((adjLon - lonField * 20 - lonSquare * 2)) / (2 / 24)).floor().clamp(0, 23);
  final latSub = (((adjLat - latField * 10 - latSquare)) / (1 / 24)).floor().clamp(0, 23);

  final field = String.fromCharCode(65 + lonField) + String.fromCharCode(65 + latField);
  final square = '$lonSquare$latSquare';
  final sub = String.fromCharCode(97 + lonSub) + String.fromCharCode(97 + latSub);
  return '$field$square$sub';
}
