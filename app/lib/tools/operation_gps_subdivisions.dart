// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_core/halo_core.dart';

import '../services/error_reporting_service.dart';
import '../services/us_subdivision_lookup.dart';

Future<UsSubdivisionResult> lookupGpsSubdivisions(UsSubdivisionLookup lookup, GridLocation fix, double accuracyMeters) async {
  try {
    return await lookup.lookup(fix, accuracyMeters: accuracyMeters);
  } catch (error, stack) {
    // The grid still describes the fix when the downloaded geography cannot be read.
    ErrorReportingService.report(error, stack, context: 'operation:usSubdivisionLookup');
    return noUsSubdivision;
  }
}

/// A blank string is an explicit edit. Null means the field can be filled.
/// The saved GPS values distinguish inferred fields from edits by other
/// writers that do not update this metadata.
Map<String, dynamic> gpsSubdivisionPatch(Map<String, dynamic> data, {String? state, String? county}) {
  final statedState = asQsonString(data['state']);
  final gpsState = statedState != null && statedState == data['gpsState'];
  final gpsCounty = gpsSuppliedCounty(data);
  final fillState = gpsState || statedState == null;
  final fillCounty = gpsCounty || data['county'] == null;
  final effectiveState = fillState ? state : statedState.trim().toUpperCase();
  final matchingCounty = state != null && effectiveState == state ? county : null;
  return {
    if (gpsState || (fillState && state != null)) 'state': state,
    if (data['gpsState'] != null || (fillState && state != null)) 'gpsState': fillState ? state : null,
    if (gpsCounty || (fillCounty && matchingCounty != null)) 'county': matchingCounty,
    if (data['gpsCounty'] != null || (fillCounty && matchingCounty != null)) 'gpsCounty': fillCounty ? matchingCounty : null,
  };
}

bool gpsSuppliedCounty(Map<String, dynamic> data) {
  final county = asQsonString(data['county']);
  return county != null && county == data['gpsCounty'];
}
