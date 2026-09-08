// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { adifCounty } from "./county.ts"

// The three producers of QSON `county`, none of which agree: the importer's
// country-qualified path, a lookup's bare name, and polo's ADIF-shaped one.
test("adifCounty strips the importer's country tag", () => {
  assert.equal(adifCounty("US/CT/Hartford", "CT"), "CT,Hartford")
  assert.equal(adifCounty("??/CT/Hartford", "CT"), "CT,Hartford")
})

test("adifCounty qualifies a bare county name with the state", () => {
  assert.equal(adifCounty("Hartford", "CT"), "CT,Hartford")
  // The importer's shape for a CNTY that carried no state of its own.
  assert.equal(adifCounty("US/Hartford", "CT"), "CT,Hartford")
})

// A CNTY whose primary subdivision is wrong is worse than no CNTY: the reader
// files the contact under a state the operator never claimed.
test("adifCounty drops a county it cannot qualify", () => {
  assert.equal(adifCounty("Hartford", undefined), undefined)
  assert.equal(adifCounty("Hartford", ""), undefined)
  assert.equal(adifCounty(undefined, "CT"), undefined)
  assert.equal(adifCounty("   ", "CT"), undefined)
})

// A scheme with no country tag of its own — the importer writes Puerto Rico's
// counties this way, and `PR` must not be mistaken for one and stripped.
test("adifCounty keeps a leading segment that is a real primary subdivision", () => {
  assert.equal(adifCounty("PR/Arecibo", "PR"), "PR,Arecibo")
  // With no state to check it against, the importer's structure is all there is.
  assert.equal(adifCounty("PR/Arecibo", undefined), "PR,Arecibo")
})

test("adifCounty recognises ADIF's own shape", () => {
  assert.equal(adifCounty("CT,Hartford", "CT"), "CT,Hartford")
})

// The operator's county field is free text, so punctuation in it means
// nothing on its own. Promoting a segment because a comma preceded it writes
// `<CNTY>Hartford, CT` beside `<STATE>CT` — one record naming two different
// primary subdivisions, one of them a county, and the file says nothing.
test("adifCounty does not let punctuation promote a county to a state", () => {
  assert.equal(adifCounty("Hartford, CT", "CT"), "CT,Hartford")
  assert.equal(adifCounty("St. Louis City, MO", "MO"), "MO,St. Louis City")
})

// A county carrying a state the record does not claim describes somewhere the
// operator does not say they were. Gluing it to the record's own state invents
// a county ("MA,CT Hartford"); writing it under its own contradicts STATE.
// Neither is true, so nothing is written.
test("adifCounty drops a county belonging to a state the record does not claim", () => {
  assert.equal(adifCounty("CT,Hartford", "MA"), undefined)
  // The same shape the importer stores for a log made somewhere else.
  assert.equal(adifCounty("US/CA/Marin", "NY"), undefined)
  // Whichever end the state was written at.
  assert.equal(adifCounty("Hartford, CT", "MA"), undefined)
  assert.equal(adifCounty("St. Louis City, MO", "NY"), undefined)
})

// A county LINE is two counties and ADIF's CNTY holds one, so there is no
// true answer to give. Nor can it be told from `US/CA/Marin` without a table
// of subdivision codes — and `Bee`, `Lee` and `Ida` are real counties shaped
// exactly like one, so such a table would have to be a real table.
test("adifCounty drops a value it cannot reduce to one county of this state", () => {
  assert.equal(adifCounty("Deschutes/Jefferson", "OR"), undefined)
  assert.equal(adifCounty("Bee/Live Oak", "TX"), undefined)
})

test("a county code keeps only its state and county, whatever country qualified it", () => {
  // The importer's own shape (`adif_to_qson.dart`): CNTY has no country in
  // it, so a code written back verbatim would name a county no program can
  // find.
  assert.equal(adifCounty("US/NY/Kings", "NY"), "NY,Kings")
  assert.equal(adifCounty("??/ON/Bruce", undefined), "ON,Bruce")
})

test("a plain county name takes the contact's own state, and writes nothing without one", () => {
  // A lookup answers with a bare name (`normalizeGuess.ts`), and so does an
  // operator typing into the More pane. CNTY without its state is not a
  // county to anything reading the file — better absent than half-answered.
  assert.equal(adifCounty("Hartford", "CT"), "CT,Hartford")
  assert.equal(adifCounty("Hartford", ""), undefined)
  assert.equal(adifCounty("Hartford", undefined), undefined)
  assert.equal(adifCounty("  ", "CT"), undefined)
  assert.equal(adifCounty(undefined, "CT"), undefined)
})

test("a two-segment county tells a state qualifier from a country one", () => {
  // The importer produces both: `PR/Ponce` where the first segment is the
  // state, and `US/Hartford` from a CNTY that arrived with no comma, where it
  // is the country and no state was ever stated. `US,Hartford` names nothing.
  assert.equal(adifCounty("PR/Ponce", undefined), "PR,Ponce")
  assert.equal(adifCounty("US/Hartford", undefined), undefined)
  assert.equal(adifCounty("US/Hartford", "CT"), "CT,Hartford")
  assert.equal(adifCounty("??/Hartford", "CT"), "CT,Hartford")
})
