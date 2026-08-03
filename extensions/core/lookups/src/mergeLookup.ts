// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pure merge algorithm for folding one CallInfoLookup result into a running
// `guess`, per the locationScope rules. Kept free
// of any hook/host dependencies so it can be unit tested in isolation —
// this is the highest-defect-risk piece of the whole feature.

import { gridToLocation, locationToGrid6 } from "@ham2k/lib-geo-tools"
import type { CallInfo, CallInfoLookup } from "@ham2k/halo-extension-sdk"
// Relative (not the `@ham2k/halo-extension-sdk` alias) so this file's own
// `mergeLookup.test.ts` — run via plain `node --test`, which can't resolve
// that tsc-only bare specifier — stays runnable; same constraint as
// annotate.ts's dxcc import.
import { LOCATION_ACCURACY } from "../../../sdk/src/location.ts"

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
  const next = { ...guess } as CallInfo & { locAccuracy?: number }
  const res = result as CallInfoLookup & { locAccuracy?: number }
  const resultScope = result.locationScope
  // Per-source location accuracy (lower = more precise); rides along untyped
  // like `flag`. Absent means "unknown" — treated as the least precise.
  const resultAccuracy = typeof res.locAccuracy === 'number' ? res.locAccuracy : undefined
  const currentAccuracy = typeof next.locAccuracy === 'number' ? next.locAccuracy : LOCATION_ACCURACY.NO_LOCATION
  const resultHasLocation = LOCATION_FIELDS.some((f) => hasValue((res as Record<string, unknown>)[f]))

  // 1. This result takes over the location — clearing every existing location
  //    field so its own values fill them below, and adopting its scope — when
  //    either its locationScope is strictly more specific, OR it has the same
  //    scope but a strictly more precise location (so the most accurate of
  //    several same-scope refs, e.g. a SOTA summit vs a POTA park on one QSO,
  //    wins regardless of the order they're folded in).
  const scopeUpgrade = resultScope != null && scopeRank(resultScope) > scopeRank(next.locationScope)
  const refinesSameScope =
    resultScope != null &&
    scopeRank(resultScope) === scopeRank(next.locationScope) &&
    resultHasLocation &&
    resultAccuracy != null &&
    resultAccuracy < currentAccuracy
  if (scopeUpgrade || refinesSameScope) {
    for (const field of LOCATION_FIELDS) delete next[field]
    delete next.locAccuracy
    if (resultScope != null) next.locationScope = resultScope
  }

  // A same-scope result that is strictly LESS precise than the location already
  // established must not touch ANY location field — otherwise a vaguer home
  // lookup (QRZ/HamDB, which inherit whatever locationScope a POTA/SOTA ref
  // already set) would fill the city/state a park's grid-only result left
  // empty, and the grid/city reconciliation below would then thrash the park
  // grid and location away. A more precise same-scope
  // result took over above; an equal one still first-wins per-field below.
  const locationLocked =
    resultScope != null &&
    scopeRank(resultScope) === scopeRank(next.locationScope) &&
    (resultAccuracy ?? LOCATION_ACCURACY.NO_LOCATION) > currentAccuracy

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
    if (field === 'source' || field === 'scope' || field === 'call' || field === 'notes' || field === 'history' || field === 'locationScope' || field === 'locAccuracy') continue
    if (!hasValue(value)) continue
    if (isLocationField(field)) {
      if (scopeRank(resultScope) < scopeRank(next.locationScope)) continue
      if (locationLocked) continue
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
    // A malformed grid (e.g. HamDB's literal "NOT_FOUND" before it started
    // filtering, or any future source's junk) makes gridToLocation throw —
    // and a throw here discards the source's entire result, valid name and
    // city included. Drop just the bogus grid instead.
    try {
      const [lat, lon] = gridToLocation(next.grid!)
      next.lat = lat
      next.lon = lon
    } catch (e) {
      delete next.grid
    }
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

  // Record the accuracy of the location this result actually contributed
  // (i.e. wrote at least one location field), so a later same-scope result
  // can tell whether it would be an improvement. A contributing result with
  // no declared accuracy leaves the slot "unknown" (least precise).
  if (written.size > 0) {
    if (resultAccuracy != null) next.locAccuracy = resultAccuracy
    else delete next.locAccuracy
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
