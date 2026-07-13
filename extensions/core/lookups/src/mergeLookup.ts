// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pure merge algorithm for folding one CallInfoLookup result into a running
// `guess`, per the locationScope rules from ham2k/app-halo-dist#8. Kept free
// of any hook/host dependencies so it can be unit tested in isolation —
// this is the highest-defect-risk piece of the whole feature.

import { gridToLocation, locationToGrid6 } from "@ham2k/lib-geo-tools"
import type { CallInfo, CallInfoLookup } from "@ham2k/polo-sdk"

const LOCATION_SCOPE_RANK: Record<string, number> = { qth: 0, prefixed: 1, portable: 2 }

const LOCATION_FIELDS = ['locSource', 'lat', 'lon', 'grid', 'city', 'state', 'county', 'country', 'location'] as const
type LocationField = (typeof LOCATION_FIELDS)[number]

function scopeRank(scope: CallInfo['locationScope'] | undefined): number {
  return scope ? (LOCATION_SCOPE_RANK[scope] ?? 0) : 0
}

function isLocationField(field: string): field is LocationField {
  return (LOCATION_FIELDS as readonly string[]).includes(field)
}

function hasValue(value: unknown): boolean {
  return value !== undefined && value !== null && value !== ''
}

/// Applies one lookup result onto the running `guess`. Returns a NEW guess
/// object — never mutates its input, so callers/tests can compare before
/// and after freely.
export function mergeLookupIntoGuess(guess: CallInfo, result: CallInfoLookup): CallInfo {
  const next: CallInfo = { ...guess }
  const resultScope = result.locationScope

  // 1. A strictly-more-specific locationScope clears all existing location
  //    fields before anything from this result is merged in, and the guess
  //    adopts the new, more specific scope.
  if (resultScope && scopeRank(resultScope) > scopeRank(next.locationScope)) {
    for (const field of LOCATION_FIELDS) delete next[field]
    next.locationScope = resultScope
  }

  // 2. Priority order: fields already present in `next` are never
  //    overwritten (higher-priority/earlier results win). Location fields
  //    additionally require this result's own scope to be at least as
  //    specific as the guess's (possibly just-updated) locationScope — a
  //    more general-scoped result must never populate a slot that belongs
  //    to a more specific one, even if that slot happens to be empty.
  //    `written` tracks fields THIS result actually caused to be set — by
  //    real write, not by comparing values afterward (a rejected field can
  //    coincidentally equal what's already in `next`, e.g. two sources
  //    agreeing on the same grid, which must not count as "written").
  const written = new Set<LocationField>()
  for (const [field, value] of Object.entries(result)) {
    if (field === 'source' || field === 'scope' || field === 'call' || field === 'notes' || field === 'history' || field === 'locationScope') continue
    if (!hasValue(value)) continue
    if (isLocationField(field)) {
      if (scopeRank(resultScope) < scopeRank(next.locationScope)) continue
      if (hasValue(next[field])) continue
      ;(next as Record<string, unknown>)[field] = value
      written.add(field)
    } else {
      if (hasValue((next as Record<string, unknown>)[field])) continue
      ;(next as Record<string, unknown>)[field] = value
    }
  }

  // 3. Grid/lat-lon reconciliation, scoped to fields THIS result actually
  //    wrote in step 2 (see `written` above).
  const setGrid = written.has('grid')
  const setLatLon = written.has('lat') || written.has('lon')
  // `location` (the display-friendly "City, State" / POTA park summary
  // string) travels with city/state/country for reconciliation purposes —
  // it's the same underlying "where" data in a different shape.
  const setCityStateCountry = written.has('city') || written.has('state') || written.has('country') || written.has('location')

  if (setGrid && !setLatLon) {
    const [lat, lon] = gridToLocation(next.grid!)
    next.lat = lat
    next.lon = lon
  } else if (setLatLon && !setGrid && next.lat != null && next.lon != null) {
    next.grid = locationToGrid6(next.lat, next.lon)
  }

  if (setGrid || setLatLon) {
    // Clear city/state/country/county/location unless THIS result also
    // supplied them.
    for (const field of ['city', 'state', 'country', 'county', 'location'] as const) {
      if (!written.has(field)) delete next[field]
    }
  } else if (setCityStateCountry && !written.has('county')) {
    // City/state/country/location updated (without county, and without
    // this result also touching grid/lat/lon — the two reconciliation
    // rules are mutually exclusive per result) clears grid/lat/lon.
    delete next.grid
    delete next.lat
    delete next.lon
  }

  return next
}

/// Runs an ordered list of already-fetched lookup results through
/// `mergeLookupIntoGuess`, accumulating both the final `guess` and the raw
/// `lookups[]` list (every result, unconditionally, `notes`/`history` and
/// all — those two fields are never touched by the merge rules above).
export function runLookupPipeline(
  initialGuess: CallInfo,
  orderedResults: CallInfoLookup[],
): { lookups: CallInfoLookup[]; guess: CallInfo } {
  let guess = initialGuess
  const lookups: CallInfoLookup[] = []
  for (const result of orderedResults) {
    lookups.push(result)
    guess = mergeLookupIntoGuess(guess, result)
  }
  return { lookups, guess }
}
