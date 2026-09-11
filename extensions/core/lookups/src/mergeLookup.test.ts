// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { mergeLookupIntoGuess, runLookupPipeline } from "./mergeLookup.ts"
import type { CallInfo, CallInfoLookup } from "@ham2k/extension-sdk"
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

test("a grid-only result stores a grid and no coordinate", () => {
  // The square's centre would be a coordinate no source reported, and a
  // coordinate outranks a grid everywhere it is read
  // (docs/design/locations.md) — so every reader would measure from, and
  // every export would state, a point invented in the merge. Nothing needs
  // it: the resolvers fall through to the grid on their own.
  const withGridOnly = mergeLookupIntoGuess({ call: "X" }, { call: "X", source: "a", scope: "general", grid: "FN21rq" })
  assert.equal(withGridOnly.grid, "FN21rq")
  assert.equal(withGridOnly.lat, undefined)
  assert.equal(withGridOnly.lon, undefined)
})

test("a grid a decoder cannot place is dropped on its own, not with the result around it", () => {
  // HamDB sent the literal "NOT_FOUND" before it started filtering. The whole
  // result must survive it: the name and city in the same record are good,
  // and only the grid is junk.
  const withJunkGrid = mergeLookupIntoGuess(
    { call: "X" },
    { call: "X", source: "a", scope: "general", grid: "NOT_FOUND", city: "Newington" },
  )
  assert.equal(withJunkGrid.grid, undefined)
  assert.equal(withJunkGrid.city, "Newington")
})

test("a lat/lon-only result still derives a 6-digit grid, and a result giving both is taken verbatim", () => {
  // The other direction stays: a grid derived from a real coordinate states
  // the square that coordinate is actually in, which invents nothing.
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

test("a pinless result's town lands only on a guess with no location at all — it neither replaces nor completes an established town or pin", () => {
  // Established pin: the city-only result contributes nothing (deleting the
  // pin for it — a vaguer answer destroying a precise one — is the trap).
  const withPin = mergeLookupIntoGuess({ call: "X", grid: "FN21rq", lat: 41.5, lon: -74.5 }, { call: "X", source: "a", scope: "general", city: "New City" })
  assert.equal(withPin.grid, "FN21rq")
  assert.equal(withPin.city, undefined)

  // Established town: a second pinless town must not complete it per-field —
  // filling only the empty state slot would put b's state under a's city.
  // Its country is refused with the rest of its group, though country counts
  // as neither town nor pin on the landing side.
  const withTown = mergeLookupIntoGuess({ call: "X", city: "Springfield" }, { call: "X", source: "b", scope: "general", city: "Shelbyville", state: "TX", country: "Canada" })
  assert.equal(withTown.city, "Springfield")
  assert.equal(withTown.state, undefined)
  assert.equal(withTown.country, undefined)

  // Unlocated ground — an entity-level country alone doesn't count: lands.
  const onEmpty = mergeLookupIntoGuess({ call: "X", country: "United States" }, { call: "X", source: "c", scope: "general", city: "Newington", state: "CT" })
  assert.equal(onEmpty.city, "Newington")
  assert.equal(onEmpty.state, "CT")
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

test("`online` never leaks into the merged guess — it's meta about the result, not a guessable field", () => {
  // The background lookup queue (lookup_queue_service.dart) reads `online`
  // straight off the stored `lookups[]` entries to decide whether a QSO
  // already has a real network answer. Were this field ever folded into
  // `guess` like an ordinary property, it would show up as a stray key on
  // exported/synced QSON.
  const guess: CallInfo = { call: "X" }
  const result = { call: "X", source: "qrz.com", scope: "general", name: "Someone", online: true } as CallInfoLookup & {
    online?: boolean
  }
  const { guess: after, lookups } = runLookupPipeline(guess, [result])
  assert.equal((after as Record<string, unknown>).online, undefined)
  // But it DOES survive on the raw per-source record, same as notes/history —
  // that's what the queue actually reads.
  assert.equal((lookups[0] as Record<string, unknown>).online, true)
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

test("regression: free-tier QRZ (town, no pin) then the Ham2K service — the pin-bearing record takes over the whole location", () => {
  // Free-tier QRZ answers name/city/state/country but no grid or lat/lon.
  // Without the pin takeover, the service's grid write either wipes the
  // established town (clearing keyed on written fields — the guess collapses
  // to flag+name+grid) or leaves QRZ's town sitting under the service's pin;
  // instead the service's own town/county/pin replace QRZ's town together.
  const qrzFree: CallInfoLookup = { call: "X", source: "qrz.com", scope: "general", locationScope: "qth", name: "Some Op", location: "Newington, CT", city: "Newington", state: "CT", country: "United States" }
  const ham2k: CallInfoLookup = { call: "X", source: "services.ham2k.net", scope: "general", locationScope: "qth", name: "SOME OP", location: "Newington, CT", city: "Newington", state: "CT", county: "Hartford", country: "United States", grid: "FN31pr", lat: 41.71, lon: -72.72 }

  // The initial guess carries the annotation's entity-level country — which
  // must not count as "already located" and block QRZ's pinless town.
  const { guess } = runLookupPipeline({ call: "X", locationScope: "qth", country: "United States" }, [qrzFree, ham2k])
  assert.equal(guess.city, "Newington")
  assert.equal(guess.state, "CT")
  assert.equal(guess.country, "United States")
  assert.equal(guess.location, "Newington, CT")
  assert.equal(guess.county, "Hartford")
  assert.equal(guess.grid, "FN31pr")
  assert.equal(guess.name, "Some Op") // non-location field: first-wins, untouched by the takeover
})

test("a pin-bearing result replaces a pinless established town wholesale, even where per-field first-wins would keep it", () => {
  // Per-field first-wins would keep Springfield and accept only the grid,
  // labeling source b's pin with source a's town.
  let guess: CallInfo = { call: "X", locationScope: "qth" }
  guess = mergeLookupIntoGuess(guess, { call: "X", source: "a", scope: "general", locationScope: "qth", city: "Springfield", state: "IL", country: "United States" })
  guess = mergeLookupIntoGuess(guess, { call: "X", source: "b", scope: "general", locationScope: "qth", grid: "FN31pr", city: "Newington", state: "CT" })
  assert.equal(guess.city, "Newington")
  assert.equal(guess.state, "CT")
  assert.equal(guess.grid, "FN31pr")
  assert.equal(guess.country, undefined) // b carries none — a's town went with a's country
})

test("a result whose own pin loses to an established one contributes no location fields — its town describes the pin that lost", () => {
  // Accepting the city here would put a Dallas label on a Connecticut pin.
  let guess: CallInfo = { call: "X", locationScope: "qth" }
  guess = mergeLookupIntoGuess(guess, { call: "X", source: "a", scope: "general", locationScope: "qth", grid: "FN31pr" })
  guess = mergeLookupIntoGuess(guess, { call: "X", source: "b", scope: "general", locationScope: "qth", grid: "EM12ab", city: "Dallas", state: "TX" })
  assert.equal(guess.grid, "FN31pr")
  assert.equal(guess.city, undefined)
  assert.equal(guess.state, undefined)
})

test("the takeover respects the accuracy lock — a vaguer pin-bearing result must not clear a locked pinless location", () => {
  // The group clear runs on the promise the per-field loop refills it; a
  // locked result writes nothing, so a bad guard here erases the location
  // outright instead of leaving it alone.
  const guess = { call: "X", locationScope: "portable", location: "W2/GC-001 Summit", locAccuracy: LOCATION_ACCURACY.ACCURATE } as CallInfo
  const merged = mergeLookupIntoGuess(guess, { call: "X", source: "qrz.com", scope: "general", locationScope: "portable", grid: "EM64mn", city: "Hartselle" })
  assert.equal(merged.location, "W2/GC-001 Summit")
  assert.equal(merged.grid, undefined)
  assert.equal(merged.city, undefined)
})

test("the takeover respects scope — a qth-scoped pin-bearing result must not clear a portable pinless location", () => {
  // Same trap as the accuracy lock: the clear must be gated by the same
  // conditions that gate the writes, or it clears for writes that never come.
  const guess: CallInfo = { call: "X", locationScope: "portable", location: "US-1 Park" }
  const merged = mergeLookupIntoGuess(guess, { call: "X", source: "qrz.com", scope: "general", locationScope: "qth", grid: "FN21rq", city: "Woodridge" })
  assert.equal(merged.location, "US-1 Park")
  assert.equal(merged.grid, undefined)
  assert.equal(merged.city, undefined)
})

test("a junk grid grants no takeover authority — an invalid pin degrades its result to the pinless rules", () => {
  // "NOT_FOUND" passes a presence check and fails gridToLocation. Judged a
  // pin by presence, it wipes the established town, installs the junk
  // source's own, and then delivers no pin at all.
  const guess: CallInfo = { call: "X", city: "Springfield", state: "IL" }
  const merged = mergeLookupIntoGuess(guess, { call: "X", source: "b", scope: "general", grid: "NOT_FOUND", city: "Dallas", state: "TX" })
  assert.equal(merged.city, "Springfield")
  assert.equal(merged.state, "IL")
  assert.equal(merged.grid, undefined)
})

test("half a lat/lon pair is not a pin", () => {
  // A lone lat places nothing, so it must earn its result no takeover or
  // blocking authority — the pinless rules apply.
  const merged = mergeLookupIntoGuess({ call: "X", city: "Springfield" }, { call: "X", source: "b", scope: "general", lat: 41.5, city: "Dallas" })
  assert.equal(merged.city, "Springfield")
  assert.equal(merged.lat, undefined)
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

test("#185: a home lookup that INHERITED the portable scope can't thrash away a POTA park's grid/location", () => {
  // The real-world failure: POTA sets a park grid+location at portable scope
  // (clearing city/state it didn't supply); QRZ/HamDB then resolve the home
  // call and inherit that portable scope, so they're same-scope and — without
  // the accuracy lock — fill the empty city/state, which the grid/city
  // reconciliation thrashes into deleting the park grid and location.
  const results: Located[] = [
    { call: "W1WC", source: "callsign-annotation", scope: "general", locationScope: "qth", entityPrefix: "K" },
    { call: "W1WC", source: "call-notes", scope: "general", name: "Some Op" },
    { call: "W1WC", source: "pota", scope: "qso", locationScope: "portable", grid: "FN41bb", location: "US-2005 US-NY Amsterdam Beach State Park", locAccuracy: LOCATION_ACCURACY.REASONABLE },
    { call: "W1WC", source: "qrz.com", scope: "general", locationScope: "portable", grid: "EM64mn", city: "Hartselle", state: "AL", location: "Hartselle, AL" },
    { call: "W1WC", source: "hamdb.org", scope: "general", locationScope: "portable", grid: "EM64mn", city: "Hartselle", state: "AL" },
  ]
  const { guess } = runLookupPipeline({ call: "W1WC" }, results)
  assert.equal(guess.grid, "FN41bb")
  assert.equal(guess.location, "US-2005 US-NY Amsterdam Beach State Park")
  assert.equal(guess.name, "Some Op") // non-location fields still merge normally
})
