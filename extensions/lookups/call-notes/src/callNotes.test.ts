// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { parseCallNotes, combineNotes, customIdentifier, expansionValueFor } from "./callNotes.ts"

test("parseCallNotes: skips comments and blank lines, splits key from note", () => {
  const body = [
    "# TITLE: Hams of Note",
    "",
    "#== Ham2K =================",
    "KI2D 🤩 Sebastián - Ham2K PoLo Creator",
    "W1AW Hiram Percy Maxim Memorial Station",
  ].join("\n")
  const index = parseCallNotes(body)
  assert.deepEqual(Object.keys(index).sort(), ["KI2D", "W1AW"])
  assert.equal(index.KI2D[0].note, "🤩 Sebastián - Ham2K PoLo Creator")
  assert.equal(index.W1AW[0].note, "Hiram Percy Maxim Memorial Station")
})

test("parseCallNotes: keys shorter than 3 chars and note-less lines are dropped", () => {
  const index = parseCallNotes("AB too short a key\nK1ABC\nK2DEF kept")
  assert.deepEqual(Object.keys(index), ["K2DEF"])
})

test("parseCallNotes: repeated keys accumulate in file order, keys uppercase", () => {
  const index = parseCallNotes("vk1ao 🧑‍💻 Alan - Dev Team\nVK1AO 😁 Alan - Elmer")
  assert.equal(index.VK1AO.length, 2)
  assert.equal(index.VK1AO[0].note, "🧑‍💻 Alan - Dev Team")
  assert.equal(index.VK1AO[1].note, "😁 Alan - Elmer")
})

test("combineNotes: first entry supplies the text, all entries contribute unique marker emoji", () => {
  const combined = combineNotes([
    { call: "VK1AO", note: "🧑‍💻 Alan - Dev Team" },
    { call: "VK1AO", note: "😁 Alan - Elmer" },
    { call: "VK1AO", note: "😁 duplicate marker" },
  ])
  assert.equal(combined?.note, "🧑‍💻😁 Alan - Dev Team")
  assert.equal(combined?.emoji, "🧑‍💻")
})

test("combineNotes: marker emojis cap at 4 with a +n overflow", () => {
  const combined = combineNotes(["🤩", "😁", "👷", "🍻", "🎉", "🐶"].map((emoji, i) => ({ call: "K1ABC", note: `${emoji} note ${i}` })))
  assert.equal(combined?.note, "🤩😁👷🍻+2 note 0")
})

test("combineNotes: a note with no emoji keeps its text and has no marker", () => {
  const combined = combineNotes([{ call: "K1ABC", note: "Dan POTA Royalty" }])
  assert.equal(combined?.note, "Dan POTA Royalty")
  assert.equal(combined?.emoji, undefined)
})

test("combineNotes: a leading accented letter is text, not an emoji marker", () => {
  const combined = combineNotes([{ call: "K1ABC", note: "Ángel - friend" }])
  assert.equal(combined?.note, "Ángel - friend")
  assert.equal(combined?.emoji, undefined)
})

test("combineNotes: empty input combines to null", () => {
  assert.equal(combineNotes([]), null)
  assert.equal(combineNotes(undefined), null)
})

test("expansionValueFor: comma lists of calls are eligible, uppercased", () => {
  assert.equal(expansionValueFor([{ call: "DAN", note: "wd4dan,wd4jmm" }]), "WD4DAN,WD4JMM")
  assert.equal(expansionValueFor([{ call: "DAN", note: "WD4DAN, WD4JMM" }]), "WD4DAN, WD4JMM")
  assert.equal(expansionValueFor([{ call: "DAN", note: "WD4DAN" }]), "WD4DAN")
})

test("expansionValueFor: free-text prose disqualifies (issue #17)", () => {
  assert.equal(expansionValueFor([{ call: "K1ABC", note: "👑 James POTA King" }]), null)
  assert.equal(expansionValueFor([{ call: "K1ABC", note: "Dan POTA Royalty" }]), null)
  assert.equal(expansionValueFor([{ call: "K1ABC", note: "WD4DAN,  WD4JMM" }]), null) // two spaces
})

// A decorative leading marker (a heading OR an emoji) is stripped before the
// eligibility check, not folded into it — an entry authored with
// "## VK1GM,VK2ETI" for readability in the note display must expand the same
// as a bare "VK1GM,VK2ETI" would.
test("expansionValueFor: a leading heading OR emoji marker is stripped, not disqualifying", () => {
  assert.equal(expansionValueFor([{ call: "VK1GM", note: "## VK1GM,VK2ETI,VK2AIT" }]), "VK1GM,VK2ETI,VK2AIT")
  assert.equal(expansionValueFor([{ call: "VK1GM", note: "# VK1GM,VK2ETI" }]), "VK1GM,VK2ETI")
  assert.equal(expansionValueFor([{ call: "K1ABC", note: "🎉 K1ABC,K2DEF" }]), "K1ABC,K2DEF")
  // The remainder still has to pass EXPANDABLE — a heading over PROSE stays descriptive.
  assert.equal(expansionValueFor([{ call: "VK1GM", note: "## Canberra club roster" }]), null)
})

// Not chained: combineNotes/_noteParts only ever look for a leading emoji at
// position 0, so a note starting "## 🎉 …" would go unrecognized as marked
// there even though this function's own EXPANDABLE test would pass it if
// both markers were stripped — leaving it ineligible instead keeps "no
// expansion offered" the one answer both paths agree on for this shape.
test("expansionValueFor: a heading marker does not also strip a SECOND, emoji marker behind it", () => {
  assert.equal(expansionValueFor([{ call: "K1ABC", note: "## 🎉 K1ABC,K2DEF" }]), null)
})

test("expansionValueFor: a heading marker with no space after it is not a heading, per ATX syntax", () => {
  assert.equal(expansionValueFor([{ call: "K1ABC", note: "#K1ABC,K2DEF" }]), null)
})

test("expansionValueFor: falls through to the first eligible entry", () => {
  const value = expansionValueFor([
    { call: "DAN", note: "👑 James POTA King" },
    { call: "DAN", note: "WD4DAN,WD4JMM" },
  ])
  assert.equal(value, "WD4DAN,WD4JMM")
})

test("customIdentifier: strips scheme/punctuation into a filename-safe slug", () => {
  assert.equal(customIdentifier("https://example.com/my-club-notes.txt"), "custom-https-example-com-my-club-notes-txt-1l4nzmd")
})

test("customIdentifier: same location always derives the same identifier", () => {
  const location = "https://example.com/a.txt"
  assert.equal(customIdentifier(location), customIdentifier(location))
})

test("customIdentifier: a changed location derives a different identifier (no stale cache reuse)", () => {
  assert.notEqual(customIdentifier("https://example.com/a.txt"), customIdentifier("https://example.com/b.txt"))
})

test("customIdentifier: caps length so an absurdly long URL still makes a safe filename", () => {
  const identifier = customIdentifier(`https://example.com/${"x".repeat(200)}.txt`)
  // slug (<=60) + 'custom-' + '-' + a 32-bit hash rendered base-36 (<=7 chars)
  assert.ok(identifier.length <= "custom-".length + 60 + 1 + 7)
})

test("customIdentifier: two URLs sharing the same first 60 slug characters still get distinct identifiers", () => {
  // Differ only after character 60 — the truncated slug alone would be
  // identical for both; the hash suffix is what keeps them apart.
  const base = "https://example.com/pre-signed/" + "x".repeat(40)
  assert.notEqual(customIdentifier(`${base}/token-aaaa.txt`), customIdentifier(`${base}/token-bbbb.txt`))
})
