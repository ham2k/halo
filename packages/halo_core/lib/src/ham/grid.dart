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
