// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import { test } from "node:test"
import assert from "node:assert/strict"

import { normalizeGuess, normalizeName } from "./normalizeGuess.ts"
import type { CallInfo } from "@ham2k/extension-sdk"

test("an all-caps name is recapitalized, reordered, and keeps its acronyms", () => {
  assert.equal(normalizeName("DELMONT, SEBASTIAN"), "Sebastian Delmont")
  assert.equal(normalizeName("ARRL HEADQUARTERS"), "ARRL Headquarters")
  assert.equal(normalizeName("JOHN MCMILLAN"), "John McMillan")
})

test("a name that already carries capitalization is reordered but never recapitalized", () => {
  // The trap: recapitalizing here would "fix" Mcmillan into McMillan against
  // the source's own spelling — and would break every deLuca and van Dyke.
  assert.equal(normalizeName("Mcmillan, John"), "John Mcmillan")
  assert.equal(normalizeName("Sebastian deLmont"), "Sebastian deLmont")
})

test("only a two-part comma split is a Last, First — anything else keeps its order", () => {
  assert.equal(normalizeName("SMITH, JOHN, ACME"), "Smith, John, Acme")
  assert.equal(normalizeName("SMITH,"), "Smith,")
})

test("a suffix after the last comma goes on the end, whichever order the name is in", () => {
  // Flipped at the suffix's comma instead, the QRZ name reads "Jr Oscar A Curtis".
  assert.equal(normalizeName("OSCAR A CURTIS, JR"), "Oscar A Curtis Jr") // QRZ
  assert.equal(normalizeName("CURTIS, OSCAR A, JR"), "Oscar A Curtis Jr") // Ham2K lookup
  assert.equal(normalizeName("OSCAR A CURTIS, JR ."), "Oscar A Curtis Jr") // Callook
  assert.equal(normalizeName("Wingenter, Ronald C, III"), "Ronald C Wingenter III")
  assert.equal(normalizeName("SMITH, JOHN, MD"), "John Smith, MD")
  assert.equal(normalizeName("SMITH, JOHN, JR, MD"), "John Smith Jr, MD")
  assert.equal(normalizeName("Hill, Mr. Matthew H"), "Mr. Matthew H Hill")
})

test("a suffix keeps the source's own spelling unless the source is shouting", () => {
  assert.equal(normalizeName("Smith, John, Jr."), "John Smith Jr.")
  assert.equal(normalizeName("Smith, John, Ph.D."), "John Smith, Ph.D.")
  assert.equal(normalizeName("SMITH, JOHN, 2ND"), "John Smith 2nd")
})

test("what only looks like a suffix stays part of the name", () => {
  // Two initials, not Jr or MD.
  assert.equal(normalizeName("SMITH, J R"), "J R Smith")
  assert.equal(normalizeName("SMITH, M. D."), "M. D. Smith")
  // A one-word surname before the comma: Vi, Do and JR are given names here.
  assert.equal(normalizeName("NGUYEN, VI"), "Vi Nguyen")
  assert.equal(normalizeName("NGUYEN, DO"), "Do Nguyen")
  assert.equal(normalizeName("EWING, JR"), "Jr Ewing")
  assert.equal(normalizeName(", JR"), ", Jr")
})

test("an apostrophe surname keeps its shape, and a one-letter name is not turned into an initial", () => {
  // capitalizeString's `content: 'name'` mode does both of these wrong (it
  // reads the apostrophe as a word break and periods any single letter):
  // "Patrick O.'Brien", "X. Li". This is why that mode is not used here.
  assert.equal(normalizeName("O'BRIEN, PATRICK"), "Patrick O'Brien")
  assert.equal(normalizeName("D'ANGELO, MARIA"), "Maria D'Angelo")
  assert.equal(normalizeName("LI, X"), "X Li")
})

test("each part of a nicknamed name decides its own casing", () => {
  // Judged as one string, the hand-typed "Jack" makes the whole name look
  // deliberately capitalized and the shouted halves survive untouched.
  assert.equal(normalizeName("JOHN “Jack” SMITH"), "John “Jack” Smith")
  assert.equal(normalizeName("SEBASTIAN “SEB” DELMONT"), "Sebastian “Seb” Delmont")
  // Initials are a nickname's most common shape, and capitalizing them as a
  // word gives "Mj".
  assert.equal(normalizeName("MARY-JO “MJ” OBRIEN"), "Mary-Jo “MJ” Obrien")
  // A record with a nickname but no first name leads with the quote, which
  // capitalizeString absorbs into the first word — lowercasing it.
  assert.equal(normalizeName("“SEB” DELMONT"), "“Seb” Delmont")
})

test("a name in a script capitalizeString cannot judge is left exactly as written", () => {
  // Greek uppercase drops the tonos and lowercasing cannot restore it, so
  // recasing here produces a confident misspelling of a real person's name.
  assert.equal(normalizeName("ΓΕΩΡΓΙΟΣ ΠΑΠΑΣ"), "ΓΕΩΡΓΙΟΣ ΠΑΠΑΣ")
})

test("city, county and country are cleaned up; state is left as the code it is", () => {
  const guess = normalizeGuess({
    call: "KI2D",
    city: "WOODRIDGE",
    state: "NY",
    county: "SULLIVAN",
    country: "UNITED STATES",
  } as CallInfo)

  assert.equal(guess.city, "Woodridge")
  assert.equal(guess.county, "Sullivan")
  assert.equal(guess.country, "United States")
  assert.equal(guess.state, "NY")
})

test("a composed location follows its city, and its state code is not word-capitalized", () => {
  const guess = normalizeGuess({ call: "KI2D", city: "WOODRIDGE", state: "NY", location: "WOODRIDGE, NY" } as CallInfo)
  assert.equal(guess.location, "Woodridge, NY")
})

test("a country the lookup service could not name stays the code it is", () => {
  // services.ham2k.net has full names for three countries and reports ISO
  // alpha-2 for every other — "FR" must not become "Fr".
  assert.equal(normalizeGuess({ call: "F5ABC", country: "FR" } as CallInfo).country, "FR")
  assert.equal(normalizeGuess({ call: "F5ABC", country: "FRANCE" } as CallInfo).country, "France")
})

test("the location rewrite needs the whole city, not a prefix of a different place", () => {
  // city and location routinely arrive from different sources (a park owns
  // the location, QRZ the city), so a bare startsWith splices the two.
  const guess = normalizeGuess({ call: "KI2D", city: "SPRING", location: "SPRINGFIELD, IL" } as CallInfo)
  assert.equal(guess.location, "SPRINGFIELD, IL")
})

test("a location that is not about the city is left untouched", () => {
  // POTA/SOTA locationDescs ride in the same field; address-capitalizing one
  // would turn "US-NY" into "Us-Ny".
  const guess = normalizeGuess({ call: "KI2D", city: "WOODRIDGE", location: "US-NY" } as CallInfo)
  assert.equal(guess.location, "US-NY")
})

test("normalization does not mutate the guess it was given", () => {
  const original: CallInfo = { call: "KI2D", name: "DELMONT, SEBASTIAN", city: "WOODRIDGE" }
  normalizeGuess(original)
  assert.equal(original.name, "DELMONT, SEBASTIAN")
  assert.equal(original.city, "WOODRIDGE")
})
