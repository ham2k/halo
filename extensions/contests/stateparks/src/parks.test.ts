// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The park-resolution contract, tested where it lives rather than through the
// scorer that consumes it — because the whole reason this module exists is that
// the scorer and the exports each had their own answer and the two disagreed.
// A test here is a test of what BOTH will do.

import { test } from "node:test"
import assert from "node:assert/strict"

import { eventFor } from "./events.ts"
import { configuredOurPark, ourParkAbbreviation, ourParkRefs, theirParkAbbreviation, theirParkRefs, theirParkWasDecided } from "./parks.ts"

const OHSP = eventFor("OHSP")!
const TXSP = eventFor("TXSP")!

// Ohio: ADA = US-1932, ALU = US-1933, HOC = US-1958.
const qso = (refs: Record<string, unknown>[]) => ({ their: { call: "K1ABC" }, refs }) as never
const operation = (refs: Record<string, unknown>[]) => ({ uuid: "op", refs }) as never

test("what the operator typed is the park of record, over any reference on the QSO", () => {
  // The case that used to split: the scorer read the POTA reference and the
  // Cabrillo read the typed abbreviation, so the app claimed a multiplier for a
  // park the submitted log never mentioned.
  const both = qso([
    { type: "pota", ref: "US-1933" },
    { type: "stateparks", park: "ADA" },
  ])
  assert.equal(theirParkAbbreviation(OHSP, both), "ADA")
  assert.deepEqual(theirParkRefs(OHSP, both), ["US-1932"], "the typed park, not the hunted reference")
})

test("a park reference answers for a station who sent nothing", () => {
  const hunted = qso([{ type: "pota", ref: "US-1958" }])
  assert.equal(theirParkAbbreviation(OHSP, hunted), "HOC")
  assert.deepEqual(theirParkRefs(OHSP, hunted), ["US-1958"])

  // A POTA two-fer is still ONE Ohio contact. The two programs' exchanges are
  // independent: OHSP's exchange is a single abbreviation, and the sponsor's park
  // list is a subset of POTA with no multi-reference location in it, so no station
  // can be at two of Ohio's parks at once and a second POTA reference is never a
  // second state-park claim.
  const twofer = qso([
    { type: "pota", ref: "US-1958" },
    { type: "pota", ref: "US-1933" },
  ])
  assert.deepEqual(theirParkRefs(OHSP, twofer), ["US-1958"])

  // Parks outside the event are somebody else's activity.
  assert.deepEqual(theirParkRefs(OHSP, qso([{ type: "pota", ref: "US-0001" }])), [])
})

test("an exchange the operator DECIDED is honoured, blank or wrong", () => {
  // Emptied on purpose: the core writes `park: ''`, and nothing may put a park
  // back from the QSO's references — not on screen, and not in the file they
  // submit.
  const cleared = qso([
    { type: "pota", ref: "US-1958" },
    { type: "stateparks", park: "" },
  ])
  assert.equal(theirParkWasDecided(cleared), true)
  assert.equal(theirParkAbbreviation(OHSP, cleared), "")
  assert.deepEqual(theirParkRefs(OHSP, cleared), [])

  // Typed something this event doesn't have: they told us what they heard, and it
  // claims no park. Falling back to the reference would credit a park they just
  // said they weren't in.
  const wrong = qso([
    { type: "pota", ref: "US-1958" },
    { type: "stateparks", park: "ZZZ" },
  ])
  assert.equal(theirParkAbbreviation(OHSP, wrong), "ZZZ")
  assert.deepEqual(theirParkRefs(OHSP, wrong), [])

  // Never filled in at all is NOT a decision — the key is absent.
  const untouched = qso([{ type: "pota", ref: "US-1958" }])
  assert.equal(theirParkWasDecided(untouched), false)
  assert.deepEqual(theirParkRefs(OHSP, untouched), ["US-1958"])
})

test("an event with NO exchange counts every park of theirs — there is no list to be a subset of", () => {
  // Texas has no abbreviation to type, so a genuine park-to-park pair is a
  // contact for each park.
  const twofer = qso([
    { type: "pota", ref: "US-2984" },
    { type: "pota", ref: "US-2985" },
  ])
  assert.deepEqual(theirParkRefs(TXSP, twofer), ["US-2984", "US-2985"])
})

test("an event with no exchange reads its parks from the references alone", () => {
  // Texas has no abbreviation to type, so a stray `park` key — synced from an
  // Ohio operation, say — must not stop its POTA references counting.
  const texas = qso([
    { type: "pota", ref: "US-2984" },
    { type: "stateparks", park: "ADA" },
  ])
  assert.deepEqual(theirParkRefs(TXSP, texas), ["US-2984"])
})

test("our park is the POTA activation, with the setup field as a FALLBACK", () => {
  const activating = operation([
    { type: "stateparks", ref: "OHSP", ourPark: "ADA" },
    { type: "potaActivation", ref: "US-1933" },
  ])
  // The activation wins and is the ONLY park: adding the setup value doubled
  // every QSO's points and invented a second activated park.
  assert.deepEqual(ourParkRefs(OHSP, activating), ["US-1933"])

  const noPota = operation([{ type: "stateparks", ref: "OHSP", ourPark: "HOC" }])
  assert.deepEqual(ourParkRefs(OHSP, noPota), ["US-1958"], "someone running the event without POTA")

  // Two parks at once still both count — a genuine n-fer, from references.
  const nfer = operation([
    { type: "potaActivation", ref: "US-1933" },
    { type: "potaActivation", ref: "US-1958" },
  ])
  assert.deepEqual(ourParkRefs(OHSP, nfer), ["US-1933", "US-1958"])

  // An activation outside the event isn't this contest's park.
  assert.deepEqual(ourParkRefs(OHSP, operation([{ type: "potaActivation", ref: "US-0001" }])), [])
})

test("a park left behind by another event is not read as this one’s", () => {
  // A hidden `visibleWhen` field still submits, so switching an operation from
  // Ohio to Texas leaves Ohio's `ourPark` on the ref. It must not label a Texas
  // operation, and must not score as a Texas park.
  const switched = operation([{ type: "stateparks", ref: "TXSP", ourPark: "ADA" }])
  assert.equal(configuredOurPark(TXSP, switched), "")
  assert.equal(ourParkAbbreviation(TXSP, switched), "")
  assert.deepEqual(ourParkRefs(TXSP, switched), [])

  // Still Ohio's, read as Ohio's.
  assert.equal(configuredOurPark(OHSP, operation([{ type: "stateparks", ref: "OHSP", ourPark: "ADA" }])), "ADA")
})

test("a scorer reads the ref it was HANDED, which on a segmented log is the segment’s", () => {
  // `scoreQso` is given the ref that selected it. Passing it explicitly is what
  // keeps a segment's own setup authoritative over the base operation's.
  const base = operation([{ type: "stateparks", ref: "OHSP", ourPark: "ADA" }])
  const segmentRef = { type: "stateparks", ref: "OHSP", ourPark: "HOC" }
  assert.equal(ourParkAbbreviation(OHSP, base), "ADA")
  assert.equal(ourParkAbbreviation(OHSP, base, segmentRef as never), "HOC")
  assert.deepEqual(ourParkRefs(OHSP, base, segmentRef as never), ["US-1958"])
})

test("our abbreviation prefers the setup value, then the activation’s own park", () => {
  assert.equal(ourParkAbbreviation(OHSP, operation([{ type: "potaActivation", ref: "US-1958" }])), "HOC")
  assert.equal(ourParkAbbreviation(OHSP, operation([])), "")
  // Texas has no abbreviations at all, so there is nothing to show.
  assert.equal(ourParkAbbreviation(TXSP, operation([{ type: "potaActivation", ref: "US-2984" }])), "")
})
