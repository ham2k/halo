// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Pure merge algorithm for folding one CallInfoLookup result into a running
// `guess`, per the locationScope rules. Kept free
// of any hook/host dependencies so it can be unit tested in isolation —
// this is the highest-defect-risk piece of the whole feature.

import { gridToLocation, locationToGrid6 } from "@ham2k/lib-geo-tools"
import type { CallInfo, CallInfoLookup } from "@ham2k/extension-sdk"
// Relative (not the `@ham2k/extension-sdk` alias) so this file's own
// `mergeLookup.test.ts` — run via plain `node --test`, which can't resolve
// that tsc-only bare specifier — stays runnable; same constraint as
// annotate.ts's dxcc import.
import { LOCATION_ACCURACY } from "../../../sdk/src/location.ts"

const LOCATION_SCOPE_RANK: Record<string, number> = { qth: 0, prefixed: 1, portable: 2 }

// `street` and `postal` are the mailing address's own lines: grouped with the
// town they complete, so an address is never one source's street on another
// source's town.
const LOCATION_FIELDS = ["locSource", "lat", "lon", "grid", "street", "city", "state", "postal", "county", "country", "location"] as const
type LocationField = (typeof LOCATION_FIELDS)[number]

// Meta fields ABOUT a result, never folded into the flat guess merge below —
// `notes`/`history` accumulate onto `lookups[]` unconditionally instead
// (mergeLookup.test.ts), `locAccuracy`/`online` are read directly off the
// stored per-source record (this file's own location-precedence logic;
// LookupQueueService._hasOnlineLookup).
const META_FIELDS = new Set(["source", "scope", "call", "notes", "history", "locationScope", "locAccuracy", "online"])

function scopeRank(scope: CallInfo["locationScope"] | undefined): number {
  return scope ? (LOCATION_SCOPE_RANK[scope] ?? 0) : 0
}

function isLocationField(field: string): field is LocationField {
  return (LOCATION_FIELDS as readonly string[]).includes(field)
}

function hasValue(value: unknown): boolean {
  return value !== undefined && value !== null && value !== ""
}

/// Applies one lookup result onto the running `guess`. Returns a NEW guess
/// object — never mutates its input, so callers/tests can compare before
/// and after freely.
export function mergeLookupIntoGuess(guess: CallInfo, result: CallInfoLookup): CallInfo {
  const next = { ...guess } as CallInfo & { locAccuracy?: number; street?: string; postal?: string }
  const res = result as CallInfoLookup & { locAccuracy?: number }
  const resultScope = result.locationScope
  // Per-source location accuracy (lower = more precise); rides along untyped
  // like `flag`. Absent means "unknown" — treated as the least precise.
  const resultAccuracy = typeof res.locAccuracy === "number" ? res.locAccuracy : undefined
  const currentAccuracy = typeof next.locAccuracy === "number" ? next.locAccuracy : LOCATION_ACCURACY.NO_LOCATION
  // Whether this result CARRIES a value for a field, whatever becomes of it
  // in the per-field merge below.
  const carries = (field: LocationField) => hasValue((res as Record<string, unknown>)[field])
  const resultHasLocation = LOCATION_FIELDS.some(carries)

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
    resultScope != null && scopeRank(resultScope) === scopeRank(next.locationScope) && (resultAccuracy ?? LOCATION_ACCURACY.NO_LOCATION) > currentAccuracy

  // A "pin": a grid gridToLocation can place, or a full lat/lon pair — half
  // a pair places nothing, and a junk grid ("NOT_FOUND") earns no authority:
  // an invalid pin degrades its result to the pinless rules rather than
  // letting it take a town over on the strength of a value the
  // reconciliation below then throws away. A "town": the human-readable side
  // of a location. `country` counts as neither — the annotation pre-step
  // stamps an entity-level country on nearly every call, and that must not
  // make the guess read as located. (A blocked result's country is refused
  // along with the rest of its group.) Judged after the takeover clearing
  // above, so a scope/accuracy takeover that just emptied the location reads
  // as unlocated here.
  const placeable = (grid: unknown): boolean => {
    if (typeof grid !== "string" || grid.trim() === "") return false
    try {
      gridToLocation(grid)
      return true
    } catch (e) {
      return false
    }
  }
  const guessHasPin = hasValue(next.grid) || (hasValue(next.lat) && hasValue(next.lon))
  const resultHasPin = placeable(res.grid) || (carries("lat") && carries("lon"))
  const guessHasTown = (["city", "state", "county", "location"] as const).some((f) => hasValue(next[f]))
  const scopeEligible = !locationLocked && scopeRank(resultScope) >= scopeRank(next.locationScope)

  // 1b. Location fields merge as a GROUP, never per field — a splice of two
  //     sources' halves names a place neither of them reported:
  //     - A result bringing a pin to a guess that has none takes over the
  //       whole location: the pinless town established so far is replaced by
  //       the pin-source's own town (or just cleared, for a grid-only
  //       result), never kept alongside the new pin. Without this, a
  //       free-tier QRZ answer (city/state, no grid) followed by a full
  //       record leaves one source's town under another source's pin.
  if (scopeEligible && resultHasPin && !guessHasPin) {
    for (const field of LOCATION_FIELDS) delete next[field]
  }
  //     - A result whose own pin loses to an already-established one
  //       contributes no location fields at all: its town describes the pin
  //       that lost. And a PINLESS result's town lands only where the
  //       higher-priority lookups left no town or pin — it neither replaces
  //       nor completes an established location (filling just its empty
  //       slots would put, e.g., its state under another source's city).
  //       (Both enforced in the per-field merge below.)
  const locationBlocked = resultHasPin ? guessHasPin : guessHasPin || guessHasTown

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
    if (META_FIELDS.has(field)) continue
    if (!hasValue(value)) continue
    if (isLocationField(field)) {
      if (scopeRank(resultScope) < scopeRank(next.locationScope)) continue
      if (locationLocked) continue
      if (locationBlocked) continue
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
  const setGrid = written.has("grid")
  const setLatLon = written.has("lat") || written.has("lon")
  // `location` (the display-friendly "City, State" / POTA park summary
  // string) travels with city/state/country for reconciliation purposes —
  // it's the same underlying "where" data in a different shape.
  const setCityStateCountry = written.has("city") || written.has("state") || written.has("country") || written.has("location")

  if (setGrid && !setLatLon) {
    // A grid-only result stores a grid and NO coordinate. The square's centre
    // would be a coordinate nobody reported, and a coordinate outranks a grid
    // everywhere it is read (docs/design/locations.md) — so every reader would
    // measure from, and every export would state, a point invented here.
    // Nothing needs it: the resolvers fall through to the grid on their own,
    // and `gridForDisplay` renders the stored square as written.
    //
    // The check stays, because it was always doing two jobs. A malformed grid
    // (e.g. HamDB's literal "NOT_FOUND" before it started filtering, or any
    // future source's junk) must be dropped on its own, without discarding the
    // source's whole result — its name and city are still good.
    if (!placeable(next.grid)) delete next.grid
  } else if (setLatLon && !setGrid && next.lat != null && next.lon != null) {
    next.grid = locationToGrid6(next.lat, next.lon)
  }

  if (setGrid || setLatLon) {
    // Clear city/state/country/county/location unless THIS result also
    // supplied them. (A pin write only happens into a pinless guess — rule
    // 1b already replaced the established town — so this clears at most the
    // writer's own leftovers, keeping town and pin from one source.)
    for (const field of ["street", "city", "state", "postal", "country", "county", "location"] as const) {
      if (!written.has(field)) delete next[field]
    }
  } else if (setCityStateCountry && !written.has("county")) {
    // City/state/country/location updated (without county, and without
    // this result also touching grid/lat/lon) clears grid/lat/lon. A town
    // only lands where rule 1b found no full pin, so all this can still
    // sweep is a leftover half lat/lon pair — kept for exactly that.
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
export function runLookupPipeline(initialGuess: CallInfo, orderedResults: CallInfoLookup[]): { lookups: CallInfoLookup[]; guess: CallInfo } {
  let guess = initialGuess
  const lookups: CallInfoLookup[] = []
  for (const result of orderedResults) {
    lookups.push(result)
    guess = mergeLookupIntoGuess(guess, result)
  }
  return { lookups, guess }
}

/// What the callsign annotation can only answer for a whole entity or call
/// area, and a source that knows the station answers better: a W6 call
/// living in New England is in CQ zone 5, not the 3 its prefix says.
const ENTITY_DEFAULT_FIELDS = ["cqZone", "ituZone", "tz"] as const

/// Run once every lookup has folded in: each entity-default field the
/// annotation's value still holds goes to the first of [results] (priority
/// order) that answered it — the one exception to "the first source to answer
/// keeps a field", since the annotation always answers first. Only for a
/// station at home: on a portable or prefixed contact a source's answer
/// describes the home QTH, and the annotation's call-area value is the better
/// guess.
export function preferStationValues(guess: CallInfo, annotation: CallInfoLookup, results: CallInfoLookup[]): CallInfo {
  if ((guess.locationScope ?? "qth") !== "qth") return guess
  const next = { ...guess } as Record<string, unknown>
  for (const field of ENTITY_DEFAULT_FIELDS) {
    if (!hasValue(annotation[field]) || next[field] !== annotation[field]) continue
    const station = results.find((result) => hasValue(result[field]))
    if (station) next[field] = station[field]
  }
  return next as CallInfo
}
