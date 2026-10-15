// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Run with `node --experimental-strip-types --test` (see package.json).

import { test } from "node:test"
import assert from "node:assert/strict"

import { parseSelfSpotCommand, isLastSpotCommand, parseRespotCommand } from "./spotCommandParsing.ts"

test("parseSelfSpotCommand: bare SPOT has an empty comment", () => {
  assert.deepEqual(parseSelfSpotCommand("SPOT"), { comment: "" })
})

test("parseSelfSpotCommand: SPOTME, SPME, SELFSPOT all behave like SPOT", () => {
  for (const trigger of ["SPOTME", "SPME", "SELFSPOT"]) {
    assert.deepEqual(parseSelfSpotCommand(trigger), { comment: "" }, trigger)
  }
})

test("parseSelfSpotCommand: SPOT with free text carries it as the comment verbatim", () => {
  assert.deepEqual(parseSelfSpotCommand("SPOT good signal"), { comment: "good signal" })
})

test("parseSelfSpotCommand: a Q-code trigger becomes the first word of the comment", () => {
  assert.deepEqual(parseSelfSpotCommand("QRV"), { comment: "QRV" })
  assert.deepEqual(parseSelfSpotCommand("QRT ADIOS"), { comment: "QRT ADIOS" })
  assert.deepEqual(parseSelfSpotCommand("QSY up"), { comment: "QSY up" })
  assert.deepEqual(parseSelfSpotCommand("QRX brb"), { comment: "QRX brb" })
})

test("parseSelfSpotCommand: matching is case-insensitive, trigger normalizes to uppercase in the comment", () => {
  assert.deepEqual(parseSelfSpotCommand("qrt adios"), { comment: "QRT adios" })
  assert.deepEqual(parseSelfSpotCommand("spot"), { comment: "" })
})

test("parseSelfSpotCommand: a slash separator works the same as a space", () => {
  assert.deepEqual(parseSelfSpotCommand("SPOT/good signal"), { comment: "good signal" })
})

test("parseSelfSpotCommand: unrelated input doesn't match", () => {
  assert.equal(parseSelfSpotCommand("K1ABC"), null)
  assert.equal(parseSelfSpotCommand("SPOTLAST"), null) // handled by isLastSpotCommand instead
  assert.equal(parseSelfSpotCommand(""), null)
})

test("isLastSpotCommand: SPOTLAST, SPOTEM, SPOTTHEM, SPTHEM all match, case-insensitively", () => {
  for (const trigger of ["SPOTLAST", "SPOTEM", "SPOTTHEM", "SPTHEM", "spotlast"]) {
    assert.equal(isLastSpotCommand(trigger), true, trigger)
  }
})

test("isLastSpotCommand: doesn't accept trailing text (no comment support, per the issue)", () => {
  assert.equal(isLastSpotCommand("SPOTLAST typo"), false)
})

test("isLastSpotCommand: unrelated input doesn't match", () => {
  assert.equal(isLastSpotCommand("SPOT"), false)
  assert.equal(isLastSpotCommand("K1ABC"), false)
})

test("parseRespotCommand: bare RESPOT is every ten minutes, a number is that many", () => {
  assert.deepEqual(parseRespotCommand("RESPOT"), { minutes: 10 })
  assert.deepEqual(parseRespotCommand("respot 7"), { minutes: 7 })
  assert.deepEqual(parseRespotCommand("RESPOT 30"), { minutes: 30 })
})

// What the confirmation promises has to be what the app does, and the app
// holds RESPOT between five and sixty minutes.
test("parseRespotCommand: fewer than five minutes is five, more than sixty is sixty", () => {
  assert.deepEqual(parseRespotCommand("RESPOT 1"), { minutes: 5 })
  assert.deepEqual(parseRespotCommand("RESPOT 40000"), { minutes: 60 })
})

test("parseRespotCommand: OFF and 0 stop it", () => {
  assert.deepEqual(parseRespotCommand("RESPOT OFF"), { off: true })
  assert.deepEqual(parseRespotCommand("respot off"), { off: true })
  assert.deepEqual(parseRespotCommand("RESPOT 0"), { off: true })
})

// Recognized but wrong, so the operator is told how to use it rather than
// having "RESPOT FIVE" fall through to the callsign.
test("parseRespotCommand: any other parameter is invalid, anything else is not RESPOT", () => {
  assert.deepEqual(parseRespotCommand("RESPOT FIVE"), { invalid: true })
  assert.deepEqual(parseRespotCommand("RESPOT 5.5"), { invalid: true })
  assert.equal(parseRespotCommand("RESPOTS"), null)
  assert.equal(parseRespotCommand("SPOT"), null)
})
