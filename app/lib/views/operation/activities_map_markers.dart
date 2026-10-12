// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where an activity reference sits, and the markers that draw references on
// the Activities and Maps maps (activities_results_map.dart).

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../map/map_marker_data.dart';
import 'activity_rows.dart' show activityRowTitle;

/// The entry's own coordinate when the activity's lookup table has one
/// (tighter than decoding a 6-character grid square — see the SDK's `Ref.lat`
/// / `Ref.lon`, extensions/sdk/src/types.ts), otherwise the center of its
/// `grid`. Null when the entry has neither, same as a QSO with no
/// resolvable location on the Map tab.
GridLocation? locationForSuggestion(Map<String, dynamic> suggestion) =>
    // Read, not cast: an extension's answer, and a malformed one must not take
    // the map with it.
    locationFromLatLon(suggestion['lat'], suggestion['lon']) ?? gridToLocation(suggestion['grid'] is String ? suggestion['grid'] as String : null);

/// One marker per [suggestions] entry that is NOT already on the operation
/// and has a resolvable location (see [locationForSuggestion]) — entries
/// without one are silently omitted, the same treatment a location-less QSO
/// gets on the Map tab. The id is [selectedRefMarkerId], what the entry IS
/// rather than where it sits in the list: suggestions arrive late (a pan,
/// parks found by their outline) and are re-ranked, and an open card or a
/// tap's pager has to keep naming the same reference through that. One
/// marker per reference — the first of two that share one wins.
///
/// Unlike the list rows, this takes no "are these search results?" — the
/// rows keep an already-added search hit and fade it (`suggestionHidesAsAlreadyAdded`),
/// where the map has [activitySelectedRefMarkers] drawing that same point in
/// the reference's own icon, and two dots on one point read as two
/// references. Which is the whole justification for dropping it, so the drop
/// is conditional on that other marker actually existing: a reference the
/// operation stored WITHOUT a location gets none, and dropping its
/// suggestion too would take the only dot that reference had off the map.
///
/// Given [glyphFor], each marker is drawn in its reference type's icon, as
/// [activitySelectedRefMarkers] draws the operation's own.
List<MapMarkerData> activitySuggestionMarkers(
  List<Map<String, dynamic>> suggestions, {
  required List<Map<String, dynamic>> controls,
  required List<Map<String, dynamic>> refs,
  required Color defaultColor,
  required Color strokeColor,
  MapMarkerGlyph? Function(IconData icon, Color background)? glyphFor,
}) {
  final markers = <MapMarkerData>[];
  final drawn = <String>{};
  for (final suggestion in suggestions) {
    final storedRef = refs.where((r) => r['type'] == suggestion['type'] && r['ref'] == suggestion['ref']).firstOrNull;
    if (storedRef != null && locationForSuggestion(storedRef) != null) continue;
    final location = locationForSuggestion(suggestion);
    if (location == null || !drawn.add(selectedRefMarkerId(suggestion))) continue;
    final control = controlForRefType(controls, suggestion['type'] as String?);
    final baseColor = colorForRefType(controls, suggestion['type'] as String?) ?? defaultColor;
    // Faded when the operation already has it: this dot only survives the
    // drop above because the stored reference has no location of its own
    // to draw, and at full strength it would be indistinguishable from a
    // reference the operator can still add — which its card, offering no
    // Add button, then contradicts. The glyph is what a map draws, so it
    // fades too.
    final color = storedRef == null ? baseColor : baseColor.withValues(alpha: 0.4);
    markers.add(
      MapMarkerData(
        id: selectedRefMarkerId(suggestion),
        latitude: location.latitude,
        longitude: location.longitude,
        label: activityRowTitle(control, suggestion),
        kind: MapMarkerKind.qso,
        color: color,
        strokeColor: strokeColor,
        glyph: glyphFor?.call(resolveIconName(control?['icon'] as String?), color),
      ),
    );
  }
  return markers;
}

/// What a reference is named by on the map — its marker, its card, a tap's
/// pager — whether it is on the operation or suggested.
String selectedRefMarkerId(Map<String, dynamic> ref) => 'ref-${ref['type']}/${ref['ref']}';

/// One marker per operation reference with a resolvable location, in the
/// reference type's own icon and color — the same pair the Current
/// Activities rows above the map use, so a dot and its row read as the same
/// object. Ids are [selectedRefMarkerId], the same a suggestion of that
/// reference carries: removed from the operation, a reference's card stays
/// open on the suggestion it becomes, now offering Add — the undo for a
/// removal made by mistake. Whether an id names one of the operation's own
/// references is a question for the refs, not for the id.
///
/// [glyphFor] returns null while a marker's pixels are still being drawn;
/// that reference falls back to a plain dot in its color for those frames
/// rather than vanishing from the map.
List<MapMarkerData> activitySelectedRefMarkers(
  List<Map<String, dynamic>> refs, {
  required List<Map<String, dynamic>> controls,
  required Color defaultColor,
  required Color strokeColor,
  required MapMarkerGlyph? Function(IconData icon, Color background) glyphFor,
}) {
  final markers = <MapMarkerData>[];
  for (final ref in refs) {
    final location = locationForSuggestion(ref);
    if (location == null) continue;
    final control = controlForRef(controls, type: ref['type'] as String?, code: ref['ref'] is String ? ref['ref'] as String : null);
    // With the code, like the control lookup above it: a reference answered
    // under a legacy type would otherwise take the default colour while the
    // row beside it wears its extension's.
    final color = colorForRefType(controls, ref['type'] as String?, code: refCodeOf(ref)) ?? defaultColor;
    markers.add(
      MapMarkerData(
        id: selectedRefMarkerId(ref),
        latitude: location.latitude,
        longitude: location.longitude,
        label: activityRowTitle(control, ref),
        kind: MapMarkerKind.qso,
        color: color,
        strokeColor: strokeColor,
        glyph: glyphFor(resolveIconName(control?['icon'] as String?), color),
      ),
    );
  }
  return markers;
}
