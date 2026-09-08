// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { adifCounty, renderRow } from "./fields.ts"

test("a field carries its own length in characters, and fields are space-separated", () => {
  assert.equal(renderRow([{ name: "CALL", value: "KI2D" }, { name: "BAND", value: "20m" }]), "<CALL:4>KI2D <BAND:3>20m ")
})

test("an empty, null or undefined value writes nothing at all", () => {
  assert.equal(renderRow([{ name: "STATE", value: undefined }, { name: "COUNTRY", value: null }, { name: "QTH", value: "" }]), "")
})

test("the first hook to name a field wins, and the later one is dropped whole", () => {
  // ADIF gives no meaning to a repeated field: an operation activating a park
  // AND a summit has two hooks answering MY_SIG, and a reader taking the
  // second would contradict the first.
  const row = renderRow([
    { name: "MY_SIG", value: "POTA" },
    { name: "MY_SIG_INFO", value: "US-0001" },
    { name: "MY_SIG", value: "SOTA" },
    { name: "MY_SIG_INFO", value: "W2/GC-001" },
  ])
  assert.equal(row, "<MY_SIG:4>POTA <MY_SIG_INFO:7>US-0001 ")
})

test("the contact's own field outranks a hook that names it later", () => {
  assert.equal(renderRow([{ name: "MODE", value: "CW" }, { name: "MODE", value: "SSB" }]), "<MODE:2>CW ")
})

test("a name a hook skipped is still free for the next one", () => {
  // The row above holds every optional field it considered, empty ones
  // included; a hook must not lose SIG_INFO to a slot nothing was written to.
  assert.equal(renderRow([{ name: "SIG_INFO", value: undefined }, { name: "SIG_INFO", value: "US-0002" }]), "<SIG_INFO:7>US-0002 ")
})

test("a name differing only in case does not get a second field", () => {
  // ADIF field names are case-insensitive, so `my_sig` from a third-party
  // extension beside a core hook's `MY_SIG` is the same field — and writing it
  // twice is the record this exists to prevent.
  assert.equal(renderRow([{ name: "MY_SIG", value: "POTA" }, { name: "my_sig", value: "SOTA" }]), "<MY_SIG:4>POTA ")
})

test("typographic quotes from a lookup are folded to ASCII", () => {
  assert.equal(renderRow([{ name: "NAME", value: "First “Nick” Last" }]), '<NAME:17>First "Nick" Last ')
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
