// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Guessing NAQP's exchange. A guess here is not a hint — it is STAMPED onto the
// ref at save and exported as though the station had sent it — so a wrong guess
// is a wrong claim in a submitted log, not a cosmetic annoyance.
//
// Both bugs found in this file's logic were data-shape assumptions that one
// command against the country file would have disproved. These check the
// country file rather than restating what it was assumed to say.

import { test } from "node:test"
import assert from "node:assert/strict"

import { firstName, guessedLocation, guessedName, ourExchange } from "./exchange.ts"
import { VALID_LOCATIONS } from "./locations.ts"
import { annotateCallAgainstCountryFile } from "../../../sdk/src/dxcc.ts"

test("a US or Canadian station is guessed at its state, never its prefix", () => {
  assert.equal(guessedLocation({ call: "W1AW", state: "CT" }), "CT")
  assert.equal(guessedLocation({ call: "VE3XYZ", guess: { state: "ON" } }), "ON")
  // No state resolved: blank, because every US and Canadian station is a
  // multiplier and a wrong one is a wrong claim.
  assert.equal(guessedLocation({ call: "W1AW" }), "")
})

test("Alaska is 'KL' in the country file, not 'KL7'", () => {
  // The bug: SENDS_A_STATE listed 'KL7', so Alaskan calls fell through to the
  // entity branch and were guessed as the raw prefix — an invalid exchange, and
  // a state multiplier silently lost.
  assert.equal(annotateCallAgainstCountryFile("KL7RA").entityPrefix, "KL")
  assert.equal(annotateCallAgainstCountryFile("NL7V").entityPrefix, "KL")

  assert.equal(guessedLocation({ call: "KL7RA", state: "AK" }), "AK")
  assert.equal(guessedLocation({ call: "KL7RA" }), "", 'not "KL", which is no exchange at all')
})

test("a North American entity is guessed only when NAQP recognizes it", () => {
  assert.equal(guessedLocation({ call: "XE1ABC" }), "XE")
  assert.equal(guessedLocation({ call: "TI2ABC" }), "TI")
})

test("a sub-entity prefix reduces to the DXCC prefix NAQP actually lists", () => {
  // The country file splits entities finer than NAQP does: San Andres is
  // 'HK0/a' and Clipperton 'FO/c', neither of which is an exchange. Passing one
  // through would stamp "HK0/A" onto the ref — five characters, past the
  // field's own maxLength and pattern, and rejected by any log checker. But
  // dropping it entirely loses a real multiplier, so reduce to the parent.
  assert.equal(annotateCallAgainstCountryFile("HK0AA").entityPrefix, "HK0/a")
  assert.ok(!VALID_LOCATIONS.has("HK0/A"))
  assert.equal(guessedLocation({ call: "HK0AA" }), "HK0")

  assert.equal(annotateCallAgainstCountryFile("FO0AAA").entityPrefix, "FO/c")
  assert.equal(guessedLocation({ call: "FO0AAA" }), "FO")
})

test("a prefix with no valid parent is still dropped rather than invented", () => {
  // Malpelo is 'HK0/m' but sits in South America, so it never reaches the NA
  // branch at all — it is DX, which is what a NAQP entrant would send.
  assert.equal(guessedLocation({ call: "HK0MM" }), "DX")
})

test("a station outside North America is DX", () => {
  assert.equal(guessedLocation({ call: "DL1ABC" }), "DX")
  assert.equal(guessedLocation({ call: "JA1ABC" }), "DX")
  // Nothing resolvable at all — not even DX, which would be a claim.
  assert.equal(guessedLocation({ call: "" }), "")
})

test("every location this can produce is one NAQP accepts", () => {
  // The invariant the two bugs above both broke. Sweep a spread of real calls
  // and assert the guess is always either blank or a valid exchange — never a
  // raw country-file artifact.
  const calls = [
    "W1AW",
    "K1ABC",
    "KL7RA",
    "NL7V",
    "KH6XX",
    "VE3XYZ",
    "VY1AAA",
    "XE1ABC",
    "TI2ABC",
    "HK0AA",
    "HI3ABC",
    "CO2ABC",
    "ZF2AB",
    "8P6XX",
    "V31AB",
    "DL1ABC",
    "JA1ABC",
    "PY2ABC",
    "VK2ABC",
    "ZS1ABC",
    "",
  ]
  for (const call of calls) {
    const guess = guessedLocation({ call })
    assert.ok(guess === "" || VALID_LOCATIONS.has(guess), `${call} guessed "${guess}", which is not a valid NAQP exchange`)
  }
})

test("a name is the first word, upper-cased", () => {
  assert.equal(firstName("Hiram Percy Maxim"), "HIRAM")
  assert.equal(firstName("  bob "), "BOB")
  assert.equal(firstName(undefined), "")
  assert.equal(guessedName({ name: "Seb" }), "SEB")
  assert.equal(guessedName({ guess: { name: "Bob Smith" } }), "BOB")
  assert.equal(guessedName({ name: "Seb", guess: { name: "Bob" } }), "SEB", "the resolved name wins")
})

test("our own exchange is read from ourName/ourLocation, not name/location", () => {
  // `name` on a ref is a CORE slot: decorateRef writes the activity row's
  // subtitle there and the decorated ref is what gets persisted. Reading our
  // sent exchange from it meant the setup overwrote itself on save — with
  // Location "NY" and Name blank, the stored name became "NY" and every
  // exported QSO line read "NY NY".
  assert.deepEqual(ourExchange({ ourName: "seb", ourLocation: "ny" }), { name: "SEB", location: "NY" })
  assert.deepEqual(
    ourExchange({ ourName: "SEB", ourLocation: "NY", name: "SEB NY", location: "whatever" }),
    { name: "SEB", location: "NY" },
    "the decoration slot is ignored entirely",
  )
  assert.deepEqual(ourExchange(undefined), { name: "", location: "" })
})
