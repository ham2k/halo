// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where a contact is, said in one line — "2,605 km to Santo Domingo, DN –
// Dominican Republic".
//
// A top-level function rather than a method on the logging panel because two
// surfaces compose the same line now: the call-info area, and the peer
// positions panel showing what other operating positions are working. Both
// answer it against THEIR OWN operation and settings, which is why the
// operation and the units come in as arguments — a distance is to wherever
// the reader is, and a line rendered once by the sender would be wrong for
// everybody else.

import 'package:flutter/widgets.dart';
import 'package:halo_core/halo_core.dart';

import '../i18n/strings.g.dart';
import 'distance_format.dart';

/// The location string for [guess] — distance (and bearing, if the setting is
/// on) to the contact, then a location label. Country is shown only for DX
/// contacts, never our own entity. A distance from a centroid (not a real
/// grid) is shown approximate ("~") and rounded. Null when nothing is known.
String? callLocationLine(
  BuildContext context,
  Map<String, dynamic> guess, {
  required GridLocation? ourLocation,
  required bool miles,
  required bool showBearing,
  String? ourEntityPrefix,
}) {
  final t = context.t.loggingControls.info;
  final entityPrefix = asQsonString(guess['entityPrefix']);

  final resolved = locationForQsoInfoWithSource(
    exact: locationFromLatLon(guess['lat'], guess['lon']),
    grid: asQsonString(guess['grid']),
    entityPrefix: entityPrefix,
    state: asQsonString(guess['state']),
  );

  String? distStr;
  int? bearingDeg;
  // Skip an entity-centroid distance for the largest countries — the country
  // center is a poor estimate; show a distance for them only once we know the
  // state (a state-centroid fix).
  final skipCentroid = resolved?.source == QsoLocationSource.entity && kLargeEntities.contains(entityPrefix);
  if (ourLocation != null && resolved != null && !skipCentroid) {
    final approximate = resolved.source.isApproximate;
    final km = distanceOnEarthKm(resolved.location, ourLocation);
    distStr = fmtDistance(approximate ? approxRoundedKm(km, miles: miles) : km, miles: miles);
    if (approximate) distStr = '~$distStr'; // centroid-based, not a real fix
    if (showBearing) bearingDeg = bearingOnEarthDeg(ourLocation, resolved.location).round();
  }

  final location = asQsonString(guess['location'])?.trim();
  final country = asQsonString(guess['country'])?.trim();
  // Location + country (country for DX only, never our own entity), joined
  // with an en dash rather than a bullet.
  final label = [
    if (location != null && location.isNotEmpty) location,
    if (country != null && country.isNotEmpty && entityPrefix != ourEntityPrefix) country,
  ].join(' – ');

  if (distStr != null && label.isNotEmpty) {
    // The distance's "to" flows straight into the place — "2,605 km to
    // Santo Domingo, DN – Dominican Republic".
    final phrase = bearingDeg != null
        ? t.distanceBearingTo(distance: distStr, bearing: bearingDeg)
        : t.distanceTo(distance: distStr);
    return '$phrase $label';
  }
  if (label.isNotEmpty) return label;
  // No place to point "to" — say the distance "away" instead ("15 km away").
  if (distStr != null) {
    return bearingDeg != null
        ? t.distanceBearingAway(distance: distStr, bearing: bearingDeg)
        : t.distanceAway(distance: distStr);
  }
  return null;
}
