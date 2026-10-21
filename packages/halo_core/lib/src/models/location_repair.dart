// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Reconciling the two halves of an operation's location when it arrives from
// another device — see docs/design/locations.md, whose invariant this
// enforces at the one boundary that can break it.

import '../ham/grid.dart';
import 'qson_values.dart';

/// Reconciles an operation record's `grid` and `lat`/`lon`, in place. Returns
/// whether anything changed.
///
/// Two things can be wrong with a record this app did not write, and only
/// those two:
///
///  - **A coordinate that contradicts the locator beside it.** Where a pair
///    is present it OUTRANKS the grid everywhere it is read, so a writer that
///    states a grid replaces the pair in the same write (locations.md). A
///    writer with no concept of the pair — app-polo's OperationLocationScreen
///    stores `grid` alone — changes only the locator, and the coordinate it
///    leaves behind then answers for a location the operator has moved away
///    from. The pair is the half that goes: the grid is what was edited.
///
///  - **A locator that names no place.** `''` is what app-polo's location
///    screen writes for a field never filled in, and it is not null, so every
///    reader asking "does this operation have a grid?" is told yes while
///    `gridToLocation` gets nothing — a record that is unplaceable and claims
///    to be located. A fragment (`IL2`) does the same; this app's own editor
///    refuses to store either. Any coordinate beside it goes with it.
///
/// **An operation's record, and nothing else.** The first rule rests entirely
/// on both halves being written together, which holds for every writer of an
/// operation's location and for no other record: the QSO edit pane's Latitude
/// and Longitude fields are the operator stating where a station is, to the
/// precision they have, and they deliberately survive an edit to the grid
/// beside them (`logging_controls_draft.dart`). A contact's two halves
/// disagreeing is that statement, not a stale half, and reading it as one
/// would delete what the operator typed.
///
/// A placeholder locator ([isPlaceholderGrid]) is left alone, both halves of
/// it: `AA00` decodes like any other square, and reading it as a statement
/// about where the station is would drop a real coordinate in favour of a
/// point at the South Pole that names nothing.
bool repairStatedLocation(Map<String, dynamic> data) {
  final grid = asQsonString(data['grid'])?.trim();
  if (grid != null && isPlaceholderGrid(grid)) return false;

  final cell = grid == null || grid.isEmpty ? null : gridCell(grid);
  if (cell == null) {
    // `gridSource` names where a locator came from, so it goes with it — left
    // alone it would say a location was set by GPS on a record that no longer
    // states one. Nothing is repaired when neither key is really there: an
    // explicit `grid: null` is a record with no locator, not a broken one,
    // and rewriting the row to say so would touch every log for nothing.
    if (!_holds(data, 'grid') && !_holds(data, 'gridSource')) return false;
    // The pair goes too when a locator was there to empty. Every writer here
    // states both halves together, so a coordinate beside an emptied grid is
    // what a grid-only writer left behind when it cleared the location —
    // app-polo removing the park that placed it writes `grid: ''` and keeps
    // the rest — and it would go on placing the operation where it no longer
    // is.
    if (_holds(data, 'grid')) {
      data.remove('lat');
      data.remove('lon');
    }
    data.remove('grid');
    data.remove('gridSource');
    return true;
  }

  final stated = _statedCoordinate(data);
  if (stated == null || gridCellContains(cell, stated)) return false;
  data.remove('lat');
  data.remove('lon');
  return true;
}

bool _holds(Map<String, dynamic> data, String key) => data[key] != null;

/// The coordinate this record states, read the way STORAGE will read it.
///
/// [asQsonCoordinate], not a bare number: app-polo's ADIF import copies
/// `MY_LAT`/`LAT` verbatim, so a well-formed coordinate reaches us as
/// `N041 41.250` and the QSON normalizer converts it — after this runs. A
/// reader that only knew numbers would find no coordinate on exactly the
/// records written by the program this repair exists for.
///
/// A `locSource: 'prefix'` pair is refused here as it is everywhere
/// ([locationFromGuess]): it is an entity centroid that may be west-positive,
/// so judging a locator against it could place the station on the wrong side
/// of the meridian, and dropping the pair it disagrees with would cost the
/// record the coordinate its own locator was written from.
///
/// A placeholder pair ([isPlaceholderLocation]) IS returned, though no reader
/// in the app takes it as a location: beside a real locator it contradicts it
/// and goes, or extension hooks and chasing programs, which receive the stored
/// record raw, would be handed a pair that outranks the square.
GridLocation? _statedCoordinate(Map<String, dynamic> data) {
  if (data['locSource'] == 'prefix') return null;
  final lat = asQsonCoordinate(data['lat'], latitude: true);
  final lon = asQsonCoordinate(data['lon'], latitude: false);
  if (lat == null || lon == null) return null;
  final pair = GridLocation(lat.toDouble(), lon.toDouble());
  return isPlaceholderLocation(pair) ? pair : locationFromLatLon(lat, lon);
}
