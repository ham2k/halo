// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { mergeLookupIntoGuess, runLookupPipeline } from "./mergeLookup.ts"
import type { CallInfo, CallInfoLookup } from "@ham2k/halo-extension-sdk"
// Relative import (the SDK bare specifier is tsc-only, unresolvable under
// `node --test` — see annotate.ts).
import { LOCATION_ACCURACY } from "../../../sdk/src/location.ts"

// A lookup result carrying a per-source location accuracy (rides along untyped,
// like POTA/SOTA now emit — see LookupResult).
type Located = CallInfoLookup & { locAccuracy?: number }

test("priority order: earlier result's field is not overwritten by a later one, but an absent field is populated", () => {
  const guess: CallInfo = { call: "KI2D" }
  const first: CallInfoLookup = { call: "KI2D", source: "a", scope: "general", name: "First Name" }
  const second: CallInfoLookup = { call: "KI2D", source: "b", scope: "general", name: "Second Name", city: "Woodridge" }

  const { guess: afterFirst } = runLookupPipeline(guess, [first])
  const { guess: final } = runLookupPipeline(afterFirst, [second])

  assert.equal(final.name, "First Name") // not overwritten
  assert.equal(final.city, "Woodridge") // populated, was absent
})

test("locationScope upgrade clears location fields, then the more specific result's own fields populate", () => {
  let guess: CallInfo = { call: "KI2D", locationScope: "qth", grid: "FN21rq", city: "Woodridge", state: "NY" }

  const portableResult: CallInfoLookup = { call: "KI2D", source: "pota", scope: "qso", locationScope: "portable", grid: "DN60ns" }
  guess = mergeLookupIntoGuess(guess, portableResult)

  assert.equal(guess.locationScope, "portable")
  assert.equal(guess.grid, "DN60ns")
  assert.equal(guess.city, undefined) // cleared, not repopulated by this result
  assert.equal(guess.state, undefined)
})

test("rule 3: after a scope upgrade, only same-or-more-specific results can populate the now-cleared fields", () => {
  let guess: CallInfo = { call: "KI2D/M", locationScope: "qth", grid: "FN21rq", city: "Woodridge" }

  // Portable indicator clears qth fields but doesn't supply its own city.
  guess = mergeLookupIntoGuess(guess, { call: "KI2D/M", source: "callsign-annotation", scope: "general", locationScope: "portable" })
  assert.equal(guess.grid, undefined)
  assert.equal(guess.city, undefined)

  // A later qth-scoped result must NOT repopulate the cleared city field —
  // its scope (qth) is less specific than the guess's current (portable).
  guess = mergeLookupIntoGuess(guess, { call: "KI2D", source: "qrz", scope: "general", locationScope: "qth", city: "Somewhere Else", grid: "FN21aa" })
  assert.equal(guess.city, undefined)
  assert.equal(guess.grid, undefined)
})

test("issue example: EA3/KI2D full match is scoped 'prefixed'; QRZ fallback to KI2D is scoped 'qth' and must not clobber it", () => {
  let guess: CallInfo = { call: "EA3/KI2D", locationScope: "prefixed" }

  // QRZ resolves EA3/KI2D directly -> prefixed scope, sets location data.
  guess = mergeLookupIntoGuess(guess, { call: "EA3/KI2D", source: "qrz", scope: "general", locationScope: "prefixed", city: "Barcelona", grid: "JN11aa" })
  assert.equal(guess.city, "Barcelona")
  assert.equal(guess.locationScope, "prefixed")

  // Simulate the SAME source's home-callsign fallback still being folded in
  // (hypothetically, if some other qth-scoped hook ran afterward) — it must
  // not override the already-set prefixed-scope city/grid.
  guess = mergeLookupIntoGuess(guess, { call: "KI2D", source: "qrz-fallback", scope: "general", locationScope: "qth", city: "Woodridge", grid: "FN21rq" })
  assert.equal(guess.city, "Barcelona")
  assert.equal(guess.grid, "JN11aa")
})

test("issue example: QRZ qth (grid/city) then POTA portable ref clears qth data and adopts the park's grid", () => {
  let guess: CallInfo = { call: "KI2D", locationScope: "qth" }

  guess = mergeLookupIntoGuess(guess, { call: "KI2D", source: "qrz", scope: "general", locationScope: "qth", grid: "FN21rq", city: "Woodridge" })
  assert.equal(guess.grid, "FN21rq")
  assert.equal(guess.city, "Woodridge")

  guess = mergeLookupIntoGuess(guess, { call: "KI2D", source: "pota", scope: "qso", locationScope: "portable", grid: "DN60ns" })
  assert.equal(guess.locationScope, "portable")
  assert.equal(guess.grid, "DN60ns")
  assert.equal(guess.city, undefined) // cleared, POTA didn't supply a city
})

test("grid-only result computes lat/lon; lat/lon-only result computes a 6-digit grid; both given are taken verbatim", () => {
  const withGridOnly = mergeLookupIntoGuess({ call: "X" }, { call: "X", source: "a", scope: "general", grid: "FN21rq" })
  assert.ok(typeof withGridOnly.lat === "number" && typeof withGridOnly.lon === "number")

  const withLatLonOnly = mergeLookupIntoGuess({ call: "X" }, { call: "X", source: "a", scope: "general", lat: 41.5, lon: -74.5 })
  assert.ok(typeof withLatLonOnly.grid === "string" && withLatLonOnly.grid!.length === 6)

  const withAllThree = mergeLookupIntoGuess({ call: "X" }, { call: "X", source: "a", scope: "general", grid: "FN21rq", lat: 1, lon: 2 })
  assert.equal(withAllThree.lat, 1)
  assert.equal(withAllThree.lon, 2)
  assert.equal(withAllThree.grid, "FN21rq")
})

test("a grid update clears prior city/state/country/county unless the same result also supplies them", () => {
  const guess: CallInfo = { call: "X", city: "Old City", state: "Old State", country: "Old Country", county: "Old County" }

  const cleared = mergeLookupIntoGuess(guess, { call: "X", source: "a", scope: "general", grid: "FN21rq" })
  assert.equal(cleared.city, undefined)
  assert.equal(cleared.state, undefined)
  assert.equal(cleared.country, undefined)
  assert.equal(cleared.county, undefined)

  // A fresh guess (no pre-existing city, so priority-order doesn't block the
  // write) supplying both grid and city in the same result: city survives.
  const freshGuess: CallInfo = { call: "X" }
  const keptSameResultFields = mergeLookupIntoGuess(freshGuess, { call: "X", source: "a", scope: "general", grid: "FN21rq", city: "New City" })
  assert.equal(keptSameResultFields.city, "New City")
  assert.equal(keptSameResultFields.state, undefined)
})

test("a city/state/country update (without county, and without grid/lat/lon in the same result) clears grid/lat/lon", () => {
  const guess: CallInfo = { call: "X", grid: "FN21rq", lat: 1, lon: 2 }

  const cleared = mergeLookupIntoGuess(guess, { call: "X", source: "a", scope: "general", city: "New City" })
  assert.equal(cleared.grid, undefined)
  assert.equal(cleared.lat, undefined)
  assert.equal(cleared.lon, undefined)
})

test("a result setting both a new grid AND a new city in the same call clears neither family", () => {
  const freshGuess: CallInfo = { call: "X" }
  const merged = mergeLookupIntoGuess(freshGuess, { call: "X", source: "a", scope: "general", grid: "FN21rq", city: "New City" })
  assert.equal(merged.grid, "FN21rq")
  assert.equal(merged.city, "New City")
})

test("a field rejected by scope gating is never treated as 'touching' that field for reconciliation purposes", () => {
  // Regression: a lower-scoped result nominally carrying city+grid must not
  // trigger the city/state/country-clears-grid (or vice versa) rule when
  // its own fields were rejected by the priority/scope gate in step 2.
  let guess: CallInfo = { call: "EA3/KI2D", locationScope: "prefixed", city: "Barcelona", grid: "JN11aa" }
  guess = mergeLookupIntoGuess(guess, { call: "KI2D", source: "qrz-fallback", scope: "general", locationScope: "qth", city: "Woodridge", grid: "FN21rq" })
  assert.equal(guess.city, "Barcelona")
  assert.equal(guess.grid, "JN11aa")
})

test("an empty result ([]) contributes nothing and leaves the guess untouched", () => {
  const guess: CallInfo = { call: "X", name: "Someone" }
  const { guess: after } = runLookupPipeline(guess, [])
  assert.deepEqual(after, guess)
})

test("notes/history accumulate onto lookups[] regardless of merge outcome", () => {
  const guess: CallInfo = { call: "X" }
  const a: CallInfoLookup = { call: "X", source: "a", scope: "general", notes: ["note A"] as unknown as CallInfoLookup["notes"] }
  const b: CallInfoLookup = { call: "X", source: "b", scope: "general", notes: ["note B"] as unknown as CallInfoLookup["notes"] }
  const { lookups } = runLookupPipeline(guess, [a, b])
  assert.equal(lookups.length, 2)
  assert.deepEqual(lookups[0].notes, ["note A"])
  assert.deepEqual(lookups[1].notes, ["note B"])
})

test("full pipeline: portable annotation -> qth hamdb -> prefixed qrz ends with locationScope 'portable'", () => {
  const guess: CallInfo = { call: "KI2D/P" }
  const annotation: CallInfoLookup = { call: "KI2D/P", source: "callsign-annotation", scope: "general", locationScope: "portable" }
  const hamdb: CallInfoLookup = { call: "KI2D", source: "hamdb.org", scope: "general", locationScope: "qth", city: "Woodridge", grid: "FN21rq" }
  const qrz: CallInfoLookup = { call: "KI2D", source: "qrz.com", scope: "general", locationScope: "prefixed", name: "Someone" }

  const { guess: final } = runLookupPipeline(guess, [annotation, hamdb, qrz])
  assert.equal(final.locationScope, "portable")
  assert.equal(final.city, undefined) // hamdb's qth data never populated (portable already claimed it)
  assert.equal(final.grid, undefined)
  assert.equal(final.name, "Someone") // non-location field, unaffected by scope gating
})

test("location travels with city/state/country: a qth-scoped result's location is suppressed once a portable scope has already claimed it", () => {
  let guess: CallInfo = { call: "KI2D/P", locationScope: "portable" }
  guess = mergeLookupIntoGuess(guess, {
    call: "KI2D",
    source: "hamdb.org",
    scope: "general",
    locationScope: "qth",
    location: "Woodridge, NY",
    city: "Woodridge",
    state: "NY",
  })
  assert.equal(guess.location, undefined)
  assert.equal(guess.city, undefined)
})

test("a grid update clears a prior location unless the same result also supplies it; POTA's combined grid+location survives together", () => {
  const staleGuess: CallInfo = { call: "X", location: "Old City, OS" }
  const cleared = mergeLookupIntoGuess(staleGuess, { call: "X", source: "a", scope: "general", grid: "FN21rq" })
  assert.equal(cleared.location, undefined)

  const freshGuess: CallInfo = { call: "US-2005", locationScope: "qth" }
  const pota = mergeLookupIntoGuess(freshGuess, {
    call: "US-2005",
    source: "pota",
    scope: "qso",
    locationScope: "portable",
    grid: "DN60ns",
    location: "US-2005 NY Amsterdam Beach State Park",
  })
  assert.equal(pota.grid, "DN60ns")
  assert.equal(pota.location, "US-2005 NY Amsterdam Beach State Park")
})

test("regression: a result whose grid/city are REJECTED by priority order (already set) must not be treated as 'written', even if its rejected grid value coincidentally matches", () => {
  const guess: CallInfo = { call: "X", grid: "FN21rq", city: "Springfield" }
  // Same grid value as already in guess (coincidence), different city —
  // both fields are rejected by step 2 since `next` already has values.
  const merged = mergeLookupIntoGuess(guess, { call: "X", source: "b", scope: "general", grid: "FN21rq", city: "Shelbyville" })
  assert.equal(merged.grid, "FN21rq")
  assert.equal(merged.city, "Springfield") // must survive — this result wrote nothing
})

// ── issue #185: keep the most precise same-scope location ──────────────────

const pota: Located = { call: "X", source: "pota", scope: "qso", locationScope: "portable", grid: "DN60ns", location: "US-1 Park", locAccuracy: LOCATION_ACCURACY.REASONABLE }
const sota: Located = { call: "X", source: "sota", scope: "qso", locationScope: "portable", grid: "FN31aa", location: "W2/GC-001 Summit", locAccuracy: LOCATION_ACCURACY.ACCURATE }

test("#185: the more precise same-scope ref wins regardless of fold order (SOTA summit over POTA park)", () => {
  // POTA folded first, then the more precise SOTA refines it.
  const forward = runLookupPipeline({ call: "X", locationScope: "qth" }, [pota, sota]).guess
  assert.equal(forward.grid, "FN31aa")
  assert.equal(forward.location, "W2/GC-001 Summit")

  // Reverse order: SOTA first, POTA must NOT clobber the more precise summit.
  const reverse = runLookupPipeline({ call: "X", locationScope: "qth" }, [sota, pota]).guess
  assert.equal(reverse.grid, "FN31aa")
  assert.equal(reverse.location, "W2/GC-001 Summit")
})

test("#185: a less precise same-scope result does not replace an already more precise location", () => {
  let guess: CallInfo = { call: "X", locationScope: "qth" }
  guess = mergeLookupIntoGuess(guess, sota)
  guess = mergeLookupIntoGuess(guess, pota)
  assert.equal(guess.grid, "FN31aa") // summit kept, park rejected
})

test("#185: equal-accuracy same-scope results keep the first (no thrash)", () => {
  const parkA: Located = { call: "X", source: "pota", scope: "qso", locationScope: "portable", grid: "DN60ns", locAccuracy: LOCATION_ACCURACY.REASONABLE }
  const parkB: Located = { call: "X", source: "pota", scope: "qso", locationScope: "portable", grid: "FN31aa", locAccuracy: LOCATION_ACCURACY.REASONABLE }
  let guess: CallInfo = { call: "X", locationScope: "portable" }
  guess = mergeLookupIntoGuess(guess, parkA)
  guess = mergeLookupIntoGuess(guess, parkB)
  assert.equal(guess.grid, "DN60ns")
})

test("#185: a portable ref still overrides a home QTH grid by scope, whatever its accuracy tag", () => {
  let guess: CallInfo = { call: "X", locationScope: "qth", grid: "FN21rq", city: "Home" }
  guess = mergeLookupIntoGuess(guess, pota)
  assert.equal(guess.grid, "DN60ns")
  assert.equal(guess.city, undefined) // qth city cleared by the portable takeover
})
