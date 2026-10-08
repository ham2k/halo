// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An operation with no location of its own takes one from its references —
// see docs/design/locations.md, "Located by its references".

import 'dart:convert';

import '../ham/grid.dart';
import 'models.dart';
import 'qson_values.dart';

/// The `gridSource` of a location this rule wrote, and the one it may go on
/// rewriting: a location from any other source was stated by the operator or
/// a device, and the refs never override it.
const refsGridSource = 'refs';

/// Fills in, moves or clears [after]'s location to follow its refs, in place.
/// Returns whether anything changed. [before] is the record as it was (null
/// for a new one).
///
/// Runs only on a write that changes the refs, and only for an operation with
/// no location or one this rule placed (app-polo's `gridSource: 'refs'`,
/// which it re-derives the same way). A location from any other source —
/// even one stated in the same write — is left alone:
///
///  - The first ref with a location places the operation — its own
///    coordinate where it publishes one, the square's center otherwise.
///  - A ref marked `largeArea` never places anything. Its point is a
///    representative one for a trail or a park across several states, and
///    the operator could be anywhere along it.
///  - When no ref can place it, a location this rule placed is cleared, so
///    removing the park removes the location it brought.
///
/// The device's position plays no part, as in app-polo: reading it here would
/// make the answer depend on when a write happens to run, and a position the
/// service keeps after it stops can be hours old. Adopting a GPS fix is the
/// operator's act, on the Location screen.
bool locationFollowsRefs(Map<String, dynamic>? before, Map<String, dynamic> after) {
  if (jsonEncode(before?['refs']) == jsonEncode(after['refs'])) return false;
  final operation = Operation(uuid: '', data: after);
  final following = after['gridSource'] == refsGridSource;
  if (!following && operation.location != null) return false;

  final placing = operation.refs.where((ref) => ref['largeArea'] != true).map(_refLocation).nonNulls.firstOrNull;
  if (placing == null) {
    if (!following) return false;
    for (final key in _locationKeys) {
      after.remove(key);
    }
    return true;
  }
  final placed = {'grid': placing.grid, 'gridSource': refsGridSource, 'lat': placing.location.latitude, 'lon': placing.location.longitude};
  final changed = _locationKeys.any((key) => after[key] != placed[key]);
  after.addAll(placed);
  return changed;
}

const _locationKeys = ['grid', 'gridSource', 'lat', 'lon'];

({GridLocation location, String grid})? _refLocation(Map<String, dynamic> ref) {
  final grid = asQsonString(ref['grid']);
  final location = locationFromLatLon(ref['lat'], ref['lon']) ?? locationForStatedGrid(grid);
  if (location == null) return null;
  // Non-null whenever `location` is: either the pair is valid or `grid` is a
  // non-empty locator.
  return (location: location, grid: gridForDisplay(lat: ref['lat'], lon: ref['lon'], grid: grid)!);
}
