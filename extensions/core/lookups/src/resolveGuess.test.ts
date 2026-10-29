// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { resolveGuess, storedGuessLookup } from "./resolveGuess.ts"
import type { CallInfoLookup } from "@ham2k/extension-sdk"

// What QRZ files for a station registered in Rhode Island: a town and the
// coordinate of the address.
const qrz = (call: string, extra: Record<string, unknown> = {}): CallInfoLookup =>
  ({
    call,
    source: "qrz.com",
    scope: "general",
    name: "Jim",
    city: "Kingston",
    state: "RI",
    grid: "FN41gk",
    lat: 41.44783,
    lon: -71.476222,
    ...extra,
  }) as CallInfoLookup

const located = (guess: Record<string, unknown>) => ({ grid: guess.grid, lat: guess.lat, lon: guess.lon, city: guess.city, state: guess.state })

// The operator typing a different state is saying the lookup's address is not
// where the station is; keeping its square would put it back there.
test("an entered state that disagrees with the lookup takes the lookup's whole location away", () => {
  const guess = resolveGuess("KE1J", [qrz("KE1J")], { their: { call: "KE1J", state: "ME" } }) as Record<string, unknown>
  assert.deepEqual(located(guess), { grid: undefined, lat: undefined, lon: undefined, city: undefined, state: "ME" })
  assert.equal(guess.name, "Jim", "only the location is overruled")
})

// Typing the state the lookup already named confirms it — throwing its square
// away there would lose precision for nothing.
test("an entered state that matches the lookup keeps the lookup's location", () => {
  for (const state of ["RI", " ri "]) {
    const guess = resolveGuess("KE1J", [qrz("KE1J")], { their: { call: "KE1J", state } }) as Record<string, unknown>
    assert.equal(guess.grid, "FN41gk")
    assert.equal(guess.lat, 41.44783)
  }
})

test("an entered state beside a lookup that names no state keeps the lookup's square", () => {
  const guess = resolveGuess("KE1J", [qrz("KE1J", { state: undefined, city: undefined })], { their: { call: "KE1J", state: "ME" } }) as Record<string, unknown>
  assert.equal(guess.grid, "FN41gk")
  assert.equal(guess.state, "ME")
})

// A coordinate outranks a grid everywhere it is read, so a lookup coordinate
// left beside an entered square would quietly win over it.
test("an entered grid replaces the lookup's square and drops its coordinate; an entered coordinate wins over both", () => {
  const byGrid = resolveGuess("KE1J", [qrz("KE1J")], { their: { call: "KE1J", grid: "FN54" } }) as Record<string, unknown>
  assert.equal(byGrid.grid, "FN54")
  assert.equal(byGrid.lat, undefined)
  assert.equal(byGrid.lon, undefined)
  assert.equal(byGrid.state, "RI", "a square alone does not contradict the state")

  const byPair = resolveGuess("KE1J", [qrz("KE1J")], { their: { call: "KE1J", lat: 44.3, lon: -69.8 } }) as Record<string, unknown>
  assert.deepEqual([byPair.lat, byPair.lon, byPair.grid], [44.3, -69.8, "FN54ch"])
})

test("a country-file centroid on `their` is not an entered coordinate", () => {
  const guess = resolveGuess("KE1J", [qrz("KE1J")], { their: { call: "KE1J", lat: 37.5, lon: -91.6, locSource: "prefix" } }) as Record<string, unknown>
  assert.equal(guess.grid, "FN41gk")
})

// A portable, mobile or relocated station is not at its registered address,
// whatever a source that only knows the license says.
test("a portable call, or one with a call-area digit, keeps the lookup's name but not its address", () => {
  for (const call of ["KE1J/P", "KE1J/M", "KE1J/MM", "KE1J/4"]) {
    // The full call resolving (QRZ answers for KE1J/P with KE1J's record) is
    // exactly the case a source's own scope bookkeeping lets through.
    const guess = resolveGuess(call, [qrz(call, { locationScope: "portable" })], { their: { call } }) as Record<string, unknown>
    assert.equal(guess.name, "Jim", call)
    assert.deepEqual(located(guess), { grid: undefined, lat: undefined, lon: undefined, city: undefined, state: undefined }, call)
  }
})

// app-polo's rule: a profile filed under the full prefixed call is about that
// operation; the base call's is about home.
test("a prefixed call keeps a location only from a source that answered for the full call", () => {
  const full = resolveGuess(
    "EA3/KE1J",
    [qrz("EA3/KE1J", { locationScope: "prefixed", city: "Barcelona", state: undefined, grid: "JN11cj", lat: 41.4, lon: 2.17 })],
    {
      their: { call: "EA3/KE1J" },
    },
  ) as Record<string, unknown>
  assert.equal(full.grid, "JN11cj")

  const fallback = resolveGuess("EA3/KE1J", [qrz("KE1J", { locationScope: "prefixed" })], { their: { call: "EA3/KE1J" } }) as Record<string, unknown>
  assert.equal(fallback.name, "Jim")
  assert.equal(fallback.grid, undefined)
  assert.equal(fallback.city, undefined)
})

// A park or summit is where the station is. The ref must place it even when
// no source answered for it — offline, or a program with no lookup of its own.
test("a reference with a location replaces the callsign lookup's address, with or without a source answering for it", () => {
  const byRef = resolveGuess("KE1J", [qrz("KE1J")], {
    their: { call: "KE1J" },
    refs: [{ type: "wwff", ref: "KFF-1234", grid: "FN44", lat: 44.5, lon: -68.5 }],
  }) as Record<string, unknown>
  assert.deepEqual([byRef.lat, byRef.lon, byRef.city], [44.5, -68.5, undefined])
  assert.equal(byRef.name, "Jim")

  const pota: CallInfoLookup = { call: "KE1J", source: "pota", scope: "qso", locationScope: "portable", grid: "FN44ab", locAccuracy: 300 } as CallInfoLookup
  const byPota = resolveGuess("KE1J", [qrz("KE1J"), pota], { their: { call: "KE1J" }, refs: [{ type: "pota", ref: "US-0001" }] }) as Record<string, unknown>
  assert.deepEqual(located(byPota), { grid: "FN44ab", lat: undefined, lon: undefined, city: undefined, state: undefined })
})

test("a large-area reference keeps the station off the callsign's address but does not place it", () => {
  const guess = resolveGuess("KE1J", [qrz("KE1J")], {
    their: { call: "KE1J" },
    refs: [{ type: "pota", ref: "US-4567", grid: "FN44", lat: 44.5, lon: -68.5, largeArea: true }],
  }) as Record<string, unknown>
  assert.deepEqual(located(guess), { grid: undefined, lat: undefined, lon: undefined, city: undefined, state: undefined })
})

// A contest's ref (a serial, a section) names no place, and must not cost a
// contest log every location its lookups found.
test("a reference with no location leaves the callsign lookup's address standing", () => {
  const guess = resolveGuess("KE1J", [qrz("KE1J")], { their: { call: "KE1J" }, refs: [{ type: "naqp" }] }) as Record<string, unknown>
  assert.equal(guess.grid, "FN41gk")
})

// The guess written elsewhere is the only record of what the lookup said once
// HaLo has overlaid it; filed as a lookup, clearing the entry brings it back.
test("a stored guess filed as a lookup settles the same way, and restores the lookup when the entry is cleared", () => {
  const stored = storedGuessLookup({ call: "KE1J", name: "Jim", state: "RI", grid: "FN41gk", lat: 41.44783, lon: -71.476222 })
  const corrected = resolveGuess("KE1J", [stored], { their: { call: "KE1J", state: "ME" } }) as Record<string, unknown>
  assert.equal(corrected.grid, undefined)
  const cleared = resolveGuess("KE1J", [stored], { their: { call: "KE1J" } }) as Record<string, unknown>
  assert.equal(cleared.grid, "FN41gk")
  assert.equal(cleared.state, "RI")
})

// Where a reference is, and which state it lies in, replaces the callsign
// lookup's home address — the state too, or a park contact leaves the export
// with no STATE and state awards with nothing to count.
test("a reference's program answer and the reference itself each place the station, state included", () => {
  const potaRef = { type: "pota", ref: "US-0001" }
  const pota = (extra: Record<string, unknown>) => ({ call: "KE1J", source: "pota", scope: "qso", locationScope: "portable", ...extra }) as CallInfoLookup

  const oneState = resolveGuess("KE1J", [qrz("KE1J"), pota({ grid: "FN44ab", state: "ME", locAccuracy: 300 })], { their: { call: "KE1J" }, refs: [potaRef] })
  assert.deepEqual(located(oneState as Record<string, unknown>), { grid: "FN44ab", lat: undefined, lon: undefined, city: undefined, state: "ME" })

  const stateOnly = resolveGuess("KE1J", [qrz("KE1J"), pota({ state: "ME" })], { their: { call: "KE1J" }, refs: [potaRef] })
  assert.deepEqual(located(stateOnly as Record<string, unknown>), { grid: undefined, lat: undefined, lon: undefined, city: undefined, state: "ME" })

  const refWithState = resolveGuess("KE1J", [qrz("KE1J")], { their: { call: "KE1J" }, refs: [{ type: "wwff", ref: "KFF-1234", grid: "FN44", state: "ME" }] })
  assert.deepEqual(located(refWithState as Record<string, unknown>), { grid: "FN44", lat: undefined, lon: undefined, city: undefined, state: "ME" })

  const refStateOnly = resolveGuess("KE1J", [qrz("KE1J")], { their: { call: "KE1J" }, refs: [{ type: "wwff", ref: "KFF-1234", state: "ME" }] })
  assert.deepEqual(located(refStateOnly as Record<string, unknown>), { grid: undefined, lat: undefined, lon: undefined, city: undefined, state: "ME" })
})

// A park across several states is one point standing for all of it: placing
// the station there would claim a square, and a state, nobody knows.
test("a park spanning several states keeps the station off its callsign address and places it nowhere", () => {
  const multiState = { call: "KE1J", source: "pota", scope: "qso", locationScope: "portable", grid: "FN44ab", locAccuracy: 300 } as CallInfoLookup

  // The decorated ref says so…
  const byRef = resolveGuess("KE1J", [qrz("KE1J"), multiState], {
    their: { call: "KE1J" },
    refs: [{ type: "pota", ref: "US-4567", grid: "FN44", largeArea: true }],
  }) as Record<string, unknown>
  assert.deepEqual(located(byRef), { grid: undefined, lat: undefined, lon: undefined, city: undefined, state: undefined })
  assert.equal(byRef.largeArea, undefined, "the flag is about the answer, not a field of the guess")

  // …or, for a ref no one decorated (a spot's), the program's answer does.
  const byAnswer = resolveGuess(
    "KE1J",
    [qrz("KE1J"), { call: "KE1J", source: "pota", scope: "qso", locationScope: "portable", largeArea: true } as CallInfoLookup],
    {
      their: { call: "KE1J" },
      refs: [{ type: "pota", ref: "US-4567" }],
    },
  ) as Record<string, unknown>
  assert.deepEqual(located(byAnswer), { grid: undefined, lat: undefined, lon: undefined, city: undefined, state: undefined })
  assert.equal(byAnswer.name, "Jim")

  // An entered state still says where in it.
  const entered = resolveGuess("KE1J", [qrz("KE1J"), multiState], {
    their: { call: "KE1J", state: "NH" },
    refs: [{ type: "pota", ref: "US-4567", largeArea: true }],
  }) as Record<string, unknown>
  assert.equal(entered.state, "NH")
  assert.equal(entered.grid, undefined)
})

// A VHF contest files its grid exchange on `refs` as `{type, grid}` — the
// lookup's own grid, prefilled. Counted as a reference, it would strip the
// lookup's state from every contest contact and overrule the very answer it
// was copied from.
test("a contest exchange carried on refs is not a reference, and leaves the lookup standing", () => {
  const guess = resolveGuess("KE1J", [qrz("KE1J")], { their: { call: "KE1J" }, refs: [{ type: "arrl-vhf-tests", grid: "FN41" }] }) as Record<string, unknown>
  assert.equal(guess.grid, "FN41gk")
  assert.equal(guess.state, "RI")
})

// A stored POTA answer outlives the park it was about until the next lookup;
// replayed after the ref is removed, it would keep the station in that park.
test("an answer for a reference the contact no longer has places nothing", () => {
  const pota = { call: "KE1J", source: "pota", scope: "qso", locationScope: "portable", grid: "FN44ab", state: "ME", locAccuracy: 300 } as CallInfoLookup
  const guess = resolveGuess("KE1J", [qrz("KE1J"), pota], { their: { call: "KE1J" }, refs: [] }) as Record<string, unknown>
  assert.equal(guess.grid, "FN41gk")
  assert.equal(guess.state, "RI")
})

// A guess written by app-polo was settled there: a `/P` chase's summit square
// in it is the summit's, not a callbook address. Run through the away rules
// again, it would lose the summit for the country's middle.
test("a stored guess keeps its location on a portable call; only an entered state overrules it", () => {
  const stored = storedGuessLookup({ call: "W7ABC/P", name: "Ann", grid: "CN85lm" })
  const qso = { their: { call: "W7ABC/P" }, refs: [{ type: "sota", ref: "W7O/CN-001" }] }
  assert.equal((resolveGuess("W7ABC/P", [stored], qso) as Record<string, unknown>).grid, "CN85lm")

  const corrected = storedGuessLookup({ call: "KE1J", state: "RI", grid: "FN41gk" })
  assert.equal((resolveGuess("KE1J", [corrected], { their: { call: "KE1J", state: "ME" } }) as Record<string, unknown>).grid, undefined)
})
